# Clickable Page Dots — Independent Source Review

Date: 2026-10-13
Status: BOUNDED SOURCE REVIEW FAIL — R3/R4/R5 remain. R1/R2 repaired, source rechecked, and Main reports regression PASS in focused r5 (57/0).
Authority: approved `Docs/PAGE_DOT_IMPLEMENTATION_SPEC.md`.
Scope: Core / TransitionContext / Surface / owner wiring / frozen UI and focus code; source-only review. Main owns repairs and serial validation.

## Outstanding findings after Main's R1/R2 repairs

### R3 [P1] Revalidate the environment and ownership after stale observers

Evidence: `Sources/PagingCore/PagingCore.swift:223-234`, `Sources/PagingCore/PagingCore.swift:332-381`, `Sources/PagingCore/PagingCore.swift:386-395` (repair snapshot).

Scenario A: on an 8-page Core, request page 7. Before superseding it with page 6, install a one-shot `onStaleRejection` callback that calls `setPageCount(2)`. Abandonment has already cleared `activeTransition`, but state remains settling. The count setter finds no active context and leaves state/token unchanged. The outer request's guard at line 231 passes and uses the previously cached target 6. The new begin ownership checks also pass. It can commit page 6 with pageCount 2. Capture of target/offset before an outward callback is not made safe by a token/state-only check.

Scenario B: while a direct transition is active, `setReduceMotion` abandons it. If its stale observer tears down, cancels, or requests another page, lines 393-395 still call `beginSettle` for the obsolete target. `beginSettle` checks ownership only after creating a context and publishing settling, so teardown may already have been followed by state/transition mutation and a state callback; a newer request can be overwritten.

Likely cause: stale callbacks are treated as harmless between old-context removal and new-context creation. The new `requestPage` has a partial guard, while RM restart has no corresponding guard.

Recommendation: Main should validate current page domain, teardown, state and ownership after abandonment, derive a target/offset from the current environment, and protect RM restart against callback cancellation/replacement. Do not resurrect an obsolete owner. This is a recommendation within the approved stale-safety contract, not authority to redesign paging.

Testing suggestion (not executed): a one-shot stale observer shrinks 8 pages to 2 during request replacement; assert every target/committed page remains legal. Repeat with count 0 and offset/width change. For RM restart, stale observers cancel/teardown/request a newer page; assert no callbacks after teardown and latest ownership is retained.

Scope/risk: Core direct requests and RM restarts; preserve ordinary physical rebasing and commit-before-Idle publication. Confidence: high, synchronous source trace.

### R4 [P2] Provider replacement must cancel direct navigation before rebinding content

Evidence: `Sources/PagingUI/PagingSurface.swift:73-80`, contrasted with `:656-659` and `:695-698`.

Scenario: start a direct jump on provider A, then assign provider B with the same page count (including the same numeric revision). The public setter refreshes live content and relayouts immediately without cancelling the old direct context or releasing its pin. It therefore rebinds a new provider under the old interaction revision and allows the previous target to commit against replacement content. Even a later `refreshPresentation` cannot detect a different revision reliably because the setter already assigned `servedRevision` from B.

Likely cause: cancellation was added to explicit refresh/reload seams but omitted from the public replacement setter.

Recommendation: Main should cancel only direct ownership before refreshing replacement content and reconcile replacement revision/count and observation at that boundary. Keep physical input policy unchanged. Current AppDelegate assigns the provider during setup; this finding concerns the published Surface replacement seam and the approved content-replacement contract.

Testing suggestion (not executed): replace with distinct ready providers at equal count/equal revision and equal count/new revision, plus nil/not-ready provider, during direct settling. Assert old completion rejected, zero old-target commit, pin released, consistent content/count, and notification after replacement. Physical tracking must survive.

Scope/risk: Surface public provider replacement; avoid cancelling initial assignment or physical gestures unnecessarily. Confidence: high, setter inspected.

### R5 [P1] Reentrant offset observers can put the renderer back at a cancelled position

Evidence: `Sources/PagingUI/PagingSurface.swift:566-576`, especially the callback at 570 and captured-offset write at 573.

Scenario: install a one-shot `surface.appEvents.onVisualOffsetChange` that cancels direct navigation when the first animated frame arrives. Core's cancellation resets `visualOffset` to committed page 0 and synchronously renders that reset through a nested offset event. Returning to the original `handleCoreOffset(offset)` still writes `containerView.frame.origin.x` from its old nonzero argument. Its range check uses current Core offset and need not relayout, so the renderer stays displaced after the driver stops, even though Core is Idle at page 0. With immediate RM, a callback that requests another page similarly allows the outer offset handler to overwrite the nested final render.

Likely cause: Surface forwards a mutable/reentrant event before rendering a captured offset, and checks only teardown afterward.

Recommendation: Main should render the current owned Core offset after the callback or discard the obsolete event using an ownership/value check. Keep Core as the sole offset owner.

Testing suggestion (not executed): real Surface appEvents offset callbacks cancel, replace and teardown on the first frame; assert `-pageContainer.frame.minX / width == core.visualOffset` immediately after the frame/request, pin/driver consistent, no later correction frame required. Include synchronous RM replacement.

Scope/risk: Surface rendering; preserves existing range-dependent reuse. Confidence: high, actual synchronous nested call trace.

## Historical early findings (Main repaired; source rechecked)

The original observations below are retained for traceability; their original line references refer to the initial inspected source. They are no longer outstanding findings in their original scenarios.

