# T-G-P7 独立评审 r1：MINOR-1 修复（静默过期移除会话后刷新聚合状态）

- 任务：T-G-P7 子任务「MINOR-1 修复（refreshAggregateState）」（T-G-P6-r2 评审 M-1 挂账项）
- 评审角色：Reviewer（独立；零代码改动；唯一写操作 = 本报告）
- 评审时间：2026-09-06 23:05–23:20；对象提交：Workflow/results/T-G-P6.md §R-08（2026-09-06 23:01）
- 评审范围：`Sources/PagingPrototypeApp/PinchRecognizer.swift`（611 行，修复 L374-376）、`Tests/PagingUITests/PinchRecognizerTests.swift`（931 行，新增用例 L904-930）、`Workflow/results/T-G-P6.md` §R-08
- 权威输入：Workflow/reviews/T-G-P6-r2.md M-1（缺陷源）；Workflow/results/T-G-P6.md §R-08（Worker 交付）
- **总体判定：PASS**（0 BLOCKER / 0 MAJOR / 0 MINOR / 0 QUESTION / 5 INFO；满足 PLAN §10 INDEPENDENT_REVIEW = PASS（0 BLOCKER/0 MAJOR）门）

---

## 一、分级问题清单

### BLOCKER
无。

### MAJOR
无。

### MINOR
无。

### QUESTION
无。

### INFO

- **I-1 修复行位置与语义核对通过**：静默过期分支（L368-380）`.candidate/.recognizing` 分支在 `sessions.removeValue` + `recordCancel(.dataExpired)` 之后立即 `refreshAggregateState()`（L376），与 `deviceDisconnected`（L333-339：removeValue + recordCancel + refresh）和 `endSession`（L546-549：removeValue + refresh）两条移除路径完全一致；净改动 = 1 行调用 + 2 行注释（L374-375），与 Worker 声明一致。
- **I-2 锁存分支不刷新合理**：`.fired/.waitingForRelease` 分支会话未移除，聚合状态（由 sessions 派生）本就一致，刷新属冗余；独立驱动验证（见二）E2：触发后静默超限帧 → 保持 `.fired`、fireCount 恒 1、无新增 dataExpired、无重复触发。
- **I-3 回归用例覆盖充分性**：新用例覆盖 `.candidate` 相位；`.recognizing` 与 `.candidate` 共享同一代码路径（`case .candidate, .recognizing` 同一分支），无需重复用例；锁存分支由既有 `testContract12SilenceIsNotReleaseForLatchedSession`（L883-900）覆盖。用例与 T-G-P6-r2 §八 建议（「静默过期 + 次帧非 4 触点 → 期望 .idle」）逐字吻合。
- **I-4 全量测试时长差异**：Worker 报 18.5s，Reviewer 实测 18.75s（同机同构建），属正常波动，计数一致（1412/0）。
- **I-5 工作流簿记**：events.jsonl 无独立 T-G-P7 派发事件（子任务在 T-G-P6 任务上下文内完成，§R-08 追加于 T-G-P6.md）；不影响交付物质量，建议 Main 在收口时补记 decision/note 落档。

---

## 二、独立测试计数（Reviewer 重跑）

| 运行 | 命令 | 结果 | 时间 |
|---|---|---|---|
| 过滤（识别器） | `swift test --filter PinchRecognizer` | **Executed 49 tests, 0 failures (0 unexpected)**，exit 0（PinchRecognizerTests 39 + Lifecycle 10） | 2026-09-06 23:06 |
| 全量 | `swift test` | **Executed 1412 tests, 0 failures (0 unexpected)**，18.75s，exit 0 | 2026-09-06 23:12 |
| Worker 声明（核对） | — | filter 49/0、全量 1412/0（18.5s）、build 0 | 一致 ✓ |

用例核数：`PinchRecognizerTests.swift` 恰好 39 个 `func test*`（38 + 新增 testM1SilentExpiryWithNonFourContactsRefreshesToIdle L904）；Lifecycle 10 个。过滤合计 49 = 评审基线 48 + 1 ✓。

