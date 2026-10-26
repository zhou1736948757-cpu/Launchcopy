# Spacious main-grid icons: correction in progress

Date: 2026-10-19
Status: implementation, frozen tests/builds/package and bounded native checks delivered; human aesthetic acceptance pending.

## Human correction and implementation
The human rejected the previous narrow128pt column cap because icons still looked too small and clustered. That candidate is superseded, not an accepted baseline for this new layout. The current correction restores available-width columns and gives main-page icons an independent32–96pt preference, clean-profile/default80pt. Base/folder appearance stays32–64pt/default48pt. Existing schema1/2 saved values retain their point meaning through a nil inherited main override; loads do not write. Explicit new saves use schema3 and future4 is protected.

Main cells use a shared larger vertical budget and centered bounded glyph/caption stack. Renderer, readability, page-dot geometry, settings fit estimate, drag preview and folder source conversion use the actual layout. No paging physics, icon pipeline/cache or folder inner-layout policy changes. Four new translated keys bring exact resource inventory to365. See `Docs/MAIN_GRID_SPACIOUS_ICON_SPEC.md`.

## Independent review
Pascal production SOURCE ACCEPT after a reproduced P2 and repair: candidate fit must reflect the selected capacity draft rather than an old committed capacity while presentation is deferred. RED1test/3assertions retained; projection-only draft observer/provider repair tested. This is source acceptance, not physical/visual acceptance. A separate final test-contract review is pending.

## Verification chronology (retained)
- Focusedr1 compile failure: stored initializer `Self.previewSize`; corrected to concrete type.
- Focusedr2:166tests/5failures from old combined appearance, readiness boundary and renamed-caption expectations.
- P2 RED:1test/3failedassertions.
- Focusedr3:167tests/2old-fixture/default assumptions; focusedr4:167/0 before final tiny teardown-guard movement.
- Fullr1:3130tests/25assertionfailures. Serial runner stopped before builds/package. Failures include old schema/key/caption contracts, two changed readability boundaries, a pre-existing generation-readiness wait issue and one0.4sec runloop settle miss. No product frame source/physics change was made to hide the latter.
- Unfrozen bounded compatibility run:10/0; only diagnostic because a test-contract worker could edit concurrently. It is not final frozen evidence.
- Finalr2 freezes514source/test/package inputs, verifies hashes before/after serial focused/full/Debug/actualRelease/package jobs. Results below will be filled only from terminal receipts.

Generation readiness test repair preserves the2sec deadline, record/revision and all original failure/status/consumer checks; it waits on a current-generation usable request, then synchronously pins and verifies a valid request before source invalidation and stale rejection. Independent review accepted this semantic correction. It does not establish the historical timeout cause. Two protection fixtures use700x550 rather than700x600: improved padding now admits the latter at8x8, so the new fixture still distinguishes readable5x7 from protected8x8 without changing product thresholds.

## Delivery and limits
New intended candidate: `.build/candidates/main-grid-spacious-icons-rc-20261019-r1/LaunchcopyUITest.app`, not yet built at this checkpoint. Unsigned/uninstalled ordinary isolated-window test profile only; no formal preference, real-app or reference-resource writes. Main-size legacy values are not silently overridden. New authored numbered color icons will be diagnostic fixtures only, not evidence of real-app imagery fidelity. Physical paging/performance, original long-tail cause,120Hz/multidisplay, realIME/VoiceOver and human aesthetic acceptance remain separate.

## Frozen r2 tests (terminal)
- focusedr5:62tests/0failures; fullr2:3131tests/0failures. Full elapsed94.019sec; XCTest90.360sec. The unchanged runloop test passed in both frozen focused/full runs; no historical fullr1 timing cause claimed.
- Debug build:exit0. Actual Release and fresh packaging still in progress at this checkpoint.
- Einstein independently accepted the final five test-contract adaptations with all514frozen hashes matching; no findings or test weakening identified.


## Packaging boundary failure and exact repair
Actual Release r2 passed, but package r2 exit1 correctly rejected365 resource keys against stale361 developer-probe inventory. This is a delivery verifier-contract miss, not app runtime evidence. Incomplete candidate r1 retained and never launched/seeded. Updated ONLY exact count361→365 in the Foundation LocalizationResourceProbe and resource-only verification script; removal/uniqueness/language/signature/development-fallback guards retained. New514-input r3 freeze and serial verification use a fresh candidate suffixr2; no overwriting/deleting/signing/installing. No main-app product source changed by this packaging repair.


## Final delivery — frozen r3 / native r1

| Evidence | Actual result |
| --- | --- |
| Frozen inputs |514; all match before/after serial jobs and after native checks |
| Focused r6 |62tests /0failures |
| Full r3 |3131tests /0failures;81.402sec runner |
| Debug / actual Release |exit0 /exit0 |
| Fresh package r3 |exit0; reserved isolated native entry accepted |
| Packaged resources |3languages ×365keys; independent resource-only smoke1095entries,exit0 |
| Source review |Pascal SOURCE ACCEPT after reproduced/fixed fit-draft P2 |
| Test-contract review |Einstein TEST-CONTRACT ACCEPT; no findings |
| Main packaging-contract check |Two files changed only exact361→365 counts/output; all other guards retained |
| History/fixture |Previous511-input baseline has27changed +3added inputs, no missing; existing PagingCore/IconPipeline hashes preserved; old87whitelisted fixture files unchanged |

Candidate: `/Users/mac/Projects/Launch_Copy/PagingPrototype/.build/candidates/main-grid-spacious-icons-rc-20261019-r2/LaunchcopyUITest.app`

Executable SHA-256: `dc4ed86fbc2912b4c86d27a19e2125e1fa0ca80c462f936a6016431e49e5eaee`.

This is unsigned and uninstalled; it does not replace the formal app/profile. Incomplete suffixr1 candidate is retained but never seeded/launched. Final metadata/fixture/native/source receipts are under `.build/verification/20261019/main-grid-spacious-icons/`, especially `final-verification-r3.json`, `native-receipt-r1.json`, `source-inputs-r3.json`, `source-delta-r3.json`, `native-fixture-r1.json` and retained logs/patches.

### Actual native observations
Normal Finder Open started PID72107 before binding. At ordinary1000×700pt/6columns×5rows, own authored color glyphs visibly spread across width; folder source opens the accepted5×3panel/35members/3pages, Escape returns, one search result is horizontally centered. Appearance showed clean main80/base48/font11; native main slider80→96→80 saved live, base48 unchanged. Fit estimate correctly reported80/76 then88/76 in the ordinary current grid, not an unconditional96 promise. This is frame/preference size: transparent source-art padding can make painted ink smaller.

First instance normally Quit; exact process absence verified before same Finder Open. Restart PID72970 recovered main80/base48/font11/6×5; settings closed, query empty, folder closed. This ordinary isolated test instance is intentionally left running for the human, not an active build/agent job. No real app launch/removal/history, formal-data writes, security/OS-wallpaper/Git/signing/install/publication action. No saved wallpaper pixels, source filenames/paths or hash; CUA inline only.

### Honest residual gates
Window diagnostic was stillwallpaper-loading and visuallyblack at observations; do not claim wallpaper cause fixed or READY from these checks. This slice does not establish real-app imagery fidelity, actual trackpad motion/performance,120Hz/multidisplay, realIME/spokenVoiceOver or human aesthetic acceptance. Existing>25ms causality and full migration goal remain open. The new80pt default is our desktop design decision, not an Apple-prescribed iOS Home Screen ratio; legacy explicit saved sizes are not silently enlarged.
