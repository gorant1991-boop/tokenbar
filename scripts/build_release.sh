#!/bin/bash
# Builds TokenBar.app and packages it as TokenBar.zip ready to share.
# User flow: unzip → double-click TokenBar.app → done.
set -e

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SRC="$ROOT/TokenBar/TokenBar"
BUILD="$ROOT/build"
APP="$BUILD/TokenBar.app"
RESOURCES="$APP/Contents/Resources"
DIST="$BUILD/dist"

echo "[1/5] Building app..."
bash "$ROOT/scripts/build_app.sh"

echo "[2/5] Bundling log_parser.py..."
mkdir -p "$RESOURCES"
cp "$ROOT/proxy/log_parser.py" "$RESOURCES/log_parser.py"

echo "[3/5] Re-signing with bundled resource..."
codesign --force --deep --sign - "$APP" 2>/dev/null || true

echo "[4/5] Packaging..."
rm -rf "$DIST" && mkdir -p "$DIST"
cp -r "$APP" "$DIST/TokenBar.app"

# Quarantine-safe: zip preserves symlinks, no extra metadata
cd "$DIST"
zip -qr "$BUILD/TokenBar.zip" "TokenBar.app"

echo "[5/5] Done."
echo ""
echo "Release: $BUILD/TokenBar.zip"
echo "Size:    $(du -sh "$BUILD/TokenBar.zip" | cut -f1)"
echo ""
echo "User install: unzip TokenBar.zip → double-click TokenBar.app"
