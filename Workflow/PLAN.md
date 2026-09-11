# Phase 1E Plan — Folder Foundation Vertical Slice

- **Author**: Chief (glm-5.3)
- **Date**: 2026-08-30
- **Prompt**: `Docs/PHASE1E_FOLDER_FOUNDATION_PROMPT.md` (838 lines, authoritative)
- **Workflow**: chef-worker-reviewer-workflow v1.4.1
- **Supersedes**: Phase 1D plan (Phase 1D history lives in `Docs/PHASE1D_REPORT.md`, `Docs/PHASE1D_SPEC.md`, `Docs/ADR-007-SEARCH-PRESENTATION.md`; do not rewrite history)

---

## 1. Goal

Add an **independently-designed folder/group presentation foundation** on top of the existing local app catalog, paging, search, keyboard, and launch capabilities. This is a **vertical slice** proving the folder foundation end-to-end:

- top-level folder entries (one folder = one top-level slot, coexisting with apps);
- open layer + member paging (inner paging isolated from outer paging);
- keyboard/mouse/ESC/focus-restore behavior;
- member launch **reuses** `AppLaunchController` (no parallel launch path);
- search/refresh/page-reuse/blank-click compatibility;
- session-only title editing;
- neutral folder visuals (no brand/thumbnail replication);
- explicit folder-lab test entry (deterministic, no I/O, no machine dependency).

This is **not** a full Launchpad and **not** a visual replica. Drag, persistence, Hot Corner, and brand visuals are Phase 1F.

## 2. Scope (in)

1. **Independent folder domain model** (T-1E-A): stable non-name folder identity; title; ordered members; top-level entry kind (app vs folder); folder generation vs catalog revision; latest-wins stage/commit; deterministic member-shrink rules on refresh (removed member, empty folder, single-member decision); session-only title-editing semantics.
2. **Folder data source — session-only, explicit lab entry** (T-1E-A + T-1E-E): a `--folder-lab` CLI flag (or equivalent explicit test injection) that deterministically builds session-only groups from the committed catalog; default product launch must **not** reorder user apps; neutral titles (`Group 1`, …); no disk persistence; auto tests fully inject a folder snapshot (no machine dependency).
3. **Top-level presentation** (T-1E-B): empty-query top-level shows apps + folders; one folder = one slot; top-level page count from actual top-level entry count; members not duplicated at top level; stable/predictable order; refresh commits at idle boundary (no mid-gesture mis-page/duplicate/stale); page reuse clears stale folder title/thumbnail/icon; explicit stale defenses for folder identity / catalog revision / page identity / view reuse generation.
4. **Folder visuals + open layer** (T-1E-C): neutral folder entry (symbol + title + member count, not app-icon collage by default); open layer with clear hierarchy and hit-test boundary; title + member grid; inner paging when members exceed one page; inner paging must not drive/pollute outer paging; Reduce Motion reduces large displacement/scale while keeping state correct; open/close animation params from `PRODUCT_DECISION`/`ACCESSIBILITY_REQUIREMENT` and registered in `PARAMETER_RATIONALE`; click outside open layer closes folder only (does not exit app); next real background click exits.
5. **Pointer + keyboard behavior** (T-1E-D): pointer activates folder → open (no launch); pointer activates member → existing `AppLaunchController`; Return/Enter on focused folder → open; Return/Enter on focused member → launch; arrows inside open folder move only within members; member cross-page keeps focus/page consistent; ESC priority (title-edit → close folder → clear grid selection); Tab not swallowed; after close, focus restores to the folder entry (documented fallback if it vanished); key-window rebuilds correct first responder; teardown leaves no responder/notification/animation callbacks. No global NSEvent monitor / Accessibility / Input Monitoring.
6. **Title editing (session-only)** (T-1E-D): explicit enter-edit interaction; blank-title normalization/fallback; length cap + Unicode safety; Enter commit / Escape cancel / focus-loss deterministic; arrows/Return during edit must not launch; title never enters telemetry/stdout/JSONL/signpost/profile/report; no disk write.
7. **Search compatibility** (T-1E-B + T-1E-E): global search filters by **app display name** only; results show apps only (members flattened); no folder-title match; no in-folder search/fuzzy/pinyin/ranking/Spotlight; Command-F while folder open → safely close folder then enter global search; clear/exit search restores top-level folder presentation; search generation and folder generation never impersonate each other; old search results never overwrite newer folder/catalog presentation; member launch uses the unified launch pipeline.
8. **Catalog refresh compatibility** (T-1E-B + T-1E-E): new catalog snapshot still assigned by the existing revision owner; folder layer never forges `CatalogRevision`; refresh arriving during gesture/inner-paging/open-close/title-edit is staged; atomic commit at safe idle boundary; removed apps removed from members; new apps enter top-level ungrouped; empty folders removed; single-member folder keep-or-dissolve decided by ADR + tested; if the open folder is removed, close the open layer and restore nearest legal top-level state; in-flight old icon writebacks rejected; refresh never blocks the trackpad hot path.
9. **Accessibility + Reduce Motion** (T-1E-C + T-1E-D): folder entry has explicit accessibility role/label/description; open-layer title and member hierarchy understandable; predictable focus order; visual thumbnail never the sole state expression; Reduce Motion open/close + inner paging correct; lab mode satisfies the same basic accessibility semantics.

## 3. Non-goals (out of scope — Phase 1F)

Drag-create folders; drag-reorder apps/folders; cross-page drag; move in/out of folders; cross-folder move; persisted layout / SQLite / UserDefaults layout / cloud sync; read/write Launchpad or Dock private DB; system layout import; in-folder search; search by folder title; pinyin/fuzzy/prefix/tokenize/rank/Spotlight search; Hot Corner / global gestures / global NSEvent monitor; Accessibility / Input Monitoring permissions; default frame-source switch / DisplayLink product integration; Timer tolerance or paging-parameter tuning; strict `>25ms` long-tail root-cause fix; LaunchBetter/Buho visual/brand/asset/copy/screenshot replication; install/sign/notarize/publish/commit/push/tag/release; activation/license bypass.

If folder foundation requires drag or persistence, **stop** and mark `SCOPE_EXPANSION_REQUIRES_USER_DECISION` — do not silently expand scope.

## 4. Frozen trees (do not modify)

```
Sources/PagingCore/
Sources/AppCatalogCore/
Sources/MacAppCatalog/
Sources/AppIconPipeline/
Sources/PagingTelemetry/
Package.swift
Sources/PagingPrototypeApp/AppLaunchController.swift
```

`Sources/PagingUI/` is **frozen by default**. Per ADR-008, the existing neutral `PagingPageContentItem.identity: AnyHashable` seam **already expresses** the folder item kind, so **no PagingUI change is required** this phase. If a later finding proves otherwise, a PagingUI change is only allowed as a Main/Chief-approved task with a Reviewer gate, and must stay neutral/backward-compatible. `Package.swift` is Main-exclusive; no new target/third-party dependency this phase.

## 5. Allowed write scope

```
Sources/AppGridUI/
Tests/AppGridUITests/
Sources/PagingPrototypeApp/  (except AppLaunchController.swift)
Tests/PagingUITests/
Docs/
PROVENANCE/
Workflow/
```

## 6. Task DAG

```
Gate 0 (Main, done: T-1E-gate0 READY; T-1E-H2-repair in flight)
   │
   ▼
T-1E-A  (no deps)  ── ADR-008 draft + pure folder domain + lab fixture + focus-identity generalization
   │
   ├───────────────┐
   ▼               ▼
T-1E-B (deps A)   T-1E-C (deps A)     ← parallel, disjoint write scopes
(top-level        (folder cell /
 composition /     thumbnail /
 provider)         open layer)
   └───────┬───────┘
           ▼
T-1E-D (deps B/C)  ── keyboard / focus / title editing
           │
           ▼
T-1E-E (deps B/C/D, serial)  ── AppDelegate integration / refresh / search / launch / blank-click
           │
           ▼
T-1E-F (independent)  ── Reviewer + docs + physical gates
```

`max_worker_concurrency = 3` (Workflow/config.json). T-1E-B and T-1E-C run in parallel **only** because their write scopes are fully disjoint (see §7). AppDelegate / shared provider / shared ADR / Package.swift integration is serial.

## 7. Per-task write scopes (disjoint)

