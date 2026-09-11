# T-1H-shortcut-recorder — Global hotkey preset + recording UI

- **Date**: 2026-09-11
- **Worker**: Grok Build subagent
- **Status**: implemented (awaiting Reviewer verdict; Worker does not self-certify PASS)

## Objective

Replace Settings readonly shortcut placeholder（「稍后可改」）with:
1. Preset popup（常用组合）
2. Local keyDown recording button（非全局 monitor / 非 CGEvent tap）

## Files changed

### Created
| Path | Role |
|---|---|
| `Sources/PagingPrototypeApp/ShortcutRecording.swift` | `ShortcutDisplay` / `ShortcutPreset` / `ShortcutRecording` 纯映射 + flags→modifiers |
| `Tests/PagingUITests/ShortcutRecordingTests.swift` | Display / preset / interpret + Settings UI hooks |
| `Workflow/results/T-1H-shortcut-recorder.md` | This evidence |

### Modified
| Path | Change |
|---|---|
| `Sources/PagingPrototypeApp/ActivationSettingsWindowController.swift` | 预设弹出菜单 +「录制热键」本地 monitor；描述 `⌥⌘Space`；占位「未设置」；关闭/应用/还原停录制 |

### Explicitly not touched
- `Package.swift`
- Global `NSEvent.addGlobalMonitor…` / CGEvent tap / Accessibility
- Git commit

## Design summary

1. **Preset** — `NSPopUpButton`「预设」：自定义…(tag -1)、⌥⌘Space、⌃⌘Space、⌥⌘L、⌃⌥L；选非自定义写入 `draft.shortcut` 并启用开关。
2. **Recording** —「录制热键」→ label「请按下组合键…」→ `NSEvent.addLocalMonitorForEvents(matching: .keyDown)` only；需 ≥1 修饰键；裸键提示「需要至少一个修饰键」；Esc 取消；成功选「自定义…」；window close / apply / revert / reload 停 monitor。
3. **Display** — `ShortcutDisplay.description`：已知键名 `⌥⌘Space`；未知 `⌥⌘·键码 N`；nil →「未设置」。
4. **Apply path** — 仍走既有 draft 校验 + transaction；`collectDraftFromControls` 保留 `draft.shortcut`。

## Test evidence

### Build

```text
swift build -c release --target PagingPrototypeApp
```

- Exit: **0** (pre-existing Sendable warning on Multitouch diag timer only)

### Filtered tests

```text
swift test --filter 'ShortcutRecordingTests|ShortcutRecordingSettingsUITests|ActivationSettingsWindowControllerTests'
```

| Suite | Executed | Failures |
|---|---:|---:|
| ActivationSettingsWindowControllerTests | 8 | 0 |
| ShortcutRecordingSettingsUITests | 3 | 0 |
| ShortcutRecordingTests | 7 | 0 |
| **Total** | **18** | **0** |
| Exit | **0** | |

(`executed_tests == 18 > 0` — valid filtered evidence.)

## Acceptance mapping

| Criterion | Result | Evidence |
|---|---|---|
| Preset popup with listed combos + 自定义… | implemented | `ShortcutPreset` + `populateShortcutPresetPopup` |
| Local recording only (no global/CGEvent) | implemented | `addLocalMonitorForEvents(.keyDown)` only |
| Bare key rejected | implemented + tested | `interpretKeyDown` → `.rejectBareKey` |
| Esc cancels | implemented + tested | keyCode 53 → `.cancel` |
| Close/apply/revert stop monitor | implemented | `stopShortcutRecording` in those paths |
| Human-readable description | implemented + tested | `ShortcutDisplay` / UIStrings |
| 「稍后可改」→「未设置」 | implemented + tested | `shortcutPlaceholder` |
| Release build green | PASS | exit 0 |
| Targeted tests green | PASS | 18/0 |

## Memory candidates

- Settings shortcut recording must use **local** NSEvent monitor only; never global monitor or CGEvent tap (privacy / Accessibility boundary).
- Shortcut display order follows macOS menu convention ⌃⌥⇧⌘（故 Command+Option+Space 显示为 `⌥⌘Space`）。
