# Review: T-1E-E — AppDelegate integration / refresh / search / launch / blank-click

- **Reviewer**: Independent Reviewer (READ-ONLY; no implementation file modified)
- **Task**: T-1E-E (chef-worker-reviewer-workflow v1.4.1)
- **Spec**: `Workflow/tasks/T-1E-E.md`; **ADR**: `Docs/ADR-008-FOLDER-PRESENTATION.md` (ACCEPTED)
- **Worker result**: `Workflow/results/T-1E-E.md`
- **Review round**: r1
- **Date**: 2026-08-30

## Verdict: PASS

All acceptance criteria verified independently. No BLOCKER, no MAJOR. One MINOR (test-coverage
observation, not a correctness defect). Two documented deviations (synthetic-cell launch path,
test placement) are both sound and justified.

---

## Findings

### BLOCKER
None.

### MAJOR
None.

### MINOR
1. **`testOverlayOutsideClickClosesThenBackgroundClickExits` does not assert the click itself closes
   the folder.** The test verifies the window-level two-stage logic (stage 1: folder open → blank
   click → `terminated == false`; stage 2: after manual `folderOpenState.close()` → blank click →
   `terminated == true`). It does not install a `FolderOverlayView`, so the actual
   `overlay.handleClick → onRequestClose → closeFolder` chain is not exercised in this test. That
   chain is covered by T-1E-C's overlay tests and is correctly wired in
   `AppDelegate.installFolderWiring` (`overlay.onRequestClose = { self?.closeFolder() }`). This is a
   coverage gap, not a correctness defect.

### QUESTION
None blocking. (Noted for completeness: the synthetic member cell's `pageIdentity`/`itemSlot`/
`reuseGeneration`/`iconKey`/`surfaceGeneration` fields are synthetic values; they are irrelevant to
`AppLaunchController.launch(from:)`, which reads only `catalogRevision` and `appID`. No weakening.)

---

## Verification evidence (independently measured)

### Builds (all exit 0)
- `swift build -c debug` → `Build complete!` — **exit 0**
- `swift build -c release` → `Build complete!` — **exit 0**

### Tests
- `swift test` full suite → **`Executed 756 tests, with 0 failures (0 unexpected)`** (XCTest line;
  the swift-testing `0 tests in 0 suites` line is NOT the count). Matches Worker's claim of 756.
- `swift test --filter FolderIntegrationTests` → **`Executed 12 tests, with 0 failures`**.
- 12 new tests present in `Tests/PagingUITests/FolderIntegrationTests.swift` (counted: 12).

### Frozen trees untouched (mtime check)
- `Package.swift` (08-28 20:42), `Sources/PagingPrototypeApp/AppLaunchController.swift` (08-28 21:46),
  `Sources/PagingCore/` (08-30 11:46), `Sources/AppCatalogCore/` (08-28 20:50),
  `Sources/MacAppCatalog/` (08-28 21:01), `Sources/AppIconPipeline/` (08-29 00:22),
  `Sources/PagingTelemetry/` (08-28 21:09), `Sources/PagingUI/` (08-30 15:15) — all predate T-1E-E writes.
- `Sources/AppGridUI/` (read-only this task): **no file newer than 16:44** (latest 16:42 = T-1E-D's
  `FolderKeyboardLogic.swift`).
- `find Sources Tests -newermt "2026-08-30 16:44:00"` → **only the 4 write-scope files**:
  `AppArguments.swift`, `AppCatalogAssembly.swift`, `AppDelegate.swift`,
  `Tests/PagingUITests/FolderIntegrationTests.swift`.
- T-1E-B/C/D files (task + result) all mtime 16:07–16:43, before T-1E-E's 16:49+ writes — **not touched**.
- Prior-task App files (`KeyboardFocusController.swift` 16:42, `AppSearchController.swift` 16:37,
  `FolderTitleEditor.swift` 16:37, `KeyboardLaunchAdapter.swift` 08-29) — **not touched** by T-1E-E.

### Write scope exactly 4 files
`AppArguments.swift`, `AppCatalogAssembly.swift`, `AppDelegate.swift`,
`Tests/PagingUITests/FolderIntegrationTests.swift`. No git operations performed (none observed).

