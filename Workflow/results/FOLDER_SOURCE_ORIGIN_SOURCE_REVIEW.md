# Folder Source-Origin Motion — Independent Bounded Source Review

Date: 2026-10-16
Verdict: **FAIL — one P2 source finding; no physical or performance verdict.**

## Scope and evidence boundary

Reviewed `AGENTS.md`, the APPROVED `Docs/FOLDER_SOURCE_ORIGIN_MOTION_SPEC.md`, the current stage summary, and the actual source-origin paths in:

- `Sources/AppGridUI/{FolderMotion.swift,FolderOverlayView.swift,AppGridCellView.swift}`
- `Sources/PagingPrototypeApp/{AppDelegate.swift,AppCatalogAssembly.swift}`
- `Tests/AppGridUITests/{FolderMotionTests.swift,FolderIconGeometryTests.swift}`
- `Tests/PagingUITests/{AppCatalogAssemblyTests.swift,AppDelegateBoundedRegressionTests.swift}`

Read only the existing coordinator and keyboard/window routing needed to trace input admission. The broad dirty worktree is not this stage's diff and is not certified by this review. The accepted glass, prior candidate baseline 463 / 05c415a0 / 2794 green, paging physics and unrelated changes remain outside the verdict.

Reviewer executed no SPM command, test, build, UI operation, reference-code inspection, or agent dispatch. Only this report was written. Main owns execution and integration. No model override was requested or performed.

Main initially reported RED: 2 tests / 5 assertions; focused r2: 72 tests / 1 offscreen-resolver failure; then the explicit page/pageHost-bounds guard with r3 running. During review, Main reported the corrected focused run passed 72 tests, including the exact actual-CA-anchor owner test, and full session 99477 was running. These are attributed execution reports, not reviewer-executed or independently log-verified results. No current full-build/full-suite/package/localization result is inferred.

## Finding F1 — [P2] Admit member pointers only when their hit geometry matches the presentation

**Location:** `Sources/PagingPrototypeApp/AppDelegate.swift:1532-1544` (entrance starts without member pointer admission); related owner wiring at `939-941`, `960-966`, `1078-1102`, and `1691-1711`. Existing consumers: `Sources/AppGridUI/FolderOverlayView.swift:750-805`.

**Concrete trigger and effect:** Open a visible folder by pointer, then press at a member's final cell position during the 240 ms entrance, while the visible panel is still a small/moving presentation near the source glyph. The live overlay can classify that position as the member and send a press to the coordinator. A short release can dispatch a member launch; sufficient motion can begin a member drag using final-layout geometry. The same mismatch applies to a resumed entrance. This violates approved contract item 8's requirement against pointer launch at an incorrect moving region.

**Source evidence:**

- `animateFolderEntrance` marks `folderEntranceAppearanceGeneration` and animates the panel, but leaves the live overlay interactive.
- `animateFolderLayer` immediately sets the model transform to the final identity and model opacity to 1, then adds a presentation animation. Presentation motion does not update the view-space member regions used by the handlers.
- `handleClick(at:)` and `mouseDown(with:)` classify against `panel.frame` and `cell.frame`, without an entrance admission check. The coordinator path sets `isTrackingMemberDrag` and forwards the selected source cell.
- The installed `dragGate` checks title editing only. `dragStartGate` checks workspace/search/title conditions; none excludes the entrance. Merely denying `dragStartGate` would still arm its click fallback in `DragUISessionCoordinator.pointerDown`.
- The owner-wired member activation callbacks and `handleDragCellClick` route to `launchMember` without settling/rejecting this entrance. `canCommitWorkspaceLayout` does not exclude it either.
- `canBeginTrackpadPaging` already checks entrance/exit state, but that guard only protects scrolling. The window's existing folder/interaction-zone path forwards pointer events to the overlay without an entrance settle/admission step.

**Likely root cause:** The much larger source-origin visual transform was connected to the stable panel, while pointer classification retained its settled-layout assumptions. The earlier small nudge had related assumptions; this finding concerns their consequence under the newly approved full glyph-to-panel travel, not a claim that every input path was newly introduced.

