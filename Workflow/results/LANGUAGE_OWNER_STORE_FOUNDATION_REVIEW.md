# Language Owner / Store Foundation — Independent Source Review

Date: 2026-10-14

Verdict: **SOURCE_REVIEW_FINDINGS** — one P2 finding in the bounded foundation scope. This is a source-only review, not an implementation, integration, test, packaging, or runtime acceptance verdict.

## Authority, scope, and method

Reviewed against the approved `Docs/INTERFACE_LANGUAGE_SPEC.md` and the foundation boundary in `Workflow/stage-summaries/2026-10-14-language-implementation.md`. Read project `AGENTS.md` and `/Users/mac/.codex/RTK.md`; the explicit task waiver governs the chef workflow. The foundation uses Swift, Foundation/UserDefaults, AppKit controls, main-actor state ownership, injected callbacks, and XCTest source fixtures.

Inspected:

- `Sources/PagingPrototypeApp/LanguagePreferences.swift`
- `Sources/PagingPrototypeApp/LanguageSettingsCoordinator.swift`
- `Sources/PagingPrototypeApp/LanguagePresentationController.swift`
- `Sources/PagingPrototypeApp/LanguageSettingsView.swift`
- `UITestProfile.languageSuiteName` declaration/assembly and its namespace testcase
- New `LanguagePreferencesTests`, `LanguageSettingsTests`, and `LanguagePresentationControllerTests`

All shell commands used RTK. No tests, builds, Swift commands, GUI interactions, app/process operations, commits, or external/reference-source reads were performed. The resource worker's mutable LauncherLocalization internals/resources/tests were excluded; the documented language-resolution and immutable typed-string API are assumed. AppDelegate and existing consumers are intentionally unwired in this wave and were not treated as defects or certified as integrated. Only this report was written; implementation and concurrent work were preserved.

## Finding

### [P2] An out-of-range future schema header becomes overwriteable corruption

**Source:** `Sources/PagingPrototypeApp/LanguagePreferences.swift:79-84`, `128-130`, and `99-125`.

**Trigger and evidence:** A small, syntactically valid JSON payload such as `{"schemaVersion":9223372036854775808}` carries a positive schema version greater than the supported version, but greater than the 64-bit `Int` range as well. The header's `schemaVersion` is declared as `Int` at line 129. Its decoding failure is absorbed by `try?` and classified as `.corrupt` at lines 79-81, before the future-version branch can protect it. `save` then permits `.corrupt` at lines 110-111 and replaces the original bytes at line 123. Applying defaults through the coordinator reaches the same repair path (`LanguageSettingsCoordinator.swift:22-29`). The approved contract requires future schema bytes to remain protected and read-only (`Docs/INTERFACE_LANGUAGE_SPEC.md:159-162`); it does not limit that protection to versions representable by the current decoder's `Int`.

**Impact:** An explicit Apply can irreversibly replace an unrecognized future payload instead of refusing it. Initial view loading also receives `.corrupt`, so the protected/read-only control path is not selected (`LanguageSettingsView.swift:65-73`).

**Likely root cause:** Header decoding combines known malformed-schema recovery with inability to represent an otherwise positive future schema number. Only successfully decoded `Int` values can reach the byte-protection branch.

**Recommended solution:** Keep header inspection within the existing 16 KiB budget, but distinguish an unrepresentable positive future version from repairable known corruption before allowing a write. Preserve such bytes with an explicit protected result or another deliberately documented read-only classification. Do not truncate/clamp a large value into schema 1 or normalize its payload. Main should decide the exact result representation within the approved protection contract.

**Regression coverage needed:** Add a small payload with a positive integer just above `Int.max`; assert that load does not classify it as repairable corruption, both direct save and coordinator Apply refuse replacement, payload/write counts remain unchanged, and the view selects a protected state. Retain existing malformed-schema repair cases. `LanguagePreferencesTests.swift:119-135` currently checks future versions only through `Int.max`, so it misses this boundary.

**Affected scope:** Header inspection, save protection, coordinator failure handling, and view read-only feedback. No resource or existing-consumer changes are needed to establish the defect.

**Regression risks:** Overly broad protection could make genuinely corrupt schema-1 payloads unrecoverable; overly permissive numeric coercion could accept booleans, fractional versions, or unsupported values as schema 1. Keep those distinctions explicit.

**Confidence:** High for the static decode/classification/write path. No executable reproduction was run under this task's restrictions.

## Remaining bounded observations

