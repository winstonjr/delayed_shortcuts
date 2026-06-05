#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BUILD_ROOT="${DELAYED_SHORTCUTS_BUILD_ROOT:-$ROOT_DIR/tmp}"
APP_PATH="$BUILD_ROOT/DelayedShortcuts.app"

VERSION="$(grep -m1 'MARKETING_VERSION' "$ROOT_DIR/DelayedShortcuts.xcodeproj/project.pbxproj" | sed 's/.*= *//;s/;//;s/ *//')"
PKG_PATH="$BUILD_ROOT/DelayedShortcuts-$VERSION.pkg"

PKGBUILD_ARGS=(
  --identifier "com.local.DelayedShortcuts"
  --version "$VERSION"
  --install-location "/Applications"
  --component "$APP_PATH"
)

if [[ -n "${DELAYED_SHORTCUTS_INSTALLER_SIGN_IDENTITY:-}" ]]; then
  PKGBUILD_ARGS+=(--sign "$DELAYED_SHORTCUTS_INSTALLER_SIGN_IDENTITY")
fi

"$ROOT_DIR/scripts/build.sh"

/usr/bin/xattr -cr "$APP_PATH" || true
/usr/bin/codesign --verify --strict --deep "$APP_PATH" >/dev/null

env COPYFILE_DISABLE=1 pkgbuild "${PKGBUILD_ARGS[@]}" "$PKG_PATH"

echo "$PKG_PATH"
