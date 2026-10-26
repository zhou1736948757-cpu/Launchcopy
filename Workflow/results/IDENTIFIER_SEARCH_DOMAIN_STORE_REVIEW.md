# Identifier search domain and store review

Date: 2026-10-15

Verdict: **BOUNDED PASS — source review only.** No actionable correctness defect was identified in the reviewed domain, store, and focused test sources. This does not approve the complete feature or its application-level integration.

Reviewer executed tests: **0**. No Swift invocation, test execution, build, UI operation, application launch, or process control occurred. No compilation, runtime, performance, restart, or native acceptance result is claimed.

## Authority and scope

Read `/Users/mac/.codex/RTK.md`, repository `AGENTS.md`, the approved `Docs/BUNDLE_IDENTIFIER_SEARCH_SPEC.md`, and `Workflow/stage-summaries/2026-10-15-identifier-search-implementation.md`. The stage and human assignment waive Chief dispatch; no agents were invoked or messaged.

The project is SwiftPM/AppKit. Its existing architecture places immutable management values and shared matching in AppGridUI, with injected persistence and a save-before-apply coordinator in PagingPrototypeApp. The review follows that architecture and the approved default-off contract.

Primary review inputs:

- `Sources/AppGridUI/AppManagementPreferences.swift`
- `Sources/AppGridUI/AppSearchMatcher.swift` (existing name-only contract)
- `Sources/AppGridUI/AppGridSearchPresentationController.swift`
- `Sources/AppGridUI/AppGridUIPageContentProvider.swift`
- `Sources/AppGridUI/AppLibraryDomain/AppLibraryProjection.swift`
- `Tests/AppGridUITests/BundleIdentifierSearchPolicyTests.swift`
- `Sources/PagingPrototypeApp/AppManagementStore.swift`
- `Tests/PagingUITests/IdentifierSearchStoreTests.swift`

Supporting reads were limited to `Sources/AppGridUI/AppSearchQuery.swift`, `Tests/PagingUITests/AppManagementStoreTests.swift`, and relevant test-target declarations in `Package.swift`. No moving AppDelegate, settings/localization implementation, external reference implementation/assets, or global memory was reviewed. No dirty-tree change is attributed to a particular contributor. This is an exact-source review, not a broad Git diff review.

Only this report was written. Procedure deviation: the initial read of RTK rules used plain `cat`; every subsequent shell invocation was prefixed with `rtk`. That first read did not modify files.

## Findings and evidence

No blocking findings. The following conclusions are bounded to the source identified below.