| Task | Deps | Expected/Allowed write scope | Forbidden write scope |
|---|---|---|---|
| **T-1E-A** | none | New pure-domain files in `Sources/AppGridUI/` (folder domain: identity/title/membership/generation/top-level entry kind/activation-router decision; lab fixture); generalize `Sources/AppGridUI/AppGridFocusIdentity.swift` to a neutral entry identity; new domain tests in `Tests/AppGridUITests/`; `Docs/ADR-008-FOLDER-PRESENTATION.md` (Chief DRAFT) | `Sources/PagingUI/`, `Sources/PagingPrototypeApp/`, `Sources/AppGridUI/AppGridUIPageContentProvider.swift`, `AppGridSearchPresentationController.swift`, `AppGridCellView.swift`, `AppGridPageView.swift`, `AppGridUIState.swift`, `Package.swift`, `Sources/PagingCore/` etc. |
| **T-1E-B** | A | `Sources/AppGridUI/AppGridUIPageContentProvider.swift`, `AppGridSearchPresentationController.swift`, `AppGridUIState.swift`; new provider/presentation tests in `Tests/AppGridUITests/` | `Sources/AppGridUI/AppGridCellView.swift`, `AppGridPageView.swift`, folder overlay/open-layer views (C's files); `Sources/PagingPrototypeApp/`; `Sources/PagingUI/` |
| **T-1E-C** | A | `Sources/AppGridUI/AppGridCellView.swift`, `AppGridPageView.swift`; new folder overlay/open-layer view + open-state files in `Sources/AppGridUI/`; new cell/overlay/inner-paging tests in `Tests/AppGridUITests/` | `Sources/AppGridUI/AppGridUIPageContentProvider.swift`, `AppGridSearchPresentationController.swift`, `AppGridUIState.swift` (B's files); `Sources/PagingPrototypeApp/`; `Sources/PagingUI/` |
| **T-1E-D** | B/C | `Sources/PagingPrototypeApp/KeyboardFocusController.swift`, `AppSearchController.swift`; new title-editor + focus code in `Sources/PagingPrototypeApp/`; new keyboard/focus/title tests | `Sources/AppGridUI/AppGridCellView.swift`, `AppGridPageView.swift`, overlay views (C's files, read-only); `Sources/PagingPrototypeApp/AppLaunchController.swift`; `Sources/PagingUI/` |
| **T-1E-E** | B/C/D (serial) | `Sources/PagingPrototypeApp/AppDelegate.swift`, `AppCatalogAssembly.swift`, `AppArguments.swift` (lab flag); new integration tests | `Sources/PagingPrototypeApp/AppLaunchController.swift` (frozen); `Sources/PagingUI/`; `Sources/AppGridUI/` (read-only) |
| **T-1E-F** | independent | Docs (`PHASE1E_SPEC.md`, `PHASE1E_VALIDATION_PLAN.md`, `PHASE1E_REPORT.md`, `PHASE1E_BASELINE_MANIFEST.sha256`, appends to `VALIDATION_RESULTS.md`/`IMPLEMENTATION_LOG.md`/`PARAMETER_RATIONALE.md`/`PRIVACY_DATA_MAP.md`), `PROVENANCE/` appends, `Workflow/results/T-1E-*.md`, `Workflow/reviews/T-1E-*-r*.md` | No product code |

**Shared files** (provider, AppDelegate, ADR, Package.swift) are integrated serially by Main; no two Workers write the same file in the shared working tree.

## 8. Architecture decision (ADR-008 — summary)

**Chosen approach**: **Unified presentation item in the existing top-level provider** (extend `AppGridUIPageContentProvider` to present a neutral top-level composition of app entries + folder entries), **not** a separate folder composition/overlay provider. This mirrors ADR-007 (extend the existing provider, reject the wrapper). A separate folder provider would require a wrapper/coordinator over the single `PagingSurface.contentProvider` slot and would split anchor/page-count/focus identity across two providers.

**Grid-entry identity**: **Generalize to a neutral top-level entry kind (app vs folder) with a unified activation router.** Folder branch → open folder; app branch → delegate to existing `AppLaunchController`. Folder identity is a distinct Hashable type carried in the neutral identity slot; the launch path's `as? AppID` cast naturally rejects folder identities — **folder identity never passes through app launch validation**. No PagingUI change required (the `AnyHashable` identity seam already expresses the folder kind).

Full decision + 14 questions answered in `Docs/ADR-008-FOLDER-PRESENTATION.md` (Chief DRAFT; Main transcribes/finalizes).

## 9. Acceptance summary

Per task (full detail in each task packet):

- **T-1E-A**: identity/title/membership/top-level composition pure logic; generation/revision not conflated; refresh member-shrink rules testable; lab fixture deterministic/no-I/O/no-machine-dependency; no real names/paths recorded.
- **T-1E-B**: empty-query shows apps+folders; search shows flattened apps; page count/anchor/idle commit/latest-wins correct; refresh no-repeat/no-miss/no-forge; existing Phase1B/1D provider tests keep passing.
- **T-1E-C**: neutral independent visuals; folder vs app entry distinguishable; thumbnail stale defense; inner paging isolated from outer; click-outside closes folder only; Reduce Motion correct; teardown zero callbacks.
- **T-1E-D**: Return/Enter open-vs-launch routing; inner arrows/paging/focus restore; ESC priority; Command-F closes folder then search; title editing Enter/Escape/focus-loss; key-window responder rebuild; no global listeners.
- **T-1E-E**: lab flag/test-injection wiring; member launch reuses `AppLaunchController`; folder cell never enters app launch; search/refresh/folder pending priority; overlay-outside click closes + next real background click exits; teardown full chain.
- **T-1E-F**: every implementation task independently reviewed; Main re-runs full tests/builds; provenance/privacy/visual-neutrality scan; real fullscreen GUI/physical keyboard/trackpad gates; final report + unique next-phase recommendation.

## 10. Privacy redlines

Folder title / membership / identity raw values and icon data must **never** enter telemetry / JSONL / stdout / signpost / profile / report. Only neutral counters allowed: `folder_count`, `member_count`, open/close outcome enum, stale rejection count, apply-duration numeric. **No PagingTelemetry schema change** this phase. No disk persistence of folder data. No Spotlight / Launchpad / Dock private DB reads.

## 11. Manual gates (user real fullscreen + physical input)

- `MANUAL_FOLDER_GUI_GATE` — folder lab launch; top-level neutral folder entries without member duplication; pointer opens folder; member click launches; click outside open layer closes only; next real background click exits; rapid open/close of different folders shows no stale title/thumbnail/flash.
- `MANUAL_KEYBOARD_GATE` — arrows focus folder; Return/Enter opens (not launches); inner arrows + cross-page correct; Return/Enter launches member; ESC closes + restores folder focus; title-edit Enter/Escape correct; Command-F from folder enters global search; clear search restores top-level folder.
- `MANUAL_TRACKPAD_60HZ_REGRESSION_GATE` — top-level multi-page trackpad paging still follows; inner multi-page paging does not drive outer; fast reverse/close during animation no jump; refresh arrival no mis-page/duplicate/stale-icon/crash; 60Hz feel not visibly regressed.
- `MANUAL_REDUCE_MOTION_RESIZE_GATE` — Reduce Motion open/close state correct; fullscreen/resize keeps folder layer in bounds; close/reopen app → lab groups not persisted.
- `MANUAL_120HZ_GATE` — `BLOCKED_BY_HARDWARE` (60Hz panel) unless a real 120Hz device is available; never write PASS without real evidence.

## 12. Stop conditions

Stop the affected branch and report `BLOCKED` (with blocking fact, affected scope, saved evidence, whether Chief/user decision needed, minimal next step) if any of:

- need to read a forbidden source to continue;
- need to copy old source/visual/asset/copy;
- need to modify `PagingCore` to do folder foundation;
- need to read/write Launchpad or Dock private DB;
- need drag, persistence, or global listeners to meet the phase goal;
- need to change Timer tolerance / frame source / paging params to make tests green;
- cannot distinguish app identity from folder identity;
- cannot guarantee folder/search/catalog generations never overwrite each other;
- real names/titles/paths/query would enter logs;
- concurrent Workers would modify the same file or shared mutable state;
- tests exit 0 but executed tests = 0;
- need automatic commit/push/tag/release.

## 13. Final pass conditions (all required)

```
ADR-008 = ACCEPTED
FOLDER_DOMAIN_TESTS = PASS
TOP_LEVEL_COMPOSITION_TESTS = PASS
FOLDER_OVERLAY_TESTS = PASS
KEYBOARD_RESPONDER_TESTS = PASS
SEARCH_REFRESH_LAUNCH_INTEGRATION_TESTS = PASS
FULL_SWIFT_TESTS = PASS_WITH_EXECUTED_COUNT
BUILD_DEBUG = PASS
BUILD_RELEASE = PASS
INDEPENDENT_REVIEW = PASS
PRIVACY_REDLINE = PASS
PROVENANCE_REVIEW = PASS
MANUAL_FOLDER_GUI_GATE = PASS_USER_REPORTED_WITH_EVIDENCE
MANUAL_KEYBOARD_GATE = PASS_USER_REPORTED_WITH_EVIDENCE
MANUAL_TRACKPAD_60HZ_REGRESSION_GATE = PASS_USER_REPORTED_WITH_EVIDENCE
MANUAL_120HZ_GATE = BLOCKED_BY_HARDWARE_OR_REAL_PASS
```

If automation passes but the user has not physically tested, write at most `AUTOMATED_IMPLEMENTATION_VERIFIED` + `PHYSICAL_ACCEPTANCE_PENDING` — never inflate to a product physical-gate PASS.

## 14. Next-phase recommendation boundary

If Phase 1E fully passes, recommend `RECOMMEND_PROCEED_TO_PHASE_1F_DRAG_AND_PERSISTENCE`. If physical gates are not complete, write `PHASE1E_AUTOMATED_COMPLETE_PHYSICAL_PENDING` and keep `PRODUCT_TIMER_TOLERANCE_0MS` / `SHORT_TAIL_MITIGATED_BY_TOLERANCE` / `CAUSALITY_UNRESOLVED_FOR_GT25MS`.

---

# Phase 1F Plan — Drag Orchestration + Folder Mutation + Local Persistence (APPENDED)

- **Author**: Chief (glm-5.3)
- **Date**: 2026-08-31
- **Prompt**: `Docs/PHASE1F_DRAG_PERSISTENCE_PROMPT.md` (1251 lines, authoritative)
- **Workflow**: chef-worker-reviewer-workflow v1.4.1
- **Appended to**: Phase 1E plan above (Phases 1A–1E history preserved; do not rewrite)
- **State observation (read at planning time)**: `Workflow/STATE.json` already reports `phase: PHASE_1F_IN_PROGRESS` and `next_action: "Phase 1F Gate 0 (reconciliation + 789 baseline freeze) in progress; then T-1F-A ADR+layout domain"` (updated_at 2026-08-30T22:30:00+09:00). Prompt §2's claim that `T-1E-folder-open-repair` still shows EXECUTING does **not** match the current file (it is PASSED with `reconcile_note`; no history forged). Gate 0 must verify against disk facts, not assume.

## 1. Goal

Add the **drag orchestration + folder mutation + local persistence** vertical slice on top of 1A paging / 1B catalog / 1C keyboard / 1D search / 1E folder foundation. The only new product variable: the user reorders top-level apps/folders, creates folders, moves apps into/out of folders, reorders inside folders, and moves across pages — via the app's own drag gestures **and** equivalent accessibility actions — and the logical layout is safely persisted locally and restored after restart + catalog refresh.

## 2. Scope (in)

1. **Logical layout domain** (T-1F-A): `PersistentWorkspaceLayout` (sole persistent truth), `PersistentAppReference` (independent DTO, ≠ AppID), `VisibleWorkspaceProjection` (expected layout + fresh catalog derived), `LayoutGeneration` (owned only by logical layout), `LayoutMutation(expectedGeneration:)` (sole write entry), `PresentationAnchor` (stable landing after reorder/dissolve, no hashValue). 10 invariants (Prompt §3.1).
2. **Top-level reorder** — same-page / cross-page / folder reorder / app↔folder swap / head / tail / partial pages / empty slots / page-count change / restore after exit; no-move drop = no-op (no disk write); new apps append deterministically.
3. **Folder create / add / inner reorder / move-out** — create from app-on-app drop; add top-level app to folder cell; cross-folder atomic move; inner reorder incl. inner cross-page; move-out with single-member dissolve (user-logical, permanent) vs unavailable-member visual dissolve (latent membership kept); no nested folders / no merge.
4. **Cross-page drag + edge paging** — edge dwell → one page per turn; hysteresis; leave-edge cancels; no overshoot at first/last; re-hit-test + re-validate token/layout/catalog generations after each turn; `DragScope = .topLevel | .folder(id)`; outer edge turn uses only the accepted outer paging entry, never writes `visualOffset`.
5. **Drag session state machine** (T-1F-C): `DragTransaction(opaqueToken, scope, sourceIdentity, layoutGeneration, catalogGeneration)`; states `idle → pressed → dragging/edgeTurnPending → commit | cancel → idle`; unified cancel (ESC / resign / refresh / search / title edit / overlay close / teardown / second drag) → zero disk writes, no preview/edge-timer residue; pasteboard carries only a random short-lived opaque token (zero identity data).
6. **AppKit drag integration** (T-1F-D): independent neutral drag preview / insertion indicator / folder-create highlight; click opens/launches, drag never does; drag never starts on drag of app (launch) or folder (open); click-vs-drag threshold + edge dwell + drop-zone params independently determined with source category from the 5 allowed classes (never REVERSE_ENGINEERING_COPY / OLD_SOURCE_TRANSLATION / UNKNOWN_ORIGIN).
7. **Versioned layout store** (T-1F-B): schema v1 codec + validator; deterministic encoding; unknown-future-version read-only protection; A/B dual-slot generation journal with monotonic writeGeneration + checksum; temp write + atomic replace; last-known-good; bounded flush barrier; PERSISTENCE_DEGRADED on write failure (retry, never clear LKG); explicit multi-instance policy (single-writer / file coordination / explicit last-writer-wins); injectable store, tests use injected temp dirs only.
8. **Provider / AppDelegate persistence integration** (T-1F-E): startup load → reconcile against fresh catalog → validated projection → runtime presentation; drag commit → provider commit → open-state/focus reconcile → async persist enqueue; refresh cancels drag then reconciles; search active disables drag; Command-F cancels drag then searches; title rename persists; single testable commit chain (catalog → visible layout → optional search → provider → open-state/focus) — a later provider commit must never clear earlier search state; folder open-state migration; termination flush barrier; reset command; neutral store-failure UI; `renameFolder` real mutation.
9. **Accessibility equivalents** (T-1F-C engine + T-1F-D presentation): Move Before/After, previous/next page, Move Into/Out of Folder, in-folder Move Before/After, cancel reorder — all through menus / context menu / keyboard reorder mode / `NSAccessibility` custom actions, all routed to the **same pure mutation engine** (no second algorithm); understandable announcements; no Accessibility / Input Monitoring permissions; VoiceOver/keyboard at least manual gate.
10. **Reduce Motion** — shortened/cancelled visuals, logical state/commit unchanged; no unnecessary large-scale/fly animations.
11. **Performance discipline** (Prompt §5.4, §12): drag-move hot path forbids disk writes / JSON encode / catalog scan / Bundle reads / synchronous icon decode / view-tree rebuild / unbounded O(n²) / synchronous actor waits; real persistence only async after committed mutation; neutral counters only.
12. **Docs deliverables**: `Docs/PHASE1F_SPEC.md`, `Docs/PHASE1F_VALIDATION_PLAN.md`, `Docs/PHASE1F_REPORT.md`, `Docs/PHASE1F_BASELINE_MANIFEST.sha256`, appends to `VALIDATION_RESULTS.md` / `IMPLEMENTATION_LOG.md` / `PARAMETER_RATIONALE.md` / `PRIVACY_DATA_MAP.md`, PROVENANCE appends.

## 3. Non-goals (out of scope — per Prompt §13)

Nested folders; folder-on-folder merge; multi-select/batch drag; moving/copying/deleting real apps on disk; Finder/desktop/external app drops; Launchpad or Dock private DB read/write; system layout import/export; iCloud/network/account sync; collaborative conflict merge; drag on search results changing layout; Hot Corner / global gestures / global NSEvent monitor; Accessibility / Input Monitoring permissions; Timer tolerance / frame source / PagingCore tuning; strict `>25ms` long-tail root-cause fix; LaunchBetter/Buho visual/brand/asset/copy replication; install/sign/notarize/publish/commit/push/tag/release; activation/license bypass. A hard dependency on any of these → stop + `SCOPE_EXPANSION_REQUIRES_USER_DECISION`.

## 4. Frozen trees (do not modify)

```
Sources/PagingCore/
Sources/MacAppCatalog/
Sources/AppIconPipeline/
Sources/PagingTelemetry/
Sources/PagingUI/
Package.swift
Sources/PagingPrototypeApp/AppLaunchController.swift
```

`Sources/AppCatalogCore/` is **frozen by default**. A narrow AppCatalogCore change is allowed **only** if ADR-009 proves no safe persistent-identity projection can be built within `AppGridUI/` + `PagingPrototypeApp/` — and even then only as a Main/Chief-approved narrow task with a Reviewer gate, never exposing `AppID.storage` internals, never changing catalog-revision ownership, never changing scan behavior. If the PagingUI seam is insufficient for edge page turns / drag overlay, stop and write minimal architecture-conflict evidence for a Chief decision — do not modify `PagingCore`/`PagingUI`.

## 5. Allowed write scope

```
Sources/AppGridUI/
Tests/AppGridUITests/
Sources/PagingPrototypeApp/  (except AppLaunchController.swift)
Tests/PagingUITests/
Docs/
PROVENANCE/
Workflow/
```

## 6. Task DAG + concurrency waves

```
Gate 0 (1E reconciliation + 789 baseline freeze; T-1F-gate0)
   │
   ▼
T-1F-A (no deps)  ── ADR-009 + ADR-010 drafts + pure layout/mutation domain (pure Foundation, no AppKit/I/O)
   │
   ├────────────────┐
   ▼                ▼
T-1F-B (deps A)   T-1F-C (deps A)    ← Wave 3 parallel, write scopes fully disjoint
(layout store /    (drag state machine
 schema v1 codec /  + drop resolver, pure)
 A-B journal)
   └───────┬────────┘
           ▼
T-1F-D (deps C)  ── AppKit drag UI (preview / insertion / folder-create / edge turn / top+inner+move-out)
           │
           ▼
T-1F-E (deps A/B/C/D, serial)  ── Provider/AppDelegate/persistence integration (shared files)
           │
           ▼
T-1F-F (independent)  ── per-task Reviewer + Main full tests/builds/hash + privacy/provenance/persistence audit + physical gates + final report
```

`max_worker_concurrency = 3` (Workflow/config.json, declared models: main=current-main-conversation, chief=glm-5.3, worker=deepseek-v4-flash:0731, reviewer=glm-5.3-flash:cloud — declaration is config, not proof of upstream routing). Implementation peak is **2 Workers** (Wave 3); Reviewer waves run separately. Per-wave 6-question concurrency check must be recorded before every Worker/Reviewer wave (dependencies satisfied / write scopes fully disjoint / test+persistence temp dirs isolated / SwiftPM `.build` contention / Reviewer independent stable evidence / no quality regression). Wave plan: **Wave 1** (1 Worker: Gate 0, no product-code writes) → **Wave 2** (1 Worker: T-1F-A) → **Wave 3** (2 Workers: T-1F-B ∥ T-1F-C, disjoint write sets + separate temp roots) → **Wave 4** (1 Worker: T-1F-D, deps C) → **Wave 5** (1 Worker: T-1F-E, deps A/B/C/D, serial, shared files) → **Wave 6** (Reviewer wave + Main final verification, T-1F-F). `.build` is Main-serialized across all waves; persistence tests use per-Worker injected temp dirs and clean only their own.

## 7. Per-task write scopes (disjoint; file level)

| Task | Deps | Expected/Allowed write scope | Forbidden write scope |
|---|---|---|---|
| **T-1F-gate0** | none | Re-run `swift test` + debug/release builds + record real counts + executable SHA-256; `Docs/PHASE1F_BASELINE_MANIFEST.sha256`; STATE/events reconciliation (verify, don't forge); fix ADR-006 §9 header date if confirmed typo | No product code; no forged history; no automatic commit |
| **T-1F-A** | none | New pure-domain files in `Sources/AppGridUI/LayoutDomain/` (workspace layout / persistent app reference / projection / mutation engine / generation / anchors / invariant validator); `renameFolder` as real mutation in `Sources/AppGridUI/FolderDomain.swift` (read+extend allowed; 64-grapheme via existing `FolderTitle.normalized` semantics) **or** new LayoutDomain file delegating to it; new pure tests in `Tests/AppGridUITests/`; `Docs/ADR-009-WORKSPACE-LAYOUT-AND-PERSISTENCE.md` + `Docs/ADR-010-DRAG-SESSION-AND-DROP-SEMANTICS.md` (**Chief DRAFT**) | `Sources/PagingPrototypeApp/`, `Sources/PagingUI/`, `Sources/AppGridUI/AppGridUIPageContentProvider.swift`, `AppGridSearchPresentationController.swift`, `AppGridUIState.swift`, `AppGridCellView.swift`, `AppGridPageView.swift`, store files (B), drag session files (C), `Sources/PagingCore/`, `Package.swift` |
| **T-1F-B** | A | New store files in `Sources/AppGridUI/LayoutStore/` (store protocol + actor, schema v1 codec/validator, Application Support location abstraction, A/B generation journal, coalescing sink, flush barrier, failure state, reset); new durability tests in `Tests/AppGridUITests/` — **all persistence tests use injected temp dirs** | `Sources/AppGridUI/LayoutDomain/` (read-only), drag session files (C), `Sources/PagingPrototypeApp/`, `Sources/PagingUI/`, `AppDelegate.swift`, provider files |
| **T-1F-C** | A | New pure files in `Sources/AppGridUI/DragSession/` (drag state machine, `DragTransaction`, drop resolver, hit-zone/drop intent, insertion-vs-create classification, edge paging scheduler pure seam, unified cancel policy); new drag-intent tests in `Tests/AppGridUITests/` | `Sources/AppGridUI/LayoutStore/` (B's files), `Sources/AppGridUI/LayoutDomain/` (read-only), `Sources/PagingPrototypeApp/`, any AppKit view files |
| **T-1F-D** | C | AppKit drag presentation: new files in `Sources/AppGridUI/` (drag preview view, insertion indicator, folder-create highlight, drag coordinator view); minimal read-only deps on C's pure seams; new AppKit-integration tests in `Tests/AppGridUITests/` | `Sources/PagingUI/`, `Sources/PagingCore/`, `Sources/PagingPrototypeApp/`, `Sources/AppGridUI/AppGridUIPageContentProvider.swift`, `AppGridSearchPresentationController.swift` (read-only), store files (B), `LayoutDomain/` (read-only) |
| **T-1F-E** | A/B/C/D (serial) | `Sources/PagingPrototypeApp/AppDelegate.swift` (drag wiring, commit chain, termination flush, reset command, store-failure UI), `AppCatalogAssembly.swift` / `AppArguments.swift` (store injection, reset flag) as needed; `Sources/AppGridUI/AppGridUIPageContentProvider.swift` (layout-backed presentation if required); integration tests incl. restart-restore, refresh-cancel-reconcile, search-disables-drag, open-state migration | `Sources/PagingPrototypeApp/AppLaunchController.swift` (frozen); `Sources/PagingUI/`; `Sources/PagingCore/`; `FolderDomain.swift` beyond rename delegation |
| **T-1F-F** | independent | `Docs/PHASE1F_SPEC.md`, `PHASE1F_VALIDATION_PLAN.md`, `PHASE1F_REPORT.md`, appends (`VALIDATION_RESULTS.md`/`IMPLEMENTATION_LOG.md`/`PARAMETER_RATIONALE.md` drag params/`PRIVACY_DATA_MAP.md` layout store + pasteboard flows), `PROVENANCE/` appends, `Workflow/results/T-1F-*.md`, `Workflow/reviews/T-1F-*-r*.md` | No product code |

**Shared files — write prohibited in parallel**: `Sources/PagingPrototypeApp/AppDelegate.swift`, `Sources/AppGridUI/AppGridUIPageContentProvider.swift`, `AppGridSearchPresentationController.swift`, `AppGridUIState.swift`, `FolderDomain.swift` (rename extension), `AppCatalogAssembly.swift`, `AppArguments.swift`, `Package.swift` (Main-exclusive), ADR/PARAMETER_RATIONALE/PRIVACY_DATA_MAP canonical files. T-1F-E is the only serial owner of the AppDelegate/provider integration; all other waves treat them read-only.

## 8. Architecture decisions (ADR-009 + ADR-010 — summaries; drafts in Docs/)

**ADR-009 (Workspace layout & persistence)**: persistent truth = `PersistentWorkspaceLayout` (dedicated DTO/envelope, never auto-Codable of `FolderSnapshot`/runtime objects — interleaved top-level order and shrink-absence gaps are unrepresentable); app persistent reference = bundle-ID primary + deterministic fallback (≥3 schemes compared; never Swift Hasher / displayName / redactedDescription; `AppID.storage` stays private); `FolderID` persisted only via controlled projection; schema v1 with engineering caps (1 MiB / 512 folders / 10,000 refs / 2,048 members per folder — **pending-verification engineering caps, not existing product facts**); Application Support neutral subdirectory + injection; A/B dual-slot generation journal (monotonic writeGeneration, checksum = accidental-corruption only), last-known-good, bounded flush, explicit multi-instance policy; corruption / unknown-version → read-only protection, evidence never auto-overwritten; reconcile distinguishes user-logical dissolve (permanent) from unavailable-member visual dissolve (latent kept); reset explicit and safe; local-sensitive data list + exposure limits; AppCatalogCore stays frozen by default; drag hot path never writes disk. Full 16 questions in the ADR.

**ADR-010 (Drag session & drop semantics)**: default = **custom in-window pointer state machine** (not NSDraggingSession — reasons: click-vs-drag distinction, cross-page/overlay control, drop-target testability, drag image + Reduce Motion, pasteboard privacy, external-process spoofing, teardown/cancel, conflicts with existing click/scroll/blank-click routing), with `DragTransaction(opaqueToken, scope, sourceIdentity, layoutGeneration, catalogGeneration)`, `DragScope = .topLevel | .folder(id)`, states `idle → pressed → dragging/edgeTurnPending → commit | cancel → idle`; pasteboard carries only a random short-lived opaque token (zero identity); unified cancel path; 5 mutation classes (app reorder / folder reorder / create folder / move into / move out & cross-folder) with insertion-vs-folder-create visual distinction; accessibility equivalents route through the same mutation engine; click/drag threshold + edge dwell + drop zones independently determined with 5-class parameter provenance; Reduce Motion respected; full parameter list enters PARAMETER_RATIONALE.md; nested folder / merge / external file drop explicitly unsupported. Full 14 questions in the ADR.

## 9. Acceptance summary

Per task (full detail in each task packet; automation matrix in Prompt §10):

- **T-1F-A**: 10 invariants pure-tested; deterministic default/layout order; no-op drop doesn't bump generation or write; stale generation rejected; `renameFolder` real mutation + 64-grapheme normalize + restart-restore semantics.
- **T-1F-B**: first launch no file; save/load/restart; atomic replace; interrupted write; corrupt primary + valid backup; both corrupt → safe default; permission denied; disk full; coalesce latest-wins; flush barrier; reset; unknown future version never overwritten; multi-instance policy; all temp roots.
- **T-1F-C**: click below threshold vs drag above; reorder / create / insert / move-into / move-out / cross-folder classification; invalid/external token rejected; duplicate drop consumed once; stale source/target/layout/catalog rejected; all cancel paths testable; edge enter/dwell/turn/leave/cancel/first-last; second drag invalidates first.
- **T-1F-D**: click launches, drag never; folder click/Return opens, drag never; blank-click two-stage unchanged; search active disables drag; Command-F cancels then searches; title edit blocks drag; inner drag doesn't move outer page; cross-page drop updates visible content+focus; view reuse zero stale apply; Reduce Motion correct; teardown zero callbacks.
- **T-1F-E**: startup load → reconcile → runtime layout; drag commit → provider commit → focus reconcile → async persist; refresh cancels drag then reconciles; later provider commit never clears search state; folder open-state migration; termination flush; reset command; store-failure neutral UI.
- **T-1F-F**: every implementation task independently reviewed; Main re-runs full tests/builds/hash; privacy/provenance/persistence file inspection; crash/corruption/permission tests; real fullscreen GUI + physical mouse/trackpad/keyboard/VoiceOver gates; restart-restore gate; final report + unique next-phase recommendation.

## 10. Privacy redlines (Prompt §4.2–4.3, §5.2; PRIVACY_DATA_MAP appends)

App display name / bundle ID / canonical path / URL / AppID raw / FolderID raw / folder title / member lists / layout order / layout file body / drag source-target identity / user input must **never** enter telemetry / JSONL / stdout / signpost / profile / report / pasteboard. Only neutral counters (drag-move p95/max, drop-mutation wall, persist wall, edge-turn counts, stale rejections, retry/failure counts). The layout file itself is the **single controlled exception** (local-sensitive product storage) — its field list is documented in ADR-009/PRIVACY_DATA_MAP, never copied into diagnostics or Workflow reports. `FolderID.redactedDescription` stays `<redacted>`; UUID raw never leaves the process except the controlled file projection.

## 11. Manual gates (user real fullscreen + physical input)

- `MANUAL_TOP_LEVEL_DRAG_GATE` — same-page / cross-page / folder reorder / swap / head / tail / cancel-invalid / rapid double drag / click-not-regressed.
- `MANUAL_FOLDER_DRAG_GATE` — create / add / inner same+cross-page reorder / move-out / cross-folder / single-member dissolve / title-edit then restart restore / open-close + keyboard nav + launch not regressed.
- `MANUAL_EDGE_PAGING_GATE` — left/right dwell turns one page; leave edge cancels; first/last no overshoot; ESC / window resign / refresh / Command-F cancel cleanly; no ghost insertion/timer residue.
- `MANUAL_RESTART_PERSISTENCE_GATE` — real fullscreen layout persisted across exit/reopen; top-level order, folder IDs/titles/member order restored; temp-missing restored; new apps deterministic; reset returns default; injected-corruption safe start.
- `MANUAL_KEYBOARD_ACCESSIBILITY_GATE` — keyboard/menu/VoiceOver reorder actions produce identical results to drag; announcements understandable; focus follows; no permission prompts.
- `MANUAL_TRACKPAD_60HZ_REGRESSION_GATE` — real trackpad paging + drag coexistence, 60Hz feel not visibly regressed; current recorded status (1E): PASS_USER_REPORTED_WITH_EVIDENCE — 1F re-verification required; otherwise `NOT_RUN`/evidence-limited per Prompt honesty rules.
- `MANUAL_120HZ_GATE` — `BLOCKED_BY_HARDWARE_OR_REAL_PASS` (60Hz panel, no 120Hz evidence); never PASS without real evidence.

## 12. Stop conditions (per Prompt §15 — report BLOCKED + blocking fact + affected scope + saved evidence + decision needed + minimal next step)

Needed-forbidden-source read; old source/visual/param copy; Launchpad/Dock private DB; cannot define a safe stable app persistence reference; must expose `AppID.storage` or log raw values; pasteboard must carry identity or layout body; cannot atomically distinguish user mutation from catalog temporary absence; persistence would sync-write on drag hot path; PagingCore/Timer params must change; search/refresh/drag generations may overwrite each other; multiple Workers write the same schema/provider/AppDelegate file; tests exit 0 with executed = 0; automatic commit/push/tag/release needed; unknown schema version overwritten by old version; tests write real user Application Support.

## 13. Final pass conditions (all required; per Prompt §16)

```
PHASE_1E_WORKFLOW_RECONCILED
ADR-009 = ACCEPTED
ADR-010 = ACCEPTED
LAYOUT_DOMAIN_TESTS = PASS
DRAG_INTENT_TESTS = PASS
PERSISTENCE_SCHEMA_TESTS = PASS
STORE_DURABILITY_TESTS = PASS
CATALOG_RECONCILIATION_TESTS = PASS
APPKIT_DRAG_INTEGRATION_TESTS = PASS
ACCESSIBILITY_REORDER_TESTS = PASS
FULL_SWIFT_TESTS = PASS_WITH_EXECUTED_COUNT
BUILD_DEBUG = PASS
BUILD_RELEASE = PASS
INDEPENDENT_REVIEW = PASS
PRIVACY_AND_PASTEBOARD_REDLINE = PASS
PROVENANCE_REVIEW = PASS
MANUAL_TOP_LEVEL_DRAG_GATE = PASS_USER_REPORTED_WITH_EVIDENCE
MANUAL_FOLDER_DRAG_GATE = PASS_USER_REPORTED_WITH_EVIDENCE
MANUAL_EDGE_PAGING_GATE = PASS_USER_REPORTED_WITH_EVIDENCE
MANUAL_RESTART_PERSISTENCE_GATE = PASS_USER_REPORTED_WITH_EVIDENCE
MANUAL_KEYBOARD_ACCESSIBILITY_GATE = PASS_USER_REPORTED_WITH_EVIDENCE
MANUAL_TRACKPAD_60HZ_REGRESSION_GATE = PASS_USER_REPORTED_WITH_EVIDENCE
MANUAL_120HZ_GATE = BLOCKED_BY_HARDWARE_OR_REAL_PASS
```

If automation passes but physical gates are incomplete, write at most `PHASE1F_AUTOMATED_COMPLETE_PHYSICAL_PENDING` — never inflate to a product drag/persistence physical-gate PASS. Diagnostic boundary stays `PRODUCT_TIMER_TOLERANCE_0MS` / `SHORT_TAIL_MITIGATED_BY_TOLERANCE` / `CAUSALITY_UNRESOLVED_FOR_GT25MS`.

## 14. Next-phase recommendation boundary

If Phase 1F fully passes, recommend `RECOMMEND_PROCEED_TO_PHASE_1G_ACTIVATION_ENTRY_AND_HOT_CORNER` (Phase 1G evaluates Hot Corner / menu / shortcut activation entries; still no global listeners / permission expansion without a separate product + privacy decision). Otherwise write `PHASE1F_AUTOMATED_COMPLETE_PHYSICAL_PENDING` (or partial) and keep the three diagnostic tokens above.

---

# Phase 1F BUG6-fix（2026-08-31，追加节）

- **触发**：用户实机验收 4 缺陷（`Workflow/BUG6-REPORT.md`），Ops 出权威修复方案 `Workflow/BUG6-FIX-PROMPT.md`（275 行，file:line 已由 Chief 抽查核对一致）。
- **角色分工**：Chief 只做本节规划 + `decisions/D-2026-08-31-bug6-fix-plan.md`；Worker 按 `tasks/T-1F-B6-wave-*.md` 实现；每缺陷独立 Reviewer PASS 才合并。
- **总原则（§0 硬约束）**：净删代码。缺陷 3+4 删 `DropZones` 两个 zone 字典字段换纯函数；缺陷 2 删重复点击通路（第二层）随之删抑制状态机；缺陷 1 三行语义修正 + 注释同步。改完总行数必须**减少**。

## F1. 三波语义 DAG

```
T-1F-B6-planning (Chief, done)
   │
   ▼
T-1F-B6-wave-a  ← 先行：缺陷3+4 + off-by-one（同波，不可拆）
   │              其方案 i/ii 选择决定 wave-b 的并发资格（Worker 必须回报 Main）
   ├──────────────────────────────┐
   ▼                              ▼
T-1F-B6-wave-b                T-1F-B6-wave-c（第一层：缺陷2 堵漏）
（缺陷1；方案 ii → A→B 强制串行；写范围与 A/B 完全不相交，
  方案 i → Main 记 concurrency_check 后可评估并行）
   │
   ▼
T-1F-B6-wave-c2  ← 第二层根治（拆 recognizer 双通路）：Status: blocked
                   BLOCKED-on-frozen-tree: Sources/PagingPrototypeApp/AppLaunchController.swift（install() :93-98）
```

- 并发资格规则：方案 i（引擎内换算 `index-1`）→ A∥B 写范围不相交，可评估并发；方案 ii（`.insertion` 载荷语义化）→ 波及 DropIntent enum + Wave B 测试预期 → **A→B 串行**。由 Main 裁定，任何放行必须先记 `concurrency_check`（6 问，沿用 MAIN_BRIEF §2 政策）。C 第一层写范围（DragUISessionCoordinator.swift）与 A/B 不相交，可与任一波并行；SwiftPM `.build` 全局串行。
- 每波后跑 `BUG6-FIX-PROMPT.md §7` 实机复验脚本（7 条）；任一条不过 → Reviewer FAIL。

## F2. 写范围表

| 波次 | 可写 | 明确禁写 |
|---|---|---|
| T-1F-B6-wave-a | `Sources/AppGridUI/DragSession/DropIntent.swift`、`DragSession/DragMutationEngine.swift`、`FolderOverlayView.swift`（仅 `memberDragItemFrames`）+ 对应测试 | 冻结树、`DragParameters.swift`（禁新增参数）、`LayoutMutation.swift`（Wave B）、`DragUISessionCoordinator.swift`（Wave C）、`AppDelegate.swift` |
| T-1F-B6-wave-b | `Sources/AppGridUI/LayoutDomain/LayoutMutation.swift` + 对应测试 | 冻结树；DropIntent/DragMutationEngine（A 的文件，方案 ii 冲突即串行的原因） |
| T-1F-B6-wave-c | `Sources/AppGridUI/DragUI/DragUISessionCoordinator.swift` + 对应测试 | 冻结树（含 AppLaunchController.swift）；AppDelegate/AppGridCellView 属 c2 范围 |
| T-1F-B6-wave-c2 | **blocked**：评估后若需解冻 → `AppLaunchController.swift`（仅经 Main/Chief 书面解冻）；否则 `AppDelegate.swift` + `AppGridCellView.swift` + coordinator 抑制状态机自删 | 任何情形 Worker 不得自行改冻结文件 |

冻结树全文照旧：`Sources/PagingCore/`、`AppCatalogCore/`、`MacAppCatalog/`、`AppIconPipeline/`、`PagingTelemetry/`、`PagingUI/`、`Package.swift`、`PagingPrototypeApp/AppLaunchController.swift`。

## F3. 4 缺陷 → 波次 → 验收映射

| # | 缺陷（用户现象） | 波次 | 自动化验收锚点 | 实机脚本（FIX-PROMPT §7） |
|---|---|---|---|---|
| 3 | B 右侧不出蓝条（全宽 center zone 吃掉 insertion） | A | §2.1 行为表全项 + 死区回归（3×2 九宫格+缝隙+页边距全非 `.invalid`） | 脚本 2 |
| 4 | folder 内拖成员无反应 | A | 成员拖到成员正中 → `.insertion`（非 `.invalid`）+ preview 跟手 | 脚本 5、6 |
| —（新发现） | off-by-one：源在目标前时落点多移一格 | A | 双方向锁：`[A,B,C]` A→B右 ⇒ `[B,A,C]`；C→B左 ⇒ `[A,C,B]` | 脚本 2、3 放下结果 |
| 2 | 建夹后点击打不开 + 空白退不出 | C 第一层（c2 标根治） | 直接断言 suppressor 收到 `true`（非仅 `isSessionActive==false`）+ 20 次配平 | 脚本 4、7 |
| 1 | folder 长在 A 的位置 | B | 左右两方向落点测试 + 成员序 `[target,source]` 锁 + 头注释一致性 | 脚本 1 |

## F4. 方案 i/ii 分歧（off-by-one 修法）

- **方案 i**（建议）：`DragMutationEngine` 的 `.insertion` 分支做换算（源在目标前 → `index-1`）。域层语义不动。冲突面 = 仅引擎一处。
- **方案 ii**：`.insertion` 载荷从下标改为"插到某条目之前/末尾"。更健壮，但波及 enum、分类器、引擎、视觉、全部相关测试，**并与 Wave B 的测试预期重叠**。
- 裁定规则：Worker 波次 A 选定后必须回报 Main；**方案 ii → A→B 串行**，方案 i → Main 记 `concurrency_check` 后裁定 A∥B。若 Worker 发现 `reorderFolderMembers`(:230-236) 与 `moveOutOfFolder`(:210) 需要相反换算方向，直接升级方案 ii 并报 Chief。

## F5. 决策与观察项（详见 decisions/D-2026-08-31-bug6-fix-plan.md）

1. **ADR-010 M3 修订**：createFolder 顶层位置 = **drop 目标 target 原地**（废弃「min 原 index」）；下标移位：source 在 target 前时 `targetIndex-1`，先算后删再 clamp；`LayoutMutation.swift` 文件头语义速查与 doc 注释同波同步（不同步 = Reviewer FAIL 项）。
2. **C 第二层解冻条件**：BLOCKED。Worker 先评估 AppDelegate 侧不调用 `install()` 是否等效（recognizer 双通路合一）；可行则不解冻；不可行报 Main 申请解冻；任何情形不得自行改冻结文件。
3. **sessionLayout generation 恒零观察项**（FIX-PROMPT §4.3，AppDelegate.swift:539-547 / makeSessionLayout generation:.zero / applyCommittedLayout 用 folder generation）：本三波**不修**，是 fallback 通路的上游成因；用户复测报「第二次拖拽行为异常」→ 直接指向此项，由 Chief 决定是否单独开任务。

---

# Phase 1F BUG7-fix（2026-09-01，追加节）

- 上游：`Workflow/BUG7-REPORT.md`（用户实机复测 3 缺陷）+ `Workflow/BUG7-FIX-PLAN.md`（定案方案，Main 手算核验）+ `Workflow/tasks/T-1F-B7-planning.md`
- 决策：`Workflow/decisions/D-2026-09-01-bug7-fix-plan.md`（D1–D6）
- 基线：1026 tests / 0 failures；debug/release exit 0

## DAG 与调度

```
BUG6 三波（已合并，1026/0 复核）→ T-1F-B7-wave-a ∥ T-1F-B7-wave-b → T-1F-B7-wave-c（blocked，串在 b 后）
```

- **A′**（缺陷 1，域层，Status: ready）：`LayoutMutation.swift`（createFolder 落点行 + 注释三处）+ `LayoutMutationCreateFolderBug6Tests.swift`；与 B′ 写范围不相交。
- **B′**（缺陷 2，几何/映射，Status: ready）：`DragGeometry.swift` + `DropIntent.swift` + `AppDelegate.swift` 仅 makeDragGeometry + page≥1 新测试；次因（edge zone 40pt 重叠）只评估。
- **C′**（缺陷 3，启动路径，**Status: blocked**）：AppDelegate（handleDragCellClick / 空白收窄）+ DragUISessionCoordinator（DBG 清理）；**第一层取证（lastOutcome 六态处置表）先于结构修改**；解 blocked 条件 = B′ Reviewer PASS 合并。

## 缺陷 → 修复 → 验收映射

| 缺陷 | 修法（公式定案，不改） | 验收（用户原话字面，格子语义） |
|---|---|---|
| 1 建夹落点 | `insertion = targetIndex`（无 -1）；成员序 `[target,source]` | 拖 A→B ⇒ folder 在 B 的格子：`[C,F]` / `[F,C]` / `[X,C,F]` 三构型 |
| 2 最右列 | 顶层 intent 产出处 `global = page×itemsPerPage + local`；folder 不乘；engine/resolver 不二次换算 | 其他列可拖到最右列（同页 + 跨末页）；page≥1 单测 + folder 回归锁 |
| 3 顶层点击 | 先 lastOutcome 取证 → 合成 cell + servedRevision 统一路径；空白收窄 + DBG 清理 | 建夹后顶层单击可启动、空白退出、成员启动不回归 |

## 红线（沿用 BUG6 全项）

- 冻结树全列：PagingCore / AppCatalogCore / MacAppCatalog / AppIconPipeline / PagingTelemetry / PagingUI / Package.swift / **AppLaunchController.swift**（C′ 也不碰）。
- 禁读 LaunchBetter / BuhoReverseNotes / 2026-08-25-buho-launchpad-reverse；隐私 A/B/C 代称；无 git；注释与实现不一致 = Reviewer FAIL。
- **ADR-010 M3 誊写归 Main 合并时**（Wave A′ 合并动作），Worker/Chief 不碰 Docs/。

## 实机复验脚本（每波后，用户原话字面）

1. `[A,B,C]` 相邻左/右两方向建夹落点（folder 在 **B 格**）
2. 同页拖到最右列 + 跨页拖到末页最右列
3. 建夹后单击各顶层 app + 空白退出
4. 交替拖拽/点击 20 次无退化；folder 内成员拖拽/启动不回归

---

# Phase 1F BUG10-fix（2026-09-02）

- 上游：`Workflow/BUG10-REPORT.md`（用户实机 3 缺陷）+ `Workflow/BUG10-FIX-PROMPT.md`（OBS 审查结论 334 行，§0 证据等级声明权威）。
- 基线：1062/0（BUG9 wave-a+b 已合并）；debug/release exit 0。
- 决策：`Workflow/decisions/D-2026-09-02-bug10-fix-plan.md`（D1–D6）。
- 证据等级 → 处置（FIX-PROMPT §0 定死，Chief 不重诊断）：C 数值证明 → 直接实现；B 静态证明 → 直接实现（B1/B2 已定案 B1，见 D2）；A 强假设未实机确认 → **取证前置，实现波 blocked**。

## DAG 与调度

```
wave-c（C，ready）∥ wave-b（B，ready）∥ wave-a-forensics（A 取证，ready，零行为）
         ↓（census 读数回 Main + 判别表命中）
wave-a-fix（A 实现，blocked，按判别表命中行解除）
```

- **wave-c**（缺陷 C，几何单点）：`Sources/AppGridUI/DragSession/DropIntent.swift`（insertionIndex :86-125 坐标系无关重写 + 注释同步）+ `Tests/AppGridUITests/Bug6DropZoneGeometryTests.swift`（y-up 夹具回归锁 + 边界锁 + 顶层同构锁）。
- **wave-b**（缺陷 B，宿主切换，方案 B1 已定案）：`DragUIVisuals.swift`（host 可切换 + 幂等）+ `DragUISessionCoordinator.swift`（visualHost 同源）+ `AppDelegate.swift`（refreshFolderOverlay 处切换驱动）+ 坐标系契约测试。
- **wave-a-forensics**（A 取证，零行为变更）：`FolderOverlayView.swift` + `AppDelegate.swift`（仅 census 布点 4 处，见任务包）+ 用户实机 6 步脚本 + 判别表 4 行。独立于 C/B，可先行。
- **wave-a-fix**（A 实现，**blocked**）：解除条件 = 取证读数回 Main 且判别表命中行；按命中行定写范围（候选 overlay 移除/hitTest 生命周期，或 launchMember 调用方，或 handleCell 校验链调用方——校验链本体 :129-143 冻结）。

## 写范围表（文件级，互斥）

| 文件 | wave-c | wave-b | wave-a-forensics | wave-a-fix |
|---|---|---|---|---|
| DropIntent.swift | ✅ | ❌ | ❌ | ❌ |
| DragUIVisuals.swift | ❌ | ✅ | ❌ | ❌ |
| DragUISessionCoordinator.swift | ❌ | ✅（仅 visualHost 切换面） | ❌ | ❌ |
| AppDelegate.swift | ❌ | ✅（仅切换驱动） | ✅（仅 census 布点） | 待判别表 |
| FolderOverlayView.swift | ❌ | ❌ | ✅（仅 census 布点） | 待判别表 |
| Bug6DropZoneGeometryTests.swift | ✅ | ❌ | ❌ | ❌ |
| 冻结树全列 | ❌ | ❌ | ❌ | ❌（校验链本体永不改） |

**冲突裁决**：wave-b 与 wave-a-forensics 都写 AppDelegate.swift（不同区域、无行段交集——b 只动 refreshFolderOverlay 附近切换驱动、forensics 只动 closeFolder/hitTest 喂点），准许并行但合并顺序 Main 定（建议 forensics 先并，防 b 的 diff 噪声盖过取证布点）。若 Reviewer 判定有冲突，降级为串行 forensics→b。

## 缺陷 → 修复 → 验收映射

| 缺陷 | 修法（FIX-PROMPT 定案，不改） | 验收（用户原话字面） |
|---|---|---|
| C 蓝条落下一行正中 | `DropZoneGeometry.insertionIndex` 坐标系无关重写（竖直区间重叠聚类 + 阅读序）；只修这一处，`insertionRect` 不动 | 右列最上 app B 右缘外拖 → 蓝条在 **B 右侧**；顶层同构场景�正确；`insertionIndex ∈ [0,count]`；y-up 夹具锁 |
| B preview 在主界面 | B1：folder scope 下视觉宿主切到 overlay；坐标链同源契约写死 | folder 内拖成员 preview 面板内跟手；move-out 不跳变；顶层零回归；宿主切换幂等 |
| A 建夹后点不开 | **先取证**（触发条件=开过再关 folder，非建夹——census run2 :64-71 时序）；判别表命中后才实现 | 取证读数落盘 → 定位闭环 → 修复后 建→开→关→顶层点击能启动、s10 正常增 |

## 红线（FIX-PROMPT §5 全项）

- 冻结树零触碰全列 + `AppLaunchController.swift`（A 若定位校验链，改调用方）。
- 禁读 LaunchBetter / BuhoReverseNotes / 2026-08-25-buho-launchpad-reverse / Ghidra / otool dump；B2 解冻仅限已裁决记录（CONTAMINATION_LOG.md :22），且本批已定案 B1 不采用 B2。
- 本次不新增 `DragParameters` 字段；census sink 只中性名+计数+布尔位；隐私 A/B/C；无 git。
- `swift test` ≥1062+新增全绿；debug/release exit 0；每波独立 Reviewer PASS。

---

# Phase 1G Plan — 驻留启动器、菜单栏、Dock Reopen、全局快捷键、Hot Corner 与四指向内捏合呼出（APPENDED）

- **Author**: Chief (glm-5.3)
- **Date**: 2026-09-05
- **Prompt**: `Docs/PHASE1G_ACTIVATION_ENTRY_HOT_CORNER_PROMPT.md`（1655 行，权威开发输入）
- **Workflow**: chef-worker-reviewer-workflow v1.4.1
- **Appended to**: Phase 1F plan above（历史保留，不重写）
- **State observation（规划时读取）**: `Workflow/STATE.json` phase = `PHASE1F_AUTOMATED_COMPLETE_PHYSICAL_PENDING`；Gate 0 对账完成（自动化 1137/0，debug/release exit 0）；B10 生产默认关定案（`PAGING_CLICK_MANUAL_DELIVERY` 默认关，实机 A/B 延后）；B11 视觉验收挂账（`PHYSICAL_VISUAL_ACCEPTANCE_PENDING`）；四指 G-P0 路线已定（接受私有 MultitouchSupport 后端，来源审计+ADR+风险清单先行，用户确认风险清单后才运行采集实验）；Phase 1G 先做纯逻辑（`Workflow/decisions/2026-09-05-gate0-user-decisions.md`）。

## 1. Goal

在 Phase 1F（分页/目录/启动/搜索/文件夹/拖拽/布局持久化）之上新增一套**独立设计、基础入口公开 API、四指单独决策、默认低权限**的启动器呈现入口：

1. 应用作为驻留进程时可靠显示/隐藏/切换**唯一**启动器窗口；
2. 菜单栏提供稳定 Show/Hide、Activation Settings 与真正 Quit；
3. Dock/Reopen 显示现有窗口，不重复创建；
4. 可选全局快捷键触发 Show/Hide，不读取普通键盘内容；
5. 可选 Hot Corner 后台触发 Show，无全局事件监听/CGEvent tap/辅助功能权限；
6. 多入口同时到达由单一 `LauncherPresentationCoordinator` 仲裁（无双窗口、反向 toggle、卡死全屏 Space、旧回调覆盖）；
7. 隐藏/再显示不破坏 1F 布局持久化、拖拽、文件夹、搜索、焦点与应用启动；
8. 启动/空白点击/ESC 从「退出进程」迁移为「关闭启动器界面」，仅明确 Quit 终止驻留进程；
9. 全部参数、权限、能耗与物理行为有可重复证据；
10. 进程驻留且界面隐藏时，四指向内捏合发出一次 Show；向外张开不自动 Hide。

## 2. Scope (in)

1. **纯 presentation/activation 状态机**（T-1G-A）：`LauncherPresentationState`（.hidden/.presenting(requestID, targetScreen)/.visible(screenID)/.dismissing(requestID, reason)/.suspended(reason)/.terminating）、`LauncherActivationSource`（.initialLaunch/.dockReopen/.statusItem/.globalShortcut/.hotCorner/.testHarness）、`LauncherCommand`（.show/.hide/.toggle/.quit）、`DismissReason`（.backgroundClick/.escape/.appLaunched/.statusItem/.globalShortcut/.screenConfigurationChanged/.sessionResigned/.explicitQuit）；request generation/stale rejection；toggle 原子仲裁；opposite-command 中断/排队策略；Hot Corner 纯状态机（.disabled/.armed/.insideCandidate(corner, enteredAt)/.triggeredAwaitingExit(corner)/.suspended(reason)）+ fake clock；`ScreenGeometrySnapshot` 值模型（负坐标/多屏/内角规则）；shortcut registration outcome 模型（configured/conflict/unavailable）。
2. **ADR-011/012 草稿**（T-1G-A）：ADR-011 12 问（state/generation 所有权、幂等与中断语义、native fullscreen vs panel 选择+spike 证据、单窗跨 hide/show 复用、hide vs terminate teardown 边界、blank/ESC/launch/close 行为、drag/search/folder/title/focus/page 调和、竞态拒绝、多屏 target、Reduce Motion、B10 保持、为何不用私有 Space API）；ADR-012 12 问（默认启用集、shortcut 公开 API、Hot Corner API/scheduler、为何不用 monitor/tap/Accessibility、dwell/hysteresis/cooldown/re-arm、多屏/sleep/lock、配置持久化/迁移/reset/隔离、数据接触与禁记、能耗门与降级、冲突恢复、无 trigger 时访问/退出、延期项）。
3. **窗口与驻留生命周期**（T-1G-B，物理门回填后启动）：native-fullscreen vs screen-covering panel 最小 spike；单 window controller；show/hide/present/dismiss；key/main/first responder；Reduce Motion；hide vs terminate teardown；多屏 target；transition callback generation guard。
4. **Status Item 与 Dock Reopen**（T-1G-C，物理门回填后启动）：`StatusItemController`（NSStatusBar/NSStatusItem，独立 symbol，Show/Hide 动态状态、Activation Settings、Quit，菜单 validation 从 coordinator committed state 派生，创建失败不崩溃）；`applicationShouldHandleReopen` adapter（hidden→show；visible→key；不建第二窗口）。
5. **Shortcut、Hot Corner 与 Preferences**（T-1G-D，物理门回填后启动）：`GlobalShortcutRegistrar`（RegisterEventHotKey 路径比较，默认 Off，fake registrar 测试）；Hot Corner poll scheduler + screen adapter + sleep/session observer；`ActivationPreferences`（专用 namespace UserDefaults，非法值回 Off，独立 suite，reset activation 独立动作）。
6. **AppDelegate 单点集成**（T-1G-E，物理门回填后启动）：composition root；全部入口进同一 coordinator；blank/ESC/app launch/window close→hide；explicit Quit→terminate；drag/search/folder/title/focus/layout flush 调和；B10/B11 回归。
7. **四指参考审计与决策**（T-G-P0）：`Docs/FOUR_FINGER_REFERENCE_AUDIT.md`（LaunchBetter 白名单 4 文件逐项审计：PinchAnalyzer.swift/MultitouchSupport.swift/GestureCaptureEngine.swift/ActivationCoordinator.swift；另有 2 个测试文件仅定位未读取）+ 四指 API/权限 ADR（ADR-013）+ 风险清单（用户确认后才运行采集实验）。
8. **独立四指识别器**（T-G-P1）：纯值状态机（Disabled/Idle/Candidate/Recognizing/Fired/WaitingForRelease/Suspended 或等价）、可注入单调时钟、设备隔离 token、§19.2 十二条合同、P01-P20 自动化矩阵（纯逻辑部分）。
9. **平台 provider**（T-G-P2）：`TouchProvider` protocol + Mock provider（合成匿名触点）+ 生命周期测试；真实 MultitouchSupport 后端仅 T-G-P0 批准后（独立子任务）。
10. **配置与入口状态**（T-G-P3）：四指开关/后端可用性/未验证状态/失败原因（Off/Checking/Ready/NoDevice/Unavailable/PermissionNotConfirmed/Suspended；Enabled≠Ready）、迁移、状态展示。
11. **协调器接线**（T-G-P4）：四指识别器→coordinator 的 `show(source: fourFingerPinch, eventToken:)` 接线、去重、generation、隐藏与 Quit 语义、输入交接策略（会话结束优先）。
12. **评审/实机/收口**（T-1G-F、T-G-P5/P6/P7）：独立 Reviewer、能耗 A/B、真实设备矩阵、final docs/manifest。

## 3. Non-goals（out of scope）

- 不实现：三指拖动、系统手势替代、向外张开关闭、鼠标/压力手势、多手识别；不屏蔽系统事件、不改系统手势偏好、不杀其他手势软件、不读其配置。
- 不申请 Accessibility/Input Monitoring/Screen Recording（四指获批窄例外除外）；无 global NSEvent monitor / CGEvent tap / IOHID 抓取。
- 不读 Launchpad/Dock 私有 DB；不读系统 Hot Corner 私有偏好；不复制第三方菜单/快捷键/参数/视觉/动画。
- 不修改 `PagingCore`/Timer tolerance/frame source 默认值（`PRODUCT_TIMER_TOLERANCE_0MS` 不变）；不宣称 `>25ms` 长尾已修复。
- 不实现自动更新/购买/许可证/最近启动列表/应用清单菜单；不做发布/签名/公证/Launch at Login。
- 不清理 B10 诊断代码（独立任务）；不新增第三方依赖。
- 四指「启动」= 进程已驻留时呼出界面；不承诺冷启动进程、不建后台 helper/LaunchAgent/登录项/守护进程。
- 硬依赖以上任一项 → 停止 + `SCOPE_EXPANSION_REQUIRES_USER_DECISION`。

## 4. Frozen trees（do not modify）

```
Sources/PagingCore/
Sources/PagingTelemetry/
Sources/PagingUI/
Sources/AppCatalogCore/
Sources/MacAppCatalog/
Sources/AppIconPipeline/
Sources/AppGridUI/LayoutDomain/
Sources/AppGridUI/LayoutStore/
Sources/AppGridUI/DragSession/
Package.swift
Sources/PagingPrototypeApp/AppLaunchController.swift
```

## 5. Allowed write scope

```
Sources/PagingPrototypeApp/  （新增窄文件优先：LauncherPresentationState.swift、
  LauncherPresentationCoordinator.swift、LauncherWindowController.swift、
  StatusItemController.swift、GlobalShortcutRegistrar.swift、HotCornerMonitor.swift、
  HotCornerGeometry.swift、ActivationPreferences.swift、WorkspaceSessionObserver.swift
  ——文件名可调，职责不得塞回 AppDelegate.swift）
Sources/PagingPrototypeApp/AppDelegate.swift、AppMain.swift、AppArguments.swift
Sources/PagingPrototypeApp/KeyboardFocusController.swift（仅 ESC/dismiss seam）
Tests/PagingUITests/
Tests/AppGridUITests/（仅必要集成回归）
Docs/
PROVENANCE/
Workflow/
```

例外：Carbon/HIToolbox 需 `Package.swift` 调整只能 Main 单独改+Reviewer，不得加第三方依赖；AppGridUI 窄 cancel/reconcile seam 需 Chief 先证明 App 层无法安全组合再建独占任务。

## 6. Task DAG（§7 基础入口轨 × §22 四指轨融合；仅语义依赖，不写运行时并发）

```
Gate 0（Phase 1F 对账，已完成：gate0-1g；phase=PHASE1F_AUTOMATED_COMPLETE_PHYSICAL_PENDING）
   │
   ├───────────────────────────────┐
   ▼                               ▼
T-1G-A（无依赖）                T-G-P0（无依赖）
ADR-011/012 草稿 + 纯           四指参考审计（FOUR_FINGER_REFERENCE_AUDIT.md）
presentation/activation          + ADR-013 + 风险清单
状态机 + Hot Corner 纯状态机      （用户确认风险清单后才运行采集实验）
+ geometry 值模型 + shortcut
outcome 模型 + 测试
   │                               │
   ├──────────┬──────────┐         ▼
   ▼          ▼          ▼      T-G-P1（依赖 P0）
T-1G-B      T-1G-C      T-1G-D   独立四指识别器（纯值状态机、
Window/     Status/     Shortcut 可注入单调时钟、P01-P20）
lifecycle   Dock        + Hot Corner adapters
   │          │          │         ▼
   └──────────┴────┬─────┘      T-G-P2（依赖 P0/P1）
                  ▼             平台 provider（Mock 先行；
T-1G-E（依赖 A/B/C/D，串行）      真实后端需 P0 批准）
AppDelegate 单点集成 +             │
existing-feature reconcile         ▼
   │                            T-G-P3（依赖 P0）
   │                            配置与入口状态（开关/迁移/展示）
   │                              │
   ├──────────────────────────────┤
   ▼                              ▼
T-1G-F（独立）                 T-G-P4（依赖 P1/P2/P3 + T-1G-A 协调器）
整体评审/能耗/实机/收尾          协调器接线（去重/generation/隐藏与 Quit/交接）
   │                              │
   └──────────────┬───────────────┘
                  ▼
        T-G-P5 独立评审 → T-G-P6 实机与性能 → T-G-P7 收口
```

- **本轮只执行纯逻辑**：T-1G-A、T-G-P0（审计/ADR/风险清单部分）、T-G-P1、T-G-P2（Mock）、T-G-P3。
- **T-1G-B/C/D/E 与真实四指后端在物理门回填前不启动**（`PHASE1F_AUTOMATED_COMPLETE_PHYSICAL_PENDING` 解除 + 用户确认 G-P0 风险清单）；任务包已预建。
- T-G-P5/P6/P7 可后建（评审/实机/收口，依赖前序 PASS）。
- 共享文件（AppDelegate.swift、Package.swift、ADR canonical、STATE/events）单写者；SwiftPM full build/test 串行（`.build`）。

## 7. Per-task write scopes（文件级，互斥）

| 任务 | 依赖 | Expected/Allowed write scope | Forbidden |
|---|---|---|---|
| **T-1G-A** | 无 | 新纯逻辑文件 `Sources/PagingPrototypeApp/`（presentation state/coordinator 纯状态、Hot Corner 状态机、geometry 值模型、shortcut outcome 模型）；`Tests/PagingUITests/` 新测试；`Docs/ADR-011-*.md`、`Docs/ADR-012-*.md`（Chief DRAFT） | AppKit 行为代码、AppDelegate/AppMain/AppArguments、冻结树、Package.swift |
| **T-G-P0** | 无 | `Docs/FOUR_FINGER_REFERENCE_AUDIT.md`、`Docs/ADR-013-*.md`、风险清单文档；PROVENANCE 记录 | 真实采集实现、任何 Sources/ 代码、复制整份参考源码 |
| **T-G-P1** | P0 | 新纯识别器文件 + `Tests/PagingUITests/` 测试 | provider/后端、窗口代码、冻结树 |
| **T-G-P2** | P0/P1 | 新 provider protocol + Mock + 生命周期测试 | 真实 MultitouchSupport 后端（未批准）、窗口代码 |
| **T-G-P3** | P0 | 新 `ActivationPreferences.swift` + 四指入口状态模型 + 测试 | AppDelegate 接线、真实 defaults 污染 |
| **T-G-P4** | P1/P2/P3 + T-1G-A | 协调器接线文件（四指入口→coordinator） | 窗口行为代码（物理门未回填）、AppLaunchController |
| **T-1G-B/C/D/E** | 见 DAG | 按 §6.2 各自窄文件（预建，未启动） | 冻结树、AppLaunchController |
| **T-1G-F、T-G-P5/P6/P7** | 前序 PASS | Docs/Workflow 产物（可后建） | 产品代码 |

## 8. Architecture decisions（ADR-011/012/013 — 摘要；草稿在 Docs/）

- **ADR-011（Launcher presentation lifecycle）**：单一 `LauncherPresentationCoordinator` 拥有 presentation state 与 request generation；show/hide/toggle/quit 幂等与中断语义按 §3.1；窗口形态（native fullscreen vs screen-covering panel）由 T-1G-B spike 证据定案（架构硬门，Chief 决策）；hide 不 teardown 服务、terminate 才最终 teardown；ESC/blank/launch/close 的 dismiss 优先级集中定义；多屏 target screen 策略（Hot Corner=触发屏；status/shortcut/Dock=鼠标所在屏或 key/main fallback）；Reduce Motion 只影响视觉不影响状态；B10 click delivery 不因窗口形态重构回归。
- **ADR-012（System-wide activation privacy）**：默认全部系统级 trigger Off（shortcut Off、Hot Corner Off、fourFingerActivationEnabled=false 直到验证/获批）；shortcut 用公开 RegisterEventHotKey 路径（若选），窄 `GlobalShortcutRegistering` protocol；Hot Corner 用公开 `NSEvent.mouseLocation` 低频可暂停轮询 + 纯几何判定 + 纯状态机；不用 global monitor/CGEvent tap/Accessibility；dwell/hysteresis/cooldown/re-arm 语义按 §3.7；配置专用 namespace UserDefaults、非法值回 Off、独立 suite；隐私数据边界按 §4.3；能耗门失败 → `HOT_CORNER_ENERGY_GATE_FAILED`，保留菜单/快捷键。
- **ADR-013（Four-finger activation backend）**：路线=私有 MultitouchSupport 窄例外（用户已接受，风险清单确认后才运行采集实验）；独立实现来源边界（LaunchBetter 白名单 6 文件只读）；识别会话/设备隔离/锁序/输入交接/默认开关/私有实现排除方式（编译排除 vs 运行时禁用区分）；分发未评估。

## 9. Invariants（不变量）

1. 一进程最多一个 launcher window、一个有效 transition、一个 active request ID；旧 completion 永不覆盖新状态。
2. 全部激活入口（initialLaunch/dockReopen/statusItem/globalShortcut/hotCorner/fourFingerPinch/testHarness）只经 `LauncherPresentationCoordinator`；无直接窗口操作。
3. show 在 visible/presenting 幂等；hide 在 hidden/dismissing 幂等；toggle 在 committed state 原子决策；Hot Corner 与四指只发 `.show`，永不反向 hide；explicit Quit 才发 `.quit`。
4. 空白点击/ESC/app launch/window close → hide（进程驻留）；仅 status menu Quit/Cmd-Q/系统 terminate 终止进程。
5. hide 不 teardown catalog/layout store/status item/hotkey/hot-corner 服务；termination 才最终 teardown + bounded layout flush。
6. 无 global NSEvent monitor / CGEvent tap / Accessibility / Input Monitoring / Screen Recording（四指获批窄例外除外）。
7. 不记录/持久化 pointer 坐标、轨迹、screen UUID/name/serial、frontmost app、按键流、真实快捷键文本、app 身份、folder 数据、搜索词、窗口标题；只允许中性 enum/计数。
8. Hot Corner disabled = 零 timer 零轮询；参数与显示刷新率无关（dwell/cooldown 不用 frame count）。
9. 四指：严格四个有效触点、一会话一次、全指释放才 re-arm、设备隔离、单调时钟、不持久化触点数据。
10. `PRODUCT_TIMER_TOLERANCE_0MS` / `SHORT_TAIL_MITIGATED_BY_TOLERANCE` / `CAUSALITY_UNRESOLVED_FOR_GT25MS` 不变；PagingCore 冻结。
11. 不修改/绕过 `AppLaunchController` 身份/文件存在校验；不新增第二条 NSWorkspace app-launch 路径。
12. 隐藏时取消 drag/edge timer/title edit/search transient/folder overlay/旧图标回调/presentation animation；不保留半开/半拖拽状态（保留策略由 ADR-011 明确）。

## 10. Global acceptance criteria（§14 + §25.1 融合）

```
PHASE_1F_GATE0_CLOSED（自动化已过；物理门 PENDING 挂账）
ADR-011 = DRAFT（Chief 推进 ACCEPTED）；ADR-012 = DRAFT（Chief 推进 ACCEPTED）；ADR-013 = DRAFT（Chief 推进 ACCEPTED，四指轨）
PRESENTATION_STATE_MACHINE_TESTS = PASS（§9.1）
HOT_CORNER_PURE_STATE_TESTS = PASS（§9.6）
SCREEN_GEOMETRY_TESTS = PASS（§9.7）
PREFERENCES_TESTS = PASS（§9.8）
FOUR_FINGER_RECOGNIZER_TESTS = PASS（P01-P20 纯逻辑部分）
FOUR_FINGER_PROVIDER_MOCK_TESTS = PASS（P13/P14/P15）
FULL_SWIFT_TESTS = PASS_WITH_EXECUTED_COUNT
BUILD_DEBUG = PASS；BUILD_RELEASE = PASS
INDEPENDENT_REVIEW = PASS（0 BLOCKER / 0 MAJOR）
PRIVACY_AND_PROVENANCE_REDLINE = PASS（静态红线扫描）
MANUAL_*_GATES = PASS_USER_REPORTED_WITH_EVIDENCE 或 NOT_RUN/BLOCKED_BY_HARDWARE
FOUR_FINGER_PHYSICAL_GATE = PASS 或 PARTIAL/BLOCKED（不可用/Deferred 不算完成）
```

状态必须可分解：基础入口 PASS / 四指自动化 PASS / 四指物理 PASS / 兼容性未测 / 分发未评估；四指未完成 → 整体 PARTIAL 或 BLOCKED，「接口已预留」≠ 用户功能完成。120Hz/多显示器无硬件 → `120HZ_PHYSICAL_GATE_BLOCKED_BY_HARDWARE` / `MULTI_DISPLAY_PHYSICAL_GATE_BLOCKED_BY_HARDWARE`。

## 11. Privacy redlines（§4.3）

禁记/输出：raw pointer 坐标、轨迹、screen UUID/name/serial、frontmost app、按键流、真实快捷键文本（默认日志）、app 名/bundle ID/path/URL、folder title/UUID/member list、搜索词、窗口标题。允许中性：activation source enum、show/hide/toggle/quit outcome enum、corner enum、dwell/cooldown state enum、screen count、registration outcome enum、transition duration aggregate、counter。更新 `PRIVACY_DATA_MAP.md`。静态红线扫描：新增/修改源码不得出现 `addGlobalMonitorForEvents`、`CGEvent.tapCreate`、`AXIsProcessTrusted`、`IOHID`、private API selector strings、`LaunchBetter`、`Buho`、license crack/bypass、pointer coordinate logging、`frontmostApplication` query（政策文档允许出现；扫描器区分源码与文档；获批私有符号只允许精确模块白名单）。

## 12. Manual gates（用户真实设备）

- `MANUAL_SINGLE_DISPLAY_ACTIVATION_GATE` — §10.2 十二项矩阵（menu Show/Hide、Dock reopen、快捷键从他 app 触发、Hot Corner Off/On、dwell 一次、留角不重复、离开再进入、触发后交互、启动成功隐藏驻留、空白/ESC 隐藏、Quit 真退出）。
- `MANUAL_RAPID_RACE_GATE` — §10.3 快速竞态矩阵（20 次循环无多窗/卡住/残留 timer）。
- `MANUAL_MULTI_DISPLAY_GATE` — 无硬件 → `MULTI_DISPLAY_PHYSICAL_GATE_BLOCKED_BY_HARDWARE`。
- `MANUAL_SLEEP_LOCK_GATE` — sleep/wake/lock/unlock 最小真实门。
- `MANUAL_FOUR_FINGER_GATE` — M01-M12（后台呼出 20 次≥19、慢/快各 10 次≥9、可见幂等 10 次、张开 20 次零误触、负样本各 20 次、连续手势单会话一次、多入口、生命周期、无设备、设备差异、输入交接、回归）。
- `MANUAL_120HZ_GATE` — `BLOCKED_BY_HARDWARE_OR_REAL_PASS`。
- 能耗门：disabled/enabled A/B（同 Release 构建、同屏幕环境；隐藏空闲每条件≥3 轮 60s 采样；先写阈值再运行；CPU/wakeup 单位与工具写明；不得只凭 Activity Monitor 截图写 PASS）。

## 13. Stop conditions（§12 标签）

`BLOCKED_BY_PHASE1F_REGRESSION` / `SCOPE_EXPANSION_REQUIRES_USER_DECISION` / `PERMISSION_EXPANSION_REQUIRES_USER_DECISION` / `WINDOW_ARCHITECTURE_DECISION_REQUIRED` / `HOT_CORNER_ENERGY_GATE_FAILED` / `PHYSICAL_ACCEPTANCE_PENDING`。触发：1F 生产默认点击/拖拽仍坏；必须私有 Space/WindowServer API；必须 Accessibility/Input Monitoring/Screen Recording；必须全局 monitor/tap；必须读 Dock/Launchpad 私有配置；必须改 PagingCore/Timer 参数；Hot Corner 能耗门失败无低成本替代；native fullscreen 与驻留 show/hide 无法可靠共存且 overlay 改变用户语义未获决策；需第三方依赖无授权；activation/license bypass；复制第三方 UI/参数/文案。不得为「完成 1G」降低权限/隐私/物理门。

## 14. Main flexibility boundary

Main 可：调度/顺序/并发/重试/证据/状态维护；运行纯逻辑任务（T-1G-A、T-G-P0 审计、T-G-P1、T-G-P2 Mock、T-G-P3）；计划内小适配（保持设计语义）；汇总用户决策（G-P0 风险清单确认、四指默认开关确认）。Main 不可：修改用户目标/架构/接口契约/验收标准/语义依赖/已确认约束；在物理门回填前启动 T-1G-B/C/D/E 或真实四指后端；未经用户确认风险清单运行采集实验；改冻结树；借 1G 清理 B10 诊断代码；改 `Package.swift` 之外的共享文件（Package.swift 由 Main 独占）。

## 15. Chief decision items

1. 窗口形态定案（native fullscreen vs screen-covering panel）——T-1G-B spike 证据后 Chief 决策（`WINDOW_ARCHITECTURE_DECISION_REQUIRED` 标签）。
2. status/shortcut/Dock 的 target screen 策略（ADR-011 Q9）。
3. hide 时 committed page/焦点/folder selection 保留策略（ADR-011；默认不保留半开状态）。
4. Dock 图标 `.regular` vs `.accessory`（ADR-011/012）。
5. Hot Corner poll scheduler 选择（Timer vs DispatchSourceTimer vs 专用低功耗 scheduler，ADR-012）。
6. shortcut API 定案（RegisterEventHotKey vs 延后；默认 Off，ADR-012）。
7. 四指严格四 vs 至少四：实机证据与用户决策（Main 汇总）。
8. 四指最终默认开关值（用户确认前不得默认启用）。
9. 输入交接策略（会话结束优先；ADR-013）。
10. G-P0 风险清单接受（用户确认后才运行采集实验）。
11. 能耗门失败降级（保留菜单/快捷键，Hot Corner 标 Failed/Deferred）。
12. T-1G-B/C/D/E 启动门（物理门回填 + 风险清单确认后，Chief 确认解除）。

## 16. Next-phase recommendation boundary

Phase 1G 全部通过后仅允许：`RECOMMEND_PROCEED_TO_PHASE_1H_PRODUCT_SETTINGS_AND_PACKAGING_READINESS`（正式设置窗口/Launch at Login/品牌 UI/应用图标/签名沙盒公证准备/诊断代码去产品化）。不自动授权：发布/签名公证/装 Launch at Login/删历史证据/commit/push/tag/activation-license/读第三方。若自动化通过但物理门不完整 → `PHASE1G_AUTOMATED_COMPLETE_PHYSICAL_PENDING`（或 PARTIAL），保留三性能 token。
