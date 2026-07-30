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
require_backup_command jq
require_backup_command restic
require_backup_command sha256sum
require_backup_command tar

echo "Running backup preflight..."
"${SCRIPT_DIR}/backup-preflight.sh"
echo

require_initialized_repository
backup_started_epoch="$(date +%s)"
backup_started_utc="$(date -u '+%Y-%m-%dT%H:%M:%SZ')"

if ! docker info >/dev/null 2>&1; then
    echo "Docker daemon is unavailable."
    exit 1
fi

if [[ -n "$(git -C "${PROJECT_ROOT}" status --porcelain)" ]]; then
    echo "Repository worktree must be clean before creating a recovery point."
    echo "Commit or intentionally remove pending changes, then retry."
    exit 1
fi

npm_data_root="$(read_backup_private_value nginx-proxy-manager HOMELAB07_DATA_ROOT)"
nextcloud_root="$(read_backup_private_value nextcloud NEXTCLOUD_ROOT)"
paperless_root="$(read_backup_private_value paperless-ngx PAPERLESS_ROOT)"
jellyfin_root="$(read_backup_private_value jellyfin JELLYFIN_ROOT)"
homebridge_root="$(read_backup_private_value homebridge HOMEBRIDGE_DATA_ROOT)"
npm_root="${npm_data_root}/nginx-proxy-manager"

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
data_backup_events="${HOMELAB07_BACKUP_STAGING_ROOT}/.data-backup-events.$$"
manifest_backup_events="${HOMELAB07_BACKUP_STAGING_ROOT}/.manifest-backup-events.$$"
exclude_file="${HOMELAB07_BACKUP_STAGING_ROOT}/.backup-exclude.$$"
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
    if [[ "${paperless_running}" == true ]]; then
        compose_service paperless-ngx up -d >/dev/null 2>&1 || restore_failure=1
    fi
    if [[ "${jellyfin_running}" == true ]]; then
        compose_service jellyfin up -d >/dev/null 2>&1 || restore_failure=1
    fi
    if [[ "${homebridge_running}" == true ]]; then
        compose_service homebridge up -d >/dev/null 2>&1 || restore_failure=1
    fi
    if [[ "${npm_running}" == true ]]; then
        compose_service nginx-proxy-manager up -d >/dev/null 2>&1 || restore_failure=1
    fi

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
    rm -f -- \
        "${data_backup_events:-}" \
        "${manifest_backup_events:-}" \
        "${exclude_file:-}"
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

echo "Capturing repository identity and recovery artifacts..."
git -C "${PROJECT_ROOT}" bundle create "${run_dir}/repository.bundle" --all

docker exec homelab07-mariadb sh -c \
    'MYSQL_PWD="$MARIADB_ROOT_PASSWORD" mariadb -N -uroot -e "SHOW DATABASES"' \
    > "${run_dir}/databases.txt"

docker inspect -f '{{.Name}}|{{.Config.Image}}|{{.Image}}' \
    homelab07-mariadb \
    homelab07-valkey \
    homelab07-nginx-proxy-manager \
    homelab07-nextcloud \
    homelab07-nextcloud-cron \
    homelab07-paperless-ngx \
    homelab07-jellyfin \
    homelab07-homebridge \
    homelab07-cloudflare-ddns \
    homelab07-landing-page \
    > "${run_dir}/images.txt"

{
    echo "${RESTIC_PASSWORD_FILE}"
    echo "${PRIVATE_ROOT}/backups"
    echo "${HOMELAB07_BACKUP_STAGING_ROOT}"
    echo "${jellyfin_root}/cache"
} > "${exclude_file}"

echo "Writing encrypted platform snapshot..."
restic_command backup --json \
    --tag homelab07-platform-state \
    --exclude-file "${exclude_file}" \
    "${run_dir}" \
    "${PROJECT_ROOT}" \
    "${PRIVATE_ROOT}" \
    "${npm_root}" \
    "${nextcloud_root}" \
    "${paperless_root}" \
    "${jellyfin_root}/config" \
    "${homebridge_root}" \
    > "${data_backup_events}"