- **Missing origin and explicit repair:** `.missing` remains distinct from `.loaded(.default)`; startup load does not write. Small corrupt/missing/different payloads can be repaired on explicit Apply. Healthy equal store saves inspect once and return without writing (`LanguagePreferences.swift:63-75, 99-125`). Tests separately instrument payload reads and writes; these are API-call counts, not physical IO or disk-flush evidence.
- **Ordinary protected and unavailable cases:** Representable future headers are inspected before their unknown body. Oversized Data is rejected before decoding; malformed property-list inspection has byte/depth bounds. The unavailable store never reports acceptance. Coordinator failures return before committed preference or presentation changes (`LanguageSettingsCoordinator.swift:24-39`). These observations are subject to the future-header finding above.
- **Accepted/displayed/latest queue:** The coordinator requests presentation only after acceptance; equal Follow System Apply can resolve a changed effective language. The presentation controller retains distinct accepted/displayed/pending values, coalesces requests, reads the latest pending value at delivery, and cancels pending relabeling when the latest request returns to the displayed language (`LanguagePresentationController.swift:23-25, 56-63, 95-116`). Reopen refresh consults committed preference rather than the view draft (`LanguageSettingsCoordinator.swift:43-45`).
- **Lease overlap, reacquisition, and lifecycle:** Unique tokens permit multiple owners of the same kind; duplicate/foreign releases do not remove another lease. Final release retries presentation. Scheduled delivery rechecks ownership/readiness; an owner acquired before delivery postpones it until release. Requests made during `onPresent` wait for another scheduled turn. Teardown invalidates queued callbacks, clears pending presentation, retains accepted preference, and rejects later requests/releases (`LanguagePresentationController.swift:67-116`). These are controller mechanics and manually acquired test leases, not evidence of real production owner tracking. Actual pointer/IME/menu/modal/etc. acquisition and release remain integration work.
- **Drafts, controls, and status:** Defaults changes only the draft; relabel updates existing labels/menu items without reloading the draft or selection. Known future/oversized/unavailable load origins disable controls. Save failure retains the draft, and typed saved feedback rerenders queued/applied status against the current string snapshot (`LanguageSettingsView.swift:62-163`). No additional bounded implementation defect was identified in those paths.
- **Profile isolation:** The new suite uses the existing candidate/profile hash namespace with its own `.language` suffix (`UITestProfile.swift:17, 40, 91-99`). The new namespace testcase checks deterministic equality, distinct profile IDs, separation from production and other preference suites, and absence of directory creation (`UITestProfileTests.swift:8-24`). This does not demonstrate runtime assembly or fresh-process persistence.

## Evidence limits and handoff

The inspected test source contains useful assertions for missing/corrupt/protected origins, no-op counts, accepted-only refresh, queue cancellation/latest wins, overlapping leases, reacquisition, reentrant requests, teardown, draft defaults, failures, and relabel/status behavior. None was executed here.

The native-control tests instantiate `LanguageSettingsView` directly (`LanguageSettingsTests.swift:82-155`) without attaching it to an NSWindow. They therefore establish intended detached-control assertions only; mounted-window focus, popup tracking, layout/reachability, and actual owner behavior remain unverified. This is a coverage boundary, not a claim that the deferred integration has failed.

Main owns remediation and serialized verification after the resource freeze. Re-review the corrected header-protection path and its focused regression source, then run the required focused/full tests and build/package gates under Main's serialized ownership. GUI, VoiceOver, exact-profile restart, resource fingerprints, and physical/performance gates remain separate. No result from the prior 2163-test baseline is reused as language-feature evidence.

## Repair re-review — 2026-10-14

This section appends a current-source assessment; the original finding and its original line references above remain historical evidence. The same scope and restrictions apply. Only this report was modified. Resource internals remain assigned to the other reviewer; the new `.languageFutureProtected` typed key is assumed to satisfy the agreed resource API, not independently certified here.

**Current verdict: SOURCE_REVIEW_FINDINGS.** The original three regression values are protected by the repair. One residual P2 protection boundary remains in the same header-classification path; its proposed extreme-number fixtures require Main's serialized confirmation. No other actionable defect was identified in the remaining original source scope. This is not a full runtime or integrated-feature verdict.

### Repair confirmed for the supplied regression range

- Load/save now carry distinct `.futureVersionUnrepresentable` origins (`LanguagePreferences.swift:19, 34`). Data size is checked before both decoders (`76-88`). If Int header decoding fails, a numeric root version at or above `Double(Int.max)` returns the protected origin. Direct save refuses that origin before equality or encoding (`108-122`). There is no clamped/fabricated version number and no write on this protected path.
- The coordinator refuses the new origin and returns before changing committed preference or requesting presentation (`LanguageSettingsCoordinator.swift:22-40`). The native view maps both initial load and Apply failure to `.futureUnknown`, disables all three controls, preserves the selected draft, and renders a typed neutral protection message (`LanguageSettingsView.swift:62-75, 117-130, 141-160`). Relabeling retains that feedback rather than reconstructing the controls.
- The numeric fallback does not coerce strings into numbers. Boolean values cannot satisfy its large-positive threshold; small fractions, zero, and negative versions still reach the existing corrupt path when Int decoding refuses them. Representable future versions retain their concrete version result. Rounding near `Int.max` can conservatively protect an otherwise undecodable value; it cannot route that value into schema 1 or permit a write. Oversized data is still classified before any numeric inspection.
- The actual store regression source checks `Int.max + 1`, `2^64`, and `1e100`, initial view protection, coordinator/direct-save refusal, zero presentation, write counts, and unchanged bytes (`LanguagePreferencesTests.swift:8-27`). Generic coordinator refusal and all-control/action read-only tests include the new origin (`LanguageSettingsTests.swift:61-70, 131-143`). The numeric regression uses the real UserDefaults-backed store, not only a spy.

