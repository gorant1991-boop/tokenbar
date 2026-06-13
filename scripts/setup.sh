#!/bin/bash
set -e

echo "=== TokenBar Setup ==="

# 1. Install mitmproxy
if ! command -v mitmdump &>/dev/null; then
  echo "[1/3] Installing mitmproxy..."
  pip3 install mitmproxy
else
  echo "[1/3] mitmproxy OK"
fi

# 2. Install xcodegen
if ! command -v xcodegen &>/dev/null; then
  echo "[2/3] Installing xcodegen..."
  brew install xcodegen
else
  echo "[2/3] xcodegen OK"
fi

# 3. Generate Xcode project
echo "[3/3] Generating Xcode project..."
cd "$(dirname "$0")/../TokenBar"
xcodegen generate

echo ""
echo "Done! Next steps:"
echo "  1. Open TokenBar/TokenBar.xcodeproj in Xcode"
echo "  2. Build & Run (⌘R)"
echo "  3. In a separate terminal: ./scripts/start_proxy.sh"
echo "  4. Configure your AI tools to use HTTP proxy 127.0.0.1:8080"
echo "     (or set HTTPS_PROXY=http://127.0.0.1:8080 in shell)"
echo ""
echo "  mitmproxy cert: ~/.mitmproxy/mitmproxy-ca-cert.pem"
echo "  Add to Keychain: open ~/.mitmproxy/mitmproxy-ca-cert.pem"
