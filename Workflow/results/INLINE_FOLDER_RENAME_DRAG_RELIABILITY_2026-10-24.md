# Inline folder rename / intermittent drag investigation

## User scope
Compact title-sized rename field, outside-click completion, and detailed investigation of intermittent main/folder dragging. Existing FirstDragFix was not physically accepted as a complete repair.

## Implemented rename behavior
Same22pt semibold title typography; short text gets centered glyph-measured width plus24pt padding,44pt minimum and available-title bound. Live draft notifications change only the frame, preserving text/IME/editor identity and member panel geometry. Generic non-field mounted editor host contract unchanged.

A content left click outside the mounted editor negotiates makeFirstResponder(nil); refusal retains the editor/draft. Existing guarded owner commits exactly once (live field-editor text, normalized, stale layout/revision/store checks intact). Window consumes the whole dismissal down/drag/up so it cannot launch an app, close the folder or reorder. Inside editing, Enter/Escape, other windows and native title/resize paths remain normal. No forced endEditing or unmarkText.

## Drag findings and honest scope
Readonly Nash audit found multiple possible admission paths (transition, click-only search/read-only, first-mouse/focus, native folder vs B1 main, stale source, absent geometry). None is the proven physical cause. Do not claim adding counters solves dragging.

One independently reproduced safety defect: pressed down followed by far release without processed movement emitted clicked regardless of distance. Pure red2tests/4assertions reproduced both main/folder and exact6pt threshold. Now distant release returns noOp, not click/launch; no synthetic drag or drop is introduced. This safety fix is NOT proof that physical movement delivery is repaired.

## Neutral diagnostic protocol
DefaultOFF; only isolated-profile View menu exposes start/reset/report/stop. No OS setting, global monitor, event interception change, raw events/touches, coordinates, app names/IDs/paths, user titles/search text, telemetry, disk IO or per-event stderr. Fixed54-event integer counters (saturating) cover native window/B1/folder route, actual overlay admission, controller gates, processed movement/cancellation/release/outcome; report also samples neutral current-state booleans, explicitly not failure-time state. Counts from different layers/collapse reclassification do not represent one-to-one attempts.

Native handover protocol: normal Quit exact owned89871onlyafter final source/test/build/review gates; same-profile unique sibling preserves accepted data. Verify unchanged manifest/profile hashes and new executable identity. Main can inspect unchanged-title rename/blank dismissal without mutating organization, then reset/enable counters and leave main view for user. For a failed real drag, stop retrying and report it while process remains open; Main reads aggregate report before reset. Actual user physical observations remain separate from tests and native presentation.

## Evidence so far
- rename-before.log:2tests/5assertions red.
- rename-focused-r1.log:110/0.
- rename-focused-r2.log:compile-only failure in new tests due private property access; no production API widened.
- rename-focused-r3.log:113/0 after using existing capability/ownership assertions.
- release-before.log:2tests/4assertions red.
- focused-r4.log:161/0, including12accumulator tests and native B1 cancel/late-up/recovery/prod-menu refusal.
-599inputs/12deltas frozen source-inputs-r1.json vs previous595manifestR2.
- Full suite and independent Anscombe bounded review in progress. No new native delivery or physical PASS yet.

## Changed files
See source-delta-r1.json for exact12paths. Six existing production files, two new production diagnostic files, two existing test files and two new test files. No PagingCore/PagingUI/frame/gesture parameters, capability defaults, stores/schema, reference code/assets or formal install/sign/Git mutation.

## Final automated verification
FullR1 **3683/0**,90.307s execution; focusedR4 **161/0** and targeted whitespace check pass on unchanged599inputs/12deltas. Debug/Release strict package running serially; independent Anscombe review pending. No native replacement before bothgates, no physical root-cause/drag PASS. Historical compile-only private-test-access failure and red rename/release logs retained.

## Final native handover / diagnostic readiness
Independent Anscombe bounded sourcePASS closed; full3683/0,focused161/0,Debug/strictRelease/resources3×367 and599inputfreeze stable. New ownedPID5996 `/Users/mac/Projects/Launch_Copy/PagingPrototype/.build/candidates/integrated-preview-rc-20261023-r1/LaunchcopyPreviewInlineRename.app`, SHAab2b343b99cb91c288766abc0d58b9973b8e9ad7a665182eddc4a4908aa9df72. Old89871normallyQuit/exactabsenceverified; all5nonwallpaperprofilehashes/modes remain identical beforeQuit, afterstart and after native no-op title editing. Same explicit candidate/integrated namespace, no import/reset or schema change. Original canonicalmanifest byte-exact and unique newsidecar retained.

Native existingfolder opened, same-title edit entered (no newcharacters), visibly compact field at title size observed, click in panel header outside field dismissed editor and retained openfolder. Escape returnedmain. No actual newname save, realapp launch/drag/grouping or organization mutation attempted. Native presentation only, no physicalinput/IME/refusal/fullparity PASS. Transient screenshots inspected, none saved. Existing partialcatalogwarning stillobserved, not treated as a new repair.

Isolated View commands start/reset/report/stop observed. Report enabled=1,total=0 with searchActive=false,canCommit=true,noeditor,nofolder,notransition,key=true,active=true read through native alert; reportclosed and counters resetagain. Main/wallpaperREADY/LibraryON, menus/settings/reports closed, leftready for user. Report current booleans are report-time only, notfailuretime. User asked to test main-only physical threefinger attempts; onfailure stopretrying/keepprocessalive so Maincanread neutralaggregates before reset. Previous idle fix and new safety noOp do not prove physical intermittencyresolved.

Currentreceipt `.build/verification/20261024/inline-rename-drag/final-native-ready-r1.json`. Next executable action: consume actual user result, open View→dragdiagnosticreport, inspect admission/cancel counters with currentcontext, discriminate before another sourcepatch. Then independently test folderdrag if mainpath settled. Overall original goal remainsincomplete.
