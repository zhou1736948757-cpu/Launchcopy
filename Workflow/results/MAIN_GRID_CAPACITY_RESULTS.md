# Main Grid Capacity — Implementation and Bounded Native Results

Date: 2026-10-17
Status: IMPLEMENTED; AUTOMATED/BUILD/SOURCE-REVIEW GATES PASSED; BOUNDED NATIVE CHECKS OBSERVED. Human acceptance and whole-product parity remain open.

## Authority and approved contract
The human approved independent 3–8 column and row controls (default 5 columns × 7 rows), independent adaptive folders, unchanged paging feel/order, and safe-boundary application. The human separately approved a small-window notice rather than forced resize, silently reduced capacity, or unreadable squeezed cells. `Docs/MAIN_GRID_CAPACITY_SPEC.md` is the source of truth. Earlier pending-capacity/BLOCKED snapshots are history, not the current authority.

## Delivered behavior and maintenance boundaries
- Separate retained Grid settings tab, localized English/Simplified Chinese/Japanese, bounded menus, explicit scoped Apply and Defaults. Defaults edits only the draft; closing discards unaccepted changes. Relabeling does not destroy the draft.
- Immutable validated shape and pure stable-identity anchor relocation. Canonical order/catalog revision/query remain separate from per-page capacity. Deferred keyboard focus is not manufactured.
- Versioned dedicated `MainGridCapacity/capacity.json`, bounded reads, corrupt recovery only after explicit Apply, future/ambiguous schema protection, atomic expected-byte write receipts. No global preference fallback on unresolved isolated profile.
- MainActor write coordinator serializes accepted immutable writes, reports actual persistence outcomes, and participates in existing bounded Quit drain/default-Cancel failure protection. Admission is not a Saved receipt.
- One admitted idle owner transaction fans out shape to provider, refresh/search/surface/renderer, keyboard, dots and bindings. Folder, Library, active input/IME, drag, gestures/settle and lifecycle operations defer presentation; deferred work uses existing safe wakeups, not frame-loop storage.
- Small-window policy checks ordinary and every possible occupied search-row geometry. Hidden main content loses main input/menu admission while search/settings and readable live folder controls remain independently valid. Enlarging restores the chosen shape, never an implicit substitute.
- Source-origin/epoch/current-page validation rejects stale retained menus without blocking the established cancel-and-revalidate menu path during settle.

## Native-discovered defect and repair
The first candidate **did not pass**: 3×3 on page2 → 8×8/one page left a persistent quarter-page offset. A real-owner regression reproduced presentedOffset0.25 and page origin−300pt (**1 method/2 failed assertions**). Existing Core page-count clamping retains soft edge overscroll; this is not a reason to change gesture physics. After an already-admitted idle reload, owner calls the existing Surface.cancel only if presented offset differs from the clamped committed page, before requesting a new anchor. The new test checks real page origin. R2 repeated the original native sequence and stayed aligned. Historical r1 FAIL and every intermediate raw log remain preserved.

## Verified executions
| Gate | Actual evidence |
| --- | --- |
| Broadened focused XCTest | 133 tests, 0 failures, 3.954s; `integrated-focused-r9.log` |
| Full XCTest | **2900 tests, 0 failures**, 67.785s; `full-r4.log` |
| Debug product | PASS, 0.37s; `debug-r2.log` |
| Actual Release product/package | PASS, 18.55s Release; `package-r3.log` |
| Packaged localization | 309 required keys/signatures ×3 languages; packaged resources only |
| Independent source review | Foundation Newton R2 SOURCE PASS; settings Pascal SOURCE PASS; owner Jason R3 plus bounded R4 SOURCE PASS |
| Input stability after native | All482 frozen inputs match;20 existing changed +15 added, zero removed; PagingCore unchanged |

All raw logs are under `.build/verification/20261017/main-grid-capacity/`. XCTest's separate empty Swift Testing footer is not used as evidence; the actual XCTest totals above are nonzero. Reviews are bounded source evidence, not independent live/native/physical acceptance. All workers/reviewers and test/build jobs are terminal.

## Bounded native matrix — current r2
Only authored isolated data were used:80 Info-only fake app bundles with no executable,46 outer entries,35-member folder. Placeholders are intentional fixture icons, not launchable applications or a real-app launch gate.

| Case | Observed result |
| --- | --- |
| 3×3 endpoint and navigation | Nine visible cells, six pages; actual pointer page2 jump |
| Folder independence | 15 members/page, three pages, one Escape closes folder |
| Exact r1 shrink counterexample | Page2/3×3 → 8×8/one page stays aligned |
| Small viewport | 2000×1400px→2000×1000px: notice instead of squeezed grid; search/settings remain; enlargement restores unchanged8×8 |
| Three languages | Grid controls/help/footer and all seven tabs fit; dirty3×8 draft survives EN/JA relabel; restored Follow System app language |
| Discard draft | Closing/reopening without Grid Apply returns saved8×8/64 |
| Same-candidate normal restart | Normal menu Quit PID10117; exact process absence recorded; same r2 reopened and settings visibly8×8/64 |
| Scoped Defaults |5×7/35 draft while disk still8×8; explicit Apply records5×7 and native two-page layout |

Final state: current r2 running PID14086, ordinary non-topmost main window, default5×7, page1/2, query empty, folder/settings closed. No fullscreen/Space switch. Layout and Library payload hashes remained unchanged across capacity/language/resize/restart testing. No screenshots were saved.

