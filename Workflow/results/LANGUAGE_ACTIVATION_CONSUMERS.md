# Activation Language Consumers — Task A

Status: IMPLEMENTATION_COMPLETE_SOURCE_FROZEN. Task A's five owned files are ready for Main integration/review. No build, native test, application launch, or runtime acceptance executed.

## Main integration contract

- Main owns registration/resources and `LocalizedStrings.activationText(_:)` with key-specific English fallback. Main confirmed all 43 cases were authored; current source exposes the API.
- Typed `LocalizedStrings.activationKeyCode(_ keyCode: Int) -> String` is implemented by Main and consumed here: resource `activation.keyCode`, signature `{keyCode}` integer, English `Key code {keyCode}`, Simplified Chinese `键码 {keyCode}`, Japanese `キーコード {keyCode}`. Consumers keep modifier/key symbols verbatim and use this helper only for unknown virtual key codes. UInt32 conversion is safe on the supported 64-bit macOS target.
- Snapshot overload `ActivationSettingsUIStrings.validationMessage(_:strings:)` and `.alertTitle` / `.loginAlertTitle` are available for window/compatibility consumers. Main's coordinator now independently uses `ActivationServicePresentation` / `ActivationStatusTextKey` for actual action-time validation/headings. That production chain uses its displayed snapshot and preserves partial-login/future-schema semantics. The overlapping static validation/header vocabulary remains intentional compatibility coverage; this task did not edit or redirect Main's coordinator.
- Readiness and login providers must render from the current displayed snapshot; the retained window invokes each exactly once during relabel, without reload or draft mutation. Optional provider defaults now resolve `.activationGestureNotReady` / `.activationLoginDisabled` against the retained snapshot; no legacy raw-Chinese provider is installed by the window. Supplied closures and ordinary existing call sites remain compatible. Main owns the production readiness/login service renderers.

## Exact requested static vocabulary