- R1 repair: current `Sources/PagingCore/PagingCore.swift:561-581` checks active context identity, pending state, token, settling state and teardown after state/transition callbacks and after the immediate offset callback. The original cancelled/teardown/replaced begin now exits without continuing obsolete work. Core and Surface regression tests have been added. The separate stale-callback-before-begin case remains R3.
- R2 repair: current `Sources/PagingCore/PagingCore.swift:279-292` captures the completed token and publishes Idle only when token unchanged, no active context, still settling and not tearing down. Commit-before-Idle ordering is retained. `Sources/PagingUI/PagingSurface.swift:553-557` also confirms the actual Core state and teardown before idle/cancelled flushing and before `onIdleBoundary`. A newer request retains its context/pin. Main reports these regressions PASS in r5; reviewer inspected source, did not execute tests.


### R1 [P1] Revalidate transition ownership after synchronous begin observers

Evidence: `Sources/PagingCore/PagingCore.swift:556-564`; `Sources/PagingUI/PagingSurface.swift:546-563`.

Scenario: configure Reduce Motion, install a one-shot `surface.onPageNavigationChange` observer that calls `surface.cancelDirectNavigation()` when direct settling begins, then request page 4 from committed page 0. `beginSettle` sets `.settling`, which synchronously calls that observer. Cancellation invalidates the context and restores page 0/Idle. The outer begin resumes, emits `onTransitionBegin` for the stale context, writes `visualOffset = 4`, and only then rejects `completeSettle(ctx)`. Thus cancelled navigation still moves the renderer while committedPage remains 0. An observer that tears down at this boundary similarly allows callbacks/mutation after teardown. An observer issuing a newer request can have its displayed offset overwritten by the old immediate branch.

Likely cause: the new request's pre-begin token check protects stale-rejection observers, but `beginSettle` does not revalidate after `setState` or `onTransitionBegin` callbacks.

Recommendation: Main should revalidate teardown, active context identity/token and pending eligibility after each synchronous outward callback before emitting further events or writing offsets. Keep existing spring parameters and physical input policy.

Testing suggestion (not executed): one-shot state/navigation and transition observers that cancel, tear down or replace a request; test both immediate RM and nonzero RM. Assert no stale target offset/callback after cancellation, latest request remains owner, and no commit after teardown.

Confidence: high; follows the actual synchronous call graph.

### R2 [P1] Do not overwrite a reentrant accepted request with the previous commit's Idle

Evidence: `Sources/PagingCore/PagingCore.swift:279-287`; `Sources/PagingUI/PagingSurface.swift:588-596`.

Scenario: a one-shot `onPageNavigationChange` callback sees the first direct commit and requests another page. Core has cleared `activeTransition` but is still `.settling`, so the new request is accepted and creates a new direct context. Returning from the commit callback unconditionally executes `setState(.idle)` for the old transition. The new active context is left stranded in Idle; Surface stops its driver and unpins, while `isDirectNavigationActive` becomes false. Latest accepted request does not finish and direct-only cancellation no longer reaches it. The same path exists through `appEvents.onCommit`.

Likely cause: commit cleanup assumes outward callbacks cannot create another transition, although the new observer and public request API are synchronous.

Recommendation: Main should complete the old transition's state boundary before externally observable commit publication, or condition the remaining cleanup on unchanged ownership. Preserve presentation/idle callback order deliberately.

Testing suggestion (not executed): one-shot commit/navigation callback requests a new target, assert second request accepted, state/context/driver/pin remain consistent and latest target commits exactly once; repeat with RM and callback teardown.

Confidence: high; follows the actual synchronous call graph.

## Bounded consumer and contract checks

These are source observations, not blanket PASS declarations; outstanding findings above qualify them.

