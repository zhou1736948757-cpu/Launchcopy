# Hidden-label accessibility checkpoint — 2026-10-15

## Status and outcome
Full independent LaunchBetter-experience parity remains ACTIVE/incomplete. Previous turn fixed appearance draft dismissal and produced2657/0 plus native Apply/default/restart evidence. This continuation repaired the observed loss of application/folder names when visual captions are hidden. The bounded naming repair has source, XCTest, package and actual native-tree evidence. It does not close full appearance, VoiceOver or whole-product acceptance.

A later native rename check produced an independent unresolved anomaly: AX-set title draft followed by Escape became the saved title. The synthetic title was restored to Group1 using Return. Do not classify that Escape check as PASS or assume its cause is this accessibility delta.

## Actual naming owner and root cause
AppGridCellView retains complete metadata on a custom view, but the actual exported image is the existing NSImageCell inside NSImageView. A synthetic diagnostic confirmed NSImageView is an ignored AXUnknown wrapper and its NSImageCell is an exposed AXImage leaf. Merely hiding caption text therefore removed the only named exported child despite cell.accessibilityLabel property tests remaining green.

A wrapper-only test assumption initially failed too. Initial7/114 and R2-fixture7/102 RED logs are retained, but are not clean native-cell RED evidence. Initializing NSApplication did not fix the ownership assumption. Main corrected the tests to inspect the real NSImageCell rather than forcing a wrapper role. The one-test owner diagnostic passed, was retained as a log, and its temporary test was removed. Correct native-cell baseline RED:7 tests/55 assertion failures.

## Bounded implementation
Relative to the prior452-input appearance baseline, only:
- Sources/AppGridUI/AppGridCellView.swift.
- Sources/AppGridUI/FolderOverlayView.swift.
- New Tests/AppGridUITests/HiddenLabelAccessibilityTests.swift, seven tests.

The existing exposed image cell gets the full app/folder name only while captions are hidden. Visible captions, clear and inactive app/folder branches receive an explicit empty image label to suppress stale names and system-symbol fallback descriptions. Hidden folder image help follows the existing deferred localized count formatter. Updates occur only at existing bind/clear/visibility/deferred-text boundaries, not animation/layout frames. No image/view replacement, role changes, new activation route, icon request/token changes, persistence schema, geometry or paging physics.

The drawing-only proxy host always returns an empty accessibility child list. A retained visual-only folder overlay returns an empty list, while an interactive overlay delegates to super. The first mutable empty/nil-child setter attempt failed resume (focused78/2): nil did not restore automatic children. That attempt was replaced by the conditional standard override; the failure remains in focused-r1.log.

Independent R1 review found one P2: the pre-existing visual resume loop set member wrappers accessibilityElement=true, adding a second naming owner around the new image names. Actual strengthened regression reproduced1 test/4 assertions. Parent child exclusion now owns frozen-subtree suppression, so R2 removes only that obsolete per-member flag mutation and preserves native member exposure across resume and close/clear/same-count rebind. No new ownership cache or policy. Native R1 did not visibly show duplicate wrappers; that observation was not used to dismiss the source-level counterexample or infer VoiceOver speech.

## Verification and independent review
- Worker Herschel authored only the initial new test file, including proxy/resume follow-ups;0 tests/builds/UI. Main corrected the native owner assumptions and strengthened the reviewer regression. Worker closed.
- Final focused78/0,3.416s, including all7 new tests.
- Final full2664/0,59.845s. R1 full2664/0,59.370s remains historical pre-P2-repair evidence.
- Final Debug and Release/package success; diff check passed.
- Packaged localization288 keys/3 languages positive exit0; deliberate missing-key and invalid-signature negatives exit1.
- All453 final input hashes verified after native work; only2 production inputs/newtest differ. All18 PagingCore/PagingUI sources, resources, existing tests, package/scripts and previous close/discard fix remain unchanged. Two owned before copies match the prior manifest; exact bounded diff retained. R1 manifest/diff preserved separately.
- Reviewer Avicenna: original SOURCE FAIL retained in Workflow/results/HIDDEN_LABEL_ACCESSIBILITY_SOURCE_REVIEW.md. Fresh R2 SOURCE PASS closes P2, no remaining actionable bounded finding; all453 hashes independently verified and R1-to-R2 delta reconstructed. Report: Workflow/results/HIDDEN_LABEL_ACCESSIBILITY_SOURCE_REVIEW_R2.md. Reviewer0 Swift/build/tests/UI/process control; closed. All Main jobs terminal.

These layers are not interchangeable: source PASS does not certify native/VoiceOver, and synthetic tests are not physical performance.

