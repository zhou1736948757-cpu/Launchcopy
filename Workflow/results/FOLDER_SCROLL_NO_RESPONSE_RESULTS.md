# Folder Scroll No Response — Diagnosis and Current Physical Outcome

Date: 2026-10-17
Status: CURRENT PHYSICAL SWIPE SUCCEEDED; ORIGINAL FAILURE CAUSALITY UNRESOLVED.

## Human report and evidence correction
Human reported no response to horizontal trackpad scrolling within a multi-page folder. Prior capacity-stage native checks demonstrated folder button paging, not a fresh physical two-finger paging gate. Those checks must not be treated as proof against this report.

Main inspected window-owned modal scroll routing, overlay admission, folder-local input mapper/controller, frame and visual lifecycle. Sidecar Leibniz audited the inner controller/view and missing interleavings without builds/UI. Its report identifies plausible canceled-began tails and reentrant-layout admission changes, but **no established native root cause**. Do not turn these hypotheses into speculative behavioral patches.

## What actually changed
Only two prior-stage source/test inputs changed:
- `Sources/PagingPrototypeApp/AppDelegate.swift`: after the existing window→folder scroll call, a successfully resolved isolated test profile writes an in-memory, identity/path-free last-event summary to the existing folder title button's AX Help. No event monitor, file logging, persisted input, paging mutation, or formal-app AX change. The weak owner route still resolves the current overlay at event time.
- `Tests/PagingUITests/AppDelegateBoundedRegressionTests.swift`: one production-like small-event/layout-refresh regression and its injected memory-only language store. Native-sized1000×668 viewport, installed language owner,30×15pt changed events, actual window route, repeated chrome/readability/folder-layout refresh; assert inner progress/commit and fixed outer offset. **1 test/0 failures,0.297s**, `owner-small-events-r1.log`.

There was **no paging algorithm, input admission, animation, layout or parameter repair**. Current success therefore cannot be described as a proven code fix. Restart or changed transient state is a possibility, not an established cause. The diagnostic callback has extra isolated AX work and is not a physical performance measurement build.

## Native chronology and automation limits
1. Capacity r2/adbd845c had a three-page folder; CUA horizontal scroll produced no AX page change, while pointer Next changed actual members. AX alone also omits moving preview hosts, so unchanged AX is not proof of absent following motion.
2. Own capacity r2 normally Quit, exact process absence verified; diagnostic r1 built/started. Its initial summary was attached to an overlay not currently exposed as an AX element; absent Help did **not** prove missing input.
3. Own diagnostic r1 normally Quit, exact absence verified; diagnostic r2 attaches the summary to the existing exposed title control. Only own authored fixture Info.plists and layout/Library/capacity JSON moved, no cache/locks/formal data.
4. CUA injected scroll demonstrably reached window→folder routing; its last event was phase0/momentum0/horizontalfalse/admittedtrue/stateidle/offset0/page0. A last-event snapshot is not a complete event stream, and automation is not a real trackpad test.
5. Main explicitly requested actual human two-finger left/right swipes in the open folder. Human answered **“成功了这个”**. Fresh native AX showed `phase=0; momentum=8; horizontal=false; dominant=true; admitted=true; transition=false; available=true; state=idle; offset=1.0; page=1`: the folder settled on its **second page**, while outer page remained **1 of2**. The zero delta belongs to the observed terminal momentum event; do not infer all prior events had no horizontal motion.

This supports **bounded current physical success on the diagnostic candidate**, not an explanation or permanent repair of the reported earlier failure. No matched before/after physical causality experiment was performed.

## Current candidate and receipt
`.build/candidates/folder-scroll-diagnostic-rc-20261017-r2/LaunchcopyUITest.app`

Executable SHA-256: `38a1905d3cc371fc09671104012692b89abf98e7c463d51e63f997876a334fd2`

At recorded handover: running PID2042, ordinary non-topmost window, folder open/second page, outer default5×7/first page. Unsigned/uninstalled, no existing app overwritten. Fixtures are80 authored Info-only applications without executables,35 folder members/46 outer entries. This is not a real-app launching gate.

Structured physical/input/profile receipt: `.build/verification/20261017/folder-scroll-no-response/physical-user-confirmation-r1.json`. Layout and Library hashes match previous stage. Main capacity remains5×7. No screenshots were saved.

## Remaining boundaries and next action
- Leave the current working instance available. On recurrence, read diagnostic state **before** restarting, record phase/momentum/admission/core state and whether a fresh next gesture recovers. Do not automatically resurrect orphan changed/momentum events or relax modal/drag/editor safety.
- Current native wallpaper diagnostic became ready without wallpaper source or OS changes. This is an observation, **not** proof of wallpaper rootcause repair; earlier render-failed snapshots remain valid history.
- Physical >25ms causality,120Hz/multidisplay, realIME, spokenVoiceOver/offscreenAX, dense memory/energy and full parity remain independent.
- No reference repositories/assets, formal data, OS/security settings, kill/sign/install/publish/commit/reset/clean actions. CUA only for native interaction; own instances closed only through observed normal Quit.
- Build/full-suite/source-review receipt follows below when terminal. Earlier stage diary is retained; no manufactured PASS or goal completion.

## Terminal verification and review
- Full XCTest: **2901/0**,105.376s, `full-diagnostic-r1.log`. The separate zero-test Swift Testing footer is not evidence.
- Debug: PASS1.25s, `debug-diagnostic-r1.log`.
- Actual Release/package r2: PASS34.24s, `package-diagnostic-r2.log`; packaged309 keys/signatures×3 languages and native isolated entry checks passed.
- `git diff --check`: PASS. Source manifest unchanged after full suite/review; only the two named inputs changed from the stage source snapshot. PagingCore/FolderPagingController/FolderOverlayView unchanged.
- Pasteur independent bounded diagnostic/test **SOURCE PASS**, no actionable findings, no executions/UI; report `FOLDER_SCROLL_NO_RESPONSE_DIAGNOSTIC_REVIEW.md`. Leibniz and Pasteur closed; no live build/test jobs.

The current user-confirmed success remains bounded to this running diagnostic candidate. Preserve the earlier failure report and unresolved causality. Do not silently upgrade this to a behavioral repair or whole-product acceptance.
