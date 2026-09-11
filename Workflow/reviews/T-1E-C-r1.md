# Review Report — T-1E-C (r1)

- **Task**: T-1E-C — Folder cell / open layer / inner paging
- **Reviewer role**: Independent Reviewer (read-only; no implementation files modified)
- **Verdict**: **PASS**
- **Date**: 2026-08-30

## Summary

The Worker's implementation satisfies every acceptance criterion in the task packet
`Workflow/tasks/T-1E-C.md`. I independently read the task packet, the Worker result
`Workflow/results/T-1E-C.md`, the four implementation files, and the four new test
suites, and independently ran the full build/test matrix. All builds exit 0; the full
test suite executes **709 tests, 0 failures** (criterion: N ≥ 689, 0 failures — met).
No frozen tree was written this session; no privacy/security redline is violated.

## Findings

### BLOCKER
- None.

### MAJOR
- None.

### MINOR
- **M1 — Worker-reported test count (689) differs from measured (709).**
  The Worker reported "689 tests, 0 failures (baseline 660 + 29)". I measured
  **709 tests, 0 failures** on the full suite. The 20-test delta is consistent with the
  parallel T-1E-B worker landing additional `AppGridUITests` after the Worker's snapshot.
  The acceptance criterion (N ≥ 689, 0 failures) is satisfied by my measurement, so this
  is an evidence-accuracy note, not a defect. The four T-1E-C suites themselves are
  confirmed: FolderCellTests (5), FolderOverlayTests (11), FolderInnerPagingTests (4),
  FolderOpenStateTests (9) = 29 tests, 0 failures.

### QUESTION
- **Q1 — Frozen-tree / T-1E-B non-touch is mtime-based, not git-verified.**
  No git operations are permitted in this review. I verified by mtime that no file under
  `Sources/PagingCore/`, `AppCatalogCore/`, `MacAppCatalog/`, `AppIconPipeline/`,
  `PagingTelemetry/`, `PagingUI/`, `Package.swift`, or
  `Sources/PagingPrototypeApp/AppLaunchController.swift` was modified in the 16:xx
  session window (most recent frozen mtime is `PagingCore/PagingParameters.swift`
  11:46, predating this session). T-1E-B's files (`AppGridUIPageContentProvider.swift`
  16:28, `AppGridSearchPresentationController.swift` 16:26, `AppGridUIState.swift`
  10:54) carry B-session mtimes, distinct from C's files (16:19–16:25). This is
  consistent with the Worker's claim but is not a cryptographic proof of non-touch.

## Acceptance-criteria verification (independent)

1. **Folder cell = neutral independent symbol + title + member count (NOT app-icon collage).**
   PASS. `AppGridCellView.bindFolder` (L98) renders SF Symbol "folder" + title + member
   count; `isFolderCell = true`. App vs folder distinguishable. No collage.
2. **Folder cells never request app icons.**
   PASS. `AppGridPageView.render` folder branch (L129-138) calls `bindFolder` and does
   **not** call `requestIcon`; `iconKey(for:)` returns nil for non-`AppID`.
   `applyIconIfValid` (L137) guards `!isFolderCell` → folder cell always rejects
   app-icon writeback. Test `testFolderCellDistinctFromAppCell` asserts
   `pendingKeyCount == 0`; `testFolderCellRejectsIconApply` asserts reject.
3. **Open layer: hierarchy/hit-test boundary; title + member grid; inner paging; inner
   paging does not drive/pollute outer paging.**
   PASS. `FolderOverlayView` = full-surface mask + centered panel. `hitTest` routes only
   prev/next buttons to themselves, everything else to `self`. `FolderOpenState` exposes
   only `innerPage`/`open`/`close`/`setInnerPage` — no outer-page field; overlay fires
   only `onInnerPageChange`. Test `testFolderOpenStateHasNoOuterPageState` and
   `testInnerPagingOnlyFiresInnerPageChange`.
4. **Open-state owner: session-only; open A then open B → A's old callbacks must not
   overwrite B (generation-gated).**
   PASS. `FolderOpenState.open` bumps `generation`; overlay `configure` bumps
   `surfaceGeneration`. Test `testOpenAThenOpenBNoCrossOverwrite` (disjoint member sets)
   confirms A's old member-icon apply is `rejectedStale`, never written to B.
