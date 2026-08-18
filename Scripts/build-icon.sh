#!/bin/zsh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
SOURCE_IMAGE="$PROJECT_DIR/Assets/WorkIsland.png"
OUTPUT_ICON="$PROJECT_DIR/Assets/WorkIsland.icns"
APP_ICONSET_DIR="$PROJECT_DIR/AppStore/Assets.xcassets/AppIcon.appiconset"
TASK_TEMP_DIR="$(mktemp -d "${TMPDIR:-/tmp}/work-island-icon.XXXXXX")"
ICONSET_DIR="$TASK_TEMP_DIR/WorkIsland.iconset"

trap 'rm -rf "$TASK_TEMP_DIR"' EXIT

if [[ ! -f "$SOURCE_IMAGE" ]]; then
    echo "Missing icon source: $SOURCE_IMAGE" >&2
    exit 1
fi

mkdir -p "$ICONSET_DIR"
mkdir -p "$APP_ICONSET_DIR"

make_icon() {
    local size="$1"
    local filename="$2"
    sips -z "$size" "$size" "$SOURCE_IMAGE" \
        --out "$ICONSET_DIR/$filename" >/dev/null
    cp "$ICONSET_DIR/$filename" "$APP_ICONSET_DIR/$filename"
}

make_icon 16 icon_16x16.png
make_icon 32 icon_16x16@2x.png
make_icon 32 icon_32x32.png
make_icon 64 icon_32x32@2x.png
make_icon 128 icon_128x128.png
make_icon 256 icon_128x128@2x.png
make_icon 256 icon_256x256.png
make_icon 512 icon_256x256@2x.png
make_icon 512 icon_512x512.png
make_icon 1024 icon_512x512@2x.png

iconutil -c icns "$ICONSET_DIR" -o "$OUTPUT_ICON"
echo "$OUTPUT_ICON"
