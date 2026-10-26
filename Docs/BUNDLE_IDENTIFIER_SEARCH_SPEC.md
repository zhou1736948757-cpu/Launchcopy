# Optional bundle identifier search — proposed specification

Date: 2026-10-15.
Status: APPROVED — human explicitly selected implementation of this exact specification on 2026-10-15.
Parent: approved LAUNCHBETTER_PARITY_SPEC.md; optional identifier matching remains a separate decision. Independent requirements/implementation, not copied reference code or assets.

## Problem, users and intended outcome
The current launcher searches visible applications by original name and alias. Users who know an application's bundle identifier cannot find it by that identifier. Add an optional understandable search setting while preserving current defaults, paging responsiveness, saved organization and separate grid/Library queries.

This proposal is not a claim that the reference implements these exact matching/settings semantics. It defines the optional mode already identified by the requirements audit, without reading reference implementation. Whole-goal fidelity and performance remain subject to the complete parity ledger.

## Recommended product contract
- One localized “Search application identifiers” checkbox in the existing application-management settings tab; default OFF, not an additional tab or always-on hidden change.
- OFF: byte-for-byte-equivalent intended original-name/alias policy; identifier-only queries do not gain results.
- ON: original name OR alias OR canonical record.bundleIdentifier matches. This applies equally to main grid and optional Library. Do not change either search text to activate it.
- Example helper text explains that identifiers look like com.example.app. It contains only an independently invented example, never a real user's identifier.
- Hidden applications remain excluded before every matching branch.
- Only the existing optional canonical bundleIdentifier field participates. Missing/empty identifiers do not match a nonempty query. No AppID, path, URL, executable name, filename, inferred category or other fallback.
- Preserve the existing trim/case/diacritic/width folding and literal substring policy. Punctuation is literal, not a regex, glob, prefix command or token language. Empty/whitespace queries preserve existing unfiltered visible results.
- No new ranking, deduplication or reordering. Grid canonical order and Library alias/name locale sort remain unchanged; matching an identifier does not change the displayed name, details or canonical identity.
- No query/history/launch tracking, enrichment, network request, telemetry identifier or query logging.

Alternative if declined: retain current original-name/alias behavior and explicitly defer this optional branch. Deferral is not evidence of full reference parity. An id: query syntax is a different product contract and is not silently substituted.

## Architecture / interfaces
Reuse AppGridUI's pure matching boundary and existing immutable management preferences. Prefer a default-false searchByBundleIdentifier field on AppManagementPreferences, with compatible initializer defaults; both grid search and AppLibraryProjection use the same canonical matching policy. Do not extend the name-only AppSearchMatcher to silently inspect identifiers for every existing caller. Identifier matching belongs in the shared management-aware policy, preserving existing public matcher semantics/tests.

No new SwiftPM target, scanner, repository, catalog revision, pager page type, icon path or app identity. Optional Library query requests already capture management preferences by value; its latest-wins generation gate must cover this policy as it covers hide/alias. Main grid result generation must also invalidate when the effective policy changes even if query and catalog revision are identical.

Treat the stored preference and current effective presentation policy as distinct while safely queued. All hide/alias drafts derive from the real committed preference, preserving the boolean rather than accidentally resetting it. No duplicate preference owner or conflicting settings consumers.

### Idle presentation transaction
A search-only toggle must NOT call the existing management path blindly: current AppDelegate.applyAppManagementPreferences closes folders and cancels inputs. Capture a latest-wins pending policy and apply at the existing idle/readiness boundary, with separate policy-only admission.
- During gesture, drag, title/alias editing, marked text, menu/sheet, restore, Quit or accepted-write boundary, retain current presentation and wait. Do not cancel user interaction to apply faster.
- Preserve both query strings and each view's selected identity; recompute once against current committed catalog/hidden/aliases. Main grid uses current selected app/folder anchor or existing documented first-valid fallback. If the selected item ceases to match, clear invalid selection and use existing focus policy.
- Keep open folders/member identity and independent Library navigation unless their current content is no longer valid under an existing lifecycle rule. A policy toggle alone is not a request to close a folder or switch view.
- Current displayed/pinned input remains on its captured policy until an atomic safe commit. New results may not be tagged with an old policy generation.
- One immutable request, at most one running and one replaceable pending Library projection. No per-frame filtering or scan.
- Late completions after hide/teardown/profile/lifecycle replacement cannot publish or mutate current state. No busy retry timer or polling loop.

