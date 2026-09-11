# T-1F-B7-wave-b — BUG7 Wave B′: 顶层落点页内→全局下标映射（缺陷 2，最右列无法落入）

Status: ready
Wave: BUG7 B′（与 A′ 写范围不相交可并行 — Main 记 `concurrency_check`；AppDelegate 本波仅 makeDragGeometry 一处，Wave C′ 串在其后）
Role: Worker (implement + verify; do not modify Docs/, PROVENANCE/, frozen trees)

## 1. Root cause (verified — 带行号已对照源码实测)

呈现 = 全局 `topLevelOrder` 按 `itemsPerPage`（默认 35）切页；drop 几何只取当前页。链路（全部实测）：

1. `Sources/PagingPrototypeApp/AppDelegate.swift:612-618` `makeDragGeometry(.topLevel)`：只取当前页 `pageView(forPage: surface.core.committedPage)` 的 `dragItemFrames`，`DragGeometry(page: pageCount:)` 带页号（:618）。
2. `Sources/AppGridUI/DragSession/DragGeometry.swift:92-93`：有 `page`/`pageCount`，**无** `itemsPerPage` 字段。
3. `Sources/AppGridUI/DragSession/DragSessionController.swift:253-261` `currentIntent`：用 `geometry.itemFrames`（当前页）建 zones → `DropZoneClassifier.classify`（:260）。
4. `Sources/AppGridUI/DragSession/DropIntent.swift:90-125` `DropZoneGeometry.insertionIndex`：按当前页 frames 水平中点计数 → 产出**页内下标**（0…页内条目数）。
5. `Sources/AppGridUI/DragSession/DropResolver.swift:63-66`：`.insertion` 顶层 scope 校验 `index >= 0 && index <= layout.topLevelOrder.count`（:66）— **全局**序；:75-76 `.topLevelTarget` 同样按全局校验。
6. `Sources/AppGridUI/DragSession/DragMutationEngine.swift:24-32`：`.insertion(index)` → `reorderTopLevel(toIndex:)` — 按**全局**下标执行（`reorderAdjustedIndex` :77-80 仅做 remove-then-insert 差一）。

结论：**page ≥ 1 时任何顶层插入/移出落点全部错位**（页内下标被当全局下标消费）——拖到末页/最右列实际写到前面的全局槽，用户可见即"无法移到最右列"。现有 drop 测试全在 page 0/单页夹具 → **零覆盖**（BUG7-REPORT §2 候选①，Main 高置信）。

## 2. Fix spec

- 公式（**已定案，不改**）：顶层 scope 的 intent 产出处换算
  `globalIndex = page * itemsPerPage + localIndex`。
- 覆盖两类 intent：`.insertion`（顶层 scope）与 `.topLevelTarget`（move-out 顶层落点 —— 其 landing 同样由当前页 topLevelFrames 产出页内下标）。
- 换算点 = **intent 产出边界**：`DropZoneClassifier.classify`（DropIntent.swift:180-217）/`insertionIntent`（:219）或其输入（`DropZones` :129-152 / `DropZoneBuilder.zones` :155-176）带上 page+itemsPerPage。让 `DropResolver`（:63-76）与引擎（DragMutationEngine.swift:24-47）继续吃**全局下标**。
- **职责不混 mandate（禁令）**：**严禁**在 engine/resolver 二次换算。`reorderAdjustedIndex`（DragMutationEngine.swift:77-80）只负责"源在槽位左侧 → 槽位-1"的 remove-then-insert 差一，与页偏移无关，**不得混改**。
- `DragGeometry` 增加 `itemsPerPage` 字段（建议带默认值以兼容既有构造点：coordinator click 路径 :209 的空 geometry、既有测试构造；全量更新或默认值，Worker 择一并记录理由）。`makeDragGeometry` 从 `surface.itemsPerPage` 传入（该属性现成可用：AppDelegate.swift:96、:323-326；勿新增参数族 — `DragParameters` 参数族红线）。
- **folder scope 不做外层乘**：`.insertion` 在 folder scope 仍用成员下标（回归锁测试）；folder 内分页偏移本波不做（FIX-PLAN §6）。
- **页号陷阱**：folder scope 下 `DragGeometry.page` = **innerPage**（AppDelegate.swift:622），不是顶层页。`.topLevelTarget` 换算必须用**顶层 committedPage**（`surface.core.committedPage`），不得复用 geometry.page —— 建议在 `DropZones` 输入上显式携带顶层 page/itemsPerPage。
- 末页未满闭合性：前页按满页切，末页 `localIndex` 最大为该页条目数（插在最后一个之后）→ `page*itemsPerPage + local` = 全局末尾/下一页首位，公式自然闭合。
- 次因（edge zone 40pt 与末列右侧约 16pt 重叠，末列右半不好点）：**只评估 + 记录进结果文件**，不改 `edgeZoneWidthPT`/`dropZoneMarginsPT`，不单独开波。
- 必补测试（**新建 page≥1 夹具文件**，勿只改 page 0 旧测试）：
  1. page 1 页内 index `k` 的 insertion → 全局 `itemsPerPage + k`（35+k）
  2. 末页最右列：左半 = 该全局槽之前；放下后源项出现在末列
  3. 满页插最后一个之后 = 全局末尾（或下一页首位）
  4. folder 内 insertion **不得**乘外层 `itemsPerPage`（回归锁）

