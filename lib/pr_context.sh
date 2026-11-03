#!/usr/bin/env bash

generate_pr_context() {
    local work_dir="$1" pr_file="$1/context/pr.md"

    echo "Fetching PR context..." >&2
    provider_get_mr_meta > "$pr_file"

    # The PR diff is taken against the base branch, so it also carries whatever
    # another, not yet merged branch brought in.
    local merged
    merged=$(provider_get_commit_titles \
        | sed -nE "s/^Merge (remote-tracking )?branch '(origin\/)?([^']+)'.*/\3/p" \
        | grep -vxF -f <(provider_get_branch_refs) | sort -u)
    if [ -n "$merged" ]; then
        printf '\n## Hineingemergte Branches\n\n' >> "$pr_file"
        printf '%s\n' "$merged" | sed 's/^/- /' >> "$pr_file"
    fi

    echo "Fetching open review threads..." >&2
    local threads
    threads=$(provider_get_open_threads)
    if [ "$(jq 'length' <<< "${threads:-[]}")" -gt 0 ]; then
        printf '\n## Offene Review-Threads\n\n' >> "$pr_file"
        printf '%s' "$threads" | jq -r '.[]
            | "### `\(.path)` Zeile \(.line // "?")\n\n"
              + (.comments | map("**\(.author):** \(.body)") | join("\n\n"))
              + "\n"' >> "$pr_file"
    fi
}
