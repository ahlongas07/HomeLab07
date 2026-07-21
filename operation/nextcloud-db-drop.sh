#!/usr/bin/env bash

source "${BASH_SOURCE%/*}/lib.sh"

print_header "Nextcloud Database Drop"
print_project_root

readonly MARIADB_ENV="${PRIVATE_ROOT}/env/mariadb.env"
readonly NEXTCLOUD_ENV="${PRIVATE_ROOT}/env/nextcloud.env"

read_env_value() {
    local file="$1"
    local key="$2"
    awk -v key="${key}" 'index($0, key "=") == 1 { print substr($0, length(key) + 2); exit }' "${file}"
}

require_file() {
    [[ -f "$1" ]] || { echo "Missing required private environment file:"; echo "  $1"; exit 1; }
}

require_value() {
    [[ -n "$2" ]] || { echo "Missing required value:"; echo "  $1"; exit 1; }
}

require_identifier() {
    [[ "$2" =~ ^[A-Za-z0-9_]+$ ]] || {
        echo "Invalid SQL identifier for $1:"
        echo "  $2"
        exit 1
    }
}

require_file "${MARIADB_ENV}"
require_file "${NEXTCLOUD_ENV}"

MARIADB_ROOT_PASSWORD="$(read_env_value "${MARIADB_ENV}" "MARIADB_ROOT_PASSWORD")"
NEXTCLOUD_DB_NAME="$(read_env_value "${NEXTCLOUD_ENV}" "NEXTCLOUD_DB_NAME")"
NEXTCLOUD_DB_USERNAME="$(read_env_value "${NEXTCLOUD_ENV}" "NEXTCLOUD_DB_USERNAME")"

require_value "MARIADB_ROOT_PASSWORD" "${MARIADB_ROOT_PASSWORD}"
require_value "NEXTCLOUD_DB_NAME" "${NEXTCLOUD_DB_NAME}"
require_value "NEXTCLOUD_DB_USERNAME" "${NEXTCLOUD_DB_USERNAME}"
require_identifier "NEXTCLOUD_DB_NAME" "${NEXTCLOUD_DB_NAME}"
require_identifier "NEXTCLOUD_DB_USERNAME" "${NEXTCLOUD_DB_USERNAME}"

echo "This operation permanently drops the Nextcloud PoC database and user."
echo "Database: ${NEXTCLOUD_DB_NAME}"
echo "User: ${NEXTCLOUD_DB_USERNAME}@%"
echo
echo "Type the database name to confirm:"
read -r confirmation

if [[ "${confirmation}" != "${NEXTCLOUD_DB_NAME}" ]]; then
    echo "Confirmation did not match. No changes were made."
    exit 1
fi

docker exec -i \
    -e MYSQL_PWD="${MARIADB_ROOT_PASSWORD}" \
    homelab07-mariadb \
    mariadb -u root <<SQL
DROP DATABASE IF EXISTS \`${NEXTCLOUD_DB_NAME}\`;
DROP USER IF EXISTS '${NEXTCLOUD_DB_USERNAME}'@'%';
FLUSH PRIVILEGES;
SQL

print_footer
