# BUG7 修复方案 — 建夹落点 / 最右列插入 / 建夹后顶层点击

- **日期**：2026-09-01
- **状态**：待 Ops 确认后派发；本文是方案，未改产品代码、未派发 Worker
- **上游**：`Workflow/BUG7-REPORT.md`（三波 BUG6 合并后用户实机复测）
- **基线**：1026 tests / 0 failures；debug/release exit 0
- **仓库**：`/Users/mac/Projects/Launch_Copy/PagingPrototype`

本方案在 BUG7 报告的只读定位之上做了裁决：**按用户原话的格子位置修，不按 Wave B 的「相对锚点」继续修。**

---

## 0. 一句话结论

| # | 用户现象 | 根因 | 修法 |
|---|---|---|---|
| 1 | 拖 A 到 B 上建夹，folder 仍在 A 的格子 | Wave B 公式 `source < target → targetIndex - 1`，相邻时等于 min，和修 BUG6 前一模一样 | `insertion = targetIndex`（folder 顶替 B 原格） |
| 2 | 其他列拖不到最右列 | `insertionIndex` 是**页内**下标，`DropResolver` / `reorderTopLevel` 按**全局** `topLevelOrder` 消费；page ≥ 1 全部错位。次因：末列右侧与 40pt edge zone 重叠 | 顶层 intent：`global = page * itemsPerPage + local`；补 page≥1 / 末列单测 |
| 3 | 建夹后主界面 app 点不开；folder 里成员能开 | 两条启动路径不一致：成员走合成 cell + 当前 `servedRevision`；顶层走 live cell token，建夹后呈现重建可静默拒 | 顶层点击改走与 `launchMember` 同一条已验证路径；先读 `lastOutcome` |

---

## 1. 架构前提（必须先统一，否则 Wave B 会再修错）

这个原型**拖的过程中格子不会让位**（没有 springboard 式 live reflow）。用户松手时，B 还在原来的格子上。落点必须按**屏幕格子**算，不能按「先抽走 A、B 左移一格」的相对锚点算。

数据模型：

- 本原型顶层是一条全局 `topLevelOrder`，再按 `itemsPerPage`（默认 35）切页呈现。
- 页视图是 **5 列 × 7 行**（`AppGridPageView.columns = 5`）。
- drop 几何只取**当前页** `pageView.dragItemFrames`，下标是 0…页内条目数。
- mutation 引擎按全局下标写 `topLevelOrder`。

因此：建夹落点是「原格 index」问题；跨页/末列插入是「页内 index → 全局 index」映射问题。两件事不要混成一个公式。

---

## 2. 缺陷 1 — 建夹落点（Wave A′）

### 2.1 现状

`Sources/AppGridUI/LayoutDomain/LayoutMutation.swift` 约 124 行：

```swift
let insertion = sourceIndex < targetIndex ? targetIndex - 1 : targetIndex
ordered.remove(at: max(targetIndex, sourceIndex))
ordered.remove(at: min(targetIndex, sourceIndex))
ordered.insert(.folder(id), at: min(insertion, ordered.count))
```

成员序「先目标后源」是对的，不要动。错的是落点补偿 `-1`。

### 2.2 正确公式

```swift
let insertion = targetIndex
ordered.remove(at: max(targetIndex, sourceIndex))
ordered.remove(at: min(targetIndex, sourceIndex))
ordered.insert(.folder(id), at: min(insertion, ordered.count))
```

先删大下标、再删小下标，再把 folder 插回 **B 的原始 index**（clamp 兜底不变）。

### 2.3 验收表（按格子，不按相对锚点）

| 构型 | source / target | 现在（Wave B） | 用户期望 |
|---|---|---|---|
| `[A, B, C]` 相邻左→右 | A→B（0→1） | `[F, C]` folder 在 A 格 | `[C, F]` folder 在 B 格（index 1） |
| `[B, A, C]` 相邻右→左 | A→B（1→0） | `[F, C]` | `[F, C]`（碰巧对） |
| `[A, X, B, C]` 非相邻 | A→B（0→2） | `[X, F, C]` 左偏一格 | `[X, C, F]` folder 在 B 原 index 2 |

