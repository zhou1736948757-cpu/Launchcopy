# App Library native owner — narrow R3 source review

Date: 2026-10-15 (Asia/Tokyo). Inspection checkpoint: 2026-10-14T17:43:27Z.

## Verdict

**Bounded SourcePASS for the R2 category-warning/Quit admission repair.** R2 F1 is resolved in the fresh R3 source. No new actionable finding was identified within this narrow guard/regression review. Confidence: high for source control flow; execution and native presentation remain unverified by this reviewer.

This does not certify the whole Library, full parity, native accessibility/responder/sheet behavior, restart durability or physical performance. R1 and R2 remain preserved historical reports. Their previous source findings are superseded only by the scoped repair assessments in R2 and this report.

The direct assignment restricts this review to fresh frozen source and a new report. The sole write is Workflow/results/APP_LIBRARY_NATIVE_OWNER_REVIEW_R3.md. All shell commands used RTK. No Swift/build/test execution, GUI/app/process operations, implementation/test edits, other agents, forbidden reference/evidence/assets reads or production-data access occurred. Core/PagingUI were not opened or changed; the existing dirty tree was preserved.

## Repair evidence

Sources/PagingPrototypeApp/AppDelegate.swift:2274-2283 now requires libraryNonmodalLifecycleIsReady before admitting the category-warning sheet. That predicate (:2294-2301) requires workspaceQuit.phase == idle, no teardown/restore/title/drag ownership and an available idle/cancelled surface, in addition to the callback's existing current-owner/open/visible-window/no-sheet/string checks.

WorkspaceQuitCoordinator.swift:19-24 sets draining synchronously before starting the asynchronous drain. Therefore a failed accepted category write completing during Quit cannot pass the new admission predicate. The exact idle comparison also denies late warning admission during awaitingDecision or approved; it is stronger than checking only isPending. The existing protected Quit choice remains the modal owner for this failed write.

The guard suppresses only the optional category warning. AppLibraryOwnerController.swift:215-220 still clears pendingCategorySession and delivers view.categorySaveDidComplete before calling onCategorySaveFailure. AppLibraryView.swift:650-661 still records the receipt and renders localized, accessibility-labelled failure text. A denied warning is not retained for later replay: the owner already consumed its pending session marker. Cancelling Quit therefore does not turn the suppressed failure into a new deferred warning. Same-session draft/retry behavior and the persisted baseline are unchanged.

AppLibraryPreferencesCoordinator.swift is fingerprint-identical to R2. Its pending/failed requiresQuitProtection, persisted receipt bookkeeping and failed drain result are retained. AppDelegate.requestWorkspaceQuit (:3226-3260) still drains both accepted owners, returns failure to the explicit-choice path, and never turns suppression of the category warning into save success. The R2 folder-origin guard also remains present (:2372-2402); it was inspected for retention, not re-audited as a separate R3 objective.

## New regression source assessment

Tests/PagingUITests/AppLibraryLaunchAndQuitTests.swift:138-185 adds testFailedLibraryWriteDuringQuitDoesNotPresentCompetingCategoryWarning. It assembles the real AppDelegate Library failure callback, shared provider and gated preferences writer; it submits an accepted category change while Library is open, requests Quit before completing the save, then releases failure during the drain. Assertions cover zero category-warning presentations, one Quit choice, no automatic reply, explicit Cancel yielding false and retained Quit protection.

The reported-visible window (:26-29) is deliberately unordered. It makes the existing visibility predicate admit the pre-R3 warning without ordering a real window or presenting a real sheet. The fixture retains the production onCategorySaveFailure closure; it replaces the sheet presenter with a counter and injects the Quit choice. Thus it targets the source admission defect rather than passing because the ordinary window is invisible. Under the R2 callback, the failed save could increment that category-warning counter; under R3 the Quit phase excludes it.

The fixture overrides owner.canTransition/canExecuteAction/captureGrid for entry. Those overrides do not bypass the new AppDelegate libraryNonmodalLifecycleIsReady check. This is a useful regression at the production callback/drain seam, not proof of actual AppKit window visibility, sheet ordering, Cancel-button appearance or event behavior. The new test does not itself assert the inline label or committed category; those source properties remain covered by the retained owner/view paths and earlier tests. This reviewer did not execute any test.

## Verification boundaries and next action

Main reports pre-guard full r2 **2585 tests / zero failures**. This is reported historical execution evidence for the prior input set, not independent verification and not a current R3 full-suite result. Main reports the new targeted regression is running; no execution result was supplied at this review checkpoint.

Main should complete the targeted regression and fresh R3 checks required by its validation plan, keeping source hashes associated with those results. Useful follow-ups remain late save failure after timeout while awaiting/approved, cancellation/new Quit attempt with stale decisions, idle-session failure still producing one warning, and receipt after hide/teardown. The existing combined-write, mounted return/input/accessibility, restart and physical gates from R1/R2 remain separate; this narrow SourcePASS does not silently close them.

No additional source repair is requested for this reviewed guard. Main retains responsibility for execution and native acceptance.

## Source identity and historical preservation

Fingerprints were collected during the review and rechecked before handoff. Owner/view/preferences match R2; the changed AppDelegate and test identify the R3 source. The two historical report hashes remain unchanged. This is a bounded fingerprint set, not a full manifest/build verification.

| Input | SHA-256 |
| --- | --- |
| Workflow/results/APP_LIBRARY_NATIVE_OWNER_REVIEW.md | 90d9247eb933cda585d8d44e8aeae3f06920fe9f63d58dd7a0c20fb51143646b |
| Workflow/results/APP_LIBRARY_NATIVE_OWNER_REVIEW_R2.md | f2aca3c3d6c4722f8314bb18d3f5032bd1778df440909fc1f87929ffe63b53ec |
| Sources/PagingPrototypeApp/AppDelegate.swift | 5e35d803b492b6198ebf5a14fd24a03b52342b00499727c87e65a4da7ec892ff |
| Sources/PagingPrototypeApp/AppLibraryOwnerController.swift | e99e9b851defd6cd05e90e36e40e79e4ebe4ec6c0e33e156955b98827940f7cd |
| Sources/PagingPrototypeApp/AppLibraryView.swift | 0b3baba5237d99e06a7ca81f6ba3b406d6f80ee9036f3cff106cd678855c3c34 |
| Sources/PagingPrototypeApp/AppLibraryPreferencesCoordinator.swift | 59e21fd854e06396ee39b8212710bc1339e1ca0c46c2276583e32bdee6cdb6d0 |
| Tests/PagingUITests/AppLibraryLaunchAndQuitTests.swift | e6528458f9b13ae765e572f660be49f5421a7ebd083b89cccbcbbe4659dd7be8 |
