# Native text editing checkpoint — 2026-10-15

## Status and objective
Full independent LaunchBetter-experience parity remains ACTIVE/incomplete. This slice repaired a concrete native text-editing compatibility defect in approved search/rename/settings scope. It is not a new keyboard model, performance fix, historical clean-room claim or whole-product acceptance.

## Reproduction and implementation
Before candidate: renderer-handoff-rc-20261015-r1, executable SHA-256 `1d9d1caada6a77ab14aad364a09f59a2a92a7071ce7d2ea534885897d95dd51f`. Supported native input into the focused search field worked, but Handoff + Command-A +07 yielded Handoff07 rather than07, and paste Demo inserted nothing. Its main menu contained only App and View. An unshown actual installed-menu test failed1/1 because no paste command was registered.

Added `LauncherEditMenuController.swift`: standard Undo/Redo/Cut/Copy/Paste/Select All, ordinary Command shortcuts, nil targets and native automatic validation. AppKit resolves the current editor; no new event interceptor, application-launch route, clipboard access/polling or input history. AppDelegate installs it between the unchanged App and View menus and relabels it through the existing safe deferred language owner. Installer is internal/@MainActor for production-path tests. Seven typed static menu keys, English fallbacks and three localized tables follow the existing localization pipeline.

Changes: eight modified/two new files relative to prior446-input manifest; current448 inputs all match. All18 PagingCore/PagingUI sources match the immediate prior candidate, including the previous bounded PageHost repair. Physics, timing, frame driver and gesture/search semantics are unchanged. New code executes at menu installation/language presentation, not in frame callbacks. Static boundedness is not a measured physical no-regression result.

## Verification, including failures
- Actual installed-menu RED1test/1failure retained.
- First focused attempt: actor-isolation compile failure; installer annotated MainActor. Second: test-only Any? identity comparison compile failure. Logs retained; no executed-tests claim.
- Historical focused67/0 passed before a full-suite harness issue was found; superseded by final focused result below.
- First full suite2640/4: our test's global no-key-window assumption failed safely before any command, plus three initial-readiness assertions in an existing Library writer-replacement test. No failed run is suppressed.
- Corrected menu-keymatching test: assert production niltarget, then target a local spy solely for key matching. Never paste into an arbitrary existing test editor. Native after separately proves actual editor routing.
- Existing Library test had captured an action generation before asynchronous startup fanout, then kept resolving that stale request. A deterministic real catalogDidCommit invalidation reproduced1test/3same failures; oldrequest invalidation assertions passed. Only the initial test-readiness loop now obtains a current request per iteration, retaining the original2sdeadline and every subsequent old-sheet/writer/no-write/fresh-action assertion. No production Library guard changed. The precise natural failing callback schedule was not instrumented; do not overclaim that provenance.
- Final focused75/0,6.949s; final full2640/0,58.140s; Debug succeeded.
- First package command used the display name instead of the SwiftPM executable product and aborted before app assembly. Preserved failurelog. Corrected invocation uses existing PagingPrototypeApp product; Release/package succeeded without changing the script.
- Packaged resources:288 required keys/three languages; positive exit0; missing menu.paste and invalid static signature negative fixtures exit1. All448 frozen inputs reverified after native work. Diffcheck passed.
- Independent bounded SOURCE PASS: `Workflow/results/NATIVE_TEXT_EDITING_SOURCE_REVIEW.md`. Reviewer0tests/build/UI; worker0tests/build/UI. Both agents closed. Main ran all acceptance jobs serially.

## Current candidate
Unsigned, uninstalled:
`/Users/mac/Projects/Launch_Copy/PagingPrototype/.build/candidates/native-text-editing-rc-20261015-r1/LaunchcopyUITest.app`

Executable SHA-256: `34ea5275b0d75cc52f75ca6524f2c59ef880ed4b9e95af6cbbc902fae2441d4a`.
Independent candidate-local GUI profile and forty owned Info-only fixtures. They are not executable application-launch evidence.

## Native after and real restart
Actual current-candidate observations:
1. Focused Handoff + Command-A +07 ->07 and one correct fixture result. Paste Demo ->07Demo. Command-A +paste07 replaces rather than appends.
2. Enabled optional Library via its acknowledged saved checkbox. Library Handoff +Command-A+paste08 ->08, one correct result. Back retains independent main07. No simulated owner seam used for this observation.
3. Native Edit menu exposed Paste/Select All and dynamic Undo Paste; native validation disabled unavailable actions. Copy/Cut/Undo/Redo were not executed. CUA paste restores the previous clipboard; its contents were not inspected. OS-injected writing/AutoFill/dictation commands were not invoked. Native system-provided labels can retain the OS locale; app-owned labels use the selected app language.
4. Japanese Apply acknowledged saved/applied; Settings/search/Edit/View/Library labels changed, fixture names and main07 remained. Inspected language settings screenshot showed no observed overlap. Library screenshot exposed a separate long-category-count truncation issue below, so this is not all-Japanese-layout PASS or real Japanese IME acceptance.
5. Exact PID59674 normal menuQuit -> exact executable absent. Direct samecandidate reopen -> PID61316; Japanese/Edit and Library enabled retained, grid mode restored rather than stale Library session.
6. On restart initial background dots were disabled. After actual search focus they enabled: dot2 ->2of2, dot1 ->1of2, query/focus retained. This current-candidate native navigation observation supersedes only the earlier candidate's unexecuted forward/back check, not its history or physical/VoiceOver gates. No lifecycle guard weakened.
7. Wallpaper initially loading, later ready and visibly composited. No source-delay cause or performance resolution inferred. No obsolete neutral five-page label or decorative top number observed.
8. Final normal menuQuit -> exact executable absent; no native query after finalQuit, no test instance left running.

Evidence: `.build/verification/20261015/native-text-editing/` contains red/focused/full/build/package failures and successes, source freeze/delta, strict resource results, before/after observation JSON, fixtures and exact process records. Screenshots/AX were inline tool observations, not saved raw image artifacts.

## Concrete remaining visual defect and next executable action
Japanese Library screenshot at ordinary1000x700pt viewport shows long category names such as Health/Fitness and Social Networking tail-truncated together with their numeric suffix. Source `AppLibraryView.swift:353-360` currently combines title and count in a single truncating label (`:376`). AX retains full combined label; this does not prove a VoiceOver result and does not prevent the visible count loss.

Next bounded repair: reproduce a long localized category cell at actual sidebar width; reserve an independently trailing count while allowing only the title to truncate, keep full accessibility label and stable existing category/focus semantics. Use the current448-input/candidate baseline, add regression and independent review, no new category or layout-capacity contract. Do not silently certify compact/VoiceOver/realIME/physical gates from this repair.

Other original parity requirements remain in the ledger: real IME/Tab/VoiceOver/compact focus, broader folder/management/source/error lifecycle native matrix and matched60Hz physical comparison, unresolved >25ms causes,120Hz/multidisplay and unapproved capacity/usage/destructive/gesture branches. No formal-data/app mutation, installation, signing, commit/push, OS-setting/Space changes, unrelated process stop or reference source/resource reads.
