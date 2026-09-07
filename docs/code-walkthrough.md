# Read the code in five steps

The complete implementation is in this repository. These short excerpts explain the decisions; they are not separate scripts to paste over the working files.

## 1. Start beside the script, not at a fixed drive letter

`Start-Unsloth-With-T5.cmd` resolves its PowerShell script with `%~dp0`:

```bat
"%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe" -NoProfile -STA -ExecutionPolicy Bypass -File "%~dp0T5-Launcher\T5Launcher.ps1" -Mode Launch
```

`%~dp0` is the batch file's directory. If the SSD changes from `E:` to `F:`, this still finds its sibling `T5-Launcher` folder. It doesn't solve missing dependencies or missing models.

## 2. Pair a volume and plan the cache

Open `Configure-SSD.ps1`, then `Assert-T5DeviceConfig` and `Get-T5CachePlan` in the module.

Setup creates a new random marker ID, reads the filesystem serial, and stores a relative cache path. The plan permits a missing or empty folder, rejects an unrelated nonempty folder, and recognizes the basic Hub-cache layout. No files are written until the user types `PAIR`.

Marker creation uses exclusive creation rather than replacement:

```powershell
$stream = [IO.File]::Open($destination, [IO.FileMode]::CreateNew, [IO.FileAccess]::Write, [IO.FileShare]::None)
```

The drive serial is a mistake-prevention check, not a password or cryptographic proof of ownership.

## 3. Keep model location separate from private state

Open `Get-T5HostPaths`, `Assert-T5HostPrivacy` and `New-T5StartInfo`.

The model path is relative to the current SSD root, while the credential path comes from the host's local user directory:

```powershell
$hub = [IO.Path]::Combine($Root, $Config.modelRelativePath)
$info.EnvironmentVariables['HF_HUB_CACHE'] = $hub
$info.EnvironmentVariables['HF_HOME'] = $paths.HuggingFace
$info.EnvironmentVariables['HF_TOKEN_PATH'] = [IO.Path]::Combine($paths.HuggingFace,'token')
$info.EnvironmentVariables.Remove('HF_TOKEN')
$info.EnvironmentVariables.Remove('HUGGING_FACE_HUB_TOKEN')
```

These assignments affect the new process only. The privacy guard rejects known redirected state paths before launch. It does not erase chats, sandbox Unsloth, or inspect every file on the SSD.

## 4. Ask, validate, and launch once

Read `Invoke-T5Launch` from top to bottom. Follow the early returns for declined consent, an existing Unsloth session, a cancelled app picker, and a disconnected drive. Preflight failures throw before a new app process is started.

The actual launch uses the executable path directly:

```powershell
$info.UseShellExecute = $false
$launched = [Diagnostics.Process]::Start($info)
```

This avoids building a shell command from paths containing spaces or punctuation. It is not a guarantee that an executable is trustworthy; the user must choose their trusted local installation.

## 5. Let Unsloth own model operations

There is no model downloader or model-deletion API client hidden here. In the inspected application, downloads use the active Hub cache and deletion resolves which cache owns the selected copy. The launcher supplies the cache; the user works through Unsloth's own model controls.

The optional watcher reuses the same launch function after detecting the paired volume. That keeps manual and automatic-prompt behavior in one place.

## Where to start changing things

- Change path/environment behavior in the module and add a corresponding check in `tests/Test-Launcher.ps1`.
- Change setup behavior in `Get-T5CachePlan` and `Configure-SSD.ps1`; preserve the no-overwrite rule.
- Change user-facing instructions when behavior changes. A privacy promise should match the code and the tests.
- Test on a spare drive before replacing an installed helper. The current installer refuses silent in-place upgrades.
