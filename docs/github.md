# Put this project on GitHub

Keep the source checkout on your computer. The SSD copy is for using models; it is not the folder you should upload wholesale.

## 1. Review the project

Read the README and run the Windows tests. Follow the manual test checklist with a disposable model and a second computer. If you publish before finishing those tests, leave the prototype status and unchecked items visible.

Choose a code license and add its full text as `LICENSE` before presenting this as a reusable open-source release. The draft doesn't make that choice for you. Keep the Unsloth/Hugging Face credits and the short development-assistance note.

## 2. Create an empty repository

Suggested name: `portable-local-ai-launcher`.

Suggested description:

> Windows launcher for sharing an external SSD's model cache with local Unsloth Desktop, with drive pairing and guarded host-local application state.

Choose the visibility you want. If you are going to push this local source folder, don't ask GitHub to generate another README or other initial files. [GitHub's repository-creation guide](https://docs.github.com/en/repositories/creating-and-managing-repositories/creating-a-new-repository).

## 3. Publish the reviewed source

Open a terminal **inside the source repository**, not at the SSD root. If you extracted a ZIP, initialize Git first:

```powershell
git init
```

Then review and commit the intended files:

```powershell
git add README.md CHANGELOG.md .gitignore .gitattributes .github T5-Launcher docs tests *.cmd
git add LICENSE
git diff --cached --check
git diff --cached --stat
git status
git commit -m "Add portable model-cache launcher and setup guide"
git branch -M main
```

Only run `git add LICENSE` after you have actually added your chosen license. If Git asks for author identity, use your own name and preferred commit email. Do not invent previous commits or backdate development history.

Connect your empty GitHub repository, replacing `YOUR-USERNAME` with your actual account:

```powershell
git remote add origin https://github.com/YOUR-USERNAME/portable-local-ai-launcher.git
git remote -v
git push -u origin main
```

If `origin` already exists, inspect it first instead of replacing it blindly. Authenticate through Git's normal sign-in flow; never paste a token into a source file or commit it.

These are instructions for you. Preparing this folder did not create or publish a remote repository.

## 4. Make the page useful in an interview

- Add a short recording of a real launch and one model response. Hide account details, private file paths and tokens.
- Keep the README short; the setup, privacy, code and testing guides are already linked near the top.
- Add relevant topics such as `powershell`, `windows`, `local-ai`, `unsloth` and `huggingface`.
- Check the first Actions run before displaying a passing CI badge.
- Tag a release only after testing its exact code. List the tested Windows and Unsloth versions in the release notes.

Don't upload your entire SSD, installed Unsloth, models, user profile, old chat databases, drive-formatting scripts, or the personal PDF manual without a separate privacy review.

## 5. What to say about the work

Explain the original storage problem, why fixed drive letters were fragile, how process-specific cache routing works, and why application state stays local. Demonstrate a failure case as well as a successful launch. Clear limits and reproducible tests make a stronger project than a claim that it works on every computer.
