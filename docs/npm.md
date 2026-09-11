# Install and use the npm CLI

The npm package adds the `portable-ai` command to the existing Windows launcher. It has no third-party Node dependencies. It requires **Windows, Node.js 22 or newer, Windows PowerShell 5.1, and an already configured Unsloth Desktop installation**. Install Node.js from [nodejs.org](https://nodejs.org/en/download).

This is a release candidate that has not been published to the npm registry. Install directly from GitHub now, or use a locally built `.tgz`. The public package-name commands below work only after the maintainer publishes this version under that name. npm does not install Unsloth, its runtime, GPU drivers, or model weights.

## Install directly from GitHub

```powershell
npm.cmd install --global "https://github.com/Truemaster124/Portable-Local-AI-Environment-Manager/archive/refs/heads/main.tar.gz"
portable-ai.cmd --help
```

This downloads the source archive through npm, so no manual ZIP extraction or npm-registry publication is needed. The command selects the current `main` branch. For a reproducible install, replace `refs/heads/main` in that URL with a reviewed full commit SHA. A GitHub source archive includes the repository's documentation assets; the smaller `npm pack` tarball uses the explicit package file allowlist.

## Install a local release tarball

If you received a `.tgz` release file or built it with `npm pack`, open a terminal in its folder:

```powershell
npm.cmd install --global ".\portable-local-ai-environment-manager-0.3.0-rc.1.tgz"
portable-ai.cmd --help
```

No ZIP extraction is needed. You can also install from the extracted source directory with `npm.cmd install --global .`.

## Set up the SSD

Replace `E:` with your external drive's current letter:

```powershell
portable-ai.cmd setup --drive E:
portable-ai.cmd check --drive E:
portable-ai.cmd launch --drive E:
```

Run setup in an interactive terminal. It copies the portable launcher files to the SSD root, displays the selected drive and model path, and asks you to type **PAIR**. By default, the cache is `AI\Models\huggingface\hub` relative to the SSD. For a different folder or display name:

```powershell
portable-ai.cmd setup --drive E: --model-path "AI\My Models\hub" --name "My AI SSD"
```

Setup checks the entire payload for conflicts before copying. Matching files can be reused. Different files, redirected paths, system/profile volumes, non-root paths, and unsupported filesystems are refused. It never overwrites an existing pairing or model file. Cancelling at the PAIR prompt leaves the copied launcher files on the drive; rerun setup when ready. A disconnected drive or interrupted copy can leave a partial payload: reconnect and rerun setup. If a file is incomplete, retain a backup and follow the replacement procedure below.

A paired drive can be verified with `setup --drive E:` again. Do not include `--model-path` or `--name` for an already paired drive; setup does not change its configuration. Use `check` for readiness diagnostics. `check` returns exit code 1 if prerequisites or checks fail and reports the problems as JSON. A successful check does not prove that a model can load.

Use the current drive letter with CLI commands. The desktop shortcut and optional connection helper retain the original launcher's drive-discovery behavior. A drive letter change does not require pairing again.

## Optional commands

```powershell
portable-ai.cmd shortcut --drive E:
portable-ai.cmd popup-install --drive E:
portable-ai.cmd popup-remove --drive E:
```

Each command retains the existing launcher's checks and confirmation behavior. Installing the npm package does not create a desktop shortcut or start a background helper. The copied `.cmd` files continue to work without Node.js on another prepared Windows PC.

## Public registry commands after publishing

Only after this version has been published under the configured name:

```powershell
npm.cmd install --global portable-local-ai-environment-manager@next
portable-ai.cmd setup --drive E:
```

Or use a pinned release without a permanent global installation:

```powershell
npx.cmd --yes --package portable-local-ai-environment-manager@0.3.0-rc.1 portable-ai setup --drive E:
```

Before publication, the local tarball also works with `npm exec`:

```powershell
npm.cmd exec --yes --package ".\portable-local-ai-environment-manager-0.3.0-rc.1.tgz" -- portable-ai --help
```

## Updates and removal

Install a newer release tarball with the same global install command. After publication, `npm.cmd install --global portable-local-ai-environment-manager@next` selects the current release candidate. Runtime scripts on the SSD must match the npm package before it will execute them.

This first npm release retains launcher runtime `0.2.1-rc.3` unchanged. An existing SSD can be used directly when its runtime files match the installed npm copy byte for byte. GitHub archives and Git checkouts may use different line endings; a mismatch is deliberately reported even when the version is the same. Future runtime changes may also require replacement. No automatic in-place overwrite is provided:

1. Close Unsloth and any launcher prompts. If enabled, disable the old connection popup using its existing removal command first.
2. Back up `T5-Launcher` and the six launcher `.cmd` files to a separate ordinary folder. Keep the original `device.json` pairing marker.
3. Remove only the old runtime files from the SSD's `T5-Launcher` folder, retaining `device.json`. Move the six old `.cmd` files into the backup. Keep model/cache directories in place.
4. Run the new npm version's `setup --drive E:`. It validates the retained pairing and adds the new files without re-pairing. If `LICENSE` differs, back up that file separately before retrying.
5. Run `check` and test a launch. Existing local desktop/helper copies are separate installations; follow [setup.md](setup.md) for their deliberate replacement. This npm wrapper does not bypass their version checks.

To remove the CLI:

```powershell
npm.cmd uninstall --global portable-local-ai-environment-manager
```

Disable the optional popup before uninstalling if you no longer want it. npm uninstall removes the npm package and command; it leaves the SSD, models, pairing, desktop shortcut, and separately installed helper intact. The copied `Remove-T5-Connection-Popup.cmd` can still disable the helper afterwards.

## Troubleshooting

| Message or symptom | Action |
| --- | --- |
| npm or portable-ai PowerShell script is blocked | Use `npm.cmd`, `npx.cmd`, and `portable-ai.cmd` as shown. You do not need a persistent execution-policy change. Organization policy may still prohibit scripts. |
| Command not found after installation | Reopen the terminal and check `npm.cmd prefix --global`. Its Windows command directory must be on PATH. |
| npm install folder contains `&` and the CMD shortcut fails | npm 11.16.0's generated CMD shortcut does not quote one internal path assignment. Use the generated `portable-ai.ps1` when your execution policy allows it, or install into an npm prefix without `&`. The adapter itself accepts spaces and punctuation in data values. |
| Windows only / `EBADPLATFORM` | This release does not support Ubuntu, macOS, or iOS. npm packaging does not port the Windows runtime. |
| Existing file differs | Use the matching release or the deliberate replacement steps above. Do not force an overwrite of a different installation. |
| Setup needs an interactive terminal | Run setup directly in a terminal so the original PAIR confirmation is available. |
| Missing or disconnected drive | Check the current drive letter, connection, and whether the drive is unlocked. |
| Unsloth setup or readiness failure | Read the JSON problems from `check` and the existing [setup guide](setup.md). |

## Maintainer workflow

From the extracted repository:

```powershell
npm.cmd ci
npm.cmd test
npm.cmd run test:launcher
npm.cmd run test:package
npm.cmd pack
```

`test:package` creates a disposable install prefix and cache under `test-results`, validates the actual tarball, tests its command shim and `npm exec`, and uninstalls from that prefix. It never installs into your normal global npm directory. `npm pack` runs the npm test suite first.

Before a public release, choose an available name (or your npm scope), review package metadata and the tarball, and test pairing and a real model launch on a spare SSD. Name ownership has not been checked. After signing in with your own npm account, publish from the source directory using `npm.cmd publish --tag next`. The `prepublishOnly` gate runs npm, launcher, and package tests before publication. Promote a tested stable version separately; this prerelease defaults to the `next` tag.

Keep `package.json`'s explicit `files` allowlist and `npm/payload.json` in sync when adding runtime assets. Pairings, credentials, model weights, logs, tests, and large documentation images are excluded from the npm tarball. Never add an install lifecycle script to perform drive setup automatically.

The CLI transports options as JSON in a child-only environment variable and starts Windows PowerShell directly, without interpolating user input into shell source. It lets Windows PowerShell build its own module path, avoiding inherited PowerShell 7 module conflicts.

References: [npm package metadata and executable mapping](https://docs.npmjs.com/cli/v11/configuring-npm/package-json/), [npm pack](https://docs.npmjs.com/cli/v11/commands/npm-pack/), [Node.js child processes](https://nodejs.org/api/child_process.html).
