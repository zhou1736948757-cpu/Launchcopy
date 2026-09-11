# Task Packet: T-1E-E

- **Task ID**: T-1E-E
- **Role**: Worker E (fresh context — must not inherit any old reverse-engineering context)
- **Phase**: 1E — AppDelegate integration / refresh / search / launch / blank-click
- **Prompt**: `Docs/PHASE1E_FOLDER_FOUNDATION_PROMPT.md` §6 T-1E-E, §9.6
- **ADR**: `Docs/ADR-008-FOLDER-PRESENTATION.md` (Chief DRAFT — read it; you implement the integration it describes)

## Objective

Wire the folder foundation into the composition root: lab flag/test-injection wiring, member launch reusing `AppLaunchController`, folder cell never entering app launch, search/refresh/folder pending priority, overlay-outside click closes + next real background click exits, and teardown full chain.

## Dependencies

- **T-1E-B** (top-level composition/provider), **T-1E-C** (folder cell/overlay/open layer), **T-1E-D** (keyboard/focus/title) — all complete. **Serial** integration task.

## Context

**Fresh Context requirement (source discipline)**: fresh context, no old reverse-engineering context. Never read the forbidden sources (see T-1E-A).

**Key existing seams (read-only)**:
- `AppDelegate` (636 lines): `installContentAssembly`; `applyPresentationUpdate(_:overridePageCount:)`; `applyPendingAtIdleBoundary()` (search-first commit); `QuitOnBlankClickWindow.sendEvent` + `onBlankClickShouldExitSearch` + `onBlankClick`; `blankClickResolvesToCell(_:)`; `teardownAll()`.
- `AppCatalogAssembly` (383 lines): `dataSource`/`provider`/`refreshController`/`urlResolver`/`searchPresentation`; `onPresentationUpdate`; `begin()`/`teardown()`.
- `AppArguments` (Options): `pagingLab`, `pageCount`, `itemsPerPage`, `neutralContent`, `frameDriver`, `reduceMotionOverride`, `fullscreen`, `telemetryEnabled`, `runID`, etc.
- `AppLaunchController` (154 lines, **frozen**): `handleCell(_:)` → `launch(from:)` (stale revision → identity in catalog → file existence → `NSWorkspace`); `as? AppID` cast rejects non-AppID identities.

## Scope

- **Lab flag / test injection wiring**: add an explicit `--folder-lab` flag (or equivalent) to `AppArguments`; wire the folder lab fixture (T-1E-A) into the assembly. Default product launch must **not** reorder user apps; lab is off by default. Auto tests fully inject a folder snapshot (no machine dependency).
- **Member launch reuses `AppLaunchController`**: folder member activation resolves the member `AppID` and calls the existing `AppLaunchController` pipeline. No parallel launch path.
- **Folder cell never enters app launch**: the unified activation router (T-1E-A) branches folder → open; the launch path's `as? AppID` cast rejects folder identities.
- **Search/refresh/folder pending priority**: implement the fixed baseline (new catalog snapshot > rebuild folder composition on new base > re-run search on new base > restore/close folder open state > relayout/focus reconcile). Search generation / folder generation / surface generation never impersonate each other.
- **blank-click two-stage**: clicking outside the open layer closes the folder only (does not exit); next real background click (folder closed) exits. Extend `blankClickResolvesToCell`/`QuitOnBlankClickWindow` interaction-zone classification for the open layer.
- **teardown full chain**: teardown leaves no responder/notification/animation callbacks; folder open state cleared.
- **Tests**: integration tests (lab flag wiring; member launch reuses `AppLaunchController`; folder cell never enters launch; search/refresh/folder pending priority; overlay-outside click closes + next real background click exits; teardown full chain).

## Out of Scope

- Folder cell/overlay rendering (T-1E-C).
- Keyboard/focus/title editing (T-1E-D).
- Provider/presentation composition (T-1E-B).
- Modifying `Sources/PagingCore/`, `Sources/AppCatalogCore/`, `Sources/MacAppCatalog/`, `Sources/AppIconPipeline/`, `Sources/PagingTelemetry/`, `Package.swift`, `Sources/PagingPrototypeApp/AppLaunchController.swift`.
- Drag / persistence / Hot Corner / Spotlight / Launchpad-Dock DB / brand visuals.

## Expected / Allowed Write Scope

- `Sources/PagingPrototypeApp/AppDelegate.swift`
- `Sources/PagingPrototypeApp/AppCatalogAssembly.swift`
- `Sources/PagingPrototypeApp/AppArguments.swift` (lab flag)
- New integration tests (e.g. `Tests/PagingPrototypeAppTests/FolderIntegrationTests.swift`)

## Forbidden Write Scope

- `Sources/PagingPrototypeApp/AppLaunchController.swift` (frozen).
- `Sources/PagingUI/` (frozen).
- `Sources/AppGridUI/` (read-only).
- `Sources/PagingCore/`, `Sources/AppCatalogCore/`, `Sources/MacAppCatalog/`, `Sources/AppIconPipeline/`, `Sources/PagingTelemetry/`, `Package.swift`.
- `Tests/PagingUITests/`, `Tests/PagingCoreTests/` and other teams' test dirs.

## Constraints

- Catalog revision single source = existing owner; folder layer never forges `CatalogRevision`.
- No global NSEvent monitor / Accessibility / Input Monitoring.
- Folder identity never passes through app launch validation.
- Privacy: folder title / membership / identity raw values and icon data **never** enter telemetry/JSONL/stdout/signpost/profile/report; only neutral counters. No PagingTelemetry schema change.
- No commit/push/tag/reset/clean/release; do not modify LaunchBetter / BuhoReverseNotes.
- Diagnostics stay `CAUSALITY_UNRESOLVED` / `PARTIAL_CONTRIBUTOR_SUPPORTED` / `PRODUCT_DEFAULT_UNCHANGED`.

## Acceptance

- `SEARCH_REFRESH_LAUNCH_INTEGRATION_TESTS = PASS`: lab flag/test-injection wiring; member launch reuses `AppLaunchController`; folder cell never enters app launch; search/refresh/folder pending priority; overlay-outside click closes + next real background click exits; teardown full chain.
- Privacy redline clean.