### Residual [P2] Protection still depends on whole-root numeric conversion succeeding

**Source:** `LanguagePreferences.swift:81-90` and `108-134`.

**Evidence and trigger:** The fallback uses `try? JSONSerialization.jsonObject(with:)` for the entire payload and requires its version to become an NSNumber. Any failure of that conversion goes directly to `.corrupt` at line 90, which remains overwriteable at lines 121-134. This conflates malformed known data with a syntactically valid positive future number outside the fallback parser's numeric representation range. A version token such as `1e1000`, or a 400-digit positive integer, is still small enough for the 16 KiB inspection budget but exceeds finite Double/decimal numeric representation. A future header accompanied by an unknown body containing such a number also tests the whole-root conversion dependency.

The three new fixtures demonstrate numbers representable by the fallback, not this second representation boundary. No inspected regression or retained log exercises conversion refusal for a syntactically valid extreme number. The exact Darwin parser outcome for these proposed fixtures was not executed in this re-review; they are concrete confirmation fixtures for Main, not a claimed new red run.

**Impact / likely root cause:** If whole-root conversion refuses such valid future data, load returns a repairable origin, initial controls are enabled, and either direct save or coordinator Apply can replace the bytes. The protection boundary moved from Int decoding to Foundation numeric/root conversion rather than distinguishing every numeric inspection failure from known corruption.

**Recommended solution:** Confirm the proposed boundary with Main's serialized regression runner. Preserve a syntactically valid positive future numeric header even when it cannot be materialized as NSNumber, using bounded header/token inspection that does not require numeric conversion of an unknown future body. Retain explicit repair for genuinely malformed known payloads; do not solve this by indiscriminately making all broken JSON read-only. Reuse the existing protected result rather than displaying an invented version.

**Affected scope / regression risks:** Store header inspection and its focused regression; coordinator and view already handle the protected result. Guard against accepting string/bool/fractional schema-1 coercions, misidentifying nested keys as the root header, losing corrupt-payload recovery, or relaxing the 16 KiB budget.

**Confidence:** High for the source fallback-to-overwrite path; medium for the proposed exact platform fixtures without their permitted serialized runtime confirmation. The supplied three-value reproduction is repaired, but this review does not close the broader future-header protection concern on those values alone.

### Remaining original scope and retained execution evidence

Re-read current presentation controller/test source, settings coordinator/view/test source, store tests, and the language profile additions. Healthy equal Apply still makes one fresh inspection with no store save; missing/corrupt explicit repair remains separate. Failed acceptance cannot independently refresh Follow System. Accepted/displayed/pending separation, latest-wins cancellation, overlapping lease tokens, reacquisition recheck, reentrant presentation deferral, teardown rejection, draft-only defaults, and relabel/status preservation remain as described in the original bounded observations. Production owner acquisition/release and existing consumers remain intentionally unwired. View fixtures remain detached from an NSWindow, so mounted-window and real input-owner behavior are not certified.

Read-only inspection of Main's retained logs confirms:

- `.build/verification/20261014/language-foundation/future-header-red.log:772-800`: the original regression method ran with 21 assertion failures, including corrupt classification, enabled Apply, acceptance/presentation, writes, and changed bytes.
- `focused-r1.log:96-100, 204-206`: the corrected regression method passed within the initial 72-tests/0-failures selector. This is Main's execution evidence, not a test run by this reviewer.
- `focused-r3.log:204-208`: the expanded selector subsequently completed with 85 tests and 0 failures while this re-review was underway. This updates the earlier pending-selector snapshot only; it is not a full-suite, resource-internals review, packaging, fresh-process persistence, or GUI verdict.

The resource golden-key correction and resource internals remain with their assigned reviewer. Main retains ownership of all serialized verification and the residual numeric-boundary confirmation. Historical source findings and red logs are preserved; no prior 2163-test evidence is promoted into language acceptance.

## Root-token preflight re-review — 2026-10-14

This is a further append-only assessment of the latest supplied source. Main reports that its separate numeric probe confirmed JSONSerialization refusal of `1e1000` and 400-digit integers, establishing the prior residual concern. The new preflight removes that whole-root conversion dependency for a recognizable extreme root version. No tests, builds, Swift, GUI, or process operations were run by this reviewer, and only this report was changed. The running focused-r4 selector is not treated as completed evidence or an implementation PASS.

**Current verdict: SOURCE_REVIEW_FINDINGS — one remaining P2 encoding boundary.** The previous UTF-8 extreme-number path is repaired in the inspected source; the complete future-header protection concern remains open for BOM-less UTF-16/UTF-32 input. The original findings and earlier source snapshots above remain preserved.

### What the new preflight establishes

`LanguagePreferences.swift:90-92` invokes `containsUnrepresentableRootVersion` before returning corrupt. The existing 16 KiB check precedes this call. At `145-195`, scanning advances through the bounded input, skips quoted strings including escaped quotes/backslashes, counts container depth, and decodes root-depth string literals to recognize escaped spellings of `schemaVersion`. Nested version keys and ordinary string values are not mistaken for headers in well-formed input. The anchored numeric grammar rejects strings, booleans, leading plus signs, leading-zero forms, incomplete fractions, and incomplete exponents. A positive overflow-to-infinity Double satisfies the protection threshold without constructing a fake version number; negative overflow does not. UTF-8 BOM and BOM-identified UTF-16/32 input are normalized before the scan.

