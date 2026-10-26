# Folder Clear Backdrop — Independent Source Review

Date: 2026-10-16
Disposition: No actionable findings in the bounded change. Source review only; no runtime or visual acceptance verdict.

## Scope and authority

Reviewed the approved `Docs/FOLDER_BACKDROP_FEEDBACK_PROPOSAL.md` contract, current `Sources/AppGridUI/FolderOverlayView.swift`, `Tests/AppGridUITests/FolderMaterialPolicyTests.swift`, and directly related folder ownership, animation, input routing and cleanup in `Sources/PagingPrototypeApp/AppDelegate.swift` and `Sources/AppGridUI/FolderMotion.swift`.

The contract removes the whole-window dim while preserving panel material, layout, motion and modal outside-click dismissal. The user's explicit Chief-workflow waiver applies. No additional agents were dispatched. All shell calls used RTK. This reviewer ran no build, test, UI, install, kill or commit operation; read no reference implementation or global memory; changed only this report.

## Baseline and evidence identity

The supplied `.build/verification/20261016/folder-native-input/source-inputs-final.json` contains 463 entries. It is a source identity baseline, not evidence of current physical acceptance. The earlier startup-scroll repair belongs to that baseline and remains outside this review's acceptance claims.

| Input | Baseline SHA-256 | Reviewed SHA-256 |
| --- | --- | --- |
| FolderOverlayView.swift | `0f1bb040f3610106ae037cc05a5b427c6fc53433d616753b43e39ec6ea848489` | `8511ed8ba71b5b41793e4f24931df2c810927f8ebaeaa8a6a373514ffe2d921b` |
| FolderMaterialPolicyTests.swift | `b04b92ddb453ea195b17598620b28f3764d3ddbacea86f3daca746ee57925746` | `48c0d320dbba39e88ddd5b797e3e6bc527e733648fa8c2e5816af83a76c82082` |
| AppDelegate.swift | `55dac97ca278a569ad5ed70a66553648020edcd439dfa9a96e09460a1eb3890c` | Same |
| FolderMotion.swift | `000be7a60dbc2cf7d5b5e0b98ce4a33740f5324a8f04b3398cf5778bbefe54bc` | Same |

The working tree contains extensive older changes, so HEAD diff alone does not isolate this task. In-memory reversal of just the initializer background assignment and private `materialBackdropColor` getter (including its new comment) reproduces the exact manifest hash of FolderOverlayView.swift. This independently establishes that every other byte in that implementation file is unchanged from the supplied baseline. No file was modified to perform that comparison. The four reviewed hashes were rechecked immediately before writing this report.

## Source findings

No actionable defects attributable to the clear-backdrop change were found.

- **All root background writes remain clear.** Initializer line 364 assigns clear before mounting. `applyMaterialPolicy` lines 428–447 assigns clear for both collapsed and expanded states, for all Reduce Transparency / Increase Contrast combinations. Collapse line 815 assigns clear; restoration line 832 obtains the same unconditional clear getter. No black fill, tint, layer filter or background animation remains in this overlay implementation.
- **Lifecycle restoration cannot reinstate the old dim through these paths.** Configure lines 529–536 restores before its idempotency return; `clearContent` lines 566–582 and `teardown` lines 586–619 call the private restore directly. The private restore lines 821–833 bypasses the visual-only mutator guard for cleanup but now still assigns clear. `setVisualOnly` lines 455–507 never changes the fill; material updates return before changing stored policy on frozen or torn-down views.
- **Panel material and accessibility policies are unchanged.** Initial panel fill, border and radius remain at lines 366–371. Lines 434–440 retain the system window fill, explicit alpha 1 under Reduce Transparency, stronger label-colored 2-point border under Increase Contrast, and high-contrast footer text. The color-only delta does not alter accessibility exposure, title-editor ownership, focus callbacks, layout or member bindings. This is a code-preservation statement, not a measured contrast or VoiceOver result.
- **Panel-visible motion remains unchanged.** MotionParams lines 50–57 retain standard scale/displacement and the Reduce Motion identity geometry. AppDelegate lines 1443–1711 and FolderMotion.swift match their baseline hashes. Existing animation still targets the overlay root's opacity/transform, thereby animating its panel/subviews; it does not animate or replace the clear background with a tint. Retained exit preparation at lines 1569–1601 freezes the same overlay, and completion/cancellation at lines 1622–1668 removes it before cleanup/resume. No new exterior black fill is introduced by those owners.
- **Transparent exterior remains modal in source.** `hitTest` lines 899–918 still returns the overlay for the ordinary exterior and nil for visual-only/torn-down views; the editor and buttons keep their existing exceptions. `handleClick` lines 702–716 still requests close outside the panel. Production drag-coordinator routing remains at lines 725–754; AppDelegate lines 942–944 and 1055–1057 connect both dismissal callbacks to folder close. The window's open-folder guard at lines 4061–4069 still lets the event reach the overlay. No alpha-dependent hit-test condition was added.
- **Other black fills are not folder exterior replacements.** AppDelegate's existing black alpha-0.7 fill at line 1203 belongs to a small workspace-save notice, with explicit notice geometry at line 1205; it is not a whole-window folder dim. Existing wallpaper/container material is unchanged by this bounded patch.

