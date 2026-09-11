$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$repo = Split-Path $PSScriptRoot -Parent
Import-Module (Join-Path $repo 'T5-Launcher\T5Launcher.psm1') -Force -DisableNameChecking
Import-Module (Join-Path $repo 'npm\NpmInstaller.psm1') -Force -DisableNameChecking
$script:passed = 0
function Assert-True($Condition, [string]$Name) {
    if (-not $Condition) { throw "FAIL: $Name" }
    $script:passed++
}
function Assert-Throws([scriptblock]$Action, [string]$Pattern, [string]$Name) {
    $message = ''
    try { & $Action | Out-Null } catch { $message = $_.Exception.Message }
    Assert-True ($message -match $Pattern) "$Name ($message)"
}
foreach ($file in @(Get-ChildItem -LiteralPath (Join-Path $repo 'npm') -File | Where-Object { $_.Extension -in @('.ps1','.psm1') })) {
    $tokens = $null; $errors = $null
    $null = [Management.Automation.Language.Parser]::ParseFile($file.FullName, [ref]$tokens, [ref]$errors)
    Assert-True (@($errors).Count -eq 0) "Parse $($file.Name)"
}
$fixtures = Join-Path $repo ('test-results\npm-' + [guid]::NewGuid().ToString('N'))
[void][IO.Directory]::CreateDirectory($fixtures)
$fresh = Join-Path $fixtures 'SSD files with spaces & punctuation'
[void][IO.Directory]::CreateDirectory($fresh)
$plan = @(Get-NpmPayloadPlan $repo $fresh)
Assert-True ($plan.Count -eq 13) 'Payload contains only the portable launcher files and license'
Assert-True (@(Get-ChildItem -LiteralPath $fresh -Force).Count -eq 0) 'Preflight writes nothing'
Copy-NpmPayload $plan
foreach ($item in $plan) { Assert-True ((Get-FileHash -LiteralPath $item.Target).Hash -eq $item.Hash) "Exact copy: $($item.Name)" }
Assert-NpmRuntime $repo $fresh
Assert-True $true 'Copied runtime is accepted'
$deviceText = '{"keep":"original pairing"}'
[IO.File]::WriteAllText((Join-Path $fresh 'T5-Launcher\device.json'), $deviceText)
[IO.File]::WriteAllText((Join-Path $fresh 'my-model.gguf'), 'existing model fixture')
Copy-NpmPayload @(Get-NpmPayloadPlan $repo $fresh)
Assert-True ([IO.File]::ReadAllText((Join-Path $fresh 'T5-Launcher\device.json')) -eq $deviceText) 'Repeated setup preserves pairing'
Assert-True ([IO.File]::ReadAllText((Join-Path $fresh 'my-model.gguf')) -eq 'existing model fixture') 'Repeated setup preserves unrelated model files'
$conflict = Join-Path $fixtures 'conflict'
[void][IO.Directory]::CreateDirectory($conflict)
[IO.File]::WriteAllText((Join-Path $conflict 'Start-Unsloth-With-T5.cmd'), 'keep this file')
Assert-Throws { $null = @(Get-NpmPayloadPlan $repo $conflict) } 'Existing file differs' 'A late conflict aborts preflight'
Assert-True (@(Get-ChildItem -LiteralPath $conflict -Force).Count -eq 1) 'A late conflict writes no earlier files'
Assert-True ([IO.File]::ReadAllText((Join-Path $conflict 'Start-Unsloth-With-T5.cmd')) -eq 'keep this file') 'A conflict is not overwritten'
$race = Join-Path $fixtures 'changed after preflight'
[void][IO.Directory]::CreateDirectory($race)
$racePlan = @(Get-NpmPayloadPlan $repo $race)
[IO.File]::WriteAllText((Join-Path $race 'Start-Unsloth-With-T5.cmd'), 'created after preflight')
Assert-Throws { Copy-NpmPayload $racePlan } 'Destination changed' 'Rechecks a concurrent destination change'
Assert-True (@(Get-ChildItem -LiteralPath $race -Force).Count -eq 1) 'Concurrent conflict writes no earlier files'
$occupied = Join-Path $fixtures 'occupied'
[void][IO.Directory]::CreateDirectory((Join-Path $occupied 'T5-Launcher\T5Launcher.ps1'))
Assert-Throws { $null = @(Get-NpmPayloadPlan $repo $occupied) } 'Existing file differs' 'Directory cannot stand in for script'
$runtime = Join-Path $fresh 'T5-Launcher\T5Launcher.ps1'
[IO.File]::AppendAllText($runtime, "`r`n# Different runtime")
Assert-Throws { Assert-NpmRuntime $repo $fresh } 'differs from this npm version' 'Changed drive scripts cannot be executed through npm'
$empty = Join-Path $fixtures 'empty'
[void][IO.Directory]::CreateDirectory($empty)
Assert-Throws { Assert-NpmRuntime $repo $empty } 'files are missing' 'Missing runtime gives setup instructions'
$badPackage = Join-Path $fixtures 'bad package'
[void][IO.Directory]::CreateDirectory((Join-Path $badPackage 'npm'))
foreach ($payload in @('["../outside"]','["T5-Launcher/../../outside"]','["C:/outside"]','[]')) {
    [IO.File]::WriteAllText((Join-Path $badPackage 'npm\payload.json'), $payload)
    Assert-Throws { $null = @(Get-NpmPayloadPlan $badPackage $empty) } 'Invalid|empty' 'Invalid manifest is rejected'
}
[IO.File]::WriteAllText((Join-Path $badPackage 'npm\payload.json'), '["missing.ps1"]')
Assert-Throws { $null = @(Get-NpmPayloadPlan $badPackage $empty) } 'Package file missing' 'Missing package asset detected before writes'
foreach ($drive in @('C:','..','E:\folder','\\server\share')) {
    Assert-Throws { Assert-NpmDrive $drive } 'drive root' 'Non-root and network targets are refused'
}
$systemDrive = [IO.Path]::GetPathRoot([Environment]::GetFolderPath('Windows'))
Assert-Throws { Assert-NpmDrive $systemDrive } 'system volume' 'System volume is refused before writes'

# A junction requires no administrator privilege. Retain it inside this disposable
# test directory; no recursive cleanup traverses it.
$redirected = Join-Path $fixtures 'redirected'
[void][IO.Directory]::CreateDirectory($redirected)
$link = Join-Path $redirected 'T5-Launcher'
New-Item -ItemType Junction -Path $link -Target $empty | Out-Null
Assert-Throws { $null = @(Get-NpmPayloadPlan $repo $redirected) } 'Redirected path rejected' 'Redirected payload destinations are refused'
Assert-True (@(Get-ChildItem -LiteralPath $empty -Force).Count -eq 0) 'Redirected directory stays untouched'
Write-Output "$script:passed npm installer checks passed. Fixtures: $fixtures"
