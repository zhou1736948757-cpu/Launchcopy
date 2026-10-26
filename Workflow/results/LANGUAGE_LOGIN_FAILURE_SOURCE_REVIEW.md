# L1 Login Failure — Independent Bounded Source Review

Date: 2026-10-14. Project: `/Users/mac/Projects/Launch_Copy/PagingPrototype`.

**Verdict: no blocking source defect found in the inspected L1 repair.** The typed failure route closes the previously identified application-authored English leakage at source level. One focused coverage follow-up remains below. This is not executed-test, build, packaging, GUI, physical-service, performance, or whole-language/parity acceptance.

## Authority and evidence boundary

Reviewed RTK, project `AGENTS.md`, approved `Docs/INTERFACE_LANGUAGE_SPEC.md`, and the L1 section of `Workflow/results/LANGUAGE_RESIDUAL_AND_PARITY_AUDIT.md`. The project is an AppKit macOS launcher with SwiftPM 5.9 and macOS 14 deployment (`Package.swift:1`, `:11`). The repair stays within the existing service / transaction / presentation / Foundation localization boundaries.

The assignment explicitly waives the old orchestration workflow and limits participants to Main, this reviewer, and ActionReviewer. This reviewer dispatched no additional roles and owns only this report. Main subsequently announced source freeze 391 and a running focused-r1 job; the review incorporates the current `TypedLoginFailureLanguageTests.swift` and exhaustive transaction rejection branch. That announcement is not independent test execution evidence. No job output was inspected or execution result inferred.

Only source/document reads and selected source fingerprints were collected. No build, test, app, native UI interaction, process inspection/control, reference-project access, global memory access, commit, or implementation/test-file write was performed. The report is the only file changed by this reviewer. RTK compliance limitation: the RTK bootstrap read and initial `pwd` / file-discovery `rg` preceded application of the prefix rule; subsequent shell commands used `rtk proxy`.

The Git baseline includes broader uncommitted language work. The Git diff is therefore not asserted to be an isolated L1-only patch. Review conclusions are limited to the named L1 routes and the current fingerprints below.

## Source findings

No blocking correctness or compatibility finding was identified.

