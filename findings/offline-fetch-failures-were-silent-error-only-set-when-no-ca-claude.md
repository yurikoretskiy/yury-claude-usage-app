# Offline fetch failures were silent: error only set when no cache — widget showed stale data as fresh

<!-- #claude -->

- Date: 05-07-2026

## Finding

`UsageService.fetchUsage()`'s catch block set `usage.error` only when `usage.lastFetched == nil`; because last-known-good data is persisted in UserDefaults, that was effectively never — so with no internet the widget kept showing stale percentages as if fresh (Yury noticed via "Last updated: 1 day, 17 hrs ago"). Fix (commit `7d54952`, on `feature/compact-mode`): every network failure now sets a visible error — offline-type URLError codes (notConnectedToInternet, networkConnectionLost, dnsLookupFailed, cannotFindHost, cannotConnectToHost, timedOut, dataNotAllowed) map to "No internet connection — showing last known data", others to the raw message. DetailPopover already rendered `usage.error` as a warning row; additionally `MenuBarRenderer` gained a `stale:` flag that draws a 9px amber "!" badge in the top-right of both full and compact menu bar images. Badge and message clear on the next successful fetch. Deployed to /Applications, md5-verified. Live offline test still pending (couldn't cut this session's own internet).
