#!/usr/bin/env bash
set -euo pipefail

APP_NAME="QuickSnap"
ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
VERSION_FILE="$ROOT_DIR/VERSION"
DEFAULT_APP_VERSION="$(tr -d '\n' < "$VERSION_FILE")"
APP_VERSION="${APP_VERSION:-$DEFAULT_APP_VERSION}"
APP_PATH="$ROOT_DIR/build/${APP_NAME}.app"
DIST_DIR="$ROOT_DIR/dist"
ZIP_PATH="$DIST_DIR/${APP_NAME}-v${APP_VERSION}-macOS-signed.zip"

: "${DEVELOPER_ID_APPLICATION:?Set DEVELOPER_ID_APPLICATION to your Developer ID Application certificate name.}"
: "${NOTARY_PROFILE:?Set NOTARY_PROFILE to a notarytool keychain profile name.}"

cd "$ROOT_DIR"

codesign --force --options runtime --timestamp --deep --sign "$DEVELOPER_ID_APPLICATION" "$APP_PATH"
codesign --verify --deep --strict --verbose=2 "$APP_PATH"
spctl --assess --type execute --verbose=4 "$APP_PATH"

mkdir -p "$DIST_DIR"
rm -f "$ZIP_PATH"
/usr/bin/ditto -c -k --sequesterRsrc --keepParent "$APP_PATH" "$ZIP_PATH"

xcrun notarytool submit "$ZIP_PATH" --keychain-profile "$NOTARY_PROFILE" --wait
xcrun stapler staple "$APP_PATH"
xcrun stapler validate "$APP_PATH"

echo "Signed, notarized, and stapled app: $APP_PATH"
