# T-1E-E — AppDelegate 集成 / 刷新 / 搜索 / 启动 / blank-click

- **Task ID**: T-1E-E
- **Role**: Worker E
- **Phase**: 1E — AppDelegate integration / refresh / search / launch / blank-click
- **ADR**: ADR-008 (ACCEPTED) §2.1/§2.4/§2.5/§3 Q6/Q10
- **Status**: IMPLEMENTED (verification complete)

## Objective

Wire the folder foundation into the composition root: lab flag/test-injection wiring, member
launch reusing `AppLaunchController`, folder cell never entering app launch, search/refresh/folder
pending priority, overlay-outside click closes + next real background click exits, teardown full chain.

## Implementation

### Files changed (write scope)

- `Sources/PagingPrototypeApp/AppArguments.swift` — added `--folder-lab` flag → `Options.folderLab: Bool`
  (default `false`; product launch does not reorder user apps). Parsed in `parse()`; documented in header + help text.
- `Sources/PagingPrototypeApp/AppCatalogAssembly.swift` —
  - `AppRuntimeFactory.makeAssembly(options:)` wires `FolderLabFixture.makeGroups` as
    `folderSnapshotGenerator` when `options.folderLab` is set (default off).
  - `AppCatalogAssembly` gains `folderLabEnabled`, `folderSnapshotGenerator`, private
    `lastFolderCatalogRevision`; `rebuildFolderCompositionIfNeeded()` (idempotent per catalog
    revision; stages via `provider.receiveFolderSnapshot`; folder layer never mints/forges
    `CatalogRevision`); `begin()` calls it after `refreshController.begin()`.
  - `AppCatalogAssembly.makeMemberLaunchCell(appID:servedRevision:)` — constructs a synthetic cell
    bound with the member `AppID` + correct served revision, so member launch reuses the exact
    `AppLaunchController.handleCell` pipeline (stale revision → identity in catalog → file existence →
    `NSWorkspace`). No parallel launch path.
- `Sources/PagingPrototypeApp/AppDelegate.swift` —
  - New props `folderOpenState`, `folderOverlay`, `folderTitleEditor`.
  - `installFolderWiring(assembly:surface:keyboard:launch:)` wires `FolderOpenState` + `FolderOverlayView`
    + `FolderTitleEditor` into the keyboard controller's folder seams (`folderOpenStateProvider`,
    `onOpenFolder`, `onCloseFolder`, `onActivateMember`, `onInnerPageChange`, `folderOverlayProvider`,
    `onTitleEditRequest`, `onTitleCommit`, `onTitleCancel`) and the search controller's
    `modeFirstResponderProvider` (title editing > folder open > search > top-level).
  - `openFolder` / `closeFolder` / `launchMember` / `setFolderInnerPage` / `refreshFolderOverlay` /
    `memberName` / `beginTitleEditing` / `commitFolderTitle` / `cancelFolderTitle`.
  - **T-1E-D handoff**: `closeFolder()` calls `keyboardController?.endTitleEditing()` on ALL
    folder-close paths (blank-click `onRequestClose`, overlay clear, ESC/Command-F via `onCloseFolder`).
  - `applyPendingAtIdleBoundary()` now calls `assembly.rebuildFolderCompositionIfNeeded()` after the
    search commit and before the refresh controller commit (priority: catalog > folder > search).
  - `QuitOnBlankClickWindow` gains `folderOpenStateProvider`; `sendEvent` routes blank clicks to the
    overlay when the folder is open (close folder, not exit); next real background click (folder
    closed) exits — two-stage blank-click.
  - `teardownAll()` tears down the overlay (zero UI writes), clears folder open state, releases the
    title editor.
- `Tests/PagingUITests/FolderIntegrationTests.swift` — **new** (12 tests, see below).

### Test placement deviation (documented)

`Tests/PagingPrototypeAppTests` does **not** exist and `Package.swift` is frozen (Main-only). The only
test target that can import `PagingPrototypeApp` is `Tests/PagingUITests/` (Package.swift L60-63).
Per the packet's write-scope note ("if PagingPrototypeAppTests does not exist and Package.swift is
frozen, place integration tests in an existing allowed test target and document the deviation"),
the integration tests are placed in `Tests/PagingUITests/FolderIntegrationTests.swift` as a **new
file**; no existing PagingUITests file was modified.

