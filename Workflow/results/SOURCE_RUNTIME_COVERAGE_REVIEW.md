# Source runtime coverage repair — independent bounded review

Date: 2026-10-15. Role: SOURCE reviewer. Repository: `/Users/mac/Projects/Launch_Copy/PagingPrototype`.

## Verdict and findings

**PASS — bounded SOURCE review. No actionable P0/P1/P2/P3 finding in the supplied two-file delta.** This verdict covers the private coordinator repair and causal unit-test changes, not overall delivery, physical acceptance, or changed-candidate native UI acceptance. No implementation fix is requested.

**Reviewer executions: 0 tests, 0 builds, 0 Swift invocations, 0 native UI actions, 0 application/process-control actions.** Only read-only inspection, textual diff reconstruction, and SHA-256 checks were performed before writing this report. No agents were spawned or messaged. Only this result file was written; implementation, contracts, stage documentation, and other agents' files were preserved. Main owns serial full-suite/Debug/Release/package execution.

## Exact candidate and evidence identity

Evidence base below: `.build/verification/20261015/source-reappearance-native/coverage-repair/`.

`source-inputs-final.json` contains **455 entries**, SHA-256 `4fbe24defe5732cf91f083845f03417ba2a49a7f4d62162823d3c1d1dd409eff`.

| Changed input | Current SHA-256, matching freeze | Saved prior-body SHA-256 |
| --- | --- | --- |
| `Sources/PagingPrototypeApp/AppSourcesCoordinator.swift` | `ea99279814573271fe57aafe5549d28b80654d89aaf2c1917561fdfef3e46d15` | `dfbd5972fa725b412ca32ff5e2c3ee0233a9c39709a80c43e2242bc33eccc676` |
| `Tests/PagingUITests/AppSourcesCoordinatorTests.swift` | `976ece33bee51f022d4e6fdedad31da39d732d58c69136e9c71cc20a09a44325` | `b26a5a4f84cab7dda66d2bd45b1af225d2ec7d9c4a44795eb499ea0ef4662967` |

Both saved `.swift.diff` files were reconstructed byte-for-byte from the corresponding saved prior body and current body, with matching headers. Diff hashes, respectively: `abff2f338bae0ae978fb8f16ed12de762794356fd2457bea8317f9c3c2c98c12` and `39b93eb1454ba1a93cfe4f8cee4cca34ab122dcc2a907cf6f32ae2e97d98a574`. The two current inputs and freeze were checked again immediately before report creation.

The assigned delta is exactly these two inputs among the 455-entry freeze. This review independently establishes their exact bodies and diffs; the remaining 453 entries are manifest context, not an independent full-tree rehash or semantic review. In particular, no raw images/assets/resource bodies were opened to broaden that claim.

## Source reasoning

