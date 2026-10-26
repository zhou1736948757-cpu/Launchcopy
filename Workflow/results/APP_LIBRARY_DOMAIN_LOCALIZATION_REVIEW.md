# App Library domain and localization — independent source review

Date: 2026-10-15 (Asia/Tokyo)
Verdict: **SOURCEPASS — bounded domain/localization source contract only**
Project: `/Users/mac/Projects/Launch_Copy/PagingPrototype`
Reviewer role: independent, read-only implementation review; sole write is this report.

## Findings and confidence

No actionable P0/P1/P2/P3 finding was identified in the frozen implementation or the expressly added localization-test expectation adaptation. Severity: none. Confidence: high for the source contracts and resource contents below; compilation, Swift runtime behavior, packaged resources and UI acceptance remain unverified by this reviewer. SOURCEPASS does not mean full Library completion or a test/build PASS.

The approval source is `Docs/APP_LIBRARY_SPEC.md`, which incorporates the proposal's exact taxonomy and contracts. Historical PROPOSED markers in `Docs/APP_LIBRARY_SLICE_PROPOSAL.md` do not reopen approval. Both worker result documents were inspected as handoffs, not accepted as independent execution evidence. The project is an existing native macOS Swift/SwiftPM launcher: AppCatalogCore supplies canonical values, MacAppCatalog supplies the utility-queue scanner, AppGridUI supplies pure Library projection/preferences, and LauncherLocalization supplies immutable validated presentation strings. The review follows these existing boundaries.

Formal workflow was explicitly waived and agents were authorized by the human. This reviewer created no agents and used no other-agent tools; the requested Main + other reviewer + this reviewer ceiling remains unaffected. All shell invocations used RTK. No Swift commands, builds, app/process controls, reference/evidence-directory reads or production-data reads were performed. Existing dirty sources were preserved. No implementation, test, resource, owner, UI, workflow-state or stage-summary file was written.

## Contract inspection

Paths and line numbers below are relative to the project root and refer to reviewed source bytes.

