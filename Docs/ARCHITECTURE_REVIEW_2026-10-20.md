# Dated shared-JSON follow-up — 2026-10-20

The historical P3 Activity-to-concrete-Library lexical-helper coupling is closed. An internal Foundation-only namespace now owns the exact81-line shared block; two consumer inverse reconstructions and four qualified call sites prove no policy redesign. Original and extracted stores each passed identical5-method/36-input corpus; focused40/0, full3381/0, Debug/Releasepackage/diff and bounded independent source/test-sourcePASSr2. Schema/body/recovery/I/O/clock/default policy remains feature-owned; no JSON-validator/security/performance claim. See Docs/JSON_INSPECTION_OWNERSHIP_SPEC.md and Workflow/results/JSON_INSPECTION_OWNERSHIP_RESULTS.md. First Library hitch user-deferred/non-blocking, CPU unproven. Full parity/native/device/functional gates and broader architecture concerns remain separate.

# Dated mixed-anchor follow-up — 2026-10-20

The historical P2 hash-ordered missing mixed anchor is closed for stable-domain recovery. Reused AppID predicate and internal folder UUID comparison preserve actual app-first rank, current-array first/last qualification and exact app-only behavior without sorting or saved-order rewrites. Ten multi-page baseline-compatible public-provider methods, old six-process 31 assertion failures with observed variation, repaired six-process 60/0; final focused 76/0, full 3376/0, Debug/Release package/diff and independent bounded source/test-source PASS r1. Source/body/cross-kind preservation and byte-exact restoration checked. See Docs/MIXED_ANCHOR_ORDER_SPEC.md and Workflow/results/MIXED_ANCHOR_ORDER_RESULTS.md. No native/performance/full-product acceptance; user-deferred Library hitch remains non-blocking, CPU cause unproven. Other findings/gates remain open.

# Dated diagnostic-state follow-up — 2026-10-20

The historical P2 unsynchronized public diagnostic getters is closed for CatalogRepositoryDataSource timing and TelemetrySession status. Existing NSLock/serialqueue ownership now covers both writes and public reads, with coherent small value snapshots and one Bridge timing capture. No recursive queue getters or frame buffer copies. Final focused85/0/full3366/0/Debug/Releasepackage/diff, targeted linked-runtime TSan9/0/no reports, bounded source/test-sourcePASSr1. Exact inverse proofs preserve clocks/generation/stamp/log/default/capacity behavior. See Docs/DIAGNOSTIC_SNAPSHOT_OWNERSHIP_SPEC.md and Workflow/results/DIAGNOSTIC_SNAPSHOT_OWNERSHIP_RESULTS.md. This does not establish historical-revision timing attribution, universal race freedom, native/physical/performance or first-hitch causality. Other findings/gates stay open; full parity incomplete.

# Dated gesture takeover follow-up — 2026-10-20

The historical P2 “gesture takeover continues after reentrant interruption/stale callbacks” is closed for the specified stale/interruption/interrupted-state continuation: same-token/session/state ownership guards and caller Boolean gate. Exact two-region inverse preserves all other Core bytes/physics; all other existing inputs unchanged. New9XCTestmethods; selected old3RED/140failures, old/current normalcontrol1/0 each. Final focused 235/0/full 3357/0/Debug/Releasepackage/diff and independent bounded source/test-sourcePASSr1. See Docs/TAKEOVER_REENTRANCY_SPEC.md and Workflow/results/TAKEOVER_REENTRANCY_RESULTS.md. This does not certify general environment/completion callback compositions or physical behavior; other open findings remain open. Full parity incomplete, firstLibraryhitch user-deferred, not CPU-proven/fixed.

# Dated icon source follow-up — 2026-10-20

The historical P2 “same AppID winning at another source can reuse old icon content” is now closed for committed URL add/remove/change: targeted cache/in-flight/queued-delivery invalidation, served authority and actual refresh/root-search source wiring. Final focused105/0/full3348/0/Debug/Releasepackage/diff, independent bounded source/test-sourcePASSr2. Positive old-finish acknowledgment and loadID mutationRED verify replacement listeners/cache; same-URL/unchanged identities retain cache hits. See Docs/ICON_SOURCE_INVALIDATION_SPEC.md and Workflow/results/ICON_SOURCE_INVALIDATION_RESULTS.md. No native icon/performance, same-path content-update or NSWorkspace-cache certification. Other old open findings remain open unless dated supersession explicitly says otherwise; full parity incomplete.

