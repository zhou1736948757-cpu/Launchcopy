# Phase 1G Continuation Decision — 2026-09-10

- **Owner**: Main (same-model subagent mode; Chief/Worker/Reviewer role models not used)
- **User instruction**: continue development; ignore Chef model split; Main + same-model subagents
- **User gate choice**: 直接推进 T-1G-B→E，B10/B11 继续挂账不挡

## Decision

**`PROCEED_WITH_DEFERRED_GATES`**

## Gate treatment

| Gate | Treatment |
|---|---|
| Phase 1F B10 real-machine A/B | **Deferred non-blocking** — remain `PHYSICAL_PENDING`; do not invent PASS |
| Phase 1F B11 visual acceptance | **Deferred non-blocking** — remain `PHYSICAL_PENDING` |
| Phase 1G M01–M12 / energy A/B | Still require T-1G-E integration first; stay pending until real evidence |
| Four-finger recognizer physical (prior) | Keep recorded recognizer-level PASS; full matrix still pending after E |

## Window architecture (ADR-011 Q3)

**Chosen: Option B — screen-covering borderless window/panel (public API), not native fullscreen Space.**

Rationale (spike comparison against prompt §3.3 / ADR-011 Q3 table):

1. Current production path (`AppDelegate` delayed `toggleFullScreen` + `.fullScreenPrimary`) creates an independent fullscreen Space and uses hard-coded `asyncAfter(0.3)` — exactly the anti-pattern ADR-011 warns against.
2. Resident launcher needs interruptible show/hide, rapid toggle, Dock/status/hot-corner/four-finger entries without Space thrash.
3. Screen-covering panel: direct show/hide, controllable animation / Reduce Motion, explicit key/main/first responder, target-screen placement, no private Space/WindowServer API.
4. Hide must not destroy the assembly; terminate/teardown remains separate (ADR-011 Q4–Q5).

Hard constraints preserved: no special private window level APIs beyond normal AppKit panel/window usage, no CGEvent tap / global monitor, no Accessibility permission expansion for this choice.

## Semantic task sequence (no runtime concurrency plan)

1. **T-1G-B** — `LauncherWindowController` + ADR-011 Q3 lock + lifecycle tests
2. **T-1G-C** — `StatusItemController` + Dock reopen adapter
3. **T-1G-D** — `GlobalShortcutRegistrar` + `HotCornerMonitor` (+ session observer as needed)
4. **T-1G-E** — AppDelegate composition root: all entries → coordinator; blank/ESC/launch/close → hide; Quit → terminate; four-finger `process`+`flushPendingShows`; `applicationShouldTerminateAfterLastWindowClosed = false`
5. **T-1G-F / physical** — after E; honesty rules unchanged

## Remaining user decisions (do not infer)

- Physical PASS for B10/B11/M01–M12/energy/multi-display/120Hz only with real evidence
- Distribution / notarization / Launch at Login still out of scope

## Next executable action

Dispatch T-1G-B implementation subagent (same model as Main).
