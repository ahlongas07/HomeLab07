#!/usr/bin/env bash

source "${BASH_SOURCE%/*}/lib.sh"

print_header "Status"

print_project_root

echo "Platform"
echo

echo "  Landing Page"
echo

compose_service landing-page ps

print_footer
