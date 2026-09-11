# T-1F-B10-wave-a-forensics — 独立 Reviewer 审查结论

Status: **PASS**（1 项文档性 deviation，不影响合并；零行为变更铁律核验通过）
Reviewer: 独立只读门禁（glm-5.3-flash:cloud）
审查对象：Workflow/results/T-1F-B10-wave-a-forensics.md + 5 个改动文件
核验方式：源码逐行对照（git 不可用，mtime 扫描 + 内容比对）+ 全量测试独立复跑

## 1. 零行为变更（最高优先级）— PASS

| 布点 | 位置（现行） | 核验结论 |
|------|-------------|---------|
| s14 hitTest 入口 | FolderOverlayView.swift:305 | `ClickCensus.hit(...)` 在 `super.hitTest` 之前，仅计数；返回逻辑 `if hit === prevButton/nextButton { return hit }; return self` 与改前逐字一致（:306-310） |
| s15 mouseDown 静默 return | FolderOverlayView.swift:284 | 计数在成员 for 循环无命中后的 `return` 之前；三分支（成员→pointerDown+return / 面板内非成员→静默 return / 遮罩→pointerDown(nil)）结构未动（:274-288） |
| s16 closeFolder 尾部 | AppDelegate.swift:797-800 | `if let overlay = folderOverlay { ClickCensus.hit(...) }` 纯读 `overlay.superview == nil`，零状态变更；位于 `refreshFolderOverlay()` 之后、函数尾（:784-801） |
| s17 blankClickResolvesToCell | AppDelegate.swift:1174 | 祖先 walk 仅写局部 `chainHasOverlay` 布尔位（:1160-1168），计数在 cell 分支 `return true` 之前；返回路径 true/false 与改前一致（:1150-1180） |

零行为回归断言在测试中逐一对齐：hitTest 返回值（成员/遮罩→overlay、按钮→NSButton，含 detached 态）、mouseDown 三分支（.pressed / 静默+idle / 空白派发）均有夹具断言（FolderOverlayForensicsTests 5 个行为测试）。

## 2. 写范围合规 — PASS

mtime 扫描（2026-09-02 17:00–19:30 窗口）确认仅 5 个声明文件被触碰：
- Sources/AppGridUI/FolderOverlayView.swift（18:14）、Sources/PagingPrototypeApp/AppDelegate.swift（18:27）、Tests/AppGridUITests/FolderOverlayForensicsTests.swift（18:51）、Tests/PagingUITests/BlankClickToQuitTests.swift（18:47）、Tests/PagingUITests/DragCommitIntegrationTests.swift（18:41）
- 冻结/禁写文件零触碰：AppLaunchController.swift（Aug 28）、DragParameters.swift（Aug 31）、DropIntent.swift（16:39 = wave-c 窗口）、DragUIVisuals.swift / DragUISessionCoordinator.swift（17:52 = wave-b 窗口，ClickCensus 核心零改动）
- sink 均以 `extension ClickCensus.Sink` 追加（FolderOverlayView.swift:465-480、AppDelegate.swift:1208-1228），机制零改动
- DragParameters 无新字段（文件未动）

## 3. 布点 5 停手合规 — PASS

- AppLaunchController.swift:95-96 实核：`NSClickGestureRecognizer(target: self, action: #selector(handleGesture(_:)))` — target/action 均指向 AppLaunchController 自身（:102-105 `@objc private func handleGesture`），**不存在 AppDelegate 挂接的 action 闭包**
- AppLaunchController.swift 全文零 ClickCensus/s18 引用（grep 确认）；全仓 s18 零落地
- 结果文件 §4 停手理由与任务包条款逐字对应（「若 action 闭包也不在 AppDelegate，则停手报 Main 走 D4 冻结面升级」）；§7 判别表 s18 列全部标注 "—"
- 裁定：停手路径为任务包明示允许，非 FAIL；AppDelegate 侧无越权替代实现（sA 为既有观测点，非新增）

## 4. census 纪律 — PASS

- sink 命名中性：s14_overlay_hittest / s15_overlay_mousedown_silent_return / s16_closefolder_overlay_state / s17_blankhit_chain_has_overlay
- 仅计数 + 布尔位（_sv1/_sv0、_ov1/_ov0），无坐标/标题/app 名/窗口标题
- env 门控确认：DragUISessionCoordinator.swift:84 `PAGING_CLICK_CENSUS == "1"` 才输出（默认零输出），:93 stderr 格式 `PAGING_CLICK_CENSUS <sink> <n>`

## 5. 测试证据 — PASS（1 项 deviation）

- **全量复跑（Reviewer 独立执行）**：`swift test` → `Executed 1083 tests, with 0 failures (0 unexpected)`，exit 0 — 与声称 1083/0 完全一致
- 定向套件计数核验：FolderOverlayForensicsTests 6 个测试方法（6/6 ✓）、BlankClickToQuitTests 19 个（19/19 ✓，含原 15 + 新 4）、DragCommitIntegrationTests 13 个（13/13 ✓）
- 计数算术自洽：1062（基线）+ 10（wave-a）+ 7（wave-b）+ 4（wave-c）= 1083 ✓
- 零行为回归断言在位（见 §1）
- **Deviation（文档性）**：结果文件 §6 未含 swift test 全量 executed/failures **原文**（wave-b/wave-c 结果文件均含 verbatim 行）；仅摘要行「1083 tests, 0 failures」。声称数值经 Reviewer 独立复跑证实为真，证据实质成立，但格式未达任务包「原文」要求——建议 Main 知悉，不构成行为/证据 FAIL

## 6. 纪律 — PASS

- 无 git 操作痕迹（结果文件零 git 引用）
- 无禁读来源引用（任务包无禁读条款；引用仅任务包/FIX-PROMPT/决策/源码）
- 结果文件 0 个代码块（无大代码块）
- 隐私中性（§4 核验）

## Deviation 汇总

1. （文档性）§6 缺全量测试 verbatim 输出原文 — 数值已独立复跑证实
2. （说明性）§6 基线分解「1062 + 10 + wave-b」未列 wave-c 的 4 个测试，总数 1083 正确
3. （说明性）行号漂移声明与实核一致（closeFolder :784-793 vs 任务包 :774-782；sink 声明行号 ±1 括号差异，无实质影响）

## 结论

**PASS**。零行为变更铁律逐行核验通过（4 布点均仅计数/布尔位，返回逻辑与分支结构零改动）；写范围、布点 5 停手、census 纪律、纪律项全部合规；1083/0 全量测试经 Reviewer 独立复跑证实。唯一 deviation 为结果文件缺 verbatim 测试输出原文（文档格式，非行为/证据问题），建议 Main 合并时知悉即可。
