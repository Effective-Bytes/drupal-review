#!/usr/bin/env bash
# GitLab provider — implements the provider interface via glab CLI
#
# Fork workflow support:
#   The MR lives on the upstream project; the feature branch lives in the fork.
#   We maintain two separate project references:
#     _gl_local_*  — the repo you cloned (fork or main), used for commit/branch ops
#     _gl_mr_*     — the project that owns the MR (auto-detected upstream or same as local)
#
# Optional env vars (set by generate_context.sh arg parser):
#   GL_MR_NUMBER  — explicit MR number (required when running from a fork)
#   GL_MR_REPO    — explicit MR project (namespace/project), skips auto-detection

provider_auth_check() {
    glab auth status >/dev/null 2>&1 \
        || die "GitLab CLI nicht authentifiziert. 'glab auth login' ausführen."
}

provider_mr_exists() {
    _gl_mr_json | jq -e '.iid' >/dev/null 2>&1
}

# ---------------------------------------------------------------------------
# Internal: local repo (the repo you cloned — fork or upstream)
# ---------------------------------------------------------------------------

_gl_local_repo_path() {
    local remote_url
    remote_url=$(git remote get-url origin 2>/dev/null || true)
    printf '%s' "$remote_url" \
        | sed 's|^https\?://[^/]*/||; s|^git@[^:]*:||; s|\.git$||'
}

_gl_local_encoded_path() {
    printf '%s' "$(_gl_local_repo_path)" | jq -rR '@uri'
}

# ---------------------------------------------------------------------------
# Internal: MR repo (upstream project that owns the MR)
# ---------------------------------------------------------------------------

# Memoized: set once in _gl_init, then read-only
_GL_MR_REPO_PATH=""

_gl_mr_repo_path() {
    printf '%s' "$_GL_MR_REPO_PATH"
}

_gl_mr_encoded_path() {
    printf '%s' "$_GL_MR_REPO_PATH" | jq -rR '@uri'
}

# Detect upstream project for a fork via GitLab API
_gl_detect_fork_upstream() {
    local encoded
    encoded=$(_gl_local_encoded_path)
    glab api "projects/${encoded}" 2>/dev/null \
        | jq -r '.forked_from_project.path_with_namespace // empty'
}

# Called once at startup (by run_preflight after auth) to wire up MR repo path
# and auto-detect the MR number from the current branch when running from a fork.
_gl_init() {
    # Explicit repo override wins
    if [ -n "${GL_MR_REPO:-}" ]; then
        _GL_MR_REPO_PATH="$GL_MR_REPO"
    else
        local upstream
        upstream=$(_gl_detect_fork_upstream)
        if [ -n "$upstream" ]; then
            _GL_MR_REPO_PATH="$upstream"
            echo "Fork erkannt — MR wird in '$upstream' gesucht." >&2
        else
            _GL_MR_REPO_PATH=$(_gl_local_repo_path)
        fi
    fi

    # If MR number not explicitly given and we're on a fork, find it by branch name
    if [ -z "${GL_MR_NUMBER:-}" ] && [ "$_GL_MR_REPO_PATH" != "$(_gl_local_repo_path)" ]; then
        local current_branch mr_encoded
        current_branch=$(git branch --show-current 2>/dev/null)
        [ -z "$current_branch" ] && die "Kein Branch ausgecheckt — bitte Feature-Branch auschecken."
        mr_encoded=$(_gl_mr_encoded_path)
        GL_MR_NUMBER=$(glab api \
            "projects/${mr_encoded}/merge_requests?source_branch=${current_branch}&state=opened&per_page=5" \
            2>/dev/null | jq -r 'first(.[] | .iid) // empty')
        if [ -z "$GL_MR_NUMBER" ]; then
            die "Keine offene MR für Branch '$current_branch' in '$_GL_MR_REPO_PATH' gefunden. Manuell übergeben: --mr <nummer>"
        fi
        echo "MR #${GL_MR_NUMBER} für Branch '$current_branch' gefunden." >&2
    fi
}

# ---------------------------------------------------------------------------
# Internal: MR lookups
# ---------------------------------------------------------------------------

_gl_mr_json() {
    local args=()
    [ -n "${GL_MR_NUMBER:-}" ] && args+=("$GL_MR_NUMBER")
    glab mr view "${args[@]}" --repo "$(_gl_mr_repo_path)" --output json 2>/dev/null
}

_gl_mr_api() {
    glab api "projects/$(_gl_mr_encoded_path)/merge_requests/$(_gl_mr_json | jq -r '.iid')/$1" 2>/dev/null
}

# ---------------------------------------------------------------------------
# Provider interface
# ---------------------------------------------------------------------------

provider_get_branch_refs() {
    _gl_mr_json | jq -r '.target_branch, .source_branch'
}

provider_get_mr_meta() {
    local mr_json approvals
    mr_json=$(_gl_mr_json)
    approvals=$(_gl_mr_api approvals | jq -r '(.approved_by // []) | map(.user.username) | join(", ")')

    printf '%s' "$mr_json" | jq -r '"# MR: \(.title)",
        "**Branch:** \(.source_branch) → \(.target_branch)",
        (if (.labels // []) != [] then "**Labels:** \(.labels | join(", "))" else empty end),
        "", "## Beschreibung", (.description // "")'
    [ -n "$approvals" ] && printf '\n## Approvals\nApproved by: %s\n' "$approvals"
    return 0
}

provider_get_open_threads() {
    _gl_mr_api "discussions?per_page=100" \
        | jq '[.[] | select(.notes[0].type == "DiffNote" and (.notes[0].resolved | not))
               | {path: .notes[0].position.new_path, line: .notes[0].position.new_line,
                  comments: [.notes[] | select(.system | not) | {author: .author.username, body}]}]'
}

provider_get_diff() {
    glab mr diff "$(_gl_mr_json | jq -r '.iid')" --repo "$(_gl_mr_repo_path)" 2>/dev/null
}

provider_get_commit_titles() {
    _gl_mr_api "commits?per_page=100" | jq -r '.[].title'
}

# Note: _gl_init is NOT called on source.
# It is called by run_preflight after auth is confirmed.
