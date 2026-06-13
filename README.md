# TokenBar

Track Claude Code token usage and costs directly in your macOS menu bar.

## What it is

TokenBar monitors Claude Code activity from `~/.claude/projects/**/*.jsonl` logs and displays real-time usage metrics in your menu bar. No setup beyond opening the app — reads logs locally, no proxy or network requests.

## Install

**One-click:** download `TokenBar.zip` from [releases](https://github.com/gorant/tokenbar/releases), unzip, double-click `TokenBar.app`. App installs itself to `~/Applications` and auto-starts on login.

**From source:** 
```bash
git clone https://github.com/gorant/tokenbar
cd tokenbar
./scripts/build_release.sh
# Produces: build/TokenBar.zip
```

## Features

- **TODAY panel** — daily tokens used and cost (switches based on plan)
- **Progress bar** — visual usage meter with configurable alert thresholds (50%, 75% by default)
- **BY MODEL** — token breakdown per Claude model with % of daily total
- **LAST 7 DAYS** — bar chart of daily usage trend
- **NETWORK** — real-time per-process bandwidth (KB/s, MB/s) via `nettop`
- **ECO tab** — energy (Wh), CO₂ (g), water (ml), fun comparisons (phone charges, Tesla km, Netflix minutes), rotating wisdom quotes from Tao Te Ching / Stoics / Borges
- **Notifications** — macOS alerts when usage hits thresholds
- **Settings** — plan selector, daily token limit, alert thresholds

## Plans

TokenBar supports four plan types:

| Plan | Display | Alert |
|------|---------|-------|
| Claude Pro | tokens only | user-set daily limit |
| Claude Max $100 | tokens only | user-set daily limit |
| Claude Max $200 | tokens only | user-set daily limit |
| API (pay-per-use) | dollars | user-set daily budget |

Anthropic doesn't publish token limits for subscription plans, so you set your own after observing where you hit rate limits.

## How it works

TokenBar parses Claude Code logs (`~/.claude/projects/**/*.jsonl`) every 60 seconds, extracts token counts and model names, stores daily stats in `~/.tokenbar/usage.db` (SQLite, owner-only permissions), and displays aggregated metrics in the menu bar popover. Network monitoring runs via `nettop` in the background.

Settings (plan, limits, thresholds) are persisted in macOS `UserDefaults`. All processing is local — zero network requests.

## Build from source

### Requirements
- macOS 13+
- Swift 5.9 (via Command Line Tools: `xcode-select --install`)
- No Xcode, no CocoaPods, no external dependencies

### Dev build
```bash
./scripts/build_app.sh
open build/TokenBar.app
```

### Release build (distributable zip)
```bash
./scripts/build_release.sh
# Outputs: build/TokenBar.zip
```

Both scripts compile a universal binary (Intel + Apple Silicon) using only `swiftc`.

## Security

- Symlink-protected log parsing (no TOCTOU vulnerabilities)
- Token values clamped to prevent integer overflow
- SQLite database owned by current user (mode 0600)
- No secrets stored; no credentials sent anywhere
- All processing stays local to your machine

## License

[MIT](LICENSE)

## Feedback

Issues and pull requests welcome on GitHub.
