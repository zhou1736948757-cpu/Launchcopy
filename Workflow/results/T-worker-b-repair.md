# T-worker-b-repair — Reviewer E MINOR 修复波（M-3 / M-4 / Q-2）

**Worker**: B/D 同人（PagingCore + PagingUI 作者）延续
**依据**: `/Users/mac/Projects/Launch_Copy/PagingPrototype/Workflow/reviews/T-reviewer-r1.md`（Findings M-3/M-4/Q-2；Verdict PASS）
**Scope**: `Sources/PagingCore/`、`Sources/PagingUI/`、`Tests/PagingCoreTests/`、`Tests/PagingUITests/`（本波允许写入范围）
**未触碰**: `Package.swift`、`Sources/PagingPrototypeApp/`（本波范围外；其预存 `var event` 编译警告未处理）、`Sources/PagingTelemetry/`、`Docs/`、`PROVENANCE/`、`Workflow/`（本结果文件除外）、README（M-5 属 Docs 范围，非本波三项）
**AccessDeclaration: NO_PRIOR_EXPOSURE**（重申：未读取 §1.3 禁止路径与治理文档；本波零外部来源接触）

---

## 三项修复状态

### M-3（PagingCore，注释一致性）— **fixed**
- `Sources/PagingCore/PageTargetPolicy.swift:71`（原 :72）：注释由「velocityContribution：0=纯位移，1=纯速度」改为「0=纯位移；合法范围 0.0–0.5，0.5=速度加权上限——位移为主、速度为辅，与 PagingParameters 约束一致」。
- 零行为改动（仅注释）；与 `PagingParameters.swift:53-54`、文件头注、`PARAMETER_RATIONALE.md` 的 0.0–0.5 一致。
- 正确性：无风险（Reviewer 判定零行为风险）。

### M-4（PagingUI，高度 resize 边缘）— **fixed**
- `Sources/PagingUI/PagingSurface.swift` `layout()`：守卫由「仅宽度」放宽为「宽度或高度任一变化 > 0.5 阈值」：
  - 宽度变化 → 原路径（`core.setPageWidth` rebase + `onResize` + `relayoutPages`）；
  - **仅高度变化** → `onResize` + `relayoutPages`（**不触碰 Core**——宽度未变则 D6 偏移语义不变）；全部 live host 经 relayoutPages 步骤 2b 按新高度重新对齐（高度源 = `max(bounds.height, 64)`）。
  - 新增 `lastLayoutHeight` 守卫状态；保持事件驱动（同尺寸重复 `layout()` 零成本，无每帧重排）。
- 新增 3 个回归测试（`Tests/PagingUITests/PagingSurfaceTests.swift`）：
  1. `testHeightOnlyResizeReframesHosts` — 仅高度 700→800：host 高度刷新为 800、宽度/x 不变、Core pageWidth 不变（无 rebase）、恰好 +1 次布局；
  2. `testWidthAndHeightSimultaneousResize` — 宽高同时 800×600：host 宽/高/容器尺寸全部对齐、Core pageWidth=800；
  3. `testRepeatedHeightResizeNoLayoutStorm` — 3 次不同高度各恰好 +1 布局；同尺寸重复 layout()×10 零额外布局（守卫生效）。
- 回归确认：既有 `testResizeRealignsAllPages`、`testResizeSameWidthDoesNotRelayout`、`testResizeDuringSettlingRebasesAndRealigns` 全绿（宽度守卫防风暴语义未放宽为每帧）。