# Dated lifecycle follow-up — 2026-10-20

The journal initialization/reset P1 listed OPEN in the historical first-wave table below is now implemented and independently source/test-source reviewed (r4PASS). Final focused 106/0/full 3336/0; twelve new lifecycle methods and discriminating old-baseline/mutation RED evidence. Shared initialization, FIFO reset barriers/epoch-fenced old drains, successor retention, flush receipts, unique archives and validated-peer high water are covered. No public signature/schema/default/physics change; automatic tests use only memory/owned temporary fixtures, no user reset. See Docs/JOURNAL_LIFECYCLE_OWNERSHIP_SPEC.md and Workflow/results/JOURNAL_LIFECYCLE_OWNERSHIP_RESULTS.md. This closes that bounded source contract, not all persistence/cross-process/native/performance concerns. Other listed open findings remain OPEN. User-deferred first-entry hitch is not a blocker or verified CPU-caused/fixed.

# Whole-code architecture review and first optimization wave

Date: 2026-10-20. Status: implementation complete; independent source follow-up and final serial/native verification in progress. This is a repository-wide inventory and risk-focused review, **not** a claim that every line or possible interleaving has been certified.

## Scope and evidence
The baseline contains217 production Swift files /45,785lines across ten SwiftPM targets, with AppDelegate at5,255lines. Baseline per-file hashes and inventories are retained under `.build/verification/20261020/architecture-review/`. Two disjoint auditors covered domain/presentation and catalog/services; Main covered composition/UI/build integration and selected concrete changes. Detailed depth/coverage and evidence are in `Workflow/reviews/ARCHITECTURE_DOMAIN_AUDIT.md` and `ARCHITECTURE_SERVICES_AUDIT.md`. Main's targeted deep paths: AppDelegate startup/library/lifecycle/window-input block, AppLibraryOwner/View/Gallery/Search, leading presentation, package/test entry, and the selected codec/actor boundaries. Other app views/activation/backends were inventoried and traced at their boundaries rather than all being deeply reviewed. No external reference implementation was read.

| Baseline target | Swift files | Lines |
| --- | ---: | ---: |
| `AppCatalogCore` | 2 | 535 |
| `AppGridUI` | 58 | 10,174 |
| `AppIconPipeline` | 5 | 710 |
| `LauncherLocalization` | 17 | 1,411 |
| `LocalizationResourceProbe` | 1 | 79 |
| `MacAppCatalog` | 7 | 592 |
| `PagingCore` | 6 | 1,313 |
| `PagingPrototypeApp` | 104 | 26,916 |
| `PagingTelemetry` | 4 | 732 |
| `PagingUI` | 13 | 3,323 |

## Overall assessment
The declared module dependency direction is useful and currently coherent: pure paging state and catalog identity, AppKit paging/presentation adapters, then the application composition root. Existing generation gates, accepted-write receipts, shared icon pipeline, injected I/O, localization snapshots and independent test profiles are assets to preserve. Do not replace them with a generic architecture framework.

The main maintainability pressure is responsibility concentration and feature-to-feature policy duplication. AppDelegate mixes startup/services, folder/drag/search interaction, optional Library, settings/language, teardown, native window routing and diagnostics. Logical workspace/drag/Library domains are mostly value-oriented but share the AppGridUI package target. File splitting helps discoverability, not complete state ownership separation. Large settings/folder/Library views remain future presenter seams; their different layout/input contracts should not be forcibly unified.

## Implemented bounded improvements

