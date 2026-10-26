# Library category count visibility — independent source review R2

Date: 2026-10-15

## Verdict and scope

**Bounded SOURCE PASS for the R2 accessibility refinement. No actionable source defect found in this delta.** Returning cell/title accessibility exposure to native defaults and putting the full combined label on the native title is a proportionate response to the observed extra R1 Unknown wrapper. That observation is **not a diagnosed VoiceOver failure**, and this verdict is not a VoiceOver or mounted AX-tree acceptance result.

This report supplements and preserves `LIBRARY_CATEGORY_COUNT_SOURCE_REVIEW.md`. Its R2 accessibility assessment supersedes the R1 description of explicitly exposing the container and suppressing both labels. The prior geometry, ownership, finite-width, and performance boundaries continue to apply. Main owns runtime order, serial test/build/package resources, and the unique R2 native candidate.

Reviewer execution: **0 tests, 0 builds, 0 Swift invocations, 0 UI/process-control operations, 0 agent dispatches/messages**. All shell commands were RTK-prefixed. Only this new R2 report was written. Original report SHA-256 before/after preservation check: `48566045f93ae3d395850a91f3946d08425ce1ac01cd11e05fd3c9be06828d61`. Existing dirty work was preserved. No restricted LaunchBetter/Buho/reference/raw-asset material was read; this is a continuation of the same independent source-review scope.

## Frozen input verification and exact delta

Read the updated current stage summary, preserved R1 report, current two changed files, Main's AX RED/focused logs, native-R1/resource result records, and manifest/delta-proof artifacts. Prior project rules and same-scope authorization remain applicable.

- Preserved R1 manifest: `.build/verification/20261015/library-category-count/source-inputs-r1.json`, 450 inputs, SHA-256 `e2c3da147659ce0eb232ff2744ef435dcf9a34e8f1887a01d18451d03d86ea20`.
- Current R2 manifest: `.build/verification/20261015/library-category-count/source-inputs-final.json`, 450 inputs, SHA-256 `9f3ef3247cd5974fc8345cf289f7fd28c3c555dc65995fc59783d01b422cddcb`.
- Independently recomputed all 450 current input hashes: **0 mismatches**. R1→R2 contains exactly **2 modified files, 448 unchanged, 0 added/removed**. `AppLibraryView.swift`, resources, package/dependency configuration, domain/taxonomy, and all 18 frozen PagingCore/PagingUI inputs remain unchanged from R1.

| R2 changed file | Final SHA-256 |
| --- | --- |
| `Sources/PagingPrototypeApp/AppLibraryCategoryCell.swift` | `52f454d65984983678da8328d4bc6bd8b9ba25d89a6994d08e45e9c56e020bb4` |
| `Tests/PagingUITests/AppLibraryCategoryCellTests.swift` | `fa51d14fb0387d20c0c1c9d648894f330d5f56b75871177d242fe8b0ef5bb8ec` |

Independently reversed only the known R2 AX changes **in memory**, reconstructing both complete R1 files and matching their preserved R1 SHA-256 values exactly. Thus production changes are limited to the constructor's exposure statements/comment and one title accessibility-label assignment; test changes are the revised reuse expectations and fifth native-default comparison. Geometry, numeric text, title truncation, tooltip, and binding invalidation are byte-identical to R1 apart from shifted line numbers.

Main's `app-library-view-delta-proof.json` separately records reversal of the earlier AppLibraryView factory delta, with recovered SHA-256 `cd9e464010df3c588bc67bc31b94629a6c4edb4018fb8ca719b2ba21fe591938`. Independently checked that both recorded prior/reversed hashes match the actual 448-input baseline manifest entry. This closes the R1 historical-body limitation **as Main-provided reconstruction evidence**; this reviewer did not independently rerun that factory reversal. The independent R2 cell/test reconstruction above is a separate check.

## Accessibility and retained bounded behavior

`AppLibraryCategoryCell.swift:18–23` retains native NSTableCellView/textField composition and removes both explicit `setAccessibilityElement(true)` on the custom cell and explicit title suppression. Only the new decorative count remains explicitly ignored. There is no forced replacement role, new wrapper view, table-selection override, responder action, event hook, or accessibility traversal implementation.

