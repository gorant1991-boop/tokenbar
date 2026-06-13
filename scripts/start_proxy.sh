#!/bin/bash
# Starts mitmproxy with TokenBar addon in transparent mode (localhost:8080)
# Usage: ./scripts/start_proxy.sh

SCRIPT_DIR="$(cd "$(dirname "$0")/.." && pwd)"

# Check mitmproxy installed
if ! command -v mitmdump &>/dev/null; then
  echo "mitmproxy not found. Install: pip install mitmproxy"
  exit 1
fi

mitmdump \
  --listen-host 127.0.0.1 \
  --listen-port 8080 \
  --scripts "$SCRIPT_DIR/proxy/addon.py" \
  --set block_global=false \
  "$@"
