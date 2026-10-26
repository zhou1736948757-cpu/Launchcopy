# Page-Dot Hidden-Ancestor AXPress Review

Date: 2026-10-13. Independent bounded review of existing maintenance.

## Verdict and scope

**PASS — source only.** No actionable correctness or scope finding was identified in the inspected hidden-strip/hidden-ancestor AXPress repair. This verdict does not approve VoiceOver, GUI, physical input, performance, or a packaged candidate.

The project is a macOS 14+ SwiftPM/AppKit application: PageDotsView is bounded presentation chrome, AppDelegate arbitrates page requests, PagingSurface forwards accepted requests to PagingCore, and XCTest supplies source-level/native-action regressions. This review inspected those existing seams only as needed for the repair.

Main identifies the incremental implementation change as replacing the own-view `!isHidden` predicate in `PageDotButton.accessibilityPerformPress()` with `!isHiddenOrHasHiddenAncestor`, retaining `isEnabled`. Main also added two tests. The files are untracked in this checkout, so a tracked Git diff cannot independently establish the complete previous-candidate delta. The assessment below is of the current source, the reported bounded delta, and the actual red/green logs; it is not certification of every dirty file.

The independently proposed icon/type specification remains pending user approval and was not reviewed as implemented. No reference application, reverse-engineering evidence, or reference assets were opened. No old formal routing was initiated.

## Findings and correctness assessment

No blocking findings.

- **Reject before native state/action effects.** `Sources/PagingPrototypeApp/PageDotsView.swift:227-232` returns false when disabled or when the button or a superview is hidden, before `performClick(nil)`. This matters because the page buttons use native push-on/push-off state (`:45`). Under the old guard, a hidden strip could still allow the native toggle before `requestPage` rejected the hidden strip (`:199-206`), leaving the selected button off. A hidden outer container could allow both the dot request and window browsing because those handlers check the strip's own visibility, not every ancestor. The new entry guard covers both failures.
- **Common protection for all controls.** Both the nine reusable page buttons and the previous/next window buttons are PageDotButton instances (`:24-25`, `:41-54`). The guard therefore covers dots and both browsing directions. It preserves own-button hiding and disabled rejection; it does not rewrite owner enablement or add stored visibility state that could become stale.
- **Visible native dispatch remains intact.** For an enabled, visible hierarchy, AXPress still calls `performClick(nil)` exactly once and reports handling. The Bool is not an asynchronous navigation success result. `requestPage` refreshes committed selection before invoking the callback (`:199-206`); window actions only change the displayed page window (`:209-221`). AppDelegate retains lifecycle/input/count checks and clears focus only after acceptance preflight (`Sources/PagingPrototypeApp/AppDelegate.swift:2230-2262`). Surface retains its existing request/driver seam (`Sources/PagingUI/PagingSurface.swift:276-287`). No synthetic gesture, chained adjacent navigation, or second action route was added.
- **Appropriate scope and no added loop.** The repair is an event-time native visibility query. It introduces no custom ancestor traversal, polling, observer, timer, recursive action, per-frame refresh, or new navigation loop. This is not a claim that AppKit's hierarchy query has constant cost or that frame performance has been measured.
- **Defaults and existing behavior are preserved within this delta.** Current source retains the initial hidden/disabled presentation, hiding for zero/one page, nine-dot/two-control bound, absolute identifiers, committed selection, equal-update short circuit, 24-point buttons, 4-point spacing, 8-point inset, 32-point strip, material policy and responder refusal (`PageDotsView.swift:14-20`, `:39-54`, `:67-84`, `:124-169`). The predicate substitution does not change these values or Core/Surface paging parameters. Existing tests cover native single dispatch, selected-page dispatch, synchronous commit, disabled owners, count shrink/clamping, Int.max, window traversal, reuse, materials, layout and focus. Green execution supports these covered cases, not a universal absence of regression.

## Regression design and red/green evidence

The two added tests exercise retained real NSButtons through `accessibilityPerformPress()`, rather than a helper duplicating the predicate:

1. `Tests/PagingUITests/PageDotsViewTests.swift:90-102` hides the strip while its selected child remains enabled and locally visible. It requires false handling, no callback, and unchanged `.on` selection, then unhides the strip and requires exactly one selected-page callback.
2. `Tests/PagingUITests/PageDotsViewTests.swift:104-121` mounts a 30-page strip under an NSView, hides that outer view, and presses a dot and the enabled next-window control. It requires false handling, no requests and unchanged absolute tags. After showing the ancestor, the retained dot must dispatch page 8 exactly once. The tags assertion detects silent hidden window browsing even though browsing itself does not request navigation.