| Contract | Source evidence and assessment |
| --- | --- |
| Default OFF and compatible initializer calls | `AppManagementPreferences.swift:10-20` adds a Boolean with a default-false initializer argument and retains `.default`. Existing initializer forms do not opt in. |
| Preserve original-name/alias policy | `AppManagementPreferences.swift:70-77` retains the original name and resolved alias branches before the optional identifier branch. `AppSearchMatcher.swift:25-31` remains a display-name-only literal matcher. |
| Canonical identifier only | `AppManagementPreferences.swift:76-82` reads only the optional `record.bundleIdentifier`, rejects nil/empty identifiers for that branch, and uses case/diacritic/width folding with the query locale and literal substring matching. No AppID/path/URL/category fallback is introduced. Query trimming and folding remain in `AppSearchQuery.swift:27-42`. |
| Hidden exclusion and empty query | `AppManagementPreferences.swift:71` rejects hidden records before all branches. Existing name matching accepts empty normalized queries, so visible records with nil/empty identifiers remain eligible. Canonical and path-based hidden-key continuity remains at lines 35-38. |
| Real consumers and ordering | `AppGridSearchPresentationController.swift:119-121` filters canonical catalog records using the management policy, then maps presentation copies without sorting. `AppLibraryProjection.swift:41-60` uses the same policy, retains canonical records, and preserves the existing alias/name locale sort and path tie-breaker. |
| Same-query grid invalidation | `AppGridUIPageContentProvider.swift:146-148` stages changed preferences. At lines 230-305, pending management is an admission reason, the new preferences are committed, and old pending search results are cleared. `AppGridSearchPresentationController.swift:90-97` reruns the current query after that commit, which increments generation through lines 46-54. This supports the pure grid boundary; it does not establish AppDelegate readiness admission. |
| Alias presentation and copy retention | `AppManagementPreferences.swift:48-59` copies only the displayed name while retaining ID, bundle identifier, URL, icon identity, root priority, and bundle metadata. Hide/alias transformations at lines 86-111 copy `self`, retaining either Boolean value and unrelated metadata. |
| Required schema-2 Boolean | `AppManagementPreferences.swift:7-17` uses synthesized Codable with a nonoptional stored Boolean and no custom defaulting decoder. A default initializer argument does not supply a missing decoded field. `AppManagementStore.swift:59-64` decodes schema 2 through that type and validates existing metadata afterward. |
| Schema 1 compatibility, no autonomous write | `AppManagementStore.swift:35-41,49-65` decodes legacy hidden keys and aliases separately, constructs the default-off value, validates it, and performs no write during load. Missing payload returns defaults without writing. |
| Corrupt and bounded payloads | `AppManagementStore.swift:50-52,57-64` rejects wrong stored types, oversized payloads, malformed JSON/header, malformed legacy/current preferences, and invalid metadata. Schema-2 missing/wrong Boolean is a decoding failure, not a silent OFF value. |
| Future schema protection | `AppManagementStore.swift:53` recognizes versions greater than 2 before attempting current-shape decoding. Save at line 68 and the toggle at lines 127-129 reject those versions, preserving the payload. The existing 1 MiB load bound still precedes version dispatch. |
| No implicit corruption repair by the toggle | `AppManagementStore.swift:124-135` reloads the actual store, rejects corruption/future versions, rejects a different current baseline, and derives the draft from committed metadata. Existing direct `save`/generic `apply` repair semantics remain; those are not evidence that the new toggle repairs corruption. |
| Save failure and receipt boundary | `AppManagementStore.swift:111-121` commits and invokes the callback only after `.saved`. Lines 72-75 acknowledge bounded encoding and `UserDefaults.set`; they do not implement fsync, process-restart proof, or a durable Quit receipt. The toggle does not introduce another persistence owner. |

The inspected matching/projection/store paths add no query history, query/identifier logging, network activity, metadata scan, icon loading, or frame callback. This is a local source observation, not an application-wide privacy/performance certification.

## Test-source assessment

**12 domain methods and 5 identifier-store methods were inspected; none was executed.** `Package.swift:65-69,83-87` declares the existing PagingUITests and AppGridUITests targets without an explicit source list excluding these files. Actual discovery and execution still require Main's nonzero test evidence.

- `BundleIdentifierSearchPolicyTests.swift:21-46` exercises the actual grid controller/provider idle boundary and actual Library projection. Expected record membership/order is supplied by each test; the helper does not generate expected membership by invoking the matcher under review. Its use of `presentationRecord` for expected grid copies is supplemented by independent field-by-field identity assertions at lines 189-197.
- Lines 48-119 distinguish OFF misses, original/alias hits, ON literal identifier hits/misses, locale folding, and nil/empty identifiers. The deliberately mismatched AppID and canonical identifier at lines 108-116 make fallback regressions observable. Synthetic punctuation/full-width identifiers are intentional matcher fixtures; they are not scanner or real-app claims.
- Lines 121-148 cover both hidden key forms, both policy values, whitespace queries, and visible records lacking identifiers. Lines 150-178 assert staged-versus-published state, unchanged query/catalog, and a new generation for the same query after each applied toggle.
- Lines 181-227 check different grid/Library orders, alias display, canonical metadata, immutable copies, and unrelated hidden/alias retention. Lines 230-259 check JSON/plist round trips and required decoding. Missing-field decoding specifically checks `DecodingError.keyNotFound`; malformed flag cases contain otherwise complete preference objects with valid JSON flag tokens. They do not pass merely because a fixture is unparseable JSON.
- `IdentifierSearchStoreTests.swift:8-12` uses a unique injected UserDefaults suite with teardown, rather than the formal suite. Lines 15-24 compare literal schema-1 bytes before/after loading. Lines 26-43 inspect the saved schema number/Boolean, retained metadata, callback, and same-process reload. The test explicitly disclaims process-restart durability.
- Lines 46-59 explicitly parse malformed-flag fixture JSON before checking `.corrupt`, failed toggle, and unchanged bytes. Thus missing/wrong flags are tested inside valid envelopes. Lines 62-71 use a valid schema-3 header with an unknown body, test both toggle values, and require unchanged bytes.
- Lines 74-105 use a stateful store double that changes its value only on successful save. The failure/retry test checks committed state, absent callback on failure, preserved alias metadata, externally changed hidden metadata, and an exact save-call count. The double does not fabricate a successful production reload or disk guarantee.
- Supporting `AppManagementStoreTests.swift:35-99,111-205` supplies existing missing-payload, corrupt/invalid/oversized/future protection, save-before-callback, failed save, no-op, and explicit-repair assertions. Its relevant JSON fixtures are structurally valid when intended to isolate version/metadata failures. No skip, empty test, conditional no-op, or swallowed assertion-producing error was found in the two new files.

