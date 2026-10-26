# Main-grid screen-relative proportions: delivery

Date: 2026-10-19
Status: IMPLEMENTED / AUTOMATED_VERIFIED / BOUNDED_NATIVE_OBSERVED / AESTHETIC_AND_PHYSICAL_ACCEPTANCE_PENDING

## What changed
Human requested a modest adjustment to app icon size/arrangement/position relative to the screen, informed by iOS. Main checked public Apple Home Screen and adaptable-layout guidance and audited current independent Swift/AppKit geometry. Current fixed preferred glyph size plus unbounded horizontal cell growth caused a horizontally sparse/vertically compressed relationship. Selected a first-pass128pt maximum MAIN-grid cell width, retaining smaller fits and actual occupied-row centering. This is an independently chosen desktop value, not an Apple/SpringBoard constant. No iOS assets/code/implementation were copied.

Only one production file changed: Sources/AppGridUI/AppGridGeometry.swift, inside frame(for:). Vertical area/row height/spacing algorithm, ordinary envelope/search row policy, saved32–64pt preference/default48, capacity3…8/default5columns7rows, canonical order/storage, paging physics/frame pump, and independent FolderLayoutPolicy are unchanged. Actual glyphs can remain smaller than their preference in dense height-constrained configurations; this revision does not claim to solve that separate caption/vertical fitting issue.

Three test files changed: AppGridGeometryTests.swift (+3 methods), AppGridPageViewTests.swift (adapt two full-width expectations, strengthen exact width/center), CompactGridGeometryTests.swift (adapt two full-width expectations, add full-row center while retaining vertical checks). No other frozen code/package input changed;511 inputs rechecked. All before/patch files retained. No generic rewrite, per-frame work, extra visual effect, icon rebinding/request or preference migration was added by this geometry delta. Actual physical/energy/RSS/hitch improvement is NOT established.

## Verification history
- Focusedr1:30 tests/2failures, old full-row24pt assertions deliberately superseded.
- Focusedr2:30/0 after preserving centering with exact180/128 assertions.
- Fullr1:3101tests/3assertionfailures: two additional compact-width assumptions and one Library2-second readiness wait. No Library source/test/timeout changes. The latter passed in exact focused control and fullr2; its environmental/scheduling cause was not diagnosed.
- Focusedr3:38/0, including adapted CompactGridGeometryTests and the exact Library method.
- Fullr2:3101/0 (199.120s XCTest;205.150s process).
- Debug build, actual Release executable build and native-entry package validation passed. Packaged361localizationkeys/signatures x3languages passed.
- Selected code diff whitespace check passed. Existing unrelated warnings retained, not zero-warning claim.
- James independently SOURCE ACCEPTed stable production+two-test delta; Ptolemy independently accepted the later compact-test arithmetic. Neither ran UI/tests or issued a runtime/performance PASS; both completed and closed.

## Candidate
Unsigned/uninstalled: `.build/candidates/main-grid-proportions-rc-20261019-r1/LaunchcopyUITest.app`
Executable SHA-256: `75ba53448ecabea1ef3ae97bfe4411b988dda20ac039082ecfa3e3941e050269`.
New isolatedgui profile seeded only87whitelisted previously authored own fixture files, inert executables, marker, layout and capacity; no appearance/Library/activity/cache/lock import or formal data. Appearance was subsequently set via nativeUI to28blur/54icon/12font/namesON for comparison, not by changing production defaults or old saved preferences. Old profile86JSON/plist payloads remain byte-identical.

## Actual native observations
Exact PID40324, normal Finder Open, ordinary non-topmost1000 x700pt window: six-column/five-row grid centered; folder glyph at its new location opened the independent35-member folder (15visible/page1of3); Escape closed it; a single controlled search result remained centered. Full result names are still exposed in AX while visible long names truncate earlier. Those placeholders are controlled test content, not real-app visual fidelity evidence.

AX Settings activation worked. Search editing kept capacity presentation queued as designed; after normal Quit/exactabsence/Finder Open, exact PID42772 visibly displayed saved5 x7 and retained28/54/12. Original6 x5 was restored through native Appearance controls, settings closed/query cleared, final normal Quit and exact process absence verified. Saved6 x5 and unchanged canonical layout confirmed on disk; final6 x5 reopen was NOT run. No test instance remains running.

Native menu observation temporarily remained menu-only after Escape; exposed Cancel secondary action cleared it. Coordinate gear attempts did not establish activation; explicit AX Settings control did. These observations are not relabeled proven product bugs or activation PASS for every full-cell point. Initial wallpaper wasloading and laterready without a wallpaper or source change; prior intermittent cause remains unresolved, not repaired here.

## Remaining limits and next action
Current native coverage is bounded, not whole-product/human acceptance. Actual wide/compact viewport rendering, drag/drop under narrowed targets, first-frame folder-source animation, physical two-finger paging/matched performance and human aesthetic acceptance remain unclaimed. Existing geometry/frame ownership tests plus source review are narrower. Next inspect the candidate visually with representative real icons and long names, and adjust this isolated constant only if needed; do not change row/column preferences or folders to hide a proportion issue. Do not call it a literal iOS clone or claim a universal screen percentage.

Design contract: Docs/MAIN_GRID_PROPORTION_PROPOSAL.md. Independently authored schematic and all receipts/logs: `.build/verification/20261019/main-grid-proportions/`. The full LaunchBetter-on-Launchcopy goal remains incomplete; no signing/install/publish/commit/reset/clean/security/system wallpaper change or real-app removal occurred in this stage.
