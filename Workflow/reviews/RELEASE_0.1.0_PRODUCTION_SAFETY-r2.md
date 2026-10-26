# Launchcopy 0.1.0 production safety review — r2

Date: 2026-10-26

**Verdict: PASS — bounded source review of the final B1 repair and associated test changes.** B1's shared-temporary-root deletion chain is closed in the reviewed root-checkout source. No genuine remaining source release blocker was identified in this bounded delta. **This is not an executed-test, integrated-export, package, or release-readiness PASS.** Main's fresh integrated verification and artifact gates remain open.

The r1 FAIL remains correct historical evidence for the original snapshot. It has not been edited, deleted, or retroactively converted to PASS. Its SHA-256 at this review is `03f3d70d7e0c4c9b9a19d3bd22c19a6949bae95c816c2d0f203c0737de97dbda`.

## Scope and authority

This review compares actual root-checkout bytes with Git baseline `e13125b3f9a68380b4c24ef585d31cbc7ddc4942`, including new files, rather than trusting the dirty index or a worker summary. It covers the final configured-profile-first / unresolved-profile guard, unavailable backend, cleanup hardening, six availability tests, eight cleanup tests, and the previously corrected AppSources wait helper. The latest test-only compilation corrections are included; superseded intermediate bytes are not approved.

Authorization is recorded in `Docs/RELEASE_0.1.0_SPEC.md:23-27` and `Workflow/stage-summaries/2026-10-26-release-0.1.0.md:12-16`. The B1 exception supersedes unchanged-product wording only for failure-path storage and cleanup safety; it does not authorize unrelated product changes. Main's subsequent direct instruction adds the unresolved-isolation guard and sixth regression before integrated freeze.

Only source/document reads, local Git-object comparisons, and file hashing were performed. No tests, builds, executable/probe/UI runs, network calls, publication, private-store inspection, real temporary-root cleanup, or reference-project inspection occurred. Main owns copying into the clean export, hashes/provenance, serial execution, packaging, and publication. The sole reviewer write is this new r2 report.

## Frozen source identity

Across `Sources/`, `Scripts/`, `Resources/`, `Tests/`, and `Package.swift`, the baseline comparison found **613 unchanged files, five modified files, three added files, and no missing files**. The eight changed/added paths are exactly those below. Within production inputs, only the four modified storage/composition files and one added backend differ; packaging, resources, manifest, paging parameters, and other product inputs remain baseline bytes.

| Reviewed path | SHA-256 |
| --- | --- |
| `Sources/AppGridUI/LayoutStore/LayoutStore.swift` | `edb5158fb28396cf69af7b8cd86cad85c0911f071db73116abfc7e6363af8979` |
| `Sources/AppGridUI/LayoutStore/LayoutStoreActor.swift` | `f6f82b5a091dd658535ae3a99527bfecc3d56828c90e03c525983fb59b944ef1` |
| `Sources/AppGridUI/LayoutStore/LayoutStoreIO.swift` | `a4a65d2b706b40876690c38760784414e5300753946813ab747ec9a8a6747046` |
| `Sources/AppGridUI/LayoutStore/UnavailableLayoutStore.swift` | `94c3921ab3e02f427525a050a6ad0e600a79c75cef46962c9357a15102562286` |
| `Sources/PagingPrototypeApp/AppDelegate.swift` | `5b44e41d8ee8fe2b26a5bd45bbb1b8ede8ad59a734e2e85c12f1c9782ca79ab3` |
| `Tests/AppGridUITests/LayoutStoreTemporaryCleanupTests.swift` | `42c347cb1c84297d9028f748ddda40bf09f52f3eca4df987df92bac4ccae96c1` |
| `Tests/PagingUITests/AppSourcesProfileAssemblyTests.swift` | `fb27dfd5676e891872b61142248e9ff2f86b30d2337accdcf0fa4981044e119e` |
| `Tests/PagingUITests/LayoutStoreAvailabilityTests.swift` | `3dab9742f9c4151735dd5111ac3fd59a9f7fddb9411182b5cfe4ee9bf176034e` |

