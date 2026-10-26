# Icon / Typography Owner Source Review

Current disposition (R8, 2026-10-14 JST): **bounded source review clear; all original and follow-up findings resolved**. R8 at the end confirms the current verdict; R7 contains the unchanged final input hashes. Earlier dispositions are preserved historical review records; no build/GUI/candidate PASS is asserted.

Scope: approved display-only 32–64 / 9–16 auto-fit contract; preferences, native settings, application owner, renderer propagation and drag preview. Grid geometry is independently reviewed by Turing and excluded here. Rows/columns remain unapproved.

Disposition: **source repair required** for the three P2 findings below. This is not candidate PASS, GUI/restart acceptance or measured performance evidence. Only this report was written; no source, test, other document, asset or shared dirty change was edited. No Swift/build/test/app command was run.

## Open findings

### F1 — P2: Accessibility changes can strand saved appearance after cancelling folder motion

- Evidence: `Sources/PagingPrototypeApp/AppDelegate.swift:1893–1907`. Title cleanup and Reduce Motion notification attempt a flush before `cancelFolderVisualTransition()` at line 1902 clears the motion blocker. The handler has no subsequent flush. Cancellation invalidates the old generation (`:1348–1365`), so the natural completion (`:1252–1263`) will reject its token instead of releasing the queue.
- Trigger/outcome: start folder entrance/exit, accept a changed appearance, then deliver an accessibility display notification while Core is idle and drag/title owners are absent. Motion is cancelled, but accepted preferences remain queued and the settings status can remain “waiting” until an unrelated boundary.
- Likely cause: readiness is checked before the final blocker is removed. Resize/screen-change/close/Escape/resign handlers have now received tail flushes; this sibling path has not.
- Proposed fix: add a guarded tail flush after this handler completes motion cancellation and any overlay refresh. Add an owner test using the actual notification handler, checking latest accepted style, queued-to-applied status and rejection of the old completion.
- Scope/risk/confidence: owner lifecycle only; avoid restyling the retained visual before cancellation. High confidence from synchronous call order; not runtime reproduced by this reviewer.

### F2 — P2: Blank-pointer cleanup bypasses the notification used to release appearance

- Evidence: `Sources/AppGridUI/DragUI/DragUISessionCoordinator.swift:180` includes `pendingBlankPress` in `isSessionActive`. `pointerDragged` clears that candidate at `:318–322` without calling `endSession`; the subsequent pointer-up reaches the idle early return at `:413–415`. Likewise `cancel` clears the candidate before its idle guard at `:447–455`, returning without the `onSessionStateChange(.idle)` notification at `:599`.
- Trigger/outcome: arm a blank press with an idle controller, accept appearance while that press blocks readiness, move beyond threshold and release. No session-end callback reaches `AppDelegate.swift:864–876`; preferences and queued status can remain pending after input has ended. The recent owner tail flushes cover selected cancellation callers, but not this normal threshold/release sequence.
- Likely cause: auxiliary pointer ownership is not represented in the controller's state-transition notification contract.
- Proposed fix: preserve held-pointer ownership until release and funnel terminal blank/cancel paths through a single notification/cleanup boundary, including blank-only cancellation. Do not add appearance work to every pointer move. Main should coordinate any companion coordinator change. Add an owner test for blank press -> accepted draft -> threshold move -> release, without manually flushing.
- Scope/risk/confidence: pointer ownership/owner integration, not drop geometry; preserve blank-click dispatch and click suppression. High confidence from the branch trace.

### F3 — P2: A queued appearance is applied inside the final animation frame

- Evidence: `Sources/PagingUI/PagingSurface.swift:530–549` calls `core.tick`; `Sources/PagingCore/PagingCore.swift:248–254,295–296` completes settling and synchronously emits idle. `PagingSurface.swift:561–564` invokes the owner's idle callback. `AppDelegate.swift:1128–1136` drains appearance synchronously through its defer; `:1943–1955` updates all consumers and may refresh wallpaper for a mixed draft.
- Outcome: an accepted change performs presentation work on the `advanceFrame` stack. This conflicts with the approved specification's explicit absence of appearance work in `advanceFrame`/offset callbacks. It is one terminal-boundary update, not a claim of repeated per-frame work or a measured regression.
- Proposed fix: make frame-originated readiness notifications schedule one coalesced next-main-turn drain. Recheck current pin/Core/drag/title/motion/restore/quit/teardown state and consume only the latest pending value. Keep equal/size/font updates free of requests. Test that consumers remain unchanged during the terminal frame callback and update once after its stack unwinds; test a new input owner arriving before the scheduled drain.
- Scope/risk/confidence: owner boundary scheduling; preserve queued status until actual application and do not bypass new input ownership. High confidence from the call chain and contract text; no performance measurement performed.

## Revalidated and otherwise consistent source

