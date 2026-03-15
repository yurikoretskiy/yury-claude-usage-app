# Yury Claude Usage App — Project Guide

## What This Is
A native macOS menu bar widget that displays real-time Claude Pro/Max subscription usage. Shows current session %, weekly %, and per-model limits (e.g. Sonnet, Opus). Built with Swift/SwiftUI using `MenuBarExtra`. No dock icon — lives entirely in the menu bar.

## Architecture

```
ClaudeUsage/
├── ClaudeUsageApp.swift      — App entry point. MenuBarExtra with .window style.
├── UsageService.swift        — Fetches usage from Anthropic OAuth API every 60s.
│                               Parses five_hour, seven_day, and dynamic model-specific
│                               limits (seven_day_sonnet, seven_day_opus, etc.).
│                               Published @ObservableObject driving the UI.
├── KeychainHelper.swift      — Reads OAuth token from BOTH ~/.claude/.credentials.json
│                               AND macOS Keychain, picks freshest by expiresAt.
│                               Read-only: Claude Code handles token refresh.
│                               Caches token for 5 min to avoid repeated reads.
├── MenuBarRenderer.swift     — Renders the retro-digital NSImage for the menu bar:
│                               Claude logo PNG + orange segmented bar + percentage.
├── DetailPopover.swift       — Dropdown panel matching claude.ai/settings/usage style.
│                               Shows session %, weekly %, per-model limits with progress bars.
└── Resources/
    └── claude-logo.png       — Official Claude starburst logo (transparent PNG).
```

## Data Flow
1. `KeychainHelper` reads OAuth token from **two sources**: `~/.claude/.credentials.json` (file) and macOS Keychain via `security find-generic-password -w`. Picks whichever has the freshest `expiresAt`. Claude Code flip-flops between these storage locations across versions — both are checked permanently.
   - Supports two JSON formats: nested `{"claudeAiOauth": {"accessToken": ...}}` and flat `{"accessToken": ...}`
2. `UsageService` calls `GET https://api.anthropic.com/api/oauth/usage` with Bearer token, `anthropic-beta: oauth-2025-04-20`, and `User-Agent: claude-code/X.X.X` header (required by Cloudflare)
3. API returns active fields (`five_hour`, `seven_day`, `seven_day_sonnet`, etc.) plus null/inactive fields — parser dynamically discovers any `seven_day_*` model-specific limits
4. `MenuBarRenderer` generates an NSImage from the session percentage
5. `DetailPopover` shows full breakdown: session, weekly "All models", and per-model rows (Sonnet, Opus, etc.)

## API Response Shape (as of March 2026)
```json
{
  "five_hour": { "utilization": 13.0, "resets_at": "..." },
  "seven_day": { "utilization": 38.0, "resets_at": "..." },
  "seven_day_sonnet": { "utilization": 2.0, "resets_at": "..." },
  "seven_day_opus": null,
  "seven_day_oauth_apps": null,
  "seven_day_cowork": null,
  "iguana_necktie": null,
  "extra_usage": { "is_enabled": false, ... }
}
```
Only non-null `seven_day_*` entries with a `utilization` field are shown. Unknown/null fields are silently skipped.

## Key Technical Decisions
- **SPM over Xcode project** — simpler, no .xcodeproj files, builds with `swift build`
- **NSImage rendering** — MenuBarExtra label only accepts Image+Text, so the entire widget (logo + bar + %) is rendered as a single NSImage
- **User-Agent header** — Anthropic's API requires `User-Agent: claude-code/X.X.X` or Cloudflare blocks with 429
- **Dynamic model parsing** — automatically discovers new `seven_day_*` model limits without code changes

## Build & Run
```bash
./build-and-run.sh    # Build and launch (debug)
open "/Applications/Claude Usage.app"  # Start installed version
pkill -f ClaudeUsage  # Stop
```
For reinstall protocol (kill/rm/cp/open/md5-verify) and debugging via `/tmp/ClaudeUsage.log`, see the **app-development skill**.

## Dependencies
- macOS 13+ (Ventura) — required for `MenuBarExtra`
- Swift 5.9+
- Claude Code must be logged in (token must exist in `~/.claude/.credentials.json` or macOS Keychain under service "Claude Code-credentials")
- No third-party packages

## Breakage History
8 breakages in Feb–Mar 2026. Full table and lessons in the **app-development skill** (`~/.claude/skills/app-development/reference.md`).

## Development Guidelines

This project follows the **app-development skill** (installed at `~/.claude/skills/app-development/`). Claude loads it automatically when working on this app.

**Key rules for this project:**
1. **Check logs first** (`/tmp/ClaudeUsage.log`) before changing any code
2. **Never call `fetchUsage()` immediately from backoff/error paths** — use `startPolling(fetchImmediately: false)`
3. **Deploy protocol:** `pkill` → `rm -rf` → `cp -R` → `open` → verify with `md5`
4. **One change per session** — don't bundle fixes