This is intentionally a conservative protection preflight, not a full JSON validator: it can protect a recognized extreme header before validating the remainder of the document. That does not interfere with the inspected known schema-1 corrupt-repair fixtures. It must not be described as certifying arbitrary document validity.

The regression array now includes all five reported numeric values (`LanguagePreferencesTests.swift:11`), retaining coordinator/direct-save refusal, disabled Apply, zero presentation, zero additional writes, and exact byte comparisons (`12-26`). Those fixtures still construct UTF-8 Data; they do not exercise alternate encodings, escaped keys, or nested-key decoys.

### [P2] BOM-less UTF-16/UTF-32 future headers bypass the preflight

**Source:** `Sources/PagingPrototypeApp/LanguagePreferences.swift:146-157, 175-177`, with fallback classification at `81-93` and overwrite permission at `124-137`.

**Trigger / evidence:** Encode `{"schemaVersion":1e1000}` in UTF-16LE, UTF-16BE, UTF-32LE, or UTF-32BE without a BOM. These are JSON encodings recognizable from their initial zero-byte pattern by Foundation's JSON readers. The numeric value remains unrepresentable to the existing decoders, so the new fallback must protect it. However, every alternate-encoding branch at lines 147-150 requires a BOM. Without one, line 151 assumes UTF-8.

For big-endian input, the first zero byte causes the root-opening check at line 157 to fail. For little-endian input, the opening brace can pass, but interleaved zero bytes remain in the scanned string literal; it cannot decode to the `schemaVersion` key at lines 175-177. The preflight therefore returns false rather than the protected origin. Load falls through to `.corrupt`, and explicit Apply/direct save can still replace the bytes. The payload is well below 16 KiB; the size protection does not cover this encoding gap.

**Likely root cause:** Encoding normalization handles BOM detection but omits the BOM-less byte-pattern detection used by JSON readers. Once BOM-less data is interpreted as UTF-8, the otherwise sound depth/key/number scan cannot identify its root header.

**Recommended solution:** Extend bounded encoding detection to BOM-less UTF-16/32 initial byte patterns before scanning, or explicitly protect an uninspectable supported JSON encoding. Keep UTF-32 detection ahead of UTF-16 detection and preserve the current maximum payload size and known-corrupt recovery semantics. Do not guess unsupported encodings or silently rewrite their bytes.

**Regression recommendation:** Main should serialize a matrix of the five numeric values across UTF-8 and UTF-16/32 endianness, with and without BOM. Check that alternate encodings actually carry the expected prefix, then assert protected load/save origins, coordinator refusal, all three disabled controls, retained draft, zero presentation/write counts, and exact original bytes. Include a healthy schema-1 payload in each supported encoding and escaped/nested-key cases to distinguish encoding recognition from blanket protection. Do not obtain a green result by changing BOM-less fixtures to add BOMs.

**Affected scope / risks / confidence:** Store encoding normalization and focused store regression; coordinator/view already support the correct protected result. Risks include confusing UTF-32 with UTF-16, misreading arbitrary malformed bytes, and making known schema-1 corruption unrecoverable. Confidence is high in the source scanner's BOM-less rejection and ensuing repair path; exact platform decoding fixtures still belong to Main's serialized verification and were not executed here.

### Unchanged boundaries

The coordinator/new protected origin, native `.futureUnknown` feedback, and original owner/queue/profile mechanisms show no additional change requiring another finding in this bounded inspection. Resource internals remain with their assigned reviewer. AppDelegate/production owner wiring, mounted-window behavior, packaging, full-suite results, restart durability, GUI/VoiceOver, and physical/performance acceptance remain outside this report's source verdict. Prior focused-r3 and historical red results do not validate the newly revised bytes or the missing encoding matrix.

## Preflight-before-header / ambiguity re-review — 2026-10-14

Reviewed the current supplied `LanguagePreferences.swift` and expanded store-test source. This append preserves all earlier findings. Only this report was written. No implementation edits or test/Swift/GUI/process commands were performed; Main's already-produced focused-r5 log was inspected read-only.

**Current verdict: SOURCE_REVIEW_FINDINGS — three P2 issues in this snapshot:** representable duplicate-future protection remains incomplete; `Int.max` is misclassified by the newly front-loaded Double threshold; and the previously reported BOM-less encoding gap remains unchanged. This is a bounded source verdict, not an implementation PASS.

### [P2] An earlier representable future root version can still be discarded

**Source:** `LanguagePreferences.swift:80-84, 101-117, 184-198`.

The front-loaded lexical scan now protects any recognizable extreme numeric root version before either decoder can choose a duplicate known version. However, its threshold is still `Double(Int.max)` at line 198. It ignores a future token such as `2`. The additional schema-1 root check at lines 112-115 sees only the single value retained by JSONSerialization; it cannot recover a duplicate future value already discarded by both readers.

