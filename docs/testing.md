# Testing notes

Latest automated source check: 10 September 2026. The repository cleanup passed all 97 checks under Windows PowerShell 5.1.26100.9444. The installed-backend probe and original prototype results below were recorded on 8 September 2026 and were not rerun for this documentation cleanup.

## This repository

`tests/Test-Launcher.ps1` passed **97 checks** under Windows PowerShell **5.1.26100.9444**.

The checks cover script parsing, malformed configuration, unsafe relative paths, registry path parsing, path construction with several simulated drive letters, child-only credential isolation, preserved offline settings, and direct process configuration without shell interpolation. Module-scoped test doubles exercise wrong-drive rejection, executable-volume rejection, declined consent, the already-running guard and disconnecting during the prompt. Privacy checks cover redirected private state, token-variable removal and blocking launch on preflight failure. One read-only native Windows check resolves the host PowerShell executable's volume.

Cache-preparation tests create disposable fixtures in the ignored `test-results/` directory: a missing cache, an empty cache, an unrelated folder, a file at the intended destination and a basic snapshot layout. They verify that planning is read-only and preserves a refused folder's existing content. These fixtures are retained locally, not packaged for release.

These are local automated checks. Simulating `F:` or `Z:` is not the same as physically reconnecting a drive with a new letter. The tests deliberately do not start Unsloth, pair a real SSD, or install the watcher.

The GitHub Actions workflow is prepared, but there is no remote CI result or badge to claim yet.

## Installed-backend probe

The optional `tests/Probe-Unsloth-Cache.ps1` passed seven checks using the installed Unsloth Python, its `utils/hf_cache_settings.py` and the installed Hub library: explicit cache selection, the Hub path, the auxiliary cache path, a host-local token path, removal of inherited raw Hub tokens, and the Hub library's resolved credential-home and token-file constants. It uses a synthetic cache location and does not scan or modify models. A separate read-only host privacy preflight also passed.

The installed source was inspected for model operations: `hub/services/models/downloads.py` takes its cache from `get_hf_cache_paths()`, and `hub/services/models/deletion.py` resolves the selected cache owner before deletion. This supports the routing design. No real UI download or deletion was exercised for this release.

## What came from the original prototype

The device-specific predecessor was checked on one laptop with Unsloth Desktop `0.1.806-beta`. A read-only probe using its installed backend's cache-resolution code discovered 29 cached repositories, with 10 cache warnings. Discovery is not proof that all 29 models can load or run. Those warnings need separate investigation.

That predecessor also had its own 41-check suite. Those results are historical context, not extra passing checks for this generalized release. Private file manifests, model lists, logs and database backups are not included here.

## Manual acceptance test still needed

Use a spare test SSD and a backed-up, known-good small model cache. Do not replace a working prototype to test this version.

- [ ] Pair the test SSD, then confirm that rerunning setup refuses to overwrite its marker.
- [ ] Start with an empty cache and download a small public model from Unsloth. Verify the new files are on the paired SSD, not a remembered host cache.
- [ ] Decline the launch prompt and confirm no Unsloth process starts.
- [ ] Accept it, choose the local app if needed, and verify the model in **On Device**.
- [ ] Load the small model and complete one prompt. Record the app version, model, RAM, GPU and VRAM.
- [ ] Repeat with Unsloth already open. Confirm the launcher asks you to quit rather than stopping it.
- [ ] Install the popup helper. Reconnect safely and confirm one prompt; decline and confirm it stays quiet.
- [ ] Sign out and back in; confirm the helper starts. Remove it and confirm future insertions stay quiet.
- [ ] Disconnect while the consent prompt is open. Confirm accepting afterward does not launch against the missing cache.
- [ ] Repeat on a second prepared Windows computer where the SSD receives a different drive letter.
- [ ] Make a harmless, unique test chat on PC A. On PC B, verify it is absent and that no conversation/export was written to the SSD. Inspect files as well as the UI; record limitations of the check.
- [ ] On PC B, delete only the disposable test model through Unsloth after verifying its SSD cache path. Confirm it is absent on PC A after reconnecting. Do not use an important or sole-copy model for this test.
- [ ] If claiming offline operation, repeat a prompt without network access after confirming the model and runtime are complete.

Attach actual results before checking these boxes. For a public demo, redact user paths, account names, tokens and private model names.
