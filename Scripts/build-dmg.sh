#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APP_NAME="AudioMaster"
SCHEME="AudioMaster"
# .noindex suffix excludes build products from Spotlight (no duplicate app instances).
BUILD_DIR="${BUILD_DIR:-$ROOT/build.noindex}"
VERSION="${1:?Usage: build-dmg.sh <version>}"
BUILD_NUMBER="${BUILD_NUMBER:-1}"

echo "Building ${APP_NAME} ${VERSION} (build ${BUILD_NUMBER})..."

xcodebuild \
  -project "$ROOT/AudioMaster.xcodeproj" \
  -scheme "$SCHEME" \
  -configuration Release \
  -derivedDataPath "$BUILD_DIR/DerivedData" \
  ARCHS="arm64 x86_64" \
  ONLY_ACTIVE_ARCH=NO \
  MARKETING_VERSION="$VERSION" \
  CURRENT_PROJECT_VERSION="$BUILD_NUMBER" \
  CODE_SIGN_IDENTITY="${CODE_SIGN_IDENTITY:--}" \
  CODE_SIGNING_REQUIRED="${CODE_SIGNING_REQUIRED:-NO}" \
  CODE_SIGNING_ALLOWED="${CODE_SIGNING_ALLOWED:-NO}" \
  build

APP_PATH="$BUILD_DIR/DerivedData/Build/Products/Release/${APP_NAME}.app"
if [[ ! -d "$APP_PATH" ]]; then
  echo "Expected app bundle not found at $APP_PATH" >&2
  exit 1
fi

DMG_NAME="${APP_NAME}-${VERSION}.dmg"

DMG_STAGING="$BUILD_DIR/dmg"
DMG_PATH="$BUILD_DIR/$DMG_NAME"

rm -rf "$DMG_STAGING"
mkdir -p "$DMG_STAGING"
cp -R "$APP_PATH" "$DMG_STAGING/"
ln -sf /Applications "$DMG_STAGING/Applications"

rm -f "$DMG_PATH"
hdiutil create \
  -volname "$APP_NAME" \
  -srcfolder "$DMG_STAGING" \
  -ov \
  -format UDZO \
  "$DMG_PATH"

echo "DMG created at $DMG_PATH"
