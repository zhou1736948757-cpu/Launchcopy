# Library transition continuity — independent source review r2

Date: 2026-10-20
Verdict: **FINDINGS — the direct R1 close path is repaired; one remaining P2 lifecycle notification path prevents SOURCE_ACCEPT. One nonblocking P3 test-fixture finding.**

This is a bounded source follow-up to `LIBRARY_TRANSITION_CONTINUITY-r1.md`. The earlier finding and evidence remain unchanged. Review r2 uses the subsequently supplied **r3 input packet**, which supersedes the r2 packet after the quit-fixture correction.

## Frozen scope and method

- Repository: `/Users/mac/Projects/Launch_Copy/PagingPrototype`; Swift/AppKit same-window Library composition.
- Specification: `Docs/LIBRARY_TRANSITION_CONTINUITY_SPEC.md`; stage summary: `Workflow/stage-summaries/2026-10-20-library-transition-continuity.md`.
- Final input: `.build/verification/20261020/library-transition/review-inputs-r3.json`.
- Packet SHA-256: `2f04932331d6e1ac83946ee778d82764771d2af880ec0dd9d1ec196dde60c66f`.
- All 13 file hashes matched at inspection and immediately before report creation.
- Against r1's eight Main inputs and four supplementary inputs, only `AppLibraryOwnerController.swift` and `LeadingLibraryPreviewTests.swift` changed; the additional r3 scope is `AppLibraryLaunchAndQuitTests.swift`. The former test file reconstructs exactly to its r1 hash when the two appended restore-callback cases are removed.
- Read source and preserved logs only. No builds, tests, UI, signals, Git mutations, preference changes, screenshots, reference-product source access, or implementation edits. Main retains serial verification ownership.

## R1 follow-up: direct close path repaired

`AppLibraryOwnerController.swift:25,135–138,256–286` now:

1. Sets `isClosing` before any close callback and clears it with `defer` after the entire cleanup, including final notifications.
2. Denies entry during that interval through `canPreviewEntry`.
3. Captures `outgoing` before callbacks; responder release, reset and removal use that identity rather than a potentially replaced `self.view`.
4. Preserves early action/session revocation and destination restoration before detachment/reveal.
5. Detaches the captured outgoing subtree even when restoration tears down the owner, then stops on `!isActive`.
6. Rechecks activity after the visibility callback and before the final presentation notification.

The appended tests at `LeadingLibraryPreviewTests.swift:522–564` meaningfully exercise nested-entry rejection, consistent closed/view/grid state, subsequent successful entry, and teardown from restoration without close-tail reveal/notifications. The retained `reentrancy-red.log` records two XCTest cases and eight assertions failing before the repair, including the orphaned outgoing view, extra hide/reveal, inability to enter next, and two post-teardown notifications. Main reports the repaired two cases GREEN; this reviewer did not execute them or treat that result as a physical performance verdict.

The original direct-`back()` R1 counterexample is addressed in source. The remaining outer-caller issue is separate below.

## Finding R2 — [P2] Preference-driven close still sends notifications after restoration tears down the owner

**Location:** `Sources/PagingPrototypeApp/AppLibraryOwnerController.swift:404–422`, especially the unconditional deferred callbacks at **line 408** and `close(restoring: true)` at **line 420**.

**Evidence / concrete source path:**

1. Start a loaded, enabled committed Library session with a restoration callback that synchronously invokes `owner.teardown()`, as in the new regression at lines 551–554.
2. Submit a disabled preference and let its successful save receipt commit. `AppLibraryPreferencesCoordinator.swift:67–76` updates committed preferences and synchronously calls the owner's `preferencesChanged`.
3. `preferencesChanged` passes its entry-only activity guard, installs an unconditional `defer { onReadinessChange(); onPresentationChange?() }`, then invokes `close(restoring: true)` because the Library is open and now disabled.
4. The restoration callback tears down the owner. The repaired close correctly detaches `outgoing` and returns at its activity guard without its own reveal or terminal callbacks.
5. Control returns to `preferencesChanged`; its defer still invokes both callbacks after owner teardown. Clearing preference/projection observers during teardown does not clear those owner callbacks or remove the already-installed defer.

