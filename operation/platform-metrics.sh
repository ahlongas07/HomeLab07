#!/usr/bin/env bash

source "${BASH_SOURCE%/*}/lib.sh"
source "${BASH_SOURCE%/*}/observability-metrics-lib.sh"

print_header "Platform Metrics"
print_project_root

started_epoch="$(date +%s)"

if ! command -v docker >/dev/null 2>&1 || ! docker info >/dev/null 2>&1; then
    observability_publish_batch_metrics platform 0 "${started_epoch}"
    echo "Docker runtime is unavailable."
    exit 1
fi

service_metrics=()
services=(
    mariadb valkey nginx-proxy-manager jellyfin nextcloud keycloak
    paperless-ngx homebridge cloudflare-ddns landing-page
)

for service in "${services[@]}"; do
    running=0
    if docker ps --filter "name=^/homelab07-${service}$" --format '{{.Names}}' |
        grep -Fxq "homelab07-${service}"; then
        running=1
    fi
    service_metrics+=("homelab07_platform_service_running{service=\"${service}\"} ${running}")
done

observability_publish_batch_metrics platform 1 "${started_epoch}" "${service_metrics[@]}"
echo "Platform metrics published atomically."

