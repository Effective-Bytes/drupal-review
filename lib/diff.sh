#!/usr/bin/env bash

# Writes one diff file per changed file to context/diff/<path>.diff and an
# index to context/files.md. Prints the changed paths on stdout.
generate_diff() {
    local work_dir="$1"
    echo "Fetching PR diff..." >&2

    local diff_dir="$work_dir/context/diff" stats
    stats=$(provider_get_diff | split_diff "$diff_dir")

    {
        echo "# Geänderte Dateien"
        echo
        echo "Reihenfolge: Code, Tests, dann Dateien ohne Diff."
        echo "Zeilennummern in den Diffs sind die der neuen Datei."
        echo
        echo "| Status | + | − | Kategorie | Datei | Diff |"
        echo "|---|---|---|---|---|---|"
        printf '%s\n' "$stats" | while IFS=$'\t' read -r status add del path; do
            local category diff_file="diff/$path.diff"
            category=$(file_category "$path")
            case "$category" in
                config|lock|patch|compiled) rm -f "$work_dir/context/$diff_file" ;;
            esac
            [ -f "$work_dir/context/$diff_file" ] || diff_file="—"
            printf '%s\t| %s | %s | %s | %s | `%s` | %s |\n' \
                "$(category_rank "$category")" "$status" "$add" "$del" "$category" "$path" "$diff_file"
        done | sort -t$'\t' -k1,1n -s | cut -f2-
    } > "$work_dir/context/files.md"

    printf '%s\n' "$stats" | cut -f4
}

# Reads a unified diff on stdin. Prints "status<TAB>added<TAB>deleted<TAB>path"
# per file and writes each file's hunks with new-file line numbers.
split_diff() {
    awk -v dir="$1" '
        function finish() {
            if (path == "") return
            close(out)
            printf "%s\t%d\t%d\t%s\n", status, add, del, path
        }
        /^diff --git / {
            finish()
            path = $0; sub(/^.* b\//, "", path)
            status = "M"; add = 0; del = 0; in_hunk = 0
            out = dir "/" path ".diff"
            parent = out; sub(/\/[^\/]*$/, "", parent)
            system("mkdir -p '\''" parent "'\''")
            next
        }
        !in_hunk && /^new file mode/     { status = "A"; next }
        !in_hunk && /^deleted file mode/ { status = "D"; next }
        !in_hunk && /^rename from/       { status = "R"; next }
        !in_hunk && !/^@@/               { next }
        /^@@/ { in_hunk = 1; line = substr($3, 2) + 0; print > out; next }
        /^\+/ { add++; printf "%5d %s\n", line++, $0 > out; next }
        /^-/  { del++; printf "%5s %s\n", "", $0 > out; next }
        /^ / || $0 == "" { printf "%5d %s\n", line++, $0 > out; next }
        { printf "%5s %s\n", "", $0 > out }
        END { finish() }
    '
}

file_category() {
    case "$1" in
        config/sync/*|*/config/sync/*) echo config ;;
        *composer.lock|*package-lock.json|*yarn.lock|*pnpm-lock.yaml) echo lock ;;
        *.patch) echo patch ;;
        tests/*|*/tests/*|*Test.php|*.spec.*|*.test.*) echo test ;;
        *) if should_ignore_compiled_file "$1"; then echo compiled; else echo code; fi ;;
    esac
}

category_rank() {
    case "$1" in
        code) echo 1 ;;
        test) echo 2 ;;
        *) echo 3 ;;
    esac
}
