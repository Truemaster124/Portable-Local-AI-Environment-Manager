# Set up another SSD

This guide starts with a prepared Windows computer and an external drive. It does not format anything or migrate an existing application installation.

## 1. Prepare the computer

Install and open Unsloth Desktop normally. Complete its runtime setup and check that the application opens. Then quit it fully. You need Windows PowerShell 5.1, permission to run these scripts, and hardware that supports your chosen model.

The default supported Studio location is `%USERPROFILE%\.unsloth\studio`. An explicit `UNSLOTH_STUDIO_HOME` or `STUDIO_HOME` is accepted only if the privacy checks pass; this version requires it to be within the local Windows profile. Other layouts need review rather than a guess about where the app stores its database.

## 2. Copy the launcher, not your personal profile

From the source folder, copy these items to the root of the external drive:

- `T5-Launcher/`
- `Configure-SSD.cmd`
- `Check-Setup.cmd`
- `Start-Unsloth-With-T5.cmd`
- `Install-T5-Connection-Popup.cmd`
- `Remove-T5-Connection-Popup.cmd`

Don't copy `.unsloth`, AppData, credentials, chat databases or this repository's `.git` folder. Do not overwrite an existing T5 launcher. Use a spare drive for testing a new version.

The drive must already be NTFS or exFAT. NTFS is the original test filesystem; exFAT handling still needs a real-device test. Filesystem conversion or formatting is deliberately outside this tool. Leave enough space for the intended model plus download overhead.

## 3. Pair it

Double-click `Configure-SSD.cmd`. The default cache path is:

```text
AI\Models\huggingface\hub
```

That is relative to the SSD, not an absolute `E:` path. Press Enter to use it, or enter another relative path. Check the displayed drive label and folder, then type `PAIR` exactly.

For a new collection, setup creates the missing directory. For an existing collection, select a Hub cache containing `models--...` repository folders with `snapshots` directories. Setup only checks the basic layout; it does not certify that every download is complete. A nonempty unrelated folder is refused.

It also creates a new `device.json` marker. Pair once per drive. A changed drive letter doesn't require pairing again, but reformatting the drive changes its identity. Setup refuses to replace an existing marker.

## 4. Check and launch

Run `Check-Setup.cmd`. It reports whether the paired root is valid, any detected Unsloth installation, running sessions and the host privacy preflight. This command is read-only, but its output contains local paths; redact them before sharing it.

The report includes `readyToLaunch` and a `problems` list. The command exits with code `1` when a check fails, including a missing pairing file; code `0` means its readiness checks passed. If Unsloth is not found automatically, you can still select its installed executable during launch. A passing report does not test whether a model can load.

Next, double-click `Start-Unsloth-With-T5.cmd` and accept the prompt. If a file picker appears, select the **host-installed** `unsloth-studio.exe`, not an old app copy on the SSD. No administrator account is required by the launcher.

If a known private-state directory is redirected through a junction or outside the host profile, stop and review the layout. Do not delete links or move databases just to silence the warning.

## 5. Get your first model

Open Unsloth's cache/storage settings and confirm its active Hub cache is the SSD folder selected above. In the inspected version, an environment-controlled cache may be shown as non-editable; that is expected for a launcher session.

For an empty library, follow [adding a model](models.md). For an existing library, check **On Device** and try one small model. You may need to provide your own Hugging Face credentials on this host for gated downloads because the launcher does not import credentials from the SSD.

## 6. Enable insertion prompts, optionally

Run `Install-T5-Connection-Popup.cmd` from the paired drive. Accept the installation prompt. This installs a helper for this Windows account only. The drive already connected during installation is skipped; launch it manually this time.

At the next insertion, the helper should prompt within a few seconds. Decline means no launch. Another computer needs its own one-time helper installation, or you can simply use the manual launcher there.

To disable it, run `Remove-T5-Connection-Popup.cmd`. Source files and logs remain locally; the paired SSD and its models are not removed. This version deliberately refuses in-place upgrades when helper files differ.

If you have an older helper, keep that working installation until you have tested the new version separately. Do not run both watchers together or overwrite the retained helper files to force an upgrade.

## 7. Finish a session

Stop downloads and generation, unload models, quit Unsloth and its background backend, and use Windows' eject action. Give the next user only the model drive, not a copy of your computer's application data.

Before lending an old SSD, inspect it for backups, exports, datasets and credentials. Pairing is not a privacy cleanup or secure erase.
