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
NODE_VERSION="${NODE_VERSION:-v24.16.0}"
NODE_DIST_BASE_URL="${NODE_DIST_BASE_URL:-https://nodejs.org/dist}"
NODE_RUNTIME_CACHE_DIR="${NODE_RUNTIME_CACHE_DIR:-$ROOT_DIR/build/node-runtime}"

remove_code_signature() {
  local binary="$1"

  if command -v codesign >/dev/null 2>&1; then
    codesign --remove-signature "$binary" >/dev/null 2>&1 || true
  fi
}

ad_hoc_sign_binary() {
  local binary="$1"

  if command -v codesign >/dev/null 2>&1; then
    codesign --force --sign - "$binary"
  fi
}

node_dist_arch() {
  case "$(uname -m)" in
    arm64)
      printf 'arm64\n'
      ;;
    x86_64)
      printf 'x64\n'
      ;;
    *)
      echo "Error: unsupported macOS architecture for bundled Node runtime: $(uname -m)" >&2
      exit 1
      ;;
  esac
}

verify_node_archive() {
  local archive_path="$1"
  local archive_name="$2"
  local sums_path="$3"
  local expected_hash
  local actual_hash

  expected_hash="$(awk -v file="$archive_name" '$2 == file { print $1 }' "$sums_path")"
  if [ -z "$expected_hash" ]; then
    echo "Error: could not find checksum for $archive_name in $sums_path" >&2
    exit 1
  fi

  actual_hash="$(shasum -a 256 "$archive_path" | awk '{ print $1 }')"
  if [ "$actual_hash" != "$expected_hash" ]; then
    echo "Error: checksum mismatch for $archive_name" >&2
    exit 1
  fi
}

prepare_official_node_runtime() {
  local runtime_directory="$1"
  local arch
  arch="$(node_dist_arch)"
  local package_name="node-${NODE_VERSION}-darwin-${arch}"
  local archive_name="${package_name}.tar.gz"
  local archive_path="$NODE_RUNTIME_CACHE_DIR/$archive_name"
  local sums_path="$NODE_RUNTIME_CACHE_DIR/SHASUMS256.txt"
  local extracted_node="$NODE_RUNTIME_CACHE_DIR/$package_name/bin/node"

  mkdir -p "$NODE_RUNTIME_CACHE_DIR"

  if [ ! -f "$archive_path" ]; then
    curl -fsSL "$NODE_DIST_BASE_URL/$NODE_VERSION/$archive_name" -o "$archive_path"
  fi

  curl -fsSL "$NODE_DIST_BASE_URL/$NODE_VERSION/SHASUMS256.txt" -o "$sums_path"
  verify_node_archive "$archive_path" "$archive_name" "$sums_path"

  if [ ! -x "$extracted_node" ]; then
    rm -rf "$NODE_RUNTIME_CACHE_DIR/$package_name"
    tar -xzf "$archive_path" -C "$NODE_RUNTIME_CACHE_DIR"
  fi

  cp "$extracted_node" "$runtime_directory/node"
  chmod +w "$runtime_directory/node"
  chmod +x "$runtime_directory/node"
  remove_code_signature "$runtime_directory/node"
}

cd "$ROOT_DIR"

if [ -d Resources/AppIcon.iconset ]; then
  iconutil -c icns Resources/AppIcon.iconset -o Resources/AppIcon.icns
fi

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
prepare_official_node_runtime "$HELPER_RUNTIME_DIR"

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
  ad_hoc_sign_binary "$HELPER_RUNTIME_DIR/node"
  ad_hoc_sign_binary "$MACOS_DIR/$APP_NAME"
  codesign --force --deep --sign - "$APP_DIR"
fi

echo "Built app bundle: $APP_DIR"
echo "Open with: open \"$APP_DIR\""
