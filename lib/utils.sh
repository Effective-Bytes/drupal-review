#!/usr/bin/env bash
# Shared helpers — no side-effects, no external dependencies

die() {
    echo "ERROR: $*" >&2
    exit 1
}

# Known GitLab instances: the versioned list shipped with the skill, plus
# whatever GITLAB_INSTANCES adds on top (see gitlab-instances.txt).
GITLAB_INSTANCES_FILE="${GITLAB_INSTANCES_FILE:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/gitlab-instances.txt}"

get_gitlab_instances() {
    [ -r "$GITLAB_INSTANCES_FILE" ] && cat "$GITLAB_INSTANCES_FILE"
    [ -n "${GITLAB_INSTANCES:-}" ] && printf '%s\n' "$GITLAB_INSTANCES"
    return 0
}

detect_provider() {
    [ -n "${GIT_PROVIDER:-}" ] && { printf '%s' "$GIT_PROVIDER"; return; }

    local remote_url
    remote_url=$(git remote get-url origin 2>/dev/null || true)

    local instance
    while IFS= read -r instance; do
        # strip surrounding whitespace and skip empty lines / comments
        instance="${instance#"${instance%%[![:space:]]*}"}"
        instance="${instance%"${instance##*[![:space:]]}"}"
        [ -z "$instance" ] && continue
        case "$instance" in \#*) continue ;; esac
        case "$remote_url" in
            *"$instance"*) printf 'gitlab'; return ;;
        esac
    done <<< "$(get_gitlab_instances)"

    # Self-hosted instances (e.g. git.drupal.org): ask each CLI if it knows this repo
    if command -v glab >/dev/null 2>&1 && glab repo view >/dev/null 2>&1; then
        printf 'gitlab'; return
    fi
    if command -v gh >/dev/null 2>&1 && gh repo view >/dev/null 2>&1; then
        printf 'github'; return
    fi

    # Binary-only fallback (no network check possible)
    command -v glab >/dev/null 2>&1 && { printf 'gitlab'; return; }
    command -v gh   >/dev/null 2>&1 && { printf 'github'; return; }
    die "Provider nicht erkannt. GIT_PROVIDER=github|gitlab setzen oder --provider übergeben."
}

should_ignore_compiled_file() {
    local file_path="$1"
    local file_name base_name dir_name
    file_name="$(basename "$file_path")"
    dir_name="$(dirname "$file_path")"
    case "$file_name" in
        *.min.*)
            base_name="$(echo "$file_name" | sed 's/\.min\././')"
            [ -f "$dir_name/$base_name" ] && return 0 || return 1
            ;;
        *.css)
            base_name="${file_name%.css}"
            if [ -f "$dir_name/$base_name.scss" ] || [ -f "$dir_name/$base_name.sass" ] || [ -f "$dir_name/$base_name.less" ]; then
                return 0
            fi
            return 1
            ;;
        *) return 1 ;;
    esac
}
