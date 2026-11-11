#!/bin/sh
# POSIX helper script to stage workshop checkpoint files locally.
# Uses only local filesystem and git commands.
set -eu

usage() {
    echo "Usage: ./.workshop/apply-checkpoint.sh <1|2|3|4|5> [--commit]"
    exit 1
}

if [ "$#" -lt 1 ] || [ "$#" -gt 2 ]; then
    usage
fi

CHECKPOINT="$1"
AUTO_COMMIT="false"

if [ "$#" -eq 2 ]; then
    if [ "$2" = "--commit" ]; then
        AUTO_COMMIT="true"
    else
        usage
    fi
fi

if [ ! -d ".workshop" ] || [ ! -f "pyproject.toml" ]; then
    echo "Error: Run this script from the repository root directory." >&2
    exit 1
fi

COMMIT_MSG=""
TARGET_BRANCH="main"

case "$CHECKPOINT" in
    1)
        mkdir -p .github/workflows/scripts
        cp .workshop/checkpoint-1/scorecard.yml.tmpl .github/workflows/scorecard.yml
        cp .workshop/checkpoint-1/render_scorecard_summary.py.tmpl .github/workflows/scripts/render_scorecard_summary.py
        git add .github/workflows/scorecard.yml .github/workflows/scripts/render_scorecard_summary.py
        COMMIT_MSG="Checkpoint 1: Add OpenSSF Scorecard workflow"
        TARGET_BRANCH="main"
        ;;
    2)
        rm -f bin/cronk-helper .github/workflows/awesome-action.yml
        cp .workshop/checkpoint-2/LICENSE.tmpl LICENSE
        cp .workshop/checkpoint-2/SECURITY.md.tmpl SECURITY.md
        git add -A bin .github/workflows LICENSE SECURITY.md
        COMMIT_MSG="Checkpoint 2: Remove binary artifact and dangerous workflow, add LICENSE and SECURITY.md"
        TARGET_BRANCH="main"
        ;;
    3)
        git checkout -B checkpoint-3
        mkdir -p .github/workflows/requirements
        cp .workshop/checkpoint-3/testing.yml.tmpl .github/workflows/testing.yml
        cp .workshop/checkpoint-3/codeql.yml.tmpl .github/workflows/codeql.yml
        cp .workshop/checkpoint-3/dependabot.yml.tmpl .github/dependabot.yml
        cp .workshop/checkpoint-3/pyproject.toml.tmpl pyproject.toml
        cp .workshop/checkpoint-3/requirements.in.tmpl requirements.in
        cp .workshop/checkpoint-3/requirements.txt.tmpl requirements.txt
        cp .workshop/checkpoint-3/testing.in.tmpl .github/workflows/requirements/testing.in
        cp .workshop/checkpoint-3/testing-requirements.txt.tmpl .github/workflows/requirements/testing.txt
        cp .workshop/checkpoint-3/cron_to_json.py.tmpl src/cronk/cron_to_json.py
        git add \
            .github/workflows/testing.yml \
            .github/workflows/codeql.yml \
            .github/dependabot.yml \
            pyproject.toml \
            requirements.in \
            requirements.txt \
            .github/workflows/requirements/testing.in \
            .github/workflows/requirements/testing.txt \
            src/cronk/cron_to_json.py
        COMMIT_MSG="Checkpoint 3: Add CI tests, CodeQL SAST, Dependabot, and hash-pinned dependencies"
        TARGET_BRANCH="checkpoint-3"
        ;;
    4)
        git checkout -B checkpoint-4
        mkdir -p .github/workflows/requirements
        cp .workshop/checkpoint-4/build.in.tmpl .github/workflows/requirements/build.in
        cp .workshop/checkpoint-4/build-requirements.txt.tmpl .github/workflows/requirements/build.txt
        cp .workshop/checkpoint-4/release.yml.tmpl .github/workflows/release.yml
        git add \
            .github/workflows/requirements/build.in \
            .github/workflows/requirements/build.txt \
            .github/workflows/release.yml
        COMMIT_MSG="Checkpoint 4: Add OIDC release packaging workflow and hash-pinned build requirements"
        TARGET_BRANCH="checkpoint-4"
        ;;
    5)
        git checkout -B checkpoint-5
        mkdir -p .github/workflows
        cp .workshop/checkpoint-5/release.yml.tmpl .github/workflows/release.yml
        git add .github/workflows/release.yml
        COMMIT_MSG="Checkpoint 5: Add SLSA Level 3 provenance generation to release workflow"
        TARGET_BRANCH="checkpoint-5"
        ;;
    *)
        usage
        ;;
esac

echo "=== Staged changes for Checkpoint ${CHECKPOINT} (branch: ${TARGET_BRANCH}) ==="
git status -s
echo ""
git diff --staged --stat
echo ""

if [ "$AUTO_COMMIT" = "true" ]; then
    git commit -m "$COMMIT_MSG"
    echo "Committed: $COMMIT_MSG"
    echo "Next step: git push -u origin $TARGET_BRANCH"
else
    echo "Inspect your staged changes with:"
    echo "  git diff --staged"
    echo ""
    echo "When ready, commit and push with:"
    echo "  git commit -m \"$COMMIT_MSG\""
    echo "  git push -u origin $TARGET_BRANCH"
fi
