# T-1J-LM — Reviewer r2 (HITREVERT repair verification)

- Role: Independent Reviewer r2 → Main
- Verdict: **PASS**
- Date: 2026-09-17
- Declared model: glm-5.2-max (high)
- Reviewed against: `Workflow/reviews/T-1J-LM-r1.md` (FAIL, finding M1 + minors m1–m3),
  `Workflow/tasks/T-1J-LM-HITREVERT.md`, `Workflow/decisions/D-1J-HIT-REGION-REVERT.md`,
  `Workflow/results/T-1J-LM-HITREVERT.md`, `Workflow/artifacts/T-1J-LM-HITREVERT/`
  (fail-before.log, focused-after.log, build-debug.log), and the current dirty worktree
  diff `git diff bddb0fa -- Sources/ Tests/ Docs/` (uncommitted repair on top of `bddb0fa`).
- Method: read-only independent review. This Reviewer inspected the full worktree diff of
  every changed file, re-derived the hit geometry from fixture constants, traced both
  shared-contract consumers' coordinate spaces, verified artifact log counts against the
  Worker's claims, and ran one serialized focused `swift test --filter` invocation
  (40 XCTest cases, 0 failures) on the current tree. No implementation or test file was
  edited; no git write was performed; no prohibited path was read. r1's other slice
  criteria (grid geometry, folder motion, wiring, Terra fixes, packaging) were not
  re-litigated — they were verified PASS in r1 and the repair diff does not touch them;
  spot-check only.

## Summary

The M1 repair is correct, bounded, and verifiably executed. `acceptsLaunchHit(at:)` once
again implements the user-accepted icon±4pt contract — `iconFrame.insetBy(dx: -4, dy: -4)`
with `iconFrame = isFolderCell ? folderSymbolView.frame : iconView.frame`
(`AppGridCellView.swift:229-232`) — inside the retained unified-contract structure that the
B1 work introduced. `hitTest` keeps the superview-space `frame.contains` gate, the
`convert(point, from: superview)` to receiver-local, and the detached-cell local-space
fallback (:212-221). Comments at :207-211 and :223-228 plus the file-header line now state
the real contract (icon/folder-symbol ±4pt, NOT whole-cell).

Both shared-contract consumers are coordinate-consistent under the restored contract:
`AppLaunchController.handleClick` (:113-130) converts the surface-local click to the
surface's superview space for `surface.hitTest`, then converts to cell-local
(`cell.convert(point, from: surface)`) before `acceptsLaunchHit` — a label/padding point
yields `.rejectedNoBinding`, never `handleCell`. `blankClickResolvesToCell(_:at:in:)`
(:2240-2270) converts the contentView-local point to cell-local before the same gate —
under icon±4 the cell's `hitTest` returns nil for non-icon points so the hit chain carries
no `AppGridCellView` ancestor (→ false → blank/terminate path), and the point-level gate
independently returns false even if a cell were forced as the hit. Behavior verified by
test, not just inspection.

Tests were realigned, not deleted/skipped/loosened: `testHitTestAtNameLabelMissesCell` and
`testHitTestAtCellPaddingMissesCell` now assert MISS at both cell-level and window-level
hitTest; `testHitTestAtIconCenterReturnsCell` gained a ±4 padded-edge positive assertion
(icon maxX+3 hits); new `testFolderCellHitTestUsesFolderSymbolFrame` covers the folder
branch; `AppLaunchControllerTests` gained `testClickAtNameLabelRejectedNoBinding`;
`BlankClickToQuitTests` gained `testCellInteriorNonIconPointsClassifyAsBlank` on a
realistic 88pt cell. No `…ReturnsCell` assertion survives for a non-icon point. No
`XCTSkip`/disable markers in the touched files.

All three falsified docs now record the violated-then-restored history with dated
postscripts/annotations (`PHASE1J_FAILURE_TRIAGE.md:33-44`,
`PHASE1J_CHECKPOINT.md:126`, `PHASE1J_REPORT.md:30-34`); none claims continuous
preservation. m1 received the explicit consume-site comment at `AppDelegate.swift:983-988`;
m2 is recorded in the Worker closeout; m3 untouched per decision.

