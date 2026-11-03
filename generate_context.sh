#!/usr/bin/env bash

# Drupal AI Code-Review — context generator

set -o pipefail

# Development standards source. Override both to point the review at your own
# standards repository (see README, "Eigene Standards verwenden").
STANDARDS_REPO="${STANDARDS_REPO:-Effective-Bytes/development-standards}"
STANDARDS_REF="${STANDARDS_REF:-main}"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# --- parse flags ------------------------------------------------------------
# --provider github|gitlab  override auto-detection
# --mr <number|url>         GitLab fork workflow: MR number on the upstream project
while [ $# -gt 0 ]; do
    case "$1" in
        --provider=*) GIT_PROVIDER="${1#--provider=}"; shift ;;
        --provider)   GIT_PROVIDER="${2:-}"; shift 2 ;;
        --mr=*)       GL_MR_NUMBER="${1#--mr=}"; shift ;;
        --mr)         GL_MR_NUMBER="${2:-}"; shift 2 ;;
        *)            shift ;;
    esac
done
export GIT_PROVIDER GL_MR_NUMBER

# --- source shared helpers and detect provider ------------------------------
# shellcheck source=lib/utils.sh
source "$SCRIPT_DIR/lib/utils.sh"

PROVIDER=$(detect_provider)
echo "Provider: $PROVIDER" >&2
# shellcheck source=lib/provider_github.sh
source "$SCRIPT_DIR/lib/provider_${PROVIDER}.sh"

# shellcheck source=lib/preflight.sh
source "$SCRIPT_DIR/lib/preflight.sh"
# shellcheck source=lib/standards.sh
source "$SCRIPT_DIR/lib/standards.sh"
# shellcheck source=lib/pr_context.sh
source "$SCRIPT_DIR/lib/pr_context.sh"
# shellcheck source=lib/diff.sh
source "$SCRIPT_DIR/lib/diff.sh"
# shellcheck source=lib/file_tree.sh
source "$SCRIPT_DIR/lib/file_tree.sh"
# shellcheck source=lib/environment.sh
source "$SCRIPT_DIR/lib/environment.sh"

# --- locate project root ----------------------------------------------------
PROJECT_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
cd "$PROJECT_ROOT" || die "Konnte nicht in das Projektverzeichnis wechseln."

# --- working directory ------------------------------------------------------
WORK_DIR="$PROJECT_ROOT/.drupal-review"
rm -rf "$WORK_DIR"
mkdir -p "$WORK_DIR/context"

GIT_DIR_PATH="$(git rev-parse --absolute-git-dir 2>/dev/null)"
if [ -n "$GIT_DIR_PATH" ]; then
    mkdir -p "$GIT_DIR_PATH/info"
    if ! grep -qxF '.drupal-review/' "$GIT_DIR_PATH/info/exclude" 2>/dev/null; then
        printf '%s\n' '.drupal-review/' >> "$GIT_DIR_PATH/info/exclude"
    fi
fi

# --- run phases -------------------------------------------------------------
run_preflight "$PROVIDER"

if ! provider_mr_exists; then
    echo "ERROR: kein PR/MR für den aktuellen Branch '$(git branch --show-current 2>/dev/null)'." >&2
    echo "       Branch auschecken (z.B. 'gh pr checkout <nr>') und erneut ausführen." >&2
    exit 1
fi

fetch_standards "$WORK_DIR"
generate_pr_context "$WORK_DIR"
CHANGED_FILES=$(generate_diff "$WORK_DIR")
generate_file_tree "$WORK_DIR" "$CHANGED_FILES"
generate_environment_meta "$WORK_DIR" "$CHANGED_FILES"

echo "Context files generated in $WORK_DIR/context/" >&2
echo "DRUPAL_REVIEW_WORKDIR=$WORK_DIR"
