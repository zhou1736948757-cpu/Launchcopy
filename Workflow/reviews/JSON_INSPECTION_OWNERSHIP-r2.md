# JSON inspection ownership — independent bounded review r2

Date: 2026-10-20

## Verdict

**PASS — bounded source/test review on the five frozen r2 inputs below.** No actionable production or test-source finding remains. This verdict confirms the specified mechanical extraction and regression corpus. Main owns final execution, packaging/localization evidence, runtime evidence, and stage closeout. This is not whole-product parity acceptance, native/UI acceptance, performance acceptance, or exhaustive JSON/parser-safety certification.

The r1 report and initial full packet remain unchanged. The initial full packet captured the original consumers during baseline replay; its internally consistent hashes identified the wrong production state. `invalid-final-attempt.json` records exit 1 and `REJECTED_BEFORE_JOBS`. The earlier statement that final jobs were already running was corrected by Main. **No final verification jobs from that rejected attempt are counted here.** This new review attempt binds the restored current implementation to `review-inputs-r2/` and `review-inputs-r2.json`; it does not retroactively approve the initial packet.

## Contract, ownership and reviewed hashes

Contract: `Docs/JSON_INSPECTION_OWNERSHIP_SPEC.md`. Evidence directory: `.build/verification/20261020/json-inspection/`. Corrected manifest SHA-256: `3f4cc7ea338128ab8248865c9711530da1549a8518606228d812e217c9b725ae`.

The reviewer independently hashed all five r2 snapshot copies and live counterparts. Production/spec values also match the original correct `production-review-inputs.json`; the test value matches completed `parity-proof.json`. The four code/test values match Main's final `source-inputs.json`.

| Frozen input | SHA-256 |
| --- | --- |
| `Sources/PagingPrototypeApp/JSONLexicalInspection.swift` | `721563fbf4dc955f236f5dd948588e537210e4c845884ed4fd048b1e41e135cf` |
| `Sources/PagingPrototypeApp/AppLibraryStore.swift` | `281246fe443bf48a88e80786fb4c3a2b7e0db6e76f80dd36c958e398f36f37ad` |
| `Sources/PagingPrototypeApp/LaunchActivityStore.swift` | `515f8541085c062320458e7fcbe0c32e057378635ae6674692609d4570924ed3` |
| `Docs/JSON_INSPECTION_OWNERSHIP_SPEC.md` | `f5e2b624332746be9ff1b5bdd0c8652813aa5c9717840faec2bce6bccf22f35b` |
| `Tests/PagingUITests/JSONAdmissionParityTests.swift` | `1c509b8095f5cf831d6f8f8779abbb7e058bdb3a736435cbb1d7dbc555983eb6` |

Reviewer writes were limited to the initially authorized r1 report and this explicitly added r2 report. No implementation/test/evidence files were changed. No SwiftPM/build/UI/Git/process-signal/reference/formal-data/OS inspection was performed, and no child agents were dispatched. All shell commands used the required `rtk` prefix. Current user authorization supersedes the older Chief routing procedure for this bounded review.

## Independent extraction and inverse validation

**PASS.** The reviewer independently derived the original lexical block from `AppLibraryStore.baseline.swift`, rather than trusting Main's extraction booleans. The exact block contains **81 lines**, SHA-256 `a99c681fc06ca806107bbcddfbaeabde0f43dd60dbe20ffd9b08c1b26b89d825`. The complete new helper file consists only of that byte-identical block plus the declared Foundation import, internal enum wrapper, and ownership documentation. No function body or existing comment changed.

Using in-memory byte transformations only, undoing the two Library call qualifications and reinserting the extracted block reconstructs the original Library file byte for byte. Reversing Activity's two namespace substitutions reconstructs the original Activity file byte for byte. Both saved baselines independently match `baseline-inputs.json`. The exact block and both inverse checks were repeated against **r2 snapshot bytes** after the corrected packet notice.

A final read-only hash comparison found all **553** Sources/Tests/Scripts/Package.swift inputs equal to `source-inputs.json`. Compared with the 551-input baseline, the only modified paths are the two consumers; the only additions are the lexical helper and parity test; no baseline path is deleted. Existing tests, domain models, package configuration, dependencies, and scripts are unchanged within that manifest scope.

## Behavior and ownership assessment

**PASS.** The helper is an internal, stateless, Foundation-only namespace for the two existing lexical admission primitives. Byte identity preserves decoded escaped-key equivalence, UTF-8 scanning, object/array container tracking, root-depth/token extraction, malformed-input early returns, separate scanner loops, allocation behavior, and numeric token spelling. The wrapper explicitly states that this is not a complete JSON validator. No new parser, compatibility facade, public interface, target, or dependency is added.

