# Independent bounded source review: pointer release ownership R1

Date: 2026-10-25  
Verdict: **SOURCE PASS**  
Actionable findings in the frozen three-path delta: **None**.

The minimal repair addresses the two demonstrated callback-reentrancy ownership defects. This verdict is limited to the source delta and inspected execution records. It does not establish the cause of the intermittent physical first-drag failure, actual nested native-event delivery, universal reentrancy safety, native acceptance, performance, packaging acceptance, or full application parity.

## Authority and scope

Repository: `/Users/mac/Projects/Launch_Copy/PagingPrototype`. This is a SwiftPM macOS 14+ AppKit launcher. Window-level B1 manual delivery owns the captured cell; the MainActor drag UI coordinator owns pointer arbitration, recognizer suppression, and click dispatch. The domain controller emits `.clicked` after resetting its completed transaction.

Review contract: `Docs/POINTER_RELEASE_OWNERSHIP_2026-10-25.md`; stage record: `Workflow/stage-summaries/2026-10-25-pointer-release-ownership.md`. The human's explicit bounded assignment supersedes the repository's old Chief/Worker/watchdog process. No such workflow, subagent, test/build command, app/process/UI operation, Git operation, or application-profile/reference/resource/asset read was performed. Main retains integration, build, packaging, documentation, and later native-handover ownership. This report is the only intentional repository write.

## Frozen input identity and exact delta

All evidence paths below are relative to `.build/verification/20261025/pointer-release-ownership/` unless stated otherwise.

- `source-inputs-r2.json`: 610 entries; SHA-256 `7ed56475a7bbcbe5c3151b07e4d60dbc9fbace2e9d81fec8a461bab3b3d1731f`.
- `inherited-source-baseline.json`: 610 entries with the same path set; SHA-256 `ff8cec80492eaa1790a5ca68813b5459305a146db41fffc6bcedbc71d4c58dca`.
- `source-delta-r2.json`: exactly three entries, exactly equal to the computed difference between those manifests; SHA-256 `9f01bac6f0af2a9b42758aa6568bb49afc5b384957ee5f2983789f26bec19106`.

| Changed path | Verified current/R2 SHA-256 |
| --- | --- |
| `Sources/PagingPrototypeApp/LauncherWindowInput.swift` | `9a9f9f7b04d2c5cfec095026e916af0867aac3bf1f92a78cc5a3bae2d767a81d` |
| `Sources/AppGridUI/DragUI/DragUISessionCoordinator.swift` | `c2045c4d81153b22984bc3cd64397fd80e2750cf4974fb199996f7757a961dcc` |
| `Tests/PagingUITests/B1ManualDeliveryTests.swift` | `95a98f21535e7da0ea14ede26175c0c0148e8bacd08018ad55d1973c5df5cc6a` |

To establish the actual delta without treating the dirty Git tree as the baseline, I reversed the visible edits in memory and matched each resulting file to its recorded inherited SHA-256. Both product files match exactly after reversing the small ownership edits. Removing the single 198-line test insertion also matches its inherited hash exactly. Thus the production delta is confined to B1 release retirement and ordinary `.clicked` completion; the test delta adds nine tests plus a private helper. No access widening, parameter changes, or unrelated product edits are hidden in these files.

The remaining 607 manifest entries inherit the previously reviewed footer baseline. They were not independently rehashed or re-audited as a whole; narrowly related inherited code was read only to evaluate the changed ownership paths. Manifest metadata was read without opening resource files. Main separately reports the complete 610-input freeze remains byte-exact.

## Findings and source reasoning

No unresolved actionable scoped regression was identified. The following are assessed repairs and controls, not open findings.

