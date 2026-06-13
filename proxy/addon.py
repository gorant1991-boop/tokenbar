"""
TokenBar mitmproxy addon.
Intercepts Anthropic API traffic, extracts token usage, writes to SQLite.
"""
import json
import sqlite3
import time
import re
from datetime import date
from pathlib import Path

DB_PATH = Path.home() / ".tokenbar" / "usage.db"

# Cost per million tokens (input, output) USD
MODEL_PRICING = {
    "claude-opus-4":        (15.00, 75.00),
    "claude-opus-4-5":      (15.00, 75.00),
    "claude-opus-4-6":      (15.00, 75.00),
    "claude-opus-4-8":      (15.00, 75.00),
    "claude-sonnet-4":      (3.00,  15.00),
    "claude-sonnet-4-5":    (3.00,  15.00),
    "claude-sonnet-4-6":    (3.00,  15.00),
    "claude-haiku-4":       (0.25,  1.25),
    "claude-haiku-4-5":     (0.25,  1.25),
    "claude-3-5-sonnet":    (3.00,  15.00),
    "claude-3-5-haiku":     (0.25,  1.25),
    "claude-3-opus":        (15.00, 75.00),
}
DEFAULT_PRICING = (3.00, 15.00)


def get_pricing(model: str) -> tuple[float, float]:
    for key, pricing in MODEL_PRICING.items():
        if model.startswith(key):
            return pricing
    return DEFAULT_PRICING


def init_db():
    DB_PATH.parent.mkdir(parents=True, exist_ok=True)
    conn = sqlite3.connect(DB_PATH)
    conn.execute("""
        CREATE TABLE IF NOT EXISTS usage (
            id          INTEGER PRIMARY KEY AUTOINCREMENT,
            ts          INTEGER NOT NULL,
            day         TEXT NOT NULL,
            model       TEXT NOT NULL,
            input_tok   INTEGER NOT NULL,
            output_tok  INTEGER NOT NULL,
            cache_read  INTEGER NOT NULL DEFAULT 0,
            cache_write INTEGER NOT NULL DEFAULT 0,
            cost_usd    REAL NOT NULL,
            tool        TEXT
        )
    """)
    conn.execute("CREATE INDEX IF NOT EXISTS idx_day ON usage(day)")
    conn.commit()
    conn.close()


def detect_tool(flow) -> str | None:
    """Guess which CLI tool sent the request from User-Agent or process."""
    ua = flow.request.headers.get("user-agent", "").lower()
    if "claude-code" in ua or "claudecode" in ua:
        return "Claude Code"
    if "openai-python" in ua or "codex" in ua:
        return "Codex CLI"
    if "hermes" in ua:
        return "Hermes"
    if "cursor" in ua:
        return "Cursor"
    return "Unknown"


class TokenBarAddon:
    def __init__(self):
        init_db()

    def response(self, flow):
        if "api.anthropic.com" not in flow.request.pretty_host:
            return
        if "/messages" not in flow.request.path:
            return
        if flow.response.status_code not in (200, 206):
            return

        content_type = flow.response.headers.get("content-type", "")
        body = flow.response.get_text(strict=False)
        if not body:
            return

        usage = None

        # Streaming SSE: look for the final usage event
        if "text/event-stream" in content_type:
            for line in body.splitlines():
                if line.startswith("data:"):
                    try:
                        data = json.loads(line[5:].strip())
                        if data.get("type") == "message_delta" and "usage" in data:
                            usage = data["usage"]
                        elif data.get("type") == "message_start":
                            msg = data.get("message", {})
                            if "usage" in msg:
                                usage = msg["usage"]
                                model_from_stream = msg.get("model", "")
                    except (json.JSONDecodeError, KeyError):
                        pass
        else:
            try:
                data = json.loads(body)
                usage = data.get("usage")
                model_from_stream = data.get("model", "")
            except json.JSONDecodeError:
                return

        if not usage:
            return

        # Extract model from request body
        try:
            req_body = json.loads(flow.request.get_text(strict=False) or "{}")
            model = req_body.get("model") or model_from_stream or "unknown"
        except (json.JSONDecodeError, UnboundLocalError):
            model = "unknown"

        input_tok   = usage.get("input_tokens", 0)
        output_tok  = usage.get("output_tokens", 0)
        cache_read  = usage.get("cache_read_input_tokens", 0)
        cache_write = usage.get("cache_creation_input_tokens", 0)

        in_price, out_price = get_pricing(model)
        cost = (input_tok / 1_000_000 * in_price) + (output_tok / 1_000_000 * out_price)

        tool = detect_tool(flow)
        today = date.today().isoformat()
        ts = int(time.time())

        conn = sqlite3.connect(DB_PATH)
        conn.execute(
            "INSERT INTO usage (ts,day,model,input_tok,output_tok,cache_read,cache_write,cost_usd,tool) "
            "VALUES (?,?,?,?,?,?,?,?,?)",
            (ts, today, model, input_tok, output_tok, cache_read, cache_write, cost, tool)
        )
        conn.commit()
        conn.close()


addons = [TokenBarAddon()]
