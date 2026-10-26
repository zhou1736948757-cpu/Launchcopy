# Activation Diagnostic Isolation — Code Checkpoint

Date: 2026-10-14. CODE_VALIDATED; independent bounded SOURCE_REVIEW_PASS.
Goal remains ACTIVE / INCOMPLETE. Exact-candidate GUI, device, restart and physical
performance: NOT_RUN. Previous checkpoint: MENU_MUTATION_LIFECYCLE_CODE_CHECKPOINT.md.

## Concrete mismatch and bounded repair

The approved parity specification §5 requires diagnostics opt-in and performance
preservation. Production assembly previously created a repeating 2s four-finger
diagnostic Timer, a 1s backend-report callback, and unconditional stdout formatting/
flush on recognized gesture events. A separate delayed 2s "catalog diagnostic/repair"
changed Core page count and reloaded/layouted the surface regardless of input state.
It was outside the authoritative catalog/idle-boundary update path. Raw teardown
stack output was also unconditional. These are concrete source mismatches, not
proof that they caused a particular observed physical frame hitch.

- Default production constructs no four-finger diagnostic owner, timer or sink.
  The nil callback short-circuits counting/formatting/output in recognition.
- Existing explicit `--paging-lab` supplies the optional neutral observer. No new
  CLI flag, user-facing feature, store schema, identity or preference migration.
- New internal MainActor FourFingerDiagnostics holds a weak composition, one owned
  Timer and a generation. Replacement/stop reject retained ticks and callbacks;
  host stop precedes service teardown. Timer does not capture a non-Sendable backend.
- Optional samples contain only counters/typed states/bounded startup details.
  No application names, canonical URLs, paths, coordinates or raw contact records.
- Removed the delayed catalog Core/UI mutation rather than hiding it behind a
  diagnostic switch. Current startup snapshot delivery, non-busy scan completion,
  idle commit callbacks and already-served bootstrap reload remain authoritative.
- Removed raw teardown stack output. Other existing error/telemetry/startup output
  is outside this bounded slice; not a whole-application zero-I/O certification.

Four-finger provider attachment, preferences, recognizer process/flush/adopt/apply,
window behavior, paging parameters and Timer tolerance 0ms remain unchanged.
No reference source/resources, Buho notes or raw evidence were read or copied.

## Authoritative execution and evidence separation

Evidence root: `.build/verification/20261014/activation-diagnostic-isolation/`.

| Gate | Result |
| --- | --- |
| Behavioral prepatch baseline-r3 | 1 XCTest / 1 assertion failure: actual synthetic recognition wrote default `paging-fourfinger-` output; pure visible state and no native window |
| Final focused-r3 | 93 XCTest / 0 failures at 2026-10-14 16:31:20.788 JST,4.970s; includes actual catalog/status/source, gesture/backend and prior menu/action suites |
| Final full-r1 | 2417 XCTest / 0 failures at 2026-10-14 16:32:39.422 JST,42.701s |
| Debug-r1 | PagingPrototypeApp build exit0 |
| Release/package-r1 | Unique unsigned candidate assembled,exit0; no compiler warning in this run's log |
| Actual packaged resources | 3 languages,221 required keys/signatures; positive exit0,missing-action-key and invalid-login-template each exit1/3issues |
| Source freeze | 394 Source/Test/Script/Package files match source-files-r1.sha256/source-check-r1.json |
| Independent review | ACTIVATION_DIAGNOSTIC_ISOLATION_SOURCE_REVIEW.md: bounded source PASS; all4 changed source/test hashes match final freeze; no test/build/runtime execution by reviewer |
| Manual runner | Exact binary/resources verified in prepared runner; zsh -n exit0; NOT executed |

Trailing Swift Testing zero-test output is not the XCTest gate. Earlier baseline-r1
had a misspelled PinchFramePhase compile error; baseline-r2 lacked NSApplication
initialization and crashed in a fixture. Neither is valid production reproduction.
Their artifacts are retained. Focused-r2 was60/0 but did not include the nonexistent
CatalogStatusRuntimeTests filter; focused-r3 explicitly includes the real suites.
Two local weak-variable warnings were fixed with a test-only weak LifetimeProbe.
The previous default-backend capture compiler warning is absent after removing
that capture, not after adding unchecked Sendable or migrating the toolchain.

Seven new behavioral tests use generated contacts, injected fake library/devices,
unscheduled Timer factories and manual ticks. They verify real recognizer firing,
default stdout-prefix silence/no observer, opt-in reporting, replacement/stop,
missing/stopped backend and deallocation. A pure already-visible coordinator means
no test here orders a launcher window. These prove code paths, not real hardware
activation, RunLoop delivery, native hidden-to-visible transition or physical AB.

## Current source and candidate identity

HEAD: `319b8cc149a8553adfc3414abaacbe28b59d97ef`.
Exactly4 inputs changed relative to the preceding392-input checkpoint:
ActivationComposition.swift, AppDelegate.swift, new FourFingerDiagnostics.swift
and new FourFingerDiagnosticIsolationTests.swift. Frozen paging/catalog/grid,
launch-controller, keyboard, Package and localization inputs are unchanged.
Existing broad dirty tree/history/candidates preserved; no commit/reset/clean.

Candidate:
`/Users/mac/Projects/Launch_Copy/PagingPrototype/.build/candidates/activation-diagnostic-isolation-rc-20261014-r1/LaunchcopyUITest.app`

Executable SHA-256:
`759e57cd2f34ebe77af30135829c9491d8990f9c3ebf73b98b682887dcaf2792`

Resource manifest SHA-256:
`387640e21d8dc8a0ba08aa96a38a36e806d90f17a169e368a6a2098c8e6bc684`

Current runner:
`/Users/mac/Projects/Launch_Copy/PagingPrototype/.build/candidates/activation-diagnostic-isolation-rc-20261014-r1/RUN_ISOLATED_UI_TEST.command`

Supersedes the menu-mutation-lifecycle runner for current-source testing. Only37
synthetic Info.plist-only bundles copied; no old layout/preferences/cache or original
app data. Candidate-derived isolated suites, --ui-test-windowed --ui-test-profile gui
--folder-lab; ordinary/non-topmost, no cross-Space presence or autoactivation.
The app name alone is not isolation: use the runner, not a direct default app start.
These fixtures have no executable and cannot prove real application launch.

## Native boundary, helper outcomes and remaining goal

User authorized reopening after closing the original app. Prior fresh CUA inventory
showed neither app running, but Terminal selection was denied by tool policy. No
alternate shell/Finder/default-mode launch was used, no test instance started, and
no installation/sign/notarization occurred. The prepared current runner remains a
normal user-start option; no repeated async startup request was sent this wave.

Source reviewer McClintock completed its assigned report and is closed. The separate
approved-scope gap auditor Darwin initially hit429; same-agent recovery attempts
were made. Its final returned response described inability to resume another agent
and produced no audit report. It is closed; that sidecar is NOT an accomplished
scope audit. No replacements or invented report/evidence are claimed.

Next real checks: initial/late catalog readiness while input is active; language
Apply/reopen, IME/drafts/menu/picker ownership; hide/reopen, activation preference
changes and normal Quit; UI/VoiceOver, actual application launch, fresh-process
persistence and matched physical performance. The diagnostic repair removes work
by source evidence only: >25ms remains CAUSALITY_UNRESOLVED; no120Hz or current
physical-regression PASS. Library/capacity specific contracts and usage/additional/
destructive parity decisions remain pending; the full goal is not narrowed to
this code-tested subset. This turn is concrete implementation/evidence progress,
not a repeated no-progress blocker or completion audit.
