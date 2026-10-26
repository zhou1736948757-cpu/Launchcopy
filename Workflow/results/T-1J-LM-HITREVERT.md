# T-1J-LM-HITREVERT — Worker result

- Role: Worker (declared `swe-2-max`, medium) → Main
- Task: `Workflow/tasks/T-1J-LM-HITREVERT.md` — repair Reviewer r1 FAIL finding M1
  (`Workflow/reviews/T-1J-LM-r1.md`) per user decision
  `Workflow/decisions/D-1J-HIT-REGION-REVERT.md`
- Date: 2026-09-17
- Status: **DONE**

## Summary

Restored the user-accepted **icon±4pt launch hit-region contract** inside the unified
`acceptsLaunchHit(at:)` shared-contract structure that the Phase 1J B1 click-routing work
had widened to whole-cell `bounds.contains` without authorization. Only the contract body
reverted; `hitTest` keeps its unified structure (detached-cell fallback → local-space
`acceptsLaunchHit`; attached path → `frame.contains` pre-filter → superview→local convert →
`acceptsLaunchHit`), and `appGridCellAncestor` / `blankClickResolvesToInteractionZone` /
`blankClickResolvesToCell` are untouched (orthogonal to hit width). Tests asserting
whole-cell semantics were realigned to icon±4 (label/padding/point misses + explicit
blank-path classification); falsified docs received dated postscripts stating the
violated-then-restored history. Minors: m1 got an explicit consume-site comment; m2 is
recorded in Closeout below.

## Changed files

