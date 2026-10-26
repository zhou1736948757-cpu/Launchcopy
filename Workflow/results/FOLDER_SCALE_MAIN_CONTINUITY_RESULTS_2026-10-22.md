# Folder scale and main reorder continuity — results

## User intent and accepted baseline
The human clarified that folder items move correctly and the folder panel does not flash. Preserve that accepted behavior. Separate remaining complaints: main-page reorder sometimes refreshes the entire page; folder glyphs are too small relative to the panel and outer glyphs.

## Implementation
- Fresh/factory appearance defaults: main80pt, folder80pt; folder slider32–96pt, independent from the main override. Existing saved explicit choices remain unchanged.
- Appearance schema4 reads schemas1–3 without writes. Schema1 still resolves48pt/nil. Old folder values outside32–64 remain corrupt rather than silently newly valid. Future>4 is read-only. Live/coalesced save and interaction deferral stay intact.
- Existing adaptive folder policy accommodates80/96 by reducing rows when needed; max5×3 and pagination remain unchanged. No extra blur or per-frame work.
- Same-page main reorder retains valid ready images during the synchronous render transaction, applies them only after fresh complete bindings, and still issues generation-gated asynchronous requests. Catalog/search/page/host/reuse/capacity/identity-set changes fall back to ordinary invalidation. Cross-page/member changes are not covered by this continuity optimization.

## Verification chronology
1. New appearance tests on unchanged source:5methods/23failedassertions (RED).
2. Appearance focused103/0; combined main/folder/appearance focused121/0.
3. FullR1:3455tests/29failedassertions, all outdated appearance contract expectations. Narrow adaptations retain protection, old bytes, deferral, layout and generation checks; no test removal.
4. Contract-focused84/0.
5. FullR2:3455tests/2failedassertions (1unexpected), unchanged Library early-entry test timeout; isolated class10tests reproduced2failures. Not ignored or attributed to CPU.
6. Test-only helper now waits for queued continuations and drains intentionally completed stale requests until the latest projection finishes. Same3second deadline and all test bodies retained. This proves a possible synchronization flaw, not the exact historical ordering or deinit diagnostic cause. Library10+real drag17=27/0 after repair.
7. Complete fullR3 still pending at document creation.

## Build and static review
Debug and actual Release/package exit0. Packaged native isolated entry accepted;365requiredlocalizationkeys/signatures in3languages validated. Product source unchanged across the test-only repairs. Candidate is unsigned/uninstalled and not opened yet:

`.build/candidates/folder-scale-main-continuity-rc-20261022-r1/LaunchcopyUITest.app`

Executable SHA256: `d9f3ab2ffe45c78627589938dc82d413a69f644f7c7a9a56e834b1e69d4c7287`.

Final source manifest:565inputs,19deltafiles; SHA `200f00cfa498890bc678d4255c9029f4b393444187e1ef14538bda375c348f12`. Verification logs/manifests are under `.build/verification/20261022/folder-scale-main-continuity/`.

Kepler independently accepted the bounded appearance/renderer source statically. A suggested drag-test vacuity gap was addressed by fixed expected counts/iteration and nonnil images. Final narrow test-repair re-review pending. No independent runtime or physical acceptance is implied.

## Delivery and boundaries
Current owned c19a2f18 candidate remains running with the newest human layout. Before opening the new build: require final full-suite/review gates, normally Quit only that owned instance, verify exact absence without querying the old app, clone only249known authored files preserving modes/current layout, and open the exact new path. No preference/history/wallpaper-cache import or formal-data changes. Native scale/flash acceptance pending. Physical scanout/performance, all-flash elimination, full parity,120Hz and complete perceived300ms cause are not established. The user-accepted Library first-entry hitch is not investigated or tuned by this stage.


## Final authoritative delivery — 2026-10-22
This supersedes the pending/unlaunched state above. Full R3 passed3455/0, Debug and actual Release/package passed;565frozen inputs/19deltas and executable hashes remain stable. Kepler final bounded SOURCE_ACCEPT_STATIC_ONLY includes both test repairs. All agents closed and all verification jobs terminal.

Old owned c19a2f18 app normally quit and exact absence was verified without querying it afterward. Only249known authored fixture files were copied to the new profile with copy2, preserving82helper executable modes and the newest human layout SHA1847c20d086e356283d669438f37ac0ef465b6d18999e1c468bcdc7b5efebc00. No preferences/history/wallpaper-cache import or old-profile mutation. New d9f3ab2f candidate is running, PID40758 at receipt, ordinary non-topmost isolated window.

Native Settings shows main80/folder80 and accurate32–96captions; changing only folder80→96 produced a saved acknowledgment while main stayed80, then folder restored80. Settings was closed; main query empty and wallpaper READY. No restart-save acceptance was obtained. Generated custom folder clicks did not reliably produce an observed open panel; AX was also truncated by the long main list. Do not infer a new product defect or call actual drag/folder visual acceptance passed. The final transient view shows main page, folder closed. No screenshot file was saved. Human should open the35member folder to assess scale, then perform a same-page outer reorder to assess flash.

Final receipt: `.build/verification/20261022/folder-scale-main-continuity/final-receipt.json`. Full original parity, all-flash elimination, cross-page continuity, scanout latency and complete300ms causality remain unclaimed. Formal data, OS/security, excluded references, Git history, signing, install and publication untouched.


## Bounded human acceptance — 2026-10-22
The human replied “完美了” to the delivered candidate comparison request for folder proportions and same-page main-grid dragging. Record both requested visual/interaction outcomes as HUMAN_ACCEPTED for the d9f3ab2f candidate. Preserve the accepted folder reorder/no-panel-flash behavior and the current sizing; no further tuning is requested. This supersedes the pending human gates above, not the earlier automation limitations.

This acknowledgment does not establish cross-page/member-change continuity, a controlled performance/scanout result, restart persistence,120Hz/multi-display coverage, independent live Reviewer acceptance, installation/publication, full product parity or the complete historical300ms cause. No source edits, test reruns, app restarts or formal-data changes were made to record this acceptance. The prior3455/0 build/test receipt remains historical evidence of this candidate, not a new test execution.
