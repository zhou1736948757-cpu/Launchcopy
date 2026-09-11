# T-targeted-callback-boundary-probe

## Goal

Add an opt-in, privacy-safe Timer callback boundary probe to distinguish nominal deadline lateness, missed periods, start-to-first-tick delay, callback wall/CPU work, and callback-external gaps. Then run controlled diagnostic captures for the unresolved >25ms long tail.

## Frozen / forbidden

- Do not read or modify `/Users/mac/Projects/LaunchBetter/` or `/Users/mac/Projects/BuhoReverseNotes/`.
- Do not read reverse-engineering evidence.
- Do not modify `Sources/PagingCore/`.
- No commit, push, tag, reset, clean, or release.
- Do not record app names, bundle IDs, paths, URLs, or icon data.
- Runloop mode output is restricted to: `default`, `eventTracking`, `modalPanel`, `other`, `none`.

## Scope

- New independent callback JSONL file; do not change the main telemetry schema.
- Fields: callback sequence, driver generation, nominal scheduled time, entry/exit, signed lateness, missed periods, first tick, raw callback interval, simulation dt, mode, callback wall time, current-thread CPU entry/exit/delta.
- Default off; disabled path must not create a file or alter paging behavior.
- RunLoopFrameDriver production interval/tolerance defaults remain unchanged.
- CLI should permit callback-only captures so telemetry/frame/runloop profiler overhead can be excluded.

## Acceptance

1. Unit tests cover parsing, disabled behavior, deadline arithmetic, first tick, generation/sequence, schema, anonymous mode, and no raw mode leakage.
2. Existing tests pass; Release build passes.
3. At least one controlled capture validates JSONL and proves first-tick/deadline fields are populated.
4. Any root-cause statement stays evidence-bounded. Waiting-like or lateness is not renamed scheduler, WindowServer, Core Animation, or GPU without independent proof.
