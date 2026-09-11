# T-1E-folder-open-repair-cell — Review r1

- Reviewer: independent (read-only)
- Verdict: **PASS**

## Scope verified

Task adds a folder-click recognizer to `AppGridCellView` (public `onFolderClick` callback, fires only for folder cells) plus two tests in `FolderCellTests`. Verified independently against the task spec.

## Findings

- `Sources/AppGridUI/AppGridCellView.swift:43` — `folderClickRecognizer = NSClickGestureRecognizer()` added.
- `Sources/AppGridUI/AppGridCellView.swift:53` — `public var onFolderClick: ((FolderID) -> Void)?` added.
- `Sources/AppGridUI/AppGridCellView.swift:89-91` — recognizer wired in `init` to `#selector(handleFolderClick(_:))`.
- `Sources/AppGridUI/AppGridCellView.swift:163-167` — `handleFolderClick` guards `isFolderCell == true` (line 164), reads `bindingToken?.appID as? FolderID` (line 165, same source as renderer), invokes `onFolderClick?(folderID)`. App cells no-op via early return. Correct.
- `Tests/AppGridUITests/FolderCellTests.swift:155-176` — `testFolderCellClickFiresOnFolderClick`: folder cell click fires `onFolderClick` with the correct `FolderID`. Correct.
- `Tests/AppGridUITests/FolderCellTests.swift:178-195` — `testAppCellClickDoesNotFireOnFolderClick`: app cell click does NOT fire `onFolderClick`. Correct.

No AppDelegate / KeyboardFocusController changes (out of scope): both files' mtimes predate this task's work. No frozen-tree changes.

## Verification evidence

- `swift build -c debug` → exit 0 (Build complete).
- `swift test` (full suite) → **Executed 764 tests, 0 failures**, exit 0. Baseline 762 + 2 new tests = 764. Valid test execution (executed > 0).
- `swift build -c release` → exit 0 (Build complete).

## Frozen-tree mtime check

Task work mtime = 1788079102 (AppGridCellView.swift 17:38:22; FolderCellTests.swift 17:38:25; result file 17:38:59). Newest mtime in each frozen tree predates the task work:

- Sources/PagingCore: 1788057962
- Sources/AppCatalogCore: 1787917822
- Sources/MacAppCatalog: 1787918515
- Sources/AppIconPipeline: 1787930560
- Sources/PagingTelemetry: 1787918942
- Sources/PagingUI: 1788070530
- Package.swift: 1787917375
- Sources/PagingPrototypeApp/AppLaunchController.swift: 1787921214

Out-of-scope files also predate task work: AppDelegate.swift 1788077569, KeyboardFocusController.swift 1788075775.

## Notes

- MINOR: none.
- MAJOR: none.
