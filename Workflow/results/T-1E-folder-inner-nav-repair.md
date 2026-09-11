# T-1E-folder-inner-nav-repair — Worker Result

- Status: PASS
- Task: Bug 1 — inside a folder, ↓ does not clamp on the last visible row (focus ring keeps moving down past the last row and becomes invisible).
- Root cause (from packet): `FolderOverlayView.layoutPanel()` uses a FIXED cell pitch (cellHeight 88 + spacing 16 = 104pt). Panel grid area is only ~580pt tall (gridTop 636 − gridBottom 56 on a 700pt panel). A 35-member folder needs 7 rows × 104 = 728pt > 580pt → rows 6+ laid out below the panel (invisible). `FolderInnerNavigator` clamping is correct and unit-tested; the defect is purely the panel layout.

## Plan

1. `Sources/AppGridUI/FolderOverlayView.swift` — `layoutPanel()`: compute dynamic pitch so all member rows of the current page fit the grid area:
   - `rows = ceil(memberCells.count / columns)` (columns = 5)
   - `pitch = min(104, area.height / max(rows, 1))`
   - `cellHeight = max(pitch - spacing, 56)` (spacing stays 16)
   - Keep the existing row-major placement formula (`y = area.maxY - (row+1)*(cellHeight+spacing)`); last row lands at/above `area.minY`.
   - Small folders (≤ 5 rows) keep 88pt cellHeight (pitch 104) — no visual change.
2. Do NOT touch `FolderInnerNavigator` / `FolderKeyboardLogic.swift` (clamping already correct).
3. Tests (Tests/AppGridUITests/FolderCellTests.swift):
   - 35-member folder on a 700pt-tall overlay → all member cell frames within panel bounds (last row `minY ≥ panel.minY`).
   - Regression: 13-member folder (3 rows) keeps 88pt cellHeight (pitch 104).
4. Verify: `swift build -c debug` (exit 0), `swift test` (executed > 0, 0 failures), `swift build -c release` (exit 0).

## Write scope
- Sources/AppGridUI/FolderOverlayView.swift
- Tests/AppGridUITests/FolderCellTests.swift

## Forbidden (untouched)
- All frozen trees (PagingCore, AppCatalogCore, MacAppCatalog, AppIconPipeline, PagingTelemetry, PagingUI, Package.swift, AppLaunchController.swift).
- KeyboardFocusController.swift, AppDelegate.swift (parallel task).
- No git ops.

## What changed

1. `Sources/AppGridUI/FolderOverlayView.swift` — `layoutPanel()`: replaced the fixed 88pt cellHeight with a dynamic pitch so all member rows of the current page fit the grid area:
   - `rows = ceil(memberCells.count / columns)` (columns = 5)
   - `pitch = min(104, area.height / max(rows, 1))`
   - `cellHeight = max(pitch - spacing, 56)` (spacing stays 16)
   - Row-major placement formula unchanged (`y = area.maxY - (row+1)*(cellHeight+spacing)`); last row now lands at/above `area.minY` → every row visible.
   - Small folders (≤ 5 rows) keep 88pt cellHeight (pitch 104) — no visual change.
2. `Tests/AppGridUITests/FolderCellTests.swift` — added two tests:
   - `testLargeFolderAllRowsVisibleInPanel`: 35-member folder on a 700pt panel (frame 1000×900 → panelH 700) → all 35 cell frames within panel bounds; last-row first cell (index 30) `minY ≥ 0` (visible).
   - `testSmallFolderKeepsFixedCellHeight`: 13-member folder (3 rows) keeps 88pt cellHeight.

## Verification

- `swift build -c debug` → exit 0
- `swift test` → **Executed 772 tests, with 0 failures (0 unexpected)**, exit 0 (baseline 767 + 2 new layout tests + parallel-task additions)
- `swift build -c release` → exit 0

Note: an initial `swift test` run reported 5 failures and a transient compile error in `Tests/PagingUITests/FolderIntegrationTests.swift` (`makeFolderClickHandler` not in scope). This was a mid-edit state from the parallel task T-1E-folder-mouse-open-repair (that file's mtime changed seconds before). After the parallel task settled, the full suite passed cleanly (772/0). I did NOT modify that file.

## Frozen-tree mtime check

Only `FolderOverlayView.swift` and `FolderCellTests.swift` were edited by me. Frozen trees untouched (mtimes match baseline):
- Sources/PagingCore 1788057962, AppCatalogCore 1787917822, MacAppCatalog 1787918515, AppIconPipeline 1787930560, PagingTelemetry 1787918942, PagingUI 1788070530, Package.swift 1787917375, AppLaunchController.swift 1787921214.
- KeyboardFocusController.swift (1788090946) / AppDelegate.swift (1788090949) modified by the parallel task, not me.

No git ops. No telemetry/schema change. No folder title/membership raw values logged.