- Re-read Main's updated AppDelegate/Owner tests. Tail flushes now cover resize, screen change, closeFolder, Escape and resign paths; natural motion completion remains generation-gated. The two new actual-entrance tests cover natural completion and resize/screen-change cancellation. Their current hashes supersede the initial inputs.
- Store: explicit schema1 defaults, required schema2 fields, future-header protection before body decoding/save, no writes on load, healthy equal Apply no-op, and persistence failure before presentation callback are present. Defaults stay draft; unsaved status is not overwritten by later presentation refresh.
- Owner: accepted and applied values are separate; one latest pending value exists. Pinned/Core/drag/title/motion/restore/quit gates and teardown guards are present. Reentrant acceptance is queued while a consumer is applying and retried without recursive drain. No source path from a size/font-only setter to icon requests, scans, query/order/focus/layout persistence or wallpaper refresh was found in this scope.
- Renderer: live/pool setters and render-time inheritance are present. Preview captures style/name/visibility with an independent image; nil capture preserves content, new show resets it, pointer moves only place the cached preview, and clear/teardown reset cache/elevation ownership. No production source retention defect was established by the initial weak-source test failure.
- Telemetry installs before folder wiring in current startup; folder wiring chains the prior state observer. The separate page-navigation seam survives telemetry event replacement. Manual public pin release still requires its caller to request a drain; the Owner test explicitly does so, and no additional production manual-pin caller was found.

## Verification limits

Existing `focused-r1.log` was read: 83 tests / 7 assertion failures; Preferences 8/0 and Owner 8/0 are subset results. Main subsequently reported the two fixture reruns as 2/0 and focused-r3 as 85/0. This focused result does not resolve the source findings or establish full/build/candidate acceptance. Updated preview source was inspected: the weak-release assertion remains outside the autorelease pool, and nil/style/content assertions remain. No overall passing result is inferred from the focused subset. Main owns subsequent compile/full tests, failure handling and fresh review inputs. No real GUI, restart, VoiceOver, runtime icon quality, physical AB, candidate hash or measured performance acceptance is asserted here.

## Reviewed source fingerprints

SHA-256 at report capture; any later change requires revalidation. Paths are relative to `/Users/mac/Projects/Launch_Copy/PagingPrototype`.

Capture (UTC): 2026-10-13T14:28:13+00:00

```text
707a4a98283182b943a20bf50f9c66dd534310573da33075ab2f02dbb131b4da  Docs/ICON_AND_TYPOGRAPHY_SPEC.md
66991c6335e296972e518c3ba8da2c3410aef66b22480b9ae1a7795198358a13  Sources/PagingPrototypeApp/AppearancePreferences.swift
422bc98a1d66eb9a00c570185bf863f10733f602ae7ce4162600f43b0332aa22  Sources/PagingPrototypeApp/AppearanceSettingsView.swift
2efc2a170a749253f4a5f90d148ee5ea24941ed344b45d88481e715e1218a411  Sources/PagingPrototypeApp/AppDelegate.swift
b60ad71a93ac2aa7369b8d42ffaa03a524fe3d9fbd12e9154e7471e0b8c59b5b  Sources/PagingPrototypeApp/AppCatalogAssembly.swift
5c4211153266ba4ee78e603fcdb039e6b5de1b4e1bdf830a828611d862bc4572  Sources/AppGridUI/DragUI/DragUIVisuals.swift
57a141f2cca1289410e6caf9d438725d66944e980ddd12901a6fca23d8ef2667  Sources/AppGridUI/DragUI/DragUISessionCoordinator.swift
9e20767ff19c0817bba43297a332cca0ec8c0abd438c95f6410ca564076adba7  Sources/PagingUI/PagingSurface.swift
fcef83d7b586e5ee36e6339f6ebc7702a6e4b1b15150a0206f61fedb81d68369  Sources/PagingCore/PagingCore.swift
c8fa7878e3ab29558e848826afebce333a9c76e336ead01c843fccc708bacb8c  Tests/PagingUITests/IconTypographyPreferencesTests.swift
605fbd381d7c3814e6fe73f6db439a93af82bf693ea9227f5119c1f86fd35013  Tests/PagingUITests/IconTypographyOwnerTests.swift
65de5184363a2e547d02bb73fa2f22e1ec6d18d7028956de017dc38bbc322895  Tests/AppGridUITests/DragPreviewAppearanceTests.swift
```

## R2 revalidation — supersedes the initial open-findings disposition

Current disposition: **one remaining P2; source repair still required**. DragUISessionCoordinator is now explicitly included. The initial findings/fingerprints above are historical, not current acceptance. No test/build/app commands were run; only this report was updated.

### Closed at source level

