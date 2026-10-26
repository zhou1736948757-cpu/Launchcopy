# Language UI Surface Survey

Date: 2026-10-14  
Project: `/Users/mac/Projects/Launch_Copy/PagingPrototype`  
Status: bounded static source inventory; no implementation or runtime acceptance.

## Scope and evidence boundary

The task covers launcher UI text, AppKit accessibility text, menus, alerts, settings, and their source-level data/lifecycle contracts. “Shipped” here means a path wired into the ordinary application in the inspected source, not verification of an installed binary or release bundle.

Read the project's `AGENTS.md` and `/Users/mac/.codex/RTK.md`. The user's explicit chef-workflow waiver and single-report write boundary supersede workflow dispatch/state/stage-summary requirements for this task. Subagents were authorized with a maximum of three agents including Main, but no subagent spawn/delegation tool was available in this session. Main performed all inspection, including separate store, profile, and lifecycle checks. No independent subagent/reviewer verdict is claimed.

Inspection used RTK-prefixed, read-only shell commands over:

- `Package.swift`, `README.md`, all 147 Swift files under `Sources/` for candidate searches, and selected source excerpts for ownership/call-path analysis.
- Localization-related filename discovery in `Sources/` and `Resources/`; resource pixels/content were not opened.
- `Scripts/package-app.sh` and `Scripts/package-app-smoke.sh` as text only.
- Selected tests as source text, to identify existing assertions and fixtures. The 189 test files were additionally hashed, not executed.

Excluded: LaunchBetter, BuhoReverseNotes, evidence/assets/reference source material, historical evidence and reference documentation, generated build artifacts, installed applications, user preference data, native GUI and live processes. No Swift command, build, test execution, app launch, installation, process alteration, commit, or source/test/package edit occurred.

Only this report is owned and written:
`Workflow/results/LANGUAGE_UI_SURFACE_SURVEY.md`.
Other contributors' work was not reverted. A start/end-of-inspection hash comparison of 339 source/test/package/packaging-script files found no content drift. This is a bounded file-content observation, not a clean-working-tree claim.

## Current architecture and localization support

This is a SwiftPM macOS 14+ AppKit application. `PagingPrototypeApp` owns composition, resident launcher lifecycle, settings and menus; `AppGridUI` owns cells, folders, catalog states, search presentation and persistent layout; `PagingUI` owns page hosts/surface/accessibility and the neutral renderer. `AppCatalogCore` supplies identity/catalog logic; `MacAppCatalog` scans metadata; `AppIconPipeline` loads icons; `PagingCore` and `PagingTelemetry` supply paging logic and diagnostics. Target/dependency boundaries are in `Package.swift:10–65`.

There is **no product localization implementation found in the inspected source/configuration scope**:

- No `NSLocalizedString`, `String(localized:)`, `Bundle.module`, localized-string helper, application language preference, or language-change refresh path was found.
- No `.strings`, `.stringsdict`, `.xcstrings`, `.lproj`, `.xib` or `.storyboard` names were found under the inspected source/resource roots. UI construction is programmatic.
- `Package.swift:10–65` declares neither `defaultLocalization` nor target resource processing. The top-level resource filenames are app icons.
- `Scripts/package-app.sh:89–100` declares `CFBundleDevelopmentRegion = zh-Hans` and product-name metadata. Its assembly path copies the executable and optionally the icon (`76–79, 121–122`), with no localized resource-bundle copy path. A development-region declaration alone does not translate literals or prove multilingual delivery.
- `ActivationSettingsWindowController.swift:16–95` calls its constants “localization-ready,” but these are literal Chinese strings and functions, not lookups. Many accessibility labels, tab titles, alerts and settings messages bypass even that enum.
- `AppSearchQuery.swift:18–35` uses `Locale.current` for search folding; `AppCatalogCore.swift:109–112, 201` uses locale for comparison/identity policy. These do not provide UI language selection. POSIX locales in layout/telemetry timestamp formatting are diagnostic/persistence concerns.
- `MacAppCatalog/CatalogScanner.swift:38–48, 227–230` reads raw `CFBundleName` from the application's Info.plist and falls back to the bundle basename. It does not resolve localized application display-name resources. Catalog names are external content, independently of translating launcher chrome.

The current UI mixes Chinese settings/menu/alert strings with English search, grid status, folder assistance and page descriptions. Hot Corner and keyboard names also remain English inside Chinese settings. This finding describes source text, not the effective language of OS-provided panel chrome.

## Inventory and approximate size

The reproducible candidate ledger in Appendix A contains **207 source-line sites in 19 files**. A site is a nonempty product literal/template source line, including accessibility-only copy and strings later forwarded to a view. Multiple strings on a line count once; duplicate visible/accessibility definitions count separately. These are approximately 210 localization review sites, not 207 unique translation keys, widgets, currently visible controls, or runtime states.

