#!/usr/bin/env bash

source "${BASH_SOURCE%/*}/lib.sh"

print_header "OwnCloud Branding Apply"

print_project_root

readonly BRANDING_ROOT="${PROJECT_ROOT}/services/owncloud/theme-snowcone"
readonly CONTAINER="homelab07-owncloud"

require_file() {
    local file="$1"

    if [[ ! -f "${file}" ]]; then
        echo "Missing required branding file:"
        echo "  ${file}"
        exit 1
    fi
}

require_file "${BRANDING_ROOT}/core/img/favicon.svg"
require_file "${BRANDING_ROOT}/core/img/logo-icon.svg"
require_file "${BRANDING_ROOT}/core/img/logo.svg"

docker cp "${BRANDING_ROOT}/core/img/favicon.svg" "${CONTAINER}:/var/www/owncloud/core/img/favicon.svg"
docker cp "${BRANDING_ROOT}/core/img/logo-icon.svg" "${CONTAINER}:/var/www/owncloud/core/img/logo-icon.svg"
docker cp "${BRANDING_ROOT}/core/img/logo.svg" "${CONTAINER}:/var/www/owncloud/core/img/logo.svg"

docker exec \
    --user root \
    --workdir /var/www/owncloud \
    "${CONTAINER}" \
    chown www-data:www-data \
    core/img/favicon.svg \
    core/img/logo-icon.svg \
    core/img/logo.svg

echo
echo "Snow Cone branding assets were copied into the running OwnCloud container."
echo "Reapply this script after recreating or upgrading the OwnCloud container."

print_footer
