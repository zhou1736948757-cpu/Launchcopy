# Interface Language — Owner, Store and Resource Seams

Read-only source findings, 2026-10-14. No code changes, builds, process launches or
runtime acceptance. Exact source paths below belong to PagingPrototype only.

## Verified current facts

- Package.swift uses tools5.9/macOS14 with AppKit application/AppGridUI targets;
  no defaultLocalization/resource rules or localization target currently exist.
  Do not adopt unrelated Swift6.4 macros or migrate XCTest for this feature.
- Scripts/package-app.sh:74-80 copies only the known build executable;
  :89-90 fixes CFBundleDevelopmentRegion to zh-Hans; :121-123 optionally copies
  the app icon. There is no SwiftPM resource-bundle packaging step. A successful
  SwiftPM resource build would therefore be insufficient candidate evidence.
- ActivationSettingsWindowController.swift:16-93 hardcodes Chinese UIStrings.
  :491-509 exposes activation/appearance/management/sources tabs, no language tab.
  :165-171 sharedOrCreate reloads existing drafts; :242-246 reload stops recording;
  :583-610 tab/recording lifecycle stops monitors and rewrites captions. Live
  relabeling must be distinct from factories/reload, preserving drafts/recording.
- AppDelegate.swift:174-183 configures the isolated profile BEFORE scalar prefs
  and UI. A language install seam must follow valid profile resolution and precede
  any construction of localized controls, menus or notices.
- UITestProfile.swift:30-40 creates hashed activation/appearance/management/sources
  suites, but no language namespace. Extending it must preserve all existing
  names and candidate storage boundaries, with no fallback to production suite.
- AppearancePreferences.swift:56-104 reads strict schema2 with legacy1 compatibility
  and protects future versions. :137-151 explicitly reinspects persisted state on
  equal Apply; new language preferences should retain this conditional repair rule,
  not change appearance schema or reset it.
- AppSourcesStore.swift:49-74 adds a bounded payload before decoding and protects
  oversized uninspectable data. A small enum payload can follow that pattern with
  a smaller independently documented ceiling and no source-root side effects.
- AppDelegate.swift:1930-1942 appearancePresentationIsReady already checks restore,
  Quit, title context, physical pointer/drag, folder visuals, pinned surface and
  Core state. It is NOT by itself a language readiness predicate: shortcut
  recording, IME composition, menu tracking and sheets/native pickers add owners.
  Do not equate controller idle with physical UP or silently force owner release.
- WorkspaceQuitCoordinator.swift keeps exactly-once pending termination replies.
  AppDelegate.swift:2545-2575 currently drains workspace layout accepted writes,
  not generic preferences. Scalar UserDefaults success is not disk flush proof;
  no claim that this Quit mechanism flushes language bytes is supportable today.
- AppCatalogCore.swift:109-114/240-257 selects catalog comparison using the existing
  ordering locale (nil resolves current OS locale). App interface language must
  not be fed into that policy or mutate displayed/user app names.

## Integration and evidence consequences

The proposal's new neutral localized resources require Main-owned Package.swift
and known-bundle candidate packaging, consumer relabel hooks, a separate language
preference namespace and owner queue. A bulk literal replacement, global
AppleLanguages override, settings reconstruction or binary-only hash is inadequate.

No localization/source modifications are made here. The previous2163/0 test gate
certifies the previous candidate only. Discovery needs user confirmation before
these new interface/data/presentation contracts are implemented. Pending Library,
capacity and physical/GUI/restart gates remain on the full parity ledger.

## Documentation lookup boundary

The initial SwiftPM documentation URL used in lookup returned404 and Apple method
Markdown lookup was unavailable. No implementation conclusion was inferred from
those failed fetches. Official Apple package-localization/resource pages and
WWDC resource-bundle guidance were found and linked in the proposed contract.
No third-party library/source implementation or reference asset was used.
