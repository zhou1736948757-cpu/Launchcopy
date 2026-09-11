# Task Packet: T-worker-b-fullscreen（全屏支持 + 全屏基准调参）

- **Task ID**: T-worker-b-fullscreen
- **Role**: Worker（PagingPrototypeApp + PagingCore 作者）
- **来源**: T-step8 物理调参第 10 轮：用户确定**全屏为调参基准**
- **日期**: 2026-08-28

## 背景

- 当前调参全部在窗口（1000pt 宽）下进行；用户实际使用为**全屏**（1470pt 宽，1.47×）。页宽比例类参数（位移阈值/惯性/过冲）在全屏下手感更"沉"。
- 用户已给目标阈值：**前进 0.48、回退 0.42**（在全屏下验证）。

## 任务

### A. 全屏启动支持（PagingPrototypeApp）
1. CLI 加 `--fullscreen`（布尔，可选；缺省 = 窗口形态保持现状）。
2. 窗口显示后进入全屏：`NSWindow.toggleFullScreen(nil)`（真实全屏 Space，菜单栏隐藏）——注意调用时机（window 需先 makeKeyAndOrderFront）；或等价的可靠实现（写理由）。
3. `--help` 文本补行；越界/多余参数遵循既有宽松约定（fullscreen 无参数值）。
4. 测试：AppArguments 解析（--fullscreen 出现/缺省）；冒烟验证全屏窗口 bounds == 屏幕 visibleFrame（记录数字）。

### B. 全屏基准阈值（PagingCore）
1. `PagingParameters.displacementThreshold` 默认 0.5 → **0.48**（前进；注释：全屏基准调参第 10 轮）。
2. `retreatDisplacementFactor` 默认 0.9 → **0.875**（回退 = 0.48 × 0.875 = **0.42**；注释同步用户决策）。
3. 测试更新：前进 0.48/0.49 边界、回退 0.42/0.43 边界（velocityContribution=0 隔离 + 真实混合路径各一）；不对称断言值更新；速度强制/边界/RM 不回归；全量 swift test 0 failures（179+）。
4. `swift build` exit 0（0 warning）。

## Write Scope

- `Sources/PagingPrototypeApp/`（AppArguments + AppDelegate 全屏）
- `Sources/PagingCore/PagingParameters.swift`
- `Tests/PagingCoreTests/`、相关 App 测试
- `Workflow/results/T-worker-b-fullscreen.md`

## Forbidden

- `Package.swift`、`Docs/`、`PROVENANCE/`、`Workflow/`（结果文件除外）
- `Sources/PagingUI/`、`Sources/PagingTelemetry/`
- §1.3 禁止路径与治理文档

## Verification

- `swift test` 全量 0 failures；`swift build` exit 0（0 warning）
- `swift run -c release PagingPrototypeApp --help | grep fullscreen` 命中
- 冒烟：`swift run -c release PagingPrototypeApp --page-count 5 --items-per-page 35 --fullscreen --paging-telemetry --run-id fs-smoke` → 窗口 bounds == 屏幕（用 CGWindowList 验证，数字记入结果文件）→ 手动 kill
- 心跳 role Worker, task-id T-worker-b-fullscreen, ACTIVE

## Status

- 2026-08-28：Main 记录决策（全屏基准 + 0.48/0.42）；Worker 实施中。
