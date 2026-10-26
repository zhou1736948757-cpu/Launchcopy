# Independent App Library native UI source review

Date: 2026-10-15 (Asia/Tokyo)
Repository: `/Users/mac/Projects/Launch_Copy/PagingPrototype`
Verdict: **SOURCE REVIEW FAIL — two actionable P2 findings; no Source PASS issued.**
This is a bounded manual source judgment, not an automated test verdict or native UI acceptance.

## Authority, scope and evidence limits

The human authorized agents, waived the formal workflow, and limited concurrency to three including Main. This reviewer dispatched or contacted no agents. Main exclusively owns serial Swift/build/test execution and application/process control. The existing dirty tree was retained; the sole reviewer write is this report. No implementation or test was edited. All shell invocations were prefixed with `rtk`.

The approved contract is `Docs/APP_LIBRARY_SPEC.md`, its incorporated `Docs/APP_LIBRARY_SLICE_PROPOSAL.md`, and `Workflow/stage-summaries/2026-10-15-app-library-native.md`. The domain is an existing Swift/AppKit macOS resident launcher, using SwiftPM modules, pure AppGridUI projections, snapshot localization, and an injected shared AppIconPipeline. The review follows that architecture rather than proposing a replacement.

Primary inputs:

- `Sources/PagingPrototypeApp/AppLibraryView.swift`
- `Sources/PagingPrototypeApp/AppLibraryCategoryLabels.swift`
- `Sources/PagingPrototypeApp/AppLibrarySettingsView.swift`
- `Tests/PagingUITests/AppLibraryViewTests.swift`
- `Tests/PagingUITests/AppLibrarySettingsViewTests.swift`
- `Tests/PagingUITests/AppLibraryLocalizationTests.swift`
- Library property/initialization/tab/relabel additions in `ActivationSettingsWindowController.swift` (182, 217, 226, 277, 604–607). Existing controller diff context was inspected to locate these additions; unrelated controller behavior is not independently certified here.

Minimal contract corroboration: immutable `AppLibraryActionRequest.swift`, `LibraryTextKey.swift`, Library entries in the project's English/Chinese/Japanese `.strings` source tables, and the localization accessor. These are project source, not reference-product assets. No LaunchBetter/Buho reference, evidence artifact, or image/media asset content was read. No build products or test logs were read. No Swift command, build, test, application, or process-control operation was executed by this reviewer.

Main progress supplied by the human, not independently executed or verified here:

- Initial compile failed in the new NSEvent test helper because this SDK requires a nonoptional `charactersIgnoringModifiers` String. Main changed only the helper to actual Escape/Return strings; the inspected helper now contains them at `AppLibraryViewTests.swift:66–70`.
- r2 focused run: 126 methods, 12 assertion failures confined to the six fixtures of one Settings layout method; the other 125 methods were reported passing. This does not mean 12 failing methods or a focused-suite PASS.
- Main subsequently changed only that test's measurement to native alignment rectangles, added whole-frame root containment, and retained actual status/recovery frame nonintersection. r3 remains pending at this report's checkpoint.
- Earlier 2533-green foundation/source results do not establish native Library acceptance.

## Findings

### F1 — [P2] Keyboard selection opens the narrow details drawer and steals result focus

**Locations:** `AppLibraryView.swift:375–379`, `312–322`; related search handoff at `405–415`, result Return handling at `721–724`.

**Evidence and trigger:** At a 700pt root width, the layout's content width is below 600pt. Search Return/Down selects the first result and deliberately closes Details, leaving the result table as first responder. A subsequent native Down/Up selection change goes through `tableViewSelectionDidChange`, which calls `showDetails(nil)` for every nonempty selection. On layout, the details drawer hides the result scroll view and explicitly makes `closeDetailsButton` first responder when the result table had focus. Consequently subsequent keys no longer reach the table's Return-to-open handler or its native row navigation. The issue also affects keyboard selection from an initially unselected results table.

**Impact:** Users cannot continuously browse results with arrow keys and then use the selected-result Return contract at supported drawer widths without closing Details after each selection. This is not the intended search Return/Down selection-versus-launch distinction. No unintended launch is alleged.

**Likely root cause:** A generic selection-change notification conflates selection with a details-open action. The narrow-layout focus repair amplifies this by transferring focus away from the table.

**Recommended solution:** Keep row selection distinct from explicitly opening Details. In drawer mode, ordinary keyboard selection should leave results visible and focused; only an intentional details action should replace them. If Details are already open, refresh their factual content without treating every selection as a new drawer-open request. Preserve explicit mouse/details behavior and native Tab traversal.