| Area | Actual source behavior and remaining limits |
| --- | --- |
| Core acceptance/no-ops | `PagingCore.swift:214-235` accepts Idle/settling with nonempty domain, clamps extremes, rejects Idle committed page and active direct target, clears session only after gates. Tracking includes release wait/glide and is rejected. Existing spring/tolerances are reused. Reentrant environment safety remains R3. |
| Provenance / RM | `TransitionContext.swift:26-67` separates reason from `isDirectNavigation`; Core RM restart carries provenance. Immediate/nonzero RM tests exist. Stale callbacks before RM restart remain R3. No physical timing/feel acceptance inferred. |
| Surface pin / finish | `PagingSurface.swift:270-289` rejects pending physical finish, pins before forwarding (necessary for synchronous RM), retains an existing pin across replacement, and delegates to existing driver. Idle/cancelled clear pin/pending through existing seams, now state-checked. Ordinary physical cancellation is excluded by direct-only guard. |
| Surface replacement / resize | `PagingSurface.swift:293-301`, `:656-717`, `:875-891` cancel count changes, new revisions and same-revision reload, including height-only bounds change. Explicit provider replacement remains R4. These paths execute cancellation before switching on Idle; they do not simply wait for natural completion. |
| Observation timing | Separate `onPageNavigationChange` is not telemetry `appEvents`, is cleared at teardown, and is emitted for discrete state/commit/count/reload changes, not offset ticks. Commit observation still occurs before Idle by design. Reentrant renderer consistency remains R5. |
| Real button to owner | `PageDotsView.swift:199-206` restores committed selection and sends absolute page target through the actual target/action callback. `AppDelegate.swift:2216-2262` wires owner to Surface/Core; checks title context, open folder, active held/click/drag session, final teardown, visible/key/active lifecycle, Core eligibility and served count agreement before clearing focus. Count now comes from committed provider count (nil hides loading), falling back to Core only without assembly. These updated gates are source-checked. |
| Focus clearing / suppression | `KeyboardFocusController.swift:137-202`, `:219-221`, `:256-278`, `:444-497` clear pending cross-page identity before pointer forwarding, clear actual old highlight/current/deferred state, consume top-level direction/activation through both key entry points while direct ownership is active, and seed the final committed page on the first later direction. Folder/title/search/Escape priority remains. Frozen focus tests exercise real cells, but some suppression tests inject an active provider; they are not actual direct-control or GUI acceptance. |
| Search input / Return | `AppSearchController.swift:129-148`, `:171-192` cancels direct ownership before query updates/clears, then commits when Idle. Return and Down are consumed during direct settling. Buttons refuse first responder and owner request does not alter query/responder. Owner test covers input cancellation, search count and Return suppression; installed field-editor responder acceptance remains a runtime gate. |
| Catalog before Idle | `AppGridRefreshController.swift:138-143` stages provider data before nonbusy notification; `AppDelegate.swift:580-586` cancels active direct navigation and commits pending at the resulting Idle boundary. `AppDelegate.swift:1084-1123` refresh/reload reconciliation and focus application are shared. This checks dot cancellation wiring only, not a re-audit of the Sources phase. |
| Parent hide / resign / screen | `AppDelegate.swift:2311-2340`, `:2526-2563`, `:1709-1713` explicitly cancel before hide transient cleanup, on hide completion/suspension, key/app resignation, resize and screen changes. Real lifecycle defaults are visible/key/NSApp active; Owner fixture explicitly injects lifecycle readiness and is not a real-window gate. |
| Chrome / B1 | `AppDelegate.swift:3071-3100` recognizes the strip ancestor identifier, including gaps/disabled controls. The actual window's chrome branch (`:2867-2870`) passes mouse-down to AppKit before blank dismissal/B1 manual cell delivery. The B1 recorded-cell up/drag branch still precedes hit classification (`:2786-2797`); Owner performClick tests do not prove all held-cell/chrome press routing. |
| Parent geometry | `AppDelegate.swift:2266-2269` derives strip position/width from its parent bounds; `:1606-1609` relayouts on existing resize/screen hooks. `LauncherWindowController.swift:403-422` fills only width+height-autoresizing views; dots do not use that mask, so are not stretched full-screen. Actual resize/show cycles still need runtime or mounted-parent tests. |
| Bounded reuse / cost | `PageDotsView.swift:14-49`, `:67-82` allocates nine dots plus two window buttons once; equal presentation updates are inert. `PagingSurface.swift:767-870` maintains range-based hosts and recycles before adding. Long jumps can change ranges and cause existing asynchronous icon requests. The 100-page test asserts residency per frame, not total icon work or frame latency. No new per-offset dot update, timer or synchronous icon loader was found in the dot changes. Performance remains unmeasured. |

## AXPress repair assessment

Current `Sources/PagingPrototypeApp/PageDotsView.swift:225-232` overrides AXPress to reject individually disabled/hidden controls, call native `performClick(nil)` exactly once, and report true. It does not call both super AXPress and performClick, and does not directly mutate navigation or selection. Existing target/action restores committed selection before forwarding, so a successful action can report true while an asynchronous target is still uncommitted; an enabled same-page no-op likewise need not change selection.

Main verified Apple's primary documentation and added its link to the approved implementation spec: [Apple accessibilityPerformPress](https://developer.apple.com/documentation/appkit/nsaccessibilityprotocol/accessibilityperformpress()). The action-trigger interpretation is consistent with this implementation and Main's observed r3 action delivery. This source assessment does not certify VoiceOver discovery, action availability, focus announcements, hidden ancestor behavior or full-screen accessibility. Return true is not navigation acceptance. Keep runtime VoiceOver as an explicit gate.

Recommended bounded regression additions: AXPress on nonselected and selected dots, exactly one action per press, unchanged selection until commit, disabled/hidden returns false with no callback, window-control AXPress changes only viewport, hidden strip/ancestor and owner-rejected stale state cause no navigation or focus change. Existing selected-button AXPress test does not establish all of these.

## Acceptance gaps for Main (not additional proven code defects)

- Use a mounted title editor/real first responder and actual button/strip coordinates, not just `requestPageFromDots`, to prove ignored title clicks leave editing/context/focus untouched. The full-bounds folder overlay is above dots (`AppDelegate.swift:1471-1475`; `FolderOverlayView.swift:728-743`) and routes backdrop presses differently (`:563-617`). The title drag gate rejects arbitration, but `refusesFirstResponder` alone does not prove this complete routing/responder contract. Do not label it passed from a detached performClick test.
- Exercise held B1 cell press and click-only search press through real window down/up routing, then attempt chrome action while busy. Assert no navigation, focus clearing, old-cell launch, session cancellation or pending-finish changes attributable to the ignored dot request. The coordinator's `isSessionActive` includes pressed and click-only states, but detached Owner tests have not established the actual chrome event sequence.
- Add same-count catalog/revision and same-revision replacement cancellation before natural Idle, including renderer/pin and stale completion assertions; R4 needs distinct provider replacement coverage. Keep physical tracking/glide counterexamples.
- New unloaded-catalog and actual-renderer-reuse Owner tests were reported by Main as added for the full run after r5. Their execution result is not available in this review. Finish focused/full checks on the repaired fingerprint, then Debug/Release/candidate/hash gates per spec. GUI, full-screen physical A/B, 120 Hz and performance remain separate.

## Execution and evidence boundary

