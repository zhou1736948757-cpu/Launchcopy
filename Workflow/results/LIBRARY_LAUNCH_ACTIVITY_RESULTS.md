# Optional Library Recent/Frequent — Delivery Results

Date: 2026-10-18
Status: CODE/TEST/BUILD/PACKAGE AND BOUNDED SOURCE REVIEW PASSED; CONTROLLED NATIVE ACCEPTANCE PASSED.

## Contract and delivery scope
The human explicitly approved Docs/LIBRARY_LAUNCH_ACTIVITY_PROPOSAL.md. Library remains optional and defaultOFF; activity tracking is independently defaultOFF. Recent (up to12) and Frequent (up to8) are sections in the existing Library sidebar/compact picker and reuse its search/results/details/action pipeline, not new outer pages. Rank only validated Launchcopy-originated executor-accepted launch requests in the current and previous29 UTC days. This is not evidence of cold launch, process startup, actual use, foreground attention or duration.

No system-wide application observers, process/keyboard/search tracking, network/upload, new gestures, uninstall or alternate launch path. Domain is bounded to256identities×30daily buckets with saturated counts; bundle identities are canonical, path-only identities use a per-document salted hash. No raw paths/names go into activity payloads or telemetry. DefaultOFF/missing inspection creates no activity directory/file; formal data has not been opted in.

## Ownership and implementation
- `LaunchActivityDocument`/section/entry and protected `LaunchActivityFileStore`; existing descriptor-relative no-follow cooperative compare/lock/flush I/O reused in a separate directory. Existing Library/workspace schema unchanged. Two existing private JSON inspection helpers became internal for reuse; their behavior is unchanged.
- `LaunchActivityCoordinator` owns receipt-aware consent, single-use pre-executor observation closures, generation invalidation on disable/Library changes/clear/teardown, existing-supported-payload expiry, current intent versus actual persisted receipts, one active write plus one latest queued snapshot and bounded Quit drain. It never awaits disk from the launch path.
- `AppLaunchController` retains all existing revision/identity/hidden/file/executor checks; an optional internal observer is prepared after validation and completed only on executor acceptance. Public neutral outcome callbacks/telemetry stay neutral. Cell, keyboard, folder, Library and context paths retain their shared launch controller.
- Library owner/async projection/view integrate optional sections without altering taxonomy, query/count meanings, saved organization, shared action validation or grid return context. The activity projection captures the same owner clock and uses existing1active+1latestpending work scheduling.
- The native Library settings page now scrolls vertically; its independently localized activity child provides opt-in, truthful save/error/protected states, Retry, explicit Recovery and a confirmed feature-only Clear. Privacy OFF remains possible while busy/protected/Library-disabled. Clearing preserves the enabled choice; disabling Library additionally switches recording OFF without deleting retained records. A later Library enable cannot silently opt into tracking again.
- New activity storage location is candidate-local for test profiles; unresolved test intent cannot fall back to formal data. Existing injected Library-only tests do not instantiate a formal activity owner. Quit includes pending/failed activity decisions/writes and uses the approved default-Cancel protection.
-24 new typed static localization keys in English/Simplified Chinese/Japanese; exhaustive validation/probe contract now347keys/signatures per language. No public package target/dependency, PagingCore/physics/tolerance/frame source or original assets changed.

## Actual review and failure history
Foundation Feynman R1 SOURCEPASS: domain/store/location and focused foundation tests inspected, no execution; closed. Integration Euclid R1 SOURCEFAIL2P2, R2 SOURCEFAIL startup variant, finalR3 SOURCEPASS exactr4manifest; closed. These are independent bounded source judgments, not native/performance or formal release acceptance.

