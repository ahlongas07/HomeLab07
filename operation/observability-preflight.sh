#!/usr/bin/env bash

source "${BASH_SOURCE%/*}/lib.sh"

print_header "Observability Preflight"
print_project_root

config_file="${PRIVATE_ROOT}/env/observability.env"
failure_count=0

pass() {
    echo "[PASS] $1"
}

fail() {
    echo "[FAIL] $1"
    failure_count=$((failure_count + 1))
}

file_mode() {
    stat -c '%a' "$1" 2>/dev/null || stat -f '%Lp' "$1" 2>/dev/null || true
}

is_within() {
    local candidate="$1"
    local boundary="$2"
    [[ "${candidate}" == "${boundary}" || "${candidate}" == "${boundary}/"* ]]
}

is_private_ipv4() {
    local address="$1"
    local first second third fourth octet

    [[ "${address}" =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]] || return 1
    IFS=. read -r first second third fourth <<<"${address}"
    for octet in "${first}" "${second}" "${third}" "${fourth}"; do
        ((10#${octet} >= 0 && 10#${octet} <= 255)) || return 1
    done

    ((10#${first} == 10)) ||
        ((10#${first} == 192 && 10#${second} == 168)) ||
        ((10#${first} == 172 && 10#${second} >= 16 && 10#${second} <= 31))
}

if [[ ! -f "${config_file}" ]]; then
    fail "Private observability configuration is missing"
    echo "Create it from services/observability/.env.example."
else
    mode="$(file_mode "${config_file}")"
    if [[ "${mode}" =~ ^[0-7]{3,4}$ ]] && ((10#${mode} % 100 == 0)); then
        pass "Private observability configuration is owner-only"
    else
        fail "Private observability configuration permissions are broader than owner-only"
    fi

    set -a
    # shellcheck disable=SC1090
    source "${config_file}"
    set +a
fi

for command_name in docker findmnt df awk find sort; do
    if command -v "${command_name}" >/dev/null 2>&1; then
        pass "Required command is available: ${command_name}"
    else
        fail "Required command is unavailable: ${command_name}"
    fi
done

if docker info >/dev/null 2>&1; then
    pass "Docker daemon is available"
else
    fail "Docker daemon is unavailable"
fi

if docker compose version >/dev/null 2>&1; then
    pass "Docker Compose v2 is available"
else
    fail "Docker Compose v2 is unavailable"
fi

for image_variable in ALLOY_IMAGE PROMETHEUS_IMAGE LOKI_IMAGE GRAFANA_IMAGE; do
    image_reference="${!image_variable:-}"
    if [[ "${image_reference}" =~ ^[^[:space:]@]+:[^[:space:]@]+@sha256:[0-9a-f]{64}$ ]]; then
        pass "${image_variable} uses a tagged immutable digest"
    else
        fail "${image_variable} must use image:tag@sha256:<64 lowercase hex characters>"
    fi
done

for directory_variable in \
    HOMELAB07_OBSERVABILITY_ROOT \
    HOMELAB07_OBSERVABILITY_METRICS_ROOT \
    HOMELAB07_NPM_LOG_ROOT; do
    directory_path="${!directory_variable:-}"
    if [[ "${directory_path}" != /* ]]; then
        fail "${directory_variable} must be an absolute path"
    elif [[ ! -d "${directory_path}" ]]; then
        fail "${directory_variable} does not exist"
    elif [[ ! -r "${directory_path}" || ! -x "${directory_path}" ]]; then
        fail "${directory_variable} is not readable and traversable"
    else
        directory_real="$(cd "${directory_path}" && pwd -P)"
        if is_within "${directory_real}" "${PROJECT_ROOT}" ||
            is_within "${directory_real}" "${PRIVATE_ROOT}"; then
            fail "${directory_variable} overlaps a protected repository boundary"
        else
            pass "${directory_variable} is available outside protected boundaries"
        fi
    fi
done

for writable_path in \
    "${HOMELAB07_OBSERVABILITY_ROOT:-}" \
    "${HOMELAB07_OBSERVABILITY_METRICS_ROOT:-}"; do
    if [[ -n "${writable_path}" && -w "${writable_path}" ]]; then
        pass "Required runtime path is writable by the operator"
    else
        fail "A required runtime path is not writable by the operator"
    fi
done

for private_file_variable in \
    HOMELAB07_OBSERVABILITY_PROBE_TARGETS_FILE \
    HOMELAB07_STORAGE_INVENTORY_FILE; do
    private_file="${!private_file_variable:-}"
    if [[ "${private_file}" != /* || ! -s "${private_file}" ]]; then
        fail "${private_file_variable} must reference an absolute non-empty private file"
    else
        mode="$(file_mode "${private_file}")"
        if [[ "${mode}" =~ ^[0-7]{3,4}$ ]] && ((10#${mode} % 100 == 0)); then
            pass "${private_file_variable} is owner-only"
        else
            fail "${private_file_variable} permissions are broader than owner-only"
        fi
    fi
done

if is_private_ipv4 "${GRAFANA_LAN_BIND_ADDRESS:-}"; then
    pass "Grafana declares an explicit RFC1918 IPv4 LAN bind address"
else
    fail "GRAFANA_LAN_BIND_ADDRESS must be an explicit RFC1918 IPv4 address"
fi

grafana_port="${GRAFANA_LAN_PORT:-3000}"
if [[ "${grafana_port}" =~ ^[0-9]+$ ]] &&
    ((grafana_port >= 1 && grafana_port <= 65535)); then
    pass "Grafana LAN port is valid"
else
    fail "GRAFANA_LAN_PORT must be between 1 and 65535"
fi

runtime_subdirectories=(prometheus loki alloy grafana)
runtime_owners=(65534 10001 0 472)
for index in "${!runtime_subdirectories[@]}"; do
    runtime_subdirectory="${runtime_subdirectories[${index}]}"
    expected_owner="${runtime_owners[${index}]}"
    path="${HOMELAB07_OBSERVABILITY_ROOT:-}/${runtime_subdirectory}"
    if [[ ! -d "${path}" ]]; then
        fail "Runtime directory is missing: ${runtime_subdirectory}"
    else
        actual_owner="$(stat -c '%u' "${path}" 2>/dev/null || stat -f '%u' "${path}" 2>/dev/null || true)"
        owner_mode="$(file_mode "${path}")"
        if [[ "${actual_owner}" == "${expected_owner}" ]] &&
            [[ "${owner_mode}" =~ ^[0-7]{3,4}$ ]] &&
            (( (10#${owner_mode} / 100) % 10 & 2 )); then
            pass "Runtime directory owner and write mode match: ${runtime_subdirectory}"
        else
            fail "Runtime directory ownership differs from the declared container user: ${runtime_subdirectory}"
        fi
    fi
done

if ((failure_count == 0)); then
    if compose observability config --quiet; then
        pass "Observability Compose definition renders successfully"
    else
        fail "Observability Compose definition does not render"
    fi
fi

echo
if ((failure_count > 0)); then
    echo "Observability preflight failed with ${failure_count} required-control failure(s)."
    exit 1
fi

echo "Observability preflight completed successfully."
