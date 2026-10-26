# Approved parity gap audit — 2026-10-15

## Decision

**Highest-priority confirmed failure: the current candidate's wallpaper remains loading/black during the recorded source-open observations. It is NOT_FIXED.** Main already owns the bounded source-access/configuration investigation; this audit neither duplicates it nor proposes a speculative renderer or permission patch.

**One concrete next acceptance task outside that ownership: prove the approved Library save-failure → ordinary Quit → default Cancel → successful retry → fresh-process category restoration transaction using the existing real file writer.** This is an unproven data/lifecycle acceptance requirement, not a newly discovered production bug or a request for another broad test suite. A deterministic, candidate-local advisory-lock contention route exists in current production source; no new product feature is needed to exercise it.

The bounded mapping below did not establish another absent, specifically approved feature that justifies immediate implementation. Library, identifier matching, folder rename, direct page selection, managed sources, and the approved appearance/language controls have implementation routes. Their remaining evidence boundaries do not authorize inventing additional features or declaring full parity.

## Authority, inspection and unchanged inputs

Read the assigned stage summary, `Docs/LAUNCHBETTER_PARITY_SPEC.md`, the current parity ledger and the relevant contracts:

- `LAUNCHBETTER_APPEARANCE_SLICE.md`, `ICON_AND_TYPOGRAPHY_SPEC.md`, `PAGE_DOT_IMPLEMENTATION_SPEC.md`.
- `LAUNCHBETTER_APP_MANAGEMENT_SLICE.md`, `LAUNCHBETTER_FOLDER_ASSIGNMENT_SLICE.md`, `LAUNCHBETTER_FOLDER_RENAME_REPAIR_PLAN.md` including its approved Quit policy/addendum, and `APP_SOURCES_AND_WATCHING_SPEC.md`.
- `INTERFACE_LANGUAGE_SPEC.md`, `APP_LIBRARY_SPEC.md` and its fully incorporated `APP_LIBRARY_SLICE_PROPOSAL.md`, `BUNDLE_IDENTIFIER_SEARCH_SPEC.md` including its approval receipt, and `ISOLATED_NATIVE_TEST_ENTRY_SPEC.md`.
- The permitted authored digest `Docs/PHASE1I_VISUAL_REFERENCE_DIGEST.md`; no underlying reference source, raw evidence or assets were read.

Current architecture remains a Swift Package/AppKit application: PagingCore/PagingUI own paging; AppCatalogCore/MacAppCatalog own scanned identities; AppIconPipeline owns asynchronous icons; AppGridUI owns layout/search/folders/Library domain; PagingPrototypeApp assembles native controls, settings, persistence and lifecycle. The audit follows those seams rather than treating settings labels or test counts as feature implementations.

Read-only integrity inspection established:

| Identity | Audit result |
| --- | --- |
| Current freeze | `.build/verification/20261015/wallpaper-loading/source-inputs-final.json`, 455 entries; manifest SHA-256 `2ab1e65f615b365fa5d9869cfa2ee73c47d21f2cab3d5a9fa798a85d3eb34d7b` |
| Current files checked | All 453 Package/Sources/Tests/Scripts entries match their frozen hashes; zero mismatches. The two `Resources/AppIcon*` image assets were not opened or hashed. This audit does not claim a fresh 455-file content verification. |
| Comparison to the title-edit-focus freeze | Prior manifest has 454 entries. No removed entries or changed shared hashes; the sole addition is `Tests/PagingUITests/WallpaperBackdropPipelineTests.swift`. This comparison includes the recorded asset hashes without opening assets. |
| Actual latest candidate | `.build/candidates/title-edit-focus-rc-20261015-r1/LaunchcopyUITest.app` |
| Executable independently hashed | `Contents/MacOS/LaunchcopyUITest`: `889d661392cc18f0e59958b1b51d499dfac13d82a116a7fa53e1b31852c12bed` |

Reuse Main's existing receipts: title-edit-focus **2675 full / 0**, Debug/Release/package and strict **288-key, three-language** checks; wallpaper-controls **16 focused / 0 and 2677 full / 0**, including two added pipeline controls. These are prior executions, not audit executions. All shared frozen production/package inputs remain unchanged from the 2675 checkpoint. The two controls and this report do not require another build, candidate or blanket gate rerun. Bounded source reviews retain their original scope and authorship.

## Approved scope mapped to current implementation and evidence

Paths below are relative to the repository root. Source anchors identify inspected routes, not whole-module certification. Native observations are attributed to their recorded candidate; they are not silently relabeled as fresh 889d... observations.

