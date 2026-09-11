# T-1F-D2 — Accessibility reorder actions（无障碍重排动作）

Status: in progress
Created: 2026-08-31 (Main)
Depends on: T-1F-D1 (drag UI core — coordinator seams), T-1F-A, T-1F-C — all merged.
Split decision (Main, recorded): T-1F-D split into D1 (drag UI core) + D2 (accessibility reorder actions) — serial waves; D2 builds on D1's coordinator/commit seams; write sets overlap on AppDelegate.swift → serial.

## 1. 目标

为键盘/VoiceOver 提供与指针拖拽**同一 mutation 引擎**的重排等价动作（Prompt §3.10、§10.7 矩阵）：Move Before/After、Move to Previous/Next Page、Move Into Folder、Move Out of Folder、folder 内 Move Before/After、取消重排模式。动作结果与指针拖拽完全一致（同一 DragMutationEngine，不得第二套算法）；非法动作不可用或安全拒绝；焦点跟随移动项；screen-reader label 无路径/ID；无需 Accessibility 权限。

## 2. 写范围（仅这些文件）

- 新建 `Sources/AppGridUI/DragUI/DragAccessibilityActions.swift` — 重排动作定义 + 执行器（复用 DragMutationEngine + DropIntent 构造；经 D1 的 commit seam 提交）
- 修改 `Sources/PagingPrototypeApp/AppDelegate.swift` — 装配动作入口（菜单/键盘等价物；与既有 Command-F/ESC/Return 路由协调）
- 新建 `Tests/AppGridUITests/DragAccessibilityActionsTests.swift` — 纯逻辑测试
- 新建 `Tests/PagingUITests/DragAccessibilityIntegrationTests.swift` — seam 驱动集成测试

**禁止写**：Sources/AppGridUI/DragSession/、Sources/AppGridUI/LayoutDomain/、Sources/AppGridUI/DragUI/DragUISessionCoordinator.swift、Sources/AppGridUI/DragUI/DragUIVisuals.swift（D1 产物，只读）、Sources/AppGridUI/FolderDomain.swift、Sources/AppGridUI/FolderKeyboardLogic.swift、Sources/AppGridUI/AppGridFocusNavigator.swift、Sources/AppGridUI/AppGridFocusLayout.swift、Sources/AppGridUI/AppGridFocusIdentity.swift、Sources/AppGridUI/AppGridCellFocus.swift、Sources/AppGridUI/FolderOpenState.swift、Sources/AppGridUI/AppGridUIPageContentProvider.swift、Sources/AppGridUI/AppGridSearchPresentationController.swift、Sources/AppGridUI/AppGridUIState.swift、Sources/AppGridUI/AppGridCellView.swift、Sources/AppGridUI/AppGridPageView.swift、Sources/AppGridUI/FolderOverlayView.swift、既有测试、全部冻结树、Docs/、PROVENANCE/。

## 3. 必读（严格限制，勿读其他）

1. 本包
2. `Sources/AppGridUI/DragUI/DragUISessionCoordinator.swift`（D1 产物 — commit seam 与 cancel 入口签名）
3. `Sources/AppGridUI/DragSession/DragMutationEngine.swift` + `DropIntent.swift`（引擎与意图构造）
4. `Sources/AppGridUI/LayoutDomain/PersistentWorkspaceLayout.swift`（布局 API：move/insert/intoFolder/moveOut/rename 等 mutation 方法）
5. `Sources/PagingPrototypeApp/AppDelegate.swift` 的键盘路由段（Command-F/ESC/Return 处理，约 :465-540）与 D1 装配段
6. `Tests/AppGridUITests/DragDropTests.swift`（引擎测试模式参考）

**勿读**：ADR-009/010、PHASE1F_DRAG_PERSISTENCE_PROMPT.md 全文、LayoutStore/、禁止来源。

## 4. 实现要求

### 4.1 动作集（与指针同一引擎）
- Move Before/After（顶层与 folder 内）：构造 .reorder/.insertion 意图 → DragMutationEngine.apply → commit seam。
- Move to Previous/Next Page：目标页首/末有效槽位 → 同引擎 mutation（跨页移动 = 同一布局 mutation，非分页状态改动）。
- Move Into Folder：.intoFolder(FolderID) 意图。
- Move Out of Folder：.moveOut(Int) 意图（folder 内成员移出到顶层）。
- 取消重排模式：无残留（复用 D1 统一 cancel 语义）。
- 非法动作（如 folder 内 Move Into 自身、顶层 Move Out、目标不存在）→ 安全拒绝，布局不变，无崩溃。

### 4.2 焦点与可达性
- 焦点跟随移动项（移动后焦点落在被移动项的新位置；跨页移动后焦点落在目标页对应槽位）。
- 动作有 announcement/label（中性：'Moved before/after'、'Moved to page N'、'Moved into folder'、'Moved out of folder'；不含路径/ID/名称）。
- 无需 Accessibility 权限；不引入私有 API。

### 4.3 与既有输入协调
- 与 Command-F/ESC/Return/方向键路由不冲突；重排动作进行中禁拖（或先 cancel 再执行）；搜索 active 时动作安全拒绝或先退出搜索。

## 5. 测试要求

- `Tests/AppGridUITests/DragAccessibilityActionsTests.swift`：每个动作的意图构造正确性（与指针路径同一引擎产物一致）、非法动作拒绝、布局不变性、焦点目标计算。
- `Tests/PagingUITests/DragAccessibilityIntegrationTests.swift`（seam 驱动）：Move Before/After 顶层与 folder 内；Previous/Next Page 跨页；Move Into/Out of Folder；取消无残留；焦点跟随；与指针拖拽结果一致性（同一布局 mutation 断言）；announcement 中性。
- 隐私：仅中性 fixture 数据。
- 验证（串行，项目根）：`swift build -c debug` exit 0；`swift test` 全量（基线 = D1 合并后计数，新增全绿，既有不回归；写范围外失败如实报告不修改）；`swift build -c release` exit 0。用 ${PIPESTATUS[0]} 取退出码。

## 6. 红线

- 无 git；不读禁止来源；隐私中性；不改冻结树；不写 Docs/PROVENANCE；不新增第三方依赖；Apple 框架公开 API + 最低系统版本记录。

## 7. 输出纪律

- 先写 `Workflow/results/T-1F-D2-accessibility-reorder-actions.md`（"Status: in progress"）再实现；完成后 Status: PASS + 文件清单 + 测试数 + 验证证据。
- 回复 <250 词，无大代码块。
