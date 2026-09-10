# A short classroom or interview demo

## Explain the problem first

"My models were filling an internal drive. Moving them to an SSD saved space, but the applications still needed a reliable way to find them. I built a Windows launcher that pairs the SSD and passes its current cache path to the local Unsloth installation."

That is the contribution. Don't describe the SSD as a computer or say the project implements Unsloth's inference engine.

## Show the working path

Once the manual acceptance test passes on your demo setup:

1. Show that Unsloth is installed on the host and the model cache is on the SSD. Hide private folders.
2. Connect the paired SSD. Open `Start-Unsloth-With-T5.cmd`, or demonstrate the popup on a host where the helper was installed earlier.
3. Read the consent prompt. Explain that the path comes from this insertion's drive location.
4. Accept, open **On Device**, and run one short prompt with a model that fits the host.
5. Open `New-T5StartInfo` in the module. Point out the child-process environment and `UseShellExecute = false`.
6. Close the application and eject safely. Finish by showing the test script and the unfinished manual-test checklist.

## Questions worth preparing for

**Why not just download the models again?**

You can. The benefit is reusing a prepared collection without downloading another copy on each host. Each host still needs the application, dependencies and enough memory.

**Is it really plug-and-play?**

It is a one-click launcher on a prepared Windows host. An insertion popup needs a one-time helper installation for that Windows account. It isn't automatic on an arbitrary computer.

**Does it work without the internet?**

Potentially, when the model files and runtime dependencies are complete and the application supports that operation offline. The launcher preserves offline settings but doesn't guarantee or enforce network isolation.

**What was the important design decision?**

Keeping model storage separate from application state. The launcher sets the cache for a new process rather than moving another computer's accounts or editing its model database.

**What would you improve next?**

Launch and model discovery have been reported working on a second Windows laptop with a SanDisk SSD. The next checks are generation, download and deletion, privacy across hosts, and more machine and filesystem combinations. Signed releases, better cache-health diagnostics, and a reviewed helper upgrade path remain future work.

**Did you use AI tools?**

Yes, for implementation and documentation assistance. Explain the parts you understand and verified. Be ready to trace pairing, consent, cache selection and failure handling in the code.

## Suggested project description

"Windows launcher for reusing an external SSD's Hugging Face model cache with local Unsloth Desktop. Includes drive pairing, consent-based startup, an optional per-user connection watcher, and automated configuration and safety checks."