**Recommended solution:** Main should add an owner-controlled admission or reconciliation step before member pointer classification/press ownership. During entrance, member click/drag/menu/page-control paths must either be withheld or operate on deliberately reconciled visible geometry. Apply it to the coordinator and direct fallback routes. Keep ESC and outside-close available and keep modal outside-hit coverage fixed; setting the whole overlay visual-only would break those requirements. No new animation owner or paging physics change is needed. This recommendation is not authorization for a wider architecture change.

**Required regression evidence:** With a real source-origin entrance active, deliver an in-panel member down/up at final geometry and a thresholded drag through production overlay/coordinator wiring; establish no mismatched launch or drag. Cover the no-coordinator fallback and resumed entrance. Confirm normal member interaction after settle/cancel, and ESC/outside-close plus blocked scroll ownership during entrance. A source-level gate assertion alone would not exercise the dispatch gap. Main owns these executions.

**Affected scope / regression risks:** Folder member pointer admission during entrance; callback and coordinator ordering, release of press/suppression state, normal settled interactions, outside-close and keyboard cancellation. **Confidence: high for the source-path gap; no native accidental-launch, frame-timing, or physical smoothness reproduction claimed.**

## Other bounded checks

- **Pure geometry:** For panel center C, pivot P = panel.min + size × actual anchor, source center S and uniform s = min(1, glyph.width/panel.width, glyph.height/panel.height), the implementation uses t = S − P − s(C − P). Therefore P + s(C − P) + t = S; the two scaled extents fit the glyph and retain the panel aspect ratio. This is full source travel, not the former 8 pt hint. Tests cover nonzero origins, rectangular glyphs, multiple anchors, edge positions and malformed inputs. The owner test projects through actual layer bounds/position/anchor rather than asserting translation alone; Main reports it passed.
- **Coordinates and source validation:** The cell seam reads the actual symbol view frame without forcing layout or changing hit padding. The renderer converts through the common AppKit hierarchy, validates the currently committed page/binding generations, rejects hidden/detached/reused sources and now explicitly intersects both page and pageHost bounds. Flipped-host conversion is covered in test source. No cached resolver glyph anchor or backing-pixel rounding was introduced.
- **Fallback and reversal:** Fresh invalid-source entrance returns identity for an opacity fade; an invalid source at exit preparation closes synchronously. Same-folder retained-exit reopening samples before cancellation, while a different folder starts its own entrance. Generation checks, sampled-presentation sanitization, retained-visual callback/accessibility suppression and completion cleanup remain present. Existing tests inspect these mechanisms; this is not rendered continuity acceptance.
- **Lifecycle and ownership:** Animation is on the stable `motionPresentationView` panel; the root/modal coverage and title-editor host identity stay fixed. Standard durations are 240/200 ms; Reduce Motion is 180 ms with identity transforms. Resize, screen changes, hide/session suspension, accessibility-display changes, teardown and normal move-out close retain owner cancellation/reconciliation paths. Appearance/layout queues continue to recognize motion ownership. No new framework, animation timer, per-frame layout/binding loop or paging-physics modification was found in this bounded stage.

## Reviewed input fingerprints

SHA-256, captured after source inspection; verdict applies to these inputs and must be revisited after repairs:

