# T-G-P6 独立评审 r2：识别器重构（首帧基线 + 相对收缩，R-05）

- 任务：T-G-P6 子任务「四指识别器重构（首帧基线 + 相对收缩）」
- 评审角色：Reviewer（独立；零代码改动；唯一写操作 = 本报告）
- 评审时间：2026-09-06 22:24–22:35；对象提交：Workflow/results/T-G-P6.md §R-05（2026-09-06）
- 评审范围：`Sources/PagingPrototypeApp/PinchRecognizer.swift`（608 行）、`Tests/PagingUITests/PinchRecognizerTests.swift`（901 行）、`Tests/PagingUITests/PinchRecognizerLifecycleTests.swift`（199 行）、`Workflow/results/T-G-P6.md`
- 权威输入：Docs/PHASE1G_ACTIVATION_ENTRY_HOT_CORNER_PROMPT.md §19.2/§22/§23；Workflow/PLAN.md Phase 1G 段；ADR-013；Workflow/events.jsonl #824（用户指示 decision_recorded，2026-09-06 22:16:53）
- **总体判定：PASS**（0 BLOCKER / 0 MAJOR / 2 MINOR / 2 QUESTION / 6 INFO；满足 PLAN §10 INDEPENDENT_REVIEW = PASS（0 BLOCKER/0 MAJOR）门）

---

## 一、分级问题清单

### BLOCKER
无。

### MAJOR
无。

### MINOR

**M-1（状态一致性）静默过期移除会话后未刷新聚合状态，`state` 可观察属性可能滞后**
- 位置：`PinchRecognizer.swift` L367-377（process() 静默分支：`.candidate/.recognizing` → `sessions.removeValue` + `recordCancel(.dataExpired)`，**未调用 refreshAggregateState()**）；L392-399（无会话分支在触点不足 4 时提前 `return []`，同样不刷新）；对照 L380-383/L543-546 结束证据路径有刷新。
- 现象：候选/识别中静默超限（>0.5s）被移除后，若同一帧触点数 ≠ 4（如 2/3 指），`state` 仍停留在 `.candidate/.recognizing`，而 `sessions` 已空；`activeSessionID` 同步失真。下一帧 4 触点或结束证据/断开才纠正。
- 独立验证（/tmp scratch driver 编译运行同一源文件，非仓库改动）：
  - A: t=0 四指 → `state=candidate`；B: 静默至 0.6s 后收到 2 触点帧 → 输出 `state=candidate`、`cancelCounts[.dataExpired]=1`（sessions 已空）；C: 0.7s 四指帧 → 新候选 `state=candidate`；D: 结束证据帧 → `idle`。
- 影响评估：仅观察面（`state/activeDeviceID/activeSessionID` 对外可读）不一致；process() 后续判定以 `sessions` 字典为准，不受 `state` 值影响 → **无事件错发、无重复触发、无安全/隐私影响**。
- 建议：静默分支移除会话后立即 `refreshAggregateState()`（一行）；可随 T-G-P7 或一个极小 repair 任务处理。**不阻塞本次 PASS**（不影响任务验收语义），但建议记录为挂账项。

**M-2（文档一致性）偏差④已核验属实：Prompt §19.2 L1401-1402 与 ADR-013 L41-42 仍文字性要求「短稳定窗口 + 噪声容忍」，与交付实现（无稳定窗口/无噪声容忍）冲突**
- 证据：`Docs/PHASE1G_ACTIVATION_ENTRY_HOT_CORNER_PROMPT.md` L1401「2. 落指不同步不能让第四根手指的出现被当作收缩；建立基线需要一个短稳定窗口。」L1402「3. 从基线计算归一化收缩量；阈值、稳定窗口、时间上限和噪声容忍必须分别命名。」；`Docs/ADR-013-FOUR-FINGER-ACTIVATION-BACKEND.md` L41-42 同文。
- 判定：**不阻塞本任务**——用户指示已由 events.jsonl #824 记录（「参照 LaunchBetter PinchAnalyzer 模型调整识别器（首帧基线+相对收缩，无稳定窗口）」），代码实现即该授权的直接产物；Worker 已透明披露并给出同步路径；合同 3「分别命名」核心仍满足（shrinkThreshold/maxGestureDuration/expansionCancelThreshold 等均独立命名，删除项不残留）。
- **但 Phase 1G 完成门（§25.1）前必须同步，给 Main 的明确同步时点（评审意见）：**
  1. 在 **T-G-P7 收口**（或独立 Docs 同步子任务，先于 §25.1 完成门判定）内执行：Prompt §19.2 L1401-1402 合同 2/3 文字改为「首帧基线 + 相对收缩」语义；ADR-013 §3 L41-42 同步，并在 ADR-013 §2 参数表删除 `baselineStableWindow`/`noiseTolerance`、`maxGestureDuration` 改 3.5s、补记用户决策 #824 与 §R-03/§R-04 实机证据引用。
  2. 同步排查 §24 文档清单（FOUR_FINGER_ACTIVATION_SPEC.md / VALIDATION / RESULTS / CHECKPOINT）中是否残留旧语义表述。
  3. 建议记 events.jsonl (decision/note) 落档；T-G-P1-r1.md 保持历史不改（同意 Worker 处理）。

