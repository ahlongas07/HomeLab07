#!/usr/bin/env bash

source "${BASH_SOURCE%/*}/backup-lib.sh"

print_header "Disposable Restore"
print_project_root

if (($# != 2)); then
    echo "Usage: $0 <snapshot-id|latest> <empty-destination>"
    exit 1
fi

snapshot_id="$1"
restore_target="$2"

load_backup_environment
require_backup_command restic
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

echo "Restoring encrypted snapshot into disposable destination..."
restic_command restore "${snapshot_id}" \
    --tag homelab07-platform-state \
    --target "${restore_target}"

manifest_count="$(find "${restore_target}" -type f -name manifest.txt | wc -l | tr -d ' ')"
database_dump_count="$(find "${restore_target}" -type f -name '*.sql' -size +0c | wc -l | tr -d ' ')"

if ((manifest_count < 1)); then
    echo "Restored snapshot does not contain the expected manifest."
    exit 1
fi

if ((database_dump_count < 1)); then
    echo "Restored snapshot does not contain a non-empty database dump."
    exit 1
fi

echo
echo "Disposable restore completed."
echo "  Manifest files       : ${manifest_count}"
echo "  Database dump files  : ${database_dump_count}"
echo
echo "No restored service was started and no production path was modified."