| Contract | Inspected evidence and conclusion |
| --- | --- |
| Application-authored failures are semantic; legacy details stay literal | `Sources/PagingPrototypeApp/LaunchAtLoginService.swift:22`–`:24` retains `.failure(message:)` and adds `.operationFailed(enabling:)`. `ActivationSettingsCoordinator.swift:235`–`:239` concatenates legacy detail as literal data, while typed direction selects a localized reason. It performs no English-string matching or native-detail heuristic. |
| Tests share the actual production catch seam without registration | `LaunchAtLoginService.swift:122`–`:124` reads mapped status after an exception and calls `statusAfterFailedOperation`. The helper at `:147`–`:152` has no service calls, IO, error formatting, or logging. Tests invoke the same helper, rather than a duplicate catch simulation. This proves source connectivity, not actual OS exception behavior. |
| Truthful mapped outcomes remain preserved | Failed enable with mapped disabled becomes typed enable failure; failed disable with mapped enabled becomes typed disable failure (`LaunchAtLoginService.swift:149`–`:150`). Matching enabled/disabled states, requiresApproval, and unavailable remain unchanged. Compared with the prior catch diff, this preserves the existing mapped-state decisions for every status reachable from `mapStatus` (`:130`–`:142`). |
| Authored English no longer reaches presentation as native detail | The production catch no longer calls `neutralFailureMessage` or creates `.failure(message:)`. The old helper remains at `LaunchAtLoginService.swift:157` for compatibility tests; the inspected application source has no caller. Its remaining English strings are not evidence of a continuing production L1 leak. |
| Existing transaction acceptance and rollback remain intact | `Sources/PagingPrototypeApp/ActivationApplyTransaction.swift:153`–`:159` adds `.operationFailed` only to the existing unconditional rejection group. Only enabled-for-enable and disabled-for-disable are accepted. The bounded diff leaves execution, rollback, persistence, and refusal handling unchanged (`:83`–`:123`, `:139`–`:145`). In particular, the pre-existing best-effort cleanup after failed enable is retained. |
| Both localized and compatibility renderers handle the new case | `ActivationSettingsCoordinator.swift:228`–`:239` covers the new case in the localized renderer. `Sources/PagingPrototypeApp/ActivationSettingsWindowController.swift:67`–`:74` covers it in the legacy renderer and retains literal interpolation for `.failure(message:)`. The nil renderer continues its established Chinese compatibility behavior. |
| Two keys are available in all three supported resources | `Sources/LauncherLocalization/ActivationStatusTextKey.swift:26`–`:32` defines both typed keys and safe English fallbacks. All three `Resources/{en,zh-Hans,ja}.lproj/Localizable.strings` tables contain both entries at `:241`–`:242`, with independently authored direction-specific text and no dynamic placeholders. |
| Resource schema discovers the added keys | `Sources/LauncherLocalization/LocalizationResources.swift:109` enumerates `ActivationStatusTextKey.allCases`; static activation status keys have no placeholder parameters at `:143`. `LocalizedStrings.swift:50`–`:51` uses the typed renderer/fallback. No separate manual key-list omission was found for these additions. |
| Apply warnings and retained settings use the same renderer | `ActivationSettingsCoordinator.swift:86`–`:88` installs the service-backed current-snapshot label provider. The actual login-not-accepted warning composes `loginStatus` with localized title/partial explanation at `:172`–`:177`. Retained relabel calls `refreshSideStatusLabels` at `ActivationSettingsWindowController.swift:694`; that updates both text and accessibility value at `:658`–`:663`. |
| Privacy and persisted contracts | The new operation state carries only a Bool. The catch does not expose NSError descriptions, paths, or userInfo. No logging was added to the inspected repair. The bounded service/transaction changes introduce no preference/schema changes. This is a source conclusion about L1, not a global privacy audit. |

## Test source assessment and concrete coverage follow-up

`Tests/PagingUITests/TypedLoginFailureLanguageTests.swift` contains three test methods. None was executed by this reviewer.

- `:8`–`:19` covers all eight direction × reachable-mapped-status combinations, a legacy failure helper input, and rejection of each typed direction for the corresponding request. It never constructs or mutates a real registration service.
- `:22`–`:33` checks both authored reasons and literal legacy detail in English, Simplified Chinese, and Japanese (`InterfaceLanguage.swift:3`–`:6`). Existing resource tests enumerate all activation status keys and compare against the actual language tables (`Tests/LauncherLocalizationTests/ActivationGridLocalizedStringsTests.swift:6`–`:14`), so the new presentation test is not the sole evidence for resource coverage.
- `:36`–`:57` uses the coordinator and an actual retained settings view with a fake typed enable failure. It relabels the mounted label across all three languages, checks draft equality, checks inactive recording, and verifies zero fake setEnabled calls. It does not establish preservation of already-active recording by itself; existing `ActivationLanguageConsumersTests.swift:183`–`:207` separately exercises active recording through relabel. It also does not test the typed disable failure in the mounted label or typed accessibility value directly; the shared renderer and existing label/AX consumer source checks support those routes, without replacing execution evidence.

**C1 — Non-blocking coverage follow-up: exercise typed failure through actual Apply and warning presentation.**

Location: `TypedLoginFailureLanguageTests.swift:15`–`:16`, `:36`–`:57`; existing `Tests/PagingUITests/ActivationApplyTransactionTests.swift:58`–`:83`; production warning at `ActivationSettingsCoordinator.swift:172`–`:177`.

The new test asserts the acceptance predicate and a label initialized with a failure. The existing rollback test injects only legacy `.failure(message:)`. Neither inspected test drives a typed enable/disable failure through `ActivationApplyTransaction.run` and the coordinator's real Apply callback into its warning. The L1 residual audit explicitly requested status/alert consumer coverage; the typed actual-alert portion remains untested in these sources. This is a coverage limitation, not evidence that the unchanged production branch is broken.