| Case | Raw resource key | English | Simplified Chinese | Japanese |
| --- | --- | --- | --- | --- |
| `showStatusItem` | `activation.showStatusItem` | Show status menu | 状态菜单显示 | ステータスメニューを表示 |
| `showStatusItemAccessibility` | `activation.showStatusItemAccessibility` | Show status menu switch | 状态菜单显示开关 | ステータスメニューの表示切り替え |
| `globalShortcut` | `activation.globalShortcut` | Global Shortcut | 全局快捷键 | グローバルショートカット |
| `globalShortcutEnable` | `activation.globalShortcutEnable` | Enable global shortcut | 启用全局快捷键 | グローバルショートカットを有効にする |
| `shortcutPresetLabel` | `activation.shortcutPresetLabel` | Preset | 预设 | プリセット |
| `shortcutPresetAccessibility` | `activation.shortcutPresetAccessibility` | Global shortcut preset | 全局快捷键预设 | グローバルショートカットのプリセット |
| `shortcutRecord` | `activation.shortcutRecord` | Record Shortcut | 录制热键 | ショートカットを記録 |
| `shortcutRecordAccessibility` | `activation.shortcutRecordAccessibility` | Record global shortcut | 录制全局热键 | グローバルショートカットを記録 |
| `shortcutRecordingPrompt` | `activation.shortcutRecordingPrompt` | Press a key combination… | 请按下组合键… | キーの組み合わせを押してください… |
| `shortcutRecordingHelp` | `activation.shortcutRecordingHelp` | Press a key combination with at least one modifier key. Press Escape to cancel. | 请按下包含至少一个修饰键的组合键。按 Escape 取消。 | 修飾キーを1つ以上含むキーの組み合わせを押してください。Escapeでキャンセルします。 |
| `shortcutNeedsModifier` | `activation.shortcutNeedsModifier` | At least one modifier key is required | 需要至少一个修饰键 | 修飾キーが1つ以上必要です |
| `shortcutDescriptionAccessibility` | `activation.shortcutDescriptionAccessibility` | Current global shortcut | 当前全局快捷键描述 | 現在のグローバルショートカット |
| `shortcutPlaceholder` | `activation.shortcutPlaceholder` | Not set | 未设置 | 未設定 |
| `shortcutCustomPreset` | `activation.shortcutCustomPreset` | Custom… | 自定义… | カスタム… |
| `hotCorner` | `activation.hotCorner` | Hot Corner | Hot Corner | ホットコーナー |
| `hotCornerEnable` | `activation.hotCornerEnable` | Enable Hot Corner | 启用 Hot Corner | ホットコーナーを有効にする |
| `hotCornerAccessibility` | `activation.hotCornerAccessibility` | Hot Corner selection | Hot Corner 角落选择 | ホットコーナーの選択 |
| `cornerNone` | `activation.cornerNone` | Not selected | 未选择 | 未選択 |
| `cornerTopLeft` | `activation.cornerTopLeft` | Top left | 左上角 | 左上 |
| `cornerTopRight` | `activation.cornerTopRight` | Top right | 右上角 | 右上 |
| `cornerBottomLeft` | `activation.cornerBottomLeft` | Bottom left | 左下角 | 左下 |
| `cornerBottomRight` | `activation.cornerBottomRight` | Bottom right | 右下角 | 右下 |
| `fourFinger` | `activation.fourFinger` | Four-finger Pinch | 四指捏合 | 4本指でピンチ |
| `fourFingerEnable` | `activation.fourFingerEnable` | Enable four-finger pinch | 启用四指捏合 | 4本指のピンチを有効にする |
| `fourFingerStatusAccessibility` | `activation.fourFingerStatusAccessibility` | Four-finger pinch readiness | 四指捏合就绪状态 | 4本指のピンチの準備状況 |
| `launchAtLogin` | `activation.launchAtLogin` | Open at Login | 登录时打开 | ログイン時に開く |
| `launchAtLoginEnable` | `activation.launchAtLoginEnable` | Open Launchcopy at login | 登录时打开 Launchcopy | ログイン時にLaunchcopyを開く |
| `launchAtLoginAccessibility` | `activation.launchAtLoginAccessibility` | Open at login switch | 登录时打开开关 | ログイン時に開く設定の切り替え |
| `launchAtLoginStatusAccessibility` | `activation.launchAtLoginStatusAccessibility` | Current open at login status | 登录时打开当前状态 | ログイン時に開く設定の現在の状態 |
| `apply` | `activation.apply` | Apply | 应用 | 適用 |
| `applyAccessibility` | `activation.applyAccessibility` | Apply settings | 应用设置 | 設定を適用 |
| `revert` | `activation.revert` | Restore Defaults | 恢复默认 | デフォルトに戻す |
| `revertAccessibility` | `activation.revertAccessibility` | Restore default settings | 还原设置 | 設定をデフォルトに戻す |
| `close` | `activation.close` | Close | 关闭 | 閉じる |
| `closeAccessibility` | `activation.closeAccessibility` | Close settings window | 关闭设置窗口 | 設定ウインドウを閉じる |
| `applySuccess` | `activation.applySuccess` | Settings applied | 已应用成功 | 設定を適用しました |
| `defaultsRestored` | `activation.defaultsRestored` | Default settings restored | 已恢复默认设置 | デフォルト設定に戻しました |
| `applyResultAccessibility` | `activation.applyResultAccessibility` | Settings apply result | 应用结果提示 | 設定の適用結果 |
| `alertTitle` | `activation.alertTitle` | Unable to Apply Settings | 无法应用设置 | 設定を適用できません |
| `loginAlertTitle` | `activation.loginAlertTitle` | Open at Login Not Completed | 登录时打开未完成 | ログイン時に開く設定が完了していません |
| `validationCornerMissing` | `activation.validationCornerMissing` | Select a corner before enabling Hot Corner. | 启用 Hot Corner 前请选择一个角落。 | ホットコーナーを有効にする前にコーナーを選択してください。 |
| `validationShortcutMissing` | `activation.validationShortcutMissing` | Select a preset or record a shortcut before enabling the global shortcut. | 启用全局快捷键前请选择预设或录制热键。 | グローバルショートカットを有効にする前にプリセットを選択するか、ショートカットを記録してください。 |
| `validationShortcutModifiers` | `activation.validationShortcutModifiers` | The global shortcut must include at least one modifier key. | 全局快捷键必须包含至少一个修饰键。 | グローバルショートカットには修飾キーが1つ以上必要です。 |

The unknown-key integer helper is additional to the 43 static cases.

## Changed paths and preserved baseline

- `Sources/PagingPrototypeApp/ActivationSettingsWindowController.swift`: preserves the existing dirty settings tabs/views, draft-preservation options and language ownership hooks. Initializes the snapshot before constructing the window/controls. All activation button/caption/AX/corner/custom-preset text uses typed keys. Retains bindings to original controls, updates menu items in place, and rerenders side-status providers without application transactions. Adds only internal `makeAlert(title:message:)` and event-handler visibility for unshown native checks; these are the production alert builder/key interpreter paths.
- `Sources/PagingPrototypeApp/ShortcutRecording.swift`: snapshot overloads for shortcut display and preset captions. Known key names, modifier order/symbols, raw key codes, preset tags/order/matching and key interpretation are unchanged. Unknown-key text uses Main's typed snapshot helper. Old static description/menu APIs remain intact for source/test compatibility. `ShortcutPresetCatalog.swift` is absent; the actual preset/display types live in this assigned file, so no extra file was edited.
- `Sources/LauncherLocalization/ActivationTextKey.swift`: 43 unique `activation.` raw keys, `CaseIterable`, `Sendable`, and exhaustive public `englishFallback: String`.
- `Tests/PagingUITests/ActivationLanguageConsumersTests.swift`: nine focused native test methods, authored but not executed.
- `Workflow/results/LANGUAGE_ACTIVATION_CONSUMERS.md`: exact vocabulary, retained-state integration and verification handoff.

