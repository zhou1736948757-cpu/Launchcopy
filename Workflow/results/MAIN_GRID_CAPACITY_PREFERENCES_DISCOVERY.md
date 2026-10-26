# Main-grid capacity: preferences and persistence discovery

Date: 2026-10-17
Status: SOURCE DISCOVERY ONLY; no implementation authorization and no PASS verdict.
Owner: bounded preferences/settings/localization/quit reader. Main owns the product specification; the other reader owns capacity geometry, focus and drag integration.

## Scope and evidence boundary

Read root `AGENTS.md` and `/Users/mac/.codex/RTK.md`; shell commands used the `rtk` prefix. The explicit user waiver of Chief workflow and the maximum of three agents including Main were respected; this reader created no agents. Read the current `Docs/MAIN_GRID_CAPACITY_SPEC.md` draft after Main supplied it. The proposed 3–8 rows and 3–8 columns remain subject to user confirmation; accepted folder experience does not authorize outer-capacity implementation.

Only this report was written. No production/test/specification edits, tests, builds, UI operations, process control, preference access, reference-product inspection, asset access, reset, deletion, installation, signing or commits were performed. Existing tests were read as contract evidence, not executed. The supplied 464-input freeze is Main's baseline; this reader did not independently hash or certify that entire baseline. Line references below describe inspected source, not a runtime acceptance result. No exhaustive project audit was attempted.

## Findings for Main before confirmation

1. Icon size and font size are independently authored integers but share one appearance draft, payload and Apply transaction. They do not currently encode grid capacity.
2. Prefer a **separate versioned main-grid capacity preference**, leaving appearance schema 2 and workspace organization intact. A schema-3 appearance payload would make the current schema-2 executable fall back to default appearance and disable all appearance edits, even though it preserves the newer bytes.
3. Do not describe existing appearance `.saved` as a disk receipt. It means validation/encoding succeeded and `UserDefaults.set` returned. There is no appearance flush API or quit-drain participant.
4. Draft specification line 29 needs an explicit architecture qualification: **the existing Quit drain does not already protect capacity or appearance writes**. It currently drains workspace and Library only. If Main retains the draft's explicit quit-protection promise, recommend a separate receipt-bearing capacity store/coordinator and explicit inclusion in that drain. A separate UserDefaults store is the smaller alternative only if Main explicitly selects the existing scalar write-acknowledgement strength and corrects the specification accordingly.
5. Keep capacity draft/reset/apply status independent from existing appearance controls. Separate stores plus one unconditional shared “Apply succeeded” message would introduce partial-save ambiguity. Separate Apply/Defaults scopes are the minimal coherent recommendation, pending Main's product decision.

## Actual appearance data and decoder contract

| Contract | Exact source evidence |
| --- | --- |
| Defaults: labels on, blur 18, icon 48, font 11. Icon/font are separate fields, no rows/columns. | `Sources/PagingPrototypeApp/AppearancePreferences.swift:AppearancePreferences.init:13–19`; `AppearancePreferences.itemAppearance:21–23` |
| Blur accepts 0–60; icon accepts 32–64 and font 9–16. | `Sources/PagingPrototypeApp/AppearancePreferences.swift:AppearancePreferences.isValid:24–26`; `Sources/AppGridUI/GridItemAppearance.swift:GridItemAppearance.isValid:13–15` |
| Dedicated suite/key: `com.launchcopy.appearance` / `appearance.payload`; one encoded envelope contains version and preferences. | `Sources/PagingPrototypeApp/AppearancePreferences.swift:UserDefaultsAppearancePreferencesStore:54–68` |
| Missing key loads defaults. Wrong storage type, undecodable header, unknown nonfuture version, invalid body or invalid ranges load `.corrupt`; loading performs no repair/write. | `Sources/PagingPrototypeApp/AppearancePreferences.swift:UserDefaultsAppearancePreferencesStore.load:77–95` |
| Version 1 decodes only labels/blur, constructs current preferences with 48/11 defaults. Version 2 requires the complete current Codable value. | Same `load:83–90`; `LegacyPayload:61–64`; `AppearancePreferences:5–19` |
| Decodable integer header greater than 2 is `.futureVersion` before decoding the body. Runtime fallback is defaults, while the raw newer payload remains untouched. | Same `load:79–81`; `AppearancePreferencesLoadResult.preferences:35–38` |
| Save reloads and refuses future data, validates, encodes schema 2, then calls `defaults.set`; other keys are not explicitly modified. | Same `save:97–105` |

