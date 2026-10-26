# Folder dismissal, accessibility, and retained exit audit — r1

Date: 2026-10-19
Repository: `/Users/mac/Projects/Launch_Copy/PagingPrototype`
Mode: bounded, read-only source review; this report is the only authored file.

## Finding

**No concrete production branch was identified in the inspected dismissal lifecycle that leaves a logically closed folder mounted with its ordinary accessibility children exposed or deliberately keeps keyboard navigation routed to its members.** This is a source conclusion, not a source/native/performance PASS and not proof of correct VoiceOver behavior.

The supplied observation (AX totals 106 before opening, 166 after paging and Escape; the first 100 returned items omit modal controls) does not identify a surviving folder descendant. The screenshot reportedly shows the panel gone and the source folder selected. Those observations are compatible with the Escape source path below. Lazy rendering, a changed underlying grid inventory, enumeration limits, or stale tool/AX references remain possible explanations, not established diagnoses. No patch is justified by the totals alone.

## Evidence boundary and source identity

The project is a Swift Package targeting macOS 14+, with AppKit views in `AppGridUI`, paging infrastructure in `PagingUI`, application assembly in `PagingPrototypeApp`, and XCTest contracts. The application owner manages logical folder state and transition lifetime; the overlay owns member presentation and its AX child-list gate.

The supplied freeze manifest `.build/verification/20261019/library-drawer-focus/source-inputs-r1.json` contains 511 entries. SHA-256 comparison matched these 15 inspected inputs against that manifest at review time:

- `Package.swift`
- `Sources/AppGridUI/FolderOverlayView.swift`
- `Sources/AppGridUI/AppGridCellView.swift`
- `Sources/AppGridUI/AppGridCellFocus.swift`
- `Sources/AppGridUI/FolderMotion.swift`
- `Sources/PagingPrototypeApp/AppDelegate.swift`
- `Sources/PagingPrototypeApp/KeyboardFocusController.swift`
- `Sources/PagingPrototypeApp/FolderTitleEditor.swift`
- `Tests/AppGridUITests/HiddenLabelAccessibilityTests.swift`
- `Tests/AppGridUITests/FolderOverlayTests.swift`
- `Tests/AppGridUITests/FolderMotionTests.swift`
- `Tests/AppGridUITests/FolderKeyboardLogicTests.swift`
- `Tests/PagingUITests/AppDelegateBoundedRegressionTests.swift`
- `Tests/PagingUITests/FolderIntegrationTests.swift`
- `Tests/PagingUITests/FolderTitleEditorCompletionTests.swift`

This is not a fresh comparison of all 511 inputs and does not identify the running binary. The worktree contains concurrent pre-existing changes; none were edited or reverted. No tests, build, native UI, process inspection/control, reference application access, or subdelegation occurred. Runtime observations are user-supplied, not independently reproduced here.

## Production paths and precise source locations

| Path | Source trace | Consequence supported by source |
| --- | --- | --- |
| Escape with folder open and no title edit | `KeyboardFocusController.swift:478–485` → private close at `389–395`; assembly callback at `AppDelegate.swift:1044` → `closeFolder(animatedFromPointer: false)` at `1554–1575` | Cancels visual transition, closes logical state, then refreshes the overlay synchronously. It does not intentionally start an exit fade. |
| Synchronous closed refresh | `AppDelegate.swift:1830–1843` | With no open entry and no retained exit owner, clears content and removes the overlay from its superview. Reusable member views may remain in the detached overlay object; retained objects are not evidence of window AX reachability. |
| Member cleanup | `FolderOverlayView.swift:627–646`; `AppGridCellView.swift:225–240`; `AppGridCellFocus.swift:21–31` | Advances generation, clears entry/title/bindings/names/images, and clears member visual and accessibility focus. |
| Keyboard selection after close | `KeyboardFocusController.swift:389–415` | Restores the top-level folder identity or deterministic available fallback, applies outer focus, and clears internal member selection/seeds. This is application selection/focus handling, not proof of the VoiceOver cursor position. |
| Pointer outside/close request | `AppDelegate.swift:992–994`, `1559–1560`, `1633–1664` | Retains a visual only when mounted and source geometry is reliable. Calls `setVisualOnly(true)` before the subsequent logical close. Invalid/missing geometry falls back to synchronous removal. |
| Retained visual isolation | `FolderOverlayView.swift:515–577`, `738–746`, `967–968`, `1138–1147`, `1232–1246` | Suspends interaction callbacks, clears overlay/member AX focus, disables title-edit exposure, returns an empty AX children list while visual-only, rejects hit testing and paging actions, and drops late icon writes. Member native AX metadata is intentionally retained behind the parent gate. |
| Retained visual completion/cancellation | `AppDelegate.swift:1685–1731`; `FolderMotion.swift:74–78` | Generation-gates completion; detaches before clearing and restoring interactive mode. Cancellation also detaches before restoring. Reopening invalidates older completion generations. No inspected branch restores ordinary AX children while leaving a closed retained visual mounted across an asynchronous boundary. |
| Escape while an exit visual remains | `AppDelegate.swift:4012–4023` | Cancels the visual immediately through the same detach/clear path. |
| Title editing | `KeyboardFocusController.swift:478–485`; `AppDelegate.swift:2012–2026`; `FolderOverlayView.swift:719–746`; `FolderTitleEditor.swift:105–110` | First Escape while editing cancels the edit; a subsequent Escape closes the folder. Closing invalidates callbacks and unmounts the editor. The close transaction uses `returnFocus: false`; native responder behavior after removing an editor is not proved by this review. No concrete closed-folder AX/focus failure is established from that fact alone. |

