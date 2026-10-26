# T-WALLPAPER-CELL-FILL — Independent Reviewer r1

- Date: 2026-09-11, Asia/Shanghai
- Role: Independent Reviewer → Main; task-scoped reviewer override authorized by Main/user.
- Verdict: **PASS — scoped cell-fill patch only**.
- Reviewed: task packet, Worker result, actual tracked diff against `6382bd911741831d13360e402c270bb6509b3679`, complete new regression test, targeted test logs, and synthetic folder PNG pair.
- Reviewer execution: no SwiftPM, build, application launch, process inspection, or GUI interaction. Only this review artifact was written.

## Findings and minimality

No blocking or major patch defects found. The actual production change is exactly two one-line substitutions, not two changes within a single file:

1. `Sources/AppGridUI/AppGridCellView.swift:66`: initialization replaces `controlBackgroundColor` with `nil`.
2. `Sources/AppGridUI/AppGridCellFocus.swift:30`: the unfocused branch replaces `controlBackgroundColor` with `nil`.

An independent read-only comparison reconstructed each current source file from its HEAD version using precisely that single substitution and asserted byte-for-byte equality. This establishes that all remaining implementation code in both files is unchanged, including layout, hit testing, mouse/drag delivery, token validation, folder handling, and accessibility setters. `git diff --check` also passed.

`Tests/AppGridUITests/AppGridCellFocusReuseTests.swift:34`, `Tests/AppGridUITests/AppGridCellFocusReuseTests.swift:62`, and `Tests/AppGridUITests/AppGridCellFocusReuseTests.swift:93` change only the three explicitly authorized idle-background expectations and their messages. They now require nil rather than an opaque control background. Existing focus reset, content identity, and reuse assertions are retained; this does not weaken those assertions or modify the unrelated baseline failure expectations.

## Synthetic evidence

Evidence directory: `Workflow/artifacts/T-WALLPAPER-CELL-FILL/`.

| Evidence | Independently inspected result |
|---|---|
| `fail-before.log` | At 21:33:08, XCTest reports 3 executed tests with 24 failed assertions. All six padding samples are approximately device RGB `(0.118637, 0.118637, 0.118637)`. This is an executed failing regression, not a build-only failure. |
| `pass-after-targeted.log` | At 21:35:03, XCTest reports 15 tests, zero failures: new transparency tests 3/3, focus/reuse tests 3/3, folder tests 9/9. All six padding samples are approximately `(0.998450, 0.146943, 0.000110)`. |
| `before-folder.png` / `after-folder.png` | Reviewer opened both images. Before: dark rounded cell interior covers the red backdrop. After: red backdrop is visible across the cell padding while the folder symbol, title, and member count remain visible. |

`Tests/AppGridUITests/CellBackdropTransparencyTests.swift:74` captures the real `AppGridCellView` over an in-memory red parent using AppKit bitmap caching. For the 120×96-point cell, the sample is at x=10 points and vertical midpoint; the icon starts at x=36 points, and text occupies the bottom rows. The sample therefore measures empty padding, not an icon, label, rounded corner, or focus border. Scale-aware sampling and red-dominance tolerances accommodate bitmap scale and color conversion. The nil-background assertion additionally checks the property responsible for the defect.

The six logged states are initial, unfocused after focus, cleared after focus, folder bind, folder unfocused, and app rebound from a focused folder. The Worker reports the same new tests were used before and after; the stored failures, sampled states, current assertions, and PNG contrast support that account. The Reviewer did not rerun either binary or independently capture the before execution. Numeric RGB values above come from logs, not a separate Reviewer pixel-decoding measurement.

## Contract checks

- **Idle transparency:** initialization is clear; `setFocused(false)` clears the background as well as the border. Existing `clearContent()` calls that method, and bind/rebind retain their existing cleanup sequence, so those paths cannot restore the removed control fill.
- **Focus:** the focused branch remains unchanged: selected-control fill, 3-point accent border, and `setAccessibilityFocused(true)`. The unfocused branch retains `setAccessibilityFocused(false)`. The new tests check focused fill/ring and subsequent reset. Live assistive-technology focus is not exercised or claimed.
- **Identity and folders:** new tests retain binding-token equality, cleared-token absence, folder role/label/symbol/member count, and folder-to-app cleanup checks. The targeted folder suite remains 9/9 according to its log. No production identity or callback code changed.
- **Hit bounds and input:** icon/folder hit regions, 4-point expansion, frames, `hitTest`, and pointer/drag methods are byte-for-byte unchanged. Background transparency is not implemented by changing view bounds, alpha, visibility, or event routing. No new live-input acceptance is claimed.
- **Earlier host patch:** `Sources/PagingUI/PageHostView.swift` still hashes to `b552714856e3d1ebb3a22691580136f479e0ed8531436308e0d8a9724a84bcef`, matching the previously reviewed patch. It was not reverted.
- **Privacy:** the new fixture uses synthetic names, tokens, and an in-memory color; it performs no wallpaper or user-image lookup. Artifact output is opt-in through the two test environment variables. No real wallpaper image or user application identity log was accessed by this Reviewer; no LaunchBetter/Buho material was accessed.

## Reviewed production hashes

- `Sources/AppGridUI/AppGridCellView.swift`: `8056b97b7800c470b8af82c1a107ffe42ce1d93ccc1c191af4c6e14dc5661c53`.
- `Sources/AppGridUI/AppGridCellFocus.swift`: `32e5148322f63878f9dfc69d0f7da53b995b99fdcaa57728e7c3286bc6287551`.

## Remaining gates

Main reports real wallpaper was visible in the preceding candidate, with dark cell boxes motivating this follow-up. That observation is Main-provided context, not this Reviewer's GUI evidence for the new cell patch.

Full-suite and Release work for this follow-up remain exclusively Main-owned; no completion or global-green claim is made here. The earlier baseline's 12 failed assertions across seven cases are historical integration context, not a result for this new patch and not grounds by themselves to fail it. Main must assess its fresh integration results separately.

Real candidate confirmation that idle app/folder boxes are gone, wallpaper remains visible, and focus/input remain usable is still a separate GUI/user gate. The synthetic and source-level acceptance criteria support **scoped PASS**, not packaged-app or global acceptance.

## Main integration update — 2026-09-11

This dated update supersedes the pending full-suite/Release status above. Attribution: Main's follow-up message; these fresh runs were not executed or independently re-audited by this Reviewer.

- Full suite: 1,528 tests, the same 12 failed assertions in the same seven prior failed cases; the three new tests passed. The reported failure set is unchanged, not globally green.
- Release: exit 0, 8.09 seconds. Candidate smoke: OK, as reported by Main.
- Candidate: `.build/cell-backdrop-20260911/Launchcopy.app`; reported executable SHA-256: `246adc55f107a425437cbe1fd2bec638479b571e10becd1605017117a3c8e4a6`.
- Main is beginning real GUI inspection. Its result is not yet available; the cell-patch GUI gate remains **UNVERIFIED**.
- Verdict remains **PASS — scoped cell-fill patch only**. Neither the unchanged known failure set nor a successful smoke check is represented as full-suite green or visual acceptance.