- **F1:** `AppDelegate.swift:1893–1908` now schedules a drain after accessibility cleanup. Other lifecycle/readiness hooks use the same coalesced scheduler. `IconTypographyOwnerTests.swift:247–259` invokes the actual handler and retains stale-motion/latest-style assertions.
- **F3:** `AppDelegate.swift:1962–1968` coalesces next-main-queue delivery, then `:1945` rechecks live readiness. All production readiness callers now schedule; only explicit Apply and the scheduled drain call the synchronous flush. Terminal-frame/new-input tests (`IconTypographyOwnerTests.swift:200–224`) assert no application during the terminal stack or during a subsequently started gesture. Explicit idle Apply remains synchronous.
- **Original F2 blank-release/cancel gap:** `DragUISessionCoordinator.swift:180–190,255,374–384,463–472` retains blank ownership through ineligibility and releases/announces it at up/cancel. The generation guard avoids a duplicate deferred idle after normal endSession or a reentrant newer press. Blank threshold/release/cancel owner tests (`IconTypographyOwnerTests.swift:227–244`) exercise this path. This does not close the fallback variant below.

### F2-R2 — P2: Fallback threshold cleanup still releases held-pointer ownership early

- Evidence: `Sources/AppGridUI/DragUI/DragUISessionCoordinator.swift:330–335` still calls `endSession()` when a click fallback crosses the movement threshold. `:599–618` clears `hasPointerOwnership` and emits idle, although no pointer-up or explicit cancellation occurred. This contradicts the new ownership policy applied to blank candidates.
- Trigger/outcome: arm an unresolved/stale-source fallback (or dragStartGate-disabled click-only fallback), accept changed appearance while pressed, exceed the threshold, and keep holding. The owner schedules an idle drain from this premature end; on the next main turn its `dragCoordinator.isSessionActive` gate is false and appearance can be applied before release. The dragStartGate-disabled branch is production-reachable while search is active (`AppDelegate.swift:860–862`).
- Likely root cause: historical suppression/candidate cleanup and physical pointer lifetime still share `endSession`. The new private flag is cleared by that existing early-cleanup branch.
- Proposed fix: preserve held-pointer ownership while restoring click suppression and clearing the ineligible fallback at the same historical threshold; publish the terminal readiness notification only on up/cancel. Separate candidate cleanup from physical ownership termination rather than changing threshold or click behavior. Do not blindly restore the flag after an outward callback: preserve a synchronously cancelled/replaced session using an ownership/generation guard.
- Regression expectation: owner test for disabled-drag/search or unresolved-source fallback -> accepted draft -> threshold move -> next-main-queue marker must still show queued/default style; up/cancel then applies once. Preserve the existing suppression timeline and zero-click assertions in `DragUISessionCoordinatorTests.swift:556–581`. Add notification-count/reentrant-new-press assertions. High source confidence; not executed by this reviewer.

### Evidence and boundaries

The existing focused-r3 log was previously inspected and records 85/0 for its earlier source inputs. It does not validate this repair revision. Main has announced a new focused run after the independent proxy test; no result is assumed. New next-main-turn helpers use a real DispatchQueue marker (`IconTypographyOwnerTests.swift:60–63`); existing gesture/direct/held/title/hide assertions remain. Frozen-exit owner test was inspected only for queue scheduling; the grid/proxy fallback review remains Turing's scope. Preview implementation and preferences/settings/renderer source are unchanged from the initial fingerprints.

### R2 source fingerprints

Capture (UTC): 2026-10-13T14:38:00+00:00

```text
707a4a98283182b943a20bf50f9c66dd534310573da33075ab2f02dbb131b4da  Docs/ICON_AND_TYPOGRAPHY_SPEC.md
66991c6335e296972e518c3ba8da2c3410aef66b22480b9ae1a7795198358a13  Sources/PagingPrototypeApp/AppearancePreferences.swift
422bc98a1d66eb9a00c570185bf863f10733f602ae7ce4162600f43b0332aa22  Sources/PagingPrototypeApp/AppearanceSettingsView.swift
90e2aec3b0b4b287eb28b2fb6af7c25a032eeff8aa9a7b6f339c4e4832036922  Sources/PagingPrototypeApp/AppDelegate.swift
b60ad71a93ac2aa7369b8d42ffaa03a524fe3d9fbd12e9154e7471e0b8c59b5b  Sources/PagingPrototypeApp/AppCatalogAssembly.swift
5c4211153266ba4ee78e603fcdb039e6b5de1b4e1bdf830a828611d862bc4572  Sources/AppGridUI/DragUI/DragUIVisuals.swift
0fb32da26437bf5f906fe027ceb5f1fc18bb8b548b0eff9f5fb6722854daf4a1  Sources/AppGridUI/DragUI/DragUISessionCoordinator.swift
9e20767ff19c0817bba43297a332cca0ec8c0abd438c95f6410ca564076adba7  Sources/PagingUI/PagingSurface.swift
fcef83d7b586e5ee36e6339f6ebc7702a6e4b1b15150a0206f61fedb81d68369  Sources/PagingCore/PagingCore.swift
c8fa7878e3ab29558e848826afebce333a9c76e336ead01c843fccc708bacb8c  Tests/PagingUITests/IconTypographyPreferencesTests.swift
0f7ec9efd5f09b3a3b234ed43e3e473963badfbeacb3cfd29b9cd3b6ba1a9186  Tests/PagingUITests/IconTypographyOwnerTests.swift
65de5184363a2e547d02bb73fa2f22e1ec6d18d7028956de017dc38bbc322895  Tests/AppGridUITests/DragPreviewAppearanceTests.swift
f394ea4530a8b846aef7b02191d14f00456a7c14583004f326c55ed6be9a10c0  Tests/AppGridUITests/DragUISessionCoordinatorTests.swift
f63804ae1b818930ac0323e027161dba858b9f7fafecf7498968a1adad5c844a  Tests/AppGridUITests/AppManagementDragVisualTests.swift
```

