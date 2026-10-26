# Separate App Library — Proposed Next Slice

Status: PROPOSED_CONTRACT, 2026-10-13. Product-level optional Library scope is
approved; these metadata/navigation/category contracts require confirmation before
implementation. Current icon/type slice remains in validation, not Library PASS.
Source discovery: Workflow/results/APP_LIBRARY_INTEGRATION_SURVEY.md (130 lines).

## Problem, users and outcome

Bring the remaining category browsing/details/manual-classification capability to
Launchcopy without replacing its performant pager or canonical app identities.
Offer launcher users an optional separate Library in the SAME resident window.
Do not redefine full parity as this optional pane; reference visual/taxonomy
fidelity remains an exact observable/user-approval gate, not inferred from an audit.

## Proposed product decisions

- Default off, with a Settings enable checkbox and explicit Library/Back control.
  No synthetic negative page, swipe entry, global shortcut or second launcher.
- Fixed flat declared-category taxonomy plus Other. All is a filter, not a stored
  category. Fold documented game subcategories into Games; unknown/missing values
  go to Other. Exact labels/order and whether the user prefers broader groups must
  be confirmed; do not infer exact reference taxonomy from source presence.
- Automatic classification from the bundle's declared category only. A single
  explicit manual override wins; Automatic removes all equivalent override keys.
  No app-name heuristics, downloaded enrichment, inferred sensitive categories or
  machine-learning model. Category is independent of folder membership/layout.
- Alias is primary display name, original name remains searchable and in Details;
  hidden apps excluded consistently. Stable locale-aware alias/name sort with
  canonical URL tie, no usage ranking. Category counts reflect visible matches.
- Independent Library query (same original/alias policy, no bundle-ID matching
  mode without its separate contract), explicit empty/no-result/load/error states.
  View shows category list, app results and an on-demand details side pane.
- Details: original name, alias, effective/automatic/manual category, bundle ID,
  location, optional declared version/build. Unknown shown clearly; no invented
  developer, install date, size or last-use facts. Open/reveal/category controls;
  safe existing alias/hide/folder assignment actions only via shared validation.
- Query Return/Down selects a result, not launches; selected result Return opens.
  Escape: editor/sheet cancel, details close, query clear, Back; only later grid
  Escape uses existing hide behavior. Tab follows native accessibility controls.
- Enter saves grid query/page/selected identity, closes any open folder immediately,
  and sets independent Library search focus. Reject transition during active title,
  drag, modal save/quit or restore; do not cancel user edits to enter faster.
  Back restores grid query/anchor against latest committed content; absent/hidden
  anchors use documented nearest/first-valid fallback. No automatic folder reopen.
- Library blank space is interactive, not launcher-hide blank click. Scroll stays
  in Library, never drives hidden pager. Successful launch uses existing hide path;
  Finder reveal retains Library state. Normal hide discards Library query/details
  and returns the next launcher opening to grid. Confirm this reopen contract.

## Architecture and metadata

Retain AppCatalogCore/MacAppCatalog, existing scanner/repository/latest-wins commits,
AppIconPipeline and sole AppDelegate/window ownership. Current canonical records
lack category/version/build; add nullable value AppBundleMetadata with compatible
initializer defaults. Forward it through aliases/management transformations.

