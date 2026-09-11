# T-worker-b-glide — momentum 系统流截断（momentumGlideFrames）

**Worker**: B/D 同人（PagingCore + PagingPrototypeApp）
**来源**: 物理调参第 3 轮，用户反馈（原话）："那这样吧，你把这个滑时间就改成一帧，行不？"
**日期**: 2026-08-28
**Scope**: `Sources/PagingCore/`（PagingParameters + PagingCore + GestureSession）、`Sources/PagingPrototypeApp/`（AppArguments + AppParameters + AppDelegate + AppMain）、`Tests/PagingCoreTests/`、`Tests/PagingUITests/`、`Workflow/results/T-worker-b-glide.md`
**未触碰**: Package.swift / Docs / PROVENANCE / Workflow（结果文件除外）/ PagingTelemetry / PagingUI
**AccessDeclaration: NO_PRIOR_EXPOSURE**（重申）

---

## 根因（Main 分析，telemetry 证据复读）

- 真实触控板松手后系统仍发大量 momentum 事件流：phys-auto-02 实测 **433 个 momentum 事件 / 13 手势 ≈ 每次 ~33 个 ≈ 0.5s+**——Core 跟随整个系统惯性流 = 用户感知"滑行太长"的主因。
- 前两轮 `momentumDecay` 调参（0.95→0.85→0.55）只影响系统流**结束后**的 Core glide 段；系统流阶段不受 decay 控制 → 用户仍觉太长。**正确修复 = 截断系统 momentum 流**。
- 复用先例：RM（D8）momentum 降级 = 不做惯性滑行直接决策——本任务把该机制**参数化**。

## 截断机制（事件计数；确定性理由）

**实现**：`momentumGlideFrames: Int?`（来源类别 PRODUCT_DECISION；物理调参中）：
- `nil` = 跟随完整系统流（现行为；默认，用户试值确认前不改）；
- `0` = momentumBegan 即释放决策（=RM 降级效果：无惯性滑行，直接回弹/翻页/吸住）；
- `N`（1–10）= 最多跟随 **2N 个 momentumChanged 事件**后释放决策（N=1 → 第 2 个事件后决策）。

**用户复测试值 = 10**（补充：Main 转达用户"甩动后最多 10 帧，应该也就是 0.1 秒"）：N=10 → 第 20 个
momentumChanged 事件后决策。**时长诚实换算**：20 事件按真实事件率（phys-auto-02 ≈66Hz）≈ **0.3s**
系统流跟随（66–120Hz 下 0.17–0.3s）——可能长于用户"0.1s"心智模型（0.1s ≈ 6–10 事件）；旋钮是
事件计数线性映射，复测若仍偏长可按 2N/1N 映射或降 N 线性缩短（见 Deviations 4）。

**事件计数 vs 时间戳的理由**：选事件计数——(1) 确定性：测试可复现序列直接驱动，不受真实时钟/调度影响（与速度窗口估计同一原则）；(2) 帧映射：60Hz 帧 ≈ 1–2 事件（phys-auto-02 ≈66Hz ≈1.1 事件/帧），2 事件是"1 帧"的确定性安全上界（任务包允许"约 1 帧/≤2 个 momentumChanged 事件"）；(3) 无时钟分辨率/回拨顾虑（D5 时间回拨防御已有，但计数不依赖它）。

**截断点决策**：`finishGesture`（与 momentumEnded 非滑行分支同一决策路径：位移/速度 → 回弹/翻页/吸住 → beginSettle，无跳变）；momentumChanged 计数在 GestureSession（`momentumChangedCount`，beginMomentum 归零）。**无双重 commit**：截断后 state 离开 tracking → 系统后续 momentum 事件被 handleMomentum* 的 guard 防御拒绝（D3/D5），commit 至多 1 次。

**RM 强制 0（D8 行为不变）**：RM 下截断逻辑不生效——RM 路径保持既有事件流（决策点仍在 momentumEnded，不做惯性滑行）。理由：既有 RM 测试（testReduceMotionMomentumStillTurnsPage）断言 momentumEnd 为决策点，且 D8 降级语义为文档化行为；"强制 0" = RM 用户效果等价（无惯性滑行），实现不改变 RM 行为。新增测试 testMomentumGlideFramesIgnoredUnderReduceMotion 固化该语义。

## CLI 与接线

- `--momentum-glide-frames <0–10>`（可选；缺省 nil）：AppArguments 解析（越界/非数字/缺值 → `.invalidMomentumGlideFrames` → AppMain 打印帮助 + **exit 2**，不静默回退）；帮助文本补行。
- `AppParameters.make(momentumDecay:momentumGlideFrames:)`（签名扩展）→ AppDelegate → `PagingSurface(parameters:)`（PagingUI 已有参数口，零 UI 改动）。

## 测试（+7：Core 4、AppArguments 2、AppParameters 1）

