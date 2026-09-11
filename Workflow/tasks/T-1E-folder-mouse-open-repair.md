# T-1E-folder-mouse-open-repair

- Status: OPEN
- Created: 2026-08-30 (Main)
- Phase: Phase 1E (folder foundation)
- Type: repair (user real-GUI feedback)

## Evidence (user real-GUI, verbatim)

User: "第二个bug就是说，就是最外面那大的面板里面，对吧？我按方向键，比如说已经在某个应用上面有蓝框以后，这时候我用鼠标轻点某个软件，轻点，不是轻点某个软件，就是轻点了这个文件夹打开以后，这个应用的这个框啊，就会留在外面那个大的面板里面，然后在这个文件夹里面的话，使用这个左右方向键啊，它就无法选中这个软件了。"

Translation: (1) after arrow-key focus is on an outer app, mouse-clicking a folder to open it leaves the outer blue focus ring visible on the outer panel; (2) inside the folder, left/right arrows cannot select the members.

## Root cause (Main read-only investigation, verified)

The mouse-open path bypasses `KeyboardFocusController` entirely:

- `AppDelegate.handleFolderCellClick(folderID:)` → `openFolder(folderID:)` only does `folderOpenState.open(entry)` + `refreshFolderOverlay()`. It NEVER clears `focusModel.current` (→ the outer blue ring stays, symptom 1), never sets `innerFocusIndex` / `openedFolderIdentity`, and never applies the inner focus visual (→ no visible selection state inside the folder until the first arrow press, symptom 2).
- The keyboard-open path (`KeyboardFocusController.openFolder(_ identity:)`, lines ~267-273) DOES all of this: `openedFolderIdentity = identity.entryIdentity; innerFocusIndex = 0; focusModel = nil; applyFocusVisual(); onOpenFolder?(identity)`. The two open paths are inconsistent.
- Additionally, NEITHER path calls `applyInnerFocusVisual()` on open — the inner ring is deferred until the first arrow (known T-1E-D-r1 MINOR "initial inner focus visual deferred"). After a mouse-open the user sees no selection state at all, so left/right presses feel broken (left at index 0 is a no-op at the edge; the ring only appears after a right press, skipping member 1).
- `isFolderOpen` itself is correct after mouse-open (same `FolderOpenState` instance is wired to `keyboard.folderOpenStateProvider`), so `handleInnerArrow` DOES run — the defect is the missing state initialization + missing visible selection, not the routing.

## Fix (Worker)

1. **Sources/PagingPrototypeApp/KeyboardFocusController.swift** — add a public seam for the mouse path:
   - `public func openFolderFromClick(_ folderID: FolderID)` that mirrors the keyboard path: `openedFolderIdentity = .folder(folderID)`, `innerFocusIndex = 0`, `focusModel = AppGridFocusModel(current: nil)`, `applyFocusVisual()`, then `onOpenFolder?(<synthetic AppGridFocusIdentity with entryIdentity = .folder(folderID)>)`, then `applyInnerFocusVisual()` (AFTER onOpenFolder so the overlay is configured and memberCells exist).
   - In the existing keyboard path `openFolder(_ identity:)`: also call `applyInnerFocusVisual()` after `onOpenFolder?(identity)` — both paths now show the inner ring on member 1 (slot 0) immediately on open (resolves the T-1E-D-r1 MINOR).
   - Do NOT change `handleInnerArrow` / `applyInnerFocusVisual` / `closeFolder` semantics.
2. **Sources/PagingPrototypeApp/AppDelegate.swift** — `handleFolderCellClick(folderID:)`: route through the keyboard seam: `keyboardController?.openFolderFromClick(folderID)` instead of calling `openFolder(folderID:)` directly. Keep `openFolder(folderID:)` as the state+overlay primitive (it is still called via `onOpenFolder`). The click must NOT set keyboard focus on the folder cell (click-focus repair behavior preserved: mouse interaction shows no outer ring).
3. **Tests** (Tests/PagingUITests/FolderIntegrationTests.swift or new file in PagingUITests) — wire the click handler through the keyboard seam (onFolderClick → keyboard.openFolderFromClick; keyboard.onOpenFolder → open state + configure overlay; keyboard.folderOpenStateProvider / folderOverlayProvider wired):
   - (a) Set outer focus first (keyboard.setFocus(to: an app identity)), then click folder → `keyboard.focusModel.current == nil` (outer ring cleared) AND `overlay.memberCell(at: 0)?.isFocused == true` (inner ring on member 1).
   - (b) Keyboard-open (arrow-select folder + Return via `keyboard.keyDown(with:)`) → inner ring on member 1.
   - (c) After click-open, simulate a right-arrow keyDown → ring moves to `memberCell(at: 1)` (inner navigation works after mouse-open).
   - (d) Update the existing click-open test wiring to the new seam; click still opens immediately (no Return needed).
   - Existing tests (arrow-select + Return open, app cell launch, blank-click) must keep passing.

## Read scope (read ONLY these)

- Sources/PagingPrototypeApp/KeyboardFocusController.swift (openFolder, applyInnerFocusVisual, handleInnerArrow, closeFolder, isFolderOpen)
- Sources/PagingPrototypeApp/AppDelegate.swift (handleFolderCellClick, openFolder(folderID:), openFolder(_ identity:), installFolderWiring)
- Tests/PagingUITests/FolderIntegrationTests.swift (existing patterns incl. testFolderCellClickOpensImmediately to rewire)
- Sources/AppGridUI/FolderOverlayView.swift (only memberCell(at:)/memberCellCount/isFocused read access for tests — do NOT modify)

## Write scope

- Sources/PagingPrototypeApp/KeyboardFocusController.swift
- Sources/PagingPrototypeApp/AppDelegate.swift
- Tests/PagingUITests/FolderIntegrationTests.swift (or new test file in PagingUITests)

## Verification (run these)

- `swift build -c debug` → exit 0
- `swift test` → executed > 0, 0 failures, exit 0 (baseline 767)
- `swift build -c release` → exit 0

## Forbidden

- All frozen trees: Sources/PagingCore/, Sources/AppCatalogCore/, Sources/MacAppCatalog/, Sources/AppIconPipeline/, Sources/PagingTelemetry/, Sources/PagingUI/, Package.swift, Sources/PagingPrototypeApp/AppLaunchController.swift.
- Sources/AppGridUI/FolderOverlayView.swift (parallel task T-1E-folder-inner-nav-repair owns it).
- No git ops. No telemetry/schema change. No folder title/membership raw values in telemetry/logs.

## Output discipline (CRITICAL — prior workers died from context exhaustion)

1. FIRST action after reading the spec: write `Workflow/results/T-1E-folder-mouse-open-repair.md` with "in progress" so progress is never lost.
2. Implement in small steps; run the full suite once at the end (builds serialize on the SwiftPM lock; retry on contention).
3. Final reply: < 250 words, NO large code blocks (describe what changed in one line each).

## Acceptance

- swift build -c debug: exit 0; swift test: executed > 0, 0 failures, exit 0; swift build -c release: exit 0
- Frozen trees untouched (mtime check)
- Mouse-open: outer ring cleared, inner ring visible on member 1, left/right arrows move the inner ring
- Result file: Workflow/results/T-1E-folder-mouse-open-repair.md
