# Concise folder names: independent bounded source review R1

Verdict: **SOURCE PASS**. No actionable finding in the frozen six-path naming scope. No implementation correction is recommended.

Reviewed at: 2026-10-26T00:55:43+09:00. Repository: `/Users/mac/Projects/Launch_Copy/PagingPrototype`.

## Authority and evidence boundary

Independent SOURCE reviewer only. Main remains the sole build/test/package/native UI owner. This review executed **no builds, tests, UI operations, process control, profile operations, reference-tree reads, or Git mutations**. Only this report was written. One read-only scoped Git tracked-file listing was used; the dirty tree was otherwise left intact. No subagents were dispatched by this reviewer.

The governing contract is `Docs/FOLDER_NAMING_AND_CATALOG_WARNING_2026-10-24.md:37-50`, especially the dated 2026-10-26 supersession at lines 43-48, together with `Workflow/stage-summaries/2026-10-26-concise-folder-names.md`. This is the existing SwiftPM/Swift/AppKit macOS 14+ project: AppGridUI owns the pure policy and existing drag/mutation domain; PagingPrototypeApp composes committed catalog, category preferences and localization snapshots.

## Reviewed scope and independent hash checks

Compared the two 610-entry supplied manifests as data: their differences are exactly the six paths in `source-delta-r1.json`, with no additional manifest difference. Independently recomputed current SHA-256 for **23 distinct files: 6/6 scoped files plus 17/17 supporting files match `source-inputs-r1.json`**. All 17 supporting files also match `source-baseline-r1.json`. Checks were repeated immediately before writing this report. The other 587 current inputs were not reread or rehashed by this reviewer; Main's whole-input freeze verification remains inherited evidence.

| Scoped file | Source inspection coverage | Frozen/current SHA-256 |
| --- | --- | --- |
| `Sources/AppGridUI/LayoutDomain/FolderCreationTitle.swift` | Entire pure policy | `fc948a64094f990865aa398b7f51429ae3aed2187fffefa7bd42ab2ee5a6e0d9` |
| `Sources/PagingPrototypeApp/FolderCreationNaming.swift` | Entire composition | `3d91a22c485e252ff022681641dd708ab20d3d45c48be16536cfedce75a4a973` |
| `Sources/PagingPrototypeApp/AppDelegate.swift` | Naming provider at 1142-1148; immediate installation/commit context only | `536843a7c55140ef49f6ca6ac1325cf822185491cd166285566341ae5ba7f027` |
| `Tests/AppGridUITests/FolderCreationTitleTests.swift` | All 32 methods and helper | `df64c535554a52b9931b2a0af7330844d1528d91b71b68dfa1ddb29ac8498d21` |
| `Tests/PagingUITests/FolderCreationNamingTests.swift` | All 10 methods and helpers | `deae1c9b9a8e7319e3d5c5bbb338aebb7f51e6b32c3db44e18a3223c6c293140` |
| `Tests/PagingUITests/AppDelegateBoundedRegressionTests.swift` | Eight naming methods at 533-680, naming drag helper at 490-530, necessary fixture/mouse/store dependencies only | `f43ec817ad72bf8df3d25d1b70cca42acba602343d5c1388765c7310eee4d204` |

Supporting inspection was limited to the relevant category, title-normalization, reference, release-validation/mutation, localization and test-owner sections of these unchanged files:

- `Package.swift`
- `Sources/AppGridUI/AppLibraryDomain/AppLibraryCategory.swift`
- `Sources/AppGridUI/AppLibraryDomain/AppLibraryPreferences.swift`
- `Sources/PagingPrototypeApp/AppLibraryCategoryLabels.swift`
- `Sources/AppGridUI/FolderDomain.swift`
- `Sources/AppGridUI/DragSession/DragSessionController.swift`
- `Sources/AppGridUI/DragUI/DragUISessionCoordinator.swift`
- `Sources/AppGridUI/DragSession/DropResolver.swift`
- `Sources/AppGridUI/DragSession/DragMutationEngine.swift`
- `Sources/AppGridUI/LayoutDomain/LayoutMutation.swift`
- `Sources/AppGridUI/LayoutDomain/PersistentAppReference.swift`
- `Tests/AppGridUITests/FolderCreationDropContextTests.swift`
- `Sources/LauncherLocalization/GridTextKey.swift`
- `Sources/LauncherLocalization/Resources/en.lproj/Localizable.strings`
- `Sources/LauncherLocalization/Resources/zh-Hans.lproj/Localizable.strings`
- `Sources/LauncherLocalization/Resources/ja.lproj/Localizable.strings`
- `Sources/LocalizationResourceProbe/main.swift`

