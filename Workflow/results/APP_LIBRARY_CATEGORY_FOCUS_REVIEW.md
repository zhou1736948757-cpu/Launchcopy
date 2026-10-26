# App Library category focus repair review

Date: 2026-10-15. Repository: `/Users/mac/Projects/Launch_Copy/PagingPrototype`.

## Verdict and evidence boundary

**Narrow source/regression review complete; execution acceptance pending. No PASS is issued from source alone.** The final patch addresses the observed category-focus loss by capturing prior ownership before layout can displace it. No additional source defect was identified in this bounded patch. Main's focused r2 run is still running as last reported; this report does not infer its outcome or claim a successful executable repair.

**reviewer0tests:** this reviewer executed zero tests, Swift/compiler/build commands, or native UI actions. Main owns all runs and their results. Only this report was written; the earlier `APP_LIBRARY_INPUT_ACCESSIBILITY_AUDIT.md` remains unchanged and historical. Existing source/tests and Main's other work were preserved. Every shell command was RTK-prefixed. No agents or apps/processes were launched or controlled.

This is an existing-contract keyboard-focus repair. It introduces no feature approval or broader category/Back lifecycle audit. Broad IME routing (E1), accessibility action/VoiceOver evidence (E3), and native Tab traversal remain open.

## Correction and observed failure history

The earlier audit's E2 described a conditional risk that AppKit might retain a responder inside the newly hidden category control. That was not a reproduced mechanism and must not be presented as the actual diagnosis.

Main subsequently reports the following observations; this reviewer did not execute those runs or independently read their logs:

1. `testCategoryResponderMovesToVisibleCounterpartAcrossCompactLayout` reproduced the original category-focus failure with an actual mounted, unshown window, `makeFirstResponder`, and resizing in both directions: **1 XCTest / 4 assertion failures**, retained by Main in `category-focus-red.log`.
2. The first repair checked `window.firstResponder` only **after** changing hidden states. Main's focused run still reported **35 tests / 4 failures** in the counterpart-focus test. The search-composition/results-preservation test passed in that run. This first repair was insufficient, not a successful repair checkpoint.
3. Main's pre/post diagnostic run established that the pre-layout responder belonged to the category table/picker, but the post-hide/resize responder was **NSWindow**, not the hidden control. The concrete failure is loss of category focus to the window. A predicate checking for the original control afterward cannot recognize the displaced ownership.
4. Main replaced those predicates with pre-layout ownership snapshots. The final patch reviewed below corresponds to that correction; focused r2 execution was pending at the last update.

These observations establish a mounted AppKit focus defect and explain the failed first attempt. They do not establish behavior of a visible/key/active launcher, real input-method candidates, or VoiceOver.

## Exact final source review

[AppLibraryView.swift:297](/Users/mac/Projects/Launch_Copy/PagingPrototype/Sources/PagingPrototypeApp/AppLibraryView.swift:297), lines 297–328:

- Lines 300–301 capture `categoryTableWasFocused` and `categoryPickerWasFocused` using exact responder identity **before `super.layout()`**, either category hidden-state mutation, or the layout's frame changes.
- Lines 315–321 set the compact picker's visibility/frame and the wide category scroll's visibility/frame. Both destination visibility states have been established before remapping.
- Lines 324–327 use the saved identities. In compact layout, prior category-table focus goes to `compactCategoryPicker`; in wide layout, prior compact-picker focus goes to `categoriesTable`. The condition no longer depends on the post-hide responder remaining the original control.
- Only the displaced category control owns these branches. A search field editor, results table, details control, unrelated responder, or window responder at layout entry matches neither saved category identity. There is no unconditional search/results refocus.
- The existing result-to-details focus handling remains at lines 340–341. The category patch does not generalize or replace that separate drawer behavior.

The booleans are local to each layout invocation. Once the visible counterpart becomes responder, repeated layout at the same width does not match the opposite hidden control's saved identity and does not repeatedly steal focus. A detached view with no window also cannot match either category identity.

### Mutation and scope check

A read-only in-memory comparison removed only the final capture/remapping additions and obtained the **exact SHA-256 of the source from the original audit**. Thus the reviewed source delta is confined to those additions, including their comments. Removing the two new test methods similarly restored the original test-file hash. No files were rewritten for this comparison.

The added source statements read the current responder, store two booleans, and invoke `makeFirstResponder` on existing controls. They contain no query/category assignments, selection changes, action-generation changes, action emission, projection request, persistence/catalog call, I/O, or pagination/physics parameter change. Existing layout geometry and icon synchronization remain byte-identical to the previous implementation after removing the additions. This is evidence of **no new I/O**, not a claim that all existing layout work is I/O-free.

