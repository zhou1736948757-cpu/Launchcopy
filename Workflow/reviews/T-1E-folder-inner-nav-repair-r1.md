# T-1E-folder-inner-nav-repair — Review r1

- Reviewer: independent (read-only; no files modified)
- Verdict: **PASS**
- Reviewed: 2026-08-30

## Spec compliance

1. **layoutPanel fix** — `Sources/AppGridUI/FolderOverlayView.swift` matches the spec exactly:
   - `rows = (memberCells.count + columns - 1) / columns` (integer ceil, columns = 5)
   - `pitch = min(Self.cellHeight + spacing, area.height / CGFloat(max(rows, 1)))` → `min(104, area.height / max(rows,1))`
   - `cellHeight = max(pitch - spacing, 56)` (spacing stays 16)
   - Row-major placement formula unchanged: `y = area.maxY - (row+1) * (cellHeight + spacing)`
   - Small folders (≤ 5 rows) keep 88pt: 580pt grid / 5 rows = 116 ≥ 104 → pitch 104 → cellHeight 88.
   - Independent math check (700pt panel, grid 636→56, area height 580): 35 members → 7 rows → pitch 82.86 → last row y = 636 − 7×82.86 = 56 = area.minY → row 6 (slots 30–34) fully visible; ↓ clamps on a visible cell. Confirmed.
2. **Navigator untouched** — `Sources/AppGridUI/FolderKeyboardLogic.swift` mtime 1788075778 (pre-task); not modified. Clamping already correct per spec.
3. **Write scope** — only `Sources/AppGridUI/FolderOverlayView.swift` (1788090925) and `Tests/AppGridUITests/FolderCellTests.swift` (1788090939) carry this task's mtimes.
4. **Frozen trees untouched** — mtimes match worker-reported baseline exactly: PagingCore 1788057962, AppCatalogCore 1787917822, MacAppCatalog 1787918515, AppIconPipeline 1787930560, PagingTelemetry 1787918942, PagingUI 1788070530, Package.swift 1787917375, AppLaunchController.swift 1787921214. Newest-file-per-tree scan confirms no interior file modified. (Repo is fully untracked, so mtimes are the authoritative scope check.)
5. **No git ops / no privacy leaks** — no evidence of git operations; fixtures and review output use neutral counters only.

## Tests (new, in FolderCellTests.swift)

- `testLargeFolderAllRowsVisibleInPanel` — 35 members, 1000×900 frame → panelH 700; asserts all 35 cell frames within panel bounds and slot 30 (row 6, col 0) `minY ≥ 0`. Passed (0.017s).
- `testSmallFolderKeepsFixedCellHeight` — 13 members (3 rows) → cellHeight 88. Passed (0.005s).

## Verification evidence

| Gate | Result |
|---|---|
| `swift build -c debug` | exit 0 (waited out SwiftPM lock from parallel task) |
| `swift test` | **Executed 772 tests, 0 failures (0 unexpected)**, exit 0 (baseline 767 + 2 new + parallel-task additions) |
| `swift build -c release` | exit 0 |
| `swift test --filter FolderCellTests` | Executed 9 tests, 0 failures; both new tests pass |

## Findings

- None blocking. Minor note (non-blocking): `makeOverlay` in the new tests creates an `IconPipeline` without `shutdown()` (existing tests use `defer`); no functional impact, tests pass.
- Worker's note about a transient mid-edit failure from the parallel task is consistent with observed lock contention; final suite is clean.

## Verdict: PASS