| Assessment | Location and evidence | Root cause / recommendation | Regression risks and confidence |
| --- | --- | --- | --- |
| B1 capture retirement is correctly ordered. | `LauncherWindowInput.swift:190-197`; new tests `B1ManualDeliveryTests.swift:193-222,255-287,371-389`; behavioral RED `before-r2.log:14-18`. | Old `mouseUp` cleared the shared capture after the target callback admitted another press. Clearing it before dispatch prevents that old frame from erasing either a same-cell or different-cell capture. The unwrapped local target retains the old recipient through delivery. Accept this minimal ordering change. | Extra unmatched releases no longer receive old B1 manual redelivery; existing native fallback routing remains intact. Same-cell identity comparison alone would have been insufficient. High confidence for the demonstrated seam. |
| Ordinary click cleanup preserves the original recipient and the newer gesture. | `DragUISessionCoordinator.swift:562-564,619-635,647-668`; tests `B1ManualDeliveryTests.swift:224-310`. | Old `dispatchClick(); endSession()` allowed the callback's newer press to acquire state/suppression that the old cleanup then removed, turning its release into a blank dispatch. `completeClick` retains the original cell/binding, finishes cleanup, and dispatches that retained target. No old cleanup follows the click callback. The outer `pointerUp` defer also avoids notifying over an active newer session (`395-407`). Accept. | A new press from the completed idle observer is deliberately allowed: it does not increment the end generation, and the old click still goes to its original cell. Nonreentrant click counters retain their meaning. High confidence. |
| Cancellation, teardown, and replacement binding fences are appropriate. | `DragUISessionCoordinator.swift:494-505,520-529,620-628`; tests `B1ManualDeliveryTests.swift:312-369`; `ItemBindingToken.swift:25-32`. | The expected generation is captured before cleanup callbacks as the existing generation plus one. An actual additional end/cancel changes it; teardown also sets the terminal flag. A changed or cleared token fails equality. The token includes catalog/page/slot/app/reuse/icon/surface identity, and the original cell stays strongly retained while cleanup clears the coordinator's reference. Accept without changing idle-cancel semantics. | An idle `cancel` remains a no-op. The negative control first admits a newer press and then cancels it; the positive control separately protects idle-no-op compatibility. Token equality protects replacement binding, not every conceivable external semantic change. High confidence within that contract. |
| Diagnostic and inherited route behavior remain bounded. | `LauncherWindowInput.swift:192`; `DragUISessionCoordinator.swift:395-407,419-455,562-588,629-667`; existing B1 census assertions `B1ManualDeliveryTests.swift:837-849,867-875`; focused log suites listed below. | `.b1Up` and `.clicked` remain at delivery/controller-event boundaries; cell/blank dispatch counters remain adjacent to actual dispatch; restoration still counts actual suppression restoration. A fenced click can record the controller's `.clicked` without recording a dispatch, which correctly distinguishes those events. Accept. | Cleanup now precedes an ordinary click callback, as required. Commit remains `onCommit` before `endSession`; fallback/blank branches, hit testing, thresholds, paging, native folder tracking and persistence are unchanged by this delta. High confidence in source identity; no native/performance inference. |

The production suppressor seam currently toggles recognizers (`AppDelegate.swift:1170-1182`); the tested idle observer runs after field cleanup. This report does not certify arbitrary reentry at every instruction or seam inside inherited cleanup. Native folder tracking and committed-drop callback reentrancy are distinct, unchanged routes outside the demonstrated repair. No speculative expansion is recommended.

## Execution evidence inspected, not rerun

| Record | Observed result | Interpretation |
| --- | --- | --- |
| `before-r1.log:7-48` | Private suppression-flag assertions fail compilation. | Invalid test execution; neither behavioral RED nor PASS. Production access remains private. |
| `before-r2.log:14-29` | 2 executed tests, 7 assertion failures. | Separate B1 capture loss (same/different cell) and ordinary coordinator cleanup/suppression failure are demonstrated through production seams. |
| `initial-green-r1.log:180-192` | 2 tests, 0 failures. | Initial focused repair evidence. |
| `focused-r1.log:56-57,285-287` | 113 tests, 1 failure. | The new control incorrectly expected an already-idle cancellation to revoke the completed click. This failed attempt is retained. |
| `focused-r2.log:55-76,286-288` | 114 tests, 0 failures; reported test time 1.584 s (1.591 s suite wall time). | Final nine added tests pass; B1 suite executes 24 tests. The corrected active-cancel control and separate idle-no-op compatibility control both pass. |
| `full-r1.log:2396-2416,8703-8705` | 3781 tests, 0 failures; reported test time 86.016 s (86.271 s suite wall time). | Main's completed full-suite execution record, independently read here. No reviewer execution or native acceptance is implied. |

The final focused record also includes blank-click, coordinator, drag/commit, selected folder assignment/reorder/title, and pointer-diagnostic suites (`focused-r2.log:77-258`). These are regression evidence for those executed tests, not a renewed complete parity audit. Test fixtures use unshown synthetic events and existing public seams; their callback reentry is deterministic but is not an observed native nested-event trace.

## Disposition and remaining gates

**SOURCE PASS** for the exact three-path R2 delta. No source repair is requested by this review. Source reasoning and preserved RED/green records support the bounded ownership correction with high confidence.

Main may integrate this report into its ongoing serial verification and unique-candidate packaging work. This review does not certify those build/package results. Native handover remains Main-owned after unlock. The intermittent physical drag cause, native input behavior, and performance remain unproved by this review; no fresh physical claim or broad parity closure follows from SOURCE PASS.
