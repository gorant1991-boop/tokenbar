"""
Parses ~/.claude/projects/**/*.jsonl and writes token usage to SQLite.
No proxy, no certificates — reads Claude Code logs directly.
"""
import json
import sqlite3
import time
from datetime import datetime, date
from pathlib import Path

DB_PATH    = Path.home() / ".tokenbar" / "usage.db"
CLAUDE_DIR = Path.home() / ".claude" / "projects"

MODEL_PRICING = {
    "claude-opus-4":     (15.00, 75.00),
    "claude-sonnet-4":   (3.00,  15.00),
    "claude-haiku-4":    (0.25,  1.25),
    "claude-3-5-sonnet": (3.00,  15.00),
    "claude-3-5-haiku":  (0.25,  1.25),
    "claude-3-opus":     (15.00, 75.00),
}
DEFAULT_PRICING = (3.00, 15.00)


def get_pricing(model: str) -> tuple[float, float]:
    for key, p in MODEL_PRICING.items():
        if model.startswith(key):
            return p
    return DEFAULT_PRICING


def init_db():
    import os
    DB_PATH.parent.mkdir(parents=True, exist_ok=True)
    old_umask = os.umask(0o077)  # owner-only permissions on DB file
    conn = sqlite3.connect(DB_PATH)
    os.umask(old_umask)
    conn.execute("""
        CREATE TABLE IF NOT EXISTS usage (
            id          INTEGER PRIMARY KEY AUTOINCREMENT,
            ts          INTEGER NOT NULL,
            day         TEXT NOT NULL,
            model       TEXT NOT NULL,
            input_tok   INTEGER NOT NULL DEFAULT 0,
            output_tok  INTEGER NOT NULL DEFAULT 0,
            cache_read  INTEGER NOT NULL DEFAULT 0,
            cache_write INTEGER NOT NULL DEFAULT 0,
            cost_usd    REAL    NOT NULL DEFAULT 0,
            tool        TEXT,
            msg_id      TEXT UNIQUE
        )
    """)
    conn.execute("CREATE INDEX IF NOT EXISTS idx_day ON usage(day)")
    # msg_id index for fast dedup
    conn.execute("CREATE INDEX IF NOT EXISTS idx_msg ON usage(msg_id)")
    conn.commit()
    conn.close()


def already_imported(conn: sqlite3.Connection, msg_id: str) -> bool:
    row = conn.execute("SELECT 1 FROM usage WHERE msg_id=?", (msg_id,)).fetchone()
    return row is not None


def parse_all():
    """Full scan: import every JSONL file, skip already-seen messages."""
    init_db()
    conn = sqlite3.connect(DB_PATH)
    imported = 0

    for jsonl_file in CLAUDE_DIR.rglob("*.jsonl"):
            if jsonl_file.is_symlink():
                continue
        try:
            with open(jsonl_file, encoding="utf-8", errors="ignore") as f:
                for raw in f:
                    raw = raw.strip()
                    if not raw:
                        continue
                    try:
                        entry = json.loads(raw)
                    except json.JSONDecodeError:
                        continue

                    msg = entry.get("message", {})
                    if not isinstance(msg, dict):
                        continue

                    usage = msg.get("usage")
                    if not usage:
                        continue

                    msg_id = msg.get("id")
                    if not msg_id:
                        continue

                    if already_imported(conn, msg_id):
                        continue

                    model = msg.get("model", "unknown")
                    if not model or model.startswith("<") or model == "unknown":
                        continue
                    # Normalize date-suffixed model names: claude-haiku-4-5-20251001 → claude-haiku-4-5
                    import re as _re
                    model = _re.sub(r"-\d{8}$", "", model)
                    _cap  = 100_000_000
                    inp   = max(0, min(usage.get("input_tokens", 0), _cap))
                    out   = max(0, min(usage.get("output_tokens", 0), _cap))
                    cr    = max(0, min(usage.get("cache_read_input_tokens", 0), _cap))
                    cw    = max(0, min(usage.get("cache_creation_input_tokens", 0) or
                             usage.get("cache_creation", {}).get("ephemeral_1h_input_tokens", 0), _cap))

                    in_p, out_p = get_pricing(model)
                    cost = (inp / 1_000_000 * in_p) + (out / 1_000_000 * out_p)

                    # Derive timestamp from file mtime as fallback
                    ts  = int(jsonl_file.stat().st_mtime)
                    day = date.fromtimestamp(ts).isoformat()

                    conn.execute(
                        "INSERT OR IGNORE INTO usage "
                        "(ts,day,model,input_tok,output_tok,cache_read,cache_write,cost_usd,tool,msg_id) "
                        "VALUES (?,?,?,?,?,?,?,?,?,?)",
                        (ts, day, model, inp, out, cr, cw, cost, "Claude Code", msg_id)
                    )
                    imported += 1
        except (OSError, PermissionError):
            continue

    conn.commit()
    conn.close()
    return imported


if __name__ == "__main__":
    n = parse_all()
    print(f"Imported {n} new messages")
