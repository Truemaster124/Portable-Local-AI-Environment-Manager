$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$repo = Split-Path $PSScriptRoot -Parent
$code = Join-Path $repo 'T5-Launcher'
$script:passed = 0
function Assert-True($Condition, [string]$Name) {
    if (-not $Condition) { throw "FAIL: $Name" }
    $script:passed++
    Write-Output "PASS: $Name"
}
function Assert-Throws([scriptblock]$Action, [string]$Name) {
    $failed = $false
    try { & $Action | Out-Null } catch { $failed = $true }
    Assert-True $failed $Name
}

foreach ($file in @(Get-ChildItem -LiteralPath $code -File | Where-Object { $_.Extension -in @('.ps1','.psm1') })) {
    $tokens = $null; $errors = $null
    $null = [Management.Automation.Language.Parser]::ParseFile($file.FullName, [ref]$tokens, [ref]$errors)
    Assert-True (@($errors).Count -eq 0) "Parse $($file.Name)"
}
Import-Module (Join-Path $code 'T5Launcher.psm1') -Force -DisableNameChecking
$example = Get-Content -LiteralPath (Join-Path $code 'device.example.json') -Raw
$config = $example | ConvertFrom-Json
Assert-T5DeviceConfig $config
Assert-True $true 'Accept a well-formed device configuration'
foreach ($path in @('..\hub','models\..\hub','.\hub','E:\hub','\server\hub','hub/../other','hub\','hub\\data','hub:stream','hub*','hub.','hub \data','')) {
    $bad = $example | ConvertFrom-Json
    $bad.modelRelativePath = $path
    Assert-Throws { Assert-T5DeviceConfig $bad } "Reject invalid relative path: [$path]"
}
foreach ($field in @('deviceId','volumeSerial','displayName')) {
    $bad = $example | ConvertFrom-Json
    $bad.$field = ''
    Assert-Throws { Assert-T5DeviceConfig $bad } "Reject empty $field"
}
$bad = $example | ConvertFrom-Json
$bad.PSObject.Properties.Remove('schemaVersion')
Assert-Throws { Assert-T5DeviceConfig $bad } 'Reject missing schema version'
Assert-True (-not (Test-T5Root $repo $config)) 'Source checkout is not a paired SSD'
Assert-True (-not (Test-T5Root 'relative' $config)) 'Reject relative storage roots'
Assert-True (-not (Test-T5Executable 'unsloth-studio.exe' 'E:\')) 'Reject relative executables'
Assert-True (-not (Test-T5Executable 'C:\Windows\notepad.exe' 'E:\')) 'Reject unrelated executables'
Assert-True ((Get-T5ExeFromText '"C:\Apps with spaces\unsloth-studio.exe",0') -eq 'C:\Apps with spaces\unsloth-studio.exe') 'Read quoted registry path'
Assert-True ((Get-T5ExeFromText 'C:\Apps with spaces\unsloth-studio.exe,0') -eq 'C:\Apps with spaces\unsloth-studio.exe') 'Read unquoted registry path'
Assert-True (-not (Get-T5ExeFromText 'cmd.exe /c something')) 'Reject a shell command as registration'

$beforeHub = [Environment]::GetEnvironmentVariable('HF_HUB_CACHE','Process')
$beforeHome = [Environment]::GetEnvironmentVariable('HF_HOME','Process')
$beforeToken = [Environment]::GetEnvironmentVariable('HF_TOKEN_PATH','Process')
foreach ($root in @('E:\','F:\','Z:\','C:\Mounts\AI SSD\','F:\Models with spaces & punctuation\')) {
    $info = New-T5StartInfo 'C:\Installed Apps\Unsloth\unsloth-studio.exe' $root $config
    Assert-True ($info.EnvironmentVariables['HF_HUB_CACHE'] -eq [IO.Path]::Combine($root,$config.modelRelativePath)) "Build cache path from $root"
    Assert-True ($info.EnvironmentVariables['HUGGINGFACE_HUB_CACHE'] -eq $info.EnvironmentVariables['HF_HUB_CACHE']) 'Both cache variables agree'
    Assert-True ($info.EnvironmentVariables['HF_HOME'] -eq (Get-T5HostPaths).HuggingFace) 'Use host-only credential home'
    Assert-True ($info.EnvironmentVariables['HF_TOKEN_PATH'] -eq [IO.Path]::Combine((Get-T5HostPaths).HuggingFace,'token')) 'Use host-only token path'
    Assert-True (-not $info.UseShellExecute -and $info.Arguments -eq '') 'No shell interpolation'
    Assert-True ($info.EnvironmentVariables['HF_XET_CACHE'].StartsWith([Environment]::GetFolderPath('LocalApplicationData'))) 'Auxiliary cache stays on host'
}
Assert-True ([Environment]::GetEnvironmentVariable('HF_HUB_CACHE','Process') -eq $beforeHub) 'Parent cache environment unchanged'
Assert-True ([Environment]::GetEnvironmentVariable('HF_HOME','Process') -eq $beforeHome) 'Parent credential home unchanged'
Assert-True ([Environment]::GetEnvironmentVariable('HF_TOKEN_PATH','Process') -eq $beforeToken) 'Parent token path unchanged'
Assert-True ($info.EnvironmentVariables['TRANSFORMERS_CACHE'] -eq $info.EnvironmentVariables['HF_HUB_CACHE']) 'Legacy Transformers cache agrees with selected Hub cache'
$oldHubOffline = $env:HF_HUB_OFFLINE
$oldTransformersOffline = $env:TRANSFORMERS_OFFLINE
try {
    $env:HF_HUB_OFFLINE = '1'
    $env:TRANSFORMERS_OFFLINE = '1'
    $info = New-T5StartInfo 'C:\Apps\Unsloth\unsloth-studio.exe' 'F:\' $config
    Assert-True ($info.EnvironmentVariables['HF_HUB_OFFLINE'] -eq '1') 'Preserve explicit Hub offline mode'
    Assert-True ($info.EnvironmentVariables['TRANSFORMERS_OFFLINE'] -eq '1') 'Preserve explicit Transformers offline mode'
} finally {
    $env:HF_HUB_OFFLINE = $oldHubOffline
    $env:TRANSFORMERS_OFFLINE = $oldTransformersOffline
}

$module = Get-Module T5Launcher
# These overrides exist only inside this module invocation. No drive is modified.
& $module {
    param($Config)
    $script:fixtureConfig = $Config
    function Test-Path { param($LiteralPath,$PathType); $true }
    function Get-T5DeviceConfig { param($Directory); $script:fixtureConfig }
    function Get-T5VolumeSerial { param($Root); '0123ABCD' }
    $testRoot = [IO.Path]::GetPathRoot([Environment]::GetFolderPath('Windows'))
    if (-not (Test-T5Root $testRoot $Config)) { throw 'Valid simulated SSD not recognized' }
    $different = $Config | ConvertTo-Json | ConvertFrom-Json
    $different.modelRelativePath = 'different\hub'
    if (Test-T5Root $testRoot $different) { throw 'Changed model path accepted' }
    $different = $Config | ConvertTo-Json | ConvertFrom-Json
    $different.deviceId = [guid]::NewGuid().ToString()
    if (Test-T5Root $testRoot $different) { throw 'Wrong device marker accepted' }
    function Get-T5VolumeSerial { param($Root); 'DEADBEEF' }
    if (Test-T5Root $testRoot $Config) { throw 'Wrong volume serial accepted' }
} $config
Assert-True $true 'Simulated root: identity, serial and model path must all match'

& $module {
    function Test-Path { param($LiteralPath,$PathType); $true }
    function Get-T5VolumeSerial { param($Root); '0123ABCD' }
    function Get-T5ContainingVolumeSerial { param($Path); '0123ABCD' }
    if (Test-T5Executable 'C:\Mounts\AI\unsloth-studio.exe' 'F:\') { throw 'SSD app copy accepted through mount' }
    if (Test-T5Executable 'F:\Apps\unsloth-studio.exe' 'F:\') { throw 'Direct SSD app copy accepted' }
    function Get-T5ContainingVolumeSerial { param($Path); 'CAFEBABE' }
    if (-not (Test-T5Executable 'C:\Apps\Unsloth\unsloth-studio.exe' 'F:\')) { throw 'Host app rejected' }
    function Get-T5ContainingVolumeSerial { param($Path); throw 'Volume resolution unavailable' }
    if (Test-T5Executable 'C:\Apps\Unsloth\unsloth-studio.exe' 'F:\') { throw 'Unknown executable volume accepted' }
}
Assert-True $true 'Executable volume guard rejects SSD copies and unresolved volumes'

& $module {
    param($Config)
    $script:testEvents = [Collections.Generic.List[string]]::new()
    function Test-T5Root { param($Root,$Config); $true }
    function Show-T5Message { param($Message,[switch]$Question); $script:testEvents.Add('prompt'); $false }
    function Get-T5RunningUnsloth { throw 'Process inspection called after declining consent' }
    $testRoot = [IO.Path]::GetPathRoot([Environment]::GetFolderPath('Windows'))
    Invoke-T5Launch $testRoot $Config
    if ($script:testEvents.Count -ne 1) { throw 'Decline did not stop the launch flow' }
    function Show-T5Message { param($Message,[switch]$Question); $script:testEvents.Add('prompt'); if ($Question) { $true } }
    function Get-T5RunningUnsloth { [pscustomobject]@{Name='unsloth-studio.exe';ProcessId=999999} }
    function Find-T5Unsloth { throw 'App discovery called despite running Unsloth' }
    Invoke-T5Launch $testRoot $Config
    if ($script:testEvents.Count -ne 3) { throw 'Running-app guard did not stop launch' }
} $config
Assert-True $true 'Declining consent stops before launch or state changes'
Assert-True $true 'Running Unsloth blocks a competing launch'

& $module {
    param($Config)
    $script:rootChecks = 0
    function Assert-T5HostPrivacy { param($Config) }
    function Test-T5Root { param($Root,$Config); $script:rootChecks++; $script:rootChecks -eq 1 }
    function Show-T5Message { param($Message,[switch]$Question); $true }
    function Get-T5RunningUnsloth { }
    function Find-T5Unsloth { param($Root); 'C:\Apps\Unsloth\unsloth-studio.exe' }
    function New-T5StartInfo { throw 'UNSAFE: reached process construction after disconnect' }
    $caught = $false
    try { Invoke-T5Launch ([IO.Path]::GetPathRoot([Environment]::GetFolderPath('Windows'))) $Config }
    catch { if ($_.Exception.Message -ne 'The T5 was disconnected. Nothing was launched.') { throw }; $caught = $true }
    if (-not $caught) { throw 'Expected disconnect to stop launch' }
} $config
Assert-True $true 'Disconnect while consent is open stops launch'

$savedEnvironment = @{}
$privacyKeys = @('HF_HOME','HF_TOKEN_PATH','HF_TOKEN','HUGGING_FACE_HUB_TOKEN','TEMP','TMP','TMPDIR','HF_DATASETS_CACHE','UNSLOTH_STUDIO_DOCUMENTS_HOME','UNSLOTH_STUDIO_PROJECTS_HOME')
try {
    foreach ($key in $privacyKeys) {
        $savedEnvironment[$key] = [Environment]::GetEnvironmentVariable($key,'Process')
        [Environment]::SetEnvironmentVariable($key,'Z:\Shared\previous-user','Process')
    }
    $info = New-T5StartInfo 'C:\Apps\Unsloth\unsloth-studio.exe' 'Z:\' $config
    foreach ($key in @('HF_HOME','HF_TOKEN_PATH','TEMP','TMP','TMPDIR','HF_DATASETS_CACHE','UNSLOTH_STUDIO_DOCUMENTS_HOME','UNSLOTH_STUDIO_PROJECTS_HOME')) {
        Assert-True ($info.EnvironmentVariables[$key].StartsWith((Get-T5LocalDirectory) + '\',[StringComparison]::OrdinalIgnoreCase)) "Keep $key in this user's launcher directory"
    }
    Assert-True (-not $info.EnvironmentVariables.ContainsKey('HF_TOKEN')) 'Do not inherit a raw Hub token'
    Assert-True (-not $info.EnvironmentVariables.ContainsKey('HUGGING_FACE_HUB_TOKEN')) 'Do not inherit a legacy raw Hub token'
    Assert-True ($env:HF_TOKEN -eq 'Z:\Shared\previous-user') 'Child credential isolation does not change the parent'
} finally {
    foreach ($key in $privacyKeys) { [Environment]::SetEnvironmentVariable($key,$savedEnvironment[$key],'Process') }
}
foreach ($path in @('relative','Z:relative','\\server\profile','C:\Users\..\Shared','C:\file:stream','C:\folder*')) {
    Assert-Throws { Assert-T5PlainPath $path } "Reject unsafe private path: $path"
}
& $module {
    function Get-Item { param($LiteralPath,[switch]$Force,$ErrorAction); [pscustomobject]@{Attributes=[IO.FileAttributes]::ReparsePoint} }
    $caught = $false
    try { Assert-T5PlainPath 'C:\Users\Example\Redirected' } catch { $caught = $true }
    if (-not $caught) { throw 'Reparse point accepted' }
}
Assert-True $true 'A simulated junction is rejected without following it'
& $module {
    param($Config)
    $script:privateFixture = Get-T5HostPaths
    function Get-T5HostPaths { $script:privateFixture }
    function Assert-T5PlainPath { param($Path) }
    function Test-Path { param($LiteralPath,$PathType); $true }
    function Get-T5VolumeSerial { param($Root); 'CAFEBABE' }
    Assert-T5HostPrivacy $Config
    $script:privateFixture.Studio = 'Z:\Shared\studio'
    $caught = $false
    try { Assert-T5HostPrivacy $Config } catch { $caught = $true }
    if (-not $caught) { throw 'Shared Studio state accepted' }
} $config
Assert-True $true 'Studio state outside the host profile is rejected'

& $module {
    param($Config)
    function Test-T5Root { param($Root,$Config); $true }
    function Show-T5Message { param($Message,[switch]$Question); $true }
    function Get-T5RunningUnsloth { }
    function Assert-T5HostPrivacy { param($Config); throw 'Privacy check blocked launch' }
    function Find-T5Unsloth { throw 'UNSAFE: app lookup reached after failed privacy check' }
    $caught = $false
    try { Invoke-T5Launch ([IO.Path]::GetPathRoot([Environment]::GetFolderPath('Windows'))) $Config }
    catch { if ($_.Exception.Message -ne 'Privacy check blocked launch') { throw }; $caught = $true }
    if (-not $caught) { throw 'Privacy check did not block launch' }
} $config
Assert-True $true 'Privacy failure stops before app selection or launch'

# Disposable fixtures are created only inside this checkout's ignored test-results folder.
$fixtureRoot = Join-Path $repo ('test-results\' + [guid]::NewGuid().ToString())
[void][IO.Directory]::CreateDirectory($fixtureRoot)
$fixtureConfig = $example | ConvertFrom-Json
$fixtureConfig.modelRelativePath = 'new\hub'
$plan = Get-T5CachePlan $fixtureRoot $fixtureConfig
Assert-True (-not $plan.Exists -and $plan.RepositoryCount -eq 0) 'Plan an empty library on a new drive'
Assert-True (-not (Test-Path -LiteralPath $plan.CachePath)) 'Planning alone creates no model directory'
[void][IO.Directory]::CreateDirectory($plan.CachePath)
Assert-True ((Get-T5CachePlan $fixtureRoot $fixtureConfig).RepositoryCount -eq 0) 'Accept an existing empty cache'
$fixtureConfig.modelRelativePath = 'loose'
[void][IO.Directory]::CreateDirectory((Join-Path $fixtureRoot 'loose'))
$dummyWeight = Join-Path $fixtureRoot 'loose\example.gguf'
[IO.File]::WriteAllText($dummyWeight,'test fixture, not a model')
$beforeFixture = (Get-FileHash -LiteralPath $dummyWeight).Hash
Assert-Throws { Get-T5CachePlan $fixtureRoot $fixtureConfig } 'Refuse a loose-file folder as a Hub cache'
Assert-True ((Get-FileHash -LiteralPath $dummyWeight).Hash -eq $beforeFixture) 'Refused setup preserves existing files'
$fixtureConfig.modelRelativePath = 'loose\example.gguf'
Assert-Throws { Get-T5CachePlan $fixtureRoot $fixtureConfig } 'Refuse a regular file as the cache destination'
$fixtureConfig.modelRelativePath = 'existing\hub'
[void][IO.Directory]::CreateDirectory((Join-Path $fixtureRoot 'existing\hub\models--example--model\snapshots'))
Assert-True ((Get-T5CachePlan $fixtureRoot $fixtureConfig).RepositoryCount -eq 1) 'Recognize an existing cache layout without claiming model completeness'

$windowsRoot = [IO.Path]::GetPathRoot([Environment]::GetFolderPath('Windows'))
$windowsExe = Join-Path ([Environment]::GetFolderPath('Windows')) 'System32\WindowsPowerShell\v1.0\powershell.exe'
Assert-True ((Get-T5ContainingVolumeSerial $windowsExe) -eq (Get-T5VolumeSerial $windowsRoot)) 'Native volume lookup resolves the host PowerShell volume (read-only)'
Write-Output "`n$script:passed checks passed on PowerShell $($PSVersionTable.PSVersion). No applications launched or helper installed."
