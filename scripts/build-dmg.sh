#!/usr/bin/env zsh
set -euo pipefail

ROOT_DIR=$(cd "$(dirname "$0")/.." && pwd)
APP_NAME=${APP_NAME:-ssrMac}
CONFIGURATION=${CONFIGURATION:-Release}
ARCH=${ARCH:-arm64}
DERIVED_DATA_PATH=${DERIVED_DATA_PATH:-"$ROOT_DIR/build/DerivedData"}
APP_PATH=${APP_PATH:-"$DERIVED_DATA_PATH/Build/Products/$CONFIGURATION/$APP_NAME.app"}
DIST_DIR=${DIST_DIR:-"$ROOT_DIR/build/dist"}
STAGING_DIR="$ROOT_DIR/build/dmg-staging"
VOLUME_NAME=${VOLUME_NAME:-"ssrMac"}

mkdir -p "$DIST_DIR"

if [[ "${SKIP_BUILD:-NO}" != "YES" ]]; then
    "$ROOT_DIR/build.sh"
fi

if [[ ! -d "$APP_PATH" ]]; then
    echo "[dmg] App bundle not found: $APP_PATH" >&2
    exit 1
fi

VERSION=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$APP_PATH/Contents/Info.plist" 2>/dev/null || true)
BUILD=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' "$APP_PATH/Contents/Info.plist" 2>/dev/null || true)
if [[ -z "$VERSION" || "$VERSION" == *'$('* ]]; then
    VERSION=$(date -u '+%Y%m%d%H%M%S')
fi
if [[ -n "$BUILD" && "$BUILD" != *'$('* ]]; then
    VERSION="$VERSION-$BUILD"
fi

DMG_PATH="$DIST_DIR/$APP_NAME-$VERSION-$ARCH.dmg"
RW_DMG_PATH="$DIST_DIR/$APP_NAME-$VERSION-$ARCH.rw.dmg"

echo "[dmg] Preparing staging directory: $STAGING_DIR"
rm -rf "$STAGING_DIR" "$DMG_PATH" "$RW_DMG_PATH"
mkdir -p "$STAGING_DIR"
ditto "$APP_PATH" "$STAGING_DIR/$APP_NAME.app"
ln -s /Applications "$STAGING_DIR/Applications"

echo "[dmg] Verifying app signature"
codesign --verify --deep --strict "$STAGING_DIR/$APP_NAME.app"

SIZE_KB=$(du -sk "$STAGING_DIR" | awk '{print $1}')
SIZE_MB=$(( (SIZE_KB / 1024) + 64 ))
if (( SIZE_MB < 128 )); then
    SIZE_MB=128
fi

echo "[dmg] Creating writable image: $RW_DMG_PATH (${SIZE_MB}m)"
hdiutil create \
    -volname "$VOLUME_NAME" \
    -srcfolder "$STAGING_DIR" \
    -fs HFS+ \
    -fsargs "-c c=64,a=16,e=16" \
    -format UDRW \
    -size "${SIZE_MB}m" \
    "$RW_DMG_PATH"

echo "[dmg] Compressing image: $DMG_PATH"
hdiutil convert "$RW_DMG_PATH" -format UDZO -imagekey zlib-level=9 -o "$DMG_PATH"
rm -f "$RW_DMG_PATH"

echo "[dmg] Verifying image"
hdiutil verify "$DMG_PATH"

echo "[dmg] Built $DMG_PATH"