## Exact current candidate
Unsigned, uninstalled:
/Users/mac/Projects/Launch_Copy/PagingPrototype/.build/candidates/hidden-label-accessibility-rc-20261015-r2/LaunchcopyUITest.app

Executable SHA-256:4f15b1333d6e030c48e1c6ab7dc8d4ffd687517e5491f0f6bcc82e289a4c2ca8.

Candidate-local ordinary non-topmost window and isolated profile; forty owned Info-only fixtures, not real executable-app launch evidence. R1 cd46a756... remains historical; do not use it as final source acceptance.

## Supported native R2 observations
1. Saved captionsOff acknowledged. Actual full tree exports named AXImage apps HandoffDemo06..40 and Group1 image description with Chinese five-member help. Captions absent visually; the naming owner is not just an ignored custom-view property.
2. First folder open exposes all five member image names01..05. Close removes member nodes. Second open: each member name occurs exactly once in the full tree; screenshot shows title retained and visual member captions absent.
3. CaptionsOn Apply acknowledged: native grid named-image count0 and textual app caption count35 across mounted pages. Folder members likewise have five text captions and zero named member images. The exposed tree includes mounted pages/background grid: this is not proof of modal or visible-page-only VoiceOver navigation.
4. True persistence: R2 PID62456 -> normal menuQuit -> exact executable absent -> same candidate PID64021. Actual startup tree remains named images, settings restore Off/18/48/11. No fake singleton-only restart claim.
5. Final test profile defaultsOn/18/48/11 applied/acknowledged; restored Group1 title using Return as described below. No second restart of final defaults/title claimed. PID64021 normal menuQuit -> exact executable absent; no native query afterward. R1 PID58145 was separately normally quit before R2 source work.
6. Retained-exit/proxy child exclusion is source/unshown regression evidence, not an actual captured180ms native exit/drag tree. VoiceOver speech/actions/focus/notifications remain separate.
7. Wallpaper diagnostic remained loading and inspected background black in these R1/R2 runs. This slice does not claim wallpaper readiness, a delay-cause repair or complete appearance acceptance. Historical ready/visible runs remain different observations, not current proof.

## Unresolved native rename anomaly and next action
After the R2 restart with captionsOn, actual rename button opened the existing editor. AX setValue changed Group1 to `R2 cancel-only draft`; pressing Escape ended editing and changed the actual title to that draft rather than cancelling. Native tree confirmed the change. Reopened editor, AX-set Group1 and Return restored the actual title; a subsequent Escape closed the folder normally. R1 AX-set+Escape had restored Group1, while an earlier R1 typeText attempt did not insert. These inconsistent input routes must remain visible in the evidence.

No claim yet that this is caused by the R2 delta, a physical Escape failure, an IME issue, or merely an automation artifact. Source discovery anchor: Sources/PagingPrototypeApp/FolderTitleEditor.swift:59-80 handles cancelOperation through cancel(), but controlTextDidEndEditing unconditionally commits. Actual text-movement notification, field-editor ownership, app/window activation, event ordering and application escape route have not been captured.

**Next executable action:** start a bounded rename-cancellation diagnostic stage. Preserve this453-input/4f15... baseline, use the same isolated native profile, compare real focused editing with AX string-setting, inspect existing field-editor/escape/end-edit ownership and add an actual production-path regression before a causal repair. Do not weaken intentional focus-loss commit, bypass IME, alter launch/paging routes, or claim a product root cause from a single routed tool event. Existing approved Escape-cancel behavior authorizes maintenance; no unapproved feature is needed.

## Evidence / remaining full-goal boundaries
Evidence:.build/verification/20261015/hidden-label-accessibility/. Includes initial/corrected REDs, owner diagnostic, focused attempts, full R1/R2, Debug/Release/package/probes, before sources, R1/final453-input manifests/diffs, native-r1-process/quit, native-r2-process-before/restart/quit/final-quit and native-r2-results.json. JSON observations summarize inline tool AX/images; no raw screenshot files or fabricated traces are asserted.

Prior status old-callback discriminating assertion and combined locale+Library follow-ups remain. RealIME/Tab/VoiceOver, matched physical60Hz AB, unresolved>25ms causality,120Hz/multidisplay/powerloss, failure dialogs/scanner/source/management lifecycle and full parity remain independent. Capacity/rows/columns/anchor, usage/history, destructive/extra gestures remain separately unapproved. No installation/signing/notarization/publication/commit/push/reset/cleanup/deletion/processkill, formal app/data modification, reference code/resource read, OS setting/Space change or unrelated-app control. Existing dirty tree preserved.
