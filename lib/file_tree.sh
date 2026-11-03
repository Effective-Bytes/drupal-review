#!/usr/bin/env bash

# Lists every file of the custom modules and themes the PR touches, plus the
# names of all other custom modules and themes.
generate_file_tree() {
    local work_dir="$1" changed_files="$2"
    echo "Generating file tree..." >&2
    {
        echo "# Berührte Module und Themes"
        echo
        printf '%s\n' "$changed_files" \
            | sed -nE 's#^(.*/custom/[^/]+)/.*#\1#p' | sort -u \
            | while IFS= read -r root; do
                git ls-files -- "$root" | while IFS= read -r file; do
                    should_ignore_compiled_file "$file" || echo "$file"
                done
            done
        echo
        echo "# Alle Custom-Module und -Themes"
        echo
        git ls-files -- ':(glob)**/custom/*/*.info.yml' | sed 's#/[^/]*$##'
    } > "$work_dir/context/file_tree.txt"
}