| 测试 | 断言 |
|---|---|
| `testMomentumGlideFramesOneTruncatesLongStream` | N=1：第 1 事件仍 tracking；第 2 事件后 → settling；后续事件全拒绝；settle 后 commit 恰 1 次（无双重 commit）、stale 0 |
| `testMomentumGlideFramesZeroDirectDecision` | N=0：momentumBegan 即 settling；后续事件拒绝；commit 1 |
| `testMomentumGlideFramesNilFollowsFullStream` | nil：10 事件后仍 tracking（不截断）；决策点仍在 momentumEnded（20px/s ≤ 40 停止阈值 → 直接决策 settle） |
| `testMomentumGlideFramesIgnoredUnderReduceMotion` | RM + N=1：momentum 流照常跟随、momentumEnd 决策、即刻提交、无 glide（D8 不变） |
| `testMomentumGlideFramesTenTruncatesAtTwentyEvents` | N=10（用户复测试值）：第 19 事件仍跟随、第 20 事件后 settle；后续拒绝；commit 恰 1 次、stale 0 |
| `testMomentumGlideFramesParsed` | 0/1/10 合法；缺省 nil |
| `testMomentumGlideFramesOutOfRangeFails` | 11 / -1 / abc / 1.5 / 缺值 → 全部失败 |
| `testMomentumGlideFramesOverrideApplied` | 接线 1/0/10 生效；nil 保持 Core 默认（momentumGlideFrames nil） |

## Verification（命令 + 退出码）

| 命令 | 结果 |
|---|---|
| `swift build`（debug + release） | exit 0（0 warning） |
| `swift test`（全量） | **164 tests, 0 failures**（156 → +8），exit 0 |
| `.build/release/PagingPrototypeApp --help \| grep momentum-glide-frames` | 命中帮助行 |
| `--momentum-glide-frames 11` / `abc` | **exit 2**（打印帮助，不崩溃） |
| `--momentum-glide-frames 1` / `10`（用户复测试值） | 窗口正常打开（3s 存活 → 手动 kill） |

## Changed Files

| 文件 | 变更 |
|---|---|
| `Sources/PagingCore/PagingParameters.swift` | +`momentumGlideFrames: Int?`（文档注释含语义/RM/来源） |
| `Sources/PagingCore/GestureSession.swift` | +`momentumChangedCount` + `noteMomentumChanged()`（beginMomentum 归零） |
| `Sources/PagingCore/PagingCore.swift` | handleMomentumBegan（N=0 直接决策）+ handleMomentumChanged（2N 截断 → finishGesture） |
| `Sources/PagingPrototypeApp/AppArguments.swift` | +`--momentum-glide-frames`（解析/错误 case/帮助） |
| `Sources/PagingPrototypeApp/AppParameters.swift` | make 签名扩展 |
| `Sources/PagingPrototypeApp/AppDelegate.swift` | 接线 + 注释 |
| `Sources/PagingPrototypeApp/AppMain.swift` | invalidMomentumGlideFrames → exit 2 |
| `Tests/PagingCoreTests/PagingCoreTests.swift` | +5 截断测试（N=1/0/nil/RM/N=10） |
| `Tests/PagingUITests/AppArgumentsTests.swift` | +2 解析测试 + 帮助文本断言 |
| `Tests/PagingUITests/AppParametersTests.swift` | 签名更新 + 接线覆盖 |
| `Workflow/results/T-worker-b-glide.md` | 本文件 |

## Deviations

1. **RM 语义落点**：任务"RM 强制 0"实现为"RM 下参数不生效、D8 行为不变"（决策点仍在 momentumEnded），
   而非把 RM 路径改为 momentumBegan 决策——后者会破坏既有 RM 测试与 D8 文档语义；效果等价（无惯性滑行）。
2. **测试 1 首版失败 1 次**：nil 测试初用 10px/0.05s momentum 样本（速度 200px/s > 停止阈值 40 →
   momentumEnd 进入 glide 而非 settle）；改用 1px/0.05s（20px/s ≤ 40）保证决策确定性——行为本身正确，
   断言场景修正。
3. **Docs/PARAMETER_RATIONALE.md 参数表回填**：本任务禁写 Docs；momentumGlideFrames 行（来源
   PRODUCT_DECISION、物理调参中、试值确认后固化）由 Main/后续波补录。
4. **未固化默认值 + 试值变更**：nil 保持现行为；试值经 Main 补充从 1 改为 **10**（范围 0–10 不变，零代码改动，
   仅新增 N=10 边界测试）。2N 事件映射的时长诚实标注（20 事件 ≈ 0.17–0.3s @66–120Hz，可能长于用户"0.1s"）
   已记入机制节；复测后如需更短，旋钮线性（降 N 或改 1N 映射）即可，无需改机制。

## Memory Candidates

- 系统 momentum 流是"滑行太长"的隐藏主源（~33 事件/手势 ≈ 0.5s+，decay 调参管不到）；
  截断跟随（事件计数 2N）是独立于 decay 的旋钮。
- 截断点决策复用 finishGesture → 与 momentumEnded 同路径 → 无跳变、无双重 commit
  （state 离开 tracking 即天然防御）。
- 参数化 RM 降级机制时注意既有测试锚定的决策点（momentumEnded）——语义等价实现优先于改测试。