成员序锁：`folders[0].members == [B, A]`（先目标后源）。

### 2.4 必须改的测试与文档

Wave B 测试把「索引 1 / B 原位」写成了 `[folder, C]`，内部自相矛盾，当时按相对锚点裁决，用户实机否定。

- 重写 `Tests/AppGridUITests/LayoutMutationCreateFolderBug6Tests.swift`
  - 左方向：期望 `[C, F]`，不是 `[F, C]`
  - 右方向：仍 `[F, C]`
  - 非相邻：期望 `[X, C, F]`，不是 `[X, F, C]`
- 同步 `LayoutMutation.swift` 文件头 / `createFolder` doc
- 同步 `Docs/ADR-010-DRAG-SESSION-AND-DROP-SEMANTICS.md` Q4 M3：删掉「source 在 target 前时 targetIndex − 1」

### 2.5 写入范围

- `Sources/AppGridUI/LayoutDomain/LayoutMutation.swift`
- `Tests/AppGridUITests/LayoutMutationCreateFolderBug6Tests.swift`
- `Docs/ADR-010-DRAG-SESSION-AND-DROP-SEMANTICS.md`

不碰 AppDelegate、不碰 DragSession。域层独立。

### 2.6 用户验收

`[A, B, C]` 把 A 拖到 B 上 → folder 出现在 **B 原来的格子**，C 补到左边。两方向 + 非相邻都要过。

---

## 3. 缺陷 2 — 最右列无法落入（Wave B′）

### 3.1 主因（高置信）

链路：

1. `AppDelegate.makeDragGeometry` 只取当前页 frames，`DragGeometry.page` 已有、但未参与 index 换算。
2. `DropZoneGeometry.insertionIndex` / `hitZone` 左右半区产出的是**页内**下标。
3. `DropResolver` 用 `0...layout.topLevelOrder.count` 校验。
4. `DragMutationEngine.reorderTopLevel(toIndex:)` 按**全局**下标插入。

page ≥ 1 时，拖到末页最右列会写到第 0 页对应槽，看起来就是「没法进最右列」。当前 drop 测试全在 page 0 / 单页夹具，**零覆盖**。

`DragGeometry` 有 `page` / `pageCount`，**没有** `itemsPerPage`。默认每页 35。

### 3.2 修法

顶层 insertion 与 move-out 的 `topLevelTarget`：

```text
globalIndex = page * itemsPerPage + localIndex
```

- **只**对顶层 scope 做。folder 内成员重排仍用成员下标（若 folder 内分页，另加 inner 偏移，本波不做）。
- 换算点放在 **intent 产出边界**（`DropZoneClassifier` / `insertionIntent`），让 `DropResolver` 与引擎继续吃全局下标。不要在引擎里偷偷再减一次（`reorderAdjustedIndex` 仍只负责「源在槽位左侧 → 槽位 -1」，与页偏移无关）。
- `DragGeometry` 增加 `itemsPerPage`；`makeDragGeometry` 从 `surface.itemsPerPage` 传入。

末页未满：`localIndex` 最大为该页条目数（插在最后一个之后）。前页按满页切，`page * itemsPerPage + local` 仍等于全局末尾。

### 3.3 次因（中置信，本波评估，不单独开波）

页视图 inset 24pt，edge zone 40pt。满行末列右侧约 16pt 与右缘热区重叠：

- 非末页：悬停末列右侧会武装 500ms 翻页 dwell。
- 末页：`atLastPage` 不翻页，但右半格不好点。

