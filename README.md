# Portable Local AI Launcher

Keep a model library on an external SSD and open it with the Unsloth Desktop installed on the computer you're using.

**Windows prototype · Version 0.2.0 · No model weights included**

[Set up an SSD](docs/setup.md) · [Add or remove models](docs/models.md) · [Privacy](docs/privacy.md) · [Read the code](docs/code-walkthrough.md) · [Publish on GitHub](docs/github.md)

## Why I made this

My local AI setup was taking up a large part of an internal drive. I moved the model files to a Samsung T5, but copying the files was only half the job: the applications still needed to know where to look, and Windows could assign the SSD a different drive letter on another computer.

This project handles that connection. It pairs a drive with a small configuration file, asks before using it, and launches the local Unsloth installation with the correct model-cache path. The SSD holds the files. The computer still does the inference.

It's a Windows integration project, not a new model or inference engine. The T5 name remains in the launcher's filenames because that's the drive this started with; the pairing step is not tied to that brand.

## Current status

The original, device-specific prototype was used to check cache discovery on one Windows laptop. This repository is the generalized version, with its own helper directory and a new pairing step. Its automated checks pass locally; a full second-computer test is still pending. See [testing notes](docs/testing.md) for the distinction.

## Before you start

- Use Windows with Windows PowerShell 5.1 and Unsloth Desktop already installed and initialized locally.
- Use an existing NTFS or exFAT external volume with enough free space. Start with an empty model folder, or reuse a complete Hugging Face hub cache. Loose weight files aren't a Hub cache. Preserve snapshot files and their links when copying an existing collection. [Cache layout reference](https://huggingface.co/docs/huggingface_hub/guides/manage-cache).
- Your computer still needs enough RAM/VRAM and a supported runtime for the chosen model. Carrying a larger library does not make every model runnable.
- Back up important files. Don't use the same writable cache from several computers at once.

No model weights, Unsloth installer, accounts, or drivers are included.

## First use

1. Copy `T5-Launcher/` and all five root-level `.cmd` files from this repository to the **root of the external SSD**. Keep the folder name. Don't overwrite a launcher already there; see the note below.
2. Double-click `Configure-SSD.cmd`. Enter the cache folder relative to the drive, for example `AI\Models\huggingface\hub`. Check the drive and folder shown, then type `PAIR`.
3. Fully quit Unsloth, including any background inference session. Double-click `Start-Unsloth-With-T5.cmd` and accept the prompt. If the installation isn't found, choose the computer's `unsloth-studio.exe`.
4. For an existing cache, check **On Device**. For an empty cache, open **Model hub** and download a small supported model after verifying the active cache location is on the SSD. Only recognized, complete models can be used.

Pairing creates `T5-Launcher/device.json` and the cache folder if missing. Do not commit the pairing file. You pair the drive once; you don't need to repeat pairing when its drive letter changes. Run `Check-Setup.cmd` for a read-only diagnostic before your first launch.

**Already using the original T5 prototype?** Keep it in place. This source checkout is not an automatic upgrade package. The generic helper uses a different name, but the SSD filenames overlap. Test on a separate drive before planning an upgrade, and don't enable both watchers together.

## Want a popup when you plug it in?

Run `Install-T5-Connection-Popup.cmd` from the paired SSD once on each Windows account where you want this feature. The helper runs locally, starts at sign-in, and checks every five seconds. It asks before launching Unsloth. The drive connected during installation is skipped; use the manual launcher for that first session.

On a new computer without the helper, plugging in the SSD does **not** run anything automatically. Double-click the launcher instead. This is not USB AutoRun.

To disable popups, run `Remove-T5-Connection-Popup.cmd`. It removes only this helper's verified Startup shortcut and tells the watcher to stop. It retains the helper files and logs. You can also find the removal command in `%LOCALAPPDATA%\PortableLocalAI`.

Before unplugging, stop generation, unload models, quit Unsloth and its backend, then use Windows' eject option. A loaded model may still read from disk later.

## What the launcher changes

It sets the Hub cache path in the **new Unsloth process**, not in Windows' global environment. This version uses `%LOCALAPPDATA%\PortableLocalAI\HuggingFace` for Hugging Face credentials, clears inherited raw Hub token variables in the child, and keeps temporary files, auxiliary caches and launcher-session project defaults on the host. You may need to sign in again for gated models. Explicit offline settings remain unchanged.

Known application-state paths must remain inside the current Windows profile without junctions or symbolic links. If these checks fail, the launcher stops. Existing local Unsloth chats remain local; they are not erased. This is not an incognito session.

It doesn't copy models or chats, stop applications, format drives, or configure ComfyUI. Unsloth itself can still download or modify files during normal operation. This is a storage selector, not a network blocker or a read-only sandbox.

The [design notes](docs/design.md) explain the paths and backend. The [demo guide](docs/demo.md) is a short walkthrough for a classroom or interview.

## Sharing the drive between people

| Shared on the SSD | Kept on each prepared host |
| --- | --- |
| Model repositories, weights and cache metadata | Unsloth's local chat/authentication state |
| Added models and the effect of model deletions | Hugging Face credentials for launcher sessions |
| Model filenames and filesystem timestamps | Launcher logs, temporary files and project defaults |

Anyone with access to this unencrypted SSD can inspect its files. Don't put private fine-tunes, chat exports, datasets, tokens or backups there. The launcher doesn't scrub an old drive, prevent an explicit export to it, or protect you from an untrusted PC. See the [privacy boundary](docs/privacy.md).

## Running the checks

From the repository root:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\tests\Test-Launcher.ps1
```

The tests do not start Unsloth, install a helper, or modify a model drive. The execution-policy flag applies only to that process; it is not a reason to bypass your institution's device policy. A Windows GitHub Actions workflow is included but has not run remotely yet.

## Limits worth knowing

This version supports one paired drive per account's popup helper. It does not convert loose GGUF files into Hub cache entries, install missing dependencies, or guarantee discovery in every Unsloth release. The inspected prototype used Unsloth Desktop `0.1.806-beta`; later versions need retesting.

Windows is the only target of these scripts. macOS, Linux, network/redirected profiles and nonstandard runtime layouts are not covered by a universal compatibility promise. Model download/delete support is provided by the installed Unsloth version, not a private API client in this launcher.

There are no performance benchmarks yet. An external SSD makes the files portable, not the GPU, RAM, drivers, or application installation.

## Credits and release notes

Project by Garv Gupta, developed with AI assistance. Unsloth and Hugging Face provide the application and model infrastructure; this repository contains the launcher integration, not their source code or model weights.

A code license has not been selected yet. Before publishing a reusable release, complete the [release checklist](docs/release-checklist.md), including the license decision and a real second-PC test.
