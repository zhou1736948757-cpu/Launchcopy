# ADR-008 — Folder Presentation Architecture

> **STATUS: ACCEPTED (Main-transcribed from Chief draft, 2026-08-30).** Chief authored the draft; Main transcribed/finalized it into the canonical ADR. Two product decisions were confirmed by the user (2026-08-30): single-member folder policy = **dissolve** (user overrode Chief's KEEP recommendation), folder-lab group rule = **stable catalog order, first N per group** (neutral titles `Group 1`, …; default off). Both are recorded in §6 and reflected in §2.4.

- **Date**: 2026-08-30
- **Phase**: 1E — Folder Foundation vertical slice
- **Prompt**: `Docs/PHASE1E_FOLDER_FOUNDATION_PROMPT.md` §4
- **Decision**: **Unified presentation item in the existing top-level provider** + **generalized neutral grid-entry identity with a unified activation router** + **single-member folder dissolves to the app entry**.

---

## 1. Context

Phase 1E adds an independently-designed folder/group presentation foundation on top of the existing local app catalog, paging, search, keyboard, and launch capabilities. The current architecture (ADR-003/004/005/006/007) has:

- `PagingCore` (frozen) — pure paging state machine.
- `PagingUI` (frozen by default) — `PagingSurface` + `PagingPageContentProviding`/`PagingPageRendering`; neutral content slots (`PagingPageContentItem.identity: AnyHashable`, `title: String`).
- `AppCatalogCore` — `AppID`, `CatalogSnapshot`, `CatalogRevision`, `CatalogPlanner.remap` (5-level degradation), `PagePlan`.
- `MacAppCatalog` — `CatalogRepository` is the **sole** `CatalogRevision` owner.
- `AppGridUI` — `AppGridUIPageContentProvider` (single content provider), `AppGridSearchPresentationController`, `AppGridFocusLayout/Navigator/Model`, `AppGridCellView`, `AppGridPageView`, `ItemBindingToken` (7 fields).
- `PagingPrototypeApp` — composition root (`AppDelegate`, `AppCatalogAssembly`, `AppLaunchController`, `AppArguments`).

The existing focus identity, grid layout, and launch entry are **`AppID`-centric**. "A folder is just an app cell" is **not** the current fact. Phase 1E must decide how folders coexist with apps at the top level, how the open layer works, and how folder identity is kept out of the app-launch path.

## 2. Decision

### 2.1 Presentation architecture — unified item in the existing top-level provider

**Chosen**: Extend the existing `AppGridUIPageContentProvider` to present a **neutral top-level composition** of entries, where each entry is either an **app entry** or a **folder entry**. The committed presentation is a `[TopLevelEntry]` (`.app(AppRecord)` / `.folder(FolderEntry)`). Search results are an app-only slice of that composition. This is the "unified presentation item in the existing top-level provider" approach.

**Rejected**: A separate folder composition/overlay provider. Rationale:

- `PagingSurface.contentProvider` is a **single slot** (`PagingPageContentProviding?`). A separate folder provider would require a wrapper/coordinator to merge two providers into one slot — exactly the "wrapper" approach ADR-007 rejected for search.
- Splitting anchor / page-count / focus identity across two providers would force cross-provider reconciliation for every top-level page, anchor remap, and focus migration — more surface for stale/mis-page bugs.
- The existing provider already owns `servedSnapshot`/`presentationRecords`/`servedPageCount`/`content(for:)`/`anchorCandidate`/`pageIndex(of:)`/`applyPending` (latest-wins + idle commit + anchor remap). Reusing it keeps a single source of truth for "what is presented now" and makes search flattening natural (search = app-only slice of the same composition).

### 2.2 Grid-entry identity — generalized neutral entry + unified activation router

**Chosen**: Generalize the grid-entry identity to a **neutral top-level entry kind** (app vs folder) with a **unified activation router**. The router branches:

```
top-level app      -> existing AppLaunchController
top-level folder   -> open folder
folder member app  -> existing AppLaunchController
placeholder/stale  -> reject safely
```

Folder identity is a **distinct Hashable type** (`FolderID`) carried in the neutral identity slot. The app-launch path's existing `as? AppID` cast (in `AppLaunchController.launch(from:)`) **naturally rejects** any non-`AppID` identity — so a folder identity can never pass through app launch validation. There is **no weakened second launch path**.

**Rejected**: A separate folder selector/overlay that avoids mixed cells. Rationale: it would duplicate the top-level composition, page-count, anchor, and focus machinery, and would make keyboard navigation between apps and folders (and focus restore after close) awkward. The unified entry keeps one top-level grid where apps and folders are peers.

### 2.3 PagingUI impact — none required

The existing neutral `PagingPageContentItem.identity: AnyHashable` seam **already expresses** the folder item kind (a `FolderID` is `Hashable` and can be carried as `AnyHashable`). The cell/renderer distinguishes app vs folder at the **AppGridUI** layer (allowed scope) by the identity type. Therefore **no `Sources/PagingUI/` change is required** this phase; PagingUI stays frozen. If a later finding proves the seam insufficient, a PagingUI change is only allowed as a Main/Chief-approved task with a Reviewer gate, and must stay neutral/backward-compatible.

### 2.4 Single-member folder policy — dissolve (user decision, 2026-08-30)

**Chosen**: A folder whose member set contains exactly **one** app **dissolves** at the top level — it is presented as the app entry itself (the member app appears directly in the top-level composition, not as a one-member folder). The folder entry exists only while it has ≥ 2 members. Rationale (user decision, overriding Chief's KEEP recommendation): a one-member folder is a redundant indirection; showing the app directly is the behavior the user wants. Consequences:

- The dissolve rule is a **composition rule** in the folder domain model (T-1E-A) and the top-level composition (T-1E-B): `FolderEntry` with `members.count == 1` contributes the member `AppID` as an app entry; `members.count == 0` contributes nothing (empty folder removed).
- Dissolve is **deterministic and tested**: single-member folder → app entry at top level; member count changes across refresh (2→1) dissolve; (1→2) re-form folder; anchor/focus migration must handle the identity change (folder `FolderID` → member `AppID`) via the existing 5-level remap degradation.
- Dissolve does **not** affect the open layer: a folder is only openable while it exists as a folder (≥ 2 members).
- The folder-lab fixture must include single-member groups to exercise dissolve.

### 2.5 Folder-lab group rule (user decision, 2026-08-30)

**Chosen**: The folder-lab (demo/test entry, default off) groups apps by **stable catalog order, first N per group** (e.g., first 35 apps → group 1, next 35 → group 2, …), with neutral titles (`Group 1`, `Group 2`, …). Deterministic and reproducible in tests. Grouping is session-only; no persistence.

## 3. Answers to the 14 required questions

1. **Who owns catalog snapshot, folder snapshot, search result, open state?**
   - Catalog snapshot: existing `MacAppCatalog.CatalogRepository` (sole `CatalogRevision` owner, ADR-004). Unchanged.
   - Folder snapshot: a new pure folder domain model (T-1E-A) — `FolderSnapshot` holding `FolderEntry` (stable `FolderID`, title, ordered members). Owned by a new folder composition source in `AppGridUI`/`PagingPrototypeApp`. It **derives from** the committed catalog snapshot and is **not** a `CatalogRevision` owner.
   - Search result: existing `AppGridSearchPresentationController` owns query generation + current query + result set (ADR-007). Unchanged.
   - Open state: a new folder open-state owner (which folder is open, its inner page) at the AppGridUI/presentation layer. Session-only, not persisted.

2. **How does folder generation differ from catalog revision?**
   - `CatalogRevision`: monotonic, sole owner = `CatalogRepository`, minted only on catalog scan/refresh commit. The folder layer **never** mints/forges a `CatalogRevision`.
   - Folder generation: a separate monotonic token (like `AppSearchGeneration`) that increments when the folder composition changes (lab rebuild, member-set change after refresh). It is independent of `CatalogRevision`. Search generation, folder generation, and surface generation are three distinct tokens that never impersonate each other.

3. **How do page count, anchor, focus identity work with apps+folders coexisting?**
   - Top-level page count = `ceil(topLevelEntryCount / itemsPerPage)`, each folder = one slot. Mirrors `CatalogPlanner`.
   - Anchor: `anchorCandidate`/`pageIndex(of:)` operate on the top-level composition; anchor is a stable top-level entry identity (app `AppID` or folder `FolderID`). `CatalogPlanner.remap` 5-level degradation applies to the top-level composition.
   - Focus identity: generalize `AppGridFocusIdentity` to carry a neutral top-level entry identity (app `AppID` or folder `FolderID`). `AppGridFocusLayout` is built from the top-level composition; focus migration mirrors `CatalogPlanner.remap`.

4. **Why does search flatten apps, and how does exiting search restore folders?**
   - Search filters by **app display name** only (never folder title). Search result = app-only top-level entries (members flattened). When search is active, the provider's presentation is app-only (folders hidden). Exiting search (clear query) re-commits the full top-level composition (apps + folders). This mirrors ADR-007's `baseSnapshot` + presentation pattern: the base composition is always available; search is a presentation slice over it.

5. **How do outer and inner paging isolate input/animation?**
   - Outer paging = existing `PagingSurface`/`PagingCore` state machine. Inner paging = folder member paging, a **separate presentation-layer state** that does **not** drive `PagingCore`. Input routing: when a folder is open, arrows/scroll route to inner paging; when closed, to outer paging. Inner open/close and inner page transitions are separate from outer momentum and must not drive/pollute outer `PagingCore` state.

6. **Pending commit priority (refresh, search, folder open/close simultaneously)?**
   - Fixed baseline (prompt §8.2): **new catalog snapshot > rebuild folder composition on new base > re-run search on new base > restore/close folder open state > relayout/focus reconcile**. This is recorded in the ADR and tested.

7. **How do folder cells avoid the app-launch path?**
   - The unified activation router branches on entry kind: folder → open folder; app → delegate to `AppLaunchController.handleCell`. The launch path's `as? AppID` cast rejects folder identities. No weakened second launch path.

8. **How do members reuse the launch safety validation?**
   - Folder member apps are `AppID`s. When a member is activated, the router resolves the member `AppID` and calls the existing `AppLaunchController` pipeline (stale revision → identity in catalog → file existence → `NSWorkspace`). No parallel launch path.

9. **Async thumbnail/member-icon stale/teardown protection?**
   - Reuse the existing async icon pipeline (`AppIconPipeline`) with generation-gated writeback (`ItemBindingToken` 7 fields: `surfaceGeneration`/`reuseGeneration`). Folder member icons and any folder thumbnail go through the same pipeline with the same stale rejection. Teardown bumps `surfaceGeneration` → in-flight callbacks rejected. Open A then open B: A's old callbacks rejected by generation.

10. **blank-click, ESC, Command-F, key-window priority?**
    - Input priority (prompt §8.1): **title-editing Enter/Escape > folder open-layer Escape/arrows/activate > search field responder > top-level keyboard focus > window background exit**.
    - blank-click: clicking outside the open layer closes the folder (does **not** exit app); clicking real window background (folder closed) exits. Two-stage semantics.
    - ESC: if editing title → cancel/end edit; else if folder open → close folder; else → existing ESC clear-grid-selection.
    - Command-F: if folder open → safely close folder, then enter global search.
    - key-window: rebuild first responder per current mode (title editing / folder open / search / top-level).

11. **Title editing first responder + privacy?**
    - Title editing uses a first responder (text field) in the open layer. Enter commits, Escape cancels, focus-loss commits/cancels deterministically. During editing, arrows/Return must not launch apps. Title text **never** enters telemetry/stdout/JSONL/signpost/profile/report; only neutral counters (`folder_count`, `member_count`, open/close outcome enum, stale rejection count, apply-duration numeric). No PagingTelemetry schema change.

12. **Why no drag/persistence this phase?**
    - Scope boundary (prompt §3.2): drag creation/reorder/move and persistence are Phase 1F. This phase is a vertical slice proving folder foundation (top-level entries, open layer, member paging, keyboard/mouse, search/refresh/launch compatibility). Adding drag/persistence would expand scope and require user decision (`SCOPE_EXPANSION_REQUIRES_USER_DECISION`).

13. **Reduce Motion impact?**
    - Reduce Motion reduces large displacement/scale in open/close and inner paging animations while keeping state correct. Open/close animation parameters come from `PRODUCT_DECISION`/`ACCESSIBILITY_REQUIREMENT` and are registered in `PARAMETER_RATIONALE`. Reduce Motion path is tested.

14. **Compatibility/migration risk with existing public interfaces?**
    - The unified approach extends the existing provider (like ADR-007). Risk: changing the provider's committed presentation type from `[AppRecord]` to `[TopLevelEntry]` touches existing consumers (search controller, `AppDelegate.applyPresentationUpdate`, `AppSearchController.firstValidResultOnCurrentPage`). Mitigation: keep the app-only search path behavior identical; existing Phase1B/1D provider tests must keep passing (behavior preserved). PagingUI stays frozen (no change needed). `AppLaunchController.swift` unchanged. No public-interface break in PagingUI/AppCatalogCore/PagingCore.

## 4. Consequences

- **Positive**: single source of truth for top-level presentation; reuses latest-wins/idle-commit/anchor-remap machinery; natural search flattening; folder identity kept out of launch by the existing `as? AppID` cast; no PagingUI change.
- **Negative**: the provider's committed presentation type changes (`[AppRecord]` → `[TopLevelEntry]`), requiring updates to existing consumers and their tests (contained in AppGridUI + PagingPrototypeApp, allowed scope). Focus identity generalization touches `AppGridFocusIdentity` (pure domain, T-1E-A).
- **Migration**: existing Phase1B/1D provider tests must keep passing (behavior preserved). No frozen-tree modification.

## 5. Rejected alternatives

- **Separate folder composition/overlay provider** — rejected (wrapper over single contentProvider slot; split anchor/page-count/focus; ADR-007 precedent).
- **Separate folder selector/overlay avoiding mixed cells** — rejected (duplicate top-level machinery; awkward app↔folder keyboard navigation and focus restore).
- **Treating folder as an ordinary app cell** — rejected (would route folder identity through app launch validation; violates prompt §4).

## 6. Open items for Main/user — RESOLVED (2026-08-30)

- **Single-member folder policy**: **dissolve** (user decision, overriding the Chief draft's KEEP recommendation). A one-member folder is presented as the member app entry itself; folder entry exists only with ≥ 2 members. See §2.4. Tested in T-1E-A (domain) and T-1E-B (composition).
- **Folder-lab group rule**: **stable catalog order, first N per group**, neutral titles (`Group 1`, …), default off. See §2.5.
- Phase 1D manual search GUI gates remain `NOT_RUN` (no user evidence in the events tail) — recorded as a boundary in the Phase 1E final report.
- T-1E-H2-repair: **resolved** (merged, 633/0) — T-1E-B may start.
