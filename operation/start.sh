#!/usr/bin/env bash

source "${BASH_SOURCE%/*}/lib.sh"

print_header "Start"

print_project_root

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
    echo "Starting $(service_label "${service}")..."
    compose "${service}" up -d
    echo
done

echo
echo "HomeLab07 started successfully."