`AppLibraryCategoryCell.swift:29–36` binds the full localized title plus decimal count to **both the native cell label and title label**, while keeping the visual title string separate from the numeric field. Every bind rewrites both AX labels and the full tooltip, so a reused/relocalized title cannot retain the old combined label. Geometry cannot shorten those strings. Keeping a label on the container does not explicitly re-enable its accessibility-element flag; the new direct comparison covers that getter behavior. Actual mounted exposure, role/name/value resolution, and whether assistive technology speaks the count exactly once remain native gates.

The unchanged layout (`39–51`) still reserves intrinsic trailing count width first, caps it to available space, and gives only the title the remaining nonnegative width with tail truncation. Supported cell-width sampling remains 112/184/200 points, representative counts 0/7/12,345/999,999, three shipped languages, and long Health/Fitness/Social titles. Tiny-width sampling remains 0/4/8/16/30 points. This does not promise full readability at arbitrary Int.max or tiny bounds; full combined label/tooltip is retained.

Selected styling remains the inherited native backgroundStyle/system-label path discussed in R1. R2 does not change colors, fonts, drawing, frames, or row selection. Main's R1 Japanese Health12/Social12 visibility, readable blue/white selected Health row, exactly12 filtered results, All40/Productivity16, and normal-Quit exact-process absence are recorded in `native-r1.json`. These are **Main's R1 observations**, not reviewer UI inspection or R2 runtime evidence. The additional Unknown wrapper is recorded alongside them without inferring a VoiceOver failure.

Because the view/delegate and every other input are unchanged from R1, there is no new query/category/focus/compact-picker/domain/count-engine ownership change. No I/O, timer, observer, framework dependency, icon work, frame/gesture callback, or paging parameter change is introduced. Static boundedness is not measured physical-performance acceptance.

## Regression quality and execution evidence

The fifth test (`AppLibraryCategoryCellTests.swift:117–129`) constructs an independent default NSTableCellView and native title, then compares cell/title exposure getters and asserts the custom title's full Japanese combined AX label. This is stronger than asserting a hard-coded exposure flag: it guards preservation of the native default on the tested platform. It does not establish mounted AX children, actual Unknown-wrapper removal, speech order, native role, or VoiceOver output. The diagnostic assertion message expresses the intended topology boundary, not an independently measured role result.

Main's `ax-exposure-red.log` records **1 XCTest / 2 failures** against R1: custom cell true versus native baseline false, and missing complete title AX label. The title exposure comparison itself did not fail; removing its override avoids pinning the native default unnecessarily. The revised reuse test (`60–75`) now checks the title's combined AX label after each bind and still checks that the decorative count is ignored. Updating the old exposure expectation is justified by the native-default comparator and recorded topology observation, rather than merely weakening a failing assertion.

The existing real-delegate localized geometry, All-count/query/category relabel, and tiny-bounds tests remain intact. Tests retain the R1 limitations concerning implementation identifiers/intrinsic-width measurement and non-exhaustive sampling; they remain meaningful for the bounded regression. Independent localization tests continue to establish label correctness beyond shared provider expectations.

At read time, Main's previously live `focused-r2.log` was terminal: **35 XCTest / 0 failures, 6.394 seconds** — 5 cell tests + 9 localization tests + 21 Library view regressions. Reviewer ran none. The zero-test Swift Testing footer is separate from the executed XCTest suite. Main reports R1 full **2644/0**, Debug/Release/package, and 288-key three-language positive/negative probes against the R1 freeze; the saved resource record confirms R1 executable/input attribution. These R1 results do not certify the R2 binary.

## Outstanding gates

Main must associate R2 terminal full-suite/Debug/Release/package/resource results with the current freeze and distinct R2 candidate. Its native-after check should confirm the unnecessary wrapper is absent relative to the native-before topology, full title/count remains available through the native title, count12 stays visible, selection contrast/filter interaction remain correct, and normal-Quit exact-process handling meets the existing boundary. Preserve the R1 observations and RED evidence as history.

Actual VoiceOver, real IME, physical motion/performance, and broader parity remain separately unaccepted. No further source change is requested by this R2 verdict.
