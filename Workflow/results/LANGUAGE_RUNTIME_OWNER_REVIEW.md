# Language Runtime Owner — Independent Source Review

Date: 2026-10-14
Verdict: **FAIL — bounded runtime-integration SOURCE review; two findings.**

## Authority and evidence boundary

- Reviewed the approved `Docs/INTERFACE_LANGUAGE_SPEC.md`, repository `AGENTS.md`, runtime stage summary, and current implementation source. This is an existing approved project; Chief workflow is waived and the limit is three agents including Main. No additional agent was dispatched.
- Reviewer owns only this report. Main owns implementation repairs, integration tests, compilation, and verification.
- No Swift command, build, test execution, UI/app launch, app/process control, commit, installation, or reference implementation/resource access occurred. Existing tests were read as source only. Main's compile/focused run is independent evidence and is not certified here.
- Appearance/Management/Sources view internals were inspected only where needed to trace Main's reload and ownership wiring. Their detailed resource/view review belongs to the other reviewer.
- Activation/service/shortcut copy, folder/pager/accessibility consumers, app-action/error-alert copy, and other explicitly deferred groups remain pending. Their missing future-wave translations are not findings and this report does not grant full-feature PASS.
- AccessDeclaration: NO_PRIOR_EXPOSURE to restricted reference code/assets in this review.

## Findings

### F1 — [P1] Reopening/fronting the existing settings window destroys in-progress drafts and stops recording

**Evidence / lines**

- `Sources/PagingPrototypeApp/ActivationSettingsCoordinator.swift:69–95`: every `showSettings()` reconstructs an activation draft from committed preferences, invokes the singleton factory, and unconditionally invokes `configureAdditionalSettings`.
- `Sources/PagingPrototypeApp/ActivationSettingsWindowController.swift:198–204`: the existing-instance branch still invokes `existing.reload(draft: draft)`.
- Same controller, `:286–290`: reload stops shortcut recording, overwrites the draft, and synchronizes controls.
- `Sources/PagingPrototypeApp/AppDelegate.swift:1809–1813`: the additional-settings hook reruns Appearance, Management, Sources, and Language configuration on every open/front request.
- Same delegate, `:1889–1894`, `:2234–2237`, `:1868–1870`: the first three configurators reload committed preferences rather than preserve existing drafts.
- `Sources/PagingPrototypeApp/AppSourcesSettingsView.swift:94–103,118–122`: the invoked reload cancels operations/the open panel and replaces the source draft. `AppManagementSettingsView.swift:103,110–113` overwrites unsaved alias text through selection refresh. These are caller-chain evidence, not a separate deep consumer audit.
- `Docs/INTERFACE_LANGUAGE_SPEC.md:59–66` explicitly requires preserving every in-progress draft on reopen and prohibits the existing `reload(draft:)` factory path.

**Concrete trigger / impact**

Open Settings, leave unaccepted activation/appearance/source changes or an unsaved alias, then request Settings again through the status menu (`AppDelegate.swift:2624–2625`). The visible singleton is reused, but the above code replaces those drafts with committed values. Shortcut recording is stopped by the factory. Reopening after hide also reloads other sections even though the new close hook deliberately discards only the language draft. An active source operation/picker can be cancelled by this same route. `configureLanguageSettings` preserves the language draft when already configured, but that local protection does not protect the surrounding sections.

**Likely root cause**

The language reopen refresh was added to the old destructive open/configuration path. Singleton reuse and callback rebinding were not separated from initial draft population.

**Recommended solution**

Main should make repeated front/reopen a non-destructive path: retain the existing activation controls/recording and all other drafts, rebind necessary callbacks without reload, and refresh only accepted-language resolution plus non-destructive semantic status. Populate committed drafts on first construction or an explicit section-specific accept/discard action. Preserve the approved language-close behavior. Do not fix this by rebuilding the singleton.

**Affected scope / regression risks**

Settings coordinator/factory and Main's additional-settings configurators. Preserve first-open initialization, explicit Apply/Restore Defaults, read-only notices, selected records/roots/tab, alias field editor content/selection, recording lifecycle, and source operation generations. Acceptance tests should drive the real repeated `showSettings()` path, not only view `relabel()` methods. Also cover an equal Follow System refresh with a changed effective language while another section has a draft or ownership.

**Confidence:** High. The destructive assignments/cancellation are explicit in the current source. No GUI reproduction is claimed.

### F2 — [P2] A retained old language coordinator can route acceptance into a replacement namespace's owner

**Evidence / lines**

- `Sources/PagingPrototypeApp/AppDelegate.swift:2007,2016–2018`: installation tears down the previous presentation, but each coordinator's request closure dynamically dereferences `self.languagePresentationController`. It is not bound to the coordinator's original owner or `languageGeneration`.
- Same file, `:2023–2025`: subsequent installation replaces the current coordinator/owner/snapshot.
- Same file, `:2113–2124`: teardown invalidates scheduled retries and clears view callbacks, but does not invalidate a retained coordinator's request closure.
- `Sources/PagingPrototypeApp/LanguageSettingsCoordinator.swift:36–46`: successful Apply and `refreshAcceptedPresentation()` can still call that closure.
- The readiness callbacks at `AppDelegate.swift:2053–2060` do check an epoch; that protection is absent from this acceptance-to-owner route.

**Concrete source sequence / impact**

