# T-1G-B — Launcher window / resident lifecycle

## Objective

Lock ADR-011 Q3 to **screen-covering borderless panel**, implement `LauncherWindowController` that executes `LauncherPresentationCoordinator` effects (present/dismiss/suspend/terminate/teardown), and add automated lifecycle tests. Do **not** fully rewire AppDelegate multi-entry activation (that is T-1G-E).

## Decision inputs (already decided by Main)

- `Workflow/decisions/2026-09-10-phase1g-continuation.md` → `PROCEED_WITH_DEFERRED_GATES`
- Window architecture = **Option B screen-covering panel** (not native fullscreen Space)
- Same-model subagent; no Chef role split

## Expected / Allowed Write Scope

```
Sources/PagingPrototypeApp/LauncherWindowController.swift   (CREATE)
Sources/PagingPrototypeApp/AppDelegate.swift                (MINIMAL host seam only if required)
Docs/ADR-011-LAUNCHER-PRESENTATION-LIFECYCLE.md             (Q3 lock + spike evidence fill-in)
Tests/PagingUITests/LauncherWindowControllerTests.swift     (CREATE)
Workflow/results/T-1G-B.md                                  (CREATE)
```

Optional tiny helpers under `Sources/PagingPrototypeApp/` only if needed for screen resolution / Reduce Motion policy and kept out of AppDelegate bloat.

## Forbidden

- Frozen trees: PagingCore, PagingTelemetry, PagingUI, AppCatalogCore, MacAppCatalog, AppIconPipeline, AppGridUI/LayoutDomain|LayoutStore|DragSession, Package.swift, AppLaunchController.swift
- Do not create StatusItemController / GlobalShortcutRegistrar / HotCornerMonitor / WorkspaceSessionObserver (C/D)
- Do not wire four-finger into AppDelegate (E)
- Do not flip blank-click / last-window-closed terminate→hide production behavior yet (E) — but design APIs so E can swap cleanly
- No git commit/push; no private Space/WindowServer API; no global NSEvent monitor / CGEvent tap / Accessibility
- Do not log pointer coordinates, screen UUID/name, frontmost app, window titles, app identities

## Design requirements

1. **Single assembly**: at most one launcher window; hide does not destroy window/surface ownership seam; terminate/teardown path separate and idempotent.
2. **Effect execution**: apply `.present/.dismiss/.suspend/.terminate/.teardown` from coordinator; on animation end (or Reduce Motion skip) call `completeTransition(requestID:)` only for matching ID.
3. **Screen covering**: borderless window/panel covering target `NSScreen.frame` (or visibleFrame if you document why); place on `ScreenID` → screens list index with deterministic fallback when screen disappears.
4. **Key/main/first responder**: present establishes key window + activates app; controller exposes a seam to restore a provided first responder (keyboard controller) without owning keyboard logic.
5. **Reduce Motion**: read system preference; shorten/skip opacity/transform animation; state semantics unchanged.
6. **Interrupt**: opposite-command mid-transition must not leave dual windows or orphaned fullscreen Space (panel path should make this natural).
7. **AppDelegate minimal seam** (only if needed): prefer constructing the controller around the existing window *or* providing `attach(window:contentView:)` so E can migrate; avoid large rewrite. If you must stop auto `toggleFullScreen`, replace with panel covering while keeping existing content hierarchy working for smoke launches — document the change clearly in the result.
8. **Privacy**: neutral counters/enums only.

## Acceptance criteria

1. ADR-011 Q3 updated to ACCEPTED Option B with comparison evidence (table dimensions covered).
2. `LauncherWindowController` exists and is used or ready for E to host.
3. Automated tests cover: present→visible complete; dismiss→hidden complete; stale `completeTransition` no-op; show while visible idempotent (via coordinator+controller); teardown once; Reduce Motion path does not break completion; screen fallback deterministic. Exact executed count > 0.
4. `swift test` relevant suites pass (at least new tests + prior LauncherPresentationCoordinatorTests). Prefer full `swift test` if time allows; report exact counts.
5. `swift build` and `swift build -c release` exit 0.
6. Result file `Workflow/results/T-1G-B.md` with files changed, evidence, residual risks, and what E must still do.

## Result format

Write `Workflow/results/T-1G-B.md` with: Objective, Changes, Verification (commands + counts), ADR update summary, Residual for T-1G-C/D/E, AccessDeclaration (`NO_PRIOR_EXPOSURE` unless true).