The ledger excludes data-only names, brand/symbol decisions, fixture/test titles, neutral-mode labels and diagnostic output. Some candidates are backing text or gated status branches rather than always-visible UI. Additional consumers outside the 19 producer files include `AppGridStatusView.swift`, `StatusItemController.swift`, `AppGridUIPageContentProvider.swift` and drag preview views.

All paths below are relative to the project root. Line numbers refer to the inspected snapshot.

| Module/file | Concrete sites and content | Important presentation boundary |
| --- | --- | --- |
| PagingPrototypeApp/ActivationSettingsWindowController.swift | `Sources/PagingPrototypeApp/ActivationSettingsWindowController.swift:18–50`: window, section/control/action, corner, recording, readiness, alert and status-menu constants. `68–90`: login/readiness/validation templates. `294`: reset result. `385–485`: independent accessibility labels. `495–507`: four settings tab labels. | Shared window is built once; static captions/labels and popup items are separate from current draft/status values. `368, 564–568, 628–634, 716–725` consume these strings. |
| PagingPrototypeApp/ActivationSettingsCoordinator.swift | `Sources/PagingPrototypeApp/ActivationSettingsCoordinator.swift:81, 162, 167`: unavailable coordinator, partial login acceptance and future-schema messages. `186, 197–203`: four-finger readiness details. | Service states are semantic outcomes; translated messages must preserve partial acceptance, enabled-versus-ready and rollback meaning. |
| PagingPrototypeApp/AppearanceSettingsView.swift | `Sources/PagingPrototypeApp/AppearanceSettingsView.swift:11–60`: labels, buttons, slider accessibility, ranges/units and explanatory text. `124–126, 145, 163–178, 196–200`: future/corrupt/invalid/unavailable/save/default/applied/queued messages. | Numeric slider values use `String(Int)` at `153–155, 185–189`; treat number/unit formatting separately. Saved does not necessarily mean presented. |
| PagingPrototypeApp/AppManagementSettingsView.swift | `Sources/PagingPrototypeApp/AppManagementSettingsView.swift:14–45`: hide/alias/reset controls, placeholder, accessibility and help. `82–98`: prompt, hidden suffix, hidden-reference count and load errors. `130–133`: save/error outcomes. | `85` combines alias and original name with a dash; `86` adds a translated status wrapper. Names remain data. Population/reload preserves selected AppID but overwrites the alias field at `105`. |
| PagingPrototypeApp/AppSourcesSettingsView.swift | `Sources/PagingPrototypeApp/AppSourcesSettingsView.swift:11–44`: controls, accessibility, headings/help. `89–98`: load/watch states. `109, 135, 144, 164–166, 179–183`: prompt, draft feedback, open-panel prompt and admission/apply outcomes. | Paths at `87, 111` remain literal data. Only the open-panel prompt is app-owned; native panel chrome needs later runtime validation. Asynchronous completion can write messages after other events. |
| PagingPrototypeApp/AppSearchFieldView.swift | `Sources/PagingPrototypeApp/AppSearchFieldView.swift:19, 21`: English accessibility label and placeholder. | Search query/field editor contents are user input; never replace them during text refresh. |
| PagingPrototypeApp/FolderTitleEditor.swift | `Sources/PagingPrototypeApp/FolderTitleEditor.swift:38, 42`: Chinese placeholder/accessibility label. | `26` is a fallback data title, not an ordinary UI caption. Active editor contents have their own commit/cancel contract. |
| PagingPrototypeApp/AppContextMenuController.swift | `Sources/PagingPrototypeApp/AppContextMenuController.swift:44–45, 54`: open, alias, restore, hide, Finder reveal, organization parent. | Five action/title tuples span two source lines. Action strings/identifiers are contracts, not translations. Menus are constructed on demand. |
| PagingPrototypeApp/AppFolderAssignmentMenuController.swift | `Sources/PagingPrototypeApp/AppFolderAssignmentMenuController.swift:126, 137`: folder submenu and move-out action. `144–160`: duplicate destination-title formatting. | Folder names and destination identity stay unchanged; ordinal suffixes are display-only and collision-aware. |
| PagingPrototypeApp/StatusItemController.swift | `Sources/PagingPrototypeApp/StatusItemController.swift:203–204, 233, 338`: LC/Launchcopy brand text and accessibility. `236–259`: show/hide, settings, quit consume the shared settings constants. | `276–292` only refreshes/validates the show/hide title. Settings/quit are materialized at menu creation. No additional ordinary literal candidates beyond the constants ledger. |
| PagingPrototypeApp/PageDotsView.swift | `Sources/PagingPrototypeApp/PageDotsView.swift:36, 53, 56, 168, 184–188`: navigation group, previous/next window of pages, page/count/no-pages, selected suffix/value. | `151–189` handles windowed button reuse and clears hidden buttons' labels/values. One page template feeds both tooltip and accessibility. |
| PagingPrototypeApp/ShortcutRecording.swift | `Sources/PagingPrototypeApp/ShortcutRecording.swift:57, 69–74`: named keys; `100, 102`: unknown-key-code descriptions; `120, 122`: custom preset title. | Letters/digits/modifier glyphs and virtual key codes have input meaning. US ANSI display mapping at `19–79` is a separate keyboard-layout limitation; translating words cannot fix layout mapping. |
| PagingPrototypeApp/LaunchAtLoginService.swift | `Sources/PagingPrototypeApp/LaunchAtLoginService.swift:158–163`: two English neutral failure messages. | These are UI-facing via the Chinese login-status wrapper, despite originating in a service. Preserve neutral sanitization; do not surface raw NSError details. |
| PagingPrototypeApp/AppDelegate.swift | `Sources/PagingPrototypeApp/AppDelegate.swift:982, 986`: save notice/accessibility. `1678–1685`: app/View menus. `2213–2251`: organization rejection, alias sheet and management save errors. `2271, 2275, 2277`: settings image/accessibility/tooltip. `2594–2598`: quit-save warning/buttons. | Main menu is installed at `443`. Main-menu quit names Paging Prototype, while status-menu quit names Launchcopy: a source naming inconsistency to decide explicitly. `349` is an isolated-test title, excluded from ordinary candidates. |
| AppGridUI/AppGridUIState.swift | `Sources/AppGridUI/AppGridUIState.swift:29–34`: six English loading/ready/empty/partial failure/refreshing/no-results descriptions. | Used as both visible status and accessibility by `AppGridStatusView.swift:50–53`; actual on-screen reachability varies by state. |
| AppGridUI/AppGridCellView.swift | `Sources/AppGridUI/AppGridCellView.swift:155, 160`: member count and folder help. `138–141, 153–159`: app/folder names feed label, tooltip and accessibility. | Preserve complete names even with hidden/truncated labels. Counts require singular/plural review; reused cells clear old accessibility at `171–180`. |
| AppGridUI/AppGridPageView.swift | `Sources/AppGridUI/AppGridPageView.swift:168, 170`: English page/count backing label and group accessibility. | Backing page label is hidden in initialization (`145`); do not count it as proven visible chrome. Render/reuse and teardown paths reset text. |
| AppGridUI/FolderOverlayView.swift | `Sources/AppGridUI/FolderOverlayView.swift:298–299, 533–534, 805`: previous/next accessibility, rename tooltip and parameterized accessibility, inner-page counter. `417, 419, 532`: persisted folder title consumers. | Chevron glyphs at `290–291` are symbols. Inner counter only appears for multiple pages. Visual-only exit overlays disable accessibility/interaction at `370–383`. |
| PagingUI/PageHostView.swift | `Sources/PagingUI/PageHostView.swift:69`: English page/count accessibility label. | Host pool reuse creates another page-description owner independent of grid page, surface and page dots. |
| PagingUI/PagingSurface.swift | `Sources/PagingUI/PagingSurface.swift:920`: English page/count accessibility value. | Uses transition target while settling, rounded visual page while tracking, committed page otherwise (`911–923`). Text refresh must preserve those semantics. |

