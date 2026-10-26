# Title-edit key restoration checkpoint — 2026-10-15

## Status / superseding conclusion
Full independent LaunchBetter-experience parity remains ACTIVE/incomplete. Previous turn repaired legitimate cancel-notification completion, but did not fix the native background first-key symptoms. This turn repaired a concrete key-restoration ownership defect. The original inactive first-Escape mis-save, first-Return extra failure feedback and dropped first-text-input symptoms no longer reproduce in the recorded fresh-process sequences on the final candidate.

This supersedes those particular unresolved observations for the tested candidate, not their historical truth. It does not establish a universal native event-replay trace, zero launch-API calls, physical IME/VoiceOver or whole-product acceptance.

## Discovery and causal source counterexample
SwiftPM/AppKit14+ composition has a search controller observing NSWindow.didBecomeKeyNotification and choosing a mode first responder. Before this repair:
1. AppDelegate's provider returned the current mounted title only if currentEditor() was already nonnil. A pending acquisition could therefore lose title-over-folder priority.
2. AppSearchController compared the window's first responder only with the control itself. When the actual first responder was that control's native NSText field editor, it unnecessarily called makeFirstResponder(control) again.

Actual unshown production composition/observer regression reproduced the second defect:3 responder requests, title completion/unmount, lost native text/selection and canonical layout changed to an unaccepted draft. This is a real callback consequence in the test window, not just a failed getter. The recording-store empty assertion did not fail in that RED log, so no completed disk write is inferred from it.

The separate pending-acquisition probe deliberately returns true without acquiring NSText; it models requested-responder admission and is not evidence that AppKit did exactly that in the original native run. Explorer identified the conditional post-completion keyboard/member launch route, but did not prove replay of one Return or the actual notification movement/order. That exact event trace remains uninstrumented.

## Bounded implementation and existing contract
Only two production private paths changed:
- AppDelegate.modeFirstResponderProvider returns a live current rename context's exact mounted editor in the owner's current window, without requiring a native field editor to have already been acquired. Stale, unmounted or moved views do not win.
- AppSearchController.rebuildFirstResponder returns when the existing first responder is already the target, or is the exact native field editor currently owned by that NSControl. Otherwise it uses the original responder request.

This preserves the already-approved title > folder/search/grid restoration priority. It introduces no new activation policy, makeKey/order-front/NSApp.activate call, window-level/Space/geometry change, global key interceptor, event replay suppression, persistence/schema change or completion-rule change. The previous cancellation-notification fix remains unchanged. Maintenance rationale is appended to Docs/LAUNCHBETTER_FOLDER_RENAME_REPAIR_PLAN.md.

## Regression / execution / review
- New three tests are appended to existing FolderRenameAssemblyTests. Only these tests opt into an actual AppSearchController/observer and a recording probe window. All previous fixtures default to their original NSWindow and no search controller.
- Cases: pending mounted title remains target without native editor; already-owned actual native editor/draft/selection/layout remain untouched; a detached editor moved to the same window cannot regain title priority.
- Initial red.log is a compile failure (NSText selection uses a property), not executed RED. Actual red-r2:3 executed tests,9 assertions across2 failing cases; the stale-owner negative already passed.
- Final focused75/0,4.556s; full2675/0,52.039s. Debug and Release/package succeeded; diff check passed.
- Packaged-only288-key/3-language positive probe exit0; deliberate missing-key and invalid-signature negatives exit1.
- All454 final inputs match after native work. Exactly AppDelegate, AppSearchController and existing test file differ; no additions/removals to input inventory. All18 PagingCore/PagingUI, all53 AppGridUI, resources/package/scripts and previous completion/naming fixes remain unchanged. Before copies match prior454 manifest; exact bounded diff retained.
- Galileo independent BOUNDED SOURCE PASS,454 hashes and exact delta independently verified;0 tests/build/UI. Optional coverage suggestions: isolated foreign-window guard, a second generic mode control and marked text across this exact observer. These are not demonstrated defects or newly required implementation. Reviewer closed.
- Epicurus source-only discovery,0 Swift/build/tests/UI. Report discloses initial unprefixed instruction reads and ancestor-wide filename inventory returning excluded-tree AGENTS pathnames; no excluded file contents were opened. Explorer closed. Main and all verification jobs terminal; max concurrency2 includingMain.

Reports: Workflow/results/TITLE_EDIT_FOCUS_SOURCE_REVIEW.md and TITLE_EDIT_EVENT_ROUTE_DISCOVERY.md. Source review is bounded source evidence, not native acceptance.