Retained real failures:
- focused-r1:146methods/4assertfailures in one pre-existing compact Library settings geometry test. A leading-anchor-only attempted fix did not resolve them (scroll-geometry-r1.log). Diagnostic scroll-geometry-r2.log showed clip361/356pt inside340ptpane: new checkbox intrinsic minimum width plus nested margins. Actual repair allows native checkbox wrapping and horizontal compression; no font shrink or weaker margin/overlap expectation. focused-r2:147/0,10.916s.
- Review I01: Clear followed by immediate privacyOFF lost the clearing-completion marker; I02: failed LibraryOFF receipt restored collection from old acknowledgedON. Actual review-red-r1.log:2methods/7assertfailures,0.821s. Repairs preserve pending clear semantics through latestOFF snapshot and accept a separate activityOFF snapshot on LibraryOFF, keeping history and requiring explicit activityON to resume. Tests cover active/queued Clear, final failure/retry and failed/unavailable/protected Library receipt plus unrelated saves.
- Review R2 startup variant: initial activity read could overwrite accepted LibraryOFF before it loaded. Actual review-red-r2.log:1method/5assertfailures,0.980s. Separate pending privacy intent now mergesOFF before first publication; supported existing differences persist, missing stays no-create, protected/unavailable files remain untouched and report failure/Quit protection. Pending privacy read is included in a real bounded drain deadline. Held-read and all protected/missing cases now covered.
- r1 candidate6c06a32a... and r2candidate61549b0e... had green full suites/builds but were NOT LAUNCHED because review findings were material. They remain historical artifacts, not final runtime evidence.

## Verification evidence
Root: `.build/verification/20261018/library-launch-activity/`.
- Final focused-r5.log:151tests/0failures,9.078s.
- focused-r4:149/0,10.559s; focused-r3:149/0,9.425s, before additional startup regression/repair.
- full-r1:3029/0,112.052s and Debug0.60s/actualRelease347-key package success apply to the earlier r1 source only.
- full-r2:3031/0,92.945s and Debug0.56s/actualRelease347-key package success apply to earlier r2 source only.
- Current500inputs frozen in source-integrated-r4.json; final full-r3/Debug and finalr3package receipts must be appended after completion. No zero-test Swift Testing footer is used as evidence.

## Native test fixture and honest runtime boundary
Existing b1ca4fcb isolated test app was not modified/restarted. Current native query explicitly returned locked Mac. An asynchronous human unlock request was submitted; no automatic unlock bypass, process signal or alternate UI-control tool used.

New finalr3profile is authored fixture only:80Info-only bundles plus one previously independently authored inert AppKit probe (SHA6972c9ca26a6a9ae02fcdd6c6381fe0f9e2b7768b4196f7f1c88a16328ee6fb8). Authored layout/capacity payloads seeded from the own test fixture, no formal data, old preference suites, caches, locks or activity history imported. Activity file is absent before native launch; new Library preference remains defaultOFF. Seed receipts native-fixture-r2/r3.json; neither seed is a launch or event-capture PASS.

Native still needed: exact new candidate defaultOFF/no-history file; actual controlled launch whileOFF; explicit Library/trackingON; accepted grid and Library Open requests appearing once in Recent/Frequent; OFF no new records; Clear Cancel/confirm scoped effects; same-candidate normalQuit/reopen persistence and settings scroll/layout. Do not bind the probe through CUA before verifying its new process appeared after product Open, or claim CUA created startup as product evidence. Preserve old human appearance values (28.40063010899183/54/12/nameson/6×5) and existing old profile; no formal tracker setting may be enabled.

## Remaining limits
No matched physical60/120Hz/energy/RSS, real IME, spoken VoiceOver/multidisplay, all-window-size native layout, arbitrary-application launch/quarantine, power-loss durability or full LaunchBetter parity claim. Original wallpaper intermittency and >25ms causality remain unresolved; folder physical success does not prove its original intermittent cause. No install/sign/notarize/publish/commit/reset/clean/reference-code/assets/OS security action. Full objective remains incomplete.

## Final stable artifact and verification — 2026-10-18
Final full-r3.log: **3033tests/0failures,99.364s**; Debug-r3 PASS0.60s. Actual Release-r3 PASS29.62s; packaged native test entry and347requiredkeys/signatures×3languages verified. Final candidate: `.build/candidates/library-launch-activity-rc-20261018-r3/LaunchcopyUITest.app`, executable SHA256 `310b61f240e3c8c7412b6582d8b21554d787d66240c637351b577aa59acab70c`. All500frozeninputs match after packaging;16existingmodified+12new/zero removed, PagingCore unchanged. `git diff --check` passed. Existing test compilation warnings are not a whole-suite zero-warning claim.

Native recheck after packaging again returned locked Mac. New candidate exact executable is absent; its activity file and Library preference remain absent. Previous own b1ca4fcb/PID29032 instance remains running, not replaced/installed. Final receipt `final-receipt.json` separates packaged artifact from runtime. All stage agents/build/test jobs are terminal; no synthetic wait/live-job claim. The next action is manual unlock then normal own-old Quit/exactabsence, direct new candidate open and bounded native activity matrix. No repeated build or speculative source change is needed merely because native acceptance is pending.

