# T-1J-LM — Reviewer r1 (Phase 1J layout-motion slice)

- Role: Independent Reviewer → Main
- Verdict: **FAIL**
- Date: 2026-09-16
- Reviewed against: `Workflow/tasks/T-1J-LAYOUT-MOTION.md`, `T-1J-LM-GRID.md`, `T-1J-LM-MOTION.md`, `T-1J-LM-WIRING.md`, `T-1J-LM-VERIFY.md`; `Workflow/decisions/D-1J-LAYOUT-MOTION.md`; `Docs/PHASE1J_LAYOUT_MOTION_PLAN.md`, `Docs/PHASE1J_SPEC.md`, `Docs/PHASE1J_CHECKPOINT.md`, `Docs/PHASE1J_FAILURE_TRIAGE.md`, `Docs/PHASE1J_REPORT.md`, `Docs/PHASE1J_VALIDATION_RESULTS.md`; `Workflow/results/T-1J-LM-{GRID,MOTION,WIRING,VERIFY}.md`; `Workflow/stage-summaries/2026-09-12-phase1j-layout-motion.md`; the committed diff `git diff 6382bd911741831d13360e402c270bb6509b3679..bddb0fa28af3f3c2ab9e7be0bfab9d5497738f03 -- Sources/ Tests/` (30 files, +1619/−149).
- Method: read-only independent review of task packets, decision artifact, worker results, stage summary, validation record, full product/test diff, candidate manifest, and executable hash. This Reviewer ran two serialized focused `swift test --filter` invocations (67 XCTest cases total, 0 failures) to spot-check the new-behavior claims. No implementation source or test file was edited; no git write operation was performed; no prohibited source tree was read.

## Summary

The Phase 1J layout-motion core is implemented correctly and verifiably. `AppGridGeometry` preserves five columns, 88pt cells, 16pt preferred spacing, and gives ordinary pages a shared, vertically centered seven-row envelope so partial pages keep full-page row origins (no page-to-page vertical jump); committed search mode is explicit-state only (`provider.activeQuery`, committed at `AppGridUIPageContentProvider.swift:172`, pending staging untouched). Folder pointer motion is 180ms/0.96/≤8pt ease-out, anchored to the live committed-page Folder cell, with opacity-only identity-transform fallback when source geometry is unreliable; Reduce Motion is a 180ms opacity-only fade with identity transform. The retained exit visual (the real overlay in `isVisualOnly` mode) is genuinely noninteractive — `hitTest` → nil, accessibility stripped, callbacks suspended, late icon writes suppressed — and removal is generation-gated. All three Terra audit findings are verifiably addressed at the claimed locations. PagingCore, `Timer.tolerance`, persistence/LayoutStore, `Package.swift`, and wallpaper-transparency repairs are untouched.

The FAIL is for one finding: the committed diff changes the **launch hit-region contract** — from the user-accepted icon±4pt target to the whole cell bounds — inside the B1 click-routing work, without a recorded Chief/user authorization and in direct contradiction of the plan ("Keep icon-plus-4pt hit regions"), the Chief decision ("without changing … hit regions"), the task-packet constraints ("Do not alter … hit-region contracts"), and the Phase 1J spec's recorded user acceptance ("Icon-only ±4px hit contract is user-accepted for production"). The change is deliberate, unified, and test-covered — and is plausibly the correct product behavior — but several acceptance artifacts now make factually false statements (`icon ±4pt` preserved; `…MissesCell` test disposition), and no decision delta authorizes the reversion. Under the task-packet constraints and the verdict rules, this Reviewer cannot certify PASS until the contract change is either authorized and documented or reverted.

## Findings

### BLOCKER

None.

### MAJOR

**M1 — Launch hit-region contract changed (icon±4pt → whole-cell bounds) without recorded authorization; contradicts five written preserves and falsifies acceptance docs.**

