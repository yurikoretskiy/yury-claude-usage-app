# Compact Mascot Version Snapshots

Each `.swift` file here is a complete copy of `ClaudeUsage/MenuBarRenderer.swift` from a specific iteration of the compact mascot widget. Keep these for easy revert / visual comparison without having to dig through git history.

## Versions

| Version | File | Status | Notes |
| --- | --- | --- | --- |
| **v2.18** | [MenuBarRenderer-v2.18.swift](MenuBarRenderer-v2.18.swift) | ✅ **PRIMARY (shipping)** | System-font digits (10pt heavy monospaced, orange) centered in a rounded-top-corner chip with faint `labelColor@0.5` outline. Transparent body. Compact (body 24×12). |
| v2.7 | [MenuBarRenderer-v2.7.swift](MenuBarRenderer-v2.7.swift) | archived | 3×5 pixel bitmap digits at unit=2, glyph 6×10, coral outline, body 24×14. The "retro mascot" look before the Full-mode alignment work. |
| v2.6 | [MenuBarRenderer-v2.6.swift](MenuBarRenderer-v2.6.swift) | archived | 5×7 bitmap at unit=1, glyph 5×7, body stroke 0.5. Smaller but too thin → right arm clipped at canvas edge. |
| v2.8 | [MenuBarRenderer-v2.8.swift](MenuBarRenderer-v2.8.swift) | archived | 3×5 bitmap at unit=1.5 with antialiased digit fills, glyph 4.5×7.5. Softer and more aesthetically balanced than v2.7 but digits read less clearly on a crowded menu bar. |

## Why v2.7 is primary

User decision (2026-04-20):

> v2.8 looks more beautiful / more aesthetically balanced, but the visibility isn't good. I decided to bring back the bigger numbers. They look less beautiful, less aligned, but they are better visible and they kind of psychologically motivate me to use Claude. That's the main reason to trace it.

Visibility + motivational value of a bold, easy-to-read percentage beat visual refinement. v2.8 is preserved here in case a future iteration wants to revisit the softer style.

## Recreation

To revert to a snapshot: `cp snapshots/MenuBarRenderer-vX.X.swift ClaudeUsage/MenuBarRenderer.swift && ./build-and-run.sh`
