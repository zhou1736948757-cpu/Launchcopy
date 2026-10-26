# T-1J-LM-WIRING — Layout Mode and Folder Lifecycle Integration

Status: BLOCKED_ON_DEPENDENCIES
Owner: Worker

## Objective

Wire the accepted grid-mode and Folder-motion contracts into the composition root while preserving immediate logical lifecycle behavior.

## Dependencies

- `T-1J-LM-GRID`
- `T-1J-LM-MOTION`

## Scope

Propagate committed mode from `provider.activeQuery` through `AppGridRenderer` to all pages. Resolve source Folder cells by `FolderID`, convert their live frames after overlay layout, and pass explicit pointer/keyboard/lifecycle triggers. Keep close synchronous, restore drag host immediately, cancel visuals on reopen/hide/resize/teardown, and preserve refresh/move-out behavior.

## Expected / Allowed Write Scope

- `Sources/PagingPrototypeApp/AppCatalogAssembly.swift`
- `Sources/PagingPrototypeApp/AppDelegate.swift`
- `Tests/PagingUITests/FolderIntegrationTests.swift`
- `Tests/PagingUITests/AppCatalogAssemblyTests.swift`
- `Workflow/results/T-1J-LM-WIRING.md`

## Acceptance Criteria

- Pending search input cannot change visible layout; committed search can.
- Pointer Folder open/close is anchored when live geometry is valid; keyboard/Escape/Command-F/hide/move-out/teardown remain immediate.
- Logical close and drag-host restoration precede any exit visual; no residual hit-testing or accessibility surface remains.
- Existing click, focus, search, drag, persistence, and wallpaper behavior is preserved.

## Required Verification

- Run focused `PagingUITests` and relevant AppGridUI regression filters with nonzero executed counts.
- Record changed files, tests, lifecycle evidence, deviations, risks, and Reviewer focus.

## Prohibitions

Do not edit `LauncherWindowController.swift`, `PagingCore`, persistence/schema, drag intent, `Package.swift`, packaging scripts, workflow decisions/stage summaries, or forbidden source trees. Escalate if one is required. No commit/push.

