# Live Appearance and Integrated Grid — Delivery Results

Date: 2026-10-17
Status: IMPLEMENTED; AUTOMATED/BUILD/BOUNDED SOURCE REVIEW PASSED; BOUNDED NATIVE SAVE/RESTART OBSERVED. Human continuous-drag/live-effect acceptance PASSED on 2026-10-17; see the appended human acceptance record.

## Confirmed product contract
The human approved `Docs/LIVE_APPEARANCE_AND_GRID_SPEC.md`: automatic live effect and automatic saving; rows/columns inside Appearance; no independent Grid tab or healthy Apply button; safe interaction boundaries remain. Closing no longer discards accepted appearance/grid edits. Other settings retain their own explicit-Apply behavior: this change does not remove Activation or Language Apply.

## Delivered implementation
- Native Appearance has six settings tabs overall, one vertically scrolling appearance/grid page, continuous native sliders, immediate numeric feedback, embedded main-grid rows/columns/count and one scoped Restore Appearance Defaults. Retry/recovery appears only when needed; programmatic reload/relabel is silent.
- `LiveAppearanceSettingsCoordinator` separates latest valid user intention/preview from the current persistence acknowledgment. One cancellable200ms common-mode debounce retains the newest value; pointer tracking end, completed checkbox/nonmouse action, dismissal and Quit flush admitted work. Failures retain intention and save protection. A success state is not used as evidence that queued geometry is already displayed.
- Existing Appearance schema2 and dedicated capacity schema1 stay separate. No workspace/layout schema migration. Supported corruption requires explicit recovery, including corruption discovered after preview; future/unknown/unavailable storage remains protected.
- Existing explicit appearance commands remain valid. Successful current commands, even equal healthy commands, supersede older live debounce state; weak owner identity revokes old command presentation authority. Reentrant flush cannot cancel the newest debounce or falsely acknowledge it.
- Capacity has one immutable active write plus one latest replaceable queued intention, not an unbounded task chain. Actual intermediate successful receipts remain tracked; failed newest intentions remain visible/unsaved rather than silently rolling back. Healthy equal idle values do not write again; failed/indeterminate retries and missing/corrupt explicit creation/recovery still need a real write.
- Native dropdown admission previews through the existing safe capacity transaction; stable app/folder identity, query, canonical order, keyboard and stale menu/icon/drag guards remain. Folder and Library defer main-grid reflow. No PagingCore/physics/tolerance/frame-driver change.
- Wallpaper background rendering has at most one active render plus one latest pending request per controller. Stale completions retain existing generation/host guards. No synchronous full-resolution blur was added to the input path. This bounds render work, not whole-process memory, source diagnostics or physical latency.
- Added14 typed localized strings×English/Simplified Chinese/Japanese, including recovery-aware failure instructions. Existing legacy text keys are retained for old document/resource compatibility but are not used for live Apply/discard instructions.

## Verification on stable inputs
| Gate | Actual result |
| --- | --- |
| Focused new functionality/review repairs |95 tests/0 failures,7.279s; `focused-r5.log` |
| Broadened integration/legacy-contract tests |260/0,15.606s; `broadened-r6.log` |
| Full XCTest |**2951/0**,88.824s; `full-r2.log` |
| Debug product |PASS,0.52s; `debug-r1.log` |
| Actual Release product |PASS,54.33s; `package-r1.log` |
| Native test entry/package/localization |PASS,323 required keys/signatures×3 languages, packaged resources only |
| Independent bounded owner review |Carver R2 SOURCE PASS, four R1 findings repaired |
| Independent UI/localization review |Hypatia R2 SOURCE PASS, two R1 findings repaired |
| Input hashes / diff check |All488 frozen inputs match after native;23 existing modified+6 new, zero removed; PagingCore unchanged; `git diff --check` PASS |

The separate empty Swift Testing footer is not used as test evidence; these are nonzero XCTest totals. Release packaging emitted no warnings; broader test compilation did emit warnings in existing test surfaces, so no whole-suite zero-warning claim is made. All agents and build/test jobs are terminal.

