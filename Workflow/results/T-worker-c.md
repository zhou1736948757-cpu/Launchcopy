# Worker Result — T-worker-c（PagingTelemetry）

- **Task ID**: T-worker-c
- **Role**: Worker C（fresh context 实现 worker，deepseek-v4-flash:0731，max）
- **日期**: 2026-08-28
- **AccessDeclaration**: NO_PRIOR_EXPOSURE
  - 本 worker 仅读取：任务包 `Workflow/tasks/T-worker-c.md`、`Docs/PHASE1_SPEC.md`、
    `Docs/ADR-001-PAGING-STATE-MODEL.md`、`Docs/VALIDATION_PLAN.md`、`Package.swift`（只读）、
    `Workflow/PLAN.md`（任务图/验收上下文）。
  - **未读取**：BuhoReverseNotes、LaunchBetter（含 Packages/LaunchBetterApp/2026-08-25 逆向目录）、
    Launch_Copy 治理文档（RISK_REDUCTION_PLAN / CONTEXT_LEDGER / SOURCE_MANIFEST）、任何旧项目日志/源码/测试。
  - 未接触任何禁止来源；未读取旧项目文本、临时文件名或 bundle identifier。

## Changed Files（仅限独占范围）

`Sources/PagingTelemetry/`（4 文件）：

| 文件 | 内容 |
|---|---|
| `PagingTelemetry.swift` | 模块门面 `PagingTelemetry`（App 层最小接线入口）+ `TelemetryConfiguration`（enabled / runID / outputDirectory / fileNamePrefix）+ run ID 净化与自动生成 |
| `TelemetryEvent.swift` | `TelemetryEvent`：17 个必需字段（PHASE1_SPEC §6，全非可选、每行必现）+ 4 个可选扩展字段（transitionToken / staleCallbackFired / interruptSourceOffset / reduceMotionEnabled）+ `PageCacheOutcome` + `TelemetryPhase` 阶段常量（与 ADR-001 语义对齐） |
| `TelemetrySession.swift` | `TelemetrySession`：run 生命周期（begin/record/end/flush）、串行队列线程安全、会话级累计计数（interruption / staleRejection / layout / teardownCallback）写入时统一盖章、文件失败降级为有界内存环形缓冲（10k） |
| `TelemetryArguments.swift` | `TelemetryArguments`：`--paging-telemetry` / `--run-id <id>` 解析 + 帮助文本；参数错误返回 `.failure` 不崩溃；其他参数忽略（归 Worker D） |

`Tests/PagingTelemetryTests/`（4 文件，33 个测试）：

| 文件 | 测试数 | 覆盖 |
|---|---|---|
| `TelemetrySessionTests.swift` | 17 | 默认关闭无输出、开启落盘、JSONL 完整性（17 字段/行）、run ID 隔离、计数盖章、时间戳、异常输入（end 后记录/双 begin/路径穿越 run ID/超长 run ID/极端数值）、文件失败降级、内存缓冲上界、并发写入安全 |
| `TelemetryArgumentsTests.swift` | 11 | 无参数默认关闭、flag 开启、run-id 组合、无关参数忽略、缺值/以 `--` 开头的值 → failure、帮助文本、facade 接线 |
| `TelemetryEventTests.swift` | 5 | snake_case 键稳定、17 键齐全、扩展字段省略/出现、解码往返、阶段常量稳定性 |
| `TestSupport.swift` | — | 共享工具：临时输出目录（测试绝不写 /tmp 正式命名空间）+ 17 字段清单 |

## Per-Criterion Results（任务包验收标准）

| # | 验收标准 | 结果 | 证据 |
|---|---|---|---|
| 1 | `--paging-telemetry` 开关 | ✅ 实现（API + 解析） | `TelemetryArguments.parse`；App 层接线由 Worker D 完成（见 Deviations） |
| 2 | 默认关闭，无参数不产生日志 | ✅ | `testDefaultDisabledProducesNoOutput`、`testDisabledRecordWithoutBeginIsNoOp`；smoke：无参数 → `logPath=telemetry disabled`、recorded=0 |
| 3 | JSONL 输出到 `/tmp/launch-copy-paging-prototype-<run-id>.jsonl` | ✅ | `defaultOutputDirectory = /tmp`；smoke：`logPath=/tmp/launch-copy-paging-prototype-smoke-check-1503.jsonl` |
| 4 | 不使用 Buho 品牌前缀 | ✅ | 前缀固定 `launch-copy-paging-prototype`；源码扫描仅发现规格要求的禁止性注释 |
| 5 | 不记录个人数据 | ✅ | 字段全为数值/ID/时间戳；run ID 为时间戳+随机数；无路径/用户名/设备信息 |
| 6 | 每次正式 run 独立日志文件 | ✅ | 文件名含 run ID；`testRunIDIsolationBetweenSessions` |
| 7 | 日志路径和 run ID 明确输出 | ✅ | `session.runID` + `session.logPathDescription`（供 App 层打印 stdout）；smoke 验证 |
| 8 | 记录全部 17 字段 | ✅ | `testEveryLineCarriesAllSeventeenFields`、`testJSONKeysAreSnakeCaseAndStable` |
| 9 | `--run-id <id>` 可用 | ✅ | 解析 + 净化（路径穿越防御）+ 自动生成兜底 |
| 10 | 参数错误给出帮助，不崩溃 | ✅ | `ParseError` + `helpText()`；`testMissingRunIDValueFailsWithoutCrash` 等 |
| 11 | 无参数可正常打开原型（关闭态） | ✅ | `makeSession` 默认 disabled；无参数 smoke 正常运行 |
| 12 | 不影响 release 默认行为（无大量日志） | ✅ | enabled==false 时 begin/record/end 全 no-op；测试目录为空断言 |

