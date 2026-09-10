# Release checklist

Use this checklist before tagging a reusable release. Repository publication alone does not establish compatibility or completion of the acceptance tests.

- [ ] Select a license for the original launcher code and add its full text as `LICENSE`.
- [ ] Run the automated checks against the exact source being released and inspect the Windows Actions result.
- [ ] Complete and record the [manual acceptance tests](testing.md), including a second prepared PC with a different drive letter.
- [ ] Verify a disposable model's download and deletion through Unsloth and check for unintended transfer of chats or credentials between hosts.
- [ ] Record the tested Windows, Unsloth, filesystem, model, and hardware versions. Keep unsupported combinations and pending tests visible.
- [ ] Review the files being packaged. Exclude real `device.json` files, tokens, chats, databases, logs, model weights, application installations, and test fixtures.
- [ ] Keep one root README, check its local links, and include only documentation assets that are actually used. Preserve third-party image attribution.
- [ ] If adding demo screenshots or recordings, use a real run and remove account details, private paths, and tokens.
- [ ] Update the changelog and review the final source archive before creating a release tag.

Maintain the source checkout separately from the model SSD. Test with a spare drive rather than overwriting a working prototype. The generic connection helper and original prototype watcher must not run together.
