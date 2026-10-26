# Live Appearance / Integrated Grid — Independent UI and Localization Review

Date: 2026-10-17
Verdict: **FAIL — source-only; two P2 findings**

## Authority and evidence boundary

This is the bounded independent UI/localization review requested by Main. Chief ceremony is human-waived. The supplied concurrency allocation is Main + Carver (core owner/reviewer) + this reviewer; no additional agents were created. UI/localization workers were reported closed and their sources stable. Main retains serialized execution r2 and the later native UI gate.

Only this report was written. No implementation or test edits, application/probe execution, builds, test runs, UI interaction, process management, Git operations/diffs, reference-source access, OS changes, or formal-data actions were performed. File reads and SHA-256 capture were used for source evidence. No broad dirty-tree attribution was attempted. The initial read of RTK preceded awareness of its prefix rule; subsequent shell source operations used `rtk`.

Reviewed the approved `Docs/LIVE_APPEARANCE_AND_GRID_SPEC.md`, project `AGENTS.md`, `/Users/mac/.codex/RTK.md`, both assigned worker reports, the three UI files, the new localization family/registration/accessor/resources/probe, and both worker-authored test files. Applied the `write-swift` skill's source-review guidance to state and callback ownership. The localization worker's reported required-key integration dependency was checked against the current existing coverage test.

The established architecture is SwiftPM/AppKit with retained native settings views and a separate `LauncherLocalization` snapshot module. Appearance and grid persistence remain separate owner contracts. Per the supplied handoff, Main now binds dismissal to flushing rather than rollback and binds live change admission automatically. This review does not re-review or certify Main's live coordinator, Quit, backdrop, capacity-writer internals, or their runtime behavior; those remain outside this slice/with Carver.

## Findings

### UI-1 — P2: Non-mouse edits have no interaction-end flush signal

**Affected scope / evidence:** `Sources/PagingPrototypeApp/AppearanceSettingsView.swift:12–21, 74–86, 206–210, 272–285`. `LiveAppearanceSlider` exposes completion only through `mouseDown(with:)` returning. The checkbox and all slider actions share `controlChanged`, which collects/submits the value without calling `onFlush`. There is no keyboard completion override or equivalent non-mouse completion route in the view. Other explicit calls to `onFlush` are retry fallback and Defaults (`216–217`, `236–246`), plus the controller's dismissal seam supplied by the owner. This misses the approved contract's interaction-end flush for keyboard/accessible edits and for a completed checkbox action.

**Concrete source trace:** Install independent `onChange` and `onFlush` callbacks; deliver the checkbox's native action, or a slider value action through keyboard/accessibility rather than `mouseDown`. The newest valid value is admitted and numeric feedback updates, but this view sends no completion/flush callback. With the permitted owner debounce, persistence can therefore remain pending until inactivity or another boundary, although that particular edit has ended. This is a missing flush signal, not evidence that live preview is absent, that the debounce never saves, or that dismissal/Quit loses data. The owner could separately compensate; that compensation is not established by this bounded UI review.

**Likely root cause:** The continuous mouse tracking completion seam was treated as the universal interaction-end seam, while discrete and non-mouse inputs reuse the action handler without a completion distinction.

**Recommended solution:** Keep continuous mouse tracking coalesced, and provide an explicit completion path for completed discrete actions and supported keyboard/accessibility slider interactions. Forward the newest accepted edit to the existing owner flush callback. Keep load/relabel/resize silent and avoid flushing every action of a continuous mouse drag. No store/coordinator redesign is required by this recommendation.

**Regression checks for Main:** Verify checkbox completion and keyboard slider completion flush the newest admitted value; verify repeated keyboard changes preserve ordering; retain mouse-drag coalescing/final flush and silent programmatic synchronization. Cover accessibility action completion with the appropriate seam and retain a native gate for actual platform delivery. `Tests/PagingUITests/LiveAppearanceSettingsViewTests.swift:70–87` manually calls `trackingDidEnd`; it cannot catch the missing non-mouse route. The checkbox coverage at `38–67` asserts admission but does not assert completion flushing.

**Regression risks:** An indiscriminate action-handler flush would defeat continuous-drag coalescing; keyboard repeats must not create redundant writes or monitors with unrelated ownership.

