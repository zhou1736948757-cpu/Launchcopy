# Identifier Search Domain Worker

Date: 2026-10-15. Status: implementation ready for Main's serial verification; no execution acceptance claimed.

## Changed paths
- `/Users/mac/Projects/Launch_Copy/PagingPrototype/Sources/AppGridUI/AppManagementPreferences.swift`
- `/Users/mac/Projects/Launch_Copy/PagingPrototype/Tests/AppGridUITests/BundleIdentifierSearchPolicyTests.swift` (new)
- `/Users/mac/Projects/Launch_Copy/PagingPrototype/Workflow/results/IDENTIFIER_SEARCH_DOMAIN_WORKER.md` (this report)

## Implementation
- Added public `searchByBundleIdentifier: Bool`, default false in the value initializer. Kept synthesized Codable: the stored boolean is required on decode; no legacy fallback or custom decoder added.
- Hidden exclusion precedes all search branches. Original-name and resolved-alias matching precede optional canonical `record.bundleIdentifier` matching, using the query locale and existing case/diacritic/width folding plus literal substring semantics.
- Nil/empty identifiers cannot match a nonempty query through the new branch. No AppID, URL, path, category or other metadata fallback. Empty queries retain existing visible results through the original-name branch.
- Hide/alias helpers already copy `self`; they retain the flag without additional reconstruction. No scanner, frame callback, sorting, I/O, telemetry or query storage introduced.
- `AppSearchMatcher`, grid/Library production consumers and all unrelated files were left untouched by this worker.

## Authored coverage (not executed)
12 test methods exercise actual grid search controller/provider idle commits and Library projection, covering default/legacy initializer forms, original/alias OR semantics, identifier folding and literal punctuation, injected locale, absent/empty identifiers and nonidentifier metadata rejection, preferred/path hidden keys, empty/whitespace queries, same-query off/on/off/on generation changes, grid order versus Library alias sort, canonical identity/metadata, hide/alias copy retention, JSON/plist round trips, and required/malformed boolean decoding.

## Checks performed — source only
- Read RTK instructions, applicable AGENTS.md, approved identifier-search specification, and relevant first-party domain/consumer/test sources. Chief workflow was waived by the human task; no agents were invoked.
- Inspected final owned source and test text. Python text assertions confirmed required stored Bool/default-false initializer, synthesized Codable, hidden/name/alias/identifier branch order, canonical-only literal folding and existing value-copy helpers.
- Both Swift files have final newlines, no trailing whitespace or conflict markers; source inventory contains 12 uniquely named tests.
- Source SHA-256: `9cd2eb84398c79283b9819b3dc5fd23ba8997c2a93d42c6d9e8146e5d5d29890`.
- Test SHA-256: `4f0a1b49173f817f6b059799ae1ee3c5e9dfaf9619106949ce5513de169526c3`.
- No Swift interpreter/parser/compiler, tests, builds, application launches, process inspection/control, reference source/assets, global-memory operations or commits. No compile/runtime/test PASS claimed.
- Process deviation: the initial read of `/Users/mac/.codex/RTK.md` used plain `cat`; every subsequent shell invocation used RTK. This was an instruction-following error, not an execution-validation step.

## Main handoff
Main owns serial focused/full tests and builds. Include `BundleIdentifierSearchPolicyTests`, existing `AppManagementPreferencesTests`, `AppSearchMatcherTests`, `AppGridSearchPresentationControllerTests` and `AppLibraryProjectionTests`. The new schema2 boolean remains mandatory; Main must explicitly decode schema1 legacy collections with the flag OFF and preserve corrupt/future payload protections. Store, settings, scheduling/admission and native acceptance remain with their assigned owners. Test sources have not been compiled or executed.