## Exact final candidate
Unsigned/uninstalled:
/Users/mac/Projects/Launch_Copy/PagingPrototype/.build/candidates/title-edit-focus-rc-20261015-r1/LaunchcopyUITest.app

Executable SHA-256:889d661392cc18f0e59958b1b51d499dfac13d82a116a7fa53e1b31852c12bed.

Candidate-local ordinary non-topmost isolated profile with40 owned Info-only fixture bundles. No real executable application launch success inferred.

## Actual native evidence
### Supported before control, unchanged5280... build
Two attempts to read the same Dock returned observation timeouts. No Dock restart/terminal fallback; the owned app remained accessible via the same handle. Opening and closing the app's existing Settings UI without Apply visibly produced an active main window and blue title field. Under that input-ready condition, first Return saved with no open failure, first Escape cancelled, normal typing/Tab saved and typingGroup1/Return restored. Thus ordinary focused commands were not universally broken before this patch. PID80476 normally quit/exact absence before Swift work.

### Matched after sequences, three new final-candidate processes
1. PID88887: background gray window from fresh launch, same Raise/folder/title AX actions, AX-set `AX observation only`, screenshot and further no-action read still draft. First Escape closed the editor and left accepted Group1 unchanged. Before5280... the same setup committed that draft. No Settings activation preflight was used after the patch.
2. Normal menuQuit/exact absence, then new PID90154: same background gray setup, AX-set nondefault `Focus Restore Probe`, first Return accepted the title and five members. No app-open-failure feedback immediately or in a later read-only full tree. Subsequent Escape directly closed the folder. This is absence of observed feedback, not instrumentation proving zero launcher invocations.
3. Normal menuQuit/exact absence, same candidate reopened as PID91419: nondefault Focus Restore Probe/five members restored, a discriminating persistence check rather than default seed equivalence. Opening the title and using typeText as the very first keyboard input kept `Discard first typing` in the actual blue native editor. Escape cancelled back to accepted Probe. Subsequent actual typingGroup1 plus Tab saved the restoration; next Escape closed the folder. No added app-open-failure feedback in these observations.
4. Final Group1 visibly restored, appearance defaults unchanged; no additional restart of final restoration claimed. Final PID91419 normal menuQuit/exact executable absent; no native query afterward. No owned test app remains running.

Before/after screenshot styling and tool input are observations, not private OS focus booleans or physical hardware events. Native CUA text entry is not a real IME composition test. The actual timing/identity/replay of an anomalous key was not signposted or traced. Source causality plus matched symptom improvement supports this bounded repair without inventing that missing trace.

## Next actual parity issue: wallpaper loading/black backdrop
The final candidate still reports wallpaper loading with regular/local source metadata and black background in inspected runs. The own final profile cache inventory was empty (metadata-only); this alone does not diagnose render/provider failure or justify replacing the accepted compositor. Historical ready/visible runs remain different evidence.

Next stage should inspect the actual async source/decode/render/completion path using authored synthetic image/provider/background-loader controls and path-free diagnostics. Distinguish unfinished work, stale generations/host attachment and a completed image hidden by compositing; do not assume the old black-layer cause or copy reference code. Preserve this454-input/889d... baseline,5x7/physics and existing privacy/IO boundaries. Do not create more focus/activation patches for the now-resolved matching cases without new counterevidence.

## Remaining full-goal and safety boundaries
Evidence:.build/verification/20261015/title-edit-focus/ includes before copies, bounded diff/freeze, RED/focused/full/debug/release/probe/fixture artifacts and native before/firstEscape/firstReturn/restart/finalQuit/results JSON. AX trees/screenshots are inline observations, not raw saved traces/images. Only synthetic fixture strings appear in test summaries; production title diagnostics were not added.

RealIME/VoiceOver/modal/offscreen accessibility, matched physical60Hz comparisons, unresolved>25ms causality,120Hz/multidisplay/powerloss, management/source/error lifecycle and outstanding capacity/rows/columns/anchor/history/destructive/extra-gesture approvals remain distinct. Prior callback/combined-locale coverage follow-ups remain. No formal app/data mutation, reference source/assets file-content access, installation/signing/notarization/publication/commit/push/reset/cleanup/delete/processkill, OS-setting/Space change or unrelated-app stop. Existing dirty tree preserved; full goal remainsACTIVE/incomplete.
