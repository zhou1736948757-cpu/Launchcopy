# T-1E-folder-open-repair-wiring

- Status: OPEN
- Created: 2026-08-30 (Main)
- Phase: Phase 1E (folder foundation)
- Type: repair (user real-GUI feedback) — SPLIT part 2 of 2 (wiring + integration)

## Context

Parent task T-1E-folder-open-repair was split after two consecutive Worker context-exhaustions. Part 1 (T-1E-folder-open-repair-cell) has landed: `AppGridCellView` now has `public var onFolderClick: ((FolderID) -> Void)?` fired by a cell-level click recognizer ONLY for folder cells. This task wires it up.

User evidence: "文件夹打不开，不管是按return还是左键" — folder entries cannot be opened. Root causes (Main, verified): (1) left-click — frozen AppLaunchController rejects FolderID silently, no routing; (2) Return — KeyboardFocusController.keyDown routes activation only when `focusModel.current != nil`, and clicking a folder does NOT set keyboard focus, so click-then-Return no-ops.

## Fix (Worker) — wiring ONLY

**Sources/PagingPrototypeApp/AppDelegate.swift**:
- Wire `cell.onFolderClick` (via the renderer/page factory path already used for `folderSnapshotProvider`, or the closest existing seam) to:
  (a) set keyboard focus to that folder entry — reuse the existing focus-setting seam (e.g. `keyboard.setFocus(to:)` or equivalent) so a subsequent Return/Enter activates the folder;
  (b) open the folder — reuse the existing `openFolder` path (add an `openFolder(folderID:)` overload or construct the AppGridFocusIdentity from the entry).
- Do NOT modify AppLaunchController (frozen). The frozen launch pipeline must remain the ONLY app-launch path.

**Tests/PagingUITests/FolderIntegrationTests.swift** (or new file in PagingUITests):
- Click folder → openFolder path invoked (open state set, overlay configured).
- Click folder then Return → member activation context (folder open), not a no-op.
- App cell click still launches via AppLaunchController (existing tests must keep passing).

## Read scope (read ONLY these)

- Sources/PagingPrototypeApp/AppDelegate.swift (installFolderWiring :415-470, openFolder :530-536, closeFolder :540-547, refreshFolderOverlay :568-590)
- Sources/PagingPrototypeApp/AppCatalogAssembly.swift (renderer/page factory seam, folderSnapshotProvider propagation :161-167, :228)
- Sources/PagingPrototypeApp/KeyboardFocusController.swift (focus-setting seam, routeActivation :373-380, openFolder :267-273)
- Tests/PagingUITests/FolderIntegrationTests.swift (existing patterns)
- Sources/AppGridUI/AppGridCellView.swift (only to confirm the onFolderClick signature)

## Write scope

- Sources/PagingPrototypeApp/AppDelegate.swift
- Tests/PagingUITests/FolderIntegrationTests.swift (or new test file in PagingUITests)

## Verification (run these)

- `swift build -c debug` → exit 0
- `swift test` → executed > 0, 0 failures, exit 0 (baseline 762 + new tests)
- `swift build -c release` → exit 0

## Forbidden

- All frozen trees: Sources/PagingCore/, Sources/AppCatalogCore/, Sources/MacAppCatalog/, Sources/AppIconPipeline/, Sources/PagingTelemetry/, Sources/PagingUI/, Package.swift, Sources/PagingPrototypeApp/AppLaunchController.swift.
- No git ops. No telemetry/schema change. No folder title/membership raw values in telemetry/logs.

## Output discipline (CRITICAL — two prior workers died from context exhaustion)

1. FIRST action after reading the files: write `Workflow/results/T-1E-folder-open-repair-wiring.md` with a placeholder ("in progress") so progress is never lost.
2. Implement in small steps; run the full suite once at the end (builds serialize on the SwiftPM lock; retry on contention).
3. Final reply: < 250 words, NO large code blocks (describe what changed in one line each).

## Acceptance

- swift build -c debug: exit 0; swift test: executed > 0, 0 failures, exit 0; swift build -c release: exit 0
- Frozen trees untouched (mtime check)
- Result file: Workflow/results/T-1E-folder-open-repair-wiring.md
