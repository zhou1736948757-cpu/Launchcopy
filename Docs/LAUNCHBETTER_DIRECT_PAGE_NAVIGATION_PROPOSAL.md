# Page Dots and Direct Navigation — Decision Proposal

Status: APPROVED_CONTRACT — user explicitly selected the recommended clickable-dot
interaction on2026-10-13. Implementation follows Sources repair closeout.
Date: 2026-10-13
Authority: LAUNCHBETTER_PARITY_SPEC.md direct-navigation open decision.

## Problem and outcome

LaunchBetter-style bottom page dots should expose the current ordinary page and
allow direct selection without sacrificing Launchcopy's established gesture feel.
Preserve5x7 capacity and existing paging parameters; no synthetic scrolling or
negative Library page. Independent implementation and Launchcopy visual tokens.

## Recommended interaction contract

- Count comes from committed presentation, including managed/search results.
  Hide dots for0/1 page. Show committed selected page; do not switch selection just
  because an animation passes another page. Single click directly requests target.
- Add an explicit target-page API, not a sequence of nextPage calls. Clamp target
  to current ordinary page count; request same committed idle page is a no-op.
  Keep the validated duration/easing. No change to wheel/trackpad release policy.
- While a pointer gesture, momentum glide, drag or title editor owns input, ignore
  dot selection rather than cancel that physical interaction unexpectedly.
  Folder-open page dots stay behind/inert. Normal settling can be interrupted by
  another dot request: start from currently presented offset, invalidate the old
  completion, commit exactly once to latest target. No intermediate page commits.
- Before direct navigation clear grid selection as a pointer operation; first
  direction key seeds the existing deferred focus model on the settled page.
  Do not auto-launch or transfer stale keyboard identity across nonadjacent pages.
- Reduce Motion directly lands at the target and follows identical logical/focus
  reconciliation. Hide/resize/catalog/search replacement/teardown cancels obsolete
  transitions using current stale-token rules; no inactive-window callbacks.
- Accessibility exposes page-count/current-page and labeled page buttons; retain
  keyboard navigation through existing arrows. Do not introduce global shortcuts.

## Architecture and requirements

Core owns target transition/token/reason. Surface owns presented-offset capture,
frame driver/lifecycle and bounded page reuse; application owns folder/drag/editor
gate and focus. Dots use layout bounds/safe areas, not device-specific coordinates.
Bound the dot renderer/control count for large catalogs with a scrolling/windowed
representation without changing page identities. No icon work or I/O per frame.
Page-indicator updates occur on count/commit/lifecycle, not each offset tick.

## Acceptance, delivery and boundaries

Tests must cover idle first/last/nonadjacent/same-page, rapid latest-wins requests,
interrupted physical gestures ignored, stale completion rejection, Reduce Motion,
hide/resize/teardown, search page count and deferred keyboard focus. Verify real
controls-to-Core path and page reuse bound for jumps; full suite/review/build/hash.
Physical60Hz comparison and exact-candidate GUI required;120Hz remains unverified.

Specific interaction confirmed; do not change wheel/trackpad physics or silently
reduce full parity. No page-dot implementation or physical PASS is claimed yet.