**Confidence:** High that the source lacks the completion route; medium-high on the resulting integration gap because core owner implementation/runtime was intentionally excluded. No measured latency or durability claim.

### UI-2 — P2: Failed corrupt recovery tells users to choose a button that is not present

**Affected scope / evidence:** `Sources/PagingPrototypeApp/AppearanceSettingsView.swift:193–202, 220–233, 310–319, 347–350`; `Sources/PagingPrototypeApp/MainGridCapacitySettingsView.swift:221–224, 369–375, 396–404`; `Sources/LauncherLocalization/LiveAppearanceTextKey.swift:28–30`; all three `Localizable.strings:342–344`.

**Concrete source trace, Appearance:** Reload a corrupt payload, then explicitly choose Recover Settings. If `onApply` returns `.encodingFailed` (or `.invalidPreferences`), the view keeps `requiresRecovery = true` and renders `.failed`. The status selects generic `.saveFailed`, whose English text says “Choose Retry Saving to try again,” while the only visible action remains `.recover` (“Recover Settings”). The original explicit-recovery explanation is no longer selected by Appearance's single status label. The same mismatch is present in Chinese (`重试保存` versus `恢复损坏的设置`) and Japanese (`保存を再試行` versus `破損した設定を復旧`).

**Concrete source trace, Grid:** A corrupt recovery admitted by `onApply`, followed by `updateStatus(pendingCount: 0, saveResult: .failed, ...)`, retains `requiresExplicitRecovery`. The failure receipt maps to the same generic `.saveFailed` copy, while `updateWriteAvailability` titles the available action `.recover`. Grid retains a separate recovery warning as well, so users can receive contradictory action instructions on the same section. This is a feedback/adoption issue; the explicit storage-recovery authorization remains intact in the inspected UI code.

**Likely root cause:** Failure copy assumes every failure is a healthy save retry. Recovery and retry buttons are correctly distinguished by state, but failure text is selected without that distinction. Localization unit tests validate the generic strings in isolation, not the failed-recovery UI state.

**Recommended solution:** Render recovery-aware failure feedback that names the actual Recover Settings action and preserves the explicit replacement explanation, or combine neutral failure copy with the existing recovery explanation. Keep ordinary failures pointing to Retry Saving. Preserve the explicit recovery-only callback boundary and future/unrecognized payload protections; do not solve this by silently authorizing recovery through ordinary live edits.

**Regression checks for Main:** For each language, cover corrupt Appearance recovery returning failure and corrupt Grid recovery receiving a failed receipt. Assert the displayed instruction names the visible action, the candidate is retained, automatic edits do not authorize repair, and successful explicit recovery clears the recovery state. Existing UI coverage includes successful Appearance recovery (`193–215`) and a failed Grid recovery (`291–316`), but the latter checks enabled controls/retryability rather than its failure instruction. `Tests/LauncherLocalizationTests/LiveAppearanceLocalizedStringsTests.swift:63–108` checks retry/recovery strings separately and therefore misses this adoption mismatch.

**Regression risks:** Removing the recovery warning, conflating normal retry with destructive replacement consent, or altering protected-format behavior would weaken the approved fail-closed contract.

**Confidence:** High; both failure-to-copy paths and all three translations are visible in the reviewed source. Not reproduced by executing tests or the app.

## Other source observations

