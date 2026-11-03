#!/usr/bin/env bash

generate_environment_meta() {
    local work_dir="$1" changed_files="$2" lock php="" core="" theme_config core_dir block_files file
    echo "Generating environment meta information..." >&2

    lock=$(find . -maxdepth 2 -name composer.lock -print -quit)
    if [ -n "$lock" ]; then
        php=$(jq -r '."platform-overrides".php // empty' "$lock")
        core=$(jq -r 'first(.packages[] | select(.name == "drupal/core" or .name == "drupal/core-recommended") | .version) // empty' "$lock")
    fi
    [ -n "$php" ] || php=$(find . -maxdepth 2 -name .php-version -exec cat {} \; -quit | tr -d '[:space:]')

    theme_config=$(find . -maxdepth 3 -path '*/config/*' -name system.theme.yml -print -quit)
    theme_config="${theme_config#./}"
    core_dir=$(find . -maxdepth 4 -path '*/core/lib/Drupal.php' -print -quit)
    core_dir="${core_dir#./}"
    core_dir="${core_dir%/lib/Drupal.php}"
    block_files=$(printf '%s\n' "$changed_files" | grep -E '(^|/)block\.block\.[^/]+\.yml$')

    {
        echo "PHP: ${php:-unbekannt}"
        echo "Drupal Core: ${core:-unbekannt}"
        echo "Standards: $STANDARDS_REPO@$STANDARDS_REF (Commit $STANDARDS_COMMIT)"

        if [ -n "$theme_config" ]; then
            echo "Default-Theme: $(yaml_value default "$theme_config") ($theme_config)"
            echo "Admin-Theme: $(yaml_value admin "$theme_config") ($theme_config)"
        else
            echo "Default-Theme: unbekannt"
            echo "Admin-Theme: unbekannt"
        fi

        if [ -n "$block_files" ]; then
            echo "Block-Konfiguration im Diff:"
            printf '%s\n' "$block_files" | while IFS= read -r file; do
                echo "- $file: Theme $(yaml_value theme "$file")"
            done
        else
            echo "Block-Konfiguration im Diff: keine"
        fi

        if [ -f deploy.php ]; then
            echo "drush-Aufrufe in deploy.php:"
            grep -nE "run\(.*drush[^ ]*.*\b(deploy|updb|updatedb|cim|config:import|config-import|cr|cache:rebuild|cache-rebuild|site:install)\b" deploy.php \
                | grep -vE '^[0-9]+:[[:space:]]*(//|\*|#)' \
                | sed -E 's/^([0-9]+):[[:space:]]*/- deploy.php:\1: /'
        else
            echo "deploy.php: fehlt"
        fi

        if [ -d "$(dirname "${lock:-./composer.lock}")/vendor" ]; then
            echo "vendor/: vorhanden"
        else
            echo "vendor/: fehlt"
        fi
        echo "Drupal-Core-Code: ${core_dir:-fehlt}"
    } > "$work_dir/context/environment_meta.txt"
}

# Prints the value of a top-level YAML key, or "unbekannt".
yaml_value() {
    local value
    value=$(sed -n "s/^$1: *//p" "$2" 2>/dev/null | tr -d "\"'")
    echo "${value:-unbekannt}"
}
