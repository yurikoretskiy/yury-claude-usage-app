# Compact Mascot — Future Iteration Ideas

Captured 2026-04-20 after shipping **v2.7** as primary. These are directions to explore in later rounds; **not on the current sprint**.

## Theme: unify visual language between Full and Compact modes

The core idea: when the widget "compacts" from Full mode → Compact mode, it should feel like the same element squeezed smaller, not a different icon. Today the two modes use different color palettes (Full: black pill + orange logo/bar/digits; Compact: transparent + coral mascot outline). That visual break should go away.

## Candidate directions

### 1. Align the color palette across modes

- Full mode palette (reference):
  - Background: `#0F0F0F` (near-black)
  - Primary: `orangeColor = rgb(1.0, 0.6, 0.0)` (warm orange)
  - Dim primary: `dimOrangeColor = rgb(0.30, 0.18, 0.02)` (unfilled bar segments)
- Compact mode currently uses **coral** (`#FCAC98`) and transparent background
- **Option A**: swap compact coral → full's orange, keep transparent background. Minimal change, mascot outline becomes orange.
- **Option B**: give the compact mascot a filled black body (like the full pill) with orange outline + orange digits. Highest visual continuity — the mascot literally is "a shrunken pill".
- **Option C**: invert — mascot body is filled black, "eyes"/digits are orange, legs/pins orange. Feels more like a character.

### 2. Bring the Full-mode digit style into Compact

Full mode renders the percentage in `monospacedDigit` system font (heavy weight, 11 pt) with a smaller `%` symbol. Compact currently uses a 3×5 pixel bitmap (v2.7).

- **Option D**: replace the compact bitmap digits with a shrunken version of the full-mode system-font digits (e.g., 8–9 pt heavy). Transition between modes would feel continuous — the digits are the same typographic object, just smaller.
- Caveat: system fonts may not stay as crisp at 7-px glyph heights as the hand-tuned bitmap. Test before committing.

### 3. Compact = "pill with legs"

Combine 1 and 2:

- Filled black rounded-rect background (same corner radius / fill as full mode's pill)
- Coral or orange mascot outline + pins + legs overlaid on top
- Orange digits (system font) centered
- The mascot shape becomes a "pill with a chip-silhouette frame and legs"

This is the strongest unification: Full and Compact share background, color, and digit style; only the width and the added chip-frame differ.

### 4. Transition animation (stretch goal)

If/when modes change via the Display Mode toggle, animate the collapse: Full → interpolate width down, hide progress bar, reveal mascot frame, digits rescale. Fun, low priority.

## Decision points to resolve before implementing

1. **Which palette wins?** Full's orange + black, or keep Compact's coral? User quote: "I want also to align the colors, using the full copy and compact copy" — suggests aligning, but direction (full → compact, or compact → full) is open.
2. **Mascot body: filled or outlined?** Filled black changes character dramatically from the yrojko reference. Outlined (current) preserves yrojko look. A hybrid (outlined with semi-transparent fill) could work.
3. **Digits: bitmap or system font?** Bitmap matches yrojko retro personality; system font matches Full mode. Pick one story.
4. **3-digit case (100%)**: still handled by shrink-to-unit=1 rule, unchanged by this theme.

## What to keep untouched

- Silhouette anatomy (1 pin/side, 4 legs clustered 2+2, flat top, 32×22 canvas)
- Leg / pin / body proportions on the 2-pixel unit grid
- Deploy / git-commit / snapshot workflow established in v2.1–v2.7

## Notes from user (verbatim)

### 2026-04-20 — color-unification intent

> Take for the further interactions maybe change color of the borders of the mascot, maybe change all the colors or maybe make the mascot itself black the same way as a full widget, not compacted version. And in the full widget from there bring numbers that are on the right of the full widget, that are on the right side, that it kind of when it's compacting from the full widget it's It is compacted into the black mascot with the same colors. I want also to align the colors, using the full copy and compact copy. Keep it as a to-do plan ideas.

### 2026-04-20 — after shipping v2.21 (black body + orange digit)

> Let's keep it because the primal version is also connected to CU, terminal. I just really feel something is not mentioned but I don't know what, maybe the black cover inside with this gray-white border line, maybe it's okay when it's night and dark time, but it's not okay during the day. But at least it's very observability. Yeah, I see the number.

**Outstanding concern to address later**: the near-black body fill (`backgroundColor = rgb(0.06, 0.06, 0.06)`) gives strong contrast in dark menu-bar appearances (night, dark wallpapers) but may feel heavy or mismatched in LIGHT menu bars (day, light wallpapers). Options to explore in a future round:

- Swap the fill to a `dynamic color` that flips with `NSAppearance` (dark → near-black, light → near-white or a subtle tint)
- Use `NSColor.controlBackgroundColor` or another semantic background color that inherently adapts
- Drop the fill in light mode (transparent body + outline only, like v2.18) and keep the black only in dark mode
- Use a mid-gray fill that reads OK in both modes