## 3. Write scope

- `Sources/AppGridUI/DragSession/DragGeometry.swift`（加 `itemsPerPage`）
- `Sources/AppGridUI/DragSession/DropIntent.swift`（顶层 intent 全局化；或其分类输入带上 page/itemsPerPage）
- `Sources/PagingPrototypeApp/AppDelegate.swift`（**仅 `makeDragGeometry`**）
- 新建 `Tests/AppGridUITests/` page≥1 夹具（新文件）

## 4. Forbidden writes

- 冻结树全列：`Sources/PagingCore/`、`Sources/AppCatalogCore/`、`Sources/MacAppCatalog/`、`Sources/AppIconPipeline/`、`Sources/PagingTelemetry/`、`Sources/PagingUI/`、`Package.swift`、`Sources/PagingPrototypeApp/AppLaunchController.swift`
- `AppDelegate.swift` 除 `makeDragGeometry` 外的一切（onCommit/handleDragCellClick/QuitOnBlankClickWindow 属 Wave C′）
- **`DragSessionController.swift`、`DropResolver.swift`、`DragMutationEngine.swift`**（换算不得下沉到这三处；reorderAdjustedIndex 只读）
- `Sources/AppGridUI/DragParameters.swift`（edge zone 参数不动）；`Docs/`、`PROVENANCE/`

## 5. Required reading (minimal, ≤4 files)

1. `Sources/AppGridUI/DragSession/DropIntent.swift` — insertionIndex :86-125、DropZones :128-152、zones :155-176、classify :179-217、insertionIntent :219
2. `Sources/AppGridUI/DragSession/DragGeometry.swift` — :88-110（page/pageCount 与 init）
3. `Sources/PagingPrototypeApp/AppDelegate.swift` — makeDragGeometry :606-634（仅此函数可写）
4. `Sources/AppGridUI/DragSession/DragMutationEngine.swift` — :75-80 `reorderAdjustedIndex`（只读，确认职责边界）

## 6. Verification

- `swift build -c debug` → exit 0
- `swift test`（全量）：基线 1026 + 新 page≥1 测试全绿；范围外失败只报告不修
- `swift build -c release` → exit 0

## 7. Acceptance（缺陷 2 映射）

- 用户验收：其他列的 app 能拖到**当前页最右列**并落位；**跨到末页最右列**同样落位；蓝条位置与放下后的格子一致。
- 四条新测试全绿（含 folder 回归锁）；旧 page 0 测试不回归。

## 8. Output discipline

- 先写 `Workflow/results/T-1F-B7-wave-b.md` 为 in-progress；次因（edge zone 重叠）评估结论写进结果文件；终版含改动清单、验收映射、测试证据。
- 回复 <250 词；无大代码块；隐私中性 A/B/C；无 git；声明 AccessDeclaration。