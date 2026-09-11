# Task Packet: T-worker-b-overshoot2（过冲上限 0.20 + CLI）

- **Task ID**: T-worker-b-overshoot2
- **Role**: Worker（PagingCore + PagingPrototypeApp 作者）
- **来源**: T-step8 物理调参第 6 轮
- **日期**: 2026-08-28

## 用户反馈

1. 惯性时长 5 帧 → **3 帧**（`--momentum-glide-frames 3`，CLI 已有，无需代码改动）
2. 过冲上限："最多冲到第二页加 1/5 页" → `momentumMaxOvershoot` 默认 **0.35 → 0.20**，并加 CLI 便于后续微调

## 任务

1. `Sources/PagingCore/PagingParameters.swift`：`momentumMaxOvershoot` 默认 0.35 → **0.20**（注释同步）。
2. CLI `--momentum-overshoot <0.05–1.0>`（可选；缺省 nil=用默认 0.20）：
   - `Sources/PagingPrototypeApp/AppArguments.swift` 解析 + 越界/非数字 → exit 2 + 帮助文本
   - `AppParameters` 接线覆盖（momentumDecay / momentumGlideFrames / momentumOvershoot 三参数并列，风格一致）
3. 测试更新：
   - Core：钳制测试峰值断言 3.35 → **3.20**（ended 2.429 + 钳制 committed+1+0.20）、拉回 0.20；慢甩/边界断言不变（未越限路径）；新增"自定义 overshoot 生效"测试（如 0.1 → 峰值 3.1）
   - App：`--momentum-overshoot` 解析 0.2/边界 0.05/1.0/越界 1.1/0.04/abc exit 2/缺省 nil；接线覆盖生效
   - 全量 swift test 0 failures（168+）
4. `swift build` exit 0（0 warning）。
5. 不改：glide 机制、钳制语义、其余默认。

## Write Scope

- `Sources/PagingCore/PagingParameters.swift`
- `Sources/PagingPrototypeApp/AppArguments.swift`、`AppParameters.swift`
- `Tests/PagingCoreTests/`、相关 App 测试
- `Workflow/results/T-worker-b-overshoot2.md`（简短）

## Forbidden

- `Package.swift`、`Docs/`、`PROVENANCE/`、`Workflow/`（结果文件除外）
- `Sources/PagingUI/`、`Sources/PagingTelemetry/`
- §1.3 禁止路径与治理文档

## Verification

- `swift test` 全量 0 failures；`swift build` exit 0（0 warning）
- `swift run -c release PagingPrototypeApp --momentum-overshoot 1.1` → exit 2
- `--help | grep momentum-overshoot` 命中

## Status

- 2026-08-28：Main 记录决策；Worker 执行中。完成后重启：`--momentum-glide-frames 3 --momentum-overshoot 0.2`。