| Change | Concrete maintenance / correctness benefit | Boundary preserved |
| --- | --- | --- |
| Move690 exact window/input/diagnostic lines into `LauncherWindowInput.swift` | Root becomes4,565lines; event routing is independently navigable and testable. A read-only E4 projection replaces one root reference; original private gate remains private. Exact moved-block hash and inverse root reconstruction verified. | Same type names/access, event order, diagnostic sinks/gates; not a new router rewrite. |
| `LibraryHorizontalLayout` | Actual frames and pre-layout icon admission consume one compact/sidebar/details policy rather than duplicated420/600 thresholds. | Existing frames and mode thresholds, no folder/grid geometry change. |
| `SearchFieldFocusPolicy` and removal of custom Library decoration | Two search controls share the user-requested no-blue-outline policy; delete custom stroke geometry/state and focus-only observer work. | Native caret, selection, field editor, IME and AX identity; other controls' focus policies. This supersedes previous blue-decoration styling by explicit user request. |
| One idle-prepared empty Library shell | Reuse the expensive native tree without constructing it in the first scroll event when idle preparation is available; reset/detach before bounded retention. | No closed actionable snapshots, catalog projection, icon requests/history capture; no ownership while closed; cancel/drop on disable/teardown, current language/bounds on entry and synchronous fallback. No measured hitch elimination claim. |
| Codec final-byte cap | Never acknowledge encoded output which exceeds the decoder's existing1MiB bound; reject before journal write and retain prior bytes. | Same v1 bytes/checksum/domain/count limits and existing rejected-over-limit result. |
| Minimal version header before v1 decoding | Protect future-version JSON even when it no longer resembles v1, including a valid v1 peer journal slot. | No future-format downgrade, migration, quarantine or overwrite; same version/result API. |
| Accepted activity writer lifetime | An accepted queued Clear/OFF document survives release/invalidation of its UI owner until finite queued handoff/receipts complete. | Oneactive/onepending coalescing, privacy/clear admission, schema and post-invalidation callback suppression. |

These are selected from concrete contracts; no dependency, toolchain, product default, app ordering, paging parameter or persistence schema migration was introduced. Constructor counts and byte-equivalence checks are structural evidence, not frame-time/energy/leak benchmarks.

## Prioritized findings and remaining work

| Priority | Finding | This wave / next boundary |
| --- | --- | --- |
| P1 | Encoded size can exceed its own readable cap | Implemented guard and near-limit/oversize/journal-preservation coverage. |
| P1 | Future version detection requires v1 shape | Implemented minimal-header protection and both-slot/valid-peer preservation coverage. |
| P1 | Journal initialization/reset can overlap suspended work across actor awaits | **OPEN**, separate lifecycle design/test wave. Define reset epoch/ordering and admissions during reset; shared initialization receipt and gated I/O tests required. Do not assume Task cancellation stops I/O. |
| P2 | Accepted activity queued privacy/Clear write can lose owner before handoff | Implemented finite writer retention plus release-boundary regressions. |
| P2 | Gesture takeover can continue after reentrant interruption/stale callbacks | **OPEN**, dedicated Core ownership repair with callback traces; no paging-engine changes slipped into this UI wave. |
| P2 | Missing mixed app/folder anchor fallback uses hash ordering | **OPEN**, specify visual-neighbor versus stable-domain fallback before changing outcomes; do not reorder saved layout. |
| P2 | Same AppID winning at another source can reuse old icon content | **OPEN**, source incarnation/in-flight cache invalidation design needed. Main confirmed no compensating production purge calls; existing generation checks alone do not identify icon content. |
| P2 | Diagnostic timings/state have unsynchronized getters beside guarded writers | **OPEN**, coherent owner-specific snapshots/getters and race checks required; avoid per-frame heavy aggregation or nested serial-queue deadlock. |
| P3 | Activity decoder reaches through a concrete Library store for shared JSON lexical inspection | **OPEN**, next low-risk exact shared-helper extraction; keep each feature's version/recovery policy separate. |

All findings are source-established contract risks, not assertions that the user's current data is lost or that they cause the reported first-swipe hitch. In particular, open P1 reset ownership deserves attention before a production release. This test package is not a release certification.

## Suggested sequence after this wave
1. Complete native no-outline/search/Library return checks and real first/repeat/canceled swipe feedback on the new isolated candidate. Preserve the bc701 first-entry FAIL; return flicker was not specifically answered.
2. Journal initialization/reset ownership and Core gesture-reentrancy repairs in separate frozen deltas; define reset admission semantics before coding. Review gated I/O and reentrant callbacks independently.
3. Define deterministic mixed-anchor behavior and source-incarnation icon keys, then verify source replacement/canceled loads and exact page outcomes.
4. Extract identical JSON/run-ID helpers only where real consumers share semantics. Keep activity, Library, Capacity and workspace write/flush/recovery protocols distinct.
5. Continue root decomposition by feature ownership (composition/bootstrap, workspace interaction and lifecycle, feature presentation), not arbitrary extension files that merely widen private state access. Consider pure workspace-domain target extraction only with an explicit API/dependency plan.

