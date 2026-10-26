# Controlled native context actions — results

Date: 2026-10-15. Main bounded native PASS on exact79002dc4 candidate; no independent live Reviewer/full physical acceptance.

## Identity / anti-false-positive controls
Candidate: `.build/candidates/appearance-store-unavailable-rc-20261015-r1/LaunchcopyUITest.app`.
Executable SHA25679002dc4eb582358c64dc7937d932c69b090067deb5001eaf9480bcd44b0e473. Main process99555 first, normalQuit/verifiedabsence, then792 fresh restart; native healthy appearance64/16 restored/default48/11Apply acknowledged.

Fixture in own gui Applications: locally authored NativeLaunchProbe binary SHA2566972c9ca26a6a9ae02fcdd6c6381fe0f9e2b7768b4196f7f1c88a16328ee6fb8; source hash matched earlier controlled-native-launch receipt. Only own Info metadata changed to unique context-probe ID/name; static window title remains Native Launch Probe by design. No external code/resources or new signing/install. New profile before first startup; original profile not copied/overwritten.

## Actual Reveal
Inventory APIs supplied no Finder window IDs. Supported native Finder created a new own window in the newly created candidate Applications directory. An authored plain control file was single-selected (never opened), so the expected app was **not** already selected. In Launchcopy, actual right-click on the own app -> `management.reveal` -> Finder selection changed to the exact probe bundle in that owned path. No direct helper/shell/opening user files manufactured the result. Closed only that own observed directory window; original focused Finder header matched the session-only baseline again. The original header/path/file list was not copied into project diagnostics and temporary observation variables were cleared. No all-window ID census claim.

## Actual context Open / residency
Exact probe executable absent immediately before real context menu `management.launch`. Afterwards the launcher observation returned noWindowsAvailable, but exact probe PID2739 appeared before its first CUA bind. Actual fixture window contained Controlled launch succeeded; native Quit button then exactabsence.

Main launcher remained exactly PID792 with no window: consistent with the existing successful-launch->resident-hide behavior, not an inferred crash. To finish normal cleanup without killing it, a second own Finder window navigated to the exact candidate directory and invoked its observed Open action on the .app (not any script). Exact mainPID792 verified before rebinding; launcher window returned. Normal own application-menu Quit/exactabsence followed, with no later app query. Closed only the own candidate Finder window; original focused header restored again.

## Final state / limits
Native-default appearance restoration acknowledged; query empty; own fixture/control file retained. Main and fixture executables absent, no test/agent/job/fault left. Source455 and candidate hashes unchanged after native actions. No original app/data/permissions/wallpaper/signing/install/publish/commit/kill/delete.

This proves these two context actions and the stated resident reopen flow on one controlled program/current OS. It is not arbitrary app/quarantine compatibility, real factory-nil occurrence, power-loss durability, spoken VoiceOver or physical frame/gesture performance. Wallpaper currentready is transient recovery, not a causal repair. Full goal remains ACTIVE/incomplete.

Receipt: `.build/verification/20261015/appearance-store-unavailable/native-context-actions.json`.
