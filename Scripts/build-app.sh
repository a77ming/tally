#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

# Build each arch in its own pass and merge with lipo. SwiftPM's single-pass
# `--arch arm64 --arch x86_64` hits a caching race ("auxiliary file not
# registered"), so we build them separately — this reliably yields a
# universal binary that runs on both Apple Silicon and Intel.
BINARY=".build/Tally-universal"
ARM=".build/arm64-apple-macosx/release/Tally"
X86=".build/x86_64-apple-macosx/release/Tally"

swift build -c release --arch arm64
if swift build -c release --arch x86_64 && [[ -f "$X86" ]]; then
    lipo -create "$ARM" "$X86" -output "$BINARY"
    echo "✓ universal binary (arm64 + x86_64)"
else
    echo "⚠ x86_64 build unavailable — shipping Apple Silicon only"
    cp "$ARM" "$BINARY"
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
