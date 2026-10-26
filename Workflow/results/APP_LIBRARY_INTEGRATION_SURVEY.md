# App Library Integration Survey

Date: 2026-10-13. Status: PROPOSED CONTRACT; Library-specific approval remains pending.
Scope: source inspection only; sole write is this report. Existing dirty work preserved.
No Swift execution, tests, builds, running-app inspection, production catalog scan, or reference/evidence/assets reads.
Formal workflow waived for this assignment; no dispatch or workflow-state writes. Main + two workers maximum.
Main retains owner/preferences and drag-preview maintenance; grid worker retains Cell/Page/Folder work.
Approved icon/type work (32–64 / 9–16, auto-fit, queued; unchanged capacity) is separate and not surveyed again.
The supplied 2100 tests / 0 failures baseline was not rerun and is not Library PASS.
Paths below are repository-relative; line references describe the inspected working tree and may move during concurrent edits.

## Approved boundary and architecture

- `Docs/LAUNCHBETTER_PARITY_SPEC.md:61–96`: optional separate Library; hidden exclusion; aliases; independent category rules/overrides; preserve AppID and launch validation; separate versioned preferences; atomic idle commits.
- `Docs/LAUNCHBETTER_PARITY_SPEC.md:108–125`: lazy optional UI, off-main I/O, no frame-time classification/scanning/persistence, privacy-safe diagnostics and explicit performance budget.
- `Package.swift:9–49`: macOS 14+, Swift Package, AppKit; Foundation catalog domain, macOS scanner adapter, AppGridUI presentation, application composition root.
- Do not add a negative pager page, alter page count/capacity/physics, derive categories from folders, or migrate workspace layout.
- Suggested/recent sections and usage collection are NOT approved; the discovery table (`Docs/LAUNCHBETTER_PARITY_SPEC.md:42`) is not authorization.

## Exact metadata availability and cheapest acquisition seam

| Available now | Source / limitation |
| --- | --- |
| AppID | `Sources/AppCatalogCore/AppCatalogCore.swift:12–35`; opaque bundle ID or canonical-URL fallback; not Codable and not a storage key. |
| Name | Same file `:66–82`; scanner reads only CFBundleName, falling back to bundle filename (`Sources/MacAppCatalog/CatalogScanner.swift:44–48,227`). No localized/display-name plist handling. |
| Bundle identifier / canonical URL | `AppCatalogCore.swift:69–70`; identifier optional; canonical URL retained for actions. |
| Icon identity / source priority | `AppCatalogCore.swift:71–72`; no icon bytes, source label, category, version, build, size, install date, developer, or usage history. |
| Revision / deterministic catalog | `AppCatalogCore.swift:85–101,150–158,208–249`; default root-priority bundle-ID dedupe, canonical-URL dedupe, original-name ordering. Alternate multi-instance policy can repeat AppID. |
| Alias / hidden status | `Sources/AppGridUI/AppManagementPreferences.swift:18–70`; separately stored and projected, not fields on canonical AppRecord. |
| Folder membership | `Sources/AppGridUI/LayoutDomain/WorkspaceAppReferenceResolver.swift:18–64`; obtainable from canonical layout, not AppRecord; folder title is not category evidence. |

