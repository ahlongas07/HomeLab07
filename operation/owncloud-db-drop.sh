#!/usr/bin/env bash

source "${BASH_SOURCE%/*}/lib.sh"

print_header "OwnCloud Database Drop"

print_project_root

readonly MARIADB_ENV="${PRIVATE_ROOT}/env/mariadb.env"
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

require_identifier() {
    local name="$1"
    local value="$2"

    if [[ ! "${value}" =~ ^[A-Za-z0-9_]+$ ]]; then
        echo "Invalid SQL identifier for ${name}:"
        echo "  ${value}"
        echo
        echo "Use only letters, numbers and underscores."
        exit 1
    fi
}

require_file "${MARIADB_ENV}"
require_file "${OWNCLOUD_ENV}"

MARIADB_ROOT_PASSWORD="$(read_env_value "${MARIADB_ENV}" "MARIADB_ROOT_PASSWORD")"
OWNCLOUD_DB_NAME="$(read_env_value "${OWNCLOUD_ENV}" "OWNCLOUD_DB_NAME")"
OWNCLOUD_DB_USERNAME="$(read_env_value "${OWNCLOUD_ENV}" "OWNCLOUD_DB_USERNAME")"

require_value "MARIADB_ROOT_PASSWORD" "${MARIADB_ROOT_PASSWORD}"
require_value "OWNCLOUD_DB_NAME" "${OWNCLOUD_DB_NAME}"
require_value "OWNCLOUD_DB_USERNAME" "${OWNCLOUD_DB_USERNAME}"

require_identifier "OWNCLOUD_DB_NAME" "${OWNCLOUD_DB_NAME}"
require_identifier "OWNCLOUD_DB_USERNAME" "${OWNCLOUD_DB_USERNAME}"

echo "This operation will permanently drop:"
echo
echo "Database:"
echo "  ${OWNCLOUD_DB_NAME}"
echo
echo "User:"
echo "  ${OWNCLOUD_DB_USERNAME}@%"
echo
echo "Type the database name to confirm:"
read -r confirmation

if [[ "${confirmation}" != "${OWNCLOUD_DB_NAME}" ]]; then
    echo "Confirmation did not match. No changes were made."
    exit 1
fi

docker exec -i \
    -e MARIADB_PWD="${MARIADB_ROOT_PASSWORD}" \
    homelab07-mariadb \
    mariadb -u root <<SQL
DROP DATABASE IF EXISTS \`${OWNCLOUD_DB_NAME}\`;
DROP USER IF EXISTS '${OWNCLOUD_DB_USERNAME}'@'%';
FLUSH PRIVILEGES;
SQL

print_footer