- Reviewer ran no Swift executable, build/test, GUI, process inspection/control, commit, signing/publishing, reference-product/Buho inspection or source-phase re-audit. Only `Docs/PAGE_DOT_SOURCE_REVIEW.md` was written; all implementation/test/workflow files were read-only. Existing dirty work was preserved.
- RTK was read first; that initial read plus initial skill-path lookup/memory-registry miss lacked the prefix. Every subsequent shell command used RTK. Actual skill loaded: `/Users/mac/skills/skills/skills/write-swift/SKILL.md` (catalog path was stale). Review respects the project's Swift 5.9/macOS 14 package and XCTest conventions; no speculative toolchain migration.
- Source-phase baseline: 2023 tests / 0 failures and prior source/build evidence are historical, not dot validation.
- Main-reported dot execution: r3 52 tests / 1 AXPress-return assertion failure; actual action was delivered. r4 52/0 after AXPress/count gates, before R1/R2 repairs. r5 57/0 after three Core and two Surface reentrancy regressions, including R1/R2. These are direct Main reports; reviewer did not run tests or independently inspect result logs.
- Evidence update (2026-10-13, Main direct report): full-r1 completed at 21:48:51.962 JST in 31.422 s, 2082 tests / 0 failures, comprising 59 dot cases plus the 2023 baseline. This supersedes the earlier 2082/0 expectation. Reviewer did not independently inspect the log. R3/R4/R5 scenarios remain absent from inspected regressions; a full green run does not close them. No final build/candidate/GUI/VoiceOver/physical/performance PASS is asserted.
- Main plans an actual mounted-title dot-ignore regression in the existing FolderRenameAssemblyTests fixture, plus static grid-bottom/dot-footprint geometry checks, before final build. These are pending and are not treated as production defects or completed runtime validation.

## Bounded verdict and next action

R1/R2: repaired for the reported scenarios, source rechecked; Main reports r5 regression PASS. R3/R4/R5: actionable source defects still present in the fingerprint below. Verdict is FAIL for the bounded source slice until Main repairs these and adds corresponding regressions. Recommendations do not authorize reviewer code edits or architecture changes. A green current full suite would not discharge scenarios absent from that suite.

Main owns repair, serial test/build execution, updated stage documentation and all subsequent runtime acceptance. This report closes the requested review pass without executing or interfering with Main validation. Full-r1 evidence was reported after this fingerprint was taken; the source verdict remains qualified by R3/R4/R5.

## Exact reviewed fingerprint

The fingerprint identifies inspected source/test inputs, not an app binary or performance candidate. Later edits require matching repair review and fresh execution evidence.

Snapshot UTC: 2026-10-13T12:50:08+00:00

```text
06886c47ce51709bf3091e940308119d0651775d706e122cd2bd8f60f69be74c  Docs/PAGE_DOT_IMPLEMENTATION_SPEC.md
3149443adb72bf17ddd24be83d9286999e68256d14f7e530727a4b28486fa650  Sources/PagingCore/PagingCore.swift
2a9e3e66ca0a1a07ac02d2453eda8d1e923a1240154b5b0892a37b48e9f0f88b  Sources/PagingCore/TransitionContext.swift
882699ef784ff5ac33f51538089cdc0d81cd63eac9d674e247b2940aa8383798  Sources/PagingUI/PagingSurface.swift
d7a90f516f85f05df1d7aa989fae0a61887948c4ba040e70a44ecf20ebeeb889  Sources/PagingPrototypeApp/AppDelegate.swift
c2f49fb29479df13f34b2c329c5848149167a45fcdd312a53978c053c56bd39a  Sources/PagingPrototypeApp/AppSearchController.swift
f8059dad106d5c15e0cfbfcaacc295d01b870a4b5aa1307d197987d4e0a6b8c8  Sources/PagingPrototypeApp/KeyboardFocusController.swift
a00c0c190ac247ab05d23509572c6a2f432eb3090e49d729ab46616ef3f585e7  Sources/PagingPrototypeApp/PageDotsView.swift
21da1f1f5a56cc75ee0bb43caaeedbeb56cd559725ea3739aa891f2ca1e28321  Sources/PagingPrototypeApp/LauncherWindowController.swift
c15663ae78b97b256685095aea74a2a08c57df19b22c96d4663a0fde58368c51  Sources/AppGridUI/FolderOverlayView.swift
57a141f2cca1289410e6caf9d438725d66944e980ddd12901a6fca23d8ef2667  Sources/AppGridUI/DragUI/DragUISessionCoordinator.swift
0735993ef4fdb8d9c090a1a4c85f6a98d0e718a707d81360c039b33f71009492  Tests/PagingCoreTests/DirectPageNavigationTests.swift
300ee5ed4b31bace6074d3db94c8b30c3ef0b6a44c650469bab782cfcd2f29b5  Tests/PagingUITests/DirectPageSurfaceTests.swift
7462b669ff9e5c9b824454da945043a3fa48a5a63b5e6cdca34d1021a825f9eb  Tests/PagingUITests/PageDotOwnerTests.swift
c794067e1717ff4700d7a1140011d36b7344d32ab776c0e2311c5984f41c00e6  Tests/PagingUITests/PageDotsViewTests.swift
f0fa0de87f9e8a4bd82b6bc36b05afa48d9a2b148a79f98890e4fe77292b9b5f  Tests/PagingUITests/PointerPageFocusTests.swift
```


## Repair re-review — 2026-10-13 (R3–R5)

**Latest bounded source verdict: PASS for the inspected repairs.** This dated addition supersedes the earlier source FAIL for R3/R4/R5; all earlier findings, evidence and fingerprints above remain historical records. No additional actionable defect was identified in this bounded repair pass. This is not a final test/build/GUI/VoiceOver/physical/performance verdict.

### R3 — Closed for the reported stale-observer scenarios

Actual source: `Sources/PagingCore/PagingCore.swift:223-240`, `:391-405`, `:557-581`.