Important limits: the appearance future guard requires a header representable as Swift `Int`. A malformed or unrepresentable version is classified as corrupt, not conservatively protected future data. There is no explicit size limit, duplicate-header detector, unknown-field round-trip preservation, interprocess compare-and-swap, disk flush receipt or permission-denied result in this store. Those stronger properties must not be inferred from the “atomic payload” comment. In particular, `.encodingFailed` does not test whether macOS persisted the suite to disk.

Source tests documenting this boundary:

- `Tests/PagingUITests/IconTypographyPreferencesTests.swift:testLegacySchemaDefaultsNewFieldsWithoutRewritingBytes:26–35`, `testSchemaTwoRoundTripAndInvalidSaveProtectPriorBytes:37–50`, `testSchemaTwoMissingWrongTypeFractionalAndOutOfRangeAreCorruptWithoutWrites:52–69`, and `testFutureVersionProtectsOpaqueBytesAndDisablesNewControls:71–83`.
- `Tests/PagingUITests/AppearancePreferencesTests.swift:testCorruptPayloadFallsBackWithoutWritingUntilExplicitSave:72–82` and `testFutureSchemaIsPreservedEvenWithUnknownPayloadShape:84–92`.
- These exercise synthetic suites and store reloads in source. They are not evidence of a fresh process restart or a denied OS write in this discovery.

## Apply, failure, factory and draft lifecycle

`AppearanceSettingsCoordinator.init` loads once and initializes `committed`, without invoking its presentation callback (`AppearancePreferences.swift:128–134`). `apply` validates and freshly reloads storage, blocks future versions, and skips a save only when draft, committed and a healthy current stored value all match (`apply:137–145`). Otherwise it saves first. Only `.saved` updates committed/load health; only an effective committed change invokes presentation (`apply:146–152`). Consequently:

- Explicit equal Apply can repair current corruption, a removed nondefault payload, or a different healthy stored value. Load/reopen/close does not repair it.
- A healthy matching schema-1 payload can remain byte-for-byte schema 1 indefinitely; equal Apply is not an automatic migration.
- Invalid/save-failed/future attempts leave accepted preferences intact and do not dispatch the failed draft. A failed newer draft cannot replace an earlier accepted pending presentation.
- `loadResult` is not refreshed on the failure returns of appearance Apply. A future payload introduced after opening can produce Save Future feedback without immediately disabling already-enabled controls; repeat Apply remains protected by the fresh checks. Do not promise live store-health observation.

Test evidence: `AppearancePreferencesTests.swift:testCoordinatorPersistsBeforeApplyingAndSkipsEqualApply:100`, `testFailedSaveDoesNotChangeCommittedOrUI:117`, `testExplicitCorruptRepairWritesOnlyOnce:134`, `testNativeEqualApplyRepairsCorruptionIntroducedAfterInitialization:144`, `testNativeEqualApplyRestoresRemovedNondefaultPayload:173`, `testNativeEqualApplyReplacesDifferentHealthyPayloadIntroducedAfterInitialization:200`, `testNativeEqualApplyPreservesLateFuturePayloadIncludingSaveRecheck:223–254`, `testNativeFailedRepairPreservesCommittedDraftAndSuppressesRuntimeApplication:256–285`, and `testNativeEqualApplyLeavesHealthyMatchingSchemaOneBytesUntouched:287–306`.

Factory facts:

- `Sources/PagingPrototypeApp/AppDelegate.swift:installAppearancePreferences:2238–2258` accepts an injected store or constructs the profile-specific/dedicated persistent store. A nil persistent factory leaves no coordinator and preserves previously displayed or queued appearance. It does **not** silently substitute `InMemoryAppearancePreferencesStore`.
- `configureAppearanceSettings:2262–2292` uses unavailable presentation/no Apply callback when no persistence owner exists. Its discard callback restores only the accepted pending-or-displayed snapshot, guarded by current owner/view identity. Healthy configuration binds the coordinator and restores its accepted snapshot on discard. Apply is refused during final teardown or a pending workspace quit.
- The generic Apply closure captures the coordinator weakly but has no explicit current-view/current-coordinator identity check; the discard closure does. A new asynchronous capacity owner needs explicit generation/invalidation rules rather than assuming all appearance callbacks already have those guards.
- Startup resolves the isolated test profile before preferences, then installs appearance before surface/content creation (`AppDelegate.applicationDidFinishLaunching:408–418`). Loaded style reaches the initial renderer in `installContentAssembly:811–812`.
- `UITestProfile.swift:UITestProfile.init:31–44` isolates existing suites. A new capacity store needs its own profile-local location/suite; do not fall back to production storage on isolation/factory failure. Invalid profile resolution aborts startup before preference installation (`AppDelegate:408–417`).

