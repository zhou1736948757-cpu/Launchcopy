# Library responder isolation results

Date: 2026-10-19.
Status: implementation handed off; independent review and final serial validation belong to Main. Source and test edits stopped on Main's request.

## Scope and diagnosis

Read `Docs/LIBRARY_CATEGORY_GALLERY_SPEC.md`, repository instructions and `/Users/mac/.codex/RTK.md`. Existing edits were retained. This worker changed only:

- `Sources/PagingPrototypeApp/AppLibraryOwnerController.swift`
- New `Tests/PagingUITests/LibraryResponderIsolationTests.swift`
- This result file.

The inspected close path called `reset()` and detached the Library without explicitly relinquishing its responder. The inspected reset ended editing only when its `hasPresentationOwnership` predicate recognized an `NSTextView`. Ending an editor alone does not establish that a Library control is no longer first responder; reset/closeDetails can also return focus to a Library control before removal. This is a source-level ownership gap consistent with the reported blue decoration. It is not a reproduced or visually confirmed native compositing diagnosis.

## Exact implementation

`close(restoring:)` now calls the private owner helper `relinquishResponder(in:)` twice: immediately before reset and again after reset, before removal. The first call retains ownership evidence while the subtree and editor are intact. The second handles synchronous focus reacquisition during reset/closeDetails.

The helper recognizes a responder view inside the Library subtree, the Library search field's current native field editor, and a field editor whose delegate control belongs to that subtree. It explicitly calls `window.makeFirstResponder(nil)` only after establishing ownership. If a Library responder survives normal resignation, it ends editing and retries resignation, checking current ownership after each callback. A responder acquired by another control during those callbacks is preserved.

No AppLibraryView changes or new internal view API were needed. Preview admission/cancellation and existing transition guards are unchanged. No global focus-ring suppression, application activation, key-window changes or NSApp focus operations were added. Restoring the grid remains the existing restore callback's responsibility after detachment.

## Regression coverage in the final source

The new test file contains 13 test methods using actual mounted, never ordered NSWindows, ordinary native editors, in-memory preferences and synthetic controls. Its window observer delegates responder operations to AppKit; it does not replace responder behavior.

1. Back releases the search responder while mounted and before query reset, then preserves the captured return context.
2. Swipe return releases the search responder before restoring first-page context and the grid responder.
3. Hide releases search without restoring the prior grid context.
4. Teardown releases search before detachment.
5. An owned nested control is released even when no field editor is active.
6. A different Library control's native field editor is released.
7. A nonowned control survives close.
8. The shared window editor, reassigned to grid search, retains its responder and marked text during Library hide.
9. Preview entry/cancellation retain the grid editor, composition and ownership without grid restoration.
10. Preview takes search focus only on commit and releases it on hide.
11. Rejected back/swipe admission preserves Library composition.
12. A nonowned responder acquired during resignation survives subsequent cleanup.
13. A reset-time ownership callback reacquires a Library control; cleanup explicitly releases it after reset while still mounted. This deliberately exercises the reset notification seam as a stand-in for synchronous browser focus restoration, rather than claiming a physical closeDetails reproduction.

## Verification and evidence boundary

- This worker ran no SwiftPM, compiler/build, UI or native-app verification, in accordance with Main's shared build-slot ownership. No process signals or production data changes were performed.
- Static inspection confirmed the pre-reset/post-reset/pre-removal order and private owner-only API. A read-only Python whitespace/hash inventory exited 0; neither source file contained trailing whitespace. The new file had 13 test methods.
- Earlier `rtk proxy git diff --no-index --check /dev/null ...` checks emitted no whitespace diagnostics and returned 1 because the files differ from `/dev/null`; those checks were not test executions and predated the last reset-focused addition.
- Main reported focused-r3: **60 tests, 0 failures** across Gallery 8, View 24, Preview 16 and Responder 12. This is Main-reported evidence, not a test run performed by this worker.
- **Snapshot limitation:** before Main's final stop message arrived, this worker had already added the post-reset cleanup and the thirteenth test. The reported 12-test responder run cannot certify the final 13-test source snapshot. Whether the two helper calls were present in Main's particular build snapshot has not been established here. Main must bind its independent review and serial validation to the final hashes below.
- Visible focus-ring disappearance after a physical swipe remains a native observation/user-acceptance gate. Mounted unshown-window ownership assertions alone do not prove that visual outcome. No task PASS or native acceptance is claimed.

## Final source identities

Captured after the post-reset update and before Main requested the edit stop:

| File | Lines | SHA-256 |
| --- | ---: | --- |
| `Sources/PagingPrototypeApp/AppLibraryOwnerController.swift` | 490 | `b1b9983f04f34e0c7a778f13fcd3a717eb15e763515589c7313a7f9682d7d6a7` |
| `Tests/PagingUITests/LibraryResponderIsolationTests.swift` | 331 | `a3b0aeeda8352a2146f98f6f12c0495fb139e4fb35ed6955b9bb16e5e9bd288e` |

## Handoff

Main can independently review the three owned files, then run the responder suite against this final snapshot and its serial full suite. Main owns any remaining gallery/legacy browser-test alignment and native candidate verification. No further edits or builds are running from this worker.
