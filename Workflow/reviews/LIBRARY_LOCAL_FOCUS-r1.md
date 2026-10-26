# Library local focus — independent bounded review r1

Date: 2026-10-19

Latest applicable verdict and input hashes are in the dated superseding checkpoint at the end of this report.
Verdict: **BOUNDED SOURCE ACCEPT** for the reviewed local-focus implementation and seven regression test definitions. No demonstrated production correctness defect requiring a repair was found. This is not an executed-test, build, native rendering, physical swipe, performance, or full-goal PASS. Main retains the critical path and all execution gates.

## Authorization and evidence boundary

Read RTK instructions, repository AGENTS.md, the last dated correction in Docs/LIBRARY_CATEGORY_GALLERY_SPEC.md, and Workflow/stage-summaries/2026-10-19-library-focus-local.md. Inspected actual current source and tests, not just the proposed mechanism. No SwiftPM commands, builds, UI actions, process signals, formal application data, reference applications, or reference source were accessed. Only this review report was written. Initial RTK bootstrap and memory lookup were read-only; subsequent shell inspection and this report write used RTK.

The user's physical blue-remnant failure on galleryr2/559c133c remains unresolved evidence. Main's later report of a first-page, inactive/title-gray/window-responder capture without a blue frame concerns a different state and cannot contradict the active-window physical report. That capture was not independently inspected in this review.

## Stable reviewed inputs

SHA-256, checked twice with unchanged values before writing this report:

| Input | SHA-256 |
| --- | --- |
| Sources/PagingPrototypeApp/LibrarySearchField.swift | 48da5cdd4751fb2dc9968203c69abef3c0cfc9bcb2b1f1ac8ecf065a0a782d30 |
| Sources/PagingPrototypeApp/AppLibraryView.swift | 4402e859044633d46f352420b2c7ff8fbbfb99dcf3a3ff4e2f51308adbd29988 |
| Tests/PagingUITests/LibrarySearchFocusDrawingTests.swift | 8b5a693f34f09ebc9a7caeaed6ef0774114b66ee332d6821bff2b82313c94525 |

Context inspected: AppDelegate.swift (e27d08db6b870e048bfd5b55e080733422abc6930c7430896577aa1dd0a926f8), AppLibraryOwnerController.swift (b1b9983f04f34e0c7a778f13fcd3a717eb15e763515589c7313a7f9682d7d6a7), LeadingLibraryNavigator.swift (e9183f4a95cc9ff3be4e4e3f3209a4f195fcfb5e38daa44bfaa37ddfa025f9e6), AppSearchController.swift, AppSearchFieldView.swift, LibraryResponderIsolationTests.swift, and existing AppLibraryViewTests.swift. The repository is substantially dirty and Library inputs are untracked; git diff alone would not define the repair. New-control source was read in full, and AppLibraryView integration was checked against the earlier live read in this audit.

## Actual parent/window/editor path

1. AppDelegate.swift:2616-2682 wires parent navigation. render applies setAffineTransform to the individual grid roots and the Library root. The Library translation is -offset * host width; grid roots use (1 - offset) * width. The native main search is itself one of those grid roots (2702-2705). Wallpaper is outside this moving set. Reduce Motion uses identity transforms plus opacity.
2. LeadingLibraryNavigator.swift:184-202 commits a completed return through owner.backToFirstGridPage(), then configures/resetPresentation/setGridPreviewVisible(false). AppLibraryOwnerController.swift:241-275 resigns owned focus before reset, rechecks after reset, and removes the Library before restoring grid context. On a successful return, the removed Library root is no longer available through owner.view when parent reset executes; this is a lifetime fact, not evidence of surviving compositor pixels.
3. AppLibraryOwnerController.swift:279-300 proves current ownership from the search currentEditor, editor delegate/control ancestry, or responder ancestry before makeFirstResponder/endEditing. It rechecks after callbacks, so it does not intentionally resign a newly acquired grid editor. Existing mounted tests exercise shared-editor reuse and marked text preservation for another owner.
4. No custom window fieldEditor override/replacement was found in Sources. The visible code uses AppKit's native NSSearchField/currentEditor route. The actual runtime editor superview/layer hierarchy and compositor presentation state were not observed; window-owned editing does not by itself prove that editor pixels escape the moving subtree.
5. AppDelegate.swift:2720-2725 rejects navigation while the actual first responder has marked text. backToFirstGridPage sets searchWasFocused=false; restoreGridAfterLibrary (2739 onward) then requests the keyboard controller for a swipe return. Ordinary Back can deliberately restore the captured grid-search focus. These are distinct focus outcomes.

