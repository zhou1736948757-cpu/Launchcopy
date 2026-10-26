# JSON inspection ownership — independent review r1

Date: 2026-10-20

## Status and authority

**PENDING final corpus packet. Production source review: PASS on the frozen snapshot below.** No final source/test acceptance is issued yet. The worker-owned corpus has not been inspected while drafting. Main owns all execution, packaging, runtime evidence, and stage closeout; this review cannot close whole-product parity or certify parser safety/performance.

Reviewer writable scope is exclusively this report. No implementation/test edits, SwiftPM/build execution, Git, UI, process signals, reference-source/evidence access, formal-data access, or OS inspection were performed. Shell commands used the required `rtk` prefix. No child agents were dispatched. The current user packet authorizes this bounded independent review and bypasses the older Chief route.

## Reviewed contract and frozen production inputs

Contract: `Docs/JSON_INSPECTION_OWNERSHIP_SPEC.md`. Production copies: `.build/verification/20261020/json-inspection/production-review-inputs/`; manifest: `production-review-inputs.json` in the same verification directory. Independently computed SHA-256 values match every frozen copy and its live production/spec counterpart:

| Input | SHA-256 |
| --- | --- |
| `Sources/PagingPrototypeApp/JSONLexicalInspection.swift` | `721563fbf4dc955f236f5dd948588e537210e4c845884ed4fd048b1e41e135cf` |
| `Sources/PagingPrototypeApp/AppLibraryStore.swift` | `281246fe443bf48a88e80786fb4c3a2b7e0db6e76f80dd36c958e398f36f37ad` |
| `Sources/PagingPrototypeApp/LaunchActivityStore.swift` | `515f8541085c062320458e7fcbe0c32e057378635ae6674692609d4570924ed3` |
| `Docs/JSON_INSPECTION_OWNERSHIP_SPEC.md` | `f5e2b624332746be9ff1b5bdd0c8652813aa5c9717840faec2bce6bccf22f35b` |

## Independent inverse validation and source findings

No actionable production finding.

The reviewer independently read the baseline bytes, identified the original block by its leading comment and the Library actor's final closing brace, and compared the complete shared-file contents against exactly that block plus the declared Foundation import/internal enum documentation wrapper. The block is **81 lines**, SHA-256 `a99c681fc06ca806107bbcddfbaeabde0f43dd60dbe20ffd9b08c1b26b89d825`. This was recomputed rather than inferred from Main's `extraction-proof.json`.

In memory only, undoing the two Library qualifications and reinserting the block reconstructs `AppLibraryStore.baseline.swift` byte for byte. Replacing the two Activity namespace qualifications reconstructs `LaunchActivityStore.baseline.swift` byte for byte. Both saved baselines independently match their entries in `baseline-inputs.json`. The checks were repeated against the frozen production copies.

A read-only comparison against the 551-entry baseline input manifest initially found only the two modified consumers and the added helper (552 current inputs), with no deletions or other Sources/Tests/Scripts/Package.swift modifications. The pending new corpus will account for one additional test input; final frozen scope must be rechecked.

The actual transformation therefore preserves both scanner bodies/comments, UTF-8 scanning, escaped decoded keys, object/array container handling, root-depth/token behavior, early malformed-input returns, and allocation/loop strategy. The new namespace is internal, Foundation-only, stateless, and limited to these two existing methods. It is explicitly preliminary inspection, with no new parser or compatibility facade.

Library decode still owns its byte bound, version classification, strict preferences envelope, and domain validation (`AppLibraryStore.swift:187-213`). Activity decode still owns its byte bound, version classification, strict document/entry/day-key admission, and document validity (`LaunchActivityStore.swift:70-112`). Both retain Foundation shape validation and JSONDecoder after lexical admission. Exact consumer reconstruction also covers unchanged save/recovery/protected-payload outcomes, encoder configuration, I/O ownership, schema constants, defaults, and Activity's clock-independent load contract. Shared file-I/O naming and its existing concrete limit reference are intentionally unchanged by the specification.

