#!/usr/bin/env bash

source "${BASH_SOURCE%/*}/backup-lib.sh"

print_header "Backup Retention"
print_project_root

if (($# > 1)); then
    echo "Usage: $0 [--apply]"
    exit 1
fi

apply=false
if (($# == 1)); then
    if [[ "$1" != "--apply" ]]; then
        echo "Usage: $0 [--apply]"
        exit 1
    fi
    apply=true
fi

load_backup_environment
require_backup_command restic
require_initialized_repository

keep_daily="${HOMELAB07_BACKUP_KEEP_DAILY:-7}"
keep_weekly="${HOMELAB07_BACKUP_KEEP_WEEKLY:-4}"
keep_monthly="${HOMELAB07_BACKUP_KEEP_MONTHLY:-6}"
keep_yearly="${HOMELAB07_BACKUP_KEEP_YEARLY:-1}"

for value in "${keep_daily}" "${keep_weekly}" "${keep_monthly}" "${keep_yearly}"; do
    if [[ ! "${value}" =~ ^[0-9]+$ ]]; then
        echo "Retention values must be non-negative integers."
        exit 1
    fi
done

acquire_backup_lock
trap release_backup_lock EXIT

retention_args=(
    --keep-daily "${keep_daily}"
    --keep-weekly "${keep_weekly}"
    --keep-monthly "${keep_monthly}"
    --keep-yearly "${keep_yearly}"
)

if [[ "${apply}" == false ]]; then
    echo "Retention dry-run; no snapshots will be removed."
    for retention_tag in homelab07-platform-state homelab07-recovery-manifest; do
        restic_command forget --dry-run --tag "${retention_tag}" "${retention_args[@]}"
    done
    echo
    echo "Review the result, then run with --apply to remove snapshots and prune data."
    exit 0
fi

echo "Applying reviewed retention policy and pruning unreferenced data..."
for retention_tag in homelab07-platform-state homelab07-recovery-manifest; do
    restic_command forget --prune --tag "${retention_tag}" "${retention_args[@]}"
done

echo
echo "Verifying repository after retention..."
restic_command check

print_footer
