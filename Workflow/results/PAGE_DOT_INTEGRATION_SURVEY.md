# Page Dot Integration Survey
Date: 2026-10-13. Status: READ-ONLY SURVEY COMPLETE; this survey agent had no implementation authority.
The user-approved feature may proceed under Main after Sources code closeout.
Authority: Docs/LAUNCHBETTER_DIRECT_PAGE_NAVIGATION_PROPOSAL.md:3-58, APPROVED_CONTRACT.
Sequence: this feature follows Sources repair/review closeout; this survey does not certify that closeout.
Owned output: Workflow/results/PAGE_DOT_INTEGRATION_SURVEY.md only. Concurrent Main/Reviewer work is outside this survey.

## Finding and scope
There is NO existing explicit nonadjacent target-page API in Core or Surface.
There is NO existing requestLatestTarget, programmatic-settle entry, or presentedOffset accessor.
The useful primitive is private Core.beginSettle; existing public keyboard turns synthesize adjacent gestures.
Surveyed SwiftPM/macOS 14 AppKit architecture: pure Foundation PagingCore -> PagingUI -> application composition, with AppGridUI providing committed content/focus data (Package.swift:9-70).
This is source inspection and a proposed bounded integration, not implementation, testing, runtime acceptance, a Sources audit, or reference-product analysis.
Locations below are repository-relative file:line references from the current shared tree; recheck after Sources closeout because concurrent edits can move lines.

## Existing API inventory (exact signatures)
| Owner and location | Existing API/state | Integration consequence |
| --- | --- | --- |
| Sources/PagingCore/PagingCore.swift:141 | public func handleGesturePhase(_ phase: GesturePhase, delta: Double = 0, timestamp: TimeInterval = 0) -> Bool | Normalized physical input; dots must not synthesize this. |
| PagingCore.swift:164,198 | public func finishGesture(timestamp: TimeInterval? = nil) -> Bool; public func legacyScrollDelta(_ delta: Double, timestamp: TimeInterval) -> Bool | Release targets only committedPage +/- 1 or bounce (:174-192); neither selects an arbitrary page. |
| PagingCore.swift:511 | private func beginSettle(targetPage: Int, fromOffset: Double, reason: SettleReason, createdAt: TimeInterval) | Already accepts arbitrary target internally; keep private and expose a guarded request. |
| PagingCore.swift:214,234 | public func tick(deltaTime: TimeInterval) -> Bool; public func completeSettle(_ transition: TransitionContext) -> Bool | Existing spring advance and explicit late-completion rejection seam. |
| PagingCore.swift:365,384 | public func cancel(); public func teardown() | Cancel snaps to committedPage and invalidates active context; it is unsuitable for replacing one dot request continuously. |
| PagingCore.swift:266,297,350 | public func setPageWidth(_ newWidth: Double); public func setPageCount(_ newCount: Int); public func setReduceMotion(_ enabled: Bool) | Environment paths already have token invalidation/restarts, with important behavior differences below. |
| PagingCore.swift:49-74 | public private(set) state, committedPage, visualOffset, pageCount, transitionToken, activeTransition, currentSession, commitCount, staleRejectionCount, isTearingDown, reduceMotion | Core owns all paging values; consumers cannot set offsets/pages/tokens. |
| Sources/PagingCore/TransitionContext.swift:26-34,41-57 | SettleReason: gestureRelease, resizeRebase, pageCountChange, reduceMotionChange; token: UInt64, targetPage: Int, fromOffset: Double, reason: SettleReason, createdAt: TimeInterval | Context initializer and markCommitted/markStale are internal, not Surface construction APIs. |
| Sources/PagingUI/PagingSurface.swift:266,276,283,290,297 | public func setPageCount(_ count: Int); public func setReduceMotion(_ enabled: Bool); public func refreshReduceMotionFromSystem(); public func cancel(); public func teardown() | Preserve Surface as application control entry; do not bypass its driver/content/lifecycle work. |
| PagingSurface.swift:590,600,623,660 | public func beginInteraction(); public func endInteraction(); public func refreshPresentation(); public func reloadCurrentPresentation() | Existing pin/latest-content-replacement seams; request latest target is a different concern. |
| Sources/PagingUI/KeyboardPageTurner.swift:48 | public func turn(direction: KeyboardPageDirection, timestamp: TimeInterval) -> KeyboardPageTurnResult | Idle only, adjacent, synthetic began/changed/ended/finish (:50-77). Leave this behavior intact. |