## Source assessment

- **Local drawing is bounded.** LibrarySearchField.swift:35-51 uses the control's bounds, a 1.5-point centerline inset, and a 2-point stroke: the geometric stroke has a 0.5-point margin. An explicit bounds clip also contains antialiasing. Bounds below four points yield no stroke. No window-coordinate path, external focus-ring mask, global override, or added layer sibling is created.
- **Replacement remains narrow.** Only this NSSearchField and its existing cell receive focusRingType.none (11-15). Native super.draw, native editing, native field editor, clear/search cell controls, query handling, delegate, and accessibility identity remain in place. wantsLayer is local to this control. Other controls retain their own focus policy.
- **Invalidation is conditional.** refreshFocusPresentation (23-31) updates cached ownership every call, but only requests display when visible emphasis changes. Repeated window updates therefore do not create an unconditional focus redraw loop. Effective-appearance changes independently request display, which is appropriate for the dynamic system focus color.
- **Integration order is sound for its scope.** AppLibraryView's notification handler filters foreign NSWindow objects, refreshes focus before the icon path, and does not place refresh behind window-visible/result-list/icon-pipeline early returns. Editing begin/end also refresh before readiness callbacks. layout refreshes after visibility changes and responder handoffs. didResignKey is now observed alongside didBecomeKey/didUpdate.
- **Removal clears the cache.** viewDidMoveToWindow refreshes after super; on detachment window is nil, focused and visible resolve false, and any previously visible decoration invalidates. The notification handler cannot re-enable a detached field from a foreign old-window notification because the window identity filter rejects it. Hide/unhide callbacks recompute visibility without resigning editing.
- **No IME mutation in the replacement.** The new code does not change text, selection, marked ranges, input context, first responder, or editor delegate.

Apple's official [NSView focusRingType documentation](https://developer.apple.com/documentation/appkit/nsview/focusringtype) and [NSCell focusRingType documentation](https://developer.apple.com/documentation/appkit/nscell/focusringtype) were read through their official Markdown endpoints. They permit replacing default rings with a custom indication and assign custom drawing responsibility to the view. They do not diagnose this user's remnant or certify this particular drawing as visually sufficient.

## Non-blocking verification risks and concrete discriminators

### P2 — Exercise the actual post-handoff notification path

Evidence: LibrarySearchFocusDrawingTests.swift:93-107 manually calls refresh after makeFirstResponder(nil); 120-139 manually invokes begin/end delegate methods. The 30-repeat check (110-117) calls refresh directly rather than posting didUpdate notifications. These prove the state function and observer wiring for key notifications, but not the full native editing-end ordering.

Risk: become/resign and native editing notifications may run while a window's firstResponder transaction is still in progress. Immediate refresh can temporarily read the previous owner; the real AppLibraryView didUpdate handler is the later reconciliation path. No stale-state failure was demonstrated, so this is not a production-bug finding.

Recommended Main-owned check: mount an AppLibraryView with another native search/control in the same unshown window; acquire the Library editor, transfer focus through makeFirstResponder, and allow actual editing callbacks without manually invoking delegate/refresh methods. Verify final state after a real or explicitly delivered didUpdate notification. Verify a reused shared editor now belonging to the sibling does not light the Library stroke or lose marked text. For teardown, assert both focus flags false immediately after removal without manual refresh. Repeated didUpdate notifications with an unchanged state should leave needsDisplay false after the first transition is consumed. Preserve the no-test-execution boundary of this report.

### P2 — The native main search and other native rings remain possible alternate owners

Evidence: AppSearchFieldView.swift keeps its native focus ring; AppDelegate translates that control as a separate grid root. Result/category tables, category picker, detail controls, and gallery buttons also retain native focus behavior. Existing teardown ownership covers Library descendants, but replacing one ring does not replace all possible blue outlines.

Recommended discriminator if the remnant persists: record whether the starting responder was Library search/editor, result table, category control, or another control; distinguish ordinary Back from completed swipe. Compare the outline's dimensions/location with the Library search, main search, and active list. For a completed swipe the semantic target should be the keyboard controller; for ordinary Back a restored main-search ring may be intentional. Use an isolated candidate and Main's permitted observation path. Do not infer root cause merely from a matching rectangle.