### QUESTION

**Q-1（误触敞口）新模型单帧即判，无时间累积：落指瞬间几何突变可能假触发，需实机门回答**
- 新模型无稳定窗口/无噪声容忍，`advanceRecognizing` 对每帧独立判定 `contraction ≥ 0.15` 即触发（无连续帧要求）。风险窗口：第 4 指落下（基线帧）后的首个判定帧若半径相对基线发生 ≥15% 突变（落指瞬间按压分布变化/手指跳动），可在无真实捏合意图时触发。
- §R-04 实机证据（6 段整段移动、取消 0.2s 内）证明了旧模型失效，但未包含「落指瞬间半径突变」回放样本；平移/旋转/微抖动由 P05 用例覆盖（半径不变/波动 ≈0.007），**未覆盖「单帧 15% 尖峰」形态**。
- 该敞口的回答责任在后续实机门：M04（张开 20 次零误触）、M05（负样本各 20 次零误呼出）、M02（慢/快召回）。请 Main 在 T-G-P6 实机矩阵执行时把「落指抖动帧」纳入 M05 负样本形态并回填结果；若误触率超标，备选缓解（首帧后 N 帧平均半径 / 连续 K 帧超阈值）记入 ADR-013 修订条目。

**Q-2（阈值定案出处）「用户授权区间 0.15-0.20」未找到可核查记录**
- §R-05 声称 shrinkThreshold=0.15 是「用户授权区间 0.15-0.20 下界」；但 grep events.jsonl / Workflow/decisions/ / Prompt §19.2 均无该区间记录。可核实的沿革仅为 T-G-P1 结果 §参数：0.15 为暂定值（标注「待 §19.2 定案与实机验证后确认」）。
- 0.15 属于保持未改值，方向（较 LaunchBetter 0.18 更灵敏）有 §R-05 实测余量论证（47-57%），不构成参数范围扩张；但仍建议**在 ADR-013 修订时把 0.15 定案依据正式落档**（§R-05 论证文字即可；若存在用户对话原文请一并引用），消除「授权区间」无源引用的痕迹。

### INFO

- **I-1 偏差 ①②③ 审查结论（合理可接受）**：① LaunchBetter「触发后更新 startDistance」不适用——本状态机锁存 `.fired`（合同 6 一会话一次），触发后该会话不再判定，等价安全由冷却（合同 7）+ 释放后新会话重建基线承担；② 冷却 0.5s 单调时钟 ≠ LaunchBetter 0.2s 墙钟——沿用既有 §19.2 合同 7 值，用户指示仅要求单调时钟，保守值防快速连续误触，可接受；③ minBaselineRadius 退化几何检查提前至首帧——安全收严（首帧半径 <0.02 立即取消），testP11NearZeroBaselineRadiusCancels 已按新语义改写并断言，可接受。
- **I-2 lastFireLatency 时间基**：`lastFireLatency = clock.now() - candidateStartedAt`（处理时刻）与帧捕获时刻 `frame.timestamp` 可能相差投递延迟（≤ dataExpiryInterval 0.5s），同属 systemUptime 单调域（合同 §19.3），仅影响低频统计精度，不涉及跨时钟换算。
- **I-3 防御性死代码**：`advanceRecognizing` L506 `guard baselineRadius > 0` 不可达（advanceCandidate 保证 ≥ minBaselineRadius=0.02），无害，无需改。
- **I-4 仓库状态**：本仓库无任何 commit（全部路径未跟踪，git log 空）→「不 commit/push/tag」由仓库状态天然确认；写范围核验只能依赖 mtime（本报告采用目录级 + 文件级双查）。
- **I-5 测试分层**：testP17EventTypeIsShowOnly 仅编译期验证事件类型；Show 幂等（P16）由 FourFingerActivationCoordinatorTests（20 用例）覆盖，分层合理。
- **I-6 冻结树核验方法说明**：目录 mtime 只反映条目增删/改名；评审补充了冻结树内**文件级** mtime 扫描（≥2026-09-05 的 `Sources/AppGridUI/FolderOverlayView.swift`(09-05 14:13)、`DragUI/DragUIVisuals.swift`(09-05 00:59)、`DragUI/DragUISessionCoordinator.swift`(09-05 00:58) 均属更早任务（Bug11/Drag 集成）触碰，**非本次 09-06 会话**）。本次会话（09-06 22:21–22:23）全仓 Sources/Tests 触碰仅限声明的 3 个源码文件 + 1 个结果文件。