- **Six-tab integration:** `ActivationSettingsWindowController.swift:208–229, 275–294, 589–617` retains the same grid view, embeds it under Appearance, routes combined Defaults to that instance with a weak capture, relabels it in place, and creates exactly activation/appearance/management/sources/language/library. No independent Grid tab is constructed in this path.
- **Admission versus receipt:** Appearance publishes pending before its Bool callback and preserves synchronous owner status using a revision check (`272–285`). Grid does likewise (`263–293`). Appearance presentation refresh only renders (`304–308`); it does not manufacture save success. Healthy stale-receipt filtering remains an explicit owner responsibility; this review makes no assertion about Carver's/core coverage.
- **Recovery/protection:** Ordinary corrupt control changes and Defaults retain a candidate without invoking repair. Grid's recovery flag is scoped to the explicit synchronous callback and reset with `defer` (`281–284`); accepted corrupt recovery disables candidate editing until its receipt (`380–381`). Protected/unavailable grid loads are latched until reload (`184–188`). Appearance protects future payloads until reload. No UI-level silent recovery bypass was identified in the inspected paths.
- **Scoped Defaults and dismissal:** Appearance attempts its own healthy domain, separately calls Grid Defaults, and flushes (`236–246`); protected Appearance does not prevent the other domain's request. Both retained dismissal hooks are still called by `hideSettings` (`329–337`), and `windowShouldClose` uses that same path (`363–367`). The handoff says Main now uses these for flushing; no rollback claim is made here.
- **Layout and accessibility structure:** Appearance has one vertical `NSScrollView` with a flipped document and width bound to the clip view (`115–139`). Embedded Grid uses edge-pinned natural content rather than a second scroll view (`108–145`), hides its Defaults button, and collapses its unused button row (`369–377`). Help/status labels have wrapping construction and explicit content-width constraints; labels/status/accessibility values are refreshed during relabel/render. These are structural observations only. Constraint solving, reachability of the final controls at small sizes, three-language button/tab fit, keyboard focus visibility while scrolling, actual mouse tracking and spoken VoiceOver remain unverified native gates. No visual PASS is inferred.
- **Localization resources/probe:** All 13 new typed cases are included in `ResourceKey.all`, the name switch and empty placeholder signature (`LocalizationResources.swift:94, 120, 136, 152`); the accessor renders from an existing snapshot (`LocalizedStrings.swift:83–86`). The three resource tables include the new family at `338–350`. The packaged probe iterates it (`main.swift:45–48`) after strict raw-resource validation. No additional missing translation, obsolete Apply/discard instruction in the new family, or new-family placeholder discrepancy was identified by source reading.
- **Worker report correction, already integrated:** The localization worker warned that `LocalizationResourceValidationTests.swift` omitted the new family. Current source includes it in both key construction and count (`53, 58`), so that historical dependency is not an additional finding. This is source evidence, not a test PASS.
- **Authored tests:** Read all 499 lines of `LiveAppearanceSettingsViewTests.swift` and all 166 lines of `LiveAppearanceLocalizedStringsTests.swift`. Their assertions cover much of the intended UI state/resource contract, including several protective paths, but neither file was executed in this review. Their completion-seam/resource assertions do not substitute for interaction completion and failed-recovery adoption coverage identified above.

## Delivery and remaining gate

Return these two bounded findings to Main for disposition/repair within the approved specification. Recommendations are not implementation or architecture authorization. Main retains focused/full tests, build/package/probe verification, native UI and human physical acceptance; Carver retains the excluded core review. This FAIL is confined to the reviewed UI/localization source slice and is not a verdict on r2 execution results.

## Preserved source snapshot — SHA-256

Paths below are relative to `/Users/mac/Projects/Launch_Copy/PagingPrototype`, except the explicit RTK path. Hashes capture this review's file contents, not Git cleanliness or the diagnostic binary. No reviewed implementation/test/resource file was written by this reviewer. All 19 listed hashes were recaptured after writing the report and matched the captured inputs. Recheck before consuming the verdict if any listed input changes.

