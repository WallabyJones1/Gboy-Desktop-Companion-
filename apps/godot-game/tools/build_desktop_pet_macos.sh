#!/bin/zsh

set -euo pipefail

SCRIPT_DIR="${0:A:h}"
PROJECT_DIR="${PROJECT_DIR:-${SCRIPT_DIR:h}}"
GODOT_BIN="${GODOT_BIN:-$(command -v godot || true)}"
EXPORT_PRESET="${EXPORT_PRESET:-macOS Pet}"
OUTPUT_APP="${OUTPUT_APP:-${PROJECT_DIR}/build/Gboy Companion.app}"
TEMPLATE_VERSION="${TEMPLATE_VERSION:-4.6.1.stable}"
TEMPLATE_RELEASE_TAG="${TEMPLATE_RELEASE_TAG:-4.6.1-stable}"
TEMPLATE_DIR="${HOME}/Library/Application Support/Godot/export_templates/${TEMPLATE_VERSION}"
TEMPLATE_ARCHIVE="${TEMPLATE_DIR}/Godot_v${TEMPLATE_RELEASE_TAG}_export_templates.tpz"
TEMPLATE_URL="${TEMPLATE_URL:-https://github.com/godotengine/godot-builds/releases/download/${TEMPLATE_RELEASE_TAG}/Godot_v${TEMPLATE_RELEASE_TAG}_export_templates.tpz}"

if [[ ! -x "${GODOT_BIN}" ]]; then
  echo "Godot binary not found at ${GODOT_BIN}" >&2
  exit 1
fi

mkdir -p "${TEMPLATE_DIR}"
mkdir -p "$(dirname "${OUTPUT_APP}")"

if [[ ! -f "${TEMPLATE_DIR}/macos.zip" ]]; then
  if [[ ! -f "${TEMPLATE_ARCHIVE}" ]]; then
    echo "Downloading Godot export templates..."
    curl -L "${TEMPLATE_URL}" -o "${TEMPLATE_ARCHIVE}"
  fi

  echo "Installing export templates..."
  unzip -o -q "${TEMPLATE_ARCHIVE}" -d "${TEMPLATE_DIR}"
fi

echo "Exporting standalone pet app to ${OUTPUT_APP}"
"${GODOT_BIN}" --headless --path "${PROJECT_DIR}" --export-release "${EXPORT_PRESET}" "${OUTPUT_APP}"
echo "Done."