左右半区语义（Wave A 已修）：末列**左半** = 插入到该格之前（占用末列）；**右半** = 插到该格之后（换行或下一页首位）。用户说「拖到最右列」是要**占用末列格子**，应对左半 / 上一格右半。主修仍是页偏移；边缘重叠只做评估 + 必要时缩小与末列的冲突，不把 edge zone 从 40pt 盲改掉。

### 3.4 必须补的测试

- page 1：页内 index `k` 的 insertion → 全局 `itemsPerPage + k`
- 末页最右列：左半 = 该全局槽之前；放下后源项出现在末列
- 满页、插在最后一个之后 = 下一页首位（或全局 count）
- folder 内 insertion **不得**乘外层 `itemsPerPage`（回归锁）

### 3.5 写入范围

- `Sources/AppGridUI/DragSession/DragGeometry.swift`（加 `itemsPerPage`）
- `Sources/AppGridUI/DragSession/DropIntent.swift`（顶层 intent 全局化）
- `Sources/PagingPrototypeApp/AppDelegate.swift` 仅 `makeDragGeometry`（传入 `itemsPerPage`）
- 对应 `Tests/AppGridUITests/`（新建 page≥1 夹具，不要只改 page 0 旧测试）

与 A′ 无文件冲突，可并行。与 C′ 抢 AppDelegate → C′ 串在 B′ 之后。

### 3.6 用户验收

其他列的 app 能拖到当前页最右列并落位；跨到末页最右列同样落位；蓝条位置与放下后的格子一致。

---

## 4. 缺陷 3 — 建夹后主界面点不开（Wave C′）

### 4.1 已澄清

- folder 内成员启动**正常**。
- 问题只限建夹后**主界面顶层** app 单击。
- 连点 6 次同一 cell：有 `pointerDown`，无启动、无拖拽、无反馈。
- Wave C 修的是 fallback `endSession` 泄漏；用户走的是正常 click 路径，那次修复未覆盖。

### 4.2 两条启动路径

成员（已通）：

```swift
let cell = AppCatalogAssembly.makeMemberLaunchCell(appID: appID, servedRevision: served)
_ = launchController.handleCell(cell)
```

顶层（不通）：

```swift
handleDragCellClick → launchController.handleCell(liveCell)
```

`handleCell` 校验：`token.catalogRevision == servedRevision` → `bundleURL` → `fileExists` → `NSWorkspace.open`。失败全部静默，只记 `lastOutcome`。

建夹 commit：`applyCommittedLayout` **不 mint** CatalogRevision，但会 `refreshPresentation` + `setPageCount` 重建 cell。live token 与当前 served 的关系、以及 `AppID as?` 是否仍命中，是拒绝候选。

`AppLaunchController.swift` **冻结**，不能改校验链。修复只能在 AppDelegate / coordinator。

### 4.3 先取证，再靶向

在 `handleDragCellClick` 里读 `launchController.lastOutcome`（及是否进入该函数）。不要猜。

| lastOutcome | 处置 |
|---|---|
| `rejectedStaleRevision` / `rejectedMissingApp` / `rejectedNoBinding` | 顶层 app 改走 `launchMember(appID)`（或抽一层 `launchApp(appID)` 共用） |
| `nil` | 点击没到 `handleCell`：查 `pointerUp` 是 `.clicked` / fallback / idle；查 `sourcePresent` |
| `launched` | 不在本波（启动器） |
| `failedToLaunch` | 不在本波 |

取证通过后的结构性修法（即使拒绝类别是 stale）：顶层与成员共用合成 cell + 当前 `servedRevision`，**不信任**重建后的 live token 去做启动校验。身份仍从 `cell.bindingToken?.appID as? AppID` 读。

### 4.4 顺手收口（同一波，小）

1. `QuitOnBlankClickWindow.sendEvent`：现在 **任何** `leftMouseDown` 只要 `isSessionActive` 就 `cancel` 并吞事件。注释写的是「空白才吞」。本次 6 次 `pointerDown` 已打到 cell，不是主因；C′ 收成「仅空白 + session active」。
2. 删除 coordinator 里遗留的 `DBG pointerDown` 打印（T-1F-B-tests-actor-fu-1）。

