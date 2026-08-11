#!/usr/bin/env bash

source "${BASH_SOURCE%/*}/lib.sh"

print_header "Observability Status"
print_project_root

compose_service observability ps

echo
echo "Host exposure"
if docker inspect homelab07-grafana >/dev/null 2>&1; then
    docker port homelab07-grafana 3000/tcp || true
else
    echo "  Grafana container is unavailable."
fi

for container in homelab07-prometheus homelab07-loki homelab07-alloy; do
    if docker inspect "${container}" >/dev/null 2>&1; then
        published="$(docker port "${container}" 2>/dev/null || true)"
        if [[ -n "${published}" ]]; then
            echo "  Unexpected published port: ${container}"
        else
            echo "  Internal only: ${container}"
        fi
    fi
done

print_footer

