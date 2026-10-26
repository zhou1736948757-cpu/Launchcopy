# Hidden-label accessibility — independent bounded source review

Date: 2026-10-15

**Verdict: SOURCE FAIL — one actionable P2 ownership issue on retained-overlay resume.** This verdict concerns the frozen source delta only. It is not a native accessibility, VoiceOver, build, performance, or full-goal verdict. The full parity goal remains active and incomplete.

## Authority, execution and write boundary

Read project `AGENTS.md`, `/Users/mac/.codex/RTK.md`, `Workflow/stage-summaries/2026-10-15-hidden-label-accessibility.md`, and the current checkpoint sections of `Workflow/PLAN.md`. The human's explicit waiver supersedes the legacy Chief/watchdog workflow for this assignment. Worker was already closed; authorized concurrency is Main plus this Reviewer, two participants within the ceiling of three. No further agents were dispatched.

Reviewer executed **0 Swift commands, 0 builds, 0 tests, and 0 native/UI operations**. All shell invocations were RTK-prefixed. Read-only text inspection and Python hash/diff comparisons are the only verification performed here. Only this report is written. Existing dirty source and tests are preserved; no process control, installation, signing, commit, external reference application/source inspection, or raw asset inspection was performed. Asset files were read as bytes solely to verify their manifest hashes, as authorized.

## Frozen inputs and exact delta

Independently recomputed all 453 current input SHA-256 values: **453/453 match**, no missing files or hash mismatches. All 443 Swift files under the project's `Sources/` and `Tests/` are represented in the current manifest; no omitted Swift input was found.

| Artifact | Independently verified SHA-256 |
| --- | --- |
| Current 453-input manifest | `97d2b2bc1e2d6d02e6ebe7eee410873145b435ac341b5c6b4093af4233b85a36` |
| Prior 452-input manifest | `cc7a6494bf9513bfe2cebc6048946b696f33c00b0ec5a6be29a892b95c139ffd` |
| Owned before-AppGridCellView.swift | `3fe5fbae3eeaa64e4c63c51329f5f0096b896cc44bfba0b6fbc505913fa46fa6` |
| Owned before-FolderOverlayView.swift | `76b4d198a4ebea9d54893f9f4a3672813179543585996d91ada1394bdc0f09dd` |
| bounded-production.diff | `bb755fade17692da1a77976ea5acf6f6c32c1f18ab4401dafde26ebd2ad9200c` |

Both owned before copies independently match the corresponding entries in the prior manifest. Reconstructing their unified diffs against current source, including the stored before/after path headers, reproduces `bounded-production.diff` exactly: five hunks, 22 added lines, zero removed lines.

The complete reviewed change set relative to that owned prior baseline is:

- `Sources/AppGridUI/AppGridCellView.swift`: image-cell metadata synchronization after deferred folder text, app bind, and label visibility changes.
- `Sources/AppGridUI/FolderOverlayView.swift`: conditional overlay `accessibilityChildren()` and always-empty drawing-only proxy-host children.
- New `Tests/AppGridUITests/HiddenLabelAccessibilityTests.swift`: all seven tests and their helpers, lines 1–372.

No other prior input changed and none was removed. All 18 `Sources/PagingCore/` and `Sources/PagingUI/` inputs, resources, package/scripts, previous appearance close/discard repair, and existing tests match the prior manifest. The repository's dirty Git state is not treated as this slice's baseline.

Supporting source reads were limited to the changed files' immediate consumers/ownership paths: `Package.swift`; `AppGridPageView.swift` propagation/render/reuse; `AppCatalogAssembly.swift` renderer propagation/pooling; `AppGridCellFocus.swift`; `FolderOverlayView.swift` member/proxy binding, icon guards, title editor and lifecycle; relevant `AppDelegate.swift` folder close/cancel/refresh call sites; `LocalizedStrings.swift` folder-help formatting and matching existing three-language resource entries; and relevant existing language/appearance test sections. These are contextual reads, not a whole-application review or approval of unchanged subsystems.

## Finding

### [P2] Account for the member wrapper becoming exposed on visual resume

**Changed location:** `Sources/AppGridUI/AppGridCellView.swift:231–239`, especially the unconditional hidden-name assignment at 234–237.

**Trigger and evidence:** With captions hidden, configure an overlay with members, enter visual-only mode, then resume the same overlay. `FolderOverlayView.setVisualOnly(false)` explicitly executes `cell.setAccessibilityElement(true)` for retained members at line 403, then calls `rebindCurrentMembersAfterVisualResume()` at 409. That method retains same-count member views and binds them again at 933–943. `AppGridCellView.bind` sets the wrapper's complete accessibility label at 179 and now calls the new helper through `updateLabelVisibility()`. The helper also assigns that complete name to the existing exposed image cell, without considering whether the wrapper is itself exposed.

The source therefore explicitly produces a named, exposed member wrapper and a named native image cell for the same member after resume. The new comment's assumption that the custom view is always an ignored wrapper is not valid across this existing lifecycle. Ordinary application paths also invoke this lifecycle: `AppDelegate.swift:1588`, `1612`, `1719`, and `1726`; completed close/cancellation can restore flags on retained cleared cells before subsequent same-count configuration.

**Impact / affected scope:** Hidden-caption folder members after retained-overlay resume or subsequent reuse can acquire an additional named accessible element. This undermines the single-owner/no-duplicate-name intent and changes accessible naming across the same retained identity. Source establishes the conflicting ownership and duplicate metadata; the exact exported native tree and whether/how VoiceOver repeats the name have **not** been executed or established by this Reviewer.

