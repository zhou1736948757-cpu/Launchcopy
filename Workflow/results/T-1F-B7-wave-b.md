# T-1F-B7-wave-b — BUG7 Wave B′ 结果（顶层落点页内→全局下标映射）

Status: complete
Worker: fresh-context Worker（chef-worker-reviewer-workflow v1.4.1）
AccessDeclaration: NO_PRIOR_EXPOSURE（未读取 LaunchBetter/、BuhoReverseNotes/、2026-08-25-buho-launchpad-reverse 及任何 Ghidra/otool dump）

## 1. 改动清单（均在写范围内）

1. `Sources/AppGridUI/DragSession/DragGeometry.swift`
   - `DragItemFrame` 增加 `pageIndex: Int?` / `itemsPerPage: Int?`（默认 nil，既有构造点 AppGridPageView/FolderOverlayView/测试全部零改动编译）+ `annotated(pageIndex:itemsPerPage:)` 注记副本。
   - `DragGeometry` 增加 `itemsPerPage: Int`（init 默认 0）。
2. `Sources/AppGridUI/DragSession/DropIntent.swift`（intent 产出边界）
   - `DropZoneClassifier` 新增私有 `globalIndex(localIndex:frames:)`：帧带注记时执行已定案公式 `globalIndex = page * itemsPerPage + localIndex`；无注记 → 页内下标即全局。
   - `insertionIntent` 两处 `.insertion` 产出经该换算（消费 `zones.itemFrames` 注记）。
   - `classify` 的 `.topLevelTarget` 分支换算（消费 `zones.topLevelFrames` 注记——注记由 D 层显式携带**顶层 committedPage**，绝不复用 folder scope 的 `geometry.page = innerPage`，页号陷阱结构性规避）。
3. `Sources/PagingPrototypeApp/AppDelegate.swift`（**仅 makeDragGeometry**）
   - `.topLevel`：当前页帧注入 `(committedPage, surface.itemsPerPage)` 注记；`DragGeometry` 传 `itemsPerPage: surface.itemsPerPage`。
   - `.folder`：成员帧**不注记**（folder 内 insertion 不乘外层的结构性回归锁）；顶层帧按 `surface.core.committedPage` 注记；`DragGeometry` 传 `itemsPerPage`。
4. 新建 `Tests/AppGridUITests/Bug7PageAwareDropTests.swift`（7 测试，中性 A/B 夹具：a01…a70 / b1…b3 / Group A，bundleID = "fixture.*"）。

未触碰：全部冻结树、DragSessionController/DropResolver/DragMutationEngine/DragParameters、AppDelegate 其余函数、Docs/、PROVENANCE/、既有测试。无 git 操作。

## 2. 设计决策（含理由）

- **itemsPerPage 兼容策略 = 默认值（非全量更新）**：coordinator click 路径空 geometry（DragUISessionCoordinator.swift:209，文件不在写范围）与既有测试构造点无法全量更新；默认 0 = "未提供"，生产 makeDragGeometry 显式传 `surface.itemsPerPage`。
- **换算输入载体 = DragItemFrame 分页注记**（对规格"换算点=classify/insertionIntent 或其输入带上 page+itemsPerPage"的实现取径）：`DropZones` 唯一构造点在冻结的 `DragSessionController.currentIntent`（:255-259，逐字段转发 itemFrames/topLevelFrames/containerWidth/moveOutArmed/parameters），其不可能转发新增字段；`DragItemFrame` 是分类链路中唯一可携带换算信息的写范围内类型。换算本体（乘法与公式）100% 落在 DropIntent.swift 的 intent 产出边界；resolver/engine 继续吃全局下标，未做任何二次换算；`reorderAdjustedIndex` 只读未动。

## 3. 验收映射（缺陷 2）

| 必补测试 | 测试方法 | 断言要点 | 结果 |
|---|---|---|---|
| ① page1 页内 k → 全局 35+k | `testPage1InsertionConvertsToGlobalIndex` | 页内 local 3 → `.insertion(38)`；commit 后源在全局 37（a38 与 a39 之间） | ✅ |
| ② 末页最右列左半=该全局槽之前 | `testLastPageRightmostLeftHalfInsertsBeforeGlobalSlot` | 最右条目（全局 69）左半 → `.insertion(69)`；源落末页全局 68，a70 仍在 69 | ✅ |
| ②（放下后源项出现在末列） | `testLastPageRightmostDropLandsSourceInRightmostColumn` | 最右条目右半 → `.insertion(70)`；源落全局 69 = 末页最右列 | ✅ |
| ③ 满页插最后之后=全局末尾 | `testFullPageInsertAfterLastClosesAtGlobalTail` | `.insertion(70)`（== count，resolver 闭合接受）；源落全局末尾 69 | ✅ |
| ④ folder 内不乘外层 | `testFolderInnerInsertionNotMultipliedByOuterItemsPerPage` | 顶层帧带 page1 注记 + armed，成员插入仍 `.insertion(2)`（非 37）；成员序 [b2,b1,b3]，顶层序不变 | ✅ |
| ⑤ move-out 页号陷阱锁（补充） | `testMoveOutFromFolderOnTopPage1UsesCommittedPage` | innerPage=0、committedPage=1 → `.topLevelTarget(38)` = 35+3（误用 innerPage 会得 3）；成员移出至全局 38 | ✅ |
| 分类器直测（补充） | `testClassifierAnnotationDrivesGlobalConversion` | 同指针：注记帧 → 37；无注记帧 → 2（换算只此一次） | ✅ |