The other source modules yielded identity keys, metadata, diagnostic strings, symbols or content carriers rather than additional ordinary product copy in this bounded search. This is a static classification, not proof that every future/conditional runtime text path has been exercised.

## Data, fixtures and diagnostics: keep these categories separate

| Category | Evidence | Localization treatment |
| --- | --- | --- |
| Persisted folder names | `LayoutDomain/PersistentWorkspaceLayout.swift:39–55`; `LayoutStore/LayoutStoreCodec.swift:72–76, 164, 277` under AppGridUI. Titles pass through provider `AppGridUIPageContentProvider.swift:392` and overlay `417, 419, 532`. | User/content data. Do not translate on reload, language change, layout encoding or restoration. |
| Production default folder title | `Sources/AppGridUI/LayoutDomain/LayoutMutation.swift:114–117, 133–138` creates and stores “Group N,” checking existing titles for uniqueness. | **Not fixture-only.** If default naming becomes localized later, define creation-time behavior and collision policy; existing stored strings must remain unchanged. Changing collision matching to translated output is a domain-contract decision. |
| Editor fallback | `Sources/PagingPrototypeApp/FolderTitleEditor.swift:26, 81`; AppDelegate sets fallback and starting value to the existing title at `1522–1523`. | Generic “Folder” is a fallback. Ordinary composition overrides it with stored data. Do not translate an active draft or reset the fallback as a side effect. |
| App aliases/original app names | `Sources/AppGridUI/AppManagementPreferences.swift:7–13, 36–53, 88–104`; management store `Sources/PagingPrototypeApp/AppManagementStore.swift:29–58`. | Persisted alias data keyed by stable references. Translate only surrounding help/status/hidden markers. Do not rewrite bundle metadata or aliases. |
| Source paths | `Sources/PagingPrototypeApp/AppSourcesPreferences.swift:4–43`; settings view `87, 110–111`. | File-system data, not resource keys. Preserve paths exactly; test wrapping and accessibility without logging user values. |
| Folder-lab group names | `Sources/AppGridUI/FolderLabFixture.swift:25, 51, 65`; factory gate `Sources/PagingPrototypeApp/AppCatalogAssembly.swift:428–431`. | Same “Group N” text, but gated by opt-in `--folder-lab`. Keep separate from the production default-name site. |
| Neutral renderer | `Sources/PagingUI/NeutralPageRenderer.swift:51, 61–66`; `Sources/PagingPrototypeApp/AppDelegate.swift:545–551`. | Page description and slot numbers in neutral/fallback content, not ordinary catalog labels. Shipping code includes this regression/fallback renderer, so do not silently ignore it in later release-mode acceptance. |
| Test-window titles | `Sources/PagingPrototypeApp/AppDelegate.swift:349`; `LauncherWindowController.swift:366–374`. | “Isolated UI Test”/“UI Test” are profile/windowed-test chrome, not normal borderless-launcher text. |
| Test fixtures/assertions | E.g. `Tests/PagingUITests/AppearanceRendererLabelsTests.swift:51, 91` (“Fixture …”), `FolderRenameAssemblyTests.swift:126, 270`, and `Tests/AppGridUITests/FolderTitleEditingHostTests.swift:62–65`. | Fixture names are data; expected product copy is an assertion to update deliberately, not evidence of another shipped UI site. |
| Brand and symbols | Status item `203–204, 233, 338`; drag preview `Sources/AppGridUI/DragUI/DragUIVisuals.swift:28, 361`; folder chevrons `290–291`. | LC/Launchcopy and plus/chevron/modifier glyphs need explicit brand/symbol policy. Drag preview names are content, not translated captions. |
| Developer diagnostics | `Sources/PagingUI/PagingSurface.swift:928–941`: opt-in paging-lab state overlay. AppDelegate print output, `AppArguments.swift` help, `FrameDriverExperiment.swift:209, 218`, telemetry JSON/event names, invariant descriptions, preconditions/fatalError. | Exclude from product-key counts; preserve machine-stable event/schema/identifier text. The lab overlay is conditionally visible but diagnostic. Service errors that actually feed alerts, such as the two login failures above, are the exception. |

