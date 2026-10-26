# Catalog status footer — 2026-10-25

## Objective, baseline and confirmed evidence
Remove the observed lower-right catalog-warning/caption overlap without changing grid geometry, paging or warning semantics. Current owned FolderNamesR2 preview was last confirmed PID51878 / SHA4d6e9ccb…; previous full3762/0 is only the inherited baseline. The previous goal turn was concrete progress (folder naming, severity and native handover), not completion.

## Specification and ownership
`Docs/CATALOG_STATUS_FOOTER_LAYOUT_2026-10-25.md`. Main implements the tightly coupled view/composition/resolver and tests serially. Independent bounded read-only review after a stable freeze; at most three active including Main. No old workflow/watchdog or speculative source/gesture changes. Preserve existing dirty work and the current human profile.

## Next action and gates
Reproduce the installed-owner overlap with actual page cells, then implement compact passive footer presentation and safe dot exclusion. New tests/build/review/native gates pending. No new code repair or physical acceptance claimed at stage start.

## Reproduction and first integration
`before-r1.log` executes1test/3assertionfailures through the actual installed owner: the54pt status intersects two bottom-row cells. Footer style/resolver and view integration then pass focusedR1 **41/0**. No grid/page-dot frame or input behavior changed.

Added broader finite-origin/capacity/locale/tooltip/AX/passive-control tests. The unchanged320pt dotstrip can exhaust footer space in very narrow windows, so explicitly amended the specification with a fallback only inside the existing grid-to-search/settings header gap; no extra rows/insets/controlmovement. In insufficient text space the caution glyph retains the full message via parentAX/tooltip. Final tests/freeze/review follow.

## Test-only compile correction
FocusedR2 did not execute: new geometry tests used the wrong capacity initializer argument order/failable handling and ambiguous `.infinity`. Corrected tests with the existing failable API via XCTUnwrap and explicit CGFloat.infinity; no production access or contract was weakened. Retain compile log, do not count it as red/PASS.

## Stable integration
FocusedR3 executes43/0 after the test-only compile correction. Added one explicit calling-stack formatting/coalescing regression before final focused verification. Frozen610inputs/sixdeltas: two existingproductionfiles, one newresolver, one existingownertest and two newtestfiles. Existing grid, dots, resources, catalog severity, folder naming and paging sources remain unchanged. Independent read-only reviewer next; Main alone executes the serial final tests/build/native work.

## Final focused verification
FocusedR4 **48/0**,3.014s, including the explicit no-format-on-calling-stack and equal-style coalescing checks. All610inputs remain byte-exact. FullR1 now running serially while Hypatia independently reviews source only. No native replacement yet; user profile and previous51878candidate remain authoritative.

## Full verification
FullR1 **3770/0**,72.090s, on unchanged610inputfreeze. Finalfocus48/0. Debug/Release/strict package running serially into a unique same-profile StatusFooter sibling, with both old top-level manifests preserved/restored. Source review and actual native replacement still pending. No user data or old process change yet.

## Strict artifact ready
Debug/actualRelease/strict package and standalone resource smoke pass,369keys×3languages/1107entries. Unique StatusFooter artifact SHA32bdb0c0ab83df226d5556859ac87761bbfe4b63e125618ace920cca7c7ece40 is not yet launched. Original canonical/resource manifests restored; new sidecars separate. Old51878 remains running and reachable; latest neutral report retained (only3native menu-related counterstages, no drag), report-time layout writable/no title/folder/search/transition. Five-file profile hash/mode baseline captured. Source610inputs still byte-exact; independent Hypatia review pending before native swap.

## Independent review correction — metric commits
Hypatia r1 SOURCE FAIL found a real stale-geometry integration defect after capacity/appearance commits. Added two actual-owner regressions before repair: equal-product 8×3→3×8 and appearance-only48→96 at5×5, both without root resize or manual status-layout calls after the change. `metric-before-r1.log` executes2tests/6assertionfailures, reproducing both stale frames and two cell intersections per case. Main then added geometry-only `layoutCatalogStatus()` immediately after `layoutPageDots()` in both admitted metric commits. No semantic/status formatting, source refresh or paging retune. Tests also retain state/query/revision/format counts and containment/dot exclusion. The specification explicitly records the required invalidation order. R1 candidate remains unlaunched; new610input/sixdeltaR2 freeze, focused/full/build/package and renewed independent review are required. Old51878preview and latest human profile remain untouched.