| File | SHA-256 |
| --- | --- |
| `Sources/AppGridUI/FolderMotion.swift` | `d9db540dd7a67aadcf25700b540a6b4e30b421e3de3f256b4ce612921dc5ce90` |
| `Sources/AppGridUI/FolderOverlayView.swift` | `b24ddb1267fbd8b2fa4de3fc81f19f309962e8e8f3f9de3319a7654cf783d929` |
| `Sources/AppGridUI/AppGridCellView.swift` | `eb38dce836c0214fd6a29ccf4f8fa4c1946e1cd5cc8ac61104c24b9d5339195a` |
| `Sources/PagingPrototypeApp/AppDelegate.swift` | `7e07eee8e90c651a0a625e78b44a7573a674e98c7840a4dc4e13bbafe6c520d0` |
| `Sources/PagingPrototypeApp/AppCatalogAssembly.swift` | `8174fe17c95454b75df5fd09f2d6b7ac2eef8c0f54b65d20cf4c7da3c6c8111b` |
| `Tests/AppGridUITests/FolderMotionTests.swift` | `82ef825b8654356378ea4641b8412b580e613c31f5c6e24897f6865a373beffd` |
| `Tests/AppGridUITests/FolderIconGeometryTests.swift` | `144ab26909c0b84bc8b538f687e4e4417498a52e7cc74285adaa6148de46f9c9` |
| `Tests/PagingUITests/AppCatalogAssemblyTests.swift` | `a2399b1d86cdd7d833e2feb2642f6d07a7c25c9ebe3ff3e114741788400b8b7f` |
| `Tests/PagingUITests/AppDelegateBoundedRegressionTests.swift` | `1194e05b21114110a7241eb3aae465fc7043c75fb86841a805ee8402c4a80fbe` |
| `Docs/FOLDER_SOURCE_ORIGIN_MOTION_SPEC.md` | `4ca064b9e8d4a406484891ee7e0c007145b7d1be6be9125adeb9449c20a58ab5` |

Next action: Main repairs F1 within the approved input contract, supplies targeted execution evidence and stable updated inputs for bounded re-review. Native visual/physical gesture/flash/performance acceptance remains independent and pending.

## Repair review R2 — 2026-10-16

**Current bounded source verdict: PASS for the F1 repair; F1 CLOSED at source level.** The original FAIL, evidence and original fingerprints above remain historical and unchanged. This supersedes that outstanding finding only for the repaired inputs below; execution and native acceptance are separate gates.

### Actual repair inspected

- `AppDelegate.swift:1459` sets the panel-transition state before `refreshFolderOverlay` can configure/mount the live overlay. This also covers same-folder retained-exit resume and opacity-only entrance fallbacks. Configure does not reset this flag.
- `FolderOverlayView.swift:301-312` exposes read-only state with an owner-controlled setter. It cancels local paging when activated and updates title/page-control readiness; it does not transform or remove the modal root.
- `FolderOverlayView.swift:768-819` rejects an in-panel direct click or member mouse-down while active, before setting member drag-tracking state or calling `coordinator.pointerDown`. The no-coordinator path delegates to the same guarded direct handler. Denial happens before either controller press or coordinator click fallback can be armed, rather than relying on `dragStartGate` alone.
- `mouseDragged`/`mouseUp` retain their normal forwarding. With the rejected down, there is no corresponding member press/fallback to release later; the existing coordinator's `pointerUp` swallows an idle release when neither blank nor fallback was armed. This closes the release-after-settlement case without blocking the outside-blank press/release path.
- `FolderOverlayView.swift:967-986` returns the modal root during entrance before native child controls can be selected. Overlay menu lookup, the direct member-cell menu callback (`1210-1217`), title-edit availability, direct previous/next actions and trackpad admission independently reject the active transition. The trackpad handler still consumes rejected input; it does not forward scrolling to the outer surface.
- The panel-outside branches of `handleClick` and `mouseDown` remain available. A real outside down still arms normal blank-close arbitration. Existing Escape/keyboard routes are unchanged. The implementation did not make the entire live overlay visual-only as an input workaround; the original inert retained-exit mechanism remains separate.
- `AppDelegate.swift:1555` clears admission only after the accepted completion generation; `1643` clears it through owner cancellation. `FolderOverlayView.clearContent` and `teardown` also reset it, and clear restores page-button readiness. Retained-exit cancellation clears content before restoring interaction, so the visual-only setter guard does not strand this state on reuse. No new animation owner, timer, framework or physics changes were introduced by this repair.

No additional concrete source defect was found in this bounded repair inspection. Confidence is high for closure of the identified dispatch gap; no rendered timing or physical input outcome is claimed.

### Regression evidence and remaining execution boundary

Main reports the actual pre-repair RED was 1 test / 2 assertions (pointer activation and armed session), retained at `.build/folder-source-origin-input-red.log`. Reviewer did not execute that regression or inspect its log; this is attributed evidence.

