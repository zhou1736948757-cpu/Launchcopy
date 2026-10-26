# Controlled real application launch — native verification

Date: 2026-10-15. Goal ACTIVE/incomplete. Previous goal turn PROGRESS (actual repaired-candidate root-loss/retry gate and transient backdrop recovery). This stage verifies an existing approved core launch requirement; no new product feature or interface contract.

## Scope / safety
Main exclusively owns one standalone AppKit fixture build and native interactions. No agents dispatched: the task is a short serial native launch/quit transaction with process-identity dependencies, no useful disjoint source implementation. User has authorized use of the computer, isolated test profile and normal quit of owned instances. Current 66cd55c1 unsigned/uninstalled candidate and all product inputs remain unchanged.

Own authored .build verification Swift source produces only a titled window, static success text and normal Quit button. No file IO/network/preferences/process/event control in fixture. No UI automation through shell, no signing/install/reference code/resources, no ordinary apps or formal data. The fixture remains within candidate-local staging or watched Applications; no personal data used.

## Acceptance / anti-false-positive controls
1. Verify candidate and fixture executable process absence before the click.
2. Build fixture separately with local SDK, save compiler receipt/hash; no product rebuild/SwiftPM changes.
3. Move fixture into own allowed source, open exact existing isolated candidate via supported CUA, observe named cell. Never call getApp on fixture before launch evidence: it could launch it and invalidate the test.
4. Real grid click -> exact fixture process appears before CUA binding; then inspect actual fixture window and success label. Attributed to native click + public launch adapter, not a mocked launcher.
5. Normal own fixture Quit and exact executable absence; restore fixture to staging and original empty source/query. Quit own launcher normally, verify absence.
6. Leave gate open if CUA denies/locks, launch fails or fixture origin is ambiguous. Do not bypass security prompts or use shell open/AppleScript/NSWorkspace helpers to manufacture success.

## Boundaries
No broad launch success, external app compatibility, quarantine/signature/notarization, multiple OS versions, physical paging/performance, Library-specific route or whole parity claim from this single grid test. Wallpaper transient recovery is not a repair. Pending unapproved product branches and physical gates remain.

## Evidence (pending)
.build/verification/20261015/controlled-native-launch/: source, compiler log, identity/cleanup receipt. Main must append actual result and next action; no independent live Reviewer claim.

## Grid PASS and Library-route extension

Existingapproved Library Open requires samevalidatedpubliclauncher. Extend this native protocol to its specificroute (no feature/code/contractchange). Main temporarilyenabledLibrary usingisolatedsettings, initialfalse; restorefalse viaUIaftertest. GridclickbeforeanyfixtureCUAbind producedexactfixturePID72080 fromabsence, actualcontrolledsuccesswindow; normalQuit/exactabsence. MainlauncherPID71877 unchanged. NextLibrarydetailsOpenwithfreshabsenceguard; boundresultonlytospecificroute, notgeneralLibraryacceptance. No independentReviewerclaim.

## Current checkpoint — 2026-10-15 real application launch gate

GoalACTIVE/incomplete. Previous/currentturnPROGRESS. Existing66cd55c1 candidate/MainPID71877, all455inputs unchanged. OwnminimalAppKitfixture compiledseparately (Swift6 strictconcurrency/warnings-as-errors,exit0/0output), no prodsource/build/packagechange. Actualgridclick ->newfixturePID72080 BEFOREfixtureCUAbind; actualsuccesswindow/text; normalQuit/exactabsence. ActualLibrarydetailsOpen ->newPID72895 BEFORErebind; actualsuccesswindow; normalQuit/exactabsence. MainnativeboundedPASS forbothroutes; no independentliveReviewer/fullparity/physicalclaim. LibrarytemporaryOn restoredOff viaUI/savedack; fixturestaged/notdeleted/sourceempty/queryempty; ownlauncher normalQuit/exactabsence/no postQuitappquery. No jobs/agents/ownapps/faults. Backdropreadywithwarmcache, originalintermittentstallNOT_FIXED. Fullresult Workflow/results/CONTROLLED_NATIVE_LAUNCH_RESULTS.md; stage2026-10-15-controlled-native-launch.md; receipts.build/verification/20261015/controlled-native-launch/. Nextunclosedgates shouldretainfullscope/pendingapproval/physical/performanceboundaries, notduplicatebuildsorclaimcomplete.
