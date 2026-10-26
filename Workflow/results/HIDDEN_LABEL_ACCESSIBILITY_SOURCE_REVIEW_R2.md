# Hidden-label accessibility — independent bounded source review R2

Date: 2026-10-15

**Verdict: SOURCE PASS. The original P2 member-wrapper ownership finding is CLOSED for the R2 frozen source. No remaining actionable finding was identified in the bounded delta.** This is source acceptance only; it is not R2 full-test/build/package, native accessibility, VoiceOver, or performance acceptance. The original full parity goal remains active and incomplete.

## Preservation and authority

This new report supersedes only the current disposition of the original P2 after the explicit R2 repair. `Workflow/results/HIDDEN_LABEL_ACCESSIBILITY_SOURCE_REVIEW.md` remains unchanged, including its historical SOURCE FAIL and evidence limits. Its SHA-256 before and after this review is `aa1ed65e24232318ed0b0057ad377a4c7222c46678217fabfebccbeb43694c48`.

Re-read project `AGENTS.md`, `/Users/mac/.codex/RTK.md`, the hidden-label stage summary including its appended R1/R2 decisions, and the current checkpoint sections of `Workflow/PLAN.md`. The stage summary and explicit human R2 instruction govern this maintenance slice; older plan text still describing the initial defect does not erase the later recorded progress. The existing human waiver of legacy Chief/watchdog applies. Authorized participants remain Main plus this Reviewer, within the ceiling; no new agent was dispatched.

Only `Workflow/results/HIDDEN_LABEL_ACCESSIBILITY_SOURCE_REVIEW_R2.md` is written. All shell invocations were RTK-prefixed. Reviewer execution totals are **0 Swift / 0 builds / 0 tests / 0 UI / 0 process-control operations**. Read-only text inspection and hash/diff scripts were used. Existing dirty source/tests and the original report are preserved. No installation, signing, commit, reference-application/source inspection, or raw asset inspection occurred. Resource assets were read only as bytes for permitted hash verification.

## Independently verified input chain

All **453/453 current input hashes match**, with no missing files. All 443 Swift files under `Sources/` and `Tests/` occur in the manifest; none is omitted.

| Artifact | SHA-256 |
| --- | --- |
| R2 `source-inputs-final.json` | `0bdbf42fa75721e73075669e75bba081a9a3b8f45684d1558ef135d545962096` |
| Retained R1 `source-inputs-r1.json` | `97d2b2bc1e2d6d02e6ebe7eee410873145b435ac341b5c6b4093af4233b85a36` |
| Prior appearance 452-input manifest | `cc7a6494bf9513bfe2cebc6048946b696f33c00b0ec5a6be29a892b95c139ffd` |
| Retained `bounded-production-r1.diff` | `bb755fade17692da1a77976ea5acf6f6c32c1f18ab4401dafde26ebd2ad9200c` |
| R2 `bounded-production.diff` | `8d72fbc0a5a7bfd1808d4078a3d52e103b5661455ca44e555218c1071f73d07c` |

The retained R1 manifest and production diff hashes equal those recorded by the original review. Both owned before copies still independently match their entries in the prior appearance manifest: AppGridCellView `3fe5fbae3eeaa64e4c63c51329f5f0096b896cc44bfba0b6fbc505913fa46fa6`; FolderOverlayView `76b4d198a4ebea9d54893f9f4a3672813179543585996d91ada1394bdc0f09dd`.

Applied the retained R1 unified diff to those before copies **in memory only** and verified that both reconstructed production bodies match the retained R1 manifest. Compared those bodies with R2 independently: AppGridCellView is unchanged; FolderOverlayView removes exactly `cell.setAccessibilityElement(!visualOnly)` and inserts a two-line explanatory comment. No other R1 production change is present.

The strengthened test contains exactly 23 inserted lines relative to R1. Removing only the inspected additions in memory recovers the original R1 test SHA-256, confirming no assertion removal, test removal, or unrelated test rewrite. It remains seven tests, now 395 lines.

Reconstructing the complete before-to-R2 production diff reproduces `bounded-production.diff` exactly: six hunks, 24 added lines, one removed line. Relative to the prior 452-input appearance baseline, exactly two existing production files differ and one test file is added; no input is removed. All 18 PagingCore/PagingUI sources, all resource inputs, package/scripts, previous appearance close/discard repair, and all pre-existing test files remain unchanged. Relative to R1, exactly FolderOverlayView and the new test file differ; all other 451 inputs match.

## Precisely reviewed scope

The production review is limited to the frozen delta in:

- `Sources/AppGridUI/AppGridCellView.swift`: existing NSImageCell label/help synchronization at bind, visibility, clear and deferred folder-text boundaries; identical to reviewed R1 source.
- `Sources/AppGridUI/FolderOverlayView.swift`: parent child-list exclusion, proxy-host exclusion, and R2 removal of member exposure mutation within the existing visual-only lifecycle.
- `Tests/AppGridUITests/HiddenLabelAccessibilityTests.swift`: all seven tests/helpers, with detailed review of the strengthened lifecycle regression at lines 245–318.

Supporting context is the same immediate ownership/reuse chain reviewed in R1: AppGridPageView render/clear/policy propagation, AppCatalogAssembly renderer live/pool propagation, AppGridCellFocus, relevant AppDelegate close/cancel/refresh seams, LocalizedStrings folder-help handling and existing three-language entries, and relevant pre-existing language/appearance tests. Their input hashes remain unchanged. This is not a new review of all application source or all unchanged tests.