- Baseline (`git show 6382bd9:Sources/AppGridUI/AppGridCellView.swift:211-217`): `hitTest` returned `self` only when the point landed inside the icon frame (or folder symbol frame) inset by −4 — "热区 = 仅图标…外扩 4pt".
- Committed (`Sources/AppGridUI/AppGridCellView.swift:208-227`): `hitTest` returns `self` whenever `frame.contains(point)` and `acceptsLaunchHit(at:)` returns `bounds.contains(point)` — the entire ~88pt-tall tile (icon + name label + interior padding) is the launch target. `acceptsLaunchHit` is also the shared contract consumed by `AppLaunchController.handleClick` (`AppLaunchController.swift:113-124`) and the window-level blank/cell classifier (`AppDelegate.swift:2234-2257`, `blankClickResolvesToCell(_:at:in:)`).
- User-visible delta: under the baseline contract, a click on the name label or interior cell padding missed the cell → classified blank → launcher dismissed. Under the committed contract the same click launches. This is likely the *desired* behavior (it matches the original BUG9 wave-a funnel "点在 bounds 内恒返回 self" per `Workflow/BUG10-CODEX-HANDOFF.md:40,60`, and fixes a real misclassification), but it is a contract change, not a preserve.
- Contradicted artifacts: `Docs/PHASE1J_LAYOUT_MOTION_PLAN.md:42` ("Keep icon-plus-4pt hit regions and member row-band semantics unchanged"); `Workflow/decisions/D-1J-LAYOUT-MOTION.md:10` ("without changing … hit regions"); `Workflow/tasks/T-1J-LAYOUT-MOTION.md:24` ("Do not alter … hit-region contracts"); `Workflow/tasks/T-1J-LM-GRID.md:29` ("no … hit-padding change"); `Docs/PHASE1J_SPEC.md:44` ("Icon-only ±4px hit contract is user-accepted for production").
- Falsified acceptance records: `Docs/PHASE1J_FAILURE_TRIAGE.md:15-16,22-24` claims tests 4–5 were "Renamed/rewrote → `…MissesCell`" and that "icon (±4pt) launch hit target" was preserved — no `…MissesCell` tests exist in the committed tree (committed names: `testHitTestAtCellPaddingReturnsCell`, `testHitTestOutsideCellMissesCell`, `testHitTestAtNameLabelReturnsCell`, all asserting whole-cell hits); `Docs/PHASE1J_CHECKPOINT.md:126` and `Docs/PHASE1J_REPORT.md:23-27` likewise record "hit = icon±4" / "icon ±4pt launch hit" preserved.
- No authorization found: `Workflow/decisions/`, `Workflow/events.jsonl` (all post-2026-09-11 events), `MEMORY.md`, `Docs/PHASE1J_CODEX_LAYOUT_MOTION_HANDOFF.md`, and the stage summary contain no decision approving the hit-target reversion. `Workflow/BUG10-CODEX-HANDOFF.md:81` explicitly lists cell-interior-blank semantics as an **open user question** ("用户点格内空白应关夹/无操作还是退出？（行为规格问题）"); the committed code answers it (cell interior = launch) without a recorded answer.
- The icon±4 narrowing itself dates to 2026-09-11 (baseline comment) and sits inside the same BUG9/BUG10/B1 workstream; the whole-cell restoration is coherent with the B1 manual-delivery repair (`appGridCellAncestor`, `lastManualMouseDownCell`, interaction-zone split at `AppDelegate.swift:2211-2262`) that this slice was tasked to preserve/repair. Plausible authorization exists in intent — it is simply not in the artifacts, and the reviewer verdict must be artifact-verifiable.

### MINOR

**m1 — `pendingPointerFolderID` can leak pointer attribution across a different-folder keyboard open.** `AppDelegate.swift:982-988`: `openFolder(_ identity:)` consumes the pending ID only when `pendingPointerFolderID == folderID`. Sequence: pointer-click folder A (pending = A) → keyboard-open folder B (pending stays A because B ≠ A and `cancelFolderVisualTransition` clears it only when called) → keyboard-open A later → `pointerTriggered` is true and A animates a pointer entrance on a keyboard trigger. `cancelFolderVisualTransition()` does clear `pendingPointerFolderID` and runs at the top of every `openFolder(folderID:)`, so the leak is actually narrower than it first appears — it survives only if a folderID-mismatched `openFolder(_ identity:)` is invoked *before* the next `openFolder(folderID:)` call, which currently cannot happen because `openFolder(_ identity:)` is the sole caller of `openFolder(folderID:)` and always cancels first. Net effect: the flag is cleared on every open path, so the residual risk is a same-folder re-open attribution edge only. Minor; worth a comment or a dedicated consume site.

**m2 — `rebuildFolderCompositionIfNeeded` now prefers `provider.pendingSnapshot ?? provider.servedSnapshot`** (`AppCatalogAssembly.swift:434-445`). This is a behavioral change beyond the packet's stated mode/anchor scope (though inside the allowed file), made to fix a real ordering defect — first async scan leaves the catalog pending, so folder composition previously waited a cycle. Covered by `testAsyncFirstScanStagesFolderBeforeIdleCommit`. Acceptable bounded repair; noted because it widens the semantic surface (pending base → committed folder generation) and should be listed in the closeout record.

