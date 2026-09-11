# T-1F-B7-wave-c — Reviewer Review r1

- Reviewer: 独立 Reviewer（glm-5.3-flash:cloud，只读）
- AccessDeclaration: NO_PRIOR_EXPOSURE
- 日期: 2026-09-01；判定: **PASS**

## 独立核验记录（A–H 全项，不复述 Worker，自行走代码/实跑）

**A. 取证链有效** ✓ — ①results §1.1 取证装置为真实栈（真实 .bundle + 真实 surface/assembly/coordinator + RecordingLauncher），证据含 token catalogRevision==servedRevision=1、bundleURL 命中、6 连点全 `.launched`；②静态链自核：coordinator `resolveSource` 失败→`pendingBlankPress`（:118-121）→pointerUp 空白分支（:176-188）`onOverlayBlankClick`；`sourcePresent` guard 在 DragSessionController（stale→fallback 武装 :129-134，fallback 分支 Wave C 已堵漏必派发）；`.pressed`→`.clicked`→dispatchClick+endSession；handleDragCellClick if-let 失败=静默跳过——三处静默丢失点全部落在 live-token/重建态信任层，推理链成立；③**未跳步**：Worker 对 pointerUp 三分支 + sourcePresent 均已查证（§1.2.2-1.2.5）后才实施修法；nil-族（lastOutcome 不更新=启动从未尝试）与 harness"数据健全即健康"互证。mandate 处置表 nil 行要求"查证后再修"已满足；且 FIX-PLAN §4.3 明示"取证通过后的结构性修法（**即使拒绝类别是 stale**）＝合成 cell 路径"，修法为 mandate 预定结构，非跳步。

**B. 结构性修法** ✓ — ①handleDragCellClick（AppDelegate:652-663）：folder cell 先行 return（:654-659），app-cell 分支统一 `launchMember(appID)`；旧码 folder-open 分支本就调 launchMember，折叠等价、无误走；②launchMember（:759-768）→`makeMemberLaunchCell`（AppCatalogAssembly:450-462，servedRevision+appID 直绑）→`handleCell`→`launch(from:)`（AppLaunchController:129-143 冻结）：②`bundleURL(for:)` 对**当前 catalog** 重解析、③`fileExists` 磁盘门均在合成路径上原样执行——stale/缺失 app 的拒绝语义未被绕过（identity 失效→`rejectedMissingApp`，bundle 消失→`rejectedMissingFile`），PRIVACY/安全红线保持；③AppLaunchController.swift mtime 2026-08-28 21:46（零修改）✓。

**C. 顺手收口** ✓ — ①sendEvent（:1029-1070）：cancel 评估仅入 `!blankClickResolvesToCell(hit)` 分支（:1040-1047），cell 命中落 :1069 `super`（secondDrag 归 coordinator，:121-124 旧会话抑制解除 + `.secondDrag` cancel 路径在册）；空白退出链完整保留（drag 防御→folder open 放行→search 退出→`onBlankClick` 终止）；`onDragActiveCancel` 实现（:239-244）仍仅 `isSessionActive` 时 cancel，防御语义不变。②coordinator grep DBG=0，pointerDown guard 语义（isTornDown/dragGate/host）不变。

**D. 测试完整性** ✓ — `testFolderCreateCommitThenTopLevelClickLaunches`（DragCommitIntegrationTests:431-498）9 步硬断言链：基线启动→建夹 commit→顶层单击（opened 1→2, .launched）→连点 6 次（opened=7）→开夹→合成成员路径（:483-489）→关夹→顶层单击；fake launcher（RecordingLauncher）+ 双镜像 `handleCellClick`（:152-163 与生产逻辑同构）。验收四项映射齐全；2 个空白收口测试（BlankClickToQuitTests:129-148）断言 cancelCalls==0/1 + 不退出。

**E. 写范围** ✓（mtime 取证）— 变更恰为 4 文件且全部落 Worker 窗口 19:31:05–19:33:13：AppDelegate.swift、DragUISessionCoordinator.swift、DragCommitIntegrationTests.swift、BlankClickToQuitTests.swift。冻结树六目录（-newermt 过滤空集）、Package.swift（08-28）、AppLaunchController.swift（08-28）零触碰；Wave B′ 文件（DropIntent/DragGeometry 18:58-59、LayoutMutation 18:49、Bug7PageAwareDropTests 19:02）全部早于本任务 19:16:51；Docs/（最新 19:01:37 系 B′ ADR）、PROVENANCE/（最新 08-31）窗口内零触碰。

**F. Deviation** ✓ — Package.swift:60-63 PagingUITests 依赖 PagingPrototypeApp（:26-28 executableTarget）；AppGridUITests（:78-81）无该依赖 → AppDelegate 级端到端（AppLaunchController/fake launcher/handleDragCellClick 镜像）确实只能落 PagingUITests，且先例（FolderIntegrationTests/DragCommitIntegrationTests/AppLaunchControllerTests/BlankClickToQuitTests）一致。未抽 launchApp：mandate 提供两案，取 launchMember 直调为 mandate 首案，可接受。

**G. 独立实跑** ✓ — `swift build -c debug` exit 0；`swift test` 全量 exit 0，**Executed 1036 tests, 0 failures**（Test Suite 'All tests' passed, 19:38:40；1036>0，非 INVALID）；RunLoopFrameDriverTests 本轮绿；`swift build -c release` exit 0。

**H. 红线与隐私** ✓ — grep buho/launchbetter 零命中；夹具中性（alpha/beta/gamma/echo/foxtrot、fixture.* ID、Group 1）；取证仅中性 outcome 计数（opened/lastOutcome），无真实身份/bundleID/路径。

## Findings

- **MINOR-1**（A①）：缺陷 3 在真实栈 harness 不可复现，nil-族动态取证不可得；取证=动态 harness（排除数据层）+ 静态全链核实（定位信任层）。修法有效性以回归测试背书而非 red→green 演示——系不可复现实机上 mandate 预定修法的固有形态，Worker 已如实记录，不构成违规。
- **MINOR-2**：任务包 §6 基线"1026"与实测基线 1033 不符（Worker 已在 results §4 记为笔误）；总执行 1036=1033+3 自洽。
- **QUESTION-1**：死路 A（`resolveSource` nil→空白分支→`onOverlayBlankClick`，顶层无 folder 时 no-op，与"无反应"签名相容）不在本波修法覆盖内。若用户实机复测仍复现，应与 sessionLayout generation 观察项同族记档，而非默认本波修法失效。
- **QUESTION-2**：取证时序（print 观测版先跑、结论先落盘再改结构）无法从仓库独立复核（结果文件单次落盘）；采信 Worker 声明，佐证为 results §1 先于 §2 的结构且内容为观测形态。

## 结论

A–H 全项独立核验完成，证据在册；判定 **PASS**。建议：QUESTION-1 记入遗留观察项；无修复轮需求。