**Impact:** the repaired no-notification-after-death contract holds for direct Back but not for the existing feature-disable entry point. Readiness and semantic presentation consumers can still act on a torn-down owner. This is a source-established callback-seam failure, not an executed reproduction here; the current production restoration callback triggering teardown remains unproven, as in r1. The unconditional defer predates this repair and is relevant because it encloses the same close path.

**Likely root cause:** lifecycle checks were added inside `close`, while an outer notification scope outlives that close and checks activity only on entry.

**Recommended bounded solution:** make the deferred preference notifications conditional on current activity, including a second activity check between readiness and presentation because readiness itself may synchronously tear down the owner. Stop remaining post-close preference presentation work when close invalidates the owner. Retain ordinary active-owner preference and close notifications.

**Regression expectation:** repeat the teardown-from-restore case with a successful disabled-preference receipt as the close trigger, rather than `back()`. Assert no owner notifications after teardown, no reveal, detached outgoing subtree, and denied subsequent entry. Preserve the existing normal preference-disable notification test at `LeadingLibraryPreviewTests.swift:461–485`. Use the injected store; no formal preferences are needed.

**Affected scope / regression risks:** owner preference-change notification epilogue and regression coverage only. Avoid suppressing legitimate active-owner preference/save-completion notifications. Confidence: high in the source-level sequence; no claim of established native user-event triggering or measured flicker causality.

## Finding T1 — [P3, nonblocking] Both new restore callbacks retain their owner through the fixture teardown

**Location:** `Tests/PagingUITests/LeadingLibraryPreviewTests.swift:528–531,551–554`; fixture cleanup at lines 97–100.

Each assigned `owner.restoreGrid` closure captures `owner` strongly. The owner strongly stores this closure, forming `owner → restoreGrid closure → owner`. Neither `Fixture.teardown` nor `AppLibraryOwnerController.teardown` clears `restoreGrid`. The tests therefore leave their owner, preference/projection controllers and captured callback state retained even after view/window cleanup. This is confined to the test fixtures and does not undermine their state assertions or the production close repair.

Use weak owner capture with an explicit test failure if unexpectedly absent, or clear the injected callback in fixture cleanup. Keep the callback behavior and assertions intact. Confidence: high from stored-closure ownership; no allocation instrumentation was run.

## Additional r3 quit-fixture correction: no finding

`Tests/PagingUITests/AppLibraryLaunchAndQuitTests.swift:232–241` now waits for a request built with the **current** `owner.actionGeneration` to resolve, then captures and uses that generation without another explicit suspension before the category action.

This matches the fixture's actual asynchronous attach/projection lifecycle. The previously captured request could become stale while waiting, and `resolve` correctly rejects stale action generations. The correction neither changes product startup nor bypasses readiness: it still calls the real `resolve`, including projection/catalog identity and URL checks. The category-warning count, quit result, single-choice, reply ordering and failed-write quit-protection assertions remain at lines 242–256. The existing bounded wait still fails on timeout.

The retained `focused-final-pre-fixture-correction.log` records 237 tests with five assertions failing in that test; earlier passes cannot disprove this scheduling race. Those logs remain historical. No final full-suite/build result was generated or certified by this review.

## Unchanged reviewed slice and acceptance limits

The other ten original inputs match r1, including root/menu routing, unchanged-query restoration with pending catalog commits, navigator/presentation CA scopes, result-icon mode and asynchronous admission, material color/visibility caching, gallery regression coverage, and responder-isolation expectations. Their prior source assessment carries forward without new findings; no unstable worker slice was inspected.

Repair R2 and address or explicitly track the nonblocking test callback ownership issue, then freeze any changed inputs for follow-up. Preserve r1 and this report. Historical focused/full results are not substituted for Main's final frozen serial verification. SOURCE_ACCEPT remains withheld for the lifecycle issue; this report makes no physical performance PASS, native UI acceptance, or whole-app certification claim.
