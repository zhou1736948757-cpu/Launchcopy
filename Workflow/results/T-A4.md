# T-A4 — 生产默认 Timer.tolerance 8.333ms → 4ms

**Worker**: worker-a（T-A4）
**任务**: 将生产默认 `Timer.tolerance` 从 `1.0/120.0`（8.333ms）改为 **4ms = `0.004`**。唯一允许的产品行为变更。
**日期**: 2026-08-30
**决策依据**: 用户书面决策（T-A1 梯度 + T-A2 用户 A/B，2026-08-30）
**AccessDeclaration: NO_PRIOR_EXPOSURE**（未读取 `/Users/mac/Projects/BuhoReverseNotes/`、`/Users/mac/Projects/LaunchBetter/`、`2026-08-25-buho-launchpad-reverse` 任何内容；仅依据本任务说明、Apple 公开文档与本工程自身文件）

---

## 一、变更（file-by-file）

| 文件 | 变更 |
|---|---|
| `Sources/PagingUI/PagingFrameDriver.swift` | `init` 默认参数 `tolerance: TimeInterval = 1.0 / 120.0` → `tolerance: TimeInterval = 0.004`（4ms）。同步更新两处注释（`tolerance` 属性 doc 与 `timer.tolerance = tolerance` 行）中"缺省 8.333ms"为"生产默认 4ms（T-A4）"。 |
| `Sources/PagingPrototypeApp/AppDelegate.swift` | ① 帧驱动装配默认 `?? (1.0 / 120.0)` → `?? 0.004`（秒）；② SELFDRIVE 打印默认 `?? (1_000.0 / 120.0)` → `?? 4.0`（ms）；③ 同步更新 A/B 注释"缺省保留 Phase 1A 的 8.333ms"→"生产默认 4ms（T-A4）"。 |
| `Tests/PagingUITests/RunLoopFrameDriverTests.swift` | **无改动**。该文件仅断言显式传入值（`tolerance: 0`、`tolerance: 9` 的 clamp），未断言默认值；CLI 边界测试传显式值，未触碰。 |
| `Docs/PARAMETER_RATIONALE.md` | §3 平台参数表新增一行 `timerTolerance`：默认 4ms、合法范围 0–16.667ms、来源 `PRODUCT_DECISION`、理由（T-A1 梯度 + T-A2 用户 A/B，2026-08-30；范围与 CLI `--frame-timer-tolerance-ms` 一致）、验证 `TUNING_REQUIRED`（物理门待 T-A5 物理验收 PASS）。 |
| `MEMORY.md` | "Confirmed decisions" 新增事实：生产默认 `Timer.tolerance = 4ms`（`PRODUCT_TIMER_TOLERANCE_4MS`，T-A4，2026-08-30）；长尾 >25ms 仍 `CAUSALITY_UNRESOLVED`，不宣称已修复。 |
| `Docs/IMPLEMENTATION_LOG.md` | 追加一行：生产默认 `Timer.tolerance` 8.333ms → 4ms（T-A4，2026-08-30）。 |

**新默认值**: `0.004`（4ms）

---

## 二、验收标准逐项结果

| 验收标准 | 结果 |
|---|---|
| `swift test` 全绿且 executed tests > 0 | ✅ **631 tests, 0 failures**（`Executed 631 tests, with 0 failures (0 unexpected)`；忽略 swift-testing 的 "0 tests in 0 suites"） |
| `swift build -c debug` exit 0 | ✅ exit 0（Build complete! 4.06s） |
| `swift build -c release` exit 0 | ✅ exit 0（Build complete! 11.34s） |
| 禁止树未变 | ✅ 见下节 mtime 前后对比 |
| 无 CLI flag 时走新默认 4ms | ✅ grep 确认 driver/AppDelegate 无残留 `1.0 / 120.0` / `1_000.0 / 120.0` 默认；driver 默认 `0.004`、AppDelegate `?? 0.004` / `?? 4.0` |
| 无 git commit | ✅ 未执行任何 git 操作；本仓库无任何 commit（`git log` exit 128） |

---

## 三、禁止树验证（mtimes 前后一致）

| 文件 | mtime（前） | mtime（后） |
|---|---|---|
| `Sources/PagingCore/PagingState.swift` | 1787897056 | 1787897056 |
| `Sources/PagingCore/TransitionContext.swift` | 1787900304 | 1787900304 |
| `Sources/PagingCore/GestureSession.swift` | 1787903342 | 1787903342 |
| `Sources/PagingCore/PagingCore.swift` | 1787905826 | 1787905826 |
| `Sources/PagingCore/PageTargetPolicy.swift` | 1788005795 | 1788005795 |
| `Sources/PagingCore/PagingParameters.swift` | 1788057962 | 1788057962 |
| `Package.swift` | 1787917375 | 1787917375 |
| `Sources/PagingPrototypeApp/AppLaunchController.swift` | 1787921214 | 1787921214 |

全部一致，未触碰。`Sources/PagingCore/`、`Package.swift`、`AppLaunchController.swift` 均未修改。

---

## 四、未触碰 / 未宣称

- 未触碰 `Sources/PagingCore/`（任何文件）、`Package.swift`、`Sources/PagingPrototypeApp/AppLaunchController.swift`。
- 未改 DisplayLink observation → driving 转换、telemetry schema。
- 未改 CLI `--frame-timer-tolerance-ms` 行为或其合法范围（0–16.667ms）。
- 未宣称长尾已修复；未写 `ALL_HITCHES_FIXED` / `FIX_VALIDATED` / `ROOT_CAUSE_FOUND` / `SHORT_TAIL_MITIGATED_BY_TOLERANCE`。长尾 >25ms 保持 `CAUSALITY_UNRESOLVED`；`timerTolerance` 验证状态 `TUNING_REQUIRED` 直至 T-A5 物理验收 PASS。

---

## 五、结论

生产默认 `Timer.tolerance` 已从 8.333ms（`1.0/120.0`）改为 **4ms（`0.004`）**，为本次唯一产品行为变更。631 测试全绿、debug/release 构建 exit 0、禁止树 mtime 未变、无 git 操作。CLI 显式参数路径与合法范围保持不变。