## Failures and corrections retained, not silently relabeled
- First compile failed Main's covariant Self default argument / actor-isolation boundary; corrected actor-aware scheduler/default and existing main-actor teardown boundary. No runtime PASS from that attempt.
- Owner review R1 four actual issues reproduced **4 methods/10 failed assertions** (`owner-review-red-r1.log`), then repaired and re-reviewed R2. Nested save, explicit/current/old-owner authority and healthy equal-capacity cases are distinct from UI acceptance.
- UI review R1 missing nonmouse completion and incorrect failed-recovery instruction reproduced **3 methods/10 failed assertions** (`ui-review-red-r1.log`), then repaired and re-reviewed R2.
- `focused-r4.log`:95/1; new synthetic tracking fixture sent a completed nonmouse action and a second artificial completion. Changed only its sender to the documented synthetic continuous update; actual nonmouse completion tests remain.
- Old broad contract run249/167 failed assertions(one unexpected) preceded migration of the previous Apply/draft-discard/tab/copy expectations. Four-file Worker adaptation retained70 test methods and byte/future/corrupt/gesture/late-callback assertions. Main corrected its incorrect numeric AX assumption to the actual full native count caption. A first textual replacement matchedzero and one repeat run retained the same36 failures; verified multiline correction followed. Raw logs stay intact.
- Fullr1 **2951/12**, confined to three additional old IconTypography preference tests excluded by the prior name filter. Updated live-action/defaults/receipt expectations, no production repair. A geometry probe showed the scoped Defaults button offscreen in a small standalone viewport, not clipped: the approved design scrolls all content/buttons. Final test requires full Defaults frame reachability after scrolling, not an obsolete fixed-footer promise. Final broad/full results above are from the corrected frozen source.

## Bounded native observations
Candidate: `.build/candidates/live-appearance-grid-rc-20261017-r1/LaunchcopyUITest.app`.
Executable SHA-256: `b1ca4fcbcedc4ff5da45d3775cf6a9c587b4cb117933d87ce5d7ef7ce8cf48c7`.
Unsigned/uninstalled; no formal app overwritten. Own previous diagnostic normally Quit and exact process absence was verified before handover.

Authored fixtures only:80 Info-only apps without executables;46 outer items and35 folder members. Copied only those Info.plists, own layout/Library/capacity JSON and the exact validated own appearance payload into the fresh isolated namespace. No cache/locks/formal data copied. The previous actual test preferences were icon54/font12/blur23, names on, **6columns×5rows**, not the product default5×7; these were preserved at initial load and restored after checks.

| Native case | Observed evidence |
| --- | --- |
| Six tabs/merged page |No independent Grid tab. Appearance shows existing sliders and6×5/count30; no healthy Apply. Chinese layout visually inspected. |
| Nonmouse/AX slider changes |Blur31/icon40/font14 update numeric captions and Saved state without Apply. |
| Native checkbox |Names off, automatically saved; main screenshot shows icons without visible captions. |
| Native row/column menus |3×3 automatically saves/applies, count9 and six main pages; no Apply. |
| Close behavior |Main retains3×3/no-label state after settings closes. |
| Folder independence |35 members remain15/page,3pages; Next shows16–30, one Escape closes. This is button/keyboard evidence, not a new physical swipe gate. |
| Same-candidate restart |Normal Quit/exact absence; disk payload31/40/14/no labels and3×3 verified. Reopened same candidate visibly loads those exact values. |
| Scroll reachability |Native vertical scroll reaches grid feedback and scoped Defaults. Returned to top for handover. |
| Baseline restoration |Via live controls only, restored blur23/icon54/font12/names on and6×5/count30. Actual Saved/Applied states observed. |
| Mouse drag attempt |Two CUA drags left icon value unchanged. These are **not PASS**, and do not establish whether the cause is automation/native tracking. Human continuous-drag trial was requested. |

No intermediate drag frames or physical latency were captured. AX setValue success, source isContinuous and post-action screenshots do not by themselves prove real pointer-following quality. Current English/Japanese native layouts were not rerun; packaged/source/localization tests are separate evidence.

Final receipt: `.build/verification/20261017/live-appearance-grid/native-handover-r1.json`; normal-Quit receipt `native-normal-quit-r1.json`; frozen sources `source-integrated-r3.json`. Packaging/initial candidate-r1 launched:false is a historical prelaunch record, superseded by the actual native receipt. At final receipt the same candidate was running PID29032, ordinary non-topmost, Appearance settings open/top; the human can now edit values, so snapshots are timestamped rather than promises of immutable current preferences. Layout and Library payload hashes remained unchanged.