| Contract | Source evidence | Source conclusion | Confidence |
| --- | --- | --- | --- |
| Exact taxonomy and filter-only All | `Sources/AppGridUI/AppLibraryDomain/AppLibraryCategory.swift:3-30` | Exactly the approved 22 stored suffixes in order: business, developer-tools, education, entertainment, finance, games, graphics-design, healthcare-fitness, lifestyle, medical, music, news, photography, productivity, reference, social-networking, sports, travel, utilities, video, weather, other. All is absent from the stored enum; nil is the projection filter. Other has no declared identifier. | High |
| Exact game whitelist and unknown fallback | `Sources/AppGridUI/AppLibraryDomain/AppLibraryCategory.swift:33-50` | Only the 19 enumerated game suffixes map to Games: action, adventure, arcade, board, card, casino, dice, educational, family, kids, music, puzzle, racing, role-playing, simulation, sports, strategy, trivia and word, each suffixed -games. Arbitrary prefixes/suffixes, wrong-case and missing/unknown declarations yield Other. No name heuristics. | High |
| Preferred/manual/path precedence | `Sources/AppGridUI/AppLibraryDomain/AppLibraryPreferences.swift:10-33,48-55`; existing dependency `Sources/AppGridUI/LayoutDomain/PersistentAppReference.swift:25-38,52-58` | Defaults disabled/empty. Bundle-first preferred reference wins over normalized canonical-path fallback, then recognized declaration/Other. Uses the existing standardized, lowercased, trailing-slash-normalized path convention and exact bundle string matching. Explicit Other remains a manual override. | High |
| Reset and dormant retention | `Sources/AppGridUI/AppLibraryDomain/AppLibraryPreferences.swift:35-55`; `Sources/AppGridUI/AppLibraryDomain/AppLibraryProjection.swift:41-60` | Explicit category removes the current path fallback and stores the preferred key. Nil removes both current preferred/path keys. Unrelated/dormant overrides and enablement survive; reads and projections do not migrate or prune preferences. Grammar validation preserves stored values for owner validation. | High |
| Hidden and alias/original search | `Sources/AppGridUI/AppManagementPreferences.swift:30-71,103-111`; existing dependencies `Sources/AppGridUI/AppSearchQuery.swift:26-42`, `Sources/AppGridUI/AppSearchMatcher.swift:25-31`; `Sources/AppGridUI/AppLibraryDomain/AppLibraryProjection.swift:41-51` | Shared management matching excludes hidden preferred/path references. Original name or effective alias can match; matching uses injected-locale case/diacritic/width folding and literal substring semantics. Empty/whitespace query includes visible records. Bundle IDs and paths are not search fields. Canonical original records remain in entries with separate alias display names. | High |
| Sorting/revision/counts | `Sources/AppGridUI/AppLibraryDomain/AppLibraryProjection.swift:20-30,37-60` | Injected-locale case-insensitive display-name sort, then standardized canonical-path tie. Counts initialize all 22 categories, count visible query matches before selected-category filtering, and include zero values. Revision is copied unchanged from committed catalog. Pure projection creates no tasks, I/O or new revisions; enablement/scheduling/publication gates belong to Main. | High |
| Optional metadata byte bounds | `Sources/AppCatalogCore/AppBundleMetadata.swift:9-25` | Each field independently checks at most 1,025 UTF-8 bytes and admits at most 1,024 before trimming/control scanning. Oversize is rejected, never truncated. Blank/embedded-control values degrade to nil; valid version/build strings are not inferred or numerically coerced. | High |
| Compatible record identity and forwarding | `Sources/AppCatalogCore/AppCatalogCore.swift:66-85`; `Sources/AppGridUI/AppManagementPreferences.swift:43-55` | AppRecord adds a compatible empty metadata default. Synthesized value equality/hash includes metadata while explicit AppID/icon identity are preserved. The alias reconstruction forwards every canonical field, including metadata. | High |
| Metadata from existing scanner decode only | `Sources/MacAppCatalog/CatalogScanner.swift:19-54,216-237` | Optional String casts reuse the existing decoded dictionary for LSApplicationCategoryType, CFBundleShortVersionString and CFBundleVersion. One existing Data read and one plist decode remain. Optional malformed/wrong types do not add scan failures; existing missing/corrupt/identifier classifications and caller revision survive. Existing utility queue remains the execution path. | High |
| Full typed localization interface | `Sources/LauncherLocalization/LibraryTextKey.swift:3-56,58-115`; `Sources/LauncherLocalization/LocalizedStrings.swift:74-77`; `Sources/LauncherLocalization/LocalizationResources.swift:82-116,119-146` | 53 unique Library keys: 31 navigation/detail/preference/recovery/loading keys and 22 category labels. All 51 minimum keys plus automaticCategory/loading are present. Complete English fallback switch. Typed API/schema registration and empty placeholder signatures are present; no domain dependency. | High |
| Three actual resource tables | `Sources/LauncherLocalization/Resources/en.lproj/Localizable.strings:245-297`; `Sources/LauncherLocalization/Resources/zh-Hans.lproj/Localizable.strings:245-297`; `Sources/LauncherLocalization/Resources/ja.lproj/Localizable.strings:245-297` | All 53 keys exist once in each table. Chinese category labels/order match the approved proposal exactly; English/Japanese labels preserve the flat taxonomy. No game subcategories or stored All label are introduced. English resource equals every built-in English fallback. Recovery requires confirmation, future-version text prohibits overwrite, and reset action has an ellipsis in all languages. | High |
| Strict validation independent of fallback | `Sources/LauncherLocalization/LocalizedStrings.swift:28-35,128-140`; `Sources/LauncherLocalization/LocalizationResources.swift:157-207,221-266` | Rendering uses validated selected-language value, then validated English resource, then built-in English. Validation independently reports missing/invalid tables, missing keys, invalid values/signatures and unknown keys. Library placeholders are empty, so unexpected brace tokens are rejected. Rendering accesses snapshots without resource I/O. Existing 64 KiB table/4,096-byte value bounds and safe diagnostics are retained. | High |