Factory tests: `Tests/PagingUITests/AppearanceDraftCloseIntegrationTests.swift:testNilPersistentFactoryRejectsChangedApplyWithoutSessionOnlySuccess:143`, `testNilPersistentFactoryDoesNotReportUnchangedDefaultsAsPersisted:160`, `testUnavailableFactoryPreservesPreviouslyAcceptedCustomAppearance:189`, `testUnavailableFactoryDoesNotDropAnAlreadyPersistedQueuedAppearance:204–225`, `testExplicitAppearanceStoreBypassesThePersistentFactoryAndStillApplies:227`, and `testUnavailableDiscardCannotResetAReplacementOwnerOrView:240`.

Settings facts:

- `AppearanceSettingsView.swift:init:37–59` creates separate noncontinuous icon/font sliders. `controlChanged:147–169` rounds and validates all current controls and reconstructs the complete appearance draft; `applyClicked:171–183` recollects controls before applying. Defaults only stages a draft (`defaultsClicked:185–190`); no live save or live slider presentation occurs.
- `reload:119–145` resets a draft from the supplied accepted value, disables all appearance controls on future data, and distinguishes corrupt/future feedback. Missing Apply callback shows unavailable and retains edited draft (`applyClicked:174`). Failed Apply retains the draft for retry.
- `ActivationSettingsWindowController.swift:hideSettings:322–330` discards appearance and language drafts after hiding; `windowShouldClose:355–359` routes through it and retains the window. `AppDelegate.configureAppearanceSettings:2278–2287` restores accepted coordinator values, which may still be queued, not older displayed values.
- Retained reopen is intentionally different from initial construction: `ActivationSettingsCoordinator.swift:prepareSettingsForPresentation:76–105` preserves existing interface drafts and refreshes accepted language instead of rerunning every settings configurator. A capacity view must be attached to close/discard and text-only relabel explicitly; do not rely on reopen reconstructing it.

Draft tests: `AppearanceDraftCloseIntegrationTests.swift:testNativeCloseDelegateDiscardsUnappliedDraftWithoutSavingOrApplying:56`, `testHideDiscardsDefaultsDraftBackToAcceptedCustomValues:70`, `testCloseUsesAcceptedQueuedValuesRatherThanOlderPresentedValues:81–97`, `testFailedApplyThenCloseRestoresAcceptedValuesNotFailedDraft:99`, `testAppearanceDismissalDoesNotResetActivationOrAliasDrafts:112`, and `testRetainedDiscardCallbackCannotMutateReplacedSettingsView:125`. Scroll/footer/draft-only defaults coverage is in `IconTypographyPreferencesTests.swift:85–127`.

## Accepted versus presented state and input deferral

`AppDelegate.swift:applyAppearancePreferences:2327–2336` stores one latest accepted whole preference snapshot. Accepting the currently displayed value cancels any superseded pending snapshot. `appearancePresentationState:2339–2342` reports queued/applied/unavailable, separately from persistence health.

`appearancePresentationIsReady:2345–2356` blocks final teardown, restoration, reentrant appearance work, workspace quit, title editing, rename context, active drag/pointer session, folder entrance/exit, folder trackpad paging/collapsed move-out, pinned presentation and nonterminal outer paging states. It does **not** require an ordinary open folder to close and does not contain the broader language/IME/modal/Library ownership checks. Therefore the draft's “wait until folder closed and all editing/modal ownership ends” is a new capacity contract, not an existing appearance guarantee.

`flushPendingAppearanceIfReady:2359–2374` fans style out to renderer and folder, refreshes folder layout and changes wallpaper only for a blur change. It performs no capacity reconfiguration. `schedulePendingAppearancePresentation:2378–2388` schedules a coalesced next-main-turn attempt and rechecks readiness; it does not poll every frame or force-cancel input. Readiness events, including normal hide, schedule retries (`prepareTransientCancellationForHide:3399–3420`; `launcherDidHideHandler:3423–3436`).

