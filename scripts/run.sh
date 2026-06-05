#!/usr/bin/env bash
# Reset stale TCC permissions and launch the app.
# Run this every time you rebuild/re-sign so macOS accepts the new signature.
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BUILD_ROOT="${DELAYED_SHORTCUTS_BUILD_ROOT:-$ROOT_DIR/tmp}"
BUNDLE_ID="com.local.DelayedShortcuts"

# Prefer the xcodebuild output; fall back to the swiftc-compiled bundle.
if [[ -d "$BUILD_ROOT/DerivedData/Build/Products/Release/DelayedShortcuts.app" ]]; then
  APP_PATH="$BUILD_ROOT/DerivedData/Build/Products/Release/DelayedShortcuts.app"
else
  APP_PATH="$BUILD_ROOT/DelayedShortcuts.app"
fi

if [[ ! -d "$APP_PATH" ]]; then
  echo "error: app not found at $APP_PATH — run scripts/build.sh first" >&2
  exit 1
fi

# Stop any running instance so TCC entries can be removed cleanly.
if pgrep -x DelayedShortcuts >/dev/null 2>&1; then
  echo "Stopping existing instance..."
  pkill -x DelayedShortcuts || true
  sleep 0.5
fi

# Reset TCC permissions — stale after every re-sign.
echo "Resetting permissions for $BUNDLE_ID..."
/usr/bin/tccutil reset Accessibility   "$BUNDLE_ID" 2>/dev/null || true
/usr/bin/tccutil reset ListenEvent     "$BUNDLE_ID" 2>/dev/null || true

echo "Launching $APP_PATH..."
open "$APP_PATH"