### 4.5 写入范围

- `Sources/PagingPrototypeApp/AppDelegate.swift`（`handleDragCellClick` / 空白吞事件）
- `Sources/AppGridUI/DragUI/DragUISessionCoordinator.swift`（DBG 清理；若取证要加中性 outcome 观察）
- 对应测试：建夹 commit 后顶层 app 单击 → 启动管线被调用（可用 fake launcher）；folder 成员启动不回归

不改 `AppLaunchController.swift`。

### 4.6 用户验收

建夹后，主界面任意剩余 app 单击可启动；空白单击仍可退出；folder 内成员启动保持正常。

---

## 5. 波次、并发、约束

### 5.1 调度

| 波次 | 缺陷 | 与其他波 | Reviewer |
|---|---|---|---|
| **Wave A′** | 缺陷 1 | 无依赖，可立即派发 | 独立 PASS 才合并 |
| **Wave B′** | 缺陷 2 | 与 A′ 可并行（写入不重叠） | 同上 |
| **Wave C′** | 缺陷 3 | AppDelegate 与 B′ 共享 → **串在 B′ 之后**；A′ 不挡 | 同上 |

`max_worker_concurrency = 3`。建议有效并发：A′ ∥ B′，然后 C′。不派 Expert Worker，除非某波 Reviewer 正式 FAIL 第二次。

### 5.2 每波流程

Worker 实现 → 独立 Reviewer PASS → 合并。Main 不手写产品修复。事件经 `record_workflow_event.py`。任务包文件必须先存在。

### 5.3 红线（沿用 BUG6 / BUG7 报告）

- **冻结**：`Sources/PagingCore/`、`AppCatalogCore/`、`MacAppCatalog/`、`AppIconPipeline/`、`PagingTelemetry/`、`PagingUI/`、`Package.swift`、`PagingPrototypeApp/AppLaunchController.swift`
- **禁读**：LaunchBetter / BuhoReverseNotes / `2026-08-25-buho-launchpad-reverse`；Worker 只按本方案与用户原话实现
- **隐私**：报告/日志/telemetry 用 A/B/C 代称；禁真实 app 名、bundle ID、路径、folder 标题、成员列表
- **无 git**：不 commit / push / tag
- **测试**：全量 `swift test` 须保持绿；`exit_code == 0` 且 `executed_tests == 0` = 无效

### 5.4 每波后实机脚本

1. `[A,B,C]` 相邻左/右两方向建夹落点（folder 在 B 格）
2. 跨页拖到末页最右列，以及同页内拖到最右列
3. 建夹后单击各顶层 app + 空白退出
4. 交替拖拽/点击 20 次无退化；folder 内成员拖拽/启动不回归

---

## 6. 明确不在本方案里的事

- 不把建夹落点改回 min / 「最早位置」（那是 live-reflow 网格的语义；本原型无 live reflow，会再次落在 A 格）。
- 不在本波做 folder 内分页的页偏移（用户报告的是主网格最右列）。
- 不改 `AppLaunchController` 校验顺序。
- 不把 5 列网格改成 7 列（用户没要求）。
- sessionLayout generation 恒零：维持 `BUG6-FIX-PROMPT` §4.3 观察项，本三波不修，除非 C′ 取证证明它就是顶层点击失败的直接原因。

---

## 7. 建议的立即动作

1. Ops 确认本方案后派发 **Wave A′**（范围小、公式闭合、无 AppDelegate）。
2. 同时或紧接着派发 **Wave B′**（页偏移 + page≥1 测试）。
3. B′ 合并后再派 **Wave C′**（先 `lastOutcome`，再统一启动路径）。

A′ 用户验收就一句：把 A 拖到 B 上，folder 出现在 B 原来的格子。