- `requestPage` snapshots count/width/RM and continuous offset before abandonment. It first rejects teardown, changed token or changed state, so it does not cancel a newer accepted request. It then compares the environment/offset and cancels the abandoned request if they changed, returning false instead of using the cached target. Shrink-to-two no longer creates or commits target six; shrink-to-zero leaves no new context.
- RM restart snapshots the previous token and page domain, then validates teardown/token/settling/no active context after abandonment. Reentrant cancellation/teardown returns; a newer request changes token or creates an active context and is preserved. Changed count/width/RM cancels rather than resurrecting the cached target.
- `beginSettle` now guards teardown, nonempty count and target legality before incrementing the token, creating context or publishing state. The R1 ownership checks still follow state/transition/offset outward callbacks.

Regression source: `Tests/PagingCoreTests/DirectPageNavigationTests.swift:131-144` covers stale-observer count 0/2 and asserts rejection, no commit, legal final offset and no context. `:146-165` covers RM stale-observer cancellation, teardown and latest replacement. These are meaningful regressions against the exact prior defects. Width/RM domain comparison is also visible in source; not every environment combination is parameterized in the two tests. Execution of this new snapshot is pending Main's r6 report.

### R4 — Closed for provider replacement cancellation

Actual source: `Sources/PagingUI/PagingSurface.swift:73-86`.

`willSet` calls direct-only cancellation while the old provider reference is still installed. Cancellation therefore releases the old direct context/pin before content binding changes. `didSet` reconciles a ready replacement's page count only when an old provider exists and Core is Idle, then refreshes content, relayouts and emits the discrete navigation callback. Initial provider assignment does not force the ready-count reconciliation; physical tracking does not enter that Idle branch and direct-only cancellation does not cancel physical ownership.

Regression source: `Tests/PagingUITests/DirectPageSurfaceTests.swift:115-135` covers equal/new/nil revision providers, replacement with nil, rejection of old completion, no old-target commit, released pin and surviving physical tracking. Together with the existing count/reload seams, this closes the reported public-setter omission. No claim is made that all possible provider identity/lifecycle permutations have been executed.

### R5 — Closed for renderer overwrite after reentrant offset consumers

Actual source: `Sources/PagingUI/PagingSurface.swift:571-582`.

The external offset observer still receives the original event value, but after it returns Surface checks teardown, obtains current bounds, and renders `core.visualOffset` rather than the stale argument. Nested cancellation/replacement can therefore render its final owned position without the outer handler moving the container back. Range-dependent host reuse still derives from Core and is unchanged.

Regression source: `Tests/PagingUITests/DirectPageSurfaceTests.swift:91-106` uses actual Surface offset callbacks for animated cancellation and synchronous RM replacement, then compares container geometry directly with Core offset and checks final page/Idle immediately. It does not rely on a later correction frame. Execution evidence is pending r6.

### Preservation of R1/R2 and existing consumers

Current `PagingCore.swift:284-297` retains the completed-token/active-context/state/teardown conditional Idle cleanup and commit-before-Idle order. Current `PagingSurface.swift:558-562` retains the actual-state and teardown guards around idle flushing. No spring, tolerance, physical gesture threshold, frame driver or keyboard focus implementation was changed in these repairs. The prior R1/R2 closure and Main-reported r5 57/0 stand for their earlier fingerprint; the combined new fingerprint still requires fresh execution.

The original direct/no-op, committed-count, keyboard pending-target, search input/Return, lifecycle and AXPress consumer checks remain applicable: their inspected source files did not change since the prior review fingerprint. This is a repair review, not a new Sources-phase audit.

### Mounted-title acceptance update

`Tests/PagingUITests/FolderRenameAssemblyTests.swift:137-153` adds a real mounted editor/window first-responder fixture and a real page button target/action. It explicitly enables a stale dot presentation, attempts both owner request and `performClick`, and asserts the same editor/responder, unchanged layout and no store writes. This materially improves the previous detached/title acceptance gap and exercises stale UI enablement defense.

Its lifecycle readiness is explicitly mocked, and `performClick` invokes target/action without the window's physical mouse-down/up hit-routing path. Therefore this test is mounted responder/action coverage, not GUI, B1-held chrome routing, native title-backdrop click, or VoiceOver acceptance. The existing one-page/folder fixture also has overlapping rejection gates; it does not isolate each gate independently. These are stated test limits, not new source defects. Execution is pending r6.

### Evidence and remaining delivery gates

Main reports r6 running/about to run on the stable repaired sources. No r6 result was supplied during this pass; no execution is inferred. Prior r5 57/0 and full-r1 2082/0 remain valid historical Main reports and must not be reused as execution of the newer four regression cases plus mounted-title addition. Main owns serial focused/full validation and final Debug/Release/candidate/hash gates.

No proven source defect remains from R1–R5 in this review's bounded scenarios. Actual B1-held/click-only chrome event routing, repeated parent show/resize/screen behavior, static grid-bottom/strip geometry checks, native VoiceOver, exact-candidate GUI/full-screen physical A/B, 120 Hz and measured frame/icon costs remain separate acceptance evidence. Source PASS does not close those gates.

Reviewer modified only this document, executed no Swift/build/test/GUI/process/commit operation, and preserved the dirty tree and prior FAIL history. All commands in this repair pass used RTK. The previously loaded actual write-swift skill guided ownership/reentrancy/lifetime review; no toolchain migration or test-framework change was proposed.

### Repair fingerprint

Snapshot UTC: 2026-10-13T12:58:05+00:00