## Residual risks and recommendations

These are evidence limits or targeted coverage improvements, not newly established production defects.

1. **Application-level safe admission remains unreviewed.** A pure controller test explicitly calling an idle boundary cannot establish gesture/editor/marked-text/menu/sheet/restore/Quit behavior, open-folder preservation, selection preservation, obsolete asynchronous Library completion rejection, or queued-versus-effective settings behavior. Main must finish and freeze its idle-policy integration before a separate bounded review and execution evidence. Worker2 settings/localization is also excluded.
2. **Schema-2 metadata regression coverage could be more direct.** The new file directly tests flag corruption; existing invalid-key/alias fixtures at `AppManagementStoreTests.swift:59-60` use schema 1. The common validation at `AppManagementStore.swift:64` is correct on inspection. Recommended additional fixtures: valid schema-2 envelopes with a valid Boolean but invalid hidden key/alias, missing/wrong-type existing fields, plus malformed/oversized stored payload toggle attempts; require no callback and exact payload preservation. Also consider checking schema-3 rejection through direct store save, supplementing the existing version-9 direct-save test.
3. **Persistence remains an acceptance receipt.** The new store test's reload is within one process. Main still owes isolated normal Quit/fresh-process reopen evidence for the same candidate before calling persistence accepted. Do not reinterpret `.saved` as a stronger receipt.
4. **Baseline checking is not an interprocess transaction.** `AppManagementStore.swift:127-135` protects a detected different loaded value. Separate UserDefaults reads and writes do not establish atomic compare-and-swap against another process; no such guarantee was proven or added to the approved contract.
5. **Execution and performance gates remain open.** Main owns compilation, nonzero focused/full tests, candidate/package verification, native behavior, and matched performance evidence. No synthetic source review result closes those gates.

Confidence: high for the inspected pure matching, value-copy, schema dispatch, and coordinator ordering logic; test behavior and application integration remain unexecuted/unreviewed as stated above. No implementation repair is recommended on the current bounded evidence.

## Reviewed source fingerprints

SHA-256 fingerprints were captured after source inspection and rechecked before report completion. They identify the bounded inputs, not the complete dirty tree or a packaged executable. Supporting reads are not a certification of other files.

```text
9cd2eb84398c79283b9819b3dc5fd23ba8997c2a93d42c6d9e8146e5d5d29890  Sources/AppGridUI/AppManagementPreferences.swift
a0a8d765fb658c18b40d60ceaaa19ebeb671cc7a9f40a6e6e0fc53e6930d5a18  Sources/AppGridUI/AppSearchMatcher.swift
8344e01e5cb28f032c51097a7fcfda1b0868b36978b2490b5e0d3436989d8628  Sources/AppGridUI/AppGridUIPageContentProvider.swift
361beac3483c812c227ca3bed4dc27c90ee5124550f2a6736217569082377e47  Sources/AppGridUI/AppGridSearchPresentationController.swift
a4163c7976402cfe43d2a57408a31d4370503d734f4b9bb9692914e6a90d4c92  Sources/AppGridUI/AppLibraryDomain/AppLibraryProjection.swift
0cbe5c3bccadfb1b6f90b508d6c549f26a2ba1882311c86966a45213262d2e67  Sources/PagingPrototypeApp/AppManagementStore.swift
4f0a1b49173f817f6b059799ae1ee3c5e9dfaf9619106949ce5513de169526c3  Tests/AppGridUITests/BundleIdentifierSearchPolicyTests.swift
475031f7b10de99aeb2d7902f07195435e57d148b31fafa824e28928fd680a07  Tests/PagingUITests/IdentifierSearchStoreTests.swift
e0731672d3c4e424f81edbe1afd7ae219de1177542897e0540ffe72818dade3a  Tests/PagingUITests/AppManagementStoreTests.swift
```
