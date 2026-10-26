# Wallpaper Source Classification — 2026-10-15

## Objective and evidence baseline

Continue full parity, not just diagnostic readiness. Previous turn delivered neutral state and actual source-open stall evidence. Latest code has2455tests and407hashed inputs; native primary ImageIO worker stalled in __open while its peer waited for in-flight dedupe. Source kind/locality/cloud availability remain unknown. Specific Library contract still awaits human confirmation; no broad implementation approval inferred.

## Bounded observation contract

Only a resolved isolated UI profile starts one independent background metadata inspection per existing wallpaper refresh. This does NOT run before/inside the image loader and must not delay or replace rendering. Observe the exact existing URL, classify stat file kind plus optional local-volume/ubiquity/download metadata; record no URL/path/name/identifier/content. Observation is a point-in-time snapshot, not descriptor admission or a proven IO timeout. Nil default inspector means production starts no metadata task or AX diagnostic work.

Controller accepts optional metadata inspection through its existing constructor; generation+host gating rejects obsolete inspection completions just like image completions. Neutral diagnostic value combines current LoadState and optional source inspection; only test-window accessibility help receives it. No extra file/directory/store, timers, polling, private wallpaper lookup, permission grants or system changes. Original image loader signature/cache/rendering remains unchanged.

## Plan, tests and acceptance

Main implements classifier/controller/owner and deterministic source metadata + stale-inspection tests. Verify regular/file-symlink/directory/FIFO/missing/non-file cases without opening FIFO or image files; Main creates only independent temporary fixtures. Read-only reviewer runs separately with report-only scope; Main owns serial Swift/build/native resource. Max2 agents includingMain.

After source freeze, focused/full tests, Debug/Release/package/resource identity: direct Cua open unique dedicated app and read real neutral source token. Use actual classification to choose next fix. Don't assume FIFO, cloud or permission cause from an open stack alone; do not declare wallpaper fixed without visible rendering. Normal Quit only our test instance; preserve all candidates, dirtytree and production data.

## Next action

Implement bounded metadata observer and tests, then inspect actual source classification. Physical/Library/capacity/global/data/distribution gates remain separate and incomplete.