## R3 revalidation — focused-r4 / exit-fixture and teardown follow-up

Current source disposition remains **one open P2: F2-R2**. F1/F3 remain closed at source level. This section supersedes R2 fingerprints, not its unresolved fallback finding.

- `AppDelegate.swift:1973–1975` now prevents settings status refresh after final teardown. Next-main-turn coalescing and live readiness recheck remain intact.
- `IconTypographyOwnerTests.swift:32` supplies the production committed-page provider; native surface/overlay layout is included in folder installation. Exit-freeze, pending-state and eventual-application assertions remain at `:264–278`. The prior fixture could legitimately trigger the synchronous unreliable-anchor exit fallback; its failure alone did not establish a production animation defect.
- `DragUISessionCoordinator.swift:330–335,599–618` is unchanged from R2: thresholded fallback cleanup still calls endSession and clears held ownership before up/cancel. Passing blank-pointer/accessibility/terminal-frame tests do not exercise this fallback variant. The proposed held fallback -> threshold -> next-main-turn -> up/cancel regression remains necessary.
- Preview implementation is unchanged; updated release fixture still checks the weak source after draining the autorelease pool and retains nil capture, cache/style/content and host/reaffirm assertions. Grid/proxy/old-label test changes remain the independent grid reviewer's scope.

Read existing focused-r4 log: **108 tests / 5 assertion failures**. Main reports terminal-frame/new-input/blank/accessibility regressions and delayed-proxy lifecycle cases passed, and focused-r5 is running after fixture repairs. No r5 result, full/build/candidate PASS, GUI/restart or performance acceptance is inferred. No tests/build/app executed by this reviewer; only this report changed.

### R3 source fingerprints

Capture (UTC): 2026-10-13T14:42:20+00:00

```text
707a4a98283182b943a20bf50f9c66dd534310573da33075ab2f02dbb131b4da  Docs/ICON_AND_TYPOGRAPHY_SPEC.md
66991c6335e296972e518c3ba8da2c3410aef66b22480b9ae1a7795198358a13  Sources/PagingPrototypeApp/AppearancePreferences.swift
422bc98a1d66eb9a00c570185bf863f10733f602ae7ce4162600f43b0332aa22  Sources/PagingPrototypeApp/AppearanceSettingsView.swift
467803ff6847af7cc374d997af0747656db876ecb92cc43278f288557e589bb5  Sources/PagingPrototypeApp/AppDelegate.swift
b60ad71a93ac2aa7369b8d42ffaa03a524fe3d9fbd12e9154e7471e0b8c59b5b  Sources/PagingPrototypeApp/AppCatalogAssembly.swift
5c4211153266ba4ee78e603fcdb039e6b5de1b4e1bdf830a828611d862bc4572  Sources/AppGridUI/DragUI/DragUIVisuals.swift
0fb32da26437bf5f906fe027ceb5f1fc18bb8b548b0eff9f5fb6722854daf4a1  Sources/AppGridUI/DragUI/DragUISessionCoordinator.swift
9e20767ff19c0817bba43297a332cca0ec8c0abd438c95f6410ca564076adba7  Sources/PagingUI/PagingSurface.swift
fcef83d7b586e5ee36e6339f6ebc7702a6e4b1b15150a0206f61fedb81d68369  Sources/PagingCore/PagingCore.swift
c8fa7878e3ab29558e848826afebce333a9c76e336ead01c843fccc708bacb8c  Tests/PagingUITests/IconTypographyPreferencesTests.swift
a71fa71d32c73cd3641d8ca1dd3fea58c475ec456ce7255ba2f9f47fd9730f70  Tests/PagingUITests/IconTypographyOwnerTests.swift
d497f45d044314df4deecdd4e1bd55f81c4b4379747c04cc3ef04cba68b5596c  Tests/AppGridUITests/DragPreviewAppearanceTests.swift
f394ea4530a8b846aef7b02191d14f00456a7c14583004f326c55ed6be9a10c0  Tests/AppGridUITests/DragUISessionCoordinatorTests.swift
f63804ae1b818930ac0323e027161dba858b9f7fafecf7498968a1adad5c844a  Tests/AppGridUITests/AppManagementDragVisualTests.swift
```

## R4 final requested repair-source verdict — focused-r6 follow-up

**Verdict: original three P2 findings resolved at source level; one follow-up P2 (F2-R2) remains open. This is not a clean source acceptance.** Original findings and earlier input hashes are retained above as historical evidence. This section is the current disposition.