These are root source hashes, not evidence that an export, executable, archive, or release tag contains these bytes. Main must bind the final commit and integrated execution to this exact set, including the two latest files rather than earlier intermediate hashes. All source references below are repository-relative, one-based lines in these final bytes.

## B1 closure assessment

### Production directory failure and isolated-entry admission — PASS

`Sources/PagingPrototypeApp/AppDelegate.swift:965-967` now installs `makeLayoutStore()`; it no longer substitutes `FileManager.default.temporaryDirectory`. The factory at `:3394-3407` has three explicit branches:

1. A configured `uiTestProfile` selects its dedicated layout directory before consulting the provider (`:3398-3399`).
2. A requested but unresolved profile returns `UnavailableLayoutStore` before provider access (`:3401-3402`), including a direct call of this composition seam.
3. An ordinary production request resolves the injected/default dedicated directory; a thrown resolution error returns the unavailable backend (`:3403-3406`). The ordinary provider still uses `PagingPrototypeLayout` under Application Support (`Sources/AppGridUI/LayoutStore/LayoutStore.swift:134-148`).

Thus the original B1 resolver-error path cannot instantiate a journal against a shared temporary root. The provider itself can attempt Application Support lookup/creation before throwing; the no-I/O claim applies to the unavailable backend and absence of fallback journal/lock/cleanup work, not to an assertion that directory resolution performs no system calls.

### Unavailable storage state and consumers — PASS

`Sources/AppGridUI/LayoutStore/UnavailableLayoutStore.swift:3-14` contains no filesystem adapter, file opening, lock, queue, or task. Load/currentState return `.readOnlyProtection(.storageUnavailable)`; enqueue is inert; flush returns `.readOnly`; reset returns `.failed`; lock mode is `.unavailable`. It never acknowledges a durable write or reset success. The `/dev/null` URL at `:5-6` is a protocol compatibility token, not an opened file or a journal directory. Inspected `storeDirectory` consumers use it as identity or equality data; the backend does not pass it into the real actor/I/O implementation.

The new reason/mode are explicit neutral enum cases (`Sources/AppGridUI/LayoutStore/LayoutStore.swift:28-36,83-90`). Restore retains the read-only classification (`AppDelegate.swift:3430-3453`), and the existing guards reject layout commits, title commits, and folder assignments (`:1212-1213,2105-2113,3771-3785`). The pre-load interval is protected by `isRestoringLayout`; there is no interval where a known unavailable store is presented as successfully persisted.

Launch admission remains independent of storage health (`AppDelegate.swift:190-195`; `Sources/PagingPrototypeApp/AppLaunchController.swift:162-179`). Existing Quit behavior is retained: accepted workspace work is drained, a `.readOnly` receipt enters the explicit failure decision, and cancellation does not approve termination (`AppDelegate.swift:4243-4275`; `Sources/PagingPrototypeApp/WorkspaceQuitCoordinator.swift:24-36`). With no accepted pending work, the ordinary fast Quit remains permitted; the repair does not invent an unsaved-work warning solely because an unavailable store exists. This is a static consumer check, not mounted UI or actual termination acceptance.

### Cleanup selection, locking, and deletion primitive — PASS with explicit limits

`Sources/AppGridUI/LayoutStore/LayoutStoreActor.swift:372-379` now requires a retained lock and constructs only the two exact slot temporary URLs. Slot names are defined at `:29-35`. Both initial load (`:281-289`) and reset (`:190-199`) use this one cleanup method. Lock absence/failure causes no cleanup requests; no directory enumeration or suffix wildcard remains in the method. The diff does not change journal schema, archive/reset sequencing, ordinary writes, retries, or flush behavior.

`Sources/AppGridUI/LayoutStore/LayoutStoreIO.swift:84-100` independently allowlists the exact A/B temporary names, opens the containing directory with `O_DIRECTORY | O_NOFOLLOW | O_CLOEXEC`, and anchors `fstatat(..., AT_SYMLINK_NOFOLLOW)` and `unlinkat(..., 0)` to that descriptor. A nonregular entry or failed inspection/open is skipped. With no `AT_REMOVEDIR` and no recursive FileManager deletion, cleanup cannot recursively delete a directory. A stable symlink entry is skipped; unlink does not follow a symlink target.