No resources, `LocalizedStrings.swift`, coordinator, AppDelegate, packaging, other tests or workflow/state files were edited by Task A. The repository was already dirty before this task; a comparison against Git HEAD includes earlier work and is not a Task A-only patch. No commit/reset/clean/stash, signing/install, process control or reference-app source reads were performed.

## Retained notices and lifecycle

- `applySuccessKey` distinguishes applied success from restored defaults. Relabel changes the visible green banner's sentence only. It does not schedule/cancel/restart the existing one-second hide work item. Hide clears the key/value, so relabel cannot revive expired feedback. Main needs no additional banner data.
- `shortcutRecordingNeedsModifier` retains bare-key rejection separately from the active-recording prompt. Relabel preserves `isRecordingShortcut`, the original local monitor, ownership callbacks and the shortcut draft. Recording help/AX values update without synthesizing key events. Main must continue to defer production language presentation while shortcut recording owns presentation; the direct consumer test deliberately calls relabel while recording to verify it cannot cancel the owner.
- Failure alert title/message remain action-time data from the coordinator. The native modal/sheet freezes that snapshot until dismissal. Main's existing modal ownership/release tracking must remain authoritative; the window's production builder supplies the displayed-language Close button and passes any native error details verbatim. No retained error-sentence migration is needed in this window because it does not store failure alert contents for later relabel.
- Status provider closures must be render-only and use the newly installed displayed snapshot before calling window relabel. They can retain typed readiness/login state in Main. This task rerenders the retained labels; it does not infer/alter readiness, acceptance, operation generations, service results or login partial failures.
- Existing explicit actions still stop recording where they already did (Apply, Restore Defaults, tab change, hide and preset choice). Relabel invokes none of those actions. No query, user title, alias, binding, editor selection or other settings draft is translated or collected during relabel.

## Authored native coverage (not executed)

1. All three initial snapshots configure the actual unshown activation buttons, captions, popup items, AX/help and default statuses.
2. Relabel retains control/constraint identity, menu item identity/tags/represented objects, selections, actions/targets, enabled/check states, selected tab, first responder, activation draft, appearance slider value, alias draft and language draft control selection.
3. Active recording and bare-key rejection survive direct relabel in all three languages, without ownership-release/Apply callbacks; Escape preserves the binding.
4. Actual recording handler acceptance and popup action dispatch retain raw shortcut specs and custom-preset preservation.
5. Disabled shortcut/corner controls and missing shortcut stay disabled/unset across languages.
6. Retained current-snapshot readiness/login providers rerender exactly once without Apply/draft reload.
7. Applied/restored-default green banners retain their semantic kind and do not repeat transactions when relabeled.
8. Natural success-banner expiry remains hidden after relabel.
9. Production action-time alert builder and validation overload use translated text without presenting a sheet; native error details stay verbatim.

Tests construct `NSWindow`/real controls but never order them front, run the application, present alerts, register login services or create a global monitor. Recording tests use the existing window-local monitor and explicitly clean it up. Main should run `ActivationLanguageConsumersTests` with its permitted isolated native runner after freezing the integrated sources. New tests require Main's resources, `activationText`, `activationStatusText`, and `activationKeyCode`; zero authored execution is not a native PASS.

## Static verification and remaining gates

- `rtk proxy git diff --check --` followed by the five assigned paths: exit 0, no whitespace diagnostics.
- Read-only Python source assertions: 43 unique prefixed cases with complete English fallbacks; no Chinese string literals in the shipping controller outside the compatibility enum; snapshot assignment precedes window/control construction; relabel has no reload/cancellation/application callbacks/menu rebuild/timer scheduling; unknown-key consumer has no bundle/locale/file access and calls the typed snapshot helper; exactly nine unshown native methods inventoried.
- Source inspection confirms Main exposes `activationKeyCode(_:)` rendering the retained integer template, and the coordinator's current selected-snapshot chain uses its semantic service vocabulary. This is not resource packaging or runtime validation.
- No Swift compiler, build, test, app launch or GUI acceptance was run. Main owns compilation, the focused/full suite, shared schema/resource validation, packaging/fingerprints and runtime acceptance.
- Real 500×560-window fit for long English/Japanese captions and service details, VoiceOver behavior, marked-text/menu/sheet timing, final ownership release, exact-candidate startup/persistence and physical input remain Main's integration/acceptance gates. Geometry/layout and recording lifetime are preserved by source, not certified by an unexecuted test.
- The legacy no-snapshot constructor still resolves Simplified Chinese for ordinary legacy callers, consistent with its earlier compatibility behavior. Production must supply the initialized displayed snapshot. Optional status defaults are snapshot-aware; any explicitly injected legacy-string provider outside this window remains Main's responsibility.

Source freeze: Task A will make no further edits to these five files unless Main reports a specific review/build/test issue. Main may take ownership for final integration.
