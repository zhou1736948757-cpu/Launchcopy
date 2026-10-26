# App Library source-refresh failure — narrow R2 source review

Date: 2026-10-15 (Asia/Tokyo).

## Verdict and scope

**Bounded SourcePASS for SF1's final production callback-composition repair.** The overwrite reported in APP_LIBRARY_NATIVE_SOURCE_FAILURE_REVIEW.md is resolved in the freshly frozen source. No new actionable finding was identified within this narrow callback-order/regression review. Confidence: high for source assignment/call flow; no execution or native behavior was verified.

The prior FAIL report is preserved. This assessment closes that specific source finding; it does not certify the whole Library, current full-suite execution, native/accessibility behavior, restart durability, physical performance or full parity. The R3 category-warning Quit guard remains a separate scoped assessment.

Reviewed sources: AppDelegate.swift, the unchanged AppLibraryOwnerController.swift and AppLibraryOwnerIntegrationTests.swift. Sole write: this R2 report. All shell commands used RTK. No Swift/build/tests, GUI/app/process operations, other agents, implementation/test edits, forbidden reference/evidence/assets content reads or production-data access occurred. Core/PagingUI were not opened or changed. The pre-existing dirty tree and historical reports were preserved. Main reports r7 focused verification is next; no r7 execution outcome was supplied or inferred here.

## Repair evidence

Sources/PagingPrototypeApp/AppDelegate.swift:771 now calls installFinalCatalogRuntimeCallbacks at the former second-assignment location. The earlier wrapper invocation was removed. Startup installs this one final helper before assigning the shared assembly/starting sources and assembly.begin() (:778-780). Text search of the file finds refresh-state assignments only inside the final helper and its composed presentation helper; no later startup assignment overwrites the Library notification.

installFinalCatalogRuntimeCallbacks (:1303-1313) captures the pre-existing onStateChange consumer, invokes it first, then retains the existing status/idle-boundary/direct-navigation cancellation behavior. It finishes by calling installCatalogPresentationCallbacks. That helper (:1318-1324) captures this complete consumer and wraps it with status and Library delivery. A busy-state early return inside the retained idle consumer returns to the wrapper; it does not skip noteCatalogRefreshState. Consequently retry/refreshing and terminal failure reach Library through the authoritative shared refresh callback rather than a second scanner or independent refresh owner.

The retained consumer runs before Library notification. If its idle work commits a newer catalog, AppLibraryOwnerController.catalogDidCommit clears invalidation and failure (:200-207); the subsequent noteCatalogRefreshState returns because there is no invalidation marker (:194-197). The old failure event therefore does not re-invalidate the newly committed catalog. With no newer commit, partialFailure/refreshing updates presentation while the source marker continues to block entry and execution (:98, :213). The owner source fingerprint is identical to the previous source-failure review; no domain/classification contract change was found in this scoped repair.

There are status scheduling calls in both retained and wrapper layers, as before the repair. This report's single-delivery conclusion concerns the retained refresh consumer and Library notification, not a claim that status scheduling is invoked only once.

## Regression-source assessment

Tests/PagingUITests/AppLibraryOwnerIntegrationTests.swift:221-257 adds testFinalProductionRefreshCompositionRetainsConsumerAndLibraryFailureDelivery. It calls the **same final helper used by startup**, after installing a prior observer (:229-231); it then opens Library against the shared provider, captures a currently valid action and invalidates source targets.

The test delivers partialFailure, refreshing and partialFailure through the resulting refreshController.onStateChange callback, not by directly calling the owner method. It checks the prior observer's exact event sequence, unavailable/loading/unavailable text and stale action rejection during failure/retry. Same-revision catalogDidCommit remains unable to turn the terminal failure into loading/recovered content. The retained earlier test (:107-131) additionally checks failure-label visibility, same-revision non-acknowledgement and newer-catalog recovery with a fresh action.

This closes the specific coverage gap identified in SF1: a helper-only owner test could pass while production wiring overwrote its callback, whereas startup and this test now share the final composition seam. The new fixture still directly emits refresh states and overrides owner admission for entry; it does not perform a real rescan, mounted window interaction, app launch or native failure presentation. No test was executed by this reviewer.

## Remaining verification and handoff

No further source repair is requested for SF1. Main completes focused r7 and the planned fresh full checks against current frozen inputs, recording executed counts and source identity separately. Historical green runs cannot be relabelled as execution for this repaired input set.

The earlier broader verification boundaries remain: failed real rescans, pending projection/preferences work during invalidation, closed/teardown behavior, mounted input/return/accessibility, restart and physical performance. Those are not silently closed by this narrow SourcePASS. Future changes to startup wiring should use the final composition seam rather than add a later assignment to the single callback slot.

## Source identity and preservation

The following fingerprints were collected during inspection and rechecked before handoff. The historical source-failure report remains byte-identical. These are scoped identities, not a full manifest/executable verification.

| Input | SHA-256 |
| --- | --- |
| Sources/PagingPrototypeApp/AppDelegate.swift | 7d77f4b99d9fafe75bba58ca9bdd980074be3bca5e58cbce4635fffc029acf9e |
| Sources/PagingPrototypeApp/AppLibraryOwnerController.swift | b90670adab5e0179e5251ec483e0f475389d4948396a619849cc37e1ca90c58c |
| Tests/PagingUITests/AppLibraryOwnerIntegrationTests.swift | 6af97e63b836bd45e7e4a9faa82aaa380646d2ff5c9a57b99860edc8a20fe5a3 |
| Workflow/results/APP_LIBRARY_NATIVE_SOURCE_FAILURE_REVIEW.md | 0defd5d600988f427ec36c29422b1895c3a7e7d4a6a109f2d30324f1d375249b |
