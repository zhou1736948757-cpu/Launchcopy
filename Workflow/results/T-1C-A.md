# T-1C-A — 键盘焦点 domain / 导航策略（纯逻辑）

**Worker**: worker-a（T-1C-A）
**任务**: 实现纯逻辑键盘焦点 domain 与导航策略（revision-stable 焦点身份、初始焦点、方向键导航、边界/末页策略、snapshot revision 迁移）+ 起草 ADR-006
**日期**: 2026-08-29
**接口契约**: PHASE1C_KEYBOARD_INTERACTION_PROMPT §3.1–3.3、§6 Worker A；ADR-004（remap 五级降级）；ItemBindingToken（七字段 binding token）
**AccessDeclaration: NO_PRIOR_EXPOSURE**（亲笔声明：未读取 `/Users/mac/Projects/BuhoReverseNotes/`、`/Users/mac/Projects/LaunchBetter/`、`2026-08-25-buho-launchpad-reverse` 任何内容；仅依据本 Prompt、Apple 公开文档与本工程自身文件）

---

## 一、实现（新增 4 个源文件 + 2 个测试文件 + 1 个 ADR 草稿）

| 文件 | 内容 |
|---|---|
| `Sources/AppGridUI/AppGridFocusIdentity.swift` | `AppGridFocusIdentity`（revision-stable）：`catalogRevision: UInt64` / `pageIndex` / `slotIndex` / `appID: AppID?` / `presentationID: PagePresentationID`；`Hashable, Equatable, Sendable`；便捷 init 保证 `presentationID.revision == catalogRevision` |
| `Sources/AppGridUI/AppGridFocusLayout.swift` | `AppGridFocusLayout`（纯输入）：由 `CatalogSnapshot` 构建；`pageCount` / `itemsPerPage` / 每页有效身份（`validSlots(on:)` / `validAppID(page:slot:)` / `validIdentities(on:)`）；`firstValidIdentity()` / `contains(_:)` / `position(of:)`；`rowCount(page:columns:)` 从有效 item 数推导（不硬编码 5×7）；`migrate(identity:)` 镜像 `CatalogPlanner.remap` 五级降级 |
| `Sources/AppGridUI/AppGridFocusModel.swift` | `AppGridFocusModel`：当前焦点身份（或 `.none` 空态）；确定性初始焦点；`apply(layout:)` 迁移（successor → predecessor → clamped → empty；旧 revision 永不夺回）；`AppGridFocusMigration` 枚举（located/successor/predecessor/clamped/empty/unchanged） |
| `Sources/AppGridUI/AppGridFocusNavigator.swift` | `AppGridFocusNavigator`（columns 为布局参数，不硬编码 5×7）：←/→ 行内移动 + 跨页；↑/↓ 同列上下行 + 确定性 clamp；全局边界不环绕；stale/无效守卫 |
| `Tests/AppGridUITests/AppGridFocusTests.swift` | 12 测试：空 catalog 无焦点 / 确定性初始焦点 / pageCount 0/1/多页 / revision 更新保留同一 AppID / 消失→successor/predecessor/clamped/empty / 旧 index 不复用 / 旧 revision 永不夺回 / placeholder 空 slot 不可启动 / 身份 revision-stable |
| `Tests/AppGridUITests/AppGridFocusNavigatorTests.swift` | 13 测试：5 列与非 5 列左/右/上/下 / 末页不完整不越界 / 跨页右/左 / 跨页 clamp / 全局边界不环绕 / 重复与快速序列可预测 / stale 不导航 / Reduce Motion 无关 |
| `Docs/ADR-006-KEYBOARD-FOCUS.md` | 草稿：状态模型、导航边界、未支持按键策略；事件分发/启动由 Main 整合 B/C 段 |

**未触碰**：`Sources/PagingCore/`（冻结）、`Sources/PagingUI/`、`Sources/PagingPrototypeApp/`、`Sources/AppGridUI/AppGridCellView.swift`、`AppGridPageView.swift`、`AppGridUIPageContentProvider.swift`、`AppGridRefreshController.swift`、`ItemBindingToken.swift`、`Package.swift`、`Docs/`（除 ADR-006 草稿）、`PROVENANCE/`、他人 test 目录。

---

## 二、验收标准逐项结果