**Trigger:** `{"schemaVersion":2,"schemaVersion":1,"preferences":{"language":"system"}}` when both readers retain the known value. The lexical scan does not protect `2`, the selected header is schema 1, the selected root is schema 1, and load reports healthy preferences. Applying a different draft then writes schema 1 over the ambiguous future bytes. The new test explicitly includes this ordering and its reverse (`LanguagePreferencesTests.swift:30-46`). Main's r5 log records a refusal assertion failing because save returned `.saved`, an additional write, and changed bytes in that method (`focused-r5.log:42-44`). The log does not label the individual loop fixture, so the exact ordering above is a source-derived trigger rather than a separately logged fixture identity.

There is another ordering problem in the fallback: even when JSONSerialization retains a future value, lines 102-108 require a valid schema-1 body before inspecting that version. Missing/null/unknown future preferences can return corrupt before reaching the version protection. Protection should precede schema-1 body validation, consistent with the original future-header contract.

**Likely root cause / recommended solution:** Protection considers only extreme lexical tokens or whichever representable token survives decoder selection. Inspect all actual root version tokens for positive integral future values before interpreting the payload as schema 1; inspect a parsed future root before validating a known-version body. Preserve duplicates conservatively rather than selecting whichever decoder happens to win. Keep escaped-key/root-depth recognition and do not infer a root header from nested/string decoys.

**Affected scope / regression risks / confidence:** Store root-header classification and store regression. Risks include accepting fractional/bool/string schema values or protecting nested decoys. Retain both duplicate orders; add missing/null/unknown future-body variants and equal/different Apply byte/write assertions. Confidence is high in the source gap and the retained method-level overwrite evidence. No new test was executed by this reviewer.

### [P2] Front-loaded Double comparison marks representable `Int.max` as unrepresentable

**Source:** `LanguagePreferences.swift:82-84, 195-198`.

`Double("9223372036854775807")` and `Double(Int.max)` round to the same value. The `>=` threshold therefore marks the valid, representable `Int.max` header as `.futureVersionUnrepresentable` before exact Int decoding can retain `.futureVersion(Int.max)`. This is a result/feedback regression rather than a write-protection bypass: the bytes remain protected, but the available concrete version is lost and the view displays the unknown-version reason.

**Evidence:** The existing regression requires exact representable results through `Int.max` (`LanguagePreferencesTests.swift:161-175`). Main's r5 log contains nine mismatches between `.futureVersionUnrepresentable` and `.futureVersion(9223372036854775807)` for load and both save choices across the three body variants (`focused-r5.log:53-61`).

**Likely root cause / recommended solution:** A rounded floating-point comparison is being used as the exact integer representability boundary. Preserve exact representable root tokens while still scanning every duplicate for genuine future/unrepresentable values. Merely changing `>=` to `>` would miss `Int.max + 1`, which rounds to the same Double. Keep exact boundary assertions for `Int.max`, `Int.max + 1`, and nearby values; do not weaken the concrete-version expectations to accept either case.

**Affected scope / risks / confidence:** Preflight classification and typed future-version feedback; coordinator and view already handle both results. Risks include losing protection for the adjacent out-of-range value or fabricating rounded version numbers. Confidence is high; both source arithmetic and Main's retained nine failures support this finding.

### Prior BOM-less encoding P2 remains open

Encoding normalization still recognizes UTF-16/32 only through BOMs (`LanguagePreferences.swift:155-160`); the rest of the scan still assumes normalized UTF-8. Moving the scan earlier does not repair the BOM-less root/key recognition described in the previous section. The new ambiguous-root fixtures remain UTF-8, so they do not supply the requested encoding matrix. No new encoding failure was claimed from r5.

### Large-input protection and positive changes

- Data larger than 16,384 bytes returns `.oversized` at lines 76-78 before text conversion, lexical scanning, regex, or either JSON decoder. Save refuses `.oversized` before encoding or setting bytes. The oversized-data and wrong-type regressions retain zero-write/unchanged-byte assertions (`LanguagePreferencesTests.swift:179-192, 238-258`).
- Wrong-type property-list inspection retains a decrementing byte budget and a depth cap of 64 (`LanguagePreferences.swift:218-251`); exhaustion is read-only. The lexical scan itself is iterative and bounded by the previously checked Data size; its index/depth cannot grow with an unbounded external document. No physical IO or timing budget is inferred from this structural observation.
- Moving the scan before Header decoding fixes the specific known-1-plus-huge-future hiding path for recognized encodings. The added escaped root key and nested escaped-string fixture exercise string skipping/root-depth discrimination (`LanguagePreferencesTests.swift:36-37`), and the same method keeps direct write-count and exact-byte assertions.
- No additional owner/coordinator/native-view/profile changes are certified by this narrow repair review. Their previously reviewed foundation boundaries and deferred production integration remain unchanged.

### Main execution evidence update

