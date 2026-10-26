# Chrome geometry order — independent source review

Date: 2026-10-14

Verdict: **ACCEPT for the bounded source-order repair. No blocking defect found in the reviewed methods. Runtime verification remains pending and owned by Main.** This verdict does not close the whole LaunchBetter parity objective.

## Scope and evidence boundary

Reviewed the current AppKit/Swift application assembly in `Sources/PagingPrototypeApp/AppDelegate.swift`, focused test source in `Tests/PagingUITests/ChromeGeometryOrderTests.swift`, the chrome geometry stage summary, and `Docs/LAUNCHBETTER_PARITY_SPEC.md`. Read the relevant in-file layout callers, dependent geometry helpers and lifecycle wiring. Read repository status and a source-only Git comparison; the checkout contains substantial existing dirty work.

This reviewer writes only this report. No source/test changes, tests, builds, application launches, process control, desktop/Terminal interaction, reference-project/assets/raw-evidence reads or global-memory reads were performed. No additional agents were started. Main retains serial verification ownership; the reported running focused r1 was neither inspected nor interrupted. Desktop lock and Terminal denial remain constraints with no workaround attempted.

The prepatch result is **provided evidence**, corroborated by the stage summary at lines 4–7: one actual-unshown delegate test, two assertion failures, `notice.maxY` 584 versus expected 616 points on both resize and screen-change callbacks, attributed by the task to `baseline-r1.log`. That raw log was not read or independently reproduced by this reviewer. The initial inset was deterministic synthetic current-inset +32; neither a physical display migration nor a visible window was exercised.

## Source findings

1. **Dependency order is correct.** `layoutSearchField` at AppDelegate lines 1837–1847 first assigns `search.field.frame` using current container bounds and current window-screen metadata, then calls `layoutPageDots`, `layoutCatalogStatus`, and `layoutActionFeedback`, in that order. All of these operations are synchronous within one `MainActor.assumeIsolated` closure, with no new task, dispatch or suspension between producer and consumers. Feedback therefore reads the updated search frame on this path.

2. **Missing-search fallback survives.** The `if let container, let search` condition encloses only the search-frame assignment; it does not return from the transaction. Dependent layouts still execute when either prerequisite is missing. `layoutActionFeedback` at lines 132–142 uses the field only when it shares the notice's root; otherwise its top anchor is `root.bounds.maxY - 80`. No search means the fallback remains reachable. Absent detached views cause the existing helper guards to return without recreating presentation.

3. **Geometry policies remain explicit.** Search geometry at lines 1824–1835 caps width at 300 and height at 28, clamps available size and finite/nonnegative safe-area top, limits top spacing by available height, and reads `window?.screen?.safeAreaInsets.top ?? 0` rather than a fixed notch offset. Feedback retains its 12-point gap below the same-root field, width cap 560, horizontal centering, height measurement and bottom clamp. Dots retain their existing ordinary-grid bottom-gutter calculation (lines 2793–2803); catalog status retains its compact/centered rules (lines 246–257). The reorder does not introduce an alternative formula. At sufficient height without top/bottom clamping, the synthetic +32 prior inset moves the stale feedback anchor 32 points lower, consistent with the reported 584/616 discrepancy. The exact 12-point gap is subject to the existing bottom clamp in short hosts; the focused fixture does not establish all-size acceptance.

4. **No query/deadline/input/physics operation was added to the geometry transaction.** The reviewed transaction assigns frames and invokes the existing dependent layout methods. It does not assign search text, invoke search presentation, show/clear a notice, renew an expiration deadline, move first responder, request a page, or mutate paging parameters. `layoutActionFeedback` itself sets only frame and autoresizing mask and reads required presentation height; the implementation of that height helper is outside this bounded review. This supports the intended narrow change without claiming an audit of all related modules.

5. **Actor and lifecycle boundaries remain appropriate for the narrow repair.** The field assignment and calls to the `@MainActor` dependent helpers share the existing assumed-isolated transaction. `assumeIsolated` asserts the execution context; it does not marshal arbitrary background callers to MainActor. The reviewed callers are the root layout hook (line 559) and the window delegate paths (lines 3085–3099); tests invoke them from an `@MainActor` class. Both delegates retain direct-navigation cancellation, folder-title editing completion with `returnFocus: false`, folder visual cancellation, and deferred appearance scheduling before/after geometry. Those are existing delegate responsibilities, not a promise that the entire callback is free of input-state effects. Feedback installation retains a weak presentation callback; teardown clears that callback, tears down/removes the view and advances its generation (lines 109–129). The reorder adds no lifecycle callback or new presentation object.

