# Four-finger cold-enable: independent bounded source review

Date: 2026-10-15. Verdict: **SOURCE PASS for the specified three-input repair**. Confidence: high for the inspected source/lifecycle contract; limited to source and recorded test evidence. This is not native/physical acceptance, candidate approval, or full-goal completion.

## Authority and scope

Read `/Users/mac/.codex/RTK.md`, repository `AGENTS.md`, `Workflow/stage-summaries/2026-10-15-four-finger-cold-enable.md`, and `Docs/FOUR_FINGER_COLD_ENABLE_REPAIR.md`. Followed the explicit bounded reviewer assignment and user-authorized concurrency/old-Chief waiver. No agents were created or contacted.

Reviewed the saved original bodies, exact three `.swift.diff` files, both input manifests, current three changed files, and the existing composition/settings/transaction/provider lifecycle code needed to interpret them. This is an existing macOS AppKit/Swift application with a MainActor composition root, injectable service adapters, a settings transaction, and XCTest coverage. The added internal host helper follows that architecture without changing public protocols.

Only this report was written. No implementation, other documentation, reference code, resources, scripts, defaults, or workflow state were edited. No Swift invocation, tests, builds, packaging, application launch, native interaction, device access, or process-management action was performed by this reviewer. Resource/script entries were included only in the explicitly requested read-only digest verification.

## Input identity and change boundary

Bundle: `.build/verification/20261015/four-finger-cold-enable/`.

- `baseline-inputs.json` and `source-inputs-final.json` each contain 455 entries with identical path sets.
- Exactly three entries differ; the other 452 captured entries are unchanged.
- Independently calculated SHA-256 for every current captured input: **455/455 match final manifest, zero missing/unreadable inputs, zero mismatches**.
- Each saved original `.swift` body matches its baseline manifest digest.
- Reconstructed unified diffs from those original bodies and current files match all three supplied `.swift.diff` files exactly.
- These conclusions apply to the 455 captured inputs, not an assertion about every unlisted worktree file. Earlier auditors' frozen snapshots were not used as an intermediate shared-helper baseline.

| Input | Original SHA-256 | Reviewed final SHA-256 |
| --- | --- | --- |
| `Sources/PagingPrototypeApp/AppDelegate.swift` | `fd937580eddc8443b3bd34687ef75ae35cd41cad3b3160fea2b7a51581c0dcd8` | `59e990a26c5b186936322453e3f492c38d0bd4df3e1dd59a85e671c2ff26563d` |
| `Sources/PagingPrototypeApp/LauncherRuntimeServices.swift` | `967db367f5219f8bdf56116eaecddab632ddb9dc986b57a29e69c49bba656927` | `4b8e25ebec37305e84982485f7884b98012e66a32aa9f44865aa0a58c5890e8a` |
| `Tests/PagingUITests/LauncherRuntimeServicesTests.swift` | `6184bc00fed7c6345c29fc917d4eceff736206c2ca9ef60f771edddb4c73c9f8` | `2dfd79cc3352bb255a446944bedc3bdb53d89cfbae36318d74698a32a4b71a70` |

## Findings

**No actionable P0, P1, P2, or P3 finding in the reviewed delta. No minimal fix recommended.** The original cold-Off/settings-On defect is addressed by the reviewed helper and both host call sites.

### Host wiring and isolation

- `AppDelegate.swift:1985-1997` still loads the existing activation preferences. Startup at `2014-2015` now calls the same helper as the settings closure at `2037-2039`; the old startup-only attachment block is removed.
- Settings capture `[weak composition, isolated = self.uiTestProfile != nil]` fixes isolation as a Boolean at closure creation. It neither rereads a subsequently changing profile nor captures the delegate strongly through the helper. A released composition exits before any helper/factory call.
- Profile configuration precedes service installation; its existing failure branch returns from launch (`AppDelegate.swift:405-412`). The repair does not introduce a production fallback for a rejected isolated profile.
- `LauncherRuntimeServices.swift:23-33` is internal and MainActor-isolated through its enclosing enum. Its synchronous, nonescaping default factory creates the existing backend only inside the guarded branch. Passing the closure does not eagerly instantiate a backend, and it is not stored for later use.
- Isolation short-circuits factory invocation even when On is repeatedly applied. Existing fake registrar/login selection remains unchanged. The helper still applies preferences, allowing isolated enabled-but-not-connected status to remain honest.

### Lifecycle and factory semantics

