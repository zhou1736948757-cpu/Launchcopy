# T-1F-B9-wave-a — BUG9 主页面点击失效：cell hitTest 漏斗 + cell 层 census

Status: **done**（待独立 Reviewer 门禁）
Worker: chef-worker-reviewer-workflow Worker（fresh context）
测试文件选择（§3 二选一）：**新文件** `Tests/AppGridUITests/Bug9CellHitRoutingTests.swift`

## AccessDeclaration

**NO_PRIOR_EXPOSURE**（未读 LaunchBetter/BuhoReverseNotes/2026-08-25-buho-launchpad-reverse 及任何 Ghidra/otool dump）。

## §1 改动清单（实测 diff 摘要）

`Sources/AppGridUI/AppGridCellView.swift`（唯一实现文件，4 处）：
1. 头注释追加 BUG9 wave-a 行（保留既有 AccessDeclaration 行）。
2. `public override func hitTest(_ point: NSPoint) -> NSView?`：`frame.contains(point) ? self : nil`（漏斗：icon/标签/格内空白统一路由 cell 自身 mouseDown；照抄 FolderOverlayView.swift:297-303 模式去按钮例外——cell 无交互子控件）。
3. `mouseDown`：入口第一行 `ClickCensus.hit(Sink.cellMouseDownFired)`（s10）；`(dragCoordinator ?? shared)` 重构为 guard-let，nil 时 `ClickCensus.hit(Sink.cellLookupNil)`（s11）后 return（与原 optional-chaining 语义等价；不调 super 维持）。mouseDragged/mouseUp 主体逐字未动。
4. 文件尾 `extension ClickCensus.Sink`：`cellMouseDownFired = "s10_cell_mousedown_fired"`、`cellLookupNil = "s11_cell_lookup_nil"`（仅计数；PAGING_CLICK_CENSUS=1 stderr 门控与内存计数沿用 ClickCensus.hit 既有管道；coordinator 文件零触碰）。

`Tests/AppGridUITests/Bug9CellHitRoutingTests.swift`（新文件，7 测试，@MainActor，夹具中性 fixture.*，注入实例 coordinator）：见 §4。

## §2 实施前红线核实

- cell 子视图清点 = iconView(NSImageView)/nameLabel/memberCountLabel(NSTextField label)/folderSymbolView(NSImageView)，与任务包 §2 完全一致，**无未列出交互子控件** → 未触发停手红线（folderClickRecognizer 为挂 self 的识别器，非子视图；hitTest→cell-frame 内 self 不影响其随 cell 接收事件）。
- 全仓 grep：AppGridCellView 原无 hitTest/acceptsFirstMouse 覆写；KeyboardFocusController.swift:128 hitTest→nil 属冻结树，未触碰。

## §3 关键过程证据（hitTest 包含性检查为必要项——实验定案）

首版 hitTest 无条件 `return self` → 全量 swift test 出现 4 个测试 13 处断言失败（testBlankHitRejectedNoBinding 得 launched≠rejectedNoBinding、testWindowSendEventClassifiesCellAndBlankWithCensus 空白分类翻转为 cell 等）。Neutralize 实验（hitTest 临时改回 `super.hitTest(point)`）：4 个失败测试中 3 个恢复通过、testWindowKeyStateCensusCountsInKeyAndNonKeyFixtures 仍失败（与本波无关，见 §5）→ 定罪无条件返回 self。机理：AppKit 默认 hitTest 下探把「是否命中」决定权交给各子视图自身（point 为父视图坐标系）——漏斗必须自带 `frame.contains(point)` 守卫，否则劫持 frame 外命中、破坏窗口空白分类（s8/s8c 面）与 AppLaunchController handleClick 空白拒绝。修复为 `frame.contains(point) ? self : nil` 后全部通过。

## §4 测试证据（真实执行原文）

- `swift build -c debug` → `Build complete!`，exit 0
- `swift build -c release` → `Build complete!`，exit 0
- `swift test`（修复后终态，exit 0）原文：
  `Test Suite 'All tests' passed at 2026-09-01 23:07:17.157.`
  `Executed 1062 tests, with 0 failures (0 unexpected) in 16.468 (16.551) seconds`