The focused-r5 log completed while this review was underway: `focused-r5.log:232-234` reports **86 tests with 12 failures**. Three assertions report acceptance/write/byte-change in the ambiguity regression, and nine report the `Int.max` origin regression. This supersedes the task's running-selector snapshot only. It is Main's execution evidence, not a reviewer-run test, and does not establish any full-suite, packaging, resource-internals, fresh-process, GUI, or integrated-feature verdict. Main owns remediation and serialized verification on the next frozen snapshot.

## Exact root-version / encoding-matrix disposition — 2026-10-14

Reviewed the latest `protectedRootVersion` implementation and full store-test source. Only this report was modified. Historical findings and the r5 failure evidence remain unchanged above. No tests, builds, Swift, GUI, or process commands were run; the already-produced Main r6 log was read only.

**Current verdict: SOURCE_REVIEW_FINDINGS.** The three previously reported paths are repaired for plain integer tokens and future-header encoding fixtures. Two issues remain: a healthy encoding-matrix input is still classified as corrupt, confirmed by Main's r6 log; and duplicate-root protection omits integral decimal/exponent spellings, identified from source and requiring Main's focused confirmation. No integrated or final runtime verdict follows.

### Disposition of the prior three P2 paths

- **Plain representable duplicate future headers:** Repaired in the inspected source. `protectedRootVersion` runs before Header/body interpretation (`LanguagePreferences.swift:82-84`) and returns `.futureVersion(version)` for an exact `Int(token) > 1` (`201-202`). It detects a plain `2` regardless of duplicate order or unknown/missing body, removing the earlier dependence on whichever reader retains a value. The original both-order fixtures and huge duplicate fixture remain (`LanguagePreferencesTests.swift:30-47`). This disposition does not cover all integral numeric spellings; see the remaining source finding below.
- **Plain `Int.max` misclassification:** Repaired. Exact Int conversion precedes floating-point fallback; a successfully parsed `Int.max` does not enter the unrepresentable branch (`LanguagePreferences.swift:201-205`). Original exact-result assertions remain through `Int.max` (`LanguagePreferencesTests.swift:209-224`), rather than being weakened to accept either protected result.
- **BOM-less extreme future headers:** Repaired at the source recognition boundary. BOM-less initial four-byte zero patterns are now detected, with UTF-32 before UTF-16 (`LanguagePreferences.swift:156-164`). UTF-8/BOM and normalized leading whitespace remain handled at `166-170`. The future encoding matrix explicitly asserts raw fixtures lack the relevant BOM, then separately exercises raw and BOM-prefixed data (`LanguagePreferencesTests.swift:50-79`). This closes the previously reported preflight recognition gap for the tested numeric fixtures, not the healthy-load inconsistency below.

### [P2] A healthy encoding-matrix payload still loads as corrupt

**Source and evidence:** `LanguagePreferences.swift:82-108`; `LanguagePreferencesTests.swift:81-85`; `.build/verification/20261014/language-foundation/focused-r6.log:45-47`.

The healthy schema-1 matrix constructs Japanese preferences in each of UTF-8, UTF-16LE/BE, and UTF-32LE/BE, with and without BOM. Main's r6 log records `.corrupt` instead of `.loaded(.japanese)` at test line 84. The log does not identify the failing encoding/BOM iteration, so this review does not invent that identity.

**Impact / likely cause:** A healthy preference is exposed to callers as corrupt and defaults to Follow System; explicit Apply can then overwrite the original healthy payload as a repair. Alternate-encoding normalization occurs inside the preflight, but a known version causes that helper to return nil. Header and strict-root decoding subsequently consume the original Data. The current source therefore does not apply the normalized decoding path uniformly to healthy payloads. The precise failing parser/fixture needs Main's labeled serialized confirmation.

**Recommendation:** Identify the failing iteration with explicit encoding/BOM fixture context. Make supported input decoding consistent for both healthy and protected payloads, retaining original bytes for no-op and protected saves. Do not remove the healthy fixture, convert the BOM-less input to BOM input, or relax the healthy expectation to corruption.

**Affected scope / regression risks / confidence:** Store decoding and encoding regression. Retain strict schema-1 shape/enum validation, distinguish genuinely malformed bytes, and assert healthy equal save preserves original encoding/bytes without writing. Confidence is high in the existing healthy-load failure; medium in its exact normalization/parser cause because the retained log does not label the iteration. The future matrix has no reported assertion failure in r6, which does not erase this healthy-path failure.

### [P2] Integral decimal/exponent future tokens can still hide behind a duplicate known key

**Source:** `LanguagePreferences.swift:188-205`, with selected-root fallback at `112-117`.

The numeric grammar accepts decimal and exponent forms, but `Int(token)` accepts only the plain integer spelling. If that conversion fails, the fallback protects only values at least `Double(Int.max)`. Consequently, root tokens `2e0` and `2.0` are not protected by the preflight even though they express the integral future version 2. The later selected-root check already recognizes integral NSNumber values through its `rounded() == value` predicate, so this is an inconsistency in the protection paths rather than a request to accept arbitrary fractional schema values.

