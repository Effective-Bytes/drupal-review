#!/usr/bin/env bash

generate_environment_meta() {
    local work_dir="$1"
    echo "Generating environment meta information..." >&2
    {
        local COMPOSER_LOCK_PATH
        COMPOSER_LOCK_PATH=$(find . -maxdepth 2 -name "composer.lock" -print -quit)

        echo "--- Language Runtimes ---"
        local PHP_VERSION="" PHP_SOURCE=""
        if [ -n "$COMPOSER_LOCK_PATH" ]; then
            PHP_VERSION=$(jq -r '."platform-overrides".php // empty' "$COMPOSER_LOCK_PATH" 2>/dev/null)
            [ -n "$PHP_VERSION" ] && PHP_SOURCE="composer.lock platform-overrides"
        fi
        if [ -z "$PHP_VERSION" ]; then
            local PHP_VERSION_FILE
            PHP_VERSION_FILE=$(find . -maxdepth 2 -name ".php-version" -print -quit)
            if [ -n "$PHP_VERSION_FILE" ]; then
                PHP_VERSION=$(tr -d '[:space:]' < "$PHP_VERSION_FILE")
                [ -n "$PHP_VERSION" ] && PHP_SOURCE="$PHP_VERSION_FILE"
            fi
        fi
        echo "PHP: ${PHP_VERSION:-not specified} ${PHP_SOURCE:+(source: $PHP_SOURCE)}"
        echo "Node: $(node -v 2>/dev/null || echo 'Not found')"
        echo "NPM: $(npm -v 2>/dev/null || echo 'Not found')"
        echo "Yarn: $(yarn -v 2>/dev/null || echo 'Not found')"

        printf "\n--- Drupal Core (from composer.lock) ---\n"
        if [ -n "$COMPOSER_LOCK_PATH" ]; then
            echo "Found at: $COMPOSER_LOCK_PATH"
            local DRUPAL_VERSION
            DRUPAL_VERSION=$(jq -r '.packages[] | select(.name == "drupal/core") | .version' "$COMPOSER_LOCK_PATH" 2>/dev/null)
            if [ -z "$DRUPAL_VERSION" ]; then
                DRUPAL_VERSION=$(jq -r '.packages[] | select(.name == "drupal/core-recommended") | .version' "$COMPOSER_LOCK_PATH" 2>/dev/null)
            fi
            if [ -n "$DRUPAL_VERSION" ]; then
                echo "Drupal Core: $DRUPAL_VERSION"
            else
                echo "Drupal core not found in $COMPOSER_LOCK_PATH"
            fi
        else
            echo "composer.lock not found in root or first-level subdirectories."
        fi
    } > "$work_dir/context/environment_meta.txt"
}
