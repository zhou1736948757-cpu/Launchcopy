# T-1F-B10-wave-a-forensics — BUG10 缺陷 A 取证布点

状态：已完成（布点落地 + 单测全绿 + 全量回归待最终汇总）
任务包：Workflow/tasks/T-1F-B10-wave-a-forensics.md
判别依据：Workflow/BUG10-FIX-PROMPT.md §4 + Workflow/decisions/D-2026-09-02-bug10-fix-plan.md D3

## 1. 布点清单（现行行号，2026-09-02 wave-b 合并后基线）

| # | 布点 | 位置 | Sink 名 | 语义 |
|---|------|------|---------|------|
| 1 | hitTest 入口计数 + superview==nil 布尔位 | `Sources/AppGridUI/FolderOverlayView.swift:305`（hitTest 函数体首行，`super.hitTest` 之前） | `s14_overlay_hittest_sv1` / `s14_overlay_hittest_sv0`（decl :470-474） | 每次 overlay 参与 hitTest；`_sv1` = 视图已从树中移除仍被命中（残留命中/被重挂/孤儿）直接证据 |
| 2 | mouseDown 面板内非成员区静默 return 计数 | `Sources/AppGridUI/FolderOverlayView.swift:284`（panel 分支成员 for 循环后、`return` 前） | `s15_overlay_mousedown_silent_return`（decl :479） | 事件进了 overlay 且被吞（标题/页脚/面板边距） |
| 3 | closeFolder 执行后 overlay.superview 状态位 | `Sources/PagingPrototypeApp/AppDelegate.swift:798-800`（`closeFolder()` 函数尾，`refreshFolderOverlay()` 之后） | `s16_closefolder_overlay_state_sv1` / `_sv0`（decl :1212-1216） | `_sv1` = 移除执行到位；`_sv0` = overlay 仍挂树（候选：被重挂/移除竞争） |
| 4 | blankClickResolvesToCell 返回 true 时命中链是否含 FolderOverlayView | `Sources/PagingPrototypeApp/AppDelegate.swift:1174`（`is AppGridCellView` 分支内、`return true` 前） | `s17_blankhit_chain_has_overlay_ov1` / `_ov0`（decl :1222-1226） | `_ov1` = 命中 cell 在 overlay 内（成员 cell；祖先链含打开层）；`_ov0` = cell 在 grid 内 |
| 5 | surface 手势层 s18 | **STOP——未落地（见 §4）** | — | — |

### 布点实现要点（零行为变更）

- 布点 1/3/4 的布尔位随每次命中以独立 sink 名计数（`_sv1`/`_sv0`、`_ov1`/`_ov0`，沿用 s8e/s9 先例），census 纪律：中性名 + 计数 + 布尔位，无坐标/标题/app 名。
- 布点 4 实现细节：成员 cell 是 `overlay.panel` 的子视图，overlay 是命中 cell 的**祖先**——不能只沿命中链下行检查；实现为命中 cell 后沿 `cell.superview` 链向上 walk，遇 `FolderOverlayView` 置位。
- 全部布点仅加 `ClickCensus.hit(...)` 计数调用与文件尾 `extension ClickCensus.Sink` 声明（同 T-1F-B9-wave-b 先例）；`DragUISessionCoordinator.swift`（ClickCensus 核心）零改动；`AppLaunchController.swift`（冻结）零改动。
- sink 声明：`FolderOverlayView.swift:469-480`（s14/s15）、`AppDelegate.swift:1211-1227`（s16/s17）。

## 2. 单测证据（新增 10 测试方法，全部通过）

### AppGridUITests/FolderOverlayForensicsTests.swift（新建，6 测试）

