# D-2026-09-02-bug8-diagnosis — BUG8 诊断定案

Status: adopted（Chief 诊断定案；Main 派发）
上游：Workflow/BUG8-REPORT.md（诊断全文）、tasks/T-1F-B8-planning.md（权威规格）

## D1 蓝条根因定案（静态铁证）

`DragUIVisuals.updateIntent`（DragUIVisuals.swift:89-90/:92-93）把 Wave B′ 后的**全局** intent 下标直接配**页内** frames；`insertionRect`（:169-184）`index >= frames.count` clamp 末帧右缘（:176-178）= 网格右下角，与用户症状逐字吻合。`.topLevelTarget`（folder move-out，帧注记 topPage）同病。修法边界：**仅 DragUIVisuals.swift**——帧注记回减 `local = global − pageIndex×itemsPerPage`（只信 DragItemFrame 注记，绝不用 geometry.page），注记 nil 原样回退。落点语义零改动（resolver/engine 不动）。

## D2 缺陷 2 诊断结论：无唯一静态根因，取证先行

三现而三修不中的方法论根因已实证：C′ harness 直呼 coordinator + 镜像 handleDragCellClick（DragCommitIntegrationTests.swift:463-471/:152-163），结构性绕过 window.sendEvent/cell.mouseDown/surface recognizer/key-window/真 AppDelegate 五层。静态全链（BUG8-REPORT §2.1-§2.3）给出完整 sink 清单 S1-S9，但单点静态推理无法在多 sink 中唯一裁决真机吞点。** mandate：Stage 1 取证（中性 census + harness 补盲区 + 实机 E1-E7 实验序列）→ 证据落盘 → Stage 2 结构修改。**

## D3 Stage 2 预授权（已证潜伏缺陷，与 census 证据无关也须修）

1. N1：pointerUp blank 分支（DragUISessionCoordinator.swift:181-186）补 endSession（幂等）——Wave C 只堵了 fallback 分支，blank 分支从未审计；抑制滞留 = 双启动通路齐灭的唯一自洽形态。
2. N3：pendingBlankPress 收窄为 sourceCell==nil；resolveSource 失败且有 cell → clickFallbackCell（C′ QUESTION-1 死路 A 转正收口）。
3. N2：dragGate :105「点击不受影响」注释与实现矛盾——仅改文档；行为拆分需另行决策。
4. 防过度修复：census 未指到的面不改；AppLaunchController 冻结不动。

## D4 升级路径

Stage 1 证据指到冻结面（S9 rejected 族 / recognizer 行为）→ 升 Main 按 BUG6 D4 先例做等效评估；harness 无法覆盖的层（真窗口 server 行为）以实机 E 序列 + census 为准。

## D5 调度

wave-v（DragUIVisuals.swift）与 wave-c（coordinator/AppDelegate/tests）写范围零交集，可并行；Main 合并时统一基线复验（1036+新增）。决策先例：BUG6 D6 净删原则适用于 census 开关（默认关、可整体摘除）。