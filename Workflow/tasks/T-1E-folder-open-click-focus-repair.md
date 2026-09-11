# T-1E-folder-open-click-focus-repair

- Status: OPEN
- Created: 2026-08-30 (Main)
- Phase: Phase 1E (folder foundation)
- Type: repair (user real-GUI feedback)

## Evidence (user real-GUI)

User: "不知道为什么，我左键点击这个文件夹的时候，这文件夹上面就会显示那个就是键盘选中那个框啊" — left-clicking a folder shows the keyboard focus ring on the folder. Expected: left-click opens the folder directly with NO focus ring (standard macOS: mouse interaction does not show the keyboard focus ring).

## Root cause (Main read-only investigation, verified)

The just-merged folder-open repair (T-1E-folder-open-repair-wiring) made `AppDelegate.handleFolderCellClick(folderID:)` do (a) `keyboardController?.setFocus(to:)` — to make click-then-Return work — then (b) open the folder. Step (a) sets keyboard focus to the folder entry, which renders the keyboard focus ring on the folder cell. The folder DOES open (user confirms), but the focus ring is unwanted for a mouse click.

## Fix (Worker)

1. **Sources/PagingPrototypeApp/AppDelegate.swift** — `handleFolderCellClick(folderID:)`: remove the `setFocus(to:)` call; left-click on a folder now ONLY opens the folder (reuse the existing openFolder(folderID:) path). Do NOT touch the keyboard focus model otherwise.
2. **Keyboard navigation must be unaffected**: arrow-select folder → Return still opens (existing path, existing tests must keep passing). The focus ring remains the normal feedback for keyboard navigation.
3. **Tests** (Tests/PagingUITests/FolderIntegrationTests.swift or new file):
   - Click folder → folder opens AND keyboard focus is NOT set to the folder (assert focus unchanged / not the clicked folder).
   - Existing tests: click-then-Return test must be UPDATED — click now opens directly, so the old "click then Return activates member" test no longer describes the behavior; replace it with: click folder → opens immediately (no Return needed). Arrow-select + Return open test (if present) must keep passing.
   - App cell click still launches via AppLaunchController (existing tests keep passing).

## Read scope (read ONLY these)

- Sources/PagingPrototypeApp/AppDelegate.swift (handleFolderCellClick, openFolder(folderID:), installFolderWiring)
- Sources/PagingPrototypeApp/KeyboardFocusController.swift (only to confirm the focus-ring source and the arrow-select+Return path)
- Tests/PagingUITests/FolderIntegrationTests.swift (existing patterns incl. the click-then-Return test to update)

## Write scope

- Sources/PagingPrototypeApp/AppDelegate.swift
- Tests/PagingUITests/FolderIntegrationTests.swift (or new test file in PagingUITests)

## Verification (run these)

- `swift build -c debug` → exit 0
- `swift test` → executed > 0, 0 failures, exit 0 (baseline 767)
- `swift build -c release` → exit 0

## Forbidden

- All frozen trees: Sources/PagingCore/, Sources/AppCatalogCore/, Sources/MacAppCatalog/, Sources/AppIconPipeline/, Sources/PagingTelemetry/, Sources/PagingUI/, Package.swift, Sources/PagingPrototypeApp/AppLaunchController.swift.
- No git ops. No telemetry/schema change. No folder title/membership raw values in telemetry/logs.

## Output discipline (CRITICAL — prior workers died from context exhaustion)

1. FIRST action after reading the spec: write `Workflow/results/T-1E-folder-open-click-focus-repair.md` with "in progress" so progress is never lost.
2. Implement in small steps; run the full suite once at the end (builds serialize on the SwiftPM lock; retry on contention).
3. Final reply: < 250 words, NO large code blocks (describe what changed in one line each).

## Acceptance

- swift build -c debug: exit 0; swift test: executed > 0, 0 failures, exit 0; swift build -c release: exit 0
- Frozen trees untouched (mtime check)
- Result file: Workflow/results/T-1E-folder-open-click-focus-repair.md
