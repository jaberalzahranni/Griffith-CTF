#!/usr/bin/env bash
set -euo pipefail

PROJECT_NAME="ctfd"
OUT_DIR="offline-images"
OUT_FILE="${OUT_DIR}/nightowl-images.tar"

echo "[1/6] Checking Docker..."
docker info >/dev/null

echo "[2/6] Validating Compose..."
docker compose -p "${PROJECT_NAME}" config >/dev/null

echo "[3/6] Building/starting the tested stack..."
docker compose -p "${PROJECT_NAME}" up -d --build

echo "[4/6] Waiting briefly for containers to initialize..."
sleep 8

echo "[5/6] Collecting images used by this Compose project..."
mkdir -p "${OUT_DIR}"

mapfile_cmd_available=false
if command -v mapfile >/dev/null 2>&1; then
  mapfile_cmd_available=true
fi

# Works on macOS default Bash as well as newer Bash.
IMAGE_IDS="$(docker compose -p "${PROJECT_NAME}" images -q | awk 'NF' | sort -u)"

if [ -z "${IMAGE_IDS}" ]; then
  echo "ERROR: No images found for the Compose project."
  exit 1
fi

echo "Images to export:"
docker compose -p "${PROJECT_NAME}" images

# docker save accepts multiple image IDs/references.
# shellcheck disable=SC2086
docker save -o "${OUT_FILE}" ${IMAGE_IDS}

echo "[6/6] Done."
echo
echo "Created: ${OUT_FILE}"
du -h "${OUT_FILE}" || true
echo
echo "Copy the ENTIRE CTFd project directory, including ${OUT_FILE}, to the offline machine."
