#!/bin/bash
# Builds TokenBar.app directly with swiftc — no Xcode / XcodeGen required.
# Works on macOS 13 with Command Line Tools (Swift 5.9).
set -e

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SRC="$ROOT/TokenBar/TokenBar"
BUILD="$ROOT/build"
APP="$BUILD/TokenBar.app"

echo "[1/4] Cleaning..."
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS"
mkdir -p "$APP/Contents/Resources"

echo "[2/4] Compiling Swift sources (universal: x86_64 + arm64)..."
# Build for both architectures then lipo-merge into a universal binary
for ARCH in x86_64 arm64; do
  swiftc \
    -O \
    -target "${ARCH}-apple-macos13.0" \
    -framework AppKit \
    -framework SwiftUI \
    -framework Combine \
    -lsqlite3 \
    -o "$APP/Contents/MacOS/TokenBar_${ARCH}" \
    "$SRC"/*.swift
done
lipo -create -output "$APP/Contents/MacOS/TokenBar" \
  "$APP/Contents/MacOS/TokenBar_x86_64" \
  "$APP/Contents/MacOS/TokenBar_arm64"
rm "$APP/Contents/MacOS/TokenBar_x86_64" "$APP/Contents/MacOS/TokenBar_arm64"

echo "[3/4] Writing Info.plist..."
cp "$SRC/Info.plist" "$APP/Contents/Info.plist"

# PkgInfo
echo -n "APPL????" > "$APP/Contents/PkgInfo"

echo "[4/4] Ad-hoc signing..."
codesign --force --deep --sign - "$APP" 2>/dev/null || echo "  (codesign skipped)"

echo ""
echo "Built: $APP"
echo "Run:   open \"$APP\""
echo "  or:  \"$APP/Contents/MacOS/TokenBar\"   (for console logs)"
