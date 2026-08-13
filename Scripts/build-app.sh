#!/bin/zsh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
DIST_DIR="$PROJECT_DIR/dist.noindex"
APP_BUNDLE="$DIST_DIR/Work Island.app"
ICON_RESOURCE_NAME="$(plutil -extract CFBundleIconFile raw "$PROJECT_DIR/Info.plist")"

mkdir -p "$DIST_DIR"
touch "$DIST_DIR/.metadata_never_index"

zsh "$SCRIPT_DIR/build-icon.sh"
swift build -c release --package-path "$PROJECT_DIR"
BIN_DIR="$(swift build -c release --package-path "$PROJECT_DIR" --show-bin-path)"

rm -rf "$APP_BUNDLE"
mkdir -p "$APP_BUNDLE/Contents/MacOS"
mkdir -p "$APP_BUNDLE/Contents/Resources"

cp "$BIN_DIR/WorkIsland" "$APP_BUNDLE/Contents/MacOS/WorkIsland"
cp "$PROJECT_DIR/Info.plist" "$APP_BUNDLE/Contents/Info.plist"
cp "$PROJECT_DIR/Assets/WorkIsland.icns" "$APP_BUNDLE/Contents/Resources/$ICON_RESOURCE_NAME"
chmod +x "$APP_BUNDLE/Contents/MacOS/WorkIsland"

codesign --force --deep --sign - "$APP_BUNDLE"

echo "$APP_BUNDLE"