**Likely root cause:** The helper selects a naming owner solely from caption visibility, binding presence, and folder/app mode. Existing resume code also changes the wrapper's accessibility-element flag, but that ownership change is not considered.

**Recommended solution:** Keep one existing naming owner for each exposed member. A bounded option is to suppress the image's semantic name when the already-named wrapper is explicitly exposed, while retaining image naming for ignored wrappers; otherwise preserve/restore the actual pre-freeze exposure flags deliberately. Main should choose an approach consistent with the no-role/hierarchy-change constraint. Extend the existing resume regression to inspect the member wrapper and native image together, including a close/clear/resume/same-count rebind and captions off/on. Confirm the resulting unique naming in Main's exact-candidate native tree. No implementation change is authorized or made by this report.

**Coverage gap:** `HiddenLabelAccessibilityTests.swift:245–295` checks nonempty restored overlay children, the retained member view, and a named exposed image cell at 292–293. It does not inspect the member wrapper's element flag/label or the combined naming ownership, so its current assertions permit this conflict.

**Regression risks:** Removing image names indiscriminately would recreate the original unnamed-image defect. Unconditionally changing wrapper exposure could alter hierarchy, focus, or existing interactions. Preserve initial ignored-wrapper behavior, restored automatic children, current identities, and label/help clearing during a repair.

**Confidence:** High in the source-level ownership conflict; medium in native/assistive-technology impact until Main inspects the actual exported tree. Priority P2; no P0/P1 issue identified in this bounded review.

## Remaining source assessment

- **Actual API ownership:** The retained diagnostic log reports `NSImageView` as AXUnknown/not-element and its existing `NSImageCell` as AXImage/element, with the cell label reflected through the view getter. The patch correctly targets `.cell` rather than forcing the image-view wrapper's role. This diagnostic supports the initial image owner; it does not establish that every enclosing custom view stays ignored after lifecycle changes, as the finding above demonstrates.
- **Reuse and stale folder formatting:** `clearContent()` invalidates queued text generation before retiring binding/name/image metadata. Both app and folder bindings clear first. Deferred callbacks compare the captured generation, and folder formatting additionally requires current folder mode plus a nonnil binding. Old folder callbacks cannot reapply old names/help after app rebind or clear through these inspected paths. The new helper adds no async closure or captured identity.
- **Localization:** Full app/folder titles remain unmodified. Image help copies the existing deferred localized folder-help result; it introduces no new resource key, formatter, or per-frame formatting. Nil help during the existing pre-format interval is retained; zero/one/many values and all three supported languages are covered by the new synthetic tests.
- **Decorative/inactive images:** Visible captions, cleared bindings, and the inactive icon/symbol branch receive an explicit empty image label; help is cleared unless a hidden-caption named folder owns it. This suppresses symbol-description fallback through the intended explicit-empty override instead of assigning nil. Initial, repeated-toggle, mixed-script, app/folder/app, clear and stale-icon cases are present in the tests.
- **Inert subtree and identity:** Visual-only overlay children are explicitly empty; live children delegate to `super` rather than persisting a mutable empty/nil override. The drawing-only proxy host always returns an empty list, including reattachment. Existing pointer/menu/callback/icon guards remain intact. No image control/cell replacement or new view is introduced by the delta. Resume still intentionally rebinds tokens and icon work under the pre-existing lifecycle. Tests compare NSView descendant identities; they do not independently certify native AX object identity.
- **Renderer/pool and negative boundaries:** Live/pooled/new pages inherit caption/language policy; page clear calls cell clear before pool reuse, and rebind restores current metadata. The new helper is reached at existing bind/clear/visibility/deferred-text boundaries, not layout/frame/animation ticks. No paging physics, layout geometry, roles, input routes, activation, icon request/token validation, title-editor ownership, persistence, or launch behavior is modified by the reviewed delta. This is source inspection, not a measured performance claim.

## Supplied evidence and limitations

Read the retained logs without executing them:

| Evidence | Recorded result / interpretation |
| --- | --- |
| `red.log` | 7 tests / 114 failures; initial incorrect ownership fixture, not a clean native-cell RED |
| `red-r2.log` | 7 / 102; AppKit initialization did not fix the mistaken image-view ownership assertion |
| `image-owner-probe.log` | 1 / 0 diagnostic; actual image-cell owner, not repair acceptance |
| `red-r3.log` | Corrected native-cell baseline RED: 7 / 55 |
| `focused-r1.log` | 78 / 2; restoring children via nil failed the resume regression |
| `focused-r2.log` | 78 / 0, 3.408 test seconds; includes all seven new tests |

These are Main's retained execution records, not Reviewer executions. The first two RED fixtures and first focused failure remain historical evidence; they are not silently replaced by a claim that the original fixtures were correct. Synthetic unshown AppKit accessors, local child lists, and stable NSView descendants do not prove full window AX traversal, unique native names, notification/focus behavior, VoiceOver speech/actions, real IME, physical comparisons, 120 Hz, multidisplay behavior, or performance. The new tests do not exercise full application renderer/pool native exposure end to end.

Main's full tests/build/package and exact-candidate native work are separate parallel gates and are not certified here. The original parity goal, pending combined callback/language follow-ups, and other physical/native/data/approval gates remain intact. Next action is to resolve or disprove the P2 ownership issue with bounded source/regression evidence and exact-candidate native inspection, then obtain a fresh review if any frozen input changes.

Final report write boundary: `Workflow/results/HIDDEN_LABEL_ACCESSIBILITY_SOURCE_REVIEW.md` only. Reviewer Swift/build/test/UI execution totals: **0 / 0 / 0 / 0**.
