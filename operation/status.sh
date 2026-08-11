#!/usr/bin/env bash

source "${BASH_SOURCE%/*}/lib.sh"

print_header "Status"

print_project_root

echo "Platform"
echo

services=(
    mariadb
    valkey
    nginx-proxy-manager
    jellyfin
    nextcloud
    keycloak
    paperless-ngx
    homebridge
    cloudflare-ddns
    landing-page
    observability
)

if (($# > 1)); then
    echo "Usage: $0 [service]"
    exit 1
fi

if (($# == 1)); then
    service_label "$1" >/dev/null || {
        echo "Unknown service: $1"
        exit 1
    }
    services=("$1")
fi

for service in "${services[@]}"; do
    echo "  $(service_label "${service}")"
    echo
    compose_service "${service}" ps
    echo
done

print_footer
