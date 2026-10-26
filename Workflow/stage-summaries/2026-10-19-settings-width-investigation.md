# Settings width: bounded unshown reproduction

## Problem and scope
Main's native EN/JA Appearance screenshots show an unexpectedly wide retained Settings window. Its constructor requests500×560pt. Read-only Plato review found that full custom source paths enter NSPopUpButton menu titles, but this does not prove window expansion. Investigate without changing product behavior or blaming Sources speculatively.

## Contract and acceptance
Preserve original preferences, full source path identity/accessibility, all tabs and localized strings. Add unshown AppKit tests with in-memory drafts/synthetic paths only; no showSettings/orderFront/activation, disk fixtures or catalog scans. Measure initial window/page/popup size, short then long root menu while placeholder selected, then return Appearance. Compare widths to actual initial baseline; report constructor baseline separately. Long-path causality requires actual width growth, not just intrinsic growth.

## Implementation and verification
Main owns one new test file; serial SwiftPM execution. No production patch unless evidence establishes a defect and proportionate repair. Existing516inputs must remain unchanged; new test input is separate. Inspect focused execution and exact counts. A green unshown test is not compact native window acceptance.

## Review and remaining gates
Plato read-only recommendation completed and agent closed; no independent test/result review yet. Keep full goal active. Next executable action: measure real retained-controller layout under English/Japanese/Chinese with synthetic long paths.

## RED reproduction and bounded repair contract
Focused1test executed with3failures: each English/Japanese/Chinese short path retained500pt; a long unselected synthetic menu title expanded Sources content to2798pt with popup intrinsic2730pt. This proves a source-title-driven width failure in the unshown fixture. Returning Appearance did not fail in this fixture, so native retained-width causality is not fully proved.

Approved routine defect repair scope: only Sources popup horizontal fitting/compression and display truncation; retain complete menu titles, represented path identities, accessibility and full-path discoverability. No hardcoded global maximum, window resetting, path abbreviation/storage change or layout/paging change. Extend test to selected long path and return tabs without manual resets. Freeze new integrated inputs; focused then full serial tests; package only after stable reviews. Mainownsproducttest; independentTuringreadonlyreview inparallel, no sharedtestexecution.

## Focused repair evidence
Five production lines set Sources popup horizontal compression resistance to defaultLow and closed-cell middle truncation. No menu title/path identity is shortened. Originalr1onlymeasuredtabscontent, NOTwindowframe: its500→2798claim is contentgrowth, not proofthatnativewindowframechanged. r2originaltest1/0; independentTuringcoveragefeedback prompted actualframe/contentRect assertions, selected-long-title checks and complete menu accessibility labels. Finalr3focused56/0, with frame/contentRect/tabs500 inEnglish/Japanese/Chinese for short/long and selected/unselected titles, intrinsic2730whilepopup432. ReturningAppearancealsostable; no windowreset.

Frozen517inputs r2 contain onlythe5lineSourcesrepair and newtest beyond earlier516baseline; no shared physics/icon changes. Fullsuite,Debug,ReleaseandnewuniqueSourcesverificationpackage are runningserially in Mainsession59711. Unchanged visualdc4ed/PID17189 remains open forhuman; it doesnotcontainthisSourcespopuprepair.

## Final verification, review and native follow-up
Focused56/0; full3139/0; Debug, actualRelease and unique package all passed serially against517frozeninputs. Packaged365keys×3languages verified. Turing boundedSOURCE/TESTACCEPT, no blocker; limitations preserved in result/review. Main verified exact five-line delta and all final input hashes.

Fresh candidate de3b27a6… was seeded with only2newmetadata-onlyapps. Main normallyQuit visual17189, Finderopened own26988; SourceschooseraddedownExtrasONLYtodraft. Fullmenu/AXpathaccessible; longselectedclosedpopupfitcompactSources (inline1000px screenshot). Appearancealsocompactwithoutresize; returningSourcesretainedlongselection. No Apply orappearanceedit. New metadataunchanged. MainnormallyQuit26988/exactabsence; restored unchangeddc4edvisualPID29854 ordinary/queryempty/folderclosed/wallpaperREADY. This visualdemo DOESNOTcontainSourcewidthfix. MainupdatedCURRENTindex/plan/memory. FullgoalACTIVE/incomplete; nextunmatchedinteraction/accessibilitygatespercurrentmatrix.