## Presentation capture, tokens, and physical ownership
- Current displayed model offset is core.visualOffset (PagingCore.swift:53). Surface applies it synchronously to pageContainer.frame.origin.x = -offset * max(bounds.width, 64) (PagingSurface.swift:534-542); relayout uses the same formula (:823-829).
- There is no independently animated page CALayer or page presentation-layer capture API. A neutral Surface presentedOffset accessor could return core.visualOffset for this renderer; do not borrow AppDelegate.swift:1349-1361, which captures FOLDER opacity/transform.
- In a continuity assertion, read pageContainer.frame.minX / -max(surface.bounds.width, 64), and compare with Core offset. Never round this value for a replacement transition.
- Core.beginSettle increments transitionToken, constructs pending context, resets springVelocity, enters settling and emits onTransitionBegin (PagingCore.swift:511-525).
- completeSettle rejects teardown, nonpending context, or a token different from activeTransition.token (:234-247). Success sets committedPage/visualOffset, increments commitCount, emits onCommit BEFORE idle (:249-258). hasCommitted is recorded in the context; the operative guard checks commitState/token.
- interruptActiveTransition(takeoverOffset: Double) is private (:537): stale + interruption counters/events and transient interrupted state. abandonActiveTransition() is private (:553): stale counter/event without an idle boundary. The latter is sufficient for latest-target replacement without flushing pending content.
- Physical gate: reject state == tracking, including finger-down, released awaiting decision, momentum events, and simulated glide. Core.isAnimating (:82-83) combines settling and glide and cannot distinguish them.
- GestureSession public private(set) released, momentumActive, isMomentumGlide are in Sources/PagingCore/GestureSession.swift:37-42; momentumEnded starts glide while remaining tracking (PagingCore.swift:471-481).
- Do NOT reject merely because currentSession != nil or momentumActive is true: finishGesture/beginSettle/completeSettle do not clear the old session, so those flags can survive ordinary settling/idle. Gate by active state, not stale flags alone.
- Surface needsFinish and pendingFinishSince (PagingSurface.swift:160-161) protect the ended-with-no-next-event window. It clears them privately (:486) and decides after 0.1 seconds (:491-504). A dot must not finish/cancel that physical wait; rejected requests leave it untouched.
- settling is the interruptible ordinary animation state. interrupted/cancelled are synchronous transient states; defensively reject a dot there, rather than reentering callbacks. Accept only idle/settling with valid content and no application owner.

## Smallest neutral extension to propose after closeout
Suggested signatures below are NEW design examples, not existing APIs or approved source changes; keep all existing signatures/defaults:
~~~swift
// PagingCore; UI-independent, no folder/search/control dependencies.
@discardableResult
public func requestLatestTarget(_ targetPage: Int,
                               presentedOffset: Double,
                               timestamp: TimeInterval) -> Bool
// PagingSurface; one application entry and renderer-owned offset capture.
public var presentedOffset: Double { get }
@discardableResult
public func requestPage(_ targetPage: Int, timestamp: TimeInterval) -> Bool
// KeyboardFocusController; pointer operation, sharing existing visual cleanup.
public func clearFocusForPointerNavigation()
~~~
- Core request checks !isTearingDown, pageCount > 0, idle/settling, and finite presentedOffset/timestamp. Clamp target using clampToValidPage(_ page: Int) (PagingCore.swift:674-675).
- Idle request for the same clamped committedPage returns false without token/commit/events. Empty content returns false. One page naturally clamps to 0; dots are hidden for 0/1 page.
- For an accepted settling replacement, save current presentedOffset, invalidate old context via existing stale path, adopt that continuous offset, then beginSettle once to the clamped latest target. Do not call cancel(), finishGesture(), or emit idle between requests.
- Asking for the committed page DURING a different settle must replace the pending target and return to that page; the idle-only no-op rule is essential. Repeating the already-active target may be an idempotent no-op; document and test that minor choice before implementation.
- Surface checks lifecycle/physical pending state, captures its actual presentedOffset, pins interaction when first accepted, and forwards once; existing state callbacks start the frame driver. Do not overwrite an existing pin on rapid replacements. An optional explicit updateAnimationDriver after forwarding is defensive and must not add a new driver.
- Add one provenance case to EXISTING SettleReason, e.g. .programmaticNavigation, for the new request. Do not mislabel it .gestureRelease. There is no need for a new ordinary-settle-vs-momentum reason enum: state/session already express that distinction.
- Adding a public enum case can affect downstream exhaustive switches. No reason switch was found in the inspected Sources/tests; recheck consumers when implementing. No existing reason raw value, constructor default, or physical policy changes are needed.
- Reuse advanceSpring unchanged (PagingCore.swift:621-642), effectiveSettleDuration, and existing position/velocity termination (:214-220). Defaults remain 0.250 seconds, damping 0.85, RM duration 0, momentumGlideFrames 1, radius 1/prewarm 1.5 (PagingParameters.swift:82,86,104,120,124,134).
- The configured duration is a spring decay parameter, not a guaranteed wall-clock completion deadline; a larger jump may take longer to reach existing tolerances. Do not promise distance-independent completion or retune physics in this slice.
- Reduce Motion enters the same token/context/commit path immediately when effective duration <= 0.001 (PagingCore.swift:525-533). Focus must be cleared BEFORE forwarding because onCommit/idle may run synchronously.

