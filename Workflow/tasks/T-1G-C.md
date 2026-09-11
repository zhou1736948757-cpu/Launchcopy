# T-1G-C — Status Item + Dock Reopen

## Objective

Add `StatusItemController` (NSStatusBar item with Show/Hide, Activation Settings placeholder, Quit) and Dock reopen adapter so hidden→show / visible→key without a second window. Wire minimally through `LauncherWindowController` / AppDelegate.

## Expected / Allowed Write Scope

```
Sources/PagingPrototypeApp/StatusItemController.swift     (CREATE)
Sources/PagingPrototypeApp/AppDelegate.swift              (Dock reopen + status item host only)
Tests/PagingUITests/StatusItemControllerTests.swift       (CREATE)
Workflow/results/T-1G-C.md                                (CREATE)
```

## Forbidden

- Frozen trees + AppLaunchController + Package.swift
- GlobalShortcutRegistrar / HotCornerMonitor / four-finger wiring (D/E)
- Blank-click → hide flip (E) unless trivially required and documented
- Global monitors / CGEvent tap / Accessibility
- Logging pointer coords / screen UUID / frontmost app / window titles
- Commit/push

## Requirements

1. Status item uses independent SF Symbol (not copying third-party assets); default shown when `ActivationSettings.showStatusItem == true`.
2. Menu: Show / Hide (dynamic from `committedVisibility`), Activation Settings (can be stub/no-op panel or print-free placeholder action that does not crash), Quit → `launcher.handle(.quit)` then terminate path via controller or NSApp.terminate after quit effect.
3. Menu validation reads committed visibility from `LauncherWindowController.coordinator` (or injected provider) — no second toggle state.
4. Creation failure must not crash the app (degrade gracefully).
5. `applicationShouldHandleReopen`: if launcher hidden/suspended → show; if visible → makeKeyAndOrderFront; never create a second window.
6. Target screen: mouse-location screen index with key/main fallback (ADR-011 Q9).
7. Tests: fake status-bar seam if needed; menu title/validation from visibility; reopen behavior with controller; teardown removes status item; no real user defaults pollution.

## Acceptance

- New controller + tests pass with executed > 0
- `swift build` / `swift build -c release` exit 0
- Prefer full `swift test` or at least StatusItem + LauncherWindow + LauncherPresentation suites
- Result file with residual for E

## Concurrency note

May run in parallel with T-1G-D **only if** D does not write AppDelegate.swift. This task owns AppDelegate reopen/status host lines.
