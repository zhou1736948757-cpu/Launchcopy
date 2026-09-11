# T-1F-B7-wave-c — BUG7 缺陷 3：建夹后顶层 app 单击不启动（folder 内成员正常）

- Status: completed
- AccessDeclaration: NO_PRIOR_EXPOSURE
- 范围: 仅本文件（Workflow/results/ 写范围）；禁 git；冻结树/AppLaunchController.swift/Package.swift 未触碰

## 1. 取证结论（先于结构修改落盘；mandate ②）

### 1.1 可执行取证（真实栈 harness，Tests/PagingUITests/DragCommitIntegrationTests.swift 新增取证测试）
- 装置：FakeAppFactory 真实 .app bundle + 真实 PagingSurface/AppCatalogAssembly/DragUISessionCoordinator（复刻 installDragUI 接线）+ RecordingLauncher + AppLaunchController.install()。
- 流程：基线顶层单击 → onCommit seam 建夹 commit（A+B 入夹，C 落顶层 slot 1）→ 连点 6 次。
- 实测（六态判定输入）：
  - 基线（建夹前）顶层单击：`.launched`，opened=1。
  - 建夹 commit 后：servedRevision=1；token `catalogRevision: 1` == servedRevision=1（无 stale）；bundleURL(for:) 命中。
  - 连点 6 次（对齐用户取证）：每次 `.launched`（opened 2→7），state=idle，无一次拒绝。
- 结论：**同 revision 建夹 commit 后，"token→bundleURL→launcher" 数据/启动路径健全；harness 无法复现缺陷** → 缺陷位于 harness 未建模的真实 app 层（见 1.2 静态链路三处静默丢失点），而非启动管线本身。

### 1.2 静态链路核实（全部层已读，逐层）
1. AppGridCellView.mouseDown(:184-187)→coordinator.pointerDown(:103-137)；mouseUp→pointerUp(:176-240)。
2. resolveSource(:372-386)：token→AppID cast + appReference（需 servedSnapshot+record 命中）→ .topLevelApp(ref)；**失败→nil source→pendingBlankPress 武装(:118-121)→pointerUp 走空白分支(:181-188)→onOverlayBlankClick（=closeFolder）——单击被吞、零反馈**（真实 app 六连点全灭的候选死路 A）。
3. DragSessionController.pointerDown(:62-88)：`guard sourcePresent(source, in: layout) else { return events }`（:68 stale source 拒绝）→ 无 .pressed → coordinator 武装 clickFallbackCell(:129-134)；pointerUp fallback 分支(:190-203) **必经 endSession + onCellClick(fallback) 派发**（Wave C 已堵漏）→ handleDragCellClick 仍可达（候选死路 B 已有回退，非丢失）。
4. .pressed→pointerUp .pressed 分支→controller 无条件 reset+`[.clicked]`(:177-180)→dispatchClick(sourceCell)+endSession(:286-288)→onCellClick。
5. AppDelegate.handleDragCellClick(:651-665)：`if let appID = cell.bindingToken?.appID as? AppID { if folderOpenState?.isOpen == true { launchMember(appID) } else { _ = launchController?.handleCell(cell) } }`——**if-let 失败=静默跳过（无反馈）**。
6. launchMember(:763-770)=**合成 cell 路径**：`AppCatalogAssembly.makeMemberLaunchCell(appID:servedRevision:)`（:450-462，当前 servedRevision+appID 直绑）+handleCell——**folder 成员启动正常即走此路径，与缺陷签名吻合**。
7. AppLaunchController.launch(from:)(:129-143 冻结)：①revision ②bundleURL ③fileExists→.launched/.failedToLaunch；record(:146-152)。

### 1.3 六态判定与修法映射
- 实测+链路核实共同指向：启动管线本身在数据健全时无缺陷（1.1）；真实 app 的丢失发生在"live token/仲裁对重建后状态的信任"层（1.2.2/1.2.5），lastOutcome 不更新=启动从未尝试（nil 族形态）。
- 修法（mandate ③）：**顶层与成员共用合成 cell+当前 servedRevision 路径**——handleDragCellClick 的 app-cell 分支统一走 launchMember(appID)（身份从 cell.bindingToken?.appID as? AppID 读），删除 live-token `launchController?.handleCell(cell)` 信任路径；AppLaunchController.swift 冻结不动。