**Limit, not a new blocker under this bounded contract:** the regular-file observation and unlink are separate operations. An external writer can substitute another regular file or a symlink at the same exact name between them; unlink can remove the replacement entry, though it does not traverse its target or remove a directory. `O_NOFOLLOW` protects the opened final directory component, not every ancestor in an arbitrary path. This is cooperative store-lock/owned-namespace cleanup, not an atomic identity-checked unlink or general adversarial filesystem hardening claim. The worker explicitly records these boundaries in `Workflow/results/RELEASE_0.1.0_TEMP_CLEANUP.md:45-53`. The old last-writer-wins/write path is unchanged; tests that reject writes isolate cleanup and do not certify all cross-process write races.

**B1 conclusion:** both causes identified in r1 are repaired in source: shared-root fallback is gone, and broad/recursive cleanup has become lock-gated exact-slot regular-entry cleanup. Confidence is high in this static chain closure. Integrated runtime regression evidence remains required before final release acceptance.

## Test-source review

### Availability coverage — six authored tests, bounded source PASS

`Tests/PagingUITests/LayoutStoreAvailabilityTests.swift` now includes:

| Lines | Actual coverage and boundary |
| --- | --- |
| `33-55` | Throwing production provider selects the unavailable type; verifies load/enqueue/flush/reset/state/mode and owned unrelated file/directory sentinels. The sentinel directory is not a global I/O interceptor: zero backend I/O is supported by the implementation inspection, not a claim that this fixture monitors the whole machine. |
| `58-66` | Installs the retained injected store, waits for restoration, checks read-only state/commit admission and the same store's flush receipt. No private property access remains. The owner is unshown and lacks a mounted production surface; full GUI admission is not independently demonstrated by its false commit predicate alone. The production read-only guard was separately inspected above. |
| `69-83` | Dedicated synthetic directory persists and reopens the same layout, without a fallback sibling directory. This requires actual execution for a persistence PASS. |
| `86-97` | Configured profile directory takes precedence over a throwing production provider. |
| `100-108` | Unconfigured requested profile returns unavailable despite a supplied FixedDirectory, with `MustNotOpen` remaining absent. Source order additionally confirms the production provider is not consulted. |
| `111-123` | A `.readOnly` flush through the Quit coordinator reaches an explicit decision and cancellation replies false; this is not a complete AppDelegate/UI Quit journey. |

Fixtures create and remove unique owned temporary children (`:16-21`); wait helpers use a five-second monotonic deadline and cancellable suspension (`:26-30`). The latest tests construct options with `try AppArguments.parse([]).get()` and retain the injected store (`:40,59-65,71`); the intermediate missing-initializer/private-access compilation defects are not present in the reviewed bytes. AppDelegate's `layoutStore` remains private (`Sources/PagingPrototypeApp/AppDelegate.swift:398`), so no encapsulation weakening was introduced.

### Cleanup coverage — eight authored tests, bounded source PASS

`Tests/AppGridUITests/LayoutStoreTemporaryCleanupTests.swift:19-191` covers exact regular temporary files under lock, unrelated suffix/near-match preservation, recognized symlink/directory preservation, reset cleanup, no-lock peer and lock-failure exclusion, direct removal guards/dangling links, and a symlinked containing directory. Synthetic store/outside directories share a newly created owned sandbox (`:212-223`); teardown removes only recorded sandboxes (`:11-15`). Both symlink target variants and nested sentinels are checked (`:250-267`).

The observation adapter delegates cleanup to real production filesystem behavior (`:273-328`), so exact removal-request/no-enumeration assertions are not the only evidence being asserted. Protected-reset and peer/lock-failure tests deliberately reject subsequent writes (`:89-108,111-160,295-298`); this is a documented cleanup boundary, not proof that the unchanged general writer is symlink-safe. The cleanup regression suite should discriminate the old implementation only after it actually executes.