Recommended bounded follow-up: use only a fake service, force each typed direction, and exercise the real coordinator/controller Apply callback with the existing non-presenting alert seam. Assert `.loginNotAccepted`, unchanged login preference bit, preserved non-login accepted changes and saved accepted preferences, original typed direction in the outcome, the existing enable-cleanup/disable call pattern, and the selected-language warning title/reason/partial explanation. Keep real registration out of all test paths. No change to transaction semantics or native modal timing is recommended.

The synthetic `.operationFailed` input to the helper and opposite-direction predicate requests are not included in the new matrix; they are not reachable from production `mapStatus` and are not reported as production defects.

## Reviewed-input fingerprints

These SHA256 values identify the current inspected files after Main's source-freeze announcement; they are not a packaged candidate identity or a validation of the freeze number.

| File | SHA256 |
| --- | --- |
| `Sources/PagingPrototypeApp/LaunchAtLoginService.swift` | `ebc86a580420a75148c673e5d712c2362dce15368750c2b8fa6a5bd1c6953dd8` |
| `Sources/PagingPrototypeApp/ActivationApplyTransaction.swift` | `ae80c8895fc777a44923c8f737bd81569bc3c077ef29f00fba4ad6c95316a31e` |
| `Sources/PagingPrototypeApp/ActivationSettingsCoordinator.swift` | `61b70dbc81b83597498a43927cf9c12541b6c81b7211afbf216b65d934e45800` |
| `Sources/PagingPrototypeApp/ActivationSettingsWindowController.swift` | `9f6d8039b5e40b50119077f565368e984157e62d93d6f3d6381566a481a74dd9` |
| `Sources/LauncherLocalization/ActivationStatusTextKey.swift` | `e1ef1b16bfb08b37205dfaa5ce02f12398401708e1c220405764774f9df36400` |
| `Sources/LauncherLocalization/Resources/en.lproj/Localizable.strings` | `922d205a5080cc30cae0bc2806a46965ceeb3388dbffcc9692f8b8f9c4d33028` |
| `Sources/LauncherLocalization/Resources/zh-Hans.lproj/Localizable.strings` | `cf07dcbd2437da03159c5839024999535490d26e8a4bf6ccc0c5df4e0b248824` |
| `Sources/LauncherLocalization/Resources/ja.lproj/Localizable.strings` | `ccb028368140698809add12e96e6f5f3c32150de2ecef4152805d6cb1097dff8` |
| `Tests/PagingUITests/TypedLoginFailureLanguageTests.swift` | `f12984299c63f7216dbe3938b55178052a332e618edceb3b58e96fb7b1805c3b` |

Main owns execution-result assessment and any subsequent coverage work. This review closes only its assigned source inspection and report; it does not close L1 runtime acceptance or any broader delivery gate.

## Follow-up test-source review — 2026-10-14, focused-r3 announcement

This section appends a later observation and preserves the earlier C1 record and fingerprints. Main reported the new `testActualApplyTransactionPersistsOtherSettingsRollsBackLoginAndBuildsLocalizedFailureAlert` and a running focused-r3 job with 57 expected tests. No running job, test output, build, application, process, or sheet was inspected or executed by this reviewer. Expected counts and a running job are not passing-test evidence. Only this report was edited.

**Updated assessment: C1's missing actual Apply / warning route is now covered in test source, but the added test has a concrete incorrect call-count assertion requiring correction.** The original no-blocking-production-source-defect conclusion is unchanged. The new test cannot be accepted as correct test source at the observed revision.

### Confirmed new coverage

`Tests/PagingUITests/TypedLoginFailureLanguageTests.swift:59`–`:98` enumerates both operation directions for every supported language. It creates the real in-memory activation store and a fake login service, forces `.operationFailed(enabling:)`, and obtains the controller from the real coordinator (`:63`–`:71`). It loads a draft changing both the login preference and status-item preference (`:73`–`:75`), finds the actual Apply button by its action selector, and invokes `performClick` (`:80`–`:83`). It does not replace `onApply` or implement a parallel transaction.

