$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$command = ''
try {
    if ($PSVersionTable.PSVersion.Major -lt 5) { throw 'Windows PowerShell 5.1 or newer is required.' }
    $requestJson = $env:PORTABLE_AI_REQUEST
    Remove-Item Env:PORTABLE_AI_REQUEST -ErrorAction SilentlyContinue
    if ([string]::IsNullOrWhiteSpace($requestJson) -or $requestJson.Length -gt 16384) { throw 'Missing or invalid CLI request. Run portable-ai --help.' }
    $request = $requestJson | ConvertFrom-Json
    $command = [string]$request.command
    if ($command -notin @('setup','check','launch','shortcut','popup-install','popup-remove')) { throw 'Unknown portable-ai command.' }
    $drive = [string]$request.drive
    $packageRoot = Split-Path $PSScriptRoot -Parent
    Import-Module (Join-Path $packageRoot 'T5-Launcher\T5Launcher.psm1') -Force -DisableNameChecking
    Import-Module (Join-Path $PSScriptRoot 'NpmInstaller.psm1') -Force -DisableNameChecking
    $serial = Assert-NpmDrive $drive
    $directory = Join-Path $drive 'T5-Launcher'
    if ($command -eq 'setup') {
        $marker = Join-Path $directory 'device.json'
        Assert-T5PlainPath $marker
        $paired = Test-Path -LiteralPath $marker
        if ($paired) {
            $config = Get-T5DeviceConfig $directory
            if (-not (Test-T5Root $drive $config)) { throw 'The existing pairing does not match this drive or its cache is missing. Setup will not replace it.' }
            if ($request.PSObject.Properties['modelPath'] -or $request.PSObject.Properties['displayName']) {
                throw 'This SSD is already paired. Omit --model-path and --name; setup will not change an existing pairing.'
            }
        } else {
            $modelPath = 'AI\Models\huggingface\hub'
            $displayName = 'My AI SSD'
            if ($request.PSObject.Properties['modelPath']) { $modelPath = [string]$request.modelPath }
            if ($request.PSObject.Properties['displayName']) { $displayName = [string]$request.displayName }
            $candidate = [pscustomobject]@{schemaVersion=1;deviceId=[guid]::NewGuid().ToString();volumeSerial=$serial;displayName=$displayName;modelRelativePath=$modelPath}
            Assert-T5DeviceConfig $candidate
            $null = Get-T5CachePlan $drive $candidate
            # Refuse unattended pairing. The original Configure script provides
            # the explicit PAIR prompt after the launcher payload is copied.
            if ([Console]::IsInputRedirected) { throw 'Setup needs an interactive terminal so you can confirm the SSD by typing PAIR.' }
        }
        $plan = @(Get-NpmPayloadPlan -PackageRoot $packageRoot -Destination $drive)
        if ((Assert-NpmDrive $drive) -ne $serial) { throw 'The drive changed during setup. Nothing was copied.' }
        Copy-NpmPayload $plan
        Assert-NpmRuntime $packageRoot $drive
        if ((Assert-NpmDrive $drive) -ne $serial) { throw 'The drive changed. Pairing was not started; inspect any copied launcher files before retrying.' }
        if ($paired) {
            Write-Output 'Launcher files verified. Existing pairing kept. Run portable-ai check --drive with this SSD drive letter.'
            exit 0
        }
        Write-Output 'Launcher copied. Confirm the drive below. Cancelling pairing leaves the launcher files available for a later setup.'
        $global:LASTEXITCODE = 0
        & (Join-Path $directory 'Configure-SSD.ps1') -ModelRelativePath $modelPath -DisplayName $displayName
        # The existing configuration script controls its own cancellation/error
        # exit codes. It never overwrites a marker or existing model files.
        exit $LASTEXITCODE
    }
    Assert-NpmRuntime $packageRoot $drive
    $global:LASTEXITCODE = 0
    if ($command -eq 'shortcut') {
        & (Join-Path $directory 'Create-Desktop-Shortcut.ps1')
    } else {
        $modes = @{check='Check';launch='Launch';'popup-install'='Install';'popup-remove'='Uninstall'}
        & (Join-Path $directory 'T5Launcher.ps1') -Mode $modes[$command]
    }
    exit $LASTEXITCODE
} catch {
    if ($command -eq 'check') {
        [pscustomobject]@{readyToLaunch=$false;problems=@($_.Exception.Message)} | ConvertTo-Json -Depth 3
    } else {
        [Console]::Error.WriteLine('portable-ai: ' + $_.Exception.Message)
    }
    exit 1
}