## Verification and honest limits
Current final runner and source snapshot are in `.build/verification/20261020/architecture-review/final-r1/`; append exact outcomes after completion. Earlier focused compile had a private E4 reference error; corrected by read-only Window projection. Next374test run had one historical different-view identity assertion, updated to permitted clean-shell reuse without dropping reentry/focus checks. These failed attempts remain preserved, not claimed PASS. New focus tests explicitly supersede an old design; they are not evidence that old behavior remained unchanged.

No source/test/build result alone establishes native focus rendering, cold GPU/material behavior, real touchpad smoothness, VoiceOver,120Hz or multidisplay. No formal data, app installation/signing, Git reset/clean/commit, process signal or private screenshot file is involved. Project baseline remains dirty and preserved; full product parity is incomplete.

## Independent follow-up and toolchain
Pasteur source follow-up r2 grants bounded SOURCE-ONLY PASS on the frozen r3 packet after the cached-shell reset repair; prior r1 finding preserved. It independently checked unchanged moved-block/root reconstruction, codec inversion, activity-writer delta and current same-contract helpers. All agents closed. Final serial/native evidence remains Main-owned. Local toolchain verified: Apple Swift6.3.3, targetarm64-apple-macosx26.0, while package tools manifest remains5.9 and deploymentmacOS14+. No toolchain/dependency upgrade was made.

## Final first-wave delivery — 2026-10-20

- Current candidate `/Users/mac/Projects/Launch_Copy/PagingPrototype/.build/candidates/architecture-cold-entry-rc-20261020-r2/LaunchcopyUITest.app`, SHA256 `5e2d3b0bb9af1a10dc8660a06e81f1f2b33f8d0154da9bc5b26200edfb0bf272`; unsigned/uninstalled.540frozeninputs;17changedsource/testpaths. Focused376/0, full3286/0, Debug/Release/package/diff green; packaged365keys×3languages verified. Independent bounded source PASS r2 after preserved r1/P2reset correction; allagentsclosed. Existing unrelated warning history remains, not a global warning-clean claim.
- Main composition5255→4565lines via690exact-line extraction and one read-only E4 root projection; inverse reconstruction verified. Shared layout/no-outline policy, empty-shell preparation/reuse, complete per-session cache reset, codec size/future protection and accepted activity writer lifetime are implemented. Original actorreset/Core/anchor/icon/diagnostic/JSON-coupling risks explicitly retained in the audit report; fullparity not complete.
- Native: old88692 normalQuit/exactabsence; own fresh249hashverified fixtures only, no preferences/history/cache imports. Cold LibraryOFF/historyOFF→own LibraryON/Saved/historyOFF; main and Library active screenshots show no blue outline while native caret/input remain. Menuentry/cards, one-result query/clear, Back restoring old mainquery and second cached-session entry/Back observed. No app launch/removal/formaldata/OSsettings/signals/Git/install/sign/private screenshots. All540source/binary/249seed hashes rechecked unchanged.
- The native-probe instance was normally Quit and exactbinarypathabsence verified; samecandidate/profile cold-reopened for a meaningful FIRST Library swipe handoff. Current ownPID6229, mainfirstpage/emptyquery/SettingsfolderLibraryclosed, LibraryON/historyOFF. Main has NOT entered Library in this fresh process. Do not operate UI once user test requested. This is not a physical smoothness PASS.
- Wallpaper was still LOADING/solidfallback during this packet and at fresh startup; not READY-certified and no causal/source-regression conclusion. No savedprivatewallpaperpixel/path/hash. First/repeat/canceled real gestures, returnflicker, matched frametimes, liveIME/spokenVoiceOver/120Hz remain separate gates. Originalbc701 first-entryFAIL preserved; no synthetic horizontal test substituted.
- Receipts: `.build/verification/20261020/architecture-review/final-r2/verification.json`, `native-results.json`, `native-fixture.json`; scopedsourcepacket `review-inputs-r3.json`, extraction proof `window-extraction.json`. Whole-code findings/coverage/backlog: Docs/ARCHITECTURE_REVIEW_2026-10-20.md and both auditor reports.
