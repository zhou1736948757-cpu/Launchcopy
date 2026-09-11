# Task Packet: T-worker-c

- **Task ID**: T-worker-c
- **Role**: Worker C (fresh context — 不继承含逆向材料的旧会话上下文)
- **Step**: 5 (Prompt §6 Step 5)


## Objective

实现可开关 Telemetry 模块和单元测试，记录分页交互全过程的事件流和性能指标

## Dependencies

- **T-step1**（需要 PHASE1_SPEC 和 VALIDATION_PLAN 了解 telemetry 需求）

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

实现 Prompt §6 Step 5 和 §10 全部 Telemetry 内容：

### Telemetry 事件记录
至少记录以下字段（Prompt §5）：
- run ID
- gesture ID
- transition ID
- event phase
- timestamp
- input delta
- visual offset
- semantic current page
- proposed target
- committed page
- interruption count
- stale completion rejection count
- frame interval
- layout count
- page host/view count
- page prepare/cache hit/miss
- teardown 后 callback count

### 输出格式
- JSONL 输出到 `/tmp/launch-copy-paging-prototype-<run-id>.jsonl`
- **不得使用 Buho 品牌前缀**
- telemetry 默认关闭
- 日志不记录个人数据
- 每次正式 run 使用独立日志文件
- 日志路径和 run ID 明确输出

### 命令行参数支持（Prompt §10）
- `--paging-telemetry`：开启 telemetry
- `--run-id <id>`：指定 run ID
- 参数错误给出帮助，不崩溃
- 无参数时可正常打开原型

## Out of Scope

- 实现 PagingCore 状态机（属于 T-worker-b）
- 实现 AppKit UI（属于 T-worker-d）
- 修改 Package.swift（报告给 Main 整合）
- 在 release 默认产生大量日志
- 记录个人数据

## Expected / Allowed Write Scope

- `Sources/PagingTelemetry/`
- `Tests/PagingTelemetryTests/`


## Forbidden Write Scope

**禁止写入**：
- `Sources/PagingCore/`、`Sources/PagingUI/`、`Sources/PagingPrototypeApp/`
- `Package.swift`
- `Docs/`、`PROVENANCE/`
- 其他 worker 的 test 目录

## Constraints

- Telemetry 默认关闭
- 不使用 Buho 品牌前缀的文件名或 subsystem
- 不从旧项目搬运日志格式或字段名
- 参数来源类别禁用 REVERSE_ENGINEERING_COPY / OLD_SOURCE_TRANSLATION / UNKNOWN_ORIGIN
- 不回滚他人改动
- 不修改 Package.swift
- 命名使用中性项目语言（FrameTelemetry 等）

## Acceptance Criteria

- [ ] Telemetry 可通过 `--paging-telemetry` 开关
- [ ] 默认关闭（无参数时不产生日志）
- [ ] JSONL 输出到 `/tmp/launch-copy-paging-prototype-<run-id>.jsonl`
- [ ] 不使用 Buho 品牌前缀
- [ ] 不记录个人数据
- [ ] 每次正式 run 使用独立日志文件
- [ ] 日志路径和 run ID 明确输出到 stdout 或等效可见位置
- [ ] 记录 Prompt §5 全部 17 个字段
- [ ] `--run-id <id>` 参数可用
- [ ] 参数错误给出帮助信息，不崩溃
- [ ] 无参数时可正常打开原型（telemetry 关闭状态）
- [ ] Telemetry 不影响 release 默认行为（不产生大量日志）

## Required Verification

- `swift build` 成功（PagingTelemetry target 编译通过）
- `swift test` 全部 Telemetry 单元测试通过
- `exit_code == 0` 且 `executed_tests > 0`
- 验证默认关闭行为（无 --paging-telemetry 时无日志文件产生）
- 验证 JSONL 格式正确性
- 验证 run ID 和日志路径输出

## Reviewer Focus

- Telemetry 是否确实默认关闭
- 是否使用了 Buho 品牌前缀
- 是否记录了个人数据
- JSONL 格式是否正确且包含全部 17 个字段
- 是否有旧项目日志格式/字段名的痕迹
- 参数错误处理是否健壮（不崩溃）

## Deliverables

- Sources/PagingTelemetry/ 全部源文件
- Tests/PagingTelemetryTests/ 全部测试文件
- Workflow/results/T-worker-c.md（Worker Result）