Retain coordinator A from `languageSettingsCoordinator`; call the existing `installLanguagePreferences(store:)` replacement seam with store B; then call A's `apply(.init(language: .japanese))` or accepted-resolution refresh. A still uses its old store/committed preference, but its closure requests Japanese on B's owner. B's coordinator and accepted store can remain English while B's presentation owner accepts/queues Japanese. Teardown/epoch checks on A's old owner do not help because A bypasses that owner and targets the new one.

This finding is bounded to the existing reinstall/namespace-replacement lifecycle seam. Ordinary production startup currently calls installation once; no user-facing profile-switch feature or spontaneous cross-profile write is alleged.

**Likely root cause**

Scheduled presentation/readiness work has namespace invalidation, but accepted-preference dispatch is routed through a mutable composition-root property.

**Recommended solution**

Bind the coordinator request route to its installation epoch/original owner and reject it after replacement. If obsolete coordinators must also reject persistence, add an explicit invalidation contract before saving rather than only dropping presentation. Main should determine that boundary without changing accepted scalar durability semantics.

**Affected scope / regression risks**

Language installation/teardown and acceptance callback lifecycle. Preserve valid Apply/reopen for the current coordinator, equal Follow System resolution, latest-wins coalescing, and accepted preferences on teardown. Add a focused retained-old-coordinator replacement test verifying that B's accepted/displayed/pending state and store stay unchanged after A's late request. Current startup should continue installing the resolved snapshot before mounted UI is shown.

**Confidence:** High for the source sequence; production reachability is limited as described. No runtime reproduction is claimed.

## Bounded source observations — no additional finding established

| Area | Observed current source | Remaining evidence boundary |
| --- | --- | --- |
| Startup/profile guard | Profile validation precedes language installation (`AppDelegate:186–195`); failed validation returns before normal startup. Unresolved requested isolation uses an unavailable language store (`:2009–2015`). Candidate suites have the separate hashed `.language` suffix (`UITestProfile:40,91–99`). | No fresh-process persistence or candidate launch performed. Pending consumer groups are excluded from selected-language coverage claims. |
| Accepted/displayed/queued state | Coordinator accepts only `.saved`; failed save does not request presentation (`LanguageSettingsCoordinator:20–46`). Owner keeps separate accepted/displayed/pending values and reads the latest pending language in the queued callback (`LanguagePresentationController:56–63,95–116`). | No integrated execution; F2 limits namespace lifecycle clearance. |
| Owner recheck/final release | Counted leases, readiness recheck, and teardown generation checks exist (`LanguagePresentationController:67–116`). Core callbacks are chained rather than replaced (`AppDelegate:782–785`). Language retry is added before the appearance-only early return (`:1982–1990`). | Actual notification/run-loop timing and overlap tests remain Main's next gate. |
| Core/pin | Core state callbacks trigger readiness scheduling before final pin release; next-turn readiness checks the released pin (`PagingSurface:554–571`, `AppDelegate:1603–1605,2076–2078`). Page-navigation notifications also feed the retry (`AppDelegate:2461,2491–2493`). | No GUI, frame benchmark, retained-host AX, or performance claim. Existing pager/AX copy remains a pending wave. |
| Held pointer/drag | `DragUISessionCoordinator:180–189,255,324–336` retains physical-pointer ownership after blank/fallback click candidacy is lost. Auxiliary up/cancel paths notify release (`:375–390,469–478,605–625`); Main receives the idle event (`AppDelegate:878–889`). | Source tracing only; no physical pointer acceptance claim. |
| Title/folder/restore/Quit | Readiness guards title/editor/context, folder transition/exit/collapsed presentation, restore, and Quit (`AppDelegate:2067–2078`). Title finish, folder completions, restore completion, and Quit phase callbacks schedule retries (`:1590–1605,1275–1276,1354–1355,2206–2211,55–58`; `WorkspaceQuitCoordinator:52–60`). | Exact overlap/final-release integration tests not run; pending translated copy is not a regression. |
| Recording/IME | Settings guard recording and actual first-responder marked text (`ActivationSettingsWindowController:158–161`); start/stop recording notifies readiness (`:638–662`). Main also checks launcher marked text. Text/editing notifications feed a deferred retry (`LanguageRuntimeObservers:29–34`). | No proof of all real IME unmark/completion timing from source alone. F1 prevents clearance of the reopen/recording preservation path. |
| Menu/modal/sheet | Menu tracking acquires/releases per-menu token stacks (`LanguageRuntimeObservers:18–27`). Current launcher/settings sheets and `NSApp.modalWindow` participate in readiness. Sheet-end notifications feed retry; settings fallback modal brackets its return; Quit uses its phase/fallback-running guard (`AppDelegate:2073–2075,2727–2736`; settings controller `:767–778`). | Current attached-sheet guards cover the inspected existing parents; no generalized future-modal guarantee or native lifecycle PASS. Future alert groups remain pending. |
| Observer teardown | Explicit teardown removes observations and menu leases (`LanguageRuntimeObservers:37–44`). Main tears down the owner before observer lease release (`AppDelegate:2114–2117`), preventing release-triggered presentation on that dead owner. Final app teardown gates subsequent retries (`:2831–2838`). | No deallocation/leak or process-lifecycle measurement performed. |
| Relabel consumers/chrome | `presentLanguage` uses one snapshot and calls relabel/update-title methods without catalog/layout/wallpaper entry points (`AppDelegate:2097–2109`). Search relabel touches placeholder/AX label only (`AppSearchFieldView:30–35`). Status menu updates existing action/tag identities (`StatusItemController:185–191,288–296`); startup menu/status construction uses the installed snapshot. | Resource/three-view details are delegated; no wrapping/VoiceOver/full translation completeness claims. |
| Language draft close | Already-configured language view is not reloaded on reopen; explicit hide resets it from accepted preferences. Its reload renders a saved queued state when appropriate (`AppDelegate:2039–2052`; settings controller `:275–282`; `LanguageSettingsView:66–82`). | F1 concerns other drafts and the surrounding factory; this local path does not close that finding. |

