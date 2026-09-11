# Review: T-frame-hitch-probe-repair — **PASS**

**Independent read-only review completed.** No implementation files were edited.

## P0 / P1

- **P0: none**
- **P1: none**

## Confirmed acceptance evidence

- **Hot callbacks contain no filesystem I/O or `Data` construction.** The frame and runloop recorders only build an in-memory JSON line, cut the batch, and enqueue it. All `Data`, directory, permission, open/seek/write work is isolated in the serial writer queue.  
  - `/Users/mac/Projects/Launch_Copy/PagingPrototype/Sources/PagingUI/FrameProfileRecorder.swift:156-168,302-322`
  - `/Users/mac/Projects/Launch_Copy/PagingPrototype/Sources/PagingUI/RunLoopProfileRecorder.swift:124-143,171-189`
  - `/Users/mac/Projects/Launch_Copy/PagingPrototype/Sources/PagingUI/BufferedJSONLWriter.swift:37-43,63-108`

- **FIFO and flush completeness are correctly implemented for the intended main-thread lifecycle.** `enqueue` targets one serial queue; `flush()` first detaches the remaining recorder buffer, then waits behind all previously accepted queue work. The writer’s queue-specific guard avoids a self-`sync` deadlock.  
  - `/Users/mac/Projects/Launch_Copy/PagingPrototype/Sources/PagingUI/BufferedJSONLWriter.swift:37-60`
  - `/Users/mac/Projects/Launch_Copy/PagingPrototype/Sources/PagingUI/FrameProfileRecorder.swift:251-255,315-322`
  - `/Users/mac/Projects/Launch_Copy/PagingPrototype/Sources/PagingUI/RunLoopProfileRecorder.swift:138-143,182-189`

- **Default-off behavior and observer lifecycle pass inspection.** The writer is lazy, inactive recorders do not append or create files, and the runloop observer has idempotent `start`/`stop`, weak capture, teardown removal, and app teardown calls `stop()` before `flush()`.  
  - `/Users/mac/Projects/Launch_Copy/PagingPrototype/Sources/PagingUI/FrameProfileRecorder.swift:44-67,123-124`
  - `/Users/mac/Projects/Launch_Copy/PagingPrototype/Sources/PagingUI/RunLoopProfileRecorder.swift:33-40,76-93,97-120`
  - `/Users/mac/Projects/Launch_Copy/PagingPrototype/Sources/PagingPrototypeApp/AppDelegate.swift:353-384`

- **Permissions and nonfatal failures are implemented correctly.** New and pre-existing output files are set to owner-only `0600`; open/write/permission errors are caught, counted, and the bad handle is closed for a later retry rather than crashing.  
  - `/Users/mac/Projects/Launch_Copy/PagingPrototype/Sources/PagingUI/BufferedJSONLWriter.swift:63-80,83-116`

- **Runloop interpretation was narrowed as required.** Comments now describe only coarse active-vs-waiting correlation; they explicitly reject timer/source attribution and treating a waiting interval alone as proof of system scheduling.  
  - `/Users/mac/Projects/Launch_Copy/PagingPrototype/Sources/PagingUI/RunLoopProfileRecorder.swift:12-24,56-59`
  - `/Users/mac/Projects/Launch_Copy/PagingPrototype/Tests/PagingUITests/RunLoopProfileTests.swift:76-89`

- **JSONL compatibility:** frame and input records retain the existing `kind`, `timestamp`, `input_ns`, `state_ns`, `view_ns`, `total_ns`, and relevant `gesture_active`/`phase` fields; runloop records retain their established fields. The generated key order is stable.  
  - `/Users/mac/Projects/Launch_Copy/PagingPrototype/Sources/PagingUI/FrameProfileRecorder.swift:165-167,200-207`
  - `/Users/mac/Projects/Launch_Copy/PagingPrototype/Sources/PagingUI/RunLoopProfileRecorder.swift:126-133`

- **No performance threshold was changed.** The current modified source/test set in the repair window is limited to the allowed PagingUI recorder/writer files and the two approved test files. The repository has no commits and all project content is untracked, so a conventional Git diff against a committed base is unavailable; current-file inspection and task-artifact correlation found no attributable out-of-scope implementation change.

## P2 — follow-up quality items, not release blockers

1. **Main-thread-only ownership is documented but not mechanically enforced.** The recorders mutate buffers and expose mutable `bufferCapacity` / `flushThreshold`; concurrent callers could race with a callback or `flush()`. The shipped AppKit lifecycle uses them on the main thread, so I found no in-scope runtime race, but an explicit `@MainActor`, precondition, or immutable-after-start configuration would make the contract safer.  
   - `/Users/mac/Projects/Launch_Copy/PagingPrototype/Sources/PagingUI/FrameProfileRecorder.swift:59-67,302-322`
   - `/Users/mac/Projects/Launch_Copy/PagingPrototype/Sources/PagingUI/RunLoopProfileRecorder.swift:50-67,171-189`

2. **Failure/permission tests cover the principal paths but not every recovery variant.** The suite proves new-file `0600` and a non-crashing, queryable forced sink failure. It does not specifically assert that an *existing* permissive file is tightened to `0600`, nor that a writer succeeds on a later batch after an initial failure. Implementation supports both paths, but dedicated regressions would strengthen it.  
   - `/Users/mac/Projects/Launch_Copy/PagingPrototype/Sources/PagingUI/BufferedJSONLWriter.swift:91-107`
   - `/Users/mac/Projects/Launch_Copy/PagingPrototype/Tests/PagingUITests/FrameProfileTests.swift:256-285`

3. **The deterministic “non-blocking threshold” proof is attached to the frame recorder seam.** Because both recorders call the same writer, this is meaningful shared coverage, and runloop has its own stop-plus-flush test. A matching runloop threshold test would make the hot-callback claim independently explicit.  
   - `/Users/mac/Projects/Launch_Copy/PagingPrototype/Tests/PagingUITests/FrameProfileTests.swift:193-232`
   - `/Users/mac/Projects/Launch_Copy/PagingPrototype/Tests/PagingUITests/RunLoopProfileTests.swift:92-107`

## Verification run by this reviewer

| Command | Result |
|---|---|
| `swift test --filter FrameProfileTests` | **14 tests, 0 failures** |
| `swift test --filter RunLoopProfileTests` | **7 tests, 0 failures** |
| `swift test --filter PagingUITests` | exit **0** |
| `swift test` | **440 tests, 0 failures** |
| `swift build -c release` | exit **0**; no warnings emitted in the captured build output |
| `git diff --check` | exit **0** |

## Boundary

This is an **automated/code review PASS only**. It confirms that this repair removes the diagnosed synchronous writer work from hot callbacks and preserves the stated functional behavior. It **does not establish a physical trackpad smoothness / subjective-feel PASS**.
