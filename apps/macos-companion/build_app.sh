#!/bin/zsh

set -euo pipefail

# Resolve paths relative to this script so the repo works on any machine
SCRIPT_DIR="${0:A:h}"
ROOT_DIR="${SCRIPT_DIR}"
SPRITE_SOURCE_DIR="${SCRIPT_DIR}/../godot-game/assets/sprites/player"
EXTRA_SPRITE_SOURCE_DIR="${ROOT_DIR}/Assets/Sprites"
AI_SOURCE_DIR="${ROOT_DIR}/Assets/AI"
APP_ICON_SOURCE="${ROOT_DIR}/Assets/AppIconSource.png"
BUILD_DIR="${ROOT_DIR}/build"
APP_NAME="Gboy Companion Native"
EXECUTABLE_NAME="gboy-companion-native"
APP_DIR="${BUILD_DIR}/${APP_NAME}.app"
MACOS_DIR="${APP_DIR}/Contents/MacOS"
RESOURCES_DIR="${APP_DIR}/Contents/Resources"
ICONSET_DIR="${BUILD_DIR}/AppIcon.iconset"
ICON_FILE="${RESOURCES_DIR}/AppIcon.icns"

rm -rf "${RESOURCES_DIR}/Sprites" "${RESOURCES_DIR}/Sounds" "${RESOURCES_DIR}/AI" "${ICONSET_DIR}" "${ICON_FILE}"
mkdir -p "${BUILD_DIR}" "${MACOS_DIR}" "${RESOURCES_DIR}/Sprites"
mkdir -p "${RESOURCES_DIR}/Sounds" "${RESOURCES_DIR}/AI"

python3 "${ROOT_DIR}/scripts/generate_variant_sheets.py"
python3 "${ROOT_DIR}/scripts/generate_app_icon.py"

swiftc \
  -O \
  -framework AppKit \
  -framework AVFoundation \
  -framework QuartzCore \
  -framework ImageIO \
  "${ROOT_DIR}/Sources/"*.swift \
  -o "${MACOS_DIR}/${EXECUTABLE_NAME}"

sprite_names=("${(@f)$(ruby -e "
  source = File.read('${ROOT_DIR}/Sources/CompanionController.swift')
  puts source.scan(/sheetName: \"([^\"]+)\"/).flatten.map { |name| name.sub(/_sheet\\.png\$/, '') }.uniq.sort
")}")

for name in "${sprite_names[@]}"; do
  file_name="${name}_sheet.png"
  if [[ -f "${SPRITE_SOURCE_DIR}/${file_name}" ]]; then
    cp "${SPRITE_SOURCE_DIR}/${file_name}" "${RESOURCES_DIR}/Sprites/"
  elif [[ -f "${EXTRA_SPRITE_SOURCE_DIR}/${file_name}" ]]; then
    cp "${EXTRA_SPRITE_SOURCE_DIR}/${file_name}" "${RESOURCES_DIR}/Sprites/"
  else
    echo "Missing sprite sheet: ${file_name}" >&2
    exit 1
  fi
done

for extra_file in "${EXTRA_SPRITE_SOURCE_DIR}"/*.png; do
  [[ -e "${extra_file}" ]] || continue
  cp "${extra_file}" "${RESOURCES_DIR}/Sprites/"
done

cp "${ROOT_DIR}/Assets/psonic_blast.wav" "${RESOURCES_DIR}/Sounds/"

if [[ -d "${AI_SOURCE_DIR}" ]]; then
  cp "${AI_SOURCE_DIR}/"* "${RESOURCES_DIR}/AI/"
fi

if [[ -f "${APP_ICON_SOURCE}" ]]; then
  python3 - <<PY
from pathlib import Path
from PIL import Image

source = Path("${APP_ICON_SOURCE}")
iconset = Path("${ICONSET_DIR}")
iconset.mkdir(parents=True, exist_ok=True)
image = Image.open(source).convert("RGBA")
sizes = [16, 32, 128, 256, 512]
for size in sizes:
    resized = image.resize((size, size), Image.Resampling.LANCZOS)
    resized.save(iconset / f"icon_{size}x{size}.png")
    resized_2x = image.resize((size * 2, size * 2), Image.Resampling.LANCZOS)
    resized_2x.save(iconset / f"icon_{size}x{size}@2x.png")
PY
  iconutil -c icns "${ICONSET_DIR}" -o "${ICON_FILE}"
  cp "${APP_ICON_SOURCE}" "${BUILD_DIR}/Gboy.Companion.Icon.png"
fi

cat > "${APP_DIR}/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleDevelopmentRegion</key>
  <string>English</string>
  <key>CFBundleExecutable</key>
  <string>gboy-companion-native</string>
  <key>CFBundleIconFile</key>
  <string>AppIcon</string>
  <key>CFBundleIdentifier</key>
  <string>io.github.gboy.companion.native</string>
  <key>CFBundleInfoDictionaryVersion</key>
  <string>6.0</string>
  <key>CFBundleName</key>
  <string>Gboy Companion Native</string>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>CFBundleShortVersionString</key>
  <string>1.0</string>
  <key>CFBundleVersion</key>
  <string>1</string>
  <key>LSApplicationCategoryType</key>
  <string>public.app-category.entertainment</string>
  <key>LSMinimumSystemVersion</key>
  <string>13.0</string>
  <key>LSUIElement</key>
  <true/>
</dict>
</plist>
PLIST

touch "${APP_DIR}/Contents/PkgInfo"

echo "Built ${APP_DIR}"
