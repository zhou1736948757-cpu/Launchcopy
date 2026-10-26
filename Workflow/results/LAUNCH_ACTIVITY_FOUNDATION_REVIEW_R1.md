# Launch Activity Foundation Source Review R1

Date: 2026-10-18
Verdict: **PASS — bounded source evidence only**

## Findings

No concrete P1/P2 finding was identified in the assigned foundation scope. This verdict does not certify compilation, test execution, integration, native behavior, or performance.

## Scope and authority

Reviewed the new pure activity document/projection, file store, storage routing, and relevant domain/store test source against the approved Recent/Frequent contract. The project is a Swift/macOS application; the reviewed boundary is the pure AppGridUI domain and the actor-backed local persistence adapter reusing existing AppLibrary file I/O.

The direct review assignment overrides workflow ceremony and assigns exactly one writable path: this report. No subagent was dispatched. Main retains launch admission/deduplication, owner generations, coordinator integration, Quit, UI, compile/test, and native verification ownership. Those implementation areas were not independently audited here.

## Exact inspected inputs

All repository paths below are relative to `/Users/mac/Projects/Launch_Copy/PagingPrototype`.

Rules and approved contract, read in full:

- `AGENTS.md` — SHA-256 `6928c4ebd8edcabc637e028d24790450a052b739117f0b0ef9f6ad6b45b7bcfc`.
- `Docs/LIBRARY_LAUNCH_ACTIVITY_PROPOSAL.md` — SHA-256 `5b0bf641dd990453c0750a151f7428b6b129b69112b03100051b4c760257925f`; includes the explicit approval and UTC clarification.
- `Workflow/stage-summaries/2026-10-18-library-launch-activity.md` — SHA-256 `f637c6bee1e2575b6361c66e4d17f270748e4008fd591cba287f7f10686c0f0f`; observed status `IMPLEMENTATION_IN_PROGRESS`.
- External shell rule `/Users/mac/.codex/RTK.md`, read in full. All shell invocations used the `rtk` prefix.

Frozen review metadata:

- `.build/verification/20261018/library-launch-activity/source-integrated-r1.json` — 500 path/hash entries; SHA-256 `314f5037f7d1ad94bfb4a547b93449440d1945c3e51f9cbb5c573afbbdd010b6`.
- `.build/verification/20261018/library-launch-activity/input-delta-r1.json` — SHA-256 `3f756b68098abcf48e3cf6fde5552b27ed910358d1002958f21521a3cbee3f6b`; identifies 15 changed, 12 new, and zero removed inputs.
- The manifest was parsed for scoped hash comparison. No whole baseline diff or Git operation was used.

Primary inputs, read in full; each observed SHA-256 matches its frozen manifest entry:

| Input | SHA-256 |
| --- | --- |
| `Sources/AppGridUI/AppLibraryDomain/LaunchActivity.swift` | `3c7955320288c378698c9ef6e68476766b5709262d016d48e078b3f9daa8d2ff` |
| `Sources/PagingPrototypeApp/LaunchActivityStore.swift` | `112162ddd24fc8095717dcd8bf42ab0d5896c301c3d0bf83ae9e875c5ec7216b` |
| `Sources/PagingPrototypeApp/LaunchActivityStoreLocation.swift` | `98ffdc83412be77e316bcf5d129e308ff59eea688c1207dc5e0a8a2deda90b6b` |
| `Tests/AppGridUITests/LaunchActivityTests.swift` | `ec1b31ae6ed6a79a8c3599071ab9473369e28104dd48d775371ae268e2604e31` |
| `Tests/PagingUITests/LaunchActivityStoreTests.swift` | `67e20dd6563ec00da540f640df114da58f82447e73e15d3343da189322e9b6a9` |

Supporting inputs, with bounded reading as stated; each full-file hash matches the frozen manifest:

| Input and inspected extent | SHA-256 |
| --- | --- |
| `Sources/PagingPrototypeApp/AppLibraryStore.swift`: lines 1–170 and 210–end, plus helper/I/O symbol search | `0bd23d3c568c3a98e267cfff018780f6c9619b69bc7bb785780e8256319681c7` |
| `Sources/AppGridUI/LayoutDomain/PersistentAppReference.swift`: full file | `7cab7e498db96fdec154f4cffa6d56d3be3f5296eb96666c0d2729b26d18dda9` |
| `Sources/AppGridUI/AppLibraryDomain/AppLibraryProjection.swift`: full file | `a4163c7976402cfe43d2a57408a31d4370503d734f4b9bb9692914e6a90d4c92` |
| `Sources/PagingPrototypeApp/AppLibraryStoreLocation.swift`: full file | `27358099b471e7cdbbda1c3c3061fd64937ad7769af5b2b2e74d795436943bbe` |
| `Sources/PagingPrototypeApp/UITestProfile.swift`: lines 1–115 for validated profile/root and activity-directory context | `bea67f46a1af898845c8c8d853468eed18f080b850c076b8a9ac922949226c1a` |
| `Tests/PagingUITests/AppLibraryStoreLocationTests.swift`: full file, existing routing convention | `a19bf06c5a8a66264de91266939896966dd51d5b5c4d35bc5ad3361fdf9f96dd` |
| `Tests/PagingUITests/LaunchActivityCoordinatorTests.swift`: location-symbol search and lines 165–195 returned; only `testStoreLocationFailsClosedAndKeepsSeparateFeatureDirectory` assessed | `17409ff3b16f1e839c9cf762a64668c365b50616ee2214828125881071176814` |

