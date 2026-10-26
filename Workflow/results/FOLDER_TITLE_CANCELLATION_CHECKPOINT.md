# Folder title cancellation checkpoint — 2026-10-15

## Status: bounded contract fix complete, native focus route still OPEN
Full independent LaunchBetter-experience parity remains ACTIVE/incomplete. Previous turn repaired hidden-caption native names. This turn established and repaired a separate cancellation-notification defect. The earlier background AX/Escape anomaly was **not fixed** by this patch; controlled native comparison makes that boundary explicit. A related Return/application-open-failure observation now raises the priority of actual edit-focus/event ownership diagnosis.

Do not report ordinary focused Escape as newly repaired: it worked in the before candidate as well. Do not report the entire rename/native gate or whole product as accepted.

## Baseline and native-before distinction
Prior453 inputs and exact4f15... hidden-label candidate matched; no own executable running. Main opened only that isolated ordinary-window profile (PID67551). In an inactive gray window, AX-set-only changed the mounted draft but left the accepted Group1 title unchanged through a screenshot and another read-only observation. The first Escape then ended editing and committed the draft while active styling appeared. No actual textMovement/activation trace was captured.

With an active red window and blue field-editor selection/caret, ordinary typeText plus Escape cancelled. Active AX-set plus Escape cancelled too. Tab accepted a new title; Return restored Group1. These are BEFORE any source change. Thus the background automation route cannot be conflated with ordinary focused keyboard input, and simply changing focus-loss to cancel would break an intentional contract. PID67551 normally quit and exact absence was verified before Swift execution.

## Established source defect and minimal repair
FolderTitleEditor.controlTextDidEndEditing previously committed every end-edit notification, including AppKit's legitimate NSCancelTextMovement. Its existing command-selector cancellation already called cancel(). The notification path must respect the same cancellation intent even if it arrives before a command.

Only production Sources/PagingPrototypeApp/FolderTitleEditor.swift changed: exact integral movement matching NSCancelTextMovement calls existing cancel(); every other/missing/malformed movement retains commit(). Fractional NSNumber23.5 is not coerced to cancel23. Existing terminal guard is set before callbacks; normalization, fallback, Unicode length, current-field-editor text, owner/session generation, ordinary focus-loss commit and late-dismiss semantics are unchanged. No new key interceptor, activation, responder change, persistence/schema, telemetry/diagnostics or view API.

Added seven direct production-delegate tests in Tests/PagingUITests/FolderTitleEditorCompletionTests.swift and one actual mounted owner/persistence integration method in existing FolderRenameAssemblyTests.swift. The integration demonstrates unchanged canceled layout/no canceled write, clean unmount/readiness, a later fresh session, stale old-editor rejection, preserved membership and exactly one accepted later write. Its window is unshown, notification manually delivered and store synthetic: not physical input or disk durability.

## Execution and independent review
- Worker Dirac wrote only the initial new seven-test file;0 Swift/build/tests/UI; closed. Main added the assembly test and fractional metadata case.
- Initial red.log is a compile failure, not executed RED: Main's new integration referenced private isTitleEditing. No private API was exposed; existing readiness/mounted-view/fresh-session assertions replaced that new assertion.
- Actual red-r2:8 executed tests,8 assertion failures across4 failing test cases,0 unexpected. Ordinary Return/focus-loss and command-first cases already passed.
- Final focused63/0,1.853s, including all8 additions plus actual rename assembly, editor host, search, hidden-label and field-editor language regressions.
- Full2672/0,51.086s; Debug and Release/package success; diff check passed.
- Packaged-only localization288 keys/3 languages positive exit0, missing-key and malformed-signature negatives exit1.
- Final454 input hashes verified after native work. Exactly one production input, one existing test input and one new test differ; no removal. All18 PagingCore/PagingUI, all53 AppGridUI, resources, package/scripts and earlier fixes unchanged. Owned before copies match prior453 manifest; bounded diff and independent in-memory reversals retained.
- Reviewer Volta: BOUNDED SOURCE PASS, no actionable scoped finding;454 hashes independently verified.0 Swift/build/tests/UI/process control. Report: Workflow/results/FOLDER_TITLE_CANCELLATION_SOURCE_REVIEW.md. Reviewer and worker closed; all Main jobs terminal.

## Exact current candidate
Unsigned/uninstalled:
/Users/mac/Projects/Launch_Copy/PagingPrototype/.build/candidates/folder-title-cancellation-rc-20261015-r1/LaunchcopyUITest.app

