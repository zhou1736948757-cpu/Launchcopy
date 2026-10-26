# App Library native owner — independent source review

Review date: 2026-10-15 (Asia/Tokyo). Snapshot check: 2026-10-14T17:14:48Z.

## Verdict and authority

**SourceFAIL for this bounded owner/integration review.** Two actionable P2 findings require Main repair and fresh independent review. No SourcePASS, native acceptance, parity, performance, compilation or test-execution claim is made.

Authority: the direct review assignment authorizes agents, waives the formal Chief workflow, limits concurrency to three including Main, and assigns this report as the sole writable file. No other agent was invoked or messaged. Main retains implementation, tests, serial Swift/build and runtime ownership.

This is an existing macOS Swift/AppKit launcher using one AppDelegate composition root, the shared AppCatalogAssembly/provider/icon pipeline, an optional same-window Library owner, a pure off-main projection and an independent preferences actor. Approved references are Docs/APP_LIBRARY_SPEC.md, its incorporated proposal and Workflow/stage-summaries/2026-10-15-app-library-native.md. The proposal's historical PROPOSED markers are not a new approval gate.

All shell commands used RTK. Inspection was limited to text/source, relevant tests, Git status/diff and source hashes. No Swift execution, build, test run, app control, process inspection/control, forbidden reference-product/evidence/assets content reads, production preferences access or implementation/test edits occurred. PagingCore/PagingUI were not opened or changed in this review. The large pre-existing dirty tree remains outside this report's ownership. The historical 2533-green foundation/source result is context supplied by the assignment/stage summary, not current native validation; its underlying evidence was not opened.

## Findings

### F1 — P2: Library folder sheet can cross a layout writer replacement

**Location:** Sources/PagingPrototypeApp/AppDelegate.swift:2376-2381. Related lifecycle: :2586-2590, :2605-2624; destination write: :1115-1118. Confidence: **high in the source path**, not runtime-reproduced.

The Library assignment sheet captures the expected layout and Library request, but not layoutRestoreGeneration or the originating layout store. Its completion checks owner.resolve(request, checkingReadiness: false); the second validation around applyFolderAssignment uses the same owner-only check. That validates Library generation, catalog identity/revision/URL, source invalidation and hidden state, but not the workspace writer epoch.

Concrete sequence: open the Library folder assignment sheet for an existing layout; install a replacement layout store while its completion is retained; let restoration finish with the same retained session layout; then deliver Save from the old sheet. installLayoutStore advances the writer epoch, while beginLayoutRestore returns after restoration when sessionLayout already exists (:2624). In that case it need not publish a new catalog/presentation or advance the Library action generation. The old request and expected layout can therefore still match. applyFolderAssignment admits them and commitWorkspaceLayout submits to the **replacement** store with the current epoch, although the user initiated that sheet under the old writer.

This is a missing protection on an established lifecycle seam, not a claim that ordinary startup replaces the writer. The existing grid assignment path explicitly captures writerEpoch (AppDelegate.swift:2710-2722), and Tests/PagingUITests/MenuMutationLifecycleTests.swift:226-260 already expresses the identical-layout writer-replacement regression contract. The Library path bypasses that origin guard.

Likely cause: reuse of current-layout/action validation without carrying the writer-origin admission check into the new asynchronous sheet path.

Recommended Main repair: capture the originating writer epoch/store at sheet admission and require it at completion and in the validation closure executed again after surface cancellation. Also confirm the active Library owner identity. Do not weaken catalog, layout or source checks. A repair must reject the old sheet without writing either store, while a fresh sheet can commit once to the replacement store.

Affected scope: Library folder organization callbacks and their regression tests. Regression risks: synchronous cancellation/idle publication, identical layouts across namespaces and old completions arriving after restore. No category/layout coupling or pager change is needed.

### F2 — P2: Failed category writes have no feedback in the active Library

**Location:** Sources/PagingPrototypeApp/AppLibraryOwnerController.swift:204-235, specifically :226-230. Related view: Sources/PagingPrototypeApp/AppLibraryView.swift:618-624. Confidence: **high in the source path**, not runtime-reproduced.

A category/Automatic request submits to the preferences coordinator (:126-129). On terminal failure, that coordinator correctly retains the persisted baseline and exposes latestSaveResult. However preferencesChanged only sends that result to the separate settings view, then requests a new projection. renderProjection supplies only snapshot/loading/empty/generation to the Library. The Library status chooses loading, unavailable, empty or no-results, and is hidden again for successful nonempty projection/details. No category-save failure reaches the current Library surface or AppDelegate's action feedback path.

Thus a rejected save restores the old category and usable controls without telling the user that their category edit was not saved. Library remains enabled and open, and its launcher settings gear is hidden; the failure is only discoverable by separately opening settings. This misses the approved error-state/accepted-write presentation requirement. It does **not** establish data loss or an optimistic false disk receipt: the baseline reconciliation itself is sound.

