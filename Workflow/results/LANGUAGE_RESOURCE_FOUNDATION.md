# Language Resource Foundation — Worker Handoff

Status: IMPLEMENTED_PENDING_MAIN_VERIFICATION

Date: 2026-10-14

## Scope and ownership

Implemented the approved bounded Foundation-only localization slice for English,
Simplified Chinese and Japanese, plus Follow System resolution. The approved
contract is `Docs/INTERFACE_LANGUAGE_SPEC.md`; this slice does not claim complete
shipping-interface localization. Chef routing was explicitly waived for this
assignment. No helpers were dispatched by this Worker.

All authored files are new and confined to the assigned module, its test directory
and this result. No Package.swift, app/grid/pager source, existing test, other
documentation, workflow state or other agent's file was edited. Main's configuration,
consumer, owner/store and packaging work is outside this result's ownership.

## Exact changed files

1. `Sources/LauncherLocalization/InterfaceLanguage.swift`
2. `Sources/LauncherLocalization/LocalizedTextKey.swift`
3. `Sources/LauncherLocalization/LocalizationResources.swift`
4. `Sources/LauncherLocalization/LocalizedStrings.swift`
5. `Sources/LauncherLocalization/Resources/en.lproj/Localizable.strings`
6. `Sources/LauncherLocalization/Resources/zh-Hans.lproj/Localizable.strings`
7. `Sources/LauncherLocalization/Resources/ja.lproj/Localizable.strings`
8. `Tests/LauncherLocalizationTests/LocalizationTestSupport.swift`
9. `Tests/LauncherLocalizationTests/InterfaceLanguageResolutionTests.swift`
10. `Tests/LauncherLocalizationTests/LocalizedStringsTests.swift`
11. `Tests/LauncherLocalizationTests/LocalizationResourceValidationTests.swift`
12. `Tests/LauncherLocalizationTests/LocalizationResourceBundleTests.swift`
13. `Workflow/results/LANGUAGE_RESOURCE_FOUNDATION.md`

## Public API

```swift
public enum InterfaceLanguage: String, CaseIterable, Codable, Sendable {
    case english = "en"
    case simplifiedChinese = "zh-Hans"
    case japanese = "ja"
}

public enum InterfaceLanguagePreference: String, CaseIterable, Codable, Sendable {
    case system = "system"
    case simplifiedChinese = "zh-Hans"
    case english = "en"
    case japanese = "ja"
    public func resolve(preferredLanguages: [String]) -> InterfaceLanguage
}

public enum LocalizedTextKey: String, CaseIterable, Sendable {
    case languageTitle, followSystem, languageHelp, apply, restoreDefaults
    case languageApplied, languageQueued, languageSaveFailed, languageCorrupt
    case languageStoreUnavailable, languageDraftDefaults, close, cancel
    case searchPlaceholder, searchAccessibility, settingsTitle
    case showLauncher, hideLauncher, quitLauncher
}

public struct LocalizedStrings: Sendable {
    public let language: InterfaceLanguage
    public init(language: InterfaceLanguage)
    public init(language: InterfaceLanguage, resourceProvider: any LocalizationResourceProviding)
    public func text(_ key: LocalizedTextKey) -> String
    public func languageFutureVersion(_ version: Int) -> String
    public func page(_ page: Int, total: Int) -> String
    public func memberCount(_ count: Int) -> String
    public static var resourceBundleURL: URL { get }
    public static var requiredResourceKeys: [String] { get }
    public static func validateResources(
        resourceProvider: any LocalizationResourceProviding = BundleLocalizationResourceProvider()
    ) -> LocalizationResourceValidation
}

public protocol LocalizationResourceProviding: Sendable {
    func localizableStringsData(for language: InterfaceLanguage) -> Data?
}

public struct BundleLocalizationResourceProvider: LocalizationResourceProviding {
    public let resourceBundleURL: URL
    public init(resourceBundleURL: URL = LocalizedStrings.resourceBundleURL)
    public init(mainBundleURL: URL, mainResourceURL: URL?, swiftPackageBundleURL: () -> URL)
    public func localizableStringsData(for language: InterfaceLanguage) -> Data?
}

public enum LocalizationResourceBundleLocator {
    public static let resourceBundleName: String
    public static func resourceBundleURL(
        mainBundleURL: URL, mainResourceURL: URL?, swiftPackageBundleURL: () -> URL
    ) -> URL
}

public enum LocalizationResourceIssueKind: String, Sendable {
    case missingResource, invalidTable, unexpectedKeys, missingKey
    case invalidValue, invalidPlaceholderSignature
}

public struct LocalizationResourceIssue: Equatable, Sendable {
    public let language: InterfaceLanguage
    public let key: String?
    public let kind: LocalizationResourceIssueKind
}

public struct LocalizationResourceValidation: Equatable, Sendable {
    public let issues: [LocalizationResourceIssue]
    public var isValid: Bool { get }
}
```

## Resource and formatting behavior

- The real independently authored `.strings` resources contain the 19 required
  static keys and four typed-template entries: `languageFutureVersion`, `page`,
  `memberCountOne`, `memberCountOther`. No shipping-key expansion was attempted.
- Snapshot initialization directly reads the requested language's `.lproj` table
  and the English fallback table. English initialization requests only one table.
  The IO provider is consumed synchronously and is not retained.
- Raw OpenStep, XML or binary property-list tables are parsed with Foundation.
  Table reads are bounded to 64KiB plus one overflow-detection byte. Validation
  rejects oversized, malformed or non-string tables; known values must be
  nonblank, at most 4096 UTF-8 bytes, not their raw key, and free of prohibited
  control characters. Newline, tab and carriage-return escapes are allowed.
