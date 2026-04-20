# Compact Mascot Widget — Specification

## Goal

Replace the current broken compact-mode menu bar icon with a faithful reproduction of the Gemini-generated mascot in [Gemini_Generated_Image_yrojkoyrojkoyroj.png](../Gemini_Generated_Image_yrojkoyrojkoyroj.png), including its pixel-font digits.

## Reference Image

- File: `Gemini_Generated_Image_yrojkoyrojkoyroj.png`
- Transparent background
- Coral/pink outline silhouette: chip body with **1 pin per side** (mid-height) and **4 leg stubs** at bottom, flat top
- Chunky pixel-art digits "75" centered in the body
- No "%" symbol
- Small sparkle artifact in bottom-right (Gemini watermark-style) — must be excluded

## Design Decisions (agreed)

| Decision | Choice | Rationale |
| --- | --- | --- |
| Rendering route | **Procedural** (redraw in code, no PNG dependency) | Crisp at 22px menu-bar height; no scaling blur; dynamic digits need redrawing anyway |
| Color | **Coral ~`#F0927D`** (match yrojko) | Replaces the current orange `(1.0, 0.6, 0.0)` for compact mode only |
| "%" symbol | **Omit** | Matches reference |
| Digit font | **New 5w×7h bitmap** transcribed from yrojko's "75" glyphs | Existing 3×5 `pixelDigits` is too small/thin |
| Watermark | Not reproduced | It's a Gemini artifact, not part of the design |
| Full-mode widget | **Unchanged** | Spec only covers compact variant |

## Technical Requirements

### Canvas

- Width: 44 px (current), may adjust to fit 5×7 digits at readable scale
- Height: 22 px (menu-bar constraint)
- Transparent background

### Silhouette

- Stroked outline (no fill) — thickness tuned for 22px legibility (~1.5px)
- Chip body: rounded rectangle
- Side pins: 1 per side, mid-body
- Leg stubs: **4** evenly distributed along bottom
- Top edge: flat (no pins/antennas)
- All geometry fits inside 22px (no clipping by menu bar)

### Digits

- New `pixelDigits5x7` bitmap table for 0–9 matching yrojko's glyph shapes
- Centered horizontally and vertically inside the chip body
- Pixel size auto-scales so 1, 2, and 3-digit percentages all fit
- Same coral color as the outline

## Files Affected

- [ClaudeUsage/MenuBarRenderer.swift](../ClaudeUsage/MenuBarRenderer.swift) — rewrite `renderCompactMenuBarImage`, add `pixelDigits5x7`, add coral color constant
- [ClaudeUsage/Resources/compact-mascot.png](../ClaudeUsage/Resources/compact-mascot.png) — can be deleted (no longer referenced)
- [ClaudeUsage/Resources/compact-mascot.svg](../ClaudeUsage/Resources/compact-mascot.svg) — can be deleted

## Out of Scope

- Full-mode menu bar icon (unchanged)
- Detail popover styling
- Display mode toggle logic
- New icon states (offline, error, etc.)

## Acceptance Criteria

1. Compact widget visually matches yrojko reference (silhouette shape, proportions, pixel-digit style)
2. Live percentage renders correctly for 1, 2, and 3-digit values
3. Nothing clipped at menu-bar height
4. Coral color matches reference
5. `/tmp/ClaudeUsage.log` shows no rendering errors after deploy
6. Widget survives the standard deploy protocol (`pkill` → `rm -rf` → `cp -R` → `open` → `md5` verify)
