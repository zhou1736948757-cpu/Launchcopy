# Task Packet: T-1C-A

- **Task ID**: T-1C-A
- **Role**: Worker A (fresh context — 不继承含逆向材料的旧会话上下文)
- **Phase**: 1C — 键盘焦点 domain / 导航策略（纯逻辑）
- **Prompt**: `Docs/PHASE1C_KEYBOARD_INTERACTION_PROMPT.md` §6 Worker A

## Objective

实现键盘焦点的**纯逻辑 domain 与导航策略**：revision-stable 焦点身份、初始焦点策略、方向键网格导航、边界/末页策略、snapshot revision 迁移（successor/predecessor/clamped/empty）。全部为纯逻辑，不依赖 AppKit，可单测。起草 `Docs/ADR-006-KEYBOARD-FOCUS.md`。

## Dependencies

- **无**（纯逻辑；只读现有类型 `ItemBindingToken`、`PagingPageContent`、`AppGridUIPageContentProvider`、`CatalogSnapshot`/`CatalogPlanner`）。

## Context

**Fresh Context 要求（来源纪律）**：此 Worker 使用不继承旧逆向上下文的 fresh context。只接收：本 Prompt、Apple 官方公开文档、新工程自身文件。**不得读取**：`/Users/mac/Projects/BuhoReverseNotes/`（全部）、`/Users/mac/Projects/LaunchBetter/`（全部）、`2026-08-25-buho-launchpad-reverse`。误触 → 立即 `PROVENANCE/CONTAMINATION_LOG.md` + `BLOCKED_FOR_REVIEW`。

**关键既有类型（只读）**：
- `ItemBindingToken`（7 字段：catalogRevision / pageIdentity / itemSlot / appID / reuseGeneration / iconKey / surfaceGeneration）——焦点身份应与之对齐。
- `PagePresentationID`（revision + pageIndex）。
- `AppGridUIPageContentProvider`（`servedSnapshot`、`servedRevision`、`pageIndex(of:appID:)`、`anchorCandidate(nearPage:)`）。
- `CatalogPlanner.remap` 五级降级（located → successor → predecessor → clamped → emptyCatalog）——焦点迁移应镜像此语义。
- 网格：`AppGridPageView.columns = 5`、`itemsPerPage` 默认 35。**不得把 5×7 当不可变事实**——从布局/itemsPerPage/有效 item 数推导行列。

## Scope

- 定义 `AppGridFocusIdentity`（revision-stable）：`catalogRevision: UInt64`、`pageIndex: Int`、`slotIndex: Int`、`appID: AppID?`、`presentationID: PagePresentationID`。
- 定义 `AppGridFocusLayout`（纯输入）：`pageCount`、`itemsPerPage`、每页有效身份（仅可启动 app；placeholder/空 slot 排除）。提供从 `CatalogSnapshot` 构建的 builder。
- 定义 `AppGridFocusModel`：当前焦点身份（或 `.none` 空态）、初始焦点策略、迁移规则（successor → predecessor → clamped → empty）、旧 revision 永不夺回焦点。
- 定义 `AppGridFocusNavigator`：纯方向键移动（←/→/↑/↓），行列从 itemsPerPage + 有效 item 数推导，边界/跨页决策，末页不完整网格确定性 clamp。
- 起草 `Docs/ADR-006-KEYBOARD-FOCUS.md`（状态模型、导航边界、未支持按键策略；事件分发/启动细节由 Main 整合 B/C 段）。

## Out of Scope

- AppKit responder / first responder / keyDown（T-1C-B）。
- 键盘启动集成（T-1C-C）。
- 修改 `Sources/PagingCore/`、`Package.swift`、`Docs/`（除 ADR-006 草稿）、`PROVENANCE/`。
- 搜索、文件夹、拖拽、Hot Corner、120Hz、vsync、帧卡顿修复。

## Expected / Allowed Write Scope

- `Sources/AppGridUI/AppGridFocusIdentity.swift`（新）
- `Sources/AppGridUI/AppGridFocusLayout.swift`（新）
- `Sources/AppGridUI/AppGridFocusModel.swift`（新）
- `Sources/AppGridUI/AppGridFocusNavigator.swift`（新）
- `Tests/AppGridUITests/AppGridFocusTests.swift`（新）
- `Tests/AppGridUITests/AppGridFocusNavigatorTests.swift`（新）
- `Docs/ADR-006-KEYBOARD-FOCUS.md`（新，草稿）

## Forbidden Write Scope

- `Sources/PagingCore/`（冻结）
- `Sources/PagingUI/`、`Sources/PagingPrototypeApp/`
- `Sources/AppGridUI/AppGridCellView.swift`、`AppGridPageView.swift`、`AppGridUIPageContentProvider.swift`、`AppGridRefreshController.swift`、`ItemBindingToken.swift`（只读）
- `Tests/PagingUITests/`、`Tests/PagingCoreTests/` 等他人 test 目录
- `Package.swift`、`Docs/`（除 ADR-006 草稿）、`PROVENANCE/`

## Constraints

- 纯逻辑，不依赖 AppKit/Core Animation/窗口/真实事件。
- 焦点身份 revision-stable；迁移确定性（successor → predecessor → clamped → empty）；旧 revision 永不夺回焦点。
- 行列从布局/itemsPerPage/有效 item 数推导，不硬编码 5×7。
- placeholder/空 slot/loading 页不可作为可启动 app。
- 命名中性，不使用 Buho/LaunchBetter 身份或反编译含义。
- 不回滚他人改动；不修改 Package.swift。

## Acceptance Criteria

- [ ] 空 catalog 无焦点
- [ ] 首次聚焦策略确定性
- [ ] 左/右/上/下在 5 列及非 5 列配置下正确
- [ ] 最后一页不完整网格不越界
- [ ] placeholder/空 slot 不可启动
- [ ] 边缘跨页策略正确
- [ ] pageCount=0/1/多页
- [ ] catalog revision 更新后保留同一 AppID
- [ ] 焦点 App 消失后的 successor/predecessor/clamped/empty 迁移
- [ ] 旧 index 不会在新 snapshot 中错误复用
- [ ] 重复方向键、快速方向键序列可预测
- [ ] Reduce Motion 下键盘切页状态仍正确（导航决策不依赖 RM 参数，但状态正确）

## Required Verification

- `swift build` 成功（AppGridUI target 编译通过）
- `swift test` 全部 AppGridUITests 焦点测试通过
- `exit_code == 0` 且 `executed_tests > 0`（非 INVALID_TEST_EXECUTION）
- 测试输出记录到 Worker Result

## Reviewer Focus

- 焦点身份是否 revision-stable（含 catalogRevision + appID + presentation identity）
- 迁移是否确定性且镜像 `CatalogPlanner.remap` 语义
- 是否硬编码 5×7（应推导）
- 是否纯逻辑（无 AppKit 依赖）
- 是否引入旧项目字段名/映射痕迹
- 隐私：焦点身份/布局不记录 app 名/bundle ID/路径/URL/图标数据

## Deliverables

- `Sources/AppGridUI/AppGridFocus*.swift`（新）
- `Tests/AppGridUITests/*Focus*.swift`（新）
- `Docs/ADR-006-KEYBOARD-FOCUS.md`（草稿）
- `Workflow/results/T-1C-A.md`（Worker Result）