Extract optional metadata from the Info.plist dictionary ALREADY decoded once by
CatalogScanner on its utility queue: no second scan or frame/main-thread plist IO.
Apple documents the category declaration as a string; it is not proof of verified
function, installed origin or licensing. Use only recognized values and Other.
[Apple LSApplicationCategoryType](https://developer.apple.com/documentation/bundleresources/information-property-list/lsapplicationcategorytype)
Malformed optional metadata degrades to unknown, not scan failure or invented data.
Freeze supported mapping IDs/order/labels in the approved final spec, including
explicitly enumerated Games subcategory handling instead of arbitrary-prefix trust.

Pure LibrarySnapshot projection consumes the SHARED committed catalog, management
preferences, category overrides and query. Off-main deterministic classification/
sorting for large catalogs; bounded revisions/tokens, cancellation and latest-wins.
Only publish if all current catalog/management/override/query generations match.
No new CatalogRevision minted for category/query changes. Open creates lazy UI;
closed Library starts no classifier, icon requests or metadata enrichment task.

One owner mode/return-context transaction suspends grid input/search auto-refocus,
hides page dots, selects Library responder and restores current grid correctly.
Compose existing events; never replace one callback silently or create a second
catalog refresh controller. Source changes invalidate pending actions/projections;
persistent absence retains dormant category overrides, never prunes layout refs.

## Actions, identities and data

Generalize shared action validation to immutable AppID + expected revision + URL
(and protected lifecycle state), re-resolved against current served catalog at
execution. Do not fabricate a current cell/token from an old Library selection.
Reuse existing public NSWorkspace launch/Finder paths and same neutral failures.
Category save never invokes LayoutMutation, reorders apps or changes folder data.

New standalone versioned size-bounded Library preferences, injected store and
candidate-local profile .library namespace. Default disabled, no automatic writes
on load, explicit corrupt recovery, future payload read-only/byte-protected.
Manual category keyed by PersistentAppReference, bundle-first/canonical-path
fallback with existing canonical resolver; reset removes equivalent preferred/path
keys and dormant overrides retained. Canonical multi-instance ambiguity remains
separately specified; preserve current single-instance root-priority policy.

UserDefaults acknowledgement is not proof of disk flush/restart durability. Choose
and document accepted-write protection/shared Quit integration before category
implementation; do not advertise physical durability from actor/store reload.
No query history, launch timestamps/counters, global activation observation,
recent/suggested sections, network or cloud upload. Usage-based parity stays
identified deferred work requiring explicit retention/opt-out/reset consent.

## Performance and acceptance budget

Freeze current candidate/source workload before implementation. Structural limits:
closed Library zero extra UI/icons/classification, no frame/offset IO or sorting;
reuse one plist decode per scanned app; lazy visible results/icons with bounded
reuse/in-flight cache; one accepted projection update per discrete generation;
category-only changes zero catalog scans/layout persistence/pager parameter edits.
Define measured open/projection memory/latency targets after matched real-catalog
baseline capture, not arbitrary synthetic PASS thresholds. Require physical AB
and retain unresolved>25ms/unsupported120Hz distinctions.

Tests: optional metadata defaults/corruption/alias forwarding; category mapping/
manual precedence/reset/dormant refs/hide/search; latest projection/action races;
future/corrupt/write failure/profile/accepted Quit; mode/responder/query/anchor/Escape/
blank-click/scroll/dots/back/hide with real mounted controls. Nonzero full/focused,
independent source review, Debug/Release, current sources/executable hashes, exact
candidate GUI/VoiceOver/real restart and matched physical gate. No install/sign/
notarize/publish/commit or app/process changes without their scoped authority.

## Non-goals and unresolved decisions

No Library drag, usage tracking, deletion, folder creation, private app database,
imported reference code/assets or row/column/physics changes in this slice. These
remain explicit broader parity backlog, not waived whole-goal requirements.
Confirm enablement/entry, taxonomy, actions/details, independent-query Back/Escape/
hide behavior, dormant reset and accepted-write lifecycle before implementation.
Proposed ownership: Main owner/navigation/validated actions; disjoint metadata/
category foundation worker and lazy Library view worker after contracts/interfaces
approved. Main-only Swift, at most3 including Main. Keep visible stage summary and
full parity ledger; no Library code exists at this proposal checkpoint.

## Proposed fixed taxonomy for confirmation

Independently localized flat top-level categories from the documented declared
identifiers, in this fixed order. They are metadata values, not verified app
behavior and not a claim of exact reference-product category naming.

| Stored suffix after public.app-category. | UI label |
| --- | --- |
| business | 商业 |
| developer-tools | 开发者工具 |
| education | 教育 |
| entertainment | 娱乐 |
| finance | 财务 |
| games | 游戏 |
| graphics-design | 图形与设计 |
| healthcare-fitness | 健康与健身 |
| lifestyle | 生活 |
| medical | 医疗 |
| music | 音乐 |
| news | 新闻 |
| photography | 摄影 |
| productivity | 效率 |
| reference | 参考 |
| social-networking | 社交 |
| sports | 体育 |
| travel | 旅行 |
| utilities | 工具 |
| video | 视频 |
| weather | 天气 |
| independent other ID | 其他 |

All/全部 is filter-only. Explicit documented game suffixes action-games,
adventure-games, arcade-games, board-games, card-games, casino-games, dice-games,
educational-games, family-games, kids-games, music-games, puzzle-games, racing-games,
role-playing-games, simulation-games, sports-games, strategy-games, trivia-games
and word-games map to Games. Do not map an arbitrary unrecognized *-games string.
[Apple category values](https://developer.apple.com/documentation/bundleresources/information-property-list/lsapplicationcategorytype)

This exact flat taxonomy, default-off entry, read-only detail fields, safe actions,
independent queries/Back/Escape/hide behavior, dormant overrides and no-usage policy
remain PROPOSED, not implementation approval. Broader groups or a supplied observable
reference taxonomy may supersede this table by explicit user decision.

## Recommended storage/lifecycle resolution before implementation

Use a standalone local version1JSON preferences file with maximum1MiB payload,
injected serial actor writer and profile-local file path (never workspace layout
or default production fallback from invalid profile). Atomic replacement/flush
happen off-main. A save request is tracked as accepted/pending/failure; publish
only the latest successful generation, preserving previous UI on failure and
refusing future payload overwrite. No autonomous repair/write on load. Category
change/enable/reset share this one writer and no dormant-override pruning.

Expose accepted write drain to the existing approved Quit policy: wait bounded
in-flight save, default Cancel on timeout/failure, explicit Quit Anyway only by
user decision. Reopening/restart protection is an actual process/file gate, not
assumed from store acknowledgement. This resolves the earlier choice as a proposal,
not a promise of implemented durability or implicit authorization. Keep startup
lazy/no store-directory creation just to inspect a disabled feature.