Likely cause: the new owner wires preferences error presentation only to Settings, leaving category action failures without an active-pane consumer.

Recommended Main repair: present a localized, accessible, neutral category-save failure in the active Library or via the existing shared feedback surface. Preserve the committed baseline, independent storage, retry ability and Quit protection. Ensure obsolete/hide/teardown callbacks cannot show a failure in a later mode/session. Use the existing typed Library failure text where appropriate.

Affected scope: owner feedback wiring and a narrow presentation seam if needed. Regression risks: late failure after hide/reopen, pending/latest generations, failure followed by successful retry, retained selection and details. Do not invoke layout mutations or a rescan to present the error.

## Source observations that did not produce a blocking finding

These are inspected source properties, not executed acceptance results.

| Boundary | Observation and limits |
| --- | --- |
| Startup/options/profile | AppDelegate.options is immutable/nonoptional (:22, :346-348). Profile resolution runs before preference installation (:383-395). installAppLibrary routes through AppLibraryStoreLocation; an unresolved requested profile returns nil, never production fallback. Injected stores are explicit test seams. |
| Default-off/directory-free | The owner allocates only the discoverability button while closed; its view and projection are created/opened on entry. AppLibraryFileStore.load reads without writing; openDirectory(create: false) returns nil at missing ancestors (:118-135). Library is not in configureUITestProfile's eager directory creation list. No production directory was examined. |
| Sole launcher/shared catalog | installAppLibrary adds a sibling view to the existing host and receives servedSnapshot/shared iconPipeline. It constructs no second catalog assembly/scanner/window or pager. Settings remains the existing settings window. No physical/window inspection was performed. |
| Immutable action/shared launch | AppLibraryActionRequest carries AppID, canonical URL, displayed revision and owner generation. Owner.resolve (:193-200) rechecks all four, snapshot membership, hidden state and source invalidation. AppLaunchController.handleApp (:140-168) shares revision, identity, URL, hidden/file and public launch validation without creating a cell/token. Existing grid/member adapters are not re-certified here. |
| Source changes/catalog commits | Root replacement invalidates Library targets before changing roots (AppDelegate.swift:2044-2047). replaceScanRoots discards pending catalog/folder/query results. Same-revision commits do not acknowledge the invalidation; only a newer served revision clears it. Library consumes the existing commit fanout (:1307), rather than replacing catalog callbacks with Library-only callbacks. Failed rescans need explicit error-state regression coverage; the owner otherwise remains fail-closed. |
| Independent category writes | onSetCategory derives from committed Library preferences and submits only that writer. No LayoutMutation/catalog scan/new CatalogRevision is requested by this path. Accepted receipts survive newer failed drafts in the coordinator (:62-75). |
| Input/mode/hide | Transition predicates reject restore, Quit, drag/title editing, busy surface state, attached sheets and launcher marked text. Library mode hides grid/search/keyboard/chrome and provides a mode-specific responder. Window.sendEvent (:3574-3585) bypasses the grid blank-click/manual delivery funnel in Library and leaves marked-text/sheet Escape to AppKit. Normal hide closes/reset/detaches the Library and clears pending return focus. Mounted event behavior remains unverified. |
| Grid return | Context retains raw grid query, committed page, selected entry identity and focus intent. Policy resolves a retained identity against latest composition/revision, otherwise clamps former page/slot to nearest valid content; empty clears selection. AppDelegate restores query through the existing search transaction and waits for committed target page before focusing (:2310-2337). Mid-return catalog changes, interrupted direct navigation and app-to-folder changes require integration regressions. |
| Quit protection | requiresQuitProtection covers pending saves and terminal unsuccessful results. requestWorkspaceQuit (:3205-3239) drains workspace first and Library even when workspace fails; it approves only if both outcomes are successful. Workspace failures take precedence for the combined prompt. Both drains retain ownership of timed-out operations; the decision coordinator gates old replies by generation/phase. Waiting is sequential, so the total bounded wait includes both owners. This was not timed or executed. |
| Default Cancel/localized Quit | Cancel has Return/defaultButtonCell; Quit Anyway has no key equivalent (:3270-3286). Typed English fallback and en/zh-Hans/ja Quit resources say “changes”, including Library writes. The legacy nil-strings alert initializer still says layout only (:3275-3276); production initializes languageStrings first, so this is a fallback maintenance note, not one of the two blocking findings. |
| Closed/lazy | catalogDidCommit, relabel and preferencesChanged only request a projection when isOpen. Closing invalidates projection publications and detaches the view. Closed mode starts no extra classification/icon work from these owner callbacks. This does not prove measured memory, latency or physical performance. |

## Test-source assessment and next regressions for Main

The three new Main files contain **15 test methods by static inspection**: eight owner tests, three pure return-policy tests and four launch/Quit/window-route tests. None was run by this reviewer. Owner fixtures use an unmounted NSView with canTransition/canExecuteAction forced true; they do not validate AppDelegate's real input/lifecycle wiring. The launch test name mentions hidden checks but its body tests stale revision, wrong URL, success and removed file, without setting a hidden preference.

