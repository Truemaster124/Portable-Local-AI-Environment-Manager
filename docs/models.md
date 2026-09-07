# Add and remove models in Unsloth

The launcher supplies a writable model-cache location. Unsloth performs downloads and deletions using its own controls, authentication and safety checks. No custom deletion endpoint or automatic cleanup runs in this repository.

## Add a model

1. Connect the paired SSD, fully quit any existing Unsloth session, and start it with the SSD launcher.
2. Check the active Hub cache in Unsloth's storage/cache settings. It must point to this SSD's selected cache folder. If it points elsewhere, stop; don't test by downloading a large model.
3. Open **Model hub**, find a supported model and use its download action. Labels vary by version. Start with a small public model; gated models may require your own login and access approval.
4. Wait for completion. Keep the SSD connected and leave free space for temporary download data.
5. Confirm the model appears under **On Device** and that the new repository files are in the SSD cache. Then load it and send one short prompt.

The other user can see and use the new model when they connect the same SSD to a prepared host. Their machine still needs enough RAM/VRAM and the right backend.

## Remove a model

1. Unload the model and stop related downloads/training.
2. In Unsloth's model-management view, locate the exact downloaded model or variant.
3. Verify the selected copy belongs to the SSD cache. Unsloth can also show models from the computer's own cache or custom folders. Do not assume every visible model is on the SSD.
4. Use Unsloth's delete/remove-download action and read its confirmation. If the version does not reveal enough information to identify the copy, cancel and inspect the path first.
5. Confirm the model is gone from the intended cache. Treat this deletion as potentially permanent; don't expect the Windows Recycle Bin to hold it.

Deleting a model from the shared SSD removes that copy for **all subsequent users**, not just the current user. Back up a private fine-tune or anything that cannot be downloaded again. The launcher does not provide per-user model ownership or deletion permissions.

## What this does not mean

- **Custom folder removal** can mean removing a scan location, not deleting weight files. Read the application's action text.
- Removing weights does not necessarily delete local chat history. These are different kinds of data.
- Fine-tuning outputs and manual exports do not automatically belong in the shared library. Keep private training data and private models off a drive you lend to other people.
- A list of models is not a compatibility check. Wrong architectures, incomplete files and insufficient memory still cause errors.

## Evidence and remaining test

The inspected Windows backend routes model downloads through its active Hub cache and resolves a cache owner for model deletion. The repository's cache-routing probe passed. A complete real download/delete cycle through the UI has **not** yet been tested for this generic release. Use one disposable model for that acceptance test, not your main collection.
