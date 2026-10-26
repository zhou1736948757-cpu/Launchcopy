# App Library localization worker result

Date: 2026-10-15
Status: implementation ready for Main integration and independent review; Swift verification NOT RUN.

## Scope and authority

Implemented the approved localization slice from `Docs/APP_LIBRARY_SPEC.md` and
`Docs/APP_LIBRARY_SLICE_PROPOSAL.md`. Read project `AGENTS.md` and the existing
App Library stage summary. The human waived the formal Chief/workflow; this worker
created no agents and retained the disjoint ownership boundary. Main owns all Swift,
build and app-process execution and the stage-summary update.

The revised test ownership is the new
`Tests/PagingUITests/AppLibraryLocalizationTests.swift` only. No Package changes
or new test target are needed. Existing dirty sources were preserved through
targeted additions. No domain, AppDelegate, other tests, process, production-data,
commit, reset, cleanup, install, signing or publication operations were performed.
No LaunchBetter, BuhoReverseNotes or evidence sources were read. All shell commands
were prefixed with `rtk`.

## Changed files

- `Sources/LauncherLocalization/LibraryTextKey.swift` — new public typed vocabulary
  with 53 stable `library.*` IDs and complete last-resort English values.
- `Sources/LauncherLocalization/LocalizedStrings.swift` — public
  `libraryText(_ key: LibraryTextKey) -> String`, reading the existing immutable
  validated snapshot.
- `Sources/LauncherLocalization/LocalizationResources.swift` — Library keys added
  to ResourceKey, the full required-key list, name mapping and zero-placeholder
  signatures. Existing strict validation is retained.
- `Sources/LauncherLocalization/Resources/en.lproj/Localizable.strings` — 53
  independently authored English entries appended.
- `Sources/LauncherLocalization/Resources/zh-Hans.lproj/Localizable.strings` — 53
  independently authored Simplified Chinese entries appended.
- `Sources/LauncherLocalization/Resources/ja.lproj/Localizable.strings` — 53
  independently authored Japanese entries appended.
- `Tests/PagingUITests/AppLibraryLocalizationTests.swift` — new self-contained
  Foundation/LauncherLocalization/XCTest resource tests.
- `Workflow/results/APP_LIBRARY_LOCALIZATION.md` — this result.

## Contract and integration notes

The accessor follows selected validated resource, then validated English resource,
then `LibraryTextKey.englishFallback`. Resource validation separately reports
missing/invalid keys even when presentation has a valid fallback. All Library
keys have an empty placeholder signature; resource tokens cannot become dynamic
app identities or printf formatting. There is no AppGridUI or catalog-domain
dependency and no rendering-time resource IO.

All 22 category labels follow the approved flat taxonomy, with prefixed Swift
cases such as `categoryDeveloperTools` and `categoryGraphicsDesign`. The Chinese
labels and their order exactly match the proposal table. `all` is filter-only,
and no game subcategory or inferred category labels were added.

All 51 requested minimum keys are present. Two additional UI-neutral keys:
- `automaticCategory`: detail-field label distinct from the `automatic` option.
- `loading`: App Library loading state.

Corrupt-load text states that recovery requires confirmation and the saved file
has not been replaced. Future-version text states that settings cannot be changed
or overwritten. Recovery button text uses an ellipsis to indicate a further
confirmation step. Main must preserve those semantics when wiring the controls;
localization does not implement recovery or persistence.

The complete shipped localization schema is now 274 keys (previous 221 + Library
53). Existing consumers are unchanged and Main can use
`strings.libraryText(.title)` and the other typed cases directly.

## Authored tests — NOT RUN

Nine XCTest methods cover:
- Exact Library schema, uniqueness and all 22 category cases; All is not a category.
- Actual shipped table bytes for all three languages, full schema equality,
  nonempty Library values and rendering equality without hidden fallback.
- Exact category labels in English, Simplified Chinese and Japanese.
- Removing every Library key individually in each language (159 missing-key
  scenarios), with strict reporting despite successful fallback.
- English resource precedence over built-in English for both non-English languages.
- Missing selected and English keys falling back safely for every Library key.
- Absent and malformed tables for every key/language.
- Empty/whitespace, raw-key, control-character, oversized-value and unexpected-token
  rejection, preserving other valid selected-language values.
- Unknown resource keys failing strict validation without exposing arbitrary keys.

Fixtures are in-memory property-list data built from shipped tables, with no app,
UI, catalog, storage-profile, production-data or other test-support dependency.

## Executed static verification

- `rtk proxy plutil -lint` on all three Localizable.strings files: exit 0, all OK.
- Read-only Python source/resource inspection: exit 0. Derived all required IDs
  from explicit and implicit enum raw values plus the ResourceKey fixed keys;
  each resource has exactly 274 unique schema keys and no unknown/missing IDs.
  All 53 Library values are nonempty, not raw-key echoes, within value limits,
  free of forbidden controls and unexpected placeholders. Every English fallback
  equals the English resource. Chinese taxonomy/order matches the approved table.
- Resource sizes: English 17,951 bytes; Simplified Chinese 16,937 bytes; Japanese
  22,675 bytes. All are below the existing 65,536-byte resource bound.
- Owned-file whitespace inspection: no trailing whitespace.
- `rtk proxy git diff --check -- Sources/LauncherLocalization Tests/PagingUITests/AppLibraryLocalizationTests.swift`:
  exit 0. These paths are currently untracked in the pre-existing dirty tree, so
  this Git check alone is not verification of their contents; direct checks above
  cover the edited files.

The initial ad-hoc static checker was corrected for existing implicit Swift raw
values and for excluding the Markdown table separator. The final full check
completed with exit 0; these checker corrections did not change production files.

## Remaining gates / Main handoff

Swift compilation, XCTest execution, Debug/Release builds, Swift resource validator
execution, packaged-resource validation, GUI/VoiceOver, recovery/save lifecycle and
restart/durability checks were NOT RUN. No test PASS or runtime acceptance is claimed.

After the shared-source freeze, Main should run the focused
`rtk swift test --filter AppLibraryLocalizationTests`, the relevant existing
language/resource tests and its approved integration/build/package gates.
Independent review remains pending. Main should incorporate this result into the
visible App Library stage summary and retain the broader parity/performance gates.

