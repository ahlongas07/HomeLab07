#!/usr/bin/env bash

source "${BASH_SOURCE%/*}/lib.sh"

print_header "Paperless-ngx Database Drop"
print_project_root

readonly MARIADB_ENV="${PRIVATE_ROOT}/env/mariadb.env"
readonly PAPERLESS_ENV="${PRIVATE_ROOT}/env/paperless-ngx.env"

read_value() { awk -v key="$2" 'index($0, key "=") == 1 { print substr($0, length(key) + 2); exit }' "$1"; }
[[ -f "${MARIADB_ENV}" && -f "${PAPERLESS_ENV}" ]] || { echo "Missing private environment file."; exit 1; }

root_password="$(read_value "${MARIADB_ENV}" MARIADB_ROOT_PASSWORD)"
db_name="$(read_value "${PAPERLESS_ENV}" PAPERLESS_DB_NAME)"
db_user="$(read_value "${PAPERLESS_ENV}" PAPERLESS_DB_USERNAME)"

[[ -n "${root_password}" && "${db_name}" =~ ^[A-Za-z0-9_]+$ && "${db_user}" =~ ^[A-Za-z0-9_]+$ ]] || {
    echo "Missing or invalid private database configuration."
    exit 1
}

echo "This operation permanently drops the Paperless-ngx database and user."
echo "Type the database name (${db_name}) to confirm:"
read -r confirmation
[[ "${confirmation}" == "${db_name}" ]] || { echo "Confirmation did not match. No changes were made."; exit 1; }

docker exec -i -e MYSQL_PWD="${root_password}" homelab07-mariadb mariadb -u root <<SQL
DROP DATABASE IF EXISTS \`${db_name}\`;
DROP USER IF EXISTS '${db_user}'@'%';
FLUSH PRIVILEGES;
SQL

print_footer