### P2 — Layer presentation/editor pixels still require native evidence

The layer transform source establishes which application-owned roots move. It does not establish actual editor hierarchy, live clipping, presentation-layer settlement, or which pixels survive after removal. Compare successful swipe, cancellation, focus transfer before swipe, and key-window loss/return using the same isolated candidate. If the new local stroke itself remains, separate stale local drawing from native editor decoration or another native control before expanding scope. No navigator/physics workaround is justified by this source audit.

## Seven-test source review and remaining gates

The seven definitions cover local/native policy isolation, bounded geometry, ancestor-transform invariance of local bounds, native editor/marked-text retention under controlled key emphasis, resignation/removal, stable-state conditional invalidation, and AppLibraryView key-notification integration. The fake isKeyWindow getter is explicit and appropriate for deterministic unshown-window tests; it does not prove shown-window behavior. The ancestor-translation test checks a local rectangle and focus policy, not rasterization, clipping, compositor cleanup, or a physical gesture. Existing command/AX/responder-isolation tests supply relevant continuity coverage.

No tests were run and no compile warnings/results were adjudicated. Main's focused compilation was still in progress when reported. Main must own nonzero executed focused/full results, Debug/Release/package evidence tied to current inputs, active-window visible focus/clear/Return/Escape/IME/AX checks, and the user's completed physical swipe confirmation. Neither the old full-suite count nor a no-blue inactive-window capture closes those gates.

Conclusion: proceed with Main's serial verification on these hashes. Preserve the user's physical FAIL and the causal uncertainty until new matching-state evidence is available.


## 2026-10-19 superseding checkpoint — final refresh API, eight tests, and API geometry check

**Current verdict: BOUNDED SOURCE ACCEPT on the hashes below.** This checkpoint supersedes the earlier seven-test snapshot and the conditional-redraw fixture recommendation. Historical observations above are retained explicitly.

| Current input | SHA-256 |
| --- | --- |
| LibrarySearchField.swift | 793e21b378d1c79ba944cf3900d91a0a86cd9a0fd12b2c8d8011d876055800db |
| AppLibraryView.swift | 4402e859044633d46f352420b2c7ff8fbbfb99dcf3a3ff4e2f51308adbd29988 |
| LibrarySearchFocusDrawingTests.swift | fd0ea2dba0a2ffb05cad6d9ba6c5c7bb939f09834b849950d6c6c145ad03a52a |

### Final method and fixture correction

Reviewed the revised method and complete changed test region directly. refreshFocusPresentation now returns a discardable Bool. It updates both cached flags before guard changed, requests needsDisplay only on the changed branch, and returns whether this invocation requested focus redraw. Existing callers may ignore the result. The drawing geometry, native editing route, and AppLibraryView integration are unchanged.

The revised stable-state test asserts false for 30 unchanged focused refreshes, true on key loss, false for 30 unchanged non-key refreshes, and true on key regain. This is a legitimate narrow test of this method's redraw admission. NSView.needsDisplay is an aggregate native rendering state, so the old assertion could fail for unrelated native editor/layer work. The revised return-value assertion does not prove absence of all AppKit redraws or real notification delivery, and makes no such claim.

Read Main's completed focused-r1.log tail: XCTest reports **60 executed, 1 assertion failure**, with the failure at the old aggregated needsDisplay assertion; the local suite reports 7 executed, 1 failure. The subsequent Swift Testing zero-test footer does not override XCTest. The log establishes the failure location, not which internal native component set the dirty flag. No successful execution of the revised source is claimed here.

### Post-handoff risk addressed in test source

The new eighth test, testActualEditorHandoffReconcilesThroughWindowObserverWithoutManualRefresh, mounts a real AppLibraryView and sibling native search field. It acquires focus through the production focusSearch path, transfers via makeFirstResponder(sibling), installs sibling marked text, posts didUpdate through the actual registered observer, and checks both Library flags false while preserving sibling editor identity and marked state. Removing Library then checks both flags false and preserves sibling editing again. It does not manually call refresh or the delegate notifications. The standalone removal test now checks both flags immediately after detachment.

This addresses the earlier P2 post-handoff/observer test-source gap. Notification posting is an explicit deterministic reconciliation seam, not an observed AppKit event-loop or compositor result. The native rendering/physical gates remain.

### Cell mask bounds and draw-vs-updateLayer API check