## Frame driver, reuse, and focus owners
- PagingSurface owns frameDriver: PagingFrameDriving? (:60); protocol has isRunning/start()/stop() (Sources/PagingUI/PagingFrameDriver.swift:20-24). Default RunLoopFrameDriver is 60Hz, common runloop mode, tolerance 0 (:57-60,134-138); it calls Surface.advanceFrame (:153-162).
- Surface.advanceFrame(deltaTime: TimeInterval) is internal (:491); simulateFrame(deltaTime: TimeInterval) is public (:396). Driver starts on state callbacks and runs for core.isAnimating or pending finish (:515-530,577-584). No extra timer, animation completion, or per-dot tick.
- Bounds: r = ceil(livePageRadius + prewarmDistance) = 3; live hosts <= min(pageCount, 2*r+1) = min(pageCount,7). Range centers on clamped rounded visualOffset, NOT requested/committed page (PagingSurface.swift:725-734).
- relayoutPagesIfRangeChanged (:738) compares wanted keys; relayoutPages (:754) retires all out-of-range hosts before adding only wanted hosts (:773-799). A 0->99 jump must not retain all crossed pages or allocate all target-distance pages.
- liveHostCount/poolHostCount/layoutPerformedCount are public observations (:173-178); hostForPage(_ index: Int) and pageContainer are internal test seams (:167-170). Existing tests use conservative live+pool <= 14; validate both instantaneous sum and per-frame high-water marks.
- PageHostView.clearForReuse bumps reuseGeneration and calls renderer cleanup (Sources/PagingUI/PageHostView.swift:97-106); Surface.surfaceGeneration is separate lifecycle/reload generation (:133,300,675), not a transition token.
- AppGridRenderer detects same host changing page, sweeps retired hosts, then reuses page instances (Sources/PagingPrototypeApp/AppCatalogAssembly.swift:324-342,387-401). totalInstancesCreated/livePageInstanceCount (:272-274) and pageView(forPage index: Int) (:372) are useful real-renderer assertions; host counts alone do not prove item-instance reuse or stale-icon safety.
- KeyboardFocusController owns selection, pendingCrossPageSettleTarget and isDeferredSelection (Sources/PagingPrototypeApp/KeyboardFocusController.swift:83-86); AppDelegate installs it and its existing activation adapter (:613-640).
- Existing public clearFocusForSearch() (:201) invokes private exitKeyboardSelection() (:473), clearing model/highlight/deferred state BUT NOT pendingCrossPageSettleTarget. reconcileSettledCrossPage(committedPage: Int) (:237) can later resurrect an old keyboard identity.
- Proposed pointer clear should reuse visual cleanup AND discard that pending keyboard target. Keep search semantics intact unless separately approved. Never setFocus(to:) (:207) for dot navigation.
- handleArrow (:425-438) currently seeds the committed page even during settling. For the new direct transition, defer arrows until its settled/idle boundary (without changing ordinary keyboard/physical policy); first direction then seeds the new committed page.
- Direction-key deferral and lifecycle cancellation need reliable direct-transition ownership across .reduceMotionChange restarts, which replace reason (:350-358). Retain request provenance/token linkage; a single reason check after restart is insufficient. Do not treat generation counters as interchangeable.
- No automatic activation: KeyboardFocusController.keyDown (:134-164) routes Return through current identity; dot navigation clears it and never calls onActivate/launchAdapter.

