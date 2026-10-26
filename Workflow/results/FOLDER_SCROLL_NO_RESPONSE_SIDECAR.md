# Folder Scroll No Response — Inner Controller/View Source Audit

Date: 2026-10-17
Role: bounded sidecar source audit
Status: source audit complete; runtime root cause not established

## Scope and evidence limits

Read `AGENTS.md`, `/Users/mac/.codex/RTK.md`, the current stage summary, `FolderPagingController`, `FolderOverlayView`, their named tests, and supporting input/core/layout source. The project is a macOS AppKit/SwiftPM application: `PagingCore` owns paging physics, `PagingUI` owns folder input/timers, `AppGridUI` owns folder rendering, and the application owner supplies admission, layout, and committed-page callbacks.

This report concerns the current working-tree source inspected during this audit. It does not establish equivalence with the running adbd845c candidate. Concurrent Main edits may change line numbers or add coverage after inspection. No build, test, app/code execution, UI interaction, git/process/OS/install/sign operation, or reference repository/asset access was performed. Shell commands were RTK-prefixed file reads/searches. The only authored file is this report. No implementation or other dirty files were changed. The Chief ceremony was waived by the user; no additional agents were dispatched.

Main's AppDelegate admission/lifecycle audit was deliberately excluded. Existing unit-test results were not rerun or independently certified.

## Principal conclusion

There is no source-proven unconditional inner-controller failure for an admitted, stable-layout `.began` → horizontal `.changed` sequence. The controller applies each event immediately, and finger tracking needs no timer (`Sources/PagingUI/FolderPagingController.swift:92-117`, `161-170`, `261-265`). A timer failure alone cannot explain the complete absence of ordinary non-Reduce-Motion finger-following movement.

The important missed cases are cancellation interleaved with a live stream, synchronous lifecycle changes during callbacks/layout, and input streams unlike the tests' idealized phase sequence. These are concrete source paths and coverage gaps; their occurrence in the native candidate remains a hypothesis.

## Findings and regression candidates

### 1. A refresh/cancellation after began silently blackholes the remainder of that gesture

**Source evidence (high confidence):**

- `Sources/AppGridUI/FolderOverlayView.swift:595-599`: only the exact entry/page/motion/catalog-revision/capacity combination is idempotent. Any other refresh calls `cancelTrackpadPaging()` before rebinding. A catalog-revision-only change is sufficient, even with identical folder membership and geometry.
- `Sources/AppGridUI/FolderOverlayView.swift:254-263`: any unequal layout snapshot cancels. `FolderLayoutSnapshot` uses synthesized equality over every frame and layout field (`Sources/AppGridUI/FolderLayoutPolicy.swift:5-17`). Even a chrome/frame-only difference cancels; a real difference need not change the paging width/capacity.
- `Sources/AppGridUI/FolderOverlayView.swift:1299-1303`: a bounds change cancels during layout when a swipe viewport exists.
- `Sources/PagingUI/FolderPagingController.swift:122-129` and `Sources/PagingCore/PagingCore.swift:413-433`: cancellation clears the session and restores the committed offset without committing.
- `Sources/PagingUI/ScrollInputMapper.swift:84-90` forwards later changed events without a new began. `Sources/PagingCore/PagingCore.swift:483-486` rejects them when no tracking session exists. Orphan momentum is likewise rejected (`495-507`).

**Why existing tests can pass:** the view fixture configures/layouts once, then only configures again from a successful commit (`Tests/AppGridUITests/FolderTrackpadPresentationTests.swift:10-23`). Its resize test explicitly cancels after movement and sends a fresh began before the next experiment (`75-95`). Repeated controller configuration is tested (`Tests/PagingUITests/FolderPagingControllerTests.swift:242-256`), but that bypasses the view's larger refresh identity and rendering lifecycle. The controller orphan test intentionally asserts no recovery from orphan changed/momentum (`355-369`). Those tests prove safe cancellation, not that a production refresh preserves a gesture or occurs only at an intentional boundary.

**Suggested regressions:**

