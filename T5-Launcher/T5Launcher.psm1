# Custom T5 integration, not Unsloth source code. Compatible with Windows PowerShell 5.1.
Set-StrictMode -Version Latest

function Get-T5Version { '0.2.1-rc.3' }

function Get-T5MutexName {
    param([ValidateSet('Prompt','Watch')][string]$Purpose)
    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    try { 'Local\PortableLocalAI-' + $Purpose + '-' + $identity.User.Value }
    finally { $identity.Dispose() }
}

function Test-T5ReservedName {
    param([string]$Path)
    $Path -match '(?i)(^|\\)(CON|PRN|AUX|NUL|CLOCK\$|CONIN\$|CONOUT\$|COM[1-9\u00B9\u00B2\u00B3]|LPT[1-9\u00B9\u00B2\u00B3])(?:\.|\\|$)'
}

function Get-T5LocalDirectory {
    # Separate from the original, device-specific prototype.
    Join-Path ([Environment]::GetFolderPath('LocalApplicationData')) 'PortableLocalAI'
}

function Invoke-T5ShortcutLaunch {
    param($Config)
    $roots = @(Find-T5Roots $Config)
    if ($roots.Count -eq 0) { throw 'Connect your paired SSD, then open Portable Local AI again.' }
    if ($roots.Count -ne 1) { throw 'More than one drive matches this pairing. Connect only the intended SSD and try again.' }
    # Use the same consent, running-app and privacy checks as the SSD command.
    Invoke-T5Launch $roots[0] $Config
}

