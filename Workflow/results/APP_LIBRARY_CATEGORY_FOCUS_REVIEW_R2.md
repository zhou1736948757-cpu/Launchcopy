# App Library category focus repair — final bounded review

Date: 2026-10-15. Repository: `/Users/mac/Projects/Launch_Copy/PagingPrototype`.

## Independent disposition

**ACCEPT the bounded category-focus repair.** The final implementation addresses the observed focus loss, the regression tests exercise actual mounted responders in both layout directions, and Main's terminal XCTest records show those tests passing in both focused and full runs. No unresolved source defect was found in this patch. This disposition combines independent source/test-source review with read-only inspection of Main-owned execution evidence; it is not a source-only claim of runtime success.

**reviewer0tests:** this reviewer executed zero tests and no Swift/compiler/build, candidate/probe, UI, or process-control commands. Main executed all tests, builds, packaging and probes. This reviewer read the bounded stored evidence and compared the two reviewed current input hashes with the final manifest. Every shell command was RTK-prefixed. No agents were spawned.

Only this additive R2 report was written in this final review. [The R1 pending report](/Users/mac/Projects/Launch_Copy/PagingPrototype/Workflow/results/APP_LIBRARY_CATEGORY_FOCUS_REVIEW.md) and [the historical input/accessibility audit](/Users/mac/Projects/Launch_Copy/PagingPrototype/Workflow/results/APP_LIBRARY_INPUT_ACCESSIBILITY_AUDIT.md) are preserved unchanged. R2 supersedes R1's pending execution disposition for this repair, without silently rewriting its history or closing unrelated gates.

**GUI, real IME, native Tab, AX actions and VoiceOver remain pending.** E1 and E3 remain open. Only the category-focus-loss portion of E2 is resolved at the mounted AppKit/XCTest layer; E2's native traversal and visible launcher acceptance are not closed. The locked desktop and aggregate passing counts do not substitute for those gates.

## Confirmed defect and corrected mechanism

The original risk was initially hypothetical. Main's retained [category-focus-red.log](/Users/mac/Projects/Launch_Copy/PagingPrototype/.build/verification/20261015/library-interaction/category-focus-red.log) records one XCTest with four assertion failures across the two layout directions. The initial post-hide conditional repair also failed: [focused-r1.log:58](/Users/mac/Projects/Launch_Copy/PagingPrototype/.build/verification/20261015/library-interaction/focused-r1.log:58), lines 58–62/100–102, records the counterpart-focus failures and **35 tests / 4 failures**, while the composition/result preservation test passed at line 54.

The actual observation is **category focus lost to NSWindow**, not retention in a hidden control. [category-focus-observation.log:13](/Users/mac/Projects/Launch_Copy/PagingPrototype/.build/verification/20261015/library-interaction/category-focus-observation.log:13), lines 13–16, prints NSWindow as responder after both compact and wide transitions. The current diagnostic test checks prior category identity at lines 72/82; the observation run reports only the post-transition actual/preferred-responder failures. Main's diagnosis of successful prior ownership and loss during hide/resize is consistent with that retained record.

The first repair could not match an original category control after AppKit had changed the responder to the window. The final repair therefore captures ownership before layout mutates visibility. The historical audit's hidden-responder scenario must not be used as the reproduced mechanism. Failure evidence remains meaningful even though the final runs pass.

## Exact final source and regression assessment

[AppLibraryView.swift:297](/Users/mac/Projects/Launch_Copy/PagingPrototype/Sources/PagingPrototypeApp/AppLibraryView.swift:297), lines 297–328:

- `categoryTableWasFocused` and `categoryPickerWasFocused` are captured at lines 300–301, before `super.layout()` and either category visibility/frame mutation.
- Lines 315–321 establish both category controls' destination visibility and geometry. Lines 324–327 then move prior wide-table focus to the compact picker, or prior compact-picker focus to the wide table, using the saved ownership rather than post-hide identity.
- Exact identity guards exclude search editors, results, details and unrelated responders. Saved ownership is local to the invocation; repeated layout at the same width does not continually remap the visible counterpart. Existing result-to-details behavior at lines 340–341 is retained.