| File | Change |
|---|---|
| `Sources/AppGridUI/AppGridCellView.swift` | `acceptsLaunchHit(at:)` body → `iconFrame.insetBy(dx: -4, dy: -4).contains(point)` where `iconFrame = isFolderCell ? folderSymbolView.frame : iconView.frame` (receiver-local point). Doc comments on `hitTest`/`acceptsLaunchHit` and the file-header line now state the real contract (icon/folder-symbol ±4pt, NOT whole-cell). Detached-cell `hitTest` fallback and `frame.contains` gate kept. |
| `Sources/PagingPrototypeApp/AppDelegate.swift` | m1 only: explicit consume-site comment for `pendingPointerFolderID` at `openFolder(_ identity:)` (:987-994 area) — documents it as a one-shot pointer-attribution token set solely by `handleFolderCellClick`, read-and-cleared here, mismatch → dropped (`pointerTriggered = false`), plus `cancelFolderVisualTransition()` clearing it at the top of every `openFolder(folderID:)` path so keyboard/other-folder opens cannot inherit stale pointer attribution. No behavior change. |
| `Tests/AppGridUITests/Bug9CellHitRoutingTests.swift` | `testHitTestAtNameLabelReturnsCell` → **`testHitTestAtNameLabelMissesCell`** (asserts `hitTest` nil at label mid + window-level non-routing); `testHitTestAtCellPaddingReturnsCell` → **`testHitTestAtCellPaddingMissesCell`** (same for padding point (6, maxY-4)); `testHitTestAtIconCenterReturnsCell` kept + added ±4 padded-edge positive assertion (icon maxX+3 hits); added `testFolderCellHitTestUsesFolderSymbolFrame` (folder symbol area hits, folder label misses); header/MARK comments restate icon±4. `testHitTestOutsideCellMissesCell` and `testNestedCellDescendantResolvesToOwningCell` semantics untouched. |
| `Tests/PagingUITests/AppLaunchControllerTests.swift` | `testClickHitPathReachesCell` click point moved from `nameLabel` mid to `iconView` mid (per triage disposition #1 "click icon center"); launch→`handleCell` validation chain unchanged. Added `testClickAtNameLabelRejectedNoBinding` asserting a label click yields `.rejectedNoBinding` and zero launches (label does not reach `handleCell`). |
| `Tests/PagingUITests/BlankClickToQuitTests.swift` | Added `testCellInteriorNonIconPointsClassifyAsBlank` — on an 88pt cell: icon-mid point → `blankClickResolvesToCell(_:at:in:)` true (pass-through); nameLabel mid and interior padding points → false via real `root.hitTest` (miss) AND via the point-level `acceptsLaunchHit` gate when `hit` is forced to the cell. Locks "label/padding clicks classify through the blank path". Single-arg classifier tests (`testCellNameLabelSubviewIsCell` etc.) untouched — they assert hit-view-chain classification, orthogonal to hit width. |
| `Docs/PHASE1J_FAILURE_TRIAGE.md` | Appended dated **2026-09-16 postscript**: states icon±4 was committed-violated to whole-cell in `bddb0fa` (r1 FAIL M1) and restored 2026-09-16 per D-1J-HIT-REGION-REVERT; dispositions 4–5 are now literally true (MissesCell names exist). Historical table left intact, not silently rewritten. |
| `Docs/PHASE1J_CHECKPOINT.md` (:126) | "hit = icon±4" cell annotated: `(whole-cell in commit bddb0fa → r1 FAIL M1 → restored 2026-09-16 per D-1J-HIT-REGION-REVERT)` — no claim of continuous preservation. |
| `Docs/PHASE1J_REPORT.md` (Track-A table) | Added dated postscript under the "Contract preserved" table: icon±4 was violated by `bddb0fa` then restored 2026-09-16; the table describes the 2026-09-11 Track-A state. |
| `Workflow/artifacts/T-1J-LM-HITREVERT/` | New: `fail-before.log`, `focused-after.log`, `build-debug.log`. |

**Not changed (verified no need):** `Sources/PagingPrototypeApp/AppLaunchController.swift` —
the `handleClick` gate at :113-124 already converts the surface-local click point via
`cell.convert(point, from: surface)` to receiver-local before calling
`acceptsLaunchHit`; coordinate conversion is correct for the restored contract (proven by
`testClickAtNameLabelRejectedNoBinding` → `.rejectedNoBinding`). No consumer-chain edits.
`Sources/PagingCore/`, `Sources/PagingUI/` physics, `Package.swift`, LayoutStore,
wallpaper/transparency, telemetry: untouched. `FolderOverlayView` member-cell
`frame.contains` path (member activation inside an open folder panel) is a separate,
baseline-unchanged contract — outside this packet's scope, left as-is.

## Fail-before evidence

Command (run BEFORE the source fix, after test realignment — no `git stash`):

```
swift test --filter 'Bug9CellHitRoutingTests|AppLaunchControllerTests|BlankClickToQuitTests'
```

Result on the pre-repair (whole-cell) tree: **40 executed, 11 assertion failures** (4 test
cases), exit non-zero. Log: `Workflow/artifacts/T-1J-LM-HITREVERT/fail-before.log`.

Key failure lines (whole-cell behavior active):
- `testClickAtNameLabelRejectedNoBinding`: `XCTAssertEqual failed: ("launched") is not
  equal to ("rejectedNoBinding")` — a name-label click **launched** under whole-cell.
- `testHitTestAtNameLabelMissesCell` / `testHitTestAtCellPaddingMissesCell`:
  `XCTAssertNil failed: "<AppGridCellView…>"` — cell returned for non-icon points.
- `testCellInteriorNonIconPointsClassifyAsBlank`: label/padding points classified as cell
  instead of blank.
- `testFolderCellHitTestUsesFolderSymbolFrame`: folder label area hit the cell.

All four cases pass after the repair (see below).

## Verification (serialized SwiftPM, one invocation at a time, `.build/` shared)

1. Focused filter (exact packet command):

   ```
   swift test --filter 'Bug9CellHitRoutingTests|AppLaunchControllerTests|B1ManualDeliveryTests|BlankClickToQuitTests|LauncherIntegrationTests|FolderIntegrationTests|DragCommitIntegrationTests|Bug11RowBoundaryIndicatorTests|Bug10PreviewHostTests|T1FD1FixUITests|FolderOverlayTests|AppGridCellFocusReuseTests|AppCatalogAssemblyTests|FolderMotionTests|FolderOverlayForensicsTests'
   ```

   **exit 0 — Executed 170 tests, 0 failures** (`Test Suite 'Selected tests' passed …
   Executed 170 tests, with 0 failures`). Log:
   `Workflow/artifacts/T-1J-LM-HITREVERT/focused-after.log`.

2. Build:

   ```
   swift build --target PagingPrototypeApp --configuration debug
   ```

   **exit 0** — `Build of target: 'PagingPrototypeApp' complete!` Log:
   `Workflow/artifacts/T-1J-LM-HITREVERT/build-debug.log`.

Full suite intentionally not run — Main owns that.

## Acceptance check

- `acceptsLaunchHit` true only inside icon frame (folder: symbol frame) ±4pt — restored;
  label/padding/gap clicks miss the launch target and classify via the existing blank path
  (`blankClickResolvesToCell` false → s8/s8c blank branch; `handleClick` →
  `.rejectedNoBinding`). Proven by the realigned tests above.
- `hitTest` detached-cell safe path + superview-space conversion kept; no second click
  path; `appGridCellAncestor` / `blankClickResolvesToInteractionZone` untouched.
- Fail-before evidence captured (above).
- Realigned tests assert icon±4 — nothing deleted/skipped/loosened; `…MissesCell`
  coverage exists for label AND padding points (`testHitTestAtNameLabelMissesCell`,
  `testHitTestAtCellPaddingMissesCell`, plus classifier-level
  `testCellInteriorNonIconPointsClassifyAsBlank`).
- Docs state violated-then-restored history; no doc claims icon±4 was continuously
  preserved.
- m1 consume-site comment present at `AppDelegate.swift` `openFolder(_ identity:)`.
- Focused filter run exit 0, 170 executed / 0 failed; debug build exit 0.

## Closeout notes

- **m2 (recorded):** `AppCatalogAssembly.rebuildFolderCompositionIfNeeded`
  (`Sources/PagingPrototypeApp/AppCatalogAssembly.swift:434-452`) prefers
  `provider.pendingSnapshot ?? provider.servedSnapshot` — a bounded repair from the
  committed slice (first async scan leaves the catalog pending, so folder composition
  previously waited a cycle; covered by `testAsyncFirstScanStagesFolderBeforeIdleCommit`).
  It widens the semantic surface (pending base → committed folder generation) and is
  listed here per r1-m2 / packet instruction. Not modified by this task.
- **m3 (unchanged):** pre-existing Sendable warning at `AppDelegate.swift` ~:1473
  (`diagBackend` captured in `@Sendable` Timer closure) remains recorded, untouched.
- Other files listed in the packet's write scope (`B1ManualDeliveryTests`,
  `LauncherIntegrationTests`, `FolderIntegrationTests`, `DragCommitIntegrationTests`,
  `Bug11RowBoundaryIndicatorTests`, `Bug10PreviewHostTests`, `T1FD1FixUITests`,
  `FolderOverlayTests`, `AppGridCellFocusReuseTests`, `AppCatalogAssemblyTests`,
  `AppContentTestSupport`) were inspected and needed no changes: every click point they use
  is the cell/icon center or bounds mid-point, which lies inside the padded icon frame for
  the fixtures' cell geometry, or they exercise the single-arg `blankClickResolvesToCell`
  classifier / `appGridCellAncestor` which are hit-width-orthogonal.
- Known user-accepted trade-off (per D-1J-HIT-REGION-REVERT): under icon±4 a name-label /
  cell-padding click classifies blank → launcher dismisses. GUI/physical boundary
  re-verification (cell gaps blank→quit; icon±4 hits launch) joins the pending Track-B
  manual gate list — outside this packet.

## Unresolved questions

None blocking. Notes for Main/Reviewer r2:

- `FolderOverlayView` member activation uses `cell.frame.contains` (whole-cell) inside an
  open folder panel — pre-existing baseline behavior, NOT part of M1 and outside this
  packet's write scope. If the user intends icon±4 for folder-member clicks too, that is a
  separate decision → BLOCKED-escalation material, not done here.
- The 60pt-high fixture cells used in `BlankClickToQuitTests.makeClickHarness()` /
  `makeHierarchy()` are "all icon" vertically (icon spans y∈[0,48], label inside the ±4
  padded frame), so those harnesses cannot exercise a label-miss — the new coverage uses a
  realistic 88pt cell for the interior-miss assertions.