**Change-attribution limitation:** Git HEAD predates the accumulated safe-area/chrome/lifecycle work; it lacks the current `layoutSearchField` transaction and screen-change callback. The broad dirty diff is not an immediate prepatch comparison. The task and stage summary describe an ordering-only patch, and the current method is consistent with that description, but this review cannot independently certify exact patch-only invariance of formulas, actor boundaries or delegates against an unavailable immediate prepatch snapshot. It does not certify the whole dirty AppDelegate diff as ordering-only.

## Test honesty and coverage

- `ChromeGeometryOrderTests` is `@MainActor`. Its first test (lines 11–51) loops over two callback paths, constructs an actual NSWindow without ordering it, seeds the field with a synthetic previous inset of current +32, then directly calls the production `windowDidResize` or `windowDidChangeScreen`. Calling those delegate implementations is substantive coverage of the repaired assembly seam; constructing a notification does not simulate a system-delivered screen transition.
- The first test checks the updated field frame, feedback top relative to the updated field, retained query, unchanged deadline, and an unshown window before/after invocation. These assertions target the reported stale-anchor regression. It is one test function covering two callback cases; two prepatch failed anchor assertions are consistent with that structure. The file now contains a second test function for absent-search fallback.
- The first fixture does **not** resize the root/window, migrate between screens, install a production pager, provide active input/folder sessions, or install dots/catalog status views. It demonstrates ordering against deliberately stale geometry when either delegate method is directly invoked. Physical safe-area conversion, AppKit notification delivery, actual resize behavior, active-input cancellation, dots/status behavior and motion/performance remain outside its evidence.
- The fallback test (lines 54–70) has no search/window, sets notice geometry to zero, invokes the resize delegate and checks the root-top fallback, deadline equality and visibility. It supports retaining fallback execution, but does not separately exercise absent-search screen-change, missing-container with an attached notice, or different-superview search fallback. Both delegates share the reviewed transaction, so these are coverage limits rather than a blocking defect in this reorder.
- The expected search rectangle is calculated with the same static production helper used by layout. This is suitable for dependency-order coverage, but is not an independent oracle for the safe-area formula. Deadline equality shows retained observed state; it does not independently assert a valid/nonempty initial deadline or eventual expiration. The first test checks visibility before the callback and window visibility afterward, but does not explicitly reassert notice visibility afterward. Source inspection finds no show/clear operation in the layout transaction; no extra runtime guarantee is inferred.
- Five deferred-presentation drains occur during fixture setup, before the measured delegate call. No presentation drain or wait is inserted between that call and the geometry/deadline assertions, which keeps the ordering assertion focused on the synchronous transaction. No test result is supplied by this review; focused r1 remains Main's evidence to record.

## Acceptance and remaining gates

The repair aligns with parity-spec requirements for current-screen safe-area chrome and preservation of validated paging/input contracts (lines 100–104), within the existing Swift Package/AppKit module architecture (lines 78–94). The tests clearly disclose their synthetic inset and unshown-window boundary. No blocking source-order issue or misleading physical-PASS claim was found in the reviewed source/stage summary.

This is a source-only acceptance of the bounded repair. Compilation, focused/full test results, debug/release builds, exact packaged executable hash, GUI behavior, physical screen transitions and performance are unverified here. Main owns their serial collection under the existing access constraints. Source hashes below are not executable/candidate hashes. Spec lines 137–145 require separate evidence layers; neither this report nor future focused-test success establishes full parity. Library/capacity and other whole-goal requirements remain active as recorded in the stage summary and approved specification.

## Reviewed snapshot hashes

SHA-256 of the complete files, read and rechecked before report creation; all four were stable across those reads:

| File | SHA-256 |
| --- | --- |
| `Sources/PagingPrototypeApp/AppDelegate.swift` | `8d78ea4f207b3d7a6bf23bff8ad7b9795e01bbbf40fb11b3d6567bcabdbf24d3` |
| `Tests/PagingUITests/ChromeGeometryOrderTests.swift` | `1a5575c09cc4272a9ee7318ebbaf55afff28c5b0d95bb2157229fa27c107142c` |
| `Workflow/stage-summaries/2026-10-14-chrome-geometry-order.md` | `41820f15f962ff4ba96d071d25833876acfe0850b3fded9ac7f83aeb78a9a322` |
| `Docs/LAUNCHBETTER_PARITY_SPEC.md` | `811227da254051ac7539d2c7cf084a397d4fc89f148140a29ae9e6f0f76a918e` |

Only this authorized report was created by the reviewer; preexisting dirty work was retained. No runtime PASS or full-goal closure is issued.
