# T-1E-C — Folder Cell / Open Layer / Inner Paging

- **Task ID**: T-1E-C
- **Role**: Worker C (attempt 2 — completed partial state from stopped attempt 1)
- **Phase**: 1E — folder cell / thumbnail / open layer
- **ADR**: ADR-008 (ACCEPTED) §2.1/§2.4/§2.5
- **Status**: IMPLEMENTED (verification in progress)

## Implementation

Neutral folder entry visuals + open layer (title + member grid + inner paging), app-vs-folder
cell distinction, thumbnail stale defense, inner paging isolated from outer, click-outside-closes-folder,
Reduce Motion correctness, teardown zero callbacks.

### Files changed (write scope)

- `Sources/AppGridUI/AppGridCellView.swift` — **completed/repaired** (partial from attempt 1).
  - `bindFolder(title:memberCount:token:)` (L98): neutral SF Symbol "folder" + title + member count;
    `isFolderCell = true`; role `.button`, label = title, help = "Folder with N items".
  - `applyIconIfValid` (L137): `guard !isFolderCell` → folder cell **always rejects** app-icon writeback.
  - `clearContent` (L118): clears folder symbol / member count / title / focus / token.
  - Added read-only test accessors `memberCountText`, `isFolderSymbolVisible` (L41-42).
- `Sources/AppGridUI/AppGridPageView.swift` — **completed/repaired** (partial from attempt 1).
  - `render` (L129-138): folder identity (`as? FolderID`) → `bindFolder` with member count from
    `folderSnapshotProvider`; folder cells never request app icons (`iconKey(for:)` returns nil for non-AppID).
  - `clearForReuse`/`teardown` bump `surfaceGeneration` (stale defense).
- `Sources/AppGridUI/FolderOpenState.swift` — **completed** (partial from attempt 1; pure logic).
  - Open-state owner: which folder open + inner page (session-only). `open`/`close`/`setInnerPage`
    bump `generation` (stale defense for open-A-then-open-B). No outer-page state (inner paging isolated).
- `Sources/AppGridUI/FolderOverlayView.swift` — **completed/repaired** (partial from attempt 1).
  - Open layer: full-surface mask + centered panel (title + member grid + inner paging).
  - **Repaired bug**: `handleClick` member-cell hit-test compared overlay-coord point against
    panel-coord cell frames → now converts point to panel coords (`panel.convert(point, from: self)`).
  - Click outside panel → `onRequestClose` (closes folder only, not app). Click member → `onActivateMember`.
  - Member icons via `IconPipeline` with `surfaceGeneration` gating; teardown → zero UI writes.
  - `MotionParams` (standard / reduceMotion) — Reduce Motion path.
  - Added `panelFrame` test accessor; made `prevPage`/`nextPage` internal for testability.

### Tests added (new)

- `Tests/AppGridUITests/FolderCellTests.swift` — app vs folder distinct; folder cell shows symbol+title+count;
  folder cell never requests/writes app icon; reuse clears title/symbol/count/focus; folder cell accessibility.
- `Tests/AppGridUITests/FolderOverlayTests.swift` — configure renders title+members; configure idempotent;
  open-A-then-open-B no cross-overwrite (old member icons rejected); click-outside closes; click-member activates;
  click panel non-member ignored; teardown zero callbacks; Reduce Motion params; clearContent clears state.
- `Tests/AppGridUITests/FolderInnerPagingTests.swift` — inner paging isolated from outer (no outer-page state);
  inner paging only fires `onInnerPageChange`; next/prev navigation; resize/fullscreen layout legal.
- `Tests/AppGridUITests/FolderOpenStateTests.swift` — **already present** (created by attempt 1; kept).

## Verification

- `swift build -c debug`: exit 0. `swift build -c release`: exit 0.
- `swift test` full suite: **689 tests, 0 failures** (baseline 660 + 29; executed > 0, 0 failures).
  - New this attempt: `FolderCellTests` (5), `FolderOverlayTests` (11), `FolderInnerPagingTests` (4) = 20.
  - Kept from attempt 1: `FolderOpenStateTests` (9).
- Frozen trees unchanged: all `Sources/PagingCore/`, `AppCatalogCore/`, `MacAppCatalog/`,
  `AppIconPipeline/`, `PagingTelemetry/`, `PagingUI/`, `Package.swift`,
  `Sources/PagingPrototypeApp/AppLaunchController.swift` mtimes predate this session (no writes).

## Deviations

- None from the task packet. `memberCountText`/`isFolderSymbolVisible`/`panelFrame` are read-only
  test/diagnostic accessors (no behavior change). `prevPage`/`nextPage` made internal (was private)
  for direct test invocation of the inner-paging action path.

## Privacy

- No folder title / membership / identity raw values or icon data in telemetry/JSONL/stdout/signpost/
  profile/report; only neutral counters. No PagingTelemetry schema change.
