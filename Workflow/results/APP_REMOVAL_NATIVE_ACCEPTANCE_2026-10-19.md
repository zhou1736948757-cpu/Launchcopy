# Controlled native app-removal acceptance

Date: 2026-10-19 (Asia/Tokyo)
Status: CONTROLLED_NATIVE_CORE_PATHS_PASS_WITH_FINDER_PUT_BACK_LIMITATION

## Scope and identity
The human reported manual unlock and authorized continued testing of independently authored disposable applications only. Main alone performed native UI actions. No new source edits or rebuild were needed: all511 frozen code/package inputs and executable SHA-256 `975db8309a82e316c53e5c4d8f0fab189ebe521af94e9575b5f9f41c1748dbb8` still match the final2026-10-18 receipts. Existing focused128/0, full3095/0, Debug/Release/package and bounded source-review evidence remain separate, not newly executed here. All prior agents/jobs were closed.

Candidate: `.build/candidates/app-removal-rc-20261018-r1/LaunchcopyUITest.app`.
Fixture: candidate-local `UITestProfiles/gui/Applications/Launchcopy Trash Fixture aadf0c924773.app`, independently authored inert probe; never a real user app.

## Executed native outcomes
1. Inspected old PID30428 test appearance. Normally Quit it through its app menu and verified exact executable absence before opening the new full candidate path. No installation/overwrite.
2. Restored namesON, live blur28.40063010899183, icon54, font12; existing capacity6columns×5rows unchanged.
3. Grid context Move to Trash displayed the exact name/path and explicit default-Cancel single-bundle warning. Actual Cancel retained the bundle and identical Info SHA.
4. Reopened current menu, confirmed only the disposable fixture and performed one actual platform Trash. Product displayed success and its unique search became empty. Original path absent, exact own Trash item present, Info SHA unchanged; saved layout and capacity hashes unchanged.
5. Finder selected the exact uniquely named Trash item. **File > Put Back was disabled. This is not one-click Put Back PASS.** Used native Finder Edit > Copy on that exact selection, returned within the same window to the exact original Applications directory, then Edit > Move Item Here. No shell restore/copy/move, no Trash emptying and no other items selected. Original path restored, exact Trash item absent, Info and executable hashes identical. Product automatically rediscovered it; its unique search returned the application.
6. Temporarily enabled Library in the isolated profile, keeping trackingOFF. Same application's Library details Move to Trash displayed the same default-Cancel confirmation; actual Cancel retained the app. Actual Trash was exercised through grid only, not a second Library deletion.
7. Verified no probe process before Library Open. Product Open started the exact disposable probe PID97735. While it ran, grid removal was refused with the localized running-app warning, without a removal confirmation or force quit. Bundle remained intact. Then normally Quit the probe through its own Quit button; exact process absence verified before any further probe binding.
8. Restored LibraryOFF/trackingOFF. Normally Quit the test, verified test/probe absence, reopened the same candidate, and inspected persisted settings. NamesON/icon54/font12/6×5/FollowSystem and bothOFF retained. Existing integer blur preference reloads as28, not fractional28.40063010899183; do not claim exact fractional persistence.
9. Final own test PID98940 is available in an ordinary non-topmost main window with no query, no open folder and settings closed. Wallpaper diagnostic was ready then; this does not resolve historical intermittent loading/black backgrounds.

## Integrity
Fixture Info SHA-256: `2daf75668f90bd3fb933a57727cf3db6ef477e7edeaaa92c10972d4e41973a77`.
Fixture executable SHA-256: `6972c9ca26a6a9ae02fcdd6c6381fe0f9e2b7768b4196f7f1c88a16328ee6fb8`.
Saved layout and capacity remain byte-identical to the pre-Trash snapshot, including after normal restart. Library preference creation/disable was intentional. No launch activity file was created. User/formal data were not used.

## Limitations and maintenance guidance
- Finder recovery is verified by native manual move to the original folder; automatic Put Back was unavailable. Do not advertise automatic restoration or claim it passed. Existing copy says Finder recovery generally, not automatic Put Back. If future UX promises automatic recovery, it requires a separately specified implementation and native verification; do not fabricate private Finder metadata.
- Dormant layout/capacity retention is verified; this profile did not seed alias/manual-category/history deletion-retention scenarios. Those are automated/source evidence only.
- Failure/timeout pending-operation Quit paths, physical APFS case aliases and concurrent external launches are not new native PASS claims.
- No human feature acceptance, realIME/spokenVoiceOver, matched physical60/120Hz/multidisplay/performance or full-parity completion is inferred.
- No install/sign/notarize/publish/commit/reset/clean, privilege/OS/security changes, original reference-code/assets access, real-user application removal or permanent deletion.

## Durable evidence and next action
`.build/verification/20261019/app-removal/native-results-r1.json`, `native-baseline-r1.json` and `native-restored-files-r1.json` preserve this dated supersession. The2026-10-18 final receipt remains the historical not-launched snapshot, not silently rewritten.

This closes only the described controlled native core-path gate. Full goal remains incomplete. Continue an already-approved, unclosed non-destructive acceptance/defect task; retain physical performance, realIME, VoiceOver and historical wallpaper/folder-scroll causality boundaries. Do not repeat closed tests solely to create progress, or implement reserved major features without approval.
