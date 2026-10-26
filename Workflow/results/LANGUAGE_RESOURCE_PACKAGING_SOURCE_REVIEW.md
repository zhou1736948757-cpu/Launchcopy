# Language Resource and Packaging — Independent Source Review

Date: 2026-10-14 (Asia/Tokyo)

Verdict: **SOURCE_REVIEW_ISSUES** — one P2 packaging-verifier gap. No blocking
defect found in the inspected resolver, immutable string snapshots, current
three-language resource catalog, or packaged-app locator. This verdict covers
the bounded source foundation only; it is not feature, GUI, restart, VoiceOver,
performance, build, test, or candidate-promotion acceptance.

## Scope and authority

Reviewed the approved `Docs/INTERFACE_LANGUAGE_SPEC.md`, current
`Sources/LauncherLocalization/**`, `Tests/LauncherLocalizationTests/**`, relevant
`Package.swift` changes, `Scripts/package-app.sh`,
`Scripts/package-app-smoke.sh`, and `Scripts/verify-localization-bundle.swift`.
Read the already-generated Debug resource accessor and inspected existing Debug
resource file names and SHA-256 values. Consulted the current language stage
summary to distinguish Main's recorded results from this review's observations.

Only this report was written. No implementation edits, helper dispatch, Swift
invocation, build, test execution, native GUI, app/process control, commit or
installation occurred. Main owns serialized execution and all repairs. Existing
dirty changes were preserved. Chef workflow is explicitly waived for this
assignment; no roles were created beyond the authorized Main/owner reviewer/this
reviewer arrangement. No prohibited reference directories or assets were read.

Shell review commands used `rtk proxy`. Process deviation: the initial RTK rule
read and empty global-memory keyword lookup were mistakenly invoked without the
prefix; subsequent commands were prefixed. Neither bootstrap command read or
changed project implementation. No relevant memory material informed this review.

## Finding

### P2 — Packaged smoke can accept resources that the runtime schema rejects

**Location:** `Scripts/verify-localization-bundle.swift:23-35`, invoked as the
packaging gate at `Scripts/package-app.sh:133`.

**Evidence:** The verifier requires a nonempty string dictionary, compares each
language's key set with the first language's set, and checks nonempty values
against `Bundle.localizedString`. It never compares with the required 24-key
catalog and never validates named-token signatures or runtime value limits.
`ResourceTable` does enforce these requirements in
`Sources/LauncherLocalization/LocalizationResources.swift:125-151`; template
validation additionally requires the exact token multiplicity at line 203.
The module validation tests check the current explicit catalog, but the packaged
smoke does not invoke that validation against the candidate's bytes.

**Concrete triggering inputs, derived from source (not executed):**

- Remove `languageFutureProtected` from all three otherwise valid packaged tables.
  All key sets remain equal, all remaining lookups remain nonempty and exact, so
  the verifier can report success even though every table lacks a required key.
- Keep all keys but replace Japanese `page` with `"Page %d of %d"` or
  `"{page} / {total} / {privateName}"`. Bundle lookup returns those literal
  strings, satisfying the smoke, while the runtime rejects the template and
  silently uses English fallback. The current module tests exercise comparable
  bad templates; the packaging gate does not.

**Likely root cause:** Equal coverage and Foundation lookup were treated as
equivalent to the typed runtime resource contract. They establish readability,
not required-key coverage or renderability.

**Recommended solution:** Make the explicit packaged-path verifier enforce the
same required-key schema and named-integer signatures as `ResourceTable`, with
exact multiplicities for `{version}`, `{page}`/`{total}`, and `{count}`, no tokens
for static keys, and matching value/table bounds. Preserve the current explicit
path and absence of development fallback. If a standalone schema description is
needed, give Main an explicit maintenance/parity check so future key additions
cannot update only one validator. Main should demonstrate nonzero exit for a
common missing required key and a wrong/repeated/unknown template token, then
verify the healthy three-language candidate and its manifests.

**Affected scope:** Packaging acceptance and standalone verifier credibility.
Current inspected resources are complete and correctly shaped; no current
translation loss or runtime crash was observed or claimed. This is not a finding
against the current strict golden XCTest list.

**Regression risk:** A strengthened validator must retain Japanese token order,
literal percent sequences, permitted escapes, and invariant Chinese/Japanese
count forms. Do not introduce OS-language negotiation or development lookup.

**Confidence:** High for the source-level gap; no executable reproduction was
performed under the review's execution restriction.

## Confirmed source behavior

