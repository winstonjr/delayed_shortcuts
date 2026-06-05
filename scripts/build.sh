#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BUILD_ROOT="${DELAYED_SHORTCUTS_BUILD_ROOT:-$ROOT_DIR/tmp}"
APP_PATH="$BUILD_ROOT/DelayedShortcuts.app"
APP_SIGN_IDENTITY="${DELAYED_SHORTCUTS_CODE_SIGN_IDENTITY:--}"

# Read metadata from the Xcode project so there's a single source of truth.
PBXPROJ="$ROOT_DIR/DelayedShortcuts.xcodeproj/project.pbxproj"
VERSION="$(grep -m1 'MARKETING_VERSION'       "$PBXPROJ" | sed 's/.*= *//;s/;//;s/ *//')"
BUILD_NR="$(grep -m1 'CURRENT_PROJECT_VERSION' "$PBXPROJ" | sed 's/.*= *//;s/;//;s/ *//')"
MIN_OS="$(grep -m1  'MACOSX_DEPLOYMENT_TARGET' "$PBXPROJ" | sed 's/.*= *//;s/;//;s/ *//')"
BUNDLE_ID="com.local.DelayedShortcuts"

SDK="$(xcrun --show-sdk-path 2>/dev/null || echo /Library/Developer/CommandLineTools/SDKs/MacOSX.sdk)"
ARCH="$(uname -m)"   # arm64 on Apple Silicon, x86_64 on Intel

CODESIGN_TIMESTAMP=(--timestamp=none)
if [[ "$APP_SIGN_IDENTITY" != "-" ]]; then
  CODESIGN_TIMESTAMP=(--timestamp)
fi

echo "Building DelayedShortcuts $VERSION ($BUILD_NR) for $ARCH..."

# ── App bundle skeleton ─────────────────────────────────────────────────────
rm -rf "$APP_PATH"
mkdir -p "$APP_PATH/Contents/MacOS"
mkdir -p "$APP_PATH/Contents/Resources"

# Substitute build variables into Info.plist
/usr/bin/sed \
  -e "s|\$(DEVELOPMENT_LANGUAGE)|en|g" \
  -e "s|\$(EXECUTABLE_NAME)|DelayedShortcuts|g" \
  -e "s|\$(PRODUCT_BUNDLE_IDENTIFIER)|$BUNDLE_ID|g" \
  -e "s|\$(PRODUCT_NAME)|DelayedShortcuts|g" \
  -e "s|\$(MARKETING_VERSION)|$VERSION|g" \
  -e "s|\$(CURRENT_PROJECT_VERSION)|$BUILD_NR|g" \
  -e "s|\$(MACOSX_DEPLOYMENT_TARGET)|$MIN_OS|g" \
  "$ROOT_DIR/DelayedShortcuts/Info.plist" \
  > "$APP_PATH/Contents/Info.plist"

# ── Compile ─────────────────────────────────────────────────────────────────
swiftc \
  "$ROOT_DIR/DelayedShortcuts/main.swift" \
  "$ROOT_DIR/DelayedShortcuts/AppDelegate.swift" \
  "$ROOT_DIR/DelayedShortcuts/DSLogger.swift" \
  "$ROOT_DIR/DelayedShortcuts/ShortcutModels.swift" \
  "$ROOT_DIR/DelayedShortcuts/ShortcutStore.swift" \
  "$ROOT_DIR/DelayedShortcuts/Permissions.swift" \
  "$ROOT_DIR/DelayedShortcuts/EventSender.swift" \
  "$ROOT_DIR/DelayedShortcuts/ShortcutMonitor.swift" \
  "$ROOT_DIR/DelayedShortcuts/ShortcutListWindowController.swift" \
  "$ROOT_DIR/DelayedShortcuts/StatusMenuController.swift" \
  "$ROOT_DIR/DelayedShortcuts/ShortcutEditorSheet.swift" \
  -sdk "$SDK" \
  -target "$ARCH-apple-macosx$MIN_OS" \
  -O \
  -framework Cocoa \
  -framework Carbon \
  -framework IOKit \
  -framework ApplicationServices \
  -framework CoreGraphics \
  -module-name DelayedShortcuts \
  -o "$APP_PATH/Contents/MacOS/DelayedShortcuts"

# ── Sign ─────────────────────────────────────────────────────────────────────
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