## Honest remaining gates and safeguards
Human continuous-drag acceptance is pending. Original intermittent folder-scroll causality remains unresolved despite earlier user-confirmed success on a prior diagnostic candidate. Current wallpaper diagnostic was loading during this native matrix; earlier ready/render-failed outcomes remain history, not a rootcause fix. Physical >25ms latency causality,120Hz/multidisplay, actual energy/RSS, real IME and spoken VoiceOver/offscreen AX remain independent. No whole-product parity completion is claimed.

No reference-project source/resources, formal data, OS/security settings, signals/kill, signing/notarization/install/publication or commit/reset/clean operations. Native UI through CUA only, own instances closed normally. No screenshot files were saved. User waived Chief ceremony; Main owned integration and serialized builds, maximum3 agents including Main with disjoint writes.

## Changed implementation/test inputs
- `Sources/LauncherLocalization/LocalizationResources.swift`
- `Sources/LauncherLocalization/LocalizedStrings.swift`
- `Sources/LauncherLocalization/Resources/en.lproj/Localizable.strings`
- `Sources/LauncherLocalization/Resources/ja.lproj/Localizable.strings`
- `Sources/LauncherLocalization/Resources/zh-Hans.lproj/Localizable.strings`
- `Sources/LocalizationResourceProbe/main.swift`
- `Sources/PagingPrototypeApp/ActivationSettingsWindowController.swift`
- `Sources/PagingPrototypeApp/AppDelegate.swift`
- `Sources/PagingPrototypeApp/AppearancePreferences.swift`
- `Sources/PagingPrototypeApp/AppearanceSettingsView.swift`
- `Sources/PagingPrototypeApp/MainGridCapacityCoordinator.swift`
- `Sources/PagingPrototypeApp/MainGridCapacitySettingsView.swift`
- `Sources/PagingPrototypeApp/WallpaperBackdropView.swift`
- `Tests/LauncherLocalizationTests/LocalizationResourceValidationTests.swift`
- `Tests/PagingUITests/AppearanceDraftCloseIntegrationTests.swift`
- `Tests/PagingUITests/AppearancePreferencesTests.swift`
- `Tests/PagingUITests/IconTypographyOwnerTests.swift`
- `Tests/PagingUITests/IconTypographyPreferencesTests.swift`
- `Tests/PagingUITests/LanguageRuntimeIntegrationTests.swift`
- `Tests/PagingUITests/LanguageSettingsConsumersTests.swift`
- `Tests/PagingUITests/MainGridCapacityCoordinatorTests.swift`
- `Tests/PagingUITests/MainGridCapacityIntegrationTests.swift`
- `Tests/PagingUITests/MainGridCapacitySettingsViewTests.swift`

### New inputs
- `Sources/LauncherLocalization/LiveAppearanceTextKey.swift`
- `Sources/PagingPrototypeApp/LiveAppearanceSettingsCoordinator.swift`
- `Tests/LauncherLocalizationTests/LiveAppearanceLocalizedStringsTests.swift`
- `Tests/PagingUITests/LiveAppearanceCoordinatorTests.swift`
- `Tests/PagingUITests/LiveAppearanceSettingsViewTests.swift`
- `Tests/PagingUITests/LiveWallpaperRenderTests.swift`

## Next action
Human can directly use Appearance sliders and embedded row/column controls. On a real continuous-drag issue, preserve the running instance and characterize actual input/value/presentation before changing physics or weakening owner guards. Do not infer a successful physical gate from automation attempts that left values unchanged.

## Human live-effect acceptance — 2026-10-17

The human replied “实时变化正常” to the request to continuously drag the Appearance sliders in the delivered isolated candidate. This resolves the pending human continuous-drag/live-effect gate. The merged Appearance/row-column feature is accepted within its delivered scope; the reply specifically confirms real-time visual changes, not a separate measured performance or persistence result. Existing native save/restart observations and automated results remain their own evidence.

The two earlier inconclusive CUA drag attempts remain recorded as not PASS; human acceptance does not relabel those attempts. No source changes, rebuild, app restart, or preference restoration were performed for this closeout. Current user settings are left untouched. Other product acceptance and root-cause gates remain open; full LaunchBetter parity is not complete. Older pending-gate snapshots below are historical and superseded only for this human live-effect gate.
