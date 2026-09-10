# Testing notes

Latest local validation: **11 September 2026**, for **0.2.1-rc.2**. A successful second-laptop launch and model-discovery test has also been reported. The remaining acceptance checks are listed below.

## Second-laptop test — reported by Garv

On **11 September 2026**, Garv reported this test on a friend's newly prepared Windows laptop using a **SanDisk external SSD**:

1. Install Unsloth Desktop, complete its initial setup, then close it.
2. Connect the SSD to the laptop.
3. Accept the connection pop-up.
4. Unsloth opens and uses the model location on the SSD.
5. The SSD's models appear under **On Device**.

**Result: passed for connection detection, confirmation, app launch, and model discovery on a second laptop.** This is a maintainer-reported physical test, separate from the automated suite. No model files needed to be selected individually in the app.

The report does not include the launcher commit, Unsloth or Windows version, laptop specifications, SSD filesystem, or the drive letters on either PC. It also does not confirm loading a model and generating a response, adding or deleting a model, or inspecting the drive for personal data. Those results remain open; a visible model list alone does not verify them. The report predates the saved-path correction in `0.2.1-rc.2` and is not a physical acceptance test of that exact build.

The connection pop-up requires the helper to be installed once on that Windows account. The report confirms that it appeared; it does not change the [helper setup requirement](setup.md#6-enable-insertion-prompts-optionally).

## This repository

`tests/Test-Launcher.ps1` passed **147 checks** under Windows PowerShell **5.1.26100.9444** and PowerShell **7.6.5**. The 10 September baseline had 97 checks.

The checks cover script parsing, malformed configuration, unsafe relative paths, registry path parsing, path construction with several simulated drive letters, child-only credential isolation, preserved offline settings, and direct process configuration without shell interpolation. Module-scoped test doubles exercise wrong-drive rejection, executable-volume rejection, declined consent, the already-running guard and disconnecting during the prompt. Privacy checks cover redirected private state, token-variable removal and blocking launch on preflight failure. One read-only native Windows check resolves the host PowerShell executable's volume.

The regressions cover reserved Windows filenames, typed configuration fields, UTF-8 pairing names and saved app paths, oversized or incomplete JSON, atomic state replacement, locked files and logs, disabled watcher state during consent, and readiness failures. Helper lifecycle tests use a fake shortcut service and disposable files to check disconnects, ownership mismatches, and uninstall behavior. A simulated successful launch checks the process boundary and saved cache path without starting Unsloth. Real subprocess tests verify unpaired diagnostics and the `.cmd` wrapper's exit code.

Cache-preparation tests create disposable fixtures in the ignored `test-results/` directory: a missing cache, an empty cache, an unrelated folder, a file at the intended destination and a basic snapshot layout. They verify that planning is read-only and preserves a refused folder's existing content. These fixtures are retained locally, not packaged for release.

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

Checked items below refer to Garv's reported second-laptop run. Unchecked items were not established by that report. When testing the current candidate, record its commit, Windows and Unsloth versions, laptop hardware, model, filesystem, and drive letters. Use a spare test SSD and a backed-up, known-good small model cache; keep any working installation intact.

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
- [ ] Repeat the workflow on a physical exFAT drive and record the result.
- [ ] Make a harmless, unique test chat on PC A. On PC B, verify it is absent and that no conversation/export was written to the SSD. Inspect files as well as the UI; record limitations of the check.
- [ ] On PC B, delete only the disposable test model through Unsloth after verifying its SSD cache path. Confirm it is absent on PC A after reconnecting. Do not use an important or sole-copy model for this test.
- [ ] If claiming offline operation, repeat a prompt without network access after confirming the model and runtime are complete.

Attach actual results before checking these boxes. For a public demo, redact user paths, account names, tokens and private model names.
