# Folder Scroll No Response — Bounded Diagnostic Source Review

Date: 2026-10-17
Role: independent reviewer
Verdict: **PASS — source-only, bounded diagnostic/test review. No actionable defect found in the assigned additions.**

## Scope and controls

Read `/Users/mac/.codex/RTK.md` and project `AGENTS.md`. The human waived the Chief ceremony. Main retains all build, UI, process, integration, and full-suite responsibilities. No agents were dispatched. This review performed file reads, manifest comparison, and source hashing only; no tests, builds, UI interaction, process inspection/control, or Git operations were performed. The only authored file is this report.

The project is a SwiftPM macOS AppKit application. AppDelegate owns window routing and application admission, AppGridUI owns the folder overlay, PagingUI owns the inner input/frame controller, and PagingCore owns paging state/physics. Review is limited to the isolated AX diagnostic block in `installFolderWindowInput`, the new `testFolderSmallScrollEventsSurviveProductionLikeChromeLayoutRefresh`, and its private `FolderScrollLanguageStore`. Supporting existing source was read only to interpret those additions. Older unrelated changes are outside this verdict.

## Input identity

Compared `.build/verification/20261017/folder-scroll-no-response/source-before.json` and `source-after.json`: both contain 475 entries, and exactly two entries differ. Current bytes of both files match their after-manifest hashes:

| File | SHA-256 |
| --- | --- |
| `Sources/PagingPrototypeApp/AppDelegate.swift` | `9bb359d93351b5d8d5a7ba3505f54d9eb73d8fa3afc606895e850c37407de4e5` |
| `Tests/PagingUITests/AppDelegateBoundedRegressionTests.swift` | `2ac91c0ef8f92d3df79c084369ccd11ac3b3af4365af42872ea59a95e59a1786` |

These hash manifests establish the changed file set within their recorded inventory. They contain no before-source text, so exact insertion-only attribution comes from the task's declared scope; this review does not claim an independently reconstructed historical patch or whole-tree equivalence.

## Source assessment

### Diagnostic block

`AppDelegate.swift:934-942` executes after the existing `overlay.scrollWheel(with: event)` call. Its `uiTestProfile != nil` guard uses the resolved isolated-profile object, rather than merely the requested command-line option. The surrounding closure retains its weak owner capture and resolves the live overlay at event time.

The added block writes only phase/momentum flags, axis booleans, application admission, transition/availability, core state, normalized offset, and inner-page index to the existing title button's accessibility Help. State is a fixed-case enum. No path, application/folder identity, title, event location, persistent output, or event monitor is introduced by the block. It adds no input delivery, cancellation, configuration, commit, or physics call. The application's current admission closure (`AppDelegate.swift:995-1004`) reads readiness state without mutating it, so evaluating it again does not introduce an admission side effect in the inspected wiring.

One qualification to “observation only”: `overlay.trackpadPager` is a lazy getter (`FolderOverlayView.swift:132-148`). A rejected event before the first usable gesture can therefore allocate the existing inert pager and its callbacks in an isolated instance. Construction does not start input or a frame timer. This is a bounded instrumentation effect, not a scrolling repair or an identified regression. Per-event AX updates also mean this candidate should not establish performance equivalence.

### Added regression test and store

`AppDelegateBoundedRegressionTests.swift:851-887` uses the existing content-before-window fixture and real window event-routing seam. It supplies synthetic catalog/folder content, injects a nonpersistent language store, establishes chrome geometry, and forces host layout after each of 30 small horizontal changed events. Assertions require continued inner activity, meaningful inner displacement, unchanged outer displacement during tracking, and agreement between overlay and owner on committed inner page 1 after release/settling.

The deferred cleanup removes language presentation observers and tears down the fixture; the new layout closure captures the owner weakly. The private MainActor store (`1013-1017`) returns defaults and treats saving as a no-op success, without retaining the supplied preferences or adding persistence. This is suitable for this test, which does not exercise save/reload semantics.

The test is a useful characterization/regression guard for a supported event sequence across repeated layout refresh. Automatic frames are disabled and settling is advanced explicitly, so it does not test native timer delivery or physical momentum. Its fixture has no resolved UI-test profile, so it does not execute/assert the new AX block. It also does not simulate an actual viewport change during tracking. These are coverage boundaries, not defects requiring expansion of this bounded task.

## Diagnostic interpretation and causality

- `admitted` is the application callback's result **after** event handling. It neither captures the callback's earlier result nor summarizes all overlay eligibility guards. It must not be described as proof that this particular event was accepted by the pager.
- `dominant` literally evaluates `abs(x) >= abs(y)`, so zero/zero reports true; it must be interpreted alongside `horizontal`. Phase flags remain raw values, and `page` is zero-based.
- Help is overwritten after routed events, not continuously during later frame ticks. The stored state/offset can lag asynchronous settling. A particular event snapshot or unchanged Help is not a complete input history.
- Nothing in these additions establishes why the original instance stopped responding. Passing the new test and a successful later physical gesture cannot establish a behavioral fix or isolate restart/handover as the cause.

No false repair/root-cause claim was found in the inspected diagnostic comments, test name, or recorded confirmation interpretation. No speculative orphan-session behavior change is requested.

## Existing evidence, not independently executed

Read the existing `owner-small-events-r1.log`: XCTest reports this named test passed, with **1 executed / 0 failures**. The trailing Swift Testing runner's zero-test message is a separate runner and does not invalidate that XCTest execution. This reviewer did not rerun or certify the execution environment.

Read `physical-user-confirmation-r1.json`, alongside the human evidence supplied in the task. It records candidate `folder-scroll-diagnostic-rc-20261017-r2`, human confirmation “成功了这个” after actual two-finger swipes, post-event AX `state=idle; offset=1.0; page=1`, and outer page `1 of 2` unchanged. This supports bounded physical success on that candidate as reported by Main/human. It is not independent native observation by this reviewer, proof of the original cause, or evidence of a behavior-changing repair. The recorded interpretation correctly preserves that distinction.

## Findings and handoff

**Actionable findings: none within the assigned additions.** Source verdict does not certify the wider dirty tree, the candidate binary/source relationship, full-suite results, native performance, or absence of future recurrence. Main owns the concurrent full-suite and documentation closeout; no implementation change is requested by this review.
