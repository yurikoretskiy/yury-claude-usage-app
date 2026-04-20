# Compact Mascot Version Snapshots

Each `.swift` file here is a complete copy of `ClaudeUsage/MenuBarRenderer.swift` from a specific iteration of the compact mascot widget. Keep these for easy revert / visual comparison without digging through git history.

## Versions

| Version | File | Status | Notes |
| --- | --- | --- | --- |
| **v2.21** | [MenuBarRenderer-v2.21.swift](MenuBarRenderer-v2.21.swift) | ✅ **PRIMARY (shipping + /Applications/)** | Black body fill (`#0F0F0F`, matches Full-mode pill) + faint `labelColor@0.5` outline + orange 10pt heavy system-font digits. Rounded top corners. |
| v2.20 | [MenuBarRenderer-v2.20.swift](MenuBarRenderer-v2.20.swift) | archived | Solid `labelColor` body fill with transparent digit cutouts (destinationOut blend). "Status badge" look — visually loudest variant. |
| v2.18 | [MenuBarRenderer-v2.18.swift](MenuBarRenderer-v2.18.swift) | archived | Transparent body + faint outline + orange digits. Lightweight aesthetic; parent of v2.21. |
| v2.8 | [MenuBarRenderer-v2.8.swift](MenuBarRenderer-v2.8.swift) | archived | 3×5 bitmap digits at unit=1.5 with antialiased fills, glyph 4.5×7.5. Softer retro look. |
| v2.7 | [MenuBarRenderer-v2.7.swift](MenuBarRenderer-v2.7.swift) | archived | 3×5 bitmap digits at unit=2, glyph 6×10, coral outline, body 24×14. Original pixel-mascot direction. |
| v2.6 | [MenuBarRenderer-v2.6.swift](MenuBarRenderer-v2.6.swift) | archived | 5×7 bitmap at unit=1, glyph 5×7, body stroke 0.5. Too thin — right arm clipped. |

## Why v2.21 is primary

User decision (2026-04-20):

> Let's keep it because the primal version is also connected to CU, terminal, update the documentation commit to everywhere you need to commit. I just really feel something is not mentioned but I don't know what, maybe the black cover inside with this gray-white border line, maybe it's okay when it's night and dark time, but it's not okay during the day. But at least it's very observability. Yeah, I see the number. I understand what is at Claude. Let's process later.

The black-body fill provides strong contrast in dark menu bars (night appearance). **Open concern**: may read poorly in LIGHT menu bar appearance (daytime) — the black pill against a light wallpaper could look heavy. Tracked for a future iteration; see [tasks/compact-mascot-future-ideas.md](../tasks/compact-mascot-future-ideas.md).

## Recreation

```bash
# Swap the active renderer for any snapshot, build, and deploy to /Applications/:
cp snapshots/MenuBarRenderer-vX.X.swift ClaudeUsage/MenuBarRenderer.swift
swift build
rm -rf "/Applications/Claude Usage.app"
cp -R .build/debug/ClaudeUsage.app "/Applications/Claude Usage.app"
open "/Applications/Claude Usage.app"
```

`cu` (terminal alias) will launch whatever is installed at `/Applications/Claude Usage.app`, so the deploy above switches which variant `cu` shows.