function Get-T5DesktopShortcutPaths {
    $local = Join-Path ([Environment]::GetFolderPath('LocalApplicationData')) 'PortableLocalAI-Launcher'
    $desktop = [Environment]::GetFolderPath('DesktopDirectory')
    $profileRoot = (Get-T5HostPaths).Profile.TrimEnd('\') + '\'
    foreach ($path in @($local,$desktop)) {
        Assert-T5PlainPath $path
        if (-not ([IO.Path]::GetFullPath($path)).StartsWith($profileRoot,[StringComparison]::OrdinalIgnoreCase)) {
            throw 'The desktop shortcut needs a Desktop and AppData within this local Windows profile.'
        }
    }
    [pscustomobject]@{Local=$local; Link=(Join-Path $desktop 'Portable Local AI.lnk')}
}

function Install-T5DesktopShortcut {
    param([string]$SourceDirectory, $Config)
    $sourceRoot = [IO.Path]::GetFullPath((Join-Path $SourceDirectory '..'))
    if (-not (Test-T5Root $sourceRoot $Config)) { throw 'Run Create-Desktop-Shortcut.cmd from the root of the paired SSD.' }
    Assert-T5HostPrivacy $Config
    $paths = Get-T5DesktopShortcutPaths
    $names = @('T5Launcher.ps1','T5Launcher.psm1','device.json','portable-ai.ico')
    Assert-T5PlainPath $paths.Local
    Assert-T5PlainPath $paths.Link
    if (Test-Path -LiteralPath $paths.Local) {
        if (-not (Test-Path -LiteralPath $paths.Local -PathType Container)) { throw 'The shortcut installation path is occupied by a file.' }
        if (@(Get-ChildItem -LiteralPath $paths.Local -Force | Where-Object { $_.Name -notin $names }).Count) {
            throw 'The shortcut folder contains unrecognized files. Nothing was overwritten.'
        }
    }
    # Read and validate every file before changing anything. A different local
    # version is retained; upgrading it should be a deliberate action.
    $copies = @{}
    $sha = [Security.Cryptography.SHA256]::Create()
    try {
        foreach ($name in $names) {
            $source = Join-Path $SourceDirectory $name
            $destination = Join-Path $paths.Local $name
            Assert-T5PlainPath $source
            Assert-T5PlainPath $destination
            $bytes = [IO.File]::ReadAllBytes($source)
            if (Test-Path -LiteralPath $destination) {
                $expectedHash = [BitConverter]::ToString($sha.ComputeHash($bytes)).Replace('-','')
                if (-not (Test-Path -LiteralPath $destination -PathType Leaf) -or
                    (Get-FileHash -LiteralPath $destination -Algorithm SHA256).Hash -ne $expectedHash) {
                    throw 'An existing desktop launcher has different files or another pairing. Nothing was overwritten. See docs/setup.md for replacement steps.'
                }
            }
            $copies[$name] = $bytes
        }
    } finally { $sha.Dispose() }
    $powershell = Join-Path $env:SystemRoot 'System32\WindowsPowerShell\v1.0\powershell.exe'
    $arguments = '-NoProfile -STA -WindowStyle Hidden -ExecutionPolicy Bypass -File "' + (Join-Path $paths.Local 'T5Launcher.ps1') + '" -Mode Shortcut'
    $shell = New-Object -ComObject WScript.Shell
    $link = $null
    try {
        $link = $shell.CreateShortcut($paths.Link)
        if ((Test-Path -LiteralPath $paths.Link) -and ($link.TargetPath -ine $powershell -or $link.Arguments -cne $arguments)) {
            throw 'An unrelated Desktop shortcut has the same name. Nothing was overwritten.'
        }
        if (-not (Test-T5Root $sourceRoot $Config)) { throw 'The paired SSD changed or was disconnected. The shortcut was not installed.' }
        Assert-T5HostPrivacy $Config
        [void][IO.Directory]::CreateDirectory($paths.Local)
        foreach ($name in $names) {
            $destination = Join-Path $paths.Local $name
            if (-not (Test-Path -LiteralPath $destination)) {
                $stream = [IO.File]::Open($destination,[IO.FileMode]::CreateNew,[IO.FileAccess]::Write,[IO.FileShare]::None)
                try { $stream.Write($copies[$name],0,$copies[$name].Length) }
                finally { $stream.Dispose() }
            }
        }
        $link.TargetPath = $powershell
        $link.Arguments = $arguments
        $link.WorkingDirectory = $paths.Local
        $link.IconLocation = (Join-Path $paths.Local 'portable-ai.ico') + ',0'
        $link.WindowStyle = 7
        $link.Description = 'Open Unsloth with models on your paired SSD. Asks before launching.'
        $link.Save()
    } finally {
        if ($link) { [void][Runtime.InteropServices.Marshal]::FinalReleaseComObject($link) }
        [void][Runtime.InteropServices.Marshal]::FinalReleaseComObject($shell)
    }
    $paths.Link
}

function Get-T5HostPaths {
    $userProfilePath = [Environment]::GetFolderPath('UserProfile')
    if ([string]::IsNullOrWhiteSpace($userProfilePath)) { $userProfilePath = $env:USERPROFILE }
    if ([string]::IsNullOrWhiteSpace($userProfilePath)) { throw 'Cannot determine this Windows user profile.' }
    $local = Get-T5LocalDirectory
    $studio = [IO.Path]::Combine($userProfilePath, '.unsloth\studio')
    foreach ($key in @('UNSLOTH_STUDIO_HOME','STUDIO_HOME')) {
        $override = [Environment]::GetEnvironmentVariable($key, 'Process')
        if (-not [string]::IsNullOrWhiteSpace($override)) { $studio = $override; break }
    }
    [pscustomobject]@{
        Profile=$userProfilePath; Local=$local; Studio=$studio
        Roaming=[Environment]::GetFolderPath('ApplicationData')
        HuggingFace=[IO.Path]::Combine($local, 'HuggingFace')
        Temp=[IO.Path]::Combine($local, 'Temp')
        Documents=[IO.Path]::Combine($local, 'Documents')
        Projects=[IO.Path]::Combine($local, 'Projects')
    }
}

function Assert-T5PlainPath {
    param([string]$Path)
    if ($Path -notmatch '^[A-Za-z]:\\' -or $Path.Substring(2) -match '[:*?"<>|/\x00-\x1F]') {
        throw 'Expected an absolute local Windows path.'
    }
    if ($Path -match '(^|\\)\.{1,2}(\\|$)') { throw 'Path traversal is not allowed.' }
    if ((Test-T5ReservedName $Path.Substring(3)) -or $Path -match '[. ](\\|$)') {
        throw 'Reserved Windows names and trailing dots or spaces are not allowed.'
    }
    $cursor = [IO.Path]::GetFullPath($Path)
    while ($cursor) {
        try { $item = Get-Item -LiteralPath $cursor -Force -ErrorAction Stop }
        catch [System.Management.Automation.ItemNotFoundException] { $item = $null }
        if ($item -and ($item.Attributes -band [IO.FileAttributes]::ReparsePoint)) {
            throw "Redirected path rejected: $cursor. Use an ordinary local folder."
        }
        $parent = [IO.Path]::GetDirectoryName($cursor.TrimEnd('\'))
        if (-not $parent -or $parent -eq $cursor) { break }
        $cursor = $parent
    }
}

function Assert-T5HostPrivacy {
    param($Config)
    $paths = Get-T5HostPaths
    $profileRoot = $paths.Profile.TrimEnd('\') + '\'
    $profileVolume = [IO.Path]::GetPathRoot($paths.Profile)
    if (([IO.DriveInfo]::new($profileVolume)).DriveType -ne [IO.DriveType]::Fixed -or
        (Get-T5VolumeSerial $profileVolume) -eq $Config.volumeSerial) {
        throw 'The Windows profile must be on a local host volume, not the model SSD.'
    }
    foreach ($path in @($paths.Profile,$paths.Local,$paths.Roaming,$paths.Studio,$paths.HuggingFace,$paths.Temp,$paths.Documents,$paths.Projects)) {
        Assert-T5PlainPath $path
        $full = [IO.Path]::GetFullPath($path)
        if ($full -ine $paths.Profile -and -not $full.StartsWith($profileRoot,[StringComparison]::OrdinalIgnoreCase)) {
            throw 'Private state must stay within this Windows user profile. Redirected or custom profiles need review.'
        }
    }
    # Check known state destinations as well as their parents; never open their contents.
    foreach ($relative in @('studio.db','studio.db-wal','studio.db-shm','auth\auth.db','auth\auth.db-wal','auth\auth.db-shm',
        'rag\rag.db','cache','outputs','exports','assets','runs')) {
        Assert-T5PlainPath ([IO.Path]::Combine($paths.Studio,$relative))
    }
    foreach ($relative in @('token','stored_tokens')) { Assert-T5PlainPath ([IO.Path]::Combine($paths.HuggingFace,$relative)) }
    foreach ($relative in @('app-location.json','last-launch.json','helper.log','watcher-status.json','installed.json',
        'T5Launcher.ps1','T5Launcher.psm1','device.json','Remove-T5-Connection-Popup.cmd',
        'Cache','Cache\xet','Cache\assets','Cache\datasets','Cache\modules')) {
        Assert-T5PlainPath ([IO.Path]::Combine($paths.Local,$relative))
    }
    if (-not (Test-Path -LiteralPath $paths.Studio -PathType Container)) {
        throw 'The local Unsloth Studio folder is missing. Initialize Unsloth normally first. Nonstandard runtime layouts need review.'
    }
}

function Assert-T5DeviceConfig {
    param($Config)
    if ($Config -isnot [pscustomobject]) { throw 'device.json must contain one JSON object.' }
    foreach ($field in @('schemaVersion','deviceId','volumeSerial','displayName','modelRelativePath')) {
        if (-not $Config -or -not $Config.PSObject.Properties[$field]) { throw "Missing configuration field: $field" }
    }
    $id = [guid]::Empty
    if (($Config.schemaVersion -isnot [int] -and $Config.schemaVersion -isnot [long]) -or $Config.schemaVersion -ne 1 -or
        $Config.deviceId -isnot [string] -or $Config.volumeSerial -isnot [string] -or
        -not [guid]::TryParse([string]$Config.deviceId, [ref]$id) -or $id -eq [guid]::Empty -or
        [string]$Config.deviceId -notmatch '^[0-9a-fA-F]{8}(-[0-9a-fA-F]{4}){3}-[0-9a-fA-F]{12}$' -or
        [string]$Config.volumeSerial -notmatch '^[0-9A-Fa-f]{8}$') { throw 'Invalid device identity in device.json.' }
    if ($Config.displayName -isnot [string] -or [string]::IsNullOrWhiteSpace($Config.displayName) -or $Config.displayName.Length -gt 80 -or
        $Config.displayName -match '[\x00-\x1F]') { throw 'Use a short, single-line display name.' }
    $path = $Config.modelRelativePath
    if ($path -isnot [string] -or [string]::IsNullOrWhiteSpace($path) -or [IO.Path]::IsPathRooted($path) -or
        $path -match '[:*?"<>|\x00-\x1F]' -or $path -match '/' -or $path -match '(^|\\)\.{1,2}(\\|$)' -or
        $path -match '(^\\|\\$|\\\\)' -or (Test-T5ReservedName $path) -or
        @($path.Split('\') | Where-Object { $_ -match '[. ]$' }).Count -gt 0) {
        throw 'modelRelativePath must be a normal relative folder path, without traversal or wildcards.'
    }
}

function Get-T5DeviceConfig {
    param([string]$Directory)
    $path = Join-Path $Directory 'device.json'
    Assert-T5PlainPath $path
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
        throw 'This drive is not paired. Run Configure-SSD.cmd from the SSD root first.'
    }
    if ((Get-Item -LiteralPath $path -ErrorAction Stop).Length -gt 16384) { throw 'device.json is too large; expected a small pairing file.' }
    $json = Get-Content -LiteralPath $path -Raw -Encoding UTF8 -ErrorAction Stop
    if ([string]::IsNullOrWhiteSpace($json) -or -not $json.TrimStart().StartsWith('{')) {
        throw 'device.json must contain one JSON object.'
    }
    $config = $json | ConvertFrom-Json -ErrorAction Stop
    Assert-T5DeviceConfig $config
    $config
}

function Get-T5CachePlan {
    param([string]$Root, $Config)
    Assert-T5DeviceConfig $Config
    $hub = [IO.Path]::Combine($Root,$Config.modelRelativePath)
    Assert-T5PlainPath $hub
    $exists = Test-Path -LiteralPath $hub
    if ($exists -and -not (Test-Path -LiteralPath $hub -PathType Container)) { throw 'The cache path is a file, not a directory.' }
    $repositories = @()
    if ($exists) {
        $repositories = @(Get-ChildItem -LiteralPath $hub -Directory -Filter 'models--*' | Where-Object {
            Test-Path -LiteralPath (Join-Path $_.FullName 'snapshots') -PathType Container
        })
        if (@(Get-ChildItem -LiteralPath $hub -Force).Count -gt 0 -and $repositories.Count -eq 0) {
            throw 'The selected folder is not empty and does not look like a Hugging Face cache. Pick a new empty folder; loose GGUF files are not a hub cache.'
        }
    }
    [pscustomobject]@{CachePath=$hub; Exists=$exists; RepositoryCount=$repositories.Count}
}

function Get-T5VolumeSerial {
    param([string]$Root)
    if (-not ('T5Launcher.NativeVolume' -as [type])) {
        Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
namespace T5Launcher {
 public static class NativeVolume {
  [DllImport("kernel32.dll", CharSet=CharSet.Unicode, SetLastError=true)]
  public static extern bool GetVolumeInformation(string root, IntPtr name, uint nameSize,
   out uint serial, out uint maxComponent, out uint flags, IntPtr filesystem, uint filesystemSize);
  [DllImport("kernel32.dll", CharSet=CharSet.Unicode, SetLastError=true)]
  public static extern bool GetVolumePathName(string path, System.Text.StringBuilder volumePath, uint size);
 }
}
'@
    }
    [uint32]$serial = 0
    [uint32]$maxComponent = 0
    [uint32]$flags = 0
    $ok = [T5Launcher.NativeVolume]::GetVolumeInformation($Root, [IntPtr]::Zero, 0,
        [ref]$serial, [ref]$maxComponent, [ref]$flags, [IntPtr]::Zero, 0)
    if (-not $ok) { throw "Cannot read the filesystem identity at $Root" }
    $serial.ToString('X8')
}

function Get-T5ContainingVolumeSerial {
    param([string]$Path)
    # Initializes the interop type, then asks Windows for the actual containing mount.
    $null = Get-T5VolumeSerial ([IO.Path]::GetPathRoot($Path))
    $buffer = [Text.StringBuilder]::new(32768)
    if (-not [T5Launcher.NativeVolume]::GetVolumePathName($Path, $buffer, 32768)) {
        throw 'Cannot resolve the executable volume. Select a local installation.'
    }
    Get-T5VolumeSerial $buffer.ToString()
}

function Test-T5Root {
    param([string]$Root, $Config)
    try {
        if ($Root -notmatch '^[A-Za-z]:\\$') { return $false }
        $marker = Join-Path $Root 'T5-Launcher\device.json'
        if (-not (Test-Path -LiteralPath $marker -PathType Leaf)) { return $false }
        $observed = Get-T5DeviceConfig (Join-Path $Root 'T5-Launcher')
        Assert-T5DeviceConfig $Config
        foreach ($field in @('deviceId','volumeSerial','modelRelativePath')) {
            if ($observed.$field -ne $Config.$field) { return $false }
        }
        if ((Get-T5VolumeSerial $Root) -ne $Config.volumeSerial) { return $false }
        Assert-T5PlainPath (Join-Path $Root $Config.modelRelativePath)
        return (Test-Path -LiteralPath (Join-Path $Root $Config.modelRelativePath) -PathType Container)
    } catch { return $false }
}

function Find-T5Roots {
    param($Config)
    foreach ($driveRoot in [Environment]::GetLogicalDrives()) {
        if (Test-T5Root $driveRoot $Config) { $driveRoot }
    }
}

function Test-T5Executable {
    param([string]$Path, [string]$Root)
    try {
        if ($Path -notmatch '^[A-Za-z]:\\') { return $false }
        $full = [IO.Path]::GetFullPath($Path)
        if ([IO.Path]::GetFileName($full) -ine 'unsloth-studio.exe') { return $false }
        if (([IO.DriveInfo]::new([IO.Path]::GetPathRoot($full))).DriveType -ne [IO.DriveType]::Fixed) { return $false }
        Assert-T5PlainPath $Path
        if (-not (Test-Path -LiteralPath $full -PathType Leaf)) { return $false }
        # Do not run the legacy application copy from this SSD, even through its C: mount.
        if ($Root -and $full.StartsWith($Root.TrimEnd('\') + '\', [StringComparison]::OrdinalIgnoreCase)) { return $false }
        # The serial comes from the selected volume, not a developer's drive.
        $storageSerial = Get-T5VolumeSerial $Root
        if ((Get-T5ContainingVolumeSerial $full) -eq $storageSerial) { return $false }
        return $true
    } catch { return $false }
}

function Get-T5ExeFromText {
    param([string]$Text)
    if ($Text -match '^\s*"([^"\r\n]+\.exe)"') { return $Matches[1] }
    if ($Text -match '^\s*([^"\r\n]+?\.exe)(?:,\s*-?\d+)?\s*$') { return $Matches[1].Trim() }
}

function Find-T5Unsloth {
    param([string]$Root)
    $candidates = [Collections.Generic.List[string]]::new()
    $saved = Join-Path (Get-T5LocalDirectory) 'app-location.json'
    if (Test-Path -LiteralPath $saved) {
        try {
            $path = (Get-Content -LiteralPath $saved -Raw -Encoding UTF8 | ConvertFrom-Json).executable
            if (Test-T5Executable $path $Root) { return $path }
        } catch {}
    }
    $registryRoots = @(
        'HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall',
        'HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall',
        'HKLM:\Software\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall'
    )
    foreach ($registryRoot in $registryRoots) {
        foreach ($key in @(Get-ChildItem -LiteralPath $registryRoot -ErrorAction SilentlyContinue)) {
            $values = Get-ItemProperty -LiteralPath $key.PSPath -ErrorAction SilentlyContinue
            if (-not $values -or -not $values.PSObject.Properties['DisplayName'] -or $values.DisplayName -notmatch '^Unsloth(?:\s|$)') { continue }
            if ($values.PSObject.Properties['InstallLocation'] -and $values.InstallLocation) {
                try { $candidates.Add((Join-Path ($values.InstallLocation.Trim('"')) 'unsloth-studio.exe')) } catch {}
            }
            if ($values.PSObject.Properties['DisplayIcon']) {
                $path = Get-T5ExeFromText $values.DisplayIcon
                if ($path) { $candidates.Add($path) }
            }
        }
    }
    foreach ($path in @(
        (Join-Path $env:LOCALAPPDATA 'Programs\Unsloth\unsloth-studio.exe'),
        (Join-Path $env:LOCALAPPDATA 'Unsloth\unsloth-studio.exe'),
        (Join-Path $env:ProgramFiles 'Unsloth\unsloth-studio.exe')
    )) { $candidates.Add($path) }
    @($candidates | Where-Object { Test-T5Executable $_ $Root } | Select-Object -Unique)
}

function Get-T5RunningUnsloth {
    # Fail closed if process inspection is unavailable; never kill user applications.
    $processes = Get-CimInstance Win32_Process -Filter "Name='unsloth-studio.exe' OR Name='python.exe' OR Name='pythonw.exe' OR Name='llama-server.exe'" -ErrorAction Stop
    foreach ($process in $processes) {
        if ($process.Name -eq 'unsloth-studio.exe' -or
            ($process.ExecutablePath -and $process.ExecutablePath -match '\\\.unsloth\\') -or
            ($process.CommandLine -and $process.CommandLine -match '(?i)studio[\\/]backend|studio\.backend')) {
            [pscustomobject]@{Name=$process.Name; ProcessId=$process.ProcessId}
        }
    }
}

function New-T5StartInfo {
    param([string]$Executable, [string]$Root, $Config)
    Assert-T5DeviceConfig $Config
    $info = [Diagnostics.ProcessStartInfo]::new()
    $info.FileName = $Executable
    $info.WorkingDirectory = [IO.Path]::GetDirectoryName($Executable)
    $info.UseShellExecute = $false
    $hub = [IO.Path]::Combine($Root, $Config.modelRelativePath)
    $info.EnvironmentVariables['HF_HUB_CACHE'] = $hub
    $info.EnvironmentVariables['HUGGINGFACE_HUB_CACHE'] = $hub
    $info.EnvironmentVariables['TRANSFORMERS_CACHE'] = $hub
    $info.EnvironmentVariables['AI_EXTERNAL_ROOT'] = $Root.TrimEnd('\')
    $paths = Get-T5HostPaths
    $info.EnvironmentVariables['HF_HOME'] = $paths.HuggingFace
    $info.EnvironmentVariables['HF_TOKEN_PATH'] = [IO.Path]::Combine($paths.HuggingFace,'token')
    $info.EnvironmentVariables.Remove('HF_TOKEN')
    $info.EnvironmentVariables.Remove('HUGGING_FACE_HUB_TOKEN')
    $info.EnvironmentVariables['HF_XET_CACHE'] = [IO.Path]::Combine($paths.Local,'Cache\xet')
    $info.EnvironmentVariables['HF_ASSETS_CACHE'] = [IO.Path]::Combine($paths.Local,'Cache\assets')
    $info.EnvironmentVariables['HF_DATASETS_CACHE'] = [IO.Path]::Combine($paths.Local,'Cache\datasets')
    $info.EnvironmentVariables['HF_MODULES_CACHE'] = [IO.Path]::Combine($paths.Local,'Cache\modules')
    $info.EnvironmentVariables['XDG_CACHE_HOME'] = [IO.Path]::Combine($paths.Local,'Cache')
    $info.EnvironmentVariables['UNSLOTH_STUDIO_HOME'] = $paths.Studio
    $info.EnvironmentVariables['STUDIO_HOME'] = $paths.Studio
    $info.EnvironmentVariables['UNSLOTH_STUDIO_DOCUMENTS_HOME'] = $paths.Documents
    $info.EnvironmentVariables['UNSLOTH_STUDIO_PROJECTS_HOME'] = $paths.Projects
    $info.EnvironmentVariables['TEMP'] = $paths.Temp
    $info.EnvironmentVariables['TMP'] = $paths.Temp
    $info.EnvironmentVariables['TMPDIR'] = $paths.Temp
    # Keep explicit offline settings. Selecting storage should not change network policy.
    # Use host-only credential storage; never copy tokens from the model drive.
    # This is routing, not a sandbox. The user can still explicitly export to the SSD.
    $info
}

function Show-T5Message {
    param([string]$Message, [switch]$Question)
    Add-Type -AssemblyName System.Windows.Forms
    if ($Question) {
        return ([Windows.Forms.MessageBox]::Show($Message, 'Portable Local AI - Unsloth',
            [Windows.Forms.MessageBoxButtons]::YesNo, [Windows.Forms.MessageBoxIcon]::Question,
            [Windows.Forms.MessageBoxDefaultButton]::Button2) -eq [Windows.Forms.DialogResult]::Yes)
    }
    [void][Windows.Forms.MessageBox]::Show($Message, 'Portable Local AI - Unsloth',
        [Windows.Forms.MessageBoxButtons]::OK, [Windows.Forms.MessageBoxIcon]::Information)
}

function Start-T5Process {
    param([Diagnostics.ProcessStartInfo]$StartInfo)
    [Diagnostics.Process]::Start($StartInfo)
}

function Invoke-T5Launch {
    [CmdletBinding()]
    param([string]$Root, $Config, [switch]$FromWatcher)
    $guard = [Threading.Mutex]::new($false, (Get-T5MutexName 'Prompt'))
    $owned = $false
    try {
        try { $owned = $guard.WaitOne(0) } catch [Threading.AbandonedMutexException] { $owned = $true }
        if (-not $owned) { return }
        if ($FromWatcher -and -not (Test-T5HelperEnabled $Config)) { return }
        if (-not (Test-T5Root $Root $Config)) { throw 'The paired SSD model library is unavailable. No application was started.' }
        $accepted = Show-T5Message -Question -Message ("Allow Unsloth to access the models on " + $Config.displayName + "?`r`n`r`nModel folder: " + (Join-Path $Root $Config.modelRelativePath) + "`r`n`r`nYes launches this PC's installed Unsloth with that cache for this session. Recognized models should appear under On Device. No model files or chats are copied. Unsloth may access the network and write to its selected cache during normal use, subject to your existing offline settings. Keep the SSD connected while using it.")
        if (-not $accepted) { return }
        if ($FromWatcher -and -not (Test-T5HelperEnabled $Config)) { return }
        $running = @(Get-T5RunningUnsloth)
        if ($running.Count -gt 0) {
            Show-T5Message "Unsloth or one of its inference processes is already running. Save your work and fully quit Unsloth, including its background backend, then double-click Start-Unsloth-With-T5.cmd again. Nothing was stopped or changed."
            return
        }
        Assert-T5HostPrivacy $Config
        $candidates = @(Find-T5Unsloth $Root)
        if ($candidates.Count -eq 1) { $executable = $candidates[0] }
        else {
            Add-Type -AssemblyName System.Windows.Forms
            $picker = [Windows.Forms.OpenFileDialog]::new()
            try {
                $picker.Title = 'Select the Unsloth installed on this PC (not the SSD copy)'
                $picker.Filter = 'Unsloth Desktop (unsloth-studio.exe)|unsloth-studio.exe'
                if ($picker.ShowDialog() -ne [Windows.Forms.DialogResult]::OK) { return }
                $executable = $picker.FileName
                if (-not (Test-T5Executable $executable $Root)) { throw 'Select a local installed unsloth-studio.exe, not an application copy on the SSD.' }
                $local = Get-T5LocalDirectory
                [void][IO.Directory]::CreateDirectory($local)
                Write-T5Json (Join-Path $local 'app-location.json') @{executable=$executable}
            } finally { $picker.Dispose() }
        }
        # Recheck after any dialog: the drive can be unplugged while a prompt is open.
        if (-not (Test-T5Root $Root $Config)) { throw 'The paired SSD was disconnected. Nothing was launched.' }
        if (@(Get-T5RunningUnsloth).Count -gt 0) { throw 'Unsloth started while the dialog was open. Close it and retry.' }
        if ($FromWatcher -and -not (Test-T5HelperEnabled $Config)) { return }
        if (-not (Test-T5Executable $executable $Root)) { throw 'The selected Unsloth executable is no longer a valid local installation.' }
        Assert-T5HostPrivacy $Config
        $info = New-T5StartInfo $executable $Root $Config
        foreach ($key in @('HF_HOME','HF_XET_CACHE','HF_ASSETS_CACHE','HF_DATASETS_CACHE','HF_MODULES_CACHE','TEMP','UNSLOTH_STUDIO_DOCUMENTS_HOME','UNSLOTH_STUDIO_PROJECTS_HOME')) {
            Assert-T5PlainPath $info.EnvironmentVariables[$key]
            [void][IO.Directory]::CreateDirectory($info.EnvironmentVariables[$key])
        }
        $launched = Start-T5Process $info
        try {
            Write-T5Json (Join-Path (Get-T5LocalDirectory) 'last-launch.json') @{
                time=(Get-Date).ToString('o'); executable=$executable; processId=$launched.Id; modelCache=$info.EnvironmentVariables['HF_HUB_CACHE']
            }
        } catch { Write-Warning 'Unsloth started, but its launch record could not be saved.' }
        finally { if ($launched) { $launched.Dispose() } }
    } finally {
        if ($owned) { $guard.ReleaseMutex() }
        $guard.Dispose()
    }
}

function Write-T5Log {
    [CmdletBinding()]
    param([string]$Message)
    try {
        $log = Join-Path (Get-T5LocalDirectory) 'helper.log'
        Assert-T5PlainPath $log
        # Logging must not terminate the watcher when the log is full or locked.
        if ((Test-Path -LiteralPath $log) -and (Get-Item -LiteralPath $log -ErrorAction Stop).Length -ge 262144) { return }
        ((Get-Date).ToString('o') + ' ' + $Message) | Add-Content -LiteralPath $log -Encoding UTF8 -ErrorAction Stop
    } catch { Write-Warning 'The helper could not write its diagnostic log.' }
}

function Write-T5Json {
    param([string]$Path, $Value)
    Assert-T5PlainPath $Path
    $parent = [IO.Path]::GetDirectoryName([IO.Path]::GetFullPath($Path))
    $temporary = Join-Path $parent ('.portable-ai-' + [guid]::NewGuid().ToString('N') + '.tmp')
    $created = $false
    try {
        $bytes = [Text.UTF8Encoding]::new($false).GetBytes(($Value | ConvertTo-Json -Depth 10) + "`r`n")
        $stream = [IO.File]::Open($temporary, [IO.FileMode]::CreateNew, [IO.FileAccess]::Write, [IO.FileShare]::None)
        $created = $true
        try { $stream.Write($bytes, 0, $bytes.Length); $stream.Flush($true) } finally { $stream.Dispose() }
        for ($attempt = 0; $attempt -lt 6; $attempt++) {
            Assert-T5PlainPath $Path
            try {
                if ([IO.File]::Exists($Path)) { [IO.File]::Replace($temporary, $Path, [NullString]::Value) }
                else { [IO.File]::Move($temporary, $Path) }
                break
            } catch {
                $failure = $_.Exception
                if ($failure.InnerException) { $failure = $failure.InnerException }
                $windowsError = $failure.HResult -band 0xFFFF
                # A watcher read or antivirus scan may briefly hold the destination.
                if ($attempt -eq 5 -or $windowsError -notin @(32,33,1175)) { throw }
                Start-Sleep -Milliseconds (25 * ($attempt + 1))
            }
        }
    } finally {
        # Only remove the unique sibling temporary file created by this call.
        if ($created -and [IO.File]::Exists($temporary)) { [IO.File]::Delete($temporary) }
    }
}

function Test-T5HelperEnabled {
    param($Config)
    try {
        $path = Join-Path (Get-T5LocalDirectory) 'installed.json'
        Assert-T5PlainPath $path
        $record = Get-Content -LiteralPath $path -Raw -Encoding UTF8 -ErrorAction Stop | ConvertFrom-Json -ErrorAction Stop
        return ($record.deviceId -is [string] -and $record.deviceId -eq $Config.deviceId -and
            $record.enabled -is [bool] -and $record.enabled)
    } catch { return $false }
}

function Get-T5SetupStatus {
    param([string]$Root, $Config)
    $problems = [Collections.Generic.List[string]]::new()
    $rootValid = Test-T5Root $Root $Config
    if (-not $rootValid) { $problems.Add('Run the launcher from the root of the connected, paired SSD.') }
    $privacy = 'passed'
    try { Assert-T5HostPrivacy $Config } catch { $privacy = $_.Exception.Message; $problems.Add($privacy) }
    $installed = @()
    $running = @()
    $connected = @()
    try { $connected = @(Find-T5Roots $Config) } catch { $problems.Add('Connected drives could not be inspected.') }
    try {
        $installed = @(Find-T5Unsloth $Root)
        if ($installed.Count -eq 0) { $problems.Add('Unsloth was not found automatically. Select the installed executable when launching.') }
    } catch { $problems.Add('The installed Unsloth location could not be checked.') }
    try {
        $running = @(Get-T5RunningUnsloth)
        if ($running.Count -gt 0) { $problems.Add('Fully quit Unsloth and its backend before launching with the SSD.') }
    } catch { $problems.Add('Running processes could not be inspected; launch is blocked.') }
    [pscustomobject]@{
        version=Get-T5Version; powershell=$PSVersionTable.PSVersion.ToString(); readyToLaunch=($problems.Count -eq 0);
        expectedDevice=$Config.deviceId; scriptRootValid=$rootValid; connectedRoots=$connected;
        installedUnsloth=$installed; runningUnsloth=$running; hostPrivacy=$privacy; problems=@($problems.ToArray()); hostPaths=Get-T5HostPaths
    }
}

Export-ModuleMember -Function *-T5*