## Source findings and rationale

1. **Correct target/source priority and restricted inputs.** `FolderCreationTitle.swift:9-21` accepts category enums, injected labels, fallback and occupied titles. It excludes `.other`, rejects missing/unusable labels, then selects target, source and neutral fallback in that order. No display name, alias, brand list, name joiner or balanced-pair input/machinery remains in this policy. `FolderCreationNaming.swift:11-22` resolves stable references against the served catalog and uses `AppLibraryPreferences.category(for:)`; its owner at `AppLibraryPreferences.swift:26-33` checks committed manual overrides before declared metadata without consulting `enabled`. `AppDelegate.swift:1142-1148` supplies the current committed preference snapshot and displayed strings. Current call sites preserve target/source order. Reversed-drop and source-only tests directly exercise that distinction.

2. **Title safety and deterministic uniqueness remain covered.** `FolderCreationTitle.swift:23-86` normalizes comparison copies of occupied titles, retains the 64-Character/grapheme limit, strips unsafe format controls, collapses whitespace/control runs, and preserves script joiners, variation marks, ZWJ emoji and subdivision-flag tags. Case/diacritic comparison uses the fixed POSIX locale. Collision candidates reserve suffix space before grapheme clipping and try 2, 3, ... to fill the smallest unused suffix. The 32 active pure tests retain explicit coverage for literal strings, controls, meaningful-content rejection, Unicode preservation, clipping, canonical/case/diacritic collisions, multi-digit suffixes, clipped-candidate collisions, gaps, duplicate/order invariance and immutable saved inputs (`FolderCreationTitleTests.swift:56-206`). Target/source-label fallthrough and uniqueness of both categories and neutral titles are covered. No scoped test is disabled or converted into a skip.

3. **Accepted actual release and one mutation.** The unchanged `DragUISessionCoordinator.swift:474-490` supplies fresh release geometry/layout to `DragSessionController.pointerUp`. The latter recomputes the release intent, validates layout/catalog and consumes the resolver before invoking naming only for an accepted create-folder from a top-level app (`DragSessionController.swift:209-241`; `DropResolver.swift:28-45`). Naming receives the accepted target, not the previous hover. `DragMutationEngine.swift:50-55` calls the existing single `LayoutMutation.createFolder`; `LayoutMutation.swift:102-129` keeps members `[target, source]`, preserves other folder records and increments generation once. The naming window helper asserts one callback, one generation increment and exact member order (`AppDelegateBoundedRegressionTests.swift:515-529`). The unchanged `FolderCreationDropContextTests.swift:11-85` retains explicit changed-release-target/one-consumption, stale-layout/catalog, click/cancel and reorder controls. Source inspection confirms move-into-folder and other accepted non-creation intents bypass naming as well.

4. **Saved content and ownership remain intact in inspected source.** Composition reads `layout.folders.map(\.title)` only; there is no rename, migration, editor-opening or preference-write path. Composition tests use the real persistence codec to round-trip generated category/neutral titles and existing synthetic pair titles while requesting other languages (`FolderCreationNamingTests.swift:99-167`). These are codec round trips, not independent filesystem reload or live-profile evidence. Window naming tests preserve existing IDs/member arrays/titles and committed aliases while generating the new title (`AppDelegateBoundedRegressionTests.swift:600-639`). Exact preservation of the user's current profile remains Main-owned evidence; this reviewer neither read its contents nor operated on it.