| Area | Concrete observation and boundary |
| --- | --- |
| Domain and architecture | SwiftPM/macOS launcher; the new target imports Foundation only, has no target dependency, and does not bring localization into PagingCore, catalog identity or icon pipelines. UI/app targets receive dependencies in the manifest. |
| Strict resolution | ASCII/case/separator normalization precedes a bounded parsed language/script/region/variant/extension structure. No unrestricted language prefix or Foundation locale inference is used. Manual preferences ignore the supplied list; system resolution walks it in order and ends at English. |
| Approved tag table | `en-US`/`en-GB` resolve English; `ja`/`ja-JP` Japanese; bare `zh`, `zh-Hans`, `zh-CN`, `zh-SG` Simplified Chinese. Hans overrides region, including `zh-Hans-TW` and `ZH_hans_CN`. Hant/TW/HK/MO without Hans, `zh-Latn`, `zh-US`, unknown and malformed tags continue the list. `[zh-Hant, ja, en]` therefore selects Japanese; `[zh-TW, en]` and an empty list select English. |
| Parser bounds | Empty components, non-ASCII subtags, unsupported scripts, duplicate variants/singletons, incomplete extensions and overlong tags are rejected. Extlangs/grandfathered forms are deliberately outside this bounded resolver; it does not claim general IANA registry validation. |
| Actual catalog | All three source tables have 20 static keys including `languageFutureProtected`, plus `languageFutureVersion`, `page`, `memberCountOne`, `memberCountOther`: 24 entries per language, 72 total. The updated explicit golden list includes the new key and still checks enum order, exact required-key order, all three key sets and non-English count-form equality. |
| Typed formatting | The public dynamic entry points accept Int only. Named tokens are parsed at snapshot creation and must occur exactly once with the expected names; static keys accept none. Japanese page text places total before page without changing argument meaning. Percent sequences are literal and never printf formats. |
| Fallback | Each valid selected entry wins, otherwise the actual English entry, then a key-specific built-in English value. Invalid neighboring entries do not discard healthy translations. Missing/bad data does not expose raw keys or force unwrap. |
| Count semantics | Only English count 1 selects `memberCountOne`; other English integers use `memberCountOther`. Chinese/Japanese use their invariant other form for every integer. When that form is unusable, English fallback independently selects English one/other. Int conversion does not consult OS locale. |
| Resource safety | Reads are capped at 64 KiB plus one detection byte; validation rejects oversized or non-string tables. Values must be nonblank, not the key, at most 4096 UTF-8 bytes, and free of prohibited control characters. Issues expose supported language, known key and stable issue kind only. |
| Rendering IO | Snapshots retain parsed templates, not the provider. `text`, `page`, `languageFutureVersion` and `memberCount` do no resource reading/lookup. English initializes from one table; other languages read selected plus English. Counting/release tests cover repeated rendering and provider release. This establishes the source design for zero render IO, not a measured frame-stack or performance result. |
| App locator | `LocalizationResourceBundleLocator` chooses `<app>/Contents/Resources/PagingPrototype_LauncherLocalization.bundle` through the supplied resource URL or deterministic nil-resource fallback. It returns before evaluating the SwiftPM closure for `.app`/`.APP`, even with missing/invalid packaged resources. Only non-app CLI/test paths use `Bundle.module`. |
| Locator tests | Tests inject a development closure that fails if evaluated in app cases, and cover missing bundle, malformed tables, nil resource URL, exact copied table layout, and CLI/test selection. Fixture tests are not proof of a shipped app's loaded resources. |

## Generated accessor and packaging reconciliation

The observed Debug generated accessor is
`.build/arm64-apple-macosx/debug/LauncherLocalization.build/DerivedSources/resource_bundle_accessor.swift`.
It declares `static nonisolated let module`, tries
`Bundle.main.bundleURL/PagingPrototype_LauncherLocalization.bundle`, then an
absolute Debug build path, and calls `Swift.fatalError` if both fail. It does
**not** itself select `Contents/Resources`. The custom `.app` locator intentionally
bypasses that accessor, so the package script's `Contents/Resources` destination
matches the application's custom resource provider. The generated accessor alone
would not establish safe packaged behavior.

Source preference IDs and directory name remain `zh-Hans`; the observed processed
Debug directory is `zh-hans.lproj`. Provider lookup, packaging presence checks,
standalone smoke lookup and app fixture paths all lowercase the filesystem
component. `CFBundleLocalizations` correctly retains the canonical `zh-Hans` ID;
`defaultLocalization` and `CFBundleDevelopmentRegion` are English.

