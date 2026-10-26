# Appearance Explicit Apply Maintenance — Independent Source Review

Date: 2026-10-13. Evidence cutoff: 2026-10-13T13:51:08Z.

**Disposition: PASS for the bounded source repair and reviewed regression coverage. No actionable defect found.** Initial conditional P2 F1 is resolved in the reviewed source. This verdict does not certify a packaged candidate, GUI/restart acceptance, or physical performance.

## Authority and scope

Reviewed the existing explicit Apply contract using `Workflow/stage-summaries/2026-10-13-appearance-apply-maintenance.md` and initial F1 in `Workflow/results/APPEARANCE_EXTENSION_CONTRACT_REVIEW.md`. The latter's proposed schema 2/icon/type/capacity sections confer no implementation authority and are outside this verdict.

The project is a macOS 14 Swift Package with AppKit views. Appearance values, persistence and the main-actor coordinator reside in the application target; the settings view stages a draft and calls the coordinator only through explicit Apply. This review covers `AppearancePreferences.swift`, its test file, and the native settings view needed to interpret test assertions. `Package.swift` and project instructions supplied architecture and scope context.

Only this report was written. No source/test changes, Swift invocation, test execution, build, application launch, preference access, process control, workflow routing/state edits, or cleanup were performed. The preexisting dirty tree was preserved. LaunchBetter/Buho/reverse assets and production preferences were not opened. Main remains the sole Swift executor.

## Findings and source assessment

No blocking or actionable source finding remains within the assigned maintenance scope. Confidence is high for the inspected control flow and native test coverage; runtime evidence below comes from Main's logs, not reviewer execution.

| Contract | Assessment and evidence |
| --- | --- |
| Fresh equal-value no-op | `AppearancePreferences.swift:115–120` reads the store into local `persistedResult`. It skips saving only if the draft equals the committed value **and** the freshly loaded healthy preferences equal that draft. The successful no-op refreshes `loadResult` from the fresh observation. Cached initialization state no longer authorizes success for stale storage. |
| Explicit repair after corruption/removal/different healthy values | Fresh corruption fails the healthy match; absent storage loads defaults, so absent nondefault preferences fail the value match; different healthy preferences also fail the match. Each reaches save at line 122. Successful repair updates accepted state, and subsequent healthy equal Apply is a no-op. Absent storage with an equal default draft may still be a no-op, preserving the existing contract. |
| Future data at load and before save | Coordinator line 116 refuses a fresh future result before no-op/save. Store lines 64–69 decode the version header before the body and retain schema 1's future cutoff. Store line 74 independently rechecks before writing. The real `beforeSave` test inserts future bytes between coordinator observation and real store save and asserts their exact preservation. No atomic multi-process compare-and-write guarantee is introduced. |
| Failed saves and callback suppression | Lines 122–127 require `.saved` before mutating committed/load state or invoking the owner. An unchanged effective draft can repair persistence without an owner callback; changed drafts also remain staged on failure. Native view lines 90–98 display success or error according to the returned save result. |
| No automatic repair | Initialization only loads at lines 104–109. Store load contains no write. View reload synchronizes controls/status only. Repairs remain on explicit Apply, not load/reopen/control changes. |
| Schema/default/regression preservation | The value still has only `showsAppLabels` and integral `wallpaperBlurRadius`, defaults true/18, blur range 0–60. Store writes schema 1 and retains nonmutating corrupt fallback, future protection and whole-payload validation. No icon/type/capacity fields or migration were introduced in the inspected code. Package, settings view and cell source hashes match their initial-review identities; unchanged cell identity is hash evidence, not a new geometry audit. |

The source change is localized to the fresh observation and matching no-op/load-result refresh at coordinator lines 115–121; the save/commit/callback path remains the existing contract. Main's `source-delta.txt` records exactly the two owned files changed since the prior 334-file snapshot. That whole-tree comparison is Main's evidence; this reviewer independently checked the scoped manifest entries and hashes, not all 334 file bodies.

## Native test assessment

`RealStoreProbe` at test lines 23–42 counts save attempts and delegates ordinary load/save to the actual `UserDefaultsAppearancePreferencesStore`. Its failure seam deliberately models `.encodingFailed`; this is not proof of an actual OS persistence failure. Its `beforeSave` seam reaches the real future-version recheck. The helper at lines 44–49 wires an actual `AppearanceSettingsView` to the coordinator, and tests invoke its native Apply button. Suites are unique `fixture.appearance.<UUID>` instances, not the production suite.

| Added test, source lines | Material assertions |
| --- | --- |
| Late corruption, 143–170 | Fresh real store is corrupt before Apply; reload leaves bytes and save count untouched; Apply repairs to the draft, refreshes accepted state, shows success, emits zero owner callbacks, and repeated Apply does not save again. |
| Removed nondefault payload, 172–197 | Reload does not recreate the missing key; Apply saves, a fresh real store and coordinator recover the original nondefault preferences, and owner callback count stays zero. |
| Different healthy payload, 199–220 | Reload preserves external values; explicit unchanged Apply restores the intended committed draft, fresh real load matches it, and no runtime callback occurs. |
| Late future including save recheck, 222–253 | Fresh future data refuses before any save attempt; future bytes injected after coordinator load are refused by real save, remain byte-for-byte equal, show error, and leave committed values/callback count unchanged. |
| Failed repair, 255–284 | Equal repair attempts a save and surfaces failure; bytes, committed state and draft remain correct with error status and zero callbacks. A subsequent changed draft remains staged on another failure. |
| Matching schema 1 bytes, 286–305 | Differently formatted valid schema 1 bytes remain exactly unchanged across two Applies, zero saves/callbacks, fresh real load equals the draft, and unrelated key remains untouched. |

