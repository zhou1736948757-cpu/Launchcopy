# Frame Hitch trace capture notes

> After physical 60Hz capture. Gate remains `CAUSALITY_UNRESOLVED`.
> Signposts exist only when `--frame-callback-profile` is on.

## Signpost intervals (subsystem `PagingPrototype`, category `FrameHitch`)

| Name | Bounds |
|---|---|
| `TimerGenerationArm` | `start()` arm record |
| `TimerCallback` | Timer closure entry through `pre_return` marker |
| `AdvanceFrame` | `handleFrame` / `PagingSurface.advanceFrame` |
| `CallbackTail` | post-advanceFrame `endCallback` + deadline writeback, before `pre_return` |

Production (profiler off) does not construct `OSSignposter`.

## Local templates (this machine)

`xcrun xctrace list templates` includes **Time Profiler** and **System Trace**. Use those names; do not guess.

## What to capture next

1. **Time Profiler** first: explain the ~10ms active-like slice (stacks).
2. **System Trace** only if Time Profiler shows the thread not on-CPU for the waiting-like ~14ms, or to test runnable-but-unscheduled.

Do not name WindowServer/GPU from time-adjacency.

Physical captures used binary SHA-256 `e42535a9…` **without** these signposts. Any trace run must use a newly built Release binary and a new hash.
