
# Portable Local AI Environment Manager

<p align="center">
  <img src="docs/assets/portable-ai-banner.png" width="100%" alt="Portable Local AI Environment Manager: an external model drive connected to a prepared Windows PC, with colorful sticker accents">
</p>

<p align="center"><sub>Concept illustration: a portable model library connected to a prepared Windows PC.</sub></p>

<p align="center"><strong>Carry your model library. Keep your personal workspace on your PC.</strong></p>

<p align="center">A small Windows launcher for using an external SSD with Unsloth Desktop.</p>

<p align="center">
  <a href="#get-started">Get started</a> &nbsp;·&nbsp; <a href="#how-it-works">How it works</a> &nbsp;·&nbsp; <a href="#privacy-and-storage">Privacy</a> &nbsp;·&nbsp; <a href="#help-and-documentation">Help</a>
</p>

**Version 0.2.0 · Windows prototype · No model weights included**

## Why I built this

My local AI models were taking up too much space on my internal drive. Moving them to a Samsung T5 helped, but the apps still needed to know where to find them. A different drive letter could mean another round of path changes.

This project handles that connection. You pair the SSD once, then use the launcher to open the Unsloth installation on your computer with the right model-cache path. The files travel with the drive; the computer runs the model.

It is useful if you want to keep a library off your internal drive or carry it between prepared Windows PCs. Each PC still needs Unsloth Desktop, its runtime, and enough RAM or VRAM for the model you choose.

## How it works

**Connect the SSD → Open the launcher → Confirm → Choose a model in Unsloth**

The launcher checks the paired drive marker and filesystem volume serial, finds the current cache location, and sets the paths for the new Unsloth process. If Windows changes the drive from `D:` to `E:`, you do not need to edit the configuration. Windows’ global environment variables stay unchanged.

Unsloth handles model discovery, downloads, and removal. The launcher supplies the cache location and checks that known personal-data paths remain on the host. An optional connection prompt can make subsequent launches easier.

<p align="center">
  <img src="docs/assets/portable-ai-workflow.png" width="100%" alt="Three-step workflow: connect the paired SSD, run the launcher to resolve its cache path, and open the installed Unsloth application on the PC">
</p>

<p align="center"><sub>Illustrated workflow, not actual application screenshots. Requires a prepared Windows PC; see the privacy section for storage limits.</sub></p>

## Get started

Before you begin, have Windows PowerShell 5.1, a working and initialized Unsloth Desktop installation, and an external SSD with enough free space. Use an empty model folder or a complete Hugging Face Hub cache. Loose model weights are not a Hub cache; preserve snapshot files and links when copying one.

NTFS was used in the original prototype. The scripts also support exFAT, but a real-device exFAT test is still pending. Back up important files before changing your setup.

### 1. Copy the launcher to your SSD

Download and extract the repository ZIP. Copy `T5-Launcher/` and all five root-level `.cmd` files to the root of the SSD:

```text
Your SSD/
├── T5-Launcher/
├── Configure-SSD.cmd
├── Check-Setup.cmd
├── Start-Unsloth-With-T5.cmd
├── Install-T5-Connection-Popup.cmd
└── Remove-T5-Connection-Popup.cmd
```

Keep these filenames. The T5 names come from the original drive; you do not need a Samsung SSD. If you already have a working launcher on a drive, test this version separately before replacing it.

### 2. Pair the drive

Open `Configure-SSD.cmd` and choose a cache folder relative to the SSD, such as `AI\Models\huggingface\hub`. Check the displayed drive and folder, then type **`PAIR`**.

Setup creates the folder if needed and saves the pairing in `T5-Launcher/device.json`. Keep that file out of Git. Run `Check-Setup.cmd` for a read-only check before your first launch. Pairing does not need to be repeated when the drive letter changes.

### 3. Launch and check your library

Fully quit Unsloth and its background backend. Open `Start-Unsloth-With-T5.cmd`, accept the prompt, and select the computer’s installed `unsloth-studio.exe` if asked.

Check that Unsloth’s active Hub cache points to the SSD. Existing supported models should appear under **On Device**. For an empty library, download one small supported model through **Model hub**, load it, and try a prompt. Gated models may ask you to sign in on this PC.

[Full setup guide](docs/setup.md) · [Adding and removing models](docs/models.md)

## After the first setup

For a normal session, connect the SSD, open the launcher, and choose your model. Downloads and removals made through Unsloth affect the selected library, so check the cache location first. Anyone using that SSD later will see those library changes.

