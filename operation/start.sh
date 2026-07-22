#!/usr/bin/env bash

source "${BASH_SOURCE%/*}/lib.sh"

print_header "Start"

print_project_root

echo "Starting MariaDB..."

compose mariadb up -d

echo
echo "Starting Valkey..."

compose valkey up -d

echo
echo "Starting Nginx Proxy Manager..."

compose nginx-proxy-manager up -d

echo
echo "Starting Nextcloud..."

compose nextcloud up -d

echo
echo "Starting Paperless-ngx..."

compose paperless-ngx up -d

echo
echo "Starting Cloudflare Dynamic DNS..."

compose cloudflare-ddns up -d

echo
echo "Starting Landing Page..."

compose landing-page up -d

echo
echo "HomeLab07 started successfully."
