# Claude Usage Widget — Lessons Learned

Last updated: 13-03-2026

---

## For Claude (agent rules)

### Diagnostic Protocol — MANDATORY

When the user reports "CU is broken" or the widget shows any error:

```
1. tail -20 /tmp/ClaudeUsage.log          ← ALWAYS FIRST. No exceptions.
2. Identify the actual error:
   - "429"           → rate limiting (not auth!)
   - "401"           → token expired or invalid
   - "no credentials"→ keychain read failed
   - "skipped"       → stuck in a blocking loop
3. If 429/skipped: restart the widget (pkill + open). Done.
4. If 401: check keychain token expiry (security find-generic-password)
5. If no credentials: check if Claude Code is logged in
6. ONLY THEN look at code
```

**Do NOT jump to "auth breakage" by default.** The widget has had 3 auth issues and 1 rate-limit freeze. Each requires a completely different fix. Read the logs.

### Coding Rules

| Rule | Why | Incident |
|------|-----|----------|
| Never use `Task.sleep` inside a guarded async function (`isLoading`) | Sleep holds the guard for the entire duration, blocking all future calls. Use timer-based retry instead. | 13-03-2026: 3486s sleep froze widget |
| Cap `Retry-After` to `maxInterval` (300s) | API can return 3000+s. Respecting it literally kills the widget. | 13-03-2026: Retry-After: 3471 |
| Check `claude --version` and update User-Agent when fixing the widget | Stale User-Agent triggers Cloudflare rate limits. It rots silently. | 13-03-2026: was 2.1.63, current 2.1.74 |
| Error messages must match actual state | Widget showed "No OAuth token found" when real issue was 429 rate limit. User can't diagnose from wrong message. | 13-03-2026 |
| Never do inline retry inside `fetchUsage()` | Use `startPolling(fetchImmediately: false)` to schedule retries via timer. This is already documented in CLAUDE.md rule #2. | Multiple incidents |

### Maintenance Checklist (run every fix session)

- [ ] Read `/tmp/ClaudeUsage.log` first
- [ ] Check `claude --version` vs hardcoded User-Agent in UsageService.swift:109
- [ ] After fix: verify via logs (`OK session=X% weekly=Y%`), not just "it compiled"
- [ ] Deploy protocol: `pkill` → `rm -rf` → `cp -R` → `open` → verify md5

---

## For Yury (user quick-reference)

### When the widget shows an error or 0%

**Step 1 — Check logs (copy-paste this):**
```bash
tail -20 /tmp/ClaudeUsage.log
```

**Step 2 — Interpret:**

| Log says | Meaning | Your fix |
|----------|---------|----------|
| `HTTP 429` or `sleeping Xs` | Rate limited or stuck | Restart: `pkill -f ClaudeUsage && open "/Applications/Claude Usage.app"` |
| `HTTP 401` | Token expired | Open Claude Code extension (VSCode) or run `claude` in terminal, then restart widget |
| `no credentials` | Can't read keychain | Same as 401 — make sure Claude Code is logged in |
| `OK session=X%` | Actually working fine | Widget UI might be stale — click the menu bar icon to refresh |

**Step 3 — If restart doesn't fix it:**
Paste the last 20 lines of `/tmp/ClaudeUsage.log` when reporting to Claude. This saves 80% of diagnosis time.

### Quick commands

```bash
# Restart widget
pkill -f ClaudeUsage && open "/Applications/Claude Usage.app"

# Check if cu CLI works (independent of widget)
cu

# Check logs
tail -20 /tmp/ClaudeUsage.log

# Nuclear option: rebuild from source
cd ~/yury-vibe-coding/claude-usage-app && ./build-and-run.sh
```

---

## Incident History

| Date | Symptom | Actual cause | Fix |
|------|---------|-------------|-----|
| 13-03-2026 | Widget shows 0%, "No OAuth token" | 429 rate limit + blocking `Task.sleep(3486s)` inside `fetchUsage()` | Replaced inline sleep with timer-based backoff, capped Retry-After to 300s |
| 13-03-2026 | `cu` CLI: "HTTP 400 Bad Request" | Keychain account name changed to `yurikoretskiy`, script tried stale entry | Removed self-managed OAuth refresh, read freshest keychain entry |
| 12-03-2026 | "No Claude Code credentials found" | Keychain parser assumed field ordering | Rewrote parser to collect fields independently |
| Earlier | Script couldn't find credentials | `~/.claude/.credentials.json` removed | Added Keychain fallback (now primary) |
