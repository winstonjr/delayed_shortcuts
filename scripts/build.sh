#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BUILD_ROOT="${DELAYED_SHORTCUTS_BUILD_ROOT:-$ROOT_DIR/tmp}"
DERIVED_DATA="$BUILD_ROOT/DerivedData"
APP_PATH="$DERIVED_DATA/Build/Products/Release/DelayedShortcuts.app"
APP_SIGN_IDENTITY="${DELAYED_SHORTCUTS_CODE_SIGN_IDENTITY:--}"
CODESIGN_TIMESTAMP=(--timestamp=none)

if [[ "$APP_SIGN_IDENTITY" != "-" ]]; then
  CODESIGN_TIMESTAMP=(--timestamp)
fi

mkdir -p "$BUILD_ROOT"

xcodebuild \
  -project "$ROOT_DIR/DelayedShortcuts.xcodeproj" \
  -scheme DelayedShortcuts \
  -configuration Release \
  -derivedDataPath "$DERIVED_DATA" \
  clean build

/usr/bin/xattr -cr "$APP_PATH" || true
/usr/bin/codesign \
  --force \
  --deep \
  --sign "$APP_SIGN_IDENTITY" \
  --options runtime \
  "${CODESIGN_TIMESTAMP[@]}" \
  "$APP_PATH"
/usr/bin/codesign --verify --strict --deep "$APP_PATH" >/dev/null

echo "$APP_PATH"
