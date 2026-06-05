#!/usr/bin/env bash
set -euo pipefail

BUNDLE_ID="com.local.DelayedShortcuts"

echo "Resetting permissions for $BUNDLE_ID..."
/usr/bin/tccutil reset Accessibility "$BUNDLE_ID"
/usr/bin/tccutil reset ListenEvent   "$BUNDLE_ID"
echo "Done."