## Source identity and handoff

The primary finding-bearing files were reread at the end; their hashes matched the earlier in-review fingerprint read. These identify the inspected source, not a executable/resource candidate or test PASS. Later Main repairs require a new source check.

```text
ea31cb3e9f32d23ebe9f092cc8815e8dccbea2a0e6c4273ea5242c2a7d8e7d8a  Docs/INTERFACE_LANGUAGE_SPEC.md
60b8492619a2d7633e6699b9505b8fdfd0ab783dd44e882c7fbf7d41e5282840  Sources/PagingPrototypeApp/AppDelegate.swift
f29c102085febf0200c04035391a6f1c89516fcf896727f0b8905fdf333881b4  Sources/PagingPrototypeApp/LanguageSettingsCoordinator.swift
a89d2cf665c1a9f8b6d155fe3e90c94892f7d45c2219feda8bb9694e89a50080  Sources/PagingPrototypeApp/LanguagePresentationController.swift
c4b71b0bd6a748c369a5bee350854305f1b6b2763c2e7d7e7d78962a16b1d0b1  Sources/PagingPrototypeApp/LanguageRuntimeObservers.swift
99c80ae4904ec1c515b405ccd10df4f816b25709543ac14e7e61855b63ee801e  Sources/PagingPrototypeApp/ActivationSettingsCoordinator.swift
0ef91435472269473899a79ac0f1bcd2aacefeebc584e9f24e499371a6d55f00  Sources/PagingPrototypeApp/ActivationSettingsWindowController.swift
07b16a69b91ba718348bba220c65adc1c4b44eef1890b1d808b76382129230b7  Sources/PagingPrototypeApp/AppSearchFieldView.swift
e957f5a6f4bab6dae01d8bd0341e04ff13a76880d297112341767d6ce50fb0a2  Sources/PagingPrototypeApp/StatusItemController.swift
b0a4afcda45e90d3f0975866c035d7deed8d3885001c3624b86ae2f5f5ddc193  Sources/AppGridUI/DragUI/DragUISessionCoordinator.swift
```

Next owner action: Main repairs F1/F2, adds the planned real runtime-integration tests, and performs its authorized compile/focused/full gates. The absence of those next-wave tests at this review point is not itself a finding. Only this Markdown report was changed by this reviewer. No implementation edit or memory update was made.

## Repair rereview — 2026-10-14, current source

This dated section supersedes the original F1/F2 disposition without rewriting the historical findings or fingerprints. Scope remains SOURCE only, and only this report is appended. No Swift/build/test/UI/app/process/commit/install action occurred. Main's planned integration tests are not treated as missing-feature regressions.

**Current disposition: F1 and F2 are CLOSED AT SOURCE for their original triggers. One bounded replacement-recovery finding (F3) remains; overall runtime-lifecycle source verdict remains FAIL for that seam. No full-feature or runtime PASS is granted.**

### F1 disposition — original ordinary production reopen/fronting path repaired

- `ActivationSettingsCoordinator.swift:71–104`: real `showSettings()` calls the non-presenting `prepareSettingsForPresentation()` seam. Once this coordinator holds its first controller, preservation mode passes `preserveExistingDraft: true` and skips `configureAdditionalSettings`; only accepted-interface-language refresh runs.
- `AppDelegate.swift:1808–1817`: production explicitly enables that mode and routes refresh to the current accepted language coordinator. Initial preparation still configures all sections. The default standalone mode remains false, preserving its intentionally existing reload behavior.
- `ActivationSettingsWindowController.swift:199–205`: the existing singleton skips activation reload in preservation mode. Callback/provider rebinding and relabeling do not invoke activation draft synchronization or recording stop.
- Consequently, the original repeated production-open call no longer invokes the Appearance/Management/Sources reload chain or the activation `reload(draft:)` recording stop. Other drafts, alias content, source operations, and selected controls are retained along that path. The language-only close/discard hook remains separate (`:277–283`).

This closes F1 at source for ordinary repeated open/fronting and hide/reopen under the same configured language owner. Real mounted-control preservation, recording, IME, and notifications still require Main's next integration gate. Preservation after owner replacement has the separate F3 boundary below.

### F2 disposition — obsolete acceptance/store route repaired

- `LanguageSettingsCoordinator.swift:9,22–24,47–53`: invalidated coordinators return `.unavailable` before any fresh store load/save and suppress accepted-resolution refresh. Invalidation retains their already committed values.
- `AppDelegate.swift:2120–2123`: teardown increments the language epoch and invalidates the old coordinator before tearing down presentation and observers.
- `AppDelegate.swift:2020–2023`: the coordinator's presentation route checks the captured installation epoch. A retained old coordinator can no longer forward into the replacement owner through the original sequence.
- `AppDelegate.swift:2055–2066,2094–2098`: discard/readiness callbacks and the scheduled retry check their epoch. The original old-coordinator save/refresh sequence is therefore blocked at source without changing accepted preference durability.

