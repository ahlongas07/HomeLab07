#!/usr/bin/env bash

source "${BASH_SOURCE%/*}/backup-lib.sh"

print_header "Backup Integrity Check"
print_project_root

if (($# > 1)); then
    echo "Usage: $0 [--full]"
    exit 1
fi

load_backup_environment
require_backup_command restic
require_initialized_repository
acquire_backup_lock
trap release_backup_lock EXIT

if (($# == 1)); then
    if [[ "$1" != "--full" ]]; then
        echo "Usage: $0 [--full]"
        exit 1
    fi
    echo "Reading and verifying all repository data..."
    restic_command check --read-data
else
    echo "Verifying repository metadata and structure..."
    restic_command check
fi

print_footer