All logs below are under `.build/verification/20261013/icon-type-discovery/`. The reviewer read existing logs and did not execute tests.

| Evidence | Independently observed log result | Interpretation |
| --- | --- | --- |
| `hidden-ax-red.log` | Two XCTest cases, seven assertion failures; suite ended 22:33:38.838 | Ancestor case fails at current test lines 114, 115, 116, 117 and 120: hidden actions report true, issue a request, shift tags to 9...17 and later yield requests `[8, 17]`. Strip case fails at lines 96 and 98: true handling and selected state off. This matches the diagnosed native-action side effects. Attribution to the old predicate is Main's supplied baseline history; the log does not embed the old source. |
| `hidden-ax-focused.log:97-100,141-142,171-173` | Both new cases pass; PageDotsViewTests 23/0; selected XCTest run 70/0, ended 22:34:39.612 | Nonzero focused execution, independently corroborating Main's result. |
| `hidden-ax-full.log:3641-3644,3685-3686,4765-4767` | Both new cases pass; PageDotsViewTests 23/0; full XCTest run 2094/0, ended 22:35:56.032 | Nonzero full execution, independently corroborating Main's result. |

The trailing Swift Testing message reporting zero tests is a separate runner message; it does not replace the nonzero XCTest results above.

## Packaging evidence boundary

At dispatch, Main reported Debug/Release r3 packaging in progress. At inspection, the existing `hidden-ax-debug.log` reported the Debug product build complete in 0.35 seconds. The existing `hidden-ax-release-package.log` reported the Release product build complete in 53.30 seconds and assembly of `page-dots-rc-20261013-r3/LaunchcopyUITest.app`, followed by a manifest path and executable SHA-256 `979c8e3df595047fdb5b3a343da621f6343a58a96a50378873c1af2531343dfa`.

These are observed completion messages, not assumed success from the dispatch status. This reviewer did not inspect or hash the executable, validate the candidate manifest, inspect an exit-status record, or verify installation, promotion, signing or runtime behavior. Main owns artifact acceptance and reconciliation with its final evidence. The Release log includes a non-Sendable capture warning involving `diagBackend`/MultitouchSupportBackend, outside this predicate repair; its resolution is not assessed here.

## Limitations and maintenance

- The two new cases use an NSApplication-backed test fixture without opening a window. They establish direct native AXPress method/action behavior, not assistive-client discovery, VoiceOver announcements or navigation, native mouse down/up routing, or actual window visibility.
- The ancestor case directly tests the next-window control; previous-window rejection follows from the shared subclass guard and was not separately exercised by a new AXPress case. It also does not test visible recovery of either window control through AXPress. The existing disablement AXPress case (`PageDotsViewTests.swift:123-134`) checks no additional callback but discards the disabled return value. These are coverage limits, not source defects found in this repair.
- `isHiddenOrHasHiddenAncestor` concerns view hiding. Window ordering/occlusion, alpha, lifecycle readiness and general programmatic `performClick` calls are not newly governed by this override. Existing owner gates remain separate. No broader invisibility guarantee is claimed.
- No GUI/full-screen physical A/B, held-button routing, VoiceOver, 120 Hz, frame/icon-cost or end-to-end performance gate was executed or discharged. The full test suite's breadth does not promote the bounded review to those acceptance layers.
- Keep the shared guard at the AXPress entry point so hidden presses cannot reach native toggling or window browsing. No implementation expansion is needed for this bounded repair.

## Reviewed fingerprints and ownership

At 2026-10-13T13:39:58Z, the two current file SHA-256 values matched their selected entries in `source-files.sha256`:

```text
98fb3990dae4e8bd28dfab8e0a4ba2694c8d5a66b0796b5ae85bb053efad7b19  Sources/PagingPrototypeApp/PageDotsView.swift
ef12aba86efded470f4b1074d71ca7724a5ba6dd7e852dbae17707443fb42983  Tests/PagingUITests/PageDotsViewTests.swift
```

This checks these review inputs against Main's recorded manifest; it is not an independent audit of every build input or cryptographic binding of logs to binaries.

**Sole reviewer-owned and written path:** `/Users/mac/Projects/Launch_Copy/PagingPrototype/Docs/PAGE_DOT_HIDDEN_ANCESTOR_REVIEW.md`.

The implementation/test paths above, Package.swift, the bounded owner/Surface methods, PageDotOwnerTests, existing page-dot spec/review and verification evidence were read-only. No implementation, tests, package, workflow, existing documents or dirty files were edited. No Swift/build/test/app, install, process control, Git mutation or cleanup was run. Repository shell commands used the RTK prefix. Main retains ownership of source, tests, packaging, delivery and all outstanding runtime gates.
