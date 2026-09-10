[CmdletBinding()]
param(
    [string]$ModelRelativePath,
    [string]$DisplayName = 'My AI SSD'
)
$ErrorActionPreference = 'Stop'
Import-Module (Join-Path $PSScriptRoot 'T5Launcher.psm1') -Force -DisableNameChecking

try {
    # Running from the drive root makes the launcher independent of its drive letter.
    $root = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..')).TrimEnd('\') + '\'
    if ($root -notmatch '^[A-Za-z]:\\$') { throw 'Copy the launcher files to the root of your external drive, then run Configure-SSD.cmd there.' }
    $drive = [IO.DriveInfo]::new($root)
    if ($drive.DriveType -notin @([IO.DriveType]::Fixed, [IO.DriveType]::Removable)) { throw 'Use a local external drive, not a network share.' }
    if ($drive.DriveFormat -notin @('NTFS','exFAT')) { throw 'Use an existing NTFS or exFAT volume. Setup never formats a drive.' }
    $systemRoot = [IO.Path]::GetPathRoot([Environment]::GetFolderPath('Windows'))
    if ((Get-T5VolumeSerial $root) -eq (Get-T5VolumeSerial $systemRoot)) { throw 'Do not pair the Windows system volume.' }
    $destination = Join-Path $PSScriptRoot 'device.json'
    if (Test-Path -LiteralPath $destination) { throw 'device.json already exists. Setup will not overwrite an existing pairing.' }
    if (-not $ModelRelativePath) {
        $ModelRelativePath = Read-Host 'Hugging Face hub folder, relative to this drive [AI\Models\huggingface\hub]'
        if (-not $ModelRelativePath) { $ModelRelativePath = 'AI\Models\huggingface\hub' }
    }
    $device = [pscustomobject][ordered]@{
        schemaVersion = 1
        deviceId = [guid]::NewGuid().ToString()
        volumeSerial = Get-T5VolumeSerial $root
        displayName = $DisplayName
        modelRelativePath = $ModelRelativePath
    }
    Assert-T5DeviceConfig $device
    $plan = Get-T5CachePlan $root $device
    $hub = $plan.CachePath
    Write-Host "`nDrive: $root ($($drive.VolumeLabel))"
    Write-Host "Cache: $hub"
    Write-Host "Cache folders found: $($plan.RepositoryCount) (not a completeness or compatibility check)"
    Write-Host 'Setup adds T5-Launcher\device.json and creates the cache folder if missing. It does not copy or change models.'
    if ($plan.RepositoryCount -eq 0) { Write-Host 'Starting empty: download your first model inside Unsloth after launching.' }
    Write-Host 'Confirm that this is your external drive. Setup does not identify the USB manufacturer.'
    if ((Read-Host 'Type PAIR to continue') -cne 'PAIR') { Write-Host 'Cancelled; nothing was written.'; exit 0 }
    if ((Get-T5VolumeSerial $root) -ne $device.volumeSerial) { throw 'The drive changed during setup. Nothing was written.' }
    Assert-T5PlainPath $hub
    [void][IO.Directory]::CreateDirectory($hub)
    $bytes = [Text.UTF8Encoding]::new($false).GetBytes(($device | ConvertTo-Json) + "`r`n")
    # CreateNew also protects against another process creating the marker after our check.
    $stream = [IO.File]::Open($destination, [IO.FileMode]::CreateNew, [IO.FileAccess]::Write, [IO.FileShare]::None)
    try { $stream.Write($bytes, 0, $bytes.Length) } finally { $stream.Dispose() }
    Write-Host 'Paired. Close Unsloth completely, then double-click Start-Unsloth-With-T5.cmd.'
} catch {
    Write-Error $_.Exception.Message -ErrorAction Continue
    exit 1
}
