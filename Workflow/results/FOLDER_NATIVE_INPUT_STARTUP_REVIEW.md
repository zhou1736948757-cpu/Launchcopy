# Folder Native Input Startup Review

Date: 2026-10-16
Scope: independent, bounded source audit of startup input wiring and adjacent overlay/window lifecycle routes.
Disposition: startup causal chain confirmed from source; no native acceptance claim.

## Authority and evidence limits

- Main owns AppDelegate and regression-test repair. This review changes only this report.
- No production edits, test edits, test execution, build, UI interaction, installs, commits, process control, reference repositories, historical evidence artifacts, or global memory were used.
- All audit shell commands after loading the mandated RTK instructions used RTK. The initial read of `/Users/mac/.codex/RTK.md` itself was the bootstrap exception.
- The working tree was already extensively dirty and is being edited concurrently by Main. Line numbers below identify observed reads, not an immutable candidate or final repair.
- The reported real two-finger failure on `folder-interaction-r2` and 2788 green tests are task-provided facts, not independently reproduced or validated here. No packaged binary was inspected. This audit establishes a source defect that explains that symptom, not exclusive causation in a native run.

## Domain and architecture

This is a macOS 14+ Swift Package/AppKit launcher. `PagingCore` owns paging logic, `PagingUI` owns native paging input and surfaces, `AppGridUI` owns folder overlays and grids, and `PagingPrototypeApp/AppDelegate` composes their owners and the native window. A component-level green suite cannot establish that application lifecycle order installed the window route.

## Confirmed startup chain

The first source reads independently confirmed the chain described in the task:

1. `applicationDidFinishLaunching` creates/stores the surface and synchronously calls `installContentAssembly(surface:)` inside `MainActor.assumeIsolated` (AppDelegate.swift approximately 505).
2. Content assembly synchronously calls `installFolderWiring` (approximately 880), creating `folderOpenState` and `folderOverlay`.
3. Folder wiring installs `window.onFolderScroll` only inside `if let window = window as? QuitOnBlankClickWindow` (initial read 970-972). With a fresh AppDelegate, its stored window has not yet been assigned. This branch is skipped; it is not deferred or retried by that code.
4. The actual `QuitOnBlankClickWindow` is created later (approximately 571). The later window setup initially installed only `folderOpenStateProvider` (approximately 635); `self.window = window` followed at approximately 665. Neither initial later step installed the scroll callback.
5. `QuitOnBlankClickWindow.sendEvent` checks an open folder before the library/general responder route. For `.scrollWheel` with open state, it optionally invokes `onFolderScroll` and unconditionally returns (initial read approximately 3934-3938). A nil callback therefore consumes the event without reaching either `FolderOverlayView.scrollWheel` or `super.sendEvent`.
6. The overlay's actual scroll handler owns folder input and delegates to its local trackpad pager. It cannot compensate for an event already consumed by the window (FolderOverlayView.swift 923-956).

This explains a functioning component pager and green synthetic tests coexisting with no real folder movement. Pointer hit testing inside the overlay cannot recover an event discarded before native responder dispatch.

## Why the old fixture missed it

The initially inspected `AppDelegateBoundedRegressionTests.Fixture.init` assigned `owner.window = window` at line 47 before calling `owner.installFolderWiring` at line 53. The conditional production callback installation therefore succeeded in that fixture, despite being skipped during actual content-before-window startup. Testing through `window.sendEvent` is necessary but insufficient if the fixture reverses the dependency order.

Concurrent Main edits were visible during the audit: a `contentBeforeWindow` fixture branch, a second startup-order test, and `installFolderWindowInput(on:)` appeared. In the last bounded read that new helper still contained only the state-provider assignment, while the old conditional scroll assignment remained in folder wiring. These are intermediate edits, not a final repair verdict. The test additions were inspected as source only and were not executed.

## Required lifecycle regressions

### R1 — Production startup order must install the usable native folder route

Assemble folder content while `owner.window == nil`, then construct/attach the actual window and invoke the same window-input setup used by `applicationDidFinishLaunching`. Do not patch either callback directly in the fixture. Verify both provider and scroll callback are installed on that exact window. Open a multi-page folder with a genuinely pageable outer surface; deliver a phased scroll sequence through `window.sendEvent`. Assert observable inner-pager movement, then completion/commit for an adequate sequence, while the outer visual offset, committed page, and idle state remain unchanged. Also exercise blocked folder input: it remains consumed, cancels/does not advance the inner pager, and never moves the outer surface. Retain the inverse window-before-content case to cover both orders.

The new concurrent test source already checks both order branches, inner movement, outer immobility, and blocked input. This audit has not verified test execution or completion/commit coverage.

### R2 — Installed routing must follow the current owner, including replacement boundaries

A window route installed before content exists must resolve the owner's current state and current interactive overlay when each event arrives. For a focused lifecycle regression, retain the old overlay strongly, replace the owner-side folder state/overlay (or use an explicitly supported reassembly seam), and verify a subsequent window event reaches only the new overlay. Keeping the old object alive is essential: weak capture of a stale instance otherwise looks like a harmless nil no-op. Rebinding to a new native window must install both routes on that exact window; reinstalling them should replace closures without duplicating delivery. Closing or tearing down the folder must leave the retired overlay inactive and prevent commits from it.

