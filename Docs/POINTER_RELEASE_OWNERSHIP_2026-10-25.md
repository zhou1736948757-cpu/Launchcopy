# Pointer release ownership under callback reentrancy

## Problem and evidence boundary
The previous pointer audit identified a possible old-release/new-press ownership hazard. The human's intermittent first-drag failure remains causally unresolved: a later first-attempt success occurred on the same binary. Do not reinterpret either aggregate capture as a reentrancy trace.

The current AppKit window clears its captured cell after calling the cell's release handler. The drag coordinator's ordinary clicked event likewise dispatches an external callback before clearing old presentation state; its fallback/blank routes already use cleanup-before-callback. Separate deterministic production-seam regressions now reproduce both defects (2 tests, 7 failed assertions). This proves conditional callback-reentrancy failures, not the human's physical cause or a trace of actual native nested delivery.

## Bounded requirements and non-goals
- Exercise the actual window, cell and coordinator with deterministic unshown synthetic fixtures. First distinguish window capture loss from coordinator cleanup, including a new press on the same cell; comparing cell identity alone is insufficient.
- B1 manual capture and ordinary coordinator click completion must not clear a newer admitted press created during their callbacks. Each accepted click must route to its original intended cell exactly once; a newer press retains suppression/capture until its own release or cancellation.
- Retire the old B1 capture before target release dispatch. For ordinary coordinator clicks, retain the target/binding, complete old presentation cleanup, then dispatch only if cleanup observers have not actually cancelled an admitted session, torn down the owner, or replaced that binding. A new press alone is not stale-click cancellation. Existing idle cancellation remains a no-op, not retroactive revocation of a completed click. Preserve existing per-route counters and fallback/blank behavior.
- Preserve icon-only hit testing, native window chrome, title/Library/IME admission, normal cancellation/teardown, protected work, drag thresholds, paging physics and persistence. No new gesture feature or native event synthesis in the user session.
- Do not change commit/reorder presentation ordering without separate evidence; it supports previously accepted no-flash behavior. Do not expand a click regression into speculative drag or callback architecture work.
- Native folder tracking flags and committed-drop callback ordering are outside this demonstrated click/capture repair; do not claim universal reentrancy safety for those distinct routes.
- A repair requires a failing regression through a production seam, minimal ownership correction and explicit reentrant/cancel/teardown negative controls. If those conditions cannot be met, retain the hypothesis without changing product behavior.

## Architecture and delivery
SwiftPM/AppKit: `LauncherWindowInput.swift` owns B1 capture; `DragUISessionCoordinator` owns pointer arbitration and external click callbacks. Main performs tightly coupled reproduction/implementation locally; independent bounded source review follows a stable freeze while Main alone runs serial verification. No legacy workflow/watchdog; maximum three active including Main.

Targeted/full nonzero tests, Debug/Release/strict unique-candidate packaging, source review, native presentation and physical input remain separate gates. Preserve all dirty work, the latest isolated arrangement/preferences and old neutral diagnostics; normal Quit only after unlock. No real-app launches/drag/organization, force-exit, reference-source/asset access, signing/install/publication or Git mutation. Keep the existing reviewed StatusFooterR2 artifact available while any new source is investigated. Record outcomes and limitations in the stage, plan, project memory and delivery index. This investigation does not itself close the full parity goal.
