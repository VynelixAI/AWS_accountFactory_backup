#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SRC_DIR="${ROOT_DIR}/lambda/account_request_handler"
OUT_ZIP="${SRC_DIR}.zip"
BUILD_DIR="${ROOT_DIR}/lambda/build"

echo "Packaging Lambda from ${SRC_DIR}"
rm -rf "${BUILD_DIR}"
mkdir -p "${BUILD_DIR}"
cp -r "${SRC_DIR}/"* "${BUILD_DIR}/"

python3 -m pip install -r "${SRC_DIR}/requirements.txt" -t "${BUILD_DIR}" --quiet --disable-pip-version-check

rm -f "${OUT_ZIP}"
( cd "${BUILD_DIR}" && zip -r "${OUT_ZIP}" . -x "*.pyc" -x "__pycache__/*" -x "*.dist-info/*" >/dev/null )
rm -rf "${BUILD_DIR}"

echo "Created ${OUT_ZIP}"
ls -lh "${OUT_ZIP}"