## Main's independent contract inspection

### Stores and serialization

The inspected stores are separate, schema-aware owners, not a shared UI-language store:

| Owner | Contract found |
| --- | --- |
| Activation | `ActivationPreferences.swift:123–130, 145–205`: named suite `com.pagingprototype.activation`, schema 2, four-finger flag and JSON settings payload; future schema refuses writes. `ActivationSettings.swift:18–65` stores enable flags, corner and shortcut specification, not captions/language. |
| Appearance | `AppearancePreferences.swift:56–102`: suite `com.launchcopy.appearance`, versioned payload (reads versions 1/2), future-version write protection. `5–27` contains labels visibility, blur, icon and font sizes. |
| App management | `AppManagementStore.swift:29–60`: suite `com.launchcopy.app-management`, version-1 payload, future-version protection. Aliases/hidden references are data, not localized strings. |
| Sources | `AppSourcesStore.swift:30–76`: suite `com.launchcopy.app-sources`, version-1 payload, future-version protection; custom root paths and automatic refresh are the data. |
| Layout | `Sources/AppGridUI/LayoutStore/LayoutStoreCodec.swift:72–99, 153–172, 271–277`: schema-1 envelope preserves folder titles/reference identities. Store directory is profile-routed by `AppDelegate.swift:701`. |

A future language setting needs an explicitly approved persistence/owner decision. Do not insert language or translated strings into these existing payloads incidentally. Do not translate suite names, CodingKeys, folder IDs, comparison keys, menu action strings, accessibility identifiers or shortcut codes.

Activation applies runtime changes before persistence, with partial-login acceptance and attempted restoration on future-schema refusal (`ActivationApplyTransaction.swift:83–123`). Appearance persists before invoking its presentation callback (`AppearancePreferences.swift:137–152`). Sources validates/adopts a transaction ticket, persists, then replaces roots/refreshes (`AppSourcesCoordinator.swift:54–86`). A text refresh must not call these apply paths.

### Profile isolation

`UITestProfile.swift:7–38, 55–97` defines candidate-local layout/apps/wallpaper locations and four independently named preference suites. Its namespace derives from candidate directory plus profile ID; it rejects unsuitable candidate paths. AppDelegate resolves/validates the profile before ordinary assembly/store access (`152–169, 531–536, 1804`), routes all four stores (`1708, 1812, 1858, 1981`), and supplies synthetic catalog boundaries (`1807–1809, 1837–1839`).

