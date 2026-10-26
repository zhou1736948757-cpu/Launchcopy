# Stable mixed-anchor fallback — results

Date: 2026-10-20. Status: bounded correctness maintenance COMPLETE; whole parity incomplete.

## Implementation and preservation
Only three production paths and one new test file differ from the frozen 550-input stage baseline:
- AppCatalogCore.swift: existing AppID anchor predicate becomes public across package targets; its switch body is byte-identical. Private storage and redacted description remain private/unchanged, no Comparable conformance or raw-identity projection.
- FolderDomain.swift: one internal Boolean lexical canonical-UUID comparison. No stored property, equality/hash, encoding or durable representation change.
- AppGridUIPageContentProvider.swift: same-kind missing-anchor comparison uses those predicates rather than hashValue. Actual apps-before-folders cross-kind rank is retained; misleading folder-first comments corrected.
- MixedAnchorRemappingTests.swift: ten public-provider regression methods, synthetic records and fixed UUIDs, no production file/window/app access.

Provider still scans current composition for the FIRST greater entry or LAST lower entry; it does not sort the array or select the semantic-minimum successor. Located / nil / empty and exact CatalogPlanner app-only delegation remain, including a vanished folder anchor projected to nil once no folders survive. Saved layout and canonical presentation order are asserted unchanged. No source-incarnation, refresh-generation, search, input, layout geometry, persistence schema or paging parameter change. ADR004/008 contain no contradictory cross-kind rank mandate; this is stable-domain recovery, not a visual-neighbor redesign.

## Verification
- Preliminary existing controls: 66/0; new methods: 10/0.
- Byte-exact original three-file replay: six independently launched test processes, ten methods each; assertion failure counts [6, 6, 6, 4, 4, 5], total 31. Actual failure-count variation is observed. Every old process compiled/executed the same public-provider tests; no unexpected failure or changed test oracle.
- Repaired fresh-process comparison: six independently launched processes, 60 test executions / 0 failures. Default randomized hashing in each variant; no seed selected/controlled, no inherited SWIFT_DETERMINISTIC_HASHING override was present. These observations are not an exhaustive hash-state proof or performance benchmark.
- Original source swap enclosed in finally; all current three-file bytes restored exactly before rebuilt repaired runs. Frozen review packet and body/cross-kind inverse proofs retained.
- Final 551 frozen source/test/script/manifest inputs: focused 76/0; full 3376/0; Debug build, Release isolated packaging and git diff --check exit 0. No warning-clean claim. Packaging retains the existing 365-key / three-language contract. No diagnostic profiling marker enabled.

## Independent review and ownership
Russell owned only the new test file and ran no builds/tests; Main owned the three production changes, byte-exact old/current comparison and serial final verification. Independent bounded reviewer owns MIXED_ANCHOR_ORDER-r1.md and inspected the immutable five-input source/test/spec packet plus exact baselines. PASS is source/test-source scope, not independent runtime execution or product acceptance. All agents closed; maximum three including Main, no shared-file write overlap or concurrent SwiftPM jobs.

## Candidate and runtime boundary
Unsigned/uninstalled/unlaunched `/Users/mac/Projects/Launch_Copy/PagingPrototype/.build/candidates/mixed-anchor-rc-20261020-r1/LaunchcopyUITest.app`; executable SHA-256 `23a22eca9c9265571dc478b8485fb4cad753b91a4178f4d9c8e4b662414faba1`. Earlier fd395b00 isolated runtime was process-only checked and left untouched; native screen state was not rechecked. No installation, signing, app replacement, process signal, formal preference/data, OS setting, prohibited reference or Git mutation occurred. Existing full-suite fixture activity remains confined to owned temporary test data.

First Library swipe hitch stays non-blocking by user decision; high CPU load is an unverified hypothesis, not a fix or causal conclusion. No new first-entry profiling/tuning. Other functional/native/physical/120Hz/IME/VoiceOver/multi-display/performance and architecture follow-ups remain separate. This closes hash-ordered mixed-anchor recovery, not the whole application parity objective.

## Evidence
Spec: Docs/MIXED_ANCHOR_ORDER_SPEC.md. Immutable packet: .build/verification/20261020/mixed-anchor-order/review-inputs/ and review-inputs.json. Source-boundary proof, source-inputs.json, fresh-process-proof.json, restoration.json, final verification.json and raw logs share that directory. Bounded review: Workflow/reviews/MIXED_ANCHOR_ORDER-r1.md. Stage: Workflow/stage-summaries/2026-10-20-mixed-anchor-order.md.