| Original finding | Current source resolution |
| --- | --- |
| F1: cancelled accessibility motion strands queued appearance | Resolved: AppDelegate.swift:1894 schedules after the handler; the deferred drain rechecks readiness after cancellation. |
| F2: blank auxiliary release/cancel misses terminal notification | Resolved for the originally reported blank branches: DragUISessionCoordinator.swift:181,255 retains held ownership; :374–384 releases and emits idle once when normal endSession did not do so; :463–472 includes blank-only owned-pointer cancellation. |
| F3: appearance executes inside terminal animation frame | Resolved: production readiness callbacks schedule the coalesced next-main-turn drain (AppDelegate.swift:1962–1968), with current readiness recheck at :1945. Explicit idle Apply remains synchronous. |

**Remaining F2-R2, P2:** Coordinator bytes are unchanged from R2. `Sources/AppGridUI/DragUI/DragUISessionCoordinator.swift:330–335` still calls `endSession()` when fallback movement exceeds the threshold, and `:600,618` clears physical ownership and publishes idle before pointer release. The disabled-drag/search click-only branch at `:266–274` is a direct reachable example. Next-turn scheduling avoids doing appearance work on the pointer callback stack but does not prevent applying it while that pointer remains held. Preserve threshold, suppressor restoration and click ordering; separate ineligible candidate cleanup from physical-pointer termination with reentrancy-safe ownership tracking. The R2 proposed owner regression must assert queued/unapplied after threshold and a real next-main-queue marker, then application once after up/cancel. Current Owner test names cover blank ownership, not fallback ownership.

The teardown status guard is present at `AppDelegate.swift:1974`. Scheduler coalescing, latest-wins/readiness and generation-based duplicate notification checks remain present. Preferences/settings/renderer/preview implementation is unchanged from its previously reviewed fingerprints. Updated Owner tests retain actual exit-freeze/pending assertions; no duplicate grid/proxy geometry review was performed.

**Observed existing evidence:** focused-r6.log records selected XCTest **108 executed / 0 failures**, completing at 2026-10-13 23:43:55.344. This does not negate the uncovered source branch. Main reports full-r1 is running against a captured 340-source snapshot; no full result, build result, GUI/restart/performance or icon-type candidate PASS is inferred. This reviewer ran no Swift/build/test/app commands and wrote only this report.

### R4 input fingerprints

Capture (UTC): 2026-10-13T14:46:49+00:00

```text
707a4a98283182b943a20bf50f9c66dd534310573da33075ab2f02dbb131b4da  Docs/ICON_AND_TYPOGRAPHY_SPEC.md
66991c6335e296972e518c3ba8da2c3410aef66b22480b9ae1a7795198358a13  Sources/PagingPrototypeApp/AppearancePreferences.swift
422bc98a1d66eb9a00c570185bf863f10733f602ae7ce4162600f43b0332aa22  Sources/PagingPrototypeApp/AppearanceSettingsView.swift
467803ff6847af7cc374d997af0747656db876ecb92cc43278f288557e589bb5  Sources/PagingPrototypeApp/AppDelegate.swift
b60ad71a93ac2aa7369b8d42ffaa03a524fe3d9fbd12e9154e7471e0b8c59b5b  Sources/PagingPrototypeApp/AppCatalogAssembly.swift
5c4211153266ba4ee78e603fcdb039e6b5de1b4e1bdf830a828611d862bc4572  Sources/AppGridUI/DragUI/DragUIVisuals.swift
0fb32da26437bf5f906fe027ceb5f1fc18bb8b548b0eff9f5fb6722854daf4a1  Sources/AppGridUI/DragUI/DragUISessionCoordinator.swift
9e20767ff19c0817bba43297a332cca0ec8c0abd438c95f6410ca564076adba7  Sources/PagingUI/PagingSurface.swift
fcef83d7b586e5ee36e6339f6ebc7702a6e4b1b15150a0206f61fedb81d68369  Sources/PagingCore/PagingCore.swift
c8fa7878e3ab29558e848826afebce333a9c76e336ead01c843fccc708bacb8c  Tests/PagingUITests/IconTypographyPreferencesTests.swift
38413577d6bf3a87296892abbad43ee5ab0426976f0a9b5e3535a81217ca0282  Tests/PagingUITests/IconTypographyOwnerTests.swift
d497f45d044314df4deecdd4e1bd55f81c4b4379747c04cc3ef04cba68b5596c  Tests/AppGridUITests/DragPreviewAppearanceTests.swift
f394ea4530a8b846aef7b02191d14f00456a7c14583004f326c55ed6be9a10c0  Tests/AppGridUITests/DragUISessionCoordinatorTests.swift
f63804ae1b818930ac0323e027161dba858b9f7fafecf7498968a1adad5c844a  Tests/AppGridUITests/AppManagementDragVisualTests.swift
```

## R5 revalidation — fallback ownership repair / missing-host UP

