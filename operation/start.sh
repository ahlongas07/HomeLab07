#!/usr/bin/env bash

source "${BASH_SOURCE%/*}/lib.sh"

print_header "Start"

print_project_root

echo "Starting MariaDB..."

compose mariadb up -d

echo
echo "Starting Landing Page..."

compose landing-page up -d

echo
echo "HomeLab07 started successfully."
