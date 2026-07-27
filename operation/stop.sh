#!/usr/bin/env bash

source "${BASH_SOURCE%/*}/lib.sh"

print_header "Stop"

print_project_root

services=(
    landing-page
    cloudflare-ddns
    homebridge
    paperless-ngx
    nextcloud
    jellyfin
    nginx-proxy-manager
    valkey
    mariadb
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
    echo "Stopping $(service_label "${service}")..."
    compose "${service}" down
    echo
done

echo
echo "HomeLab07 stopped successfully."
