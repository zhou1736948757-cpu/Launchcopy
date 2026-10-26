# Folder Glass Panel — Native Controls Results

Date: 2026-10-16
Verdict: BASIC_NATIVE_CONTROLS_OBSERVED. Not a full visual/physical/performance or independent native Reviewer PASS.

## Exact candidate and context
/Users/mac/Projects/Launch_Copy/PagingPrototype/.build/candidates/folder-glass-panel-rc-20261016-r1/LaunchcopyUITest.app
Executable SHA256:05c415a05303a0d7401581b670f13f7b67bf63167e041920edb55d174f7c14c4
Exact running process55970. Ordinary non-topmost window, initially2000x1400pixel capture, no fullscreen or Space switch. Candidate-local40 Info-only fake apps and35-member folder; no fake application launch attempted. Existing native panel glass code is unchanged from2794/0 build and independent source review.

## New actual native observations
The desktop was accessible on the fresh check; this supersedes the previous final locked observation. CUA actions used only this exact current test app.

1. Current folder page2of3 displayed members16–30. Next button reached page3of3 with members31–35 and no next button. This resolves the previously unknown third-page outcome through a NEW successful operation; it does not assert the timed-out earlier click had succeeded.
2. Native title-edit button opened a selected text field. Typed Glass temporary draft, then Escape. Original Dense Folder — 35 Applications title restored; no submit. Subsequent layout/Library payload hashes match baseline, so this edit did not persist into those payloads.
3. Native window bottom-right resize2000x1400px ->1400x1000px. Open folder stayed visible, material remained rounded/clipped and translucent, adaptive layout showed4 members29–32 on page8of9. No dismissal occurred.
4. Restored2000x1400px. Material bounds restored and15 members16–30/page2of3 were shown. This is the actual reflow result, not an assertion that repeated reflow preserves the original page number.
5. Clicked outside panel at1800,900. Folder closed while launcher window remained; no app exit.
6. Reopened via folder glyph. Page1of3/members01–15 restored. Final native still shows retained material diffusing ambient color, sharp labels/icons, no uniform opaque-black panel and no new exterior dim. Window restored and folder left open for the user.

Screenshots were inspected inline only; no captured personal wallpaper image files persisted. UI automation transport duration is not a frame interval or animation-performance measurement.

## Integrity and evidence boundaries
All463 canonical source/test/package input hashes reverified unchanged; executable hash matches. Isolated layout and Library preference payload hashes unchanged after title cancel/resize/close/reopen. No source edits, new test run/build/package or independent reviewer execution this turn. Prior2794/0 remains prior verified build evidence, not a new performance or physical result. No formal data, system appearance/accessibility/wallpaper settings, source directories, installation/signing, commit, process kill or reference project changes.

This controls slice does not establish real two-finger following/settling/background isolation, actual three-finger window dragging, first-frame/subjective black-flash absence, user aesthetic acceptance, controlled bright/dark/busy material matrix, real Chinese/Japanese IME, spoken VoiceOver, matched60/120Hz frame/energy/GPU measurements, or wallpaper intermittent reliability/rootcause. Whole migration goal remains incomplete. Exterior blur remains deliberately not enabled in the current candidate under the user's performance-first conditional scope; snapshot feasibility is documented separately, not proof every alternative is costly.

## Handover
Same candidate55970 intentionally left running, restored ordinary window and folder page1of3. No further UI actions are necessary just to repeat these observed gates. User can now provide the requested real gesture/flash/appearance feedback without opening a script or replacing formal software. Broader explicitly pending product/OS decisions remain pending; do not create speculative work to bypass those boundaries.

Raw scalar receipt: .build/verification/20261016/folder-glass-panel/native-controls.json. Earlier native-handover.json and locked audits are retained as history.
