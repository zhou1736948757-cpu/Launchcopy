# Folder scale and main reorder continuity

Status: selected bounded implementation from explicit visual feedback and normal-decision autonomy.

## Outcomes / scope
Keep correct folder reordering and its non-flashing panel (human confirmed). Remove transient icon clearing during main-page reorder while actually updating order, tokens, geometry, focus and persistence. Increase clean-profile folder icons from48pt to80pt, matching the80pt main default; allow independent folder32–96pt controls. Keep adaptive panel max5×3, typography, main capacity, paging/motion/material behavior unchanged. No reference source/assets, new blur, global cache, per-frame work, formal data mutation or first-Library-entry investigation.

## Compatibility and settings
Appearance schema4 supports extended base/folder32–96pt. Schema1 retains historical48pt base and nil main override; schema2/3 preserve explicit32–64pt choices and their existing main override/inheritance. Validate old ranges before migration; do not reinterpret old invalid values. Load never writes. Future>4 remains protected. Fresh/factory defaults80/80; existing user values never silently overwritten. Live/coalesced saves and safe interaction deferral unchanged. Localized folder captions must show32–96pt accurately. Candidate-specific adjustment, if needed for demonstration, uses only normal isolated Settings.

## Main icon continuity architecture
Main Worker investigates renderer/page rebinding and implements transaction-local reuse of ready images only when identity, icon key and complete outgoing binding match and catalog safety is proven. Retain new full-token asynchronous guards. No general stale-image cache or suppression of necessary top-level refresh. On changed catalog, identity, key, search, retired/recycled/teardown ownership, fail closed to existing clear+request behavior. Bounded memory by attached visible cells, work on presentation transactions only.

## Verification / delivery
Main owns appearance preferences/settings/localization, folder-fit tests, docs and all test/build/UI resources. Worker owns main renderer/page continuity and dedicated tests only. Independent read-only review after stable source. Validate legacy1/2/3 no-write, old-invalid/corrupt/future protection,4roundtrip, independent main/folder controls,80/96 fit and small-window adaptation, full binding rejection and corrected outer order. Run focused then full suite, Debug/actualRelease/package, source manifest/diff check. Native handover only normally quits owned isolated app, preserves latest authored layout/files, keeps formal data untouched. Report source/tests/native/human evidence separately. Real drag/visual acceptance remains human physical gate.


## Bounded renderer delivery / limitations
Worker implemented per-page transaction-local ready-icon continuity, not skipped presentation updates. Only samecatalog/page/attachedhost/reusegeneration/ordinarymode/capacity/uniqueidentityset qualifies, including repeated refresh. Catalog/search/identityset/crosspage/hostrecycle/placeholder/teardown falls back to ordinary clear+async; this does not claim every possible main-page flash is eliminated. Correct new order/full tokens/generations and fresh asynchronous requests remain. No reference or pager/blur changes.

## Verification-only synchronization correction
A repeated unchanged Library test timeout exposed a possible gate ordering flaw: a delayed startup callback can supersede the first held projection; the helper delivered only that stale request and then never delivered its successor. The test helper now waits for a queued continuation and drains FIFO until the actual current-revision projection completes, retaining canceled-result delivery, all test bodies and the same3second deadline. No production Library behavior or first-entry tuning changes. This proves a possible test synchronization defect, not the exact cause of every historical timeout or the deinit diagnostic. Targeted/full reruns and static review remain required.
