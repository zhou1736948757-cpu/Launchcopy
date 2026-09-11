# T-1H-B + T-1H-F — Settings UI + composition wiring

- **Date**: 2026-09-11
- **Worker**: Grok Build subagent
- **Status**: implemented (awaiting Reviewer verdict; Worker does not self-certify PASS)
- **Gate 0**: `Workflow/decisions/2026-09-11-phase1h-gate0-approved.md`
- **Combined tasks**: T-1H-B (AppKit Settings window) + T-1H-F (AppDelegate / composition wiring)

## Objective

Native AppKit single-instance Activation Settings window with Chinese product labels; draft → validate → `ActivationApplyTransaction` → persist / `ActivationComposition.applyPreferences` / `LaunchAtLoginServicing`; wire status menu → `showSettings()`; never auto-enable real login item at launch; Fake login in tests.

## Files changed

### Created
| Path | Role |
|---|---|
| `Sources/PagingPrototypeApp/ActivationApplyTransaction.swift` | Runtime apply transaction (validate → plan → runtime → persist; login rollback) |
| `Sources/PagingPrototypeApp/ActivationSettingsWindowController.swift` | AppKit settings window + Chinese UI strings + single-instance factory |
| `Sources/PagingPrototypeApp/ActivationSettingsCoordinator.swift` | Store + login + window ownership; `showSettings()` / `applyDraft` |
| `Tests/PagingUITests/ActivationSettingsWindowControllerTests.swift` | Single-instance, invalid hot corner, Fake login, close≠quit (8 tests) |
| `Tests/PagingUITests/ActivationApplyTransactionTests.swift` | Transaction invalid/no-op/login failure/accept matrix (4 tests) |
| `Workflow/results/T-1H-B-F.md` | This evidence |

### Modified
| Path | Change |
|---|---|
| `Sources/PagingPrototypeApp/ActivationPreferences.swift` | `InMemoryActivationPreferencesStore` (tests + suite-fail fallback) |
| `Sources/PagingPrototypeApp/StatusItemController.swift` | Chinese menu titles（显示/隐藏启动器、激活设置…、退出 Launchcopy）; accessibility Launchcopy |
| `Sources/PagingPrototypeApp/AppDelegate.swift` | Hold coordinator + `SMAppServiceLaunchAtLoginService`; status menu → `showSettings()`; status-item visibility apply |
| `Tests/PagingUITests/StatusItemControllerTests.swift` | Assert Chinese titles / Launchcopy accessibility |

### Explicitly not touched
- Frozen reverse-engineering trees
- `Package.swift`
- Real `SMAppService.setEnabled` in tests
- Git commit
- Auto-enable login item at launch

## Design summary

1. **Window** — `ActivationSettingsWindowController` NSWindowController; `sharedOrCreate` + static weak; title「激活设置」; sections: 状态菜单显示 / 全局快捷键 / Hot Corner / 四指捏合 / 登录时打开; buttons 应用·还原·关闭; `windowShouldClose` → `orderOut` (no quit).
2. **Draft vs committed** — open loads committed draft; Apply runs transaction; validation failure → Chinese NSAlert, draft kept; success reloads committed.
3. **Transaction** — `ActivationApplyPlanner` then runtime: status item callback → `applyPreferences` → login `setEnabled`; `requiresApproval`/`failure`/`unavailable` → do not claim login success, rollback preference bit, persist accepted remainder.
4. **Coordinator** — owns store + Fake/production login service + window; AppDelegate injects composition apply + four-finger readiness string + status-item install/teardown.
5. **Production login** — `SMAppServiceLaunchAtLoginService` constructed at launch but **never** `setEnabled(true)` automatically; only user Apply may enable.
6. **Shortcut UI** — enable toggle + readonly keyCode/modifiers text（「稍后可改」when nil）; full recorder deferred.

## Test evidence

### Build

```text
swift build --target PagingPrototypeApp
```

- Exit: **0** (pre-existing Sendable warning on Multitouch diag timer only)

### Filtered tests

```text
swift test --filter 'ActivationSettingsWindowControllerTests|ActivationApplyTransactionTests|StatusItemControllerTests|LaunchAtLoginServiceTests'
```

| Suite | Executed | Failures |
|---|---:|---:|
| ActivationApplyTransactionTests | 4 | 0 |
| ActivationSettingsWindowControllerTests | 8 | 0 |
| LaunchAtLoginServiceTests | 12 | 0 |
| StatusItemControllerTests | 17 | 0 |
| **Total** | **41** | **0** |
| Exit | **0** | |

(`executed_tests == 41 > 0` — valid filtered evidence for this task scope.)

### Acceptance mapping

| Criterion | Result | Evidence |
|---|---|---|
| Single-instance show twice | PASS | `testShowSettingsTwiceReusesSingleWindowController` |
| Invalid hot corner without corner fails | PASS | `testApplyInvalidHotCornerWithoutCornerFailsValidation` / window keep-draft test |
| Fake login never `usesRealLoginItemRegistration` | PASS | Fake login tests + LaunchAtLoginServiceTests |
| Closing settings does not quit | PASS | `testWindowShouldCloseOrdersOutWithoutQuitting` |
| Chinese menu titles | PASS | StatusItem + `testStatusItemMenuUsesChineseProductTitles` |
| No auto login enable at launch | PASS | AppDelegate constructs service only; Apply path exclusive |
| Main-thread AppKit tests | PASS | `@MainActor` on window/coordinator suites |

## Constraints compliance

| Constraint | Result |
|---|---|
| No git commit | Yes |
| No real SMAppService setEnabled in tests | Yes (Fake only; production adapter construct-only in T-1H-C suite) |
| Frozen trees unchanged | Yes |
| Use ActivationApplyPlan / Draft / Validator | Yes |
| Use LaunchAtLoginServicing (Fake in tests) | Yes |
| Chinese UI labels | Yes |

## Memory candidates

- Settings single-instance factory: `ActivationSettingsWindowController.sharedOrCreate` + coordinator strong ownership; close = `orderOut`.
- Apply order runtime: statusItem → composition prefs → launchAtLogin; login non-success rolls preference bit back.
- Status menu Chinese copy lives in `ActivationSettingsUIStrings`.
- `InMemoryActivationPreferencesStore` available for Settings tests without UserDefaults.

## Deviations / disclosures

1. Shortcut **recording** not implemented (task allowed readonly display +「稍后可改」); enable toggle + text description only.
2. Combined result file `T-1H-B-F.md` per task instruction (instead of separate T-1H-B.md / T-1H-F.md).
3. Status-item recovery when hidden: Dock reopen remains; full app-menu Settings command left for a later recovery polish if needed (§6.5).

## Next executable action

Independent Reviewer on T-1H-B-F (diff + filtered evidence above).