- Named integer tokens are validated before rendering: `{version}`, `{page}`,
  `{total}`, `{count}`. Required tokens must occur exactly once; their order may
  differ by language. Unknown, repeated, missing, mismatched or unbalanced tokens
  are rejected. Static keys accept no tokens. Percent sequences remain literal;
  no printf/String(format:) adapter or arbitrary string argument is exposed.
- Each entry resolves selected-resource value, English-resource value, then a
  specific built-in English safety value. No raw-key fallback or forced unwrap
  is used. Valid neighboring translations survive a failed entry.
- English count 1 uses `memberCountOne`; all other English integers use
  `memberCountOther`. Chinese and Japanese always use their invariant `other`
  resource, including count 1. If a non-English count resource fails, the English
  fallback independently chooses its English one/other rule. Integer conversion
  preserves the supplied signed value and is independent of OS locale.
- Rendering uses only the immutable snapshot. Resource reading/lookup and parsing
  are not performed by `text`, `page`, `memberCount` or `languageFutureVersion`.
  Consumers must still retain snapshots and call formatting outside frame stacks.
- Validation reports only supported language IDs, known schema keys and stable
  issue kinds. Unknown keys, values, resource paths and native error details are
  excluded. The module introduces no logging, telemetry or OS preference writes.

## Follow System interpretation

The supplied ordered preferred-language list is the sole input. Manual preferences
ignore it. Matching is ASCII case-insensitive after valid separator normalization;
spaces, empty components, non-ASCII subtags and malformed suffixes are rejected.
English/Japanese variants resolve to en/ja with absent or compatible known scripts
(Latn/Jpan). Chinese Hans wins a valid explicit region, Hant/unknown scripts are
skipped, and absent-script Chinese accepts only bare zh, CN or SG. TW/HK/MO and
other Chinese regions without Hans are skipped. Unsupported entries continue the
list; exhaustion resolves English.

The parser supports structurally well-formed variants, unique extension singleton
groups and final private-use tails. It rejects duplicate variants/singletons,
incomplete extensions, extlangs and grandfathered tags; it does not guess from
prefixes or query Foundation's locale inference. A conservative 255-byte tag
limit bounds parsing. It is a supported-interface resolver, not a general IANA
registry validator or a change to catalog/search locale.

## Chosen packaged-app lookup

`resourceBundleName` is exactly `PagingPrototype_LauncherLocalization.bundle`, as
specified by Main's packaging update. When `Bundle.main.bundleURL` has `.app`
extension, lookup uses `Bundle.main.resourceURL` plus that exact basename. If the
resource URL is unavailable, the locator deterministically constructs
`<app>/Contents/Resources/<exact basename>`. The bundle is read as a resource
directory; string-table validity is checked independently of bundle metadata.

The SwiftPM accessor is supplied as a lazy closure and is **never evaluated in
the .app branch**, including missing/invalid packaged-resource cases. Those cases
fall back to English resources at the same packaged location, then built-in
key-specific English values; no development-directory search is performed.
`LocalizedStrings.resourceBundleURL` reports this effective location even when it
does not exist. The provider exposes its injected effective URL as well.

Only non-.app SwiftPM test/CLI processes use `Bundle.module`. This branch retains
the generated accessor's own behavior if the entire module bundle is absent;
the generated accessor and its actual built layout have not been inspected or
executed by this Worker. Missing/invalid table bytes and injected missing bundle
locations are handled safely by the provider. Main must verify the actual
generated basename/layout and the `.app` guard after the first build.

## XCTest source coverage (not executed)

- Approved resolution table, ordered fallbacks, override preference, stable enum
  IDs/Codable rejection, case/underscores, explicit script precedence, malformed
  and unknown scripts/regions, variants/extensions and negative cases.
- Actual packaged/module resource tables, exact key coverage, named-placeholder
  parity and invariant Chinese/Japanese resource forms.
- Selected-language plural rules, zero/one/many/negative and Int bounds, typed
  version/page values and Japanese argument ordering.
- Actual-resource fallback sentinel, missing and malformed tables/entries,
  invalid templates, broken selected plus English entries, key-specific final
  safety values, escaped quotes/newlines/tabs, Unicode/emoji and literal percent
  sequences, long values and overflow rejection.
- Lock-protected provider call counting and weak release checks to show snapshots
  consume but do not retain IO providers; repeated rendering requests no IO.
- Privacy-safe validation metadata, unknown-key redaction and diagnostic stability.
- Injected .app URLs, nil main-resource URLs, non-.app CLI/test lookup, missing
  packaged resources, fixture copies of real tables in the exact app layout and
  invalid packaged tables. App cases explicitly fail if the development closure
  is called. These tests create isolated temporary resource directories only;
  they do not construct AppKit objects or launch applications.

## Verification boundary and next action

Worker read project AGENTS.md, RTK.md, the approved specification and existing
XCTest source conventions, authored the files above and performed source readback.
All shell invocations used RTK. No Swift invocation, build, test execution,
automated resource check, native GUI, app launch, process stop, commit or install
was performed. No reference/evidence/assets were read. There is no self-certified
PASS, compilation claim, test-result claim or packaging/runtime claim.

Main owns serialized configuration/build/tests, independent review, actual bundle
accessor/basename/layout inspection and exact-candidate packaged-resource checks
with development-path fallback unavailable. App resource consumers, safe relabel
ownership, persisted preferences, native/VoiceOver checks and full shipping-text
coverage remain separate work and acceptance gates.

Source freeze: all 13 assigned files are ready for Main's serialized verification.
Further Worker edits require a concrete Main repair request.
