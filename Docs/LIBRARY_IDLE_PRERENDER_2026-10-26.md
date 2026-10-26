## Latest acceptance — 2026-10-26: user L1 PASS

The user reported: “不错，算是通过l1”. Record **L1 user acceptance** for the requested first Library entry / first return experience in the isolated idle pre-display candidate. L1 is the user's label, not a newly defined formal test level or a legacy Phase 1J task. No separate direction scores or numerical frame measurements were supplied.

Accepted artifact: `LaunchcopyPreviewIdleDisplay.app`, executable SHA-256 `569566de48c6256696d501b46182354ba01658d9a1099901e8077acf5d491bc1`; exact owned PID 98255 was verified at acceptance recording. All 616 R6 source inputs and five canonical isolated profile hashes/modes remained unchanged. No source edits, parameter changes, additional builds/tests, Quit/restart, diagnostic reset/export, installation or production-data mutation were performed for this acceptance. Existing 3824/0 full-suite evidence and bounded independent source review are unchanged prior evidence, not newly rerun.

This supersedes earlier PENDING statements **only for this subjective L1 trial**. It does not establish a numerical frame-pacing threshold, GPU/compositor warm-up, a complete hitch root cause, full feature parity or release approval. Keep the accepted version and paging parameters unchanged. The current process and its in-memory diagnostic capture are left untouched; no fresh timing export is claimed.

Evidence: `.build/verification/20261026/library-idle-prerender/human-l1-acceptance-r1.json` and `profile-after-l1-acceptance-r1.json`. Earlier entries below remain dated history; process IDs describe observation time, not a perpetual runtime guarantee.

---

# First-direction Library warm-up — 2026-10-26

## Problem and outcome
The user reports a hitch on the first Library entry and first return to the main grid; later transitions improve. Treat this as fresh physical feedback, not an established CPU diagnosis. Investigate application-side cold work and implement bounded idle preparation where supported, preserving accepted tracking and stationary search behavior.

## Scope and architecture
Use the existing AppKit Library owner, detached card preparation, icon pipeline and parent navigator. Main owns hot-path investigation, integration, tests, builds and native operations. A read-only sidecar audits icon/material lifecycle and earlier first-entry attempts; independent source review follows the stable patch. At most three active agents including Main; no legacy Chief/watchdog workflow, no overlapping source writers/builds.

## Requirements
- No physics, thresholds, timer tolerance, Library semantic location/query/action permission, catalog identity, persisted schema or arrangement changes.
- No visible warm-up flash, focus/editor transfer, accessibility/action exposure, launcher opening, application launch, raw inventory logs or private API.
- Prepare only at existing readiness gates, after a quiet opportunity; bounded memory/work and cancellation/latest-generation checks across every suspension. No repeated full work for an unchanged presentation. Native view/layout/drawing stays on MainActor; pure heavy projection stays in the existing background mechanism.
- Distinguish constructing controls, layout, bitmap drawing, icon decoding and compositor/material realization. Calling an offscreen display method alone does not prove GPU warm-up or physical smoothness.
- Yield preparation to real input, folder/title edit, visibility/lifecycle changes and pending accepted writes. Preserve Reduce Motion/Transparency behavior, separate search queries, passive category backgrounds and actual error reporting.
- Shared isolated data must survive a normal owned Quit/handover; do not reset or import older profiles. No production install/overwrite/signing/Git mutation/force exit.

## Investigation and acceptance
1. Establish unchanged source/artifact baseline and preserve current anonymous input evidence before reset/Quit. Inspect entry/return owners and previous cold-entry instrumentation.
2. Add deterministic regression tests for demonstrated cold work and invalidation; prefer reuse of existing preparation seams over a parallel cache/lifecycle.
3. Implement only justified safe idle work and avoid doing preparation in scroll dispatch. Quantify bounded component work with neutral counters/timings; never equate synthetic timing with physical frame performance.
4. Run focused then unfiltered full XCTest; serial Debug, actual Release and unique strict isolated packaging; independent bounded source review.
5. Verify native startup/no warm-up flash/header and profile preservation; leave a freshly started process for a human first entry/first return comparison. Hardware frame pacing remains pending unless actually measured.

## Risks and boundaries
Detached/hidden AppKit views may not realize the WindowServer compositor or within-window blur. Prewarming can merely move a stall to startup; do not claim an exhaustive root cause, GPU guarantee, or all hitches fixed. Existing dirty tree and previous results remain preserved. Stop a speculative method if its lifecycle/memory cost outweighs evidence; document a bounded alternative.

## Decisions / unresolved
Initial discovery: existing preparation builds detached shells/cards, but the first live projection still performs a separate bind/layout/icon lifecycle. Exact first-entry and first-return costs are not yet isolated. Final warm-up strategy will be appended after source/counter evidence.

## Design delta: bounded native-control pre-display
The source confirms prepared cards have zero frames and no first-viewport icon cache requests until live mounting. Add usable card/button geometry while building the existing pool (one category per yield). After a 200 ms closed-pane quiet opportunity and visible host admission, pre-display only the first viewport (at most eight cards / 64 caption/icon controls) and prefetch their exact existing 88/40 pt cache keys serially. Native scratch rasters are capped to 256 pixels per axis and immediately released; no window mounting, NSVisualEffectView capture, fullscreen bitmap, persistent pixels, action binding or profile write. Slow icon work times out and skips rather than delaying navigation. A distinct bounds/scale/appearance key avoids repeating display work while preserving the existing full-entry/language pool acceptance.

Prepare existing grid chrome layer backings at the same idle boundary, not by changing visibility or transform. Keep the ordinary cold fallback for early input. Parent scroll begins cancel in-flight optional display work; readiness after terminal input retries if needed. Invalidations/disable/teardown release the work. The helper belongs to the owner and must not own the pager or become a second icon cache. Warm-up uses one task slot, no per-frame writes/loops.

Apple documents cacheDisplay(in:to:) as bitmap caching, not a WindowServer warm-up guarantee: https://developer.apple.com/documentation/appkit/nsview/cachedisplay(in:to:). Therefore this stage claims only bounded CPU-side pre-display/cache work unless physical/compositor evidence later supports more. Within-window blur remains native and is not pre-captured/replaced.

## Review-driven safety delta: shared loader admission
Independent R5 source review found that canceling an optional consumer does not remove its existing semaphore waiter; abandoned work could later run before a live icon. Permit waiters must be cancellation-aware, with no tombstone set or retained canceled continuations; cancellation after grant must release its permit exactly once and skip loader admission. Recheck cancellation after a non-cooperative loader returns, before capping/caching. Preserve same-key merging/surviving consumers and existing source/loadID publication guards. This is a narrow shared-pipeline implementation correction, not a public API or cache-schema change. Add an internal numeric pending-waiter seam for deterministic tests, plus held-single-permit queued-cancel/live and repeated-cancel tests. Retain earlier SOURCE FAIL and rerun full pipeline/UI suites before delivery.

Detached pool cards also need explicit destination appearance during optional pre-display because they have no parent; restore normal inherited appearance on live binding. No material snapshot or other behavior expansion is authorized.