Test evidence: `IconTypographyOwnerTests.swift:testGestureQueuesLatestAcceptedDraftWithoutInterruptAndAppliesAtActualIdleCallback:99–114`, `testAcceptedReturnToCurrentStyleCancelsSupersededQueuedDraft:130–139`, `testTerminalFrameDefersAppearanceAndRechecksNewInputBeforeQueuedDrain:203–228`, and `testHideCancellationAppliesAcceptedQueueAndTornDownSurfaceDoesNotWritePresentation:335–349`. Existing callback tests do not establish a capacity transaction.

Capacity integration recommendation: preserve separate appearance and capacity pending slots and status. Both must consult one coherent owner/readiness boundary, but capacity may have stricter conditions than appearance. Never broaden scalar appearance's folder-close requirement accidentally. Successful capacity persistence should queue its immutable snapshot; a failed later request leaves earlier accepted state intact. Closing settings discards only unaccepted capacity edits. Geometry/anchor/focus/drag ordering belongs to the other reader and Main, not this report.

## Localization and language-draft preservation

- `AppearanceSettingsView.swift:relabel:235–253` updates text/accessibility and rerenders retained feedback by key; it does not reload preferences, query the presentation owner, apply, reset controls or persist. `refreshPresentationStatus:203–214` only replaces feedback for an accepted draft, preventing a delayed Applied event from overwriting new unsaved edits/defaults/errors.
- `ActivationSettingsWindowController.swift:relabel:207–227` relabels existing sections in place. Its `hasLanguagePresentationOwnership:193–197` accounts for shortcut recording, source operations, attached sheet and marked text in the settings window.
- `AppDelegate.swift:configureLanguageSettings:2655–2684` reloads the language draft only on first configuration; accepted Follow System refresh never accepts another section's draft. `languagePresentationIsReady:2688–2702` waits through title/rename, drag, folder transitions/paging, settings and Library ownership, sheets/modals and launcher marked text. `presentLanguage:2722–2747` relabels existing consumers.
- `LanguageSettingsCoordinator.swift:apply:22–43` has its own persistence acknowledgements and `invalidate:53` lifecycle. Its explicit comment at lines 3–4 confirms that UserDefaults acknowledgement is not disk flush confirmation. Do not join language and capacity draft state or call capacity reload during language presentation.
- Add any new capacity vocabulary to `SettingsTextKey.swift` and all three `Resources/{en,zh-Hans,ja}.lproj/Localizable.strings`, plus `LocalizedStrings.swift:safeEnglishSettingsText:143`. Existing appearance messages are at each resource's lines 39–59; they describe style fitting in existing cells and should not silently become capacity promises.
- `LocalizationResources.swift:ResourceKey.all:104–117` derives required keys from enums. `ResourceTable.init:162–198` validates exact key presence, unexpected keys and placeholder signatures; static settings keys have no arguments (`ResourceKey.placeholders:144–147`). A dynamic capacity summary needs a deliberate formatting API or separate numeric display, not invented placeholders in a static settings string.

Read test evidence: `LanguageSettingsConsumersTests.swift:testAppearanceMountedTextAndAXPreserveDraftControlsAndCallbacksInAllLanguages:93`, `testAppearanceRetainsQueuedStatusUntilExplicitStatusRefreshAndDraftFeedbackSurvives:144`, `testAppearanceLoadsAndSaveFailuresKeepTheirMeaningAcrossRelabel:183`, and `testInvalidNativeAppearanceDraftIsNotResetOrSavedByRelabel:230`. These assert draft/control/callback identity and retained feedback across Chinese, English and Japanese. Localization schema/fallback tests: `LocalizationResourceValidationTests.swift:testRequiredKeyContractAndEveryShippedTableHaveExactCoverage:6–71`; `SettingsLocalizedStringsTests.swift:testEverySettingsCaseRendersItsActualSelectedResource:6`; `testEverySettingsKeyIsStrictlyRequiredAndCannotAcquireArguments:156`; `testAbsentAndInvalidResourcesSupplyAllKeySpecificSafetyValues:237`. None were run here.

## Quit, receipt and restart facts