Reviewed the added test source in `AppDelegateBoundedRegressionTests.swift`:

- `testPointerEntranceRejectsMemberPressButKeepsOutsideClose` exercises direct activation rejection, production overlay mouse-down admission with the installed coordinator, absence of an armed session, release, and direct outside-close.
- `testBlockedEntrancePressCannotLaunchOnReleaseAfterSettlement` starts with the actual owner entrance active, rejects a member down, waits across owner completion, releases, checks that no coordinator session remains, and checks restored direct member activation. Its activation counter observes the overlay callback; the no-armed-session assertion and the inspected coordinator release path are the evidence against deferred coordinator dispatch. This is not a native launch observation.
- Existing source tests still cover keyboard Escape during entrance, coordinator blank-close with an inert retained exit, generation-safe same-folder resume, different-folder entrance, Reduce Motion and keyboard reopen.

Focused r4 was **running** at Main's handoff; no passing execution is inferred here. Main also reports the initial full 2807/0 and Debug/Release packaging completed **before F1**. Those results do not validate the repaired hashes, and pre-repair candidate `365aaaa8` must not be represented as the final repaired delivery. Main owns the new focused/full/build/package/localization results and any additional dispatch coverage. Native geometry/continuity, physical gesture/flash and performance gates remain pending.

### Stable repaired input fingerprints

SHA-256 captured after inspecting the repair. The three changed files relative to the first review are the overlay, owner and owner regression tests; the other listed inputs retain their first-review hashes.

| File | SHA-256 |
| --- | --- |
| `Sources/AppGridUI/FolderMotion.swift` | `d9db540dd7a67aadcf25700b540a6b4e30b421e3de3f256b4ce612921dc5ce90` |
| `Sources/AppGridUI/FolderOverlayView.swift` | `e91e50e70beb81220e5ff026d4c99b3fea491101694ed393dec2a11adc4da289` |
| `Sources/AppGridUI/AppGridCellView.swift` | `eb38dce836c0214fd6a29ccf4f8fa4c1946e1cd5cc8ac61104c24b9d5339195a` |
| `Sources/PagingPrototypeApp/AppDelegate.swift` | `82f4a00a4561069a1ca16f7b62f29037f600de55b06b85af55d457ea0730a918` |
| `Sources/PagingPrototypeApp/AppCatalogAssembly.swift` | `8174fe17c95454b75df5fd09f2d6b7ac2eef8c0f54b65d20cf4c7da3c6c8111b` |
| `Tests/AppGridUITests/FolderMotionTests.swift` | `82ef825b8654356378ea4641b8412b580e613c31f5c6e24897f6865a373beffd` |
| `Tests/AppGridUITests/FolderIconGeometryTests.swift` | `144ab26909c0b84bc8b538f687e4e4417498a52e7cc74285adaa6148de46f9c9` |
| `Tests/PagingUITests/AppCatalogAssemblyTests.swift` | `a2399b1d86cdd7d833e2feb2642f6d07a7c25c9ebe3ff3e114741788400b8b7f` |
| `Tests/PagingUITests/AppDelegateBoundedRegressionTests.swift` | `29825426346e0b8e8b098409dcbb24be871a136b7b51cda654d34e2a16c336b3` |
| `Docs/FOLDER_SOURCE_ORIGIN_MOTION_SPEC.md` | `4ca064b9e8d4a406484891ee7e0c007145b7d1be6be9125adeb9449c20a58ab5` |

Reviewer changes in R2: append to this report only. No production/test edits, own test/build/UI execution, reference-code access or agent dispatch. Next action belongs to Main: complete repaired-code verification and produce a newly identified candidate before native handover.

## Test-adaptation review R3 — 2026-10-16

**Verdict: PASS for the two bounded test adaptations; no new finding.** R2's production-source PASS and source-level F1 closure remain unchanged. All five production-file hashes were checked against R2 and match exactly. The original FAIL and R2 review remain preserved above.

### Inspected adaptations

