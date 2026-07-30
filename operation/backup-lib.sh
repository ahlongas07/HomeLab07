#!/usr/bin/env bash

source "${BASH_SOURCE%/*}/lib.sh"

readonly BACKUP_ENV_FILE="${PRIVATE_ROOT}/env/backup.env"

backup_file_mode() {
    stat -c '%a' "$1" 2>/dev/null || stat -f '%Lp' "$1" 2>/dev/null || true
}

backup_require_owner_only_file() {
    local path="$1"
    local label="$2"
    local mode

    if [[ ! -s "${path}" ]]; then
        echo "${label} is missing or empty."
        exit 1
    fi

    mode="$(backup_file_mode "${path}")"
    if [[ ! "${mode}" =~ ^[0-7]{3,4}$ ]] || ((10#${mode} % 100 != 0)); then
        echo "${label} must not be accessible to group or other users."
        exit 1
    fi
}

load_backup_environment() {
    if [[ ! -f "${BACKUP_ENV_FILE}" ]]; then
        echo "Missing private backup environment file:"
        echo "  ${BACKUP_ENV_FILE}"
        echo
        echo "Create it from:"
        echo "  ${PROJECT_ROOT}/operation/backup.env.example"
        exit 1
    fi

    backup_require_owner_only_file "${BACKUP_ENV_FILE}" "Private backup environment file"

    set -a
    # shellcheck disable=SC1090
    source "${BACKUP_ENV_FILE}"
    set +a

    : "${RESTIC_REPOSITORY:?RESTIC_REPOSITORY is required}"
    : "${RESTIC_PASSWORD_FILE:?RESTIC_PASSWORD_FILE is required}"
    : "${HOMELAB07_BACKUP_STAGING_ROOT:?HOMELAB07_BACKUP_STAGING_ROOT is required}"

    backup_require_owner_only_file "${RESTIC_PASSWORD_FILE}" "Restic password file"

    if [[ ! -d "${HOMELAB07_BACKUP_STAGING_ROOT}" || ! -w "${HOMELAB07_BACKUP_STAGING_ROOT}" ]]; then
        echo "Backup staging root must exist and be writable by the operator."
        exit 1
    fi

    umask 077
}

require_backup_command() {
    local command_name="$1"

    if ! command -v "${command_name}" >/dev/null 2>&1; then
        echo "Required backup command is unavailable: ${command_name}"
        exit 1
    fi
}

read_backup_private_value() {
    local service="$1"
    local variable="$2"
    local env_file="${PRIVATE_ROOT}/env/${service}.env"

    if [[ ! -f "${env_file}" ]]; then
        echo "Missing private environment file for ${service}." >&2
        return 1
    fi

    (
        set +u
        # shellcheck disable=SC1090
        source "${env_file}"
        printf '%s' "${!variable:-}"
    )
}

restic_command() {
    restic \
        --repo "${RESTIC_REPOSITORY}" \
        --password-file "${RESTIC_PASSWORD_FILE}" \
        "$@"
}

acquire_backup_lock() {
    readonly BACKUP_LOCK_DIR="${HOMELAB07_BACKUP_STAGING_ROOT}/.homelab07-backup.lock"

    if ! mkdir "${BACKUP_LOCK_DIR}" 2>/dev/null; then
        echo "Another HomeLab07 backup operation appears to be active."
        exit 1
    fi
}

release_backup_lock() {
    if [[ -n "${BACKUP_LOCK_DIR:-}" && -d "${BACKUP_LOCK_DIR}" ]]; then
        rmdir "${BACKUP_LOCK_DIR}" 2>/dev/null || true
    fi
}

require_initialized_repository() {
    if ! restic_command cat config >/dev/null 2>&1; then
        echo "Restic repository is not initialized or is not accessible."
        echo "Run ./operation/backup-init.sh after preflight succeeds."
        exit 1
    fi
}
