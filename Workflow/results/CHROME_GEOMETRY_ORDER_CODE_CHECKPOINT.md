# Chrome Geometry Order — Code Checkpoint

Date:2026-10-14. CODE_VALIDATED; bounded independent source ACCEPT/no blocking
finding. Full parity INCOMPLETE; GUI/physical screen migration NOT_RUN.

## Scope and reproduction

The Main full-scope audit found layoutSearchField positioned feedback using the
old search frame. An actual unshown search/notice/window fixture called BOTH
production resize and screen-change delegates with a deterministic previous inset
(current +32). Baseline-r1:1 XCTest function/2 anchor failures,584vs616pt. No real
screen migration/window resize, system-delivered notification or visible app was
performed. Baseline log is prepatch evidence, not an independently hashed binary
reproduction. Prior395 source freeze follows the repair, not the red baseline.

Repair: update the search field first, then existing dots/status/feedback layout
calls, synchronously inside the same existing MainActor boundary. No formula,
query, notice-show/clear/deadline, focus/input or physics change. Missing search or
container still permits the existing dependent fallback layout. Two new test
functions cover both delegate cases plus absent-search fallback; query/deadline
state and unshown window assertions are retained. Same-helper expected rectangle
is an ordering oracle, not independent all-screen safe-area formula validation.

## Authoritative gates

| Gate | Result |
| --- | --- |
| Focused-r1 |48 XCTest/0fail at2026-10-14 16:53:44.240JST,2.189s |
| Full-r1 |2419 XCTest/0fail at2026-10-14 16:54:56.855JST,42.056s |
| Debug-r1 |PagingPrototypeApp build exit0 |
| Release/package-r1 |Unique unsigned candidate,exit0; no compiler warning in this log |
| Packaged resource probe |Actual3languages/221required keys/signatures; positive0, two negativefixtures each1/3issues |
| Frozen inputs |395 Source/Test/Script/Package hashes match source-files-r1.sha256/source-check-r1.json |
| Independent review |CHROME_GEOMETRY_ORDER_SOURCE_REVIEW.md ACCEPT for bounded ordering, no blocker; both changed input hashes match |
| Manual kit |Exact binary/resources runner prepared, zsh -n exit0, NOT executed |

Only AppDelegate.swift and new ChromeGeometryOrderTests.swift differ from preceding
394-input checkpoint. No paging/grid/catalog/launch/keyboard/gesture/store/resource
inputs changed. Existing dirty tree/history/candidates preserved. HEAD remains
319b8cc149a8553adfc3414abaacbe28b59d97ef; no commit/reset/clean/install/sign/publish.
The trailing Swift Testing0test output is not the XCTest gate. The focused regex
also contained LauncherUITestWindowTests, for which no matching file was established;
no window-mode suite is credited specifically on that name. Full suite is nonzero.

## Candidate identity

`/Users/mac/Projects/Launch_Copy/PagingPrototype/.build/candidates/chrome-geometry-order-rc-20261014-r1/LaunchcopyUITest.app`

Executable SHA-256: `69e4b411fd633df0e327d6c85bd5daad18abb2705636fe91b75a56029a2c7b60`
Resource manifest SHA-256: `387640e21d8dc8a0ba08aa96a38a36e806d90f17a169e368a6a2098c8e6bc684`

`/Users/mac/Projects/Launch_Copy/PagingPrototype/.build/candidates/chrome-geometry-order-rc-20261014-r1/RUN_ISOLATED_UI_TEST.command`

Supersedes previous activation-diagnostic-isolation runner for current testing.
Only37 synthetic Info.plist bundles copied, no executable apps or old/production
layout/preferences/cache. Candidate-derived namespaces; --ui-test-windowed
--ui-test-profile gui --folder-lab; ordinary, non-topmost window with fake global/
login services. Direct default app launch is not this isolation contract. No app
launch performed. Fixture failures are not proof of real application launches.

## Current native blocker and full scope

Both initial and final current-turn CUA inventories explicitly report Mac locked /
automatic unlock failed. apps[] under that error is not process absence evidence;
separate exact-name checks found no launcher/test process at inspection. The prior
Terminal-control policy denial was not bypassed. Real native/restart/physical gates
require user unlock and normal manual start or an allowed safe launch mechanism.

Current full-scope Main audit is2026-10-14-APPROVED_SCOPE_GAP_AUDIT.md. Library and
configurable capacity remain missing, with their specific contracts still PROPOSED;
icon/type/language approvals do not approve those branches. Usage/suggested/recent,
extra gestures/destructive and distribution have separate decisions. Native visual,
IME/VoiceOver, real activation/launch/source events, accepted-write real restart and
matched physical performance remain incomplete. Timer0ms/validated physical
parameters frozen; >25ms CAUSALITY_UNRESOLVED, no120Hz/newphysicalPASS.

This turn made actual audit/reproduction/repair/test/review/package progress. After
all those jobs and the reviewer completed, no further identified approved source
feature implementation remains available without required contracts or external
native access. The repeated native/start/confirmation blocker has persisted across
menu-mutation, activation-diagnostic and current audit/chrome goal turns. It is not
lack of effort, difficulty or a voluntary pause. Main records goal status through
the goal tool only after artifact/diff checks; never marks full parity complete.

## Runtime goal status — BLOCKED, 2026-10-14

The goal tool returned BLOCKED for thread01a070c3-a1bc-7cf1-87d9-2515137fc6f9.
Full objective unchanged: LaunchBetter UI/functions on Launchcopy, independent
implementation. Not complete, not a user-requested pause. Native safe-start/access
and pending Library/capacity contracts remained unresolved across menu-mutation,
activation-diagnostic and audit/chrome turns; those turns made real source progress.
After the identified repair/audit/verification jobs completed and lock was freshly
rechecked, remaining required actions need user/external change. All agents/jobs
closed; no app running/started or policy workaround credited.

Resume inputs: unlock the Mac and normally start the current isolated runner on
Desktop2; separately confirm Library/capacity proposed contracts before newcode.
Then revalidate actual process/candidate/native state; prior blocked audit does not
carry over automatically. Existing workflow STATE is historical and untouched by
the waived workflow; this status is the real goal-tool state, not an invented PASS.
Current code:48focused/2419full0fail,395hashedinputs, Debug/Release/resources verified;
unsigned candidate69e4b411...; no native/restart/physical/full-parity acceptance.
Details: Workflow/results/CHROME_GEOMETRY_ORDER_CODE_CHECKPOINT.md and
Workflow/results/2026-10-14-APPROVED_SCOPE_GAP_AUDIT.md.

