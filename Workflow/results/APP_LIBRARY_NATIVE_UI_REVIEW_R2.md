# Independent App Library native UI source review — R2

Date: 2026-10-15 (Asia/Tokyo)
Repository: `/Users/mac/Projects/Launch_Copy/PagingPrototype`
Verdict: **BOUNDED SOURCE PASS — R1 F1/F2 resolved in the reviewed frozen inputs; no remaining actionable correctness finding in this UI scope.**
This is an independent manual source verdict, not an automated test PASS, pixel/native GUI acceptance, VoiceOver acceptance, restart durability result, or physical-performance result.

## Scope, attribution and preservation

The approved contract remains `Docs/APP_LIBRARY_SPEC.md`, its incorporated proposal, and the native stage. This is an existing Swift/AppKit launcher using supplied immutable projections, typed localization, shared icons and owner-controlled actions/storage. The human authorized agents, waived the formal workflow, and set max three including Main. This reviewer started or contacted no other agents and performed no Swift/build/test/GUI/application/process operation. All shell calls used `rtk`. The only write is this new R2 report; implementation, tests, existing dirty work and R1 were preserved.

Primary reviewed inputs: AppLibraryView.swift, AppLibraryCategoryLabels.swift, AppLibrarySettingsView.swift; their AppLibraryViewTests/AppLibrarySettingsViewTests/AppLibraryLocalizationTests; and only the Library property, initialization, tab and relabel additions in ActivationSettingsWindowController.swift. Minimal additional reads covered the owner's category submission/receipt and projection handoff seam and the projection controller's synchronous invalidation/publication contract. This is not a full owner/writer review. No reference-product, evidence artifact, media/image asset or build/test-log content was read. Hash capture is a source fingerprint, not test execution.

**Attribution correction to R1:** The compile/test-progress and layout measurements previously labeled as supplied by the human originated with **Main agent**, relayed in this conversation. Human authorization remains human authorization. R1 is not silently rewritten; this R2 note supersedes its progress-evidence attribution.

Main-agent-reported progress, not independently executed or verified by this reviewer:

- r4 focused: 130 methods / 0 failures, before the final failure-label/writer additions; it cannot certify those later inputs.
- Latest re-freeze: typed inline category-result state, localized accessible Details failure label, category-only protected-state disablement, active originating-session receipt forwarding, and two new UI regression methods.
- r5 focused: 139 methods / 0 failures, including the two new UI regressions.
- A 440-input manifest was captured by Main. This role did not read that evidence manifest or assert that it matches the reviewed hashes.
- Full r2 was still running at the latest supplied checkpoint; no full-suite result is claimed.
- Prior foundation 2533-green/source results remain foundation evidence, not native Library acceptance.

After the final-additions notice, this reviewer refreshed AppLibraryView, its new tests, and the owner receipt seam. Their hashes matched the R2 inputs already read; the latest re-freeze did not leave an unseen change in those files at the verification checkpoint.

## R1 finding disposition

### F1 — Resolved: row selection no longer implicitly opens a drawer

`AppLibraryView.swift:377–390` changes only selected identity and refreshes Details when they are already open. With Details closed, native keyboard row selection leaves them closed. Explicit table action (117) and the Details button (91) retain their intentional open behavior. Search Return/Down still selects the first result without launching and focuses results (406–425); table Return/keypad Return retains Open (780–783). Drawer layout's focus transfer at 329–330 now runs only after intentional Details opening, not ordinary selection.

The new `AppLibraryViewTests.swift:69–90` tests 700pt and 360pt widths without the `select` helper. It sends Down and Return through `window.firstResponder`, lays out after Down, checks the second row and retained table responder, asserts Details stay closed, and checks one launch request for B. This addresses R1's focus-bypass testing gap. The details-oriented helper explicitly invokes `showDetails` at 54–61 and is not used by this keyboard regression.

**Confidence:** High for the source repair and relevance of the authored regression. Main reports its execution in r5; this role did not execute it or validate a shown GUI.

### F2 — Resolved within the serialized owner contract: same-app drafts survive re-render/loading/failure

`AppLibraryView.swift:35` now stores app identity, optional chosen category, dirty and submitted state separately from the popup. The popup has an explicit change target/action (576–577); `categoryDraftChanged` records the value for the current app (643–648). Save marks submission before calling the owner (487–493). Automatic stores a submitted nil category (495–498), rather than treating nil as an absent draft.

`renderDetails` (632–639) retains a dirty/submitted same-identity draft across repeated Details and factual refreshes; clean state follows committed metadata. Nil/loading apply preserves draft while revoking actionable selection and clearing the visible controls (176–205). A terminal missing identity clears it (205); selecting another identity clears it (384–386); explicit Escape/dismiss clears it (251,501–513); reset clears draft, receipt and failure state (213–216). Loading closure deliberately does not count as explicit draft cancellation.

`categorySaveDidComplete` (650–654) records the typed result. Failure clears submission but preserves the chosen value for retry; success arms reconciliation to the next detail render. `renderDetails` consumes the success flag and creates a clean baseline from the newly supplied manual category (632–634).

