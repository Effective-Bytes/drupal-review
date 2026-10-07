#!/usr/bin/env bash

run_preflight() {
    local provider="$1"
    command -v jq >/dev/null 2>&1 || die "'jq' ist erforderlich aber nicht installiert."
    case "$provider" in
        github)
            command -v gh >/dev/null 2>&1 \
                || die "'gh' ist für GitHub-Projekte erforderlich. Installieren: https://cli.github.com"
            ;;
        gitlab)
            command -v glab >/dev/null 2>&1 \
                || die "'glab' ist für GitLab-Projekte erforderlich. Installieren: https://gitlab.com/gitlab-org/cli"
            # gh is optional here: it is only the preferred route for the standards
            # download. Without it, a public standards repository still loads over
            # curl; a private one fails later with a message naming the repository.
            if ! command -v gh >/dev/null 2>&1; then
                echo "Hinweis: 'gh' nicht installiert. Ein privates Standards-Repository ist damit nicht erreichbar." >&2
            fi
            ;;
        *) die "Unbekannter Provider: '$provider'. Erlaubt: github, gitlab." ;;
    esac
    # Authentication is checked per provider — see provider_auth_check in
    # lib/provider_github.sh / lib/provider_gitlab.sh.
    provider_auth_check
    # GitLab: wire up MR repo path after auth is confirmed (may call glab api)
    [ "$provider" = "gitlab" ] && _gl_init
}