**Current disposition: original F1/F2/F3 and follow-up F2-R2 resolved at source level; one newly identified P2 (F4) remains.** Prior findings/hashes above are historical. No implementation was edited or build/test/app executed by this reviewer.

- F2-R2 resolved: `DragUISessionCoordinator.swift:330–336` now uses `endSession(keepingPointerOwnership: true)`. `:603–623` retains the held flag, restores suppression/clears candidate state at the existing threshold and omits terminal idle publication while keeping ownership. Actual UP releases through the generation-guarded defer; explicit cancellation uses the normal terminal cleanup. `IconTypographyOwnerTests.swift:249–270` covers dragStartGate-disabled fallback, threshold, a real next-main-queue marker, unchanged applied style until UP, then application. Threshold and click dispatch ordering remain intact in these branches.
- F1/F3 scheduling and final-teardown status protection are unchanged from the revalidated AppDelegate inputs. Preview implementation remains unchanged.

### F4 — P2: Missing-host UP cleans UI but leaves a real drag controller active

- Evidence: `Sources/AppGridUI/DragUI/DragUISessionCoordinator.swift:387–389` calls only `endSession()` when an owned UP has no visualHost. That helper (`:603–623`) clears UI state/ownership but never calls `controller.cancel`. `isSessionActive` (`:180–181`) remains true for a non-idle controller. Normal cancel (`:467–476`) explicitly cancels the controller before endSession; its reset is in `Sources/AppGridUI/DragSession/DragSessionController.swift:233–236,274–281`.
- Trigger/outcome: valid ordinary pointerDown reaches controller.pressed (or move reaches dragging), accept appearance, set/lose visualHost, then pointerUp. UI is cleared and idle notification emitted, but controller stays pressed/dragging, so the next queued drain still fails the owner's active-session gate. Queue/status remain blocked until a later explicit cancellation; the source's missing-host release boundary is not complete.
- Coverage gap: the new lost-host test at `IconTypographyOwnerTests.swift:266–270` retains `dragStartGate = { false }` from line 253, so its controller is idle and it cannot detect this case.
- Proposed fix: route host-loss release through controller cancellation plus existing endSession cleanup, e.g. the normal cancel seam with an appropriate host-loss cancellation reason. Preserve single terminal notification and zero click/commit/launch. Add a gate-enabled pressed/dragging host-loss owner test asserting controller idle, no active ownership, cleared visual/suppression state, queued-to-applied once after a real next-main-turn marker and no commit/click. High confidence from call order/state ownership; not runtime executed by this reviewer.

Main reports full-r1 as 2157/5, with held-contract/menu fixtures repaired and an independent LayoutStore race under Singer review; targeted/native-owner reruns are running. These are not passing current-revision evidence. Focused-r6 108/0 remains a prior-input result. Independent grid/menu/persistence triage is not duplicated here, and no full/build/GUI/restart/performance/candidate PASS is asserted.

### R5 input fingerprints

Capture (UTC): 2026-10-13T14:55:48+00:00

```text
707a4a98283182b943a20bf50f9c66dd534310573da33075ab2f02dbb131b4da  Docs/ICON_AND_TYPOGRAPHY_SPEC.md
66991c6335e296972e518c3ba8da2c3410aef66b22480b9ae1a7795198358a13  Sources/PagingPrototypeApp/AppearancePreferences.swift
422bc98a1d66eb9a00c570185bf863f10733f602ae7ce4162600f43b0332aa22  Sources/PagingPrototypeApp/AppearanceSettingsView.swift
467803ff6847af7cc374d997af0747656db876ecb92cc43278f288557e589bb5  Sources/PagingPrototypeApp/AppDelegate.swift
b60ad71a93ac2aa7369b8d42ffaa03a524fe3d9fbd12e9154e7471e0b8c59b5b  Sources/PagingPrototypeApp/AppCatalogAssembly.swift
5c4211153266ba4ee78e603fcdb039e6b5de1b4e1bdf830a828611d862bc4572  Sources/AppGridUI/DragUI/DragUIVisuals.swift
402de77e218f37e739f9b43b803ad4caa7a0bd95babaab83b05aab253b0b668d  Sources/AppGridUI/DragUI/DragUISessionCoordinator.swift
9e20767ff19c0817bba43297a332cca0ec8c0abd438c95f6410ca564076adba7  Sources/PagingUI/PagingSurface.swift
fcef83d7b586e5ee36e6339f6ebc7702a6e4b1b15150a0206f61fedb81d68369  Sources/PagingCore/PagingCore.swift
c8fa7878e3ab29558e848826afebce333a9c76e336ead01c843fccc708bacb8c  Tests/PagingUITests/IconTypographyPreferencesTests.swift
fd626b61f8fb4e015628b4a3b84d63eed9faba4a3757adfc5bb1047b75b399e8  Tests/PagingUITests/IconTypographyOwnerTests.swift
d497f45d044314df4deecdd4e1bd55f81c4b4379747c04cc3ef04cba68b5596c  Tests/AppGridUITests/DragPreviewAppearanceTests.swift
f394ea4530a8b846aef7b02191d14f00456a7c14583004f326c55ed6be9a10c0  Tests/AppGridUITests/DragUISessionCoordinatorTests.swift
f63804ae1b818930ac0323e027161dba858b9f7fafecf7498968a1adad5c844a  Tests/AppGridUITests/AppManagementDragVisualTests.swift
01b81a115683f49c0d33bd39a625b1b2549fe16a5cd2aa3d343ad0852871661f  Sources/AppGridUI/DragSession/DragSessionController.swift
```