This closes F2 at source. The replacement seam's new settings-binding recovery behavior is independently reviewed below; closure of old requests does not establish recovery of the current UI.

### F3 — [P2] Reinstalling language after settings initialization leaves the retained settings window unbound on its next production reopen

**Evidence / lines**

- `AppDelegate.swift:2011,2126–2131`: reinstall calls language teardown, which clears settings readiness/discard/apply/state-provider bindings and sets `configuredLanguageSettingsController = nil`.
- `ActivationSettingsCoordinator.swift:76,101–103`: its strong `windowController` remains present, so subsequent production preparation takes the preserve-drafts branch and skips the entire additional-settings configuration hook.
- `AppDelegate.swift:1810–1817`: that branch only calls `languageSettingsCoordinator.refreshAcceptedPresentation()`. The only production `configureLanguageSettings(controller)` call is in the skipped additional-settings hook.
- `AppDelegate.swift:2045–2069`: language configuration is the path that reinstalls view callbacks, the state provider, the configured-controller pointer, and readiness/discard hooks.
- `AppDelegate.swift:2079`: settings recording/IME/source/sheet ownership is consulted through that configured-controller pointer, which remains nil after the above sequence.
- `LanguageSettingsView.swift:124–127,159–163`: an Apply without its callback reports unavailable, and a missing presentation-state provider cannot report the owner's actual applied/queued state.

**Concrete source sequence / impact**

Prepare Settings once through the production preservation mode; replace the language installation using the existing `installLanguagePreferences(store:)` seam; then prepare/show the same settings coordinator again. F2 correctly invalidates the old coordinator, but the retained window's Language Apply/state/discard/readiness callbacks remain cleared. It cannot apply through the new coordinator, close cannot execute its accepted-language draft discard, and the new owner's readiness omits this settings window's ownership. Factory relabeling alone does not restore those bindings. The new ordinary-reopen optimization removed the former reconfiguration route that would have recovered them.

Reachability is explicitly bounded: current ordinary production startup installs language once. This is a concrete defect in the existing replacement lifecycle seam, not an allegation of a user-facing profile switch or ordinary startup failure. Tests can exercise the seam without presenting an app; none were run here.

**Likely root cause**

“Controller already created” now skips both destructive draft population and necessary current-language-owner binding recovery. Language teardown invalidates the second, while the settings coordinator retains the first.

**Recommended solution**

Main should separate language-only binding recovery from the three other section configurators and activation draft reload. On replacement, ensure the retained settings window is associated with the current language owner before refresh/readiness evaluation, restoring only the necessary callbacks/status/accepted language draft lifecycle. Preserve all other settings drafts. Keep ordinary reopen resolution non-destructive; do not restore unconditional additional-section reloads to close F3. If post-initialization replacement is intentionally unsupported, enforce/document that boundary at the replacement seam rather than retaining a silently detached window.

**Affected scope / regression risks**

Language installation/teardown, settings preparation, and current-owner configuration. Recheck F1 preservation and F2 stale rejection while testing the retained window across replacement: current Apply and close work, accepted/displayed/pending status agrees, and current recording/marked-text/source/sheet ownership still defers presentation until release. Do not reconstruct the singleton or reset Appearance/Management/Sources drafts as a recovery shortcut.

**Confidence:** High for the explicit source sequence; production reachability is limited as stated. No GUI or runtime result is claimed.

### Rereview source fingerprints

```text
eeca29b9ae5a507ee7554fa5f39cb2ff3dc30ac3b1c32ce20dd07ea7baa61cb5  Sources/PagingPrototypeApp/AppDelegate.swift
a3035950215173a41ee87fd667644414c3329875939d868d36d828e8c8093870  Sources/PagingPrototypeApp/ActivationSettingsCoordinator.swift
fe8782efcecef41ef37b542a7450eff4546b0a8ba99c05bef61f3a41dc15f742  Sources/PagingPrototypeApp/ActivationSettingsWindowController.swift
f19e47bb6fb46fe634b70927356e0bd477a86682b01422226f45bf9a4e9ed8de  Sources/PagingPrototypeApp/LanguageSettingsCoordinator.swift
a89d2cf665c1a9f8b6d155fe3e90c94892f7d45c2219feda8bb9694e89a50080  Sources/PagingPrototypeApp/LanguagePresentationController.swift
c4b71b0bd6a748c369a5bee350854305f1b6b2763c2e7d7e7d78962a16b1d0b1  Sources/PagingPrototypeApp/LanguageRuntimeObservers.swift
```

Main owns the F3 repair/boundary decision and the planned integration tests. Existing deferred consumer/resource/GUI/restart/physical/performance gates remain unchanged. This rereview changes only this report.

## Integration-test source rereview — 2026-10-14

Reviewed the current `Tests/PagingUITests/LanguageRuntimeIntegrationTests.swift` (13 test methods), its used `TestSupport.swift` helpers, and current F1/F2 implementation/call sites. No test or Swift command was executed. User reports r3 is running; no run output was inspected and no result/PASS is inferred. Only this report is appended.

**Disposition: F1/F2 remain CLOSED AT SOURCE; F3 remains OPEN with the same bounded replacement-seam FAIL. No new independent implementation/test defect was established in this focused read. The added test source improves bounded coverage but does not supersede F3 or certify a successful run.**

### Current repair checks