**Suggested regression:** Mount a 700pt (and 360pt) view with multiple results, invoke search Return/Down, route native Down through the first responder, perform layout, and assert row advancement plus retained result focus and exactly one current immutable request on the subsequent Return. Do not call `resultsTable.keyDown` directly for Return after focus has already moved; that would bypass the defect.

**Existing coverage gap:** `AppLibraryViewTests.swift:73–90` invokes Return directly on the table in the default 1000pt fixture. The width test at 303–320 checks outer geometry, not the arrow/focus/Return sequence.

**Affected scope:** Library selection presentation and drawer responder routing only.
**Regression risks:** Mouse details opening, Escape returning to results, and wide side-by-side presentation.
**Confidence:** High for the source path; native event-loop reproduction remains unexecuted.

### F2 — [P2] Re-rendering Details for the same app discards an unsubmitted category draft

**Locations:** `AppLibraryView.swift:486–490`, `606–607`; refresh path `191–195`; contrast with relabel preservation `654–657`.

**Evidence and trigger:** Open an app whose committed manual category is Games, choose Finance in the popup without Save, then click the still-enabled Details header button again. `showDetails` unconditionally calls `renderDetails`, which resets the popup from `entry.manualCategory`. The Finance draft is lost even though the identity did not change and the user did not save, cancel, or restore Automatic. Applying a fresh snapshot containing the same surviving app while Details are open likewise unconditionally renders and resets the draft. An identical snapshot is sufficient to demonstrate the local reset path.

**Impact:** An unrelated presentation refresh can silently discard the user's explicit category choice. Direct `relabel` preserves the popup index correctly, but that protection is confined to the relabel call; it does not protect repeated Details or same-identity snapshot refreshes. No claim is made that a particular owner locale-change sequence currently invokes apply; that owner sequence is outside this review.

**Likely root cause:** The popup's unsubmitted value exists only in the control. Factual detail rendering also initializes the editor from committed state on every call.

**Recommended solution:** Track the draft separately by current app identity, or make draft initialization conditional on a new identity/explicit reset/confirmed save. Repeated Details rendering and same-identity factual refresh should preserve an unsent draft. Clear it when selection disappears or changes, on reset/cancel as defined, and reconcile after the owner's accepted save rather than preserving an obsolete submitted value indefinitely.

**Suggested regressions:** Select a draft, call Details again and reapply an unchanged/same-identity updated snapshot, then assert the draft survives without callbacks. Also assert changing/removing identity clears it and that successful category save reconciliation updates the committed baseline. Keep the existing relabel test.

**Existing coverage gap:** `AppLibraryViewTests.swift:282–301` covers direct relabel preservation only; refresh tests check committed category/metadata and identity retention without an unsaved popup draft.

**Affected scope:** Library category editor draft state, separate from Settings enablement.
**Regression risks:** Draft leaking to another app, preserving an already submitted draft after success, or resurrecting drafts after absence/reset.
**Confidence:** High; the unconditional popup assignment is explicit. No visual or native-event execution was performed.

## Bounded source observations

These observations are not individual automated PASS results and do not override F1/F2.

