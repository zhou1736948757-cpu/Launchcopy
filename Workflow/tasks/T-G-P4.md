# T-G-P4 — 协调器接线（四指入口 → coordinator）

## Objective
1. 四指识别器 → `LauncherPresentationCoordinator` 的接线组件：`PinchEvent.showRequested(token:)` → `coordinator.show(source: .fourFingerPinch, targetScreen:)`；四指只发 show，永不反向 hide（PLAN §9 不变量 3）。
2. `LauncherActivationSource` 增加 `.fourFingerPinch` 案例（PLAN §9 不变量 2 要求全部激活入口只经 coordinator；CaseIterable 与穷尽 switch 同步适配，T-1G-A 测试回归）。
3. 去重与 generation：同一 PinchEventToken 只产生一次 show；识别器 generation 与 coordinator request generation 各自独立；**Q-1 处理**（T-G-P1 评审：suspend() 不 bump generation → 本任务必须保证 suspend 前排队事件在 suspend 后不重放，否则升级 MAJOR）。
4. **QUESTION-1 处理**（T-G-P3 评审）：provider 重复上报 ready（(.ready, .backendReady) 被状态机拒绝）→ 接线层幂等接受重复 ready，不崩溃不重复启动。
5. 输入交接策略（§21.1 会话结束优先）：识别器 fired 后输入交接——会话结束（全指释放）优先；交接期间新 show 去重。
6. 隐藏与 Quit 语义：四指入口不触发 hide/quit；quit 由 coordinator 独占。
7. 接线组件为纯逻辑（可注入 clock/recognizer/coordinator），不接 AppDelegate、不碰窗口行为代码（物理门未回填）。

## Expected / Allowed Write Scope
- 新文件 `Sources/PagingPrototypeApp/`（FourFingerActivationCoordinator.swift 等接线组件）
- `Sources/PagingPrototypeApp/LauncherPresentationState.swift`（仅加 `.fourFingerPinch` case + 穷尽性适配，计划内小适配）
- 新测试 `Tests/PagingUITests/`（接线/去重/generation/重复 ready/交接）
- 禁止：窗口行为代码、AppDelegate/AppMain/AppArguments 接线、AppLaunchController、冻结树、Package.swift

## 验收
- 接线测试 executed > 0 且 0 failures；T-1G-A 既有测试回归 0 failures
- Q-1 场景有测试（suspend 后旧事件不重放）
- 重复 ready 幂等有测试
- 不 commit/push/tag
