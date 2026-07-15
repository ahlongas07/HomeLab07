#!/usr/bin/env bash

source "${BASH_SOURCE%/*}/lib.sh"

print_header "Stop"

print_project_root

echo "Stopping Landing Page..."

compose landing-page down

echo
echo "Stopping Nginx Proxy Manager..."

compose nginx-proxy-manager down

echo
echo "Stopping MariaDB..."

compose mariadb down

echo
echo "HomeLab07 stopped successfully."
