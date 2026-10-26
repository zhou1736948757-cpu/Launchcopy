# Folder reorder icon continuity —2026-10-21

## Actual repaired behavior and proof
A non-idempotent FolderOverlayView.configure previously cleared every visible icon before its asynchronous requests delivered, even for same-catalog pure member permutation. New local transaction captures eligible known images before reuse and applies them to the new complete bindings by AppID+IconKey before normal async requests. No new global cache, synchronous load, frame I/O, timer, animation or persistence/physics/edge-dwell parameter change.

Discriminating old-source evidence: new view test1/9 image-identity assertion failures; actual production-owner pointerDown→pointerDragged→pointerUp test1/2 image-identity failures. All other owner commit/provider/memberbinding/sessioncleanup assertions passed on that RED run. Thus the order was committed synchronously while known image bindings disappeared; the repair closes that established presentation gap. It does NOT prove a measured300ms cause or guarantee the user's entire perceived release delay is gone. These tests cover real composition/coordinator callbacks, not native OS pointer-event arrival or compositor presentation timing.

Eligible only for same folder/title/served catalog revision/inner page/configured capacity/ReduceMotion, exact complete-member permutation, and no panel transition/swipe/collapsed move-out. Exact outgoing seven-field token must match its expected old binding; each retained image is applied through the new full token. Different catalog/source mapping, folder/page/configuration/member set or invalid token follows normal loading. Fresh callbacks and all stale/visual-only/teardown guards remain; continuity never bypasses normal requests. Retained image storageO(visiblemembers); full-permutation validationO(totalfoldermembers) time/temporary sets, only at configure boundary, not per-frame.

## Verification and ownership
- Main: bounded one-production-file patch and4new local regression tests. Ampere:2new real-owner reorder/no-op tests in the existing private fixture; prior contents reconstructed and old hash matched. No duplicated onCommit implementation or production API expansion.
- Focused54tests/0, authoritative full3388tests/0 (3382+6), terminalexit0. Nativeview/negativeeligibility/currentasyncdelivery/oldcallbackrejection/lifecycle/ownercommit/no-op/persistence coverage. No physical latency inference from test elapsed time.
- Debug/actualRelease/unique assemblyexit0; packaged365keys×3languages verified.554recordedfrozeninput hashes unchanged through tests/build/handover, exactly3source/test deltas; gitdiffcheckPASS.
- Hooke bounded SOURCE_ACCEPT/no finding. Read-only, no independent tests/build/UI/timing or fullparityacceptance. Worker/reviewer closed; Main alone serialverification/native.

## Exact delivery and native handover
New unsigned/uninstalled `.build/candidates/folder-continuity-rc-20261021-r1/LaunchcopyUITest.app`; SHA-256 `3560657f1ba14ec646d7d52fe323c975aa74f1713c8bd1f61efb1264dfa41a71`. Preserves the previous transparent preview backing fix.

Prior drag-feedback candidate normalCommandQ/exactabsence before copying. Fresh profile copies only249knownauthored files/latestuserlayout/capacity, not preferences/history/wallpaper cache. Latest user-controlled test arrangement4302aa865272fce32c622284fecf40dd30b94c372aecb1f0ee25f6cd56cfdef7 was retained, never replaced with older723199c6seed. Original profiles preserved. Any later human test reorder is an authorized owned-data change, not automatically rolled back or relabeled as hash stability.

Main supportedCUA opened the exact new artifact; ordinary main populated, then35-member glass folder page1/3 with latest member ordering and all visible icons. Fresh wallpaper initiallyLOADING and becameREADY in the observed folder state; this is readiness, not wallpaper causal repair/performance acceptance. Left folderopen/settingsclosed/queryempty for human comparison. Desktop2placement unverified. Final neutral receipt records current exactPID and hashes; prior PIDs are historical.

One actual human question asks whether release still waits and whether black backing remains. Both physical outcomes are PENDING at this receipt. No repeated generated drag was substituted after the earlier native-slider positive-control failure. Do not mark human acceptance or whole300ms symptom fixed without the actual reply/appropriate measurement.

## Boundary and next action
No source references/rawreverseassets, formal user data, real app launch/removal, OS/backend/consent, processsignals, signing/install/publish/Git/reset/clean, saved screenshots/wallpaper pixels or private streams. All build/test/agent handles terminal/closed. The prior goal turn and this turn made concrete source/test/native progress; full original objective remainsACTIVE/incomplete. Optional outwardHide proposal and other physical/device/IME/VoiceOver/fullparity requirements remain distinct. First Library hitch remains user-accepted nonblocking with cause unproved.

If the user still observes delay on this exact candidate: record actual phase/core state and bounded neutral pointerUp→commit→iconbinding→render boundaries, preserving current source/arrangement. Do not retune dwell/settle/persistence or infer CPU causality. If the human confirms immediate placement and no backing, close only that bounded reported symptom gate; do not claim full product completion.

Evidence: `.build/verification/20261021/folder-reorder-continuity/` includes before-files, red/owner-red/focused/full/debug/package logs, source review, frozen554inputs, latest owned layout, candidatefixturemanifest and results-r1.json. Contract: Docs/FOLDER_REORDER_ICON_CONTINUITY_SPEC_2026-10-21.md.

## Superseding human feedback — 2026-10-22
The user reports: “仍有换位延迟，黑底没了”. The transparent preview backing is physically ACCEPTED. Folder placement latency remains UNRESOLVED; the prior synchronous image-continuity fix is not the entire root cause or a physical latency PASS. The user changed only the owned isolated layout during the test; preserve the latest arrangement (79f5adf8 at the next preflight, or newer), not the older4302aa86 handover order. Follow the bounded opt-in protocol in Docs/FOLDER_DROP_LATENCY_DIAGNOSTIC_SPEC_2026-10-22.md.