```text
de5288496d186b7edb280f22202e7760dc415d1ad6d4797df14e3e6bbd7d1e14  Sources/PagingCore/PagingCore.swift
b6db6baf49aa975e3a435eb335e24792f488ebc46b656fb92d50a294bd650f8b  Sources/PagingUI/PagingSurface.swift
f3b8505338007b6e101f886f0793007575e17d78c8765688ee92bcfbc3f8b770  Tests/PagingCoreTests/DirectPageNavigationTests.swift
cc139cc9f3d308e6fea87206dfbccdcdb19980252ba8dc315c1b3f83ac9dddf2  Tests/PagingUITests/DirectPageSurfaceTests.swift
385d8c83551260c29c24553b51f574aa341557f26b710159256a40c424bc4bed  Tests/PagingUITests/FolderRenameAssemblyTests.swift
d7a90f516f85f05df1d7aa989fae0a61887948c4ba040e70a44ecf20ebeeb889  Sources/PagingPrototypeApp/AppDelegate.swift
c2f49fb29479df13f34b2c329c5848149167a45fcdd312a53978c053c56bd39a  Sources/PagingPrototypeApp/AppSearchController.swift
f8059dad106d5c15e0cfbfcaacc295d01b870a4b5aa1307d197987d4e0a6b8c8  Sources/PagingPrototypeApp/KeyboardFocusController.swift
a00c0c190ac247ab05d23509572c6a2f432eb3090e49d729ab46616ef3f585e7  Sources/PagingPrototypeApp/PageDotsView.swift
06886c47ce51709bf3091e940308119d0651775d706e122cd2bd8f60f69be74c  Docs/PAGE_DOT_IMPLEMENTATION_SPEC.md
```


## Cancellation and geometry follow-up — 2026-10-13 (pre-r7)

**Latest bounded source verdict: FAIL — R6 remains.** This supersedes the preceding repair PASS only for the newly inspected Core cancellation path; R1–R5 remain closed for their reported scenarios. Historical verdicts and fingerprints are preserved.

### R6 [P1] Revalidate Core cancellation after its outward reset-offset callback

Evidence: `Sources/PagingCore/PagingCore.swift:411-429`, particularly `:425-428`.

The added token/state/no-active/teardown guard at line 419 correctly protects a newer request issued by the abandonment's stale observer. However, `cancel()` then publishes another outward callback through `fireOffsetChangeIfChanged()` at line 425, after which it still unconditionally sets Cancelled and Idle.

Concrete scenario: start page 7 navigation from committed page 0 and advance one frame so offset is nonzero. Arm a one-shot `onVisualOffsetChange` observer to request page 2 when cancellation resets the offset to 0. Call Core.cancel(). Abandonment clears the old context; its stale guard passes. The reset-offset observer sees state still settling and no active context, so `requestPage(2)` is accepted and creates the next transition. Returning to the outer cancel sets Cancelled then Idle without rechecking the captured token. The new context is stranded in Idle; ticks do not advance it and `isDirectNavigationActive` is false. If this callback instead tears down, the outer cancel also publishes state changes after teardown. This does not require modifying private state or synthetic physical input.

Likely cause: the ownership check was added after stale publication but not after the second outward boundary in the same function.

Recommended repair for Main: apply the captured token/state/no-active/teardown ownership condition after reset-offset publication, before cancellation-state cleanup. Preserve the newer request or teardown; do not change spring/input parameters. Keep direct Surface closing policy distinct from Core's general callback safety.

Regression suggestion (not executed by reviewer): one frame then one-shot reset-offset callback requests a newer page; assert accepted context continues and commits its target, no Idle/context mismatch. Add teardown counterpart asserting no state callback after teardown. Existing `DirectPageNavigationTests.swift:165-176` only reenters from `onStaleRejection`, so it does not establish this boundary.

Affected scope: Core cancel, potentially Surface consumers calling unscoped cancel/Core API. Surface scoped lifecycle cancellation now blocks reentrant Surface requests and mitigates that specific owner path, but cannot establish the public Core cancellation invariant. Confidence: high, exact synchronous source trace.

### Checks that passed at source level in this follow-up

- Surface `PagingSurface.swift:276-297` sets `isCancellingDirectNavigation` before invoking Core.cancel and keeps it set through driver update and discrete observer publication; `defer` restores it. `canRequestPage` rejects while this scope is held, before pin creation. Nested scoped cancel is also rejected. `DirectPageSurfaceTests.swift:133-140` exercises actual stale observer attempting Surface.requestPage while closing. This protects the reported visible-old-window lifecycle callback case without broad physical cancellation.
- `AppDelegate.swift:2266-2275` derives the bottom gutter from existing ordinary 35-item `AppGridGeometry` and slot 34, uses strip height at most 32 and inset at most 20 constrained by remaining gutter space. Therefore the strip's top stays at or below the last row's bottom: if gutter is below 32, height consumes only that gutter and inset is zero; otherwise inset does not exceed half the remainder. No grid spacing parameter is changed. Source geometry/renderer consumption is inspected separately from rendered GUI.
- `PageDotOwnerTests.swift:146-156` mounts the strip and invokes the owner's resize hook at heights 640/700/956, asserting strip above parent bottom and below the same last-row rectangle. This is mounted rectangle regression coverage, not pixel/UI appearance, minimum hit-target or physical acceptance.

### Updated evidence boundary

Main reports r6 **84 tests / 0 failures**, covering the R3–R5 cases and mounted-title regression. This supersedes the previous pending-r6 note for that fingerprint; reviewer did not execute tests or independently inspect logs. The new stale-cancel, Surface closing and geometry regressions belong to the following snapshot; r7 result is not yet provided. A green r7 would not discharge R6 unless the reset-offset callback scenario is added.

