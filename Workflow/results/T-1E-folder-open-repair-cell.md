# T-1E-folder-open-repair-cell — Result

Status: PASS

## Files changed

- `Sources/AppGridUI/AppGridCellView.swift`
- `Tests/AppGridUITests/FolderCellTests.swift`

## What changed (one line each)

- `AppGridCellView.swift`: added `public var onFolderClick: ((FolderID) -> Void)?` — folder-cell click callback.
- `AppGridCellView.swift`: added a private `NSClickGestureRecognizer` (`folderClickRecognizer`) wired in `init` to `#selector(handleFolderClick(_:))`.
- `AppGridCellView.swift`: added `@objc internal func handleFolderClick(_:)` — guards `isFolderCell == true`, reads `bindingToken?.appID as? FolderID` (same source as the renderer), and invokes `onFolderClick?(folderID)`; app cells no-op.
- `FolderCellTests.swift`: added `testFolderCellClickFiresOnFolderClick` — folder cell click fires `onFolderClick` with the correct `FolderID`.
- `FolderCellTests.swift`: added `testAppCellClickDoesNotFireOnFolderClick` — app cell click does NOT fire `onFolderClick`.

## Verification

- `swift build -c debug` → exit 0 (Build complete).
- `swift test --filter FolderCellTests` → executed 7 tests, 0 failures, exit 0 (both new tests passed; all pre-existing FolderCellTests still green).
- Full suite NOT run (per spec — wiring task does that).

## Frozen-tree mtime check

Only the two allowed files were modified. Frozen trees untouched (mtime recorded, unchanged by this work):
- Sources/PagingCore: 1788057962
- Sources/AppCatalogCore: 1787917822
- Sources/MacAppCatalog: 1787918515
- Sources/AppIconPipeline: 1787930560
- Sources/PagingTelemetry: 1787918942
- Sources/PagingUI: 1788070530
- Package.swift: 1787917375
- Sources/PagingPrototypeApp/AppLaunchController.swift: 1787921214

No git ops. No telemetry/schema change. No folder title/membership raw values logged.
