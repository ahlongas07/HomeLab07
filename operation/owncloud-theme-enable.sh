#!/usr/bin/env bash

source "${BASH_SOURCE%/*}/lib.sh"

print_header "OwnCloud Theme Enable"

print_project_root

readonly THEME_ID="theme-snowcone"

docker exec \
    --user www-data \
    --workdir /var/www/owncloud \
    homelab07-owncloud \
    php occ app:enable "${THEME_ID}"

docker exec \
    --user www-data \
    --workdir /var/www/owncloud \
    homelab07-owncloud \
    php occ config:system:set integrity.ignore.missing.app.signature 0 --value="${THEME_ID}"

docker exec \
    --user www-data \
    --workdir /var/www/owncloud \
    homelab07-owncloud \
    php occ config:system:set theme --value="${THEME_ID}"

docker exec \
    --user www-data \
    --workdir /var/www/owncloud \
    homelab07-owncloud \
    php occ app:list | grep -A 40 "Enabled:"

print_footer