## Application gates and committed indicator updates
- Application owner must reject dot action for folderOpenState?.isOpen == true, isTitleEditing/folderRenameContext, or dragCoordinator?.isSessionActive == true; these are already held by AppDelegate.swift:85-115 and folder/drag wiring (:702-785,796-863).
- isSessionActive includes controller nonidle, pendingBlankPress, and click-only press (DragUISessionCoordinator.swift:180), so checking only dragging would miss a held pointer/search click arbitration.
- AppDelegate.dragGate/dragStartGate (:843-849) exclude title editing and exclude search only from STARTING DRAG. Dots must remain usable on committed search pages; do not copy search prohibition from dragStartGate.
- canApplyFolderAssignment (:2073-2079) resembles the state gate but also requires writable persistent layout, restored state and served catalog through canCommitWorkspaceLayout (:2066-2070). It neither rejects open folders nor enforces dot lifecycle; it is NOT a reusable dot predicate.
- Title begin cancels Surface and drag, mounts a fresh editor, then sets editing state (AppDelegate.swift:1480-1512). Dot rejection must occur before changing first responder, or focus loss can commit a title.
- First responder priority is title editor > open folder > search > top-level keyboard (AppDelegate.swift:770-785; AppSearchController.swift:247-267). A dot must not call exitSearchAndRestoreFocus(), which clears query (:129-138). Pointer focus clearing and responder restoration are distinct.
- Require active/visible/key application lifecycle before accepting an action; use attached window state plus launcher presentation state, not core.isTearingDown alone. NSApp.isActive/isKeyWindow are currently observations, not paging guards (AppDelegate.swift:2765-2766).
- Build dots as fixed container chrome sibling, outside translating pageContainer (AppDelegate.swift:340-365). NSButton identifiers with launchcopy.chrome. prefix are already recognized by blankClickResolvesToLauncherChrome (:2981-2993).
- blankClickResolvesToInteractionZone (:3011-3012) causes QuitOnBlankClickWindow.sendEvent to preserve full AppKit down/up/action delivery BEFORE blank/drag/search dismissal (:2771-2782). Dot descendants must use that actual path; inert/disabled strip gaps must not become background-dismiss hits or close the folder.
- Count truth: AppGridUIPageContentProvider.servedPageCount (Sources/AppGridUI/AppGridUIPageContentProvider.swift:72-78) derives from COMMITTED presentationEntries and instance itemsPerPage; folders occupy one slot, filtered/managed entries determine displayed ordinary pages.
- AppDelegate aligns provider.itemsPerPage to Surface (:546-550), uses provider.servedPageCount before update.plan.pageCount (:1091-1093), and wires search commit to reloadCurrentPresentation (:648-665). Do not count raw catalog apps or pending search results.
- Surface applyPresentation (:642-650) and applySameRevisionReload (:673-680) reconcile pageCount; same catalog revision can still change count and surfaceGeneration. Search.applyPendingAtIdleBoundary (:90-101) prioritizes new catalog and reruns query before notifying.
- Stable app boundary is AppDelegate.applyPendingAtIdleBoundary() (:1112-1117): commit presentation then reconcile keyboard. Subscribe/read count + committedPage after this and after standalone query commits, applyPresentationUpdate (:1079-1105), initialization, and lifecycle changes.
- Preserve existing callbacks by chaining, as folder wiring already does (:755-759). TelemetryBridge.install assigns the entire surface.appEvents (PagingTelemetryBridge.swift:84); AppDelegate installs telemetry after content assembly (:259-266), so wiring dots too early there would be overwritten.
- onCommit occurs while state is still settling, BEFORE endInteraction and application idle reconciliation. It is a commit notification, not a guarantee that pending replacement/count clamp has finished. Refresh final indicator after the synchronous idle transaction as well.
- No existing page-count-changed Surface callback: idle setPageCount, search reload, and same-count replacement can skip onCommit/onIdleBoundary. Add a bounded presentation/count observation seam or explicitly call one app-owned updater at ALL those transaction endpoints.
- Dots show committedPage only; Surface.accessibilityDescription currently shows target while settling and rounded offset while tracking (:858-873), so it is not the selected-dot source. Supply labeled page buttons/count/current-page accessibility from committed state.
- Hide for pageCount <= 1. Window/scroll a bounded number of controls for large counts while preserving absolute page identity; layout uses bounds/safe areas, with no icon loads or per-frame indicator rebuild.

