#!/bin/zsh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
DIST_DIR="$PROJECT_DIR/dist.release.noindex"
APP_BUNDLE="$DIST_DIR/Work Island.app"
SUBMISSION_ZIP="$DIST_DIR/Work Island-notarization.zip"
VERSION="$(plutil -extract CFBundleShortVersionString raw "$PROJECT_DIR/Info.plist")"
FINAL_ZIP="$DIST_DIR/Work Island $VERSION.zip"
KEYCHAIN_PROFILE="${1:-}"

if [[ -z "$KEYCHAIN_PROFILE" ]]; then
    print -u2 "Usage: $0 <notarytool-keychain-profile>"
    exit 1
fi

if [[ ! -d "$APP_BUNDLE" || ! -f "$SUBMISSION_ZIP" ]]; then
    print -u2 "Run Scripts/build-distribution.sh before notarizing."
    exit 1
fi

xcrun notarytool submit \
    "$SUBMISSION_ZIP" \
    --keychain-profile "$KEYCHAIN_PROFILE" \
    --wait

xcrun stapler staple "$APP_BUNDLE"
xcrun stapler validate "$APP_BUNDLE"

rm -f "$FINAL_ZIP"
ditto -c -k --sequesterRsrc --keepParent "$APP_BUNDLE" "$FINAL_ZIP"

codesign --verify --deep --strict --verbose=2 "$APP_BUNDLE"
spctl --assess --type execute --verbose=2 "$APP_BUNDLE"
shasum -a 256 "$FINAL_ZIP"

print "$FINAL_ZIP"
