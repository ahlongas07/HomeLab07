#!/usr/bin/env bash

source "${BASH_SOURCE%/*}/lib.sh"
print_header "Keycloak Database Drop"
print_project_root
readonly MARIADB_ENV="${PRIVATE_ROOT}/env/mariadb.env"
readonly KEYCLOAK_ENV="${PRIVATE_ROOT}/env/keycloak.env"
read_value() { awk -v key="$2" 'index($0, key "=") == 1 { print substr($0, length(key) + 2); exit }' "$1"; }
for file in "${MARIADB_ENV}" "${KEYCLOAK_ENV}"; do [[ -f "${file}" ]] || { echo "Missing required file: ${file}"; exit 1; }; done
root_password="$(read_value "${MARIADB_ENV}" MARIADB_ROOT_PASSWORD)"
database="$(read_value "${KEYCLOAK_ENV}" KEYCLOAK_DB_NAME)"
username="$(read_value "${KEYCLOAK_ENV}" KEYCLOAK_DB_USERNAME)"
[[ "${database}" =~ ^[A-Za-z0-9_]+$ && "${username}" =~ ^[A-Za-z0-9_]+$ ]] || { echo "Invalid SQL identifier."; exit 1; }
echo "Type the database name (${database}) to permanently remove the PoC database and user:"
read -r confirmation
[[ "${confirmation}" == "${database}" ]] || { echo "Confirmation did not match. No changes were made."; exit 1; }
docker exec -i -e MYSQL_PWD="${root_password}" homelab07-mariadb mariadb -u root <<SQL
DROP DATABASE IF EXISTS \`${database}\`;
DROP USER IF EXISTS '${username}'@'%';
FLUSH PRIVILEGES;
SQL
print_footer