No existing assertions were weakened: removing only added helper lines 23–50 and added six-test block lines 143–306 **in memory, without writing a file**, yields SHA-256 `45723d439e3bc88608a6afc364cc741ebd6629f602634043997236e1ad07af52`, exactly the initial F1 report's test-file identity. Existing default/boundary, corrupt/future, explicit repair, failed save, staging/reload, controls, label-only wallpaper, and settings geometry tests remain present.

These are meaningful native action/store tests but do not display or manually operate the shipped application. Their status assertions use native text color/visibility and actual reloaded data; they do not establish exact dialog wording, mounted owner rendering acceptance, process restart durability, VoiceOver, or physical input performance.

## Reviewed test/build evidence and limits

| Evidence | Observed result |
| --- | --- |
| `red.log` | Initial incomplete filter: 5 XCTest methods, 12 assertion failures at 22:45:00.756 JST. Preserved; excludes the failure-named sixth method. |
| `red-six.log` | Complete reproduction: 6 XCTest methods, 15 assertion failures at 22:45:27.388 JST. Five methods fail; the healthy no-op control passes. This is the complete red gate. Stage/handoff associates it with old source SHA-256 `198d9f3e604359ab6ccf6b0336485f061613481edb4877115eb32a9b5e1caeca`; the log itself does not embed that source hash. |
| `focused.log` | Completed at 22:47:47.119 JST: **45 XCTest tests, 0 failures**, including all six new native methods and 23 `AppearancePreferencesTests`. Neighbor suites cover labels, renderer labels, launcher material and wallpaper controller. The log records compiling `AppearancePreferences.swift` and successful debug test build completion. |
| `full.log` | Completed at 22:49:46.052 JST: **2100 XCTest tests, 0 failures**. Reported 78.036 seconds is test duration, not physical performance. Reviewer inspected the final summary; this is Main's full-suite execution evidence, not a full-suite source audit. |
| Debug/Release candidate builds | Main reports unique `appearance-apply-r1` builds running. No completed build/candidate/executable identity is reviewed here. The focused test build does not certify the separate packaged Debug/Release candidates. |
| GUI, restart, physical gates | Unreviewed/unexecuted by this reviewer. Fresh objects loading UserDefaults in one process are not process restart or disk durability evidence. Candidate/GUI acceptance remains with Main under the recorded live-entry boundary. |

The trailing Swift Testing message reporting zero tests does not replace the nonzero XCTest summaries. Logs do not independently expose shell exit status; Main retains process-exit evidence. Future payload preservation is bounded to the store's observations/recheck, and `.saved` means accepted UserDefaults set, not synchronous durable disk confirmation.

## Reviewed identities and final integrity gate

The following live SHA-256 identities matched Main's scoped `source-files.sha256` entries and remained stable on the final pre-write read at 13:51:08Z:

```text
489ab91038736a6202a510e9ed4502fe3613e72435530a0e89612e927641f61b  Sources/PagingPrototypeApp/AppearancePreferences.swift
315b3729c4c324cfa995750021ce4da39521e112df84b0d0953d578bbf73cd6e  Tests/PagingUITests/AppearancePreferencesTests.swift
e51d7be699bcc63e81c5c3de8faccb1f0f6636b81d1f633addb5b1366aa8d8ab  Sources/PagingPrototypeApp/AppearanceSettingsView.swift
c214f04f42748e21bcf2a6143f367685e117c39984afca24a96aea6afe51f693  Package.swift
52b7fa063c66fa397f7c1b74af73b921aa3f38c6f9335dec88d284537e439874  Sources/AppGridUI/AppGridCellView.swift
69964f875d2407285d9ac62063ced365b6536ab7a166cc9c2f69ac8cc9891205  .build/verification/20261013/appearance-apply-maintenance/red.log
f33cd293a7f292086e7839571ed3bfc3d54a873cc325b8713ed4bc436aa5ef52  .build/verification/20261013/appearance-apply-maintenance/red-six.log
83247d0d3db617636a83ba3dbcfb25bc18425a5604041446c904b69390ad0719  .build/verification/20261013/appearance-apply-maintenance/focused.log
ac5d59b2bcdcdb11af7b9ee20afc77753dc812ff8eb2079532f3bb16226adc25  .build/verification/20261013/appearance-apply-maintenance/full.log
```

Main may continue candidate builds and integration without a maintenance source repair request from this review. Any subsequent change to the two reviewed source/test identities requires revalidation; build, GUI/restart and physical gates cannot be closed by this source PASS.