| 测试 | 断言要点 |
|------|---------|
| testHitTestCensusCountsAndSuperviewNilBitFlipsWhenDetached | 挂载状态两击（成员区 + 遮罩 (20,150)）→ `_sv0 == 2`、`_sv1 == 0`、hitTest 结果 === overlay；`removeFromSuperview()` 后 → `_sv1 == 1`、`_sv0` 仍 2、hitTest 仍返回 overlay（superview==nil 时布尔位翻转） |
| testHitTestButtonRegionsStillPassThroughAndCount | 多页夹具（3 成员 + membersPerPage=1 + innerPage=1，两按钮可见）prev/next 按钮区 → hitTest 返回 NSButton（非 overlay）+ `_sv0 == 2`（零行为回归） |
| testMouseDownPanelInnerNonMemberZoneSilentReturns | 标题区 (panel.midX, maxY-20) → `s15 == 1`；coordinator `.idle`；`pendingBlankNoCell == 0`（被吞，未进 blank 链） |
| testMouseDownMemberCellReachesCoordinatorNotSilent | 成员 cell 0 中心（共享 FolderID + layout/catalog 注入）→ `.pressed`、`s15 == 0` |
| testMouseDownMaskZoneDispatchesBlankNotSilent | 遮罩 (20,150) → `s15 == 0`、`pendingBlankNoCell == 1`；mouseUp → `onOverlayBlankClick` 1 次、`blankBranchDispatch == 1` |
| testOverlaySinkNamesCarrySuperviewBits | sink 名字符串断言：`s14_overlay_hittest` / `_sv1` / `_sv0` / `s15_overlay_mousedown_silent_return` |

### PagingUITests/BlankClickToQuitTests.swift（新增 4 测试 + tearDown 基建）

| 测试 | 断言要点 |
|------|---------|
| testCellInsideOverlayMarkedOv1 | AppGridCellView 挂 overlay 内 → `_ov1 == 1`、`_ov0 == 0` |
| testGridCellOutsideOverlayMarkedOv0 | cell 挂 root（grid 健康路径）→ `_ov0 == 1` |
| testIconSubviewInsideOverlayMarkedOv1 | cell.iconView 挂 overlay 内 → `_ov1 == 1`（子视图路径同样走祖先 walk） |
| testS17SinkNamesCarryOverlayBits | `s17_blankhit_chain_has_overlay` / `_ov1` / `_ov0` 字符串断言 |

### PagingUITests/DragCommitIntegrationTests.swift（1 处增强：fixture 生产保真 + 断言）

- fixture `closeFolder()`（:189-201）加生产同构 s16 census 行（与 AppDelegate 逐行一致）。
- `testFolderCreateCommitThenTopLevelClickLaunches`（:532-544 序列，关夹后顶层单击仍启动）在 `fixture.closeFolder()` 后断言：`closeFolderOverlayState(sv1) == 1`、`sv0 == 0`、`XCTAssertNil(fixture.overlay.superview)`（该测试内恰有一次 closeFolder 调用，计数确定）。

测试运行结果：FolderOverlayForensicsTests 6/6、BlankClickToQuitTests 19/19（含原 15 + 新 4）、DragCommitIntegrationTests 13/13 全绿。

## 3. §6 六步读数表（待 Main 实机回填）

> 布点已就绪；实机读数由 Main/下阶段回填。sA 系列为既有观察点（AppDelegate.onLaunchAttempt）。

| 步骤 | 操作 | s14(_sv1/_sv0) | s15 | s16(_sv1/_sv0) | s17(_ov1/_ov0) | s18 | sA | 预期判别 |
|------|------|----------------|-----|----------------|----------------|-----|-----|---------|
| 1 | 基线：未开 folder 顶层单击 | 待填 | 待填 | 待填 | 待填 | — | 待填 | 健康路径：s14_sv0 增、s17_ov0 增 |
| 2 | 打开 folder | 待填 | 待填 | 待填 | 待填 | — | 待填 | overlay 挂载：s14_sv0 增、s17_ov1 增 |
| 3 | 开夹后点成员 | 待填 | 待填 | 待填 | 待填 | — | 待填 | 成员启动路径 |
| 4 | **关夹后再点顶层空白（BUG10 复现步）** | 待填 | 待填 | 待填 | 待填 | — | 待填 | 见 §5 判别 → 若 s16_sv1==1（移除成功）且 s14_sv1 仍增 + s15 增 = 残留命中坐实 |
| 5 | 关夹后再点顶层 app | 待填 | 待填 | 待填 | 待填 | — | 待填 | 若启动成功且 s14_sv1 不增 = 移除生效（缺陷 B 修复有效） |
| 6 | 复现序列 ×5（方差） | 待填 | 待填 | 待填 | 待填 | — | 待填 | 方差判定：稳定增 / 偶发 / 不增 |

## 4. 布点 5 判定：STOP——s18 无法在 AppDelegate 落地，报 Main 走 D4 冻结面升级

任务包条款：「识别器本体在 AppLaunchController.swift（冻结）——不加代码，仅在 AppDelegate 挂接的 action 闭包处计数；若 action 闭包也不在 AppDelegate，则停手报 Main 走 D4 冻结面升级，不硬改。」