| Contract | Source judgment and boundary |
| --- | --- |
| Immutable action packets | `request()` at 466–469 uses the current entry and displayed snapshot revision plus supplied owner generation. `AppLibraryActionRequest.swift:6–16` stores only immutable app ID, canonical URL, revision and generation. No fabricated grid token/cell. Owner execution-time revalidation is outside this review. |
| No view-owned I/O | UI source consumes supplied snapshots/preferences and callbacks. No scanner, plist read, storage writer, NSWorkspace launch/reveal, or classifier is owned by these views. Icon loading is delegated to the supplied existing pipeline, which is an intentional separate service. |
| Factual/read-only details | 537–551 and 586–604 expose nine supplied-record/projection fields using selectable label controls, not editable metadata fields. Canonical record name/URL/ID/version/build are used; missing/empty optional values become localized Unknown. Effective category comes from the projection; automatic classification calls the domain mapping; manual absence displays Automatic. No invented developer/date/size/history. An alias equal to the original name cannot be distinguished from absence with this supplied entry shape and displays Unknown. |
| Categories/manual/Automatic | Exhaustive 22-case label mapping; All is filter-only. Popup item zero means nil; Save/Restore Automatic emit callbacks rather than write storage. Classification recognition, equivalent-key deletion, dormant overrides and persistence guarantees remain foundation/owner responsibilities. |
| Nil/loading selection retention | 174–200 retain only identity plus details-open intent across repeated nil/loading applies. Snapshot/action selection and detail values are revoked; 466–469 reject loading requests. A surviving identity resolves to the newly supplied canonical record/revision/generation; absent identity clears retention. Query/category changes invalidate actions before invoking the owner (418–445). |
| Search Return/Down | 396–415 selects and focuses first result without launching, then closes the selection-triggered drawer. Table Return/keypad Return dispatch to Open (721–724). F1 breaks continued native row selection at drawer widths. |
| Escape/IME/Tab | 237–253 prioritize owned marked text, Details, query clear, Back. Search command delegate defers marked-text handling and returns false for native Tab/Shift-Tab. Detail/selectable-control field editor ownership is recognized. Owner sheet/editor cancellation and launcher Escape interception are not independently certified; real IME cancellation semantics and Tab/VoiceOver order need native validation. |
| Blank/scroll containment | Library root hit testing retains blank interior and terminates bubbled scroll; native scroll views retain their own document scrolling (258–264, 729–733). No pager callbacks are issued. Actual launcher event-monitor blank-click suppression, trackpad edge momentum and hidden-pager routing require owner/native checks. |
| Native controls/accessibility/layout | NSSearchField, tables, popup buttons, scroll views, wrapping/selectable detail labels, stable accessibility identifiers and localized labels are present. Compact category replacement and details drawer versus side-by-side rules are explicit (289–327). Detail content is constrained to its clip width and vertically stacked. This establishes source intent, not text clipping, scroll reachability, pixel quality or VoiceOver acceptance. |
| Localization/drafts | All 53 Library keys have English/Chinese/Japanese source entries at `.strings:245–297`; category labels route through typed keys and supplied LocalizedStrings rather than OS locale reads. Direct relabel preserves query/selection/category and the popup index. Locale-aware filtering/sorting remains the supplied projection's responsibility. F2 limits draft preservation on subsequent renders. |
| Library Settings tab | Retained view is initialized with the current strings (277), appended as a Library NSTabViewItem (604–607), and relabeled in place (217,226). These additions do not recreate the settings view or apply/discard activation/language drafts. No unrelated controller workflow is re-certified. |

## Icon lifecycle source review

`AppLibraryView.swift:333–350` uses native reusable cells plus a weak cell registry. `685–711` gates requests on a visible window, visible Library/results list, nonloading snapshot and injected pipeline, then bounds admission and delivery to current native visible rows. The key includes record icon identity, 32pt size and backing scale. There is no catalog-wide prefetch loop.

`796–806` avoids re-requesting the same key/generation, captures a separate reuse generation, and checks delivered key/generation plus current row/identity/visibility before assigning an image. `bind` cancels reuse; `didRemove` cancels removed row cells (383–386); hide/ancestor-hide, detachment, reset and snapshot changes cancel handles and clear images (185–186, 208–211, 266–285, 775–793). Cell deinit also cancels. Closed/unshown/hidden views cannot admit new requests through the visibility guard. Immediate cancellation of every pending request on an arbitrary window order-out sequence still depends on lifecycle notifications/owner hide/reset; that integration was not exercised here.

The authored unshown-window test asserts zero requests for 500 synthetic entries, and the hide/reset test asserts resident image release (`AppLibraryViewTests.swift:341–369`). They do not demonstrate visible-window request counts, rapid scrolling/reuse, delayed stale completion rejection, row-removal cancellation or actual shared-pipeline cache/in-flight bounds. Those are remaining executable gates, not demonstrated failures in the reviewed guards. The shared pipeline implementation itself was not re-reviewed or modified.

## Settings synchronous callback and terminal-state review

`AppLibrarySettingsView.swift:103–120` captures the requested checkbox state before rendering back to the committed baseline, sets local pending before invoking `onSetEnabled`, and does not restore pending after a synchronous owner receipt. An accepted callback without an immediate owner snapshot remains pending. A synchronous pending snapshot retains the draft; a synchronous terminal snapshot clears it in `applyState` at 87. Rejected callbacks clear local pending, show failure and retain supplied committed preferences. No speculative checkbox success is shown.

Terminal `applyState` replaces the baseline with the owner's actual supplied preferences, independently of obsolete `.loaded` associated values. `statusKey` prioritizes not-loaded/protected/pending states over stale saved receipts. Later failed drafts can leave the earlier successful enabled baseline displayed without claiming failure was saved. Relabel renders presentation only and preserves pending/failure state. The 16 authored Settings methods cover acceptance, rejection, missing callback, synchronous pending/success, later failure, multiple writes, protected loads/save receipts and explicit recovery (`AppLibrarySettingsViewTests.swift:175–305`). They remain unrun by this reviewer.

