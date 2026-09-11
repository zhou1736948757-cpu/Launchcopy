# T-1E-folder-open-repair-cell

- Status: OPEN
- Created: 2026-08-30 (Main)
- Phase: Phase 1E (folder foundation)
- Type: repair (user real-GUI feedback) — SPLIT part 1 of 2 (cell layer)

## Context

Parent task T-1E-folder-open-repair was split after two consecutive Worker context-exhaustions. This task covers ONLY the cell layer. The wiring task (T-1E-folder-open-repair-wiring) is dispatched separately AFTER this lands.

User evidence: "文件夹打不开，不管是按return还是左键" — folder entries cannot be opened. Root cause (Main, verified): the ONLY click handler is the frozen AppLaunchController surface recognizer, whose `launch(from:)` does `guard let appID = token.appID as? AppID` — a FolderID fails the cast and the click is silently rejected. There is no folder-click routing anywhere.

## Fix (Worker) — cell layer ONLY

**Sources/AppGridUI/AppGridCellView.swift**:
- Add an `NSClickGestureRecognizer` on the cell (or equivalent) that fires ONLY when `isFolderCell == true`.
- Add `public var onFolderClick: ((FolderID) -> Void)?` — the callback receives the FolderID read from the cell's binding token identity (`bindingToken.appID as? FolderID`), the same source the renderer uses.
- App-cell clicks must be unaffected: the recognizer ignores non-folder cells; app cells continue through the frozen AppLaunchController launch pipeline. Both recognizers may fire on a folder cell — that is expected; the cell callback no-ops for app cells.
- Do NOT wire anything in AppDelegate (that is the other task). Do NOT touch KeyboardFocusController.

**Tests/AppGridUITests/FolderCellTests.swift** (or new file in AppGridUITests):
- Folder cell click → onFolderClick fires with the correct FolderID.
- App cell click → onFolderClick does NOT fire.

## Read scope (read ONLY these)

- Sources/AppGridUI/AppGridCellView.swift
- Tests/AppGridUITests/FolderCellTests.swift (existing patterns)
- Sources/AppGridUI/AppGridPageView.swift (only to see how the renderer derives the FolderID identity)

## Write scope

- Sources/AppGridUI/AppGridCellView.swift
- Tests/AppGridUITests/FolderCellTests.swift (or new test file in AppGridUITests)

## Verification (run ONLY these)

- `swift build -c debug` → exit 0
- `swift test --filter FolderCellTests` → executed > 0, 0 failures, exit 0
- Do NOT run the full suite (the wiring task does that).

## Forbidden

- All frozen trees: Sources/PagingCore/, Sources/AppCatalogCore/, Sources/MacAppCatalog/, Sources/AppIconPipeline/, Sources/PagingTelemetry/, Sources/PagingUI/, Package.swift, Sources/PagingPrototypeApp/AppLaunchController.swift.
- No git ops. No telemetry/schema change. No folder title/membership raw values in telemetry/logs.

## Output discipline (CRITICAL — two prior workers died from context exhaustion)

1. FIRST action after reading the files: write `Workflow/results/T-1E-folder-open-repair-cell.md` with a placeholder ("in progress") so progress is never lost.
2. Implement in small steps; run the filtered test after each step.
3. Final reply: < 250 words, NO large code blocks (describe what changed in one line each).

## Acceptance

- swift build -c debug: exit 0; swift test --filter FolderCellTests: executed > 0, 0 failures, exit 0
- Frozen trees untouched (mtime check)
- Result file: Workflow/results/T-1E-folder-open-repair-cell.md