**m3 — Pre-existing Sendable warning** at `Sources/PagingPrototypeApp/AppDelegate.swift:1473-1474` (`diagBackend` captured in `@Sendable` Timer closure) remains, as recorded; unchanged by this slice.

### QUESTION / BOUNDARY

- **Q1 (blocking until answered):** Was the whole-cell launch hit target authorized — e.g., as part of the user-verified B1 manual-delivery repair or a later verbal decision? If yes, the resolution is documentation: record the decision delta and reconcile `PHASE1J_FAILURE_TRIAGE.md`, `PHASE1J_CHECKPOINT.md:126`, and `PHASE1J_REPORT.md`. If no, restore icon±4 in `acceptsLaunchHit` and realign the Bug9/B1/AppLaunchController test expectations per the triage policy.
- **Q2:** GUI/physical gates (real WindowServer delivery, pointer Folder motion feel, Escape-during-motion, drag regression, Reduce Motion feel, hide/resize/screen-change under live animation, real `NSWorkspace.shared.open`) are outside this Reviewer's verdict — they remain user/Main-owned per `RC_IMPLEMENTED_MANUAL_PENDING`.
- **Q3:** This Reviewer spot-ran 67 focused XCTest cases (see below), not the full suite. The claimed 1553/0 full-suite run is Main's evidence; formal full-suite re-execution remains Main-owned.

## Acceptance verification

