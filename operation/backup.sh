#!/usr/bin/env bash

source "${BASH_SOURCE%/*}/backup-lib.sh"

print_header "Consistent Platform Backup"
print_project_root

if (($# != 0)); then
    echo "Usage: $0"
    exit 1
fi

load_backup_environment
require_backup_command docker
require_backup_command git
require_backup_command restic
require_backup_command tar

echo "Running backup preflight..."
"${SCRIPT_DIR}/backup-preflight.sh"
echo

require_initialized_repository

if ! docker info >/dev/null 2>&1; then
    echo "Docker daemon is unavailable."
    exit 1
fi

if [[ -n "$(git -C "${PROJECT_ROOT}" status --porcelain)" ]]; then
    echo "Repository worktree must be clean before creating a recovery point."
    echo "Commit or intentionally remove pending changes, then retry."
    exit 1
fi

shared_data_root="$(read_backup_private_value mariadb HOMELAB07_DATA_ROOT)"
nextcloud_root="$(read_backup_private_value nextcloud NEXTCLOUD_ROOT)"
paperless_root="$(read_backup_private_value paperless-ngx PAPERLESS_ROOT)"
jellyfin_root="$(read_backup_private_value jellyfin JELLYFIN_ROOT)"
homebridge_root="$(read_backup_private_value homebridge HOMEBRIDGE_DATA_ROOT)"
npm_root="${shared_data_root}/nginx-proxy-manager"

for required_root in \
    "${npm_root}" \
    "${nextcloud_root}" \
    "${paperless_root}" \
    "${jellyfin_root}/config" \
    "${homebridge_root}"; do
    if [[ ! -d "${required_root}" ]]; then
        echo "A required production state root is unavailable."
        exit 1
    fi
done

acquire_backup_lock

run_dir="$(mktemp -d "${HOMELAB07_BACKUP_STAGING_ROOT}/run.XXXXXX")"
services_restored=false
nextcloud_maintenance=false

container_was_running() {
    [[ "$(docker inspect -f '{{.State.Running}}' "$1" 2>/dev/null || true)" == "true" ]]
}

npm_running=false
nextcloud_running=false
nextcloud_cron_running=false
paperless_running=false
jellyfin_running=false
homebridge_running=false

container_was_running homelab07-nginx-proxy-manager && npm_running=true
container_was_running homelab07-nextcloud && nextcloud_running=true
container_was_running homelab07-nextcloud-cron && nextcloud_cron_running=true
container_was_running homelab07-paperless-ngx && paperless_running=true
container_was_running homelab07-jellyfin && jellyfin_running=true
container_was_running homelab07-homebridge && homebridge_running=true

restore_runtime_state() {
    local restore_failure=0

    if [[ "${nextcloud_running}" == true ]]; then
        compose_service nextcloud up -d nextcloud >/dev/null 2>&1 || restore_failure=1
    fi
    if [[ "${nextcloud_cron_running}" == true ]]; then
        compose_service nextcloud up -d nextcloud-cron >/dev/null 2>&1 || restore_failure=1
    fi
    [[ "${paperless_running}" == true ]] && compose_service paperless-ngx up -d >/dev/null 2>&1 || true
    [[ "${jellyfin_running}" == true ]] && compose_service jellyfin up -d >/dev/null 2>&1 || true
    [[ "${homebridge_running}" == true ]] && compose_service homebridge up -d >/dev/null 2>&1 || true
    [[ "${npm_running}" == true ]] && compose_service nginx-proxy-manager up -d >/dev/null 2>&1 || true

    if [[ "${nextcloud_maintenance}" == true && "${nextcloud_running}" == true ]]; then
        maintenance_disabled=false
        for _attempt in 1 2 3 4 5 6 7 8 9 10 11 12; do
            if docker exec --user www-data homelab07-nextcloud \
                php occ maintenance:mode --off >/dev/null 2>&1; then
                maintenance_disabled=true
                break
            fi
            sleep 5
        done
        [[ "${maintenance_disabled}" == true ]] || restore_failure=1
    fi

    services_restored=true
    return "${restore_failure}"
}

cleanup_backup() {
    local original_status=$?
    local cleanup_status=0

    trap - EXIT INT TERM

    if [[ "${services_restored}" != true ]]; then
        restore_runtime_state || cleanup_status=1
    fi

    if [[ -n "${run_dir:-}" && -d "${run_dir}" ]]; then
        rm -rf -- "${run_dir}"
    fi
    release_backup_lock

    if ((cleanup_status != 0)); then
        echo "WARNING: one or more services could not be restored automatically." >&2
        echo "Run ./operation/status.sh and restore only the previously running services." >&2
        exit 1
    fi

    exit "${original_status}"
}

trap cleanup_backup EXIT INT TERM

echo "Preparing consistent application state..."

if [[ "${nextcloud_running}" == true ]]; then
    docker exec --user www-data homelab07-nextcloud \
        php occ maintenance:mode --on >/dev/null
    nextcloud_maintenance=true
fi

[[ "${npm_running}" == true ]] && compose_service nginx-proxy-manager stop >/dev/null
if [[ "${nextcloud_running}" == true || "${nextcloud_cron_running}" == true ]]; then
    compose_service nextcloud stop >/dev/null
fi
[[ "${paperless_running}" == true ]] && compose_service paperless-ngx stop >/dev/null
[[ "${jellyfin_running}" == true ]] && compose_service jellyfin stop >/dev/null
[[ "${homebridge_running}" == true ]] && compose_service homebridge stop >/dev/null

if ! container_was_running homelab07-mariadb; then
    echo "MariaDB must remain running to create a logical recovery dump."
    exit 1
fi

echo "Creating logical database recovery dump..."
docker exec homelab07-mariadb sh -c \
    'exec mariadb-dump --all-databases --single-transaction --quick --routines --events --triggers --hex-blob -uroot -p"$MARIADB_ROOT_PASSWORD"' \
    > "${run_dir}/mariadb-all.sql"

if [[ ! -s "${run_dir}/mariadb-all.sql" ]]; then
    echo "MariaDB recovery dump is empty."
    exit 1
fi

echo "Capturing repository identity and sanitized manifest..."
git -C "${PROJECT_ROOT}" bundle create "${run_dir}/repository.bundle" --all

{
    echo "format=homelab07-backup-v1"
    echo "created_utc=$(date -u '+%Y-%m-%dT%H:%M:%SZ')"
    echo "git_commit=$(git -C "${PROJECT_ROOT}" rev-parse HEAD)"
    echo "git_ref=$(git -C "${PROJECT_ROOT}" describe --always --dirty)"
    echo "database_dump=mariadb-all.sql"
    echo "components=repository,private-config,mariadb,npm,nextcloud,paperless,jellyfin,homebridge"
    docker inspect -f 'image_{{.Name}}={{.Image}}' \
        homelab07-mariadb \
        homelab07-nginx-proxy-manager \
        homelab07-nextcloud \
        homelab07-paperless-ngx \
        homelab07-jellyfin \
        homelab07-homebridge 2>/dev/null || true
} > "${run_dir}/manifest.txt"

exclude_file="${run_dir}/exclude.txt"
{
    echo "${RESTIC_PASSWORD_FILE}"
    echo "${PRIVATE_ROOT}/backups"
    echo "${HOMELAB07_BACKUP_STAGING_ROOT}"
    echo "${jellyfin_root}/cache"
} > "${exclude_file}"

echo "Writing encrypted platform snapshot..."
restic_command backup --quiet \
    --tag homelab07-platform-state \
    --exclude-file "${exclude_file}" \
    "${run_dir}" \
    "${PROJECT_ROOT}" \
    "${PRIVATE_ROOT}" \
    "${npm_root}" \
    "${nextcloud_root}" \
    "${paperless_root}" \
    "${jellyfin_root}/config" \
    "${homebridge_root}"

echo "Verifying repository metadata..."
restic_command check

echo "Restoring prior runtime state..."
restore_runtime_state

echo
echo "Consistent encrypted recovery point created successfully."
echo "Run ./operation/restore-test.sh latest <empty-destination> before applying retention."