A source/test reference search found the two definitions only in `JSONLexicalInspection.swift` and exactly four production calls through that namespace. No concrete `AppLibraryFileStore.hasDuplicateObjectKeys` or `AppLibraryFileStore.rootVersionTokens` reference or forwarding definition remains. Existing concrete Library calls for store decoding/byte limits are outside the eliminated lexical-helper coupling.

## Execution evidence inspected, not reviewer-executed

Main reports existing Library 13 + Activity 20 = **33 XCTest tests / 0 failures, exit 0**. The reviewer inspected `existing-focused.log`, whose terminal XCTest suites confirm 33 tests and zero failures; the separate Swift Testing footer reports zero tests and is not the execution count used here. Exit status is Main-reported. Existing test source names/assertions retain explicit recovery, exact protected bytes, bounded payloads, no-follow/atomic I/O, defaults, and Activity clock-preservation coverage. No warning-clean build claim is made.

## Remaining review gates

Await the completed/frozen `JSONAdmissionParityTests.swift` packet and hashes before inspecting it or issuing the final bounded source/test verdict. Review literal independent expected results, baseline compatibility, synthetic in-memory scope, feature-specific loaded envelopes and the specified lexical/malformed-input categories. Inspect Main's old/current corpus receipts and exact-restoration evidence when supplied. Final focused/full/build/package/localization execution remains Main-owned and must not be inferred from this source-only checkpoint.

## Corpus review update and packet discrepancy

The completed frozen test file has now been inspected: SHA-256 `1c509b8095f5cf831d6f8f8779abbb7e058bdb3a736435cbb1d7dbc555983eb6`, matching its live copy and `review-inputs.json`. It contains five XCTest methods, 36 literal cases (7 duplicate/container + 5 root/header decoys + 8 numeric + 9 invalid/malformed/UTF-8 + 7 feature envelopes), and two direct decode assertions per case: 72 assertions per full run. All inputs are in memory. It performs no file access, store save/load, encoding, helper calls, generated classification oracle, or current-clock reads.

No actionable test-source finding. Expected outcomes are literal, separately typed store results, including full `.loaded` values rather than a coarse success classification. The test calls only the pre-existing store decode surfaces and public domain constructors, so it requires no new helper API or forwarding facade to compile against the original consumers. Library header-like escaped identity text is valid under the existing nonempty bundle-prefix grammar. The Activity populated fixture explicitly supplies a fixed 64-character hex salt, a fixed reference-date timestamp, and epoch-day 11323, consistent with the existing clock-free document validity rules. Distinct Library/Activity body envelopes assert different outcomes. Duplicate and malformed inputs deliberately preserve early lexical admission classifications, including truncated future input; no stronger parser policy is introduced or claimed.

The reviewer independently confirmed that restored live production/spec bytes match the original production packet, and that `restoration.json` names the same two current consumer hashes. `parity-progress.json` reports original and extracted corpus runs, each exit 0, five tests, zero failures; terminal logs and final receipts remain to be inspected for closeout. These are expected GREEN preservation checks, not a defect RED/GREEN demonstration.

**Evidence packaging issue, pending correction:** the full five-input `review-inputs.json` and its matching `review-inputs/` consumer copies captured the original consumers during Main's replay. Their consumer hashes are Library `0bd23d3c568c3a98e267cfff018780f6c9619b69bc7bb785780e8256319681c7` and Activity `112162ddd24fc8095717dcd8bf42ab0d5896c301c3d0bf83ae9e875c5ec7216b`. The independently reviewed extracted/live consumers instead have Library `281246fe443bf48a88e80786fb4c3a2b7e0db6e76f80dd36c958e398f36f37ad` and Activity `515f8541085c062320458e7fcbe0c32e057378635ae6674692609d4570924ed3` as listed above. Thus the full packet is internally hash-consistent but identifies the wrong consumer state for final current-source acceptance. Main's `verify.py` checks every `review-inputs.json` entry against live files and would reject these two stale hashes. Main was informed; preserve the historical packet and supply a corrected immutable packet/review attempt before final verdict. This is an evidence binding issue, not a production regression; no implementation repair is recommended.