Worker evidence is genuine: the fail-before log shows the realigned assertions failing
against the pre-repair whole-cell code (40 executed / 11 assertion failures), and the
focused-after log shows the packet's wide filter passing (170 executed / 0 failures). This
Reviewer's own serialized run of
`swift test --filter 'Bug9CellHitRoutingTests|AppLaunchControllerTests|BlankClickToQuitTests'`
on the current tree: **40 executed, 0 failures, exit 0** — the identical suite that
produced 11 failures pre-repair.

## Findings

### BLOCKER

None.

### MAJOR

None. **M1 is verifiably resolved** (see acceptance table and diff checks below).

### MINOR

- **m2-1 (doc-truth boundary, pre-existing):** `Docs/ADR-006-KEYBOARD-FOCUS.md:122` and
  `Docs/PHASE1C_REPORT.md:22` describe the Phase-1C blank-click classifier as
  "cell/icon/label → `super.sendEvent` 透传". Under the restored icon±4 contract a
  name-label click classifies blank again, so those sentences are stale. This staleness
  predates the repair (it was already inaccurate at baseline `6382bd9`, briefly accurate
  under `bddb0fa`'s whole-cell interval, inaccurate again now), the files are historical
  Phase-1C records outside the packet's named doc scope, and the packet's reconciliation
  requirement (the three Phase-1J docs) is fully met. Recommend — at Main's discretion — a
  dated correction per the project rule against silent history rewrite; not a blocker for
  this verdict.

### QUESTION / BOUNDARY

- **Q1 (Worker escalation, answered — not a finding):** `FolderOverlayView` member
  activation inside an open folder panel uses whole-member-cell `cell.frame.contains`
  (`FolderOverlayView.swift:381` activation, `:407` drag-source routing). This is **outside
  the icon±4 contract's scope** and is not M1 material:
  - The icon±4 contract is the *top-level grid launch hit target* whose miss consequence is
    the blank-click→quit classification (`blankClickResolvesToCell` /
    `handleClick → rejectedNoBinding`). Every written preserve and the D-1J decision describe
    that contract: "Clicking a name label or cell-interior padding misses the cell and
    resolves to the existing blank-click path" (`D-1J-HIT-REGION-REVERT.md:10-12`).
  - The overlay member path is a different, modal contract — "panel-outside → close;
    member cell → activate; panel non-member → ignore" (`FolderOverlayView.swift:372-390`)
    — bound up with member row-band semantics the Phase-1J plan separately preserved
    (`PHASE1J_LAYOUT_MOTION_PLAN.md:42`).
  - It is **baseline-unchanged**: `git show 6382bd9` already enumerates
    `memberCells where cell.frame.contains(panelPoint)` (baseline :312, :337); neither
    `bddb0fa` nor this repair touched the file (`git diff bddb0fa` shows no
    `FolderOverlayView.swift` change).
  - Member cells are `AppGridCellView`s but the overlay never calls their
    `hitTest`/`acceptsLaunchHit` — it manually enumerates frames — so the restored contract
    does not even participate in that path.
  If the user intends icon±4 for folder-member activation too, that is a new product
  decision (the member cells' geometry/row-band contract would need re-specification);
  the Worker correctly reported it as boundary material rather than silently expanding
  scope. Recommend Main log it as an open user question alongside the Track-B manual
  gates, not as a defect.
- **Q2 (unchanged from r1):** GUI/physical gates — including the newly-relevant physical
  boundary check "cell gaps and label/padding still classify blank→quit; icon±4 hits
  launch" (explicitly deferred by `D-1J-HIT-REGION-REVERT.md:35`) — remain user/Main-owned;
  this verdict does not certify them.
- **Q3:** This Reviewer ran 40 focused XCTest cases plus log-verified the Worker's 170/0
  focused run; the full suite remains Main's evidence and formal re-execution is
  Main-owned.

## Acceptance verification

| Criterion (packet / decision / r1 finding) | Result | Evidence |
|---|---|---|
| `acceptsLaunchHit(at:)` = padded icon frame (folder: `folderSymbolView`), receiver-local point | PASS | `AppGridCellView.swift:229-232`; verified icon slot `iconSide=48` at `layout()` :237-241 |
| `hitTest` keeps superview-space conversion + detached-cell fallback; no second click path | PASS | `AppGridCellView.swift:212-221` (`frame.contains` gate in superview space → `convert` → local `acceptsLaunchHit`; detached → local `acceptsLaunchHit`) |
| Comments/file-header state the real contract (icon±4, not whole-cell) | PASS | `AppGridCellView.swift:4,207-211,223-228` |
| `handleClick` coordinate space consistent; label/padding → `rejectedNoBinding`, not `handleCell` | PASS | `AppLaunchController.swift:113-130` (surface→superview for `hitTest`; `cell.convert(point, from: surface)` for the gate); `testClickAtNameLabelRejectedNoBinding` passes |
| `blankClickResolvesToCell` coordinate space consistent; label/padding → blank classification | PASS | `AppDelegate.swift:2240-2268` (`cell.convert(point, from: rootView)` at :2246-2248); call site :2014 passes contentView-local point; `testCellInteriorNonIconPointsClassifyAsBlank` passes |
| `appGridCellAncestor` / `blankClickResolvesToInteractionZone` untouched | PASS | `git diff bddb0fa` on `AppDelegate.swift` contains ONLY the 6-line m1 comment; functions at :2223-2238 unchanged |
| Bug9 tests realigned to icon±4 (label/padding assert MISS; `…MissesCell` coverage exists) | PASS | `Bug9CellHitRoutingTests.swift:138-189` (`testHitTestAtNameLabelMissesCell`, `testHitTestAtCellPaddingMissesCell`, `testFolderCellHitTestUsesFolderSymbolFrame`); `:117` icon-center + padded-edge positive; `testHitTestOutsideCellMissesCell` :192 and `testNestedCellDescendantResolvesToOwningCell` intact |
| No `…ReturnsCell` assertion survives for non-icon points | PASS | grep: only `testHitTestAtIconCenterReturnsCell` remains; all `nameLabel`/padding references are inside miss-assertions |
| No tests deleted/skipped/loosened | PASS | No `XCTSkip`/disable markers; renamed tests keep equal-or-stronger assertion bodies (miss asserted at cell AND window level); net +3 test methods |
| `AppLaunchControllerTests` icon-center launches; label rejected | PASS | `testClickHitPathReachesCell` now clicks `iconView` mid (:115); `testClickAtNameLabelRejectedNoBinding` :127-155 asserts `.rejectedNoBinding` + zero launches — both pass in my run |
| `BlankClickToQuitTests` interior non-icon → blank | PASS | `testCellInteriorNonIconPointsClassifyAsBlank` :208-233 (88pt cell; icon mid → cell; label mid → blank via real `hitTest` AND forced-hit point gate; padding → blank) — passes |
| Docs truth: violated-then-restored recorded; no continuous-preservation claim survives | PASS | `PHASE1J_FAILURE_TRIAGE.md:33-44` dated postscript; `PHASE1J_CHECKPOINT.md:126` inline annotation `(whole-cell in commit bddb0fa → r1 FAIL M1 → restored 2026-09-16 per D-1J-HIT-REGION-REVERT)`; `PHASE1J_REPORT.md:30-34` postscript under Track-A table |
| m1 consume site/comment at `AppDelegate.swift` ~:983-988 | PASS | Comment block added at :983-988 inside `openFolder(_ identity:)` documenting one-shot pointer-attribution token semantics; zero behavior change (diff = comment only) |
| m2 recorded in Worker result | PASS | `Workflow/results/T-1J-LM-HITREVERT.md:113-119` closeout section |
| Fail-before evidence (≥1 focused assertion fails pre-repair, passes after) | PASS | `artifacts/T-1J-LM-HITREVERT/fail-before.log`: realigned tests run against pre-repair whole-cell code → 40 executed / 11 assertion failures (`XCTAssertNil failed: "<AppGridCellView…>"` on label/padding; `("launched") is not equal to ("rejectedNoBinding")`); all pass after — independently confirmed by my 40/0 run |
| Focused wide filter exit 0, nonzero executed, real counts | PASS (worker's evidence, log-verified) | `focused-after.log`: `Executed 170 tests, with 0 failures` on the packet's 15-suite filter; `build-debug.log`: `Build of target 'PagingPrototypeApp' complete!` |
| Regression scope: only packet-scoped files changed vs `bddb0fa` | PASS | `git diff bddb0fa --name-only -- Sources/ Tests/` = `AppGridCellView.swift`, `AppDelegate.swift`, `Bug9CellHitRoutingTests.swift`, `AppLaunchControllerTests.swift`, `BlankClickToQuitTests.swift` — all in allowed write scope; `AppLaunchController.swift` correctly unchanged (conversion already correct) |
| Forbidden areas untouched (PagingCore, PagingUI physics, `Timer.tolerance`, Package.swift, LayoutStore, wallpaper, telemetry) | PASS | None appear in the worktree diff; `FolderOverlayView.swift` unmodified |
| r1's other slice criteria not broken by the repair | PASS (spot-check) | Repair diff touches only the hit contract + one comment + tests + docs; geometry/motion/wiring/overlay code unmodified; worker's 170/0 run covers FolderOverlayTests, FolderMotionTests, AppCatalogAssemblyTests, LauncherIntegration/FolderIntegration/DragCommit/Bug10/Bug11/T1FD1/FocusReuse/Forensics suites |

## Baseline and diff checks

- `git status`: dirty worktree on `bddb0fa` (HEAD unchanged, `git log` still
  `bddb0fa → 6382bd9`); modified = the 5 Sources/Tests files + 3 Docs + Workflow runtime
  files (STATE/events/watchdog/stage-summary bookkeeping); untracked = task/decision/
  result/artifact files + r1 review. Matches the claimed repair scope exactly.
- `git diff bddb0fa --stat -- Sources/ Tests/`: 5 files, +134/−19. `git diff --check` clean.
- Fixture geometry independently re-derived: 80×80 test cell, `iconSide=48` → icon
  x∈[16,64], y∈[20,68]; padded hot zone x∈[12,68], y∈[16,72]. Asserted points:
  icon mid (40,44) hit; padded edge (67,44) hit; label mid (40,7) miss; padding (6,76)
  miss — assertions are geometrically correct, i.e. the tests genuinely exercise the
  contract boundary rather than degenerate cases.
- Reviewer re-execution (serialized, read-only, `.build` shared):
  `swift test --filter 'Bug9CellHitRoutingTests|AppLaunchControllerTests|BlankClickToQuitTests'`
  → **Executed 40 tests, 0 failures, exit 0** (2026-09-17 ~17:57). Same suite/count as the
  Worker's fail-before log (40 exec / 11 fail), giving a clean before/after pair on the
  identical filter.
- Worker honesty check: artifact logs match every claimed number (40/11 fail-before,
  170/0 focused-after, build exit 0); the "not changed" claim for `AppLaunchController.swift`
  is confirmed by the diff; the claim that other in-scope test files needed no changes is
  plausible and empirically supported — all their click points are cell/icon/bounds
  mid-points inside the padded icon frame for their fixtures, and the wide filter passed.

## Regression risks (carried forward, user-accepted)

- Under icon±4 a name-label / cell-padding / dead-band click classifies blank → launcher
  dismisses. This is the trade-off the user explicitly re-accepted in
  `D-1J-HIT-REGION-REVERT.md:31-33`; physical boundary verification joins the Track-B
  manual gate list — pending, Main/user-owned.
- Dead band: on a real 88pt cell, y∈(14,24) between the name label top and the padded icon
  bottom is inside the cell but outside the hot zone → blank classification. Consistent
  with the contract; worth covering in the physical gate sweep.
- Folder-member activation remains whole-cell inside the overlay (Q1) — separate baseline
  contract; any change requires a new user decision.

## Evidence boundaries

- Code + artifact + test-execution review. Does not certify GUI behavior, physical input,
  WindowServer delivery, real `NSWorkspace.shared.open`, motion feel, or the manual gates;
  `RC_IMPLEMENTED_MANUAL_PENDING` remains the correct stage label.
- I did not re-run the full suite, release build, or packaging; Main owns those. My
  execution evidence is one serialized 40-case focused run plus verification of the
  Worker's recorded logs.
- Reviewed the dirty worktree as instructed; the repair is uncommitted on `bddb0fa`.
  Whether/when to commit is Main's call.

## Confidence

High. The contract body, both consumers' coordinate spaces, the test realignment, the doc
corrections, and the Worker's evidence were each verified by direct inspection and
independent re-execution; the diff scope is exactly the packet's allowed write set and
nothing else. The only open item (folder-member hit width) is a documented boundary
question, not a defect in this repair.