This is a bounded regression requirement for routing ownership, not a claim that normal production currently recreates folder overlays or windows. A repair that captures `[weak self]` and resolves `self?.folderOverlay` at delivery avoids the stale local-overlay capture class while also supporting window-before-content installation.

## Adjacent lifecycle inspection

- Normal close/open and folder layout refresh reuse `self.folderOverlay`; `refreshFolderOverlay` configures/remounts the same object (approximately 1760-1802 in an inspected read). Search found production overlay assignment in folder installation and clearing in final teardown, rather than a separate routine replacement route. No independently confirmed normal reopen stale-target defect was found.
- The pre-repair callback captures `[weak overlay]`, whereas the state provider resolves `[weak self]`. If either ownership graph changes without rebinding the window, this mismatch can route to a retained old overlay or consume into nil. This is the specific latent replacement risk captured by R2; it is not established as the reported native failure.
- `FolderOverlayView.viewWillMove(toWindow: nil)` cancels trackpad paging. Its input guard rejects torn-down, visual-only, collapsed, unavailable, title-editing, dragging, and externally blocked states (approximately 917-940). The pointer-exit visual is generation-gated, and transition cancellation cancels the interactive pager. Those protections reduce stale animation/input activity; they do not repair a missing or stale window callback.
- `LauncherWindowController.attach` retains the supplied window, and `ensureWindow` reuses it. Normal hide does not destroy it. Its fallback creates a plain `NSWindow` only when no window is attached; the observed AppDelegate startup explicitly attaches the real `QuitOnBlankClickWindow` before showing it. No second current production window-replacement failure was established.
- Final AppDelegate teardown tears down/removes the overlay and clears both folder state and overlay. A state provider resolving the current owner therefore stops claiming folder ownership. No test or native late-event behavior was exercised here.

## Handoff

Main should finish and verify the paired window-route installation at the actual window-creation boundary, keep lifecycle ordering authentic in the fixture, and avoid treating the newly introduced helper's existence alone as proof of repair. Runtime/user acceptance of real two-finger paging remains a separate gate. This report does not certify the candidate, tests, or native UX as passing.


## 2026-10-16 bounded repair re-review (supersedes the intermediate-edit handoff)

Conclusion: no blocking source finding in the inspected startup-order repair. The original conditional-install defect and the stale local-overlay capture risk are addressed in the current source. This is a bounded source conclusion, not a physical/native PASS, a test-execution certification, or acceptance of dimming behavior.

### Actual implementation inspected

- `AppDelegate.swift:505` still assembles content first; the actual window is constructed at 571. At 635, startup now invokes `installFolderWindowInput(on: window)` on that concrete window, before assigning `self.window` at 663. The helper does not require the stored window to exist.
- `installFolderWindowInput` at 903-910 installs BOTH `folderOpenStateProvider` and `onFolderScroll`. Both weakly capture the owner and resolve current owner properties at invocation. The scroll closure therefore follows replacement content instead of freezing a local overlay reference.
- `installFolderWiring` at 913 onward now assigns `self.folderOverlay` without conditionally touching the window route. The searched production source has one `onFolderScroll` assignment, in the helper.
- `QuitOnBlankClickWindow.sendEvent` at 3942-3945 still consumes all open-folder scroll input. Installing both routes together closes the previously identified nil-handler hole while retaining input isolation.

### Regression source inspected

- Fixture lines 47-62 invoke the exact production helper before folder wiring for window-first setup, or after folder wiring for content-before-window setup. No direct callback patching is used. In the latter branch the fixture's native window object has already been constructed, but `owner.window` is nil during content wiring, faithfully reproducing the dependency that triggered the defect. This is not an execution of the complete application startup method.
- `testWindowRoutesScrollToInnerPagerWithoutMovingOuterPage` (662) and `testContentBeforeWindowRoutesScrollToInnerPagerWithoutMovingOuterPage` (666) share the window-event exercise at 670. It checks a non-nil handler, real inner visual movement, a pageable outer surface with unchanged offset/page/idle state, and cancellation/no outer movement when folder input is blocked. Behavioral movement through `window.sendEvent` also exercises the state provider; a missing provider would bypass that route.
- `testInstalledWindowScrollRouteResolvesReplacementContentOverlay` (726-749) retains the old overlay strongly, reassembles content, opens the replacement, and sends scroll through the original window route without reinstalling it. It checks replacement identity/movement, no old-overlay offset/activity, and no outer offset. This catches a route still bound exclusively to the old overlay or old state. The old overlay is not configured/opened before replacement, so its inactivity assertions are not an independent delivery spy; the replacement's positive movement is the decisive assertion. This limitation is non-blocking for the actual one-target closure under review.
- The window-route exercises stop after began/changed and blocked cancellation; they do not demonstrate an ended/momentum sequence committing via the full owner/window path. Existing component test sources cover release/commit (`FolderPagingControllerTests.testFingerTrackingUsesPageUnitsAndCommitsOnceAfterRelease`, plus `FolderTrackpadPresentationTests.testDraggingMovesOnlyBoundedClippedMemberPresentationThenCommits`). Component coverage and routing coverage are distinct. No complete native gesture acceptance is inferred from either.

