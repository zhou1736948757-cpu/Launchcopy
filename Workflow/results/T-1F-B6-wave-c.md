# T-1F-B6-wave-c — BUG6 Wave C 第一层：抑制状态泄漏堵漏（缺陷 2）

Status: done
AccessDeclaration: NO_PRIOR_EXPOSURE（全程未读 /Users/mac/Projects/LaunchBetter/、BuhoReverseNotes/、2026-08-25-buho-launchpad-reverse 及任何 Ghidra/otool dump）
Wave: BUG6 C1（写范围：`DragUISessionCoordinator.swift` + coordinator 测试文件，与 wave-a/b 不相交）
Role: Worker (implement + verify)
Privacy: 全部中性夹具（fixture.app1/app2 合成 token）；无真实 app 名/路径进日志；无 git 操作。

## 1. §2.1 强制自查清单 — pointerUp/pointerDragged/pointerDown 每条提前 return 的 endSession 标注

行号 = 修补后 `Sources/AppGridUI/DragUI/DragUISessionCoordinator.swift`（446→450 行）现文件。

### pointerDown
| return 点 | 条件 | 需要否 | 理由 |
|---|---|---|---|
| :104 | `isTornDown` | 不需要 | 终态守卫；teardown() 已全量清理（含抑制），再清属多余 |
| :105 | `dragGate()` false | 不需要 | Chief 注记：会话建立之前，本调用未 beginArbitration；盲目 endSession 可能误伤上一轮仍然保持的仲裁 |
| :106 | `visualHost == nil` | 不需要 | 同上（Chief 注记：无 visualHost 的 pre-session return） |
| :120 | resolveSource == nil（blank press 武装后 return） | **禁止调用** | 该路径从不 beginArbitration（抑制标志不可能由它置位）；且 endSession 会清刚武装的 `pendingBlankPress`（endSession :360）→ 空白点击失效 |
| :123 | `layoutProvider() == nil` | 不需要 | 未建立任何状态：controller.pointerDown 未调用、抑制未开始、sourceCell 未赋值 |

### pointerDragged
| return 点 | 需要否 | 理由 |
|---|---|---|
| :141 `isTornDown` | 不需要 | 终态守卫 |
| :142 `visualHost == nil` | 不需要 | Chief 注记（pre-session）；会话终局归 cancel()/teardown() 管 |
| :151 pendingBlankPress 分支 | 不需要 | 空白路径从不抑制；**未过阈值子分支**若 endSession 会误清仍有效的空白候选（破坏空白点击） |
| :153-161 clickFallback 分支 | **需要（本波已修，:158）** | 过阈值清除 fallback → `endSession()`；未过阈值子分支必须保留 fallback（存活到 pointerUp） |
| :162 `controller.state == .idle` | 不需要 | 本波修复后「idle + 抑制残留」态不再由本函数族产生（fallback 消费点已恢复）；在此加补偿守卫属过度修复 |
| :163/:164 scope/geometry/layout nil | 不需要 | 活跃会话进行中；其终点由后续 pointerUp 的 controller 事件（.clicked/.committed/.noOp/.cancelled/.rejected）统一 endSession；提前清违反「抑制保持到整个仲裁结束」设计 |

### pointerUp
| return 点 | 需要否 | 理由 |
|---|---|---|
| :177 `isTornDown` | 不需要 | 终态守卫 |
| :178 `visualHost == nil` | 不需要 | 同 pointerDragged :142 |
| :187-188 pendingBlankPress 分支 | 不需要 | 空白路径从不 beginArbitration；onOverlayBlankClick 派发后本分支无残留状态（pendingBlankPress 已 :184 清） |
| :190-202 clickFallback 分支 | **需要（本波已修，:197）** | 所有子路径先 `endSession()`（恢复 `clickRecognitionSuppressor(true)`），未过阈值再派发 `onCellClick(fallback)` |
| :204 `controller.state == .idle` | 不需要 | 同 pointerDragged :162 理由 |
| :209 pressed 分支末 return | 不需要 | 事件内 .clicked → dispatchClick + endSession（handleEvents :288-291）已走 |
| :216 / :221 geometry/layout nil | 不需要 | 已走 `cancel(.teardown)` → endSession（:238-241），路径本来就正确 |

### §2.3 pointerDown :129-139（sourcePresent 失败路径）排查结论
- `controller.pointerDown` 内部：`state != .idle` → 先 `cancel(.secondDrag)`（resetSession → controller idle），再 sourcePresent 拒 → 事件仅 `[.cancelled(.secondDrag)]`、无 `.pressed`（DragSessionController.swift:62-92 已核实）。coordinator 侧 `handleEvents` 对 secondDrag 按既有设计保持仲裁（不动），于是 `isSuppressingClickRecognition` 残留为 true。
- 该残留的唯一消费出口 = fallback 两个分支（pointerUp :190-202 / pointerDragged :153-161）——本波已在两处接 endSession，残留闭合。**pointerDown 内不追加 endSession**：那会 un-arm 刚武装的 `clickFallbackCell`，破坏 Defect-3 stale-source 点击回退。
- `sourceCell` 残留：:128 赋值是机制必需（endSession 的 cell 级恢复与 secondDrag 单元切换依赖它）；消费点全部清理。
- second-drag 仲裁语义：未动（`.cancelled(.secondDrag)` 保持仲裁照旧）。