| Approved requirement | Current source route | Existing evidence and actual remaining boundary |
| --- | --- | --- |
| Wallpaper/materials; nonblocking presentation; blur 0–60 with sharp zero | `WallpaperBackdropView.swift:101` dispatches rendering off-main; `:155` refreshes policy/source/generation and `:201` gates completion. `WallpaperBackdropProvider.swift:60` coordinates caches/in-flight work, `:87` selects sharp versus blurred decode, `:130` opens ImageIO source. | Synthetic real-provider controls succeed, while current 889d... native loading/black remains a real failed outcome. See the failure analysis below. Off-main dispatch does not prove real-source completion. |
| Notch-safe chrome, no decorative top page number; native page dots/direct navigation | `AppDelegate.swift:1885` lays out search before dependent chrome; `:3155` routes accepted dots through Surface; `PagingSurface.swift:304` and `PagingCore.swift:214` expose guarded direct selection. | Chrome-order regression repaired; later renderer handoff removed obsolete neutral AX labels. Ledger records native dot 2/2 → 1/2 on 34ea5275... after the earlier inactive-control observation. Do not resurrect those resolved observations as missing implementations. Physical/VoiceOver claims remain separate. |
| Label visibility, icon 32–64, caption 9–16, independent draft/Apply and safe deferred presentation | `AppearancePreferences.swift`, `AppearanceSettingsView.swift`, `GridItemAppearance.swift`; `AppDelegate.swift:2191–2250` separates pending/applied policy and retries at readiness. | Close/discard repaired; actual nondefault extremes/normal-process restart recorded in `APPEARANCE_NATIVE_CHECKPOINT.md`. Its hidden-label AX defect was subsequently repaired and natively checked in `HIDDEN_LABEL_ACCESSIBILITY_CHECKPOINT.md`. Actual icon quality/tiny-cell readability and physical motion remain distinct, not a missing capacity feature. |
| Hide/restore, aliases and safe launch/Finder actions; optional shared identifier search | `AppManagementPreferences.swift:70` performs shared matching, `:86/:100` retain metadata semantics; `AppManagementStore.swift` has schema2/legacy admission. `AppDelegate.swift:2634` and later policy paths integrate presentation; `:2906` installs validated menus. | `IDENTIFIER_SEARCH_IMPLEMENTATION_CHECKPOINT.md` records OFF/ON/OFF same-query, Library matching, alias/hide exclusion and normal-process persistence on f3709254.... Prior safe executable-fixture success is narrower than arbitrary real-user-app launch/Finder acceptance. Identifier mode is approved/implemented, not an unanswered proposal. |
| Canonical folder assignment, mounted rename and saved organization | `AppDelegate.swift:1074` shared workspace commit, `:1806` guarded rename, `:2937` assignment menus; `FolderTitleEditor.swift` and current responder ownership in `AppSearchController.swift`. | Current 889d... first Escape cancels, first Return accepts without observed failure feedback, first typing remains native editor; nondefault title/five members restored across 90154 → 91419. The matching failures are resolved. Uninstrumented universal event replay, IME and physical behavior are not inferred. |
| User-managed local roots and automatic installation/removal refresh without layout deletion | `AppSourcesCoordinator.swift:53` validates/persists/replaces roots; `:104` gates asynchronous watch setup; `AppSourceWatcher.swift:154–158` uses a recursive public event stream and `:123` tears down generation ownership. | Ledger records native matching-app add/remove after host-range repair, and later final callback/source-failure repairs. Sustained native error/reappearance/performance evidence remains bounded; a missing-source record must not be equated with permission to prune layout. This concerns app discovery, not Main's wallpaper file-access inspection. |
| System/en/zh-Hans/ja language; preserved drafts/input; packaged resources | `LanguagePresentationController.swift:59/:71/:78` owns requested language and interaction leases; native settings retain Sources, Language and Library views in `ActivationSettingsWindowController.swift:180–182`. | Current 288-key three-language packaging receipt and prior native English/Chinese/settings/restart observations remain useful. Real composition, Japanese fitting and spoken VoiceOver remain unproved; they do not establish absent language wiring. |
| Optional same-window Library, categories/details/manual overrides, independent query/Back/hide and shared safe actions | `AppLibraryProjection.swift:37`, fixed `AppLibraryCategory.swift`; `AppDelegate.swift:2259–2392` mounts owner and restores grid; `AppLibraryOwnerController.swift:97/:151/:156/:214` owns entry, Back, hide and action validation. | Human approval on 2026-10-15 supersedes incorporated proposal markers. Identifier-stage native category/alias/hide/Back/restart, count repair and repeated status-free Back observations are existing evidence. Do not call Library absent because the old October-14 audit did. |
| Accepted workspace/Library saves block Quit on failure/timeout, with default Cancel | `AppLibraryStore.swift:47–88` real atomic writer; `AppLibraryPreferencesCoordinator.swift:15/:49/:85` tracks save protection, submissions and drain; `AppDelegate.swift:3382–3473` connects real termination, both drains and native alert. | Implemented and causally tested with injected outcomes; normal successful title/category process restarts are recorded. The actual failed-save/default-Cancel/retry transaction is still not demonstrated. This is the selected independent acceptance task below. |
| Isolated ordinary native test entry, resident hide distinct from process Quit | `NativeUITestEntry.swift`, `UITestProfile.swift`, `AppLibraryStoreLocation.swift:7`; `AppDelegate.swift:3477` retains resident-close policy. | Dedicated candidate entry and normal Quit/reopen have prior native receipts. Test profile fakes do not prove production global activation/login services or full-screen physical performance. |

