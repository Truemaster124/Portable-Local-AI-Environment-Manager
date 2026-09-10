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
# Tests use their own mutex names; concurrent CI shells and a real launcher stay independent.
& $module { function script:Get-T5MutexName { param($Purpose); "Local\PortableLocalAI-Test-$PID-$Purpose" } }
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
    catch { if ($_.Exception.Message -ne 'The paired SSD was disconnected. Nothing was launched.') { throw }; $caught = $true }
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

# Regression checks for malformed JSON, Windows device names and interrupted state writes.
foreach ($path in @('CON','nul.txt','models\COM1','LPT9\hub','AUX.bin','CONIN$','CONOUT$','CLOCK$',('COM' + [char]0x00B9))) {
    $bad = $example | ConvertFrom-Json
    $bad.modelRelativePath = $path
    Assert-Throws { Assert-T5DeviceConfig $bad } "Reject reserved Windows path: $path"
}
foreach ($version in @('1',$true,1.5)) {
    $bad = $example | ConvertFrom-Json
    $bad.schemaVersion = $version
    Assert-Throws { Assert-T5DeviceConfig $bad } 'Reject non-integer schema versions'
}
$bad = $example | ConvertFrom-Json
$bad.volumeSerial = 12345678
Assert-Throws { Assert-T5DeviceConfig $bad } 'Reject numeric volume identity'
$bad = $example | ConvertFrom-Json
$bad.displayName = '   '
Assert-Throws { Assert-T5DeviceConfig $bad } 'Reject blank display names'
foreach ($path in @('C:\folder/../elsewhere','C:\folder.\file','C:\NUL.txt')) {
    Assert-Throws { Assert-T5PlainPath $path } "Reject ambiguous Windows path: $path"
}
Assert-True (-not (Test-T5Executable '\\server\apps\unsloth-studio.exe' 'E:\')) 'Reject a network executable before reading it'

foreach ($userName in @('Example User', ('Jos' + [char]0x00E9))) {
    & $module {
        param($FixtureRoot, $UserName)
        $script:appLocationFixture = Join-Path $FixtureRoot 'saved-app-location'
        [void][IO.Directory]::CreateDirectory($script:appLocationFixture)
        $script:expectedSavedExe = 'C:\Users\' + $UserName + '\Apps\Unsloth\unsloth-studio.exe'
        function Get-T5LocalDirectory { $script:appLocationFixture }
        function Test-T5Executable { param($Path,$Root); $Path -ceq $script:expectedSavedExe }
        function Get-ChildItem { throw 'A valid saved app path should not require registry discovery' }
        Write-T5Json (Join-Path $script:appLocationFixture 'app-location.json') @{executable=$script:expectedSavedExe}
        $found = @(Find-T5Unsloth 'E:\')
        if ($found.Count -ne 1 -or $found[0] -cne $script:expectedSavedExe) { throw 'Saved application path was not preserved' }
    } $fixtureRoot $userName
    Assert-True $true "Reuse the saved Unsloth path for a Windows profile named $userName"
}

$jsonPath = Join-Path $fixtureRoot 'device.json'
$unicodeConfig = $example | ConvertFrom-Json
$unicodeConfig.displayName = 'Caf' + [char]0x00E9 + ' models'
Write-T5Json $jsonPath $unicodeConfig
Assert-True ((Get-T5DeviceConfig $fixtureRoot).displayName -ceq $unicodeConfig.displayName) 'Read UTF-8 pairing names without a BOM on Windows PowerShell'
Write-T5Json $jsonPath $config
Assert-True ((Get-T5DeviceConfig $fixtureRoot).deviceId -eq $config.deviceId) 'Atomically replace an existing pairing-shaped state file'
$beforeJson = (Get-FileHash -LiteralPath $jsonPath).Hash
$lockedJson = [IO.File]::Open($jsonPath,[IO.FileMode]::Open,[IO.FileAccess]::Read,[IO.FileShare]::Read)
try { Assert-Throws { Write-T5Json $jsonPath @{changed=$true} } 'A locked state file refuses replacement' }
finally { $lockedJson.Dispose() }
Assert-True ((Get-FileHash -LiteralPath $jsonPath).Hash -eq $beforeJson) 'Failed state replacement preserves the previous complete file'
Assert-True (@(Get-ChildItem -LiteralPath $fixtureRoot -Filter '.portable-ai-*.tmp' -Force).Count -eq 0) 'State writer removes only its own temporary files'
[IO.File]::WriteAllText($jsonPath,('[' + $example + ']'))
Assert-Throws { Get-T5DeviceConfig $fixtureRoot } 'Reject a single-object array as the JSON root'
[IO.File]::WriteAllText($jsonPath,('x' * 17000))
Assert-Throws { Get-T5DeviceConfig $fixtureRoot } 'Reject oversized pairing files before parsing'
[IO.File]::WriteAllText($jsonPath,'{"schemaVersion":')
Assert-Throws { Get-T5DeviceConfig $fixtureRoot } 'Reject an incomplete pairing file'

& $module {
    param($Config,$FixtureRoot)
    $script:helperFixture = $FixtureRoot
    function Get-T5LocalDirectory { $script:helperFixture }
    $statePath = Join-Path $FixtureRoot 'installed.json'
    if (Test-T5HelperEnabled $Config) { throw 'Missing helper state enabled the watcher' }
    Write-T5Json $statePath @{deviceId=$Config.deviceId;enabled=$true}
    if (-not (Test-T5HelperEnabled $Config)) { throw 'Valid helper state was rejected' }
    foreach ($enabled in @($false,'true','false',1)) {
        Write-T5Json $statePath @{deviceId=$Config.deviceId;enabled=$enabled}
        if (Test-T5HelperEnabled $Config) { throw 'Invalid or disabled helper state enabled the watcher' }
    }
    Write-T5Json $statePath @{deviceId=[guid]::NewGuid().ToString();enabled=$true}
    if (Test-T5HelperEnabled $Config) { throw 'Another drive enabled this watcher' }
    [IO.File]::WriteAllText($statePath,'{')
    if (Test-T5HelperEnabled $Config) { throw 'Broken helper state enabled this watcher' }
} $config $fixtureRoot
Assert-True $true 'Only matching helper state with a JSON boolean true permits watcher launches'

& $module {
    param($Config)
    $script:enabledChecks = 0
    function Test-T5Root { param($Root,$Config); $true }
    function Show-T5Message { param($Message,[switch]$Question); $true }
    function Test-T5HelperEnabled { param($Config); $script:enabledChecks++; $script:enabledChecks -eq 1 }
    function Get-T5RunningUnsloth { throw 'Launch continued after helper was disabled during consent' }
    Invoke-T5Launch ([IO.Path]::GetPathRoot([Environment]::GetFolderPath('Windows'))) $Config -FromWatcher
    if ($script:enabledChecks -ne 2) { throw 'Helper state was not checked again after consent' }
} $config
Assert-True $true 'Disabling the watcher while its prompt is open prevents a later Yes from launching'

& $module {
    param($Config)
    function Test-T5Root { param($Root,$Config); $true }
    function Assert-T5HostPrivacy { param($Config) }
    function Find-T5Roots { param($Config); 'E:\' }
    function Find-T5Unsloth { param($Root); 'C:\Apps\Unsloth\unsloth-studio.exe' }
    function Get-T5RunningUnsloth { }
    if (-not (Get-T5SetupStatus 'E:\' $Config).readyToLaunch) { throw 'A ready setup was rejected' }
    function Test-T5Root { param($Root,$Config); $false }
    if ((Get-T5SetupStatus 'E:\' $Config).readyToLaunch) { throw 'A missing SSD passed diagnostics' }
    function Test-T5Root { param($Root,$Config); $true }
    function Get-T5RunningUnsloth { throw 'Process inspection unavailable' }
    if ((Get-T5SetupStatus 'E:\' $Config).readyToLaunch) { throw 'An unknown process state passed diagnostics' }
    function Get-T5RunningUnsloth { [pscustomobject]@{Name='unsloth-studio.exe';ProcessId=123} }
    if ((Get-T5SetupStatus 'E:\' $Config).readyToLaunch) { throw 'A running app passed readiness checks' }
    function Get-T5RunningUnsloth { }
    function Find-T5Unsloth { param($Root) }
    if ((Get-T5SetupStatus 'E:\' $Config).readyToLaunch) { throw 'A missing app passed diagnostics' }
    function Find-T5Unsloth { param($Root); 'C:\Apps\Unsloth\unsloth-studio.exe' }
    function Assert-T5HostPrivacy { param($Config); throw 'Unsafe private state' }
    if ((Get-T5SetupStatus 'E:\' $Config).readyToLaunch) { throw 'Unsafe private state passed diagnostics' }
} $config
Assert-True $true 'Readiness diagnostics distinguish launchable setups from missing or unsafe dependencies'

& $module {
    param($FixtureRoot)
    $script:logFixture = $FixtureRoot
    function Get-T5LocalDirectory { $script:logFixture }
    $log = Join-Path $FixtureRoot 'helper.log'
    [IO.File]::WriteAllText($log,'Keep this existing log')
    $lock = [IO.File]::Open($log,[IO.FileMode]::Open,[IO.FileAccess]::Read,[IO.FileShare]::None)
    try { Write-T5Log 'Cannot append while locked' -WarningAction SilentlyContinue }
    finally { $lock.Dispose() }
    if ([IO.File]::ReadAllText($log) -ne 'Keep this existing log') { throw 'A locked log was damaged' }
} $fixtureRoot
Assert-True $true 'A locked log does not stop the helper or overwrite existing content'

# Exercise the real command entry point in an isolated checkout with no pairing.
$entryFixture = Join-Path $fixtureRoot 'unpaired\T5-Launcher'
[void][IO.Directory]::CreateDirectory($entryFixture)
foreach ($name in @('T5Launcher.ps1','T5Launcher.psm1')) { Copy-Item -LiteralPath (Join-Path $code $name) -Destination $entryFixture }
$checkInfo = [Diagnostics.ProcessStartInfo]::new()
$checkInfo.FileName = $windowsExe
$checkInfo.Arguments = '-NoProfile -ExecutionPolicy Bypass -File "' + (Join-Path $entryFixture 'T5Launcher.ps1') + '" -Mode Check'
$checkInfo.UseShellExecute = $false
$checkInfo.CreateNoWindow = $true
$checkInfo.RedirectStandardOutput = $true
$checkInfo.RedirectStandardError = $true
$checkProcess = [Diagnostics.Process]::Start($checkInfo)
$checkOutput = $checkProcess.StandardOutput.ReadToEndAsync()
$checkError = $checkProcess.StandardError.ReadToEndAsync()
try {
    if (-not $checkProcess.WaitForExit(15000)) { $checkProcess.Kill(); throw 'Unpaired diagnostics timed out' }
    $report = $checkOutput.GetAwaiter().GetResult() | ConvertFrom-Json
    Assert-True ($checkProcess.ExitCode -eq 1 -and -not $report.readyToLaunch) 'Unpaired diagnostics return JSON and a failing process exit code without a dialog'
    Assert-True ($report.problems[0] -match 'Configure-SSD.cmd') 'Unpaired diagnostics explain the next setup step'
} finally { $checkProcess.Dispose() }

# Load only function definitions, never the entry point, to test helper lifecycle
# with disposable paths and a fake shortcut service. No real helper is installed.
$entryTokens = $null; $entryErrors = $null
$entryAst = [Management.Automation.Language.Parser]::ParseFile((Join-Path $code 'T5Launcher.ps1'),[ref]$entryTokens,[ref]$entryErrors)
$installDefinition = $entryAst.Find({ param($node); $node -is [Management.Automation.Language.FunctionDefinitionAst] -and $node.Name -eq 'Install-ConnectionHelper' },$false).Extent.Text
$removeDefinition = $entryAst.Find({ param($node); $node -is [Management.Automation.Language.FunctionDefinitionAst] -and $node.Name -eq 'Remove-ConnectionHelper' },$false).Extent.Text
& {
    param($Definition,$Config)
    . ([scriptblock]::Create($Definition))
    $ConfirmedInstall = $false
    $script:installationRootChecks = 0
    function Test-T5Root { param($Root,$Config); $script:installationRootChecks++; $script:installationRootChecks -eq 1 }
    function Assert-T5HostPrivacy { param($Config) }
    function Show-T5Message { param($Message,[switch]$Question); $true }
    function Get-T5LocalDirectory { throw 'Installation continued after the drive disappeared' }
    $blocked = $false
    try { Install-ConnectionHelper $Config -SourceDirectory $code }
    catch {
        if ($_.Exception.Message -notmatch 'paired SSD changed or was disconnected') { throw }
        $blocked = $true
    }
    if (-not $blocked -or $script:installationRootChecks -ne 2) { throw 'Install did not recheck the drive after consent' }
} $installDefinition $config
Assert-True $true 'Disconnecting during installation consent prevents helper changes'

& {
    param($Definition,$Config,$FixtureRoot)
    . ([scriptblock]::Create($Definition))
    $helperLocal = Join-Path $FixtureRoot 'helper-lifecycle'
    [void][IO.Directory]::CreateDirectory($helperLocal)
    $helperLink = Join-Path $helperLocal 'startup-fixture.lnk'
    $helperRecord = Join-Path $helperLocal 'installed.json'
    $retainedFile = Join-Path $helperLocal 'T5Launcher.ps1'
    [IO.File]::WriteAllText($helperLink,'disposable shortcut fixture')
    [IO.File]::WriteAllText($retainedFile,'keep helper sources')
    function Get-T5LocalDirectory { $helperLocal }
    function Get-StartupLink { $helperLink }
    function Show-T5Message { param($Message,[switch]$Question); if ($Question) { $true } }
    $fakeShortcut = [pscustomobject]@{TargetPath='C:\Unrelated.exe';Arguments='unrelated'}
    $fakeShell = [pscustomobject]@{Shortcut=$fakeShortcut}
    $fakeShell | Add-Member -MemberType ScriptMethod -Name CreateShortcut -Value { param($Path); $this.Shortcut }
    function New-Object { param($ComObject); $fakeShell }

    Write-T5Json $helperRecord @{deviceId=[guid]::NewGuid().ToString();enabled=$true}
    Assert-Throws { Remove-ConnectionHelper $Config } 'Uninstall refuses an unrelated helper installation'
    Assert-True (Test-Path -LiteralPath $helperLink) 'Ownership failure preserves the startup shortcut'
    Write-T5Json $helperRecord @{deviceId=$Config.deviceId;enabled=$true}
    Assert-Throws { Remove-ConnectionHelper $Config } 'Uninstall refuses a replaced startup shortcut'
    Assert-True ((Get-Content -LiteralPath $helperRecord -Raw | ConvertFrom-Json).enabled) 'Shortcut mismatch preserves the previous helper state'

    $fakeShortcut.TargetPath = Join-Path $env:SystemRoot 'System32\WindowsPowerShell\v1.0\powershell.exe'
    $fakeShortcut.Arguments = '-NoProfile -STA -WindowStyle Hidden -ExecutionPolicy Bypass -File "' + (Join-Path $helperLocal 'T5Launcher.ps1') + '" -Mode Watch'
    Remove-ConnectionHelper $Config
    Assert-True (-not (Test-Path -LiteralPath $helperLink)) 'Verified uninstall removes only its fixture shortcut'
    Assert-True (-not (Get-Content -LiteralPath $helperRecord -Raw | ConvertFrom-Json).enabled) 'Uninstall writes a complete disabled state'
    Assert-True ([IO.File]::ReadAllText($retainedFile) -eq 'keep helper sources') 'Uninstall retains helper sources'
} $removeDefinition $config $fixtureRoot

Copy-Item -LiteralPath (Join-Path $repo 'Check-Setup.cmd') -Destination (Split-Path $entryFixture -Parent)
$wrapperInfo = [Diagnostics.ProcessStartInfo]::new()
$wrapperInfo.FileName = Join-Path $env:SystemRoot 'System32\cmd.exe'
$wrapperInfo.Arguments = '/d /c ""' + (Join-Path (Split-Path $entryFixture -Parent) 'Check-Setup.cmd') + '""'
$wrapperInfo.UseShellExecute = $false
$wrapperInfo.CreateNoWindow = $true
$wrapperInfo.RedirectStandardInput = $true
$wrapperInfo.RedirectStandardOutput = $true
$wrapperInfo.RedirectStandardError = $true
$wrapperProcess = [Diagnostics.Process]::Start($wrapperInfo)
$wrapperOutput = $wrapperProcess.StandardOutput.ReadToEndAsync()
$wrapperError = $wrapperProcess.StandardError.ReadToEndAsync()
$wrapperProcess.StandardInput.WriteLine('x')
$wrapperProcess.StandardInput.Close()
try {
    if (-not $wrapperProcess.WaitForExit(15000)) { $wrapperProcess.Kill(); throw 'CMD diagnostic wrapper timed out' }
    Assert-True ($wrapperProcess.ExitCode -eq 1) 'CMD wrapper preserves the failed setup exit code after pause'
    Assert-True ($wrapperOutput.GetAwaiter().GetResult() -match 'readyToLaunch') 'CMD wrapper invokes diagnostics from a path containing spaces'
} finally { $wrapperProcess.Dispose() }

$launchChecks = & $module {
    param($Config,$FixtureRoot)
    # Keep module assertions local: CI invokes this test from a wrapper script.
    function Confirm-LaunchCheck([bool]$Condition, [string]$Name) {
        if (-not $Condition) { throw "FAIL: $Name" }
        $Name
    }
    $script:launchFixture = Join-Path $FixtureRoot 'successful-launch'
    $script:starts = 0
    $script:processDisposed = $false
    function Get-T5LocalDirectory { $script:launchFixture }
    function Get-T5HostPaths {
        [pscustomobject]@{
            Local=$script:launchFixture; HuggingFace=(Join-Path $script:launchFixture 'HuggingFace');
            Studio=(Join-Path $script:launchFixture 'Studio'); Temp=(Join-Path $script:launchFixture 'Temp');
            Documents=(Join-Path $script:launchFixture 'Documents'); Projects=(Join-Path $script:launchFixture 'Projects')
        }
    }
    function Test-T5Root { param($Root,$Config); $true }
    function Show-T5Message { param($Message,[switch]$Question); $true }
    function Get-T5RunningUnsloth { }
    function Assert-T5HostPrivacy { param($Config) }
    function Find-T5Unsloth { param($Root); 'C:\Apps\Unsloth\unsloth-studio.exe' }
    function Test-T5Executable { param($Path,$Root); $true }
    function Start-T5Process {
        param($StartInfo)
        $script:starts++
        $script:startedInfo = $StartInfo
        $fakeProcess = [pscustomobject]@{Id=999999}
        $fakeProcess | Add-Member -MemberType ScriptMethod -Name Dispose -Value { $script:processDisposed = $true }
        $fakeProcess
    }
    $testRoot = [IO.Path]::GetPathRoot([Environment]::GetFolderPath('Windows'))
    Invoke-T5Launch $testRoot $Config
    Confirm-LaunchCheck ($script:starts -eq 1 -and -not $script:startedInfo.UseShellExecute) 'Accepted launch reaches the process boundary once without shell execution'
    $record = Get-Content -LiteralPath (Join-Path $script:launchFixture 'last-launch.json') -Raw -Encoding UTF8 | ConvertFrom-Json
    Confirm-LaunchCheck ($record.modelCache -eq [IO.Path]::Combine($testRoot,$Config.modelRelativePath)) 'A successful launch records the selected cache path'
    Confirm-LaunchCheck $script:processDisposed 'Launch releases its process handle without stopping the application'
    function Write-T5Json { param($Path,$Value); throw 'Simulated locked launch record' }
    Invoke-T5Launch $testRoot $Config -WarningAction SilentlyContinue
    Confirm-LaunchCheck ($script:starts -eq 2) 'A launch-record failure does not report an already-started app as a launch failure'
    function Test-T5Executable { param($Path,$Root); $false }
    $invalidExecutableRejected = $false
    try { Invoke-T5Launch $testRoot $Config } catch { $invalidExecutableRejected = $true }
    Confirm-LaunchCheck $invalidExecutableRejected 'An executable that becomes invalid after consent is rejected'
    Confirm-LaunchCheck ($script:starts -eq 2) 'Invalid executable recheck never reaches process creation'
} $config $fixtureRoot
foreach ($name in $launchChecks) { Assert-True $true $name }
Write-Output "`n$script:passed checks passed on PowerShell $($PSVersionTable.PSVersion). No Unsloth process started and no helper installed."