data_summary="$(jq -s '[.[] | select(.message_type == "summary")] | last' "${data_backup_events}")"
data_snapshot_id="$(jq -r '.snapshot_id // empty' <<<"${data_summary}")"
total_bytes_processed="$(jq -r '.total_bytes_processed // 0' <<<"${data_summary}")"
data_added="$(jq -r '.data_added // 0' <<<"${data_summary}")"

if [[ ! "${data_snapshot_id}" =~ ^[0-9a-f]{64}$ ]]; then
    echo "Restic did not return a valid platform snapshot identifier."
    exit 1
fi

echo "Verifying repository metadata..."
restic_command check

git_revision="$(git -C "${PROJECT_ROOT}" rev-parse HEAD)"
git_ref="$(git -C "${PROJECT_ROOT}" describe --always)"
restic_version="$(restic version | head -1)"
database_dump_sha256="$(sha256sum "${run_dir}/mariadb-all.sql" | awk '{print $1}')"
repository_bundle_sha256="$(sha256sum "${run_dir}/repository.bundle" | awk '{print $1}')"
database_dump_size="$(backup_file_size "${run_dir}/mariadb-all.sql")"
repository_bundle_size="$(backup_file_size "${run_dir}/repository.bundle")"
databases_json="$(jq -R -s 'split("\n") | map(select(length > 0))' "${run_dir}/databases.txt")"
images_json="$(jq -R -s '
    split("\n")
    | map(select(length > 0) | split("|")
      | {service: .[0] | ltrimstr("/"), configured_image: .[1], runtime_image_id: .[2]})
  ' "${run_dir}/images.txt")"

keep_daily="${HOMELAB07_BACKUP_KEEP_DAILY:-7}"
keep_weekly="${HOMELAB07_BACKUP_KEEP_WEEKLY:-4}"
keep_monthly="${HOMELAB07_BACKUP_KEEP_MONTHLY:-6}"
keep_yearly="${HOMELAB07_BACKUP_KEEP_YEARLY:-1}"
for retention_value in "${keep_daily}" "${keep_weekly}" "${keep_monthly}" "${keep_yearly}"; do
    if [[ ! "${retention_value}" =~ ^[0-9]+$ ]]; then
        echo "Retention values must be non-negative integers."
        exit 1
    fi
done

echo "Restoring prior runtime state..."
if ! restore_runtime_state; then
    echo "One or more services could not be restored automatically."
    exit 1
fi