Default is off/loading and disabled until inspected. Corrupt input disables editing and offers an explicit recovery callback; no speculative reset occurs. Future/ambiguous/oversized/unavailable/protected payload states are mixed/unknown and disable change/recovery. Recovery confirmation and file protection are owner responsibilities, not inferred from this source. Callback reentry with a success receipt followed by a contradictory false return is not an established supported owner contract and was not treated as a defect.

## Main's alignment-rectangle test correction

Reviewed updated `AppLibrarySettingsViewTests.swift:315–333` against production constraints in `AppLibrarySettingsView.swift:61–69`.

The correction is sound at the source/assertion level: production anchors constrain the native alignment rectangles, so testing their margins with `control.alignmentRect(forFrame: control.frame)` and converting from `control.superview` compares like coordinates. Main's reported native frame x=22…318 is consistent with a 2pt extension around alignment x=24…316 in a 340pt pane. The new test queries AppKit's alignment conversion; it does not hardcode a 2pt subtraction or loosen production margins.

The added `view.bounds.contains(view.convert(control.bounds, from: control))` separately requires the complete actual control rectangle inside the pane, while the prior actual status/recovery-frame nonintersection check remains. Positive alignment width/height and all four margin checks remain. This improves the assertion's meaning rather than accepting genuine root overflow. The exact 2pt native inset is based on Main's reported r2 geometry and the test comment, not independently measured by this role; it should not be generalized to every AppKit control. The term "physical" in the local test variable denotes control coordinates, not physical-device testing. No conclusion about rendered text, native GUI appearance, or r3 success follows from this source review.

## Authored tests and remaining acceptance

Inspected test inventory: 17 Library view methods, 16 Settings methods, 9 Library localization methods (42 methods total in these three files). These tests were authored in the implementation/Main wave, not by this reviewer, and none was executed in this role. Main's reported 126-method run contains broader coverage and is not equivalent to this inventory.

Required next steps for Main within authorized scope:

1. Repair F1/F2, add targeted regressions, and obtain a fresh independent source review of changed inputs.
2. Complete the serial r3 focused run and record exact nonzero execution/results; current source inspection does not supply an automated PASS.
3. Add/execute visible-row icon lifecycle and native first-responder regressions if not already covered in Main's broader suite; verify the retained Settings tab/relabel draft behavior in its integration context.
4. Keep GUI pixels, real IME/Tab/VoiceOver, scroll/blank containment, launch/reveal safety, hide/Back lifecycle, restart durability and matched physical performance as explicit separate gates. Existing foundation green results do not close them.

No implementation repair is authorized or performed by this report. Main owns remediation and verification.

## Reviewed input hashes (SHA-256)

Production hashes and the event-helper test hash matched on repeat read. The Settings test changed during review exactly as Main disclosed; the hash below is the updated alignment-rectangle version inspected here. A future change invalidates the corresponding portion of this review.

| File | SHA-256 |
| --- | --- |
| `Sources/PagingPrototypeApp/AppLibraryView.swift` | `eb11bae04649eec2c08dd835b1081e680e3971a7052ae23442f1debd96789168` |
| `Sources/PagingPrototypeApp/AppLibraryCategoryLabels.swift` | `7cf0ef70fb1d51face074efca1c9141c6a23955b9089c4a9d39d15c949c1595a` |
| `Sources/PagingPrototypeApp/AppLibrarySettingsView.swift` | `f0abda4302e20fde515900be795990008034752170f4a11ac31fc8ac1387a325` |
| `Tests/PagingUITests/AppLibraryViewTests.swift` | `7a808d888c55182399c57e8373b886c335ffdaa621e53de04248a7def98e78e7` |
| `Tests/PagingUITests/AppLibrarySettingsViewTests.swift` | `69b1b7c7872b721aecdc87f6e227ace0a2f0e6ea7581e04e216932fb05366795` |
| `Tests/PagingUITests/AppLibraryLocalizationTests.swift` | `840bd03577f9029097bfbf4b4a43eed5a8268af3909ce7c58057d9b1503fe679` |
| `Sources/PagingPrototypeApp/ActivationSettingsWindowController.swift` | `117b3a9180fdb1e5c776e6d1320d0a83d2245c8caaa3dc8fc763f06e468be843` |
