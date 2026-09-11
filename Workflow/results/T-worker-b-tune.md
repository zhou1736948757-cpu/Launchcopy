# T-worker-b-tune — momentum 物理调参工具（--momentum-decay）

**Worker**: B/D 同人（PagingCore + App 双上下文）
**来源**: 物理门复测 #3 用户反馈（原话）：**"我觉得惯性有点太大了，就是惯性的时间有点太长。"**
**日期**: 2026-08-28
**Scope**: `Sources/PagingPrototypeApp/`（AppArguments + AppParameters 新文件 + AppDelegate 接线 + AppMain exit 2）、`Tests/PagingUITests/`（AppArgumentsTests 扩展 + AppParametersTests 新文件）、`Workflow/results/T-worker-b-tune.md`
**未触碰**: Package.swift / Docs / PROVENANCE / Workflow（结果文件除外）/ **PagingCore** / PagingTelemetry / PagingUI
**AccessDeclaration: NO_PRIOR_EXPOSURE**（重申：未读取 §1.3 禁止路径与治理文档；本任务零外部来源接触）

---

## 参数与试值

- `momentumDecay` 默认 0.95（范围 0.8–0.99），来源类别 **INDEPENDENT_EXPERIMENT**，
  `Docs/PARAMETER_RATIONALE.md:20` 标 **TUNING_REQUIRED** → 本次进入真实物理调参阶段。
- 试值 **0.85**：每帧衰减 15%（vs 当前 5%），惯性滑行时长显著缩短；快甩翻页判定
  （velocityThreshold=800px/s 强制翻页）不受影响——衰减只作用于 glide 期间，决策在
  momentumEnded 时已用释放速度做出。
- glide 停止阈值 = velocityThreshold×5%（Worker B 偏差 #5 实现，40px/s @800px/s）不变——
  0.85 下速度衰减更快到达停止阈值，滑行时间更短（目标达成）。

## 实现（最小侵入，零 Core 改动）

1. **`Sources/PagingPrototypeApp/AppArguments.swift`**：
   - `Options.momentumDecay: Double?`（缺省 nil → 用 PagingParameters 默认 0.95）；
   - `--momentum-decay <0.80–0.99>`：合法范围 0.80–0.99（与 PagingParameters 声明一致）；
     越界/非数字/缺值 → `.failure(.invalidMomentumDecay(raw))`；
   - 帮助文本补 `--momentum-decay` 行。
2. **`Sources/PagingPrototypeApp/AppParameters.swift`（新）**：`AppParameters.make(momentumDecay:)`
   构造 PagingParameters——nil 保持默认 0.95，有值则覆盖；可单测的接线唯一入口。
3. **`Sources/PagingPrototypeApp/AppDelegate.swift`**：PagingSurface 构造传入
   `parameters: AppParameters.make(momentumDecay: options.momentumDecay)`。
   **接线结论：不需要动 PagingCore**——`PagingParameters` 全 public var + `public init()`，
   `PagingSurface.init` 本就接受 `parameters:`（PagingUI），App 层组合即可。
4. **`Sources/PagingPrototypeApp/AppMain.swift`**：`.invalidMomentumDecay` 失败 → 打印错误+帮助后
   **exit(2)**（调参参数非法必须显式失败，静默回退默认值会掩盖错误试值）；其余参数错误保持
   既有"打印帮助继续启动"约定不变。

## 测试（+5：AppArgumentsTests +2、AppParametersTests 新 3）

| 测试 | 断言 |
|---|---|
| `testMomentumDecayParsed` | 0.85 → 0.85；边界 0.80/0.99 通过；缺省 nil |
| `testMomentumDecayOutOfRangeFails` | 1.5 / 0.79 / 1.0 / 0.5 / abc / 缺值 / "0,85" → 全部失败（exit 2 路径） |
| `testMomentumDecayOverrideApplied` | `make(0.85).momentumDecay == 0.85`（覆盖生效） |
| `testBoundaryValuesApplied` | 0.80 / 0.99 传入生效 |
| `testNilKeepsCoreDefault` | `make(nil).momentumDecay == 0.95`（Core 默认不改） |

另：`testHelpTextIsNonEmpty` 扩展断言帮助文本含 `--momentum-decay`。

## Verification（命令 + 退出码）

| 命令 | 结果 |
|---|---|
| `swift build`（全包） | exit 0（0 warning） |
| `swift test --filter "AppArgumentsTests\|AppParametersTests"` | 17 tests, 0 failures, exit 0 |
| `swift test`（全量） | **156 tests, 0 failures**（151 → +5），exit 0 |
| `swift run -c release PagingPrototypeApp --help 2>&1 \| grep momentum-decay` | 命中帮助行，exit 0 |
| `swift run -c release PagingPrototypeApp --momentum-decay 1.5` | **exit 2**（打印错误+帮助，不崩溃、不开窗） |
| `swift run -c release PagingPrototypeApp --momentum-decay abc` | **exit 2** |
| `PAGING_PROTOTYPE_SMOKE=1 .build/release/PagingPrototypeApp --momentum-decay 0.85` | parse OK, exit 0（完整入口路径） |

## Changed Files

| 文件 | 变更 |
|---|---|
| `Sources/PagingPrototypeApp/AppArguments.swift` | +`momentumDecay` 选项（范围校验/帮助/错误 case） |
| `Sources/PagingPrototypeApp/AppParameters.swift` | 新：App 参数 → PagingParameters 接线（单测入口） |
| `Sources/PagingPrototypeApp/AppDelegate.swift` | PagingSurface 传 `parameters:`（调参接线） |
| `Sources/PagingPrototypeApp/AppMain.swift` | invalidMomentumDecay → 打印帮助 + exit 2 |
| `Tests/PagingUITests/AppArgumentsTests.swift` | +2 解析测试 + 帮助文本断言 |
| `Tests/PagingUITests/AppParametersTests.swift` | 新：3 个接线覆盖测试 |
| `Workflow/results/T-worker-b-tune.md` | 本文件 |

## Deviations

1. **exit 2 仅限 momentum-decay 参数错误**：其余参数错误保持既有"打印帮助继续正常启动"
   约定（AppArguments 头注 + AppMain 行为不变）——任务只要求调参参数显式失败，避免改变
   已文档化/已测试的宽松行为。
2. **未固化默认值**：试值 0.85 经 CLI 传入，不改 `PagingParameters` 默认 0.95（任务要求；
   调参确认后再固化 Core 默认，届时 PagingParameters.swift 一处）。
3. **接线零 Core 改动**（无需报告 Main）：`PagingParameters` 全 public var + `public init()` +
   `PagingSurface.init(parameters:)` 已存在——App 层 `AppParameters.make` 组合即可。
4. **诚实记录**：用户反馈原文、试值 0.85、来源类别 INDEPENDENT_EXPERIMENT、
   TUNING_REQUIRED → 物理调参中（尚未产生验证结果列）；试值是否保留由用户复测决定。

## Memory Candidates

- `momentumDecay` 只影响 glide 阶段（momentumEnded 已定决策）→ 调衰减系数不改变翻页判定，
  只改变惯性时长——物理调参的独立旋钮。
- App 层调参接线模式：CLI 可选值 → Options（Double?，nil=Core 默认）→ AppParameters.make →
  PagingSurface(parameters:)——零 Core 改动，试值确认后才固化。
- 参数错误策略分层：一般参数错误宽松（打印帮助继续），调参参数显式失败（exit 2 防静默掩盖）。