| Criterion (task packet / plan / decision) | Result | Evidence |
|---|---|---|
| GRID: 0/1/5/6/34/35 items, ordinary/search modes, partial pages, viewport classes, nonzero origins | PASS (covered by helper + tests; 6-item partial uses ordinary 7-row envelope; empty → nil frames; small/large regions tested) | `AppGridGeometry.swift:22-25,28-41`; `AppGridGeometryTests.swift` (4 tests, verified passing) |
| GRID: no negative dimensions, no capacity/hit-padding/paging change | PARTIAL → FAIL on hit-padding (see M1); capacity 5×7/35 and 88pt/16pt preserved; nil frame instead of negative dims | `AppGridGeometry.swift:16-25`; hit change at `AppGridCellView.swift:216-227` |
| GRID: cell frames remain the source for focus/hit/drag | PASS | `AppGridPageView.swift:285-291` sets `cell.frame`; `cell(at point:)`/`dragItemFrames` consume `cell.frame`/`cell.bounds` (:76-96) |
| MOTION: pointer/keyboard/lifecycle/RM/missing-source/reversal/stale/A-to-B/hide/resize/teardown deterministic | PASS at code+test level | `AppDelegate.swift:1052-1189`; `FolderMotion.swift`; `FolderMotionTests` (8), `FolderOverlayTests` (14) verified passing |
| MOTION: exit visuals noninteractive, inaccessible, memory-only, bounded, generation-gated | PASS | `FolderOverlayView.swift:559-560` (`hitTest`→nil), `setVisualOnly` AX stripping (:247-292), callback suspension, icon-write suppression (:655); `FolderMotionGate.accepts`; `cancelFolderVisualTransition` `AppDelegate.swift:1165-1189` |
| MOTION: no post-teardown callback mutates UI; no input/drag block | PASS (guards on `isTornDown`/`isVisualOnly`; visual is inert) | `FolderOverlayView.swift:298,377,398,428,449,459,475,507,560,576,581,655` |
| WIRING: pending search input cannot change visible layout; committed can | PASS | `AppCatalogAssembly.swift:180-186,401-403` reads `activeQuery` (commit-only at `AppGridUIPageContentProvider.swift:172`); test `testRendererLayoutModeTracksOnlyCommittedSearchQuery` verified |
| WIRING: pointer open/close anchored; keyboard/Escape/Command-F/hide/move-out/teardown immediate | PASS | `AppDelegate.swift:982-1000,1010-1012,1016-1050`; `openFolderFromClick`→`onOpenFolder` chain (`KeyboardFocusController.swift:289-300`) |
| WIRING: logical close + drag-host restore precede exit visual; no residual hit/AX surface | PASS | `AppDelegate.swift:1016-1050` order (prepare visual → clear proxy/drag/title/state → `refreshFolderOverlay` → animate); `refreshFolderOverlay` exit-visual branch :1280-1291 |
| LAYOUT-MOTION constraints: preserve dirty tree, no physics/tolerance/persistence/hit-region/wallpaper/provenance changes | FAIL on hit-region contract (M1); all others preserved | `git diff --stat`: `Sources/PagingCore`, `PagingUI` physics files, `LayoutStore/`, `Package.swift` untouched; tolerance machinery unchanged (`PagingFrameDriver.swift` not in diff) |
| D-1J §2: source cell resolved by FolderID from committed page, converted after overlay layout | PASS | `AppCatalogAssembly.swift:198-210` (`committedPageProvider` + live `convert`); `AppDelegate.swift:455-457` wiring |
| D-1J §3: pointer 180ms/0.96/≤8pt ease-out; keyboard/lifecycle immediate; RM = opacity-only identity | PASS | `MotionParams.standard/.reduceMotion` (`FolderOverlayView.swift:48-50`); `entryTransform` identity fallback (`FolderMotion.swift:96-111`); `animateFolderLayer` easeOut (`AppDelegate.swift:1199-1213`) |
| Terra finding 1: missing source → opacity-only identity entrance | PASS | `AppDelegate.swift:1055-1077` (optional `sourceFrame`; `entryTransform`→`.identity` when nil/unreliable); `FolderMotionTests.testMissingSourceFrameFallsBackToOpacityOnlyIdentityTransform` |
| Terra finding 2: no retained exit visual without reliable anchor | PASS | `AppDelegate.swift:1098-1104` (`isReliableSourceFrame` guard → `cancelFolderVisualTransition()` → synchronous close); `FolderMotionGeometry.isReliableSourceFrame` requires finite, positive, intersecting frames |
| Terra finding 3: screen change cancels Folder visual transitions before target refresh | PASS | `AppDelegate.swift:1456-1458` + `ActivationComposition.swift:333-338` (`onScreensChanged?()` invoked before `targetScreen` re-resolve); `LauncherIntegrationTests.testScreensChangedNotifiesHostBeforeTargetScreenRefresh` |
| Historical landmine: retained exit visual cannot revive click-occlusion | PASS | `hitTest`→nil while `isVisualOnly` (`FolderOverlayView.swift:559-560`); generation-gated removal (`AppDelegate.swift:1145-1162`); cancelled on reopen/hide/resize/screensChanged/teardown/launcherDidHide (:364,993,1457,1593,1710,1740) |
| VERIFY: nonzero focused + full tests; baseline drift explained | Consistent (Main's evidence; spot-verified) | Claimed 1553/0 (2026-09-13 07:11) and 94/0 focused; baseline drift 1530→1553 explained by added Phase 1J tests. This Reviewer re-ran 67 focused cases, 0 failures |
| VERIFY: debug + release builds PASS; `git diff --check` PASS | Consistent (not re-run by Reviewer) | `Workflow/results/T-1J-LM-VERIFY.md` records exit 0 for both builds |
| VERIFY: fresh unique candidate, SHA recorded, no overwrite/sign/install | PASS | `.build/candidates/phase1j-rc-20260913-1212-final/Launchcopy.app` exists; `shasum -a 256` on `Contents/MacOS/Launchcopy` = `0e1bba9a00a4eee5bc6602d681e8b59950dba45a4a1dbb9cbe7d56351bd9f8d1` (matches claim); manifest `git_head=6382bd9`, `git_dirty=69`, release; prior candidates intact |
| VERIFY: SELFDRIVE synthetic run | Consistent | Recorded `flings=40 committed=30 stales=10 live=5 pool=0 layouts=19 telemetryEvents=0` + clean `teardownAll`; plausible against the committed binary |

## Baseline and diff checks

- `git log`: `bddb0fa` (2026-09-16, "Phase 1J layout-motion implementation + workflow artifacts + role reconfiguration") is a direct child of `6382bd9` ("Initial public import"). The committed product diff therefore bundles this slice with pre-existing dirty-tree work (wallpaper occlusion/cell-fill repairs already separately reviewed `T-WALLPAPER-OCCLUSION-r1` PASS and `T-WALLPAPER-CELL-FILL` PASS_USER_REPORTED; BUG9/BUG10/B1 routing lineage; Track-A fixture alignments documented in `PHASE1J_FAILURE_TRIAGE.md`).
- Untouched as required: `Sources/PagingCore/`, `Sources/PagingUI/` physics files (incl. `PagingFrameDriver.swift` — `Timer.tolerance` default 0ms unchanged), `Sources/AppCatalogCore/`, `Sources/MacAppCatalog/`, `Sources/AppIconPipeline/`, `Sources/PagingTelemetry/`, `Sources/AppGridUI/LayoutStore/`, `Package.swift`, `LauncherWindowController.swift`.
- Test changes do not conceal product regressions: Track-A fixture repairs (row-band Y separation in `Bug10PreviewHostTests`/`Bug11RowBoundaryIndicatorTests`/`DragCommitIntegrationTests`, durable-icon assertion in `T1FD1FixUITests`) match the triage dispositions and add replacement coverage (`testFolderMemberInsideRowBandStaysInsertionEvenWhenArmed`, `testHitTestOutsideCellMissesCell`, `testNestedCellDescendantResolvesToOwningCell`).
- Reviewer re-execution (serialized, read-only): `swift test --filter 'AppGridGeometryTests|FolderMotionTests|Bug9CellHitRoutingTests'` → 20 tests, 0 failures; `swift test --filter 'AppCatalogAssemblyTests|FolderOverlayTests|FolderIntegrationTests'` → 47 tests, 0 failures. Both exited 0 on committed `bddb0fa`.
- `git status`: worktree effectively clean except `Workflow/watchdog.json` (runtime file).

## Likely root cause (of M1)

The B1 top-level click repair unified three consumers (AppKit `hitTest`, the window-level blank/cell classifier, and `AppLaunchController`) behind a single `acceptsLaunchHit` contract, and restored the pre-2026-09-11 whole-cell funnel — probably because icon±4 made label/padding clicks classify as blank → launcher dismissal, a real defect once B1 delivery works. The contract change was then carried into the Phase 1J commit without a decision delta, and the earlier triage/checkpoint/report docs that recorded icon±4 as accepted were never reconciled.

## Recommended solution (recommendation only — not repair authorization)

1. Main escalates M1 to Chief/user: explicitly decide the launch hit target (whole-cell vs icon±4). Whole-cell is the behavior the committed tests assert and is consistent with the BUG9/B1 lineage; icon±4 is what the Phase 1J spec/plan/decision/packets preserve.
2. If whole-cell is approved: record a decision delta; update `PHASE1J_FAILURE_TRIAGE.md` (dispositions 4–5 and "accepted contracts" list), `PHASE1J_CHECKPOINT.md:126`, `PHASE1J_REPORT.md` Track-A table; then this finding downgrades to closed and the slice can re-review PASS.
3. If icon±4 is restored: revert `acceptsLaunchHit` to the padded icon frame, realign `Bug9CellHitRoutingTests` (`…MissesCell` variants per triage), `AppLaunchControllerTests`, and the B1 classifier call site; keep the `appGridCellAncestor`/`blankClickResolvesToInteractionZone` structure, which is orthogonal to the hit width.
4. Address m1 (pointer-attribution consume site) opportunistically; record m2 in closeout.

## Affected scope

`Sources/AppGridUI/AppGridCellView.swift` (`hitTest`/`acceptsLaunchHit`), `Sources/PagingPrototypeApp/AppLaunchController.swift` (`handleClick` coordinate fix + launch-hit gate), `Sources/PagingPrototypeApp/AppDelegate.swift` (`blankClickResolvesToCell(_:at:in:)`, `appGridCellAncestor`, B1 delivery target), plus the asserting tests. The Folder motion, grid geometry, and Terra-fix code are unaffected by M1 and individually verified.

## Regression risks

- If the finding resolves toward icon±4: B1 manual delivery + classifier must be re-checked for label-click dismissal (the defect whole-cell fixed).
- If it resolves toward whole-cell approval: users clicking cell-interior padding now launch instead of dismiss — the intended behavior per the committed tests, but a user-visible contract change that must be explicitly accepted; `blankClickResolvesToCell`/`acceptsLaunchHit` boundary (cell gaps still blank → quit) should be physically re-verified on the candidate.
- Docs-only risk: stale `icon±4` claims in three Phase 1J docs could mislead later slices (e.g., a future worker "restoring" a contract that was deliberately changed).

## Evidence boundaries

- This is a code + artifact review. It does not certify GUI behavior, physical input, real `NSWorkspace.shared.open`, WindowServer delivery, motion feel, or the A–D manual gates; `RC_IMPLEMENTED_MANUAL_PENDING` remains correct and no `LOCAL_RC_VALIDATED` claim is endorsed here.
- I did not re-run the full suite, debug/release builds, packaging, or `git diff --check`; those are Main's recorded evidence. I did re-run 67 focused XCTest cases (all passing) and independently verified the candidate executable SHA-256.
- The FAIL concerns authorization/evidence consistency of the hit-region change, not the quality of the layout-motion implementation, which verified clean.

## Confidence

High on the finding (diff and doc contradictions are directly verifiable) and on the layout-motion implementation passing its own criteria. Moderate on impact severity: the hit change may prove to have been authorized verbally or to be the user's intended end state, in which case this FAIL resolves via documentation rather than code.