## Test-source and existing-log evidence

`FolderMaterialPolicyTests.swift:73–89` now expects a clear exterior independently of panel opacity and contrast, retaining the panel assertions. Existing cases cover Aqua/Dark Aqua, both Reduce Motion values, all four material-policy combinations, pre-configure application, binding/geometry preservation, title-editor callbacks, collapse/restore through configure/clear/teardown, frozen-policy rejection and torn-down updates. The added regression at lines 333–356 checks clear fill, live outside hit-test/dismissal, inert visual-only hit-test/click and resumed dismissal.

I read `.build/folder-clear-backdrop-red.log`: XCTest executed **1 test with 3 assertion failures**, all at the new clear-color assertions (343, 348, 353), with the old alpha-0.35 background observed. This is genuine RED evidence for that added regression. The separate trailing Swift Testing message reports zero tests and is not an additional passing suite.

These assertions are synthetic host-level coverage. The new regression calls `handleClick` directly and does not itself exercise actual window event dispatch or the drag-coordinator mouse-up route. No post-change test completion is claimed here; Main owns serial SPM execution and its focused result.

## Physical boundary and handoff

Static evidence supports the approved bounded change and preservation of existing panel/input behavior. It cannot establish absence of every compositor frame artifact, perceived dark pulse, actual pointer/trackpad delivery, real accessibility preference rendering, or satisfactory visual contrast. Main retains the focused-test gate and physical opening/closing/interruption, title-edit, move-out and accessibility checks, including the earlier startup-scroll physical gate. User-visible perception still requires physical/user acceptance.

Changes made by this reviewer: only `Workflow/results/FOLDER_CLEAR_BACKDROP_SOURCE_REVIEW.md`.


## Bounded test-only follow-up — 2026-10-16

Verdict: No actionable findings in `Tests/PagingUITests/FolderRenameAssemblyTests.swift:563–587`, `testMaterialPolicyNotificationMapsFolderAndCancelsObsoleteDraftWithoutSave`. Replacing the obsolete exterior-alpha expectations with zero implements the user-approved visual contract; it is not test weakening.

- Lines 569 and 575 require exact exterior alpha **0** for high and normal policies. No tolerance, skip or conditional bypass was added to these assertions.
- Added lines 570 and 576 independently require panel background alpha **1** for both policies. The optional equality also fails if the panel layer/fill is missing. These checks preserve the opaque-panel requirement independently of the clear exterior.
- The method retains high/normal border widths **2 / 1**, the unaccepted draft followed by a policy notification and stale `editor.commit()`, the nil-editor check, unchanged persistent layout, drained empty writes, and the close/reopen normal-border check (lines 571–586).

Evidence identity: `.build/verification/20261016/folder-clear-backdrop/source-inputs-final.json` contains **463 entries**. Current hashes of all three scoped source/test inputs match this final freeze. FolderOverlayView.swift and FolderMaterialPolicyTests.swift also retain the exact hashes recorded in the original review above, confirming no intervening change to those reviewed files. FolderRenameAssemblyTests.swift is now `91d8d994b41b0616f3f0b3129c041a0f24581e0d42f4038edf277dd2e9ab822d`. This follow-up does not assert a byte-for-byte reconstruction of the rename test's earlier version or audit unrelated inputs.

I read the existing Main-produced `.build/folder-clear-backdrop-focused-r2.log`: XCTest reports **78 tests, 0 failures**, including the complete **FolderRenameAssemblyTests: 25 tests, 0 failures** suite. The trailing zero-test Swift Testing line is not additional passing coverage. Main reports that the preceding full run executed 2,791 tests with two stale-expectation assertion failures; that preceding full-run log was not independently inspected in this follow-up.

Scope and boundary: test-source review and read-only inspection of supplied evidence only. Main reports the three-input delta relative to the native baseline (one production file and two existing test files), and that the full rerun/package job is proceeding serially. No full-suite or package success is claimed. This reviewer ran no tests, builds or UI and appended only this report. Physical/user acceptance remains pending; the focused host-test result does not establish visual perception or physical input acceptance. The original source-review verdict and physical boundary remain in effect.
