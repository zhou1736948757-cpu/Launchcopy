# Compact Grid Native Repair — 2026-10-14

## Objective and bounded scope

Direct native R3 screenshot shows seven fixed 88pt rows overflowing the grid area in a compact ordinary window. The first icon intersects the search field despite the existing 96pt top gutter. Fit cell height to the available row budget only when necessary. Preserve 5x7 capacity, sufficient-height geometry, order, centering, shared hit/drag geometry, icon identity, and paging physics. Adjustable capacity remains out of scope.

## Baseline evidence

Native candidate: `.build/candidates/native-ui-entry-rc-20261014-r3/LaunchcopyUITest.app`, exact process PID61564 confirmed. Ordinary titled non-topmost window; isolated synthetic72-app catalog, no real executable. Main-owned gates: 74 focused /2439 full tests, Debug/Release,25 headless startup cases,25 metadata cases,404 frozen inputs,221-key3-language package plus2negative resource fixtures. Source reviewer PASS after F1-F4 repairs is source-only. Canonical packaging emitted both sidecars; external destination rejected before mkdir/build. No install/sign/commit or physical performance acceptance.

## Concurrency and acceptance

Main handles native controls and integration. Gibbs exclusively owns `Sources/AppGridUI/AppGridGeometry.swift` and new `Tests/PagingUITests/CompactGridGeometryTests.swift`; no overlapping writes or worker Swift/app execution, max2includingMain. Tests must reproduce compact containment and cover ordinary/search/nonzero origin/empty budget, sufficient-height unchanged. Main owns serial test/build/newcandidate gates and before/after native comparison. Keep all prior candidates and production data intact.

## Current native observations

Direct native test entry works without CLI wrapper. Settings opened, Language choice English applied, localized window/tabs/status visibly updated. Top page badge absent visually. Main grid search/icon overlap is a real native finding, not inferred from XCTest. Further native controls and restart proof pending.

## Next action

Integrate bounded geometry repair, run serial regressions, package unique candidate, and retest native geometry plus search/folders/page dots/settings/restart.

## Final bounded delivery — 2026-10-14

Worker changed exactly the two assigned files. Main reproduced 7 tests/234 assertion failures against exact R3 original geometry bytes, then restored fixed bytes and verified 59 focused/2446 full tests with zero failures. Debug and Release passed. Independent source review PASS is in `Workflow/results/COMPACT_GRID_SOURCE_REVIEW.md`; it does not certify native execution. No Swift migration, paging parameters, capacity, item identity, or production window behavior changed.

Latest unsigned candidate: `.build/candidates/native-ui-entry-rc-20261014-r4/LaunchcopyUITest.app`.

Executable SHA256: `f9298af931aa60365da2407d4216277577a1b15c0d0cc947e6fb9b63a67fe230`.

405 source/test/script/resource/package inputs matched final freeze. Strict packaged localization positive and two new negative fixtures passed. R4 actual resolver-only process accepted isolated/windowed/folderLab options without creating profile storage; only then Main generated 72 new Info-only synthetic app fixtures. No previous candidate preferences/layout were copied.

Native R4 exact executable PID68381 confirmed. Direct Cua opening succeeded. Same-size native screenshot compared to R3: search and first-row icons now separated, all seven rows inside the window, page dots visible below. Wallpaper visible; no decorative page badge. Coordinate click opened Group1 with35 members, Escape closed it. After this real coordinate click activated the window, the existing lifecycle gate enabled dots without code changes: second-page click displayed only Sample71/72, first-page click restored the original grid. Earlier inactive-window disabled dots were expected lifecycle protection, not a proven pager failure.

Search Sample72 showed one result, Escape cleared it and restored page1. Group2 with2 members opened; title edit accepted a draft and Escape restored original Group2; outside-panel click closed the folder without hiding the launcher. Clicking a synthetic missing-executable app displayed localized launch-failure feedback while keeping the launcher visible; subsequent observation showed notice expiration. The temporary banner did not cover search text, but its lower edge briefly overlaid the top of first-row icons; no no-overlap claim is made for transient feedback chrome.

Normal application-menu Quit closed only the R4 test process. Final read-only exact-name process check and input hash check are recorded by Main. No installation/signing/commit, production app close, Spaces mutation, or system preference change. R3 native language/alias/icon settings and real same-candidate restart proof remain valid historical evidence from unchanged related implementation.

## Remaining boundaries and next executable actions

This entry and compact-grid repair are delivered, not full feature parity. Real app-launch success is not demonstrated by Info-only fixtures. No drag, screen-change, forced-fullscreen/notch/Reduce Motion physical gate or trackpad smoothness/120Hz gate is credited. Hidden retained page diagnostic AX text still reports old neutral counts; visual page badge is absent and real page-dot navigation worked. Accessibility diagnostics and transient notice clearance can be reviewed separately. Library and adjustable-capacity contracts remain proposed. The automatic goal was freshly PAUSED; current interactive work used explicit human authorization and did not mutate goal state.

Next: the user can directly open the latest dedicated app without a shell script. Continue confirmed scope from the checkpoint; obtain real-device evidence for outstanding physical/lifecycle gates rather than promoting source/test/native smoke results into them.
