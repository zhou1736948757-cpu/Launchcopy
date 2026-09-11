# Task Packet: T-1E-A

- **Task ID**: T-1E-A
- **Role**: Worker A (fresh context — must not inherit any old reverse-engineering context)
- **Phase**: 1E — ADR-008 draft + pure folder domain model + lab fixture + focus-identity generalization
- **Prompt**: `Docs/PHASE1E_FOLDER_FOUNDATION_PROMPT.md` §4, §6 T-1E-A, §9.2
- **ADR**: `Docs/ADR-008-FOLDER-PRESENTATION.md` (Chief DRAFT — read it; you implement the domain model it describes)

## Objective

Build the **pure, neutral folder domain model** and the **folder lab fixture** for Phase 1E, and generalize the grid-entry identity to a neutral top-level entry kind. All pure logic, no AppKit, fully unit-testable. Also produce the **ADR-008 draft** (Chief-authored; you may refine the draft file but the canonical ADR is Main-transcribed).

## Dependencies

- **None** (pure logic; read-only existing types `AppRecord`, `CatalogSnapshot`, `CatalogRevision`, `AppID`, `AppGridFocusIdentity`).

## Context

**Fresh Context requirement (source discipline)**: use a fresh context that does not inherit old reverse-engineering context. Only receive: this packet, the Phase 1E prompt, Apple public docs, and this project's own files. **Never read**: `/Users/mac/Projects/BuhoReverseNotes/` (all), `/Users/mac/Projects/LaunchBetter/` (all), `2026-08-25-buho-launchpad-reverse`. On accidental contact → `PROVENANCE/CONTAMINATION_LOG.md` + `BLOCKED_FOR_REVIEW`.

**Key existing types (read-only)**:
- `AppRecord` (`AppCatalogCore`): `id: AppID`, `displayName: String`, `bundleIdentifier: String?`, `canonicalURL: URL`, `iconIdentity: IconIdentity`, `sourceRootPriority: Int`.
- `CatalogSnapshot`: `revision: CatalogRevision`, `records: [AppRecord]` (stable sorted/deduped).
- `CatalogRevision`: `value: UInt64`, `zero`, `incremented()`, `Comparable`.
- `AppGridFocusIdentity` (`AppGridUI`): currently `catalogRevision: UInt64`, `pageIndex: Int`, `slotIndex: Int`, `appID: AppID?`, `presentationID: PagePresentationID`.
- `AppSearchGeneration` (`AppGridUI`): monotonic latest-wins token independent of `CatalogRevision` — the pattern to mirror for folder generation.

## Scope

- **Folder domain model** (pure, no AppKit):
  - Stable, non-name `FolderID` (opaque Hashable identity; never derived from title/name/path).
  - `FolderEntry`: `FolderID` + title + ordered members (`[AppID]`).
  - `FolderSnapshot`: immutable collection of `FolderEntry` + a **folder generation** token (monotonic latest-wins, independent of `CatalogRevision`; never mints/forges a `CatalogRevision`).
  - Title normalization: trim; blank-title fallback (neutral, e.g. `Group N`); length cap; Unicode-safe (no crash, no log leak).
  - Membership rules: stable order, no duplicates; deterministic member-shrink on refresh (removed member removed; empty folder removed; **single-member folder dissolves** — the member app appears directly as an app entry at top level; folder entry exists only with ≥ 2 members; per ADR-008 §2.4, user decision 2026-08-30).
  - `TopLevelEntry` (enum `.app(AppRecord)` / `.folder(FolderEntry)`): the neutral top-level entry kind.
  - **Activation router decision** (pure): given a top-level entry kind, return `.openFolder` or `.launchApp` (the AppKit wiring is T-1E-D/E). Folder identity must never route to launch.
- **Folder lab fixture** (pure, deterministic, no I/O, no machine dependency):
  - `FolderLabFixture.makeGroups(from: CatalogSnapshot, ...)`: builds session-only groups from the committed catalog using a simple deterministic rule (e.g., first N apps in stable catalog order per group). Neutral titles (`Group 1`, …). Default **off** (product launch must not reorder user apps). No disk persistence.