All filenames in the table resolve under `Sources/AppGridUI/` or `Sources/PagingPrototypeApp/` as listed above. The inspected methods run synchronously within the application/UI transaction; temporary statements inside cleanup are not evidence of a persistent exported AX tree.

## Existing regression contracts inspected, not executed

- `Tests/AppGridUITests/HiddenLabelAccessibilityTests.swift:245–309`: checks the actual overlay child-list getter becomes empty in visual-only mode while descendant identity and pixels are retained; checks automatic children return on resume and same-count reuse. It does not query an external AX client or VoiceOver.
- `Tests/AppGridUITests/FolderOverlayTests.swift:200–285`: checks inert hit testing, callback/paging suppression, late-icon suppression, and frozen cleanup state.
- `Tests/PagingUITests/AppDelegateBoundedRegressionTests.swift:425–463`: search-editor handoff followed by first Escape and synchronous overlay detachment.
- `Tests/PagingUITests/AppDelegateBoundedRegressionTests.swift:613–684`: production assembly blank-click closure retaining an inert visual, Escape cancellation, immediate Escape during entrance, and normal exit completion detaching/clearing the view.
- `Tests/PagingUITests/AppDelegateBoundedRegressionTests.swift:709–720`: same-folder reopen rejects an old exit completion. Its interrupted-presentation helper at `686–697` explicitly uses model fallback when a native presentation tree is unavailable.
- `Tests/AppGridUITests/FolderKeyboardLogicTests.swift:178–274`: Escape/Command-F priority and deterministic restore-target rules. These pure contracts do not establish native responder or AX focus outcomes.
- `Tests/PagingUITests/FolderTitleEditorCompletionTests.swift:5–6`, `51–60`, `121–150`: synthetic delegate completion contracts explicitly exclude a claim about the cause of native AX/Escape behavior.

## Reproduction status and bounded regression evidence still needed

No defect reproduction was performed or established in this review. The supplied scenario is: open the user's 35-member source folder, click Next through the observed pages, then Escape; the panel disappears and its source folder is selected while inventory totals remain elevated. Its reported page labels are preserved without assuming whether the tool used zero- or one-based numbering.

A regression establishing an actual dismissal defect would need stable folder-descendant identities/ancestry, not only totals:

1. Capture named member and folder-only control identities and their window/parent chain while the folder is open, including a member on the final visited page.
2. After Escape returns, establish logical closure, overlay detachment, cleared member binding/focus, and top-level keyboard target. Query the full relevant AX subtree with pagination/truncation accounted for; show whether a captured folder descendant remains reachable from the live window. Distinguish a fresh reachable node from a cached object handle.
3. For pointer close separately, check that the still-mounted exit visual exports no descendants during the fade; after completion/cancellation, check detachment. Reopen during exit and ensure the old completion cannot remove or expose the new live presentation.
4. Check first responder, application keyboard selection, AX focused element, and actual VoiceOver navigation separately. A mismatch in one is not established by another's value. If title editing is involved, distinguish cancel-edit Escape from close-folder Escape.

The inspected tests cover pieces of these contracts but do not jointly establish external AX ancestry across the exact 35-member/multipage native scenario. No new test or native action is authorized by this report, and none was run.

## Assumptions and limits

The source design relies on AppKit honoring `accessibilityChildren() == []` at the retained overlay boundary and on detached reusable views not being discovered through the live window's automatic child hierarchy. This review inspected that explicit gate; it did not verify framework traversal, AX notifications/cache invalidation, native image-cell focus, stale external references, or the CUA enumeration implementation. A direct query to an already-retained object is not equivalent to proving live-window reachability.

The source does not promise that closing a folder restores a previous global AX node count. It does promise the local dismissal behavior traced above. Underlying page host population/enumeration and unrelated main-grid accessibility were outside this bounded audit. Missing controls in the first 100 of 166 items cannot establish their absence from the remaining inventory. Native accessibility acceptance remains unresolved; no production repair is proposed on the available evidence.

## Main provenance clarification
The runtime observations described as user-supplied above were supplied by Main from its own supported CUA session, not a new human acceptance report. The reviewer did not repeat them. This wording correction does not change the bounded no-concrete-defect verdict or its limitations. Reviewer closed after report delivery.