---

## Acceptance-criteria assessment

### 1. Lab flag wiring — PASS
`--folder-lab` → `Options.folderLab: Bool` default `false` (`AppArguments.swift` L100, L132,
L261-262, help L332-333). `AppRuntimeFactory.makeAssembly` wires `FolderLabFixture.makeGroups` as
`folderSnapshotGenerator` only when `options.folderLab` (`AppCatalogAssembly.swift` L280-285).
Product launch does not reorder user apps (`folderLab` off → no folder composition; test
`testFolderLabDefaultOffDoesNotReorder`). Auto tests fully inject a folder snapshot via
`FolderLabFixture.makeGroups` with explicit config — no machine dependency (test
`testFolderLabWiringGeneratesFolderSnapshot`).

### 2. Member launch reuses AppLaunchController — PASS (synthetic-cell deviation SCRUTINIZED)
`AppDelegate.launchMember(_ appID:)` (L545-550) reads `served = assembly.provider.servedRevision`
(the **real current served revision**, not forged) and builds a synthetic cell via
`AppCatalogAssembly.makeMemberLaunchCell(appID:servedRevision:)` (L423-436), then calls
`launchController.handleCell(cell)`.

`handleCell → launch(from:)` (`AppLaunchController.swift` L123-143) runs the **exact** pipeline:
- `guard let token = cell.bindingToken` → present (cell is bound).
- `guard let appID = token.appID as? AppID` → succeeds (param is `AppID`-typed).
- `guard let served = assembly.provider.servedRevision, token.catalogRevision == served` →
  stale-revision check. The synthetic cell's `catalogRevision` = served read at `launchMember` time;
  if a refresh commits in between, the cell's revision ≠ new served → `.rejectedStaleRevision` (safe).
- `guard let url = assembly.bundleURL(for: appID)` → identity re-confirmed in current catalog.
- `guard fileManager.fileExists(atPath: url.path)` → disk re-confirmed.
- `launcher.openApplication(at: url)` → `.launched` / `.failedToLaunch`.

**(a)** Synthetic cell goes through the exact `handleCell → launch(from:)` pipeline — verified.
**(b)** No weakened second launch path — no bypass of stale/identity/file-existence validation; the
only fields `launch(from:)` reads (`catalogRevision`, `appID`) are set correctly; the other synthetic
fields are unused by the pipeline.
**(c)** Folder identities cannot pass — `makeMemberLaunchCell`'s param is `AppID`-typed and the
`as? AppID` cast rejects `FolderID` (test `testFolderIdentityNeverEntersLaunch`).
**(d)** `servedRevision` passed is the real current served revision (`assembly.provider.servedRevision`),
not forged.

**Deviation justification confirmed**: overlay member cells carry `catalogRevision: 0`
(`FolderOverlayView.memberToken` L310, AppGridUI read-only) and would be rejected as stale by the
frozen `AppLaunchController`. The synthetic cell is the correct way to reuse the frozen pipeline
without modifying it. Tests `testMemberLaunchReusesAppLaunchController` and
`testMemberLaunchStaleRevisionRejected` confirm both the success and stale-rejection paths.

### 3. Folder cell never enters app launch — PASS
`ActivationRouter.decide` branches folder → `.openFolder`, app → `.launchApp`, nil → `.reject`
(`FolderDomain.swift` L167-184). The launch path's `as? AppID` cast rejects folder identities
(`AppLaunchController.swift` L131). Tests `testActivationRouterBranchesFolderToOpen`,
`testFolderIdentityNeverEntersLaunch`.

### 4. Search/refresh/folder pending priority — PASS
`AppDelegate.applyPendingAtIdleBoundary()` (L503-517) order:
1. `search?.commitPendingAtIdleBoundary()` (applies pending catalog snapshot + re-runs query on new base),
2. `assembly.rebuildFolderCompositionIfNeeded()` (rebuilds folder composition on the **new base**;
   stages via `provider.receiveFolderSnapshot`),
3. `refreshController.applyPendingAtIdleBoundary(...)` (atomic catalog+folder commit),
4. `keyboardController?.reconcileSettledCrossPage(...)` (focus reconcile).

