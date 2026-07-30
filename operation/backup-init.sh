#!/usr/bin/env bash

source "${BASH_SOURCE%/*}/backup-lib.sh"

print_header "Initialize Backup Repository"
print_project_root

load_backup_environment
require_backup_command restic
acquire_backup_lock
trap release_backup_lock EXIT

if restic_command cat config >/dev/null 2>&1; then
    echo "Restic repository is already initialized and accessible."
    exit 0
fi

echo "Initializing encrypted Restic repository..."
restic_command init

echo
echo "Verifying repository metadata..."
restic_command check

print_footer