`package-app.sh:84-89` selects one exact bundle from `swift build --show-bin-path`,
requires it to exist, copies it, and checks all three expected tables. There is no
broad `.build` search fallback. The new sorted `LOCALIZATION_RESOURCES.sha256`
records every copied bundle file; `CANDIDATE_MANIFEST.txt` records its aggregate
hash, the exact bundle basename and the executable hash. The smoke script checks
the packaged tables and validates listed file hashes. These are sound source
mechanisms subject to the verifier issue above; their execution and candidate
values were not established by this reviewer.

Observed Debug source/built table SHA-256 pairs are identical:

| Language / processed directory | Source and observed Debug file SHA-256 |
| --- | --- |
| en / en.lproj | `54987bf7e2b6342bade6b2873b2d165e2f84a778bb0b75543cd2077cd1029854` |
| zh-Hans / zh-hans.lproj | `cb98764e7c6220c215e361b42dedbe0be227b34f2c07def15932abac3c484b20` |
| ja / ja.lproj | `fd627db1c1d27829d6605f50cc570fffbf8dddf3f593b3a233083555c9d4591a` |

Those pairs identify existing Debug resource bytes, not a Release executable or
packaged candidate. No candidate resource hash, hash-check execution, packaging
smoke execution or development-directory-unavailable runtime result is claimed.

## Main results and integration gates

Main reported focused-r2 executed 85 methods with five assertions failing solely
because the old strict 19-static-key list lacked the new 20th key. The stage
summary preserves that failure. This review read the corrected current
`LocalizationResourceValidationTests.swift`, rather than treating the stale
worker report's 19-key description as current. Main reported r3 running; its
outcome is not certified here. This reviewer executed zero tests.

Existing shipping consumers and AppDelegate remain unwired, as recorded in the
current stage summary and corroborated by the limited source symbol search:
localization references appear in the new language foundation/control files,
not existing AppGridUI/PagingUI consumers. Target dependency declarations do not
constitute relabeling integration. No claim covers complete shipping text,
retained/reused host accessibility, zero transitive frame formatting, safe live
presentation, preservation of actual user drafts/search/arrangement, startup
installation of language before controls, native menus or process restart.

Next action for Main: address or explicitly track the P2 verifier gap, retain the
r2 red record, record r3/full-suite/Debug/Release results, and verify an exact
candidate's copied resources and both executable/resource fingerprints without
development fallback. Continue shipping-consumer integration and its separate
acceptance gates. No implementation repair is authorized or performed by this
reviewer.

## Reviewed input fingerprints

SHA-256 captured from current bytes; paths are repository-relative. Resource
hashes are recorded above. Main's later repairs require a fresh bounded review
of changed inputs.

```text
44266dfbe0061e8ea65ea01fe19cfd11fb462d5da230cd77b1f676fd7cd84f99  Package.swift
fd7443264c87a386ee088282662ee4f216703f40e3a370f249f774ee17ce4590  Sources/LauncherLocalization/InterfaceLanguage.swift
896c7d6b643d4dfa4f2add9cc03e14398b8cc18fae12fee5723ccbb93693d148  Sources/LauncherLocalization/LocalizedTextKey.swift
794260ae4ba7c0f68dab75c3dd29bdde392bfa12a9e0f32a06ba02f62019dfcd  Sources/LauncherLocalization/LocalizationResources.swift
ce2839f01f7823f8c0725c53ba955ecc4b102da0968a44a47b452504e1ba75fa  Sources/LauncherLocalization/LocalizedStrings.swift
b503c0b486c45d6dc45fa1e2d9e8e3c49d5c8598b178447e571a9a683987198b  Tests/LauncherLocalizationTests/InterfaceLanguageResolutionTests.swift
4611b7b46ed598b423c8c547d0e7e448e3d3bd83d4ca1742cf7c29363fd40a01  Tests/LauncherLocalizationTests/LocalizationResourceValidationTests.swift
01210e45f26d5c1a8e7824f91889789a46f4d38f60a5dd96379c24de2b02aca9  Tests/LauncherLocalizationTests/LocalizationResourceBundleTests.swift
32952064b619613eca39130f8c6cb5aed5e1a0bf678fef2ae4c467ffb77b94e9  Tests/LauncherLocalizationTests/LocalizedStringsTests.swift
fdc15e3bc8f1ccf602c7aad3a9dcc0e1e450ddf5f38424aa124609886d14ad4f  Tests/LauncherLocalizationTests/LocalizationTestSupport.swift
2a4d61319475ab8488156a306d8b3640a14e072a709024672ae0658f3a1719f1  Scripts/package-app.sh
2adeb590fb4f1ee69bc6f33a5f729bb1acb9e72d426c0e3ef3a8269a02eb78fe  Scripts/package-app-smoke.sh
720035ba801bd764eb7c3c412c547ebd21cb4e561b5bcd5a6151b9f3f3716977  Scripts/verify-localization-bundle.swift
ec355502eab370ade26655e20c7e94952f3e8e73f71962d4db8b7dc418b261ca  .build/arm64-apple-macosx/debug/LauncherLocalization.build/DerivedSources/resource_bundle_accessor.swift
```

