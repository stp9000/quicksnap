#!/usr/bin/env bash
set -euo pipefail

APP_NAME="QuickSnap"
ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
VERSION_FILE="$ROOT_DIR/VERSION"
DEFAULT_APP_VERSION="$(tr -d '\n' < "$VERSION_FILE")"
APP_VERSION="${APP_VERSION:-$DEFAULT_APP_VERSION}"
BUILD_NUMBER="${BUILD_NUMBER:-$(date +%Y%m%d%H%M)}"
APP_PATH="$ROOT_DIR/build/${APP_NAME}.app"
DIST_DIR="$ROOT_DIR/dist"
ARCHIVE_NAME="${APP_NAME}-v${APP_VERSION}-macOS-unsigned.zip"

cd "$ROOT_DIR"

APP_VERSION="$APP_VERSION" BUILD_NUMBER="$BUILD_NUMBER" ./scripts/build_app.sh

mkdir -p "$DIST_DIR"
rm -f "$DIST_DIR/$ARCHIVE_NAME"
/usr/bin/ditto -c -k --sequesterRsrc --keepParent "$APP_PATH" "$DIST_DIR/$ARCHIVE_NAME"

echo "Created release archive: $DIST_DIR/$ARCHIVE_NAME"
