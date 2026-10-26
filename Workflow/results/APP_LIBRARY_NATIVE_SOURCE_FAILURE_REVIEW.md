# App Library source-refresh failure — independent source addendum

Date: 2026-10-15 (Asia/Tokyo). Source checkpoint: 2026-10-14T17:49:06Z.

## Verdict and bounds

**SourceFAIL for this narrow source-failure UX integration.** One P2 production callback-wiring defect prevents the new failure notification from reaching Library during ordinary startup/runtime assembly. Confidence: high from the fresh source assignment order; no runtime reproduction was attempted.

Scope: Sources/PagingPrototypeApp/AppDelegate.swift, Sources/PagingPrototypeApp/AppLibraryOwnerController.swift and Tests/PagingUITests/AppLibraryOwnerIntegrationTests.swift. The approved explicit error-state contract remains the basis for the repair. Only this addendum was written. All shell commands used RTK. No Swift/build/tests, UI/app/process operations, other agents, implementation/test edits, forbidden reference/evidence/assets content reads or production-data access occurred. Core/PagingUI and the existing dirty tree were preserved. R1/R2/R3 reports were not rewritten.

Main reports the previous pre-addendum full r3 result as **2586 tests / zero failures** and plans new focused/full runs after input freeze. That result is supplied execution context, not independently verified here and not a test result for these changed inputs. R3's narrow Quit-guard review remains a separate assessment; the same admission guard is still present in the current AppDelegate (:2275-2284, :2295-2302).

## Finding SF1 — P2: Startup overwrites the newly composed Library refresh callback

**Location:** Sources/PagingPrototypeApp/AppDelegate.swift:772-782. Related installation: :759 and :1312-1318. Missing integration coverage: Tests/PagingUITests/AppLibraryOwnerIntegrationTests.swift:119. Confidence: **high**.

installCatalogPresentationCallbacks captures the previous refresh-state consumer and assigns a composed closure that calls it, schedules catalog status and then calls appLibraryOwner.noteCatalogRefreshState(state). The composition inside the helper is correct in isolation.

However, the production content assembly calls that helper at :759 and subsequently assigns refreshController.onStateChange again at :772. This later closure owns idle-boundary commit behavior/status updates, but neither retains/calls the earlier closure nor calls noteCatalogRefreshState. It replaces the exact slot that carried the new Library failure notification. Text search finds no other production call to noteCatalogRefreshState in this file. The later assembly.begin() at :791 runs after this replacement.

Concrete consequence: Library is open, scan roots are replaced, invalidateSourceTargets revokes actions and displays loading, then the shared refresh controller reports partialFailure without a newer catalog commit. The installed production callback does not notify Library, so sourceRefreshFailed stays false. The new owner rendering predicate continues treating the invalidated source as loading rather than unavailable. The intended repair therefore does not fix the production failed-rescan presentation, although old actions correctly remain revoked.

Likely cause: the existing second assignment to the single refresh callback was missed when adding notification to the earlier helper.

Recommended Main repair: retain one composed production refresh callback through the complete startup wiring. Preserve the current idle-boundary/cancel/status consumer and deliver Library state exactly once, including busy/refreshing states before any early return. Either install the composed helper after the final consumer is established or explicitly retain/call the current callback when assigning its replacement. Do not fix this with a second scanner, independent refresh owner, timer or Core changes. Review ordering so a retained callback that commits a newer catalog does not re-invalidate that committed state.

Affected scope: AppDelegate refresh-state wiring and a focused production-composition regression. Regression risks: first scan, busy early returns, direct-navigation cancellation, pending catalog commit, duplicate callback delivery and existing consumer clobbering. Main owns repair; this recommendation does not authorize unrelated callback redesign.

## Owner and test observations

AppLibraryOwnerController.swift:183-208 adds the intended separate presentation state. Invalidation resets sourceRefreshFailed and keeps invalidatedSourceRevision. A directly delivered partialFailure sets the flag; the owner renders unavailable when no other loading work remains (:253-258). A later refreshing event clears the flag, and only a strictly newer served revision clears invalidation/failure. Enter and resolve still require invalidatedSourceRevision == nil (:98, :213); presentation of an error does not admit stale actions. Same-revision catalogDidCommit cannot acknowledge a source replacement.

The updated test (:107-131) directly calls owner.noteCatalogRefreshState(.partialFailure), asserts localized unavailable text is visible, checks the old action remains rejected, checks same-revision non-acknowledgement and then verifies recovery with a newer revision/fresh request. These are meaningful owner-state assertions but bypass AppDelegate refresh callback installation and its later overwrite. The test does not establish the claimed production wiring and was not executed by this reviewer.

The new owner method/render path introduces no second scan or classification request on a failed state, and no pager/physics edits were inspected. The source-failure presentation change is separate from the preserved R3 Quit modal guard.

## Next regressions for Main

1. Exercise the final production callback composition/order, not only the helper in isolation or a direct owner call. Retain a pre-existing consumer, perform the normal wiring sequence, invalidate an open Library, deliver partialFailure via the resulting refresh-state callback, and assert both the retained consumer and Library update occur once. Verify unavailable feedback and stale action rejection.
2. Deliver refreshing through that same callback and assert loading restarts without enabling stale actions; fail again; issue a same-revision update; finally commit a newer catalog and assert recovery. Preserve existing idle commit and status consumers through this sequence.
3. Cover no Library/closed Library/teardown and a pending projection or accepted preference write at source invalidation. Keep loading/error presentation consistent with actual outstanding work and do not restart projection/scanning merely to display a failure.

After repair, Main runs its serial focused/full validation against fresh inputs and requests a narrow source re-review. The current SourceFAIL is specific to SF1; it does not revoke the already-reviewed R3 guard repair or claim failure of native/physical gates that were not tested.

## Source identity

The three scoped source/test fingerprints were collected twice and matched. The R3 report hash also matched, preserving its historical conclusion. These hashes do not certify a full source manifest, executable or native acceptance.

| Input | SHA-256 |
| --- | --- |
| Sources/PagingPrototypeApp/AppDelegate.swift | 8191c4ea17c3bd17646a602d685dc11743adb82dfd9b69309fa7effc12856205 |
| Sources/PagingPrototypeApp/AppLibraryOwnerController.swift | b90670adab5e0179e5251ec483e0f475389d4948396a619849cc37e1ca90c58c |
| Tests/PagingUITests/AppLibraryOwnerIntegrationTests.swift | 49d5d3785aab8a70aedcbced2b360b3d159584466a083fe63726d6ec9eff2a61 |
| Workflow/results/APP_LIBRARY_NATIVE_OWNER_REVIEW_R3.md | 524b2097dc00cc6cd8ede33831bbaa121f91446657f5c4dcd187ac303b9a36ed |