**独立行为验证（/tmp scratch driver 编译同一源文件，非仓库改动，已清理）**：

| 场景 | 带修复 | 移除修复行（sed 删 L376） |
|---|---|---|
| A: t=0 四指 → 候选 | `state=candidate` ✓ | `state=candidate` |
| B: t=0.6 静默超限 + 同帧 2 触点 | **`state=idle`、events=0、dataExpired=1、activeSessionID=nil、activeDeviceID=nil、fireCount=0** ✓ | **`state=candidate`、dataExpired=1**（缺陷精确复现，与 T-G-P6-r2 复现一致） |
| C: t=0.7 四指 → 新候选 | `state=candidate` ✓ | — |
| D: t=0.8 结束证据 → idle | `state=idle` ✓ | — |
| E: 触发后静默超限（锁存分支） | `state=fired`、fireCount=1、无新增 dataExpired ✓ | — |

Worker 声称「临时移除修复行重跑 → 3 断言失败精确复现」**独立证实**：用例 B 段断言 `state == .idle`、`activeSessionID == nil`、`activeDeviceID == nil` 恰为 3 条，无修复行时全部失败。

---

## 三、正确性核对

1. **修复语义**：静默过期 = 保守重置（合同 12：无回调超时 ≠ 全指释放），会话移除后聚合状态必须同步。修复后与 deviceDisconnected/endSession 两条移除路径行为一致（removeValue → recordCancel → refreshAggregateState）。✓
2. **refreshAggregateState() 实现（L567-587）**：`.disabled` 早退；`suspendedReason` 非空 → `.suspended`；sessions 空 → `.idle` + 清空 activeDeviceID/activeSessionID；否则取 `lastSeenTimestamp` 最大会话派生 state/active 属性。静默移除后（无其他设备会话）→ `.idle` + 双 nil，正确。✓
3. **多设备边界**：其他设备仍有会话时，state 派生自最近活跃会话，不误清。✓
4. **同帧 4 触点边界**：静默移除后同帧恰好 4 触点 → 无会话分支立即新建候选并再次 refresh（L400）→ `.candidate`；process() 对调用方原子，中间 `.idle` 不可观察。✓
5. **移除路径完备性枚举**：全仓 `removeValue/removeAll` 共 4 处——deviceDisconnected（refresh ✓）、静默过期（修复后 refresh ✓）、endSession（refresh ✓）、clearAllSessions（调用方 start/stop/restart/suspend 均显式设 state ✓）。**无遗漏路径**，M-1 修复完整。✓
6. **锁存分支不刷新合理性**：会话未移除，聚合状态一致；驱动 E2 实证无副作用。✓

## 四、测试充分性

- 新用例 `testM1SilentExpiryWithNonFourContactsRefreshesToIdle`（L904-930）**精确覆盖缺陷**：静默超限（0.6s > 0.5s + timeEpsilon）→ 同帧仅 2 触点（≠4）→ 无会话分支提前 return 路径；断言 state==.idle、activeSessionID/activeDeviceID==nil、cancelCounts[.dataExpired]==1、零事件零触发（events==[]、fireCount==0）。
- 用例 C/D 段验证识别器功能不受修复影响（新候选可建、结束证据可回 idle）。
- 锁存分支（不刷新路径）由既有 testContract12 覆盖，无回归敞口。
- 独立重跑 filter 49/0、全量 1412/0，与 Worker 计数一致。

## 五、隐私红线核查（§11 静态扫描）

