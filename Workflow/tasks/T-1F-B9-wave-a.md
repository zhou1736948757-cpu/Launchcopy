# T-1F-B9-wave-a — BUG9 主页面点击失效：cell hitTest 漏斗 + cell 层 census

Status: ready
Wave: BUG9-wave-a（与 wave-b Stage 1 零文件交集，可并行）
Role: Worker（实现+测试）→ 独立 Reviewer（只读门禁）→ Main 合并

## §1 背景

BUG9-REPORT §2：窗口层 census 实证 9 次点击全部 cell 命中放行（s8d ×9），coordinator pointerDown 从未被进入（s0-s9 全零，含 teardown 守卫 s0）。断点在窗口放行之后、pointerDown 之前的未布点区间。候选 R1（cell 子视图 NSImageView/NSTextField 默认拦截 mouse 事件不转发 → AppGridCellView.mouseDown 永不触发）为本波修复对象；R5（激活点击吞没）由 wave-b 取证。库内正向先例：FolderOverlayView.hitTest（FolderOverlayView.swift:297-303）恒返回 self——这正是「folder 成员点击能开、主页面不能开」的唯一路由差异。

## §2 根因锚点（全部已实测，2026-09-02 现行行号）

- Sources/AppGridUI/AppGridCellView.swift:184-187 `mouseDown`：`(dragCoordinator ?? DragUISessionCoordinator.shared)?.pointerDown(...)`，无 super。
- 子视图构成 :44 `folderSymbolView=NSImageView()`、:47 `memberCountLabel=NSTextField(labelWithString:)`、:78-82 `iconView`（NSImageView，iconSide² 居中=最大点击靶）、:84-89 `nameLabel`、:91-96 `memberCountLabel`——**全部 NSControl/NSImageView 家族，默认拦截 mouseDown 不向 nextResponder 转发；无任何交互性子控件**。
- 无 hitTest 覆写（全仓 grep 证实）；对照 FolderOverlayView.swift:267-284（mouseDown）+:297-303（hitTest→self，prev/next 例外）。
- window 层 cell 判定 AppDelegate.swift:1077-1090（子视图命中也算 cell → s8d 与「未达 cell.mouseDown」并存不矛盾）。

## §3 写范围 / 禁写

- 写：`Sources/AppGridUI/AppGridCellView.swift`（唯一实现文件）+ 测试（新文件 `Tests/AppGridUITests/Bug9CellHitRoutingTests.swift` 或并入既有 cell 测试文件，二选一，报告声明）。
- 禁写：冻结树六目录 + Package.swift + AppLaunchController.swift；DragUISessionCoordinator.swift（ClickCensus 核心不动，sink 用同文件 extension 追加）；AppDelegate.swift；FolderOverlayView.swift；DragUIVisuals/DropIntent/DropResolver/engine；Docs/；无 git。

## §4 必读

Workflow/BUG9-REPORT.md §1-§2/§5；AppGridCellView.swift 全文；FolderOverlayView.swift:240-310；DragUISessionCoordinator.swift:22-100（ClickCensus 契约）+:200-236（pointerDown 入口序）。

## §5 实施要求

1. AppGridCellView 增加 `override func hitTest(_ point: NSPoint) -> NSView?`：点在 bounds 内一律返回 `self`（照抄 FolderOverlayView.swift:297-303 模式；cell 无交互子控件，**不需要**按钮例外）。效果：icon/标签/背景点击统一进 cell 自身 mouseDown 路由。
2. 同文件加 `extension ClickCensus.Sink`（单文件波，零触碰 coordinator）：`s10_cell_mousedown_fired`（mouseDown 入口第一行）、`s11_cell_lookup_nil`（`dragCoordinator ?? shared` 解析为 nil 时）。仅计数，env PAGING_CLICK_CENSUS=1 门控沿用 ClickCensus 既有输出管道；内存计数恒维护。
3. mouseDown/mouseDragged/mouseUp 主体逻辑零改动（不调 super 语义维持）；setClickRecognitionEnabled/folderClickRecognizer 零改动（recognizer 挂在 cell 自身，hitTest→self 不影响其追踪）。
4. 零行为面外溢：不改拖拽仲裁、不改 AppLaunchController 路径、不改 overlay。

## §6 验证与验收

- 测试（夹具中性，注入实例 coordinator）：①hitTest(icon 中心点)===cell；②hitTest(nameLabel 点)===cell；③hitTest(背景点)===cell；④mouseDown 经 cell → pointerDown 被调（census snapshot s10≥1）；⑤s11 路径：shared 与注入均 nil 时 s11+1 且不 crash；⑥既有 drag 仲裁测试全绿（pointerDown→beginArbitration 未回归）；⑦folder overlay 回归绿（overlay 路径未触碰）。
- `swift build -c debug` / `swift build -c release` exit 0；`swift test` 全量（1052+新增）。
- 验收（实机，Main 组织）：主页面点击**图标**、**名称**、**格内空白**三类均能启动应用；拖拽建夹/移动不回归；folder 打开与成员启动不回归。

## §7 输出纪律

results 写 Workflow/results/T-1F-B9-wave-a.md：改动清单/测试证据（executed/failures 原文）/deviation 逐条/未触碰声明。禁大代码块贴报告。

## §8 风险与 Red flags

- 若实机修复后仍有点击死（R5 为真）：不扩波、不自行加 acceptsFirstMouse——那是 wave-b Stage 2 预授权项，等 census。
- 发现 cell 存在本包未列出的交互子控件 → 停手报告 Chief（漏斗可能吞其事件）。
- 出现「必须改 DragUISessionCoordinator/AppDelegate/冻结文件」的冲动 = 规格理解错误，回读 §2/§5。