---

## 二、独立测试计数（Reviewer 重跑）

| 运行 | 命令 | 结果 | 时间 |
|---|---|---|---|
| 过滤（识别器） | `swift test --filter "PinchRecognizerTests\|PinchRecognizerLifecycleTests"` | **Executed 48 tests, 0 failures (0 unexpected)**，exit 0（PinchRecognizerTests 38 + Lifecycle 10） | 2026-09-06 22:24 |
| 全量 | `swift test` | **Executed 1411 tests, 0 failures (0 unexpected)**，19.7s，exit 0 | 2026-09-06 22:27 |
| 构建 | `swift build` | **Build complete, exit 0** | 2026-09-06 |
| Worker 声明（核对） | — | filter 75/0（=48+20 协调器+7 集成，与我的 48 子集一致）、全量 1411/0（基线 1408+3）、build 0 | 一致 ✓ |

手工用例核数：`PinchRecognizerTests.swift` 恰好 38 个 `func test*`（L76–L900），含新增 3 例（testFastPinchNoStableFrameTriggers L769 / testSlowPinchStartsWithRestThenContractsTriggers L794 / testDefaultMaxGestureDurationIs3Point5Seconds L819）。**关键路径覆盖核对**：快速触发 ✓（L769，连续移动无静止帧、收缩 0.20 触发、零取消）；慢速触发 ✓（L794，平放 1.6s 再捏合，1.6s 候选→触发在 3.5s 内）；时间上限边界 ✓（L819：3.5s 边界保持、3.6s `.timeLimitExceeded` 锁存；另有 0.5s 定制参数用例 L751）；5 指取消 ✓（L156）；扩张取消 ✓（L641，pinchOut 无 Hide + 锁存 + 释放后可再触发）；冷却 ✓（L847，生产默认 0.5：0.3 抑制抑制计数+1 锁存、0.6 触发）；触点更换 ✓（L339）；设备更换/隔离 ✓（L359/L390）；静默恢复 ✓（L474 候选保守重置 + L883 锁存静默不 re-arm）；退化几何 ✓（L538 首帧即取消）；平移/旋转/微抖动 ✓（L184/L213/L242）；乱序/未来帧/过载 ✓（L582/L602/L617）；NaN/Infinity/超计数/负时间戳/重复 ID ✓（L491–L578）；锁存/四变三变四 ✓（L94/L310）；顺次落指 ✓（L277）；合同 2/3/7/12 ✓（L706/L732/L751/L847/L883）。生命周期 10 例覆盖 P13/P14/P15/合同 11（含 generation 失效、重入、suspend/stop/restart 清会话）。**零缺失项**；仅 P16 幂等、P03 全释放后重触发为跨层（协调器）验证，分层合理。

---

## 三、§19.2 合同 12 条逐条核对（对照重构后实现）

