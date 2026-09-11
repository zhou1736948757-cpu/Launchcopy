# T-1E-folder-open-click-focus-repair — Review r1

Verdict: **PASS**

## Findings

- `Sources/PagingPrototypeApp/AppDelegate.swift:557-559` — `handleFolderCellClick(folderID:)` now only calls `openFolder(folderID:)`. No `setFocus(to:)` in the click path. ✓
- `Sources/PagingPrototypeApp/AppDelegate.swift:544-549` — `openFolder(folderID:)` opens the folder and refreshes the overlay; no focus mutation. ✓
- `Sources/PagingPrototypeApp/AppDelegate.swift:436-438` — `installFolderWiring` routes `renderer.onFolderClick` → `handleFolderCellClick`; no focus set. ✓
- `Sources/PagingPrototypeApp/AppDelegate.swift` — grep for `folderFocusIdentity` and `setFocus` returns no matches: dead helper removed, no dead code left. ✓
- Keyboard focus model untouched: `Sources/PagingPrototypeApp/AppDelegate.swift:466` still wires `keyboard.onOpenFolder = openFolder(identity)`; `Sources/PagingPrototypeApp/KeyboardFocusController.swift:203` retains `setFocus(to:)` for the arrow-select + Return path. ✓
- `Tests/PagingUITests/FolderIntegrationTests.swift:430-431, 477-478` — click tests assert `keyboard.focusModel.current == nil` (focus NOT set). ✓
- `Tests/PagingUITests/FolderIntegrationTests.swift:436-481` — `testFolderCellClickOpensImmediately` replaces the old click-then-Return test: click opens immediately, no Return needed. ✓
- `Tests/PagingUITests/FolderIntegrationTests.swift:483-505` — `testAppCellClickStillLaunchesViaAppLaunchController` unchanged; app-cell launch intact. ✓
- No test asserts the old click-then-Return behavior. ✓
- Write-scope check: only `Sources/PagingPrototypeApp/AppDelegate.swift` and `Tests/PagingUITests/FolderIntegrationTests.swift` were modified after task creation (2026-08-30 17:55). No other file touched. ✓

## Verification evidence

- Frozen-tree mtime check: newest frozen mtime = `Sources/PagingUI` 2026-08-30 15:15:30, all predate task creation (~17:55). Changed files: AppDelegate.swift 18:35:40, FolderIntegrationTests.swift 18:35:56 (both after task). ✓
- `swift build -c debug` → exit 0.
- `swift test` → **Executed 767 tests, 0 failures (0 unexpected)**, exit 0 (baseline 767, unchanged).
- `swift build -c release` → exit 0.

## Notes

- No MINOR/MAJOR issues. Implementation matches spec exactly; tests updated to reflect new behavior; frozen trees untouched.
