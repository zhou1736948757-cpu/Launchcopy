# Worker D Result — T-1D-D

- **Task**: T-1D-D — AppKit search UI / responder layer (Command-F, first-responder transfer/restore, Escape/Down/Return semantics, Phase 1C F3 follow-up)
- **Role**: Worker D (fresh context; no inherited reverse-engineering material)
- **Phase**: 1D — AppKit 搜索 field / responder / controller
- **Status**: COMPLETE

## What was implemented

### `Sources/PagingPrototypeApp/AppSearchFieldView.swift` (NEW)
- Neutral `NSSearchField` (public AppKit control, system font/color, no third-party brand, no prefill/history/persistence).
- Accessible label + neutral placeholder `"Search applications"`.
- `static isSearchFieldOrSubview(_:)` — blank-click interaction-zone classification helper (ADR-007 §2.7) for Worker E to extend `blankClickResolvesToCell`. Covers: the field itself, its subviews (clear button, along superview chain), and the field editor (`NSTextView` whose delegate is an `NSSearchField`).

### `Sources/PagingPrototypeApp/AppSearchController.swift` (NEW)
- Owns the `AppSearchFieldView`; is its `NSSearchFieldDelegate`.
- **Command-F** (`activateSearch`) → field becomes first responder + clears old grid focus visual (avoids double focus).
- **Real-time input** (`controlTextDidChange`) → `presentation.updateQuery` (latest-wins query generation) + commit at idle boundary when surface idle.
- **Escape non-empty** → clears field text + `presentation.clearQuery()` (restores full catalog), keeps field first responder.
- **Escape empty** → leaves field, restores `KeyboardFocusController` first responder, keeps deferred focus (no auto box).
- **↓ / Return/Enter** with committed results → transfers focus to first valid result on current displayed page (first time does NOT launch); after grid focus established, Return/Enter launches via existing `KeyboardFocusController.onActivate` pipeline.
- **No committed results or pending generation** → Return/Enter does NOT transfer/launch old results.
- **Tab / Shift-Tab** → returned false (AppKit responder chain, not swallowed).
- **F3 follow-up** (`install(in:)` observes `NSWindow.didBecomeKeyNotification`) → rebuilds correct first responder on window re-key / system focus steal per current state (search active → field; inactive → keyboard controller).
- `commitPendingAtIdleBoundary()` public seam for Worker E to call from `surface.onIdleBoundary` (covers busy-state pending commits).
- Privacy: query raw/normalized/result names never logged; only in-memory.

### `Sources/PagingPrototypeApp/KeyboardFocusController.swift` (minimal, documented — allowed for responder transfer/restore)
- Added `onSearchShortcut` closure + Command-F handling in `performKeyEquivalent` (keyCode 3 + `.command`).
- Added `clearFocusForSearch()` (clears grid focus visual, returns to deferred state).
- Added `setFocus(to:)` (sets focus to a specific identity, exits deferred state).
- Added `commandF` key code constant.

## Tests

### `Tests/PagingUITests/AppSearchControllerTests.swift` (NEW) — 11 tests
`testCommandFEntersSearch`, `testTypingUpdatesQueryAndCommits`, `testRapidTypingLatestWins`, `testEscapeNonEmptyClearsQueryKeepsField`, `testEscapeEmptyExitsRestoresKeyboardDeferred`, `testDownTransfersFocusToFirstResultNoLaunch`, `testReturnTransfersFocusThenGridReturnLaunchesOnce`, `testTabNotSwallowed`, `testNoCommittedResultsReturnDoesNotLaunch`, `testPendingGenerationReturnDoesNotTransfer`, `testNoResultsNoFakeFocusNoLaunch`.

### `Tests/PagingUITests/AppSearchResponderTests.swift` (NEW) — 5 tests
`testCommandFClearsGridFocusVisual`, `testWindowReKeyRestoresSearchFieldWhenActive`, `testWindowReKeyRestoresKeyboardWhenInactive`, `testResizeSafe`, `testTeardownSafe`.

## Verification (run by Worker D)

| Check | Result |
|---|---|
| `swift test --filter AppSearch` | PASS — 49 tests, 0 failures (incl. 16 new: 11 controller + 5 responder) |
| `swift test` (full) | PASS — 609 tests, 0 failures |
| `swift build -c debug` | PASS — exit 0 |
| `swift build -c release` | PASS — exit 0 |
| Conflict markers in my files | none |
| Trailing whitespace in my files | none |

## Forbidden-tree verification

Confirmed unchanged (mtimes predate this work; only the 5 in-scope files were created/edited):
- `Sources/PagingCore/` — untouched (FROZEN).
- `Sources/AppGridUI/AppGridUIPageContentProvider.swift`, `AppGridSearchPresentationController.swift`, `AppSearchQuery.swift`, `AppSearchMatcher.swift`, `AppSearchResultSet.swift` — untouched.
- `Sources/PagingUI/PagingSurface.swift` — untouched.
- `Sources/PagingPrototypeApp/AppLaunchController.swift`, `AppDelegate.swift` — untouched (Worker E owns AppDelegate wiring).
- `Package.swift` — untouched.
- No `CatalogRevision` minted/forged; seven-field `ItemBindingToken` unchanged.
- No global NSEvent monitor, no Accessibility/Input Monitoring, no Spotlight/FDA.
- No `PagingTelemetry` schema change; query/result names never in telemetry/log/stdout/signpost/profile/report.
- Timer tolerance 8.333ms unchanged; diagnostics remain `CAUSALITY_UNRESOLVED` / `PARTIAL_CONTRIBUTOR_SUPPORTED` / `PRODUCT_DEFAULT_UNCHANGED`.
- No commit/push/tag/reset/clean. Forbidden sources (BuhoReverseNotes / LaunchBetter) never read.

## Deviations

- None. `KeyboardFocusController.swift` was modified only for the explicitly-assigned responder transfer/restore seams (Command-F, clear-focus, set-focus), kept minimal and documented.
- The busy-state pending commit path is exposed via `commitPendingAtIdleBoundary()` for Worker E to wire into `surface.onIdleBoundary`; the idle-path commit is handled internally by the controller.

---
**Summary**: T-1D-D — 16 new tests pass (11 controller + 5 responder), full suite 609/0, debug+release build PASS.
