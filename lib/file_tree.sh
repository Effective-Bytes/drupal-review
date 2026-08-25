#!/usr/bin/env bash

generate_file_tree() {
    local work_dir="$1"
    echo "Generating file tree..." >&2
    {
        tree -a -L 5 -I '.git|.drupal-review|.review-context|.agent|.junie|config' -f -i --noreport --gitignore \
        | while IFS= read -r file; do
            if should_ignore_compiled_file "$file"; then
                continue
            fi
            echo "${file#./}"
        done
    } > "$work_dir/context/file_tree.txt"
}