`LauncherRuntimeServices.swift:7–24` chooses isolated activation dependencies and fake login service for a profile. These contracts are suitable starting points for later isolated language tests; this survey did not create a profile, inspect any user's defaults, register services, or prove profile/runtime parity. Windowed tests cannot by themselves establish behavior of the normal screen-covering resident launcher.

### Shared owners and lifecycle

- Settings controller has a static weak shared instance (`ActivationSettingsWindowController.swift:111, 147–181`), and the coordinator strongly retains its controller (`ActivationSettingsCoordinator.swift:33, 69–92`). Reopening calls `reload(draft:)`; additional sections reload through the composition root (`AppDelegate.swift:1790–1793, 1849–1851, 1873, 2087–2088`). There is no language notification/owner today.
- Settings close hides rather than destroys the window; hiding cancels source operations and shortcut recording (`ActivationSettingsWindowController.swift:234–247, 264–267`). An implementation that “refreshes language” by reopening/reloading can lose unsaved drafts and cancel work.
- AppDelegate owns the shared drag coordinator assignment/clear (`811, 2739`), menu composition, folder editor and accepted appearance queue. A future common language owner must fan out through the existing owners rather than introduce competing per-view global state.
- Layout save notices and quit-save alerts must retain their save/timeout/read-only meaning. Quit is generation-gated and replies once through `WorkspaceQuitCoordinator.swift:16–55`; AppDelegate warning presentation/default cancel button is at `2535–2599`.
- Resident window close delegates a hide request and does not terminate (`AppDelegate.swift:2604–2613`). Final teardown is guarded, clears queued appearance, tears down sources, hides settings and clears shared drag state (`2681–2741`). Delayed text work must never revive torn-down views or trigger a restart.

## Dynamic-view risks to address in a future specification

| Risk | Current evidence | Required future acceptance |
| --- | --- | --- |
| Active folder title draft / IME composition | `FolderTitleEditor.swift:70–82` commits on end editing using the field editor; AppDelegate `1507–1585` owns rename token, layout snapshot, revision and store epoch. | Refresh placeholder/help in place without resigning first responder, committing/cancelling, modifying text/selection/marked text, changing fallback, or invalidating the existing rename contract. Test commit and Escape after refresh, including stale layout rejection. |
| Accepted but queued settings | `AppDelegate.swift:1913–1975` keeps latest pending appearance until no gesture/drag/rename/folder motion/pinned presentation/quit barrier; `AppearanceSettingsView.swift:193–200` renders distinct applied/queued/unavailable states. | Preserve committed, pending and displayed values independently. Language refresh must not flush/cancel a pending appearance draft or claim it has already appeared. Handle repeated changes and return-to-current-style cancellation. |
| Unsaved settings / shared window owner | Shared creation/reload above; management reload writes alias field at `105`; sources reload cancels operations at `84`; activation reload stops recording at `243`. | Define a presentation-only refresh path in a future design. Do not reuse data reload for translations. Keep selected tab, popup identity, unsaved alias/source/appearance/activation draft and recording state. |
| Same state, new language | `AppGridStatusView.swift:45–47` ignores equal states; `AppSourcesCoordinator.swift:95–97` emits only changed watch states; captions installed once elsewhere. | An unchanged semantic state must still be able to rerender its text. Do not force a catalog scan or fabricate state/generation changes to obtain refresh. |
| Materialized and open menus | Main menu installed once; status refresh only updates show/hide; context/folder menus carry immutable binding/revision/layout expectations (`AppContextMenuController.swift:19–26, 62–68`; `AppFolderAssignmentMenuController.swift:164–193`). | Decide next-opening versus immediate-open-menu updates. Refresh all app-owned titles while preserving target/action/tag/key equivalent/represented object/enabled state and stale-action rejection. Never use translated titles as identity. |
| Pooled/current/new views | PageHost, grid pages/cells, folder inner pages, page-dot windows and cached drag labels materialize text at different times. | Cover mounted, hidden, pooled and newly allocated views. Maintain name/accessibility identity, cell reuse tokens, selected page and visual-only exit semantics. Language change alone must not reload icons or rewrite layout. |
| Async callbacks and transient messages | Source panel/admission/apply generation guards (`AppSourcesSettingsView.swift:102–105, 146–183`); source coordinator ticket/teardown guards (`54–86, 143–147`); success banner timer (`ActivationSettingsWindowController.swift:521–536`). | Render completion text in the chosen current language without resurrecting cancelled operations. Preserve result semantics and success-banner expiry; represent message meaning rather than only caching an old-language string. |
| Accessibility and layout expansion | Independent static AX labels in settings; rename and page/count templates; fixed 500×560 settings window (`ActivationSettingsWindowController.swift:363`), 20-point status text height (`AppGridStatusView.swift:68`), bounded slider/popup layouts. | Validate AX label/value/help/tooltip together, expansion, wrapping, clipping, focus traversal and VoiceOver. Keep hidden/visual-only controls out of AX. English page text is duplicated across three modules and must follow a common owner policy. |