1. `testIdenticalConfigureAndLayoutDuringTrackpadActivityPreserveSession`: 35 members/15 slots; began, changed; synchronously reapply the same snapshot/configuration; another changed must increase the offset, retain the core/session, and leave a visible preview. Install the refresh through `onTrackpadPagingActivity` as well as between events.
2. `testRevisionRefreshCancelsOnlyCurrentStreamAndNextBeganRecovers`: began/changed; configure identical members/page with a different catalog revision; changed/ended/momentum tail must not move or commit; the next complete gesture must work. Assert activity notifications, hidden-cell restoration, and zero stale hosts.
3. Repeat the latter for an actual layout change during tracking, release wait, and settling. The intended cancellation policy should remain explicit; do not fix this by automatically resurrecting every orphan changed event.

**Runtime relevance:** a refresh repeated just after every began can yield the reported sustained no-response symptom. No such repeated caller behavior was established in this scope. Main should correlate the first activation, cancellation, and next changed event before selecting this as root cause.

### 2. Admission is checked before reentrant layout, and is not rechecked afterward

**Source evidence (high confidence about the ordering; runtime occurrence unproven):**

- `Sources/AppGridUI/FolderOverlayView.swift:1005-1014` checks lifecycle/admission first, then invokes `layoutSubtreeIfNeeded()`.
- Layout can call `cancelTrackpadPaging()` (`1301`), which synchronously reaches controller callbacks (`Sources/PagingUI/FolderPagingController.swift:227-255`). The view's activity callback forwards to application code (`Sources/AppGridUI/FolderOverlayView.swift:141-145`).
- Control then continues to configure/handle the same input without repeating the lifecycle/admission checks (`1015-1024`).

**Concrete test arrangement:** begin and move enough to create a preview; change overlay bounds and mark layout needed; set `onTrackpadPagingActivity` so its false notification calls `setPanelTransitionActive(true)`; deliver a new began through `handleTrackpadScroll`. The initial guard can pass, layout can cancel and activate the transition, and the original began can then start the core despite the now-blocked view. This follows source ordering but was not executed here. The test should assert no renewed activity, no hosts, and a restored committed presentation after the callback makes the view ineligible. Equivalent variants are visual-only or presentation-unavailable changes during that callback.

**Why existing tests can pass:** presentation tests exercise each blocking state before the next call; they do not install `onTrackpadPagingActivity`. Controller reentrancy tests cover cancellation from activity/offset callbacks (`Tests/PagingUITests/FolderPagingControllerTests.swift:426-455`), but contain no view/layout/admission state to revalidate.

**Regression priority:** worthwhile inner-view hardening, but not evidence of the reported always-unresponsive gesture. This path can also restart activity unexpectedly rather than suppress it.

### 3. Input variants can produce no page change while the tested idealized stream works

**A. Lost/rejected began:** the mapper ignores mayBegin/stationary (`Sources/PagingUI/ScrollInputMapper.swift:98-99`), and changed cannot create a core session (`Sources/PagingCore/PagingCore.swift:483-486`). Thus an initial began rejected during a transition or removed by a cancellation causes the whole changed tail to be inert. Existing controller orphan coverage explicitly accepts that behavior. Add a view-level blocked-began → unblocked-changed → fresh-began recovery test; record the actual native phase stream before treating a changed-only stream as valid device behavior.

**B. Nonzero began / combined phase flags:** the mapper's began branch returns only `gestureBegan`, discarding that event's delta; the began branch also wins over changed when both flags are present (`Sources/PagingUI/ScrollInputMapper.swift:79-90`). The view test helper always sends zero began delta (`Tests/AppGridUITests/FolderTrackpadPresentationTests.swift:26-28`, `37-38`), and the mapper began test also uses zero (`Tests/PagingUITests/ScrollInputMapperTests.swift:35`). Add a documented test for the supported policy with nonzero began and combined flags. This alone explains a short impulse only if no effective changed events follow; no native evidence of that stream was obtained.