## R6 bounded final recheck — targeted 19/0 update

**Verdict remains source repair required for F4 only.** Original F1/F2/F3 and F2-R2 are resolved. All 15 R5 input hashes were recalculated and match; R5 fingerprints are the current inputs, not assumed from the reported test result.

Re-read `DragUISessionCoordinator.swift:375–389,467–476,603–623`: missing-host UP still calls only endSession, while controller cancellation exists separately in cancel. A gate-enabled pressed/dragging session therefore stays non-idle after host loss/UP; isSessionActive remains true and appearance remains queued. Re-read `IconTypographyOwnerTests.swift:249–270`: its lost-host phase still uses dragStartGate=false from line 253 and covers an idle controller only. Thus the reported targeted 19/0 does not close F4.

Concrete remaining repair: cancel the non-idle controller on missing-host UP before UI cleanup, using the existing cancel seam or equivalent guarded cancellation; test host loss after actual gate-enabled pressed/dragging input, assert controller idle/ownership false, no click or commit and one next-turn queued appearance application. No changes to thresholds or click/suppression ordering are requested. No additional bounded source finding was identified.

Main reports targeted 19/0 and independent Singer LayoutStore barrier triage. Those results are not independently executed here. No storage/grid review expansion, build/GUI/restart/performance/full/candidate PASS. Only this report was updated.

Recheck (UTC): 2026-10-13T14:56:34+00:00

## R7 final bounded repair-source verdict — all findings closed

**BOUNDED SOURCE REVIEW CLEAR: no remaining actionable finding in the assigned owner/preferences/settings/renderer/preview/coordinator scope at the hashes below.** Original F1/F2/F3, follow-up F2-R2 and F4 remain recorded above and are now all resolved at source level. This supersedes prior repair-required dispositions; it is not candidate/build/GUI/performance acceptance.

| Finding | Inspected resolution |
| --- | --- |
| F1 | AppDelegate.swift:1894 schedules after accessibility cleanup; live readiness recheck occurs at :1945. |
| F2 | DragUISessionCoordinator.swift:180–190 retains physical blank ownership; :375–384 releases with duplicate/reentrant notification guards; normal cancel terminates owned auxiliary input. |
| F3 | AppDelegate.swift:1962–1968 coalesces next-turn readiness delivery; actual current input/pin/motion/restore/quit/teardown gates are rechecked before fan-out. Explicit idle Apply remains synchronous. |
| F2-R2 | DragUISessionCoordinator.swift:330–336,605–625 preserves held ownership through fallback threshold cleanup, restores suppression/clears the candidate and withholds premature idle. UP/cancel release it. |
| F4 | DragUISessionCoordinator.swift:387–391 now calls existing cancel(.windowResign) for a non-idle controller. :469–478 resets the controller before UI cleanup. The end generation advances, so UP defer does not publish a duplicate idle. Owned idle auxiliary input still uses endSession. |

Inspected `IconTypographyOwnerTests.swift:273–299`: the added test loops actual gate-enabled pressed and dragging/edge-turn states, loses the host, delivers UP, checks controller idle/ownership inactive, then checks pending cleared/applied style after a real next-main-turn marker and zero clicks/commits. The prior disabled-drag fallback/host-loss regression remains at :249–270. Test source validates these assertions exist; single terminal notification follows the inspected generation/cancel call path, not an independently measured notification counter.

AppDelegate, preferences/settings, renderer, preview and controller implementation hashes other than the Coordinator match the prior revalidated inputs. No further bounded source defect was identified. Grid geometry/proxy review and Singer's LayoutStore triage remain separate; no other implementation or document was edited.

**Read-only existing logs:** full-r2.log records 2158/0 at 2026-10-13 23:57:47.428 JST, against historical pre-F4-repair inputs. It is not current-repair full-suite evidence. At inspection owner-repair-r7.log was still progressing; its Coordinator subset recorded 18/0, while Owner tests had started. No overall r7 outcome is assumed. No Swift/build/test/app command was run by this reviewer. Main owns fresh full/build/candidate fingerprint and GUI/restart/physical/performance gates.

### R7 final reviewed input fingerprints

Capture (UTC): 2026-10-13T15:02:23+00:00

