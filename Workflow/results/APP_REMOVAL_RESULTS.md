# App Move to Trash — implementation results

Date: 2026-10-18
Status: code, nonzero full tests, Debug/Release/package and bounded source reviews passed; native Trash/Finder acceptance pending manual unlock.

## Approved delivery
Docs/APP_REMOVAL_PROPOSAL.md was explicitly approved. The new context-menu and Library details action moves exactly one eligible selected app bundle to macOS Trash after a default-Cancel confirmation showing name and path. It is not complete uninstall: no support-file cleanup, force quit, admin escalation, permanent delete, Trash emptying, Finder scripting or network behavior. Isolated profiles are confined to their candidate-local Applications directory. No real user application is used for acceptance.

## Architecture
- Independent actor FileAccess performs local/owner/writable-volume/protected-location/link/nested/self/profile admission and bounded descriptor-relative nofollow Info.plist validation off the UI executor. Target/parent/Info identities and content fingerprint are rechecked before one public FileManager Trash call. Only its actual successful receipt reports moved; errors remain unconfirmed, with no destructive fallback. Arbitrary adversarial post-check replacement remains outside path-API atomic guarantees.
- One coordinator owns inspect/confirm/reinspect/running-check/move. Native running-app snapshots are action-scoped, canonicalized off-main and compared conservatively with fixed POSIX case-insensitive complete paths; no observers/history/process termination. Revalidate after every awaited check. Cancel retains in-flight work until real return; after platform admission, hide cannot pretend to cancel the operation.
- Existing immutable cell binding and Library identity/URL/revision/generation guard all asynchronous/modal continuations. Shared launch routes are temporarily revoked while busy. Existing inert localized feedback is reused, no new window/material/frame-I/O pipeline.
- Hide/Quit/teardown invalidate old presentation only; actual receipt, successful catalog refresh and unknown-result Quit protection remain. Acknowledged failed outcomes require checking Finder before retry; orderly Quit waits boundedly and defaults Cancel on unknown/failure. Saved organization/aliases/categories/history remain dormant under existing absent-app policy. No schema migration.
-14 static typed keys in three languages, strict resource contract361keys/signatures each.

## Executed failures and repairs
1. First focused122methods/2assertionfails in one malformed-path method (6.877s). Foundation's url.path escapes true NUL as literal%00; initial guard missed decoded component controls. Main verified Foundation representation, added component guard, retained old assertions and added seven control scalars / valid literal-percent fixture checks. DeweyR1SOURCEFAIL1P2 -> R2SOURCEPASS; localization scopedSOURCEPASS.
2. Descartes integrationR1SOURCEFAIL: case-sensitive running matcher can miss aliases; hide/show can revive old completion UI. Main RED3methods/5assertionfails on2methods(0.610s). Fixed pure conservative matcher, off-main canonicalization, awaited-query revalidation, hide-invalidated presentation epoch, actual receipts unchanged. R2boundedSOURCEPASS. Controlled tests are not physical APFS/IME/native window evidence.
3. Focused-r2 actual124/0(8.137s); finalfocused-r3 actual128/0(9.555s). Original unchanged WallpaperBackdropControllerTests weak-variable compiler warning retained; no zero-warning claim.

## Integrity and current artifact boundary
Full r2 freeze511inputs versus501baseline:14existingmodified+10new, zero removed, PagingCore/paging parameters unchanged. All workers/reviewers closed; Main alone runs serialfullsuite→Debug→actualRelease/package. Unique candidate app-removal-rc-20261018-r1 is not a native or release acceptance claim before job completion. Candidate-local authored82app fixture contains80metadata-only fixtures, the independently authored inert probe, and one uniquely named disposable valid APPL bundle reusing that probe. No preferences/history/cache/locks imported; no actual Trash or formal app operation performed.

## Remaining gates
Exact candidate normal-open/native confirmation Cancel/real own-fixture Trash/refresh/dormant-layout/Finder recovery and ordinary Quit remain unexecuted. Desktop was previously locked; recheck only when package ready. Physical performance/60/120Hz/multidisplay, real IME/spoken VoiceOver, wallpaper intermittency, original folder-scroll cause and full parity remain distinct. No install/sign/notarize/publish/commit/reset/clean/OS/security/reference code/assets operations.

Evidence root: .build/verification/20261018/app-removal/. Stage summary and review reports under visible Workflow.

## Safe app removal code verified and packaged; native pending — 2026-10-18

