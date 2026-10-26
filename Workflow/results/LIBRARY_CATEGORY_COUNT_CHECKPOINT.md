# Library category count and native folder checkpoint — 2026-10-15

## Current status
Full independent LaunchBetter-experience parity remains ACTIVE/incomplete. Previous goal turn made progress on native text editing. This turn corrected an observed localized Library presentation defect, preserved native accessibility structure after a second native check, and advanced the already-approved folder editing/persistence GUI gate. It does not establish full parity, VoiceOver, real IME or physical performance acceptance.

## Bounded source change
Baseline448 inputs: native-text-editing candidate, executable34ea5275... . Long Japanese category title and count shared one tail-truncated text field, hiding the count. Added a small internal `AppLibraryCategoryCell.swift` with independently trailing numeric space, title-only tail truncation and full combined tooltip/AX text. AppLibraryView keeps the same taxonomy, count computation, selection, query and reuse identifier; only cell factory/bind and removed old factory differ. No public API, schema, resource or paging changes.

Current450 inputs: exactly3 changed/new files:
- `Sources/PagingPrototypeApp/AppLibraryView.swift`
- `Sources/PagingPrototypeApp/AppLibraryCategoryCell.swift`
- `Tests/PagingUITests/AppLibraryCategoryCellTests.swift`

All18 PagingCore/PagingUI source hashes and every other prior input match baseline. Main reversed only the known AppLibraryView factory delta in memory and recovered the exact prior SHA-256; see app-library-view-delta-proof.json. Five tests cover actual localized delegate cells, zero/multidigit counts at112/184/200pt widths, direct bind reuse, All counts/relabel/query/selection, tiny-bound containment and native default accessibility exposure. Full count readability is measured for0..999999 in supported widths, not arbitrary integer strings or transient tiny bounds; complete tooltip/AX text remains available.

## Verification chronology and honest boundaries
1. Actual delegate RED1test/1failure: no independent numeric reservation. Native previous screenshot, not this structural test alone, proved the observed visual loss.
2. R1 focused34/0 and full2644/0,54.616s; Debug/Release/package; strict288-key/3-language positive/two negatives,450 freeze matched; independent bounded SOURCE PASS.
3. Actual R1 Japanese screenshot showed Health12/Social12 visible, selected Health contrast readable and exactly12 results. Its explicit custom-cell accessibility exposure also added a nested Unknown wrapper. This was not diagnosed as a VoiceOver failure; unnecessary topology change was removed.
4. Default-native-cell comparison RED1test/2failures: explicit custom exposure and missing full title AX label. R2 retains native cell/title exposure defaults, labels both with the complete pair and ignores only the decorative count; geometry unchanged. R1 reports/freeze/candidate/native/probe evidence preserved.
5. Final R2 focused35/0,6.394s; full2645/0,61.622s; Debug and Release/package succeeded. Packaged288 keys/3languages, positive exit0 and missing-key/invalid-signature negatives exit1. All450 current inputs reverified after native work; diffcheck passed.
6. Independent final bounded SOURCE PASS: `Workflow/results/LIBRARY_CATEGORY_COUNT_SOURCE_REVIEW_R2.md`; original report retained. Reviewer0tests/build/UI/process control; Main owns all execution. Reviewer closed, jobs terminal.

Static budget: no added application I/O, timer/observer, catalog/projection/icon work or frame/gesture callback. Fixed native cell layout operations and native text measurement are not a measured physical no-regression PASS. No physics/timing/input source or parameter change.

## Current candidate
Unsigned/uninstalled:
`/Users/mac/Projects/Launch_Copy/PagingPrototype/.build/candidates/library-category-count-rc-20261015-r2/LaunchcopyUITest.app`

Executable SHA-256: `4aeada7b756183b62a99536aa760b3f4448b66f88f74598d7d224ddfbca100a0`.
R1 candidate bd1a113a... is historical, not final acceptance. Fresh owned GUI profile and40 Info-only fixtures:12 Health/Fitness,12 Social Networking,16 Productivity. These are not executable-app launch evidence or formal user data.

## Native R2 results
- Normal settings UI enabled Library and applied Japanese with save acknowledgments; no direct preference injection or OS language change.
- All40, long Health12, long Social12 and Productivity16 displayed; only titles truncate, numbers remain fully visible. Selected Health blue/white title/count readable and filter gives exactly12 result cells in this ordinary1000x700pt dark window.
- Full localized name/count retained in actual AX cell labels; extra Unknown category wrapper absent. AX inspection is not VoiceOver traversal, and tooltip getter is not actual hover-tooltip acceptance.
- While Health selected, query Handoff Demo13 produced All1/Health0/Social1 and no Health result. Selecting Social kept the query and showed the correct single Demo13. This exercises real count rebinding and retained query/category behavior.
- Existing folder Group1 opened from observed icon coordinates; AX text clicks alone did not open it. The actual mounted title editor accepted Command-A/paste `Layout Test 日本語`; Return updated inner and outer title. A second draft `Discarded test draft` followed by Escape left the committed title intact; another Escape closed the folder.
- Exact PID72909 normal menuQuit -> exact executable absent. Direct same candidate reopen -> PID76297 retained renamed folder with5members, Japanese and enabled Library; returned to grid rather than stale Library query. This is real process restart evidence, not same-process reload.
- Final normal menuQuit -> exact executable absent; no native query after finalQuit. No own app running.

Evidence folder: `.build/verification/20261015/library-category-count/` contains retained RED/R1/R2 focused/full/build/package logs, source freezes/delta proof, packaged resource probes, synthetic fixtures, native-r1/native-r2 observation summaries and exact-process records. Native screenshots/AX were inline observations, not saved raw images. No actual app launch, IME, VoiceOver, light/compact visual matrix, failure-dialog, power-loss, physical60Hz comparison or120Hz claim.

## Concrete next defect / next executable action
Native after Library Back showed an unexpected persistent central Apps Ready badge over a populated grid; initial startup/restart did not show that overlay. Source confirms a conflicting visibility owner: `AppDelegate.swift:2266-2274` unconditionally assigns catalogStatusView.isHidden=hidden when restoring grid, overriding `AppGridStatusView.swift:131` which hides .ready.

This is an observed artifact plus a strong source hypothesis, not yet a regression-proven repair. Next: create an actual delegate/Library enter-Back regression, preserve hidden ready status while correctly restoring busy/error/empty/query states through the status owner's own presentation policy. No new timer, status copy, startup/catalog scan, page/chrome architecture or gesture parameter change. Keep current450-input/candidate baseline and original full objective intact.

Other original gates remain in the parity ledger: real IME/Tab/VoiceOver, broader folder/management/source/error lifecycle matrix, matched physical60Hz/120Hz/multidisplay and unapproved capacity/usage/destructive/extra-gesture branches. No formal app/data, reference source/assets, installation, signing, publication, commit/push, OS-setting/Space change, process kill or unrelated-app stop.