1. **Idle 收到稳定、恰好四个有效触点后才建立候选** — 部分满足：恰好 4 触点 ✓（L393、L457）；「稳定」由用户决策 #824 取消（首帧即建基线，无稳定窗口）→ 文字偏差见 M-2。
2. **落指不同步不被当收缩；建基线需短稳定窗口** — 语义满足（第 4 指落下帧为基线帧，收缩量恒 0 不判定，testContract2 L706 覆盖）；「短稳定窗口」文字已废弃 → M-2。
3. **从基线计算归一化收缩量；阈值/稳定窗口/时间上限/噪声容忍分别命名** — 满足核心：`(baseline-current)/baseline`（L512）；shrinkThreshold/maxGestureDuration/expansionCancelThreshold/minBaselineRadius 独立命名（L105-141）；已删参数零残留（全仓 swift 源码 grep `baselineStableWindow|noiseTolerance|windowStartedAt|baselinePositions` 无命中）→「稳定窗口/噪声容忍」名称随删除，文字残留见 M-2。
4. **平移不产生收缩；旋转/抖动/噪声不积累** — 满足：radius 为质心平均距离（L586-601），平移/旋转不变；逐帧独立判定无积分累积；P05 三用例断言「不应触发」。
5. **五指进入、触点替换、设备改变、数据过期必须取消或重建候选** — 满足：contactCountChanged（L457-460）/contactReplaced（L462-468）/deviceDisconnected（L333-339）/dataExpired（L368-377）。
6. **触发后锁存 Fired；一会话仅一次** — 满足：L485-487 锁存分支；P02/P07 断言 fireCount 恒 1；冷却抑制路径同样锁存（L518）。
7. **冷却只是附加保护，不是重新武装唯一条件** — 满足：0.5s 单调时钟识别器级（L245-246、L516-520），释放后新会话重武装仅依赖结束证据（合同 8）。
8. **全部离面/可靠接触结束才 re-arm；新手势建新基线** — 满足：仅 `.ended/.cancelled/moved+空触点`（L380-383）移除会话；新会话首帧重建基线（L440-451、L491-503）。
9. **四变三变四不能绕过锁存二触发** — 满足：P07 L310-335。
10. **缺帧/乱序/非有限数/非法计数/近零半径安全拒绝** — 满足：validateFrame（L417-438，负数/NaN/Infinity/超 maxContactCount=8/重复 ID）、乱序（L402-405 以 lastSeenTimestamp 为界）、未来帧（L358-361）、过期帧（L362-365）、近零首帧半径（L495-497，提前至首帧）。
11. **Suspend/stop/disable/restart 清基线/会话/待派发意图** — 满足：clearAllSessions（L548-558）+ generation +1；Lifecycle 用例全绿。
12. **无回调超时 ≠ 全指释放；保守可验证恢复** — 满足：静默两档（L368-377：candidate/recognizing 移除计数 .dataExpired；fired/waitingForRelease 保持锁存）；testContract12SilenceIsNotReleaseForLatchedSession 覆盖。

§19.3（单调时钟 systemUptime L27-32 ✓；token generation 去重 ✓；不记录原始轨迹 ✓；低频中性计数 ✓）、§20.2（回调无窗口操作——识别器为纯值类型、无锁、无 AppKit，文件头 L7 声明核实 ✓）、§20.3（识别器不涉采集/注销职责 ✓）——均满足。

## 四、隐私红线核查（§11 静态扫描）

扫描对象：`PinchRecognizer.swift` + 两个测试文件（另全仓 Sources/ 兜底）。
- 禁用模式 `addGlobalMonitorForEvents` / `CGEvent.tapCreate` / `AXIsProcessTrusted` / `IOHID` / `frontmostApplication` / 坐标日志：**源码零命中**（print/写入均无；测试文件仅纯逻辑断言）。
- `LaunchBetter`：仅出现在 PinchRecognizer.swift 注释（文件头 + L492「参照 LaunchBetter PinchAnalyzer 语义」），属说明性引用——用户指示 #824 明确授权参照该模型；非代码链接、非文件读取。合规（与 T-G-P1 既有注释模式一致）。
- `Buho`：唯一命中在冻结树 `PagingTelemetry.swift` L32 注释「禁止 Buho 品牌前缀」（未改动、与本任务无关）。
- 无坐标/轨迹/设备数据持久化：识别器纯内存值类型，输出仅 `PinchEvent.showRequested` + 中性计数。
- **结论：PRIVACY_AND_PROVENANCE_REDLINE = PASS**。

## 五、写集合规与纪律核查