- Best cost seam: `CatalogScanner.swift:19–48,211–232` already deserializes each admitted app's public `Contents/Info.plist` once, on a utility serial queue (`:55–76`). Extract optional category/version/build from that dictionary; no second enumeration or private database.
- Public keys: [LSApplicationCategoryType](https://developer.apple.com/documentation/bundleresources/information-property-list/lsapplicationcategorytype) supplies an app-declared App Store category; [CFBundleShortVersionString](https://developer.apple.com/documentation/bundleresources/information-property-list/cfbundleshortversionstring) is the user-visible release version; [CFBundleVersion](https://developer.apple.com/documentation/bundleresources/information-property-list/cfbundleversion) identifies the build.
- Recommended transport: nullable `AppBundleMetadata(categoryIdentifier, version, build)` on AppRecord with a default nil initializer argument; extend internal BundleMetadataResult and scanner construction. This is a proposed public-domain contract change requiring slice approval.
- Carry the value through `AppManagementPreferences.presentationRecord(for:)` (`:44–54`), which currently reconstructs AppRecord. Preserve identity, icon identity, sorting and dedupe; never classify the alias string.
- Missing/wrong-type/blank optional fields mean unknown, not invalid app/removal. Display raw version strings safely without enforcing App Store formatting on arbitrary local bundles. Bound text/payload lengths.
- Metadata piggyback adds no extra plist read but modest startup decode/memory work even when Library is closed; budget it explicitly. Keep category projection/view allocation lazy.
- Alternative: lazy metadata reader for served canonical URLs avoids AppRecord changes but duplicates plist I/O and needs a revision/URL cache plus source-generation cancellation. Use only if Main rejects the small catalog contract extension.
- A separate side map must retain repository-selected winner URLs and atomic revision alignment; a scanner-global dictionary is not a safe shortcut.
- Defer recursive bundle size, signature/developer verification, Spotlight, package receipts, network/App Store enrichment, and install/use dates. Source priority is not a durable root identity; show app location first.

## Hidden, aliases and reference continuity

- Build Library from `provider.servedSnapshot.records` (`Sources/AppGridUI/AppGridUIPageContentProvider.swift:55–66`), including folder members exactly once under current default dedupe. Do not use presentationRecords: ordinary projection contains only top-level apps; search projection is filtered.
- Reuse `managementPreferences.isHidden`, `displayName`, `alias`, and `matches` (`AppManagementPreferences.swift:30–70`); exclude hidden apps from categories, counts, search, details and action resolution.
- Original name and alias remain searchable; matching is folded literal substring. Bundle-ID/path/category matching is absent (`Sources/AppGridUI/AppSearchMatcher.swift:4–31`) and should remain off unless explicitly selected.
- Persistent keys are `bundle:<id>` or normalized `path:<path>` (`Sources/AppGridUI/LayoutDomain/PersistentAppReference.swift:25–57`); never use display name, hashValue, redactedDescription or AppID internals.
- Existing management uses preferred bundle key then path fallback; hide checks both, unhide/reset alias clears both (`AppManagementPreferences.swift:73–110`). Mirror this policy for category overrides without migrating old layout references.
- Folder actions must resolve the EXISTING saved reference: resolver indexes top-level apps before folder members, selects earliest matching path/bundle entry, and does not rewrite layout (`WorkspaceAppReferenceResolver.swift:15–64`).
- `Sources/AppGridUI/LayoutDomain/VisibleWorkspaceProjection.swift:72–141` retains absent references and appends unorganized apps; `AppDelegate.currentPersistentLayout()` adds that tail (`Sources/PagingPrototypeApp/AppDelegate.swift:1919–1935`). Use it for organization actions.
- Keep absent category overrides dormant for reinstalls/source removal; unknown fallback-path apps moving locations cannot promise identity continuity. Do not auto-prune them.
- Current provider/action lookup is AppID-based, first match (`AppGridUIPageContentProvider.swift:99–110,155,283–289`). Recommend keep default single-instance policy; multi-instance Library support needs an explicit URL-disambiguated contract.

## Safe actions: reuse validation, not cached URLs

- `Sources/PagingPrototypeApp/AppLaunchController.swift:142–165`: cell token revision must equal served revision; reject hidden/missing identity/file; public NSWorkspace open; neutral outcomes. Success hides through existing activation callback (`AppDelegate.swift:611–619`).
- `AppDelegate.swift:1400–1412` creates a member cell with the CURRENT revision. Library must validate its captured revision/URL before calling this helper; otherwise a stale Library selection can be relabeled current and launch a replacement.
- Prefer a shared non-cell validated action request `(AppID, expectedRevision, expectedCanonicalURL)` for Library/keyboard/folder use; extract existing checks rather than create another launch path. Keep neutral failure visible and preserve current launch outcome routing.
- `Sources/PagingPrototypeApp/AppContextMenuController.swift:38–76` captures cell token/revision/URL and revalidates record/hidden/protection on execution. Its weak-cell binding cannot directly serve a new non-grid view.
- Finder reveal currently checks file existence then `NSWorkspace.activateFileViewerSelecting` (`AppDelegate.swift:2048–2050`), after menu validation. Shared Library reveal must re-resolve served record and check expected revision/URL, hidden state and file existence; no scripting/deletion.
- Alias/hide reuse AppManagementCoordinator persistence and owner transaction (`AppDelegate.swift:1894–1915,2020–2050`); future-schema protection blocks mutations, not launch/reveal. Failed writes must not alter the committed view (`Sources/PagingPrototypeApp/AppManagementStore.swift:89–99`).
- Folder assignment policy/controller (`Sources/PagingPrototypeApp/AppFolderAssignmentMenuController.swift:13–44,176–209`) revalidates exact layout, saved reference, binding and protection. Library adapter must retain those expectations without fabricating a live grid cell.
- Commit solely through `AppDelegate.applyFolderAssignment`/`commitWorkspaceLayout` (`:2097–2119,874`), including post-cancel revision/layout recheck. Category changes never invoke LayoutMutation or move apps between folders.
- Add owner lifecycle/sheet/quit gates to Library action requests; do not assume existing grid menu protection alone covers a new mode.

## Owner integration map

| Concern | Existing seam and required Library integration |
| --- | --- |
| Window owner | `Sources/PagingPrototypeApp/LauncherWindowController.swift:22–29,233–234`: reuse resident window; AppDelegate owns `.grid/.library` mode and return context; preferred responder follows active mode. |
| Enter/leave | Proposed owner transition cancels direct navigation/settle through surface API, closes folder immediately, cancels transient input, commits pending data, then swaps sibling content. Reject transition during title edit/sheet/quit/restore; no second launcher. |
| Search | `AppDelegate.swift:647–679`; `Sources/PagingPrototypeApp/AppSearchController.swift:99–139,197–214,252–272`: current search owns pager query and can steal first responder on key regain. Add active-mode routing/suspension; Library uses independent query, matching policy and focus. |
| Keyboard | `Sources/PagingPrototypeApp/KeyboardFocusController.swift:137–202,388–418`: current arrows/Return/Command-F/Escape target grid/folder. Route Library keys before grid equivalents; Tab stays native; no hidden grid activation/typewriter/page turn. |
| Folder | `AppDelegate.swift:778–787,1180–1211`: current mode responder prioritizes title/folder; close via owner before Library. Folder membership remains layout state, classification remains metadata. |
| Pointer/scroll | `AppDelegate.swift:2873–2907,3077–3105`: window intercepts non-cell blank clicks; identify the entire Library root as an interaction zone, including empty/background space. Scope Library scroll to its view; stop pager handling while Library is active. |
| Dots | `AppDelegate.swift:2231–2262`: owner readiness currently ignores Library mode. Disable/hide dots and reject direct-page requests while Library is active; pager count stays grid-only. |
| Hide/reopen | `AppDelegate.swift:2317–2345`: normal hide cancels title/folder/drag/search; did-hide also covers session suspension. Invalidate Library requests/details and reset to grid on both paths; never refocus/order in a hidden window. |
| Quit/teardown | `AppDelegate.swift:2457–2480,2587–2645`: workspace drain owns quit; cancel Library tasks/callbacks before shared pipeline shutdown. Category storage must define its own save/flush behavior; do not bypass quit protection. |
| Settings/layout | `AppDelegate.swift:2079–2093`: restore/read-only/quit gates constrain folder mutation. Library preferences remain separate; toggling Library visibility must leave workspace unchanged and restore mode focus safely. |

## Refresh and generation discipline

- Repository owns monotonic CatalogRevision and latest-wins cancellation (`Sources/MacAppCatalog/CatalogRepository.swift:59–112`); metadata must travel with the winning snapshot, never mint a new catalog revision for manual classification.
- Source coordinator distinguishes apply transaction, watchGeneration and sourceGeneration (`Sources/PagingPrototypeApp/AppSourcesCoordinator.swift:54–86,100–147`); root admission/watching stays with existing owner, not Library.
- Data source configurationGeneration rejects stale root results (`AppCatalogAssembly.swift:110–138,142–187`); replaceScanRoots discards pending catalog/folder/search but retains current query (`:565–578`).
- Library derives only AFTER shared idle commit: `AppCatalogAssembly.swift:538–544`; `AppDelegate.swift:1084–1123`. Cover both catalog update callback paths (`:560–562,660–667`) and metadata-only commits at the SAME revision (`:1906–1915`).
- Search already separates query generation from catalog revision (`Sources/AppGridUI/AppGridSearchPresentationController.swift:26–54,90–102,125–132`). Library requires its own projection/request generation for alias/hide/category/query changes and view lifetime.
- Snapshot request token should contain served revision, Library projection generation and lifecycle generation; details/actions additionally retain AppID + canonical URL. Newer requests or hide/teardown invalidate older completions.
- If using lazy metadata, invalidate on source replacement at `AppDelegate.swift:1804–1808`, even before a new served revision arrives; never expose scanner-pending/cached results directly.
- Preserve last committed data with a refresh/error indicator; after successful source removal, drop absent details/selection and hide corresponding apps while retaining override keys. No classification/image rebuild in frame callbacks.
- Prefer one owner notification after shared commit, not a second refresh controller or replacement of existing callbacks. Category save updates only Library; hide/alias also notify through the shared management transaction.

## Candidate storage namespace proposal

- `Sources/PagingPrototypeApp/UITestProfile.swift:28–38,80–97` derives `com.launchcopy.ui-test.v1.<SHA256(candidate-directory + profile-id)>` and separate activation/appearance/management/sources suites. No Library suite exists.
- Add `librarySuiteName = namespace + ".library"`; proposed production suite `com.launchcopy.app-library`, payload key `library.payload`, schema version 1. Store only enabled preference/category overrides; query, selection, metadata cache and usage history remain unpersisted.
- Follow versioned/size-bounded preferences and save-before-publish pattern (`AppManagementStore.swift:29–60,89–99`); future schema read-only, corruption reported with safe defaults, no silent overwrite on load. Define explicit reset recovery.
- `AppDelegate.swift:145–170,523–529,1789–1800` resolves isolation before preferences, requires windowed mode, rejects unsafe/outside-synthetic roots and selects profile suites. Apply identical guards before opening the Library store; no production fallback for an invalid profile.
- In-memory store injection must support synthetic acceptance. Do not modify/open actual suites, profile directories or synthetic apps during this survey. UserDefaults save acknowledgement is not restart durability evidence.

## Decisions required in the Library slice specification

All recommendations below remain proposals; Main must obtain confirmation before Library implementation.

| Decision | Recommended minimal contract / unresolved branch |
| --- | --- |
| Enablement | Default disabled; settings checkbox exposes an explicit Library/Back control in the same window; no swipe entry or new shortcut. Confirm default and entry label. |
| Taxonomy | Fixed flat public category mapping with stable IDs plus Other; All is a filter, not a stored category. Use recognized declared categories, fold game subcategories into Games, unknown/missing into Other; freeze complete mapping/order/localized labels in spec. Confirm flat categories versus fewer broad groups. |
| Auto/manual | Automatic classification by declared category only; one manual category per app wins; “Automatic” removes both preferred/path override keys. Refresh updates automatic value, never overwrites manual. No name heuristics, learning or multi-category membership. Confirm override/reset and dormant-key policy. |
| Display/order | Section/category list with one app per selected category; alias as primary name; stable localized alias/name sort + canonical URL tie, no ranking. Omit empty category sections but keep Other selectable. Confirm section counts and ordering. |
| Details | Read-only original name, alias, effective category + automatic/manual source, bundle ID, location, optional version/build; safe open/reveal and category picker. Unknown clearly labeled; no size/developer/install/use data. Confirm fields and presentation (recommended side pane, not another window). |
| Return/query/focus | On enter, remember grid AppID/top-level anchor, page and query; Library starts with empty query and search focus. Back restores saved grid query then resolves focus against latest committed layout; missing/hidden anchor uses existing fallback. No folder restoration. Confirm query carryover versus independent queries. |
| Escape/activation | Editor/sheet cancellation first, then details close, nonempty Library query clear, then Back to grid; only subsequent grid Escape uses existing hide ladder. Query Return/Down selects first result without launching; selected result Return launches. Confirm this ladder. |
| Background/lifecycle | Library blank space stays interactive; explicit Back/Escape returns, normal launcher hide resets mode/query. Successful launch hides as today; Finder reveal retains current Library state. Confirm reveal and reopen behavior. |
| Action breadth | Reuse existing launch/reveal/alias/hide/folder assignment via shared request validation; no Library drag, folder creation or deletion. Category changes do not organize grid. Confirm which actions appear in details/menu. |
| Privacy | No recent/suggested sections, timestamps, counters, global app-activation observation, query history, upload or network enrichment. Any future usage feature requires a separate approved retention/opt-out/reset contract. |
| Acceptance/budget | Main sets matched catalog workload and startup/Library-open/projection memory/latency budget; require synthetic identity/hidden/override/source races and isolated candidate keyboard/hide/restart acceptance. Current baseline and icon/type acceptance do not establish Library acceptance. |

## Actionable minimal interface plan (after approval; Main owns integration)

1. Confirm the decision table, then write/approve a bounded Library slice spec; do not start Library code from this survey.
2. Add optional AppBundleMetadata via the existing plist decode; preserve alias-copy forwarding and default fixtures. No module/dependency or pager changes required.
3. Add pure `LibraryPreferences`/`LibraryCategoryPolicy` and `LibrarySnapshot` projection over canonical served catalog + committed management preferences + overrides + independent query. Keep UI callbacks free of I/O.
4. Add injected versioned Library store/coordinator and profile `.library` suite; persisted mutation must succeed before projection publication. Explicitly resolve quit/durability handling rather than treating defaults.set as disk flush.
5. Add a lazy AppKit Library sibling view/controller with independent responder, categories/details/query and lifecycle tokens; consume a snapshot, emit typed requests, never own catalog/layout/window services.
6. Generalize shared action validation to immutable identity/revision/URL expectations; adapt existing grid and Library consumers without weak-cell fabrication; reuse folder policy and sole workspace commit owner.
7. Main wires `.grid/.library` mode, saved return context, responder/input/dots gates, interaction-zone recognition, source invalidation, committed-data notification, hide/quit/teardown. Avoid concurrent writes to Main's owner/preferences or the grid worker's files.
8. Main schedules focused verification/build/candidate acceptance only after implementation approval and ownership handoff; no verification execution was performed here.

Deliverable: this report only. Survey findings are source-backed; taxonomy, UI semantics, storage additions and interfaces are proposed, not Library PASS or implementation authorization.