No observed component evidence should be discarded solely because the ledger says “latest candidate” or a documentation/test file changed. Conversely, unchanged component source cannot manufacture a never-observed native failure dialog or physical result.

## Confirmed failed outcome: wallpaper source-open completion

Approved parity spec §§5–6 and the wallpaper digest require a usable, asynchronously rendered backdrop with failure fallback and screen/source invalidation. The source contains decode, cover/blur, memory cache, asynchronous disk cache and same-key coordination; this is not missing initial wallpaper implementation.

`WALLPAPER_LOADING_DIAGNOSIS.md` records exact current executable/PID 96238 loading with a black backdrop both before and after normal Settings activation without Apply. In grouped sampled windows, ImageIO source creation reaches `open/__open`; another worker is in provider coordination. The controller publishes ready/render-failed only after its loader returns. A generation check rejects stale deliveries but does not cancel the underlying operation; the provider's condition wait has no deadline. These source facts explain why passing an authored PNG through the pipeline does not settle this actual completion failure.

This establishes the **observed loading/black outcome and sampled stage**, not continuous syscall duration, exact dedupe-key correspondence, kernel cause, a Downloads denial or a requirement for Full Disk Access. Separately resolved metadata is not proof of identical app-source URL or effective open permission. Historical ready/visible runs remain true and do not fix the later failing run. No startup responsiveness or physical frame regression is inferred merely from a background wait.

Main's source-access/configuration investigation is the next causal step for this confirmed failure. Do not duplicate it, read the personal wallpaper through another helper, patch blur/compositing, loosen access, or install a UI timeout that leaves blocked workers accumulating. A cancellation/resource-bound redesign would need its own justified contract if the diagnostic result makes one necessary; no specific hard deadline is invented by this audit.

## Selected independent unmet acceptance: real Library write refusal protects Quit

### Contract and exact missing observation

The approved rename plan's failure policy and `APP_LIBRARY_SPEC.md` require bounded accepted-write draining with **Cancel Quit as default** after failure/timeout. Required observation: a real candidate-local Library category save fails, ordinary Quit reaches the native failure choice, default Return cancels termination, the draft/last successful state remains recoverable, then a successful retry survives ordinary Quit/fresh-process reopening.

This is higher value than another scalar setter or callback test because it covers the user-facing boundary where an unsuccessful save could otherwise become lost organization. It is **UNPROVEN_NATIVE_ACCEPTANCE**, not SOURCE_FAIL: no data loss or broken dialog is asserted from the inspected code.

### Why existing evidence does not already close it

- `AppLibraryLaunchAndQuitTests.swift:139` checks accepted-save waiting using a continuation-controlled `LibraryQuitTestStore`.
- `:160` substitutes a `.failed` receipt and invokes a captured decision closure with `false`; it never presents the native failure sheet or terminates a process.
- `:204` checks competing category-warning suppression using a reported-visible, unshown window and substituted presenters/choices. This is valuable real-owner wiring coverage, not a native-dialog observation.
- `WorkspaceQuitCoordinatorTests.swift:26` already covers unsuccessful outcomes, Cancel and retry. `AppLibraryPreferencesCoordinatorTests.swift:52/:65` cover preservation and timeout ownership. Another equivalent test is not the next missing requirement.
- The native protocols/checkpoints explicitly leave actual failure dialogs pending. Successful category/title restart observations demonstrate successful-save persistence only. The historical terminal-receipt assertion correction accepts two legitimate success receipt shapes; `LAYOUT_TERMINAL_RECEIPT_EXPECTATION_REVIEW.md` does not identify a production data-loss bug and should not be reopened as one.

