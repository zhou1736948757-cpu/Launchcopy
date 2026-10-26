# Shared lexical inspection — 2026-10-20

## Objective and baseline
Move two existing pure JSON inspection primitives out of the concrete Library store into one internal namespace for their two real consumers. Previous stage551 inputs,76focused/3376full/0,Debug/Releasepackage/diff and bounded source review; latest23a22eca candidate unlaunched, priorfd395b00 runtime untouched. Source baseline copies/hashes retained under .build/verification/20261020/json-inspection/.

## Contract and ownership
Spec Docs/JSON_INSPECTION_OWNERSHIP_SPEC.md. Exact block extraction plus four qualified call sites; preserve feature-specific schema/recovery/IO/clock/default policy. Main three production paths/proofs/serial verification; one disjoint public-store corpus worker, then bounded review; max3includingMain. No parser rewrite or new security/performance claim.

## Gates / next action
Create exact shared helper, add baseline-compatible independent expected-result corpus, prove old/current GREEN behavior and byte restoration, run frozen focused/full/build/package/diff and independent review. No implementation acceptance yet; full parity/native/device gates remain incomplete. No new UI/profiling/reference/formal-data/OS/Git/signals/install/sign action.

## Implementation checkpoint
Main moved exactly81 original lines (both helper bodies/comments byte-identical; SHA a99c681fc06ca806107bbcddfbaeabde0f43dd60dbe20ffd9b08c1b26b89d825) into JSONLexicalInspection.swift and updated four calls. Two independent inverse transformations reconstruct both original consumer files exactly. Only those three production files changed. Existing Library13+Activity20 tests passed33/0; executable-dependent test-target recompilation produced pre-existing warnings, so no warning-clean claim. Proof and log retained. Worker owns only new corpus; reviewer has immutable four-input production/spec packet. No runtime action, no final/new-corpus acceptance yet.

## Corpus / baseline checkpoint
Feynman delivered only JSONAdmissionParityTests.swift:5methods,36literalinputs/72assertions perrun, both existing static store decode APIs; no helper oracle/files/windows. Worker closed. Same tests compiled/executed on exact original two consumers:5/0; no expectation change required. Current consumers restored byte-exact in finally, current corpus rebuild underway. Final five-input immutable packet/hashes delivered to reviewer; original GREEN is preservation evidence, not a defect RED or exhaustive parser certificate.

## Evidence binding correction (no production change)
The first complete review packet was captured while baseline replay temporarily held the original two consumer files. Its hashes were internally valid but bound the wrong variant; final verifier rejected them against the byte-exact restored sources before running any final job (exit1). Reviewer independently found the same discrepancy; initial packet/r1pendingreport retained. Original production-only packet was correct. Corrected review-inputs-r2/ plus manifest are guarded against that earlier current-production packet and unchanged corpus hash. Source/tests and valid old/current GREEN corpus proof are unchanged. The earlier message claiming final jobs live was incorrect; actual handle was terminal before jobs. Continue final verification on corrected binding, not a parser repair or reclassified test result.

## Final closeout
Exact81-line extraction/four call-site scope and two-consumer inverse proofs accepted. Original/extracted corpus5/0 each,36inputs×2stores; final553inputs focused40/0/full3381/0/Debug/Releasepackage/diff. Independent bounded source/test-sourcePASSr2; allagentsclosed/alljobs terminal. Candidate SHA0b9b20add454473ed6470498cdb031c51e2fe938da20d1826f0ee5ef97e4bb1e unsigned/uninstalled/unlaunched; originalfd395b00 runtime process-only checked and untouched. No parser/schema/recovery/IO/clock/default/UI/physics change or native/performance/security/completeparity claim. ServicesP3 closed; next substantive work is remaining product/native gates, not repetition of this completed check.