## Verification

```text
# 独立验证包（symlink 指向真实源文件；原因见 Deviations）
cd /tmp/paging-telemetry-standalone

swift build --target PagingTelemetry
→ Build of target: 'PagingTelemetry' complete!
→ exit_code = 0

swift test --filter PagingTelemetryTests
→ Test Suite 'Selected tests' passed
→ Executed 33 tests, with 0 failures (0 unexpected)
→ exit_code = 0

# 端到端 smoke（swift run Smoke，模拟 Worker D 接线；真实 /tmp 输出，验证后已清理）
swift run Smoke --paging-telemetry --run-id smoke-check-1503
→ runID=smoke-check-1503
→ logPath=/tmp/launch-copy-paging-prototype-smoke-check-1503.jsonl
→ recorded=6
→ exit_code = 0

swift run Smoke   # 无参数
→ logPath=telemetry disabled, recorded=0
→ exit_code = 0

# 真实主包构建（见 Deviations）
cd /Users/mac/Projects/Launch_Copy/PagingPrototype && swift build --target PagingTelemetry
→ error: Source files for target PagingCore should be located under 'Sources/PagingCore'
→ exit_code = 1（PagingCore 目录尚未创建，非本模块问题）
```

## Deviations

1. **主包暂不可构建**：`Package.swift` 声明了 `PagingCore` target，但 `Sources/PagingCore/` 尚未由 Worker B 创建，SwiftPM 包加载失败。按任务约束（不得修改 Package.swift、不得写入他人目录），改用 **symlink 独立验证包** `/tmp/paging-telemetry-standalone`（target path 必须是相对路径，故以 symlink 指向真实源文件；构建/测试作用于真实文件，非副本）。主包最终集成构建归 T-step7（Main），届时 PagingCore 已存在即可直接 `swift build --target PagingTelemetry` 复验。独立包可随时重建：`mkdir /tmp/paging-telemetry-standalone && ln -s <repo>/Sources/PagingTelemetry Sources/PagingTelemetry && ln -s <repo>/Tests/PagingTelemetryTests Tests/PagingTelemetryTests`（Package.swift 内容见本文件下方）。
2. **CLI 参数接线在 App 层**：`--paging-telemetry` / `--run-id` 的**最终解析执行**由 Worker D（PagingPrototypeApp）完成；本模块提供解析 API（`TelemetryArguments.parse`）、帮助文本（`helpText`）、门面（`PagingTelemetry.makeSession(arguments:)`）与 run 生命周期。任务包验收 1/9/10 在模块层面已由测试覆盖，App 层接线为 Worker D 的待办（T-worker-d 任务包已含 §10 参数要求）。
3. **文件打开失败降级语义**：目录创建/文件打开失败时降级为有界内存缓冲（10k 事件），`logPathDescription` 明确标注 degraded；`end()` 在降级模式下仍将 run.end 写入内存缓冲（计数口径统一）。

## Memory Candidates（供 Main / Reviewer 参考）

- 独立验证包重建方法（见 Deviations 1）。
- `TelemetryArguments` 帮助文本应并入 Worker D 的全局帮助输出。
- 输出文件使用 `sortedKeys` 稳定排序，便于 diff 与脚本消费。
- 会话级计数由 session 统一盖章，UI 层无需自行维护计数一致性。

## 待办 / 边界（不属于本任务）

- Worker D：App 层解析接线 + stdout 打印 run ID/日志路径。
- Main（T-step7）：主包集成构建与全量测试。
- Reviewer E：独立验收审查（禁止自我认证 PASS——本结果仅为实现报告）。

---

### 附：独立验证包 Package.swift（重建用，不属于交付物）

```swift
// swift-tools-version: 5.9
import PackageDescription
let package = Package(
    name: "PagingTelemetryStandalone",
    platforms: [.macOS(.v14)],
    targets: [
        .target(name: "PagingTelemetry"),
        .testTarget(name: "PagingTelemetryTests", dependencies: ["PagingTelemetry"]),
    ]
)
```

---

## Main 验证备注（2026-08-28 15:05）

- **主包复验（dir 修复后）**：`swift build --target PagingTelemetry` → exit 0；`swift test --filter PagingTelemetryTests` → 33 tests, 0 failures, exit 0（主包直接验证，不再依赖 symlink 独立包）。
- **根因说明**：此前主包报"PagingUI 缺源目录"是因为 `Sources/PagingUI`、`Sources/PagingPrototypeApp`、`Tests/PagingUITests` 目录尚未创建（SwiftPM 对缺失目录报错、对存在的空目录容忍）。Main 已补建空目录（未写任何文件），Worker D 独占范围不受影响。
- **来源扫描**：PagingTelemetry/PagingTelemetryTests 无 Buho/LaunchBetter/2026-08-25/reverse 字样（唯一匹配为规格要求的禁止性注释），无 `/Users/mac/Projects` 绝对路径。
- **Main 判定**：T-worker-c PASSED（验收标准 12/12 满足；App 层接线归 Worker D 属计划内）。