- `Tests/PagingUITests/IconTypographyOwnerTests.swift:185-201`: the entrance/style test now waits for `pendingAppearancePreferences == nil` with an explicit 1-second bound, then retains the nil and exact 64-point folder-style assertions. The initial non-nil assertion still proves that the style was deferred. The second 32-point application still proves queuing, invokes `windowDidChangeScreen`, yields a main turn and asserts both drainage and the exact resulting style. Thus this change observes the promised asynchronous result instead of assuming that entry completion plus queued style application must fit within a fixed 250 ms sleep. It does not remove the screen-change path or weaken the expected style values.
- `Tests/PagingUITests/AppDelegateBoundedRegressionTests.swift:484-502`: the release-after-settlement test now waits for `!overlay.isPanelTransitionActive` with an explicit 1-second bound, replacing its 300 ms fixed sleep. The active-state assertion before down, inactive-state assertion before release, zero activation assertion, no-armed-session assertion and restored settled direct activation assertion all remain. The critical order is still down during entrance, completion, then up. R2's distinction between its overlay activation counter and inspected coordinator dispatch/state evidence remains applicable.
- `Tests/PagingUITests/AppContentTestSupport.swift:115-128`: inspected the existing shared `waitUntil` implementation. It polls with asynchronous 20 ms sleeps and calls `XCTFail` at the deadline before returning false. Ignoring its Boolean return with `_ =` therefore does not silently pass on timeout; both adapted call sites also retain their post-wait state assertions. This adaptation establishes bounded eventual behavior, not an exact animation/frame-performance timing claim. The 240/200 ms production duration contract remains governed by the unchanged motion source and its separate tests.

### Evidence limits

Main reports full r2 executed 2809 tests with two assertion failures in the style/entrance test before these adaptations. The narrow fixed margin over the 240 ms entry and the additional asynchronous queue drain are consistent with the inspected source; this reviewer did not independently reproduce or inspect raw execution output to establish scheduling as the sole cause. Main reports focused r5 running and plans to rerun full/build/package verification. No r5 success or repaired final candidate is inferred. The reported stage inventory is now ten changed files / 464 total; this was not a broad-diff review or independent inventory certification.

Reviewer performed source reads and hash checks only, appended only this report, and executed no tests, build or UI. Native visual, physical gesture/flash and performance acceptance remain outside this verdict.

### R3 input fingerprints

| File | SHA-256 |
| --- | --- |
| `Sources/AppGridUI/FolderMotion.swift` | `d9db540dd7a67aadcf25700b540a6b4e30b421e3de3f256b4ce612921dc5ce90` |
| `Sources/AppGridUI/FolderOverlayView.swift` | `e91e50e70beb81220e5ff026d4c99b3fea491101694ed393dec2a11adc4da289` |
| `Sources/AppGridUI/AppGridCellView.swift` | `eb38dce836c0214fd6a29ccf4f8fa4c1946e1cd5cc8ac61104c24b9d5339195a` |
| `Sources/PagingPrototypeApp/AppDelegate.swift` | `82f4a00a4561069a1ca16f7b62f29037f600de55b06b85af55d457ea0730a918` |
| `Sources/PagingPrototypeApp/AppCatalogAssembly.swift` | `8174fe17c95454b75df5fd09f2d6b7ac2eef8c0f54b65d20cf4c7da3c6c8111b` |
| `Tests/PagingUITests/AppDelegateBoundedRegressionTests.swift` | `97ba2b8d2711c2cbae64325fcf8f311ed04f473097e394168ce633d2946fc195` |
| `Tests/PagingUITests/IconTypographyOwnerTests.swift` | `ea16dcc2a2e4d4d8424fe17a1960ea420129ae172d904f8b2f8d488aaeaa8450` |
| `Tests/PagingUITests/AppContentTestSupport.swift` (existing helper, read only) | `37738c700abe9aa2652a199b32e3a90d6b207db064f5109dd655c8dbbdd2deaa` |

Next action: Main finishes verification for these test hashes and the unchanged R2 production hashes. No production repair is requested by R3.
