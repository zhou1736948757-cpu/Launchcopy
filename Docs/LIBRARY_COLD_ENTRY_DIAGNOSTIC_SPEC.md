# Library cold-entry diagnostic — 2026-10-20

## Problem and evidence boundary
The user confirms the no-outline candidate removes the blue border, but the first real touchpad Library entry still hitches and repeated entries become smooth. Empty detached shell preparation has NOT passed the physical gate. Do not change paging parameters or infer a compositor cause from this symptom alone. Wallpaper was independently observed LOADING; correlation is unproved.

## Scope
Add bounded, privacy-neutral, opt-in timing of actual entry/input/frame, view construction, projection delivery, gallery/card layout and icon work. Compare cold and warm sessions. No behavior, physics, default preference, schema, artwork, or formal data changes. No blanket new caching or prewarming until measured.

## Diagnostic contract
Only an explicitly marked candidate bundle (`LaunchcopyLibraryEntryProfiling` Boolean true) AND a successfully resolved isolated UITestProfile can enable the recorder. Ordinary production and tests remain nil by default. Fixed enum event names and integer monotonic timestamps/durations/counts only; no strings derived from applications, identifiers, queries, URLs, paths, wallpaper pixels, or user text. At most 8192 samples, with explicit drop count, no per-event file writes. Export a bounded JSON snapshot only on normal owned test-app termination, inside that profile. Failure must not affect application shutdown or fall back to formal storage. No continuous system profiler or screenshots saved.

## Architecture / ownership
Main owns native integration, hooks and serial builds. One disjoint worker owns recorder and recorder tests; one read-only sidecar inspects wallpaper lifecycle. Max three including Main. Recorder is MainActor-owned; monotonic clock is injectable. Work remains within current dirty checkout. All prior failures and acceptance records stay historical.

## Acceptance
Tests verify bounded capacity, drops, exact durations, fixed payload schema, disabled integration and no privacy-bearing fields. Debug/Release and targeted/full regressions must pass before any new candidate. Independent source review remains separate from native and physical acceptance. Native menu/button timing is not proof of the real touchpad hitch or GPU/compositor timing. If actual intervals remain unexplained, say so and request one bounded physical capture rather than claiming fixed.

## Delivery / maintenance
Stage summary and project PLAN/MEMORY must record feedback, hooks, exact artifact identity, diagnostic limitations and next action. Do not reuse old native results for changed binaries. Probe remains opt-in and must never retain catalog/view objects or own navigation. No install/sign/commit/reset/clean/signals or prohibited source access.

## Native capture protocol
1. Package a new isolated candidate and explicitly add Boolean `LaunchcopyLibraryEntryProfiling=true` to that candidate Info.plist only; record executable/plist hashes. Formal/default packages never receive this marker.
2. Verify synthetic fixture seed integrity, normally quit only the prior owned test instance, and launch through native CUA. Enable Library on the own profile through native Settings, leaving history OFF.
3. Run cold and repeated native View-menu Library entries/ordinary Back as a source-work timing control. Quit normally, verify export/privacy schema/drop count; do not equate that control to the user's physical gesture.
4. Reopen the identical candidate/profile without entering Library. Request one real-touchpad first entry and two round trips. On reply, normal Quit exports that process's bounded capture; analyze cold/warm source wall durations and observed callback gaps. Relative DispatchTime timestamps belong solely to this capture, not the existing raw-monotonic profiler clock.
5. Empty/missing/truncated captures, generated horizontal no-op, solid-wallpaper fallback, and compositor/presentation timings remain explicit limits. Never add inclusive nested span durations together as CPU time. A short app-owned span cannot exclude OS/GPU/input-delivery waits.

## Review correction
Independent review required a separate `cardLayout` span because parent gallery layout does not necessarily enclose later native child layout. Added that fixed tag and an unshown-subtree test without changing production layout scheduling.

## Measured optimization addendum — supersedes empty-shell-only preparation
Native diagnostic capture3559 samples/0drops contains three nonempty galleryApply spans of85.2801,81.4016,52.1685ms, plus a53.5742ms viewApply inside an actual parent-navigation window. This establishes costly application-owned gallery rebuilding, not complete visual-stutter causality. Capture was not a pure menu control: parent input events appeared during operator actions; exact operator provenance is unconfirmed.

Allow one bounded set of NEVER-PRESENTED detached category cards to be prepared while Library is closed and normal transition admission is idle. Obtain a separate immutable background projection (no session/actions/icons/history/scanner/store); prepare at most one category per MainActor yield. Cards have no gallery callbacks, images beyond the existing generic placeholder, windows, or accessibility exposure. A fresh normal session projection still controls all actions; only consume the pool when complete entries and rendered language strictly match. Never reuse any previously presented card/button object (old-generation control revocation contract stays intact). Loading may retain the never-presented pool; reset/disable/source invalidation/teardown discard it. No snapshot or action-generation shortcut. Immediate entry before preparation completion uses the existing cold fallback.

Tests must cover matching consumption once, mismatch/language rejection, no icon/action/host admission while preparing, cancellation across yielded preparation, old-control revocation unchanged, and source/disable/teardown invalidation. Re-run whole suite/build/package and source review on the final changed packet. Reduced source construction cost is separate from physical acceptance and GPU material first use.

## Final review refinements
- Idle preparation has a separate `canPrepare` gate excluding parent hold/transition, rather than weakening navigation's shared `canTransition`. Zero-delta hold release provides an explicit readiness retry when no pager commits.
- Source invalidation cancels preparation and discards all source-bearing cards but retains the already-empty native shell, preserving its established reuse contract.
- Numeric `preparedCardsReady` and `preparedCardsConsumed` events prove preparation/strict single-use transfer in native captures. Optional `viewFocus` spans distinguish native field-editor transfer from card rebuilding. These add fixed event tags only, not new dynamic payload fields.
