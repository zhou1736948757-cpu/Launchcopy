# Activation diagnostic isolation — bounded correctness/performance repair

Previous goal turn: concrete menu/alias repair progress,69focused/2410full0fail,
392-input freeze/candidate verified; not full goal completion.

## Approved contract and proportional scope

PARITY_SPEC §5 requires diagnostics opt-in and no unnecessary frame/startup work.
Current AppDelegate installs an unconditional 2s diagnostic Timer, a 1s diagnostic
callback and fourfinger stdout writes; ActivationComposition formats/flushes
recognized gesture diagnostics unconditionally. The launcher also runs a delayed
2s catalog "diagnostic/repair" that directly changes Core page count/reloads UI
outside the current idle-boundary catalog path. These are contract defects, not
new product/CLI feature requests. Use existing explicit --paging-lab diagnostic
mode for neutral activation diagnostics; no new flag, persistence/API migration,
private gesture semantics, paging parameters or launch path.

Main owns immediate source/test repair and serial verification. Sidecar Darwin
owns approved-scope gap report only (no overlapping source writes). Max3 including
Main; inherited models, Chief workflow waived. Agent429 is a recoverable attempt
and same-agent continuation was sent; no replacement. No reference/global-memory
reads, app launch/process control/install/sign/commit/reset/clean. RTK required.

## Repair and acceptance plan

- Default production has no activation diagnostic timer/sink/formatting/stdout.
- Optional neutral lab diagnostics have one owned MainActor timer, weak origin,
  generation guard and explicit stop; stale delivery/deinit/teardown cannot leak
  work or callbacks into replacements. No unchecked Sendable backend capture.
- Remove delayed catalog repair; retain current authoritative callback/bootstrap
  commit and UI application. Diagnostic enablement must never mutate UI/Core.
- Remove unconditional teardown stack disclosure, not replace with raw identities.
- Test actual synthetic recognizer routing with no native window, default silence,
  opt-in callback/timer, replacement/stop/delayed delivery; existing catalog and
  launcher integration regressions; independent bounded source review.
- Final full XCTest, Debug/Release, source/candidate/resource identity gates. GUI,
  production hardware gestures/restart/physical AB remain separate unproven gates.

Native access remains: user authorized reopening, but CUA Terminal selection is
denied; no workaround. Latest manual runner prepared, not executed. Library/
capacity specific proposals remain pending, not silently removed from full scope.

## Execution checkpoint

- baseline-r1 compile error (test used wrong PinchFramePhase spelling); baseline-r2
  fixture crash (NSApplication.shared not initialized). Neither counts as reproduction.
- baseline-r3 authoritative: 1 XCTest / 1 assertion failure; actual synthetic
  recognizer with pure visible coordinator and no window wrote default stdout.
- Default sink now nil; lab-only owned MainActor timer; raw backend capture and
  delayed start diagnostic removed. The separate 2s Core/UI repair and raw
  teardown stack print removed; authoritative catalog callbacks remain.
- Final focused-r3:93/0 including actual catalog/status/source, gesture/backend and
  prior menu/action routes; new7 diagnostics tests use unscheduled timer factory,
  fake library/device, generated contacts and no launcher window.
- Source394-input freeze captured; full-r1:2417/0. Current Debug/Release/source
  review/package still require authoritative completion. No physical/hardware PASS.
- Gap auditor Darwin hit429; same-agent send-input, wait and resume attempts returned
  the same verified errored state. No report exists or is claimed; do not treat
  unexecuted audit as progress or spawn duplicate recovery without reason.

## Final evidence and recovery clarification

Final focused93/0/full2417/0; Debug/Release package exit0;394inputs match, actual
221-key3language strict probe and2negativefixtures pass; independent bounded
source PASS with4current hashes. No compiler warnings in final build logs.
Candidate activation-diagnostic-isolation-rc-20261014-r1 + exacthash isolated kit
prepared/syntaxchecked NOTexecuted. Whole native/restart/physical/fullscope gates
remain unproven. See ACTIVATION_DIAGNOSTIC_ISOLATION_CODE_CHECKPOINT.md.

Darwin's final authoritative close result was completed with an inability-to-
resume response and no report, after the earlier verified429 states; not another
new429 or a completed audit. Recovery wording was misunderstood, not feature
evidence. Auditor closed without replacement or claimed contribution. McClintock
completed bounded source review and is closed. Main alone; goal active/incomplete.
