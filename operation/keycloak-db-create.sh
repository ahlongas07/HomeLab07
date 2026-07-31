#!/usr/bin/env bash

source "${BASH_SOURCE%/*}/lib.sh"
print_header "Keycloak Database Create"
print_project_root

readonly MARIADB_ENV="${PRIVATE_ROOT}/env/mariadb.env"
readonly KEYCLOAK_ENV="${PRIVATE_ROOT}/env/keycloak.env"
read_value() { awk -v key="$2" 'index($0, key "=") == 1 { print substr($0, length(key) + 2); exit }' "$1"; }
for file in "${MARIADB_ENV}" "${KEYCLOAK_ENV}"; do
    [[ -f "${file}" ]] || { echo "Missing required private environment file:"; echo "  ${file}"; exit 1; }
done

root_password="$(read_value "${MARIADB_ENV}" MARIADB_ROOT_PASSWORD)"
database="$(read_value "${KEYCLOAK_ENV}" KEYCLOAK_DB_NAME)"
username="$(read_value "${KEYCLOAK_ENV}" KEYCLOAK_DB_USERNAME)"
password="$(read_value "${KEYCLOAK_ENV}" KEYCLOAK_DB_PASSWORD)"
for value_name in root_password database username password; do
    [[ -n "${!value_name}" ]] || { echo "Missing required private value: ${value_name}"; exit 1; }
done
for identifier in "${database}" "${username}"; do
    [[ "${identifier}" =~ ^[A-Za-z0-9_]+$ ]] || { echo "Invalid SQL identifier: ${identifier}"; exit 1; }
done
sql_string() { local value="${1//\\/\\\\}"; value="${value//\'/\'\'}"; printf "'%s'" "${value}"; }

docker exec -i -e MYSQL_PWD="${root_password}" homelab07-mariadb mariadb -u root <<SQL
CREATE DATABASE IF NOT EXISTS \`${database}\` CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
CREATE USER IF NOT EXISTS '${username}'@'%' IDENTIFIED BY $(sql_string "${password}");
ALTER USER '${username}'@'%' IDENTIFIED BY $(sql_string "${password}");
GRANT ALL PRIVILEGES ON \`${database}\`.* TO '${username}'@'%';
FLUSH PRIVILEGES;
SHOW GRANTS FOR '${username}'@'%';
SQL
print_footer