- **Private coverage inspection:** coordinator lines 148–158 construct a separate admission context with `fixedRoots: []`, preserving `homeURL` and `allowedSyntheticRoot`, and retaining exact-canonical enforcement whenever the original context requires it or a synthetic boundary exists. This removes only the `.alreadyCovered` short circuit for these status probes. The original context still serves draft admission and `AppSourceRootSetResolver`; returned coverage URLs are never persisted or used as replacement scan roots.
- **Boundary and work budget:** `LocalAppSourceRootAdmitter` checks lexical synthetic/home/bundle boundaries before canonicalization, repeats canonical boundary checks before metadata, and rejects an exact-path substitution before metadata. Actual filesystem metadata remains on the existing admission actor. The added loop has at most one additional admission per fixed-root candidate per reconciliation and stops on the first failure. It introduces no enumeration, parent watch, timer, frame work, external profile probe, or permission request.
- **Honest loss latch:** after the resolver and availability batch pass their epoch/cancellation/teardown guards, the same-session path ORs a loss into `fixedRootCoverageLost` (lines 134–135). Returned availability alone cannot clear it. Clearing for an enabled session happens only after an existing watcher replacement completes; displayed status still respects the actual backend startup result and excluded references (lines 123–139). An active/disabled backend is downgraded when coverage is incomplete; degraded/unavailable backend status is not promoted. Disable and teardown clear the private latch.
- **Bounded overlap handling:** a current callback keeps the existing `requestRefresh(false)` route. If reconciliation is already running, it sets one Boolean rather than restarting/cancelling that probe. Completion consumes that Boolean by starting one follow-up, whose entry clears it (lines 107, 140–141, 165–167). Eight callbacks during one held probe therefore cannot accumulate eight coverage tasks. Later callbacks can request a further reconciliation only as new work arrives. Ordinary fixed-root availability events with the same admitted root set/source generation do not replace streams; existing root-set/generation/manual-retry/unavailable conditions remain the rearm conditions.
- **Obsolete work and races:** resolver completion, availability completion, and watcher setup completion each recheck the coordinator epoch, cancellation and teardown before status/latch mutation (lines 118, 120, 130). Source transactions increment `sourceGeneration`, and callbacks reject old source generations. Disable/teardown increment the watch epoch, cancel the task, clear pending work and stop the watcher. The unchanged native adapter separately fences suspended setup with its own generation and closes obsolete sessions (`AppSourceWatcher.swift`, lines 97–114). An old coverage task exits without clearing or consuming a newer task's state. MainActor serialization protects the pending flag and latch.
- **Scope preservation:** the exact implementation diff adds private status bookkeeping and an admission helper only. It changes no trusted scan-root policy, preference schema/save path, public watcher protocol, catalog commit path, event payload, pager/gesture physics, or canonical layout mutation. The app composition still routes neutral invalidation to `scheduleRescan()` and explicit refresh to `refreshNow()`; settings observe the existing watch-status callback.

## Causal correctness of the three new cases

1. `testFixedRootLossDegradesExistingCoverageUntilExplicitRetryWithoutDeletingReferences` (lines 230–273) first establishes active coverage, changes the fake admission result for the same fixed path to missing, then invokes that installed session's callback. It asserts degraded status with unchanged watched roots, no replacement of discovery inputs, unchanged committed preferences/no saves, and the existing non-immediate refresh. It exercises repeated invalidation and actual revalidation after availability returns, requiring the loss latch to persist until explicit refresh replaces the watch. Its reference-retention assertion is coordinator-level; it does not independently prove native layout/query preservation.
2. `testObsoleteFixedRootAvailabilityCannotChangeDisabledCoverage` (lines 275–293) holds startup availability at the admission seam, saves automatic refresh Off, then releases a missing result. It requires disabled status and no installed stream. With no custom/synthetic resolver admission in this fixture, the held call is specifically the newly added fixed-root coverage probe. This is a suspended-startup disable regression, not evidence of native teardown execution. Teardown safety additionally follows from the shared guard and unchanged lifecycle code inspected above.
3. `testInvalidationDuringCoverageProbeKeepsOneLatestFollowUpWithoutRestartingStream` (lines 318–342) establishes a live session, holds its next probe, changes future admission to missing, delivers eight callbacks, then returns the stale accepted snapshot. Only a subsequent probe can observe missing. Degraded status plus exactly three admissions (startup, held probe, one follow-up), one stream setup, no saves, and nine non-immediate refresh requests discriminate retained follow-up work from the earlier dropped-invalidation path. No synthetic timing or filesystem signal is being presented as native automatic-root-event proof.

The fakes deliberately isolate coordinator transitions; production admission boundaries are established by the unchanged admitter implementation and relevant existing admission/profile tests inspected, not by assuming that the new fakes enforce those boundaries.

## Recorded execution evidence, not reviewer execution

