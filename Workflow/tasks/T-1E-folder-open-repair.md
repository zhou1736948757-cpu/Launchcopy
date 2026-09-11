# T-1E-folder-open-repair

- Status: SPLIT (superseded by T-1E-folder-open-repair-cell + T-1E-folder-open-repair-wiring)
- Created: 2026-08-30 (Main)
- Phase: Phase 1E (folder foundation)
- Type: repair (user real-GUI feedback)

## Evidence (user real-GUI)

User: "文件夹打不开，不管是按return还是左键" — folder entries cannot be opened, neither with Return nor left-click.

## Root cause (Main read-only investigation, verified)

1. **Left-click**: The ONLY click handling is the frozen `AppLaunchController` surface-level `NSClickGestureRecognizer` (Sources/PagingPrototypeApp/AppLaunchController.swift:95-96 install(), :104-118 handleClick → hitTest → AppGridCellView → handleCell → launch(from:)). `launch(from:)` does `guard let appID = token.appID as? AppID else { return .rejectedNoBinding }` (:131) — a folder cell's bindingToken.appID is a FolderID, the cast fails, and the click is silently rejected. There is NO routing from a folder-cell click to openFolder anywhere (AppGridPageView/AppGridCellView/PagingSurface/PageHostView have no click handling — grep-verified).
2. **Return**: KeyboardFocusController.keyDown (:157) calls routeActivation only when `focusModel.current != nil`. Clicking a folder does NOT set keyboard focus, so the user's flow "click folder → press Return" has no focus → fall through → no reaction. (Arrow-select folder → Return path exists and is complete, but the click-then-Return flow is broken at focus.)

## Fix (Worker)

1. **Sources/AppGridUI/AppGridCellView.swift**: add a folder-click recognizer — an NSClickGestureRecognizer on the cell itself (or equivalent) that fires ONLY when `isFolderCell == true` and invokes a new callback `public var onFolderClick: ((FolderID) -> Void)?` (folderID read from the cell's binding token identity, same source the renderer uses). App-cell clicks must be unaffected: they continue through the frozen AppLaunchController launch pipeline (the cell recognizer ignores non-folder cells). No interference with the surface-level recognizer (both may fire; folder → cell callback opens, app → AppLaunchController launches, cell callback no-ops).
2. **Sources/PagingPrototypeApp/AppDelegate.swift**: wire `cell.onFolderClick` (via the renderer/page factory path used for folderSnapshotProvider, or the closest existing seam) to: (a) set keyboard focus to that folder entry (so a subsequent Return/Enter works — reuse the existing focus-setting seam, e.g. keyboard.setFocus(to:) or equivalent), and (b) open the folder (reuse openFolder — add an openFolder(folderID:) overload or construct the AppGridFocusIdentity from the entry).
3. **Tests**:
   - AppGridUITests: folder cell click → onFolderClick fires with the right FolderID; app cell click → onFolderClick does NOT fire.
   - PagingUITests integration: click folder → openFolder path invoked (open state set, overlay configured); click folder then Return → member activation context (folder open), not a no-op; app cell click still launches via AppLaunchController (existing tests must keep passing).

## Write scope

- Sources/AppGridUI/AppGridCellView.swift
- Sources/PagingPrototypeApp/AppDelegate.swift
- Tests/AppGridUITests/FolderCellTests.swift (or new file)
- Tests/PagingUITests/FolderIntegrationTests.swift (or new file)

## Forbidden

- All frozen trees: Sources/PagingCore/, Sources/AppCatalogCore/, Sources/MacAppCatalog/, Sources/AppIconPipeline/, Sources/PagingTelemetry/, Sources/PagingUI/, Package.swift, Sources/PagingPrototypeApp/AppLaunchController.swift (the frozen launch pipeline must remain the ONLY app-launch path; do NOT add a parallel launch path).
- No git ops. No telemetry/schema change. No folder title/membership raw values in telemetry/logs.

## Acceptance

- swift test: executed > 0, 0 failures, exit 0 (baseline 762)
- swift build -c debug: exit 0; swift build -c release: exit 0
- Frozen trees untouched (mtime check)
- Result file: Workflow/results/T-1E-folder-open-repair.md
