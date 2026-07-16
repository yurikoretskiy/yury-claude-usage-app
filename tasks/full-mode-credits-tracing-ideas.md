# Full-mode menu bar: real-time credits tracing — under discussion

## Status
Idea only, not implemented. Decision pending (Yury: "this I will decide later").

## The idea
When usage credits are toggled **On**, Yury wants to trace how fast they're being
consumed directly from the menu bar (not just inside the popover), the same way the
session % is already visible at a glance. Motivation: the credits spend counter lags
behind real usage, and tracing it live in the menu bar would make that lag visible/useful
instead of just confusing.

## Constraint
Not truly real-time — the API's own spend counter updates with a lag (observed: 92%
shown while claude.ai already read 100%), and the widget polls every 60s. Real-time in
the menu bar means "as fresh as the API allows," not tick-by-tick. Could drop the poll
interval to ~30s specifically while credits are On, to tighten this.

## Two layout options sketched

**Option A — append**: keep the existing session-% bar exactly as-is, add the live
dollar figure alongside it.
```
[🔆|▮▮▮▮▮▮░░░░| 36%]            ← current (credits off / unused)
[🔆|▮▮▮▮▮▮░░░░| 36% | $13.77]   ← credits on: appends live $ spent
```

**Option B — swap**: while credits are On, replace the percentage readout with the
dollar counter entirely (tighter, but loses the session-% glance while credits are active).
```
[🔆|▮▮▮▮▮▮░░░░| $13.77/15]      ← credits on: % replaced by $ spent / $ limit
```

Bar itself (fill/empty ratio) stays driven by session % in both options — only the label
text differs. Neither option touches the widget when credits are Off or unused (default
compact/full rendering is unchanged).

## Open questions for whoever picks this up
- A vs B — Yury hasn't chosen yet.
- Should the poll interval actually drop while credits are On, or is that overkill given
  the API-side lag makes faster polling mostly cosmetic?
- Does this apply to Compact mode too, or Full mode only (as originally asked)?
