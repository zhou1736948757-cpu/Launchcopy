# T-1E-folder-open-click-focus-repair — Result

Status: PASS

## Files changed

- `Sources/PagingPrototypeApp/AppDelegate.swift`
  - `handleFolderCellClick(folderID:)`: removed the `keyboardController?.setFocus(to:)` call — left-click on a folder now ONLY opens the folder (reuses `openFolder(folderID:)`). Keyboard focus model untouched.
  - Removed the now-dead private helper `folderFocusIdentity(for:)` (was only used to build the focus identity for the removed `setFocus` call).
- `Tests/PagingUITests/FolderIntegrationTests.swift`
  - `makeFolderClickHandler`: dropped the `setFocus` step and the now-unused `keyboard` parameter — mirrors the new production behavior (open only).
  - `testFolderCellClickOpensFolderViaRendererSeam`: added assertion that keyboard focus is NOT set after click (`keyboard.focusModel.current == nil`).
  - Replaced `testFolderCellClickThenReturnActivatesMember` with `testFolderCellClickOpensImmediately`: click opens the folder immediately (no Return needed) and does not set keyboard focus.
  - `testAppCellClickStillLaunchesViaAppLaunchController` unchanged (app cell still launches via AppLaunchController).

## Verification

- `swift build -c debug` → exit 0
- `swift test` → **Executed 767 tests, with 0 failures (0 unexpected)**, exit 0 (baseline 767, unchanged)
- `swift build -c release` → exit 0

## Frozen-tree mtime check

Only `AppDelegate.swift` and `FolderIntegrationTests.swift` were edited. Frozen trees untouched (mtime unchanged):
- Sources/PagingCore 1788057962
- Sources/AppCatalogCore 1787917822
- Sources/MacAppCatalog 1787918515
- Sources/AppIconPipeline 1787930560
- Sources/PagingTelemetry 1787918942
- Sources/PagingUI 1788070530
- Package.swift 1787917375
- Sources/PagingPrototypeApp/AppLaunchController.swift 1787921214

No git ops. No telemetry/schema change. No folder title/membership raw values logged.
