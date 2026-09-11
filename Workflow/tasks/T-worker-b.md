# Task Packet: T-worker-b

- **Task ID**: T-worker-b
- **Role**: Worker B (fresh context — 不继承含逆向材料的旧会话上下文)
- **Step**: 2 (Prompt §6 Step 2)


## Objective

实现纯 Swift PagingCore 模块和单元测试，覆盖页索引/边界/gesture session/target page policy/interruption/transition identity/stale rejection/resize rebasing/pageCount change/cancel/teardown

## Dependencies

- **T-step1**（需要 PHASE1_SPEC、ADR-001、PARAMETER_RATIONALE 作为实现依据）

## Context

**Fresh Context 要求（Phase 1A 来源纪律）**：
此 Worker 必须使用不继承旧逆向上下文的 fresh context。Worker 只接收：
1. 本 Prompt（PHASE1_PAGING_PROTOTYPE_PROMPT.md）
2. Apple 官方公开文档
3. 新工程中由本阶段独立生成的规格、ADR、源码和测试

Worker **不得接收**：旧会话全文、逆向审计全文、治理文档中的来源审计细节。

**禁止读取的路径（Prompt §1.3）**：
```
/Users/mac/Projects/BuhoReverseNotes/（全部内容）
/Users/mac/Projects/LaunchBetter/Packages/
/Users/mac/Projects/LaunchBetter/LaunchBetterApp/
/Users/mac/Projects/LaunchBetter/Docs/aegis/work/2026-08-25-buho-launchpad-reverse/
```

如果意外接触禁止材料：立即停止实现 → 记录 `PROVENANCE/CONTAMINATION_LOG.md` → 标记 BLOCKED_FOR_REVIEW → 等待主控决定。

## Scope

实现 Prompt §6 Step 2 全部内容：
- page index 与 page count
- clamp 和边界
- gesture session（开始/结束/连续变化/momentum）
- visual offset 的纯逻辑表示
- target page policy（位移比例/速度/momentum/边界/Reduce Motion）
- interruption（settle 中被新手势接管）
- transition identity/context（旧回调资格确认）
- stale completion rejection
- resize/page-width rebasing
- page count change（tracking 时和 settling 时减少）
- cancel/teardown

**Core 不依赖 AppKit、Core Animation、窗口或真实触控板事件。**

## Out of Scope

- AppKit UI 实现（属于 T-worker-d）
- Telemetry 实现（属于 T-worker-c）
- 修改 Package.swift（报告给 Main 整合）
- 修改 Docs/ 或 PROVENANCE/ 文件
- 实现搜索、文件夹、拖拽、Hot Corner、数据库、应用扫描

## Expected / Allowed Write Scope

- `Sources/PagingCore/`
- `Tests/PagingCoreTests/`


## Forbidden Write Scope

**禁止写入**：
- `Sources/PagingUI/`、`Sources/PagingTelemetry/`、`Sources/PagingPrototypeApp/`
- `Package.swift`
- `Docs/`、`PROVENANCE/`
- 其他 worker 的 test 目录

## Constraints

- Core 不依赖 AppKit/Core Animation/窗口/真实触控板事件
- 不从旧项目搬运字段名、状态机映射或精确参数簇
- 所有参数使用 PARAMETER_RATIONALE.md 中的集中配置结构
- 参数来源类别禁用 REVERSE_ENGINEERING_COPY / OLD_SOURCE_TRANSLATION / UNKNOWN_ORIGIN
- 不回滚他人改动
- 不修改 Package.swift
- 状态模型须符合 ADR-001 设计
- 命名使用中性项目语言（PagingState/GestureSession/TransitionContext/PageTargetPolicy 等），不使用 Buho 身份或反编译地址含义

## Acceptance Criteria

Core 单元测试必须覆盖 Prompt §7.1 全部场景：

- [ ] page count 0、1、2、多页
- [ ] current page 首、中、尾
- [ ] 小位移回弹
- [ ] 达到翻页条件
- [ ] 高速度、小位移
- [ ] 低速度、大位移
- [ ] 首页向前越界
- [ ] 末页向后越界
- [ ] transition 中断
- [ ] 连续两次反向中断
- [ ] 旧 completion 晚到
- [ ] page count 在 tracking 时减少
- [ ] page count 在 settling 时减少
- [ ] resize/page width 变化
- [ ] cancel
- [ ] teardown
- [ ] Reduce Motion

可重复事件序列测试必须覆盖 Prompt §7.2 全部序列：

- [ ] begin → changes → end
- [ ] begin → changes → end → momentum
- [ ] settling → begin opposite direction
- [ ] settling → resize
- [ ] settling → pageCount reduction
- [ ] tracking → window close

每个序列验证：最终页、视觉偏移、transition 状态、commit 次数、stale callback 数量。

中断安全硬门禁（Prompt §3.F）：

- [ ] settle 动画未结束时新手势可立即接管
- [ ] 接管位置与用户当前看到的位置连续
- [ ] 不跳回旧动画逻辑起点或目标点
- [ ] 旧动画完成事件不覆盖新状态
- [ ] 快速连续正反向操作不出现双重 commit
- [ ] resize/close/pageCount 变化时 transition 安全取消或重新基准化

## Required Verification

- `swift build` 成功（Core target 编译通过）
- `swift test` 全部 Core 单元测试通过
- `exit_code == 0` 且 `executed_tests > 0`（非 INVALID_TEST_EXECUTION）
- 测试输出记录到 Worker Result

## Reviewer Focus

- 状态模型是否符合 ADR-001 设计
- 中断不变量是否全部满足（§3.F 6 条硬门禁）
- 参数来源是否全部合规（无 REVERSE_ENGINEERING_COPY / OLD_SOURCE_TRANSLATION / UNKNOWN_ORIGIN）
- 是否有旧项目字段名/状态机映射的痕迹
- stale completion rejection 机制是否可靠
- Core 是否确实不依赖 AppKit

## Deliverables

- Sources/PagingCore/ 全部源文件
- Tests/PagingCoreTests/ 全部测试文件
- Workflow/results/T-worker-b.md（Worker Result）