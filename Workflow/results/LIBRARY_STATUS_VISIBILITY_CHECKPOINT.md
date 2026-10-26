# Library/grid status visibility checkpoint — 2026-10-15

## Status and root cause
Full independent LaunchBetter-experience parity remains ACTIVE/incomplete. Previous turn repaired category count visibility and validated folder editing/restart. This continuation repaired the observed persistent central Apps Ready badge after Library Back.

Two presentation owners conflicted: Library's setGridHidden(false) unconditionally exposed the grid status, while its own renderer intentionally hides Ready. Equal semantic updates do not rerender, so the badge could remain visible indefinitely. Conversely a queued non-ready render could remove Library's external hide and expose status in the wrong mode. Reading pending state would also risk showing old Ready text before the pending error is rendered.

## Bounded implementation
Only production `Sources/PagingPrototypeApp/AppDelegate.swift` changed. A private latch captures semantic visibility immediately after each completed status render, before applying the Library mask. A private constant-size projection combines that committed result with current Library.isOpen and sets visual/AX exposure consistently. Existing render/refresh/mode callbacks reuse it; install/teardown reset the latch and retained old completion closures require exact current-view identity.

No public API, status-view implementation, view hierarchy, text resource, timer/observer, catalog/projection/icon work or frame/gesture/physics change. AppGridStatusView remains Library-independent and its renderedState remains private. Main and reviewer independently reversed the bounded AppDelegate edit in memory to recover the exact prior SHA. Current451 inputs: only AppDelegate and new `Tests/PagingUITests/LibraryCatalogStatusVisibilityTests.swift` changed/new; all18 PagingCore/UI and all other baseline inputs match.

## Execution and review evidence
- Actual composition RED:5 XCTest/19 assertion failures; legitimate loading/empty/no-results restoration already passed before correction.
- Initial focused39/0, then final focused40/0,3.060s with6 new regressions. Covers repeated/equal Ready Back, all queued renderer states under Library, actual mounted loading/empty/committed no-results restoration, pending state versus rendered text, replacement/late completion/teardown, and immediate committed busy/error restoration.
- Busy/error injection is deliberately a renderer/mode seam check before later real-provider resolution, not real scanner-failure delivery. Reported-visible admission window is unshown, not GUI proof.
- Full2651/0,53.080s; Debug success; Release/package success. Strict packaged288-key/3-language positive probe exit0, missing static key and invalid signature negatives exit1. All451 current hashes verified after native work; diffcheck passed.
- Independent bounded SOURCE PASS: `Workflow/results/LIBRARY_STATUS_VISIBILITY_SOURCE_REVIEW.md`. Reviewer0tests/build/UI; independently verified449 non-asset frozen inputs and exact AppDelegate delta; did not read the two image assets. Main separately verified all451 hashes. Reviewer closed, all jobs terminal.

Non-blocking test coverage follow-up: the retained-old-callback test invokes it while both old and replacement views are hidden, so its assertion does not independently detect a corrupted latch. The identity guard is correct by source inspection. Future strengthening should invoke old completion after Back has exposed a committed non-ready replacement and assert it stays visible/AX-exposed. Combined locale-rerender under Library is covered by shared source callback reasoning and existing language tests, not a new explicit combined test. These limitations are not omitted from the acceptance claim.

## Current candidate
Unsigned/uninstalled:
`/Users/mac/Projects/Launch_Copy/PagingPrototype/.build/candidates/library-status-visibility-rc-20261015-r1/LaunchcopyUITest.app`
Executable SHA-256: `42bc2e9d491560c9e29966798403d4d3fa043e2d8fbec9829749a6d360d932d7`.
Candidate-local GUI profile and forty owned Info-only bundles; not executable-app launch evidence or formal user data.

## Actual native verification
1. Initial Apps Loading text observed, then populated grid without Ready badge. Enabled default-off optional Library via acknowledged normal settings save.
2. Library All40 -> Back: actual full AX tree has no Apps Ready text; inspected screenshot has populated grid and no central panel. A second Ready cycle also passed.
3. Background AX field focus/paste initially did not insert. Actual observed coordinate focus/typeText inserted synthetic unmatched query; legitimate no-results text appeared. No typing success is credited to the ignored attempt.
4. Enter Library -> independent empty query/All40 and no grid no-results text. Back restores exact main query and no-results status. Native Cancel clears query -> grid returns with neither no-results nor Ready overlay. Thus the repair does not simply hide all status permanently.
5. Wallpaper initially loading/black, later ready and visibly composited in final screenshot. This is not its delay-cause repair or a physical performance result. One screenshot timed out; same target retry succeeded without restarting the app.
6. Own exact PID30718; final normal menuQuit -> exact executable query returned absent. No native query after finalQuit and no test app left running. No new restart gate claimed in this slice.

Evidence: `.build/verification/20261015/library-status-visibility/` contains red/focused/full/debug/release/probe logs and results,451-input freeze/delta proof, synthetic fixture manifest, native-results.json and exact process records. Native images/AX are inline tool observations, not saved raw screenshot artifacts.

## Next original parity gate
Continue exact-candidate appearance acceptance: approved show-labels, icon32–64pt, font9–16pt and blur0–60 Apply/restore/reopen/real-process persistence in the isolated normal window. Keep5x7/physics/capacity fixed; do not add unapproved layout controls. No source change needed unless a reproduced existing-contract defect appears. Retain the non-blocking callback/locale combined-coverage follow-up.

Real IME/Tab/VoiceOver, native scanner failure/error dialogs, broader management/source lifecycle, matched physical60Hz comparison, unresolved >25ms causality,120Hz/multidisplay/powerloss and pending capacity/usage/destructive/extra-gesture decisions remain separate. No formal data/app, copied reference source/assets, installation/signing/publication/commit/push/reset/cleanup/processkill, OS-setting/Space change or unrelated-app control. Current work is verified progress, not full goal completion.

## 2026-10-16 — Named test limitations closed (historical conclusions preserved)

New stronger oldcallback testcase runs afterBackexposesnonreadyreplacement; separatelycopied identity-guardmutant compiled thenfails1test/2visibilityAXassertions. NewactualSettingsApply/queuedlocale/Librarymask/Backqueryrestore integrationcasepasses. Canonicalfocused8/0/full2748/0; only existingtestfilechanged/allproductinputsunchanged, current99408d28candidateunchanged. Plato boundedTEST_DISCRIMINATION_EVIDENCEPASS/460+460hashes/0executions. See LIBRARY_STATUS_FOLLOWUPS_RESULTS.md. Both formerlynotedtestcoveragegapsclosed; notnewnative/physical/human/fullgoalPASS and notnewproductionrepair. Do notrepeattheseexactfollowupstokeepgoalactive.
