# T-A4 — 生产默认 Timer.tolerance 改为 4ms(用户决策调参轮)

- 类型: 调参 Worker(用户决策后)
- 依赖: Phase 2 `decision_recorded`(已记录: 选 4ms,能耗可接受)
- 依据: Docs/FRAME_LAG_FIX_PLAN.md §9
- 唯一允许的产品行为变化: 缺省 `Timer.tolerance` 从 `1.0/120.0`(8.333ms)改为 **4ms = `0.004`**。CLI `--frame-timer-tolerance-ms` 仍可用,合法范围仍 0–16.667。

## 预期写入范围
| 文件 | 做什么 |
|---|---|
| `Sources/PagingUI/PagingFrameDriver.swift` | `init` 默认 `tolerance:` 改为 0.004 |
| `Sources/PagingPrototypeApp/AppDelegate.swift` | `?? (1.0 / 120.0)` 改为新默认(0.004) |
| `Tests/PagingUITests/RunLoopFrameDriverTests.swift` | 若有断言默认 1/120,改为新值;CLI 边界测试不动 |
| `Docs/PARAMETER_RATIONALE.md` | 新增平台参数行: 默认值 4ms、范围 0–16.667、来源 `PRODUCT_DECISION`、理由(T-A1/T-A2)、验证状态 `TUNING_REQUIRED` 直到 T-A5 PASS |
| `MEMORY.md`(项目根或 ~/MEMORY.md) | 默认值事实;诊断 token |
| `Docs/IMPLEMENTATION_LOG.md` | 一行变更记录 |

## 禁止树
`Sources/PagingCore/`、`Package.swift`、`AppLaunchController.swift`、DisplayLink 观测器改成驱动、telemetry schema。无 git commit。

## 诊断 token(改默认之后)
```text
CAUSALITY_UNRESOLVED                  # 长尾仍在
PARTIAL_CONTRIBUTOR_SUPPORTED
PRODUCT_TIMER_TOLERANCE_4MS
REQUIRE_PHYSICAL_AB_BEFORE_TIMER_TOLERANCE_DEFAULT_CHANGE   # T-A5 完成前保留
```
**禁止** `ALL_HITCHES_FIXED` / `FIX_VALIDATED` / `ROOT_CAUSE_FOUND` / `SHORT_TAIL_MITIGATED_BY_TOLERANCE`(后者仅 T-A5 通过后)。

## Worker 验收
- `swift test` 全绿(executed>0)。
- `swift build -c debug` / `-c release` exit 0。
- 禁止树 hash/mtime 未改。
- 不传 CLI 时 stdout/代码路径确为新默认(4ms)。
- 无 git commit。

## Reviewer 焦点
- 是否只改了默认 tolerance,有没有顺手改帧源/Core。
- 文档与代码一致。
- 有没有把长尾写成已修。
- 隐私、无全局 monitor。
