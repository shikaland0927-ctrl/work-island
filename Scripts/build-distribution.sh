#!/bin/zsh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
DIST_DIR="$PROJECT_DIR/dist.release.noindex"
APP_BUNDLE="$DIST_DIR/Work Island.app"
SUBMISSION_ZIP="$DIST_DIR/Work Island-notarization.zip"
IDENTITY="${CODE_SIGN_IDENTITY:-}"

if [[ -z "$IDENTITY" ]]; then
    print -u2 "Set CODE_SIGN_IDENTITY to a Developer ID Application identity."
    exit 1
fi

mkdir -p "$DIST_DIR"
touch "$DIST_DIR/.metadata_never_index"

zsh "$SCRIPT_DIR/build-icon.sh"
swift build \
    -c release \
    --arch arm64 \
    --arch x86_64 \
    --package-path "$PROJECT_DIR"

BINARY="$PROJECT_DIR/.build/apple/Products/Release/WorkIsland"

if [[ ! -x "$BINARY" ]]; then
    print -u2 "Universal release binary was not found: $BINARY"
    exit 1
fi

rm -rf "$APP_BUNDLE"
rm -f "$SUBMISSION_ZIP"
mkdir -p "$APP_BUNDLE/Contents/MacOS"
mkdir -p "$APP_BUNDLE/Contents/Resources"

ICON_RESOURCE_NAME="$(plutil -extract CFBundleIconFile raw "$PROJECT_DIR/Info.plist")"

cp "$BINARY" "$APP_BUNDLE/Contents/MacOS/WorkIsland"
cp "$PROJECT_DIR/Info.plist" "$APP_BUNDLE/Contents/Info.plist"
cp "$PROJECT_DIR/Assets/WorkIsland.icns" "$APP_BUNDLE/Contents/Resources/$ICON_RESOURCE_NAME"
chmod +x "$APP_BUNDLE/Contents/MacOS/WorkIsland"

codesign \
    --force \
    --options runtime \
    --timestamp \
    --sign "$IDENTITY" \
    "$APP_BUNDLE"

codesign --verify --deep --strict --verbose=2 "$APP_BUNDLE"
ditto -c -k --sequesterRsrc --keepParent "$APP_BUNDLE" "$SUBMISSION_ZIP"

print "$APP_BUNDLE"
print "$SUBMISSION_ZIP"