### Existing AppSources wait correction — source PASS retained

The sole baseline diff in `Tests/PagingUITests/AppSourcesProfileAssemblyTests.swift` remains its helper at `:17-33`: monotonic five-second deadline, cancellable 1 ms suspension, original predicate sampling, explicit cancellation failure, final predicate assertion, and actual call-site reporting. All five test bodies and their safety assertions remain unchanged from e131. This does not explain away the historical failed run or prove a production cause.

## Evidence ledger and outstanding release gates

The following execution status comes from Main/requester messages, not independent reviewer execution or raw-log verification:

- Original export: 3824 executed / 1 failure; subsequent helper-only full suite: **3824 / 0**. That successful suite predates the B1 repair and new tests and cannot certify these repaired bytes.
- `availability-focused-r1` and `cleanup-red-r1`: compilation-only failures, **zero tests executed**. They are neither a test PASS nor a valid behavioral RED. The latest source corrections are inspected here, but compilation success is not inferred.
- Main is retrying the cleanup regression against old-export cleanup in an owned fixture, requiring **eight actual executed tests** before calling it a RED. No result is supplied or certified in this report.
- The root source has not yet been established as identical to every integrated export input. Main must copy/hash the final repair and latest tests, execute the six availability/eight cleanup methods and relevant existing persistence/termination regressions, then execute the fresh full suite serially with actual counts and zero failures. Any subsequent relevant byte change requires a new hash-bound review or explicit follow-up.

The remaining packaging/distribution gates in `Docs/RELEASE_0.1.0_SPEC.md:12-18` also remain Main's responsibility: new exact source commit, clean build, architecture/deployment target, packaged resources, production resolver-only check, metadata/data exclusions, runtime dependencies, archive/hash verification, signing disclosure, and remote tag/asset readback. Prior preview acceptance is historical for the repaired binary.

The previously reviewed production/preview separation, default telemetry/history opt-in behavior, explicit Trash protection, and package copy policy have no additional delta in this scoped comparison. r1's accepted warnings still apply: inward four-finger default ON, private system touch ABI compatibility, chosen lack of Developer ID/notarization, and unverified real installation/upgrade behavior. Neither review selects a license nor supplies legal clearance. No unrelated security or product expansion is required by this r2 source verdict.

## Disposition and ownership

**Source B1 closure: PASS. Additional current source blocker: none identified in scope. Final release acceptance: pending Main's exact integrated evidence and all required gates.** r1 remains historical FAIL for e131; r2 applies only to the hash-bound corrected root inputs above and is not permission to publish an older export or an unverified repaired artifact.

Changed by this reviewer: `Workflow/reviews/RELEASE_0.1.0_PRODUCTION_SAFETY-r2.md` only.

## Follow-up — integrated input freeze binding (2026-10-26)

**Static verdict: PASS retained; B1 is closed in the exact frozen source. No additional in-scope source blocker was found.** This follow-up advances source identity evidence and records Main's newer execution status separately; it does not retroactively alter the earlier evidence ledger or r1 FAIL.

### Freeze identity and exhaustive input comparison

Reviewed manifest: `.build/verification/20261026/release-0.1.0/release-source-freeze-r1.json`.

Manifest SHA-256: `1208c7d7d03ae8e124e59537f160425e3abaeb546a76c294fa8235e27838d5b7`.

The manifest names e131 as its base and declares eight changed paths (`:2-12`). Read-only parsing/hashing found **621 unique input paths, zero unsafe paths, zero missing files, zero current-file hash mismatches, and zero unlisted files** in the scoped source/test/script/resource/package trees. Independent comparison of the manifest hashes with baseline Git blobs again found **613 unchanged, five modified, three added, zero deleted**, with the actual modified/added set exactly equal to `changed_paths`.

All eight delta hashes exactly match this r2 report's previously reviewed table. In the freeze manifest, the layout type/actor/I/O/backend entries are at `:235-252`, AppDelegate at `:471-472`, cleanup tests at `:1327-1328`, AppSources helper at `:1803-1804`, and availability tests at `:2139-2140`. The final factory unresolved-profile guard and all **six** availability tests are included; no earlier five-test or private-property-access variant was substituted. The eight cleanup tests and the corrected helper likewise remain identical to the reviewed bytes. No new implementation diff requires a different source finding.