| Supplied receipt | Observed result | SHA-256 |
| --- | --- | --- |
| `red.log` | XCTest: 2 tests, 6 assertion failures. Missing-root status stayed active/no new admission; suspended-availability seam was absent. | `c76ab45c8b339e3918800889464ff3b47c7a32e8de2a20e0bfabc549f7ba505f` |
| `overlap-red.log` | XCTest: 1 test, 1 failure; degraded status did not settle after the stale held snapshot and overlapping callbacks. | `71a1957707e9cd50b27a6d210b88ebc59d039e0706cfb509a55df9478e06311d` |
| `focused-r2.log` | XCTest: 102 tests, 0 failures, including all 3 new cases; coordinator suite 16/0. | `cfc21e5f1739a5f8b22d8b04b1a4df3adfa87072b914146041be5ccc9024d009` |

The separate trailing Swift Testing “0 tests” footer is not the XCTest execution count. These are Main's existing receipts; this reviewer did not rerun them. Full-suite, Debug, Release and package results were not consumed for this bounded verdict.

The stage summary records the old `889d...` candidate's manual missing/degraded/recover flow, retained query/layout and restored synthetic directory. It expressly did not establish an automatic root invalidation. That historical control does not demonstrate the changed branch running in native UI. **No automatic root-event PASS and no changed-branch native PASS is claimed here.** Exact-candidate native Sources/status smoke and Main's remaining delivery checks remain separate gates.

## Exact inputs inspected

- Repository `AGENTS.md` and `/Users/mac/.codex/RTK.md` for role/read-only/command boundaries; direct human instruction governs the max-three-including-Main/old-Chief waiver and this output path.
- `Docs/APP_SOURCES_RUNTIME_COVERAGE_REPAIR.md` (entire maintenance contract; SHA-256 `ae8ca9326908bd153321b0a04cd683ffc45ab9a2949251c36339ef9081bd26f6`).
- `Docs/APP_SOURCES_AND_WATCHING_SPEC.md` (entire approved contract; SHA-256 `03274c8f25b46d08beb60d36046b3b9e663a2aa3a61b67606f2e6e3949503173`).
- `Workflow/stage-summaries/2026-10-15-source-reappearance-native.md` (stage snapshot SHA-256 `31e6267efba876ccc949726280e8c8cb38df94cb2cfe5ae350c099629507a959`; later Main updates are outside this snapshot).
- Both current changed files, both saved prior `.swift` bodies, both exact `.swift.diff` files, `source-inputs-final.json`, `red.log`, `overlap-red.log`, and `focused-r2.log` under the evidence base identified above.
- `Sources/PagingPrototypeApp/AppSourceRootAdmission.swift` (entire context/admitter/resolver).
- `Sources/PagingPrototypeApp/AppSourceWatcher.swift` (protocol/status/setup/cancellation/stop/delivery, principally lines 1–160; no native execution).
- `Sources/PagingPrototypeApp/AppDelegate.swift`, lines 2060–2130 (source assembly/refresh route/settings binding).
- `Sources/PagingPrototypeApp/AppCatalogAssembly.swift`, lines 78–155 (scan admission and generation boundary).
- `Tests/PagingUITests/AppSourcesCoordinatorTests.swift` (entire file, including unchanged lifecycle and source-generation cases).
- `Tests/PagingUITests/AppSourceRootAdmissionTests.swift`, lines 1–275 (trusted-covered behavior, metadata failures, home/synthetic/exact boundaries).
- `Tests/PagingUITests/AppSourcesProfileAssemblyTests.swift` (entire file: isolated owner, source replacement/recovery, injected services).
- `Tests/PagingUITests/AppSourcesCatalogIntegrationTests.swift`, lines 45–165 (obsolete admission/cancel and unchanged per-scan admission context).

Directory/name and symbol inventories were read only to locate this evidence. No reference directories, Buho/LaunchBetter code, raw images/assets, TCC database, formal user data, process state, or active full/build/package logs were inspected. No unrelated implementation was reviewed. No generic feature or test expansion is requested.
