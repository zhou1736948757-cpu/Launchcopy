# Language Preferences Foundation

Status: IMPLEMENTED, NOT EXECUTED. Pending Main integration, compilation, tests,
and independent review. No PASS is claimed.

## Authorized scope and boundaries

Implemented the approved scalar language preference/store foundation from
`Docs/INTERFACE_LANGUAGE_SPEC.md`, under the explicit task-specific waiver of
chef routing. No helpers were dispatched; Main retains concurrency ownership
and the Main + 2 <= 3 limit.

Only these three new files were written:

1. `Sources/PagingPrototypeApp/LanguagePreferences.swift`
2. `Tests/PagingUITests/LanguagePreferencesTests.swift`
3. `Workflow/results/LANGUAGE_PREFERENCES_FOUNDATION.md`

Existing stores, package/profile/owner/settings sources, coordinator logic, and
workspace accepted-write Quit protection were not changed. Other workers' work
was preserved. No Swift invocation, build, test execution, app launch, native GUI,
process control, commit, install, reference application, evidence, or asset reads
were performed. Shell commands used `rtk`. Read-only discovery was limited to
instructions, the approved specification, directory/path existence, and a memory
registry keyword lookup that returned no relevant context. Static inspection
read only this worker's new Swift files.

## Exact public API

```swift
public struct LanguagePreferences: Codable, Equatable, Sendable {
    public var language: InterfaceLanguagePreference
    public init(language: InterfaceLanguagePreference = .system)
    public static let `default`: LanguagePreferences
}

public enum LanguagePreferencesLoadResult: Equatable, Sendable {
    case missing
    case loaded(LanguagePreferences)
    case corrupt
    case futureVersion(Int)
    case oversized
    case unavailable
    public var preferences: LanguagePreferences { get }
}

public enum LanguagePreferencesSaveResult: Equatable, Sendable {
    case saved
    case futureVersion(Int)
    case oversized
    case unavailable
    case encodingFailed
}

@MainActor
public protocol LanguagePreferencesPersisting: AnyObject {
    func load() -> LanguagePreferencesLoadResult
    func save(_ preferences: LanguagePreferences) -> LanguagePreferencesSaveResult
}

@MainActor
public final class UserDefaultsLanguagePreferencesStore: LanguagePreferencesPersisting {
    nonisolated public static let defaultSuiteName = "com.launchcopy.language"
    public init?(suiteName: String = defaultSuiteName)
    public func load() -> LanguagePreferencesLoadResult
    public func save(_ preferences: LanguagePreferences) -> LanguagePreferencesSaveResult
}

@MainActor
public final class UnavailableLanguagePreferencesStore: LanguagePreferencesPersisting {
    public init()
    public func load() -> LanguagePreferencesLoadResult
    public func save(_ preferences: LanguagePreferences) -> LanguagePreferencesSaveResult
}
```

The UserDefaults store also exposes these internal test seams:

```swift
internal init(defaults: UserDefaults)
nonisolated static let payloadKey = "language.payload"
nonisolated static let maximumPayloadBytes = 16_384
```

`InterfaceLanguagePreference` is imported from `LauncherLocalization`, owned by
the other worker. No duplicate enum was created. Its required cases/raw values
are `.system` / `system`, `.simplifiedChinese` / `zh-Hans`, `.english` / `en`, and
`.japanese` / `ja`.

## Storage behavior

- Version 1 is JSON Data with exactly `schemaVersion` and `preferences` keys;
  `preferences` has exactly one `language` key containing a validated raw enum ID.
  Example: `{"schemaVersion":1,"preferences":{"language":"system"}}`.
- Missing remains `.missing`. Reading it returns default preferences without
  creating bytes. Explicitly saving defaults writes the version 1 payload.
- A header with a valid integer future version is inspected before applying
  version 1 body validation. Missing/null/unrecognized future bodies remain
  byte-protected. Invalid JSON or invalid/non-positive schema headers are corrupt.
- JSON Data larger than 16KiB is rejected before JSON decoding, including future
  payloads. Exactly 16KiB remains eligible for decoding.
- Wrong-type property lists are inspected with a bounded content/depth budget,
  without converting them to JSON Data or serializing a potentially huge value.
  Small invalid types are corrupt and explicitly repairable. Exhausted budgets
  are oversized/read-only; nested inspection has a conservative depth limit of 64.
- Every save performs a fresh load inspection. Future/oversized/unavailable
  results reject writes before equality or encoding. Healthy equal values return
  `.saved` without normalization or a write. Missing, corrupt, or different healthy
  data can be replaced by an explicit save, including an equal accepted preference.
- `.preferences` returns the loaded value only for `.loaded`; all degraded states
  expose `.default` without changing their inspection origin.
- The production initializer is failable. Main must choose
  `UnavailableLanguagePreferencesStore` when a persistent suite cannot be created;
  that store always returns `.unavailable`, including after save attempts.
- No `synchronize`, global preferences, in-memory success fallback, AppKit, SwiftUI,
  localization resources, or coordinator are introduced. `.saved` acknowledges the
  UserDefaults API only; it does not establish disk flush or restart durability.

## Authored tests and static inspection

19 XCTest methods were authored, using isolated UUID suites and cleanup. A locked
UserDefaults spy counts payload reads and writes separately. Coverage includes:

- Missing origin, default getter, no startup write, explicit default write, and
  subsequent healthy equal no-op.
- System plus all three explicit language round trips, Codable validation, and
  same-process reopening through the public suite initializer.
- Invalid enum IDs, malformed/invalid schema headers, and strict version 1 shapes.
- Future headers with missing or unknown bodies, including `Int.max`, with byte
  preservation and zero writes for equal and different save requests.
- Oversized Data, oversized future Data, exact-size boundary, and oversized
  wrong-type property lists with unchanged content and zero writes.
- Healthy equal Apply: one fresh payload API inspection, zero persistence writes,
  and byte preservation of noncanonical JSON whitespace/order.
- Explicit known-corrupt repair and late future, oversized, deleted, corrupt, or
  different healthy payload replacements after an initially accepted default.
- Dedicated unavailable-store behavior with no persistent acceptance.

An `rtk proxy python3` static text inspection exited 0: 187 implementation lines,
369 test lines, 19 test methods, no trailing whitespace, and no forbidden imports,
`synchronize`, `UserDefaults.standard`, `AppleLanguages`, or WorkspaceQuit usage
in the new implementation. It also found the six required load origins and the
authored inspection/write counter assertions. This is text inspection only;
it establishes no Swift compilation or XCTest result.

## Main-owned integration and remaining gates

Main must integrate the `LauncherLocalization` dependency and test target imports,
choose the persistent suite/profile, select the explicit unavailable store on
initializer failure, and own accepted/displayed/pending/coordinator behavior.
No healthy/default-origin conflation should be reintroduced by that integration.

Compilation, test discovery/nonzero execution, independent source review, actual
resource/owner integration, exact-profile fresh-process restart, and all GUI and
performance gates remain unverified. The in-process reopen test is not restart
evidence. Foundation suite-creation failure and encoder failure are not forcibly
injected; the unavailable implementation is directly covered, while the enum-only
payload has no naturally failing encoding fixture. Read/write counters measure
UserDefaults API calls, not physical disk IO. Fresh inspection is not a cross-process
compare-and-swap or a disk durability guarantee.

Next action: Main compiles and executes the focused language preference tests once
the localization module and package/test integration are ready, then addresses any
compiler/runtime findings within the same file ownership boundaries.