5. **Stale defense: reuse/surface generation reject old member-icon callbacks; reuse
   clears stale folder title/thumbnail/focus; teardown zero callbacks.**
   PASS. Overlay `requestMemberIcon` gates on `surfaceGeneration`; `clearContent` bumps
   generation; `teardown` → `ignoredAfterTeardown`. `AppGridPageView.clearForReuse`
   bumps `surfaceGeneration` and `clearCells` clears folder title/symbol/count/focus.
   Tests: `testReuseClearsFolderTitleThumbnailFocus`, `testTeardownZeroCallbacks`.
6. **Click outside open layer closes folder only (does not exit app); click-coordinate
   repair `panel.convert(point, from: self)` correct.**
   PASS. `handleClick`: if point in `panel.frame` → convert to panel coords
   (`panel.convert(point, from: self)`) and hit-test member cells (whose frames are in
   panel coords); else `onRequestClose`. The repair is correct: member cell frames are
   in panel coordinates, so the overlay-coordinate point must be converted before
   `cell.frame.contains`. Tests: `testClickOutsideClosesFolder`,
   `testClickMemberActivates`, `testClickPanelNonMemberIgnored`.
7. **Reduce Motion path correct.**
   PASS. `MotionParams.standard` (0.18s, scale 0.96, displacement 8) vs
   `reduceMotion` (0.0, 1.0, 0.0); `forReduceMotion` selects. Tests
   `testReduceMotionParams`, `testConfigureReduceMotionFlag`.
8. **Accessibility: folder entry role/label/description; predictable focus order.**
   PASS. `bindFolder` sets role `.button`, label = title, help = "Folder with N items".
   Member cells are ordered `AppGridCellView`s; overlay title + member hierarchy
   understandable. Test `testFolderCellAccessibility`.
9. **Privacy redline.**
   PASS. Grep of the four implementation files found no `print`/`NSLog`/`os_log`/
   `Logger`/`Telemetry`/`JSONL`/`signpost`/`FileHandle`/`stdout` calls (only comment
   text). No `import PagingTelemetry` / `PagingTelemetry.` reference → no schema change.
   Only neutral counters (`memberCount`, `innerPageCount`, `generation`) are exposed.
10. **No Buho/LaunchBetter replication; no global NSEvent monitor / Accessibility /
    Input Monitoring.**
    PASS. Grep found no `addGlobalMonitorForEvents`/`addLocalMonitorForEvents`/
    `AXIsProcessTrusted`/`CGEventTap`/`NSEventMonitor`. Visuals are neutral SF Symbol +
    title + count; no brand replication.

## Verification evidence (measured)

- `swift build -c debug` → **exit 0** ("Build complete!").
- `swift build -c release` → **exit 0** (waited on a parallel SwiftPM lock from the
  concurrent T-1E-B worker, then "Build complete!").
- `swift test` (full suite) → **exit 0**; XCTest line:
  `Executed 709 tests, with 0 failures (0 unexpected)`. The swift-testing line
  "0 tests in 0 suites" is NOT the real count (as the packet warns).
- Targeted folder suites → **exit 0**; 29 tests, 0 failures:
  FolderCellTests 5, FolderOverlayTests 11, FolderInnerPagingTests 4,
  FolderOpenStateTests 9.

## Frozen-tree check

- No file under the frozen trees (`PagingCore/`, `AppCatalogCore/`, `MacAppCatalog/`,
  `AppIconPipeline/`, `PagingTelemetry/`, `PagingUI/`), `Package.swift`, or
  `Sources/PagingPrototypeApp/AppLaunchController.swift` was modified in the 16:xx
  session window (mtime check; no git permitted).
- T-1E-B's files carry B-session mtimes, distinct from C's files. See Q1.

## Deviation assessment

- The Worker's declared deviations (read-only test accessors `memberCountText`,
  `isFolderSymbolVisible`, `panelFrame`; `prevPage`/`nextPage` made internal) are
  behavior-neutral and within the allowed write scope. No packet deviation found.
- The Worker's reported test count (689) is lower than my measured 709; criterion still
  met (see M1).

## Conclusion

**PASS.** All acceptance criteria verified independently. No BLOCKER or MAJOR findings.
One MINOR evidence-accuracy note (test count) and one QUESTION (mtime-based frozen-tree
verification) — neither affects the verdict.
