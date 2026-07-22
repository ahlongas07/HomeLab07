#!/usr/bin/env bash

source "${BASH_SOURCE%/*}/lib.sh"

print_header "Paperless-ngx Database Create"
print_project_root

readonly MARIADB_ENV="${PRIVATE_ROOT}/env/mariadb.env"
readonly PAPERLESS_ENV="${PRIVATE_ROOT}/env/paperless-ngx.env"

read_value() { awk -v key="$2" 'index($0, key "=") == 1 { print substr($0, length(key) + 2); exit }' "$1"; }
require_file() { [[ -f "$1" ]] || { echo "Missing required file: $1"; exit 1; }; }
require_value() { [[ -n "$2" ]] || { echo "Missing required value: $1"; exit 1; }; }
require_identifier() { [[ "$2" =~ ^[A-Za-z0-9_]+$ ]] || { echo "Invalid SQL identifier for $1: $2"; exit 1; }; }
sql_string() { local value="$1"; value="${value//\\/\\\\}"; value="${value//\'/\'\'}"; printf "'%s'" "${value}"; }

require_file "${MARIADB_ENV}"
require_file "${PAPERLESS_ENV}"

root_password="$(read_value "${MARIADB_ENV}" MARIADB_ROOT_PASSWORD)"
db_name="$(read_value "${PAPERLESS_ENV}" PAPERLESS_DB_NAME)"
db_user="$(read_value "${PAPERLESS_ENV}" PAPERLESS_DB_USERNAME)"
db_password="$(read_value "${PAPERLESS_ENV}" PAPERLESS_DB_PASSWORD)"
db_charset="$(read_value "${PAPERLESS_ENV}" PAPERLESS_DB_CHARSET)"
db_collation="$(read_value "${PAPERLESS_ENV}" PAPERLESS_DB_COLLATION)"

for pair in "MARIADB_ROOT_PASSWORD:${root_password}" "PAPERLESS_DB_NAME:${db_name}" \
    "PAPERLESS_DB_USERNAME:${db_user}" "PAPERLESS_DB_PASSWORD:${db_password}" \
    "PAPERLESS_DB_CHARSET:${db_charset}" "PAPERLESS_DB_COLLATION:${db_collation}"; do
    require_value "${pair%%:*}" "${pair#*:}"
done
require_identifier PAPERLESS_DB_NAME "${db_name}"
require_identifier PAPERLESS_DB_USERNAME "${db_user}"
require_identifier PAPERLESS_DB_CHARSET "${db_charset}"
require_identifier PAPERLESS_DB_COLLATION "${db_collation}"

echo "Creating Paperless-ngx database and least-privilege user."
echo "Database: ${db_name}"
echo "User: ${db_user}@%"

docker exec -i -e MYSQL_PWD="${root_password}" homelab07-mariadb mariadb -u root <<SQL
CREATE DATABASE IF NOT EXISTS \`${db_name}\` CHARACTER SET ${db_charset} COLLATE ${db_collation};
CREATE USER IF NOT EXISTS '${db_user}'@'%' IDENTIFIED BY $(sql_string "${db_password}");
ALTER USER '${db_user}'@'%' IDENTIFIED BY $(sql_string "${db_password}");
GRANT ALL PRIVILEGES ON \`${db_name}\`.* TO '${db_user}'@'%';
FLUSH PRIVILEGES;
SHOW GRANTS FOR '${db_user}'@'%';
SQL

print_footer
