# T-frame-hitch-probe-repair — 去除诊断探针的主线程写盘污染

**Worker scope**: `Sources/PagingUI/FrameProfileRecorder.swift`,
`Sources/PagingUI/RunLoopProfileRecorder.swift`, new
`Sources/PagingUI/BufferedJSONLWriter.swift`,
`Tests/PagingUITests/FrameProfileTests.swift`,
`Tests/PagingUITests/RunLoopProfileTests.swift`, and this result file only.

**Date basis**: 2026-08-28. Test output carries 2026-08-29 machine timestamps;
per task packet those are not used to establish execution ordering.

## Design and changes

1. Added `BufferedJSONLWriter`, a dedicated serial utility-QoS writer.
   - Recorder hot callbacks only detach an in-memory batch and call `enqueue`.
   - JSONL byte construction, directory creation, `FileHandle` open/seek/write,
     and file-permission handling happen only on the writer queue.
   - `flush()` first enqueues the current buffer, then synchronously waits for
     the serial queue's already accepted work. FIFO queue order preserves record
     order across threshold batches and teardown.
   - Writer errors drop only the failing batch, do not crash, reset the bad
     handle for a later retry, and increment a queryable failure-batch count.

2. Updated both recorders to lazily create the writer only after an *active*
   recorder accepts a record. Default-off therefore creates no observer, file,
   writer, or writer-queue work. JSONL fields and line shape are unchanged.
   `FrameProfileRecorder.endFrame` captures `total_ns` before the threshold
   batch is queued.

3. Tightened diagnostic output files to owner-only permissions (`0600`), both
   for new files and for an existing file opened for append. Permission/open/
   write failures are contained by the writer and are observable through
   `writeFailureCount`.

4. Changed both `isActive` properties to `public private(set)` so external code
   cannot disable a live runloop recorder and leave its observer registered.
   Existing `RunLoopProfileRecorder.start()` / `.stop()` guards retain idempotent
   behavior.

5. Reworded runloop comments and tests to describe only coarse
   active-vs-waiting activity markers. They no longer claim timer/source
   attribution or treat a waiting interval alone as proof of system scheduling.

6. Added focused tests for:
   - deterministic threshold splitting: a suspended injected writer queue proves
     the calling path returns before the sink can execute, and the sink later
     runs off the calling thread;
   - ordered, complete persistence across multiple threshold batches;
   - `stop()` + `flush()` persistence of every accepted runloop record;
   - default-off behavior (existing coverage retained);
   - owner-only permissions; and
   - non-crashing, queryable writer failures.

No performance threshold was changed. No `PagingCore`, `PagingTelemetry`,
`AppDelegate`, `Package.swift`, Docs, or other modules were edited. No reset,
clean, or commit was performed.

## Verification

| Command | Result |
|---|---|
| `swift test --filter PagingUITests` | exit 0; **138 tests, 0 failures** |
| `swift test` | exit 0; **440 tests, 0 failures** |
| `swift build -c release` | exit 0; build output contained **0 warnings** |
| targeted source check | File I/O APIs occur only in `BufferedJSONLWriter.swift`; recorders expose `isActive` as `public private(set)`; no trailing whitespace in changed code/tests |

The first targeted build before the final passing rerun displayed two unrelated
existing compiler warnings in `Tests/PagingUITests/PagingSurfaceInterruptionTests.swift`
for redundant `_ =` on a Void-returning call; that file is outside this task's
write scope and was not edited. The final release build printed no warnings.

## Known boundaries

- This task removes profiler-induced synchronous file I/O from the frame and
  runloop callbacks; it is not a physical trackpad or subjective smoothness
  validation, so it does **not** establish a physical-feel PASS.
- `flush()` intentionally may wait for outstanding writer I/O and is reserved
  for teardown/explicit collection, not a hot callback.
- Runloop records remain correlation clues only: they cannot independently
  distinguish timer/source work or prove system scheduling from one waiting
  interval.

## Changed files

- `Sources/PagingUI/BufferedJSONLWriter.swift` (new)
- `Sources/PagingUI/FrameProfileRecorder.swift`
- `Sources/PagingUI/RunLoopProfileRecorder.swift`
- `Tests/PagingUITests/FrameProfileTests.swift`
- `Tests/PagingUITests/RunLoopProfileTests.swift`
- `Workflow/results/T-frame-hitch-probe-repair.md`

This worker reports implementation and verification facts only; final task
acceptance remains Main/Reviewer responsibility.