- **Focus-identity generalization** (pure): generalize `AppGridFocusIdentity` to carry a neutral top-level entry identity (app `AppID` or folder `FolderID`) instead of only `AppID`. Keep existing app behavior backward-compatible.
- **ADR-008 draft**: refine `Docs/ADR-008-FOLDER-PRESENTATION.md` (Chief DRAFT) if needed; the canonical ADR is Main-transcribed. The ADR must compare the two approaches and answer the 14 questions (already drafted — verify consistency with your domain model).

## Out of Scope

- AppKit responder / cell / overlay views (T-1E-C).
- Provider / presentation composition (T-1E-B).
- Keyboard / focus controller / title editing (T-1E-D).
- AppDelegate / assembly / launch / blank-click integration (T-1E-E).
- Modifying `Sources/PagingCore/`, `Sources/AppCatalogCore/`, `Sources/MacAppCatalog/`, `Sources/AppIconPipeline/`, `Sources/PagingTelemetry/`, `Package.swift`, `Sources/PagingPrototypeApp/AppLaunchController.swift`.
- Drag / persistence / Hot Corner / Spotlight / Launchpad-Dock DB / brand visuals.

## Expected / Allowed Write Scope

- New pure-domain files in `Sources/AppGridUI/` (folder domain: `FolderID`, `FolderEntry`, `FolderSnapshot`, folder generation, title normalization, membership rules, `TopLevelEntry`, activation-router decision; lab fixture). Concrete file names are your choice.
- Modify `Sources/AppGridUI/AppGridFocusIdentity.swift` (generalize to neutral entry identity; keep app behavior backward-compatible).
- New tests in `Tests/AppGridUITests/` (folder domain, lab fixture, focus-identity generalization).
- `Docs/ADR-008-FOLDER-PRESENTATION.md` (Chief DRAFT — refine only; do not mark Accepted).

## Forbidden Write Scope

- `Sources/PagingCore/`, `Sources/AppCatalogCore/`, `Sources/MacAppCatalog/`, `Sources/AppIconPipeline/`, `Sources/PagingTelemetry/`, `Package.swift`.
- `Sources/PagingUI/` (frozen).
- `Sources/PagingPrototypeApp/` (all).
- `Sources/AppGridUI/AppGridUIPageContentProvider.swift`, `AppGridSearchPresentationController.swift`, `AppGridUIState.swift`, `AppGridCellView.swift`, `AppGridPageView.swift`, `AppGridRefreshController.swift`, `ItemBindingToken.swift` (read-only).
- `Tests/PagingUITests/`, `Tests/PagingCoreTests/` and other teams' test dirs.

## Constraints

- Pure logic, no AppKit, no I/O, no machine dependency, no disk persistence.
- Folder generation independent of `CatalogRevision`; never mint/forge a `CatalogRevision`.
- Folder identity never passes through app launch validation (the launch path's `as? AppID` cast rejects it).
- Privacy: folder title / membership / identity raw values and icon data **never** enter telemetry/JSONL/stdout/signpost/profile/report; only neutral counters (`folder_count`, `member_count`, open/close outcome enum, stale rejection count, apply-duration numeric). No PagingTelemetry schema change.
- No commit/push/tag/reset/clean/release; do not modify LaunchBetter / BuhoReverseNotes.
- Diagnostics stay `CAUSALITY_UNRESOLVED` / `PARTIAL_CONTRIBUTOR_SUPPORTED` / `PRODUCT_DEFAULT_UNCHANGED`.

## Acceptance

- `FOLDER_DOMAIN_TESTS = PASS`: identity stable and not title-derived; title normalization/blank/length/Unicode; member order stable/no-duplicate; folder generation monotonic/latest-wins; catalog revision not forged by folder layer; refresh member-shrink rules (removed member, empty folder, single-member keep) testable.
- `FOLDER_LAB_FIXTURE_TESTS = PASS`: deterministic, no I/O, no machine dependency, default off, neutral titles, no disk persistence.
- `FOCUS_IDENTITY_GENERALIZATION_TESTS = PASS`: app behavior backward-compatible; folder identity expressible; folder never routes to launch.
- No real names/paths recorded; privacy redline clean.