## R2 verification and native preflight
FocusedR5/R6 each47/0 are valid narrower runs; finalR7 uses the exact original status/Library/language consumers plus capacity/metrics owners and executes72/0(5.100s). FullR2 runs serially on unchanged610inputR2 freeze. Hypatia independently re-reviews F1/source while Main executes, no overlapping writer/test jobs. CUA preflight now returns Mac locked; no normalQuit/newlaunch or UI workaround attempted. Existing51878 process remains authoritative. Native handover cannot be inferred from tests.

## Final R2 artifact — source re-review/native pending
FullR2 **3772/0**,73.191s; focusedR7 **72/0**,5.100s; Debug0.34s, actualRelease21.75s and strict entry/package pass. Same369keys×3language packaged resource probe passes. The separate smoke wrapper first received an .app instead of its documented .bundle argument and failed (`standalone-resources-r2.log`); this is not a resource/product failure and not counted PASS. The corrected exact packaged .bundle-only invocation passes1107entries (`standalone-resources-r3.log`), no code changes or rebuild. Retain both logs.

Unique unsigned candidate `LaunchcopyPreviewStatusFooterR2.app` in the existing integrated-preview parent, SHA `be5b968dba5abb79c8eada20586b98950f24e96822b03fd010d8f7838ba199ef`. R1 artifact remains never-launched; top-level canonical manifests restored byte/mode-exact and new R2 sidecars separate. All610 R2 inputs still byte-exact. Pre-nativeR2 receipt saved. Hypatia re-review pending. CUA preflight LOCKED; existing51878/4d6e9ccb… process verified, five latest profile files/modes unchanged. No old Quit, new launch, native layout PASS, real-app mutation or saved screenshot. User asked once asynchronously for manual unlock. Next: consume bounded source conclusion, then native replacement only after unlock; no forced exit, data rollback or duplicate instance.

## Final bounded source review / native handover held
Hypatia R2 **SOURCE PASS**, F1closed, no new actionable findings, report `Workflow/reviews/CATALOG_STATUS_FOOTER-r2.md`. Reviewer independently matched607non-asset source/script inputs and the six-path delta; three resource digests remained inherited and were not independently opened/hashed. Main verified all610 inputs unchanged, plus strict packaged-resource gates. No reviewer execution/native/physical/fullparity acceptance is implied. Reviewer closed; all serial jobs completed.

Final CUA recheck still LOCKED. No old normalQuit/newlaunch, profile mutation, forced exit or workaround attempted. Current running preview remains51878/4d6e9ccb… FolderNamesR2. Allfive latest profile files/hash/modes and both canonical manifests remain unchanged; R2be5b968d… candidate remains never-launched. `pre-native-r2.json` and `handover-blocked-r2.json` record the current source/artifact/native separation. Do not create a final-native-ready receipt until actual new-process/wallpaper/footer checks. User already asked once for manual unlock; no repeated question. Next: after unlock, refresh old PID/path/hash and neutral report, normal ownedQuit, exactabsence/currentprofile preservation, uniqueR2launch/identity/wallpaper/status-caption/dot visual check and leave diagnosticsready. Source-warning cause, naming human acceptance, physical pointer causality and wholeparity remainunproved. This turn made concrete repair/verification progress; goal staysactive, not complete or a repeated-impasse declaration.

## Native combined-candidate supersession —2026-10-25
Userunlockresolvedthehandovergate. CombinedPointerRelease8335c19b… nowruns91801; normalold51878Quit/exactabsence andfivecurrentprofilehashes/modespreserved. Transient2000×1400pixelmain/wallpaperREADYscreenshot shows warningbelowbottomcaptionsandbesidedots, nooverlap atthiswindow. Fullwarningstillvisible; exactdiscoverycause/otherwindows/VoiceOver/performance unproved. No sourcechange or freshindependentreview. This supersedes the current-native-pending status only; oldFooterR1/R2 artifacts remainnever-launched. Finalnative receipt inpointer-release-ownership/final-native-ready-r1.json.