- 冻结树目录 mtime 与 Worker 报告**逐项一致**：PagingCore 08-30 10:46:02、PagingTelemetry 08-28 20:09:02、PagingUI 08-30 14:15:30、AppCatalogCore 08-28 19:50:22、MacAppCatalog 08-28 20:01:55、AppIconPipeline 08-28 23:22:40、AppGridUI 09-03 13:52:19、Package.swift 08-28 19:42:55、AppLaunchController.swift 08-28 20:46:54（本评审独立复测）。
- 文件级补充扫描：09-06 会话（22:21–22:23）触碰文件 = 仅 `PinchRecognizer.swift`/`PinchRecognizerTests.swift`/`PinchRecognizerLifecycleTests.swift`/`Workflow/results/T-G-P6.md` 4 个（写范围 ✓）。
- 禁改文件：AppDelegate.swift（09-05 14:09，前序任务）、AppMain.swift（08-29）、AppArguments.swift（08-30）——本次会话未触碰 ✓。
- Tools/FourFingerCaptureTool：main.swift 不引用已删参数；全仓 swift grep 无残留 ✓；swift build 覆盖该 target 且 exit 0 ✓。
- 纪律：仓库无提交历史（不 commit/push/tag 天然成立）；本评审零代码改动（/tmp 验证驱动不落仓库，已清理）。

## 六、偏差审查（Worker 披露 4+2 项）

| # | 偏差 | 判定 | 说明 |
|---|---|---|---|
| ① | LaunchBetter「触发后更新 startDistance」不适用 | **PASS（可接受）** | 锁存语义下无重锚定场景；等价安全由冷却+新会话基线承担（I-1） |
| ② | 冷却 0.5s 单调时钟 ≠ 0.2s 墙钟 | **PASS（可接受）** | 沿用合同 7 定案值；用户指示未要求改值（I-1） |
| ③ | 退化几何检查提前至首帧 | **PASS（可接受）** | 安全收严；测试同步改写（I-1） |
| ④ | Docs 契约文字未同步（Prompt L1401-1402 / ADR-013 L41-42） | **PASS（不阻塞本次），但为跨任务债务** | 已核验属实（M-2）；**Main 应在 T-G-P7 收口（先于 §25.1 完成门）执行 Prompt+ADR 同步**，并记 ADR-013 修订条目 |
| ⑤ | 纪律（仅 4 文件、无 commit） | **PASS** | 五节独立核验一致 |
| ⑥ | Tools 未重建 | **PASS** | 零残留 + build 覆盖（五节） |

## 七、验收结论（对照任务书 7 项）

1. **正确性** — **PASS**：判定模型（首帧基线 L491-503、次帧起识别 L475-482、相对收缩/扩张 L505-536）、触点数/ID 变化取消（L457-468）、冷却（L516-520）、3.5s 上限（L470-473）、静默恢复（L368-377）、generation、七态状态机、validateFrame 逐行核对无逻辑错误；对照合同 12 条全部满足（文字偏差除外，见 M-2）；发现 1 个状态刷新 MINOR（M-1），无事件/安全影响。
2. **测试充分性** — **PASS**：38 用例全覆盖关键路径（清单见二）；独立重跑 filter 48/0、全量 1411/0、build 0，与 Worker 计数一致。
3. **隐私红线** — **PASS**：静态扫描零命中（四节）。
4. **写集合规** — **PASS**：冻结树 mtime 一致 + 文件级扫描仅 4 文件；AppDelegate/AppMain/AppArguments 未改（五节）。
5. **偏差审查** — **PASS**：①②③ 合理；④ 不阻塞本次，同步时点 = T-G-P7 收口（六节 + M-2）。
6. **报告** — 本报告：分级清单 + 独立计数 + 逐条验收 + 合同逐条核对 + 隐私/写集/偏差专项。
7. **纪律** — **PASS**：Reviewer 只读（唯一写操作为本报告）；Worker 未 commit/push/tag。

## 八、给 Main 的后续动作（非阻塞）

1. 将 M-1（refreshAggregateState 一行修复）挂入 T-G-P7 或独立极小 repair；修复后补 1 条回归断言（静默过期 + 次帧非 4 触点 → 期望 `.idle`）。
2. T-G-P7 收口执行 M-2 文档同步（Prompt §19.2 L1401-1402 + ADR-013 L41-42 + §24 文档清单排查 + events 落档）。
3. 实机矩阵（M02/M04/M05）执行时覆盖 Q-1「落指抖动帧」负样本形态；Q-2 阈值定案依据随 ADR-013 修订一并落档。

---
*Reviewer 独立证据：48/0 过滤测试、1411/0 全量（19.7s）、build 0、静态扫描、mtime 双查、/tmp 行为复现驱动（已清理）。本报告为唯一写操作。*
