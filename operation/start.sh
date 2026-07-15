#!/usr/bin/env bash

set -euo pipefail

# Resolve the repository root regardless of the current working directory.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

echo "========================================="
echo " Starting HomeLab07"
echo "========================================="
echo

echo "Project Root:"
echo "  ${PROJECT_ROOT}"
echo

echo "Starting Landing Page..."

docker compose \
    -f "${PROJECT_ROOT}/services/landing-page/compose.yaml" \
    up -d

echo
echo "HomeLab07 started successfully."