The scanner no-follow dirty change at `Sources/MacAppCatalog/CatalogScanner.swift:151-153` and removal of its later duplicate guard are pre-existing per the assignment. They are excluded from foundation attribution and are not certified by this review. The Git diff was used only to isolate metadata edits, not to reassign ownership of that dirty fix. Because some assigned files are untracked, absence from Git diff is not evidence that their contents were inspected; direct reads and static checks supply the source review.

## Authored tests inspected, not executed

| File | Authored test methods | Meaningful source coverage |
| --- | ---: | --- |
| `Tests/AppCatalogCoreTests/AppBundleMetadataTests.swift:14-79` | 6 | Compatible defaults, normalization, independent degradation, value versus identity behavior, ASCII/multibyte exact 1,024-byte acceptance and 1,025-byte rejection before trim, catalog/revision retention. |
| `Tests/MacAppCatalogTests/AppBundleMetadataScannerTests.swift:45-141` | 8 | XML/binary decoding, absent/wrong types, independent corruption, scanner identity/revision/failure behavior, missing identifier, missing/corrupt plist and oversized fields using fake fixtures. |
| `Tests/AppGridUITests/BundleMetadataForwardingTests.swift:7-25` | 1 | Alias/visible transformation preserves all canonical fields and metadata. |
| `Tests/AppGridUITests/AppLibraryCategoryTests.swift:6-46` | 4 | Exact order/IDs and Codable, filter-only All rejection, recognized top-level mappings, exact 19 games and malformed/unknown rejection. |
| `Tests/AppGridUITests/AppLibraryPreferencesTests.swift:17-118` | 8 | Defaults, bundle/path precedence, explicit Other, all reset combinations, existing path normalization/exact bundle matching, dormant round trips and invalid schema/value handling. |
| `Tests/AppGridUITests/AppLibraryProjectionTests.swift:26-170` | 10 | Empty/whitespace/hidden queries, original/alias search and excluded identity fields, canonical metadata, manual categories, pre-filter counts, stable alias/tie sorting, supplied locale, dormant retention and caller revision. |
| `Tests/PagingUITests/AppLibraryLocalizationTests.swift:7-238` | 9 | Exact 53-key schema and labels, three shipped tables/rendering, all 159 individual missing-key scenarios, English-resource precedence and final fallback, absent/malformed resources, invalid values/tokens and safe unknown-key diagnostics. |

There are 37 foundation test methods and 9 localization test methods (46 authored methods total). These are source counts, not executed-test counts. No Swift test was executed by this reviewer. Scanner fixtures and localization fixtures are isolated synthetic/in-memory test code; they were read but not instantiated here. Invalid-value localization scenarios sample two representative keys; all 53 keys share the same validator/signature path and all are exhaustively checked for shipped values, missing keys and fallback behavior.

## Main's localization expectation adaptation

The human's mid-review update explicitly adds `Tests/LauncherLocalizationTests/LocalizationResourceValidationTests.swift` to this review. Its `allKeys` expression now includes `LibraryTextKey.allCases.map(\.rawValue)` at line 45; its expected count includes `LibraryTextKey.allCases.count` at line 48. This is a justified schema-expectation update, not an implementation workaround.

The preserved assertions remain strong: uniqueness at line 49, exact ordered `LocalizedStrings.requiredResourceKeys == allKeys` at line 50, exact table sets for every supported language at lines 51-53, and strict resource validity/no issues at lines 60-61. Existing placeholder checks at lines 64-77 still demand an empty signature for every Library entry. Independent Python reconstruction confirmed the updated expected list equals `ResourceKey.all` in exact order, contains exactly 274 unique names and retains the three-language table contract. The frozen domain/localization implementation and resources did not change between the review fingerprint checkpoint and report creation.

