#!/usr/bin/env bash
set -euo pipefail

PROJECT_NAME="ctfd"
IMAGE_FILE="offline-images/nightowl-images.tar"

if [ ! -f "${IMAGE_FILE}" ]; then
  echo "ERROR: ${IMAGE_FILE} not found."
  echo "Copy the image archive created by export-offline.sh into this project."
  exit 1
fi

echo "[1/4] Checking Docker..."
docker info >/dev/null

echo "[2/4] Loading pre-exported Docker images..."
docker load -i "${IMAGE_FILE}"

echo "[3/4] Validating Compose..."
docker compose -p "${PROJECT_NAME}" config >/dev/null

echo "[4/4] Starting CTFd without pulling/building..."
docker compose -p "${PROJECT_NAME}" up -d --no-build

echo
echo "Current status:"
docker compose -p "${PROJECT_NAME}" ps

echo
echo "Open: http://localhost"