1. **F1 regression:** retain a Library folder-sheet completion, replace the writer with identical layout, finish restore, deliver old Save; assert no layout change/enqueue on either store. Fresh current-sheet Save should enqueue once. Repeat with cancellation-triggered publication, hide/reopen, source replacement and teardown.
2. **F2 regression:** fail category save and Automatic reset while the Library is open. Assert persisted baseline and catalog revision/layout remain unchanged, the failure is visible/accessibility-readable in the current pane, retry succeeds, and late failure cannot leak across hide/reopen or teardown.
3. **Combined real AppDelegate Quit:** have both writes accepted. Exercise workspace failure + gated Library success, workspace success + Library failure, each timeout, and both failures. Assert the second drain is reached even when the first fails; no automatic approval; Cancel default; explicit Quit Anyway; retained late writer completion; old decision rejected after cancellation/store replacement/new attempt. Existing coordinator-only stale tests do not establish this new integration.
4. **Mounted return transaction:** nonempty query with selected AppID moved to another page; hidden/removed anchor nearest-slot fallback; latest catalog arriving before/during direct navigation; empty result; no-selection/search-focus case; folder membership change; navigation interrupted by pointer input/resize/resign/hide. Verify shown page, focus identity/current revision and subsequent Return action agree.
5. **Mounted lifecycle:** marked input, sheet/modal ownership, drag/title editing, restoration, pending category save and pending Quit must deny transition/actions without cancelling protected edits. Verify Escape priority, no grid blank-click, scroll-edge isolation, page dots/chrome and responder restoration after settings/Finder return.
6. **Startup/source/closed seams:** unresolved requested profile at AppDelegate installation, default-off no directory, repeated closed catalog/locale/management updates with zero extra projections/icons, existing refresh/search/watch consumers preserved, terminal failed root rescan remains nonactionable with accurate feedback. Add the missing non-cell hidden-app rejection assertion.

Main owns these repairs and their serial validation. Focused/full nonzero tests, Debug/Release and packaging/localization remain separate from real candidate GUI, accessibility, restart/durability and matched physical performance. No native-performance targets or full-parity status were evaluated here.

## Snapshot identity and handoff

The first ten inputs below were hashed twice near the end of inspection and matched. This binds the findings to the inspected source rather than the older foundation checkpoint; it is not an immutable full-repository/build bundle. AppLibraryView has one terminal fingerprint. Any material repair invalidates this verdict's source identity and needs re-review.

| Input (relative to repository root) | SHA-256 |
| --- | --- |
| Sources/PagingPrototypeApp/AppDelegate.swift | 663cbf21d9180bba7400b33cf376d698bdf4f9594d290bb727d47dcb6de3d54a |
| Sources/PagingPrototypeApp/AppLibraryOwnerController.swift | 705cce03ccc1e9deba2cc2053ffbfcfc95e6efb21b11285fd9a56826f2b37c25 |
| Sources/PagingPrototypeApp/AppLibraryActionRequest.swift | 380287fac819813f2051e8c0668724a370dab187d078c6f69e4fc538ca0bed0b |
| Sources/PagingPrototypeApp/AppLibraryGridReturnContext.swift | 59b00137889cf30161788e49c67d802c66b91d39d2b6b8d32538205649ab4d3c |
| Sources/PagingPrototypeApp/AppLaunchController.swift | 9a04a7e0ebb7fd376b8836d795e01889531d78878050d94b81390a866e0d82e9 |
| Sources/PagingPrototypeApp/AppSearchController.swift | a1fe5d4cea1eef493b45e258e4d57b5bb68ccff3ccbba23833052d13ad029649 |
| Sources/PagingPrototypeApp/AppLibraryPreferencesCoordinator.swift | 59e21fd854e06396ee39b8212710bc1339e1ca0c46c2276583e32bdee6cdb6d0 |
| Tests/PagingUITests/AppLibraryOwnerIntegrationTests.swift | 359b192e675281d26020892107efe4406112eed884cdb3f2883e665262f16e6a |
| Tests/PagingUITests/AppLibraryGridReturnPolicyTests.swift | 97b70d3184845856c26d3836d7c10e332fc87f4bb01a914daf60b2ee436f791b |
| Tests/PagingUITests/AppLibraryLaunchAndQuitTests.swift | 43b4dde14cff1751ac76f922a886b6492eee52a6f7e6ea9fcba2bf43562c8979 |
| Sources/PagingPrototypeApp/AppLibraryView.swift | eb11bae04649eec2c08dd835b1081e680e3971a7052ae23442f1debd96789168 |

Reviewer write set: **Workflow/results/APP_LIBRARY_NATIVE_OWNER_REVIEW.md only**. No implementation/test repair was attempted. Next executable action: Main addresses F1/F2, adds the targeted regressions, completes its isolated serial compile/tests and requests a new bounded source review. Historical foundation success cannot close this native stage.