## Storage / compatibility / failure
Extend the existing app-management envelope to schema2 while retaining the 1MiB bound and injected profile storage.
- Missing payload: existing defaults, including OFF; inspection alone creates no data.
- Schema1: explicitly decode legacy hiddenKeys/aliases and default the new flag to OFF; preserve every key/value. No autonomous migration/write during load.
- Schema2: require a valid boolean and valid existing metadata; wrong types, absent required schema2 field, malformed/oversized/invalid existing keys remain corrupt. Do not silently coerce a malformed flag to OFF and overwrite.
- Version greater than2: existing protected/read-only behavior; preserve bytes, no save or guessed down-migration.
- Save failure: do not publish a successful preference or apply an unsaved new mode. Retain prior baseline and show a localized error/retry.
- Acknowledged stored preference may be queued for safe presentation; distinguish queued from effective mode. Settings dismissal/reopen and competing hide/alias edits cannot lose the stored flag or pending latest value.
- Do not introduce a new persistence service, fake fsync, synchronous waiting or claimed durable Quit guarantee. Current UserDefaults acceptance is not disk-flush/restart proof. Real isolated process restart remains mandatory before calling persistence accepted.
- Existing shared accepted workspace/Library writer protection must remain unchanged; a policy draft is not an accepted layout/category write.
- An unresolved/invalid isolated profile must never fall back to formal preferences. Use the existing preflight and candidate-local management suite; production defaults otherwise unchanged.

Exact implementation may refine internal helper names, but a change to these visible matching, default, compatibility, privacy or interaction contracts requires explicit spec revision and confirmation.

## Performance / non-functional requirements
The performance reason for the rewrite is non-negotiable. No reference source/resource import; no per-app filesystem metadata extraction, network, icon decode or frame-callback IO/sorting. Identifier matching consumes the already loaded string. Recompute only on discrete query/catalog/management/policy changes at existing boundaries. Default OFF must not add per-frame work or a second scan; optional Library remains lazy.

Retain5×7default,Timer0ms,existing gestures/typewriter/pager/Core semantics and canonical saved organization. Capture a matched current workload before implementation; compare main search and Library projection wall time/allocation counts separately from real input latency/paging frame intervals. Native60Hz migration AB and120Hz remain distinct gates; synthetic timing cannot pass them or resolve >25ms causality.

Localized System/en/zh-Hans/ja UI, native checkbox label/help and keyboard/AX action semantics. No app names or identifiers translated. Avoid overlay/status overlap and preserve existing settings draft ownership.

## Acceptance / tests / delivery
| Requirement | Authoritative code/test evidence | Required stronger evidence |
| --- | --- | --- |
| DefaultOFF / unchanged matcher | Legacy init and existing name-only tests; explicit identifier-only miss; original/alias hits | Fresh isolated profile settings/default native check |
| Shared ON matching | Canonical identifier hit for grid and Library, absent/empty/literal/case/width/empty-query cases | Same actual query/expected visible results in both modes |
| Hidden exclusion / identity | Hidden ID remains excluded; alias display and canonical action packet unchanged | Native safe action after identifier match |
| Schema compatibility | Schema1 load without write and exact key preservation; schema2 roundtrip; wrong/missing flag; corrupt/oversized/future byte protection; failed save | Same-candidate normal Quit/fresh process reopen |
| Safe toggle / latest wins | Held gesture/drag/editor/marked/sheet/restore/Quit; last choice; same-query generation; obsolete completion; no unwanted folder close | Actual input-method/edit/held-gesture and settings behavior |
| Cross-feature retention | Hide/alias edits and schema2 flag compose; independent queries/Back/folder anchor unaffected | Native Library Back and settings reopening |
| Privacy/isolation | No query/identifier logs/history; injected store; unresolved profile fails preflight | No formal-data mutation; exact isolated candidate |
| Localization / AX | Typed keys/resources/strict packaged three languages; mounted checkbox actions | Current-candidate AX/VoiceOver/tab, no synthetic substitute |
| Performance | Discrete work/source/frame-IO invariant regressions, captured matching workload | Matched physical acceptance and explicit120Hz availability |

Nonzero focused/full XCTest, independent bounded source review, Debug/Release, unique unsigned isolated candidate hash and frozen-source/resource verification. Retain old candidates/failure history. No commit/install/sign/notarize/publish or unrelated process stop. Tests/review/build are not full-goal/native PASS.

## Maintenance, risks and unresolved decision
Maintain one matching policy and one preference ownership path; document schema1 default migration and queued/effective state near consumers. Risks: accidentally making name-only matcher inspect IDs; old queued policy publishing under current query generation; stale hide/alias draft losing the new bool; schema2 downgrade/corrupt overwrite; input cancellation through existing management apply; mistaking UserDefaults acknowledgment for durability.

Human decision needed: implement this default-off checkbox and shared identifier matching, or defer the branch. Main must obtain the answer before production/interface/schema edits. Native access remains blocked by locked desktop; unlock and previously sent capacity question are independent outstanding conditions, not implicit approval of this proposal.

## Approval receipt — 2026-10-15

Human answered the default-off shared identifier-search confirmation with implementation approval. The proposed alternatives above are retained as history, not pending authority. Implement this contract; capacity, unlock and other branches remain distinct.