These are source-derived risks and proposed acceptance requirements, not observed runtime failures from this session.

## Recommended key groups and ownership

The following are naming/coverage recommendations for a later approved specification, not an implemented API or committed key catalog.

| Suggested group | Coverage |
| --- | --- |
| `common.action.*` / `common.status.*` | Close, cancel, save, restore defaults, acknowledgement; share only where semantics truly match (cancel quit differs from ordinary cancel). |
| `launcher.menu.*` / `launcher.chrome.*` | Main/status menus, show/hide, settings launcher button, brand decisions. |
| `settings.section.*` / `activation.*` | Four tab titles; activation captions, corner choices, readiness, login statuses, validation, partial acceptance and rollback alerts. |
| `shortcut.*` | Preset/custom/recording text, named keys and unknown key-code template, independent of code/modifier serialization. |
| `appearance.*` | Controls, ranges/units/help, corrupt/future/invalid/save outcomes, defaults draft, queued/applied/unavailable presentation. |
| `management.*` / `app.contextMenu.*` | Hide/alias UI and sheets, prompts, hidden-name wrappers, hidden-reference count, canonical-name wrapper, management errors and actions. |
| `sources.*` | Source controls/open-panel prompt, restrictions/help, draft/admission/apply/watch states; exclude real paths. |
| `search.*` / `catalog.status.*` | Search placeholder/AX, six neutral catalog states; do not embed query/app/path data in status resources. |
| `paging.*` | Page/count templates, inner counter, navigation group, previous/next page windows, selected/no-pages values. Define shared semantic formatting across PagingUI/AppGridUI/App. |
| `folder.*` | Rename affordance/editor/AX, count/plural help, folder-assignment actions, destination-name display wrapper. Default name is creation-time data policy, not a continuously translated title. |
| `workspace.persistence.*` | Save notice, quit warning, cancel-quit and exit-anyway actions. |
| Separate non-product classifications | Brand strings, external names, persisted user content, symbols, opt-in lab text and fixtures/diagnostics; do not bulk-extract into product keys. |

Prefer stable semantic identifiers with translator context and typed/count parameters. Use whole templates for page/count, folder rename, hidden-name and partial-result messages instead of concatenated translated fragments. Counts need locale plural rules; punctuation, ellipses, parameter order and number/unit formatting need deliberate coverage. Preserve stable programmatic identifiers and privacy boundaries.

Because the executable depends on AppGridUI and PagingUI rather than the reverse, a common presentation-language owner/resource boundary must respect dependency direction. Possible shared-resource or injected-formatter designs require a future approved specification. Also decide system-language-only versus app override, immediate versus restart application, supported locales, fallback and missing-key behavior, default-folder creation policy, keyboard-layout scope, native-panel language expectations, profile namespace and unknown future schema. None of these choices is implemented or silently assumed here.

## Exhaustive follow-up scanning and testing plan

This is proposed future work; it was not executed in this survey.

