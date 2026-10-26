# MIXED_ANCHOR_ORDER — Independent bounded review r1

Date: 2026-10-20

**Verdict: PASS for the frozen production-source change and regression-test correctness/design. No actionable findings.** This is an independent source/test review plus inspection of Main-produced execution evidence. It is not independent runtime/UI acceptance or whole-project acceptance.

## Scope and authority

Reviewed `Docs/MIXED_ANCHOR_ORDER_SPEC.md`, the three production files and `Tests/AppGridUITests/MixedAnchorRemappingTests.swift`, original copies in `.build/verification/20261020/mixed-anchor-order/`, ADR-004 and ADR-008. Inspected the provider's existing public/layout projection seams only as necessary to validate test setup. Production architecture remains Swift package domain types in AppCatalogCore, with mixed presentation/remapping in AppGridUI and XCTest regression coverage.

During Main's temporary baseline replay, review used only the immutable `review-inputs/` packet and supplied baseline copies. After Main's explicit normal-restoration notice, all five current inputs were independently rehashed and matched the packet. The frozen packet also matches the source/test content inspected before replay. No additional agent was dispatched; Chief/Chef was bypassed as explicitly instructed.

ADR-004 decision 7 establishes the five-level degradation and forbids reliance on old array positions. ADR-008 §2.4 and question 3 extend that mechanism to mixed entries; §2.5's stable catalog order governs fixture grouping. Neither ADR mandates folder-before-app identity rank. Existing folder-first default **presentation composition** is a separate concern and remains unchanged. The old provider comments contradict its actual cross-kind branches; those comments are not treated as approval or authoritative policy. No conflict with ADR-004/008 was found.

## Source checks

- AppID's existing `anchorOrderLessThan` implementation is reused exactly. Its sole functional declaration change is `fileprivate` to `public`, required across the AppCatalogCore/AppGridUI target boundary. Bundle-ID variants precede canonical-URL fallback variants; each variant compares its stored strings lexically. No AppID `Comparable` conformance, raw-storage accessor, reflection, diagnostic identity output, or new hashing behavior is introduced (`AppCatalogCore.swift:40–52`).
- FolderID adds only an internal Boolean comparison of canonical `UUID.uuidString` values in memory. The stored UUID, synthesized identity/hash behavior, initializer and redacted description are preserved; no UUID/name/path getter or logging is added (`FolderDomain.swift:30–55`).
- `identityOrder` preserves the byte-identical `.app/.folder` ascending and `.folder/.app` descending branches. Same-kind equality is checked explicitly, then the appropriate strict predicate determines direction. This is deterministic and does not use hash values (`AppGridUIPageContentProvider.swift:476–489`).
- The entire `remapComposition` body is byte-identical to baseline: empty first; app-only delegation; nil clamp; equal surviving anchor lookup; FIRST greater entry in CURRENT array; otherwise LAST lower entry; otherwise page-zero clamp. There is no sorting or semantic-minimum/maximum successor/predecessor search. App-only delegation still projects a vanished folder anchor to nil (`:446–473`, `:497–500`).
- Independent in-memory inverse reconstruction of all three frozen files exactly reproduced the baseline bytes after removing only the declared edits. AppID predicate body and cross-kind branch bytes were separately compared. This corroborates `source-boundary-proof.json`; no inference from that receipt alone was required. All other regions in these three files, including workspace projection, durable/latent order handling, generations, search and counts, are unchanged. No claim is made about unrelated dirty-tree history.

## Regression-test checks

All 10 methods use existing public provider/domain APIs, ordinary imports and synthetic records/fixed UUID fixtures. They do not call the new predicate, use `@testable`, read hash values, sort to construct an oracle, access real applications, perform filesystem work, or operate windows. The exact same test file compiled and executed against the original three production files in Main's replay, confirming baseline API compatibility beyond static inspection.

Capacity is two items, with explicit expected outcome enums and page indices. Tests genuinely remove the anchor app or both anchor-folder members from the new catalog; unchanged expected layout retains the missing entries as latent references. Thus missing-anchor paths are exercised rather than accidentally locating an appended unarranged app.

| Coverage | Independent expected result / distinguishing assertion |
| --- | --- |
| Missing bundle anchor, arbitrary mixed order (`:106–112`) | `.successor(pageIndex: 2)`; the semantic minimum successor is on page 3, so reordering or minimum selection is detectable. |
| Missing fallback-path anchor (`:114–120`) | `.successor(pageIndex: 2)`; exercises lexical fallback comparison and bundle variants ranking below fallback IDs. |
| Bundle/fallback variant rank (`:122–128`) | `.successor(pageIndex: 2)` with an early lexical fallback fixture; expectations are literal, not comparator-derived. |
| Missing folder successor (`:130–137`) | `.successor(pageIndex: 3)`; a smaller greater UUID appears on page 4, distinguishing CURRENT-array first match. Early app entries also check app-before-folder rank. |
| Missing folder predecessor (`:139–145`) | `.predecessor(pageIndex: 3)`; the semantic maximum lower folder is on page 0, distinguishing LAST lower. |
| Missing app with only lower surviving apps (`:147–150`) | A late folder is `.successor(pageIndex: 2)`, directly checking the existing cross-kind policy. |
| Surviving app and folder anchors displaced (`:152–167`) | Both locate on page 2 after an explicitly supplied layout reorder. The result follows new composition, not the old page. |
| Nil and empty precedence (`:169–195`) | Mixed nil anchor clamps to page 0; nonnil and nil empty states yield `.emptyCatalog` and zero items/pages as asserted. |
| App-only successor/predecessor (`:197–216`) | Literal page-2 successor/page-3 predecessor expectations, then additional equality with CatalogPlanner's outcome and all PagePlan fields. Planner parity is supplementary, not the sole oracle. |
| Last folder disappears into app-only composition (`:218–229`) | Literal page-zero clamp, nil app anchor, and additional parity with CatalogPlanner receiving nil. |

