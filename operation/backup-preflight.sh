#!/usr/bin/env bash

source "${BASH_SOURCE%/*}/lib.sh"

print_header "Backup Preflight"
print_project_root

backup_env="${PRIVATE_ROOT}/env/backup.env"
pass_count=0
warning_count=0
failure_count=0

pass() {
    echo "[PASS] $1"
    pass_count=$((pass_count + 1))
}

warn() {
    echo "[WARN] $1"
    warning_count=$((warning_count + 1))
}

fail() {
    echo "[FAIL] $1"
    failure_count=$((failure_count + 1))
}

file_mode() {
    stat -c '%a' "$1" 2>/dev/null || stat -f '%Lp' "$1" 2>/dev/null || true
}

device_id() {
    stat -c '%d' "$1" 2>/dev/null || stat -f '%d' "$1" 2>/dev/null || true
}

is_within() {
    local candidate="$1"
    local boundary="$2"

    [[ "${candidate}" == "${boundary}" || "${candidate}" == "${boundary}/"* ]]
}

read_private_value() {
    local service="$1"
    local variable="$2"
    local env_file="${PRIVATE_ROOT}/env/${service}.env"

    [[ -f "${env_file}" ]] || return 1

    (
        set +u
        # Private files are trusted operator configuration and are never echoed.
        source "${env_file}"
        printf '%s' "${!variable:-}"
    )
}

echo "Prerequisites"
echo

for command_name in docker git jq restic sha256sum tar; do
    if command -v "${command_name}" >/dev/null 2>&1; then
        pass "Required command is available: ${command_name}"
    else
        fail "Required command is unavailable: ${command_name}"
    fi
done

if command -v docker >/dev/null 2>&1 && docker info >/dev/null 2>&1; then
    pass "Docker daemon is available"
else
    fail "Docker daemon is unavailable"
fi

echo
echo "Private backup configuration"
echo

if [[ ! -f "${backup_env}" ]]; then
    fail "Private backup environment file is missing"
    echo
    echo "Create it from:"
    echo "  operation/backup.env.example"
