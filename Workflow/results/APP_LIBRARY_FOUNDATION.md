# App Library foundation — source freeze

Status: SOURCE_READY_FOR_MAIN_VERIFICATION, 2026-10-15. Foundation sources and tests
are frozen for Main's serial Swift execution and integration review. This is not a
test PASS, independent review verdict, runtime gate or full Library acceptance.

## Scope and authority

Implemented the approved `Docs/APP_LIBRARY_SPEC.md` and detailed slice proposal in
the assigned shared-workspace ownership. Formal Chief workflow was waived by the
human; stage summary and disjoint ownership remain in force. No extra agents were
dispatched. Main retains sole Swift/build/application-process authority.

Preserved the existing dirty tree, including the scanner's existing early
no-follow symlink guard. No commit/reset/clean/install/sign/publish, production
preference changes, localization, Package.swift, AppDelegate, persistence or UI
edits. Prohibited reference/evidence sources were not read.

## Delivered behavior and owner interfaces

- `AppBundleMetadata(declaredCategoryIdentifier:version:build:)` defaults to empty.
  Each optional string is rejected if `utf8.prefix(1025).count` exceeds 1024,
  before trimming or control scanning. Valid surrounding whitespace is trimmed;
  blank/control-containing/oversized fields become nil independently. Values are
  not truncated and version/build are not inferred or coerced from plist numbers.
- `AppRecord(..., bundleMetadata: .init())` remains source-compatible; metadata
  participates in record equality/hash while AppID and icon identity remain stable.
- Scanner extraction reuses its one existing decoded plist dictionary for
  LSApplicationCategoryType, CFBundleShortVersionString and CFBundleVersion.
  Optional corruption does not invalidate an otherwise valid app bundle.
- `AppLibraryCategory` contains exactly the approved 22 cases in approved order,
  with raw suffix IDs and camelCase cases for hyphenated suffixes. Public
  `init(declaredIdentifier:)`, `from(declaredIdentifier:)` and optional
  `declaredIdentifier` support owner/detail composition. Only the 19 enumerated
  game suffixes fold into Games; unknown declarations map to Other. All is nil
  filter state and cannot be decoded as a stored category.
- `AppLibraryPreferences` is pure Codable/Equatable/Sendable. `isValid` uses the
  existing app-management reference grammar: a nonempty bundle:/path: suffix.
  Preferred bundle override wins over normalized canonical-path fallback;
  setting an explicit category replaces the equivalent path override; setting
  nil clears both current keys. Reads/projections never migrate or prune dormant
  entries. Enablement defaults false and is preserved by category mutations.
- `AppLibraryProjection.make(catalog:management:preferences:query:category:locale:)`
  accepts a String query, optional category and injectable Locale. It reuses
  app-management original/effective-alias matching, including empty/whitespace
  queries, folding and hidden filtering. Bundle IDs and paths are not searched.
  Entries contain the canonical record, separate alias display name, effective
  category and optional manual category. Ordering follows the existing catalog
  convention: locale-aware case-insensitive display name, then standardized
  canonical path. Counts contain all 22 categories, including zeros, and reflect
  visible query matches before the selected category filter. Revision is copied
  from the committed catalog, never minted for filters.
- Public entry/snapshot initializers support owner state composition. Enablement,
  scheduling, cancellation and latest-wins publication remain Main's responsibility;
  the pure domain performs no I/O, task creation or UI work. Main's current
  projection-controller call sites match these source signatures on inspection.

## Changed files attributable to this task

1. `Sources/AppCatalogCore/AppBundleMetadata.swift` — new optional bounded value.
2. `Sources/AppCatalogCore/AppCatalogCore.swift` — compatible AppRecord metadata.
3. `Sources/MacAppCatalog/CatalogScanner.swift` — optional extraction/forwarding only.
4. `Sources/AppGridUI/AppManagementPreferences.swift` — alias metadata forwarding only.
5. `Sources/AppGridUI/AppLibraryDomain/AppLibraryCategory.swift` — fixed taxonomy.
6. `Sources/AppGridUI/AppLibraryDomain/AppLibraryPreferences.swift` — pure overrides.
7. `Sources/AppGridUI/AppLibraryDomain/AppLibraryProjection.swift` — pure snapshot.
8. `Tests/AppCatalogCoreTests/AppBundleMetadataTests.swift` — 6 authored tests.
9. `Tests/MacAppCatalogTests/AppBundleMetadataScannerTests.swift` — 8 authored tests.
10. `Tests/AppGridUITests/AppLibraryCategoryTests.swift` — 4 authored tests.
11. `Tests/AppGridUITests/AppLibraryPreferencesTests.swift` — 8 authored tests.
12. `Tests/AppGridUITests/AppLibraryProjectionTests.swift` — 10 authored tests.
13. `Tests/AppGridUITests/BundleMetadataForwardingTests.swift` — 1 authored test.
14. `Workflow/results/APP_LIBRARY_FOUNDATION.md` — this result.

## Record recreation audit

Within AppCatalogCore/MacAppCatalog/AppGridUI, scanner construction now passes
extracted metadata and the sole existing-record recreation in
AppManagementPreferences now forwards it. CatalogFixture.record constructs fresh
fixtures from scalar fields rather than recreating an existing record, and retains
the compatible empty default. Searches of current Sources/PagingPrototypeApp,
Sources/AppIconPipeline and Sources/PagingUI found no other AppRecord constructor
or CatalogFixture.record calls requiring out-of-scope forwarding changes.

## Verification evidence and limits

37 tests authored; **Swift tests executed: 0**. No Swift compiler/build/test or app
process was run, as required. Compilation, XCTest execution, physical performance
and UI acceptance remain unverified. Main must execute focused/full tests serially
and arrange independent source/integration review before assigning acceptance.

Static checks only:

- `rtk git diff --check -- Sources/AppCatalogCore Sources/MacAppCatalog/CatalogScanner.swift Sources/AppGridUI/AppManagementPreferences.swift`
  exited 0.
- An RTK-prefixed Python source audit matched the exact taxonomy order and all 19
  game suffixes to the approved proposal; checked new-file whitespace; verified
  the optional byte-bound check precedes trimming/control scanning; counted one
  plist decode in scanner; confirmed the prior no-follow guard is retained; and
  found no Task/DispatchQueue/FileManager/UserDefaults/NSWorkspace domain APIs.
  These are structural checks, not Swift execution.
- Tests cover XML/binary plists, wrong optional types, independent degradation,
  1024-byte ASCII/multibyte boundaries and 1025-byte rejection before trim,
  scanner failure preservation, alias forwarding, fixed taxonomy, Codable failures,
  preferred/path continuity, dual-key reset, dormant retention, hidden filtering,
  empty/whitespace/original/alias search, canonical records, stable sorting,
  supplied locale and selected-category-independent counts.
- Scanner fixtures use unique FakeAppFactory temporary roots and its existing
  deinit cleanup; no real applications are scanned. Pure tests use synthetic paths
  without creating files or writing preferences. No test query/path offsets are
  persisted or logged by the domain, and no standalone worker tasks are introduced.

## Next action

Main may begin serial Swift tests now against this frozen foundation. Follow with
integration review and the owner/UI/lifecycle/packaging/physical gates; none is
implied complete by this source handoff.