## Lifecycle gaps specific to the proposed direct request
- Surface.cancel() currently does not clear pending finish (:290-294); direct requests must never create a synthetic physical wait. A rejected physical dot cannot use cancel as its gate.
- Hide preparation (AppDelegate.swift:2238-2253), did-hide handler (:2256-2263), window/application resign (:2445-2447,2475-2477), and LauncherWindowController.performDismiss/performSuspend (:244-281) do NOT cancel Core paging or stop its driver. orderOut keeps assembly alive. Teardown alone does not meet no-inactive-window-callback acceptance.
- Add scoped cancellation of the active direct request BEFORE hiding/suspending/resigning, using existing stale rules; driver must stop and obsolete completion stay rejected. Guarding a button action alone cannot prevent an already-running hidden commit.
- Current Surface.layout (:838-853) invokes Core.setPageWidth; settling resize abandons old context and retargets rounded rebased offset (Core:279-288). Height-only changes do not invalidate a transition. The direct contract requires explicit invalidation on resize; intercept the direct request before the existing resize restart, preserving physical D6 behavior.
- Current page-count shrink with valid target CONTINUES settle (Core:327-332); invalid target restarts to clamped rounded offset (:333-340). Bare count changes therefore do not guarantee direct-request cancellation, including same-count replacement.
- refreshPresentation/reloadCurrentPresentation defer replacement during settling (Surface:623-638,660-668). Integrate direct-owned cancellation when replacement becomes obsolete, before the pending presentation is applied; preserve pin/latest-content rules for physical interactions.
- Search query changes are staged via AppSearchController.controlTextDidChange (:143-147), committed through commitIfIdle (:238-242); catalog inputs enter existing presentation owners. Specify the direct cancellation hook at those staging/commit boundaries, not via dot offset ticks or a duplicate Sources transaction.
- Core and Surface teardown already reject/stop callbacks and release hosts (Core:384-398; Surface:297-318). Preserve those paths, weak captures, stale-token checks and generation checks.
- These gaps are future integration work under the approved direct contract, not a claim that existing gesture lifecycle policy has been repaired.