```text
6928c4ebd8edcabc637e028d24790450a052b739117f0b0ef9f6ad6b45b7bcfc  AGENTS.md
49c368c302c6f63d089f4c1085b242fc50fe22ce5bc34dada6478083000e7c6f  /Users/mac/.codex/RTK.md
674f0571fc6d00b06056186f34105302d622896dc3877fc63cfb8dd63a82a0ab  Docs/LIVE_APPEARANCE_AND_GRID_SPEC.md
60a0c97ad5578b8043500a5a215cbcf9e8d795ab5ce3e134f4e096e324b5514f  Workflow/results/LIVE_APPEARANCE_GRID_UI_WORKER.md
45e9910606d3567395f19c3630906b0dcce6dcfe4bc54cbf3470bb099e99969d  Workflow/results/LIVE_APPEARANCE_GRID_LOCALIZATION_WORKER.md
97851d299b56379abffcfac1f35f4e3e6dd31ee881a2372a0bee27cdc2276a1a  Sources/PagingPrototypeApp/AppearanceSettingsView.swift
3b153a0b775a1796aeca8e42e362261112bfd2beb849bb1ab8ee3e2139672292  Sources/PagingPrototypeApp/MainGridCapacitySettingsView.swift
f92fb825458941236e8f62b43478c8aa1a9effee8b00b507c40759db37d265ea  Sources/PagingPrototypeApp/ActivationSettingsWindowController.swift
bc7eb3364ecc56ddfa89c248822bf3c568445a837fa6c5210c8250e71b8e6ea8  Sources/LauncherLocalization/LiveAppearanceTextKey.swift
5f0694995579f9c01abec475633c06c6f3816da1dd86fb6c38bc1d643dc970c1  Sources/LauncherLocalization/MainGridCapacityTextKey.swift
ded196f46885733a522acfe549c94b5ab6f737e4bb85cf8420f09612ac65c7a1  Sources/LauncherLocalization/LocalizationResources.swift
3834e3c6b2ef96be75903baca8bffe79af8b67cf5be6810cc04eaa719e3c4b47  Sources/LauncherLocalization/LocalizedStrings.swift
5d17eb05f6c4560367ca3ce1989deba0c6ca9a54bb1b34a91b380cf3d895a22b  Sources/LauncherLocalization/Resources/en.lproj/Localizable.strings
920f30250401d7a8fafdd3a32e8c8b3c397bd2a2336edb5e8a97aff85cb40e58  Sources/LauncherLocalization/Resources/zh-Hans.lproj/Localizable.strings
1a0e6a40039791217cc5fa020a407b5569a6409aa6dcdbb009633854d245ab47  Sources/LauncherLocalization/Resources/ja.lproj/Localizable.strings
d085650fb11a4abf848e122a036b4c9f601888b2d1d3ed72dbfc7c0c4bbb8a39  Sources/LocalizationResourceProbe/main.swift
1b5679ce00e01255d1250d5fe795b5188526b478a99e6754f3d827050677af06  Tests/PagingUITests/LiveAppearanceSettingsViewTests.swift
52538bf444dd7b75142aa940cd3d08d042ffe2ef7b85d1c705d2e47da25caec9  Tests/LauncherLocalizationTests/LiveAppearanceLocalizedStringsTests.swift
cec88fab158bfabace47857f3c283e331ceb4cab318e2c40ed77ddd23890492d  Tests/LauncherLocalizationTests/LocalizationResourceValidationTests.swift
```

---

## R2 — Bounded Repair Review, 2026-10-17

**Current verdict: PASS — source-only for the UI/localization repair slice. UI-1 and UI-2 are resolved in the R2 source snapshot. No additional blocking source finding.** The R1 FAIL and its original hashes above remain historical evidence; this appended verdict supersedes that verdict only for the repaired slice.

### Scope, concurrency and evidence

The human requested this R2 append. Only this report was edited. No app/probe/test/build execution, UI, process, Git, reference-source, OS, formal-data, implementation or test mutation was performed. Main owns focused-r4 execution and later native acceptance. Carver's R2 source PASS/closure is supplied handoff context, not independently recertified here; core internals remain excluded. The active test-adaptation worker owns four disjoint existing tests; no whole-tree freeze or completion claim is made. No additional agents were dispatched.

Read Main's original `.build/verification/20261017/live-appearance-grid/ui-review-red-r1.log`. It records three named XCTest methods and **10 assertion failures, 0 unexpected**: four flush assertions, three Appearance recovery-instruction assertions, and three Grid recovery-instruction assertions, at 22:13:51–22:13:52. This corroborates R1 using Main-produced execution evidence. The trailing separate Swift Testing discovery with zero tests is not a passing replacement for that XCTest RED. This reviewer did not reproduce or rerun it and does not infer a post-repair GREEN or a focused-r4 outcome.

### UI-1 disposition — resolved in source

`AppearanceSettingsView.swift:12–23` adds private-set `isTrackingMouse`, set true only within enabled native `mouseDown`, with `defer` resetting it to false before the final `trackingDidEnd`. `controlChanged` at `208–218` validates/collects, retains the explicit-corrupt-recovery guard, submits first, then flushes for the checkbox or a `LiveAppearanceSlider` whose mouse tracking is inactive. Real slider target/action supplies the control as sender. Continuous mouse actions therefore remain coalesced until the final tracking callback; non-mouse control actions reach the completion callback immediately after submission. A nil synthetic batch action deliberately remains debounced.