The receipt flag is not itself keyed by AppID/request generation. Its correctness here relies on the actual owner seam, which was checked rather than assuming arbitrary delayed callbacks are safe:

- Owner submission resolves the displayed immutable request and rejects action/pending/source/readiness mismatches; it records the originating Library session before submit (`AppLibraryOwnerController.swift:131–135,201–208`).
- Pending writes yield a nil/loading view snapshot (`244–246`), so a different actionable selected app/new draft cannot be created through normal UI while waiting.
- Terminal forwarding requires active owner, zero pending, a pending category session, a supplied save result, open Library and equal current/originating session (`212–220`). Close increments session and resets/releases the view (`156–166`). An old closed session cannot reconcile a reopened view's draft.
- After forwarding, the owner synchronously refreshes the projection (`224,228–239`). Projection update clears its snapshot and synchronously notifies observers before asynchronous work (`AppLibraryProjectionController.swift:54–60`); current generation/revision gates publication (`83–89`). The next published detail render receives the refreshed preferences.

Therefore the old-success/newer-edit race is prevented by this serialized pending/session/projection contract, not by a universally safe receipt API. Any future change allowing edits during pending, reordered callbacks, or independent receipt delivery must add request/app binding and re-review this boundary.

The new draft regression at `AppLibraryViewTests.swift:93–117` checks repeated Details, nil/loading plus same identity, failure/retry value, failure text, success plus refreshed manual category, status clear, and replacement by another identity. Existing nil/loading/current-request and relabel tests remain. These are authored tests, unrun by this role.

**Confidence:** High for the bounded source repair; actual writer receipts and broader race tests remain Main's responsibility.

## Final inline failure-state additions

The lazy Details stack adds a wrapping status label with stable `library.details.saveStatus` identifier, width constraint and localized accessibility label (`AppLibraryView.swift:578–583,657–661`). It uses existing typed `.saveFailed` text and relabels on language changes (685–687). A `.saved` receipt clears the failure presentation; `.failed`/other unsuccessful results preserve a retry draft rather than claiming commit.

`setDetailActionsEnabled` first applies normal current-selection/loading availability, then disables only category popup, Save and Restore Automatic for protectedPayload/unavailable/recoveryRequired (664–673). Open/reveal/alias/hide/folder actions remain governed by ordinary selection availability and owner execution validation. This distinction is present in source; no shown-controls or accessibility run was performed.

The owner forwards the supplied result only to the active originating session and invokes `onCategorySaveFailure` for unsuccessful terminal results (212–220). Main's active failure alert is Main-agent-reported; this reviewer inspected that callback seam, not AppDelegate alert presentation or its GUI. The inline label and protected-control behavior do not independently prove the filesystem payload is protected; that remains the preferences/store contract.

## Other retained contract checks

| Area | Bounded source conclusion |
| --- | --- |
| Packets and I/O | `request()` at 476–478 uses current canonical entry, displayed catalog revision and owner generation. Actions remain callbacks, with no fake grid token, direct workspace action, scan, plist read or storage write in these views. Packet fields remain immutable. |
| Available factual fields | Read-only/selectable labels show original/alias, effective/automatic/manual category, bundle ID, canonical location and optional version/build (555–569,612–630). Missing/empty facts become localized Unknown; no invented developer, dates, size or usage history. |
| Taxonomy and Automatic | Exhaustive 22-category typed label mapping is unchanged from R1. All remains filter-only; Automatic/restore callbacks send nil. Canonical override reset, dormant entries, recognized metadata mapping and persistence are domain/owner responsibilities. |
| Loading and stale actions | Repeated nil/loading retains identity/navigation intent only and blocks requests. Fresh survival uses the newly supplied record/revision/generation; terminal absence clears selection/draft. Query/category changes invalidate before callbacks (428–454). |
| Escape/IME/Tab | Marked text precedes Details/query/Back (245–261); explicit Details close now cancels the draft. Search command handling preserves native Tab/Shift-Tab and marked-text delegation (406–414). Real IME behavior, sheet interception and native traversal remain GUI gates. |
| Blank/scroll/layout | Root hit/scroll containment, native scroll views, compact category control and drawer/side-by-side layout remain unchanged in behavior. Source does not establish momentum routing, clipping, reachability, actual blank-click suppression or pixel quality. |
| Locale/accessibility | Supplied typed LocalizedStrings is used throughout, including the new failure status. Direct relabel preserves query/category/selection and popup index; actual native popup changes now also populate the identity-bound draft for subsequent locale projection refreshes. English/Chinese/Japanese Library keys/mapping remain the R1-reviewed source contract, not evidence of packaged-resource validation. |
| Settings tab/relabel | Controller Library additions at 182,217,226,277,604–607 retain one view and relabel it in place; no draft apply/discard operation is introduced. The rest of that controller is outside this R2 verdict. |
| Settings state/reentry | Unchanged Settings view sets pending before synchronous callback and accepts terminal owner state without reasserting the draft afterward (103–120,77–88). It remains default off, explicit corrupt recovery, protected mixed/unknown and read-only; failure keeps the actual supplied committed baseline, success follows the receipt. |
| Settings geometry test | Unchanged corrected test at 307–333 measures native alignment rectangles for anchor margins, separately checks whole actual-control containment, and retains actual status/recovery frame nonintersection. The 2pt inset rationale is Main-agent-provided geometry, not this role's measurement or a pixel guarantee. |

