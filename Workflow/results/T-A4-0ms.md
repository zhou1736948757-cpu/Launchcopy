# T-A4-0ms — 生产默认 Timer.tolerance 4ms → 0ms

**任务**: 将生产默认 `Timer.tolerance` 从 `0.004`（4ms）改为 **0ms = `0`**。唯一允许的产品行为变更，外加 3 项文档/潜在默认一致性修复（T-A4-r1 MINOR-2 / MINOR-3）。

**执行人**: Worker（chef-worker-reviewer-workflow）
**日期**: 2026-08-30

---

## 1. 文件级变更

| 文件 | 变更 |
|---|---|
| `Sources/PagingUI/PagingFrameDriver.swift` | `init` 默认参数 `tolerance: TimeInterval = 0.004` → `tolerance: TimeInterval = 0`。同步更新两处注释（`tolerance` 属性 doc 与 `timer.tolerance = tolerance` 行）中"生产默认 4ms（PRODUCT_TIMER_TOLERANCE_4MS，T-A4）"→"生产默认 0ms（PRODUCT_TIMER_TOLERANCE_0MS，T-A4-0ms）"。 |
| `Sources/PagingPrototypeApp/AppDelegate.swift` | ① 帧驱动装配默认 `?? 0.004` → `?? 0`（秒）；② SELFDRIVE 打印默认 `?? 4.0` → `?? 0.0`（ms）；③ 同步更新 A/B 注释"生产默认 4ms（T-A4）"→"生产默认 0ms（T-A4-0ms）"。 |
| `Sources/PagingPrototypeApp/FrameDriverExperiment.swift` | 潜在 live 默认 `frameTimerTolerance: TimeInterval = 1.0 / 120.0`（8.333ms，运行时永不命中——AppDelegate 恒传值）→ `frameTimerTolerance: TimeInterval = 0`。消除任何残留的 live 8.333ms 默认。 |
| `Sources/PagingPrototypeApp/AppArguments.swift` | 三处过期 8.333ms 文案更新为 0ms：① 头部注释（:26–27）"缺省 8.333ms（保留 Phase 1A 行为）"→"缺省 0ms（nil 解析为 0ms）"；② `frameTimerToleranceMS` 属性 doc（:98）"nil = 保留默认 8.333ms"→"nil = 0ms"；③ `--help` 文本（:325–326）"缺省 8.333ms"→"缺省 0ms"。**CLI 合法范围（0–16.667）与解析行为未改。** |
| `Tests/PagingUITests/RunLoopFrameDriverTests.swift` | **无改动**。该文件无任何"默认 tolerance"断言（测试用显式值 0/9 或使用默认但不断言其值）；CLI 边界测试（显式值）按要求未触碰。 |
| `Docs/PARAMETER_RATIONALE.md` | `timerTolerance` 平台参数行：默认值 `4 ms` → `0 ms`；来源类别保持 `PRODUCT_DECISION`；理由更新为"由 4ms 改为 0ms（决策修订 2026-08-30，T-A4-0ms）"；验证状态保持 `TUNING_REQUIRED`（自动化 baseline 通过；物理门待 T-A5 物理验收 PASS）。 |
| `MEMORY.md` | ① Confirmed decisions：token `PRODUCT_TIMER_TOLERANCE_4MS` → `PRODUCT_TIMER_TOLERANCE_0MS`，`Timer.tolerance = 4ms` → `0ms`（T-A4-0ms，2026-08-30）；长尾 >25ms 仍 `CAUSALITY_UNRESOLVED` 保留。② :118 过期红线"不改生产默认 `Timer tolerance = 8.333ms`"→"不改生产默认 `Timer tolerance = 0ms`"。 |
| `Docs/IMPLEMENTATION_LOG.md` | 追加一行：生产默认 `Timer.tolerance` 4ms → 0ms（T-A4-0ms，2026-08-30）。 |

## 2. 精确新默认值

- `RunLoopFrameDriver.init(tolerance:)` 默认 = **`0`**（0ms）。
- `AppDelegate` 帧驱动装配默认（`frameTimerToleranceMS == nil` 时）= **`0`**（秒）。
- `AppDelegate` SELFDRIVE 打印默认 = **`0.0`**（ms）。
- `DisplayLinkFrameDriver.init(frameTimerTolerance:)` 潜在默认 = **`0`**。
- CLI `--frame-timer-tolerance-ms` 合法范围保持 **0–16.667**，解析行为未改。

## 3. 测试结果

- `swift test`：**631 tests, 0 failures**（`Executed 631 tests, with 0 failures`），exit 0。
- 注：swift-testing 块报告 "0 tests in 0 suites"（`◇ Test run with 0 tests in 0 suites passed`）——按任务约定忽略，以 XCTest 的 "Executed 631 tests" 为准。

## 4. 构建结果

| 命令 | 退出码 |
|---|---|
| `swift build -c debug` | **0** |
| `swift build -c release` | **0** |

## 5. 禁止树验证（mtime 前后对比）

| 文件 | before | after | 未变 |
|---|---|---|---|
| `Package.swift` | 1787917375 | 1787917375 | ✓ |
| `Sources/PagingPrototypeApp/AppLaunchController.swift` | 1787921214 | 1787921214 | ✓ |
| `Sources/PagingCore/PagingState.swift` | 1787897056 | 1787897056 | ✓ |
| `Sources/PagingCore/TransitionContext.swift` | 1787900304 | 1787900304 | ✓ |
| `Sources/PagingCore/GestureSession.swift` | 1787903342 | 1787903342 | ✓ |
| `Sources/PagingCore/PagingCore.swift` | 1787905826 | 1787905826 | ✓ |
| `Sources/PagingCore/PageTargetPolicy.swift` | 1788005795 | 1788005795 | ✓ |
| `Sources/PagingCore/PagingParameters.swift` | 1788057962 | 1788057962 | ✓ |

## 6. Grep 验证（无残留 live 默认）

在 `PagingFrameDriver.swift` / `AppDelegate.swift` / `FrameDriverExperiment.swift` 中 grep `0.004`、`1.0/120.0`、`1_000.0/120.0`：**0 命中**。Sources 全树 grep `8.333` / `4ms` / `PRODUCT_TIMER_TOLERANCE_4MS`：**0 命中**。

## 7. Git 状态

- 无 commit/push/tag（分支 `main` 尚无任何 commit）。
- 无 staged/modified tracked 文件（全部 untracked，与任务前一致）。

## 8. 未宣称项

- 未宣称长尾已修复；未写 `ALL_HITCHES_FIXED` / `FIX_VALIDATED` / `ROOT_CAUSE_FOUND` / `SHORT_TAIL_MITIGATED_BY_TOLERANCE`。
- 长尾 >25ms 仍 `CAUSALITY_UNRESOLVED`（MEMORY.md 保留）。

## 9. 偏差

- 无偏差。`RunLoopFrameDriverTests.swift` 因无默认 tolerance 断言而未改动（符合"if it asserts a default tolerance"条件）；`AppArgumentsTests.swift`（CLI 解析测试，含过期断言消息）按要求未触碰。