The B1 reasoning therefore applies directly to the freeze: production resolution errors and unresolved isolation requests select the no-I/O unavailable backend (`AppDelegate.swift:3394-3407`; `UnavailableLayoutStore.swift:3-14`); cleanup remains exact-slot/lock-gated (`LayoutStoreActor.swift:372-379`) and descriptor-anchored/nonrecursive with the previously stated replacement/ancestor limits (`LayoutStoreIO.swift:84-100`). Frozen source identity is confirmed. The manifest contains hashes, not build/test receipts or an export-root binding; this check does not independently prove which physical export or executable Main's active commands consume.

The historical r1 report still hashes to `03f3d70d7e0c4c9b9a19d3bd22c19a6949bae95c816c2d0f203c0737de97dbda` and remains unmodified.

### Main execution status — separate from static PASS

Main/requester now reports a genuine old-export cleanup RED in `cleanup-red-r2`: **eight executed tests, 34 failures, including 24 unexpected failures from removed sentinels**. This supersedes the earlier statement that no valid RED result had yet been supplied. It demonstrates the reported new cleanup regressions discriminate the old implementation in the owned-fixture run; it is not a repaired-source GREEN. The reviewer did not execute the tests or inspect the raw log, so these counts and attribution remain explicitly Main-reported.

Prior `cleanup-red-r1` and `availability-focused-r1` remain compilation-only, zero-execution attempts; they are preserved as such and are not counted as valid RED/PASS runs. The helper-only **3824/0** full result remains historical evidence for the pre-B1 product bytes.

Main reports integrated storage-focused execution, then fresh full execution, then production Release packaging proceeding serially. Completed results for those repaired-source gates have not been supplied in this follow-up. Main must bind their receipts to the 621-input freeze above, retain actual counts/warnings, and complete artifact/provenance/remote readback gates before final release acceptance. No execution result is inferred from the static source PASS, the manifest, the running-work statement, or the old-export RED.

Only this r2 report was updated. No implementation, tests, manifest, stage/specification, or historical review was edited; no tests, builds, UI, network, or publication action was performed by the reviewer.

## Follow-up — two test corrections and final freeze r2 (2026-10-26)

**Bounded static verdict: PASS for both test corrections and their new freeze binding. B1 source closure remains PASS; no B2/product-write defect is asserted by this review.** This is a new, explicitly bounded check of changed test bytes, not a silent extension of the earlier freeze-r1 verdict. Original r1 FAIL and all previously recorded failed/zero-execution attempts remain historical evidence.

### New frozen identity

Manifest: `.build/verification/20261026/release-0.1.0/release-source-freeze-r2.json`.

SHA-256: `b51cb4f2298bce6a2b3892b96bfa0a2414083e852c42bad875ae97ab3cc249b4`.

Read-only comparison found **621 unique inputs**, all matching current file hashes, with no unsafe/missing/unlisted paths. Compared with freeze-r1, there are **619 identical inputs and exactly two changed test files**, no additions/deletions, the same e131 base, and the same declared eight-path delta relative to that base. All production source/script/resource/package inputs, including the journal write primitive, factory unresolved guard, and B1 cleanup implementation, are unchanged. Prior manifest r1 still hashes to `1208c7d7d03ae8e124e59537f160425e3abaeb546a76c294fa8235e27838d5b7`.

| Final test input | New SHA-256 | Freeze-r2 lines |
| --- | --- | --- |
| `Tests/PagingUITests/LayoutStoreAvailabilityTests.swift` | `3b107a90acdeeca5da0b11c26c6f275eb7b5a4ab7974abded8ffac78f14bfcdc` | `2139-2140` |
| `Tests/AppGridUITests/LayoutStoreTemporaryCleanupTests.swift` | `11af1d434b24938eee5fa5930e368a39d26940a0e8af92b8978308c807777de6` | `1327-1328` |