扫描对象：`PinchRecognizer.swift` + `PinchRecognizerTests.swift`（另全仓 Sources/ 兜底）。
- 禁用模式 `addGlobalMonitorForEvents` / `CGEvent.tapCreate` / `AXIsProcessTrusted` / `IOHID` / `frontmostApplication` / 坐标日志（print/NSLog/os_log/Logger）：**修改源码零命中**（测试文件亦零日志）。
- 全仓兜底唯一命中：`AppDelegate.swift` L1211 注释（说明本 app **不使用** 全局 NSEvent monitor）——冻结文件（09-05），非本次会话触碰，非违规。
- `LaunchBetter`：仅 PinchRecognizer.swift 注释（L11/L495）说明性引用——用户指示 #824 明确授权参照该模型，与 T-G-P1 既有注释模式一致，合规。
- `Buho`：唯一命中在冻结树 `PagingTelemetry.swift` L32 注释「禁止 Buho 品牌前缀」（未改动、与本任务无关）。
- 无坐标/轨迹/设备数据持久化：识别器纯内存值类型，输出仅 `PinchEvent.showRequested` + 中性计数。
- **结论：PRIVACY_AND_PROVENANCE_REDLINE = PASS**。

## 六、写集合规与纪律核查

- 冻结树目录 mtime 与 Worker 报告**逐项一致**（本评审独立复测）：PagingCore 08-30 10:46:02、PagingTelemetry 08-28 20:09:02、PagingUI 08-30 14:15:30、AppCatalogCore 08-28 19:50:22、MacAppCatalog 08-28 20:01:55、AppIconPipeline 08-28 23:22:40、AppGridUI 09-03 13:52:19、Package.swift 08-28 19:42:55、AppLaunchController.swift 08-28 20:46:54。
- 本次会话（≥09-06 22:35）触碰文件 = 仅 `PinchRecognizer.swift`（23:02:05）/ `PinchRecognizerTests.swift`（23:00:32）/ `Workflow/results/T-G-P6.md`（23:01:48）3 个 + Workflow 运行时簿记（watchdog/events/STATE/heartbeats）；`PinchRecognizerLifecycleTests.swift` 本次未触碰（属 T-G-P6 前序会话）✓。
- 禁改文件：AppDelegate.swift（09-05 14:09，前序任务）、AppMain.swift（08-29）、AppArguments.swift（08-30）——本次会话未触碰 ✓。
- 纪律：仓库无任何 commit（git log 空、全部路径未跟踪）→「不 commit/push/tag」天然成立；本评审零代码改动（/tmp 验证驱动不落仓库，已清理）。

## 七、验收结论（对照评审要求 5 项）

1. **正确性** — **PASS**：修复行位置/语义与 deviceDisconnected/endSession 移除路径一致；锁存分支不刷新合理（驱动实证）；refreshAggregateState() 派生逻辑核对无错误；移除路径完备性枚举无遗漏。
2. **测试充分性** — **PASS**：新用例精确覆盖缺陷（静默过期 + 同帧非 4 触点）；独立重跑 filter 49/0、全量 1412/0，与 Worker 计数一致；无修复行时 3 断言失败精确复现（独立驱动证实）。
3. **隐私红线** — **PASS**：修改源码静态扫描零命中（五节）。
4. **写集合规** — **PASS**：冻结树 mtime 逐项一致 + 会话触碰仅 3 文件；AppDelegate/AppMain/AppArguments 未改（六节）。
5. **报告** — 本报告：分级清单 + 独立测试计数 + 独立行为验证 + 逐项验收 + 隐私/写集专项。

## 八、给 Main 的后续动作（非阻塞）

1. T-G-P7 收口时补记 events.jsonl decision/note（I-5），并推进 T-G-P6-r2 M-2 文档同步（Prompt §19.2 L1401-1402 + ADR-013 L41-42，先于 §25.1 完成门）。
2. 实机矩阵（M02/M04/M05）继续覆盖 Q-1「落指抖动帧」负样本形态；Q-2 阈值定案依据随 ADR-013 修订落档（沿用 T-G-P6-r2 §八 3）。

---
*Reviewer 独立证据：49/0 过滤测试、1412/0 全量（18.75s）、/tmp 双态驱动（带修复 PASS / 移除修复行复现缺陷，已清理）、静态扫描、mtime 双查。本报告为唯一写操作。*