else
    backup_mode="$(file_mode "${backup_env}")"
    if [[ "${backup_mode}" =~ ^[0-7]{3,4}$ ]] && ((10#${backup_mode} % 100 == 0)); then
        pass "Private backup environment permissions are owner-only"
    else
        fail "Private backup environment permissions are broader than owner-only"
    fi

    set -a
    # shellcheck disable=SC1090
    source "${backup_env}"
    set +a

    required_variables=(
        RESTIC_REPOSITORY
        RESTIC_PASSWORD_FILE
        HOMELAB07_BACKUP_STAGING_ROOT
    )

    for variable in "${required_variables[@]}"; do
        if [[ -n "${!variable:-}" ]]; then
            pass "Required backup setting is defined: ${variable}"
        else
            fail "Required backup setting is missing: ${variable}"
        fi
    done
fi

if [[ -n "${RESTIC_PASSWORD_FILE:-}" ]]; then
    if [[ ! -s "${RESTIC_PASSWORD_FILE}" ]]; then
        fail "Restic password file is missing or empty"
    else
        password_mode="$(file_mode "${RESTIC_PASSWORD_FILE}")"
        if [[ "${password_mode}" =~ ^[0-7]{3,4}$ ]] && ((10#${password_mode} % 100 == 0)); then
            pass "Restic password file is non-empty and owner-only"
        else
            fail "Restic password file permissions are broader than owner-only"
        fi
    fi
fi

if [[ -n "${HOMELAB07_BACKUP_STAGING_ROOT:-}" ]]; then
    if [[ "${HOMELAB07_BACKUP_STAGING_ROOT}" != /* ]]; then
        fail "Backup staging root must be an absolute path"
    elif [[ ! -d "${HOMELAB07_BACKUP_STAGING_ROOT}" ]]; then
        fail "Backup staging root does not exist"
    elif [[ ! -w "${HOMELAB07_BACKUP_STAGING_ROOT}" ]]; then
        fail "Backup staging root is not writable by the operator"
    elif is_within "${HOMELAB07_BACKUP_STAGING_ROOT}" "${PROJECT_ROOT}" ||
        is_within "${HOMELAB07_BACKUP_STAGING_ROOT}" "${PRIVATE_ROOT}"; then
        fail "Backup staging root overlaps a protected project boundary"
    else
        pass "Backup staging root is absolute, available and outside protected roots"
    fi
fi

echo
echo "Production storage boundaries"
echo

production_roots=()
production_labels=()

while IFS='|' read -r service variable label; do
    value="$(read_private_value "${service}" "${variable}" || true)"
    if [[ -z "${value}" ]]; then
        fail "Production root is unavailable for ${label}"
    elif [[ ! -d "${value}" ]]; then
        fail "Production root does not exist for ${label}"
    else
        production_roots+=("${value}")
        production_labels+=("${label}")
        pass "Production root is available for ${label}"
    fi
done <<'ROOTS'
mariadb|HOMELAB07_DATA_ROOT|shared platform data
nextcloud|NEXTCLOUD_ROOT|collaboration state
paperless-ngx|PAPERLESS_ROOT|document state
jellyfin|JELLYFIN_ROOT|media application state
homebridge|HOMEBRIDGE_DATA_ROOT|HomeKit state
ROOTS

if [[ -n "${HOMELAB07_BACKUP_STAGING_ROOT:-}" && -d "${HOMELAB07_BACKUP_STAGING_ROOT}" ]]; then
    overlap_found=false
    for production_root in "${production_roots[@]}"; do
        if is_within "${HOMELAB07_BACKUP_STAGING_ROOT}" "${production_root}" ||
            is_within "${production_root}" "${HOMELAB07_BACKUP_STAGING_ROOT}"; then
            overlap_found=true
        fi
    done

    if [[ "${overlap_found}" == true ]]; then
        fail "Backup staging overlaps a production storage boundary"
    else
        pass "Backup staging does not overlap production storage"
    fi
fi

echo
echo "Repository boundary"
echo

if [[ -n "${RESTIC_REPOSITORY:-}" ]]; then
    if [[ "${RESTIC_REPOSITORY}" == /* ]]; then
        if is_within "${RESTIC_REPOSITORY}" "${PROJECT_ROOT}" ||
            is_within "${RESTIC_REPOSITORY}" "${PRIVATE_ROOT}" ||
            is_within "${RESTIC_REPOSITORY}" "${HOMELAB07_BACKUP_STAGING_ROOT:-/nonexistent}"; then
            fail "Local Restic repository overlaps a protected or staging boundary"
        fi

        repository_parent="${RESTIC_REPOSITORY}"
        while [[ ! -e "${repository_parent}" && "${repository_parent}" != "/" ]]; do
            repository_parent="$(dirname "${repository_parent}")"
        done

        if [[ ! -d "${repository_parent}" || ! -w "${repository_parent}" ]]; then
            fail "Local Restic repository parent is unavailable or not writable"
        else
            repository_device="$(device_id "${repository_parent}")"
            same_device=false
            for production_root in "${production_roots[@]}"; do
                [[ "$(device_id "${production_root}")" == "${repository_device}" ]] && same_device=true
            done

            if [[ "${same_device}" == true ]]; then
                fail "Local Restic repository shares a filesystem with production data"
            else
                pass "Local Restic repository uses an independent filesystem"
            fi
        fi
    else
        pass "Restic repository uses a non-local backend"
    fi
fi

echo
echo "Runtime readiness"
echo

required_containers=(
    homelab07-mariadb
    homelab07-nginx-proxy-manager
    homelab07-nextcloud
    homelab07-nextcloud-cron
    homelab07-paperless-ngx
    homelab07-jellyfin
    homelab07-homebridge
)

if command -v docker >/dev/null 2>&1 && docker info >/dev/null 2>&1; then
    for container_name in "${required_containers[@]}"; do
        if docker inspect "${container_name}" >/dev/null 2>&1; then
            container_state="$(docker inspect -f '{{.State.Status}}' "${container_name}")"
            if [[ "${container_state}" == "running" ]]; then
                pass "Required runtime is running: ${container_name#homelab07-}"
            else
                warn "Required runtime is present but not running: ${container_name#homelab07-}"
            fi
        else
            fail "Required runtime is absent: ${container_name#homelab07-}"
        fi
    done
fi

if ((failure_count == 0)) && command -v restic >/dev/null 2>&1; then
    if restic cat config >/dev/null 2>&1; then
        pass "Encrypted Restic repository is initialized and accessible"
    else
        warn "Restic repository is not initialized or is not yet accessible"
    fi
fi

echo
echo "Summary"
echo "  Pass     : ${pass_count}"
echo "  Warning  : ${warning_count}"
echo "  Failure  : ${failure_count}"
echo

if ((failure_count > 0)); then
    echo "Backup preflight failed. No service or backup state was changed."
    exit 1
fi

echo "Backup preflight completed without required-control failures."
