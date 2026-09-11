# T-1E-folder-deferred-inner-focus-repair

- Status: PASS
- Phase: 1E (folder foundation)
- Files changed:
  - `Sources/PagingPrototypeApp/KeyboardFocusController.swift` — removed `applyInnerFocusVisual()` from `openFolder` and `openFolderFromClick`; updated both doc comments to state deferred inner-ring display (first arrow key, consistent with `isDeferredSelection`). State init preserved in both paths (`innerFocusIndex = 0`, `focusModel = AppGridFocusModel(current: nil)`, `applyFocusVisual()`, `onOpenFolder?(identity)`).
  - `Tests/PagingUITests/FolderIntegrationTests.swift` — renamed `testMouseOpenClearsOuterRingAndShowsInnerRing` → `testMouseOpenClearsOuterRingAndDefersInnerRing` and `testKeyboardOpenShowsInnerRingOnMemberOne` → `testKeyboardOpenDefersInnerRingUntilFirstArrow`; all three tests now assert `memberCell(at: 0)?.isFocused == false` on open, then `memberCell(at: 1)?.isFocused == true` after first `rightArrow()` keyDown. `testMouseOpenThenRightArrowMovesInnerRing` keeps its post-arrow assertions.
  - `Workflow/results/T-1E-folder-deferred-inner-focus-repair.md` (this file).
- Verification:
  - `swift build -c debug` → exit 0.
  - `swift test` → "Executed 772 tests, with 0 failures (0 unexpected)" (baseline 772, no flaky rerun needed).
  - `swift build -c release` → exit 0.
  - Frozen-tree mtime check: newest frozen file (`Sources/PagingPrototypeApp/AppDelegate.swift`, 1788090949) and all frozen trees predate edits (KeyboardFocusController.swift 1788091607, FolderIntegrationTests.swift 1788091614). No frozen tree touched.
- Deviations: none.
