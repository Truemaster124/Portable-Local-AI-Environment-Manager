# Before the first public release

This folder is a publication candidate, not a published release.

- [ ] Choose a license for the original launcher code and add its full text as `LICENSE`. No license choice is assumed in this draft.
- [ ] Complete and record the manual acceptance tests, especially the second-computer test.
- [ ] Verify a disposable model's download and deletion through Unsloth, plus the two-computer chat-isolation test.
- [ ] Review every file being committed. Keep this source folder separate from the actual model drive.
- [ ] Check that no real `device.json`, filesystem identifiers, tokens, chats, app databases, logs, model weights or installed applications are included. `.gitignore` helps, but it is not a security scanner.
- [ ] Add a short recording or sanitized screenshots from a real run. Don't substitute a mockup for test evidence.
- [ ] If adding the personal PDF manual, first remove account details and machine-specific identifiers, and update its instructions for this generalized version. It is intentionally not bundled here.
- [ ] Choose the GitHub repository name and visibility. Suggested name: `portable-local-ai-launcher`.
- [ ] Review the initial commit, then publish only with the owner's approval.
- [ ] Check the first Windows Actions run before adding a passing CI badge or tagging a release.

Only source and documentation belong in this repository. The original storage migration and drive-formatting scripts are not part of the product.

The public helper uses `%LOCALAPPDATA%\PortableLocalAI` and its own Startup shortcut. It must not be installed alongside an active prototype watcher during testing; two different helpers can produce two prompts.
