#!/usr/bin/env bash
set -euo pipefail

APP_NAME="QuickSnap"
BUNDLE_ID="com.quicksnap.app"
ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
VERSION_FILE="$ROOT_DIR/VERSION"
DEFAULT_APP_VERSION="$(tr -d '\n' < "$VERSION_FILE")"
APP_VERSION="${APP_VERSION:-$DEFAULT_APP_VERSION}"
BUILD_NUMBER="${BUILD_NUMBER:-$(date +%Y%m%d%H%M)}"
HELPER_DIR="$ROOT_DIR/Vendor/ObsidianClipperHelper"
cd "$ROOT_DIR"

swift scripts/generate_icon.swift
iconutil -c icns Resources/AppIcon.iconset -o Resources/AppIcon.icns

if [ ! -d "$HELPER_DIR" ]; then
  echo "Error: missing vendored helper directory at $HELPER_DIR" >&2
  exit 1
fi

npm ci --omit=dev --prefix "$HELPER_DIR"

swift build -c release

APP_DIR="$ROOT_DIR/build/${APP_NAME}.app"
CONTENTS_DIR="$APP_DIR/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"
HELPER_RUNTIME_DIR="$RESOURCES_DIR/HelperRuntime"

rm -rf "$APP_DIR"
mkdir -p "$MACOS_DIR" "$RESOURCES_DIR" "$HELPER_RUNTIME_DIR"

cp "$ROOT_DIR/.build/release/$APP_NAME" "$MACOS_DIR/$APP_NAME"
cp "$ROOT_DIR/Resources/AppIcon.icns" "$RESOURCES_DIR/AppIcon.icns"

if [ ! -f "$HELPER_DIR/clipper-helper.mjs" ]; then
  echo "Error: missing vendored helper script at $HELPER_DIR/clipper-helper.mjs" >&2
  exit 1
fi

rsync -a --delete "$HELPER_DIR/" "$RESOURCES_DIR/ObsidianClipperHelper/"

NODE_BINARY="${NODE_BINARY:-}"
if [ -n "$NODE_BINARY" ]; then
  if [ ! -x "$NODE_BINARY" ]; then
    echo "Error: NODE_BINARY is set but not executable: $NODE_BINARY" >&2
    exit 1
  fi
else
  NODE_BINARY="$(command -v node || true)"
fi

if [ -z "$NODE_BINARY" ] || [ ! -x "$NODE_BINARY" ]; then
  echo "Error: Node.js is required to package QuickSnap. Install Node.js or set NODE_BINARY to an executable runtime." >&2
  exit 1
fi

cp "$NODE_BINARY" "$HELPER_RUNTIME_DIR/node"
chmod +x "$HELPER_RUNTIME_DIR/node"

cat > "$CONTENTS_DIR/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key>
    <string>${APP_NAME}</string>
    <key>CFBundleDisplayName</key>
    <string>${APP_NAME}</string>
    <key>CFBundleIdentifier</key>
    <string>${BUNDLE_ID}</string>
    <key>CFBundleVersion</key>
    <string>${BUILD_NUMBER}</string>
    <key>CFBundleShortVersionString</key>
    <string>${APP_VERSION}</string>
    <key>CFBundleExecutable</key>
    <string>${APP_NAME}</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>NSAppleEventsUsageDescription</key>
    <string>QuickSnap requests access to supported browsers only to capture the current page URL into screenshot metadata.</string>
    <key>LSMinimumSystemVersion</key>
    <string>13.0</string>
</dict>
</plist>
PLIST

chmod +x "$MACOS_DIR/$APP_NAME"

if command -v codesign >/dev/null 2>&1; then
  codesign --force --deep --sign - "$APP_DIR" >/dev/null 2>&1 || true
fi

echo "Built app bundle: $APP_DIR"
echo "Open with: open \"$APP_DIR\""