## 2. 改动清单（已实施）
- [x] Sources/PagingPrototypeApp/AppDelegate.swift:649-666 handleDragCellClick：app-cell 分支统一走 launchMember(appID)（身份从 cell.bindingToken?.appID as? AppID 读），删除 live-token `_ = launchController?.handleCell(cell)` 信任路径；folderOpenState 分支折叠（两分支本已同归合成 cell 路径）；doc 注明"绝不信任提交重渲染后的 live token"。
- [x] Sources/PagingPrototypeApp/AppDelegate.swift launchMember（:774 区域）doc：注明"成员/顶层 app 启动共用路径（合成 cell + 当前 servedRevision，makeMemberLaunchCell → AppLaunchController.handleCell）"。
- [x] Sources/PagingPrototypeApp/AppDelegate.swift QuitOnBlankClickWindow.sendEvent（:1026-1043）+ 属性 doc（:1020-1024）：onDragActiveCancel 评估从"任何 leftMouseDown"移入空白命中分支（!blankClickResolvesToCell(hit) 内）——cell 命中（含活动会话内第二次 pointerDown）放行 super，secondDrag 归 coordinator 仲裁；空白命中防御保留。
- [x] Sources/AppGridUI/DragUI/DragUISessionCoordinator.swift pointerDown：删 5 处 DBG 打印（原 :105 dragGate false / :106 no host / :110 point+source / :120 blank press armed / :123 no layout）；guard 语义不变。
- [x] Tests/PagingUITests/DragCommitIntegrationTests.swift：①CommitFixture.handleCellClick 双镜像修复后逻辑（合成 cell 路径）；②新增回归 testFolderCreateCommitThenTopLevelClickLaunches（9 步验收链：基线单击→建夹 commit→顶层单击→连点 6 次→开夹→合成成员启动→关夹→顶层单击，launcher/lastOutcome 硬断言）。
- [x] Tests/PagingUITests/BlankClickToQuitTests.swift：新增 testCellMouseDownDuringActiveDragSessionNotSwallowed（收窄契约：cell 命中 cancelCalls==0）+ testBlankMouseDownDuringActiveDragSessionCancelsAndSwallows（防御保留：cancelCalls==1 且不退出）。

## 3. 验收映射
- 建夹 commit 后顶层单击 → 启动管线被调用（fake launcher 断言）→ testFolderCreateCommitThenTopLevelClickLaunches：opened 1→2、lastOutcome==.launched。
- folder 成员不回归 → 同测试合成 cell 成员路径断言 .launched + testCreateFolderCommitShowsFolderCellAndPersists + FolderIntegrationTests（全量绿）。
- 空白退出不回归 → BlankClickToQuitTests 既有 13 测全绿 + 新 testBlankMouseDownDuringActiveDragSessionCancelsAndSwallows（防御保留）。
- 交替拖拽/点击不回归 → testDragReorderCommitReRendersAndPersists（drag→commit→click 启动，双改后 opened==1）+ 新测试（click×6→开夹→关夹→click 时序）。
- DBG 清理 → grep DBG DragUISessionCoordinator.swift = 0 命中。

## 4. 测试证据
- swift build -c debug：Build complete!（4.64s），exit 0。
- swift test（全量）：SWIFT_TEST_EXIT=0；Test Suite 'All tests' passed；Executed 1036 tests, with 0 failures (0 unexpected) in 16.234s（= 基线 1033 + 新增 3；任务包 §6 "1026" 系笔误，实测基线 1033）。本轮含既有 flaky RunLoopFrameDriverTests 亦绿，未触发隔离复跑条件。executed_tests=1036>0（非 INVALID）。
- swift build -c release：Build complete!（15.71s），exit 0。

## 5. Deviation
1. 测试落点：新测试置于 Tests/PagingUITests/（DragCommitIntegrationTests.swift、BlankClickToQuitTests.swift），非任务包所写 Tests/AppGridUITests/——Package.swift（冻结）中 PagingPrototypeApp 为 executableTarget 且仅 Tests/PagingUITests 依赖之（:60-63；Tests/AppGridUITests :78-81 无该依赖），AppDelegate 级启动端到端断言（AppLaunchController/fake launcher/合成 cell）只能在 PagingUITests 编译；先例 FolderIntegrationTests/DragCommitIntegrationTests/AppLaunchControllerTests/BlankClickToQuitTests 均在此。AppGridUI 层唯一改动为 DBG 打印删除（零行为变化），无需新增 coordinator 级测试；既有 Tests/AppGridUITests 全量绿。
2. 未抽 launchApp：mandate 给出"顶层改走 launchMember(appID)/抽 launchApp 共用"两案，取前者（调用点仅 :480/:504/:660 三处不动，最小 churn），launchMember doc 已注明共用语义。
3. 取证时序合规：取证测试先以 print 观测版落盘执行（六态判定输入），结论先行落盘 §1，后转换为硬断言回归测试（mandate ②"取证先于结构修改"满足）。
4. 全量测试日志中 DBG4/DBG7/PROBE 打印系其他既有测试文件（LayoutStore 持久化探针等）自带，非本波范围，未触碰。
