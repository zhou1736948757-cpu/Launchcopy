# App Library native owner — independent R2 source review

Date: 2026-10-15 (Asia/Tokyo). Terminal source fingerprint checkpoint: 2026-10-14T17:34:38Z.

## Verdict and scope

**SourceFAIL for the bounded R2 owner/lifecycle integration review:** the two R1 defects have corresponding source repairs, but one new P2 finding concerns category failure sheets competing with the pending Quit decision. No overall SourcePASS or native acceptance is issued.

This report supersedes neither the historical wording nor hashes in APP_LIBRARY_NATIVE_OWNER_REVIEW.md; R1 is preserved. Main owns all repairs, tests and runtime verification. The sole reviewer write is this R2 report. All shell commands used RTK. No Swift/build/tests, GUI/app/process operations, other agents, implementation/test edits, forbidden reference/evidence/assets content reads or production-data access occurred. The existing dirty tree was preserved. Core/PagingUI were not opened or changed.

The review uses the approved APP_LIBRARY_SPEC.md/proposal contracts already inspected in R1 and the fresh R2 sources, not the R1 predicates. The 440-input frozen manifest and focused r5 **139 tests / zero failures** are facts reported by Main in the review conversation, not independently executed or manifest-verified by this reviewer. Main reports full r2 running; no fullPASS is inferred. The older foundation result remains separate from native acceptance.

## R1 repair assessment

### R1 F1 — resolved at source level

Sources/PagingPrototypeApp/AppDelegate.swift:2371-2401 now requires an originating writer, captures writerEpoch and that writer's storeDirectory, and builds currentOrigin checking the active Library owner, current epoch, current writer directory and the immutable Library request. The same closure runs at sheet completion and as applyFolderAssignment.validateBinding. That latter seam calls it before mutation and again after surface.cancel() (:2824, :2834-2838).

The layoutStore property is private (:327). Text search finds its live replacement only in installLayoutStore (:2606-2610); that immediately calls beginLayoutRestore, which increments layoutRestoreGeneration (:2629). The other assignment sets nil at teardown (:3453). Thus identical directory/layout replacements still fail the epoch check; the directory comparison supplements the epoch rather than pretending to be object identity. LayoutStore is Sendable, not class-constrained (Sources/AppGridUI/LayoutStore/LayoutStore.swift:92-94), so avoiding AnyObject identity is consistent with the authoritative origin contract and supports value implementations.

Tests/PagingUITests/MenuMutationLifecycleTests.swift:269-309 exercises the actual Library callback wiring with a retained native sheet completion, same-directory/same-layout replacement, zero writes to both stores on old Save, unchanged layout, and one new-store write from a fresh sheet. It overrides action/transition admission for the fixture but retains the production origin/completion/mutation path. This is appropriate source coverage of F1; the reviewer did not run it. No F1 blocking residual was found.

### R1 F2 — feedback gap repaired; new Quit interaction below

Sources/PagingPrototypeApp/AppLibraryOwnerController.swift:25-27, :103, :160, :131-135, :212-224 now associate accepted category receipts with a Library session token independent of query/action generations. A terminal receipt clears pendingCategorySession before notification. Delivery requires the owner to remain active/open in that same session; close increments the session and teardown invalidates preferences callbacks. Query refresh therefore does not lose a receipt, and a later session does not inherit it.

The view receives categorySaveDidComplete before projection refresh. Sources/PagingPrototypeApp/AppLibraryView.swift:650-661 records the typed receipt and renders the localized failure text with an accessibility label. Details contain the label (:578-583); relabel updates it (:685-687); reset clears receipt/draft state (:213-216). This provides feedback even when the window's existing sheet prevents the additional alert. Draft/receipt handling preserves an unsubmitted or failed draft for retry and reconciles successful receipts to the committed category (:632-647). Protected/unavailable/recovery-required receipts disable category edits (:669-672). The coordinator still keeps the persisted baseline and unsuccessful Quit protection.

