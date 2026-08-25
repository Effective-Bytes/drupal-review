#!/usr/bin/env bash

generate_pr_context() {
    local work_dir="$1"

    echo "Fetching PR context..." >&2
    provider_get_mr_meta "$work_dir"

    echo "Fetching inline review comments..." >&2
    local inline_file
    inline_file=$(mktemp /tmp/pr-comments.XXXXXX.json)
    provider_get_inline_comments "$inline_file"

    local comment_count
    comment_count=$(jq 'length' "$inline_file" 2>/dev/null || echo 0)
    if [ "${comment_count:-0}" -gt 0 ]; then
        printf '\n## Inline Review Kommentare\n\n' >> "$work_dir/context/pr_context.md"
        jq -r '.[] | "**\(.author)** in `\(.path)` (Zeile \((.line // "?") | tostring)):\n> \(.body | gsub("\r\n";" ") | gsub("\n";" "))\n\nKontext:\n```diff\n\(.diff_hunk)\n```\n---"' \
            "$inline_file" >> "$work_dir/context/pr_context.md"
    fi
    rm -f "$inline_file"

    echo "Fetching PR diff..." >&2
    printf '\n## Diff\n\n```diff\n' >> "$work_dir/context/pr_context.md"
    provider_get_diff "$work_dir/context/pr_context.md"
    printf '```\n' >> "$work_dir/context/pr_context.md"
}