Main reports full r1 executed 2,527 tests with four assertion failures solely in the older hardcoded localization coverage expectation that omitted LibraryTextKey, followed by the expectation adjustment and 107 passing focused tests including new test/resource coverage. These are **Main-reported execution results** supplied in the human update; no result transcript/evidence directory was read or execution independently reproduced. The original full r1 is not a PASS, and no subsequent full-suite PASS is inferred. Main's separate Projection observer red-test work is outside this review and has not been inspected or certified.

## Reviewer-executed static checks

All following checks exited 0 and wrote no source/test/resource files:

1. `rtk proxy plutil -lint` on the three actual Localizable.strings tables: all OK.
2. RTK-prefixed read-only Python inspection independently derived all raw/implicit enum IDs plus ResourceKey fixed keys. Each table has exactly 274 unique schema keys, zero missing/extra keys and all 53 safe Library values with empty token signatures. English table/fallback equality and Chinese proposal-label order matched.
3. Exact 22-category order and 19-game-whitelist comparison against the approved proposal; metadata guard ordering; one existing scanner read/decode; pure-domain I/O/task API scan. All assertions passed. Behavioral contracts above were also manually traced through source, not inferred from an API-name scan.
4. Separate source reconstruction of Main's adapted expected-key list: exact schema order, 274 unique keys and retained coverage assertions passed.
5. SHA-256 recheck of 24 frozen specification/handoff/implementation/test/resource inputs: no change since the review checkpoint. The newly authorized expectation-test file was fingerprinted separately after its adaptation.

| Table | Source bytes | Unique complete schema keys | Library keys |
| --- | ---: | ---: | ---: |
| English | 17,951 | 274 | 53 |
| Simplified Chinese | 16,937 | 274 | 53 |
| Japanese | 22,675 | 274 | 53 |

These checks validate source structure and resource syntax/content. They do not execute Swift Foundation normalization/sorting/decoding, XCTest, bundle lookup or app UI behavior.

## Remaining gates and Main handoff

- Main must retain its serial Swift verification authority and record a successful nonzero focused/full run after the expectation update and any later owner changes. This reviewer does not assert compilation, Debug/Release or full-suite success.
- Owner/UI Library wiring is not complete according to the frozen handoff. SOURCEPASS does not certify navigation, responder/Escape/Back/hide behavior, generation/cancellation publication, validated actions, accepted writes, file protection, profile/quit/recovery or restart durability. Those belong to owner/integration review and runtime tests.
- Packaged three-language resource validation remains separate from source-table validation and resilient rendering fallback. GUI, accessibility, real restart and matched physical performance gates remain open.
- No correction to frozen domain or localization production code is requested by this review. The reviewed test expectation adaptation is acceptable. Record this bounded verdict and the unresolved gates in Main's visible stage summary; this reviewer has not modified that summary.

## Reviewed input fingerprints

The following hashes identify reviewed bytes; they are source fingerprints, not application/executable or runtime evidence.

