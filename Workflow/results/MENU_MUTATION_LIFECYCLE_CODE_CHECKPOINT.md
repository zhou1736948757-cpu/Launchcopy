# Menu Mutation Lifecycle — Code Checkpoint

Date: 2026-10-14. Status: CODE_VALIDATED; bounded independent SOURCE_REVIEW_PASS.
Native GUI/restart/physical acceptance: NOT_RUN. Full parity goal: ACTIVE / INCOMPLETE.

## Accepted scope and architecture

SwiftPM/AppKit macOS 14+ launcher; application assembly owns menu callback origins
and the existing management/layout persistence coordinators. This is a bounded
correctness repair to approved stale-callback/validated-action contracts, not a
new menu feature, format migration or paging change. Language remains approved:
Follow System / English / Simplified Chinese / Japanese, with safe live updates.
No reference application code/resources or reverse-engineering assets were read.

## Defects, repair and authoritative evidence

1. Retained mutating menus could write through replaced presentation roots,
   language realms or management stores. Unshown native selector baseline:
   **4 tests / 13 assertion failures**, baseline-r1.log. Added shared weak origin
   assembly/coordinator and root/language epoch guard to every app-menu ingress.
   Existing cell/token/revision/canonical-URL/read-only protections remain intact.
2. Old assignment callbacks could cross an exactly equal layout's writer realm.
   Added layout-restore epoch guard, silent obsolete rejection, and rebinding only
   after current restore completion or management replacement. New tests require
   copied old onApply cancellation even with a permissive binding validator, zero
   old/new-store writes, and successful fresh-menu enqueue to the replacement only.
3. Reviewer F1: an alias editor already open before replacement could confirm into
   a same-revision new assembly or moved canonical URL. Reproduction suite:
   **7 tests / 4 assertion failures**, alias-baseline-r1.log. Confirmation now
   captures weak originating assembly, checks identity/revision/canonical URL and
   both hidden-state authorities before save/error presentation. Existing window,
   root, language, coordinator and duplicate-completion gates/lease release remain.
4. Reviewer F2: injected test presenters retained their fixture. Two weak captures
   repaired the test-only cycle; no weaker assertion or production redesign.

Baseline logs were collected before the corresponding repair; they are not
independently reproduced binary-hash gates. The final source snapshots and full
execution evidence below are separately preserved.

## Final execution and packaging gates

| Gate | Authoritative result/artifact |
| --- | --- |
| Final focused r3 | 69 XCTest tests / 0 failures, 2026-10-14 16:08:57.918 JST; focused-r3.log |
| Final full r2 | 2410 XCTest tests / 0 failures, 2026-10-14 16:13:10.947 JST, 44.485s; full-r2.log |
| Debug r2 | PagingPrototypeApp build exit 0; debug-r2.log |
| Release / unique candidate | package script exit 0; release-package-r1.log |
| Packaged resources | Strict actual-bundle probe: 3 languages, 221 required keys/signatures; positive exit0, missing-action-key and invalid-login-template each exit1/3 issues; packaged-resource-results.json |
| Frozen inputs | 392 Source/Test/Script/Package files match source-files-r2.sha256; source-check-r2.json |
| Independent review | MENU_MUTATION_LIFECYCLE_SOURCE_REVIEW.md Final R2: bounded source PASS; reviewer did not execute tests/build/app |
| Diff whitespace | git diff --check exit0; diff-check-r1.log |
| Manual runner syntax | zsh -n exit0; runner-syntax.log; runner NOT executed |

Trailing Swift Testing "0 tests" lines are not the XCTest gate. Earlier full-r1
also had 2410/0 but preceded final test-fixture cleanup; final acceptance uses r2.
Release retains a pre-existing diagnostic non-Sendable MultitouchSupportBackend
capture warning at AppDelegate.swift:1989. The prior release log contains the same
warning. This checkpoint does not claim zero warnings or Swift 6 readiness.

HEAD: `319b8cc149a8553adfc3414abaacbe28b59d97ef`.
Only AppDelegate.swift and new MenuMutationLifecycleTests.swift differ from the
previous 391-input action-feedback checkpoint. PagingCore, PagingUI, AppGridUI,
AppCatalogCore/MacAppCatalog, AppLaunchController, keyboard adapter, Package.swift
and localization sources/resources are unchanged in this wave. Existing broad
Git dirty state/history/candidates are preserved; no commit/reset/clean performed.

## Exact current candidate

Unsigned app:
`/Users/mac/Projects/Launch_Copy/PagingPrototype/.build/candidates/menu-mutation-lifecycle-rc-20261014-r1/LaunchcopyUITest.app`

Executable SHA-256:
`469e19aefd58235bb375caceae997d9b8700f6e0bdc6bcedb13232bdc33b0394`

Localization resource manifest SHA-256:
`387640e21d8dc8a0ba08aa96a38a36e806d90f17a169e368a6a2098c8e6bc684`

Runner:
`/Users/mac/Projects/Launch_Copy/PagingPrototype/.build/candidates/menu-mutation-lifecycle-rc-20261014-r1/RUN_ISOLATED_UI_TEST.command`

Supersedes earlier language-action-feedback runner for current-source testing.
No signing, notarization, installation or application launch performed. The kit
copies only 37 synthetic Info.plist-only bundles and verifies exact executable
and all resources before supplying ordinary/non-topmost --ui-test-windowed,
--ui-test-profile gui and --folder-lab. Preferences use distinct candidate-derived
hashed suites; no original arrangements/preferences/catalog were copied. These
fixtures cannot prove real NSWorkspace app launch, real global services or disk
restart durability. Do not start the app without the profile flags.

## Native state and user authorization

User first chose to start manually later, then said the original Launchcopy had
been closed and authorized reopening if needed. Fresh CUA inventory showed no
running Launchcopy or test app, not GUI acceptance or an unlocked-window proof.
Attempting to select Terminal returned a concrete policy denial:
"Computer Use is not allowed to use the app 'com.apple.Terminal' for safety reasons."
No Terminal operation or alternate shell/Finder/default-mode launch followed.
Manual current runner remains the supported next step; no repeated async question
was sent after the user's deferral. At this checkpoint no test instance is running.

## Full objective and next actions

- Exact-candidate native language Apply/reopen, IME/unfinished drafts, menu tracking,
  picker/recording/modal ownership, alias/folder/notice visuals and VoiceOver still
  need real observation. Fresh-process persistence needs a normal test-instance
  quit/reopen, not an in-memory actor or test suite substitute.
- Keep physical paging parameters and Timer tolerance 0ms unchanged; >25ms remains
  CAUSALITY_UNRESOLVED. Current migration performance/120Hz are not physical PASS.
- Specific App Library and row/column capacity proposals remain unconfirmed; usage,
  extra gestures/destructive actions and distribution have separate decisions.
  Approved language and current code tests do not waive those requirements.
- Reopen only the isolated current runner/profile when native access allows or the
  user starts it normally. Never overwrite production data or route around denial.

This turn produced concrete source/test/review/package progress; neither full-goal
completion nor the repeated-blocker threshold is satisfied. All current helper
agents are closed. Durable project memory/plan/ledger have the latest checkpoint.