The repair keeps admission/status rendering separate from flushing and does not invoke the explicit repair callback from live controls. Equal values still skip admission through `lastSubmitted`; a completion callback may nevertheless drain previously accepted work. Invalid values and already protected/unavailable states return before reaching the new completion path. If admission synchronously rejects or changes owner status, the existing revision/status contract is retained; the subsequent flush is an owner drainage request, not an assertion that the rejected candidate was saved.

`LiveAppearanceSettingsViewTests.swift:499–512` adds the checkbox `performClick` and non-mouse slider-sender regression, asserting the flushed sequence equals admitted values. The existing completion test now uses a nil synthetic update before the manual final hook (`70–87`), avoiding a double flush that would misclassify a completed non-mouse action as a mouse drag. Caption-before-admission and target/action wiring coverage remains at `39–67`.

**Confidence:** High for the bounded source repair. Native keyboard/AX event delivery, repeated input and actual suppression throughout mouse tracking remain Main's native/execution evidence boundary. The new slider regression directly calls `controlChanged(view.iconSlider)`; it does not itself synthesize a keyboard/AX event or exercise the native tracking loop.

### UI-2 disposition — resolved in source

`AppearanceSettingsView.swift:325` selects `.recoveryFailed` when a failed save still requires explicit recovery; ordinary failure continues to select `.saveFailed`. Its action remains the corresponding Recover/Retry title (`356–359`). Grid applies the same state-aware choice while rendering its failure receipt (`MainGridCapacitySettingsView.swift:403`) and retains the explicit-recovery button selection (`373–375`). Neither repair clears corruption protection or widens the callback-scoped recovery authorization.

`LiveAppearanceTextKey` now declares a fourteenth static case, `recoveryFailed`, with an English fallback matching the English resource. The new line `351` in each shipped resource names its actual `.recover` title: “Recover Settings”, “恢复损坏的设置”, or “破損した設定を復旧”. Ordinary `.saveFailed` still names `.retry` in all three languages. The new copy retains the selection and invites explicit recovery; it makes no save-success or automatic-repair claim. Grid also retains its separate explicit-replacement warning.

The key family is registered through `allCases` with the existing static placeholder signature; the snapshot accessor, strict resource census and packaged probe consequently include case 14 without a separate hand-maintained list. `LiveAppearanceLocalizedStringsTests.swift:6–28` now expects 14 keys; its omission/fallback, placeholder and snapshot loops include the new case automatically. Current `LocalizationResourceValidationTests.swift:53, 58` also uses `allCases`. New UI tests at `514–535` cover both domains' failed recovery and instruction-to-visible-button agreement across all three languages. Existing success/protection/recovery-authorization tests remain present.

**Confidence:** High for source and three-language adoption. No resource parsing, packaging, XCTest GREEN or native rendering was performed/certified here.

### Remaining nonblocking coverage limits and regression risks

- The mouse-completion test manually invokes its completion seam and does not prove that no intermediate native mouse action flushes. Preserve the later native gate for continuous dragging, final release, keyboard and accessibility delivery. A targeted assertion that nil synthetic updates have not flushed before the manual completion would strengthen the source tests.
- The new failure-copy tests check the instruction contains the visible title. Stronger assertions could check `.recoveryFailed` exactly, candidate retention and accessibility value after relabel; ordinary failure's Retry instruction in each language can also be asserted at the UI layer. Existing resource tests and the inspected branches support the current repair; these are coverage improvements, not another demonstrated defect.
- Keep synthetic programmatic synchronization silent, preserve continuous-drag coalescing and retain explicit corruption/future-format protections when extending event handling. These remain the material regression risks from R1; no repair-induced bypass or new blocking UI/localization defect was found in this slice.

The controller file's hash still matches R1, so the previously reviewed six-tab composition/embedded scroll structure has not changed in this snapshot. This is not visual acceptance. Main retains focused/full execution, packaged localization verification, native layout/scroll/focus/accessibility inspection and human physical acceptance. The separate active worker's four test adaptations are outside this PASS.