5. **Bounded cost and compatibility.** The inspected policy/composition performs synchronous local value work on an accepted creation. No new filesystem/network operation, task, timer, persistence pass or frame callback appears in the scoped product code. Unchanged release/mutation owners preserve routing and mutation semantics; this is a source conclusion, not a measured performance result. The three fallback resources remain Apps / 应用 / アプリ. `GridTextKey.swift:17-18,36-37`, the three resource files at lines 405-406, and `LocalizationResourceProbe/main.swift:28-33` deliberately retain the unused naming joiner and existing 369-key inventory. Its retention is intentional compatibility, not a finding.

## Removed pair rules and test-count reconciliation

Current source independently contains **32 pure-policy methods, 10 composition methods and 66 actual-owner class methods**; only the eight naming methods and necessary helpers in the latter were audited. Required non-pair safety coverage remains explicit as described above. The removed product inputs cannot be used to concatenate or infer app names because they are absent from the policy/composition interface.

Main supplied the historical reconciliation: pure 43 -> 32 after removing obsolete name/joiner/balancing expectations, composition 5 -> 10, actual-owner class 63 -> 66; net -11 +5 +3 = -3, explaining full 3781 -> 3778. The present counts and current non-pair coverage were independently inspected; the historical counts and exact deletion classification are **Main-supplied**, not reconstructed from old hashes. The completed full-run metadata records plain `swift test`, with no filter/skip argument. It supports a real full run rather than a filter-only substitute; it is not a historical text diff.

## Inherited Main verification logs, read after completion

All paths below are under `.build/verification/20261026/concise-folder-names/`. These were **read**, never independently rerun by this reviewer.

| Main artifact | Observed result and precise evidence |
| --- | --- |
| `before-r1.json` / `before-r1.log` | Exit 1; 2 executed tests, 2 assertion failures. Log lines 17,20 show the old concatenated result versus desired category/neutral title; lines 23-27 record the nonzero RED gate. |
| `focused-r1.json` / `focused-r1.log` | Exit 0; 132 tests / 0 failures, log lines 298-301. Actual suites: owner 66, B1 24, composition 10, pure 32. |
| `full-r1.json` / `full-r1.log` | Exit 0; unfiltered command; 3778 tests / 0 failures, lines 8696-8699. Unchanged drop-context guards also ran: 3 / 0 at lines 3516-3517. |
| `debug-build-r1.json` / `.log` | Exit 0, build-complete line 4. Subject to the wrapper-order exception below. |
| `package-release-r1.json` / `.log` | Exit 0. Log lines 3-15 show production build and assembly from the release executable; line 17 reports packaged-only verification of 3 languages and 369 keys/signatures. No independent package/release certification follows. |
| `debug-build-r2.json` / `.log` | Exit 0; completed after the package; build-complete line 4. Definitive subsequent Debug evidence supplied by Main. |

The zero-test Swift Testing footer is not used as a passing gate. The nonzero XCTest suite totals above are the inherited test evidence.

**Operational correction:** Main disclosed that the initial package wrapper was dispatched before the Debug-r1 wrapper returned. `package-release-r1.log:2` explicitly records SwiftPM waiting for the existing build lock; the wrappers were therefore not strictly serial. No simultaneous compilation is evidenced by these logs. Main then completed Debug-r2 after package termination: package completion metadata is 00:51:15 +09:00 and Debug-r2 completion is 00:51:34 +09:00 with a 2.117-second wall duration. This correction is retained rather than claiming strict initial wrapper serialization.

## Limits and disposition

- The baseline contains hashes, not pre-edit source bodies. It proves manifest path/hash differences, not exactly which old lines were removed. In particular, the claim that AppDelegate changed only by deleting one unused argument, and that every historical deletion was pair-specific, cannot be independently reconstructed from those hashes. No pre-task textual snapshot or reference tree was read. The current bounded provider call and all required present safety behavior were inspected directly.
- No verdict is given on the unrelated dirty tree, all 610 current files, all 66 owner methods, the user's exact live profile, or historical implementation parity.
- **SOURCE PASS certifies no actionable scoped source finding only.** It does not certify human naming aesthetics, the original intermittent physical-drag cause, a newly created native title, full parity, native acceptance, signing, distribution or release. Main retains those gates and all operational ownership.

Reviewer write set: only `Workflow/reviews/CONCISE_FOLDER_NAMES_2026-10-26-r1.md`.
