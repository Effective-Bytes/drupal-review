#!/usr/bin/env bash
# GitHub provider — implements the provider interface via gh CLI

provider_auth_check() {
    # Functional check against the *active* account. `gh auth status` validates ALL
    # configured accounts and returns non-zero if any secondary/stale account has an
    # invalid token — `gh api user` only exercises the active account's token.
    gh api user >/dev/null 2>&1 \
        || die "GitHub CLI nicht authentifiziert. 'gh auth login' ausführen."
}

provider_mr_exists() {
    gh pr view >/dev/null 2>&1
}

provider_get_branch_refs() {
    local refs
    refs=$(gh pr view --json baseRefName,headRefName 2>/dev/null)
    printf 'BASE_REF=%s\nHEAD_REF=%s\n' \
        "$(printf '%s' "$refs" | jq -r '.baseRefName // empty')" \
        "$(printf '%s' "$refs" | jq -r '.headRefName // empty')"
}

provider_get_repo_id() {
    gh repo view --json nameWithOwner -q '.nameWithOwner'
}

provider_get_mr_meta() {
    local work_dir="$1"
    gh pr view --json title,body,headRefName,baseRefName,labels,reviews,comments \
      --template '# PR: {{.title}}
**Branch:** {{.headRefName}} → {{.baseRefName}}
{{if .labels}}**Labels:** {{range .labels}}{{.name}} {{end}}{{end}}

## Beschreibung
{{.body}}
{{if .reviews}}
## Reviews
{{range .reviews}}### {{.author.login}} ({{.state}})
{{.body}}
{{end}}{{end}}{{if .comments}}
## Kommentare
{{range .comments}}**{{.author.login}}:** {{.body}}
{{end}}{{end}}' > "$work_dir/context/pr_context.md"
}

provider_get_inline_comments() {
    local outfile="$1"
    local repo_id pr_number
    repo_id=$(provider_get_repo_id)
    pr_number=$(gh pr view --json number -q '.number')
    gh api "repos/$repo_id/pulls/$pr_number/comments" \
        | jq '[.[] | {author: .user.login, path: .path,
                       line: (.line // .original_line), body: .body, diff_hunk: .diff_hunk}]' \
        > "$outfile"
}

provider_get_diff() {
    local outfile="$1"
    gh pr diff >> "$outfile"
}

provider_get_changed_files() {
    gh pr diff --name-only 2>/dev/null
}

provider_get_commits_json() {
    local outfile="$1"
    gh pr view --json commits \
        | jq '{commits: [.commits[] | {
            oid: .oid,
            messageHeadline: .messageHeadline,
            author: (.authors[0].name // .authors[0].login // "?"),
            committedDate: .committedDate[:10]
          }]}' \
        > "$outfile"
}