`AppDelegate.swift:requestWorkspaceQuit:3549–3585` enters protected termination only for workspace writes or Library `requiresQuitProtection`. It captures store/epoch, drains workspace, always drains Library even if workspace failed, then checks owner identity/epoch. There is no appearance/capacity store in this sequence. A pending appearance display alone does not make it return `.terminateLater`.

`WorkspaceQuitCoordinator.swift:request:16–39` owns one generation-checked termination decision: success approves, unsuccessful outcomes wait for explicit choice. `cancelPending:43–50` invalidates old replies and permits retry. `WorkspacePersistenceQueue.swift:drain:61–109` waits for accepted enqueues and a bounded flush receipt; a newer submission cannot reuse an older successful receipt. This is a materially stronger contract than `UserDefaults.set` acknowledgement. Tests describing these guarantees are `WorkspaceQuitCoordinatorTests.swift:12–74` and `WorkspacePersistenceQueueTests.swift:testDrainWaitsForAcceptedEnqueueBeforeFlush:62`, `testNewAcceptedBatchCannotReuseOldSuccessfulReceipt:176`, `testSubmissionDuringOngoingFlushRequiresAnotherReceiptForLatestBatch:188`.

`AppDelegate.swift:teardownAll:3713–3726` clears pending appearance presentation after marking teardown. It does not undo the already accepted preference write or flush it. Normal restart loads the store again through `installAppearancePreferences`; current source establishes that loading path, not crash/power-loss durability. No real restart was performed by this reader.

For the draft's stronger capacity requirement, an existing bounded pattern is available without changing appearance:

- `AppLibraryPreferencesCoordinator.swift:submit:49–80` serializes immutable requests, tracks actual successful write generations separately from UI freshness, and suppresses stale callbacks. `requiresQuitProtection:15–17` includes pending writes and failed latest saves; `drain:85–100` has a real timeout and explicit unsuccessful results. `invalidate:103–107` suppresses late UI work without canceling accepted writes.
- `AppLibraryStore.swift:AppLibraryFileStore.save:167–185` rereads/guards current storage and acknowledges `.saved` only after its I/O replacement returns. `LocalAppLibraryFileIO.replaceAtomically:47–88` includes a participating-writer lock, expected-byte check, file fsync, rename and directory fsync, with explicit race limits in comments at lines 33–35 and 84–85. This is a source example, not authorization to reuse the Library payload/path or a claim that a new store already exists.

Recommendation under the current draft: separate capacity schema and receipt-bearing asynchronous owner/store; explicitly add capacity to termination admission, drain, identity checks and failure/cancel/retry handling. Keep “saving” separate from “saved but waiting for safe presentation.” Do not request current input/folder closure just to finish quitting; persistence drain and presentation readiness are distinct. Avoid a generic persistence-framework refactor in this slice. If Main instead chooses scalar UserDefaults parity, amend draft line 29 before confirmation to state the weaker write acknowledgement and omit any existing-flush guarantee. Exact backing/location and acknowledgement strength remain Main's specification decision.

## Storage alternatives and migration consequences

| Option | Compatibility and consequences |
| --- | --- |
| Separate versioned capacity preference — recommended | Existing appearance schema 1/2 bytes, custom icon/font and workspace format need no migration. Missing capacity defaults to columns 5 / rows 7. Current old code has no capacity reader/writer, so it ignores the new storage and uses its own default grid; it must not be advertised as honoring the new capacity. A later new executable can read retained capacity again. Keep future capacity protection independent so it cannot disable ordinary appearance editing. Backing must match the chosen receipt contract above. |
| Add required fields while continuing to write appearance schema 2 | Unsafe versioning: current synthesized decoder has no missing-key defaults for new stored fields; a new reader would reject existing schema-2 bodies unless explicit legacy decoding is added. The current old reader does not model unknown fields and a later save re-encodes its four known fields, losing capacity. Initialization defaults alone do not provide Codable migration. |
| Add optional/default-decoded fields without bumping schema 2 | Avoids missing-key failure in the new reader, but old saves still discard new fields. Silent loss violates forward preservation; not recommended. |
| Bump appearance to schema 3 with explicit v1/v2 decoders | Can offer one atomic appearance/capacity payload and Apply scope. Must decode old v1/v2 shapes explicitly, preserve all old values and assign only missing capacity to 5/7. Load must not rewrite; healthy matching equal Apply may leave legacy bytes unchanged. The current schema-2 executable sees any valid header 3 as future, displays default entire appearance and disables all appearance controls. It preserves bytes but loses usable custom appearance during downgrade. Corrupt capacity also couples recovery to all appearance. Requires explicit product acceptance of this tradeoff. |

