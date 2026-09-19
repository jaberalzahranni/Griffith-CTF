#!/usr/bin/env bash
set -euo pipefail

PROJECT_NAME="ctfd"

echo "=== Operation Nightowl / CTFd status ==="
docker compose -p "${PROJECT_NAME}" ps

echo
echo "=== Last 40 log lines ==="
docker compose -p "${PROJECT_NAME}" logs --tail=40
