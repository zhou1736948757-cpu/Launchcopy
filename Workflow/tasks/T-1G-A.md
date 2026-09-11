# T-1G-A — ADR-011/012 草稿 + 纯 presentation/activation 状态机

## Objective
1. 创建 `Docs/ADR-011-LAUNCHER-PRESENTATION-LIFECYCLE.md` 与 `Docs/ADR-012-SYSTEM-WIDE-ACTIVATION-PRIVACY.md` 草稿（Chief DRAFT 标注，各答 12 问，见 PLAN §2.2 / Prompt §5.1-5.2）。
2. 纯 Foundation 逻辑（无 AppKit side effect）：
   - `LauncherPresentationState`（.hidden/.presenting(requestID, targetScreen)/.visible(screenID)/.dismissing(requestID, reason)/.suspended(reason)/.terminating）
   - `LauncherActivationSource`（.initialLaunch/.dockReopen/.statusItem/.globalShortcut/.hotCorner/.testHarness）
   - `LauncherCommand`（.show/.hide/.toggle/.quit）、`DismissReason`（.backgroundClick/.escape/.appLaunched/.statusItem/.globalShortcut/.screenConfigurationChanged/.sessionResigned/.explicitQuit）
   - `LauncherPresentationCoordinator` 纯状态机：request generation/stale rejection、toggle 原子仲裁、opposite-command 中断/排队策略、show/hide 幂等、quit dominates、terminate teardown once
   - Hot Corner 纯状态机（.disabled/.armed/.insideCandidate(corner, enteredAt)/.triggeredAwaitingExit(corner)/.suspended(reason)）+ 可注入 fake clock
   - `ScreenGeometrySnapshot` 值模型（负坐标/多屏/内角规则/屏幕变化原子替换）
   - shortcut registration outcome 模型（configured/conflict/unavailable）
3. property/sequence 测试覆盖 Prompt §9.1（12 项）、§9.6（14 项）、§9.7（10 项）、§9.8（9 项）纯逻辑部分。

## Expected / Allowed Write Scope
- 新文件 `Sources/PagingPrototypeApp/`（LauncherPresentationState.swift、LauncherPresentationCoordinator.swift、HotCornerStateMachine.swift、ScreenGeometrySnapshot.swift、ShortcutRegistrationOutcome.swift 等，文件名可调）
- 新测试 `Tests/PagingUITests/`（LauncherPresentationStateTests.swift 等）
- `Docs/ADR-011-*.md`、`Docs/ADR-012-*.md`（新建草稿）
- 禁止：AppKit 行为代码、AppDelegate/AppMain/AppArguments/KeyboardFocusController、冻结树（PagingCore/PagingTelemetry/PagingUI/AppCatalogCore/MacAppCatalog/AppIconPipeline/AppGridUI/LayoutDomain/LayoutStore/DragSession）、Package.swift、AppLaunchController.swift

## 验收
- 全部测试 executed > 0 且 0 failures（`swift test --filter` 相关套件）
- 状态机语义：show 在 visible/presenting 幂等；hide 在 hidden/dismissing 幂等；toggle 原子；Hot Corner 只发 .show 永不反向 hide；quit dominates；stale completion rejected；terminate teardown once
- 无 AppKit import（纯 Foundation）
- 不污染真实 UserDefaults（测试用独立 suite）
- 不 commit/push/tag；不改冻结树