### Tests (12 new)

1. `testFolderLabFlagParsed` — `--folder-lab` → `folderLab == true`; default → false; coexists with other flags.
2. `testFolderLabWiringGeneratesFolderSnapshot` — assembly folder generation wiring (6 apps @ 2/group → 3 folders).
3. `testFolderLabDefaultOffDoesNotReorder` — folderLab off → no folder composition; all app entries.
4. `testMemberLaunchReusesAppLaunchController` — member launch via synthetic cell → `handleCell` → launcher called with member bundle URL.
5. `testMemberLaunchStaleRevisionRejected` — member launch with stale revision → `.rejectedStaleRevision` (same pipeline).
6. `testFolderIdentityNeverEntersLaunch` — folder identity (`FolderID`) in binding token → `handleCell` rejects (`.rejectedNoBinding`); launcher never called.
7. `testActivationRouterBranchesFolderToOpen` — `ActivationRouter`: folder → openFolder, app → launchApp, nil → reject.
8. `testFolderRebasedOnNewCatalogBase` — new catalog snapshot → folder composition rebuilt on new base (member shrink); generation independent.
9. `testFolderGenerationIndependentOfCatalogRevision` — folder generation independent; no pending → no-op; CatalogRevision untouched.
10. `testOverlayOutsideClickClosesThenBackgroundClickExits` — two-stage blank-click: folder open → click closes (no exit); folder closed → next click exits.
11. `testBlankClickResolvesToCellClassification` — cell → not blank; container/nil → blank.
12. `testTeardownFullChain` — assembly teardown idempotent; folder open state cleared after close.

## Verification

- `swift test` full suite: **756 tests, 0 failures** — XCTest line `Executed 756 tests, with 0
  failures (0 unexpected) in 13.442 (13.490) seconds`. Baseline 744 (T-1E-D repair) + 12 new
  integration tests; all existing tests still pass. (The swift-testing `0 tests in 0 suites` line
  is NOT the count.)
- `swift test --filter FolderIntegrationTests`: **12 tests, 0 failures**.
- `swift build -c debug`: **exit 0** (Build complete).
- `swift build -c release`: **exit 0** (Build complete).
- **Frozen trees untouched** (mtime check): `Package.swift` (08-28 20:42), `AppLaunchController.swift`
  (08-28 21:46), `Sources/PagingCore/` (08-30 11:46), `AppCatalogCore/` (08-28 20:50),
  `MacAppCatalog/` (08-28 21:01), `AppIconPipeline/` (08-29 00:22), `PagingTelemetry/` (08-28 21:09),
  `PagingUI/` (08-30 15:15) — all predate my writes. AppGridUI (read-only) files all predate my
  writes (latest 16:42 = T-1E-D's `FolderKeyboardLogic.swift`). `find Sources Tests -newermt 16:44`
  returns **only** my 4 write-scope files.
- **Write scope exactly 4 files**: `AppArguments.swift`, `AppCatalogAssembly.swift`,
  `AppDelegate.swift`, `Tests/PagingUITests/FolderIntegrationTests.swift`.
- **No git operations** performed.

## Deviations

- Test placement in `Tests/PagingUITests/` (new file) instead of a non-existent `PagingPrototypeAppTests`
  (see above). No existing PagingUITests file modified.
- Member launch constructs a synthetic `AppGridCellView` bound with the member `AppID` + served
  revision (via `AppCatalogAssembly.makeMemberLaunchCell`) because the overlay's member cells carry
  `catalogRevision: 0` (AppGridUI, read-only) and would be rejected as stale by the frozen
  `AppLaunchController`. This still reuses the exact `handleCell → launch(from:)` pipeline — no
  parallel launch path.

## Privacy

- No folder title / membership / identity raw values or icon data in telemetry/JSONL/stdout/signpost/
  profile/report; only neutral counters and decision enums. No PagingTelemetry schema change. No
  global NSEvent monitor / Accessibility / Input Monitoring.