**Concrete confirmation fixtures:** `{"schemaVersion":2e0,"schemaVersion":1,"preferences":{"language":"system"}}` and the equivalent `2.0` spelling, with both key orders. When the readers select the known key as in the original duplicate failure, the preflight ignores the earlier future token, both selected-value checks see 1, and load/save can treat the payload as healthy and replace it. The current ambiguity regression covers plain `2` and an extreme exponent, but not a small integral exponent/decimal (`LanguagePreferencesTests.swift:33-37`). No new executable reproduction of these spellings was run here.

**Likely cause / recommendation:** Numeric grammar recognition and integer classification use different notions of an integral version. Classify supported integral numeric spellings consistently before duplicate-key selection, with bounded exact handling or a conservative protected classification where exact representation cannot be established. Avoid truncating genuine fractions or inventing a rounded concrete version. Extend Main's serialized duplicate tests to these spellings, retaining coordinator/direct-save refusal, zero writes/presentation, and exact byte checks.

**Affected scope / risks / confidence:** Root-token classification and duplicate regression; existing coordinator/view failure handling can remain. Risks include admitting boolean/string/fractional headers, losing exact `Int.max`, or reintroducing adjacent overflow mistakes. Confidence is high in the scanner's omission and the conditional selected-known overwrite path; the exact proposed fixtures remain for Main's runtime confirmation.

### Matrix, input budget, and execution limits

The future matrix covers 5 encodings × 3 extreme versions × 2 BOM states, checking the protected origin, all three disabled controls, retained Japanese draft, coordinator/direct save refusal, no presentation, unchanged write count, and exact bytes. The healthy matrix separately covers 5 encodings × 2 BOM states. The raw-prefix assertion prevents the no-BOM future fixtures from accidentally becoming BOM fixtures. Escaped root-key/nested escaped-string evidence is retained in the ambiguity method; a separate nested future-key decoy must remain corrupt and explicitly repairable (`LanguagePreferencesTests.swift:89-96`). These are materially stronger source assertions than a generic inequality alone.

Data over 16 KiB still returns oversized before normalization or preflight (`LanguagePreferences.swift:76-78`); save refuses it before encoding/writing. Wrong-type byte/depth limits remain at `226-259`. Exact-size readability, no-op read/write instrumentation, and malformed known-version repair tests remain intact. No timing or physical IO claim is inferred.

Main's retained **focused-r6** log completed during this re-review: `focused-r6.log:219-221` reports **88 tests with 1 failure**, the healthy encoding assertion identified above. This updates the earlier running-selector snapshot only; r5's 12 failures remain historical evidence. Resource internals, existing consumers/production owners, mounted GUI, packaging, full-suite verification, restart persistence, and final acceptance remain with their original owners and separate gates.

## Unified decoding normalization — final bounded encoding disposition, 2026-10-14

Read the current store and encoding-matrix source. Only this report was changed; no tests, builds, Swift, GUI, app/process operations, or implementation edits were performed. Main supplied the r6 diagnostic identity: healthy UTF-32LE with BOM (`encoding=2617245952`, `BOM=true`). The historical r6/r5 failures above remain evidence of their respective earlier snapshots. R7 execution and acceptance remain Main-owned; no result is inferred from its running status.

**Encoding repair disposition: SOURCE_REVIEW_CLEAR for the unified normalization and inspected encoding-matrix scope.** The healthy-input reader disagreement is addressed in source. **Overall store review remains SOURCE_REVIEW_FINDINGS solely for the previously reported integral decimal/exponent duplicate-root issue**, which this encoding repair does not change. No new encoding finding was identified.

### Healthy encoding finding: addressed in current source

`LanguagePreferences.swift:76-80` enforces the original stored Data limit before computing one normalized UTF-8 payload. That same local `normalized` Data is passed to the root-token preflight (`83`), Header decoder (`87`), numeric fallback root reader (`91`), and strict schema-1 root/body reader (`103`). The earlier healthy-path split between normalized preflight input and original parser input is removed.

`normalizedJSONData` retains explicit BOM and BOM-less zero-pattern recognition, with UTF-32 before UTF-16 (`155-165`), removes a leading decoded U+FEFF if present (`166-167`), and produces UTF-8 once (`168`). The root-token helper now consumes that normalized encoding (`171-173`). Thus the diagnosed UTF-32LE/BOM case no longer reaches two body/header readers with the original alternate-encoding bytes. Failed string decoding remains corrupt rather than silently accepted; supported healthy data still undergoes strict schema-1 shape and enum checks.

Normalization is inspection-only. `load` contains no persistence write, and healthy equal `save` returns before encoding or `defaults.set` (`121-147`). Protected and oversized cases also return before writes. No normalized buffer replaces stored bytes merely because the payload was read. The 16 KiB limit is on original payload bytes; alternate-encoding conversion can change byte count but remains bounded by that input limit. This is a structural bound, not measured timing, physical IO, disk-flush, or restart evidence.

### Matrix assertions: retained without weakening

`LanguagePreferencesTests.swift:50-86` retains five real encodings in both BOM states: ten encoding/BOM combinations. Each runs three extreme future numbers, yielding thirty protected payload cases; healthy Japanese schema 1 is checked separately in all ten combinations. Raw future fixtures explicitly assert absence of the corresponding BOM (`61`) before the second branch adds one (`62`). Future cases retain exact protected-origin checks, all three disabled controls, unchanged draft, coordinator/direct-save refusal, zero presentation/write increments, and original-byte equality (`65-78`). Healthy cases still require `.loaded(.japanese)` and now label failures by encoding/BOM (`81-84`), rather than accepting corrupt or dropping the previously failing case.

