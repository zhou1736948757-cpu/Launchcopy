# T-1E-folder-keyboard-return-repair — Worker B result

Status: PASS

## Summary

Task B of the two-task fix (depends on Task A composition-ized `AppGridFocusLayout`/`AppGridFocusNavigator`). Root cause: outer focus layout was built from app-only `CatalogSnapshot` → folder slot identity == `.app(same-index app)` → Return routed `.launchApp` → `AppLaunchController` `as? AppID` rejected → no action. All four caller sites switched to the composition API; folder slots now carry `entryIdentity: .folder` and Return routes `.openFolder`.

## Changed files

1. `Sources/PagingPrototypeApp/KeyboardFocusController.swift`
   - `currentLayout()` (~:472): `AppGridFocusLayout.build(from: snapshot, composition: provider.presentationEntries, itemsPerPage: surface.itemsPerPage)` (was app-only `build(from:itemsPerPage:)`).
   - `committedPageTarget` (~:483): `layout.validSlots(on:).first` + `layout.validEntry(page:slot:)` → `AppGridFocusIdentity(..., entryIdentity: entry)` (was `validAppID` + `appID:`).
   - `reconcileSettledCrossPage` (~:238): pending validity `layout.validEntry(page:slot:) == pending.entryIdentity`; target rebuilt with `entryIdentity: pending.entryIdentity` (minimal change, semantics kept).
2. `Sources/PagingPrototypeApp/AppDelegate.swift`
   - `applyPresentationUpdate` (~:506): `AppGridFocusLayout.build(from: base, composition: assembly.provider.presentationEntries, itemsPerPage:)` (was `CatalogSnapshot(revision:records:)` app-only; search-active → presentationEntries = result `.app` entries, semantics preserved).
3. `Tests/PagingUITests/FolderIntegrationTests.swift`
   - Added `downArrow()` helper (keyCode 125) + 3 tests (below). No existing test needed adaptation (app-only `build(from:itemsPerPage:)` compat path still used by KeyboardFocusControllerTests/KeyboardLaunchTests/AppSearch*Tests).

## New tests (all pass)

- `testSetFocusFolderIdentityReturnOpensFolder` — (a) composition fixture, `setFocus` to folder-slot identity (`entryIdentity: .folder`) → `keyDown(returnKey)` → `folderOpenState.isOpen == true`, `openFolderID == folder.id`.
- `testNavigatorToFolderSlotReturnOpensFolder` — (b) user Bug 4 exact repro: `keyDown(downArrow)` seed → `rightArrow` to folder slot → `focusModel.current?.entryIdentity == .folder(secondFolder.id)` → `keyDown(returnKey)` → `isOpen == true`, `openFolderID == secondFolder.id`.
- `testNavigatorToAppSlotIdentityIsActualApp` — (c) navigate to app cell → `entryIdentity == .app(record.id)` of `presentationEntries[2]` (guards off-by-folder-count regression).

## Test counts

- `swift test`: **Executed 785 tests, with 0 failures** (baseline 782 + Task A new + 3 new from this task). Exit 0.

## Build results

- `swift build -c debug`: exit 0 (Build complete, 1.37s).
- `swift build -c release`: exit 0 (Build complete, 3.03s).

## Frozen-tree mtime verification

Recorded before/after (find + stat -f '%m %N') for all files under `Sources/PagingCore/`, `Sources/AppCatalogCore/`, `Sources/MacAppCatalog/`, `Sources/AppIconPipeline/`, `Sources/PagingTelemetry/`, `Sources/PagingUI/`, `Sources/AppGridUI/`, plus `Package.swift`, `Sources/PagingPrototypeApp/AppLaunchController.swift`, `Sources/PagingPrototypeApp/AppCatalogAssembly.swift` — **all 60 mtimes identical before and after** (e.g. AppGridFocusLayout.swift 1788092133, AppLaunchController.swift 1787921214, Package.swift 1787917375). Frozen tree untouched.

## Reviewer acceptance mapping

- Three call sites on composition API: ✓ (currentLayout, committedPageTarget, reconcileSettledCrossPage) + AppDelegate.applyPresentationUpdate (4th site per spec).
- entryIdentity correct: ✓ (folder slots `.folder`, app slots `.app` actual app).
- Test (b) full navigator path: ✓ (downArrow seed → arrows → folder identity → Return opens).
- All tests pass: ✓ 785/0. Both builds exit 0: ✓. Frozen tree untouched: ✓.
- No git ops performed. Privacy: no app/folder names in output channels.
