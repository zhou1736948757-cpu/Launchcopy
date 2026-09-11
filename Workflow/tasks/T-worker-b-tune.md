# Task Packet: T-worker-b-tune（momentum 物理调参工具）

- **Task ID**: T-worker-b-tune
- **Role**: Worker（PagingCore + PagingPrototypeApp 作者）
- **来源**: T-step8 物理复测 #3 用户反馈：惯性太长
- **日期**: 2026-08-28

## 用户反馈（原话）

"我觉得惯性有点太大了，就是惯性的时间有点太长。"

## 背景

- `momentumDecay`（默认 0.95，范围 0.8–0.99，来源类别 INDEPENDENT_EXPERIMENT）在 `Docs/PARAMETER_RATIONALE.md` 标 TUNING_REQUIRED——现在进入**真实物理调参**。
- glide 停止阈值 = velocityThreshold×5%（Worker B 偏差 #5，40px/s @800）。
- 目标：惯性滑行时长显著缩短（试值 0.85 ≈ 每帧衰减 15%），同时不破坏快甩翻页判定（velocityThreshold 800px/s 强制翻页仍在）。

## 任务

1. **CLI 覆盖参数 `--momentum-decay <0.80–0.99>`**（可选；缺省 = PagingParameters 默认值 0.95）：
   - `Sources/PagingPrototypeApp/AppArguments.swift`：解析 + 合法范围校验（0.80–0.99，越界给帮助并 exit 2，不崩溃）
   - 接线：构造/应用 PagingParameters 时覆盖 momentumDecay（找到现有参数传递链，最小侵入）
   - `--help` 文本补该参数说明
   - 不改 PagingParameters 默认值（调参确认后再固化；本波只加覆盖能力）
2. **测试**：
   - AppArguments 解析测试（合法值 / 边界 0.80、0.99 / 越界 exit 2 / 缺省 nil）
   - 覆盖值确实生效的测试（构造 Core 时参数被覆盖）
   - 既有全量测试保持 0 failures
3. **文档**（写入结果文件即可，Docs 由 Main 更新）：调参决策记录（用户反馈、试值、来源类别、TUNING_REQUIRED → 物理调参中）。

## Write Scope

- `Sources/PagingPrototypeApp/AppArguments.swift` 及相关接线文件（PagingPrototypeApp 范围）
- `Tests/PagingPrototypeApp` 相关测试（如存在）或 `Tests/PagingUITests`（参数应用测试）
- `Workflow/results/T-worker-b-tune.md`

## Forbidden

- `Package.swift`、`Docs/`、`PROVENANCE/`、`Workflow/`（结果文件除外）
- `Sources/PagingCore/`（本波不固化默认值；如发现接线必须改 Core（如参数 struct 不可变），报告 Main）
- §1.3 禁止路径与治理文档

## Verification

- `swift build` exit 0；`swift test` 全量 0 failures
- 冒烟：`swift run -c release PagingPrototypeApp --help | grep momentum-decay`；`swift run -c release PagingPrototypeApp --momentum-decay 1.5` → exit 2 帮助

## Status

- 2026-08-28：Main 记录调参决策；Worker 实现中。完成后重启窗口带 `--momentum-decay 0.85` 请用户复测。
