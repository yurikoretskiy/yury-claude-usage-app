# Compact Mascot Version Snapshots

Each `.swift` file here is a complete copy of `ClaudeUsage/MenuBarRenderer.swift` from a specific iteration of the compact mascot widget. Keep these for easy revert / visual comparison without digging through git history.

## Versions

| Version | File | Status | Notes |
| --- | --- | --- | --- |
| **v2.22.4** | [MenuBarRenderer-v2.22.4.swift](MenuBarRenderer-v2.22.4.swift) | ✅ **PRIMARY (shipping + /Applications/)** | Hollow silhouette — outline only in fixed light white-gray `rgb(0.85, 0.85, 0.85)`, transparent interior, orange 10pt heavy system-font digits centered inside. Pin tips inset 1px from canvas edges (left=1, right=31) so 1pt stroke doesn't clip. Matches yrojko/aswh90 Gemini reference aesthetic. Preview: [compact-v2.22.4-preview.png](../images/compact-v2.22.4-preview.png). |
| v2.21 | [MenuBarRenderer-v2.21.swift](MenuBarRenderer-v2.21.swift) | archived | Black body fill (`#0F0F0F`, matches Full-mode pill) + faint `labelColor@0.5` outline + orange 10pt heavy system-font digits. Previous primary. |
| v2.20 | [MenuBarRenderer-v2.20.swift](MenuBarRenderer-v2.20.swift) | archived | Solid `labelColor` body fill with transparent digit cutouts (destinationOut blend). "Status badge" look — visually loudest variant. |
| v2.18 | [MenuBarRenderer-v2.18.swift](MenuBarRenderer-v2.18.swift) | archived | Transparent body + faint outline + orange digits. Lightweight aesthetic; parent of v2.21. |
| v2.8 | [MenuBarRenderer-v2.8.swift](MenuBarRenderer-v2.8.swift) | archived | 3×5 bitmap digits at unit=1.5 with antialiased fills, glyph 4.5×7.5. Softer retro look. |
| v2.7 | [MenuBarRenderer-v2.7.swift](MenuBarRenderer-v2.7.swift) | archived | 3×5 bitmap digits at unit=2, glyph 6×10, coral outline, body 24×14. Original pixel-mascot direction. |
| v2.6 | [MenuBarRenderer-v2.6.swift](MenuBarRenderer-v2.6.swift) | archived | 5×7 bitmap at unit=1, glyph 5×7, body stroke 0.5. Too thin — right arm clipped. |

## Why v2.22.4 is primary

User decision (2026-04-24): approved the hollow-silhouette direction (outline only + transparent interior + orange digit) after reviewing the yrojko/aswh90 Gemini references and confirming that the solid black body in v2.21 read too heavy on light menu bars. The fixed light white-gray outline avoids the mode-adaptive color pitfall (v2.22.1–v2.22.3 used `labelColor` / `secondaryLabelColor` which rendered near-black in light appearance).

Key fixes in v2.22.4 vs earlier hollow attempts:

- **Right-arm clipping regression fixed** — pin tips inset 1px from canvas edges (left=1, right=31). Without fill, stroke-at-edge lost half its width to the image boundary.
- **Fixed outline color** (not mode-adaptive) so outline is consistent regardless of system appearance.

## Why v2.21 was previously primary

User decision (2026-04-20):

> Let's keep it because the primal version is also connected to CU, terminal, update the documentation commit to everywhere you need to commit. I just really feel something is not mentioned but I don't know what, maybe the black cover inside with this gray-white border line, maybe it's okay when it's night and dark time, but it's not okay during the day. But at least it's very observability.

The day/light-mode concern flagged there is what motivated the v2.22.x hollow direction.

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
