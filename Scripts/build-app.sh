#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

# Try a universal (arm64 + x86_64) release build; fall back to native-only
# if the x86_64 stdlib/SDK isn't available with Command Line Tools.
BINARY=""
if swift build -c release --arch arm64 --arch x86_64; then
    BINARY=".build/apple/Products/Release/Tally"
else
    echo "⚠ universal build failed — falling back to native-only release build"
    swift build -c release
    BINARY=".build/release/Tally"
fi

if [[ ! -f "$BINARY" ]]; then
    echo "error: built binary not found at $BINARY" >&2
    exit 1
fi

APP="dist/Tally.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"

cp "$BINARY" "$APP/Contents/MacOS/Tally"
cp Resources/Info.plist "$APP/Contents/Info.plist"
cp Resources/AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"
printf 'APPL????' > "$APP/Contents/PkgInfo"

codesign --force --deep -s - "$APP"

echo "✓ dist/Tally.app"
