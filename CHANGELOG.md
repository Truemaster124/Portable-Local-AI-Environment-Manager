# Changes

## npm 0.3.0-rc.1 - 2026-09-11

- Add a dependency-free npm package and `portable-ai` CLI for setup, diagnostics, launch, desktop shortcut, and optional connection-popup management.
- Preserve the existing Windows runtime (`0.2.1-rc.3`) and ZIP workflow unchanged.
- Validate the destination volume, check all payload conflicts before copying, preserve pairing/model files, and reject mismatched SSD runtime scripts.
- Pass CLI input as JSON data to Windows PowerShell and avoid inherited PowerShell 7 module-path conflicts.
- Add npm unit/installer tests, a real tarball/global-install/npx/uninstall smoke test, Windows Node CI, and maintainer documentation.
- Package is an unpublished Windows-only release candidate; physical SSD setup and model generation through the new npm route still need acceptance testing.

## 0.2.1-rc.3 - 2026-09-11

- Add an optional Portable Local AI desktop shortcut with a custom drive-and-play icon. It discovers the paired SSD at launch instead of storing its drive letter.
- Keep the desktop launcher's files on the host and reuse the existing confirmation and privacy checks. Refuse missing or ambiguous drives and unrelated files at installation destinations.
- Add a matching README button that opens the launcher source, plus shortcut setup and removal instructions.
- Expand the automated suite to 177 checks, including native Windows shortcut creation and readback in disposable folders. Physical shortcut acceptance remains on the test checklist.

## Documentation visuals - 2026-09-11

- Add matching storage and shared-drive privacy illustrations using the existing navy, cyan, and amber theme.
- Replace the old SSD reference photograph with the supplied Samsung T7 Shield product image.
- Simplify the credits and clarify which third-party images and marks are outside the code license.

## 0.2.1-rc.2 - 2026-09-11

- Record Garv's successful second-laptop test with a SanDisk SSD: the connection prompt appeared, accepting it launched Unsloth, and the SSD models appeared under On Device.
- Read the saved application path as UTF-8. Windows PowerShell could otherwise forget an Unsloth location containing accented characters and ask for it again.
- Add regression checks for saved app paths containing spaces and accented characters, bringing the automated suite to 147 checks.
- Use "SSD" in connection prompts and launch errors so the wording fits SanDisk and other drives. Keep existing filenames for compatibility.

The second-laptop report confirms launch and discovery. Remaining physical acceptance checks and the unrecorded test-environment details are listed in `docs/testing.md`.

## 0.2.1-rc.1 - 2026-09-11

- Add the MIT license and rewrite the README with clearer setup steps, launch options, and expandable help. Keep both existing illustrations unchanged.
- Reject invalid configuration types, reserved Windows names, network executables, and redirected executable paths. Read pairing files as UTF-8 and limit their size.
- Write helper state atomically, tolerate brief file-sharing conflicts, and prevent log failures from stopping the watcher.
- Recheck the SSD after installation consent and the executable before launch. Stop a watcher launch if the helper is disabled while its prompt is open.
- Return useful readiness results and failing exit codes from diagnostics; preserve those codes through the command wrappers.
- Scope prompt and watcher locks to the Windows user. Release the process handle after launch, and treat a failed launch record as a warning after the app has already started.
- Expand automated coverage from 97 to 145 checks and run CI in both Windows PowerShell and PowerShell 7. Rerun the seven-check installed-backend probe.

This candidate still needs the physical acceptance tests in `docs/testing.md` before a production release.

## Documentation cleanup - 2026-09-10

- Remove a duplicate README and eight unused documentation graphics.
- Shorten the README and consolidate outdated publishing instructions into the release checklist.
- Ignore common editor backups and operating-system metadata.
- Preserve launcher behavior, tests, and the current attributed SSD photograph.

## 0.2.0 - local prototype

- Allow pairing a drive with a missing or empty model-cache directory.
- Add `Check-Setup.cmd` for read-only diagnostics.
- Route Hugging Face credentials, temporary files and known project defaults to the host profile for launcher sessions.
- Drop inherited raw Hub token variables from the child process; preserve explicit offline settings.
- Reject known private-state paths outside the local profile or through reparse points.
- Add cache-planning fixtures, privacy tests and an optional installed-backend cache probe.
- Document Unsloth-based download/delete operations, privacy limits and GitHub publishing steps.

At the time of this local prototype entry, the source update had not upgraded the original Samsung T5 installation, completed a second-computer test, or been published to GitHub.

## 0.1 - initial local draft

Generalized the original device-specific launcher with user-created pairing, consent-based launch, a per-user connection watcher and an initial automated test suite. This was not a published release.