| Input | SHA-256 |
| --- | --- |
| `Docs/APP_LIBRARY_SLICE_PROPOSAL.md` | `e1a76505b0fa37ef065455dfded333c1ae6baed0d70a2a1b39a0db07758a8558` |
| `Docs/APP_LIBRARY_SPEC.md` | `d12d4bb3b0d8503196e7410a8da42ad19a194d6808500ea3cb4efb222e6cda23` |
| `Sources/AppCatalogCore/AppBundleMetadata.swift` | `6a9cd9d70dbf1d4ca4f841950f405737d9dceb50b9b53226c25132dce2c888d0` |
| `Sources/AppCatalogCore/AppCatalogCore.swift` | `c9d975bead373ad41ddf66d76099174e1e371e6493b7a5f6fc2fa35c8dc684dd` |
| `Sources/AppGridUI/AppLibraryDomain/AppLibraryCategory.swift` | `440230b1e5070adb1d80c0a269e9369d1e77df0ebabc3272d45f9532b6d20d00` |
| `Sources/AppGridUI/AppLibraryDomain/AppLibraryPreferences.swift` | `b4f08d5795008e68ace204b7231b79e2d5bac982f763866e6a688747fa6aa4ff` |
| `Sources/AppGridUI/AppLibraryDomain/AppLibraryProjection.swift` | `a4163c7976402cfe43d2a57408a31d4370503d734f4b9bb9692914e6a90d4c92` |
| `Sources/AppGridUI/AppManagementPreferences.swift` | `c583969c9202f82014eecc639c430ce8007b952ad7f0f402fb8c04f20539fbb6` |
| `Sources/LauncherLocalization/LibraryTextKey.swift` | `06a2c53c71efe14d6328eb098bfe46aa07c323dcbf07cb23eddb3cdbc462af7f` |
| `Sources/LauncherLocalization/LocalizationResources.swift` | `80663188bb21040a543f79d016d4bd4601d485e414d714a2724762d79004129a` |
| `Sources/LauncherLocalization/LocalizedStrings.swift` | `e38cf226fbbe3b07082c9e601f7b6b41143af2d08b91e91e09fc9d0e2a9197e2` |
| `Sources/LauncherLocalization/Resources/en.lproj/Localizable.strings` | `a601f988637feba58b6f4feb12d9b95722c51c9d1843cb445d775a94c845ccb4` |
| `Sources/LauncherLocalization/Resources/ja.lproj/Localizable.strings` | `534e62b7fb39af998aed226c308a316fafb3ddda5d31501a3aba2de60119c78b` |
| `Sources/LauncherLocalization/Resources/zh-Hans.lproj/Localizable.strings` | `1cc9e16944d0d7787ade1d3921f71304c8817a37c3bef0e39dd2cf0c975ead5d` |
| `Sources/MacAppCatalog/CatalogScanner.swift` | `141359764f015d248cbff56dc0fb88a93cc75a6ae7ba1ad2a29120fad4a4f80d` |
| `Tests/AppCatalogCoreTests/AppBundleMetadataTests.swift` | `295a93619976648757da3a96e6c57d7a0d5a95c4924cc9904078ac39831a4411` |
| `Tests/AppGridUITests/AppLibraryCategoryTests.swift` | `f92870531a41d672d5e64f08b060590806200abb56c6092b60ddcae767bb44f0` |
| `Tests/AppGridUITests/AppLibraryPreferencesTests.swift` | `076f4df1b61c25b5a39f2529780738723c23c75b76796350cc150c2955556a9c` |
| `Tests/AppGridUITests/AppLibraryProjectionTests.swift` | `b131d356dd6480bcb4436c9800ce11ecf052b8b7642e98575e11f8b4266ed3b8` |
| `Tests/AppGridUITests/BundleMetadataForwardingTests.swift` | `d54e63aea98f2d4228f48d7a6dc8c7f6de4d6016f11e6de9ac26e38918731e0e` |
| `Tests/LauncherLocalizationTests/LocalizationResourceValidationTests.swift` | `46b7923b0217231a396654c0881d06546ec5911342f9d5f23fdaba58eb3c0ad0` |
| `Tests/MacAppCatalogTests/AppBundleMetadataScannerTests.swift` | `e3945e8fe5b3624a856c222c0e032aeb99e1420817ea7511bdde5ef3891705ea` |
| `Tests/PagingUITests/AppLibraryLocalizationTests.swift` | `840bd03577f9029097bfbf4b4a43eed5a8268af3909ce7c58057d9b1503fe679` |
| `Workflow/results/APP_LIBRARY_FOUNDATION.md` | `66cf4255fc54551fe96237de93e7acdf091ac7c56e27217ada39c57a78acba51` |
| `Workflow/results/APP_LIBRARY_LOCALIZATION.md` | `5e537e41a2948cd1842b5055d8f4f7ab277ceded5e417028353b3898a9ac28a0` |