1. **Freeze an explicit release scope.** Snapshot hashes of allowed product sources, manifest and packaging inputs. Enumerate normal, neutral/fallback, lab and isolated-test modes separately. Revalidate each source-to-consumer path. Keep forbidden evidence/reference material excluded unless the user changes scope. Review metadata-only discovery before widening content access.
2. **Scan every text sink and producer.** Start with Appendix A, then inspect all ordinary/raw/multiline/interpolated string expressions, static/computed display properties and callback-provided strings. Search NSTextField/NSButton/NSTabViewItem/NSMenu/NSAlert/NSOpenPanel, window title, placeholder/prompt, toolTip, image accessibilityDescription, AX label/value/help/title, attributed strings and custom drawing. Trace variables/tuple arrays/functions to sinks. A CJK search alone misses the English sites; an API search alone misses enums and service messages.
3. **Classify every result.** Record file/line, source expression, consumer, ordinary/conditional/test-only reachability, owner/update point, visible/AX channel, parameters/plurality, persistence status and disposition (key, user data, external content, brand, symbol, protocol, diagnostic, fixture). Review duplicates and exclusions explicitly. Use syntax-aware extraction later if available; do not treat regex line counts as exhaustive key extraction.
4. **Verify resources and packaging.** Audit resource names, locale sets, fallback behavior and complete typed parameters. After separately authorized implementation/build, inspect SwiftPM resource bundles and an independently staged packaged candidate's metadata/file list. Test both direct executable and .app resource lookup. Ensure packaging includes resource bundles, not just the executable/icon. No rebuild of the shared app is part of this survey.
5. **Resolver/resource tests.** Under approved test execution, exercise every key in every supported locale plus unsupported/system fallback, missing keys, parameter reorder and count cases 0/1/2/large. Include Unicode/emoji/combining/RTL content, long text and numbers/units. Verify no language change rewrites alias/folder/source data, identities, generations, diagnostics or existing schema payloads.
6. **Owner/state tests with fakes.** Cover the shared settings window before first creation, while open/hidden, on reopen and across fresh owner/profile instances. Preserve all unsaved drafts, selected tab/app/root/corner/preset, current recording and service state. Cover future/corrupt preferences, rejected writes, partial login acceptance, queued appearance and teardown. No real login/global shortcut/gesture service should be registered by these tests.
7. **Interaction and asynchronous tests.** Cover active folder rename/IME/selection with commit, Escape, stale revision and unchanged layout; queued appearance across gesture, pointer-held drag, title edit, folder entrance/exit, direct navigation/pinning, resize/screen change/hide/quit; source-panel cancel, delayed admission/apply supersession and watcher state unchanged across language changes. Assert no text refresh invokes a save/apply/rescan/launch/teardown operation.
8. **Menu/render/accessibility tests.** Exercise main/status/context/folder menus before and after language changes and while tracking; duplicate literal folder titles including names resembling ordinal suffixes; hidden/read-only actions and stale bindings. Cover pooled/rebound/new cells and hosts, multiple inner pages, >windowSize page dots, no-pages/search/no-results/partial-failure states and same-state rerender. Assert all relevant AX properties and tooltips, not just visible captions.
9. **Source assertions and existing tests.** Review current hardcoded-copy assertions deliberately: `ActivationSettingsWindowControllerTests.swift:254–258`, `PageDotsViewTests.swift:296–307`, `FolderTitleEditingHostTests.swift:62–65`, `AppSourcesSettingsTests.swift:21, 44–45, 75`, `IconTypographyOwnerTests.swift:108`. Retain fixture-name and identity invariants; replace incidental substring assertions with semantic outcomes plus deterministic locale-specific expectations. Relevant existing suites also cover status menus, folder rename, sources profile assembly, layout codecs, search and renderer reuse. Their existence is not a current passing-test result.
10. **Separately authorized native acceptance.** Use a candidate-local isolated profile first for pixels, expansion/clipping, keyboard/VoiceOver, title editor/IME, settings/sheets and native open panel; then separately validate ordinary resident/screen-covering hide/reopen behavior and real catalog names with a disruption boundary. Record exact candidate/profile/locale/mode and results. Static inventory, fake services and windowed tests cannot establish runtime parity.

## Delivery limitations

The report is an auditable static inventory and future coverage plan. It does not claim successful builds/tests, deployed localization resources, translations, native readability, service readiness, accessibility runtime acceptance, or parity with any excluded application/reference. Generated artifacts and installed bundles were not inspected. Resource absence is limited to inspected source/resource/configuration paths. Regex searches and selected call-path inspection may miss indirect/custom future surfaces; Appendix A is a reproducible starting ledger, not proof of exhaustive runtime coverage.

No feature specification was approved, no language feature was implemented, and no preference/domain/lifecycle behavior was changed.

## Appendix A — candidate source-line ledger

These 207 candidate lines are the counting basis. Consumer forwarding sites, empty resets and data-only expressions are not additionally counted. Each row links to the first counted line and lists all counted line numbers; review the surrounding function for parameters and multiple literals.

