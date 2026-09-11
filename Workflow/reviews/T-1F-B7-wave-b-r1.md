# T-1F-B7-wave-b — Reviewer 评审报告 r1

- **判定：PASS**
- Reviewer: 独立 Reviewer（chef-worker-reviewer-workflow v1.4.1，只读角色，未改任何实现/测试文件）
- AccessDeclaration: NO_PRIOR_EXPOSURE（未读取 LaunchBetter/、BuhoReverseNotes/、2026-08-25-buho-launchpad-reverse 及任何 Ghidra/otool dump）
- 日期：2026-09-01；评审对象 = Worker 终版结果 + 当前工作树实况

## 独立核验记录（A–H，全部完成）

**A. 公式正确性 — ✅**
换算唯一发生在 intent 产出边界：`DropZoneClassifier.globalIndex`（DropIntent.swift:245-250，`page * itemsPerPage + localIndex`），消费点 = `insertionIntent`（:235/:238，hit 与未命中两路均过换算）与 `.topLevelTarget` 分支（:214-217）。全仓 grep 证实该公式仅存在于 DropIntent.swift（无第二处）。消费端零改动、零二次换算：DropResolver.swift:63-76 仍按全局 `topLevelOrder.count` 校验（.insertion 顶层 :66 / .topLevelTarget :75-76）；DragMutationEngine.swift:24-47 直接消费；`reorderAdjustedIndex`（:77-80）只做 remove-then-insert 差一，`.topLevelTarget` 明确不经它（:76 注释），与任务包禁令逐字一致。公式闭合性：满页插最后之后 local=35 → 35+35=70=count，resolver :66 接受（测试③实证）。

**B. Deviation 评估 — ✅ 合理（关键项，独立验证）**
Worker 声明核验属实：生产链路 `DropZones` 唯一构造点 = `DropZoneBuilder.zones`（DropIntent.swift:166），其唯一生产调用点 = 冻结的 `DragSessionController.currentIntent`（:253-261，逐字段转发 itemFrames/topLevelFrames/containerWidth/moveOutArmed/parameters）。要在 `DropZones`/`zones()` 上携带 page+itemsPerPage 必须改冻结调用点签名 → 写范围内不可达；`DragItemFrame` 注记是链路中唯一可带换算信息的写范围内通道（全仓 grep：`.annotated(` 仅 AppDelegate :618/:636 两处注入，均 D 层 makeDragGeometry）。措辞修正：构造点本体在可写的 DropZoneBuilder（测试另可直接 init DropZones），但"无法在不动冻结文件的前提下转发新字段"的实质声明成立。规格要求的换算边界（classify/insertionIntent）、禁令、folder 不乘外层全部满足 → 不可避免的合理 deviation，已记录理由。注意：tests 直构 DropZones 的两处（本波测试文件 :253/:260）不走 builder，无影响。

**C. 测试完整性 — ✅（7 测试断言值全部独立手算复核）**
① `testPage1InsertionConvertsToGlobalIndex`：local2 右半 → local 3 → 1×35+3=**38** ✓；commit 换算 38−1（源 a01 全局 0）→ [37]=a01、[36]=a38、[38]=a39 ✓。② 左半：local34 → **69**；commit −1 → [68]=a01、[69]=a70 ✓。②b 右半：local35 → **70**；[69]=a01=末页最右列 ✓。③ x=3500 未命中任何帧 → 中点计数 local35 → **70**，[69]=a01 ✓。④ 位移 130pt armed 但指针落在顶层 a36 内缩区（108..172 含 170）→ landing false → 成员插入 local2（成员帧无注记）→ **2** 非 37；members=[b2,b1,b3]、顶层序不变 ✓。⑤ 位移 250pt armed、指针在 a37/a38 缝隙 → local3 → 35+3=**38**（误用 innerPage=0 会得 3）；new[38]=b1、members=[b2,b3] ✓。⑥ 同指针注记→**37** / 无注记→**2**（换算仅一次）✓。覆盖任务包必补 ①②③④ + Worker 增补 ⑤⑥，无缺项。夹具中性（a01…a70/b1…b3/Group A、fixture.*）。

**D. 页号陷阱 — ✅**
AppDelegate.swift `.folder` 分支：成员帧不注记（:625），顶层帧注记显式用 `surface.core.committedPage`（:634-636 topPage），绝不复用 `state.innerPage`（geometry.page 仍 = innerPage :626）；测试⑤结构性锁定（同几何 innerPage=0/committedPage=1 → 38）。