```text
707a4a98283182b943a20bf50f9c66dd534310573da33075ab2f02dbb131b4da  Docs/ICON_AND_TYPOGRAPHY_SPEC.md
66991c6335e296972e518c3ba8da2c3410aef66b22480b9ae1a7795198358a13  Sources/PagingPrototypeApp/AppearancePreferences.swift
422bc98a1d66eb9a00c570185bf863f10733f602ae7ce4162600f43b0332aa22  Sources/PagingPrototypeApp/AppearanceSettingsView.swift
467803ff6847af7cc374d997af0747656db876ecb92cc43278f288557e589bb5  Sources/PagingPrototypeApp/AppDelegate.swift
b60ad71a93ac2aa7369b8d42ffaa03a524fe3d9fbd12e9154e7471e0b8c59b5b  Sources/PagingPrototypeApp/AppCatalogAssembly.swift
5c4211153266ba4ee78e603fcdb039e6b5de1b4e1bdf830a828611d862bc4572  Sources/AppGridUI/DragUI/DragUIVisuals.swift
b0a4afcda45e90d3f0975866c035d7deed8d3885001c3624b86ae2f5f5ddc193  Sources/AppGridUI/DragUI/DragUISessionCoordinator.swift
9e20767ff19c0817bba43297a332cca0ec8c0abd438c95f6410ca564076adba7  Sources/PagingUI/PagingSurface.swift
fcef83d7b586e5ee36e6339f6ebc7702a6e4b1b15150a0206f61fedb81d68369  Sources/PagingCore/PagingCore.swift
c8fa7878e3ab29558e848826afebce333a9c76e336ead01c843fccc708bacb8c  Tests/PagingUITests/IconTypographyPreferencesTests.swift
24f608f9a86d0e23d1a0c3bb2d1b08f77c5a7bf5440c4605309525c543aaf5df  Tests/PagingUITests/IconTypographyOwnerTests.swift
d497f45d044314df4deecdd4e1bd55f81c4b4379747c04cc3ef04cba68b5596c  Tests/AppGridUITests/DragPreviewAppearanceTests.swift
f394ea4530a8b846aef7b02191d14f00456a7c14583004f326c55ed6be9a10c0  Tests/AppGridUITests/DragUISessionCoordinatorTests.swift
f63804ae1b818930ac0323e027161dba858b9f7fafecf7498968a1adad5c844a  Tests/AppGridUITests/AppManagementDragVisualTests.swift
01b81a115683f49c0d33bd39a625b1b2549fe16a5cd2aa3d343ad0852871661f  Sources/AppGridUI/DragSession/DragSessionController.swift
```

## R8 final fresh recheck — actual owner-repair-r7 outcome

**BOUNDED SOURCE REVIEW CLEAR confirmed.** Freshly inspected Coordinator host-loss UP, normal cancel, cleanup/ownership generation and actual gate-enabled pressed/dragging test. F4 correctly resets the controller before UI cleanup and the generation guard prevents duplicate deferred idle publication. No remaining actionable finding; original F1/F2/F3, F2-R2 and F4 are all resolved.

Recalculated all 15 R7 input hashes: no drift. The R7 fingerprint block remains the final reviewed source/spec/test inputs.

Read actual owner-repair-r7.log: **76 executed / 0 failures**, finishing 2026-10-14 00:01:35.103 JST; summed XCTest case time 11.777 seconds (Selected tests elapsed 11.832 seconds). This supersedes R7's then-in-progress log observation only. Historical full-r2 2158/0 remains pre-F4-repair evidence. Main will refresh its broader 340-file snapshot and run full-r3/Debug/Release; no new full/build/GUI/restart/performance/candidate PASS is inferred.

Only this report updated; no Swift/build/test/app command executed by the reviewer.

Fresh recheck (UTC): 2026-10-13T15:03:49+00:00

## Final evidence addendum — full-r3, review stopped

Bounded source disposition remains **CLEAR**, all recorded findings resolved. Recalculated the 15 final review inputs again: no drift.

Read existing logs: owner-repair-r7 **76/0** at 2026-10-14 00:01:35.103 JST; full-r3 **2159/0** at 2026-10-14 00:03:54.720 JST (summed case time 39.725 seconds; All tests elapsed 39.945 seconds). These are actual nonzero XCTest results. Full-r3 is the current post-F4-repair suite, superseding historical full-r2 for test corroboration.

Main snapshot: `.build/verification/20261013/icon-type/source-files-r3.sha256`, 340 entries; SHA-256 `a31b80b1bd409cd276e46ac521382ccd63dccbe4e2c66681011124511a5414b3`. 14 final reviewed inputs match snapshot entries, with 0 mismatches. Inputs outside that source snapshot: `Docs/ICON_AND_TYPOGRAPHY_SPEC.md`. Their current bytes separately match the final review hashes.

Main owns the running unique `icon-type-rc-20261014-r1` Debug/Release builds and remaining GUI/restart/physical/performance/candidate gates. None is certified here. Reviewer performed only read-only evidence checks and this designated report update; no builds/tests/app runs, source edits, restarts or other writes. Review work stops here.
