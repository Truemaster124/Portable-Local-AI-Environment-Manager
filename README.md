<a name="top"></a>

<p align="center">
  <img src="docs/assets/samsung-t5.jpg" width="720" alt="A Samsung T5 portable external SSD">
</p>

<p align="center"><sub>Samsung T5 photo by <a href="https://www.flickr.com/people/87296837@N00">Tony Webster</a>, via <a href="https://commons.wikimedia.org/wiki/File:Samsung_T5_Portable_External_SSD_(Solid_State_Drive)_(43544308485).jpg">Wikimedia Commons</a>, <a href="https://creativecommons.org/licenses/by/2.0/">CC BY 2.0</a>. Image unchanged.</sub></p>

# Portable Local AI Environment Manager

A Windows launcher for keeping your Unsloth model library on an external SSD. It finds the paired drive, sets the model cache path for the local Unsloth app, and checks that known chat and credential locations stay on the PC.

The project started with a Samsung T5, but pairing is not tied to that brand. Each computer still needs its own working Unsloth installation, runtime, and enough RAM/VRAM for the models you want to run.

**Version 0.2.0 — Windows prototype.** The testing notes record 97 passing local automated checks. A complete test on a second prepared PC is still pending. See the [testing notes](docs/testing.md) for the evidence and remaining work.