The previous two hashes in the original r2 table apply only to the explicitly named earlier freeze. They are retained as history, not substituted for these final test hashes. To establish exact change scope without assuming old test bytes from a hash list, the reviewer reversed only the described textual edits in memory; each reconstructed file matched its freeze-r1 SHA-256 exactly. No reconstructed file was written or executed.

### Healthy dedicated-store expectation — PASS

The sole new hunk in `Tests/PagingUITests/LayoutStoreAvailabilityTests.swift:77-83` accepts either `.persisted` or `.nothingPending` from flush and reports all other results as failure. This matches the unchanged actor contract: enqueue may start its owned writer (`Sources/AppGridUI/LayoutStore/LayoutStoreActor.swift:95-104`); a successful writer clears the pending layout and marks healthy (`:434-444`); flush with no pending layout returns its terminal rejection or `.nothingPending` (`:119-133`). A successful write completed before flush need not manufacture another `.persisted` receipt.

Acceptance of `.nothingPending` is not sufficient to pass this regression. The unchanged checks at `LayoutStoreAvailabilityTests.swift:84-88` instantiate an independent real `LayoutStoreActor`, load from the same dedicated on-disk directory, require `.loaded`, and compare the restored layout with `layout()`. That fixture uses layout generation 1 (`:23-25`); `PersistentWorkspaceLayout` equality includes generation, top-level order, and folders (`Sources/AppGridUI/LayoutDomain/PersistentWorkspaceLayout.swift:59-70`). A missing/default first-launch result, wrong layout/generation, corrupt/read-only load, or actual failed/timed-out/stale/read-only flush still fails. The envelope's separate writeGeneration remains ignored in this particular reopen pattern, as before; this review does not invent an additional assertion for it. No operation retry, product timing change, writer change, or deleted durable-reopen assertion is present.

### Cleanup URL representation expectation — PASS

The only new cleanup hunks replace three direct `[URL]` equality checks with ordered comparisons of `standardizedFileURL.path` (`Tests/AppGridUITests/LayoutStoreTemporaryCleanupTests.swift:38-39,80-81,108-109`). They still require exactly the two expected slot paths in order; they no longer use NSURL's directory-hint representation as the safety invariant. There is no symlink-resolution step, reduced expected list, or removal of lock/no-enumeration/write-count checks.

All actual regular-file removal, unrelated/near-match file-byte, directory-sentinel, symlink-destination, external-sentinel, no-lock preservation, and durable reset encoding/generation assertions remain byte-identical apart from shifted lines. Representative current checks are at `:31-41,73-88,103-111,247-270`. Thus the correction narrows a representation assertion without dropping the filesystem preservation criteria that detected the old implementation.

### Execution ledger — Main-reported, not reviewer execution

- Preserve the integrated **125 executed / 2 failures** as a failed historical run against prior test expectations. It is not relabeled PASS.
- Main reports the diagnostic **14 / 1** result identified healthy `.nothingPending` after the writer completed, and an owned missing-destination FileManager probe succeeded with target present/source gone. These are Main's reported observations; they do not by themselves prove every FileManager scenario, and this reviewer did not run or inspect the probe. The inspected unchanged flush contract supports the narrower test-expectation correction; no B2 primitive change is introduced or authorized here.
- Main reports corrected cleanup **8 / 0**. This is execution evidence attributed to Main, distinct from this report's static PASS. The old-export cleanup RED **8 / 34**, including 24 unexpected sentinel-related failures, and earlier compile-only zero-test attempts remain retained history.
- Main reports final **125-focused → 3838-full → production Release package** proceeding serially against freeze-r2. Completed final focused/full/package outcomes have not been supplied for this follow-up. No test or package PASS is inferred from planned counts or work in progress.

Final release acceptance remains pending Main's completed, hash-bound integrated receipts and all packaging/publication gates. The reviewer updated only this r2 report, performed no tests/builds/UI/network/publication, and left the original r1 report unchanged at SHA-256 `03f3d70d7e0c4c9b9a19d3bd22c19a6949bae95c816c2d0f203c0737de97dbda`.