## 2. 改动摘要（行数净变化 ≈0～微增，零新机制/状态/字段）
- `pointerUp` clickFallback 分支：3 行显式清除（clickFallbackCell/DownPoint/sourceCell）替换为**先 `endSession()` 后派发**（endSession 为超集：抑制恢复 + 全量清场）；顺序按 §2 要求——防 `onCellClick → handleDragCellClick → launchController.handleCell → 呈现更新 → 重入 cancel(.catalogRefresh)` 时状态半旧半新。
- `pointerDragged` fallback 过阈值清除分支：2 行显式清除替换为 `endSession()`（同样超集）。
- 行数：coordinator 446→450（+4，含注释）；测试文件 503→608（+105）。
- 未触碰：AppDelegate.swift、AppGridCellView.swift、DragSessionController.swift、AppLaunchController.swift、冻结树、Docs/、PROVENANCE/。

## 3. suppressor 调用次数/时序证据（新增测试，全部通过）
新增 `Tests/AppGridUITests/DragUISessionCoordinatorTests.swift` MARK-12 三个用例（swift test 实跑记录 "passed"）：
1. `testStaleSourceFallbackClickRestoresSuppressorBeforeDispatchingClick`：真实 down（suppress(false)）→ 第二个 down 被 sourcePresent 拒（controller 重置 idle、无 .pressed）→ 未过阈值 up。断言事件序列 **`["suppress(false)", "suppress(true)", "click(stale)"]`** —— 直接断言 suppressor 收到 `true`（非仅 isSessionActive）+ **先恢复后派发**时序。
2. `testStaleSourceFallbackDragOverThresholdRestoresSuppressor`：过阈值清除 → suppressor 序列 `[false, true]`；up 不派发回退点击、无重复恢复（残留=0）。
3. `testStaleSourceFallbackSuppressionBalanceOver20Repetitions`：同序列 ×20 → 断言 `falseCount == 20`、`trueCount == falseCount`（20/20 配平，无累积）、`clicks == 20`、`controller.state == .idle`。

## 4. 验证执行记录（真实执行）
- `swift build -c debug` → **exit 0**；`swift build -c release` → **exit 0**。
- `swift test` 全量：**1015 = 基线 1012 + 本波 3 新增**；本波 3 用例每次运行均 passed。
- 全量运行间歇性失败（范围外，报而不修）：`PagingUITests.RunLoopFrameDriverTests.testStartIsIdempotentAndPumpCompletesSettleThenTeardownStops` —— 真实 RunLoop 60Hz 泵时序型测试（`spinMainRunLoop(0.4)`），全量负载下 5 断言抖动失败；**隔离运行 7/7 全过（exit 0）**，且多次全量运行中出现过整体全绿（1015/0，exit 0）。该套件属 PagingUI（本波冻结树），与本改动（AppGridUI drag coordinator）无模块交集，判定为既有 flake，按 §6「范围外失败报而不修」处理，建议后续单开 flake 修复任务。

## 5. 验收映射（§7）
| 验收项 | 证据 |
|---|---|
| 直接断言 suppressor 收到 true | §3 测试 1/2 事件序列断言（非 isSessionActive 替代断言） |
| 同一序列 20 次配平 | §3 测试 3（falseCount==20 ∧ trueCount==falseCount） |
| §2.1 逐条 return 清单 | 本文件 §1 |
| 实机脚本 4/7（建夹后点 app 能启动/点空白能退出；交替 20 次不退化） | **本 Worker 未执行**（CLI 无 GUI 实机环境）：待 Chief/Main 按 `Workflow/BUG6-FIX-PROMPT.md §7` 脚本 4/7 实机复验；复验焦点 = 建夹后真实会话被 secondDrag+sourcePresent 拒绝后的一次点击（正是堵漏路径） |

## 6. 风险
1. `cancel()`（coordinator 公开取消）在 `controller.state == .idle` 且抑制残留时不会 endSession —— 本波修复后该残留态不再由本函数族产生；保留现状以遵守「不新增机制」注记。
2. `visualHost` mid-session 变 nil（host 被释放）理论上可携抑制残留至 teardown —— AppDelegate 侧 host 生命周期归 wave-c2 评估，本波不越权。
3. RunLoopFrameDriverTests 全量 flake（见 §4）——非本波引入，需要独立任务收敛。