- F1's current production wiring still sets preservation mode (`AppDelegate.swift:1809`); repeated preparation skips activation reload and the three additional section reloads (`ActivationSettingsCoordinator.swift:75–104`, `ActivationSettingsWindowController.swift:199–205`). `showSettings()` uses this preparation seam (`ActivationSettingsCoordinator.swift:71`).
- F2's invalidation still precedes owner/observer teardown (`AppDelegate.swift:2120–2123`); inactive Apply exits before load/save and inactive refresh is suppressed (`LanguageSettingsCoordinator.swift:22–24,47–53`). The coordinator route and retained discard/readiness/retry callbacks retain the epoch checks (`AppDelegate.swift:2020–2023,2055–2066,2094–2098`).
- The F3 sequence is unchanged: language reinstall clears settings bindings; repeated production preparation only invokes `refreshAcceptedInterfaceLanguage`, which does not call `configureLanguageSettings` (`AppDelegate.swift:1810–1817,2126–2131`; `ActivationSettingsCoordinator.swift:102–103`). The current source fingerprints for these repair files match the preceding rereview.

### What the added test source covers, and its limits

All line numbers below refer to `LanguageRuntimeIntegrationTests.swift` unless another file is named. These describe executable assertions present in source, not executed results.

| Test(s) / lines | Concrete assertions and boundary |
| --- | --- |
| Fixture and actual tab/Apply, `:23–51,71–88` | Constructs a real settings controller with the owner's snapshot, calls Main's `configureLanguageSettings`, clicks the actual language Apply button, and checks persisted acceptance precedes the deferred snapshot update and all three view snapshots. The fixture manually attaches a surface and idle callback; it does not launch the production AppDelegate startup/activation/catalog graph or order windows. |
| Core/pin/latest-wins/frame stack, `:90–104` | Drives real `PagingSurface.handleScrollInput` helpers, keeps the tracked pin stable, applies two choices, and checks zero language-presentation applications before the subsequent main-turn drain, then one latest presentation. Helpers disable the frame driver and manually call `advanceFrame` (`TestSupport.swift:14–25,33–51,71–76`). This is a useful synchronous presentation counter check; it is not a transitive resource-lookup/format counter, retained-host AX test, frame benchmark, or physical gesture result. |
| Counted menu final release, `:106–118` | Posts two begin notifications for the same real `NSMenu` object to the injected center, checks one end remains blocked, and checks final end permits one presentation. This exercises production observer handlers and counted leases with synthetic notification delivery; it does not run native menu tracking or verify real AppKit begin/end ordering. |
| Source busy final release, `:120–136` | Uses the actual view's asynchronous admission operation and ownership callback, suspends it with a continuation, verifies a queued language remains displayed in English, then resumes it and asserts release/relabel/status rendering without another input. Admission is a fake result, not filesystem/source-panel interaction. |
| Native marked-text guard/retry, `:138–154` | Mounts an actual `NSTextView`, makes it first responder, marks/unmarks text, explicitly posts a text-change notification, and asserts blocking then relabel with preserved string. This covers the responder guard and retry route. It does not exercise a system input method, an actual NSTextField shared field editor, automatic unmark notification delivery, or editor selection preservation. |
| Replacement/stale coordinator/discard, `:156–173` | Retains old coordinator/discard closure, installs another store, verifies old Apply refuses, both stores have zero writes, no pending replacement request appears, and old discard cannot overwrite the new language draft. This directly targets F2. **Line 162 manually calls `configureLanguageSettings(f.controller)` after replacement; that is the recovery missing from F3's production preparation path. Therefore this test neither closes nor reproduces F3.** |
| Teardown, `:175–185` | Checks queued relabel is dropped, accepted store contents survive, state becomes unavailable, and apply count stays zero after a post-teardown menu notification. These assert inert post-teardown behavior; they cannot distinguish removal of observer registrations from callbacks that merely no-op on a dead owner. Registration removal is explicit in the reviewed observer source, not measured by this test. |
| Unresolved profile guard, `:187–196` | Exercises the real unresolved-isolation installation branch, unavailable store/apply, and supported initial system resolution. It does not validate fresh-process candidate/production persistent-suite isolation or payload files. |
| Preparation/all-other-drafts, `:198–221` | Uses the actual preparation/factory path twice, asserts controller identity and one configuration/one accepted-refresh invocation, and preserves activation shortcut draft, icon-size draft, alias text, and source automatic-refresh draft. `.controlCommandSpace` at line 207 exists in `ShortcutRecording.swift:112`; the corrected fixture symbol matches current source. Additional-configuration and refresh closures are counters, not Main's real composition closures. No active shortcut recording, source picker, selected tab/root/record, IME, hide/reopen, or replacement recovery is driven by this test. Those coverage limits are not separate findings. |
| Language-only close, `:223–232` | Calls the actual hide/close behavior and checks language draft resets to accepted English, an unrelated alias draft survives, and no language save occurs. It does not subsequently reopen via the production settings coordinator, or exercise saved/queued language while closing. |
| All-language constructor/search/menu, `:62–69,234–260` | Constructor checks the Sources placeholder before population in all supported languages. Search checks unchanged query/action plus translated placeholder/AX. Menu checks per-language show/quit titles and Quit target on newly built menus. The menu test creates a new menu each iteration, so it does not establish retained installed-menu identity across relabel. These are consumer construction/seam checks, not all shipping controls or a full startup-selected-snapshot matrix. |

### Remaining owner action / acceptance boundary