That action reaches the existing controller callback (`ActivationSettingsWindowController.swift:358`–`:368`), coordinator `handleApply` (`ActivationSettingsCoordinator.swift:161`–`:177`), and transaction. The test asserts the old login preference is retained, the non-login change is accepted, and the memory-store read matches committed preferences (`TypedLoginFailureLanguageTests.swift:86`–`:89`). Because the original status-item preference defaults to true (`ActivationSettings.swift:38`), saving false verifies an actual accepted change rather than equality with untouched initial storage.

The test intercepts only the existing `alertPresenter` seam (`:76`–`:77`), receiving the actual NSAlert built by `presentAlert` (`ActivationSettingsWindowController.swift:905`–`:917`). It checks the localized title, direction-specific reason and partial-acceptance explanation, then invokes the captured completion (`TypedLoginFailureLanguageTests.swift:90`–`:95`). This is the real production warning construction route; it does not use the separate `makeAlert` helper or present a native sheet. The asserted fake service never uses real registration (`:85`); no real service is constructed by this new test.

### F1 — [P2] Enable-failure cleanup makes the fixed one-call expectation incorrect

**Location:** `Tests/PagingUITests/TypedLoginFailureLanguageTests.swift:84`.

**Finding and evidence:** The assertion always expects `service.setEnabledCallCount == 1`. For each `enabling == true` iteration, initial committed login is false (`:64`), the draft requests true (`:74`), and the first fake call returns the forced typed failure (`:67`). `ActivationApplyTransaction.swift:90` calls `setEnabled(true)`, then its existing failed-enable cleanup at `:95`–`:96` calls `setEnabled(false)`. Both increment the fake counter (`LaunchAtLoginService.swift:72`–`:79`); cleanup therefore makes the count **2**. For disable failure, the cleanup guard is false and the expected count remains **1**. By source inspection, this assertion disagrees with the preserved transaction for all three enable-language iterations. No executed failure is claimed.

**Likely root cause:** The assertion counts the attempted operation but omits the pre-existing best-effort cleanup. This is a test expectation defect, not a reason to change production rollback.

**Recommended solution:** Assert `enabling ? 2 : 1`. Also asserting `lastRequestedEnabled == false` and final fake status `.disabled` for failed enable / `.operationFailed(enabling: false)` for failed disable would document the existing cleanup distinction. Preserve the production transaction and its acceptance policy. The captured warning must continue describing the original attempted direction, even after enable cleanup changes current fake status.

**Affected scope and regression risk:** Only the newly added test expectation needs correction. Weakening the count assertion to a lower bound could hide missing cleanup; removing cleanup to satisfy the test would change the preserved transaction contract. The actual Apply/store/alert coverage remains useful.

**Confidence:** High; the counter increment and both service calls are explicit and synchronous in the inspected source.

### Follow-up fingerprints and remaining boundary

Observed test SHA256: `695da045b1e558409f36195320f44eace81b756d585b29a359b553ce867b624e`.

The transaction, coordinator, settings controller and login service hashes were re-read and match their earlier values in this report. The test file now contains four test methods; its earlier three-method count and earlier test fingerprint describe the prior observation only. No resource or whole-tree revalidation is implied.

C1's route-coverage limitation is superseded at source level by the new method. F1 requires Main's test correction; focused-r3 execution results and any subsequent revision remain Main's verification responsibility. No native registration, sheet behavior, persistence across process restart, GUI, or broader acceptance is certified.

## Fixture correction follow-up — 2026-10-14, focused-r4 announcement

Main reported that focused-r3 encountered fixture compilation errors from using activation preference fields directly, then corrected the accesses and started focused-r4. This is attributed to Main's report; this reviewer did not inspect execution logs or run compilation/tests.

