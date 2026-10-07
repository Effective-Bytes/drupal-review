#!/usr/bin/env bash

generate_environment_meta() {
    local work_dir="$1" lock php="" core=""
    echo "Generating environment meta information..." >&2

    lock=$(find . -maxdepth 2 -name composer.lock -print -quit)
    if [ -n "$lock" ]; then
        php=$(jq -r '."platform-overrides".php // empty' "$lock")
        core=$(jq -r 'first(.packages[] | select(.name == "drupal/core" or .name == "drupal/core-recommended") | .version) // empty' "$lock")
    fi
    [ -n "$php" ] || php=$(find . -maxdepth 2 -name .php-version -exec cat {} \; -quit | tr -d '[:space:]')

    {
        echo "PHP: ${php:-unbekannt}"
        echo "Drupal Core: ${core:-unbekannt}"
        echo "Standards: $STANDARDS_REPO@$STANDARDS_REF (Commit $STANDARDS_COMMIT)"
    } > "$work_dir/context/environment_meta.txt"
}