The read-only comparison recorded in R1 removed only the capture/remapping additions and recovered the original source hash exactly. Removing only the two new test methods recovered the original test-file hash. Final current hashes remain the same as R1's final-source review and match Main's final manifest. Consequently the bounded production delta adds responder reads, two local booleans and focus transfers only: no query/category/selection assignment, action emission/invalidation, new projection or persistence call, new I/O, or pagination/physics change. Existing layout/icon behavior is not newly introduced by this patch. No production repair beyond this delta is assumed.

The fixture at [AppLibraryViewTests.swift:17](/Users/mac/Projects/Launch_Copy/PagingPrototype/Tests/PagingUITests/AppLibraryViewTests.swift:17), lines 17–24, mounts the view as real NSWindow content and asserts the window is unshown. This is stronger than model-only focus evidence, and remains distinct from a visible launcher.

| Regression | Exact assertions | Terminal execution evidence owned by Main |
| --- | --- | --- |
| `testCategoryResponderMovesToVisibleCounterpartAcrossCompactLayout` | [AppLibraryViewTests.swift:69](/Users/mac/Projects/Launch_Copy/PagingPrototype/Tests/PagingUITests/AppLibraryViewTests.swift:69), lines 69–90: verifies successful actual initial focus and prior identity, changes widths 1000→360→1000, checks both hidden-ancestor states, and asserts actual plus preferred responder become the visible counterpart. | Passed in [focused-r2.log:57](/Users/mac/Projects/Launch_Copy/PagingPrototype/.build/verification/20261015/library-interaction/focused-r2.log:57) and [full-r2.log:1133](/Users/mac/Projects/Launch_Copy/PagingPrototype/.build/verification/20261015/library-interaction/full-r2.log:1133). |
| `testCategoryLayoutDoesNotStealSearchCompositionOrResultFocus` | [AppLibraryViewTests.swift:92](/Users/mac/Projects/Launch_Copy/PagingPrototype/Tests/PagingUITests/AppLibraryViewTests.swift:92), lines 92–115: uses the actual marked search editor across both widths, checks actual/preferred identity and marked-text presence, then checks actual/preferred results focus and no hidden ancestor across both widths. | Passed in [focused-r2.log:53](/Users/mac/Projects/Launch_Copy/PagingPrototype/.build/verification/20261015/library-interaction/focused-r2.log:53) and [full-r2.log:1129](/Users/mac/Projects/Launch_Copy/PagingPrototype/.build/verification/20261015/library-interaction/full-r2.log:1129). |

The production code ignores `makeFirstResponder`'s Boolean; the regression checks actual destination identity, and Main's recorded passing runs establish acceptance for both mounted test transitions. No unhandled failure was observed in those transitions. This is not a guarantee for every native window state, nor grounds to invent another fallback repair.

## Main-owned final verification, inspected read-only

All evidence below resides under `.build/verification/20261015/library-interaction`. This reviewer did not rerun any command represented by these artifacts.