## Shared icon lifecycle

Source guards remain intact at `AppLibraryView.swift:744–770`: visible window/Library/results, nonloading current snapshot, native visible-row bounds and identity checks on admission and delivery. Reusable cells use key + presentation generation + separate reuse generation (855–865); same key/generation avoids a new request. Binding, row removal, snapshot change, reset, hide/ancestor-hide and detachment cancel requests; cancellation clears images, and deinit cancels remaining handles (393–395,834–852,825 plus root lifecycle methods). No catalog-wide prefetch was added by the repairs or status label.

The unshown-window zero-request and hide/reset image-release tests remain at `AppLibraryViewTests.swift:394–419`. They do not independently exercise shown visible-row counts, delayed delivery during rapid reuse/scroll, row-removal cancellation, shared cache/in-flight budgets or an arbitrary order-out sequence. This source verdict covers the guards and reuse/cancel design; native lifecycle/performance verification remains separate.

## Coverage limits and next gates

Inspected inventory: 19 Library-view + 16 Settings + 9 localization methods = 44 methods in these three files. They were authored by the implementation/Main wave, and none was executed by this reviewer. Main's broader focused139/0 is separately attributed above; this review is not its test receipt.

Nonblocking coverage improvement: the new success-receipt assertion uses Finance before and after reconciliation, so it cannot by itself distinguish preservation of a dirty Finance draft from creation of a clean committed Finance baseline. It also directly injects receipts rather than performing a real submitted-save lifecycle. Strengthen coverage with a subsequent same-ID committed-category update after success (clean state should follow it), and explicit close/reset draft checks after a dirty edit. This is a test-strength observation, not evidence that the reviewed source is incorrect. Separate assertions for protected-result category-only disablement, failure-label relabel/accessibility and delayed originating-session receipts would improve confidence if not already in Main's broader tests.

Main retains ownership of full-r2 completion, current-manifest/source/executable matching, writer/owner race verification, build/package checks and delivery. Shown native GUI, real IME/Tab/VoiceOver, Details scroll/long text, blank/edge scroll containment, launch/reveal/hide/Back, restart durability and matched physical performance remain unresolved acceptance gates. No foundation or focused-test count closes those gates.

## Frozen source fingerprints (SHA-256)

These were rechecked after the final-additions re-freeze. A subsequent change invalidates the affected source judgment. Owner/projection hashes identify only the ancillary seam reads, not full-file certification.

| Input | SHA-256 |
| --- | --- |
| `Sources/PagingPrototypeApp/AppLibraryView.swift` | `0b3baba5237d99e06a7ca81f6ba3b406d6f80ee9036f3cff106cd678855c3c34` |
| `Sources/PagingPrototypeApp/AppLibraryCategoryLabels.swift` | `7cf0ef70fb1d51face074efca1c9141c6a23955b9089c4a9d39d15c949c1595a` |
| `Sources/PagingPrototypeApp/AppLibrarySettingsView.swift` | `f0abda4302e20fde515900be795990008034752170f4a11ac31fc8ac1387a325` |
| `Tests/PagingUITests/AppLibraryViewTests.swift` | `bbfcea593253a145d1f62abcd8a3aa2f032a2d96a16ab772bedfc0f5d228440f` |
| `Tests/PagingUITests/AppLibrarySettingsViewTests.swift` | `69b1b7c7872b721aecdc87f6e227ace0a2f0e6ea7581e04e216932fb05366795` |
| `Tests/PagingUITests/AppLibraryLocalizationTests.swift` | `840bd03577f9029097bfbf4b4a43eed5a8268af3909ce7c58057d9b1503fe679` |
| `Sources/PagingPrototypeApp/ActivationSettingsWindowController.swift` | `117b3a9180fdb1e5c776e6d1320d0a83d2245c8caaa3dc8fc763f06e468be843` |
| `Sources/PagingPrototypeApp/AppLibraryOwnerController.swift` (receipt seam) | `e99e9b851defd6cd05e90e36e40e79e4ebe4ec6c0e33e156955b98827940f7cd` |
| `Sources/PagingPrototypeApp/AppLibraryProjectionController.swift` (handoff contract) | `0ea791453aa1c6c6907071c83dc940cfef8e6ff78e4f78451262ac120a4a2309` |
| Preserved `Workflow/results/APP_LIBRARY_NATIVE_UI_REVIEW.md` | `b4dea5941ecc07a91e8fe3554ebd951e3122ebd73a68ccb964fa1ceef60aaee4` |