Main should address or explicitly enforce F3's replacement boundary and add an assertion that exercises replacement followed by `prepareSettingsForPresentation()` using the production language-only recovery route, **without manually inserting `configureLanguageSettings` in the test**. Assert restored current Apply/state/discard/readiness bindings while preserving the other drafts and rejecting old callbacks. This is the same open source finding, not a new missing-test failure.

The added 13 tests remain unexecuted by this reviewer. Recording, real sheet/modal overlap, title/folder/restore/Quit release timing, default-center AppKit notifications, all-group translations, resource/frame instrumentation, fresh-process persistence, exact-candidate GUI/VoiceOver, and physical/performance acceptance remain separate gates at their existing scopes. Deferred feature groups are not reclassified as regressions.

```text
bc93fa51f8c287cd2482fddb70fdbe3b41678f52494d37f9a5acee087d54008e  Tests/PagingUITests/LanguageRuntimeIntegrationTests.swift
eeca29b9ae5a507ee7554fa5f39cb2ff3dc30ac3b1c32ce20dd07ea7baa61cb5  Sources/PagingPrototypeApp/AppDelegate.swift
a3035950215173a41ee87fd667644414c3329875939d868d36d828e8c8093870  Sources/PagingPrototypeApp/ActivationSettingsCoordinator.swift
fe8782efcecef41ef37b542a7450eff4546b0a8ba99c05bef61f3a41dc15f742  Sources/PagingPrototypeApp/ActivationSettingsWindowController.swift
f19e47bb6fb46fe634b70927356e0bd477a86682b01422226f45bf9a4e9ed8de  Sources/PagingPrototypeApp/LanguageSettingsCoordinator.swift
```

No implementation or test file was edited. Main retains repair/test/run ownership. Historical verdicts above are preserved; this section is the latest bounded disposition.

## Final requested source rereview — 2026-10-14, two added runtime tests

Reviewed the two additions at `LanguageRuntimeIntegrationTests.swift:261–335`, their current production dependencies, and the still-current F1/F2/F3 routes. The file now contains **15 test methods**. Only this report is appended; no Swift/build/test/UI/app/process operation was performed.

Main reports R3 broad **106 tests / 0 failures**, including the preceding 13 runtime and 17 consumer tests. This is attributed Main-provided execution evidence; this reviewer did not inspect its log or certify its fingerprint. The two new tests were added afterward. R4 compile is reported in progress, with **no result inferred**. R3's earlier result is not evidence that the two additions compile or pass.

**Latest bounded verdict: FAIL. F1/F2 remain CLOSED AT SOURCE; F3 remains OPEN. The two new test fixtures contain F4/F5 below. No new product-path regression beyond the already reported F3 was established.**

### F4 — [P1] New held-pointer test writes a private production setter

**Evidence:** `Tests/PagingUITests/LanguageRuntimeIntegrationTests.swift:268` assigns `f.host.dragCoordinator = nil` during cleanup. `Sources/PagingPrototypeApp/AppDelegate.swift:130` still declares `private(set) var dragCoordinator`. The setter is private to the production declaration/file, while this test is in a different file/module. `@testable import` permits internal access; it does not grant access to this private setter.

**Impact / likely root cause:** The added test contains a source-level access-control violation that blocks compilation of the test target. Fixture cleanup tried to reset ownership through a property whose public-to-tests getter does not expose its setter. No compiler output or executed failure is claimed here.

**Recommended solution:** Remove the unnecessary direct assignment and retain explicit `dragCoordinator?.teardown()` plus normal fixture cleanup, or use an already appropriate owner cleanup seam. Do not widen production setter access merely to let this fixture clear the property.

**Affected scope / regression risks:** New test cleanup only. Keep teardown idempotent and preserve assembly/surface cleanup ordering and production ownership encapsulation.

**Confidence:** High from the current declaration and assignment.

### F5 — [P2] New recording test never enables the shortcut required by the real Record action

**Evidence:** `LanguageRuntimeIntegrationTests.swift:308–314` constructs the coordinator with default `InMemoryActivationPreferencesStore()` and prepares its controls; `:322–324` finds the Record button, performs a click, and expects recording to be active without first enabling the shortcut. `InMemoryActivationPreferencesStore` defaults to `ActivationPreferences()` (`ActivationPreferences.swift:87–90`), whose `ActivationSettings` defaults `globalShortcutEnabled = false` (`ActivationSettings.swift:32–37`). Controller synchronization leaves the checkbox off and Record disabled (`ActivationSettingsWindowController.swift:589–593`). Independently of button delivery, the real action explicitly refuses to start while the checkbox is off (`:394–401`).

**Impact / likely root cause:** The fixture omits the necessary enabled-shortcut precondition. On the current source path, it cannot reach the intended recording-owned queued state; the assertions at test lines 324/328 therefore do not establish the claimed lifecycle. This is a new test setup problem, not a failure of the F1 preservation fix or the product's intentional shortcut-Off default.

**Recommended solution:** Seed this test's in-memory activation preferences with a valid enabled shortcut, or use the real enable-control action before clicking Record. Assert the button/control is enabled and then enter recording through `performClick`. Preserve the product default; do not bypass the action's guard or call the private recording starter.

**Affected scope / regression risks:** Recording fixture and its reentry/stop assertions. Retain the production preparation path, real button action, active recording across reentry, saved/queued language while recording, and actual hide/stop final-release check.

**Confidence:** High. The default and the action's guard are explicit source facts; no runtime result is claimed.

### Added coverage intent, once fixtures are repaired