Escaped root-key/nested escaped-string fixtures (`30-47`), the nested-key corruption decoy (`89-96`), exact representable `Int.max`, payload-size bounds, missing-origin repair, and healthy equal-save preservation remain in the inspected source. Existing equal-save tests are UTF-8; no new claim that healthy equal saves in every alternate encoding were executed is made.

### Outstanding boundary and handoff

The earlier small integral notation finding remains unchanged at `LanguagePreferences.swift:207-212`: `Int(token)` cannot recognize `2e0` or `2.0`, while the Double fallback only protects values at least `Double(Int.max)`. The current duplicate fixture list still omits those spellings. This append closes the encoding source finding only; it does not silently close that separate source concern or relabel the whole foundation as clear.

Main retains serialized verification and disposition of the remaining numeric concern. Resource internals, production owner wiring/consumers, mounted GUI, packaging, full-suite execution, fresh-process persistence, VoiceOver, and final runtime acceptance remain separate. No implementation PASS or integrated-feature claim is issued.

## Integral notation repair — final bounded source disposition, 2026-10-14

**Current verdict: SOURCE_REVIEW_CLEAR within the original bounded owner/store/settings/profile foundation scope.** The last reported integral decimal/exponent duplicate-root P2 is addressed in the inspected current source. No actionable source issue remains from this review. This append supersedes the earlier current-source findings dispositions; all historical findings and red evidence above remain preserved. It is not an implementation/test/GUI/runtime PASS, resource-internals verdict, or integrated-feature claim.

Read current `LanguagePreferences.swift`, the ambiguity/encoding regression source, and Main's retained `integral-notation-red.log`. Only this report was modified. No tests, builds, Swift, implementation edits, GUI, or app/process operations were performed. Main identifies this wave as the 362-input frozen-r2 snapshot; this reviewer does not independently certify that complete snapshot manifest. Running R8/full-r2 verification remains Main-owned and is not presumed successful.

### Last P2: addressed

`LanguagePreferences.swift:207-215` retains strict JSON numeric-token grammar, attempts exact plain `Int(token)` first, and then uses `JSONDecoder().decode(Int.self, from: Data(token.utf8))` for integral decimal/exponent forms. This shares the Header's Int decoding semantics (`225-227`) rather than truncating a Double or applying a separate permissive coercion. A successfully decoded version greater than 1 returns the concrete protected version before whole-header duplicate selection (`83-85, 211-212`). Only failed integer decoding reaches the conservative large-positive/unrepresentable fallback (`213-214`).

Consequently, `2.0` and `2e0` no longer disappear behind a selected known key; both spellings are inspected as root tokens before body interpretation. Plain `Int.max` remains exact via the first conversion. Strings/booleans do not pass the numeric grammar, and ordinary nonintegral numbers do not become future integers through truncation. The fallback still protects the previously reviewed extreme positive numbers without inventing a concrete version.

`LanguagePreferencesTests.swift:33-50` now retains `2e0` and `2.0` in both duplicate-key orders, along with plain duplicate 2, an extreme duplicate, and the escaped root key/nested escaped-string fixture. Every iteration still asserts save refusal, unchanged write count, and exact original bytes. The repair did not weaken those assertions or remove the earlier plain-integer cases.

Read-only inspection confirms the actual historical red reproduction: `.build/verification/20261014/language-foundation/integral-notation-red.log:14-19` records two sets of save-accepted/write-count/changed-byte failures, and `22-26` reports one method with six assertion failures. This corroborates the previously source-derived concern on the earlier implementation; it is not execution evidence for the repaired source.

### Preservation and remaining acceptance boundaries

The same normalized UTF-8 buffer still feeds preflight, Header, and both root-reader paths (`LanguagePreferences.swift:80-103`); original stored bytes are not rewritten by inspection. The 16 KiB original-data rejection still precedes normalization/scanning (`76-78`), and healthy equal/protected/oversized save paths return before encoding or setting data (`121-147`). Root-depth/string-escape discrimination remains intact. The future/healthy encoding matrix retains all ten encoding/BOM combinations, true no-BOM prefix assertions, read-only controls, retained draft, refusal/presentation/write/byte guards, and labeled healthy expectations (`LanguagePreferencesTests.swift:54-90`). The separate nested-key decoy remains explicitly corrupt and repairable (`93-100`).

The original review's source-only conclusions for accepted/displayed/latest-queue separation, lease overlap/reacquisition/reentrant presentation/teardown, native draft-only defaults/relabel/status, missing-origin/no-op counts, and profile isolation remain bounded to their previously inspected stable foundation. Actual production owners and existing consumers are still intentionally unwired in this wave. Resource internals remain excluded. Main must complete serialized verification and all separate packaging, persistence, mounted-GUI, VoiceOver, and runtime gates; source-review clearance does not satisfy those gates.