Only this Markdown was appended; source remains read-only. No Swift/build/test/GUI/process/commit operation was run by reviewer. VoiceOver/GUI/full-screen physical/120 Hz/performance gates remain unclaimed. Main owns repairs and serial evidence collection.

### Follow-up fingerprint

Snapshot UTC: 2026-10-13T13:02:23+00:00

```text
daf12a67cc69603097830be9b5d617990d4726f71280bf820ee07ddc238abca1  Sources/PagingCore/PagingCore.swift
9e20767ff19c0817bba43297a332cca0ec8c0abd438c95f6410ca564076adba7  Sources/PagingUI/PagingSurface.swift
440dcd426d16b4502288d255bfed39975617d6f223718e38350541ca59c5fd76  Sources/PagingPrototypeApp/AppDelegate.swift
f5831cd12187c9b60d6c7762ea7905cf633def8294198b0fcc82b62049b0a1f3  Sources/AppGridUI/AppGridGeometry.swift
e4ad35b405f9a2e750b723496f312545cc43d4facdf5e5bf62d576e0edac46af  Sources/AppGridUI/AppGridPageView.swift
593c092dd25b2d49d7357a7a3a9079cac0efce003a55c966e263233eae7995f8  Tests/PagingCoreTests/DirectPageNavigationTests.swift
2c1f5c958695ba13f0020c2f546f62acbaaacd61882a063034b456b25b895c9c  Tests/PagingUITests/DirectPageSurfaceTests.swift
681e24b58b0d1418c6c5c92bed82ab16328a90c21555b0fbefac6121d92592e4  Tests/PagingUITests/PageDotOwnerTests.swift
385d8c83551260c29c24553b51f574aa341557f26b710159256a40c424bc4bed  Tests/PagingUITests/FolderRenameAssemblyTests.swift
```


## Final bounded R6 repair re-review — 2026-10-13

**Latest bounded source verdict: PASS. R6 is closed for the reported scenarios; R1–R5 remain closed.** This appendix supersedes the pre-r7 R6 FAIL above without changing its history. No remaining actionable source defect was identified in this bounded R6 repair review. Test/build/delivery and runtime gates remain separate.

### Actual repair and ownership trace

`Sources/PagingCore/PagingCore.swift:411-430` now validates teardown, the captured transition token, absence of a new active context, and the pre-cancel state immediately after the reset-offset outward callback (`:425-426`). A callback accepting a new page changes token/active context, so the old cancel exits before publishing Cancelled/Idle. A callback tearing down exits without publishing another state event. Cancellation with unchanged ownership retains the original offset reset and Cancelled→Idle boundary.

The additional check after `setState(.cancelled)` (`:428-429`) validates teardown/token/no active context and actual `.cancelled` state before publishing Idle. Thus another owner/state adopted synchronously by a Cancelled observer is not overwritten by old Idle cleanup. The prior stale-observer guard at `:417-419` is retained. These three checks cover distinct outward callback boundaries; counter/token increment and physical/spring parameters were not changed by this patch.

### Regression source assessment

`Tests/PagingCoreTests/DirectPageNavigationTests.swift:177-196` adds `testCancellationResetOffsetObserverCannotStrandNewRequestOrEmitAfterTeardown`. It first starts a nonadjacent transition and advances one frame, then arms the reset-to-zero offset callback. One variant requests a newer page and asserts acceptance/final committed page 2; the other tears down and asserts zero state callbacks after teardown, final page 0 and no active context. This test would fail the prior R6 behavior and directly exercises the reported callback boundary rather than just stale publication.

The separate post-Cancelled callback guard is source-checked; the new test does not independently reenter from `onStateChange(.cancelled)`. This is a disclosed test limit, not a newly found defect. Surface scoped closing protection and gutter/mounted-rectangle checks retain the preceding review's source assessment: their source/test fingerprints have not changed since the pre-r7 snapshot.

### Current evidence and remaining gates

Main reports r7 **87 tests / 0 failures**, including closing guards and geometry, executed before the R6 reset-offset repair. Therefore r7 is historical evidence for that earlier snapshot, not execution of the repair reviewed here. Main reports r8 focused validation running and full-r2 next; neither result was provided during this pass. R6 source closure is conditional only on this inspected source, while fresh execution remains Main's delivery responsibility.

No blanket GUI, VoiceOver, actual held-B1/chrome down/up routing, physical A/B, 120 Hz or frame/icon performance PASS is claimed. Mounted title and rectangle tests remain the specific evidence layers previously described. No Swift/build/test/GUI/process/commit was executed by reviewer; only this Markdown was appended and all prior FAIL/PASS history was preserved.

### Final R6 fingerprint

Only Core and its direct-navigation regression test changed relative to the preceding pre-r7 review fingerprint; the other listed files matched when checked during this pass.

Snapshot UTC: 2026-10-13T13:04:49+00:00

```text
06a83e4ec5c2ff2cd0d6a388bf957b3ff08fc4fd6bcc03b6c6049f7553612792  Sources/PagingCore/PagingCore.swift
92b98e2943e8175c4ad8c23f00c8eea9867136b4d8980ae57fc2012bd848c8af  Tests/PagingCoreTests/DirectPageNavigationTests.swift
```


## Final review handoff and r8 evidence — 2026-10-13

**Final bounded source verdict: PASS; review handed back to Main.** R1–R6 are closed for their reported source scenarios. No remaining actionable source finding was identified in the assigned review. Historical FAIL/repair records above are retained; this dated handoff supersedes earlier pending-r8 notes.

