[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)][string]$Python,
    [Parameter(Mandatory=$true)][string]$BackendDirectory
)
$ErrorActionPreference = 'Stop'
$repo = Split-Path $PSScriptRoot -Parent
Import-Module (Join-Path $repo 'T5-Launcher\T5Launcher.psm1') -Force -DisableNameChecking
foreach ($path in @($Python,$BackendDirectory)) {
    if ($path -notmatch '^[A-Za-z]:\\' -or $path.Contains('"')) { throw 'Supply absolute local installation paths.' }
}
if (-not (Test-Path -LiteralPath $Python -PathType Leaf)) { throw 'Python executable not found.' }
if (-not (Test-Path -LiteralPath (Join-Path $BackendDirectory 'utils\hf_cache_settings.py') -PathType Leaf)) { throw 'Installed cache module not found.' }
$config = Get-Content -LiteralPath (Join-Path $repo 'T5-Launcher\device.example.json') -Raw | ConvertFrom-Json
# A synthetic path is sufficient: routing does not require opening model files.
$info = New-T5StartInfo $Python $repo $config
$info.EnvironmentVariables['PYTHONDONTWRITEBYTECODE'] = '1'
$probe = Join-Path $PSScriptRoot 'Probe-Unsloth-Cache.py'
$info.Arguments = '-B "' + $probe + '" "' + $BackendDirectory.TrimEnd('\') + '"'
$info.RedirectStandardOutput = $true
$info.RedirectStandardError = $true
$info.CreateNoWindow = $true
$process = [Diagnostics.Process]::Start($info)
$output = $process.StandardOutput.ReadToEndAsync()
$errors = $process.StandardError.ReadToEndAsync()
try {
    if (-not $process.WaitForExit(30000)) {
        $process.Kill() # Only this read-only probe, never an existing Unsloth session.
        throw 'Cache probe exceeded 30 seconds.'
    }
    $stdout = $output.GetAwaiter().GetResult()
    $stderr = $errors.GetAwaiter().GetResult()
    if ($process.ExitCode -ne 0) { throw "Cache probe failed: $stderr $stdout" }
    $stdout
} finally { $process.Dispose() }