The current source confirms `initial.settings.launchAtLoginEnabled` at `TypedLoginFailureLanguageTests.swift:64` and `coordinator.committed.settings.launchAtLoginEnabled` / `.showStatusItem` at `:86`–`:87`. These agree with `ActivationPreferences.settings` (`Sources/PagingPrototypeApp/ActivationPreferences.swift:34`). The direct draft accesses at test `:74` remain valid because `ActivationPreferencesDraft` declares those facade fields (`Sources/PagingPrototypeApp/ActivationApplyPlan.swift:19`, `:25`–`:26`). This establishes the specific field-access correction by source inspection, not successful compilation.

Correction to the earlier review's precision: the focused-r3 follow-up described the intended Apply/store/alert path but failed to flag the invalid direct preference-field accesses in that revision. That earlier route assessment was source-only and did not establish an executable fixture. The original record is retained here rather than silently rewritten.

**F1 remains open at this observation.** Test `:84` still asserts exactly one fake setEnabled call for both directions. Correcting field accesses does not change the preserved failed-enable cleanup, which makes two calls for enabling and one for disabling. No assertion was removed; the existing count assertion still needs the direction-aware expectation `enabling ? 2 : 1`. C1's source-route coverage remains present, and the no-blocking-production-source-defect conclusion remains unchanged.

Current test SHA256: `9f8bdbb53e6d3fbbdd803c1965567ee36a5d02819cb991b7a0e078a3e62ff255`. Re-read hashes for the transaction, coordinator, settings controller, and login service match the earlier report. Only this report was changed by this reviewer. No focused-r4 pass, real registration, sheet presentation, GUI, or broader acceptance is claimed.

## Final bounded test-source check — 2026-10-14, focused-r6 announcement

Main reported focused-r4 as 57 tests / 2 failures, attributed to the call-count expectation and clearing the singleton's contentView between iterations, and reported the earlier pure seam tests as passed. These are Main-reported results, not independently inspected execution evidence. This reviewer did not read test logs, inspect jobs/processes, or run tests, builds, applications, or sheet presentation. Main reported focused-r6 as running; no outcome is inferred.

### Singleton fixture correction confirmed at source level

`TypedLoginFailureLanguageTests.swift:61`–`:66` now retains controllers and defers destructive view/delegate cleanup until the whole method exits. Each iteration appends its controller (`:78`), completes its captured alert callback (`:102`), and only hides the controller (`:103`). The existing factory refreshes the current service providers, Apply callback, draft and language when reusing the retained singleton (`ActivationSettingsWindowController.swift:237`–`:245`). The contentView is therefore no longer cleared before a later iteration re-enters the factory. Multiple array references to the same reused controller do not clear its contentView during the iteration loop.

This addresses the reported re-entry fixture mechanism by inspection. The earlier review did not identify that lifecycle defect before Main's execution report; that omission is recorded here without changing the historical findings.

### F1 updated — [P2] Fixed two-call and old-value last-request assertions are wrong for disable failure

**Current location:** `Tests/PagingUITests/TypedLoginFailureLanguageTests.swift:90`–`:91`.

The fixed one-call assertion has been changed to a fixed two-call assertion, and a lastRequestedEnabled check against the initial preference has been added. This corrects the enable-failure expectation but does not fit the disable-failure branch. With `enabling == false`, initial committed login is true (`:70`), the requested fake operation is false, and the forced result is `.operationFailed(enabling: false)` (`:73`, `:80`). The transaction calls the fake once (`ActivationApplyTransaction.swift:90`); its additional cleanup is guarded by `enabled && !committed.settings.launchAtLoginEnabled` at `:95`–`:96`, which is false for disable failure. Saving the accepted old preference does not itself issue another login operation.

Consequently the current disable-language cases have call count **1**, and `lastRequestedEnabled` is **false**, whereas lines `:90`–`:91` expect **2** and **true**. Failed enable has count **2** and last requested **false**. These are source-derived expectations; no executed assertion failures are claimed.

