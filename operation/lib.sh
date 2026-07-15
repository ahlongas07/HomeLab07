#!/usr/bin/env bash

set -euo pipefail

# -----------------------------------------------------------------------------
# HomeLab07 Operations Library
# -----------------------------------------------------------------------------

readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

print_header() {
    local action="$1"

    echo "========================================="
    echo " HomeLab07 Operations"
    echo "-----------------------------------------"
    echo " Action : ${action}"
    echo "========================================="
    echo
}

print_project_root() {
    echo "Project Root:"
    echo "  ${PROJECT_ROOT}"
    echo
}

compose() {
    local service="$1"
    shift

    docker compose \
        -f "${PROJECT_ROOT}/services/${service}/compose.yaml" \
        "$@"
}
