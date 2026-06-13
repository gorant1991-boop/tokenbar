#!/bin/bash
# Starts mitmproxy with TokenBar addon on localhost:8080
# Run once: sudo security add-trusted-cert -d -r trustRoot \
#           -k /Library/Keychains/System.keychain ~/.mitmproxy/mitmproxy-ca-cert.pem

SCRIPT_DIR="$(cd "$(dirname "$0")/.." && pwd)"

if ! command -v mitmdump &>/dev/null; then
  echo "mitmproxy not found. Install: pip install mitmproxy"
  exit 1
fi

CERT=~/.mitmproxy/mitmproxy-ca-cert.pem
if [ ! -f "$CERT" ]; then
  echo "Cert not found — generating..."
  mitmdump --listen-port 18080 &
  sleep 3; kill %1 2>/dev/null; wait 2>/dev/null
fi

# Check if cert is trusted
if ! security verify-cert -c "$CERT" &>/dev/null; then
  echo ""
  echo "⚠  Certificate not trusted. Run once:"
  echo "   sudo security add-trusted-cert -d -r trustRoot \\"
  echo "        -k /Library/Keychains/System.keychain $CERT"
  echo ""
fi

echo "TokenBar proxy → http://127.0.0.1:8080"
echo "Launch Claude Code via proxy:"
echo "  HTTPS_PROXY=http://127.0.0.1:8080 claude"
echo ""

mitmdump \
  --listen-host 127.0.0.1 \
  --listen-port 8080 \
  --scripts "$SCRIPT_DIR/proxy/addon.py" \
  --set block_global=false \
  --set ssl_insecure=false \
  "$@"