The downgrade statements follow the current appearance decoder/save and absence of capacity fields in the inspected composition; they are not tests against an independently archived older executable or arbitrary future implementations.

Proposed capacity decoder contract for Main to adopt or revise: one versioned envelope with integer columns and rows; for the proposed range require each 3–8 before multiplication (capacity 9–64). Missing store defaults to 5/7 without writes; present supported-version bodies must contain both correctly typed valid fields. Do not partially accept a corrupt pair or silently clamp malformed stored values. Distinguish missing, corrupt, future/protected and unavailable. Protect future/ambiguous data before typed body decoding and recheck before save. Do not copy appearance's Int-overflow future-header gap into a supposedly stronger new decoder. Explicit Apply may repair corrupt capacity only under the confirmed recovery policy; load, language change, close and ordinary resize must never repair it. Unknown-field/version handling must be stated, not silently discarded by accidental Codable behavior.

Folder independence: current ordinary outer defaults are five columns/seven rows (`AppGridGeometry.swift:AppGridGeometry.init:12–22`); startup defaults to 35 items/page (`AppDelegate.swift:applicationDidFinishLaunching:456–458`). `FolderLayoutPolicy.swift:resolve:26–56` takes bounds and item appearance, independently resolves up to five columns/three rows and has no outer row/column input. Keep capacity out of `GridItemAppearance` and out of that folder policy. Shared icon/font preferences may continue to influence folder fitting as they do today; main-grid capacity must not become another input.

## Minimal coherent follow-up, after confirmed specification only

1. Main integrates these facts into the English draft: separate capacity preference, exact persistence acknowledgement/backing, separate Apply/Defaults scope, explicit capacity drain participation if retained, recovery/future behavior, and strict distinction between saving/accepted/queued/presented. Keep 3–8 and folder-close deferral proposed until user confirmation. The user reply was still pending at this report's closeout.
2. Define a small capacity domain value and versioned store/coordinator with isolated test location and injectable unavailable/failure seams. Preserve appearance schema 2, defaults 48/11, labels/blur and organization. Do not migrate data on startup just to create a new capacity payload.
3. Add independent controls/status in existing settings, text-only relabel, pending-edit recollection on Apply, scoped draft defaults, accepted-snapshot discard on close, and current owner/view/generation guards. Failed save retains draft and earlier accepted configuration. For asynchronous receipts, stale completions must not reset a more recently edited draft or mark it Applied.
4. Connect the successful capacity snapshot to Main's single layout owner and the other reader's transaction design; do not copy appearance fan-out as if it repaginated. Capacity deferral while a folder is open must leave folder geometry/state untouched and must not delay existing style unnecessarily.
5. Later verification should cover missing/legacy defaults, endpoints, malformed/overflow/future/protected bytes, unavailable factory, failed/late receipts, repeated/equal Apply, explicit repair/no implicit writes, latest successful queue semantics, close/reopen and three-language draft preservation, capacity-only quit, combined workspace/Library/capacity failures, cancel/retry and fresh normal restart. Main owns execution against a newly frozen implementation; the present report supplies no test result.

## Open risks and unresolved decisions

- Draft line 29's quit promise is not supplied by existing scalar preference code. Resolve this before treating the spec as confirmed, rather than presenting a later storage expansion as routine implementation.
- Independent stores cannot provide all-or-nothing cross-store Apply without a new transaction contract. Separate Apply/Defaults is recommended; a combined action needs explicit partial-failure semantics.
- A capacity store replacement/view replacement and newer edits during asynchronous save require explicit epochs and feedback ownership. Existing appearance discard guards alone are insufficient.
- Source facts do not establish minimum viewport readability, 64-slot resource/performance envelope, anchor/focus/drag consistency or safe order of simultaneous appearance/capacity transactions. Those are owned by Main and the geometry reader.
- No fresh runtime, native UI, restart, permission-denial, physical performance, build, full-suite or 464-input integrity claim is made. No production implementation should start automatically from this report.

Change disclosure: added only `Workflow/results/MAIN_GRID_CAPACITY_PREFERENCES_DISCOVERY.md`.