## Bounded existing tests to extend (read only; none run)
All paths below are under Tests/. Add focused cases next slice; retain the existing adjacent/physical cases.
| Existing fixture/test location | Bounded new assertions |
| --- | --- |
| PagingCoreTests/PagingCoreTests.swift:113,133,169,459 | Extend testPageCountZero/One, testMultiPage, testLateCompletionRejected: 0->4, last->first, negative/oversized clamp, idle same-page no-op, return-to-committed while settling; no intermediate commits. |
| PagingCoreTests/PagingCoreSequenceTests.swift:86,120,144,164 | Existing settling interruption/resize/shrink sequences: direct 0->4->1->3 latest-wins; capture old contexts; reject every old completion before/after latest completion, duplicate latest commits once. |
| PagingCoreTests/PagingCoreTests.swift:702,728,757,795 | testReduceMotionInstantCommit/ToggleMidSettle, testMomentumIsTrackingSubStage/GlideFramesOneTruncatesLongStream: instant target, ownership survives RM restart, physical tracking/glide requests ignored without token/session/offset changes. |
| PagingUITests/PagingSurfaceInterruptionTests.swift:58,74,122,142,160,189 | Extend continuous takeover, old-completion, resize/shrink/close/glide fixtures with direct requests; assert saved presentedOffset/fromOffset and container origin continuity; obsolete callbacks never update controls. |
| PagingUITests/PagingSurfacePendingFinishTests.swift:31,82,117 | Existing ended-no-events, momentum-window, teardown cases: rejected dot leaves needsFinish/pendingFinishSince and 0.1-second physical policy intact. |
| PagingUITests/PagingSurfacePerformanceTests.swift:19,43,63,79 | Exercise 100-page repeated 0->99->2->97 jumps via Surface; assert per-frame live <= 7, live+pool <= 14, correct host identities/clamped range and frames. Replace adjacent-only layout <= 2 expectation with no relayout when wanted keys are unchanged. |
| PagingUITests/PagingSeamTests.swift:167,197,234,288,351; PagingSurfaceSearchReloadTests.swift:201,319,334,345,370,389 | Pin survives replacements; latest pending applies once; 0/1/multi shrink updates selected/count, same-revision query invalidates old cell bindings, reused host generation carries through. |
| PagingUITests/AppCatalogAssemblyTests.swift:77 | testMultiPageFlipKeepsPerPageInstancesAcrossLiveHosts: expand bounded synthetic catalog to nonadjacent pages; assert pageView.superview === hostForPage, livePageInstanceCount bounded, totalInstancesCreated plateaus over repeats; no new synchronous frame-path I/O. |
| PagingUITests/KeyboardFocusControllerTests.swift:219,283,300 | Existing interrupted-cross-page/deferred/ESC fixtures: dot supersedes keyboard settle, clears pending identity/highlight, no Return activation, first arrow during direct settling deferred and after idle seeds final page. |
| PagingUITests/AppDelegateBoundedRegressionTests.swift:205,264,295; FolderRenameAssemblyTests.swift:119,173; B1ManualDeliveryTests.swift:218 | Reuse production assembly, title, folder and full interaction-zone delivery fixtures for actual NSButton action -> app gate -> Surface -> Core. Folder/title/held press reject; search remains active/query intact; repeated button down/up executes once and cannot blank-hide. Do not re-audit Sources. |
| PagingUITests/LauncherWindowControllerTests.swift:127,157,316; PagingSurfaceTests.swift:191,251,278 | Extend dismiss/suspend/stale and driver/RM/container fixtures with wired direct cancellation: hide/resign/resize/teardown invalidate old paging token, stop driver, no inactive callback or resumed obsolete commit. |

Fixtures: PagingUITests/TestSupport.swift:14 creates manual-driver Surface; settleFrames (:71) bounds completion to 600 ticks. Use a smaller explicit bound justified by the existing spring for a fixed jump; record timeout/failure instead of assuming landing.
Actual control-to-Core integration cases are REQUIRED additions; existing adjacent gesture fixtures and source/API inspection do not establish that path.

## Architecture tripwires and handoff
- Do not chain next/previous, forge scroll input/catalog revision, write Core state, move all pages into the live range, or create a second animation/focus/catalog owner.
- Gate before clearing selection/pinning/moving first responder; ignored physical/folder/title/drag requests must have zero effects. Clear accepted pointer focus before synchronous RM commit.
- Latest-wins target must preserve presented offset, invalidate old token without intermediate idle/content flush, and commit only the final target. Keep target clamp tied to current committed ordinary count, not count captured by a stale button.
- Long jumps may traverse many rounded ranges; existing range changes call requestContent/host.render on the frame path (Surface:738-799), and real renderer binding can request icons. Bounded residency alone does not prove the no-icon-work-per-frame contract. Verify caching/preparation under the real renderer; if it cannot meet the contract, return that bounded gap to Main before expanding scope.
- Do not select by offset tick, target reason, Surface accessibility text, pending query, or raw catalog count. Commit/replacement/lifecycle updates must leave indicator count/current-page consistent after all callbacks.
- Track direct ownership across RM restart and scoped lifecycle cancellation; test old completions after hide/reopen, resize, query/count changes, and teardown. Core transition tokens, Surface generations and launcher request IDs are separate domains.
- Remaining implementation decisions to record: active-target repeat no-op policy, bounded dot window size/accessibility traversal, neutral observation hook placement, and direct ownership across environment restarts. No visual/reference measurements or Sources findings are inferred here.
- Changed files: this document only. No source edits, Swift/build/test/GUI/commit/process operations or LaunchBetter/Buho interaction performed.
- Command note: all project reads and this document write use rtk proxy. Bootstrap RTK.md read and an unsuccessful memory-index keyword lookup were unprefixed; no relevant memory was used.
- Evidence limit: inspected source/test declarations only; no automated or physical PASS. Main must rebase this survey on Sources closeout and approve the concrete next-slice API/specification before implementation.