The human explicitly approved the bounded Move to Trash contract. Implementation adds context-menu and Library details actions with default-Cancel single-app confirmation; one off-main eligibility/receipt service, current binding/catalog/profile/owner/lifecycle checks, conservative running-app refusal, existing refresh/dormant organization and bounded Quit protection. No force quit, privilege, permanent delete, support-file cleanup or removal of formal apps during acceptance. It is not complete uninstall.

Final executed focused128/0(9.555s), full3095/0(109.343s), Debug0.58s, actualRelease61.86s and resourceprobe2.47s/package361keys×3languages/nativeentry/diffcheck PASS. Foundation/localization DeweyR2 boundedSOURCEPASS and integration DescartesR2 boundedSOURCEPASS; all agents/jobs closed. Preserve actual focusedR1 122/2assertfails (decoded NUL path guard) and reviewRED3methods/5assertfails (case-alias running match and hide/show late presentation). Repairs retain control/path guards plus legitimate percent filenames, fixed-POSIX conservative complete-path matching only for running refusal, off-main canonicalization with post-await validation/bounded cancellation, and hide-invalidated presentation epochs preserving actual receipts/refresh/Quit. No real APFS/native Trash claim from these regressions.

All511frozeninputs match after verification,14existingmodified+10new/zero removed versus501baseline; PagingCore and paging parameters unchanged. Original unchanged WallpaperBackdropControllerTests weak-variable warning is historical, not a new zero-warning claim.

New unsigned/uninstalled candidate `/Users/mac/Projects/Launch_Copy/PagingPrototype/.build/candidates/app-removal-rc-20261018-r1/LaunchcopyUITest.app`, executable SHA256 `975db8309a82e316c53e5c4d8f0fab189ebe521af94e9575b5f9f41c1748dbb8`, NOT LAUNCHED. Old own bcf43c54/PID30428 retained. New own82app fixture includes uniquely named valid disposable APPL app using only independently authored inert6972probe executable; no preferences/history/cache/locks imported. Disposable bundle untouched; no activity/Library preference file created. Fresh post-package CUA stilllocked, so no oldQuit/newOpen/actualTrash/Finderrecovery attempted. One concise manual-unlock request pending; no workaround or duplicate material approval request.

Current goal turn is concretePROGRESS (approved implementation, actual failure reproduction/repairs/reviews/tests/package), not a live-job wait or completion. No old blocked audit count carries forward; goal tool historicalBLOCKED cannot be setACTIVE by this API. Full parity/physicalperformance/realIME/spokenVoiceOver/120Hz/multidisplay/wallpaper and original folder-scroll causality remain incomplete. No install/sign/notarize/publish/commit/reset/clean/OS/security/reference-tree actions.

Authoritative report: `Workflow/results/APP_REMOVAL_RESULTS.md`; stage `Workflow/stage-summaries/2026-10-18-app-removal-implementation.md`; `.build/verification/20261018/app-removal/final-receipt.json`. After actual unlock: normal old-own Quit/exactabsence, exactnewcandidate open, preserve current user appearance/6×5, verify Cancel and only the authored disposable app's real Trash/refresh/dormant state/Finder recovery, then handover. Native outcome is NOT PASS yet; no need rebuild unchanged511inputs.


## Current supersession: native removal paths exercised — 2026-10-19

Manual unlock allowed actual testing of unchanged `app-removal-rc-20261018-r1` (SHA `975db830…`,511 inputs still match). Grid Cancel/real own-fixture Trash/automatic catalog disappearance and rediscovery, Library-details Cancel, real-running-probe refusal, normal Quit/restart and layout/capacity byte retention were observed. No real user app was removed. **Finder Put Back was disabled**; recovery passed only using native Finder Copy followed by Move Item Here into the exact original directory. Do not claim one-click Put Back or full native coverage.

Full dated report: `Workflow/results/APP_REMOVAL_NATIVE_ACCEPTANCE_2026-10-19.md`; receipt: `.build/verification/20261019/app-removal/native-results-r1.json`. Historical NOT LAUNCHED/locked snapshots below are preserved but superseded only for these gates. Latest own test PID98940 is available; Library/trackingOFF, FollowSystem, namesON/icon54/font12/6×5; integer blur reload28. No source changes, rebuild, install, commit or full-goal completion. Physical performance/realIME/spokenVoiceOver/wallpaper and original folder-scroll causality remain incomplete.
