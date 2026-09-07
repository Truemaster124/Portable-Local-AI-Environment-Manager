# How the launcher works

## Two things that need to stay separate

The application belongs to the host computer. Its Python/runtime dependencies, GPU support, account and chat history are machine-local concerns.

The model cache belongs to the external drive. It contains the repositories and files Unsloth can discover and load. Moving those files does not move the inference hardware.

The original laptop also used a stable Windows folder mount for several AI applications. This repository doesn't create that mount. It uses the SSD's current location to build a path for each launch, so a new computer does not need the original laptop's `C:` folder layout.

## From double-click to model list

1. The `.cmd` wrapper locates its PowerShell script using `%~dp0`, the wrapper's own directory.
2. The script reads `device.json`. It checks the marker ID, filesystem serial and relative cache folder. A copied marker on a different volume is not enough to pass the normal check.
3. The user gets a Yes/No prompt, with No selected by default. A decline ends the launch path.
4. The launcher checks for an existing Unsloth session. It asks the user to close it instead of killing processes or trying to change a running backend's environment.
5. App discovery checks a saved local selection, Windows uninstall registrations and a few common install paths. If necessary, a file picker asks for `unsloth-studio.exe`. Copies on the model volume are rejected, including through a Windows volume mount.
6. Privacy preflight checks the host profile and known state paths. Before starting, the launcher checks privacy, the drive and running processes again, then builds a `ProcessStartInfo` and starts the executable directly, without constructing a shell command.
7. Unsloth's backend reads the cache path during startup and performs its own model discovery. The launcher does not insert fake records into its database or populate its UI directly.

`HF_HUB_CACHE` selects the repository cache. Environment variables need to be set before the Hub library is imported, which is why starting a fresh backend matters. [Hugging Face environment-variable reference](https://huggingface.co/docs/huggingface_hub/package_reference/environment_variables).

## The connection helper

Installation copies the launcher module, entry script and pairing configuration into `%LOCALAPPDATA%\PortableLocalAI`. It creates a shortcut named `Portable Local AI Connection Popup.lnk` in the current user's Startup folder.

The watcher enumerates drive letters every five seconds. A newly detected matching drive gets a short debounce delay, then the same consent flow as a manual launch. Declining doesn't trigger another prompt on every scan. A disconnect and reconnect entirely between scans can be missed.

The installed watcher executes its **local copy of the helper**, not arbitrary code found on a newly inserted drive. Session mutexes prevent duplicate generic watchers and overlapping generic prompts. It is still a small polling helper, not a Windows service.

## Files to read first

| File | Responsibility |
| --- | --- |
| `T5-Launcher/Configure-SSD.ps1` | Validate the selected cache and create a pairing marker without overwriting one |
| `T5-Launcher/T5Launcher.psm1` | Validate paths and drive identity, find the app, ask for consent, construct its environment |
| `T5-Launcher/T5Launcher.ps1` | Dispatch launch/check/install/uninstall/watch modes |
| `tests/Test-Launcher.ps1` | Configuration, path, environment and guarded-launch checks |

Only the optional helper installer adds a Startup shortcut. Removal verifies its target and arguments before deleting that one shortcut. Model folders are never a deletion target.

## What happens after loading

The runtime reads model data from the SSD into memory as needed. Depending on the backend and configuration, weights may be copied into RAM and VRAM, memory-mapped, or partly offloaded. The host's CPU/GPU performs the computation; the T5 is storage.

An internal NVMe drive and an external USB SSD can hold identical model files. The differences are their connection, throughput, latency and availability. External storage can affect startup and workloads that keep accessing disk. This project has not measured those differences, so it makes no speed claim.

Downloading from a website is how you obtain files. This launcher is how you reuse already-downloaded files on another prepared computer. It does not change the weights, remove model licenses, or eliminate hardware requirements.

## Trust boundary

Pairing prevents ordinary wrong-drive mistakes. It is not cryptographic authentication: filesystem serials and marker files can be copied or forged. This tool assumes a trusted SSD and trusted model collection. It does not audit model code, secure an untrusted computer, or isolate secrets from the application. Version 0.2 sets a host-local Hugging Face credential home and drops inherited raw Hub token variables in the child. The host's original environment is unchanged.

The cache root and its ancestors must not be junctions or symbolic links. Individual snapshot links inside the cache can still lead elsewhere: the launcher does not inspect every model file. Inspect those links when preparing a portable collection. Known host-state paths get the same conservative reparse-point checks. These checks detect ordinary misconfiguration, not a malicious process changing paths after validation.
