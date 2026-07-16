# Liquid Glass style — parked

## Status
Removed from the widget (2026-07-15). Not deleted from history — this note captures
what was tried and why it didn't look right, in case it's revisited later.

## What was built
A "Style" picker (Current / Liquid Glass) next to the Display-size picker. Liquid Glass
mode wrapped the popover content in `GlassEffectContainer { ... .glassEffect(.regular, in:) }`
(macOS 26 API) and cleared the host `NSWindow`'s opaque background (`isOpaque = false`,
`backgroundColor = .clear`) so the glass would have real desktop content behind it to
refract, instead of just blurring its own panel's flat backing.

## Why it still didn't read as real Liquid Glass
Confirmed via Yury's own screenshots after deploying the window-transparency fix: still
flat, not the Control Center look. The window-opacity fix compiled and ran without
crashing, but visually made no discernible difference. Root cause not confirmed — candidates,
untested:
- `MenuBarExtra`'s `.window` style may re-assert its own opaque backing on every
  layout pass (fighting `ClearWindowBackground`'s one-shot `DispatchQueue.main.async` set).
- The panel might have an internal `NSVisualEffectView` layer between the window and our
  SwiftUI content that isn't reachable via the window's own background properties.
- `.glassEffect()`'s specular/lensing rendering may be tuned for small controls (buttons,
  capsules) inside `GlassEffectContainer`, not a large static panel — Apple's own examples
  are toolbar buttons, not full popovers.
- Menu-bar popovers may sit at a window level Liquid Glass doesn't composite against
  correctly (unclear).

## If revisited
Would need actual visual inspection during development (not blind), e.g. build a tiny
throwaway SwiftUI window (not a MenuBarExtra) to isolate whether `.glassEffect()` itself
renders as expected outside the MenuBarExtra panel, before reintroducing it here.

## Decision
Not worth further token spend chasing without ability to visually iterate cheaply.
Dropped per Yury's instruction — one style only (Current/native), no toggle.
