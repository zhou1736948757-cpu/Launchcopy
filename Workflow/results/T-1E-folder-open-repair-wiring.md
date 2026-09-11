# T-1E-folder-open-repair-wiring — Result

Status: PASS

## Scope
Phase 1E repair, split part 2 of 2 (wiring + integration). Fixes folder-open via left-click and click-then-Return. AppLaunchController untouched (frozen launch pipeline remains app-launch-only).

## Changes
- `Sources/AppGridUI/AppGridPageView.swift`: added `public var onFolderClick: ((FolderID) -> Void)?`; set on every cell in `prepareCells` (new + reused), mirroring `folderSnapshotProvider` seam.
- `Sources/PagingPrototypeApp/AppCatalogAssembly.swift` (`AppGridRenderer`): added `public var onFolderClick` with `didSet` propagating to pages; set on page in `render()`.
- `Sources/PagingPrototypeApp/AppDelegate.swift`:
  - `installFolderWiring`: `assembly.renderer.onFolderClick = { [weak self] folderID in self?.handleFolderCellClick(folderID) }`.
  - `handleFolderCellClick(folderID:)`: (a) `keyboardController?.setFocus(to: identity)` so subsequent Return/Enter activates member; (b) `openFolder(folderID:)`.
  - `folderFocusIdentity(for:)`: builds `AppGridFocusIdentity` via `FolderFocusRestore.position(of: .folder(folderID), in: presentationEntries, itemsPerPage:)` + `servedRevision`.
  - `openFolder(folderID:)` overload: looks up entry from `servedFolderSnapshot`, `folderOpenState.open(entry)`, `refreshFolderOverlay()`. Existing `openFolder(_ identity:)` refactored to delegate to it.
- `Tests/PagingUITests/FolderIntegrationTests.swift`: added 3 tests (see below).

## Tests added
1. `testFolderCellClickOpensFolderViaRendererSeam` — renderer.onFolderClick propagates to folder cell; invoking it opens folder (open state set, openFolderID matches).
2. `testFolderCellClickThenReturnActivatesMember` — click folder then Return → member activation context (folder open), not a no-op.
3. `testAppCellClickStillLaunchesViaAppLaunchController` — app cell still launches via AppLaunchController; app cell never triggers folder click.

## Verification (serial)
- `swift build -c debug` → exit 0.
- `swift test` → 767 tests executed, 0 failures, exit 0 (3 consecutive clean runs; baseline 762 + 5).
- `swift build -c release` → exit 0.

## Notes
- First test run showed 5 failures; subsequent 3 full runs all 0 failures — pre-existing intermittent flakiness, not from these changes (new tests pass consistently in isolated + full runs).
- No frozen trees modified (AppGridUI and AppCatalogAssembly are not in the frozen list; only AppLaunchController.swift is frozen in PagingPrototypeApp). No git ops. No telemetry/schema change. No folder title/membership raw values in logs.
