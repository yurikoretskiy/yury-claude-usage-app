# Compact Mascot — Handover

## Status
**Planned, not implemented.** Spec agreed with user 2026-04-20. Awaiting implementation go-ahead.

## Branch
`feature/compact-mode`

## Context for Next Session
The current compact widget renders a procedural chip silhouette + 3×5 bitmap digits, which does **not** match the Gemini reference. Previous attempts swapped PNGs into `ClaudeUsage/Resources/compact-mascot.png`, but that file is **loaded but never drawn** — see [MenuBarRenderer.swift:16](../ClaudeUsage/MenuBarRenderer.swift#L16) (`compactTemplate` cached, never used). That's why image swaps had no visible effect.

## Reference
- Target image: [Gemini_Generated_Image_yrojkoyrojkoyroj.png](../Gemini_Generated_Image_yrojkoyrojkoyroj.png)
- Spec: [compact-mascot-spec.md](compact-mascot-spec.md)

## Implementation Plan
1. **Read** the yrojko PNG in Python/tool to extract exact pixel grid of the "7" and "5" glyphs → transcribe to `pixelDigits5x7` Swift dict (all 0–9).
2. **Sample** the coral color from yrojko (mid-pixel of a filled region) → add `coralColor` constant in [MenuBarRenderer.swift](../ClaudeUsage/MenuBarRenderer.swift).
3. **Rewrite** `renderCompactMenuBarImage(percentage:)`:
   - Draw stroked chip outline in coral (body rect, 2 pins, 5 legs)
   - Render percentage digits with `pixelDigits5x7` auto-scaled for 1/2/3-digit widths
   - Center digits inside body rect
4. **Remove** now-unused `compactTemplate` loader and `compact-mascot.png/svg` resources.
5. **Deploy** via `./build-and-run.sh`, verify via `md5` and screenshot.
6. **Update** [CLAUDE.md](../CLAUDE.md) if architecture changed.

## Files Touched (expected)
- `ClaudeUsage/MenuBarRenderer.swift` (rewrite compact renderer, add digits/color)
- `ClaudeUsage/Resources/compact-mascot.png` (delete)
- `ClaudeUsage/Resources/compact-mascot.svg` (delete)
- `Package.swift` (remove resource entry if needed)

## Risks / Gotchas
- **Pixel-digit extraction**: the PNG is rendered with anti-aliasing, so digit edges aren't perfectly binary. Use a luminance threshold (~0.5) when transcribing glyphs.
- **22 px height is tight**: a 7-row digit at 2px/pixel = 14px tall — leaves 8px for body padding + legs. May need to drop pixel size to 1.5 for 3-digit case ("100").
- **Color consistency**: compact-mode coral differs from full-mode orange. Don't touch full-mode colors.
- **Breakage history**: this project has had 8 breakages in Feb–Mar 2026. Stick to deploy protocol in [CLAUDE.md](../CLAUDE.md) (`pkill` → `rm -rf` → `cp -R` → `open` → `md5` verify). Check `/tmp/ClaudeUsage.log` first if anything misbehaves.

## Uncommitted Work on Branch
From `git status` at handover time:
- `M  ClaudeUsage/MenuBarRenderer.swift` — partial procedural compact renderer (keep as scaffolding, rewrite digit section)
- `M  ClaudeUsage/Resources/compact-mascot.png` — will be deleted
- `M  Package.swift`, `build-and-run.sh` — review before committing
- Untracked Gemini PNGs in repo root — the yrojko one is the source of truth; others can be archived or removed

## Decision Log
- **2026-04-20** — User chose route 2 (procedural redraw) + coral + no `%` symbol. PNG-overlay route (`route 1`) rejected because scaling blurs at 22px.
