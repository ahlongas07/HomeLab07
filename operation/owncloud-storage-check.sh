#!/usr/bin/env bash

source "${BASH_SOURCE%/*}/lib.sh"

print_header "OwnCloud Storage Check"

print_project_root

readonly OWNCLOUD_ENV="${PRIVATE_ROOT}/env/owncloud.env"

read_env_value() {
    local file="$1"
    local key="$2"

    awk -v key="${key}" '
        index($0, key "=") == 1 {
            print substr($0, length(key) + 2)
            found = 1
            exit
        }
        END {
            if (!found) {
                exit 0
            }
        }
    ' "${file}"
}

require_file() {
    local file="$1"

    if [[ ! -f "${file}" ]]; then
        echo "Missing required private environment file:"
        echo "  ${file}"
        exit 1
    fi
}

require_value() {
    local name="$1"
    local value="$2"

    if [[ -z "${value}" ]]; then
        echo "Missing required value:"
        echo "  ${name}"
        exit 1
    fi
}

require_absolute_path() {
    local name="$1"
    local value="$2"

    if [[ "${value}" != /* ]]; then
        echo "Invalid path for ${name}:"
        echo "  ${value}"
        echo
        echo "The path must be absolute."
        exit 1
    fi
}

require_file "${OWNCLOUD_ENV}"

OWNCLOUD_DATA_ROOT="$(read_env_value "${OWNCLOUD_ENV}" "OWNCLOUD_DATA_ROOT")"

require_value "OWNCLOUD_DATA_ROOT" "${OWNCLOUD_DATA_ROOT}"
require_absolute_path "OWNCLOUD_DATA_ROOT" "${OWNCLOUD_DATA_ROOT}"

echo "OwnCloud data root:"
echo "  ${OWNCLOUD_DATA_ROOT}"
echo

if [[ ! -d "${OWNCLOUD_DATA_ROOT}" ]]; then
    echo "The OwnCloud data root does not exist."
    echo
    echo "Create the dedicated NAS-backed directory before starting OwnCloud."
    exit 1
fi

echo "Host path ownership and permissions:"
ls -ldn "${OWNCLOUD_DATA_ROOT}"
echo

echo "Current top-level layout:"
find "${OWNCLOUD_DATA_ROOT}" -maxdepth 2 -printf '%M %u:%g %p\n'
echo

if [[ -f "${OWNCLOUD_DATA_ROOT}/files/.ocdata" ]]; then
    echo "OwnCloud data marker found:"
    echo "  ${OWNCLOUD_DATA_ROOT}/files/.ocdata"
else
    echo "OwnCloud data marker not found yet:"
    echo "  ${OWNCLOUD_DATA_ROOT}/files/.ocdata"
    echo
    echo "This is expected before first initialization. If the service already"
    echo "installed successfully, storage and database state may be inconsistent."
fi

print_footer
