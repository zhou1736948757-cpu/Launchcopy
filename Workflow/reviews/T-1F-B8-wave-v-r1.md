# T-1F-B8-wave-v r1 — 独立 Reviewer 门禁

- Reviewer: independent（fresh context，chef-worker-reviewer-workflow v1.4.1）
- Date: 2026-09-02（证据运行 2026-09-01 22:29–22:33）
- AccessDeclaration: NO_PRIOR_EXPOSURE（未读取 LaunchBetter/、BuhoReverseNotes/、2026-08-25-buho-launchpad-reverse、任何 Ghidra/otool dump）
- Git: 零 git 操作（写范围核验用 mtime/stat，未用 git）

## Verdict: **PASS**（可合并）

## Findings

### BLOCKER
无。

### MAJOR
无。

### MINOR
- M-1（记录，不阻塞）：`localInsertionIndex`（DragUIVisuals.swift:158-164）只读首帧注记，隐含「同一帧列表同页」契约。该契约与 DropIntent.globalIndex（DropIntent.swift:245-250）完全同构，且 clamp [0, frames.count] 保证注记/全局不一致时不越界（仅可能映射到错误帧位）。契约破坏属 D 层（AppDelegate.swift:617-620/:634-640）违约，非本波修复面。无需动作。
- M-2（记录，不阻塞）：Deviation D1 `insertionIndicatorFrame`（:42-43）为纯只读 getter，零行为面，在 §3 写范围内；与既有 previewFrame（:41）同模式。备选（host.subviews 遍历）更脆，D1 选择合理。

### QUESTION
- Q-1（已裁决）：测试计数口径。**独立实测全量 = 1052/0**（非 1061）。工作树同时含 wave-v 文件（Bug8VisualIndexTests.swift mtime 21:27:22、DragUIVisuals.swift 21:29:36）与 wave-c 文件（DragUISessionCoordinator.swift/AppDelegate.swift 22:02:38、DragCommitIntegrationTests.swift 22:04:39）→ Main 的「wave-c 合并后基线 1052」必然已包含 wave-v 的 9 个新测试（1043+9=1052）。Main 若预期 1061 系双重计数；以实测 1052 为准合并。Worker D3 解释与实测一致。
- Q-2（已裁决）：22:02–22:04 的 AppDelegate/DragUISessionCoordinator/DragCommitIntegrationTests 变更**不属于 wave-v**——mtime 晚于 wave-v 终态 21:29，属并行 wave-c 写范围（D-2026-09-02-bug8-diagnosis D5：零交集并行），非 wave-v 越权。

## 独立核验证据（A–F 逐项）

- **A. helper 正确性 ✅**：`localInsertionIndex`（:158-164）`local = global − pageIndex×itemsPerPage`，clamp `min(max(local,0), frames.count)`（含 §8 红旗负下标）；注记任一 nil 或 frames 空 → 原样返回（:159-161）；**.insertion（:92）与 .topLevelTarget（:95）均经 showInsertionBar（:138-139）单入口覆盖**，grep 全 Sources 无第三调用点（§8 红旗 2 未触发）；`geometry.page` 零读取（仅 :157 注释提及）；insertionRect（:191-206）页内纯函数未改、:198-200 clamp 保留。
- **B. 9 测试覆盖 6 验收项 ✅**（Tests/PagingUITests/Bug8VisualIndexTests.swift，9 个 func test）：①testPage1MiddleColumn…（38→local 3，x=263.5≠437，含反向断言）；①+负下标 clamp（global 10→x=0）；②testPage1AfterLast…（40→local 5，x=437=末帧右缘）；③testPage0Unannotated…（index 0/3/5/38 四断言）；④testFolderMemberFrames…（index 2/7 原样）；⑤testMoveOutTopLevelTarget…（geometry.page=0=innerPage 陷阱位 + topLevelFrames 注记 topPage=1，若误用 geometry.page → 437 → 断言失败，结构性锁死）；⑥testPartialAnnotation（pageIndex=1/itemsPerPage=nil → 原样 437）+ testEmptyFrames（两路径 hide）+ testTopLevelTargetUnannotated。
- **C. 变异检查推演 ✅**：helper 禁用（pass-through）时逐测试重演：①中部列（x 263.5≠437 + NotEqual 破，2 断言）、负下标（x 0≠437，1 断言）、⑤move-out（x + NotEqual，2 断言）= **恰 3 测试 5 断言失败**；②（40→437 恰为期望）与 ③④⑥ 未注记/回退路径 pass-through 即旧行为 → 保持绿。与 Worker 声明完全一致。Reviewer 只读，未实际注入变异（分析推演为机械等价：pass-through → global≥5 → :198-200 钳 437）。
- **D. 写范围 ✅**：全仓 stat 扫描——wave-v 窗口仅 DragUIVisuals.swift（21:29:36）、Bug8VisualIndexTests.swift（21:27:22，新建）+ results 文件；冻结树（PagingCore/AppCatalogCore/MacAppCatalog/AppIconPipeline/PagingTelemetry/PagingUI/Package.swift/AppLaunchController.swift）mtime 均 ≤08-31，零触碰；DropIntent/DropResolver/DragMutationEngine/DragSessionController/AppDelegate 本波窗口（≤21:29）零触碰（22:02 后变更归 wave-c，见 Q-2）。两改动文件无冲突标记、无行尾空白（grep 双零命中）。
- **E. 独立执行 ✅**：`swift build -c debug` exit 0；`swift test` 全量 **Executed 1052 tests, with 0 failures (0 unexpected) in 16.407s**，其中 Bug8VisualIndexTests passed（9/0）、Bug7PageAwareDropTests passed（7/0，落点语义未触碰）、RunLoopFrameDriverTests passed（flaky 未现）；`swift build -c release` exit 0。日志仅 "failed" 字符串 = 既有 DBG7 flush 探针诊断（基线即存在）。
- **F. 红线 ✅**：夹具全中性（"fixture.bug8-*"，无真实 bundleID/app 名/路径）；禁读来源零触碰；零 git 操作。

## Merge Recommendation

**合并**。缺陷 1 根因（全局下标进页内 frames → 钳末帧右缘）由单入口回减修复，两路径覆盖、页号陷阱结构性锁死、回退路径向后兼容；BUG7 落点语义零触碰（resolver/engine/DropIntent 未动）；测试有效性与全量绿均为独立复验。计数口径以实测 1052 落账（1061 系重复计入，见 Q-1）。