| 验收标准 | 结果 | 测试 |
|---|---|---|
| 空 catalog 无焦点 | ✅ | `testEmptyCatalogNoFocus` |
| 首次聚焦策略确定性 | ✅ | `testDeterministicInitialFocus` |
| 左/右/上/下在 5 列及非 5 列配置下正确 | ✅ | `testRightLeftIn5Columns` / `testUpDownIn5Columns` / `testRightLeftInNon5Columns` / `testUpDownInNon5Columns` |
| 最后一页不完整网格不越界 | ✅ | `testIncompleteLastPageNoOutOfBounds` |
| placeholder/空 slot 不可启动 | ✅ | `testPlaceholderEmptySlotNotLaunchable` |
| 边缘跨页策略正确 | ✅ | `testCrossPageRight` / `testCrossPageLeft` / `testCrossPageClampWhenNextPageShorter` / `testNoWrapAtGlobalBoundary` |
| pageCount=0/1/多页 | ✅ | `testPageCountZeroOneMulti` |
| catalog revision 更新后保留同一 AppID | ✅ | `testRevisionUpdatePreservesSameAppID` |
| 焦点 App 消失后的 successor/predecessor/clamped/empty 迁移 | ✅ | `testFocusAppDisappearsSuccessorMigration` / `...PredecessorMigration` / `...ClampedMigration` / `...EmptyMigration` |
| 旧 index 不会在新 snapshot 中错误复用 | ✅ | `testOldIndexNotReusedInNewSnapshot` |
| 重复方向键、快速方向键序列可预测 | ✅ | `testRepeatedArrowKeysPredictable` / `testRapidSequencePredictable` |
| Reduce Motion 下键盘切页状态仍正确 | ✅ | `testReduceMotionIndependentNavigationState`（导航决策无 RM 参数依赖；跨页状态正确） |

---

## 三、验证证据

1. **`swift build`** → **exit 0**（AppGridUI target 编译通过，零警告）。
2. **`swift test --filter AppGridFocus`** → **25/25 全绿**（13 navigator + 12 focus），exit 0。
3. **`swift test`（全量）** → **487/487 全绿，0 failures**，exit 0（无回归）。
4. 冲突标记 / trailing whitespace 扫描：无。
5. 隐私：焦点身份/布局不记录 app 名 / bundle ID 原文 / 路径 / URL / 图标数据（`AppID` 不透明）。

---

## 四、偏离与说明

- **迁移聚焦语义**：`.located` 定位到 anchor 精确新位置；`.successor`/`.predecessor`/`.clamped` 委托 `CatalogPlanner.remap` 得目标页，聚焦该页**首个有效 cell**（ADR-006 已文档化）。因 `AppID` 不透明且 `anchorOrderLessThan` 为 AppCatalogCore 私有，无法在 AppGridUI 层直接定位"具体 successor/predecessor app"；委托 remap 精确镜像其五级降级语义，确定性由 remap 保证。
- **clamped 可达性**：`CatalogPlanner.remap` 的 `.clamped` 仅在 anchor == nil 时返回（非空快照 + 全序下消失 app 恒有 successor 或 predecessor）。故 clamped 迁移测试走"当前焦点无有效 appID（nil anchor）"防御路径，已文档化。
- **未支持按键**（Escape/Tab/Space/Home/End/PageUp/PageDown/Return/Enter）的 AppKit 语义与事件分发由 Main 整合 Worker B/C 段；本 ADR 只定义方向键纯逻辑导航，不吞掉未支持按键。

---

## 五、Reviewer Focus

- 焦点身份是否 revision-stable（含 catalogRevision + appID + presentation identity）✅
- 迁移是否确定性且镜像 `CatalogPlanner.remap` 语义 ✅
- 是否硬编码 5×7（应推导）✅（columns 为布局参数，rowCount 从有效 item 数推导）
- 是否纯逻辑（无 AppKit 依赖）✅
- 是否引入旧项目字段名/映射痕迹 ✅（中性命名）
- 隐私：焦点身份/布局不记录 app 名/bundle ID/路径/URL/图标数据 ✅

## 六、Memory 候选

- 焦点迁移委托 `CatalogPlanner.remap` 五级降级（located → successor → predecessor → clamped → empty），聚焦目标页首个有效 cell；`.located` 定位精确位置。
- 行列从 itemsPerPage + 有效 item 数推导，不硬编码 5×7；`AppGridFocusNavigator(columns:)` 为布局参数。
- 旧 revision 永不夺回焦点：`migrate` 守卫 `identity.catalogRevision >= revision → .unchanged`。