- A live, nonisolated, saved-Off cold start applies the disabled plan with no provider construction. The later accepted On call sees a missing provider and attaches the existing backend before applying the existing service plan.
- Initial On retains the original ordering: attach/start the backend, then apply preferences. The helper does not replace an attached provider, and repeated On does not construct another one.
- Existing Off/On transitions remain owned by `ActivationComposition.swift:366-395`: stop the retained provider and coordinator on Off, then restart the same provider on On. Attachment callbacks and readiness handling at `250-297` are unchanged. No recognizer/physics/private backend/protocol change is present in this delta.
- The factory does not force readiness. An unavailable provider retains its actual state and identity; repeated application cannot replace it merely because it is unavailable.
- The early `activationTeardownCount == 0` guard runs before both factory invocation and preference application. Existing teardown sets that count before removing callbacks/stopping and clearing services (`ActivationComposition.swift:188-214`). Late settings application cannot recreate a provider or restart other activation services through this helper.
- The existing transaction applies accepted non-login runtime preferences before persistence, then reapplies committed preferences on refusal (`ActivationApplyTransaction.swift:83-87,114-144`). A refused save therefore stops a newly created provider on rollback while retaining it for later reuse. This preserves the existing transaction ordering rather than inventing persist-before-runtime semantics.

## Causal regression and recorded verification

Reviewer execution counts: **0 XCTest, 0 Swift Testing, 0 builds, 0 packaging runs, 0 native/physical checks**. The following are Main's recorded runs, inspected as files rather than independently executed here.

| Saved evidence | What was actually inspected |
| --- | --- |
| `red.log` | Successful compilation/link followed by **1 XCTest / 4 assertion failures** in `testColdDisabledSettingsApplyCreatesProviderOnEnable`; failures at lines 63-66 are factory count 0 versus 1, provider identity, started state, and nil coordinator state versus ready. |
| `focused.log` | Terminal selected-suite summary: **78 XCTest / 0 failures**, 0.462 seconds; runtime-services suite **10 tests / 0 failures**. |
| `full.log` | After Main reported completion, inspected terminal tail: **2688 XCTest / 0 failures**, 53.305 seconds; `All tests` completed at 22:39:54.842. This is a recorded full-suite result, not independent reviewer execution or full-goal acceptance. |

The cold-Off regression (`LauncherRuntimeServicesTests.swift:39-67`) first calls the shared host helper with Off, verifies zero factory calls and nil provider, then uses the actual `ActivationSettingsCoordinator.applyDraft` and transaction with an On draft. It requires `.applied`, accepted On and committed On before asserting attachment/start/readiness. It neither manually attaches the provider nor directly calls the composition to bypass the repaired host path. The recorded RED reaches those lifecycle assertions after compilation and acceptance, so it is a behavioral regression rather than a missing-symbol/compiler failure. The trailing Swift Testing zero-test line is not the XCTest count.

The saved original host code independently establishes the pre-fix cause: startup conditionally attached only for saved On, while settings called `composition.applyPreferences` alone; `.startFourFinger` could not create a nil provider. Main reports the RED was run after a behavior-equivalent helper extraction with the old startup conditional retained. The bundle preserves the original and final source, not a separate complete intermediate RED source snapshot; the precise intermediate extraction is therefore attributed to Main's stage record rather than represented as independently hash-verified here. The successful behavioral RED, original call path, unchanged composition, and final shared-helper test are consistent with that account.

Independently counted test methods: 2 original, 10 final, **8 added / 0 removed**. The additions cover cold Off/accepted On, initial On/repeated application, retained-provider Off/On reuse, isolated factory non-invocation, post-teardown non-revival, unavailable-state honesty, preservation of an explicitly attached provider, and persistence-refusal rollback. They use MockTouchProvider/fake services; they do not establish physical device recognition or exercise production UserDefaults cold launch end to end. Both real host sites are verified by source inspection.

## Remaining gates and disposition

No bounded source repair is requested. Main retains ownership of Debug/Release/package/candidate verification; Debug was reported running and its result was not reviewed here. No new candidate or broad native PASS is asserted. Production cold-Off to settings-On physical behavior, four-finger M01-M12, energy/120 Hz, and full migration acceptance remain pending at their proper evidence layers. Previous binaries' native results do not transfer automatically.

Appearance factory-nil persistence and Library folder-choice findings belong to their distinct future work. They are not findings against this three-file activation repair and do not expand this review.

Main may use this SOURCE PASS alongside separately owned verification evidence. It does not close the full user goal.
