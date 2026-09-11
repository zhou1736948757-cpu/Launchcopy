# Reviewer Verdict — T-1F-B10-wave-b（BUG10 缺陷 B：drag preview 被 overlay 遮挡，方案 B1 宿主切换）

- **Reviewer**: glm-5.3-flash:cloud（独立只读门禁，零文件修改）
- **日期**: 2026-09-02
- **结论**: **PASS**（8/8 项核验全过；2 deviation 均裁定接受）

## 逐项核验

### 1. 写范围合规 — PASS
- mtime 扫描（`find Sources Tests -newer Workflow/tasks/T-1F-B10-wave-b.md`，任务包 16:33:22）：wave-b 落点恰 4 文件——`DragUIVisuals.swift`（17:52）、`DragUISessionCoordinator.swift`（17:52）、`AppDelegate.swift`（17:54）、`Bug10PreviewHostTests.swift`（18:05）。DropIntent.swift（16:39）/Bug6DropZoneGeometryTests.swift（16:41）为并行 wave-c 领地（events.jsonl seq 716 已合并 1066/0），非本波。
- 冻结树全部早于任务：PagingCore 08-28/30、AppCatalogCore 08-28、MacAppCatalog 08-28、AppIconPipeline 08-29、PagingTelemetry 08-28、PagingUI 08-28/30、Package.swift 08-28、AppLaunchController.swift 08-28。
- 禁写零触碰：DropIntent.swift（wave-c 领地，16:39 归 wave-c）、FolderOverlayView.swift（08-29）、DragParameters.swift（08-31，无新字段——`makeParameters()` 测试夹具仅用既有 8 字段）。
- Reduce Motion 路径（DragUIVisuals.swift:90-98 既有分支）逐行核对原样在位，未触碰。

### 2. Deviation 1（closeFolder 收敛）— **接受**
- a) 必要性成立：任务包 §6.2 要求「宿主切换与 visualHost 切换同一动作/同一处驱动（AppDelegate 刷新 overlay 时驱动）」。若 closeFolder 仍直接 clearContent+removeFromSuperview 绕过 refreshFolderOverlay，关闭后 visualHost 滞留已摘除的 overlay，pointerDragged（:272 `host.convert`）将经 detached 视图换算——顶层拖拽回归（§7 ④）必破。收敛是实现「唯一驱动点」的必要最小改动。
- b) 原行为未破坏：closeFolder（:784-793）保留 cancel(.overlayClosed) → endTitleEditing → isTitleEditing=false → folderOpenState.close() 原序；clearContent+removeFromSuperview 原样保留在 refreshFolderOverlay nil 分支（:830-831），顺序与幂等不变（已摘视图上 removeFromSuperview 为 no-op）。
- c) 无行为回归：关闭后 overlay 正确移除（nil 分支）、宿主切回 surface（:832 setVisualHost(surface)，同值幂等）；teardownAll（:1015-1017）独立路径不受影响。**裁定：收敛未改变 closeFolder 既有语义，仅收敛出口，接受。**

### 3. Deviation 2（visualViewSuperviews 诊断可观测）— **接受**
- 仅测试/诊断用途：`public var visualViewSuperviews: [NSView?]`（DragUIVisuals.swift:46-48）为纯 getter，返回四视图 superview 引用；沿用既有 public 诊断可观测先例（isPreviewVisible/previewFrame/insertionIndicatorFrame）。
- 隐私中性：无坐标/标题/app 名，仅 NSView 引用。零生产路径影响（无副作用、无调用点——grep 证实仅测试文件消费）。

### 4. 同源锁 — PASS
- `setVisualHost`（DragUISessionCoordinator.swift:202-205）：同一动作内 `visualHost = newHost` + `visuals.setHost(newHost)` 两半同步。
- pointerDragged（:269-302）：`host = visualHost`（:271）→ `host.convert(locationInWindow, from: nil)`（:272）→ `visuals.movePreview(to: 同点)`（:299）——preview 坐标系与指针坐标系同源。任务包行号 :257-259 为改前漂移，语义一致。
- 契约测试 testPreviewStaysGluedToPointerAfterHostSwitch 用窗口化双宿主（overlay 偏移 (100,50)）实测：切换后 preview 帧 = overlay.convert(pointer) − 偏移，继续拖动仍贴——独立复核断言数值正确。

### 5. 幂等性 — PASS
- setHost（:65-73）：同值（superview === newHost）短路不重复 addSubview；异值迁移已挂载视图（AppKit addSubview 自动从旧父移除，无两父漂移）；未挂载（含 teardown 后）不重挂；nil 仅记录 host。
- attach（:237-240）`view.superview !== host` 短路在位；teardown（:148-154）四视图全 removeFromSuperview。
- 测试 ① 四条（同值/异值迁移/teardown 后/coordinator 层同值）断言 subview 计数与帧不漂移，独立复核通过。

### 6. 契约注释 — PASS
- makeDragGeometry 注释（AppDelegate.swift:625-635）写死：host = visualHost 与 attach 宿主同源；topLevel scope 帧 = surface 系；folder scope 成员帧与顶层帧**均 convert 到 overlay 系**（同系，move-out 不跳变）；成员帧不注记分页、顶层帧注记 committedPage（绝不复用 geometry.page=innerPage）——与 FIX-PROMPT §3.3 逐句对应，实现（:637-674）与注释一致。

### 7. 测试证据 — PASS
- 结果文件含 `swift test` 全量原文：`Executed 1073 tests, with 0 failures (0 unexpected) in 34.346 (34.605) seconds` + Bug10PreviewHostTests 7/0 + debug/release build exit 0。
- **Reviewer 独立实跑复跑**：全量 **1073/0**（29.3s，exit 0）——与声明逐字吻合。基线 1066 + 新增 7 = 1073 成立。
- 7 测试覆盖任务包 §7 四项：①幂等 4 条、②同源锁 1 条、③move-out 1 条（顶层蓝条 (77,0,3,80) 与 preview (152,64,96,88) 同 overlay 系，独立复算一致）、④顶层回归 1 条（host 恒 surface、commit 正常）。

### 8. 纪律 — PASS
- 无 git 操作（仓库零 commit、全 untracked；`git status` 只读自证 + mtime 扫描替代 diff，结果文件已如实说明）。
- 禁读来源仅出现在「未读取」声明（合规披露，非引用）；结果文件 62 行无大代码块（仅测试输出摘录）；隐私中性（夹具标题 app1/app2 合成数据，无真实 app 身份）。

## Deviations / 风险

- **Deviation 1 裁定：接受**（closeFolder 收敛 = §6.2 唯一驱动点必要最小改动，语义未变）。
- **Deviation 2 裁定：接受**（visualViewSuperviews 仅测试/诊断，隐私中性，零生产影响）。
- 风险（MINOR，非阻塞）：wave-a-forensics（未落盘）任务包引用 closeFolder 旧行号 :774-782，wave-b 已移至 :784-793——forensics Worker 需按 D6 先例重钉行号；其静态假设「closeFolder 只 removeFromSuperview」现为「经 refreshFolderOverlay 收敛」，终态（overlay 摘除、superview=nil）不变，census 布尔位语义不受影响。Main 合并序建议 forensics 落盘时核对。
- 结果文件「未触碰：…（:67-75 原 :90-98）」行号标注易误读，实质（Reduce Motion 分支原样）已核验无误。

## 结论

**PASS** — 达到合并标准。可交 Main 合并。
