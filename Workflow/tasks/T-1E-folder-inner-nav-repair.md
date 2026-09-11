# T-1E-folder-inner-nav-repair

- Status: OPEN
- Created: 2026-08-30 (Main)
- Phase: Phase 1E (folder foundation)
- Type: repair (user real-GUI feedback)

## Evidence (user real-GUI, verbatim)

User: "第一个bug，打开文件夹以后，这个方向键啊，往下走就是时候，往下走就走不到底那种感觉，就是往下走它不会卡在最后最下面一个应用那边就卡住，它会一直往下走，但是也不会移到最上面那个。按道理来说应该是，比如说它是第一列的最下面，第一列的最后一行的话，那让它往下走，按方向键往下减的话，它应该会卡在这个第一列最后一行这个APP这就不会往下走。"

Translation: inside an open folder, pressing ↓ moves the focus ring down through the members but it does NOT visibly clamp at the last row — the ring "keeps going down" (disappears) instead of stopping at the last app of the first column.

## Root cause (Main read-only investigation, verified by layout math)

`FolderOverlayView.layoutPanel()` uses a FIXED cell pitch: `cellHeight = 88`, `spacing = 16` → pitch 104pt. The panel height is capped at 700pt (`panelH = min(max(h*0.8, 200), 700)`), so the member grid area is only 580pt tall (`gridTop 636 - gridBottom 56`).

A 35-member folder (5 columns) needs 7 rows × 104pt = 728pt > 580pt → **row 6 (member indices 30–34) is laid out at y = 636 − 7×104 = −92, entirely BELOW the panel (invisible)**; row 5 partially overlaps the footer.

`FolderInnerNavigator.move` (FolderKeyboardLogic.swift) is CORRECT and already clamps: ↓ from slot 30 → `next = 35`, `35 < pageEnd(35)` false → nil. The ring clamps at slot 30 (row 6, col 0) — exactly the "last row of the first column" the user expects — but the cell is invisible, so the user sees the ring vanish instead of clamping on a visible app. Unit test `testInnerDownNoMoveWhenRowAbsent` passes; the defect is purely the panel layout, not the navigator.

Verified against the running app: fullscreen 1470×923 (log `paging-fullscreen: frame=(0.0, 0.0, 1470.0, 923.0)`), panelH = min(max(923*0.8,200),700) = 700.

## Fix (Worker)

1. **Sources/AppGridUI/FolderOverlayView.swift** — `layoutPanel()`: make the cell pitch fit ALL member rows of the current page:
   - `rows = ceil(memberCells.count / columns)` (columns = 5)
   - `pitch = min(104, area.height / max(rows, 1))`
   - `cellHeight = max(pitch - spacing, 56)` (spacing stays 16)
   - Keep the existing row-major placement formula (`y = area.maxY - (row+1) * (cellHeight + spacing)`); with the dynamic pitch the last row lands at `area.minY` (gridBottom) or above — every row visible.
   - Small folders (≤ 5 rows) keep the current 88pt cellHeight (pitch 104) — no visual change for the common case.
2. **Do NOT touch** `FolderInnerNavigator` / `FolderKeyboardLogic.swift` (clamping is already correct and unit-tested).
3. **Tests** (Tests/AppGridUITests/FolderCellTests.swift or new file in AppGridUITests):
   - Configure a 35-member folder on a 700pt-tall overlay (frame e.g. 1000×700, run `layout()`), assert ALL member cells' frames are within the panel bounds (last row `minY ≥ panel.minY`).
   - Regression: a 13-member folder (3 rows) keeps the 88pt cellHeight (pitch 104).
   - Existing FolderCellTests / FolderKeyboardLogicTests must keep passing.

## Read scope (read ONLY these)

- Sources/AppGridUI/FolderOverlayView.swift (layoutPanel, layout, panel constants)
- Tests/AppGridUITests/FolderCellTests.swift (existing patterns)
- Tests/AppGridUITests/FolderKeyboardLogicTests.swift (only to confirm the navigator clamp is already covered — do NOT modify)

## Write scope

- Sources/AppGridUI/FolderOverlayView.swift
- Tests/AppGridUITests/FolderCellTests.swift (or new test file in AppGridUITests)

## Verification (run these)

- `swift build -c debug` → exit 0
- `swift test` → executed > 0, 0 failures, exit 0 (baseline 767)
- `swift build -c release` → exit 0

## Forbidden

- All frozen trees: Sources/PagingCore/, Sources/AppCatalogCore/, Sources/MacAppCatalog/, Sources/AppIconPipeline/, Sources/PagingTelemetry/, Sources/PagingUI/, Package.swift, Sources/PagingPrototypeApp/AppLaunchController.swift.
- Sources/PagingPrototypeApp/KeyboardFocusController.swift and Sources/PagingPrototypeApp/AppDelegate.swift (parallel task T-1E-folder-mouse-open-repair owns those).
- No git ops. No telemetry/schema change. No folder title/membership raw values in telemetry/logs.

## Output discipline (CRITICAL — prior workers died from context exhaustion)

1. FIRST action after reading the spec: write `Workflow/results/T-1E-folder-inner-nav-repair.md` with "in progress" so progress is never lost.
2. Implement in small steps; run the full suite once at the end (builds serialize on the SwiftPM lock; retry on contention).
3. Final reply: < 250 words, NO large code blocks (describe what changed in one line each).

## Acceptance

- swift build -c debug: exit 0; swift test: executed > 0, 0 failures, exit 0; swift build -c release: exit 0
- Frozen trees untouched (mtime check)
- 35-member folder: all 7 rows visible in the panel; ↓ clamps at slot 30 (row 6, col 0) on a VISIBLE cell
- Result file: Workflow/results/T-1E-folder-inner-nav-repair.md