backup_finished_utc="$(date -u '+%Y-%m-%dT%H:%M:%SZ')"
backup_duration_seconds="$(( $(date +%s) - backup_started_epoch ))"
manifest_file="${run_dir}/backup-manifest.json"
jq -n \
    --arg manifest_version "${BACKUP_MANIFEST_VERSION}" \
    --arg timestamp "${backup_finished_utc}" \
    --arg started "${backup_started_utc}" \
    --arg snapshot_id "${data_snapshot_id}" \
    --arg git_revision "${git_revision}" \
    --arg git_ref "${git_ref}" \
    --arg operation_version "${BACKUP_OPERATION_VERSION}" \
    --arg restic_version "${restic_version}" \
    --arg database_dump_sha256 "${database_dump_sha256}" \
    --arg repository_bundle_sha256 "${repository_bundle_sha256}" \
    --argjson database_dump_size "${database_dump_size}" \
    --argjson repository_bundle_size "${repository_bundle_size}" \
    --argjson total_bytes_processed "${total_bytes_processed}" \
    --argjson data_added "${data_added}" \
    --argjson duration_seconds "${backup_duration_seconds}" \
    --argjson databases "${databases_json}" \
    --argjson images "${images_json}" \
    --argjson keep_daily "${keep_daily}" \
    --argjson keep_weekly "${keep_weekly}" \
    --argjson keep_monthly "${keep_monthly}" \
    --argjson keep_yearly "${keep_yearly}" \
    '{
      manifest_version: $manifest_version,
      timestamp_utc: $timestamp,
      backup_started_utc: $started,
      restic_snapshot: {
        id: $snapshot_id,
        tag: "homelab07-platform-state"
      },
      git: {
        revision: $git_revision,
        ref: $git_ref,
        worktree_status: "clean",
        bundle_artifact: "repository.bundle"
      },
      operation: {
        version: $operation_version,
        scripts_git_revision: $git_revision
      },
      components: [
        "repository", "private-configuration", "mariadb",
        "nginx-proxy-manager", "nextcloud", "paperless-ngx",
        "jellyfin", "homebridge", "landing-page", "valkey",
        "cloudflare-ddns"
      ],
      services: $images,
      databases_exported: $databases,
      git_repositories: [
        {role: "platform-source", revision: $git_revision, artifact: "repository.bundle"}
      ],
      artifacts: [
        {
          name: "mariadb-all.sql",
          sha256: $database_dump_sha256,
          size_bytes: $database_dump_size
        },
        {
          name: "repository.bundle",
          sha256: $repository_bundle_sha256,
          size_bytes: $repository_bundle_size
        }
      ],
      backup: {
        total_bytes_processed: $total_bytes_processed,
        data_added_bytes: $data_added,
        duration_seconds: $duration_seconds,
        restic_version: $restic_version
      },
      retention_policy: {
        keep_daily: $keep_daily,
        keep_weekly: $keep_weekly,
        keep_monthly: $keep_monthly,
        keep_yearly: $keep_yearly,
        applied_by_backup: false
      },
      validations: {
        preflight: "pass",
        database_dump_non_empty: "pass",
        git_worktree_clean: "pass",
        restic_metadata_check: "pass",
        runtime_state_restored: "pass"
      }
    }' > "${manifest_file}"

jq -e '
    .manifest_version == "1.0.0"
    and (.timestamp_utc | type == "string")
    and (.backup_started_utc | type == "string")
    and (.restic_snapshot.id | test("^[0-9a-f]{64}$"))
    and .restic_snapshot.tag == "homelab07-platform-state"
    and .git.worktree_status == "clean"
    and (.operation.version | type == "string" and length > 0)
    and (.services | type == "array" and length > 0)
    and (.databases_exported | type == "array" and length > 0)
    and (.git_repositories | type == "array" and length > 0)
    and (.artifacts | length >= 2)
    and ([.artifacts[] |
      (.name | test("^[A-Za-z0-9][A-Za-z0-9._-]*$"))
      and (.sha256 | test("^[0-9a-f]{64}$"))
      and (.size_bytes | type == "number" and . > 0)
    ] | all)
    and (.components | length >= 1)
    and (.backup.total_bytes_processed | type == "number" and . >= 0)
    and (.backup.data_added_bytes | type == "number" and . >= 0)
    and (.backup.duration_seconds | type == "number" and . >= 0)
    and (.backup.restic_version | type == "string" and length > 0)
    and (.retention_policy.applied_by_backup == false)
    and (.validations | type == "object" and length > 0)
    and ([.validations[]] | all(. == "pass"))
  ' "${manifest_file}" >/dev/null

echo "Writing versioned recovery manifest snapshot..."
restic_command backup --json \
    --tag homelab07-recovery-manifest \
    "${manifest_file}" \
    > "${manifest_backup_events}"

manifest_summary="$(jq -s '[.[] | select(.message_type == "summary")] | last' "${manifest_backup_events}")"
manifest_snapshot_id="$(jq -r '.snapshot_id // empty' <<<"${manifest_summary}")"
if [[ ! "${manifest_snapshot_id}" =~ ^[0-9a-f]{64}$ ]]; then
    echo "Restic did not return a valid manifest snapshot identifier."
    exit 1
fi

echo
echo "Consistent encrypted recovery point created successfully."
echo "  Manifest contract : ${BACKUP_MANIFEST_VERSION}"
echo "  Data snapshot     : ${data_snapshot_id:0:12}"
echo "  Manifest snapshot : ${manifest_snapshot_id:0:12}"
echo "Run ./operation/restore-test.sh latest <empty-destination> before applying retention."