| File | Candidate lines | Count |
| --- | --- | --- |
| [Sources/PagingPrototypeApp/ActivationSettingsWindowController.swift](/Users/mac/Projects/Launch_Copy/PagingPrototype/Sources/PagingPrototypeApp/ActivationSettingsWindowController.swift:18) | 18, 19, 20, 21, 22, 23, 24, 25, 26, 27, 28, 29, 30, 31, 32, 33, 34, 35, 36, 37, 38, 39, 40, 41, 42, 43, 44, 45, 47, 48, 49, 50, 68, 69, 70, 71, 72, 78, 86, 88, 90, 294, 387, 394, 398, 412, 415, 424, 428, 440, 442, 451, 453, 466, 472, 477, 485, 495, 498, 503, 507 | 61 |
| [Sources/PagingPrototypeApp/ActivationSettingsCoordinator.swift](/Users/mac/Projects/Launch_Copy/PagingPrototype/Sources/PagingPrototypeApp/ActivationSettingsCoordinator.swift:81) | 81, 162, 167, 186, 197, 198, 199, 200, 201, 202, 203 | 11 |
| [Sources/PagingPrototypeApp/AppDelegate.swift](/Users/mac/Projects/Launch_Copy/PagingPrototype/Sources/PagingPrototypeApp/AppDelegate.swift:982) | 982, 986, 1678, 1683, 1685, 2213, 2214, 2215, 2223, 2224, 2225, 2226, 2244, 2246, 2247, 2248, 2251, 2271, 2275, 2277, 2594, 2595, 2596, 2598 | 24 |
| [Sources/PagingPrototypeApp/AppContextMenuController.swift](/Users/mac/Projects/Launch_Copy/PagingPrototype/Sources/PagingPrototypeApp/AppContextMenuController.swift:44) | 44, 45, 54 | 3 |
| [Sources/PagingPrototypeApp/AppFolderAssignmentMenuController.swift](/Users/mac/Projects/Launch_Copy/PagingPrototype/Sources/PagingPrototypeApp/AppFolderAssignmentMenuController.swift:126) | 126, 137 | 2 |
| [Sources/PagingPrototypeApp/AppManagementSettingsView.swift](/Users/mac/Projects/Launch_Copy/PagingPrototype/Sources/PagingPrototypeApp/AppManagementSettingsView.swift:14) | 14, 16, 17, 18, 27, 32, 33, 45, 82, 86, 94, 97, 98, 130, 131, 132, 133 | 17 |
| [Sources/PagingPrototypeApp/AppSourcesSettingsView.swift](/Users/mac/Projects/Launch_Copy/PagingPrototype/Sources/PagingPrototypeApp/AppSourcesSettingsView.swift:11) | 11, 12, 13, 14, 15, 39, 40, 41, 42, 44, 89, 90, 95, 96, 97, 98, 109, 135, 144, 164, 165, 166, 179, 180, 181, 182, 183 | 27 |
| [Sources/PagingPrototypeApp/AppearanceSettingsView.swift](/Users/mac/Projects/Launch_Copy/PagingPrototype/Sources/PagingPrototypeApp/AppearanceSettingsView.swift:11) | 11, 19, 20, 27, 32, 34, 35, 48, 53, 59, 60, 124, 126, 145, 163, 168, 169, 170, 178, 196, 198, 200 | 22 |
| [Sources/PagingPrototypeApp/FolderTitleEditor.swift](/Users/mac/Projects/Launch_Copy/PagingPrototype/Sources/PagingPrototypeApp/FolderTitleEditor.swift:38) | 38, 42 | 2 |
| [Sources/PagingPrototypeApp/PageDotsView.swift](/Users/mac/Projects/Launch_Copy/PagingPrototype/Sources/PagingPrototypeApp/PageDotsView.swift:36) | 36, 53, 56, 168, 184, 185, 188 | 7 |
| [Sources/PagingPrototypeApp/ShortcutRecording.swift](/Users/mac/Projects/Launch_Copy/PagingPrototype/Sources/PagingPrototypeApp/ShortcutRecording.swift:57) | 57, 69, 70, 72, 73, 74, 100, 102, 120, 122 | 10 |
| [Sources/PagingPrototypeApp/AppSearchFieldView.swift](/Users/mac/Projects/Launch_Copy/PagingPrototype/Sources/PagingPrototypeApp/AppSearchFieldView.swift:19) | 19, 21 | 2 |
| [Sources/PagingPrototypeApp/LaunchAtLoginService.swift](/Users/mac/Projects/Launch_Copy/PagingPrototype/Sources/PagingPrototypeApp/LaunchAtLoginService.swift:162) | 162, 163 | 2 |
| [Sources/AppGridUI/AppGridUIState.swift](/Users/mac/Projects/Launch_Copy/PagingPrototype/Sources/AppGridUI/AppGridUIState.swift:29) | 29, 30, 31, 32, 33, 34 | 6 |
| [Sources/AppGridUI/AppGridCellView.swift](/Users/mac/Projects/Launch_Copy/PagingPrototype/Sources/AppGridUI/AppGridCellView.swift:155) | 155, 160 | 2 |
| [Sources/AppGridUI/AppGridPageView.swift](/Users/mac/Projects/Launch_Copy/PagingPrototype/Sources/AppGridUI/AppGridPageView.swift:168) | 168, 170 | 2 |
| [Sources/AppGridUI/FolderOverlayView.swift](/Users/mac/Projects/Launch_Copy/PagingPrototype/Sources/AppGridUI/FolderOverlayView.swift:298) | 298, 299, 533, 534, 805 | 5 |
| [Sources/PagingUI/PageHostView.swift](/Users/mac/Projects/Launch_Copy/PagingPrototype/Sources/PagingUI/PageHostView.swift:69) | 69 | 1 |
| [Sources/PagingUI/PagingSurface.swift](/Users/mac/Projects/Launch_Copy/PagingPrototype/Sources/PagingUI/PagingSurface.swift:920) | 920 | 1 |

**Total: 207 candidate lines / 19 producer files.**

## Dated attribution correction by parent Main (2026-10-14)

The source inventory above was produced by the dispatched read-only Zeno sidecar
(agent01a13603-951b-7c70-bc8e-084734237817), not personally executed by the parent
Main. The sidecar's lack of its own delegation tool does not mean this parent
session lacks agents. Parent Main independently produced
LANGUAGE_OWNER_RESOURCE_SURVEY.md; Heisenberg produced the separate advisory
review. This correction supersedes the report's earlier ambiguous Main/no-subagent
attribution only; no static findings or source/test fingerprints are changed.
All remain static discovery/advisory evidence, not implemented runtime parity.
