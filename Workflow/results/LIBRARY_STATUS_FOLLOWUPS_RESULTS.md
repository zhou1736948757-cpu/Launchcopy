# Library status follow-ups — bounded test and evidence closure

Date:2026-10-16. Full independent LaunchBetter-experience goal remains ACTIVE/incomplete.

## Exactly what changed

Only existing Tests/PagingUITests/LibraryCatalogStatusVisibilityTests.swift changed. Two new integration regressions and one injected in-memory language store close the two named limitations in LIBRARY_STATUS_VISIBILITY_SOURCE_REVIEW.md. All459 other frozen inputs, including every production source and resource, match the previous460-input candidate manifest. No product API/behavior/default, AppKit window ordering, source/asset import or canonical data changed.

### Old callback discrimination
The new test captures an old Ready-hidden completion; replaces its view under Library; commits non-ready error on the current view; then Back exposes that error before invoking the old completion synchronously. Its visibility and AX assertions distinguish a correct current-owner guard from incorrectly copying the old hidden latch.

Actual mutation proof: a NEW separately owned package copy under.build contains all460 frozen inputs, with only AppDelegate's exact current catalogStatusView identity check removed. The canonical production file was NEVER temporarily edited. The copy compiled successfully (46.45s), then the one new test executed and failed exactly2 visibility/AX assertions. This is a compiled mutation RED, not a compile error or injected fake failure. Canonical focused8tests/0fail passed with the intact guard. The mutation copy/logs/receipts are retained, not installed or used as a product candidate.

### Locale rerender under Library
The second new test uses actual settings Apply -> language coordinator save -> queued language presentation -> full AppDelegate relabel -> queued status renderer -> Library mask -> actual Back restoration. A genuine committed grid no-results query and independent Library query are preserved. Japanese static status text is updated while the grid status remains visually/AX hidden under Library; Back restores the original grid query and exposes its legitimate localized no-results state. It does not manually install expected text or bypass the mode owner. The window is unshown with reported visibility admission; this is NOT native IME/spokenVoiceOver/physical acceptance.

## Verification and review

- Canonical focused:8tests/0fail,1.637s, focused-1.log.
- Independent copied mutation:1test/2expectedassertionfailures after successful compilation, mutation.log and mutation-receipt.json.
- Final canonical full:2748tests/0fail,65.051s, full.log. Trailing SwiftTesting0footer is not the XCTestcount.
- Main reverified460/460 input hashes; one testfilechanged/459unchanged. Copy differs only AppDelegate as intended. Final manifestSHA5afbc7c3ab7f47c30c485117a50ec1c940a7d80b0916fff7216339e199505f93. Broadgitdiffcheckexit0.
- Plato independent BOUNDED TEST-DISCRIMINATION/EVIDENCE PASS explicitly closesbothoriginalcoveragegaps; independently recomputed460canonicalhashes and460copiedinputhashes, inspectedactualfocused/mutationlogs, zero test/build/Swift/UI/filewrite actions. Fullsuite result was subsequently collected byMain, not reviewerexecuted. Reviewerclosed, no jobs/appinstancesremain.
- No redundant Debug/Release/package/native run: all product inputs unchanged. Existing latest unsigned/uninstalled adaptive-folder-rc-20261016-r2/LaunchcopyUITest.app SHA99408d28283198a6c9f47506652a4f94e2d55293dc8e3b1ff08dfa987b21bd04 remains current and rehashed. Existing native evidence retains its candidate-specific original scope; tests added today are not new GUI execution.

## Original limitations are superseded only as stated

The older test's both-hidden limitation and lack of explicit combined locale/Library test are now closed by the new cases and mutation discriminator. Do not erase or relabel the prior review. No new production defect was found or repaired by this test-only stage.

All remaining original-goal branches remain: human folder proportions/fullscreen acceptance, realIME/spokenVoiceOver, current matchedphysical60Hz/gesture/energy,120Hz/multidisplay/hardware, unresolvedlongtail/wallpaper cause and separately pending outercapacity/Librarypage/usage/destructive/extragesture decisions. Currentstage is PROGRESS in authoritative acceptance evidence, not fullgoalcompletion or a reason to invent unsupported features. No commit/install/sign/publish/reset/clean/delete/kill/OSsetting/formaldata/referencecode changes.