Executable SHA-256:528054ec0479fc18fac75766c9ab57fd66c1fefbaed00f3e0dbe0dd49ba05774.

Only isolated candidate-local profile/ordinary non-topmost window and40 owned Info-only fixture apps. No formal user data or executable-app launch success inferred.

## Actual native AFTER evidence and counterevidence
1. Exact same inactive gray-window AX-set-only/no-action/Escape comparison still commits the draft. The new notification branch is not a demonstrated fix for that actual native route, and no native notification reason was captured. Status: INACTIVE_AX_INPUT_ROUTE_UNRESOLVED.
2. Actual active blue-field plain typing plus Escape cancels, and active AX-set plus Escape cancels. Actual active Tab accepts the typed title; active Return restores Group1. These preserve working ordinary behavior, not a before/after native cure claim.
3. Own PID73033 -> normal menuQuit/verified absence ->75423. Group1/5members observed, but that equals the initial fixture seed, so this first restart is relaunch smoke only, not discriminating write proof.
4. In process75423, accepted the nondefault `Completion Restart Probe` and five members, normally quit/verified absence, reopened the same candidate as76782. The nondefault title and all five member names01..05 were restored. This second roundtrip is meaningful native persistence evidence.
5. Final restore in process76782: inactive AX-set Group1 plus Return restored the accepted title AND produced an application-open-failure feedback for Info-only fixture HandoffDemo05. This is counterevidence to a general no-Return-leak claim, not a successful real launch or a proven call trace. The next Escape removed that failure text from the filtered tree but the folder remained open; do not claim it closed the folder.
6. Tab/titlebar-click activation preflights on a restarted background window did not establish active styling. No focus success is credited to those attempts. Contrast actual earlier blue field/caret screenshots with these inactive controls.
7. Group1 visibly restored; no further restart of final restoration claimed. Process76782 normally quit; exact executable absent; no native query afterward. No own test process remains.
8. Wallpaper stayed loading/black in inspected runs. The first fixed instance's own cache inventory contained no files (metadata-only read). That does not alone prove a provider/render failure. No wallpaper fix, readiness, broad appearance PASS or frame-performance result is claimed.

## Next executable action: actual edit focus and first-key ownership
Priority is the unresolved background AX first-key behavior and related Return failure feedback, not another cosmetic feature. Inspect AppDelegate.beginTitleEditing and the real window/field-editor/keyboard routes. Current source anchor: it mounts the editor and calls window.makeFirstResponder(editor), but unlike the settings button does not explicitly establish a key/active window. This is a hypothesis to test, not a diagnosed cause or approval for broad activation changes.

Start a new bounded focus-ownership stage on this454-input/5280... baseline. Reproduce with native preconditions, add a production-owner/window regression and compare active versus inactive admission. Determine whether explicit user title-edit requests need local key-window acquisition before editing, without changing passive background startup, normal non-topmost test behavior, desktop/Space participation, IME Escape, ordinary focus-loss save or paging. Avoid a global key interceptor or app activation workaround merely to make automation pass. Any material focus-policy change needs an explicit English decision/specification update; no such implementation is included in this slice.

Retain the cancellation-notification fix as an independently verified contract repair, not as evidence that the unresolved first-key route is solved. Wallpaper provider/render/completion diagnosis remains another actual parity issue after the input-safety investigation.

## Evidence / remaining boundaries
.build/verification/20261015/folder-title-cancellation/ contains before copies/diff, RED and focused/full/debug/release logs,454-input freeze/probes/fixtures, native-before results/process/quit, all fixed/probe restart process records and native-fixed-results.json. Native images/AX are inline tool observations; JSON summaries are not fabricated raw traces or screenshots. Production title text never enters new diagnostics; only explicitly synthetic fixture strings appear in test evidence.

All prior coverage follow-ups, realIME/VoiceOver/modal/offscreen/native failure/source-management lifecycle, matched physical60Hz comparison, unresolved>25ms causality,120Hz/multidisplay/powerloss and pending capacity/rows/columns/anchor/history/destructive/extra-gesture approvals remain separate. No formal data/app mutation, reference source/resource access, install/sign/notarize/publish/commit/push/reset/cleanup/delete/processkill, OS-setting/Space change or unrelated-app control. Existing dirty work preserved. Full goal remains ACTIVE/incomplete.
