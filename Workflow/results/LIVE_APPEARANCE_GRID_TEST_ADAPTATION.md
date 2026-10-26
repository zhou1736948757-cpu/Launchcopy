# Live Appearance / Grid Old-Contract Test Adaptation

Date: 2026-10-17
Status: STABLE CHECKPOINT — test files frozen; execution and acceptance belong to Main.

## Authority and scope

Bounded adaptation to the human-approved `Docs/LIVE_APPEARANCE_AND_GRID_SPEC.md` and Main's clarified live/explicit-command boundaries. Project AGENTS and `/Users/mac/.codex/RTK.md` were read. Chief ceremony was waived by the human.

Only these five files were written:

- `Tests/PagingUITests/AppearancePreferencesTests.swift`
- `Tests/PagingUITests/IconTypographyOwnerTests.swift`
- `Tests/PagingUITests/LanguageSettingsConsumersTests.swift`
- `Tests/PagingUITests/MainGridCapacitySettingsViewTests.swift`
- `Workflow/results/LIVE_APPEARANCE_GRID_TEST_ADAPTATION.md`

No production source, new feature/review test files, workflow state, reference material, formal data, process state, OS settings or Git state was modified. All shell commands used RTK and only read existing files. No tests, compiler, build, UI automation or application were executed.

## Exact semantic mappings

| File / previous test or assertion | Replacement and retained meaning |
| --- | --- |
| Appearance helper bound only `onApply` | Binds the real `LiveAppearanceSettingsCoordinator` through `onChange`, live status, retry, explicit flush and dismissal; uses an inert injected scheduler so these tests control flushing without wall-clock waits. Base-command acknowledgments feed the live owner exactly as in the composition root. |
| `testNativeEqualApplyRepairsCorruptionIntroducedAfterInitialization` | `testExplicitRecoveryRepairsCorruptionIntroducedAfterInitialization`: inspect real late corruption, reload the actual corrupt result to expose recovery, click that visible recovery action. A subsequent equal base command remains a no-op. Original write-count, bytes/load, unchanged committed value, green feedback and zero presentation assertions remain. |
| `testNativeEqualApplyRestoresRemovedNondefaultPayload` | `testExplicitCommandRestoresRemovedNondefaultPayload`: real `live.retry` explicit command replaces a missing payload; healthy UI Apply remains hidden. Reopen, persisted values, write count and presentation assertions remain. |
| `testNativeEqualApplyReplacesDifferentHealthyPayloadIntroducedAfterInitialization` | `testExplicitCommandReplacesDifferentHealthyPayloadIntroducedAfterInitialization`: real explicit live command reconciles an externally replaced payload; no fabricated failed UI state. Existing persistence and feedback assertions remain. |
| `testNativeEqualApplyPreservesLateFuturePayloadIncludingSaveRecheck` | `testExplicitCommandPreservesLateFuturePayloadIncludingSaveRecheck`: real explicit live commands assert typed future-version rejection both before admission and inside the store's save recheck. Original exact future bytes, write counts, committed value and red feedback remain. |
| `testNativeFailedRepairPreservesCommittedDraftAndSuppressesRuntimeApplication` | Name retained: reload actual late corruption before the visible recovery click. Retain both equal and changed failed-repair assertions; additionally require exact `liveAppearanceText(.recoveryFailed)` feedback. |
| `testNativeEqualApplyLeavesHealthyMatchingSchemaOneBytesUntouched` | `testExplicitCommandLeavesHealthyMatchingSchemaOneBytesUntouched`: issue the real base command twice. Keep exact differently formatted schema-one bytes, zero writes, foreign key, loaded value, green acknowledgment and zero presentation work. |
| `testControlsStageApplyAndReloadWithoutImplicitPersistence` | `testLiveControlsAutosaveOnFlushAndDefaultsPersistWithoutApplyOrCloseDiscard`: synthetic `controlChanged(nil)` previews/submits without flushing, `onFlush` saves, Defaults submits and flushes, dismissal flushes a later edit, and reopen retains it. Exact save counts replace the superseded discard requirement. |
| Seven-tab assertion in `testSettingsUsesOneWindowWithBothSectionsWithoutShowingIt` | Exactly six tabs, no `grid` tab, the retained capacity view is the identical `mainGridSection` and an Appearance descendant; prior tab identities and unshown-window assertion remain. |
| `testAppearanceTabHasUsableUnclippedControlGeometry` | `testAppearanceTabScrollsToUsableUnclippedControlsAndActionableFooter`: controls must fit the scrolling document and each must become fully visible when scrolled to. Check the enabled, visible Defaults footer and hidden healthy Apply, retaining positive dimensions and unambiguous layout. |
| Icon/typography fixture's hidden Apply click | The same helper now calls `controlChanged(nil)` followed by `onFlush`. All gesture, held pointer, drag, terminal-frame, folder animation, stale completion, original binding/generation, icon request and teardown assertions remain. |
| `testIdleNativeApplyChangesOnlyAppearancePreservingBindingsAndIconRequests` | `testIdleLiveEditAndFlushChangesOnlyAppearancePreservingBindingsAndIconRequests`. |
| `testIconAndFontChangesNeverRequestWallpaperAndEqualApplyDoesNoPresentationWork` | `testIconAndFontLiveEditsNeverRequestWallpaperAndEqualEditDoesNoPresentationWork`. The queued-feedback substring check becomes exact saved-plus-queued localized text. |
| Appearance language controls used legacy Apply/Defaults/help copy | Assert exact `liveAppearanceText(.retry/.defaults/.help)`, AX labels and hidden healthy Apply while preserving control/constraint identities, callback installation, numeric values, responder and three distinct languages. Exercise both real live callback and visible corrupt recovery callback. |
| `testAppearanceRetainsQueuedStatusUntilExplicitStatusRefreshAndDraftFeedbackSurvives` | `testAppearanceRetainsQueuedReceiptUntilStatusRefreshAndDefaultsAutosubmit`: real live change receives saved-plus-queued feedback, relabel cannot query the owner, refresh updates presentation only, Defaults automatically submits once. Saved-plus-presentation-unavailable remains exact and uses secondary feedback color. |
| Appearance load/save localization errors | Exact live recovery-required/protected/save-failed/unavailable strings replace obsolete generic strings. Actual rejected live admission exposes Retry before explicit save-result cases. Invalid-preference validation remains in addition to the failure message. Failed corrupt recovery gets exact recovery-failed copy and visible enabled Recover in every language. Invalid native draft assertions remain. |
| `testEveryBoundedPairUsesExactTagsAndDerivedCountWithoutSaving` | `testEveryBoundedPairUsesExactTagsAndDerivedCountAndAutomaticallySubmits`: all 36 ordered pairs must submit exactly once, with unchanged exact menu tags and derived count. AX value is the numeric count, matching the current control's value contract; visible text still includes the exact caption. |
| Capacity admission / synchronous receipt tests clicked hidden Apply | Bind the owner before a valid actual selection; assert automatic admission and preserve saving-until-receipt and synchronous-receipt precedence. |
| Capacity failure/newer edit/retry write sequence | Both valid edits auto-submit, so exact sequence is `[accepted, newer, newer]` after explicit visible Retry. Keep newer draft/tags and receipt-only nonreplacement checks. |
| `testCorruptLoadNeedsExplicitApplyAndOnlySuccessfulReceiptClearsWarning` | `testCorruptLoadNeedsExplicitRecoveryAndOnlyItsSuccessfulReceiptClearsWarning`: Defaults and relabel remain write-free while corrupt, visible Recover submits, failure keeps warning, an old success cannot clear it, and a new explicit recovery plus success can clear it. |
| `testDefaultsOnlyChangesDraftAndItsFeedbackSurvivesReceiptRefresh` | `testDefaultsAutomaticallySubmitsAndReceiptRefreshRetainsDefaultSelection`: exact default tags/count and one automatic submission; no staged-default feedback, actual saving then queued receipt feedback. |
| Capacity generic load/protection/failure copy | Exact live recovery-required/protected/unavailable/save-failed strings, with recovery-failed checked explicitly after a failed repair. Recovery-required permits the explicit recovery action; protected receipt blocks direct edits/defaults/commands. |
| Capacity tampered-count / repaired invalid-tag final explicit Apply | A valid final edit itself submits once. Preserve every invalid count/tag/menu identity/title rejection, retained draft and zero unauthorized write assertion. Relabel still preserves callback, control, constraint and menu identities. |
| `testControllerRetainsGridTabAndDiscardsOnBothHideAndWindowClose` | `testControllerRetainsGridUnderAppearanceAndPreservesSubmittedEditsOnHideAndClose`: six tabs, retained embedded descendant and localized subsection title. Exact two-request sequence survives relabel/hide/close without rollback or duplicate submission; unrelated activation/appearance drafts remain unchanged. |

