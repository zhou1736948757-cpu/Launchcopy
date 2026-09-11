# Task Packet: T-1E-D

- **Task ID**: T-1E-D
- **Role**: Worker D (fresh context — must not inherit any old reverse-engineering context)
- **Phase**: 1E — keyboard / focus / title editing
- **Prompt**: `Docs/PHASE1E_FOLDER_FOUNDATION_PROMPT.md` §6 T-1E-D, §9.5
- **ADR**: `Docs/ADR-008-FOLDER-PRESENTATION.md` (Chief DRAFT — read it; you implement the keyboard/focus/title behavior it describes)

## Objective

Implement the **keyboard/focus/title-editing** behavior: Return/Enter open-vs-launch routing, inner arrows/paging/focus restore, ESC priority, Command-F closes folder then search, title editing Enter/Escape/focus-loss, key-window responder rebuild, and no global listeners.

## Dependencies

- **T-1E-B** (top-level composition/provider) and **T-1E-C** (folder cell/overlay/open layer) — both must be complete.

## Context

**Fresh Context requirement (source discipline)**: fresh context, no old reverse-engineering context. Never read the forbidden sources (see T-1E-A).

**Key existing seams (read-only)**:
- `KeyboardFocusController` (318 lines): single keyboard first responder; `onActivate`/`onSearchShortcut`; `keyDown`/`performKeyEquivalent`; `handleArrow`; `setFocus(to:)`; `clearFocusForSearch()`; `applyLayout(_:)`; `reconcileSettledCrossPage(committedPage:)`; `exitKeyboardSelection()`; `KeyCodes` (escape 53, return 36, keypadEnter 76, arrows 123-126, commandF 3).
- `AppSearchController` (260 lines): `activateSearch()`; `exitSearchAndRestoreFocus()`; `isSearchActive`; `control(_:textView:doCommandBy:)`; `transferFocusToFirstResult()`; `commitPendingAtIdleBoundary()`; `rebuildFirstResponder()`.
- `AppGridFocusLayout`/`AppGridFocusModel`/`AppGridFocusNavigator` (read-only; focus identity generalized in T-1E-A).
- `AppGridCellView`/`AppGridPageView`/overlay (T-1E-C, read-only).

## Scope

- **Return/Enter open-vs-launch routing**: focused top-level folder → open folder (not launch); focused top-level app → existing launch; focused folder member → existing launch. Use the unified activation router (T-1E-A).
- **Inner arrows/paging/focus restore**: when a folder is open, arrows move only within members; member cross-page keeps focus/page consistent; after close, focus restores to the folder entry (documented fallback if it vanished).
- **ESC priority**: if editing title → cancel/end edit; else if folder open → close folder; else → existing ESC clear-grid-selection.
- **Command-F**: if folder open → safely close folder, then enter global search.
- **Title editing** (session-only): explicit enter-edit interaction; blank-title normalization/fallback; length cap + Unicode safety; Enter commit / Escape cancel / focus-loss deterministic; during editing arrows/Return must not launch apps; title never enters telemetry/stdout/JSONL/signpost/profile/report; no disk write.
- **key-window responder rebuild**: window re-becomes key → rebuild correct first responder per current mode (title editing / folder open / search / top-level).
- **Tab** not swallowed (falls through to AppKit).
- **No global listeners**: no global NSEvent monitor / Accessibility / Input Monitoring.
- **Tests**: keyboard/responder/title tests (top-level folder Return/Enter opens not launches; member Return/Enter launches; inner four-direction movement; inner cross-page focus/page consistent; ESC title-edit → folder → top-level priority; Command-F closes folder then search; close restores original folder focus; folder vanished → safe fallback; Tab to AppKit; key-window rebuild; blank-click two-stage semantics).

## Out of Scope

- Folder cell/overlay rendering (T-1E-C).
- Provider/presentation composition (T-1E-B).
- AppDelegate / assembly / launch / blank-click integration (T-1E-E).
- Modifying `Sources/PagingCore/`, `Sources/AppCatalogCore/`, `Sources/MacAppCatalog/`, `Sources/AppIconPipeline/`, `Sources/PagingTelemetry/`, `Package.swift`, `Sources/PagingPrototypeApp/AppLaunchController.swift`.
- Drag / persistence / Hot Corner / Spotlight / Launchpad-Dock DB / brand visuals.

## Expected / Allowed Write Scope

- `Sources/PagingPrototypeApp/KeyboardFocusController.swift`
- `Sources/PagingPrototypeApp/AppSearchController.swift`
- New title-editor + focus code in `Sources/PagingPrototypeApp/` (e.g. `FolderTitleEditor.swift`)
- New keyboard/focus/title tests (in `Tests/AppGridUITests/` or `Tests/PagingPrototypeAppTests/` as appropriate)

## Forbidden Write Scope

- `Sources/AppGridUI/AppGridCellView.swift`, `AppGridPageView.swift`, folder overlay/open-layer views (T-1E-C's files — read-only).
- `Sources/PagingPrototypeApp/AppLaunchController.swift` (frozen).
- `Sources/PagingUI/` (frozen).
- `Sources/PagingCore/`, `Sources/AppCatalogCore/`, `Sources/MacAppCatalog/`, `Sources/AppIconPipeline/`, `Sources/PagingTelemetry/`, `Package.swift`.
- `Tests/PagingUITests/`, `Tests/PagingCoreTests/` and other teams' test dirs.

## Constraints

- No global NSEvent monitor / Accessibility / Input Monitoring.
- Folder identity never passes through app launch validation.
- Title text never enters telemetry/stdout/JSONL/signpost/profile/report; only neutral counters. No PagingTelemetry schema change.
- No commit/push/tag/reset/clean/release; do not modify LaunchBetter / BuhoReverseNotes.
- Diagnostics stay `CAUSALITY_UNRESOLVED` / `PARTIAL_CONTRIBUTOR_SUPPORTED` / `PRODUCT_DEFAULT_UNCHANGED`.

## Acceptance

- `KEYBOARD_RESPONDER_TESTS = PASS`: Return/Enter open-vs-launch routing; inner arrows/paging/focus restore; ESC priority; Command-F closes folder then search; title editing Enter/Escape/focus-loss; key-window responder rebuild; no global listeners.
- Privacy redline clean.
