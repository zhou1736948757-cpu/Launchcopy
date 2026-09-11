# Phase 1G continuation - stage record

- **Started**: 2026-09-08
- **Updated**: 2026-09-10 (T-1G-E composition root)
- **Owner**: Main (same-model subagents; Chef role models unused per user)
- **Status**: T-1G-E_COMPLETED_PENDING_REVIEW
- **User objective**: Continue Phase 1G development through T-1G-B→E.

## Durable documentation rule

Important content from every development stage is written to Markdown. This file is the canonical stage-level narrative. Runtime events remain in `Workflow/events.jsonl` when used; detailed evidence remains in task/result/review/decision artifacts.

## Starting baseline

- Phase 1G four-finger logic, mock/provider, MultitouchSupport backend, preferences/state, and pure presentation coordinator exist and are automated-complete (1412/0 historically).
- AppKit presentation adapters were missing: no `LauncherWindowController` / `StatusItemController` / `GlobalShortcutRegistrar` / `HotCornerMonitor`.
- AppDelegate still terminated on blank click and last window closed; always entered native fullscreen via delayed `toggleFullScreen`.
- Phase 1F B10/B11 remain `PHYSICAL_PENDING` (not PASS).

## Gate decision (2026-09-10)

- User chose: **直接推进 T-1G-B→E，B10/B11 继续挂账不挡**.
- Main decision: **`PROCEED_WITH_DEFERRED_GATES`** — see `Workflow/decisions/2026-09-10-phase1g-continuation.md`.
- Window architecture locked: **Option B screen-covering borderless panel** (ADR-011 Q3), not native fullscreen Space.
- Role mode: Main + same-model subagents only (no glm/deepseek Chef Worker Reviewer split).

## Wave progress

| Task | Status | Evidence |
|---|---|---|
| T-1G-B | COMPLETED | `Workflow/results/T-1G-B.md` — LauncherWindowController + ADR-011 Q3 |
| T-1G-C | COMPLETED | `Workflow/results/T-1G-C.md` — StatusItem + Dock reopen |
| T-1G-D | COMPLETED | `Workflow/results/T-1G-D.md` — Shortcut + HotCorner + Session |
| T-1G-E | COMPLETED (pending Reviewer) | `Workflow/results/T-1G-E.md` — AppDelegate composition root |

## Findings and decisions (T-1G-E)

- Single presentation authority: `LauncherWindowController` + `adoptCoordinator` sync with `FourFingerActivationCoordinator.adoptPresentation` around `process`+`flushPendingShows`.
- Hide vs terminate: blank/ESC/successful launch/window close → hide; Quit/Cmd-Q/`applicationWillTerminate` → quit+terminate+teardown once.
- `applicationShouldTerminateAfterLastWindowClosed` → `LauncherResidentPolicy.terminateAfterLastWindowClosed` (= false).
- Prefs defaults: shortcut/hot corner Off; fourFinger userEnabled from prefs (default true).
- Activation policy remains `.regular` (Dock reopen).
- Interrupt present→dismiss animation: force sync complete when interrupting (fixes known flake).
- Physical gates **not** claimed PASS.

## Changes (T-1G-E)

- `Sources/PagingPrototypeApp/AppDelegate.swift` — composition wiring
- `Sources/PagingPrototypeApp/ActivationComposition.swift` — CREATE
- `Sources/PagingPrototypeApp/LauncherResidentPolicy.swift` — CREATE
- `Sources/PagingPrototypeApp/LauncherWindowController.swift` — adoptCoordinator + interrupt sync
- `Sources/PagingPrototypeApp/FourFingerActivationCoordinator.swift` — adoptPresentation
- `Sources/PagingPrototypeApp/KeyboardFocusController.swift` — onEscapeExhausted
- `Tests/PagingUITests/LauncherIntegrationTests.swift` — CREATE (8)
- `Tests/PagingUITests/LauncherWindowControllerTests.swift` — interrupt poll harden
- `Docs/PHASE1G_CHECKPOINT.md` — update
- `Workflow/results/T-1G-E.md` — CREATE

**Forbidden untouched**: `AppLaunchController.swift`, `Package.swift`, frozen trees.

## Verification

See `Workflow/results/T-1G-E.md` for exact `swift build` / `swift build -c release` / `swift test` evidence and executed counts.

## Unresolved gates

- B10/B11 deferred non-blocking (`PHYSICAL_PENDING`)
- M01–M12 / energy A/B / multi-display / 120Hz / sleep-lock after T-1G-E — still pending real evidence
- Activation Settings panel still stub

## Next executable action

Reviewer on T-1G-E → then T-1G-F / physical gates with honesty rules unchanged.
