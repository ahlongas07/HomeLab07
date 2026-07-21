#!/usr/bin/env bash

source "${BASH_SOURCE%/*}/lib.sh"

print_header "Status"

print_project_root

echo "Platform"
echo

echo "  MariaDB"
echo

compose_service mariadb ps

echo
echo "  Valkey"
echo

compose_service valkey ps

echo
echo "  Nginx Proxy Manager"
echo

compose_service nginx-proxy-manager ps

echo
echo "  Nextcloud PoC"
echo

compose_service nextcloud ps

echo
echo "  Cloudflare Dynamic DNS"
echo

compose_service cloudflare-ddns ps

echo
echo "  Landing Page"
echo

compose_service landing-page ps

print_footer
