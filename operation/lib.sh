#!/usr/bin/env bash

set -euo pipefail

# -----------------------------------------------------------------------------
# HomeLab07 Operations Library
# -----------------------------------------------------------------------------

readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
readonly PRIVATE_ROOT="${HOMELAB07_PRIVATE_ROOT:-${PROJECT_ROOT}/../HomeLab07.private}"

export HOMELAB07_PRIVATE_ROOT="${PRIVATE_ROOT}"

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

    local env_file="${PRIVATE_ROOT}/env/${service}.env"
    local env_example="${PROJECT_ROOT}/services/${service}/.env.example"
    local env_args=()

    if [[ -f "${env_file}" ]]; then
        env_args=(--env-file "${env_file}")
    elif [[ -f "${env_example}" ]] && grep -Eq '^[[:space:]]*[A-Za-z_][A-Za-z0-9_]*=' "${env_example}"; then
        echo "Missing private environment file for ${service}:"
        echo "  ${env_file}"
        echo
        echo "Create it from:"
        echo "  ${env_example}"
        exit 1
    fi

    if [[ ${#env_args[@]} -gt 0 ]]; then
        docker compose \
            "${env_args[@]}" \
            -f "${PROJECT_ROOT}/services/${service}/compose.yaml" \
            "$@"
    else
        docker compose \
            -f "${PROJECT_ROOT}/services/${service}/compose.yaml" \
            "$@"
    fi
}

compose_service() {
    local service="$1"
    shift

    compose "${service}" "$@"
}

print_footer() {
    echo
    echo "Operation completed successfully."
}