**C. Phase-less small-delta bursts:** no-phase input uses `legacyScroll` (`Sources/PagingUI/ScrollInputMapper.swift:102-107`, controller `191-193`). `PagingCore.legacyScrollDelta` immediately finishes a one-event gesture; while settling, further legacy deltas are rejected (`Sources/PagingCore/PagingCore.swift:198-206`). A small initial impulse starts with zero elapsed sample time and does not gain velocity from the discarded burst (`Sources/PagingCore/GestureSession.swift:63-72`, `136-140`), so it can repeatedly bounce without turning a page. The existing controller legacy test uses one large -500 delta and compares to the same core implementation (`Tests/PagingUITests/FolderPagingControllerTests.swift:384-398`); it does not establish useful behavior for repeated small phase-less deltas. Add a bounded burst test as a characterization, not an assumption that physical trackpad events are phase-less. This is particularly relevant to interpreting injected scroll observations.

**D. Direction and mixed axes:** the controller tests cover both direction preferences (`68-77`) and vertical rejection (`79-88`); the view fixture fixes inversion to true and momentum to empty. Add a view-level direction matrix, mostly-horizontal multi-event drags, cancellation, and momentum follow-through. Per-event horizontal dominance can drop diagonal samples (`Sources/PagingUI/ScrollInputMapper.swift:84-90`); that is an existing policy, not proof of the runtime defect.

### 4. A narrow geometry blind spot exists before the first translated frame and under Reduce Motion

`FolderOverlayView.layout()` detects bounds invalidation only when `swipeViewport != nil` (`1301`). The viewport is created lazily on the first offset different from the committed page, and never under Reduce Motion (`1107-1111`). While the pager is active, `handleTrackpadScroll` skips configure (`1018-1021`). A bare bounds change after began but before movement, or during Reduce Motion, can therefore leave the active core's width stale unless the owner explicitly applies a changed layout snapshot/cancels. In the adaptive production path `applyFolderLayout` already provides that cancellation (`254-263`), so this is conditional, not a confirmed production failure.

The existing resize test starts with a non-Reduce-Motion translated preview (`Tests/AppGridUITests/FolderTrackpadPresentationTests.swift:75-83`); it does not cover these cases. Suggested tests: resize before the first changed, Reduce Motion resize mid-gesture, and same-bounds relayout during normal tracking. Assert the intended cancel/continue policy, coherent width, and next-gesture recovery.

### 5. AX and deterministic-frame assertions do not establish native follow-through

- Transient page hosts explicitly return no accessibility children and no hit target (`Sources/AppGridUI/FolderOverlayView.swift:48-52`). Committed-page indicator text is updated separately (`1168-1180`). An AX snapshot can stay identical while the preview moves. Unchanged AX during changed events is therefore inconclusive; unchanged committed page after complete release is more meaningful but still does not identify why input failed.
- The view fixture disables automatic frames (`Tests/AppGridUITests/FolderTrackpadPresentationTests.swift:18`) and manually advances settling (`48-52`). Controller fixtures also disable frames (`Tests/PagingUITests/FolderPagingControllerTests.swift:574-579`). Timer-specific tests inspect timer existence/invalidation and use manual advancement (`500-543`); they do not verify actual main-run-loop delivery. A native release/settle test is still needed after Main demonstrates admitted tracking.
- Stale preview icon callbacks already have viewport identity, visual generation, delivered-key/generation, token, teardown, and visual-only guards (`Sources/AppGridUI/FolderOverlayView.swift:1097-1101`); completion invalidates the generation and removes all hosts (`1122-1132`). No source-proven stale-icon mechanism explaining total lack of finger movement was found. A retained-cell/late-completion regression would strengthen stale rendering coverage but is lower priority than input/cancellation.

## Recommended order for Main

1. Establish whether the real began reaches the inner controller and whether its session survives through the first horizontal changed. Keep this distinct from AX, timer, and commit evidence.
2. Add the production-owner regression that Main's investigation supports, plus the same-snapshot/configuration activity-refresh regression above. Do not infer a rendering fix solely from a passing controller test.
3. If cancellation is implicated, identify the precise refresh/geometry/lifecycle edge; preserve intentional cancellation and reject its stale tail. Verify a fresh gesture recovers.
4. Add the reentrant-layout eligibility regression when touching that boundary. Treat phase-less burst and nonzero-began cases as explicit input-policy characterizations until actual event evidence supports a change.
5. Keep real physical trackpad acceptance separate from button navigation, injected scrolling, and deterministic unit frames.

No implementation recommendation here authorizes physics, ownership, or input-contract changes. No native root-cause or test PASS claim is made.