Main's direct execution report: focused r8 completed at **22:03:59.473 JST**, duration **2.198 s**, **88 tests / 0 failures**, including the R6 cancellation reset-offset/new-request and teardown regression. Main states no source edits followed. Reviewer rechecked the final R6 Core/test hashes against the last review fingerprint and found them unchanged; reviewer did not execute tests or independently inspect r8 logs.

Main reports a pre-validation manifest of **334 source/test/script/resource/package fingerprints** and serial full-r2 plus Debug/Release validation under unique candidate identifier `page-dots-rc-20261013-r1`. The manifest count and candidate identifier are Main-reported; reviewer did not independently audit all 334 entries or inspect an app binary. These full/build runs are in progress with no completion result supplied at this handoff. Prior full-r1 2082/0 precedes subsequent repairs and is not execution of the final candidate.

Main owns completion of full-r2, Debug/Release, candidate/hash/source-fingerprint consistency and delivery documentation. The reviewer is released after recording the known results, not claiming a final artifact/build release or launching/installing anything.

Explicitly pending: actual held-B1/chrome mouse event routing, native VoiceOver, exact-candidate GUI/full-screen physical A/B, 120 Hz and measured frame/icon performance. Mounted title/action and geometry tests provide only their stated layers of evidence. No full-parity claim is made.

Only `Docs/PAGE_DOT_SOURCE_REVIEW.md` was written throughout review; source/test/script/resource/package/workflow files remained read-only. No Swift/build/test/GUI/process/commit operation was run by reviewer, and the existing dirty tree was preserved.


## Final bounded D7 environment-cancel check — 2026-10-13

**Latest bounded source verdict: PASS for the two added guards and regression.** No new actionable source finding was identified within this requested direct-cancellation/teardown boundary. R1–R6 closures remain as previously bounded; prior review and execution history is retained.

Actual source: `Sources/PagingCore/PagingCore.swift:305-312` and `:338-344`. Both environment setters now recheck `!isTearingDown` immediately after their direct-navigation `cancel()` branch and before writing `pageWidth`/`pageCount` or entering subsequent rebasing/count reconciliation. If the cancellation's stale observer tears down Core, these second guards exit before domain mutation. Ordinary equality/no-op checks remain before cancellation, and the added guards do not change spring or physical input parameters.

Regression source: `Tests/PagingCoreTests/DirectPageNavigationTests.swift:197` adds `testEnvironmentCancelObserverTeardownPreventsLaterDomainMutation`. Its two loop cases start a direct transition, tear down from `onStaleRejection`, then exercise width 1000→1200 and count 8→2 setters. Assertions confirm teardown, unchanged width/count and final Idle. The prior code would have changed the respective domain property after teardown; this is a regression of the specific defect, not just a matching implementation check. Reviewer inspected source only; fresh execution is pending.

Main reports **full-r2 2091 tests / 0 failures** and successful **Debug/Release candidate-r1**, with SHA prefix **a072487a…**, before these two guards/new regression. The complete digest and binary were not independently inspected by reviewer, and Main explicitly states the candidate has not been promoted. These results are historical evidence for the pre-change candidate; they do not validate the following fingerprint.

Main plans r9 focused validation, full-r3 and release-r2 with fresh fingerprints. No result for those runs has been supplied at this check. Main states all other source is unchanged; reviewer verified these Core/test inputs changed relative to the last R6 fingerprint and kept this pass confined to the two guards and test. Reviewer makes no promotion, installation or final candidate acceptance claim.

No additional GUI, held-B1/native mouse routing, VoiceOver, physical A/B, 120 Hz, performance or full-parity acceptance is claimed. Only this Markdown was appended; no source edits, Swift/build/test/GUI/process/commit operations were performed by reviewer.

### D7 repair fingerprint

Snapshot UTC: 2026-10-13T13:13:30+00:00

```text
fcef83d7b586e5ee36e6339f6ebc7702a6e4b1b15150a0206f61fedb81d68369  Sources/PagingCore/PagingCore.swift
32f7ce559aeddcf9fce2012c61b8e5db0984e86f68ae5f2647ac8e183e883e47  Tests/PagingCoreTests/DirectPageNavigationTests.swift
```


## Final r9 evidence and reviewer release — 2026-10-13

**Final bounded source verdict: PASS. Reviewer ownership of this document is released to Main.** R1–R6 and the final two post-cancel teardown guards are closed for the inspected scenarios; no remaining actionable source finding was identified within the assigned review scope. Previous FAIL/repair/verification history remains unchanged.

Main reports focused r9 **89 tests / 0 failures**, completed at **22:12:29.845 JST**, after the last change comprising two Core setter post-cancel teardown guards and the additional Core regression. Reviewer rechecked the Core/test SHA-256 inputs against the immediately preceding D7 repair fingerprint and found them unchanged. Reviewer inspected source and regression design; reviewer did not run tests or independently inspect r9 execution logs.

Main reports the current **334-entry source/test/script/resource/package hash manifest** was captured before full-r3. That manifest is Main evidence, not an independent audit of every input. Full-r3/artifact/build/promotion details are intentionally left to Main's own stage and delivery documentation; no result is inferred here and no wait for those artifacts is required to release this bounded review.

Actual GUI, held-B1/native mouse routing, native VoiceOver, physical A/B, 120 Hz and performance remain **unverified**. Main's subsequent build/stage records must not be represented as this reviewer's independent runtime acceptance. No full-parity, installed/promoted candidate or physical PASS is claimed.

Only `Docs/PAGE_DOT_SOURCE_REVIEW.md` was written by reviewer. No source edits, Swift/build/test/GUI/process/commit/promotion were performed, and existing dirty work was preserved. Main owns all subsequent edits, evidence updates, builds and delivery decisions.