| Gate | Stored evidence | Result and limit |
| --- | --- | --- |
| Focused XCTest | [focused-r2.log:95](/Users/mac/Projects/Launch_Copy/PagingPrototype/.build/verification/20261015/library-interaction/focused-r2.log:95), lines 95–97 | **35 executed / 0 failures, 2.019 seconds**; includes both new regressions. |
| Full XCTest | [full-r2.log:5952](/Users/mac/Projects/Launch_Copy/PagingPrototype/.build/verification/20261015/library-interaction/full-r2.log:5952), lines 5952–5954 | **2593 executed / 0 failures, 45.680 seconds**; includes both new regressions. |
| Debug | [debug-r2.log](/Users/mac/Projects/Launch_Copy/PagingPrototype/.build/verification/20261015/library-interaction/debug-r2.log) | Terminal `Build complete! (0.27s)`. Build evidence belongs to Main. |
| Release and package | [release-package.log](/Users/mac/Projects/Launch_Copy/PagingPrototype/.build/verification/20261015/library-interaction/release-package.log) | Release executable/product builds complete; candidate assembled; native test-entry accepted; packaged localization check reports 3 languages and 274 required keys/signatures. Packaging acceptance is not GUI/IME acceptance. |
| Packaged positive/negative probes | [packaged-resource-results-r2.json](/Users/mac/Projects/Launch_Copy/PagingPrototype/.build/verification/20261015/library-interaction/packaged-resource-results-r2.json) | Positive exit 0; missing-library-key and invalid-library-template each exit 1 with required-key/signature rejection. These negative results demonstrate intentional resource rejection, not failing production tests. |
| Input association and unchanged pager | Same packaged-results JSON and [source-change-summary.json](/Users/mac/Projects/Launch_Copy/PagingPrototype/.build/verification/20261015/library-interaction/source-change-summary.json) | Main's verifier records 441 checked inputs/all matching and 18 PagingCore/UI source files unchanged from bootstrap. The summary lists only the Library view and two Library test files changed from bootstrap. This reviewer did not independently rehash all 441 files or reproduce the 18-file baseline comparison. |

The supplemental Swift Testing footer reports zero tests. It is not the successful test evidence: the nonzero XCTest suite counts above are. No zero-test footer is used to manufacture PASS.

Candidate identity recorded in Main's package log and probe JSON:

- Candidate: `library-category-focus-rc-20261015-r1`, packaged as `.build/candidates/library-category-focus-rc-20261015-r1/LaunchcopyUITest.app`.
- Executable SHA-256: `afa1df6cf2cf58deab1520422a14087a14ac315639cbac057093cbc07a884e9a`.
- This reviewer verified that `source-inputs-final.json` contains 441 entries and directly rehashed the two reviewed source/test inputs; both match [manifest line 123](/Users/mac/Projects/Launch_Copy/PagingPrototype/.build/verification/20261015/library-interaction/source-inputs-final.json:123) and [line 337](/Users/mac/Projects/Launch_Copy/PagingPrototype/.build/verification/20261015/library-interaction/source-inputs-final.json:337). The binary itself was not rehashed or launched by this reviewer.

## Remaining gates and historical identities

The focused repair now has positive source and executed mounted-control regression evidence. It does not add native Tab traversal or AX action assertions. Synthetic marked text checks ownership preservation through layout, not real IME candidate selection/commit/cancel or exact composition contents/ranges. Query/category/action side effects are not counted by the new tests; absence of explicit new mutation is established by the confined source delta rather than a fabricated assertion.

Keep visible launcher GUI, broad IME routing/E1, native Tab/E2 remainder, AX actions/E3 and VoiceOver acceptance open for the actual candidate. Do not infer physical performance or full App Library acceptance from the unchanged pager files, passing suite, build, or packaging results. No additional source repair is requested by this bounded review.

| Reviewed/preserved input | SHA-256 |
| --- | --- |
| Current `Sources/PagingPrototypeApp/AppLibraryView.swift` | `cd9e464010df3c588bc67bc31b94629a6c4edb4018fb8ca719b2ba21fe591938` |
| Current `Tests/PagingUITests/AppLibraryViewTests.swift` | `2de8c16db4bd216bce6cb6c25c3bc15307a4147bca5f38f0a3fc6b6b4d8885d1` |
| Preserved `Workflow/results/APP_LIBRARY_CATEGORY_FOCUS_REVIEW.md` | `b7042ddbab2b985693f04da4a7fb5a2be609113debcad50682e76f6506fc90d1` |
| Preserved `Workflow/results/APP_LIBRARY_INPUT_ACCESSIBILITY_AUDIT.md` | `8574e0581df75088514a31c9400f39af9ba89df0635109f1f31f139938baf2c3` |