### Evidence and scope boundaries

Main reports one red test with two failing assertions (nil handler/no offset), followed by 66 focused tests with zero failures, in `.build/folder-native-input-startup-red.log` and `.build/folder-native-input-focused.log`. These counts and log paths are attributed to Main: this re-review did not read those logs or run tests/builds. No baseline-463 comparison, packaged-candidate inspection, full-suite validation, native event-device validation, or physical/user acceptance was performed here. The repository-wide diff includes prior work and cannot be treated as this repair's scope from Git HEAD alone.

Dimming remains an unresolved user visual choice per the handoff and was outside this re-review. No implementation or test files were edited by this reviewer. Only this report was appended, preserving the historical initial-review conclusions and explicitly superseding its intermediate-edit warning. No additional agents or model overrides were used.


## 2026-10-16 final frozen-source review — authoritative current conclusion

This final section supersedes the initial intermediate-helper warning, the earlier handoff asking Main to finish installing both callbacks, and the preceding re-review's statement that window-route tests stop before release/commit. Those statements describe earlier snapshots and are no longer current findings.

**Bounded conclusion: no remaining blocking source finding in the startup-order repair or the inspected lifecycle regressions. No physical/native PASS is granted.**

### Frozen source identity

Read-only SHA-256 comparison against `.build/verification/20261016/folder-native-input/source-inputs-final.json` found **463 manifest entries, 463 matches, zero missing or mismatching files** at this review. This identifies the inspected source snapshot; it does not certify a built application or test run.

- `Sources/PagingPrototypeApp/AppDelegate.swift`: `55dac97ca278a569ad5ed70a66553648020edcd439dfa9a96e09460a1eb3890c`
- `Tests/PagingUITests/AppDelegateBoundedRegressionTests.swift`: `30fb6fe6789ddf93132960a6457f0e2e754bfc096ab89374e9ef6c03c6c1aaff`

### Final implementation and regression assessment

1. Actual startup assembles content at AppDelegate line 505, constructs the actual window at 571, and calls `installFolderWindowInput(on: window)` at 635. The helper at 903-910 installs BOTH the state provider and scroll callback using weak owner capture and event-time property lookup. It does not depend on `self.window` already being assigned. The old conditional callback installation is absent from folder content wiring; the searched production source has only the helper's scroll-callback assignment. The confirmed production startup hole is closed in source.
2. The fixture calls that SAME helper before content wiring in the window-first branch, or after content wiring in the content-first branch. In the latter case the native test window object is physically created earlier in the fixture, but the owner has no window during folder wiring; this reproduces the causal dependency order rather than literally executing all application startup steps. Both branches test the installed window route instead of directly supplying fixture callbacks.
3. The shared startup-order exercise now sends `.began`, `.changed`, and `.ended` through `window.sendEvent`, advances the injected finish clock and manual pager frames, then asserts owner `innerPage == 1`, overlay `currentInnerPage == 1`, the visible first member from page 1, and no active inner paging. It asserts outer offset/page preservation after completion, and outer idle during tracking. It also retains blocked-route/no-outer-motion assertions. The earlier release/commit coverage gap is therefore closed for this synthetic owner/window path. There is no explicit additional outer-idle assertion after release, but that is not a blocking finding for this window-wiring repair.
4. The replacement regression strongly retains the old overlay, replaces folder content/state, and delivers through the existing window route WITHOUT reinstalling it. Positive movement of the replacement, unchanged old-overlay offset/inactive state, and unchanged outer offset cover the stale exclusively captured target risk. The old overlay's inactivity is not a delivery spy because it was not configured/opened, but the new overlay's positive movement is decisive for the actual single-target production closure. No additional defect is inferred from that test-detail limitation.

### Remaining findings and acceptance boundaries

- No further production repair or blocking regression-source change is requested within this bounded startup-order scope.
- This review used source inspection and read-only manifest hash verification only, with no test/build/application execution or UI operation. The reviewer changed only this report and preserved production/tests and the dirty tree.
- Execution counts are attributed to Main, not independently verified here: red 1 test / 2 assertion failures; initial focused 66 / 0; strengthened owner suite 31 / 0. The earlier full suite 2790 / 0 predates the added completion assertions. A final full-suite rerun for this frozen source is pending per Main's handoff and is not claimed complete here.
- Synthetic native-event construction and manual frame advancement do not establish delivery from a physical two-finger gesture, packaged-candidate identity, momentum-device behavior, or user acceptance. Physical verification remains separate.
- Dimming was not changed by this review and remains a pending user visual choice per Main. No visual acceptance or request to change it is implied by this source conclusion.
