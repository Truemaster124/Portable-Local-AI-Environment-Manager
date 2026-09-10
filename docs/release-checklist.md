# Release checklist

Use this checklist before tagging a reusable release. Repository publication alone does not establish compatibility or completion of the acceptance tests.

- [x] Add the [MIT License](../LICENSE) for the original launcher code and documentation; retain third-party attribution.
- [ ] Run the automated checks against the exact source being released and inspect the Windows Actions result.
- [x] Record the maintainer's successful second-laptop connection prompt, launch, and model-discovery test with a SanDisk SSD on 11 September 2026.
- [ ] Complete the remaining [manual acceptance tests](testing.md) against the release build, including a recorded drive-letter change and a physical exFAT test.
- [ ] Verify a disposable model's download and deletion through Unsloth and check for unintended transfer of chats or credentials between hosts.
- [ ] Record the tested Windows, Unsloth, filesystem, model, and hardware versions. Keep unsupported combinations and pending tests visible.
- [ ] Review the files being packaged. Exclude real `device.json` files, tokens, chats, databases, logs, model weights, application installations, and test fixtures.
- [ ] Keep one root README, check its local links, and include only documentation assets that are actually used. Preserve third-party image attribution.
- [ ] If adding demo screenshots or recordings, use a real run and remove account details, private paths, and tokens.
- [ ] Update the changelog and review the final source archive before creating a release tag.

Maintain the source checkout separately from the model SSD. Test with a spare drive rather than overwriting a working prototype. The generic connection helper and original prototype watcher must not run together.
