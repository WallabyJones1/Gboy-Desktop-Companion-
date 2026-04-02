#!/bin/zsh

set -euo pipefail

SCRIPT_DIR="${0:A:h}"
APP_PATH="${SCRIPT_DIR}/build/Gboy Companion Native.app"
DESKTOP_DIR="${HOME}/Desktop"
LAUNCHER_NAME="Gboy.app"
LAUNCHER_PATH="${DESKTOP_DIR}/${LAUNCHER_NAME}"
LEGACY_ALIAS_PATH="${DESKTOP_DIR}/Launch Gboy Companion"
OLD_LAUNCHER_PATH="${DESKTOP_DIR}/Launch Gboy Companion.app"
OLD_SYMLINK_PATH="${DESKTOP_DIR}/Gboy.app"

if [[ ! -d "${APP_PATH}" ]]; then
  echo "Built app not found at ${APP_PATH}" >&2
  echo "Run ./build_app.sh first." >&2
  exit 1
fi

rm -rf "${LAUNCHER_PATH}" "${LEGACY_ALIAS_PATH}" "${OLD_LAUNCHER_PATH}" "${OLD_SYMLINK_PATH}"
cp -R "${APP_PATH}" "${LAUNCHER_PATH}"

echo "Desktop launcher created at ${LAUNCHER_PATH}"