## P2 closure and source assessment

**Original cause:** R1's `setVisualOnly(false)` explicitly changed retained member wrappers from ignored to exposed, while the new image owner retained the full name. The initial resume test did not check that wrapper flag. The original finding was a source ownership conflict and possible native naming risk, not an established native-tree or VoiceOver failure.

**R2 repair:** At `FolderOverlayView.swift:402–406`, the lifecycle no longer assigns any member accessibility-element flag. It preserves the member's existing native exposure without adding state, caches, roles, views, or alternative naming logic. The parent still returns an empty child list while visual-only and delegates to `super.accessibilityChildren()` while live at 416–417. Therefore removing the obsolete member flag write does not remove the existing frozen-subtree gate. The drawing-only proxy host's always-empty override remains intact. Context-menu disabling, focus clearing, callback suspension, pointer guards, generation checks and resume rebind remain unchanged.

**Regression discrimination:** The strengthened existing test records the original ignored wrapper at 260–261; checks its flag while frozen and after resume at 275 and 292–293; still requires restored nonempty automatic parent children, a named exposed native image cell and retained NSView descendants at 294–299; then exercises freeze → clear → resume → same-count configure on the same member view at 301–310. Both label policies at 311–315 preserve wrapper exposure and switch image naming to empty/full as appropriate. The baseline expectation is not merely copied from an arbitrary fixture value: the test explicitly requires the original member wrapper to be ignored.

Main's retained `resume-owner-red.log` records the actual R1 counterexample: one selected test, four assertions failing with true versus false at test lines 292, 308, and 313 twice. `focused-r3.log` records the strengthened regression passing and all 78 selected tests passing, including all seven new tests. Combined with the exact one-statement removal, this resolves the original source-level cause. **P2 CLOSED; no additional repair requested.** Confidence is high for source closure; native/assistive-technology acceptance remains separate.

The original source checks continue to hold for the unchanged image metadata implementation:

- The actual native owner is the existing NSImageCell, not the ignored NSImageView control wrapper. No role forcing, new hierarchy, or activation route is added.
- Bind/clear invalidate pending folder text through the existing generation boundary; deferred callbacks still require matching generation, current folder mode and a nonnil binding. No old name/help writer or extra async ownership is introduced.
- Hidden app/folder names remain complete and unmodified. Folder help copies the existing deferred localized formatting owner; zero/one/many and all three languages are covered. Formatting is not moved into layout/render/frame work.
- Visible captions, clear and inactive image branches explicitly clear image names with empty strings to avoid fallback descriptions or duplicate image names, and retire unneeded help. The repair does not suppress the correct hidden-caption image name.
- Same member/proxy NSViews are retained through the inspected lifecycle. Clear and same-count rebind remain current-content operations; intentional token generation changes and icon requests on interactive resume are the existing behavior.
- Live, pooled and new renderer pages continue receiving caption/language policy. Their clear/rebind paths reach the existing metadata boundaries. No paging physics, geometry, fixed grid contract, input routing, launch logic, icon validation, editor ownership, persistence or resource contract changed in R2. No added per-frame call was found; no measured performance conclusion is drawn.

## Evidence boundaries and remaining gates

Read-only inspection of supplied logs confirms:

| Evidence | Recorded result |
| --- | --- |
| R1 `full-r1.log` | 2664 tests / 0 failures, 59.370 test seconds; historical R1 evidence only |
| `resume-owner-red.log` | Strengthened lifecycle test on R1: 1 test / 4 assertion failures |
| R2 `focused-r3.log` | 78 tests / 0 failures, 3.416 test seconds; includes 7 new tests |

Historical initial wrong-owner REDs, the native-cell diagnostic, corrected RED, first nil-children failure, original focused result and original FAIL report remain retained. They are not rewritten as if the strengthened regression or repair already existed in R1.

The stage summary and retained `native-r1-process.json` report that R1's first/second folder opens exposed named images and the rename entry, without visibly duplicated wrappers in the CUA tree. `native-r1-quit.json` records normal menu Quit for PID 58145 and an absence check. These are **Main's supplied R1 records**, not this Reviewer's observations. The absence of visible duplicates in that tree does not disprove the actual local wrapper-flag mutation, establish VoiceOver speech, or constitute a native audit FAIL. R2 is accepted here because the source cause is removed and the discriminating regression is present, not because of an inferred R1 native failure.

No R2 full-suite/build/package result or R2 native acceptance is certified by this report. Those remain Main's serial verification and exact-candidate follow-up gates. Synthetic unshown accessors, local child lists, and NSView identity checks do not prove complete mounted AX traversal, stable native AX object identity, accessibility notifications/focus, VoiceOver navigation/speech/actions, physical interaction, real IME, 120 Hz, multidisplay behavior, or performance. The one-member resume fixture also does not replace full renderer/pool native traversal or successful asynchronous image loading after resume.

Full-goal scope, prior callback/combined-language coverage follow-ups, physical/native/data gates and separate approval boundaries remain unchanged. Any later source/input change requires matching evidence and fresh bounded review.

Only the new R2 report was written. Final Reviewer Swift/build/test/UI/process-control execution counts: **0 / 0 / 0 / 0 / 0**.