**E. 写范围 — ✅（mtime 取证）**
本波窗口（2026-09-01 18:58:57–19:02:15）全仓改动恰为 4 个授权文件：DragGeometry 18:58:57 / DropIntent 18:59:08 / AppDelegate 18:59:15 / Bug7PageAwareDropTests 19:02:15（其余为 Workflow 簿记）。冻结树最新 mtime 均早于本波：PagingCore 08-30、AppCatalogCore/MacAppCatalog/AppIconPipeline/PagingTelemetry 08-28、PagingUI 08-30、Package.swift 08-28、AppLaunchController 08-21:46(08-31 前日 08-28)、DragSessionController 08-31 02:13、DropResolver 08-31 02:13、DragMutationEngine 08-31 23:52（BUG6 wave）、DragParameters 08-31 01:57。AppDelegate BUG7 标记仅 :615/:630（均在 makeDragGeometry :608-645 内）；handleDragCellClick（:651+）仍原样转发 launchController.handleCell、QuitOnBlankClickWindow 未动 → Wave C′ 范围未被碰。
**观察（非本波违规）**：`Docs/ADR-010` mtime 19:01:37 落在窗口内（Docs/ 属本波禁写）。内容核验：改动全部为 Wave A′ M3 "格子位置语义 insertion = targetIndex" 文档同步（BUG7-FIX-PLAN §2.4 属 Wave A′ 写范围），零 wave-b 内容 → 归因并行 Wave A′/Main，不构成本波 FAIL 项。但该编辑晚于 wave-a review（19:00:42），建议 Main 确认其调度归属（见 QUESTION-2）。

**F. 独立实跑 — ✅（真实执行，含波动记录）**
- `swift build -c debug` → exit 0
- `swift test` 全量 ×4 轮：2 轮 `Executed 1033 tests, with 0 failures` exit 0（与 Worker 声称一致）；2 轮 1033 executed / **5 failures** exit 1 —— 5 个失败全部为 `PagingUITests.RunLoopFrameDriverTests.testStartIsIdempotentAndPumpCompletesSettleThenTeardownStops`（真实 RunLoop 泵时序断言），隔离复跑 3/3 全绿（7 tests/0 failures ×3），该文件 mtime 2026-08-29 早于本波、属 PagingUI 域 → 负载相关**既有 flaky**，与本波无关（见 MINOR-1）。`Bug7PageAwareDropTests` 在全部轮次 7/7 passed。
- `swift build -c release` → exit 0
- executed=1033 > 0，非 INVALID_TEST_EXECUTION。

**G. 蓝条回归面（转 Main 决策输入）— ✅ 已独立证实**
① 真实存在且由本波引入（限 page≥1）：DragUIVisuals.updateIntent（:87-93）消费转换后全局 index，`insertionRect`（:169-184）以**页内** frames 定位，`index >= frames.count` clamp 到末条目右缘（:176-178）。修复前 intent=页内下标 → 蓝条每页都正确；修复后 page≥1 中部列全局 index（如 38）≥ 页内帧数（5）→ 蓝条 clamp 页末右缘。② 影响面 = **仅视觉指示**：resolver/engine 消费同一 intent 的全局值，落点语义正确；主验收场景（最右列右半/末尾）蓝条 clamp 位与落位一致，左半差一格，page≥1 中部列固定页末右缘。③ 专业判断：后续单独小波在视觉层按注记回减（local = global − page×itemsPerPage）恢复 page≥1 全列蓝条精度——机械可逆、单文件（DragUIVisuals.swift，不在禁写清单）、低风险、建议尽快排期；但调度属 Main 权限，本评审仅记录 QUESTION-1。

**H. 红线与隐私 — ✅**
评审材料与实现无禁止来源痕迹；夹具中性；次因（edge zone 40pt × 末列右 ~16pt 重叠，hysteresis +10pt）已在结果文件 §4 评估记录，`DragParameters` 未动（mtime 早于本波）。

## Findings

**BLOCKER**：无。
**MAJOR**：无。
**MINOR**
- MINOR-1：既有 flaky `RunLoopFrameDriverTests`（全量压测下偶发 5 断言失败，隔离稳定绿）会污染后续波次的全量测试证据基线（Worker 本轮记录 1033/0 属实且可复现，但非 100% 稳定）。建议 Main 记录在案：后续波评审遇 5 failures 且用例 ∈ RunLoopFrameDriverTests 时按"隔离复跑"程序定性，不归因当波。
- MINOR-2：测试④注释"指针深入成员 b2 内部 → 回退 inner 插入"归因不准——实际门控是 `isTopLevelLanding` 因指针位于顶层 a36 内缩区而 false。行为与断言不受影响，建议后续顺手修正注释（非本波必须）。
- MINOR-3：`globalIndex` 空 frames 时回退页内下标（DropIntent:245-248）——空页 × page≥1 理论上会得 `.insertion(0)`。当前呈现按条目数切页、拖拽无 live reflow，committedPage 恒非空 → 不可达，仅潜在路径；记录备查。
**QUESTION（供 Main 裁决）**
- QUESTION-1：是否授权后续小波修改 `DragUIVisuals.swift`（消费帧注记做 global→local 回减），恢复 page≥1 全列蓝条精度？Reviewer 建议：授权，小波、单文件、与 C′ 无冲突。
- QUESTION-2：`Docs/ADR-010` 19:01:37 的编辑（Wave A′ M3 文档同步）晚于 wave-a review 通过时刻，请 Main 确认该编辑的调度归属与内容（本波核验其内容与 wave-b 无关）。

## 结论
公式、边界、禁令、页号陷阱、测试、写范围、实跑证据全部独立核验通过；deviation 有据且为写范围内唯一可行取径；蓝条事项已定性为视觉层遗留并附专业建议。**判定 PASS，可合并**（QUESTION-1/2 与 MINOR 不阻塞）。