Main also wires the active-owner/current-window localized NSAlert through the shared modal completion gate (AppDelegate.swift:2274-2282, :2882-2900). Tests/PagingUITests/AppLibraryOwnerIntegrationTests.swift:188-220 asserts one active failure callback, old committed classification, requiresQuitProtection and no replay after close/new entry. Tests/PagingUITests/AppLibraryViewTests.swift:94-117 checks failure label, draft retention and successful receipt reconciliation. These are inspected source assertions; the owner test closes **after** the failure, so late receipt after hide/teardown and query-change-during-pending remain separate follow-ups.

## New finding

### R2 F1 — P2: Do not admit a category warning sheet while Quit owns the lifecycle

**Location:** Sources/PagingPrototypeApp/AppDelegate.swift:2274-2282. Related ordering: AppLibraryOwnerController.swift:215-220; AppLibraryPreferencesCoordinator.swift:61-76, :85-99; AppDelegate.swift:3214-3219, :3225-3259, :3264-3280. Confidence: **high for the conflicting presentation admissions; native presentation/order consequences unverified**.

The new category failure warning guard checks owner identity/open state, window visibility, no currently attached sheet and localized strings. It does not check workspaceQuit.phase/isPending or the existing libraryNonmodalLifecycleIsReady guard (:2293-2296).

Concrete source sequence:

1. Library is open and a category save is pending. The user requests Quit; the existing coordinator moves to draining while keeping the Library open. There need not yet be an attached sheet.
2. The save returns failure. The preferences coordinator decrements pendingCount, records the failed receipt/persisted baseline and synchronously calls onChange. The owner delivers the inline receipt and calls onCategorySaveFailure in the same Library session.
3. AppDelegate's new callback can pass all its guards and request the category warning sheet **during the pending Quit**.
4. The Quit drain observes the same failed receipt. Production chooseOnFailure then calls presentQuitSaveFailure, which requests a second sheet on the visible window without excluding the first one.

This is two independent modal presentations for one failed write while the protected Quit transaction is trying to present its default-Cancel/explicit-Quit-Anyway choice. An existing-sheet guard alone cannot arbitrate the first admission, because the Quit choice has not been presented when the category receipt arrives. Late failure following drain timeout can similarly request an unrelated warning during the awaiting-decision/approved lifecycle when no attached sheet is present. This report does not claim an AppKit exception, a particular sheet queue behavior, data loss or a measured delay; those require native execution. The source ownership conflict itself is present in the freshly frozen R2 implementation.

Likely cause: active-session freshness was added without checking the process Quit owner at alert admission. The receipt must remain session-based; changing it to query generation would reintroduce missing failure feedback.

Recommended Main repair: when Quit owns the lifecycle, retain the typed inline failure/baseline and let the existing Quit decision own the modal feedback. Admit the optional category warning only in an appropriate idle lifecycle, including teardown protection. Do not queue/replay that warning after the Quit attempt or across sessions. If other protected presentation states need deferral, use explicit same-session ownership and bounded admission; the inline label already supplies persistent feedback. Do not weaken requiresQuitProtection, cancel the accepted writer or remove the normal idle-session warning.

Affected scope: AppDelegate category-warning admission and a narrow integration regression. Regression risks: failure during draining, late completion after timeout, Cancel followed by a new Quit attempt, duplicate receipt delivery, and hide/teardown. No changes to store format, category/layout separation or pager physics are needed.

## Other R2 changes checked

- **Initial safe-area layout:** AppLibraryOwnerController.layout stores lastSearchFrame (:268-277), and enter reapplies it after mounting the new view (:137-139), including screen.safeAreaInsets.top. This is a fresh-source structural fix; screen geometry was not physically measured.
- **Corrupt store arriving after initial inspection:** both owner.recoverPreferences (:88-91) and AppDelegate.presentLibraryRecovery (:2351-2366) accept latestSaveResult == recoveryRequired as well as loadResult == corrupt. Recovery remains explicit, pending-count/lifecycle protected and default Cancel. The regular recovery confirmation path still rechecks the active owner.
- **Six settings tabs:** Tests/PagingUITests/LanguageRuntimeIntegrationTests.swift:74-75 expects all five original identifiers plus library. Tests/PagingUITests/AppearancePreferencesTests.swift:382-386 expects six and checks Library's view at index 5 plus prior language/sources/appearance views. These are updated assertions, not a new full-suite execution claim.
- **Baseline shared behavior:** the preferences coordinator and AppLibraryLaunchAndQuitTests fingerprints are unchanged from R1. Category writes still do not request layout mutation or scanner work; existing dual-drain logic is retained. The new alert integration makes the pending-save/Quit combination newly material rather than covered by Library-only success/failure tests.

