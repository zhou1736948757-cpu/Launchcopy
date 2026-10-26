# Wallpaper cell-fill follow-up

- User reports dark boxes behind apps after host repair.
- Main now visually verified the prior candidate: wallpaper is visible; individual app cell backgrounds remain opaque.
- Scope: initial/idle/unfocused/reused cell fill only; keep focus indication and interaction geometry.
- Single sol/high implementation Worker, independent Luna/max review, serialized builds. Continuing prior task-scoped override; permanent config unchanged.
- Next: synthetic fail-before/pass-after test, minimal patch, targeted regression, review, Release candidate and real screenshot.
- Previous full-suite baseline debt remains unchanged and separate; no claim of overall green or phase-wide completion.

## Result and verification

- Exactly two production substitutions: AppGridCellView init background and AppGridCellFocus.setFocused(false) background now nil. Focused selected fill/accent ring and accessibility setters unchanged. Hit bounds, drag, binding, paging, folder identity, and prior PageHostView patch unchanged.
- Added CellBackdropTransparencyTests.swift: 3 synthetic-pixel cases exercising six idle/clear/folder/rebind states. Main inspected before/after app rebind PNGs: dark card before; backdrop visible after.
- Updated only 3 existing idle-fill expectations in AppGridCellFocusReuseTests.swift to match the requested transparent idle contract; other reuse/focus assertions retained.
- Targeted 15 tests / 0 failures (new3 + focus/reuse3 + folder9).
- Fresh full suite: 1528 tests / 12 failed assertions in same seven cases as the previous patched1525 and original1522 runs. No new failing case observed. Full suite is not globally green.
- Release build exit0 (8.09 seconds); candidate smoke exit0; git diff --check clean.
- Scoped independent Reviewer PASS: Workflow/reviews/T-WALLPAPER-CELL-FILL-r1.md.
- Candidate: .build/cell-backdrop-20260911/Launchcopy.app. Executable SHA-256: 246adc55f107a425437cbe1fd2bec638479b571e10becd1605017117a3c8e4a6.
- Existing bundles retained; no package-app.sh, process kill, signing, commit, push, or publication.

## Real GUI gate

Main attempted to refresh the running previous candidate before switching. Computer Use reported that the Mac is locked and requires manual user unlock. No unlock attempt, further UI interaction, quit, or new-candidate launch was performed after that result. GUI verification of the cell-fill patch remains BLOCKED_BY_LOCKED_SESSION / PHYSICAL_ACCEPTANCE_PENDING.

Next: user unlocks Mac; normally quit old Launchcopy and open .build/cell-backdrop-20260911/Launchcopy.app. Inspect default cells for no dark rectangles, then focus/unfocus and page away/back to ensure they do not reappear. Retain the distinct keyboard focus highlight.

## User acceptance — 2026-09-11 (supersedes pending black-box gate)

User explicitly stated: “黑框没问题，我验收通过”.

Status: PASS_USER_REPORTED for the app-cell dark-box repair. T-WALLPAPER-CELL-FILL is accepted and may close. The earlier locked-session/tool limitation is retained as history, not an active blocker for this scoped user acceptance.

The preceding candidate path/hash remains the engineering delivery reference, not a newly observed running-binary measurement from this reply. No new screenshot, per-step gesture log, or full manual matrix was supplied. Do not infer acceptance of all keyboard/drag/persistence/performance cases or all Phase 1I work. The seven legacy failing test cases and other unrun hardware gates remain open.

Next: Phase 1J reconciliation carries this scoped acceptance forward; do not repeat it solely because the earlier tool session was locked. Candidate changes affecting cells still require normal regression checks.
