# Instructor Guide: 90-Minute OpenSSF Scorecard Workshop (`cronk-template`)

This guide covers the classroom pacing, probe mechanics, fallback branch recovery commands, and pre-semester maintenance checklist for running the **`cronk-template`** hands-on workshop.

---

## 1. Recommended 90-Minute Workshop Timeline

| Time Window | Duration | Segment | Key Instructor Talking Points & Live Milestones |
| :--- | :---: | :--- | :--- |
| **00:00 – 00:10** | 10 min | **Intro & Pre-Flight Setup** | Introduce software supply-chain attacks (solarwinds/xz/malicious PyPI typosquats, CI script injection) and OpenSSF Scorecard. Walk students through clicking **Use this template**, choosing **Public**, and checking **Include all branches**. |
| **00:10 – 00:25** | 15 min | **Checkpoint 1: Baseline Audit** | Students run `./.workshop/apply-checkpoint.sh 1`, push `scorecard.yml` to `main`, and inspect the `$GITHUB_STEP_SUMMARY` table (`~1.2 / 10`) and `scorecard.dev/viewer`. Walk through why `Binary-Artifacts`, `Dangerous-Workflow`, `Token-Permissions`, `Pinned-Dependencies`, and `Vulnerabilities` failed. |
| **00:25 – 00:45** | 20 min | **Checkpoint 2: Quick Wins & Solo Governance** | Show `src/cronk-helper/cronk_helper.c` and `src/cronk-helper/compile.sh` to explain why `bin/cronk-helper` does not belong in Git. Walk through `awesome-action.yml` (`pull_request_target` + `${{ github.event.pull_request.body }}`). Students run `./.workshop/apply-checkpoint.sh 2` and push to `main`. **Together on screen**, configure the **0-approver GitHub Repository Ruleset** on `main`. |
| **00:45 – 01:10** | 25 min | **Checkpoint 3: CI, CodeQL SAST & Hash Pinning (PR #1)** | Explain proportional PR scoring (`totalTested / totalMerged`) and why `pip install --no-deps --no-build-isolation -e .` is required by Scorecard's shell AST parser. Students run `./.workshop/apply-checkpoint.sh 3`, open **PR #1**, **wait for green `Python package` and `CodeQL` checks**, and merge (`~7.8 / 10`). |
| **01:10 – 01:25** | 15 min | **Checkpoint 4: Trusted Packaging via OIDC (PR #2)** | Explain PyPI OIDC Trusted Publishing (`id-token: write`) vs. long-lived API tokens. Students run `./.workshop/apply-checkpoint.sh 4`, merge **PR #2**, trigger `Release` via `workflow_dispatch`, and trigger `Scorecard` via `workflow_dispatch` (`~8.3 / 10`). |
| **01:25 – 01:30+** | 5–30 min | **Debrief & Optional Checkpoint 5 (SLSA L3)** | Review the *"Why Isn't My Overall Score 10.0?"* table in `WORKSHOP.md` (`Maintained`, `Contributors`, `Code-Review`). Fast finishers can run `./.workshop/apply-checkpoint.sh 5` and push tag `v0.0.1` to generate a `.intoto.jsonl` SLSA Level 3 provenance attestation (`Signed-Releases: 10/10`). |

---

## 2. Key Technical Talking Points & Scorecard Probe Mechanics

### Why `src/cronk-helper/` Stays When `bin/cronk-helper` Is Deleted (Checkpoint 2)
At baseline, `bin/cronk-helper` is a compiled 64-bit ELF executable checked into Git alongside its C source (`src/cronk-helper/cronk_helper.c`) and local compile script (`src/cronk-helper/compile.sh`).
- **Teaching point:** Reviewers cannot audit a compiled ELF binary in a Pull Request diff to verify that it matches `cronk_helper.c`. Because `src/cronk-helper/compile.sh` can build the binary on demand from source (`gcc -O2 -Wall -o ../../bin/cronk-helper cronk_helper.c`), deleting `bin/cronk-helper` from version control in Checkpoint 2 loses zero functionality while raising `Binary-Artifacts` from `0/10` to `10/10`.
- **Scanner detail:** `src/cronk-helper/compile.sh` uses only local POSIX commands (`cd`, `mkdir`, `gcc`) and zero network downloaders, so Scorecard's `Pinned-Dependencies` shell AST parser scores it `10/10`.

### Why the 0-Approver Repository Ruleset Comes at the End of Checkpoint 2
1. **No Personal Access Token Required:** Legacy GitHub Branch Protection rules return `HTTP 403` when queried by the default `GITHUB_TOKEN`. GitHub Repository Rulesets (`Settings -> Rules -> Rulesets`) are readable by the default `GITHUB_TOKEN`.
2. **Solo PR Workflow:** Setting **Required approvals = 0** under *Require a pull request before merging* enforces the PR workflow and blocks direct pushes/force-pushes to `main` while allowing solo students to merge their own PRs without waiting on a classmate.
3. **`1/1 = 100%` Tested PR Ratio:** Scorecard calculates `CI-Tests` and `SAST` across all merged PRs (`totalTested / totalMerged`). Pushing Checkpoints 1 and 2 directly to `main` keeps `totalMerged == 0` until the Ruleset is enabled, so PR #1 in Checkpoint 3 is the very first merged PR and achieves `10/10` on both `CI-Tests` and `SAST`.

### Why `release.yml` Uses `if: vars.ENABLE_PYPI_PUBLISH == 'true'` (Checkpoint 4)
Scorecard's `Packaging` check requires both:
1. An uncommented step in `.github/workflows/release.yml` with `uses: pypa/gh-action-pypi-publish@<sha>`.
2. At least one completed workflow run of `release.yml` with `conclusion == "success"`.

Scorecard's YAML workflow parser (`checks/fileparser/github_workflow.go`) inspects `step.Uses` and `step.With` and ignores `step.If`. Gating the upload step with `if: vars.ENABLE_PYPI_PUBLISH == 'true'` and adding `workflow_dispatch:` allows students to run `Release` in class—building the wheel and sdist via `python -m build --no-isolation` and exiting `0` (`Packaging: 10/10`) without failing on TestPyPI authentication or creating an unsigned GitHub Release (which would flip `Signed-Releases` from `-1` to `0/10`).

---

## 3. Classroom Troubleshooting & Recovery Commands

### Scenario A: A Student Forgot to Check "Include all branches"
Have the student add the upstream template repository as a remote and fetch the pre-built checkpoint branches:
```sh
git remote add upstream https://github.com/<INSTRUCTOR-ORG>/cronk-template.git
git fetch upstream
```

### Scenario B: A Student Merged PR #1 Before `Python package` or `CodeQL` Finished
Because `CI-Tests` and `SAST` average over the last 30 merged PRs, merging PR #1 before checks finish results in `0/1` (`0/10`), and merging PR #2 in Checkpoint 4 raises it to `1/2` (`5/10`).
- **Explain to the student:** This is an authentic demonstration of how Scorecard measures historical PR hygiene rather than just whether a workflow file exists.

### Scenario C: GitHub Actions Runners Are Backlogged During the Lecture
If GitHub Actions experiences a runner queue delay during class:
1. Show the pre-built branches (`workshop/checkpoint-1` through `workshop/checkpoint-5`) on the instructor's repository.
2. Point out the `$GITHUB_STEP_SUMMARY` tables on the instructor repository's completed Actions runs so the lecture can proceed without stalling on live runner queues.

---

## 4. Pre-Semester Maintenance Checklist

Before running this workshop in a new semester, verify the following in `cronk-template`:

1. **OSV Vulnerability Check on Checkpoint 3 & 4 Lockfiles:**
   Verify that `.workshop/checkpoint-3/requirements.txt.tmpl`, `.workshop/checkpoint-3/testing-requirements.txt.tmpl`, and `.workshop/checkpoint-4/build-requirements.txt.tmpl` report zero vulnerabilities with `osv-scanner`:
   ```sh
   osv-scanner scan source -L requirements.txt:.workshop/checkpoint-3/requirements.txt.tmpl
   osv-scanner scan source -L requirements.txt:.workshop/checkpoint-3/testing-requirements.txt.tmpl
   osv-scanner scan source -L requirements.txt:.workshop/checkpoint-4/build-requirements.txt.tmpl
   ```
   *(Whereas the baseline root `requirements.txt` on `main` SHOULD still report `CVE-2021-42771` and `CVE-2022-0329`.)*
2. **GitHub Actions Runner Deprecations:**
   Ensure all action SHAs in `.workshop/checkpoint-{1,3,4,5}/*.yml.tmpl` (`actions/checkout`, `actions/setup-python`, `actions/upload-artifact`, `actions/download-artifact`, `github/codeql-action`, `ossf/scorecard-action`, `pypa/gh-action-pypi-publish`) remain supported on `ubuntu-latest`.
3. **Rebuild `workshop/checkpoint-1` Through `workshop/checkpoint-5` Branches After Any Template Edit:**
   Whenever any file in `.workshop/` or `main` is updated, regenerate the five fallback branches (`workshop/checkpoint-1` through `workshop/checkpoint-5`) from `main`, delete the temporary `checkpoint-3..5` working branches, and push `main` and `workshop/checkpoint-1..5` to the template repository.