Matches the fixed baseline (catalog > folder > search). Folder generation is an independent monotonic
token (`FolderGeneration`); the folder layer never mints/forges `CatalogRevision` (provider
`applyPending` sets `servedSnapshot = newBase` from the real catalog; folder snapshot carries no
`CatalogRevision`). Tests `testFolderRebasedOnNewCatalogBase`, `testFolderGenerationIndependentOfCatalogRevision`.

### 5. blank-click two-stage — PASS
`QuitOnBlankClickWindow.sendEvent` (L781-810): on blank `leftMouseDown`, if
`folderOpenStateProvider()?.isOpen == true` → `super.sendEvent(event)` (open layer is an explicit
interaction zone; overlay's `mouseDown → handleClick → onRequestClose → closeFolder` closes the
folder, does not exit); else if search active → exit search; else → `onBlankClick?()` (terminate).
So: folder open → click outside closes folder only; folder closed → next real background click exits.
`endTitleEditing()` is called in `closeFolder()` (L537), which is the single funnel for **all**
folder-close paths (blank-click `onRequestClose`, overlay clear, ESC/Command-F via `onCloseFolder`) —
T-1E-D repair handoff satisfied. Test `testOverlayOutsideClickClosesThenBackgroundClickExits`,
`testBlankClickResolvesToCellClassification`.

### 6. teardown full chain — PASS
`teardownAll()` (L712-751): `surface.teardown()`, profilers flush/stop, `assembly?.teardown()`
(cancel rescan + renderer teardown + icon pipeline shutdown, idempotent), `search?.teardown()`,
`folderOverlay?.teardown()` (zero UI writes) + `removeFromSuperview`, `folderOpenState = nil`,
`folderTitleEditor = nil`, all controllers nil'd, `motionObserver` removed. Test `testTeardownFullChain`.

### 7. Privacy redline — PASS
No folder title/membership/identity raw values or icon data in telemetry/JSONL/stdout/signpost/
profile/report in the write-scope files (grep for `print(`/`record(`/`TelemetryEvent`/`signpost`
near folder/title/member/group → no matches). Only neutral counters and decision enums. No
`PagingTelemetry` schema change (PagingTelemetry frozen, untouched).

### 8. No global NSEvent monitor / Accessibility / Input Monitoring — PASS
Grep for `addGlobalMonitorForEvents`/`addLocalMonitorForEvents`/`AXIsProcessTrusted`/`CGEventTap`/
`InputMonitoring` in write-scope + folder files → only a comment in `AppDelegate.swift` L763 explaining
the window-level `sendEvent` is **not** a global monitor. No actual global monitor installed.

### 9. No Buho/LaunchBetter replication — PASS
No forbidden sources read; no replication logic present. (Reviewer did not read forbidden sources.)

---

## Deviation assessment

### Synthetic-cell launch path (documented, justified) — ACCEPT
Verified above: reuses the exact frozen `AppLaunchController` pipeline with no weakened path. The
overlay's `catalogRevision: 0` member cells make the synthetic cell necessary. Sound.

### Test placement in `Tests/PagingUITests/FolderIntegrationTests.swift` (documented, justified) — ACCEPT
`Tests/PagingPrototypeAppTests` does not exist and `Package.swift` is frozen (Main-only); the only
test target that can import `PagingPrototypeApp` is `Tests/PagingUITests/`. The file is **new**; no
existing PagingUITests file was modified (verified: all other PagingUITests files mtime ≤ 11:53,
before T-1E-E's 16:44 start). The packet's write-scope note explicitly permits this when the
dedicated target is absent and Package.swift is frozen. The forbidden-scope intent (don't modify
other teams' test files) is respected.

---

## Conclusion

**PASS.** The Worker's claims are accurate and independently verified: 756 tests / 0 failures,
debug+release builds exit 0, frozen trees untouched, write scope exactly 4 files, both documented
deviations sound. The synthetic-cell member-launch path is a faithful reuse of the frozen
`AppLaunchController` pipeline with no validation bypass. One MINOR test-coverage observation only.
