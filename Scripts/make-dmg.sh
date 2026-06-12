#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

APP="dist/Tally.app"
if [[ ! -d "$APP" ]]; then
    echo "error: $APP not found — run Scripts/build-app.sh first" >&2
    exit 1
fi

VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$APP/Contents/Info.plist" 2>/dev/null || echo 1.0.0)"

STAGING="build/dmg"
rm -rf "$STAGING"
mkdir -p "$STAGING"
cp -R "$APP" "$STAGING/Tally.app"
ln -s /Applications "$STAGING/Applications"

DMG="dist/Tally-${VERSION}.dmg"
hdiutil create -volname "Tally" -srcfolder "$STAGING" -ov -format UDZO "$DMG"

echo "✓ $DMG ($(du -h "$DMG" | cut -f1 | tr -d '[:space:]'))"