Repository file discovery and a test-directory search for `LaunchActivityStoreLocation` were also performed. Incidental adjacent owner/UI tests in the last excerpt were not an integration audit. The assignment's statement that existing AppLibraryStore changes consist only of two helper access levels is the baseline premise; no historical diff claim is made.

## Source evidence supporting PASS

- **Identity and privacy:** `LaunchActivity.swift:34–57,146–158` supplies an independent default salt, reuses `PersistentAppReference.from(record:)` for bundle identity, and hashes the normalized path fallback with that salt. The persisted domain contains consent, salt, stable keys, timestamps, and daily counts; no raw fallback path or display name is serialized. Key validation rejects raw-path key forms and path separators. Domain tests explicitly cover moved bundle identities, profile salt differences, path normalization, and encoded path/name exclusion.
- **Bounds and deterministic ranking:** `LaunchActivity.swift:27–32,62–109,137–143` bounds identities at 256, buckets at 30, and daily counts at 1,000,000. Accepted updates prune before and after incrementing, saturate counts, and evict oldest identities with stable-key ties. Recent uses latest request then key; Frequent uses in-window total, latest request, then key. Maximum totals remain within the target's 64-bit integer range.
- **Filters before limits:** `LaunchActivity.swift:112–128` maps the already-filtered snapshot to identities, suppresses repeated catalog identities, then selects the first 12/8 eligible matches from the full ranking. It preserves effective entry labels/categories, revision, and counts. `AppLibraryProjection.make` supplies the existing management/query/category projection. Test source covers hidden/unavailable leaders, aliases, queries, dormant records, and duplicate catalog instances. Correct owner provision of that base snapshot remains Main's integration responsibility.
- **UTC and clocks:** `LaunchActivity.swift:74–103,131–143` uses epoch-day division by 86,400, keeps today through day minus 29, excludes future entries from ranking, and removes a future entry as a whole during pruning after clock rollback. Invalid/nonfinite/out-of-range clocks do not record or prune. `LaunchActivityStore.swift:68–103` decodes without consulting the wall clock, leaving pruning and resulting persistence receipts to the owner. Boundary, midnight, rollback, invalid-clock, and preserved-expired/future-load scenarios are present in test source.
- **Payload protection:** `LaunchActivityStore.swift:46–103` validates before I/O; reads at most the configured bound through the shared adapter; protects future, ambiguous, duplicate-key, non-UTF-8, and oversized data even during recovery; requires explicit recovery for corrupt data; enforces exact supported object fields and canonical integer day-key spelling; then requires successful typed decoding and domain validation. Shared duplicate-key scanning decodes escaped key spellings at every object level before Foundation selects a value. Tests contain nested/escaped duplicates, numeric day aliases, schema variants, count/cap violations, and unchanged-byte assertions.
- **Existing I/O reuse and save receipts:** `LaunchActivityStore.swift:34–65` directly uses `LocalAppLibraryFileIO`, including expected-byte replacement, and returns `.saved` only after replacement returns successfully. The inspected shared implementation uses descriptor-relative no-follow access, regular-file checks, a cooperative lock, compare-before-replacement, namespace revalidation, and synchronization. Both payload byte bounds are 1,048,576. Existing arbitrary-writer limitations remain explicit; no stronger transaction guarantee is inferred. Test source covers read/write failures, indeterminate replacement/retry, unsafe targets/ancestors, cooperative contention, changed future bytes, and namespace swaps.
- **Separate local namespace and noncreating load:** `LaunchActivityStoreLocation.swift:5–10` routes resolved profiles into their own `LaunchActivity/activity.json`, rejects unresolved requested profiles, and admits only local file URLs for the application-support branch. It performs URL construction only. `LaunchActivityStore.swift:39–43` calls shared read; shared `AppLibraryStore.swift:41–44,120–143` opens with `create: false` and returns missing without directory creation. Store tests explicitly describe missing-load noncreation and independent envelope/permissions checks.

## Execution boundary and disposition

No application, build, compiler, XCTest, test fixture, UI, reference, formal-data, OS-setting, signing, installation, or Git action was executed. Activity stores were not instantiated or called. Test assertions were inspected as source only; no executed-test count or runtime result is claimed. Read-only text/search/JSON/hash tooling and the write of this report were the only review operations.

No source or existing evidence artifact was edited. No failed build/test/runtime attempt was rerun, deleted, overwritten, or reclassified. The only authored file is `Workflow/results/LAUNCH_ACTIVITY_FOUNDATION_REVIEW_R1.md`. Main's serial compile/tests and separate integration review remain independent gates.

## Closing input stability observation — 2026-10-18

The initial inspected hashes above matched the frozen manifest. A closing comparison found 11 of the 12 scoped source/test files still matching, including all five primary inputs and all seven supporting files except `Tests/PagingUITests/LaunchActivityCoordinatorTests.swift`. That supporting test file had changed to SHA-256 `ac4c53a4f0beb73c07dc3db0c0a972cb5feb8c49f394476f66d98d3802d452f4`. Its location-only test at lines 175–181 was reread and remains textually identical to the initially inspected excerpt.

The frozen R1 PASS is retained for the assigned foundation source; the changed coordinator test file as a whole is outside this verdict. This is not certification of a later integrated tree. Main must capture changed integration inputs in a new bundle/review attempt before applying any whole-tree conclusion. The observed hash mismatch is preserved here rather than represented as a successful whole-tree stability check. No build/test result was consumed or altered.
