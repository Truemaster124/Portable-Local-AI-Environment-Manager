$ErrorActionPreference = 'Stop'
Import-Module (Join-Path $PSScriptRoot 'T5Launcher.psm1') -Force -DisableNameChecking
try {
    $device = Get-T5DeviceConfig $PSScriptRoot
    $link = Install-T5DesktopShortcut -SourceDirectory $PSScriptRoot -Config $device
    Write-Output "Desktop shortcut created: $link"
    Write-Output 'Connect your paired SSD, then double-click Portable Local AI to launch and confirm.'
} catch {
    Write-Error $_.Exception.Message -ErrorAction Continue
    exit 1
}