Before unplugging, stop downloads and generation, unload models, quit Unsloth and its backend, and eject the SSD through Windows. Keep the drive connected throughout the session and use its writable cache on one computer at a time.

<details>
<summary><strong>Show a prompt when I connect the SSD</strong></summary>

Run `Install-T5-Connection-Popup.cmd` from the paired drive once on each Windows account where you want prompts. The helper starts at sign-in and checks every five seconds. It asks before launching when it detects the paired SSD; declining keeps it quiet for that insertion.

A drive already connected during installation is skipped, so launch manually for that first session. Without the helper, use the launcher directly. This is not USB AutoRun, and the helper supports one paired drive per account.

To turn prompts off, run `Remove-T5-Connection-Popup.cmd`. It removes the verified Startup shortcut and stops the watcher. Local helper files and logs remain. The removal command is also available in `%LOCALAPPDATA%\PortableLocalAI`.

</details>

## Privacy and storage

**On the SSD:** model files and cache metadata.

**On the computer:** known chat, authentication, credential, temporary-file, and project-default paths. Existing local chats stay in place. The launcher stops if its host-state checks fail.

This separation is about where files are stored. It does not encrypt the drive, block network access, control cloud synchronization, or prevent exports. Anything you save to the SSD travels with it, so keep private datasets, credentials, and backups off a shared drive.

[Read the privacy details](docs/privacy.md)

## Help and documentation

<details>
<summary><strong>My models are missing, or the launcher will not start</strong></summary>

- **Models missing:** check the active cache path, complete snapshots, and model compatibility. Loose GGUF files are not converted into Hub entries.
- **Unsloth already running:** quit the app and its backend, then try again.
- **App not found:** select the executable installed on this PC. An app copy on the model SSD is rejected.
- **Path or privacy check failed:** run `Check-Setup.cmd` and review the setup guide. Do not move databases or delete links just to silence the check.
- **Sign-in requested:** use your own host credentials for gated models.

Diagnostic output includes local paths. Redact personal information before sharing it. See the [setup guide](docs/setup.md) for more detail.

</details>

<details>
<summary><strong>Explore the project documentation</strong></summary>

- [Setup](docs/setup.md) — prepare a drive and troubleshoot a launch.
- [Model management](docs/models.md) — add and remove supported models.
- [Demo guide](docs/demo.md) — walk through the project in a presentation.
- [Design](docs/design.md) and [code walkthrough](docs/code-walkthrough.md) — understand the implementation.
- [Testing](docs/testing.md) — review automated checks and manual acceptance steps.
- [Release checklist](docs/release-checklist.md) and [changelog](CHANGELOG.md) — prepare and track releases.

</details>

## Project status

The recorded local test run passed **97 automated checks**. A complete physical second-PC test, real-device exFAT testing, and real download/delete acceptance tests are still pending. The original prototype used Unsloth Desktop `0.1.806-beta`; later versions need retesting.

The launcher does not install runtimes, format drives, copy models, stop applications, or configure ComfyUI. Offline use depends on the installed app and a complete model/runtime. Network or redirected profiles and nonstandard layouts need separate review. No setup-time savings or inference-speed benchmarks have been measured.

Keep any working original T5 prototype in place while testing, and do not enable both watchers together.

<details>
<summary><strong>Run the automated checks</strong></summary>

From the repository root:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\tests\Test-Launcher.ps1
```

These tests do not launch Unsloth, install the helper, or modify a model drive. The execution-policy flag applies only to that process; follow your organization’s device policy. A Windows GitHub Actions workflow is included. See [testing notes](docs/testing.md) for the backend probe and manual checks.

</details>

## Credits and license

Created by **Garv Gupta**, with AI assistance. Unsloth and Hugging Face provide the application and model infrastructure; this project provides the launcher integration. The banner and workflow are AI-assisted illustrations. The original SSD photograph and its attribution are below.

<details>
<summary>Original SSD photograph and attribution</summary>

<p align="center">
  <img src="docs/assets/samsung-t5.jpg" width="560" alt="A Samsung T5 external SSD, the drive used in the original project">
</p>

<p align="center"><sub>Photo by <a href="https://www.flickr.com/people/87296837@N00">Tony Webster</a>, via <a href="https://commons.wikimedia.org/wiki/File:Samsung_T5_Portable_External_SSD_(Solid_State_Drive)_(43544308485).jpg">Wikimedia Commons</a> · <a href="https://creativecommons.org/licenses/by/2.0/">CC BY 2.0</a> · Image unchanged</sub></p>

</details>

A code license has not yet been selected. See the [release checklist](docs/release-checklist.md) before publishing a reusable release.