### R2 snapshot and R1 preservation

Before appending R2, the entire R1 report was 15,926 bytes with SHA-256 `e79a4f2724f7e8f35008c7bc246db89b28c76ce4bb311e5b3fe4606ba8d4d5e1`. After appending, hashing the first 15,926 bytes returned that same value, verifying R1 is retained byte-for-byte as the original report prefix. The three UI files, typed key, three resource tables and both worker-authored test files were also rehashed after the append and matched the R2 manifest below.

The UI test input changed during the initial R2 read from `5bb2397016864738d245ff90c62758f272897d42d6ea8a7e7687c50c0ea562cb` to the hash below. It was reread in full and recaptured at the later hash before the verdict; the earlier test snapshot is superseded for R2. This is an explicit refreshed review input, not a claim that the entire tree is frozen. The implementation/resource inputs below matched across the bounded review captures. Paths are repository-relative.

```text
674f0571fc6d00b06056186f34105302d622896dc3877fc63cfb8dd63a82a0ab  Docs/LIVE_APPEARANCE_AND_GRID_SPEC.md
60a0c97ad5578b8043500a5a215cbcf9e8d795ab5ce3e134f4e096e324b5514f  Workflow/results/LIVE_APPEARANCE_GRID_UI_WORKER.md
45e9910606d3567395f19c3630906b0dcce6dcfe4bc54cbf3470bb099e99969d  Workflow/results/LIVE_APPEARANCE_GRID_LOCALIZATION_WORKER.md
598f1eed132e6a8b5ec77280a9e94fabcf43128725e969a2fbd07996d94f8b26  Sources/PagingPrototypeApp/AppearanceSettingsView.swift
cd3a8758ebdc9a6b8c973b515b11c3c3fe0c31c9ba99fe128ac62a93a8da3dfe  Sources/PagingPrototypeApp/MainGridCapacitySettingsView.swift
f92fb825458941236e8f62b43478c8aa1a9effee8b00b507c40759db37d265ea  Sources/PagingPrototypeApp/ActivationSettingsWindowController.swift
c4253d03fe2e82ef33621380c2e1a1d532cf3109ca28840dac4bd480e7d3963d  Sources/LauncherLocalization/LiveAppearanceTextKey.swift
ded196f46885733a522acfe549c94b5ab6f737e4bb85cf8420f09612ac65c7a1  Sources/LauncherLocalization/LocalizationResources.swift
3834e3c6b2ef96be75903baca8bffe79af8b67cf5be6810cc04eaa719e3c4b47  Sources/LauncherLocalization/LocalizedStrings.swift
a6bf8f33afc424711b7f63eb23d8ea9e7978790e26e35f00f20f9539f25f0d27  Sources/LauncherLocalization/Resources/en.lproj/Localizable.strings
626ebe81b2215310969fa22e16e4d418eec927ef2dbcf27db5be906feebf2700  Sources/LauncherLocalization/Resources/zh-Hans.lproj/Localizable.strings
88ab97406b4aa9cf21b6e62a16e1a227b1fbd24dbd9e9ed36894b8a14ea923ae  Sources/LauncherLocalization/Resources/ja.lproj/Localizable.strings
d085650fb11a4abf848e122a036b4c9f601888b2d1d3ed72dbfc7c0c4bbb8a39  Sources/LocalizationResourceProbe/main.swift
23ab012f4edf615981835e3e4290bf87e9d5689db691d0c0a77026690b684fe6  Tests/PagingUITests/LiveAppearanceSettingsViewTests.swift
d321feeed1b905f3d1ac53e653195167bbeb6d236b18062bce361ccf8fb02a04  Tests/LauncherLocalizationTests/LiveAppearanceLocalizedStringsTests.swift
cec88fab158bfabace47857f3c283e331ceb4cab318e2c40ed77ddd23890492d  Tests/LauncherLocalizationTests/LocalizationResourceValidationTests.swift
2d257687d129cb4892ce2e88e275784f41cac48183dfb3f909b35a35911be62d  .build/verification/20261017/live-appearance-grid/ui-review-red-r1.log
```