## Candidate and structured receipt
Candidate: `/Users/mac/Projects/Launch_Copy/PagingPrototype/.build/candidates/main-grid-capacity-rc-20261017-r2/LaunchcopyUITest.app`
Executable SHA-256: `adbd845caf32d0dd44f01d36cfbcde59f2c66d35b42e4630746a3044816c6cfc`
Unsigned, not notarized, not installed, no existing app overwritten. Private MultitouchSupport distribution implications remain noted by packaging.

`native-handover-r2.json` records process/input/profile hashes and native distinctions; `native-r2-normal-quit.json` records exact absence after normal Quit. Both are under the verification directory. Packaging-time `candidate-r2.json` launched:false is historical and superseded by the actual native receipt, not silently rewritten.

## Remaining risks and honest boundaries
- The existing wallpaper is still loading/black in current native observations: **NOT_FIXED**, cause unresolved. Proposed OS A/B/A control remains unapproved.
- Physical >25ms long-tail causality remains unresolved. Approved Timer.tolerance0ms short-tail evidence does not prove a complete latency repair.
- A synthetic640-record census observed7 live pages/448 slots and576 icon-request calls during reconfiguration (~0.108–0.122s including async receipt wait).448 is **not** a transaction request bound; no global queue/RSS/physical frame/energy claim follows.
-120Hz, multidisplay, real IME composition, spoken VoiceOver and offscreen prewarmed-page accessibility remain separate gates. Existing AX exposure of prewarmed pages is not certified here; hidden-small-grid AX removal was observed.
- New capacity controls await human experience/acceptance. Separate optional Library, no-history baseline and other approved features retain their own scopes. Leftmost-page Library, usage history, destructive uninstall/extra gestures and OS wallpaper experiment need their own decisions.
- The full LaunchBetter-on-Launchcopy objective is **incomplete**. Goal tool previously remained BLOCKED despite this new human authority; API has no agent resume operation. No manufactured status or old three-turn audit count is used.

## Changed implementation/test inputs
This list is relative to the pre-stage467-input snapshot, not the repository's much broader existing dirty diff.

### Modified (20)
- `Sources/AppGridUI/AppGridGeometry.swift`
- `Sources/AppGridUI/AppGridPageView.swift`
- `Sources/LauncherLocalization/LocalizationResources.swift`
- `Sources/LauncherLocalization/LocalizedStrings.swift`
- `Sources/LauncherLocalization/Resources/en.lproj/Localizable.strings`
- `Sources/LauncherLocalization/Resources/ja.lproj/Localizable.strings`
- `Sources/LauncherLocalization/Resources/zh-Hans.lproj/Localizable.strings`
- `Sources/LocalizationResourceProbe/main.swift`
- `Sources/PagingPrototypeApp/ActivationSettingsWindowController.swift`
- `Sources/PagingPrototypeApp/AppCatalogAssembly.swift`
- `Sources/PagingPrototypeApp/AppContextMenuController.swift`
- `Sources/PagingPrototypeApp/AppDelegate.swift`
- `Sources/PagingPrototypeApp/AppFolderAssignmentMenuController.swift`
- `Sources/PagingPrototypeApp/AppSearchController.swift`
- `Sources/PagingPrototypeApp/KeyboardFocusController.swift`
- `Tests/LauncherLocalizationTests/LocalizationResourceValidationTests.swift`
- `Tests/PagingUITests/AppearancePreferencesTests.swift`
- `Tests/PagingUITests/FolderAssignmentAssemblyTests.swift`
- `Tests/PagingUITests/LanguageRuntimeIntegrationTests.swift`
- `Tests/PagingUITests/MenuMutationLifecycleTests.swift`

### Added (15)
- `Sources/AppGridUI/MainGridCapacity.swift`
- `Sources/AppGridUI/MainGridReadability.swift`
- `Sources/LauncherLocalization/MainGridCapacityTextKey.swift`
- `Sources/PagingPrototypeApp/MainGridCapacityCoordinator.swift`
- `Sources/PagingPrototypeApp/MainGridCapacitySettingsView.swift`
- `Sources/PagingPrototypeApp/MainGridCapacityStore.swift`
- `Tests/AppGridUITests/MainGridCapacityTests.swift`
- `Tests/AppGridUITests/MainGridPageMetricsTests.swift`
- `Tests/AppGridUITests/MainGridReadabilityTests.swift`
- `Tests/LauncherLocalizationTests/MainGridCapacityLocalizedStringsTests.swift`
- `Tests/PagingUITests/MainGridCapacityCoordinatorTests.swift`
- `Tests/PagingUITests/MainGridCapacityIntegrationTests.swift`
- `Tests/PagingUITests/MainGridCapacitySettingsViewTests.swift`
- `Tests/PagingUITests/MainGridCapacityStoreTests.swift`
- `Tests/PagingUITests/MainGridRendererMetricsTests.swift`

## Safety and next action
No reference code/assets were read/copied, no OS/formal-data/security changes, no signals/kill, installation/signing/publication or Git cleanup/commit. User waived Chief ceremony; Main integrated disjoint work with maximum3 agents including Main and serialized builds. Historical FAIL/repaired-fixture evidence is retained in stage/review/raw logs.

Next: human can open Settings → Grid, try3×3/8×8, shrink/enlarge the ordinary window, and compare folder paging. Do not call the complete product or physical gates accepted from this bounded delivery. Continue only within confirmed product branches or a concrete observed maintenance defect.
