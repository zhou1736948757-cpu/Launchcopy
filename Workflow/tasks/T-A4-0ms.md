# T-A4-0ms — 生产默认 Timer.tolerance 改为 0ms(决策修订轮)

- 类型: 调参 Worker(用户决策修订后)
- 依赖: Phase 2 `decision_recorded` 修订(已记录: 4ms → **0ms**,能耗可接受)
- 依据: Docs/FRAME_LAG_FIX_PLAN.md §9;T-A4-r1 已 PASS(4ms),现按用户修订改 0ms
- 唯一允许的产品行为变化: 缺省 `Timer.tolerance` 从 `0.004`(4ms)改为 **0ms = `0`**。CLI `--frame-timer-tolerance-ms` 仍可用,合法范围仍 0–16.667。

## 预期写入范围
| 文件 | 做什么 |
|---|---|
| `Sources/PagingUI/PagingFrameDriver.swift` | `init` 默认 `tolerance:` 0.004 → 0 |
| `Sources/PagingPrototypeApp/AppDelegate.swift` | `?? 0.004` → `?? 0`;SELFDRIVE print `?? 4.0` → `?? 0.0` |
| `Sources/PagingPrototypeApp/FrameDriverExperiment.swift` | **T-A4-r1 MINOR-1**: 潜在活默认 `1.0 / 120.0`(:130)→ 0(与生产默认一致) |
| `Sources/PagingPrototypeApp/AppArguments.swift` | **T-A4-r1 MINOR-2**: :27/:98/:325 过期注释与 --help 默认值 8.333ms → 0ms |
| `Tests/PagingUITests/RunLoopFrameDriverTests.swift` | 若有断言默认,改为 0;CLI 边界测试不动 |
| `Docs/PARAMETER_RATIONALE.md` | 平台参数行 `timerTolerance` 更新: 默认 0ms(修订),来源 `PRODUCT_DECISION`,验证状态 `TUNING_REQUIRED` 直到 T-A5 PASS |
| `MEMORY.md`(项目根或 ~/MEMORY.md) | token `PRODUCT_TIMER_TOLERANCE_4MS` → `PRODUCT_TIMER_TOLERANCE_0MS`;**T-A4-r1 MINOR-3**: :118 过期红线「不改生产默认 8.333ms」更新为 0ms 事实 |
| `Docs/IMPLEMENTATION_LOG.md` | 追加一行: 默认 tolerance 4ms → 0ms(T-A4-0ms, 2026-08-30) |

## 禁止树
`Sources/PagingCore/`、`Package.swift`、`AppLaunchController.swift`、DisplayLink 观测器改成驱动、telemetry schema。无 git commit。

## 诊断 token(改默认之后)
```text
CAUSALITY_UNRESOLVED                  # 长尾仍在
PARTIAL_CONTRIBUTOR_SUPPORTED
PRODUCT_TIMER_TOLERANCE_0MS
REQUIRE_PHYSICAL_AB_BEFORE_TIMER_TOLERANCE_DEFAULT_CHANGE   # T-A5 完成前保留
```
**禁止** `ALL_HITCHES_FIXED` / `FIX_VALIDATED` / `ROOT_CAUSE_FOUND` / `SHORT_TAIL_MITIGATED_BY_TOLERANCE`(后者仅 T-A5 通过后)。

## Worker 验收
- `swift test` 全绿(executed>0)。
- `swift build -c debug` / `-c release` exit 0。
- 禁止树 hash/mtime 未改。
- 不传 CLI 时 stdout/代码路径确为新默认(0ms)。
- 无 git commit。

## Reviewer 焦点
- 是否只改了默认 tolerance(含 3 个 MINOR 一致性点),有没有顺手改帧源/Core。
- 文档与代码一致。
- 有没有把长尾写成已修。
- 隐私、无全局 monitor。