- 新增 7 测试全绿：testHitTestAtIconCenterReturnsCell（①含窗口层 contentView.hitTest 复核）、testHitTestAtNameLabelReturnsCell（②）、testHitTestAtBackgroundReturnsCell（③）、testCellMouseDownRoutesToCoordinatorPointerDownAndCensus（④ snapshot s10≥1 + .pressed）、testLookupNilIncrementsS11WithoutCrash（⑤ shared/注入双 nil → s11+1 不 crash）、testArbitrationChainIntactThroughFunnel（⑥漏斗内直测：pressed→dragging→不派发点击）、testFolderOverlayHitTestNotHijackedByCellFunnel（⑦overlay.hitTest===overlay）。
- 既有套件回归：DragUISessionCoordinatorTests / DragCommitIntegrationTests / AppLaunchControllerTests / FolderOverlayTests / T1FD1FixUITests 等全量含于上述 1062/0。
- 注：executed 计数 1062 > 任务包基线 1052+7=1059，差 3 来自并行 wave-b 在同树新增测试（本波与其零文件交集）；两次全量运行间计数 1061→1062 即为该并行活动的旁证。

## §5 波外既有失败记录（非本波引入，交 Main/Reviewer 裁定）

`DragCommitIntegrationTests.testWindowKeyStateCensusCountsInKeyAndNonKeyFixtures` 在本波 hitTest **neutralize（=基线行为）** 时亦失败（夹具前提「makeKey 后窗口成 key」+ s8e 计数），属 wave-b Stage 1 s8e 装置/窗口 key 状态环境敏感；最终全量运行（含并行负载变化）已自愈为通过。本波未触碰 AppDelegate/该测试。

## §6 验收逐条

| # | 项 | 结果 |
|---|---|---|
| ① | hitTest(icon 中心)===cell | ✅（含窗口路由面） |
| ② | hitTest(nameLabel 点)===cell | ✅ |
| ③ | hitTest(背景点)===cell | ✅ |
| ④ | mouseDown 经 cell → pointerDown 被调（snapshot s10≥1） | ✅ |
| ⑤ | shared/注入均 nil → s11+1 且不 crash | ✅ |
| ⑥ | drag 仲裁测试全绿（pointerDown→beginArbitration 未回归） | ✅（漏斗直测+既有套件） |
| ⑦ | folder overlay 回归绿（路径未触碰+命中不劫持直测） | ✅ |
| — | swift build -c debug / release exit 0 | ✅ / ✅ |
| — | swift test 全量 exit 0 | ✅ 1062/0 |
| — | 实机验收（Main 组织） | 不在本报告范围 |

## §7 Deviation 逐条

1. hitTest 增加 `frame.contains(point)` 守卫（任务包 §5.1「点在 bounds 内一律返回 self」的必要化实现）：实验证明无守卫会劫持 frame 外命中并破坏既有空白分类测试；「bounds 内」为语义主体，frame.contains 即其父坐标系正确落点（见 §3）。
2. s11 布点仅在 mouseDown 的 lookup（mouseDragged/mouseUp 主体零改动优先于「三处 lookup 都布点」的字面读法）；s11 语义按 mouseDown 查找失败落点书写。
3. mouseDown 主体由 optional-chaining 重构为 guard-let（§5.2 要求观测 nil 分支所必需），行为等价（nil → 不调 pointerDown）、不调 super 维持。

## §7 未触碰声明

冻结树六目录、Package.swift、PagingPrototypeApp/AppLaunchController.swift、AppDelegate.swift、DragUISessionCoordinator.swift、FolderOverlayView.swift、DragUIVisuals/DropIntent/DropResolver/engine、Docs/ 均未触碰；无 git 操作；无真实 app 名/bundleID/路径输出（夹具全 fixture.* 合成数据）；若实机修复后仍有点击死（R5 为真）不扩波、不加 acceptsFirstMouse（wave-b Stage 2 预授权项）。