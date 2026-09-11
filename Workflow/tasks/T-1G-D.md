# T-1G-D — Global Shortcut + Hot Corner adapters

## Objective

Implement production adapters for global shortcut registration and Hot Corner polling on top of existing pure models (`ShortcutRegistration*`, `HotCornerStateMachine`, `ScreenGeometrySnapshot`, `ActivationSettings`/`ActivationPreferences`). Prefer injectability + fakes for tests. **Do not write AppDelegate.swift** (owned by parallel T-1G-C / later T-1G-E).

## Expected / Allowed Write Scope

```
Sources/PagingPrototypeApp/GlobalShortcutRegistrar.swift      (CREATE)
Sources/PagingPrototypeApp/HotCornerMonitor.swift             (CREATE)
Sources/PagingPrototypeApp/WorkspaceSessionObserver.swift     (CREATE if needed for sleep/session)
Docs/ADR-012-SYSTEM-WIDE-ACTIVATION-PRIVACY.md                (Q2 API lock + Q3 scheduler lock)
Docs/PARAMETER_RATIONALE.md                                   (append Hot Corner/shortcut params if missing)
Tests/PagingUITests/GlobalShortcutRegistrarTests.swift        (CREATE)
Tests/PagingUITests/HotCornerMonitorTests.swift               (CREATE)
Workflow/results/T-1G-D.md                                    (CREATE)
```

Optional tiny pure helper files under Sources/PagingPrototypeApp/ if needed (keep narrow).

## Forbidden

- **AppDelegate.swift** (hard — parallel C owns it; E does composition)
- Frozen trees + AppLaunchController + Package.swift
  - If Carbon/HIToolbox requires Package.swift linkerSettings, **STOP and report BLOCKED** to Main — do not edit Package.swift
- StatusItemController changes
- Global NSEvent monitor / CGEvent tap / Accessibility / IOHID
- Logging raw pointer coordinates, screen UUID/name, real shortcut text, frontmost app
- Commit/push
- Default-enable shortcut or Hot Corner (must stay Off until prefs say otherwise)

## Design requirements

### Global shortcut
1. Protocol `GlobalShortcutRegistering` with register/unregister/reconfigure; production adapter using public `RegisterEventHotKey` path **if importable without Package.swift change**; otherwise fake-only + documented BLOCKED for production adapter.
2. Only receives the registered combo; does not read general keyDown stream.
3. Outcomes: configured/conflict/unavailable via existing `ShortcutRegistration` rollback semantics.
4. On fire → callback with neutral signal (caller will `toggle`/`show` via coordinator in E); key repeat must not spam (debounce or ignore repeats).
5. Teardown unregisters.

### Hot Corner
1. `HotCornerMonitor` polls `NSEvent.mouseLocation` on a **pausable** scheduler.
2. **Scheduler decision (lock in ADR-012 Q3)**: prefer main-thread `Timer` with long interval (e.g. 50–100ms range — document source class as ENGINEERING_JUDGMENT or PRODUCT_DECISION, never REVERSE_ENGINEERING_COPY). Disabled = **zero timer / zero polling**.
3. Feeds points into `HotCornerStateMachine` + geometry from `ScreenGeometrySnapshot` (or equivalent builder from NSScreen.screens without persisting UUID/name).
4. On trigger → callback `.show` only (never hide) with target ScreenID of triggering screen.
5. Suspend on sleep/session inactive via WorkspaceSessionObserver; resume rebuilds geometry and requires re-enter (state machine already encodes this — wire events).
6. Privacy: never log mouse coordinates; tests use injected location provider + fake clock.

## Acceptance

1. ADR-012 Q2/Q3 filled with ACCEPTED decisions + rationale.
2. Tests with fakes: register success/conflict/rollback; unregister; hot corner disabled zero timer; dwell trigger once; leave cancels; suspend stops polling; no coordinate logging strings in new source.
3. Builds green; report exact test counts (executed > 0).
4. Result notes what E must wire (prefs → start/stop, callbacks → LauncherWindowController).

## Concurrency note

Runs parallel with T-1G-C. **Must not touch AppDelegate.swift.**