The shared state checks (`:56–103`) assert complete expected-layout equality, canonical and visible identity sequence equality, app-only projection order, folder member order, page counts, retained pre-commit presentation and post-commit state. They use fixture input sequences directly. These checks cover unchanged saved layout and arbitrary presentation order; all substantive missing-anchor outcomes span several pages. Missing-app predecessor coverage appropriately uses app-only delegation because every surviving folder ranks above every app and would instead supply a mixed successor.

## Execution evidence inspected — Main-owned

The reviewer did not run SwiftPM, launch UI, swap production files, build/package, use Git, send signals, access source-reference/formal data, or modify runtime/workflow state. The only written file is this report.

- `existing-focused.log`: terminal XCTest count **66 tests, 0 failures**.
- `new-focused.log`: terminal XCTest count **10 tests, 0 failures**. The separate trailing Swift Testing zero-test banner is not counted as evidence.
- `old-1.log` through `old-6.log`: each executed 10 XCTest methods, with assertion failures **[6, 6, 6, 4, 4, 5]**, total **31**, and zero unexpected failures. Actual failure-count variation was observed. For example, old run 1 returned successor page 0 instead of page 2 for the bundle case, and predecessor page 4 instead of successor page 3 for the folder-successor case.
- `current-1.log` through `current-6.log`: each executed **10 tests, 0 failures**, for 60 test executions. All 12 terminal counts match their job receipts and exit-status consistency checks in `fresh-process-proof.json`.
- Inspected `run-fresh-process.py`: six separate test subprocesses per variant; builds the first run for each variant, then skips rebuilding; removes only a child `SWIFT_DETERMINISTIC_HASHING` override if present; selects no seed; restores captured current source bytes in `finally`. Receipt `child_hash_override_removed: false` means no inherited override required removal, not that deterministic hashing was enabled.
- `restoration.json` records byte-exact three-file restoration; post-notice current hashes were independently verified against the frozen manifest. `fresh-process-proof.json` reports completed replay PASS. This corroborates the defect and correction under the observed processes; it does not prove every possible seed or an independent runtime acceptance result.

Main's later final focused/full suite, Debug/Release unsigned packaging/diff, and any runtime/human acceptance are outside this review verdict and are not inferred from these results. There is no source/test blocker for Main to continue those gates.

## Frozen input identity

Packet directory: `.build/verification/20261020/mixed-anchor-order/review-inputs/`.
Manifest: `review-inputs.json`, SHA-256 `e7e15b284412a0246ae29adadb219ee8b306eb141b32ce88b5339efb679b97e9`.

| Original input path | SHA-256 of reviewed frozen bytes |
| --- | --- |
| `Sources/AppCatalogCore/AppCatalogCore.swift` | `e0ebb6ad00cab56aa4258361d7ac9ec3c0e035154046ad0b31ebacb3561c6f76` |
| `Sources/AppGridUI/FolderDomain.swift` | `c6d92bb2ce4219ce5c21971d2c8b902f0b003a13ecf43d81a47d63ea0c8672c5` |
| `Sources/AppGridUI/AppGridUIPageContentProvider.swift` | `9e0472a62cef716c5216488ecee5445cd3dc933ec68a43eb6b306e3cb60bfd61` |
| `Tests/AppGridUITests/MixedAnchorRemappingTests.swift` | `8bc574ed14a92b49aea5ebdcdb175828df2212f1b321dfe26fd4192f4ecd9677` |
| `Docs/MIXED_ANCHOR_ORDER_SPEC.md` | `7428817bdb16a134d821de6b22ccdb74e3d2e43c47bd1bdc851d7128fd2f2ff8` |

Original baseline SHA-256 values, independently checked during inverse reconstruction:

| Baseline copy | SHA-256 |
| --- | --- |
| `AppCatalogCore.baseline.swift` | `c9d975bead373ad41ddf66d76099174e1e371e6493b7a5f6fc2fa35c8dc684dd` |
| `FolderDomain.baseline.swift` | `d3b14110242eb0a93b82e9ba97725b0f9a2ce84e07f97de62336dc12fd8253a3` |
| `AppGridUIPageContentProvider.baseline.swift` | `8344e01e5cb28f032c51097a7fcfda1b0868b36978b2490b5e0d3436989d8628` |

Execution receipt identity: `fresh-process-proof.json` SHA-256 `535c5692be0a00b2447cf747952a24a15ca335b6b53615943d41ddb0be814e0c`; `restoration.json` SHA-256 `6a0de945772c8a16a3b889ea6fbfa01cfd138a6de0230412c088380eb364d464`.

Confidence: high for this bounded source/test verdict. Any change to a frozen input requires checking the changed scope again; this report does not approve future edits.
