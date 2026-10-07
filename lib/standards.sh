#!/usr/bin/env bash

# Downloads the development standards into the working directory.
#
# Source and branch come from STANDARDS_REPO / STANDARDS_REF (set in
# generate_context.sh, both overridable via environment).
#
# Two ways to fetch, in this order:
#   1. gh api  — works for private repositories and respects an existing login
#   2. curl    — works for public repositories without any authentication, so
#                GitLab-only setups do not need the GitHub CLI just for this
fetch_standards() {
    local work_dir="$1"
    echo "Fetching development standards ($STANDARDS_REPO@$STANDARDS_REF)..." >&2

    local tmp
    tmp=$(mktemp "${TMPDIR:-/tmp}/dev-standards.XXXXXX.tar.gz")

    if ! fetch_standards_tarball "$tmp"; then
        rm -f "$tmp"
        die "Standards-Download fehlgeschlagen ($STANDARDS_REPO@$STANDARDS_REF). Repository und Branch prüfen (STANDARDS_REPO, STANDARDS_REF)."
    fi

    local extract_dir="$work_dir/standards_download"
    local target_dir="$work_dir/development_standards"
    mkdir -p "$extract_dir" "$target_dir"
    tar -xz -C "$extract_dir" -f "$tmp"
    rm -f "$tmp"

    # GitHub names the tarball's top directory <owner>-<repo>-<short sha>.
    local src
    src=$(echo "$extract_dir"/*)
    STANDARDS_COMMIT="${src##*-}"

    # Only the reviewer-relevant parts go into the context: the enforceable
    # checklist and the guidelines behind it. Everything else the standards
    # repository carries (README, LICENSE, CONTRIBUTING, .github) would just be
    # noise the reviewer has to read past.
    local part
    for part in ki-reviewer richtlinien; do
        [ -e "$src/$part" ] && cp -R "$src/$part" "$target_dir/"
    done
    rm -rf "$extract_dir"

    [ -d "$target_dir/ki-reviewer" ] || die "Standards-Repository ohne 'ki-reviewer/' ($STANDARDS_REPO@$STANDARDS_REF). Struktur prüfen — siehe README, \"Eigene Standards verwenden\"."
}

fetch_standards_tarball() {
    local target="$1"

    if command -v gh >/dev/null 2>&1 &&
        gh api "repos/$STANDARDS_REPO/tarball/$STANDARDS_REF" > "$target" 2>/dev/null &&
        [ -s "$target" ]; then
        return 0
    fi

    if command -v curl >/dev/null 2>&1 &&
        curl -fsSL "https://codeload.github.com/$STANDARDS_REPO/tar.gz/refs/heads/$STANDARDS_REF" -o "$target" &&
        [ -s "$target" ]; then
        return 0
    fi

    return 1
}
