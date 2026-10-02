# Testing notes

Latest documented physical-workflow evidence: **30 September 2026**, with supplemental PC01 token evidence confirmed on **1 October 2026**. See the [manual testing pilot](#manual-testing-pilot-recorded-on-30-september-2026) for results and limitations.

Historical npm adapter validation: **11 September 2026**, package **0.3.0-rc.1**, preserving Windows runtime **0.2.1-rc.3**. The original runtime checks passed on Windows PowerShell 5.1 and PowerShell 7. A previously reported second-laptop launch predates this npm adapter; physical acceptance of the new installation route remains pending.

## npm adapter checks

- `npm test`: 62 Node test cases pass, including a PowerShell fixture suite with 40 assertions. Covers CLI errors, OS/runtime guards, shell-free argument transport, exit codes, existing pairings, no unattended setup, payload conflicts, matching copies, retained files, junction rejection, and the real system-volume refusal path.
- `npm run test:launcher`: the original 177 checks pass. Also run directly under PowerShell 7.6.5, with 177 checks passing.
- `npm run test:package`: packs an actual tarball, verifies its file allowlist, installs into disposable global prefixes, runs CMD and PowerShell shims, checks the installed backend, runs offline `npm exec`, and uninstalls from those prefixes. npm 11.16.0 and Node.js 24.18.0 were used locally.
- CI includes Node.js 22 and 24 on Windows. Node.js 22 CI is configured but was not run locally.

The npm tests use disposable folders and mocked drive operations where needed. They do not format or pair a physical SSD, start a real Unsloth process, install a real startup helper, or generate from a model. Test those flows on a spare SSD before treating this release candidate as stable. The filesystem-copy tests do exercise actual files and junctions inside their fixtures.

`test-results` contains disposable test state and is excluded from Git and the npm package. The tarball includes no device pairing, credentials, model weights, test fixtures, or large documentation images. See [npm.md](npm.md) for the maintainer and replacement procedures, including the observed npm CMD shortcut limitation for installation prefixes containing ampersands.

## Manual testing pilot recorded on 30 September 2026

For the research pilot, we recorded one trial on each of three Windows PCs: PC01, PC02 and PC04. All three records report a completed response. That gives me a useful first set of results across different hardware, including a 16 GiB laptop with a 2 GiB MX450. I am treating this as an initial workflow check. Response correctness, manager-specific speed gains and acceptance of the current release candidate still need their own tests.

The results below come from our paper, *Portable Local AI Environment Manager Design and Pilot Evaluation*, by Garv Gupta, Anuj Jain and Dr. Vandana Dubey (`portable-ai-ieee-evidence-updated_final.docx`, Sections IV–VI and Appendix A). The paper describes checks of the collection files and supplemental screenshots. This page summarizes those reported values; it adds no new analysis of the raw files. The raw records and screenshots are not included with this update.

### Hosts and recorded workloads

| Recorded field | PC01 | PC02 | PC04 |
| --- | --- | --- | --- |
| CPU | Intel Core Ultra 9 275HX | Intel Core i7-14700F | Intel Core i5-1135G7 |
| Cores / threads | 24 / 24 | 20 / 28 | 4 / 8 |
| Installed RAM | 64 GiB | 16 GiB | 16 GiB |
| NVIDIA GPU | RTX 5080 Laptop GPU | RTX 3050 | MX450 |
| GPU memory reported by `nvidia-smi` | 16,303 MiB | 8,192 MiB | 2,048 MiB |
| Windows 11 build | 26300 | 26200 | 26300 |
| Recorded model | `unsloth/gemma-4-E4B-it-GGUF` | `Qwen2.5-Omni-7B-GGUF` | `gemma-4-26B-A4B-it-GGUF` |
| Recorded quantization | `UD-Q4_K_XL` | `UD-IQ2_M` | `UD-IQ2_M` |
| Operator-entered phase | Repeat use | First-time setup | Repeat use |
| Declared network condition | Offline | Offline | Online |

All sessions record Unsloth `v0.1.900-beta`. For the next round, the collection record needs exact model revisions, file hashes, complete generation settings and the path and commit of the launcher used. PC02 is labelled first-time setup; the recorded window does not establish whether application installation was included.

PC01 and PC02 snapshots identify an approximately 500 GB Samsung Portable SSD T5 on `E:` with NTFS. PC04 also records `E:` throughout its response workflow. Its device identity and filesystem remain to be captured. These observations establish drive availability; a file-read trace is the next step for confirming where the model weights were read. The September 11 SanDisk report below covers a separate earlier test.

### Operator-marked timings

Collector `1.0.0` recorded button events against a monotonic clock. The operator marked task start, launch submission, application readiness, model-load request, model readiness, prompt submission, first visible output and response completion. These marks include reaction delay.

| Interval in seconds | PC01 | PC02 | PC04 |
| --- | ---: | ---: | ---: |
| Task start to launch submission | 23.95 | 1.24 | 12.34 |
| Launch submission to application ready | 1.07 | 9.37 | 7.68 |
| Model-load request to model ready | 7.46 | 11.91 | 29.66 |
| Prompt submission to first visible output | 4.97 | 0.39 | 5.02 |
| First visible output to response completion | 5.46 | 11.78 | 159.19 |
| Task start to response completion | 112.73 | 48.75 | 248.50 |

Each analyzed `trial-001` is labelled `MANAGER`, `NORMAL` and `EXTERNAL`, with response outcome `YES` and completion `COMPLETED`. These timings are useful records of what happened on each PC. A fair speed comparison will need matched manual-launch, fixed-path and internal-storage runs, which were not part of this pilot. The models, hardware and starting conditions differ, and task time includes operator waiting, so the table is a workflow record rather than an inference-speed benchmark.

### Resources during the response workflow

The paper selects samples from task start (T0) through response completion (T7), excluding later form entry. CPU and RAM refer to the whole system; GPU readings refer to the whole device. The collector targets three-second polling, so brief peaks can be missed.

| Recorded metric within T0–T7 | PC01 | PC02 | PC04 |
| --- | ---: | ---: | ---: |
| System / GPU sample rows | 33 / 33 | 16 / 16 | 76 / 76 |
| CPU mean / sampled maximum (%) | 10.52 / 20 | 10.56 / 25 | 43.91 / 85 |
| Used RAM sampled maximum (MiB) | 20,862.75 | 11,470.76 | 15,524.17 |
| GPU utilization mean / sampled maximum (%) | 4.33 / 77 | 0.88 / 7 | 11.20 / 69 |
| Used GPU memory sampled maximum (MiB) | 7,085 | 5,493 | 603 |
| GPU temperature sampled maximum (°C) | 57 | 47 | 59 |
| `E:` present observations | 33 of 33 | 16 of 16 | 76 of 76 |

The resource samples give a view of overall host activity during the workflow. Measuring the model alone and identifying its inference backend will need more targeted logging. GPU power is left out until the source records are checked: Table IV gives PC02/PC04 values, while the accompanying text says those readings are missing.

### Supporting evidence and next steps

PC01 has two supporting screenshots showing 484 completion tokens, 125 prompt tokens and 609 total tokens. On 1 October, the operator confirmed that they show the response timed in `trial-001`. That association relies on the confirmation because the screenshots have no trial ID or timestamp. PC02 records 424 tokens, with a linked screenshot or log still needed; PC04 records 896 tokens as `UNVERIFIED_OPERATOR_ENTRY`. Keeping those distinctions makes it easier to improve the evidence in the next run. The counts and UI rates remain provisional and are not verified throughput benchmarks.

The three reported completions provide a starting point for the next test round. The follow-up checks are:

- Capture model-file reads to confirm that the weights come from the external SSD. The current records show drive presence, without identifying the read source.
- Repeat generation with a recorded network-disconnection check. PC01/PC02 declare offline; PC04 declares online, so offline operation is still to be verified.
- Capture file-write traces while using a harmless test chat to check where private state is saved. The current entries have no linked traces.
- Reconnect the SSD under another drive letter and record a successful launch. All three pilot trials use `E:`.
- Repeat matched runs with a documented cache reset to measure setup time, launcher overhead and consistency. This pilot has one run per host and no controlled cold-cache baseline.
- Save the prompt and full response with each trial so response correctness and identical prompt execution can be checked. Those checks remain open.

### Session traceability

| Host | Analyzed session |
| --- | --- |
| PC01 | `PC01_20260930_142938_da02e1` |
| PC02 | `PC02_20260930_162206_bfa739` |
| PC04 | `PC04_20260930_213644_17c521` |

The replacement PC04 session supersedes `PC04_20260930_192825_7f4aa3`; the earlier recording is excluded, not counted as an extra host or repeat. The paper uses `events.csv` for response-workflow intervals and `system-samples.csv` / `gpu-samples.csv` for the resource window. It reports that raw files were preserved unchanged.

The intended `PROMPT01` asks for a beginner-friendly English explanation of CPU, GPU, RAM and SSD roles, with exactly four numbered sections and three short sentences per section. The PC01 handoff preserves its text. Capturing the executed prompt on PC02 and PC04 will make the next comparison easier to reproduce; identical execution is not yet independently evidenced.

The checklist below tracks release acceptance separately from the research pilot. Its completed items still refer to the September 11 report; unchecked items need results for the current candidate. The npm installation route also needs its physical acceptance run. This update publishes the summary only, without the raw evidence files.

## Second-laptop test — reported by Garv

On **11 September 2026**, Garv reported this test on a friend's newly prepared Windows laptop using a **SanDisk external SSD**:

1. Install Unsloth Desktop, complete its initial setup, then close it.
2. Connect the SSD to the laptop.
3. Accept the connection pop-up.
4. Unsloth opens and uses the model location on the SSD.
5. The SSD's models appear under **On Device**.

**Result: passed for connection detection, confirmation, app launch, and model discovery on a second laptop.** This is a maintainer-reported physical test, separate from the automated suite. No model files needed to be selected individually in the app.

This run established connection detection, the confirmation prompt, application launch and model discovery on a second laptop. To turn that into a reproducible acceptance record, the next run needs the launcher commit, Windows and Unsloth versions, laptop specifications, SSD filesystem and drive letters. Loading and generating, model downloads and deletion, and private-data placement remain separate checks; the visible model list does not establish them. This September 11 report also predates the saved-path correction in `0.2.1-rc.2`, so that build needs its own physical acceptance run.

The connection pop-up requires the helper to be installed once on that Windows account. The report confirms that it appeared; it does not change the [helper setup requirement](setup.md#6-enable-insertion-prompts-optionally).

## This repository

`tests/Test-Launcher.ps1` passed **177 checks** under Windows PowerShell **5.1.26100.9444** and PowerShell **7.6.5**. The 10 September baseline had 97 checks.

The checks cover script parsing, malformed configuration, unsafe relative paths, registry path parsing, path construction with several simulated drive letters, child-only credential isolation, preserved offline settings, and direct process configuration without shell interpolation. Module-scoped test doubles exercise wrong-drive rejection, executable-volume rejection, declined consent, the already-running guard and disconnecting during the prompt. Privacy checks cover redirected private state, token-variable removal and blocking launch on preflight failure. One read-only native Windows check resolves the host PowerShell executable's volume.

The regressions cover reserved Windows filenames, typed configuration fields, UTF-8 pairing names and saved app paths, oversized or incomplete JSON, atomic state replacement, locked files and logs, disabled watcher state during consent, and readiness failures. Helper lifecycle tests use a fake shortcut service and disposable files to check disconnects, ownership mismatches, and uninstall behavior. A simulated successful launch checks the process boundary and saved cache path without starting Unsloth. Real subprocess tests verify unpaired diagnostics and the `.cmd` wrapper's exit code.

Cache-preparation tests create disposable fixtures in the ignored `test-results/` directory: a missing cache, an empty cache, an unrelated folder, a file at the intended destination and a basic snapshot layout. They verify that planning is read-only and preserves a refused folder's existing content. These fixtures are retained locally, not packaged for release.

Desktop-shortcut tests use the native Windows shortcut service inside disposable test folders. They read back the icon, executable, quoted arguments and working directory; check identical reinstalls and refusal to overwrite other files; and exercise missing drives, changed letters, ambiguous pairings, disconnection, privacy failure and redirected destinations. They do not put a shortcut on the user's Desktop.

These are local automated checks. Simulating `F:` or `Z:` is not the same as physically reconnecting a drive with a new letter. The tests deliberately do not start Unsloth, pair a real SSD, or install the watcher.

The [Windows checks workflow](https://github.com/Truemaster124/Portable-Local-AI-Environment-Manager/actions/workflows/test.yml) runs the suite in both Windows PowerShell and PowerShell 7 on pushes and pull requests. Check the result for the commit you plan to use; CI is separate from the physical acceptance tests.

## Installed-backend probe

On 11 September 2026, `tests/Probe-Unsloth-Cache.ps1` passed all seven checks using the installed Unsloth Python, its `utils/hf_cache_settings.py` and the installed Hub library: explicit cache selection, the Hub path, the auxiliary cache path, a host-local token path, removal of inherited raw Hub tokens, and the Hub library's resolved credential-home and token-file constants. It uses a synthetic cache location and does not scan or modify models. A separate read-only host privacy preflight also passed.

The installed source was inspected for model operations: `hub/services/models/downloads.py` takes its cache from `get_hf_cache_paths()`, and `hub/services/models/deletion.py` resolves the selected cache owner before deletion. This supports the routing design. No real UI download or deletion was exercised for this release.

## Compatibility and app updates

The launcher uses the Unsloth Desktop installation on the current PC. The historical version below describes the original test environment; it is not a required version or a guarantee that every newer version behaves the same way.

After updating Unsloth, fully close the app and its backend, then run `Check-Setup.cmd` from the paired SSD. Launch again, confirm the selected Hub cache and **On Device** model list, and try a prompt with a small supported model. If the update changes model management or storage, repeat the download, deletion, and privacy checks in the [manual acceptance record](#manual-acceptance-record).

Network or redirected Windows profiles and nonstandard installation layouts are not covered by the recorded physical test. If a path or privacy check fails, follow the [setup guide](setup.md) before proceeding.

## What came from the original prototype

The device-specific predecessor was checked on one laptop with Unsloth Desktop `0.1.806-beta`. A read-only probe using its installed backend's cache-resolution code discovered 29 cached repositories, with 10 cache warnings. Discovery is not proof that all 29 models can load or run. Those warnings need separate investigation.

That predecessor also had its own 41-check suite. Those results are historical context, not extra passing checks for this generalized release. Private file manifests, model lists, logs and database backups are not included here.

## Manual acceptance record

The checked items record what worked in my reported second-laptop run. The unchecked items are the next acceptance checks; they have no confirmed result from that report. For the current candidate, record the commit, Windows and Unsloth versions, laptop hardware, model, filesystem and drive letters alongside each result. Use a spare test SSD and a backed-up, known-good small model cache, keeping the working installation intact.

- [ ] Pair the test SSD, then confirm that rerunning setup refuses to overwrite its marker.
- [ ] Start with an empty cache and download a small public model from Unsloth. Verify the new files are on the paired SSD, not a remembered host cache.
- [ ] Decline the launch prompt and confirm no Unsloth process starts.
- [x] Accept the connection prompt and verify that Unsloth opens with the SSD models under **On Device**.
- [ ] Load the small model and complete one prompt. Record the app version, model, RAM, GPU and VRAM.
- [ ] Repeat with Unsloth already open. Confirm the launcher asks you to quit rather than stopping it.
- [x] Confirm that connecting the SSD produces a connection prompt on the second laptop.
- [ ] Verify a fresh helper installation, repeated insertions, and declining the prompt without repeated prompts for that insertion.
- [ ] Sign out and back in; confirm the helper starts. Remove it and confirm future insertions stay quiet.
- [ ] Disconnect while the consent prompt is open. Confirm accepting afterward does not launch against the missing cache.
- [x] Use the SSD on a second prepared Windows laptop and confirm launch and model discovery.
- [ ] Record different drive letters on the two PCs and confirm launch after the letter changes.
- [ ] Create the desktop shortcut on a prepared test PC, verify its icon, and launch through it after reconnecting the SSD with a different letter. Confirm the missing-drive message when unplugged.
- [ ] Repeat the workflow on a physical exFAT drive and record the result.
- [ ] Make a harmless, unique test chat on PC A. On PC B, verify it is absent and that no conversation/export was written to the SSD. Inspect files as well as the UI; record limitations of the check.
- [ ] On PC B, delete only the disposable test model through Unsloth after verifying its SSD cache path. Confirm it is absent on PC A after reconnecting. Do not use an important or sole-copy model for this test.
- [ ] If claiming offline operation, repeat a prompt without network access after confirming the model and runtime are complete.

Add a short result and its supporting evidence as each check is completed. That will make this record useful for anyone repeating the setup. Before sharing a demo, redact user paths, account names, tokens and private model names.
