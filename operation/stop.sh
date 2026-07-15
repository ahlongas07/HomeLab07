#!/usr/bin/env bash

set -euo pipefail

# Resolve the repository root regardless of the current working directory.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

echo "========================================="
echo " HomeLab07 Operations"
echo "-----------------------------------------"
echo " Action : Stop"
echo "========================================="
echo

echo "Project Root:"
echo "  ${PROJECT_ROOT}"
echo

echo "Stopping Landing Page..."

docker compose \
    -f "${PROJECT_ROOT}/services/landing-page/compose.yaml" \
    down

echo
echo "HomeLab07 stopped successfully."