- Held-pointer test (`:261–303`) constructs a real catalog assembly/renderer, commits 105 synthetic records, obtains a rendered cell, installs Main's folder/drag wiring, and invokes real `pointerDown` followed by `.escape` cancellation. Assertions check active ownership blocks Japanese presentation and cancellation releases it; icon pipeline request count, cell binding token, served revision, and page count remain unchanged. It uses a synthetic catalog and invokes coordinator methods directly in an unordered window; it is not physical mouse delivery or drag/reorder acceptance. The release exercised is explicit cancel, not pointerUp. The icon request counter is meaningful for this fixture; unchanged revision/page/token are structural catalog/render checks, **not a catalog query/rescan counter, localization-resource counter, layout-write counter, or performance measurement**.
- Recording test (`:305–335`) now connects a real settings preparation coordinator to Main's language configuration and accepted refresh rather than using refresh/configuration counters alone. Its intended flow is Record button → language Apply → repeated preparation → still recording/English → actual `hideSettings()` stop → Japanese on deferred release. This is useful additional F1/owner coverage after F5 is corrected. It neither feeds a keyboard event into the recording monitor nor certifies physical keyboard/IME/visible GUI behavior.

### Prior findings and final handoff

F1's ordinary production reentry path still skips activation and three-view draft reloads, and F2 still invalidates obsolete coordinators and checks epochs. Their current source identities match the preceding repair review. F3 remains unchanged: the preserve-drafts branch refreshes accepted language without restoring bindings cleared by reinstall (`ActivationSettingsCoordinator.swift:102–103`; `AppDelegate.swift:1810–1817,2126–2131`). The existing replacement test still manually rebinds at `LanguageRuntimeIntegrationTests.swift:162`; neither new test exercises that missing production recovery route.

Main owns F4/F5 fixture repairs, the F3 replacement-boundary decision/repair, and the current compile/test run. The reviewer grants no new test execution PASS, full-language PASS, GUI/VoiceOver/restart acceptance, or performance claim. Pending translated consumer groups remain pending and are not findings.

```text
083604eae4891f347ae52c81c20a3092db421e31330171a486e60ceae4c9da05  Tests/PagingUITests/LanguageRuntimeIntegrationTests.swift
eeca29b9ae5a507ee7554fa5f39cb2ff3dc30ac3b1c32ce20dd07ea7baa61cb5  Sources/PagingPrototypeApp/AppDelegate.swift
a3035950215173a41ee87fd667644414c3329875939d868d36d828e8c8093870  Sources/PagingPrototypeApp/ActivationSettingsCoordinator.swift
fe8782efcecef41ef37b542a7450eff4546b0a8ba99c05bef61f3a41dc15f742  Sources/PagingPrototypeApp/ActivationSettingsWindowController.swift
f19e47bb6fb46fe634b70927356e0bd477a86682b01422226f45bf9a4e9ed8de  Sources/PagingPrototypeApp/LanguageSettingsCoordinator.swift
```

This is the latest dated disposition; historical reports remain intact. Only this report was changed.

### Same-review source change detected at final fingerprint check

The test file changed while Main's compile/repair work was in progress. A fresh read of `LanguageRuntimeIntegrationTests.swift:261–335` at SHA-256 `b3b6f035a5b8f65e8808ae36922b2cdbe5b3ea3eae280d80e1efcceebb0ef650` shows line 268 now only calls `f.host.dragCoordinator?.teardown()`; the private-setter assignment has been removed. **F4 is CLOSED AT SOURCE on this newer snapshot.** The production AppDelegate fingerprint is unchanged.

The recording fixture at lines 308–324 still uses default shortcut-Off preferences and does not enable the checkbox before the guarded Record action. **F5 remains OPEN**, as does F3's replacement-recovery seam. Latest disposition therefore is **bounded FAIL: F1/F2/F4 closed at source; F3/F5 open**. No R4 compile/test result was observed or inferred. This correction supersedes the immediate earlier F4 disposition; it does not erase the earlier source evidence.

## F3/F5 repair and 16-test source rereview — 2026-10-14

**Latest verdict: BOUNDED SOURCE CLEAR. F1–F5 are CLOSED AT SOURCE for their reported triggers. No additional concrete finding was established in this rereview.** This dated disposition supersedes the preceding bounded FAIL; historical findings and fingerprints remain intact. It is not a compiled/tested/full-feature PASS.

Reread the current 16 runtime-test methods and the current repair wiring. Main reports R5 had three failures in the recording fixture and r6 is running. Those are attributed Main-provided status, not independently inspected logs. No r6 result is inferred. Reviewer ran no Swift/build/test/UI/app/process command and edited only this report.

### F3 — closed: production reopen now restores only current language bindings

- `ActivationSettingsCoordinator.swift:34–35` adds a read-only `retainedSettingsController` getter over the already held controller. There is no setter or new window ownership.
- `AppDelegate.swift:1809–1819` keeps draft preservation enabled. The production accepted-language refresh closure weakly captures both Main and the settings coordinator, obtains its retained controller, and calls **only** `configureLanguageSettings(controller)` on reentry. The three additional view configurators remain confined to the initial configuration branch.
- `ActivationSettingsCoordinator.swift:76–105` continues to skip activation reload and the initial additional-settings hook on reentry; the new refresh route therefore restores language bindings without restoring the old destructive three-view reload chain.
- `AppDelegate.swift:2044–2071` reattaches the configured-controller pointer, Apply, presentation-state, discard, recording/source/readiness callbacks and accepted-resolution refresh. For an already bound owner it does not reload the language draft; after namespace teardown has cleared the pointer it loads the new namespace's accepted language and load state. Other section drafts are not reloaded by this method.
- Teardown still invalidates old coordinators and clears old bindings (`AppDelegate.swift:2121–2133`); the coordinator dispatch/discard/readiness routes remain epoch-checked. Restoration uses the new owner while F2's rejection of retained old requests remains intact.

