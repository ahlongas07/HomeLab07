#!/usr/bin/env bash

source "${BASH_SOURCE%/*}/lib.sh"

print_header "Nextcloud Database Create"
print_project_root

readonly MARIADB_ENV="${PRIVATE_ROOT}/env/mariadb.env"
readonly NEXTCLOUD_ENV="${PRIVATE_ROOT}/env/nextcloud.env"

read_env_value() {
    local file="$1"
    local key="$2"

    awk -v key="${key}" '
        index($0, key "=") == 1 {
            print substr($0, length(key) + 2)
            exit
        }
    ' "${file}"
}

require_file() {
    local file="$1"
    [[ -f "${file}" ]] || {
        echo "Missing required private environment file:"
        echo "  ${file}"
        exit 1
    }
}

require_value() {
    local name="$1"
    local value="$2"
    [[ -n "${value}" ]] || {
        echo "Missing required value:"
        echo "  ${name}"
        exit 1
    }
}

require_identifier() {
    local name="$1"
    local value="$2"
    [[ "${value}" =~ ^[A-Za-z0-9_]+$ ]] || {
        echo "Invalid SQL identifier for ${name}:"
        echo "  ${value}"
        echo
        echo "Use only letters, numbers and underscores."
        exit 1
    }
}

sql_string() {
    local value="$1"
    value="${value//\\/\\\\}"
    value="${value//\'/\'\'}"
    printf "'%s'" "${value}"
}

require_file "${MARIADB_ENV}"
require_file "${NEXTCLOUD_ENV}"

MARIADB_ROOT_PASSWORD="$(read_env_value "${MARIADB_ENV}" "MARIADB_ROOT_PASSWORD")"
NEXTCLOUD_DB_NAME="$(read_env_value "${NEXTCLOUD_ENV}" "NEXTCLOUD_DB_NAME")"
NEXTCLOUD_DB_USERNAME="$(read_env_value "${NEXTCLOUD_ENV}" "NEXTCLOUD_DB_USERNAME")"
NEXTCLOUD_DB_PASSWORD="$(read_env_value "${NEXTCLOUD_ENV}" "NEXTCLOUD_DB_PASSWORD")"
NEXTCLOUD_DB_CHARSET="$(read_env_value "${NEXTCLOUD_ENV}" "NEXTCLOUD_DB_CHARSET")"
NEXTCLOUD_DB_COLLATION="$(read_env_value "${NEXTCLOUD_ENV}" "NEXTCLOUD_DB_COLLATION")"

require_value "MARIADB_ROOT_PASSWORD" "${MARIADB_ROOT_PASSWORD}"
require_value "NEXTCLOUD_DB_NAME" "${NEXTCLOUD_DB_NAME}"
require_value "NEXTCLOUD_DB_USERNAME" "${NEXTCLOUD_DB_USERNAME}"
require_value "NEXTCLOUD_DB_PASSWORD" "${NEXTCLOUD_DB_PASSWORD}"
require_value "NEXTCLOUD_DB_CHARSET" "${NEXTCLOUD_DB_CHARSET}"
require_value "NEXTCLOUD_DB_COLLATION" "${NEXTCLOUD_DB_COLLATION}"

require_identifier "NEXTCLOUD_DB_NAME" "${NEXTCLOUD_DB_NAME}"
require_identifier "NEXTCLOUD_DB_USERNAME" "${NEXTCLOUD_DB_USERNAME}"
require_identifier "NEXTCLOUD_DB_CHARSET" "${NEXTCLOUD_DB_CHARSET}"
require_identifier "NEXTCLOUD_DB_COLLATION" "${NEXTCLOUD_DB_COLLATION}"

echo "Creating Nextcloud database and user from private configuration."
echo
echo "Database: ${NEXTCLOUD_DB_NAME}"
echo "User: ${NEXTCLOUD_DB_USERNAME}@%"
echo "Character set: ${NEXTCLOUD_DB_CHARSET}"
echo "Collation: ${NEXTCLOUD_DB_COLLATION}"
echo

docker exec -i \
    -e MYSQL_PWD="${MARIADB_ROOT_PASSWORD}" \
    homelab07-mariadb \
    mariadb -u root <<SQL
CREATE DATABASE IF NOT EXISTS \`${NEXTCLOUD_DB_NAME}\`
CHARACTER SET ${NEXTCLOUD_DB_CHARSET}
COLLATE ${NEXTCLOUD_DB_COLLATION};

CREATE USER IF NOT EXISTS '${NEXTCLOUD_DB_USERNAME}'@'%'
IDENTIFIED BY $(sql_string "${NEXTCLOUD_DB_PASSWORD}");

ALTER USER '${NEXTCLOUD_DB_USERNAME}'@'%'
IDENTIFIED BY $(sql_string "${NEXTCLOUD_DB_PASSWORD}");

GRANT ALL PRIVILEGES
ON \`${NEXTCLOUD_DB_NAME}\`.*
TO '${NEXTCLOUD_DB_USERNAME}'@'%';

FLUSH PRIVILEGES;
SHOW GRANTS FOR '${NEXTCLOUD_DB_USERNAME}'@'%';
SQL

print_footer
