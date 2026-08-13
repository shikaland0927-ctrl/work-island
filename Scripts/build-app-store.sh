#!/bin/zsh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
PROJECT_PATH="$PROJECT_DIR/WorkIsland.xcodeproj"
SCHEME="Work Island"
DIST_DIR="$PROJECT_DIR/dist.appstore.noindex"
DERIVED_DATA="$PROJECT_DIR/.build/xcode-app-store-derived"
SIGNING_DISABLED=false

for BUILD_ARGUMENT in "$@"; do
    if [[ "$BUILD_ARGUMENT" == "CODE_SIGNING_ALLOWED=NO" ]]; then
        SIGNING_DISABLED=true
    fi
done

mkdir -p "$DIST_DIR"
touch "$DIST_DIR/.metadata_never_index"

zsh "$SCRIPT_DIR/build-icon.sh"

BUILD_SETTINGS="$(xcodebuild \
    -project "$PROJECT_PATH" \
    -scheme "$SCHEME" \
    -configuration Release \
    -showBuildSettings)"

VERSION="$(print -r -- "$BUILD_SETTINGS" | awk '/ MARKETING_VERSION = / { print $3; exit }')"
BUILD="$(print -r -- "$BUILD_SETTINGS" | awk '/ CURRENT_PROJECT_VERSION = / { print $3; exit }')"
TIMESTAMP="$(date '+%Y%m%d-%H%M%S')"
ARCHIVE_PATH="$DIST_DIR/Work Island $VERSION ($BUILD)-$TIMESTAMP.xcarchive"

xcodebuild \
    -project "$PROJECT_PATH" \
    -scheme "$SCHEME" \
    -configuration Release \
    -destination "generic/platform=macOS" \
    -derivedDataPath "$DERIVED_DATA" \
    -archivePath "$ARCHIVE_PATH" \
    ARCHS="arm64 x86_64" \
    ONLY_ACTIVE_ARCH=NO \
    "$@" \
    archive

APP_BUNDLE="$ARCHIVE_PATH/Products/Applications/Work Island.app"
INFO_PLIST="$APP_BUNDLE/Contents/Info.plist"
BINARY="$APP_BUNDLE/Contents/MacOS/Work Island"

[[ "$(plutil -extract CFBundleIdentifier raw "$INFO_PLIST")" == "com.shikazeriku.workisland" ]]
[[ "$(plutil -extract CFBundleShortVersionString raw "$INFO_PLIST")" == "$VERSION" ]]
[[ "$(plutil -extract CFBundleVersion raw "$INFO_PLIST")" == "$BUILD" ]]
[[ "$(plutil -extract CFBundleIconName raw "$INFO_PLIST")" == "AppIcon" ]]
[[ -f "$APP_BUNDLE/Contents/Resources/Assets.car" ]]
[[ -f "$APP_BUNDLE/Contents/Resources/PrivacyInfo.xcprivacy" ]]

ARCHITECTURES="$(lipo -archs "$BINARY")"
[[ "$ARCHITECTURES" == *arm64* ]]
[[ "$ARCHITECTURES" == *x86_64* ]]

if [[ "$SIGNING_DISABLED" == false ]]; then
    codesign --verify --deep --strict --verbose=2 "$APP_BUNDLE"
    ENTITLEMENTS="$(codesign -d --entitlements - "$APP_BUNDLE" 2>/dev/null)"
    print -r -- "$ENTITLEMENTS" \
        | grep -A2 -F '[Key] com.apple.security.app-sandbox' \
        | grep -q -F '[Bool] true'
fi

print "$ARCHIVE_PATH"
