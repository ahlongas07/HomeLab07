#!/usr/bin/env bash

source "${BASH_SOURCE%/*}/backup-lib.sh"

print_header "Disposable Restore"
print_project_root

if (($# != 2)); then
    echo "Usage: $0 <manifest-snapshot-id|latest> <empty-destination>"
    exit 1
fi

snapshot_id="$1"
restore_target="$2"

load_backup_environment
require_backup_command jq
require_backup_command restic
require_backup_command sha256sum
require_initialized_repository

if [[ "${restore_target}" != /* ]]; then
    echo "Restore destination must be an absolute path."
    exit 1
fi

case "${restore_target}" in
    /|"${PROJECT_ROOT}"|"${PRIVATE_ROOT}"|"${HOMELAB07_BACKUP_STAGING_ROOT}"|"${RESTIC_REPOSITORY}")
        echo "Restore destination is a protected path."
        exit 1
        ;;
esac

for protected_root in "${PROJECT_ROOT}" "${PRIVATE_ROOT}" "${HOMELAB07_BACKUP_STAGING_ROOT}"; do
    if [[ "${restore_target}" == "${protected_root}/"* || "${protected_root}" == "${restore_target}/"* ]]; then
        echo "Restore destination overlaps a protected path."
        exit 1
    fi
done


production_roots=(
    "$(read_backup_private_value mariadb HOMELAB07_DATA_ROOT)"
    "$(read_backup_private_value nextcloud NEXTCLOUD_ROOT)"
    "$(read_backup_private_value paperless-ngx PAPERLESS_ROOT)"
    "$(read_backup_private_value jellyfin JELLYFIN_ROOT)"
    "$(read_backup_private_value homebridge HOMEBRIDGE_DATA_ROOT)"
)

for production_root in "${production_roots[@]}"; do
    if [[ "${restore_target}" == "${production_root}" ||
        "${restore_target}" == "${production_root}/"* ||
        "${production_root}" == "${restore_target}/"* ]]; then
        echo "Restore destination overlaps a production storage boundary."
        exit 1
    fi
done

if [[ -e "${restore_target}" ]]; then
    if [[ ! -d "${restore_target}" ]]; then
        echo "Restore destination exists and is not a directory."
        exit 1
    fi
    if find "${restore_target}" -mindepth 1 -print -quit | grep -q .; then
        echo "Restore destination must be empty."
        exit 1
    fi
else
    parent="$(dirname "${restore_target}")"
    if [[ ! -d "${parent}" || ! -w "${parent}" ]]; then
        echo "Restore destination parent must exist and be writable."
        exit 1
    fi
    mkdir "${restore_target}"
fi

acquire_backup_lock
trap release_backup_lock EXIT

echo "Restoring versioned recovery manifest..."
restic_command restore "${snapshot_id}" \
    --tag homelab07-recovery-manifest \
    --target "${restore_target}"

manifest_count="$(find "${restore_target}" -type f -name backup-manifest.json | wc -l | tr -d ' ')"

if ((manifest_count != 1)); then
    echo "Manifest snapshot must contain exactly one backup-manifest.json."
    exit 1
fi

manifest_file="$(find "${restore_target}" -type f -name backup-manifest.json -print -quit)"
if ! jq -e \
    --arg version "${BACKUP_MANIFEST_VERSION}" \
    '.manifest_version == $version
     and (.timestamp_utc | type == "string")
     and (.backup_started_utc | type == "string")
     and (.restic_snapshot.id | test("^[0-9a-f]{64}$"))
     and .restic_snapshot.tag == "homelab07-platform-state"
     and .git.worktree_status == "clean"
     and (.git.revision | type == "string" and length > 0)
     and (.operation.version | type == "string" and length > 0)
     and (.operation.scripts_git_revision | type == "string" and length > 0)
     and (.components | type == "array" and length > 0)
     and (.services | type == "array" and length > 0)
     and (.databases_exported | type == "array" and length > 0)
     and (.git_repositories | type == "array" and length > 0)
     and (.artifacts | type == "array" and length > 0)
     and ([.artifacts[] |
       (.name | test("^[A-Za-z0-9][A-Za-z0-9._-]*$"))
       and (.sha256 | test("^[0-9a-f]{64}$"))
       and (.size_bytes | type == "number" and . > 0)
     ] | all)
     and (.backup.total_bytes_processed | type == "number" and . >= 0)
     and (.backup.data_added_bytes | type == "number" and . >= 0)
     and (.backup.duration_seconds | type == "number" and . >= 0)
     and (.backup.restic_version | type == "string" and length > 0)
     and (.retention_policy | type == "object")
     and (.retention_policy.applied_by_backup == false)
     and (.validations | type == "object" and length > 0)
     and ([.validations[]] | all(. == "pass"))' \
    "${manifest_file}" >/dev/null; then
    echo "Recovery manifest does not satisfy the supported contract."
    exit 1
fi

data_snapshot_id="$(jq -r '.restic_snapshot.id' "${manifest_file}")"

echo "Restoring referenced encrypted platform snapshot..."
restic_command restore "${data_snapshot_id}" \
    --tag homelab07-platform-state \
    --target "${restore_target}"

artifact_failures=0
artifact_count=0
while IFS=$'\t' read -r artifact_name expected_sha256 expected_size; do
    artifact_count=$((artifact_count + 1))
    matching_artifacts=()
    while IFS= read -r artifact_path; do
        matching_artifacts+=("${artifact_path}")
    done < <(find "${restore_target}" -type f -name "${artifact_name}")

    if ((${#matching_artifacts[@]} != 1)); then
        artifact_failures=$((artifact_failures + 1))
        continue
    fi

    actual_sha256="$(sha256sum "${matching_artifacts[0]}" | awk '{print $1}')"
    actual_size="$(backup_file_size "${matching_artifacts[0]}")"
    if [[ "${actual_sha256}" != "${expected_sha256}" || "${actual_size}" != "${expected_size}" ]]; then
        artifact_failures=$((artifact_failures + 1))
    fi
done < <(jq -r '.artifacts[] | [.name, .sha256, .size_bytes] | @tsv' "${manifest_file}")

if ((artifact_count < 1 || artifact_failures > 0)); then
    echo "Restored artifact checksum or size validation failed."
    exit 1
fi

database_dump_count="$(find "${restore_target}" -type f -name '*.sql' -size +0c | wc -l | tr -d ' ')"
if ((database_dump_count < 1)); then
    echo "Restored data snapshot does not contain a non-empty database dump."
    exit 1
fi

echo
echo "Disposable restore completed."
echo "  Manifest contract    : ${BACKUP_MANIFEST_VERSION}"
echo "  Referenced snapshot  : ${data_snapshot_id:0:12}"
echo "  Validated artifacts  : ${artifact_count}"
echo "  Database dump files  : ${database_dump_count}"
echo
echo "No restored service was started and no production path was modified."
