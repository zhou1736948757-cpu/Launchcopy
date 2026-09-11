# T-1D-blankclick-exit-search-repair

- **Type**: real-GUI defect (user behavior spec, decision_recorded)
- **Phase**: 1D
- **User spec (verbatim)**: "进入搜索状态，比如是空搜索情况下，就是我只是点击了搜索框，然后没开始搜索情况下，那我点一下非搜索框的部分，我应该是退出搜索状态，而不是退出整个软件。"
- **Current behavior (defect)**: `QuitOnBlankClickWindow.sendEvent` (Sources/PagingPrototypeApp/AppDelegate.swift:491-509 region) intercepts every real `.leftMouseDown` on the window; hit resolves via shared `blankClickResolvesToCell(_:)` (AppDelegate.swift:498-505, extended by `AppSearchFieldView.isSearchFieldOrSubview(_:)`); cell/icon/label/search-field hit → `super.sendEvent` pass-through; ANY OTHER hit → `onBlankClick` → `NSApp.terminate`. So clicking blank while IN search state (field focused, even with empty query) terminates the app — user wants exit-search instead.
- **Expected behavior**:
  - While search state is ACTIVE (search field is first responder / editing, OR a query is staged — canonical case: user clicked the field, empty query, nothing searched yet), a click on a blank area (non-cell, non-field, non-interaction-zone) → **exit search state only**: clear query if any, deactivate search UI, restore normal catalog presentation, restore `KeyboardFocusController` as first responder (same semantics as the existing Escape-empty path). CONSUME the click — do not pass through, do not terminate.
  - Normal mode (search inactive): blank click → **terminate** (unchanged, previously user-approved feature "点一下空白就退出"; blank-click regression gate must stay green).
  - Cell result click during search → launch (unchanged pass-through); search field/clear-button click → pass-through (unchanged).
- **Design freedom for Worker** (minimal, no overstepping):
  - Add ONE minimal public seam, e.g. on `AppSearchController`: `var isSearchActive: Bool` = field-is-first-responder OR editing OR staged/current query non-nil (Worker chooses exact definition; must be true in the canonical empty-query-focused case).
  - Reuse/refactor the existing Escape-empty exit routine into a single callable (e.g. `exitSearchAndRestoreFocus()`) so blank-click and Escape-empty share ONE code path — no duplicated exit logic.
  - `QuitOnBlankClickWindow.sendEvent`: before terminate decision, consult the seam; if search active → invoke exit-search, consume event (return without super.sendEvent), app stays alive.
  - Do NOT change: cell/field/icon pass-through conditions; normal-mode terminate; launch funnel (AppLaunchController unchanged); search semantics elsewhere (Command-F / Escape / Down / Return / Enter flows untouched).
- **Tests required** (extend Tests/PagingUITests/BlankClickToQuitTests.swift and/or Tests/PagingUITests/AppSearchControllerTests.swift, headless-safe patterns like existing suite):
  1. field focused + empty query → blank click exits search (search inactive after, keyboard focus restored, app ALIVE);
  2. non-empty query → blank click clears query + exits search, app ALIVE;
  3. normal mode (search inactive) blank click → app terminates (existing blank-click tests keep passing);
  4. result-cell click during search → launch still works (pass-through intact).
- **Gate**: full `swift test` green (≥622 executed + new, 0 failures); filter `BlankClickToQuitTests` and `AppSearchControllerTests` green; `swift build -c debug` exit 0; `swift build -c release` exit 0; forbidden trees untouched (`Sources/PagingCore/`, `Sources/MacAppCatalog/`, `Package.swift`, `Sources/PagingPrototypeApp/AppLaunchController.swift`); no git ops; privacy untouched (no query/result names in logs/telemetry).
- **Write scope**: `Sources/PagingPrototypeApp/AppDelegate.swift` (QuitOnBlankClickWindow + wiring), `Sources/PagingPrototypeApp/AppSearchController.swift` (seam + shared exit routine only), Tests above, `Workflow/results/T-1D-blankclick-exit-search-repair.md`.
- **Result**: `Workflow/results/T-1D-blankclick-exit-search-repair.md` (changed lines, test totals, build exits, forbidden-tree verification).