[How it works](#why) · [Setup](#quick-start) · [Daily use](#daily-use) · [Questions](#questions) · [Project status](#status)

<a name="why"></a>

## Why this exists

Windows can assign an external drive a different letter when you reconnect it or move it to another PC. Your models might be on `F:` one day and `Z:` the next, leaving the application pointed at an old cache path.

After you pair the SSD, this launcher uses its pairing marker and filesystem volume serial to find its current location. It builds the cache path, asks for confirmation, and opens the local Unsloth installation with that path set for the new process. Windows' global environment variables are left unchanged.

This makes it easier to keep a large library off your internal drive or carry it between prepared PCs, one at a time. You can do the same configuration manually or maintain your own script; this project packages the drive checks and launch steps into a routine you can reuse.

Unsloth handles model discovery. The cache must contain complete model files supported by the installed Unsloth version. The launcher supplies the location; it does not make unsupported models compatible.

<a name="quick-start"></a>

## Setup

You will need:

- A Windows PC with Windows PowerShell 5.1, Unsloth Desktop installed and initialized, suitable hardware, and permission to run these scripts.
- An external SSD with an existing NTFS or exFAT volume and enough free space. The original prototype used NTFS; exFAT still needs a real-device test.
- An empty model folder or a complete Hugging Face Hub cache. Loose weight files are not a Hub cache. Preserve snapshot files and links when copying an existing cache; see [cache preparation](docs/setup.md).

Back up important files before setup. Model weights, the Unsloth installer, accounts, and drivers are not included.

### 1. Copy the launcher to the SSD

Download the repository using **Code → Download ZIP**, extract it, and copy `T5-Launcher/` and all five root-level `.cmd` files to the root of your SSD:

```text
Your SSD/
├── T5-Launcher/
├── Configure-SSD.cmd
├── Check-Setup.cmd
├── Start-Unsloth-With-T5.cmd
├── Install-T5-Connection-Popup.cmd
└── Remove-T5-Connection-Popup.cmd
```

Keep these names. The `T5` filenames come from the original Samsung T5 prototype. If you already have a launcher installed on the drive, use a separate test drive.

### 2. Pair the drive

Double-click `Configure-SSD.cmd` and choose a cache folder relative to the SSD, for example:

```text
AI\Models\huggingface\hub
```

Review the drive and folder, then type `PAIR`. Setup creates the cache folder if needed and writes `T5-Launcher/device.json`. That file is specific to your drive; keep it out of Git. You do not need to pair again when the drive letter changes.

Run `Check-Setup.cmd` for a read-only diagnostic before your first launch.

### 3. Launch Unsloth and check the cache

Fully quit Unsloth and its background backend. Double-click `Start-Unsloth-With-T5.cmd` and accept the prompt. If asked, select this PC's installed `unsloth-studio.exe`.

In Unsloth, verify that the active Hub cache points to the SSD. For an existing library, check **On Device**. For an empty library, open **Model hub**, download a small supported model, then load it and try a prompt. Gated models may require your own sign-in on this PC.

See the [full setup guide](docs/setup.md) or the guide to [adding and removing models](docs/models.md) for more detail.

<a name="daily-use"></a>

## Daily use

Connect the paired SSD, open `Start-Unsloth-With-T5.cmd`, and approve the prompt. Once Unsloth opens, choose a recognized model from the library.

Use Unsloth's download and removal controls to manage models after checking that the selected cache is on the SSD. Changes to the shared cache affect later users of the drive. Credentials used during launcher sessions remain on the host. See the [model-management guide](docs/models.md).

Before unplugging, stop downloads and generation, unload models, and quit Unsloth and its backend. Then eject the drive through Windows. Keep the SSD connected throughout a session: loaded models can still read from disk. Use the writable cache on one computer at a time.

<details>
<summary><strong>Optional connection popup</strong></summary>

Run `Install-T5-Connection-Popup.cmd` from the paired SSD once on each Windows account where you want prompts.

The helper starts at sign-in and checks every five seconds. When it detects a newly connected matching drive, it asks before launching Unsloth. Declining keeps it quiet for that insertion. It skips the drive connected during installation, so use the manual launcher for that first session.

On a computer without the helper, open the launcher yourself. Plugging in the SSD alone does not run anything; this is not USB AutoRun. This version supports one paired drive per account's helper.

To disable the helper, run `Remove-T5-Connection-Popup.cmd`, also available in `%LOCALAPPDATA%\PortableLocalAI`. It removes its verified Startup shortcut and stops the watcher. Helper files and logs remain.

</details>

## What stays on the drive

The SSD holds model weights, repositories, and cache metadata, including model names and filesystem timestamps. Model additions and deletions carry over to later users of the drive.

Each PC keeps its Unsloth installation and runtime, known local chat and authentication state, and Hugging Face credentials used by launcher sessions. Launcher logs, temporary files, and session project defaults also stay on the host. The launcher checks known chat and credential paths before starting the app and stops if those privacy checks fail.

These checks cover storage locations. They do not control network access, cloud synchronization, or manual exports. Existing chats remain on the host, and there is no incognito session or automatic cleanup. Anything you save to the SSD travels with it; anyone who can read an unencrypted SSD can inspect its files. Keep private models, datasets, tokens, and backups off a shared drive. See the [privacy boundary](docs/privacy.md).

<a name="questions"></a>

## Questions and troubleshooting

<details>
<summary><strong>What does the launcher change?</strong></summary>

It sets `HF_HUB_CACHE` for the new Unsloth process without changing Windows' global environment. It uses `%LOCALAPPDATA%\PortableLocalAI\HuggingFace` for session credentials, removes inherited raw Hub token variables from the child process, and keeps known temporary, auxiliary-cache, and project defaults on the host. Explicit offline settings are preserved.

Known application-state paths must stay inside the current local Windows profile without junctions or symbolic links. The launcher does not copy models or chats, format drives, kill applications, or configure ComfyUI. Unsloth can still access the network and write to the selected cache during normal use.

Pairing helps prevent ordinary wrong-drive mistakes. It is not cryptographic authentication or a model-code sandbox. See the [design notes](docs/design.md) for how the launch works.

</details>

<details>
<summary><strong>My models are missing, or the launcher stops. What should I check?</strong></summary>

**Missing models:** verify the active SSD cache path and check that the Hub snapshots are complete and supported. Loose GGUF files are not converted into Hub entries.

**Unsloth is already running:** fully quit the app and its backend, then relaunch from the SSD.

**The app cannot be found:** select the host-installed `unsloth-studio.exe`. An app copy on the model SSD is rejected.

**A privacy or path check fails:** run `Check-Setup.cmd` and review the layout. Do not delete links or move databases just to silence a check.

**A gated model needs login:** use your own credentials on this host. The launcher does not import them from the SSD.

Diagnostic output contains local paths; redact it before sharing. See [setup help](docs/setup.md) for more detail.

</details>

<details>
<summary><strong>Can I use another PC or work offline?</strong></summary>

Another PC needs Windows, a working Unsloth installation, a supported runtime, and enough RAM/VRAM. These scripts do not install dependencies. macOS, Linux, network or redirected profiles, and nonstandard runtime layouts are outside the current compatibility scope.

For offline use, the model and runtime must already be complete, and the installed application must support the intended workflow. The launcher preserves explicit offline settings; it does not block network access or guarantee offline operation.

</details>

<details>
<summary><strong>Can I upgrade the original T5 prototype?</strong></summary>

Keep the working installation in place. This source is not an automatic upgrade package: SSD filenames overlap, and helper upgrades can refuse differing files. Test separately and do not enable both watchers together.

</details>

<a name="status"></a>

## Project status

Version 0.2.0 is a Windows prototype. The testing notes record 97 passing local automated checks, an installed-backend cache-routing probe, and cache discovery in the original one-laptop prototype.

Validation is still needed for a full run on a second prepared PC, real UI download and deletion, shared-state acceptance tests, current Unsloth versions, and a real exFAT device.

The original prototype used Unsloth Desktop `0.1.806-beta`. Model discovery does not prove that every model will run. A GitHub Actions workflow is included, but this README makes no claim about its current remote result. See the [testing notes](docs/testing.md).

<details>
<summary><strong>Run the automated checks</strong></summary>

From the repository root:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\tests\Test-Launcher.ps1
```

These checks do not start Unsloth, install the helper, or modify a model drive. The execution-policy flag applies only to this process; follow your organization's device policy. See the [code walkthrough](docs/code-walkthrough.md) for the implementation and the [release checklist](docs/release-checklist.md) for acceptance testing.

</details>

## Documentation

- [Setup and troubleshooting](docs/setup.md)
- [Managing models](docs/models.md)
- [Demo guide](docs/demo.md)
- [Privacy and storage](docs/privacy.md)
- [Design notes](docs/design.md) and [code walkthrough](docs/code-walkthrough.md)
- [Testing notes](docs/testing.md) and [release checklist](docs/release-checklist.md)
- [Changelog](CHANGELOG.md) and [publishing guide](docs/github.md)

---

Created by **Garv Gupta**, with AI assistance. Unsloth and Hugging Face provide the application and model infrastructure; this repository provides the launcher integration.

**License:** a code license has not been selected. Review the [release checklist](docs/release-checklist.md) before publishing a reusable release.

[Back to top](#top)
