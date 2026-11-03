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
    gh pr view --json baseRefName,headRefName -q '.baseRefName, .headRefName'
}

provider_get_mr_meta() {
    gh pr view --json title,body,headRefName,baseRefName,labels,reviews,comments \
      --template '# PR: {{.title}}
**Branch:** {{.headRefName}} → {{.baseRefName}}
{{if .labels}}**Labels:** {{range .labels}}{{.name}} {{end}}{{end}}

## Beschreibung
{{.body}}
{{if .reviews}}
## Reviews
{{range .reviews}}{{if .body}}### {{.author.login}} ({{.state}})
{{.body}}
{{end}}{{end}}{{end}}{{if .comments}}
## Kommentare
{{range .comments}}**{{.author.login}}:** {{.body}}
{{end}}{{end}}'
}

provider_get_open_threads() {
    gh api graphql -F owner='{owner}' -F repo='{repo}' \
        -F number="$(gh pr view --json number -q '.number')" -f query='
        query($owner: String!, $repo: String!, $number: Int!) {
          repository(owner: $owner, name: $repo) {
            pullRequest(number: $number) {
              reviewThreads(first: 100) {
                nodes {
                  isResolved isOutdated path line
                  comments(first: 50) { nodes { author { login } body } }
                }
              }
            }
          }
        }' \
        | jq '[.data.repository.pullRequest.reviewThreads.nodes[]
               | select((.isResolved or .isOutdated) | not)
               | {path, line, comments: [.comments.nodes[] | {author: .author.login, body}]}]'
}

provider_get_diff() {
    gh pr diff
}

provider_get_commit_titles() {
    # Not `gh pr view --json commits`: its messageHeadline is truncated.
    gh api "repos/{owner}/{repo}/pulls/$(gh pr view --json number -q '.number')/commits?per_page=100" \
        -q '.[].commit.message | split("\n")[0]'
}
