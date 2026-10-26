# Library Drawer Focus — Bounded Source Review r1

Date: 2026-10-19

Verdict: ACCEPTED FOR SOURCE SCOPE. No actionable correctness or test-fixture defects found in the two-file repair. This is not a test-execution, native UI, physical, performance, or full-goal PASS. Main owns the serial focused-suite result and remaining acceptance gates.

## Scope and stable inputs

Reviewed only the repair in `Sources/PagingPrototypeApp/AppLibraryView.swift` and the three added regressions in `Tests/PagingUITests/AppLibraryViewTests.swift`, including their existing helper/lifecycle context. Compared both current files directly against `.build/verification/20261019/library-drawer-focus/*.before`. The saved before-file hashes match `baseline-files.json` and the previously inspected Frozen511 hashes:

| File | Before SHA-256 | Reviewed SHA-256 |
| --- | --- | --- |
| AppLibraryView.swift | 1b79eaa0dafbe9b133e887325a52ffc8f7fa59cc9d146f92c5eff4455e25852f | ed6036a93546de6fce65dc622ea6c3b8913a0e1285e0cb41a31e8220f41f1e70 |
| AppLibraryViewTests.swift | 2de8c16db4bd216bce6cb6c25c3bc15307a4147bca5f38f0a3fc6b6b4d8885d1 | 3847e85568a79fca371b7c4706c7b58571dbdc6dd2a0a5eba3529488b4fa0dfb |

The direct comparisons contain only the early result-focus capture, replacement of the existing handoff predicate, the accompanying comment, and the three added test methods. Git diff for these paths returned no output, so the saved before files were the effective comparison inputs.

## Source assessment

- `AppLibraryView.swift:306–312` captures `resultsTableWasFocused` before `super.layout()` and all category/results visibility changes. Synchronous AppKit resignation during hiding can no longer erase the ownership evidence needed for handoff.
- `AppLibraryView.swift:343–351` preserves the existing `resultsScroll.isHidden` guard and existing close-details destination. The details scroll is made visible and framed before the handoff. Visible results, marked search editing, category controls, and existing details controls do not satisfy the captured result-ownership predicate, so this repair does not steal their focus.
- The same bounded correction covers both wide-to-drawer resize and the result-focus displacement created by closing details during nil/loading followed by restoration of the surviving identity. It does not change selection, snapshot admission, action generation, or details-close semantics.

## Regression and fixture assessment

- `AppLibraryViewTests.swift:423–440` explicitly starts each width case at 1000 with open details and visible, focused results; it then checks the close-details responder, visibility, preferred responder, details state, and retained selection at 700 and 360. The helpers settle layout before the transition. Reusing the view is valid because each iteration reestablishes the wide presentation and result focus.
- `AppLibraryViewTests.swift:442–460` uses the actual details category picker, verifies that nil/loading transfers focus to visible results, then publishes a newer snapshot containing the same AppID and checks restored drawer focus and selection. This exercises the actual close/loading/restore route rather than manufacturing a hidden responder.
- `AppLibraryViewTests.swift:462–493` preserves a real search field editor, marked state, and composition text through 700/360/1000. Its subsequent `reset/apply/select` establishes a fresh settled details fixture before testing the visible details category picker across 360/700/1000. This correctly isolates the picker case from the legitimate query commit caused by ending marked editing. The reset does not conceal a failure of the composition assertions, which occur first.
- No blocking fixture flaw identified. These are mounted, unshown AppKit-window regressions; they do not establish shown-window key traversal, physical input behavior, or performance.

## Evidence boundaries

Read the existing immutable `red-r2.log`: XCTest reports 3 methods, 2 failures, 8.443 seconds; the marked-search/visible-control negative case passed and both positive methods failed at their responder unwraps on the old source. The wide-to-narrow method throws at its first failing width, so that historical red run independently establishes the 700 case, not a separate completed 360 baseline failure. A successful new execution of the current method must complete both width iterations. The later zero-test Swift Testing footer does not replace the nonzero XCTest result.

Main reported red-r1 as historical (3 methods / 8 failures); it remains superseded for corrected-fixture interpretation. This review did not inspect or adopt the live focused-suite outcome, execute tests/builds, launch or control native UI/processes, or access references. The only file written by this review is this report. No source, test, ledger, or historical evidence was modified. Full-goal completion remains outside this verdict.
