[CmdletBinding()]
param(
    [ValidateSet('Launch','Check','Watch','Install','Uninstall')][string]$Mode = 'Launch',
    [switch]$ConfirmedInstall,
    [switch]$SkipPresentOnce
)
$ErrorActionPreference = 'Stop'
Import-Module (Join-Path $PSScriptRoot 'T5Launcher.psm1') -Force

function Get-StartupLink {
    Join-Path ([Environment]::GetFolderPath('Startup')) 'Portable Local AI Connection Popup.lnk'
}

function Install-ConnectionHelper {
    param($Device)
    $sourceRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
    if (-not (Test-T5Root $sourceRoot $Device)) { throw 'Run the installer from the root of the paired SSD.' }
    Assert-T5HostPrivacy $Device
    if (-not $ConfirmedInstall) {
        if (-not (Show-T5Message -Question -Message "Install the T5 connection-popup helper for this Windows account?`r`n`r`nIt starts at sign-in and checks for this T5 every 5 seconds. It asks before launching Unsloth. No administrator access is required and no model files, global model settings or accounts are changed.`r`n`r`nUse Remove-T5-Connection-Popup.cmd to disable it. Other PCs need their own one-time installation.")) { return }
    }
    $local = Get-T5LocalDirectory
    $ownershipFile = Join-Path $local 'installed.json'
    $sourceFiles = @('T5Launcher.ps1','T5Launcher.psm1','device.json')
    if (Test-Path -LiteralPath $ownershipFile) {
        $old = Get-Content -LiteralPath $ownershipFile -Raw | ConvertFrom-Json
        if ($old.deviceId -ne $Device.deviceId) { throw 'An unrelated installation occupies the helper directory.' }
        foreach ($name in $sourceFiles) {
            if ((Get-FileHash -LiteralPath (Join-Path $local $name)).Hash -ne (Get-FileHash -LiteralPath (Join-Path $PSScriptRoot $name)).Hash) {
                throw 'An existing helper has different files. No files were overwritten. Inspect it before upgrading.'
            }
        }
    } elseif (Test-Path -LiteralPath $local) {
        $allowed = @('Cache','HuggingFace','Temp','Documents','Projects','app-location.json','last-launch.json','helper.log')
        if (@(Get-ChildItem -LiteralPath $local -Force | Where-Object { $_.Name -notin $allowed }).Count -gt 0) {
            throw 'The helper directory contains unrecognized files. Nothing was overwritten.'
        }
    }
    $linkPath = Get-StartupLink
    $shell = New-Object -ComObject WScript.Shell
    $powershell = Join-Path $env:SystemRoot 'System32\WindowsPowerShell\v1.0\powershell.exe'
    $localMain = Join-Path $local 'T5Launcher.ps1'
    $arguments = '-NoProfile -STA -WindowStyle Hidden -ExecutionPolicy Bypass -File "' + $localMain + '" -Mode Watch'
    if (Test-Path -LiteralPath $linkPath) {
        $oldLink = $shell.CreateShortcut($linkPath)
        if ($oldLink.TargetPath -ine $powershell -or $oldLink.Arguments -ne $arguments) { throw 'An unrelated startup shortcut has the same name. Nothing was overwritten.' }
    }
    [void][IO.Directory]::CreateDirectory($local)
    foreach ($name in $sourceFiles) {
        $destination = Join-Path $local $name
        if (-not (Test-Path -LiteralPath $destination)) { Copy-Item -LiteralPath (Join-Path $PSScriptRoot $name) -Destination $destination }
        if ((Get-FileHash -LiteralPath $destination).Hash -ne (Get-FileHash -LiteralPath (Join-Path $PSScriptRoot $name)).Hash) { throw "Installed copy mismatch: $name" }
    }
    $link = $shell.CreateShortcut($linkPath)
    $link.TargetPath = $powershell
    $link.Arguments = $arguments
    $link.WorkingDirectory = $local
    $link.WindowStyle = 7
    $link.Description = 'Ask before opening Unsloth with models on the paired external drive.'
    $link.Save()
    @{deviceId=$Device.deviceId;version='0.2.0';enabled=$true;installedAt=(Get-Date).ToString('o');startupLink=$linkPath} |
        ConvertTo-Json | Set-Content -LiteralPath $ownershipFile -Encoding UTF8
    $removeCmd = '@echo off' + "`r`n" + '"%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe" -NoProfile -STA -ExecutionPolicy Bypass -File "%~dp0T5Launcher.ps1" -Mode Uninstall' + "`r`n"
    [IO.File]::WriteAllText((Join-Path $local 'Remove-T5-Connection-Popup.cmd'), $removeCmd, [Text.Encoding]::ASCII)
    # Suppress a popup for the drive already connected during installation.
    Start-Process -FilePath $powershell -ArgumentList ($arguments + ' -SkipPresentOnce') -WindowStyle Hidden | Out-Null
    Write-Output "Installed per-user T5 helper at $local"
    if (-not $ConfirmedInstall) { Show-T5Message "Connection popups are enabled for this Windows account. The already-connected drive is not prompted during installation. Double-click Start-Unsloth-With-T5.cmd now, or safely reconnect the T5 later. The helper will also start at your next sign-in." }
}