The original prepare → reinstall → prepare detached-window sequence now reaches the language binding recovery path. This closes F3 at source without widening setter access or rebuilding the singleton. Actual overlap/notification timing is still a runtime gate.

### F5 — closed: recording fixture establishes the real enabled precondition

- `LanguageRuntimeIntegrationTests.swift:322–332` locates the actual shortcut-enable checkbox, invokes `performClick`, asserts `draft.globalShortcutEnabled`, asserts the Record button is enabled, and only then clicks Record and asserts recording.
- Production checkbox construction still targets `controlChanged` (`ActivationSettingsWindowController.swift:724–728`); that action updates the draft and Record enabled state (`:351–359`). The Record action's shortcut-enable guard is unchanged (`:394–401`). Product defaults and production guard were not weakened.
- The test still drives pending-language Apply, preparation reentry with recording retained, then actual `hideSettings()`/stop before deferred Japanese presentation (`LanguageRuntimeIntegrationTests.swift:333–342`). This corrects the F5 fixture precondition while continuing to cover the F1 recording-preservation route.

F4's illegal setter assignment remains removed (`LanguageRuntimeIntegrationTests.swift:267–269`), and `AppDelegate.dragCoordinator` retains its private setter. F1 ordinary draft preservation and F2 obsolete-coordinator invalidation remain source-closed.

### Current 16-test source coverage

The first 13 methods at test lines 62–260 remain as previously bounded: constructor/tab Apply, Core/pin/latest-wins, counted synthesized menu notifications, actual source busy release, native marked-text plus explicitly posted retry, old coordinator/discard rejection, inert teardown, unresolved profile, repeated preparation draft preservation, language-only close, search preservation, and per-language menu construction. Their earlier execution/GUI/performance limits are unchanged; no new source issue was found on reread.

- Held-grid-pointer test (`:261–303`) still uses a rendered synthetic cell with Main's folder/drag wiring, blocks relabel during coordinator pointer ownership, and releases through explicit cancel. Its unchanged icon-request/token/revision/page assertions remain fixture-level structural checks, not a query/resource/performance counter or physical mouse-delivery gate.
- Corrected recording test (`:305–343`) now reaches the real enable/Record action chain before testing reentry and stop. It still uses an unordered native window and does not feed real keyboard events into the monitor or claim physical input acceptance. Its accepted-refresh closure calls the accepted coordinator directly under the same owner; the separate replacement test below covers the new recovery wiring.
- New replacement-reentry test (`:345–372`) mirrors the inspected production language-only refresh closure through the read-only retained-controller getter. It performs **prepare → reinstall → prepare → native language Apply**, asserts teardown clears Apply and reentry restores it, checks the new namespace's accepted draft and the retained unsaved alias, then asserts only the second store receives the Japanese write and Main displays Japanese after deferred turns. It no longer manually inserts an out-of-band `configureLanguageSettings` between reinstall and the preparation call. Production activation-service startup itself is not executed by this fixture; its callback wiring was independently inspected in source.

The new test closes the earlier F3 coverage bypass at source. It asserts Apply recovery and alias preservation; restoration of all readiness/discard callbacks is visible in the shared production configuration source, with real modal/IME/notification behavior still requiring its own runtime evidence.

### Evidence and handoff boundary

Primary repaired source/test hashes were stable across the in-review reads below. These identify current source only, not a successful r6 run or a packaged executable/resource candidate.

```text
6647c239959d19fe1177c03a2db91e1524480e08a01a62d22b3df5955bfe9491  Tests/PagingUITests/LanguageRuntimeIntegrationTests.swift
2406e89e7ae428db48d37dc18a1686c1289e3f30aabb49a506b8dff645e6212a  Sources/PagingPrototypeApp/AppDelegate.swift
8de915e91bc57fa68e2d890e166d84b3f6baf5b833be7c85c46b9010a1755a5e  Sources/PagingPrototypeApp/ActivationSettingsCoordinator.swift
fe8782efcecef41ef37b542a7450eff4546b0a8ba99c05bef61f3a41dc15f742  Sources/PagingPrototypeApp/ActivationSettingsWindowController.swift
f19e47bb6fb46fe634b70927356e0bd477a86682b01422226f45bf9a4e9ed8de  Sources/PagingPrototypeApp/LanguageSettingsCoordinator.swift
a89d2cf665c1a9f8b6d155fe3e90c94892f7d45c2219feda8bb9694e89a50080  Sources/PagingPrototypeApp/LanguagePresentationController.swift
c4b71b0bd6a748c369a5bee350854305f1b6b2763c2e7d7e7d78962a16b1d0b1  Sources/PagingPrototypeApp/LanguageRuntimeObservers.swift
```

Main owns completion and evidence for r6 and later compile/focused/full/resource/candidate gates. Activation/service/folder/pager/AX/action-alert groups remain explicitly pending at their approved scope and are not regressions. No physical GUI/VoiceOver/restart/IME or performance acceptance is claimed. Only this report was appended; no implementation/test edits or memory updates were made.