用户验收句映射：「其他列的 app 能拖到当前页最右列并落位」→ ①（任意列 → 全局槽正确）+ ②/③（最右列/末尾）；「跨到末页最右列同样落位」→ ② 两测 + ③；「蓝条位置与放下后的格子一致」→ 见 §5 蓝条事项（主场景一致，遗留视觉事项上报 Main）。

## 4. 次因评估（edge zone 40pt × 末列右侧 ~16pt 重叠）— 仅评估，未改参数

- 判定链（实测）：`EdgePagingScheduler`（:122-128）`pointer.x > containerWidth - 40` → right zone，驻留 ≥ edgeDwellDurationMs（默认 100ms）翻页；hysteresis 10pt 在已 armed 时把有效带外扩至 `containerWidth - 50`。
- 重叠面：末列条目右侧的落点带（插在最后一个之后的目标区，宽约 16pt）整体落在 40pt edge zone 内；hysteresis 使该重叠在指针回移时再 +10pt。用户瞄准"插到最后一个之后"（本修复后 = 全局页末槽）时若驻留即触发非预期翻页。
- 与本修复的关系：缺陷 2 修复后该区域的落点下标已正确；重叠只影响"瞄准页末槽"的可用性，不影响落点正确性。page 0 既有同样重叠（非本波引入）。
- 处置（按 mandate）：不改 `edgeZoneWidthPT`/`dropZoneMarginsPT`，不单独开波。可选后续方向（供 Main 决策）：条目行带内 drop 意图优先于 edge 武装 / edge zone 起点按末列右缘收缩。未实施。

## 6. 蓝条（D 层视觉）事项 — 超写范围，上报 Main

`DragUIVisuals.updateIntent`（DragUIVisuals.swift:87-93/169-184）消费**同一**转换后 intent（controller `.intentChanged` → coordinator :280-284 直转），但用**页内** frames 渲染蓝条（`insertionRect` 对 index ≥ frames.count clamp 到末条目右侧）。后果：
- 修复前：page≥1 蓝条正确 / 落点错（本缺陷）；修复后：落点正确 / page≥1 蓝条 clamp 到页末右缘。验收主场景（拖到最右列，右半/末尾）蓝条与落位一致；最右列左半为相邻边（差一格）；page≥1 中部列蓝条会固定在页末右缘（回归面）。
- 修复需改 `DragUIVisuals.swift`（视觉侧按帧注记回减 `page*itemsPerPage`）——该文件不在本波写范围（亦不在禁写清单），按"不越权"未改。**提问 Main**：是否授权后续波（如 Wave C′）在视觉层消费注记做 global→local 还原，以恢复 page≥1 全列蓝条精度？

## 7. 测试证据（真实执行）

- `swift build -c debug` → exit 0
- `swift test`（全量）：`Test Suite 'All tests' passed — Executed 1033 tests, with 0 failures (0 unexpected) in 16.066s`（基线 1026 + 新增 7 = 1033，吻合；`Bug7PageAwareDropTests` 7/7 passed；范围外失败：无）
- `swift build -c release` → exit 0
- 注：executed_tests = 1033 > 0，非 INVALID_TEST_EXECUTION。

## 8. Deviation

1. 换算输入载体：规格建议"在 DropZones 输入上显式携带顶层 page/itemsPerPage"→ 实现为分类输入帧（DragItemFrame 注记）携带、DropZones 本体不新增字段。原因见 §2（DropZones 唯一构造点为冻结的 currentIntent，无法转发新字段）；换算公式、换算边界、禁令全部按规格执行。
2. 既有测试零改动达成（page 0 旧测试不回归：1033 全绿含全部既有 drop 测试）。
3. 蓝条 page≥1 clamp 事项见 §5（不在写范围，只评估+上报，未改）。