No test method was deleted. Static method counts at freeze: Appearance 23, IconTypography 16, LanguageConsumers 17, CapacityView 14; 70 methods total. Existing source-admission cancellation/late-callback and all unrelated management/source localization tests are unchanged.

## Evidence boundary and Main handoff

- Existing `broadened-r1.log` was read as historical RED evidence; its failures are not a verdict on these edited files. Main supplied the historical 249-method / 167-assertion-failure (one unexpected) count.
- Static source inspection and targeted rereads only. No execution-based PASS or compile claim is made.
- Main's final message reports focused r5 new-feature/review-fix coverage at 95/0 and independent R2 SOURCE PASS. That evidence belongs to Main and does not establish execution of this checkpoint's four files.
- Four test files are frozen for Main's requested compilation and focused execution. Production fixes and any remaining integration failures remain Main-owned.

Minor unexecuted integration points to check first: strict scroll-document/viewport containment after native layout; the numeric capacity AX-value assertion; Swift inference for the typed save-result/localization tuple and inert scheduler closure; and merged-source `recoveryFailed` rendering. These are explicit assertions or compile surfaces, not reasons to weaken the tests. No broad refactor or additional scope is proposed.

## Main execution correction — 2026-10-17
Broadenedr2 ran252methods/36assertfailures, all36theone numericAX expectation inboundedpairtest. Actual NSTextField returns full localized count caption, as prior capacity-stage native/test evidence already established. Main corrected that exact assertion to full countLabel.stringValue; no product change, no removal of derived count/menu/admission assertions. All other migrated tests passed in that run. Worker report's numericAX claim is superseded, retained as history.