**Recommended correction:** retain exact assertions with `XCTAssertEqual(service.setEnabledCallCount, enabling ? 2 : 1)` and `XCTAssertEqual(service.lastRequestedEnabled, false)`. Update the count assertion's explanation to identify cleanup as enable-only. Do not change production rollback to create a disable-side service call merely to satisfy the fixture.

**Root cause / affected scope / risk / confidence:** The test treats rollback of the persisted preference as a second service operation in both directions; the existing transaction only performs that operation for failed enable. The affected scope is the new fixture's expectations. Removing these assertions would weaken regression coverage, and changing production would violate the preserved transaction boundary. Confidence is high: the transaction guard and fake counter/last-request assignments are explicit and synchronous (`LaunchAtLoginService.swift:72`–`:79`).

### Coverage and final source verdict at this observation

The real Apply-button → coordinator → transaction → fake-service → accepted memory-store / actual warning-construction route remains present for both directions and all three languages (`TypedLoginFailureLanguageTests.swift:67`–`:102`). The corrected `.settings` accesses, exact committed/store equality, localized title, direction-specific reason, partial-acceptance explanation, fake-registration assertion and completion callback remain in place. No native register/unregister or sheet presentation is introduced. C1's source-route gap remains superseded.

**The fixture still requires the two expectation corrections above; no new production defect was identified.** The earlier production source verdict is unchanged. Production transaction, coordinator, settings controller and login-service hashes were re-read and still match the original report. Current test SHA256: `0fa9b91981d734ad60720ebf14b4f84de5bc730ea380dc5799769265df6bdd7d`.

Only this report was changed by this reviewer. This concludes the requested bounded source check of the observed revision; it is not focused-r6 execution acceptance, GUI/physical-service acceptance, or whole-project PASS.

## Final source clearance — 2026-10-14, focused-r7 announcement

**Bounded source verdict: C1's actual Apply / warning coverage is present; F1 and the identified fixture corrections are cleared in the current test source. No outstanding blocking finding remains within this assigned L1 source review.** All earlier observations are retained as chronology, superseded only where explicitly stated here.

Current `Tests/PagingUITests/TypedLoginFailureLanguageTests.swift:90`–`:92` asserts the exact direction-dependent count `enabling ? 2 : 1` and `lastRequestedEnabled == false`. These expectations agree with the preserved enable-only cleanup in `ActivationApplyTransaction.swift:95`–`:96`; neither assertion was removed or weakened. The `.settings` accesses remain correct (`:70`, `:94`–`:95`), and retained-controller cleanup remains outside the iteration loop (`:61`–`:66`, `:78`).

The new test still exercises the real native Apply button through the coordinator and transaction using only a fake service, both directions and all three supported languages (`:67`–`:89`). Exact committed/store equality, retained old login preference, accepted non-login change, no real registration, localized alert title, original direction-specific reason, partial-acceptance explanation and completion are still asserted (`:93`–`:103`). The existing presenter intercepts the actual warning construction without showing a sheet. C1 is therefore cleared at the requested source-coverage level, and F1 is corrected at source level.

Main reports that focused-r7 passed all four TypedLoginFailureLanguageTests, with one other failure attributed to an unrelated folder fixture. This reviewer did not inspect execution logs or verify that attribution. It is recorded as Main-reported evidence only; no focused-suite/full-suite pass is inferred and no folder-fixture review was undertaken.

Current test SHA256: `c2a053bea34723fa8e908e2eace0b8da40177bb6ac62ae4e69eba81ec2b5fd37`. Re-read hashes for the production login service, transaction, coordinator and settings controller still match the original report, confirming no file changes in those inspected production routes since the first review.

Only this report was edited. No builds, tests, apps, native registration, sheet presentation, process operations, global memory, reference projects, or commits were used. This completes the assigned bounded source/coverage review. Execution acceptance remains Main's responsibility; GUI, physical-service, packaging and whole-language/parity acceptance remain outside this verdict.