实机核实（Sources/PagingPrototypeApp/AppLaunchController.swift:95-106）：
- :95 `NSClickGestureRecognizer(target: self, action: #selector(handleGesture(_:)))`——target = `self`（AppLaunchController 实例），action = `#selector(handleGesture(_:))`（:102-106 `@objc private func handleGesture`）。
- 识别器 target/action **均指向 AppLaunchController 自身，不存在 AppDelegate 挂接的 action 闭包**。
- AppDelegate 侧仅有既有观测点 `onLaunchAttempt` → sA（:377-385）：`.launched → sA_launch_accepted`，其余 outcome → `sA_launch_rejected_<outcome>`。

结论：**布点 5（s18_surface_gesture_fired + handleCell 达成位）不能在 AppDelegate 落地**。按任务包停手条款 → 报 Main 走 D4 冻结面升级（AppLaunchController.swift 为冻结文件，需 Main 决策解冻/授权后补布点）。

## 5. 判别建议（§7 表 + 布点 1-4 联动）

沿用任务包 §7 判别表，补充布点 1-4 联动口径：

- ①`s14_sv1` 增 + `s15` 增 + `s16_sv1` == 1（移除到位）→ **残留命中坐实**：closeFolder 后 overlay 已从树摘除（superview==nil），但 hitTest 仍被调用（_sv1 计数）→ 事件被无宿主 overlay 吞掉 → 假设成立 → 修 overlay 移除/hitTest 生命周期（任务包缺陷 A 修复方向）。
- ②`s14_sv1` 增 + `s15` 不增 + `s16_sv1` == 1 → 残留命中但未走面板内路径（遮罩区/非面板区被吞）→ 仍坐实残留，补看遮罩分支。
- ③`s14_sv0` 增 + `s15` 增（overlay 在树内被吞）→ overlay 未移除路径（s16_sv0）→ 查 refreshFolderOverlay 分支（openEntry 非 nil 重挂）。
- ④`closeFolder` 后 `s17_ov1` 增（顶层单击命中链含 overlay）→ 打开层仍在命中链（与 s14_sv1 联动）。
- ⑤**布点 5 缺失影响**：sA 系列（AppDelegate.onLaunchAttempt）是当前唯一 AppDelegate 侧手势观测；Path A（手势承接启动）判别只能依赖 sA_launch_accepted 计数。若读数显示 s14/s15/s16 均不增而 sA 增 → 疑似 Path A 承接（须等 D4 解锁后 s18 补点确认）。
- §7 原表 ②③④⑤⑥（s8d/s10/s7b/sA 系列）判别逻辑不变，布点 1-4 提供 overlay 侧补充证据。

## 6. 验证记录

- `swift build -c debug`：exit 0
- `swift build -c release`：exit 0
- `swift build --build-tests`：exit 0（70 测试文件编译全过）
- 定向测试：FolderOverlayForensicsTests 6/6 ✅、BlankClickToQuitTests 19/19 ✅、DragCommitIntegrationTests 13/13 ✅
- `swift test` 全量：**1083 tests, 0 failures**（基线 1062 + 本任务新增 10 测试方法 + wave-b 并行新增测试；wave-b 的 Bug10PreviewHostTests 在树共跑，全绿）
- 零行为回归：hitTest 返回值（按钮直通/其余 self）与 mouseDown 分支逻辑（成员→pointerDown / 面板内非成员→静默 return / 遮罩→pointerDown(nil)）经上述夹具断言逐一对齐

## 7. Deviation

1. **布点 5 停手**：s18 无法在 AppDelegate 落地（识别器 target/action 均在冻结的 AppLaunchController.swift:95-106）→ 报 Main 走 D4 冻结面升级（任务包条款允许的停手路径，非 FAIL）。
2. 行号漂移：wave-b 合并后 closeFolder 位于 :784-793（任务包原注 :774-782）；布点 3/4 均按**函数名**定位落地（s16 在 `closeFolder()` 函数尾、s17 在 `blankClickResolvesToCell` 的 cell 分支），不受漂移影响。
3. 测试分布：新增测试分落 3 处（FolderOverlayForensicsTests 新建 + BlankClickToQuitTests/DragCommitIntegrationTests 就地扩展），按既有先例不建新 target。
4. wave-b 并行产物 `Bug10PreviewHostTests.swift` 在树（D5 预期，Main 控合并），本次未触碰。