### Q-2（PagingCore，createdAt 诊断字段）— **fixed**（低成本路径）
- `Sources/PagingCore/PagingCore.swift` 三处重启路径 `createdAt: 0` → `Date().timeIntervalSince1970`：`setPageWidth`（.resizeRebase，原 :285）、`setPageCount`（.pageCountChange，原 :337）、`setReduceMotion`（.reduceMotionChange，原 :355）。
- `Sources/PagingCore/TransitionContext.swift` 字段文档补充语义注：手势发起 = 手势事件时间戳（事件时基）；非手势重启 = 壁钟时间（诊断字段，仅作关联，不混算）。
- 新增 `testRestartPathsRecordCreationTimestamp`（`Tests/PagingCoreTests/PagingCoreTests.swift`）：
  - resize 路径：settling 中 `setPageWidth` → 新 transition reason=.resizeRebase 且 createdAt > 锚点；
  - pageCount 路径：target 越界（initialPage 3 → target 4，`setPageCount(3)`）→ 重置 transition reason=.pageCountChange 且 createdAt > 锚点（**合法 target 时不重启**——D6 继续原动画，属设计行为，测试注明）；
  - RM 路径：D8 下 RM 重启的 settle 立即完成（beginSettle 即时完成路径），activeTransition 即刻为 nil → 经 harness `onTransitionBegin` 记录断言 `transitions.last`（reason=.reduceMotionChange，createdAt > 锚点）。
  - 锚点 1_600_000_000（2020-09），远早于任何真实运行。

---

## Verification（命令 + 退出码）

| 命令 | 结果 |
|---|---|
| `swift build`（全包） | exit 0（仅 1 条预存警告：PagingTelemetryBridge.swift:118，本波范围外） |
| `swift build --target PagingCore` | exit 0 |
| `swift build --target PagingUI` | exit 0 |
| `swift test --filter "PagingSurfaceTests|testRestartPathsRecordCreationTimestamp"` | 17 tests, 0 failures, exit 0 |
| `swift test`（全量） | **144 tests, 0 failures**（51 Core + 33 Telemetry + 60 UI），exit 0 |

测试数 140 → **144**（+3 M-4 +1 Q-2），符合「新增测试计入，总数应 >140」。

## Changed Files

| 文件 | 变更 |
|---|---|
| `Sources/PagingCore/PageTargetPolicy.swift` | M-3：velocityContribution 注释修正（0.0–0.5 合法范围一致） |
| `Sources/PagingCore/PagingCore.swift` | Q-2：三处重启路径 createdAt 传真实时间戳 |
| `Sources/PagingCore/TransitionContext.swift` | Q-2：createdAt 双时基语义注释 |
| `Sources/PagingUI/PagingSurface.swift` | M-4：layout() 高度守卫 + lastLayoutHeight；高度单独 resize 触发 relayoutPages（不触碰 Core） |
| `Tests/PagingCoreTests/PagingCoreTests.swift` | +1：testRestartPathsRecordCreationTimestamp |
| `Tests/PagingUITests/PagingSurfaceTests.swift` | +3：高度 resize 回归测试 |
| `Workflow/results/T-worker-b-repair.md` | 本文件 |

## Deviations

1. **Q-2 测试设计修正**（非代码偏差）：首版断言假设 pageCount/RM 路径必产生新 activeTransition——实测发现 (a) 合法 target 时 setPageCount 不重启（D6 继续原动画，正确行为）；(b) RM 重启 settle 即时完成（D8），activeTransition 即刻 nil。已按实际语义改为：pageCount 用 target 越界场景 + RM 用 onTransitionBegin 记录断言。代码行为未改动。
2. **M-5（README）不在本波范围**：属 Docs 范围（任务包仅列 M-3/M-4/Q-2 三项），未处理，交由 Main/后续波。
3. **PagingTelemetryBridge.swift:118 预存警告**：本波写入范围不含 `Sources/PagingPrototypeApp/`，未修（T-worker-d 遗留，`var event` 未突变；可后续顺手处理）。

## Memory Candidates

- Core D6：`setPageCount` 仅当 target 越界才重启 settle（合法 target 继续原动画）——Q-2 测试设计要点。
- Core D8：RM 重启 settle 在 beginSettle 内即时完成（activeTransition 即刻 nil）——RM 下观测 transition 须走 onTransitionBegin 记录。
- UI M-4：高度单独 resize 不触碰 Core（宽度未变则 D6 rebase 语义不适用）；布局守卫 = 宽度或高度任一 >0.5，事件驱动。
- CoreHarness 的合成时间戳（now 从 0 起）不可用于 createdAt 断言；用锚点或 onTransitionBegin 记录。