function Remove-ConnectionHelper {
    param($Device)
    if (-not (Show-T5Message -Question -Message "Disable T5 connection popups for this Windows account?`r`n`r`nOnly this helper's startup shortcut will be removed. The watcher will stop within a few seconds. Its source files and logs are retained. Models, Unsloth and the SSD launcher will not be removed.")) { return }
    $local = Get-T5LocalDirectory
    $ownershipFile = Join-Path $local 'installed.json'
    if (-not (Test-Path -LiteralPath $ownershipFile)) { Show-T5Message 'The connection helper is not installed for this Windows account.'; return }
    $record = Get-Content -LiteralPath $ownershipFile -Raw | ConvertFrom-Json
    if ($record.deviceId -ne $Device.deviceId) { throw 'Helper ownership did not match; nothing was removed.' }
    $linkPath = Get-StartupLink
    if (Test-Path -LiteralPath $linkPath) {
        $shell = New-Object -ComObject WScript.Shell
        $link = $shell.CreateShortcut($linkPath)
        $expected = '-NoProfile -STA -WindowStyle Hidden -ExecutionPolicy Bypass -File "' + (Join-Path $local 'T5Launcher.ps1') + '" -Mode Watch'
        $expectedTarget = Join-Path $env:SystemRoot 'System32\WindowsPowerShell\v1.0\powershell.exe'
        if ($link.Arguments -ne $expected -or $link.TargetPath -ine $expectedTarget) { throw 'Startup shortcut changed; refusing to remove it.' }
        Remove-Item -LiteralPath $linkPath -ErrorAction Stop
    }
    $record.enabled = $false
    $record | ConvertTo-Json | Set-Content -LiteralPath $ownershipFile -Encoding UTF8
    Show-T5Message 'Connection popups disabled. Only the helper startup shortcut was removed; source files and all models were retained. Running the installer again re-enables the helper.'
}

function Watch-T5Connection {
    param($Device)
    $mutex = [Threading.Mutex]::new($false, 'Local\PortableLocalAI-Watch')
    $owned = $false
    try {
        try { $owned = $mutex.WaitOne(0) } catch [Threading.AbandonedMutexException] { $owned = $true }
        if (-not $owned) { return }
        $local = Get-T5LocalDirectory
        $ownershipFile = Join-Path $local 'installed.json'
        if (-not (Test-Path -LiteralPath $ownershipFile)) { throw 'Install the helper before starting watch mode.' }
        $record = Get-Content -LiteralPath $ownershipFile -Raw | ConvertFrom-Json
        if ($record.deviceId -ne $Device.deviceId -or -not $record.enabled) { return }
        Assert-T5HostPrivacy $Device
        @{processId=$PID;startedAt=(Get-Date).ToString('o');deviceId=$Device.deviceId} | ConvertTo-Json |
            Set-Content -LiteralPath (Join-Path $local 'watcher-status.json') -Encoding UTF8
        Write-T5Log 'Connection watcher started. No device code will be executed; prompts use the locally installed helper.'
        $seen = @()
        if ($SkipPresentOnce) { $seen = @(Find-T5Roots $Device) }
        while ($true) {
            $record = Get-Content -LiteralPath $ownershipFile -Raw | ConvertFrom-Json
            if ($record.deviceId -ne $Device.deviceId -or -not $record.enabled) { break }
            $present = @(Find-T5Roots $Device)
            foreach ($root in $present) {
                if ($root -notin $seen) {
                    # Debounce an insertion while the filesystem is becoming available.
                    Start-Sleep -Milliseconds 1200
                    if (Test-T5Root $root $Device) {
                        Write-T5Log "T5 detected at $root; requesting consent."
                        try { Invoke-T5Launch $root $Device } catch { Write-T5Log $_.Exception.Message; Show-T5Message $_.Exception.Message }
                    }
                }
            }
            # Declining prompts only once per insertion, not every scan.
            $seen = $present
            Start-Sleep -Seconds 5
        }
        Write-T5Log 'Connection watcher stopped normally.'
    } finally {
        if ($owned) { $mutex.ReleaseMutex() }
        $mutex.Dispose()
    }
}

try {
    $device = Get-T5DeviceConfig $PSScriptRoot
    switch ($Mode) {
        'Launch' {
            $root = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
            Invoke-T5Launch $root $device
        }
        'Check' {
            $root = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
            $privacy = 'passed'
            try { Assert-T5HostPrivacy $device } catch { $privacy = $_.Exception.Message }
            [pscustomobject]@{
                powershell=$PSVersionTable.PSVersion.ToString(); expectedDevice=$device.deviceId;
                scriptRootValid=(Test-T5Root $root $device); connectedRoots=@(Find-T5Roots $device);
                installedUnsloth=@(Find-T5Unsloth $root); runningUnsloth=@(Get-T5RunningUnsloth);
                hostPrivacy=$privacy; hostPaths=Get-T5HostPaths
            } | ConvertTo-Json -Depth 5
        }
        'Install' { Install-ConnectionHelper $device }
        'Uninstall' { Remove-ConnectionHelper $device }
        'Watch' { Watch-T5Connection $device }
    }
} catch {
    Write-Error $_.Exception.Message -ErrorAction Continue
    if ($Mode -ne 'Check' -and -not $ConfirmedInstall) { Show-T5Message $_.Exception.Message }
    exit 1
}
