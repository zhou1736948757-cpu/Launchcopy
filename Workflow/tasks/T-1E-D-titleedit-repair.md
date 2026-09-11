# Task Packet: T-1E-D-titleedit-repair

- **Task ID**: T-1E-D-titleedit-repair
- **Role**: Worker (fresh context — must not inherit any old reverse-engineering context)
- **Phase**: 1E — repair of T-1E-D MAJOR finding (Reviewer 5d79a69b, Workflow/reviews/T-1E-D-r1.md)
- **ADR**: `Docs/ADR-008-FOLDER-PRESENTATION.md` (Accepted)

## Objective

Fix the MAJOR finding: Command-F during title editing leaves `isEditingTitle` stale.

## Root cause (from Reviewer)

In `KeyboardFocusController.performKeyEquivalent`, Command-F is handled BEFORE the `isEditingTitle` guard, and `closeFolder()` does not reset `isEditingTitle`. After search exits and the keyboard controller regains first responder, arrows/Return fall through to `super` and navigation is dead until ESC.

## Fix

- Reset `isEditingTitle = false` in `closeFolder()` (single source of truth for folder-close state).
- Add a regression test: Command-F during title editing → folder closes → search activates → search exits → keyboard controller regains first responder → arrows/Return navigate again (not dead).
- Also verify the same stale-flag class is covered for the other folder-close paths reachable in this task's scope (overlay clear / blank-click close are T-1E-E wiring — note in result doc that T-1E-E must call `endTitleEditing()` on all folder-close paths; do NOT implement T-1E-E wiring here).

## Write Scope

- `Sources/PagingPrototypeApp/KeyboardFocusController.swift` (minimal: isEditingTitle reset in closeFolder())
- `Sources/AppGridUI/FolderKeyboardLogic.swift` (only if the regression test needs a pure-logic seam; prefer testing through KeyboardFocusController if possible)
- Tests in `Tests/AppGridUITests/` (regression test)

## Forbidden Write Scope

- `Sources/AppGridUI/AppGridCellView.swift`, `AppGridPageView.swift`, folder overlay/open-layer views (T-1E-C's files)
- `Sources/PagingPrototypeApp/AppLaunchController.swift` (frozen)
- `Sources/PagingUI/` (frozen)
- `Sources/PagingCore/`, `Sources/AppCatalogCore/`, `Sources/MacAppCatalog/`, `Sources/AppIconPipeline/`, `Sources/PagingTelemetry/`, `Package.swift`
- `Tests/PagingUITests/`, `Tests/PagingCoreTests/`
- NEVER read forbidden sources: BuhoReverseNotes, LaunchBetter, 2026-08-25-buho-launchpad-reverse

## Constraints

- No global NSEvent monitor / Accessibility / Input Monitoring.
- Folder identity never passes through app launch validation.
- Title text never enters telemetry/stdout/JSONL/signpost/profile/report; only neutral counters. No PagingTelemetry schema change.
- No commit/push/tag/reset/clean/release.
- Diagnostics stay CAUSALITY_UNRESOLVED / PARTIAL_CONTRIBUTOR_SUPPORTED / PRODUCT_DEFAULT_UNCHANGED.

## Acceptance

- `TITLEEDIT_STALE_FLAG_REPAIR = PASS`: isEditingTitle reset in closeFolder(); regression test proves Command-F-during-title-edit → search exit → navigation alive; full suite ≥ 741/0; debug+release exit 0; frozen trees untouched.
- Privacy redline clean.