## 2026-10-14 — P2 remediation source re-review

Current bounded disposition: **SOURCE_REVIEW_CLEAR** for the inspected resource
foundation and revised packaging gate. The original P2 finding and original
fingerprints above are preserved as historical observations. Its source-level
cause is addressed; positive/negative executable verification and exact-candidate
packaging acceptance remain pending Main's serialized execution. This does not
supersede the feature/GUI/restart/performance limitations above.

### Reviewed remediation

- `Package.swift:15` adds the developer-only `LocalizationResourceProbe`
  executable target with only `LauncherLocalization` as its dependency. No
  shipping target depends on the probe. English default localization and the
  existing resource-processing declaration remain intact.
- `Sources/LocalizationResourceProbe/main.swift:6-19` requires one `.app` path,
  injects that app's `Contents/Resources` URL into the existing typed provider,
  and supplies a development-accessor closure that terminates if invoked. It
  does not depend on the probe process's `Bundle.main` resource location or use
  a default provider. The already-reviewed locator returns the exact known
  packaged bundle before consulting the forbidden closure.
- At lines 20-24, the probe calls
  `LocalizedStrings.validateResources(resourceProvider: provider)` and exits 1
  on any issue **before** rendering or fallback. This uses the runtime's actual
  24-key schema, value/table bounds and exact named-token validation for all
  three language tables, rather than maintaining a second key/token list.
  Common missing keys, unexpected keys, malformed tables and invalid templates
  therefore cannot be hidden by equal language key sets or English safety text.
- At lines 25-38, snapshots use the same injected provider for every language;
  the probe renders every static key plus version, page and count 1/2 templates,
  checking usability. Those rendering checks are smoke coverage, not exact-output
  assertions for all counts or argument boundaries; the existing module tests
  retain that broader semantic coverage.
- `Scripts/package-app.sh:75-77` explicitly builds the known probe product and
  requires its executable at the established build output. Line 138 invokes it
  with the assembled app path and fails packaging on a nonzero result. The old
  plain-Swift verifier is no longer called on this packaging path. Known-bundle
  copying, normalized `zh-hans.lproj` checks, resource fingerprints and the
  executable fingerprint remain in place.
- App assembly copies the app executable and resource bundle, not the probe.
  The probe imports Foundation and LauncherLocalization only and contains no
  NSApplication/AppKit, preference/profile access, app launch or process control.
  The developer probe is an executable that Main may run for validation; it is
  not a launch of the candidate app.

The prior `Scripts/verify-localization-bundle.swift` still exists with its old
equal-key behavior. Its historical deficiency is preserved above; it is not the
current packaging acceptance gate. Its standalone output must not be used as
typed-schema acceptance. No additional blocking source issue was found in this
bounded remediation review.

### Execution and acceptance boundary

Only this report was appended. All shell commands in this re-review used RTK.
No Swift/build/test/probe/package/native GUI/app/process/commit/install action was
run by this reviewer, and no implementation file was changed. The shared runtime
validator, renderer, typed-key catalog and corrected golden test fingerprints
still match the original reviewed bytes.

Main owns recording a healthy three-language candidate's successful probe result,
then nonzero results for the original common-missing-key and invalid-template
cases using isolated copies. Missing/invalid packaged resources must also remain
rejected with the development bundle available, demonstrating that it cannot
rescue the probe. Main should verify the probe is absent from the packaged file
list and verify the candidate resource manifest plus executable/resource identity.
No such execution result is inferred from this source disposition. Existing
shipping consumers/AppDelegate integration and its separate acceptance gates
remain outside this re-review.

Remediation SHA-256 input snapshot:

```text
f9a62774751745b8cbd0aa7b3ed98be2f08e12ba5545824fb7df5549e3e9986a  Package.swift
99135315eb6da0ce8f1ac03d2156e13c112c14085b990cebc9cd248c77b19d05  Sources/LocalizationResourceProbe/main.swift
d61364535a2b7ba532eb1011b015a10ec8d558b15fc4f3148206249ab513602d  Scripts/package-app.sh
2adeb590fb4f1ee69bc6f33a5f729bb1acb9e72d426c0e3ef3a8269a02eb78fe  Scripts/package-app-smoke.sh
720035ba801bd764eb7c3c412c547ebd21cb4e561b5bcd5a6151b9f3f3716977  Scripts/verify-localization-bundle.swift
```
