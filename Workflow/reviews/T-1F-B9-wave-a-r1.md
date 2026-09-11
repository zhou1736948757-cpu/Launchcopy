# T-1F-B9-wave-a — 独立 Reviewer 审查（r1）

Reviewer: chef-worker-reviewer-workflow 独立 Reviewer（glm-5.3-flash:cloud，只读门禁）
对象: Workflow/results/T-1F-B9-wave-a.md（Worker，fresh context）
日期: 2026-09-01 23:16（独立实跑时间戳）

## 唯一判定: **PASS**

## 审查焦点逐项

**A. hitTest 守卫 deviation#1 — 采纳（QUESTION-Q2 请 Chief 背书）**
AppKit 契约：`hitTest(_:)` 的 point 在**父视图坐标系**，`frame` 亦为父坐标系 → `frame.contains(point)` 即「点在 bounds 内」在正确坐标系下的逐字实现，语义主体未偏离任务包 §5.1。任务包内部张力：字面「照抄 FolderOverlayView 模式」与「点在 bounds 内」矛盾——先例 overlay 实际**不设守卫**（frame 外 super.hitTest→nil 落穿到 `return self`），其可容忍是因为 overlay 为模态全覆盖；grid cell 有兄弟/空白邻居，无守卫必劫持 frame 外命中。Worker 的 neutralize 实验（无条件 self → 4 测试 13 断言失败：空白分类 s8/s8c 翻转、launched≠rejectedNoBinding）机理自洽（父视图逆序下探，先问后加的子视图），与 AppDelegate 窗口层 cell 判定（s8d 面）互证。不调 super 的差异合理：cell 无交互子控件（仅 iconView/nameLabel/memberCountLabel/folderSymbolView，全被动 NSControl/NSImageView 家族，逐一见 §2 核实），无按钮例外需求。frame 外行为面：守卫后 cell 返回 nil = 基线默认行为（无覆写时 frame 外默认亦 nil）→ **零新增行为面**。意图满足：icon/名称/格内空白统一路由 cell.mouseDown（测试①②③ + 窗口路由面双查证实）。

**B. census — PASS**
s10 于 mouseDown 入口第一行（AppGridCellView.swift:189，lookup 之前，nil 路径亦计数，测试⑤断言 s10 恒≥1）；s11 于 `dragCoordinator ?? shared` 解析 nil 分支（:190-193）。位置正确。计数经 ClickCensus.hit：内存恒维护（env 检查在自增之后）、stderr 仅 `PAGING_CLICK_CENSUS=1`（DragUISessionCoordinator.swift:84-93 既有管道零改动）。sink 名逐字匹配规格：`s10_cell_mousedown_fired`/`s11_cell_lookup_nil`。仅计数、无身份泄漏。`extension ClickCensus.Sink` 落 AppGridCellView.swift 文件尾（:234-241）= §5.2 明文授权位；coordinator 文件 grep s10/s11 零命中。

**C. 零行为面外溢 — PASS**
mouseDown 主体：optional-chaining → guard-let 为 §5.2 观测 nil 分支所必需，语义等价（nil→不派发）、不调 super 维持。mouseDragged/mouseUp（:197-205）与 FolderOverlayView 同款 optional-chaining 模式逐字一致，无 super。setClickRecognitionEnabled（:180-182）/folderClickRecognizer 接线（:45,:96-98）未动；recognizer 挂 cell 自身，hitTest→self 事件仍达（测试⑥拖拽链完整 + 不派发点击旁证）。无 acceptsFirstMouse（wave-b Stage 2 预授权项未越权）。拖拽仲裁/AppLaunchController/overlay 零触碰（测试⑥⑦回归 + 冻结文件 mtime 佐证）。

