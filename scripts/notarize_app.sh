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
NOTARIZED_ZIP_PATH="$DIST_DIR/${APP_NAME}-v${APP_VERSION}-macOS-notarized.zip"
HELPER_RUNTIME_DIR="$APP_PATH/Contents/Resources/HelperRuntime"

: "${DEVELOPER_ID_APPLICATION:?Set DEVELOPER_ID_APPLICATION to your Developer ID Application certificate name.}"

cd "$ROOT_DIR"

resolve_notary_profile() {
  if [[ -n "${NOTARY_PROFILE:-}" ]]; then
    printf '%s\n' "$NOTARY_PROFILE"
    return 0
  fi

  : "${APPLE_ID:?Set NOTARY_PROFILE or provide APPLE_ID for notarytool credentials.}"
  : "${APPLE_TEAM_ID:?Set NOTARY_PROFILE or provide APPLE_TEAM_ID for notarytool credentials.}"
  : "${APPLE_APP_PASSWORD:?Set NOTARY_PROFILE or provide APPLE_APP_PASSWORD for notarytool credentials.}"

  local profile_name="quicksnap-notary-temp"
  xcrun notarytool store-credentials "$profile_name" \
    --apple-id "$APPLE_ID" \
    --team-id "$APPLE_TEAM_ID" \
    --password "$APPLE_APP_PASSWORD" >/dev/null

  printf '%s\n' "$profile_name"
}

NOTARY_PROFILE_RESOLVED="$(resolve_notary_profile)"

sign_binary() {
  local path="$1"
  codesign --force --options runtime --timestamp --sign "$DEVELOPER_ID_APPLICATION" "$path"
}

if [[ -d "$HELPER_RUNTIME_DIR" ]]; then
  while IFS= read -r -d '' binary_path; do
    sign_binary "$binary_path"
  done < <(find "$HELPER_RUNTIME_DIR" -type f \( -name "*.dylib" -o -name "node" \) -print0 | sort -z)
fi

codesign --force --options runtime --timestamp --sign "$DEVELOPER_ID_APPLICATION" "$APP_PATH"
codesign --verify --deep --strict --verbose=2 "$APP_PATH"

mkdir -p "$DIST_DIR"
rm -f "$ZIP_PATH"
/usr/bin/ditto -c -k --sequesterRsrc --keepParent "$APP_PATH" "$ZIP_PATH"

xcrun notarytool submit "$ZIP_PATH" --keychain-profile "$NOTARY_PROFILE_RESOLVED" --wait
xcrun stapler staple "$APP_PATH"
xcrun stapler validate "$APP_PATH"
spctl --assess --type execute --verbose=4 "$APP_PATH"

rm -f "$NOTARIZED_ZIP_PATH"
/usr/bin/ditto -c -k --sequesterRsrc --keepParent "$APP_PATH" "$NOTARIZED_ZIP_PATH"

echo "Signed, notarized, and stapled app: $APP_PATH"
echo "Notarized archive: $NOTARIZED_ZIP_PATH"