## Next regressions and handoff to Main

1. Use a gated category writer and the actual AppDelegate callback wiring: start Quit while the save is pending, fail it, and assert no category warning is admitted during draining while the inline failure remains available and exactly one Quit decision is requested. Exercise late failure after timeout, default Cancel, explicit Quit Anyway and stale old decisions after a new attempt.
2. Keep the existing idle-session failure notification test, and add pending save + query/category projection changes; hide before receipt; teardown before receipt; close/reopen after late failure. Assert no session replay and no baseline/Quit protection regression.
3. Preserve the retained old Library sheet regression, and add origin invalidation triggered during cancellation before mutation; fresh current-origin write still exactly once. No AnyObject requirement is needed.
4. Follow R1's outstanding combined-drain, mounted return/responder, input-method/modal, failed-source-refresh, closed-lazy and native/performance gates. Focused r5 success does not establish these or full/native parity. Main completes serial full r2 and records its own execution outcome separately.

No implementation/test changes were made by the reviewer. Next action: Main resolves R2 F1 and supplies a fresh frozen source for the narrow re-review; source, tests, packaging and native gates remain separate.

## Source fingerprints

The following first nine inputs were hashed twice and matched near the end of source inspection. The language test has one terminal fingerprint. These are bounded source identities, not verification of the reported 440-file manifest. R1's fingerprint also matched, confirming this review did not rewrite it.

| Input | SHA-256 |
| --- | --- |
| Workflow/results/APP_LIBRARY_NATIVE_OWNER_REVIEW.md | 90d9247eb933cda585d8d44e8aeae3f06920fe9f63d58dd7a0c20fb51143646b |
| Sources/PagingPrototypeApp/AppDelegate.swift | 9b35d76413ea82ac45f2bb65360afa714a40846de3c6243888c5137488760554 |
| Sources/PagingPrototypeApp/AppLibraryOwnerController.swift | e99e9b851defd6cd05e90e36e40e79e4ebe4ec6c0e33e156955b98827940f7cd |
| Sources/PagingPrototypeApp/AppLibraryView.swift | 0b3baba5237d99e06a7ca81f6ba3b406d6f80ee9036f3cff106cd678855c3c34 |
| Sources/PagingPrototypeApp/AppLibraryPreferencesCoordinator.swift | 59e21fd854e06396ee39b8212710bc1339e1ca0c46c2276583e32bdee6cdb6d0 |
| Tests/PagingUITests/AppLibraryOwnerIntegrationTests.swift | f90bc34f64ff9459d6b8cf19c55a296fa68a27bec325e0e637128c1d351b6eb1 |
| Tests/PagingUITests/MenuMutationLifecycleTests.swift | e0b93b384100b7cb1d2fad90a54c322d9ea7e5149b73fa34305a7a47f96a3d58 |
| Tests/PagingUITests/AppLibraryViewTests.swift | bbfcea593253a145d1f62abcd8a3aa2f032a2d96a16ab772bedfc0f5d228440f |
| Tests/PagingUITests/AppLibraryLaunchAndQuitTests.swift | 43b4dde14cff1751ac76f922a886b6492eee52a6f7e6ea9fcba2bf43562c8979 |
| Tests/PagingUITests/LanguageRuntimeIntegrationTests.swift | f40017af4cc5880d95e0c0ccf608bcca73edd2c36bf5a2ef6dadc5af6758bfac |