## Native verification resumed after human unlock — 2026-10-18

This checkpoint supersedes the earlier locked-Mac / NOT LAUNCHED snapshots below, without rewriting their history. The human explicitly authorized continued testing. Main normally quit the old isolated instance, verified its exact executable was absent, and opened the final r3 candidate. No formal version was installed or overwritten.

Actual native results for executable SHA-256 `310b61f240e3c8c7412b6582d8b21554d787d66240c637351b577aa59acab70c`:
- Default OFF: startup and a real controlled grid launch created no activity file.
- Explicit Library and tracking opt-in: empty initial activity; the prior OFF request was not replayed.
- One grid launch and one Library details Open each started the authored inert probe (new exact process verified before CUA binding). The persisted total is exactly two requests for one identity. Recent and Frequent each displayed that application.
- Clear warning and Cancel: scope is stated explicitly; Cancel retained both requests. Actual irreversible Clear is PENDING action-time human confirmation, not native PASS.
- Tracking OFF: a further real grid launch started the probe, but the persisted total stayed two; Recent/Frequent were hidden.
- Same-candidate normal Quit / exact process absence / reopen verified both OFF and ON persistence. Existing records were retained; no OFF-period replay occurred.
- Library OFF also switched tracking OFF; Library ON did not resume tracking. Final handover leaves both OFF, preserving the two synthetic requests until the Clear decision.
- Appearance remains names ON, blur 28.40063010899183 (native rounded display 28), icon 54, font 12, columns 6 / rows 5. The old profile is untouched.

Native receipt: `.build/verification/20261018/library-launch-activity/native-acceptance-r3.json`. All 500 frozen source inputs and the exact candidate hash still match after testing. Automated baseline remains 3033/0; no source change or redundant rebuild was needed. Two CUA probe-binding restarts are excluded from product-launch evidence; post-Quit bindings must not be queried because the automation can reopen an app. Actual launch controls used exact pre-click absence checks.

Current own candidate PID at receipt: 36593. Unsigned / uninstalled. No reference code/assets, formal tracking, process signals, OS/security changes, commit or cleanup. No human feature/performance acceptance or full parity completion is inferred. Goal tool retains its historical BLOCKED status (no supported active-setting API); actual human-authorized native progress resumed, so old consecutive lock counts do not carry forward.

Next action: apply only the human's action-time Clear decision, verify retained enabled choice / cleared activity / unchanged unrelated layout and capacity, then leave the isolated app safe for handover. Full parity and physical performance gates remain separate.

## Authorized Clear verified / routine-decision preference — 2026-10-18

The human explicitly authorized irreversible deletion of the two synthetic launch requests in the isolated r3 profile. Main confirmed the native feature-only warning, executed Clear, observed success and disabled Clear, and read entries=0 / enabled=OFF with a rotated document salt. All 84 unrelated fixture JSON/plist inputs (including layout, Library preferences, capacity and authored bundle metadata) were byte-identical. Normal Quit, exact process absence and reopening the same candidate preserved the empty history, Library OFF and tracking OFF. The ordinary non-topmost main window is left available. Formal data and the old candidate profile are untouched.

This supersedes only the pending actual-Clear gate above/below. Controlled native acceptance for this feature now passes within the described fixture and viewport; 3033/0 automated evidence and bounded source-review PASS remain separate. All 500 frozen code inputs and candidate SHA `310b61f240e3c8c7412b6582d8b21554d787d66240c637351b577aa59acab70c` still match. No rebuild, installation or release action occurred. Receipts: `.build/verification/20261018/library-launch-activity/native-clear-r3.json` and `native-acceptance-r3.json`. Human feature acceptance, matched physical performance and full LaunchBetter parity are not inferred.

The human additionally requested autonomous handling of non-major decisions: proceed with routine implementation, repairs and verification inside approved scope without repeated questions. Escalate material product/scope/architecture changes and actions requiring explicit data-deletion/security/permission authorization. Do not treat this preference as blanket consent for destructive operations or unapproved features. Next: continue already-approved non-destructive acceptance / defect work, preserving physical-performance and historical causality boundaries.