**D. 测试 — PASS**
7 测试真实断言：①②③ 用 cell.hitTest（父坐标系转换，注释明示调用约定）+ `window.contentView?.hitTest` 真实下探双面，`=== cell` 身份断言；④ `.pressed` + s10≥1（snapshot 与单 sink 双查）；⑤ 双 nil → s11+1 不 crash 且 s10 恒计数（defer 恢复 shared）；⑥ 漏斗内 pressed→dragging（20pt≥6 阈值）→ clicks==0；⑦ overlay.hitTest===overlay 且非 AppGridCellView。背景点 (6, maxY-4) 避让 icon[20,68]/标签[0,26] 区间核实。夹具中性（fixture.* 合成、无真实身份）；shared 全局操作带 defer 恢复 + tearDown 清理，与 T1FD1FixUITests 同法。

**E. 写范围 — PASS（MINOR-M1 取证注记）**
wave-a 窗口（9月1 23:00–23:08）mtime 命中 4 文件：Bug9CellHitRoutingTests 23:00:47、AppGridCellView 23:05:16（wave-a 两文件）；AppDelegate 23:03:12、DragCommitIntegrationTests 23:05:29 —— **mtime 无法单独归因**，内容定案：两文件均带明文「T-1F-B9-wave-b Stage 1」标记（AppDelegate:605/:1069/:1142-1152 s8e/s13；测试 :921-969），且 `Workflow/results/T-1F-B9-wave-b.md` 存在 → 并行 wave-b 授权文件，与 wave-a 零交集成立（wave-a 文件无 s8e/s13，wave-b 文件无 s10/s11）。冻结树核实：Package.swift 08-28、AppLaunchController 08-28、六冻结目录 ≤08-30、FolderOverlayView 08-31 09:29、DragUISessionCoordinator 9月1 22:02:38（早于 wave-a 起点且内容无 s10/s11）——全部零触碰。无 git 操作。

**F. 独立实跑 — PASS（与 Worker 计数互证一致）**
```
swift build -c debug   → Build complete! (4.16s)  exit 0
swift build -c release → Build complete! (2.74s)  exit 0
swift test → Test Suite 'All tests' passed at 2026-09-01 23:16:11.736.
             Executed 1062 tests, with 0 failures (0 unexpected) in 47.407 (47.721) seconds
Bug9CellHitRoutingTests: 7 cases 全 passed（8 passed 行 = 7 case + 1 suite），0 failed
```
executed_tests=1062>0（非 INVALID_TEST_EXECUTION）；1062/0 与 Worker 报告逐字一致。

**G. 红线 — PASS**
Reviewer 全程未读 LaunchBetter/BuhoReverseNotes/2026-08-25-buho-launchpad-reverse；代码与测试无真实 app 名/bundleID/路径（fixture.* 合成）；无 git 操作；隐私代称维持。

## Findings

- **BLOCKER**: 无。
- **MAJOR**: 无。
- **MINOR**:
  - M1: 写范围归因依赖内容标记（s8e/s13 ↔ s10/s11 标记互斥）而非纯 mtime；建议 Main 合并注记记录该归因依据。非 Worker 过错（并行波固有）。
  - M2: neutralize 实验证据为 Worker 自报（§3 13 失败），Reviewer 未复现该反向实验（守卫必要性经机理分析 + 全量通过面佐证，风险低）。
  - M3: results 文件存在两个「§7」标题（Deviation / 未触碰声明重复编号），格式瑕疵不影响内容。
- **QUESTION**:
  - Q1: 漏斗后 hitTest 恒返 self，nameLabel.toolTip（bind 时设置）是否仍经 tooltip 链呈现未测；建议并入 Main 实机验收观察（悬停提示非 §6 验收面，低影响）。
  - Q2: 「点在 bounds 内一律返回 self」与先例（overlay 无守卫）矛盾已由 deviation#1 以实验裁决——请 Chief 背书「frame.contains 守卫 = 后续波抄写该模式的标准形」，避免下一波照抄 overlay 无守卫版本回归 BUG。

## 结论

R1 修复面（hitTest 漏斗）+ census 布点（s10/s11）按任务包意图落地，deviation 1/2/3 全部合理且有实验或语义等价支撑；测试 7 项真实断言；独立实跑 debug/release exit 0、1062/0 与 Worker 互证；写范围与红线干净。**PASS，交 Main 合并**；Q1/Q2 随合并注记带交。