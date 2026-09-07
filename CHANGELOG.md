# Changes

## 0.2.0 - local prototype

- Allow pairing a drive with a missing or empty model-cache directory.
- Add `Check-Setup.cmd` for read-only diagnostics.
- Route Hugging Face credentials, temporary files and known project defaults to the host profile for launcher sessions.
- Drop inherited raw Hub token variables from the child process; preserve explicit offline settings.
- Reject known private-state paths outside the local profile or through reparse points.
- Add cache-planning fixtures, privacy tests and an optional installed-backend cache probe.
- Document Unsloth-based download/delete operations, privacy limits and GitHub publishing steps.

This is a source-only update. It has not upgraded the original Samsung T5 installation, completed a second-computer test, or been published to GitHub.

## 0.1 - initial local draft

Generalized the original device-specific launcher with user-created pairing, consent-based launch, a per-user connection watcher and an initial automated test suite. This was not a published release.
