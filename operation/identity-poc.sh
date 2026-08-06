#!/usr/bin/env bash

source "${BASH_SOURCE%/*}/lib.sh"

print_header "Identity Authority PoC"
print_project_root

readonly PAPERLESS_ENV="${PRIVATE_ROOT}/env/paperless-ngx.env"

usage() {
    echo "Usage: $0 <status|apply|rollback> [--confirm-local-admin-tested]"
}

require_running_container() {
    local container="$1"

    if [[ "$(docker inspect -f '{{.State.Running}}' "${container}" 2>/dev/null || true)" != "true" ]]; then
        echo "Required container is not running: ${container}"
        exit 1
    fi
}

occ() {
    docker exec --user www-data homelab07-nextcloud php occ "$@"
}

read_private_value() {
    local key="$1"

    [[ -f "${PAPERLESS_ENV}" ]] || {
        echo "Missing private environment file:"
        echo "  ${PAPERLESS_ENV}"
        exit 1
    }

    awk -v key="${key}" 'index($0, key "=") == 1 {
        print substr($0, length(key) + 2)
        exit
    }' "${PAPERLESS_ENV}"
}

show_nextcloud_value() {
    local scope="$1"
    local key="$2"
    local value

    if [[ "${scope}" == "system" ]]; then
        value="$(occ config:system:get user_oidc "${key}" 2>/dev/null || true)"
    else
        value="$(occ config:app:get user_oidc "${key}" 2>/dev/null || true)"
    fi

    [[ -n "${value}" ]] || value="<unset>"
    printf '  %-31s %s\n' "${key}:" "${value}"
}

show_status() {
    require_running_container homelab07-keycloak
    require_running_container homelab07-nextcloud
    require_running_container homelab07-paperless-ngx

    echo "Keycloak theme mount:"
    if docker exec homelab07-keycloak \
        test -r /opt/keycloak/themes/homelab07/login/theme.properties; then
        echo "  homelab07 theme is mounted read-only and readable"
    else
        echo "  homelab07 theme is not available in the running container"
    fi

    echo
    echo "Nextcloud user_oidc settings:"
    show_nextcloud_value system auto_provision
    show_nextcloud_value system soft_auto_provision
    show_nextcloud_value system disable_account_creation
    show_nextcloud_value system enrich_login_id_token_with_userinfo
    show_nextcloud_value app allow_multiple_user_backends

    echo
    echo "Paperless-ngx identity switches:"
    for key in \
        PAPERLESS_SOCIAL_AUTO_SIGNUP \
        PAPERLESS_SOCIALACCOUNT_ALLOW_SIGNUPS \
        PAPERLESS_SOCIAL_ACCOUNT_SYNC_GROUPS \
        PAPERLESS_DISABLE_REGULAR_LOGIN \
        PAPERLESS_REDIRECT_LOGIN_TO_SSO; do
        value="$(docker exec homelab07-paperless-ngx printenv "${key}" 2>/dev/null || true)"
        [[ -n "${value}" ]] || value="<unset>"
        printf '  %-43s %s\n' "${key}:" "${value}"
    done
}

apply_poc() {
    [[ "${2:-}" == "--confirm-local-admin-tested" ]] || {
        echo "Refusing to enable default redirects without explicit confirmation."
        echo "Test local Nextcloud and Paperless administrators, then run:"
        echo "  $0 apply --confirm-local-admin-tested"
        exit 1
    }

    require_running_container homelab07-keycloak
    require_running_container homelab07-nextcloud

    [[ "$(read_private_value PAPERLESS_SOCIAL_AUTO_SIGNUP)" == "true" ]] || {
        echo "PAPERLESS_SOCIAL_AUTO_SIGNUP must be true in private configuration."
        exit 1
    }
    [[ "$(read_private_value PAPERLESS_SOCIALACCOUNT_ALLOW_SIGNUPS)" == "true" ]] || {
        echo "PAPERLESS_SOCIALACCOUNT_ALLOW_SIGNUPS must be true in private configuration."
        exit 1
    }
    [[ "$(read_private_value PAPERLESS_DISABLE_REGULAR_LOGIN)" == "false" ]] || {
        echo "Paperless regular login must remain enabled during this PoC."
        exit 1
    }
    [[ "$(read_private_value PAPERLESS_REDIRECT_LOGIN_TO_SSO)" == "true" ]] || {
        echo "PAPERLESS_REDIRECT_LOGIN_TO_SSO must be true in private configuration."
        exit 1
    }

    echo "Enabling Nextcloud OIDC provisioning and userinfo reconciliation..."
    occ config:system:set user_oidc auto_provision \
        --type=boolean --value=true
    occ config:system:set user_oidc soft_auto_provision \
        --type=boolean --value=true
    occ config:system:set user_oidc disable_account_creation \
        --type=boolean --value=false
    occ config:system:set user_oidc enrich_login_id_token_with_userinfo \
        --type=boolean --value=true

    echo "Enabling Nextcloud default OIDC redirection..."
    occ config:app:set user_oidc allow_multiple_user_backends \
        --type=string --value=0

    echo "Recreating Paperless-ngx with the approved private identity policy..."
    compose_service paperless-ngx up -d

    echo
    echo "The Keycloak realm must select login theme 'homelab07' manually."
    echo "Validate the private Nextcloud ?direct=1 emergency URL now."
    print_footer
}

rollback_redirects() {
    require_running_container homelab07-nextcloud

    echo "Restoring the normal Nextcloud login chooser..."
    occ config:app:set user_oidc allow_multiple_user_backends \
        --type=string --value=1

    if [[ "$(read_private_value PAPERLESS_REDIRECT_LOGIN_TO_SSO)" != "false" ]]; then
        echo
        echo "Nextcloud rollback completed."
        echo "Set PAPERLESS_REDIRECT_LOGIN_TO_SSO=false in private configuration"
        echo "and rerun this command to recreate Paperless-ngx."
        exit 1
    fi

    echo "Recreating Paperless-ngx with SSO redirection disabled..."
    compose_service paperless-ngx up -d
    print_footer
}

action="${1:-}"
case "${action}" in
    status)
        show_status
        ;;
    apply)
        apply_poc "$@"
        ;;
    rollback)
        rollback_redirects
        ;;
    *)
        usage
        exit 1
        ;;
esac
