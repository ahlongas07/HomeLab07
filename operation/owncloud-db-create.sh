#!/usr/bin/env bash

source "${BASH_SOURCE%/*}/lib.sh"

print_header "OwnCloud Database Create"

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

sql_string() {
    local value="$1"

    value="${value//\\/\\\\}"
    value="${value//\'/\'\'}"
    printf "'%s'" "${value}"
}

require_file "${MARIADB_ENV}"
require_file "${OWNCLOUD_ENV}"

MARIADB_ROOT_PASSWORD="$(read_env_value "${MARIADB_ENV}" "MARIADB_ROOT_PASSWORD")"
OWNCLOUD_DB_NAME="$(read_env_value "${OWNCLOUD_ENV}" "OWNCLOUD_DB_NAME")"
OWNCLOUD_DB_USERNAME="$(read_env_value "${OWNCLOUD_ENV}" "OWNCLOUD_DB_USERNAME")"
OWNCLOUD_DB_PASSWORD="$(read_env_value "${OWNCLOUD_ENV}" "OWNCLOUD_DB_PASSWORD")"
OWNCLOUD_DB_CHARSET="$(read_env_value "${OWNCLOUD_ENV}" "OWNCLOUD_DB_CHARSET")"
OWNCLOUD_DB_COLLATION="$(read_env_value "${OWNCLOUD_ENV}" "OWNCLOUD_DB_COLLATION")"

require_value "MARIADB_ROOT_PASSWORD" "${MARIADB_ROOT_PASSWORD}"
require_value "OWNCLOUD_DB_NAME" "${OWNCLOUD_DB_NAME}"
require_value "OWNCLOUD_DB_USERNAME" "${OWNCLOUD_DB_USERNAME}"
require_value "OWNCLOUD_DB_PASSWORD" "${OWNCLOUD_DB_PASSWORD}"
require_value "OWNCLOUD_DB_CHARSET" "${OWNCLOUD_DB_CHARSET}"
require_value "OWNCLOUD_DB_COLLATION" "${OWNCLOUD_DB_COLLATION}"

require_identifier "OWNCLOUD_DB_NAME" "${OWNCLOUD_DB_NAME}"
require_identifier "OWNCLOUD_DB_USERNAME" "${OWNCLOUD_DB_USERNAME}"
require_identifier "OWNCLOUD_DB_CHARSET" "${OWNCLOUD_DB_CHARSET}"
require_identifier "OWNCLOUD_DB_COLLATION" "${OWNCLOUD_DB_COLLATION}"

echo "Creating OwnCloud database and user from private configuration."
echo
echo "Database:"
echo "  ${OWNCLOUD_DB_NAME}"
echo
echo "User:"
echo "  ${OWNCLOUD_DB_USERNAME}@%"
echo
echo "Character Set:"
echo "  ${OWNCLOUD_DB_CHARSET}"
echo
echo "Collation:"
echo "  ${OWNCLOUD_DB_COLLATION}"
echo

docker exec -i \
    -e MYSQL_PWD="${MARIADB_ROOT_PASSWORD}" \
    homelab07-mariadb \
    mariadb -u root <<SQL
CREATE DATABASE IF NOT EXISTS \`${OWNCLOUD_DB_NAME}\`
CHARACTER SET ${OWNCLOUD_DB_CHARSET}
COLLATE ${OWNCLOUD_DB_COLLATION};

CREATE USER IF NOT EXISTS '${OWNCLOUD_DB_USERNAME}'@'%'
IDENTIFIED BY $(sql_string "${OWNCLOUD_DB_PASSWORD}");

ALTER USER '${OWNCLOUD_DB_USERNAME}'@'%'
IDENTIFIED BY $(sql_string "${OWNCLOUD_DB_PASSWORD}");

GRANT ALL PRIVILEGES
ON \`${OWNCLOUD_DB_NAME}\`.*
TO '${OWNCLOUD_DB_USERNAME}'@'%';

FLUSH PRIVILEGES;

SHOW GRANTS FOR '${OWNCLOUD_DB_USERNAME}'@'%';
SQL

print_footer