### One bounded execution packet for Main, not executed here

Use the existing exact 889d... isolated candidate and a disposable synthetic category identity, within an agreed native-input session. Resolve its candidate-local Library file through the existing profile authority; never guess or use the production directory.

1. Establish a nondefault, successfully saved synthetic category as the comparison baseline. Have a controlled, cooperating holder acquire the **existing `.library.lock`** in that same isolated Library directory without changing payload bytes or permissions. `LocalAppLibraryFileIO.replaceAtomically` attempts `LOCK_EX | LOCK_NB` at `AppLibraryStore.swift:55`, so lock contention rejects before temporary-file creation/replacement. The real store maps that exception to `.failed` at `:184`.
2. Request a different category through the actual native control; observe failure instead of saved success. Close any ordinary category-error sheet normally, then request ordinary own-instance Quit. Verify the real Quit warning is shown and the default button is Cancel Quit. Press Return: the same candidate process must remain alive with the successful baseline and recoverable retry draft. A warning label or injected `reply(false)` alone does not count.
3. Release only the controlled lock holder, retry the same category through the normal control, and await acknowledged success. Normal Quit, verified process end, and reopening the **same** candidate/profile must restore the retried nondefault category. Distinguish the failed draft from both the baseline and retry receipt.

This exercises an existing supported cooperative-lock failure path with no product edits, permission changes, corrupt payloads, namespace swaps, deletion or user-app launch. It does not establish post-rename fsync failure, simultaneous warning races, power-loss durability or every timeout path. Do not add those to this packet. If a safe isolated lock holder/native session cannot be arranged under Main's authority, record that specific prerequisite; do not substitute more mock PASS results or change production code merely to keep working.

No holder, candidate launch, control interaction, file mutation or process action was performed by this audit. This proposal is for Main's scheduling within existing scope, not an expansion of this report-only assignment.

## Boundaries that are not implementation tickets

| Class | Disposition |
| --- | --- |
| Adjustable rows/columns/capacity and anchor/persistence semantics | `GRID_APPEARANCE_AND_CAPACITY_PROPOSAL.md` remains specifically unconfirmed. Icon/font scalar approval does not approve it. Missing controls are a decision dependency, not an implement-now finding. |
| Destructive deletion/uninstall, Finder scripting, expanded pinch/toggle/spread and three-finger drag | Explicitly gated backlog; broad parity intent is not approval. |
| Usage-based recent/suggested sections | Requires separate local-data/retention/opt-out/reset consent; approved Library expressly excludes it. |
| New-folder creation-time naming/other reference languages | Separate unsettled scope, not evidence that persisted user titles should be translated or more languages shipped now. |
| Physical motion, real IME, spoken VoiceOver | Require the actual hardware/input/accessibility session. AX trees, typeText, generic fixtures and mocked marked text cannot close them. This audit neither changes OS settings nor asks for another already-pending broad confirmation. |
| Matched 60Hz migration performance, >25ms causality, 120Hz/multi-display | Preserve historical 60Hz evidence and unresolved causality/hardware boundaries. No matched physical PASS is inferred from 2677 tests or cache controls; no arbitrary new benchmark threshold is introduced. |
| Optional quality work | A more discriminating old-status-callback fixture, combined locale+Library test, wallpaper distinct-image generation control and foreign-control focus coverage are useful only when a relevant change/claim needs them. Existing source reviews classify these as nonblocking; they are not new missing product features or reasons to rerun all gates. |

## Delivery and evidence boundary

Only `Workflow/results/APPROVED_PARITY_GAP_AUDIT.md` was created. No source, test, package, spec, stage summary, ledger, workflow state or evidence artifact was changed. All shell invocations were RTK-prefixed and bounded to named repository paths plus the explicitly supplied RTK instructions and a no-hit memory registry query. No relevant memory fact was used.

Zero tests/builds/Swift/native UI/process actions/other-agent dispatches. No LaunchBetter/Buho directories, raw reference evidence, personal wallpaper content or image assets were read. Main retains source-access investigation and all execution ownership. Full parity remains incomplete; the next independent packet is the single real Library failure/Cancel/retry transaction above, not a generic revalidation campaign.