Existing category synchronization remains in `selectCategoryControl` at [AppLibraryView.swift:468](/Users/mac/Projects/Launch_Copy/PagingPrototype/Sources/PagingPrototypeApp/AppLibraryView.swift:468), lines 468–474, while category mutations occur through `changeCategory`, lines 460–465. The repair does not call either. Query/action invalidation remains outside this patch at lines 453–457. Focus movement is not repurposed as a category-change command.

## Exact regression-source review

The shared fixture at [AppLibraryViewTests.swift:17](/Users/mac/Projects/Launch_Copy/PagingPrototype/Tests/PagingUITests/AppLibraryViewTests.swift:17), lines 17–24, attaches `AppLibraryView` as actual `NSWindow.contentView`, lays it out, and asserts the window is unshown. The added methods exercise real mounted controls, not only a focus model or substituted owner callback.

| Test | Verified assertions in current source | Practical limit |
| --- | --- | --- |
| `testCategoryResponderMovesToVisibleCounterpartAcrossCompactLayout` | [AppLibraryViewTests.swift:69](/Users/mac/Projects/Launch_Copy/PagingPrototype/Tests/PagingUITests/AppLibraryViewTests.swift:69), lines 69–90: checks successful `makeFirstResponder` and actual pre-responder identity; resizes 1000→360 and back; checks hidden ancestors on both category controls; asserts both actual and preferred responder are the visible counterpart. Diagnostic messages retain pre/post responder values on failures. | Directly covers both observed focus-loss directions and prevents a preferred-responder fallback from concealing actual window focus. This reviewer has not executed the final version. |
| `testCategoryLayoutDoesNotStealSearchCompositionOrResultFocus` | [AppLibraryViewTests.swift:92](/Users/mac/Projects/Launch_Copy/PagingPrototype/Tests/PagingUITests/AppLibraryViewTests.swift:92), lines 92–115: obtains the real search field editor, applies marked text, crosses widths 360/1000, and asserts the same actual/preferred editor plus marked-text state; then focuses results, repeats both widths, and asserts actual/preferred result responder and no hidden ancestor. | Meaningful regression for the repair's negative ownership conditions. Synthetic marked text and direct focus/layout operations do not test an actual IME, native Tab, key-window reacquisition, or AX actions. |

Both tests retain the existing fixture's unshown-window isolation. They do not launch an app, scan production applications, or invoke a real workspace action. The source assertions are suitable for the observed repair; they are not substituted for execution counts. The unchanged narrow keyboard-selection test follows at line 117 and still covers result navigation without automatic details opening.

## Remaining risks and handoff

- `makeFirstResponder` returns a Boolean that the production patch does not check. The new test verifies the actual destination, so Main's r2 outcome is necessary to establish that AppKit accepts both remaps under the mounted fixture. Source inspection alone cannot guarantee acceptance in every native window state; no failure fallback is presumed necessary without evidence.
- The preservation test checks editor identity and presence of marked text, not exact candidate text/range or a real input method's lifecycle. It provides narrow layout-regression evidence and does not close E1.
- The new tests do not assert query/category/request callback counts. The exact source delta establishes no explicit new mutation/emission, while any AppKit callback side effects remain execution evidence rather than an invented source defect.
- Native Tab traversal, visible launcher focus, accessibility/VoiceOver actions and broad IME command routing remain unvalidated. The existing locked-desktop and aggregate baseline limits still apply.

Main should attach the final focused r2 result to its execution evidence before claiming executable resolution. If that run fails or the final inputs change, preserve the failure and re-review the bounded change. This report confirms the corrected source mechanism and regression intent, not a final runtime PASS or GUI gate.

## Reviewed identities

| Input | SHA-256 |
| --- | --- |
| Final `Sources/PagingPrototypeApp/AppLibraryView.swift` | `cd9e464010df3c588bc67bc31b94629a6c4edb4018fb8ca719b2ba21fe591938` |
| Final `Tests/PagingUITests/AppLibraryViewTests.swift` | `2de8c16db4bd216bce6cb6c25c3bc15307a4147bca5f38f0a3fc6b6b4d8885d1` |
| Historical `Workflow/results/APP_LIBRARY_INPUT_ACCESSIBILITY_AUDIT.md` | `8574e0581df75088514a31c9400f39af9ba89df0635109f1f31f139938baf2c3` |
| Original source after removing only final focus additions | `0b3baba5237d99e06a7ca81f6ba3b406d6f80ee9036f3cff106cd678855c3c34` |
| Original tests after removing only the two added methods | `bbfcea593253a145d1f62abcd8a3aa2f032a2d96a16ab772bedfc0f5d228440f` |
