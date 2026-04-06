#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
VERSION_FILE="$ROOT_DIR/VERSION"
DEFAULT_APP_VERSION="$(tr -d '\n' < "$VERSION_FILE")"
APP_VERSION="${APP_VERSION:-$DEFAULT_APP_VERSION}"
BUILD_NUMBER="${BUILD_NUMBER:-$(date +%Y%m%d%H%M)}"

: "${DEVELOPER_ID_APPLICATION:?Set DEVELOPER_ID_APPLICATION to your Developer ID Application certificate name.}"
: "${NOTARY_PROFILE:?Set NOTARY_PROFILE to a notarytool keychain profile name.}"

cd "$ROOT_DIR"

echo "Building release app for version $APP_VERSION (build $BUILD_NUMBER)..."
APP_VERSION="$APP_VERSION" BUILD_NUMBER="$BUILD_NUMBER" ./scripts/build_app.sh

echo "Signing, notarizing, stapling, and packaging notarized release..."
APP_VERSION="$APP_VERSION" ./scripts/notarize_app.sh

echo "Release flow complete."
