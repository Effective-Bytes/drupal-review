#!/usr/bin/env bash

_composer_require_pkgs() {
    git show "$1:composer.json" 2>/dev/null \
        | jq -r '((.require // {}) + (."require-dev" // {})) | keys[]' 2>/dev/null \
        | grep -vE '^(php|ext-|lib-|composer-)' \
        | sort -u
}

_composer_lock_pkgs() {
    git show "$1:composer.lock" 2>/dev/null \
        | jq -r '((.packages // []) + (."packages-dev" // []))[].name' 2>/dev/null \
        | sort -u
}

_report_dropped_removals() {
    local label="$1" base="$2" ours="$3" theirs="$4" result="$5" fn="$6"
    local rem_theirs rem_ours
    rem_theirs=$(comm -12 <(comm -23 <("$fn" "$base") <("$fn" "$theirs")) <("$fn" "$result"))
    rem_ours=$(comm -12 <(comm -23 <("$fn" "$base") <("$fn" "$ours")) <("$fn" "$result"))
    if [ -n "$rem_theirs" ] || [ -n "$rem_ours" ]; then
        echo "**$label — suspected non-propagated removals:**"
        echo '```'
        [ -n "$rem_theirs" ] && { echo "Removed on theirs (P2) but present in result:"; printf '%s\n' "$rem_theirs" | sed 's/^/  ⚠ /'; }
        [ -n "$rem_ours" ]   && { echo "Removed on ours (P1) but present in result:";  printf '%s\n' "$rem_ours"   | sed 's/^/  ⚠ /'; }
        echo '```'
    else
        echo "_$label — no non-propagated removals detected._"
    fi
    echo
}

generate_merge_analysis() {
    local work_dir="$1"
    echo "Analyzing branch commits and merge conflict resolutions..." >&2

    local HUNK_CAP=400

    local commits_json
    commits_json=$(mktemp /tmp/pr-commits.XXXXXX.json)
    provider_get_commits_json "$commits_json"

    local BASE_REF HEAD_REF
    eval "$(provider_get_branch_refs)"

    # Resolve base branch tip to a local ref
    local base_local=""
    if [ -n "$BASE_REF" ]; then
        if git rev-parse --verify --quiet "origin/$BASE_REF" >/dev/null 2>&1; then
            base_local="origin/$BASE_REF"
        elif git fetch --no-tags --quiet origin "$BASE_REF" 2>/dev/null; then
            base_local="FETCH_HEAD"
        fi
    fi

    # commits.txt
    {
        echo "# Branch Commits (${HEAD_REF:-?} -> ${BASE_REF:-?})"
        echo
        echo "Format: <short-oid> [MERGE] <headline> — <author> (<date>)"
        echo
        jq -r '.commits[] | "\(.oid)\t\(.messageHeadline)\t\(.author)\t\(.committedDate)"' "$commits_json" \
        | while IFS=$'\t' read -r oid headline author date; do
            is_merge_commit "$oid" && marker="[MERGE] " || marker=""
            printf '%s %s%s — %s (%s)\n' "${oid:0:10}" "$marker" "$headline" "$author" "$date"
        done
    } > "$work_dir/context/commits.txt"

    # merge_conflicts.md
    {
        echo "# Merge Conflict Resolution Analysis"
        echo
        echo "Branch: ${HEAD_REF:-?} -> ${BASE_REF:-?}"
        echo

        local merge_found=0
        for oid in $(jq -r '.commits[].oid' "$commits_json"); do
            is_merge_commit "$oid" || continue
            merge_found=1

            local parents p1 p2 mbl
            parents=$(git rev-list --parents -n 1 "$oid" 2>/dev/null)
            p1=$(printf '%s' "$parents" | cut -d' ' -f2)
            p2=$(printf '%s' "$parents" | cut -d' ' -f3)
            mbl=$(git merge-base "$p1" "$p2" 2>/dev/null)

            echo "## Merge ${oid:0:10} — $(git log -1 --format='%s' "$oid" 2>/dev/null)"
            echo
            echo "- ours (P1): ${p1:0:10} · theirs (P2): ${p2:0:10} · base: ${mbl:0:10}"
            echo

            echo "### Manual resolution (combined diff)"
            echo
            local files
            files=$(git diff-tree --cc --no-commit-id --name-only -r "$oid" 2>/dev/null)
            if [ -z "$files" ]; then
                echo "_Empty — clean auto-merge or one side taken wholesale; dependency check below still applies._"
                echo
            else
                printf '%s\n' "$files" | while IFS= read -r f; do
                    [ -n "$f" ] || continue
                    case "$f" in
                        *composer.lock)
                            echo "- \`$f\` — see dependency removal check below"
                            ;;
                        *)
                            local cc cc_lines
                            cc=$(git show --cc "$oid" -- "$f" 2>/dev/null | sed -n '/^@@@/,$p')
                            echo "#### \`$f\`"
                            echo '```diff'
                            printf '%s\n' "$cc" | head -n "$HUNK_CAP"
                            cc_lines=$(printf '%s\n' "$cc" | wc -l)
                            [ "$cc_lines" -gt "$HUNK_CAP" ] && echo "[gekürzt — $(( cc_lines - HUNK_CAP )) Zeilen ausgelassen]"
                            echo '```'
                            echo "vs ours (P1):"
                            echo '```diff'
                            git diff "$p1" "$oid" -- "$f" 2>/dev/null | head -n "$HUNK_CAP"
                            echo '```'
                            echo "vs theirs (P2):"
                            echo '```diff'
                            git diff "$p2" "$oid" -- "$f" 2>/dev/null | head -n "$HUNK_CAP"
                            echo '```'
                            echo
                            ;;
                    esac
                done
                echo
            fi

            echo "### Dependency removal check"
            echo
            if [ -z "$mbl" ]; then
                echo "_Skipped: no merge-base between the parents._"
                echo
            else
                _report_dropped_removals "composer.json (require/require-dev)" "$mbl" "$p1" "$p2" "$oid" _composer_require_pkgs
                _report_dropped_removals "composer.lock" "$mbl" "$p1" "$p2" "$oid" _composer_lock_pkgs
            fi
        done
        [ "$merge_found" -eq 0 ] && { echo "_No merge commits (rebase/squash or linear history); see sections below._"; echo; }

        echo "# Composer Dependencies Added Relative to Base"
        echo
        if [ -z "$base_local" ]; then
            echo "_Skipped: base ref '${BASE_REF:-?}' not available locally._"
        else
            local added
            added=$(comm -23 <(_composer_require_pkgs HEAD) <(_composer_require_pkgs "$base_local"))
            if [ -n "$added" ]; then
                echo "Added on head (vs \`$BASE_REF\`):"
                echo '```'
                printf '%s\n' "$added" | sed 's/^/  + /'
                echo '```'
            else
                echo "_None._"
            fi
        fi
        echo

        echo "# Conflict Marker Scan"
        echo
        local hits
        hits=$(provider_get_changed_files | while IFS= read -r f; do
            [ -n "$f" ] && [ -f "$f" ] || continue
            grep -nE '^(<{7}|>{7})' "$f" 2>/dev/null | sed "s|^|$f:|"
        done)
        if [ -n "$hits" ]; then
            echo "**Leftover conflict markers found:**"
            echo '```'
            printf '%s\n' "$hits"
            echo '```'
        else
            echo "_None._"
        fi
    } > "$work_dir/context/merge_conflicts.md"

    rm -f "$commits_json"
}
