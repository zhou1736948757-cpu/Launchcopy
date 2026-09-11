# T-1G-E — AppDelegate composition root (resident launcher)

## Objective

Wire **all** activation entries through the single `LauncherWindowController` / `LauncherPresentationCoordinator` path. Flip product semantics from “prototype always fullscreen, blank exits process” to “resident launcher: blank/ESC/launch/close → **hide**; only Quit → **terminate**”. Start Hot Corner / shortcut / four-finger from prefs. Keep B10/B11 physical gates deferred (do not invent PASS).

## Expected / Allowed Write Scope

```
Sources/PagingPrototypeApp/AppDelegate.swift                 (primary)
Sources/PagingPrototypeApp/AppMain.swift                     (activation policy if needed)
Sources/PagingPrototypeApp/AppArguments.swift                (only if flags needed)
Sources/PagingPrototypeApp/KeyboardFocusController.swift     (ESC final step → hide seam only)
Sources/PagingPrototypeApp/LauncherWindowController.swift    (small adoptCoordinator / apply API if required)
Sources/PagingPrototypeApp/AppLaunchController.swift         (FORBIDDEN — frozen)
Tests/PagingUITests/LauncherIntegrationTests.swift           (CREATE — composition tests with fakes)
Workflow/results/T-1G-E.md                                   (CREATE)
Docs/PHASE1G_CHECKPOINT.md                                   (update status)
Workflow/stage-summaries/2026-09-08-phase1g-continuation.md  (update)
```

Small new helper file under Sources/PagingPrototypeApp/ is OK if it keeps AppDelegate thinner (e.g. `ActivationComposition.swift`), but do not sprawl.

## Forbidden

- Frozen trees listed in PLAN §4 for 1G (PagingCore, PagingTelemetry, PagingUI, AppCatalogCore, MacAppCatalog, AppIconPipeline, LayoutDomain/Store/DragSession, Package.swift, **AppLaunchController.swift**)
- Global NSEvent monitor / CGEvent tap / Accessibility / Input Monitoring / Screen Recording
- Commit/push/tag
- Claiming M01–M12 / energy / B10/B11 physical PASS
- Reading LaunchBetter / BuhoReverseNotes

## Required wiring

### 1. Single coordinator ownership
- `LauncherWindowController` remains the UI owner of presentation state.
- Status item / Dock reopen (already partially wired in C) must continue using the same controller.
- Hot Corner `onShowRequested` → `launcher.show(source: .hotCorner, targetScreen:)`
- Shortcut `onFired` → `launcher.handle(.toggle, source: .globalShortcut, targetScreen: mouse/fallback)`
- Four-finger: provider frames → `fourFinger.process` → `flushPendingShows` → apply present effects on **launcher** (never a second window path).
  - Keep presentation state consistent: either sync `FourFingerActivationCoordinator.presentation` from/to `launcher.coordinator` around flush, or add a narrow `adoptCoordinator` / `replaceCoordinator` on the window controller. Document the chosen approach.
  - Production path must be **process + flush**, not external-only `handlePinchEvent`.

### 2. Hide vs terminate (ADR-011 Q5/Q6)
- Blank click → `hide(reason: .backgroundClick)` (after existing folder/search/drag priority already in QuitOnBlankClickWindow)
- ESC after existing title/folder/search priority exhausted → hide (`.escape`) — extend KeyboardFocusController callback seam; do not swallow Tab
- Successful app launch → hide (`.appLaunched`) via existing `AppLaunchController.onLaunchAttempt` if outcome is success (do not edit AppLaunchController.swift — wire the callback from AppDelegate)
- Window close button → hide, not quit
- `applicationShouldTerminateAfterLastWindowClosed` → **false**
- Status Quit / Cmd-Q / `applicationWillTerminate` → `launcher.quit()` then `launcher.terminate()` then real process terminate / existing teardownAll
- Hide must cancel drag/edge/title/search transient/folder overlay per ADR-011 Q7 (reuse existing cancel helpers)

### 3. Prefs → services
- Load `ActivationPreferences` (isolated suite OK for tests; production suite as already defined)
- `showStatusItem` already hosted — honor live value at launch
- If `globalShortcutEnabled` + spec → register Carbon registrar; else ensure unregistered (default Off)
- If `hotCornerEnabled` + corner → start `HotCornerMonitor`; else zero timer
- If four-finger prefs enabled → start MultitouchSupport backend + coordinator (`userEnabled` from prefs; default true per user decision)
- Wire `WorkspaceSessionObserver` → hot-corner suspend/resume + four-finger suspend/resume as appropriate
- Teardown path stops all services once

### 4. Activation policy
- Prefer `.accessory` or keep `.regular` with Dock reopen — if changing policy, document. Default recommendation: stay `.regular` so Dock reopen works unless ADR says otherwise; do not hide Dock icon without decision note.

### 5. Tests
- Integration tests with **fakes** (FakeGlobalShortcutRegistrar, Fake hot-corner scheduler/pointer, MockTouchProvider): 
  - blank/hide does not call terminate
  - quit path sets terminating + teardown once
  - hot corner show while hidden presents
  - shortcut toggle show/hide
  - four-finger process+flush presents once per token
  - last-window-closed policy false (if testable via AppDelegate subclass or extracted policy helper)
- Do not require real trackpad / real hotkeys for green CI

## Acceptance

1. App builds debug+release exit 0
2. Full `swift test` PASS with executed count reported (expect ≥1460 + new)
3. Manual smoke note in result: how to launch and verify hide vs quit (user will physically confirm later)
4. Result lists residual physical gates honestly as PENDING
5. No privacy redline violations in new/changed code

## Suggested implementation order inside the task

1. Extract/adjust hide helpers + flip blank/ESC/launch/close + lastWindowClosed
2. Wire shortcut + hot corner + session observer from prefs
3. Wire four-finger backend process/flush loop
4. Teardown unification
5. Tests + docs/checkpoint/stage-summary updates