Library retains its own payload bound, version and future/ambiguous/corrupt classification, strict preferences envelope, Foundation shape checks, JSONDecoder, and domain validity checks. Activity retains its own document/entry/day-key checks and clock-independent load semantics. Exact consumer reconstruction also covers unchanged actor/I/O ownership, save/recovery/protected-payload outcomes, encoder configuration, schema/version constants, defaults, and durable-byte behavior. No data collection, UI, layout, paging, clock, recovery, or feature-policy change is present in the reviewed transformation. The shared file-I/O protocol and its existing naming/concrete byte-limit reference are deliberately unchanged by the contract.

The source/test reference search found the two lexical definitions only in the shared namespace and exactly four production calls through it. No concrete `AppLibraryFileStore.hasDuplicateObjectKeys` / `AppLibraryFileStore.rootVersionTokens` call or forwarding method remains. Concrete store decode/byte-limit references in existing tests and I/O code are outside the eliminated lexical-helper coupling.

## Independent regression-corpus assessment

**PASS.** The completed frozen test contains five XCTest methods and 36 literal inputs: seven duplicate/container cases, five root/header-decoy cases, eight numeric cases, nine invalid/malformed/UTF-8 cases, and seven feature-envelope cases. Each input has two direct store assertions, yielding **72 assertions per complete run**, not 72 XCTest methods.

Expected outcomes are hardcoded and separately typed for each store. Loaded cases compare full expected domain values, including different valid Library and Activity envelopes, rather than only a generic success flag. The corpus never calls the extracted helper, derives an oracle from a decoder/encoder, accesses files, constructs store I/O, writes data, or reads the current clock. It uses only the pre-existing store decode entry points and public domain constructors, preserving compatibility with original consumers without a forwarding facade.

The reviewer checked the expected classifications against the unchanged admission order and domain rules. Duplicate escaped equivalents remain ambiguous before shape validation; unrelated sibling-object keys do not collide; nested keys/header-like strings do not supply a root declaration; non-UTF-8 data remains ambiguous; future/ambiguous numeric spellings retain existing classification; and malformed future input deliberately retains the existing early future classification. This is preservation coverage, not a new parser guarantee. The Library escaped identity is valid under its existing reference-key grammar. The populated Activity expected value explicitly supplies its fixed salt, reference-date timestamp, and matching epoch-day 11323, avoiding current-clock or random-default expectations. The opposite feature's envelope and combined envelopes remain corrupt.

Existing test sources retain explicit recovery, exact protected-byte preservation, no-follow/atomic I/O, bounded reads, save receipts, defaults, and Activity clock-preservation checks. Their scope was not broadened or rewritten.

## Main-owned execution evidence inspected

The reviewer did **not** execute tests or builds. Evidence inspected:

- `existing-focused.log`: terminal XCTest count **33 tests / 0 failures** (Library 13 + Activity 20); exit 0 is Main-reported. The separate Swift Testing zero-test footer is not used as the execution count. No warning-clean build claim is made.
- `baseline-corpus.log` and `current-corpus.log`: each has five passed XCTest cases and terminal **5 tests / 0 failures**. `parity-proof.json` records both runs at exit 0, the same test hash as r2, and exact current-source restoration.
- `restoration.json`: byte-exact restoration receipt whose two current consumer hashes independently match the live tree and r2 packet. Main's replay script restores saved current bytes in `finally`; the reviewer inspected that script without running it.
- Both corpus runs are expected GREEN behavior-preservation evidence; no defect RED/GREEN claim is made.

Final focused/full XCTest, Debug build, Release unsigned isolated packaging/localization, and diff checks were newly starting under Main after the corrected packet. **No result for those final jobs is certified by this report.** Main must retain their terminal nonzero test counts, statuses, and frozen-input checks before stage closeout. Source/test PASS stands separately from those execution gates and from all broader runtime/product acceptance.

## Findings, risks and disposition

No actionable source/test finding. The evidence-binding issue that kept r1 pending is resolved for **r2** by the corrected immutable snapshots, independent original-production/test guards, exact inverse checks, and live/final-manifest hash agreement. The old packet remains invalid for current-source acceptance and is preserved for traceability.

Confidence: **high** for the bounded mechanical extraction and corpus assessment, supported by byte identity and inverse reconstruction. Existing lexical-admission limitations and broader runtime/parity gates remain unchanged. No implementation repair, parser-policy expansion, or additional reviewer-run build is requested. Main may consume this r2 source/test PASS while completing its separately owned final execution gates.