Inspected the installed macOS SDK NSCell.h:225-226 and NSView.h:245-257, plus Apple's official documentation:
- [focusRingMaskBounds(forFrame:in:)](https://developer.apple.com/documentation/appkit/nscell/focusringmaskbounds(forframe:in:))
- [wantsUpdateLayer](https://developer.apple.com/documentation/appkit/nsview/wantsupdatelayer)

Cell mask geometry is returned in control-view coordinates, so intersecting it with field.bounds is coordinate-consistent for this proposed call. Reading that geometry does not require enabling external focus drawing according to any documented precondition found here. However, the base method can return empty, and the documentation does not guarantee NSSearchFieldCell will supply a snug bezel rectangle while focusRingType.none, for every focus/style/state. Do not toggle native ring policy or editor ownership just to obtain geometry.

Recommended Main-owned synthetic checks before adopting it: native cell class, mask bounds with .none for 28/40-point heights, editing/nonediting states, effective appearance/control size, and zero/narrow geometry. Require finite/nonempty usable intersections with a deterministic bounds-based fallback. Intersect first, then inset for the two-point stroke and retain explicit bounds clipping. A bounding rectangle does not recover the exact native mask shape, so a capsule drawn inside it remains a custom indication; native visual review determines whether it is suitably snug. A possible 40-point frame versus approximately 24-point native bezel mismatch is not established by source alone.

The NSView documentation gives the default draw path as false for wantsUpdateLayer; the SDK adds that AppKit controls often use layer updates until subclass drawing overrides require drawRect. LibrarySearchField does override draw, so the current source is consistent with the documented draw route. That is not a runtime getter observation. Main should verify wantsUpdateLayer on the actual subclass and actual rendered stroke; if it unexpectedly returns true while canDrawSubviewsIntoLayer is false, draw would be bypassed and the visible replacement would need correction. No such failure was observed by this read-only audit.

No mask-geometry or wantsUpdateLayer implementation change was made or reviewed at this checkpoint. Any later geometry/drawing patch needs a fresh hash-bound delta check. Main retains tests, builds, packaging, native checks, and physical confirmation. The user-reported physical FAIL and unproven cause remain open.


## 2026-10-19 final source addendum — native cell geometry and nine tests

**Final applicable verdict: BOUNDED SOURCE ACCEPT. No blocking source finding.** This supersedes the preceding checkpoint's statement that cell-mask geometry had not yet been implemented. It remains independent of test execution, native rendering, and physical acceptance.

| Final reviewed input | SHA-256 |
| --- | --- |
| Sources/PagingPrototypeApp/LibrarySearchField.swift | 3613e4bfacff2a245441ab101d1efadb8414997aa28efc59781a38ad749af65f |
| Sources/PagingPrototypeApp/AppLibraryView.swift | 4402e859044633d46f352420b2c7ff8fbbfb99dcf3a3ff4e2f51308adbd29988 |
| Tests/PagingUITests/LibrarySearchFocusDrawingTests.swift | 822dc4386b2cb7ab3f27c6b9ffb60038b3d60c7b63063e17e0cc03510c49b325 |

### Last geometry delta

LibrarySearchField.swift:43-49 reads the current native cell mask bounds in the owning control's coordinate space, intersects with local bounds, falls back to local bounds for missing/empty geometry, and applies the existing centerline inset. draw (51-62) retains the explicit bounds clip and two-point stroke. Cell-mask queries are reached from drawing through this computed property; no per-frame query, stored window geometry, responder mutation, external ring enabling, new timer, or parent change is introduced. The production cell is an AppKit-owned native search cell; this review does not require generalized malformed custom-cell geometry support.

The delta is coordinate-consistent with the documented API and preserves the local ownership/lifetime objective. It can track a native bezel rectangle smaller than the 40-point view frame when AppKit supplies one. It still draws a custom rounded rectangle from bounding geometry, not an exact reproduction of the native mask path. No actual 24-point bezel measurement or visual fit is claimed.

The new ninth test (59-69) checks the actual mounted cell's mask/intersection/fallback result, complete stroke containment at the fixture's 640-by-40 size, wantsUpdateLayer false, and unchanged external-ring disabling. Reading this test is not observing its assertion pass. It covers the concrete fixture, not every appearance/control size/OS; Main's native visible replacement check remains necessary. No documented prohibition on reading mask geometry with focusRingType.none was found.

### Actual notification regression rechecked

Re-read final lines 136-164: production focusSearch starts native editing, makeFirstResponder transfers to the sibling, actual registered AppLibraryView notification handling is exercised by explicit didUpdate posting, and both Library flags must clear. Sibling editor identity and marked state must survive the reconciliation and Library removal. There are no direct refresh calls or manufactured editing-delegate calls in this test. The separate older notification test still uses explicit delegate callbacks but is no longer the sole handoff coverage. The standalone removal case checks both cached flags immediately after detach (117-120).

The earlier P2 notification-path test-source gap is addressed. The final conditional-redraw Bool test remains appropriately scoped to the implementation's own invalidation request rather than NSView's aggregate dirty state.

### Final limits and next action

Main should freeze these final hashes after successful nonzero focused execution, then own full/build/package and native evidence. This reviewer ran no tests or UI and does not adopt results for earlier hashes as results for this patch. The first focused-r1 failure is preserved above. Native main-search/other-control rings and live editor/layer presentation remain alternative artifact sources if a new isolated candidate still fails; no broader changes are authorized or justified by this review.

The active-window user-reported physical FAIL on galleryr2 remains open until matching-state new evidence and the completed physical swipe gate resolve it. Inactive-window absence of blue, source containment, local geometry tests, and Apple's API permission cannot establish compositor root cause or physical cleanup.


## 2026-10-19 final freeze delta — explicit draw path

Final verdict remains **BOUNDED SOURCE ACCEPT**. The latest applicable LibrarySearchField.swift SHA-256 is **121f560a682499af179cc24938e925081de89937722264a7f5f4a58adde359bb**. AppLibraryView.swift remains 4402e859044633d46f352420b2c7ff8fbbfb99dcf3a3ff4e2f51308adbd29988 and the nine-test file remains 822dc4386b2cb7ab3f27c6b9ffb60038b3d60c7b63063e17e0cc03510c49b325.

The only source delta from the preceding reviewed snapshot is override var wantsUpdateLayer: Bool { false }. Verified by removing that single line in memory and obtaining the preceding source hash 3613e4bfacff2a245441ab101d1efadb8414997aa28efc59781a38ad749af65f. No file was modified during this comparison.

This explicitly selects the draw-based path for this subclass, agrees with its custom draw implementation, and removes reliance on the inherited AppKit control getter. super.draw still executes first. The native editing/IME/AX route, geometry and clipping, conditional invalidation, ownership/lifecycle, and parent navigation are unchanged. No blocking finding.

The wantsUpdateLayer assertion now protects the explicit subclass contract, rather than measuring an inherited default. It still does not demonstrate actual drawn pixels. Per Main, focused-r3 may predate this line; it is not accepted here as verification of this final hash. A frozen rerun and subsequent native/physical gates remain Main-owned. No further source review action is pending unless these inputs change.


## 2026-10-19 superseding native-renderer refinement — child decoration, ten tests

**Latest applicable verdict: BOUNDED SOURCE ACCEPT for this refinement. No blocking source finding.** This supersedes the earlier recommendation/acceptance of an explicit draw-based implementation. Main subsequently reported native visual defects in that prototype (clipped magnifier and loose focus frame); prior source acceptance and passing automated tests did not establish visual fitness.

### Reviewed inputs and scope

Read the current LibrarySearchField.swift and LibrarySearchFocusDrawingTests.swift in full, the appended Native-renderer refinement specification, and the appended stage checkpoint. AppLibraryView.swift was hash-checked and remains the previously reviewed integration. No SwiftPM, builds, UI, processes, or formal data were accessed in this follow-up. Only this report was appended.

| Current reviewed input | SHA-256 |
| --- | --- |
| Sources/PagingPrototypeApp/LibrarySearchField.swift | c96e7de252cfc2c8ec7a9f734ffee5392ac9c353ad4cf4086717de5b1e1ca40f |
| Sources/PagingPrototypeApp/AppLibraryView.swift | 4402e859044633d46f352420b2c7ff8fbbfb99dcf3a3ff4e2f51308adbd29988 |
| Tests/PagingUITests/LibrarySearchFocusDrawingTests.swift | 0cd95ddb162485657301fdf13bb735116b472f46a1f114db42c17d861558e930 |

### Production source assessment

- **Native rendering policy preserved in source.** There is no draw, updateLayer, or wantsUpdateLayer override, and no explicit wantsLayer assignment to the search field. Only the decorative child requests layer backing. The control/cell focusRingType.none policy remains local. Native magnifier, clear control, text/selection, native editing delegate, and field-editor rendering have not been replaced by application drawing. Runtime parity is appropriately asserted separately; source removal of overrides alone is not a visual proof.
- **Contained decoration and geometry.** The new private NSView belongs to the search field's subtree. Its frame derives from the current bounds and finite positive intrinsicContentSize.height, capped at the control height and vertically centered. Missing/invalid intrinsic height falls back to bounds height. The existing inset helper returns empty below its four-point minimum; otherwise the entire decorative frame is inset by 1.5 points. The two-point CALayer border draws inward, so this implementation does not rely on a centered stroke extending outside its frame. Corner radius uses the child's current height.
- **No separate lifetime or window coordinates.** The child is added once, framed at initialization/layout, and removed with its parent. There is no window overlay, detached sibling, standalone animation, timer, parent pager change, or catalog projection. Ancestor translation remains inherited structurally.
- **Input and accessibility isolation.** The decoration's hitTest always returns nil and acceptsFirstResponder returns false; it is explicitly accessibility-hidden. It has no controls, target/actions, tracking areas, gesture handlers, or editing delegate. This does not intentionally displace the native field editor or clear/search controls. Actual native targeting remains a UI gate.
- **Focus synchronization retained.** Ownership and visible emphasis are recomputed as before; both flags update before the unchanged-state early return. Only emphasis changes toggle the child's isHidden and update its color. Detached window state resolves to false and hides a previously visible decoration. Layout updates geometry independently; appearance updates resolve the dynamic system color under the control's effective appearance. There is no repeated per-window-update geometry/redraw request added.
- **Scope matches the amended specification.** The rendering strategy changed explicitly in the spec; the visible local focus, native editing/IME/AX, lifecycle, and no-physics-change contracts remain intact. AppLibraryView integration hash is unchanged.

The intrinsic-height rectangle is a practical geometry choice, not proof of the exact painted native bezel shape on every OS/appearance/control size. It should remain a visual acceptance item rather than an inferred defect or a claim that this source fixes the original physical remnant.

### Ten-test source assessment

The replacement test at lines 59-71 compares wantsUpdateLayer and intrinsic height with an ordinary NSSearchField and checks the computed local frame. This appropriately replaces the superseded forced-draw-mode assertion. It exercises the mounted 640-by-40 fixture, not all native styles.

The new decorative-child test at 73-86 obtains the actual identified child, checks nil hit testing, refusal of keyboard focus, AX-hidden state, visible decoration after native search focus/layout, and frame equality/containment. Its hitTest sample is limited, but the production override is unconditionally nil, so no input-interception defect is indicated.

The production native-editor transfer/window-observer regression remains at 153-181: no direct refresh or fabricated editing delegate calls are used there; sibling editor identity and marked state survive notification reconciliation and Library removal. Removal still checks both cached Library flags. The other tests retain native editor, IME, scoped policy, hide/key state, conditional-update, and helper-geometry coverage. The ancestor-translation test remains local-geometry evidence only.

No test was executed by this reviewer. The earlier prototype's full3245/0 and build/package evidence are historical for this changed rendering strategy; they are not adopted for the current hashes. Main must obtain renewed nonzero focused/full/build/package evidence.

### Remaining bounded gates

Main's native check should verify the active magnifier is fully visible, the border fits the intrinsic bezel, text/selection/marked text and clear button remain usable, and the border does not cover or intercept native controls. Key loss/regain, focus transfer, and return/removal should be observed in the new candidate. These are existing native acceptance obligations, not new implementation scope.

The user's completed physical swipe gate remains unresolved. Native main-search/other-control focus and live editor/layer presentation remain possible alternate artifact sources if failure persists. Neither this child-layer implementation nor its local containment establishes a compositor root cause. No broader native focus-ring change is recommended by this review.


### Refinement freeze handoff
Final source hashes were rechecked after writing this refinement review and match the table above. Main subsequently reports focused63/0 including ten local-focus cases and a frozen532 r2 manifest, with renewed serial verification/package still running. This is Main-reported evidence, not an independently inspected test result in this narrow source review. AX-hidden setter/getter and raw accessibility exclusion do not establish VoiceOver navigation or announcement behavior. The verdict remains BOUNDED SOURCE ACCEPT for the unchanged overlay/native-mode patch, with native visual and physical gates open.
