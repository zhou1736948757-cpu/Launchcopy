# T-1F-B7-wave-c — BUG7 Wave C′: 建夹后主界面顶层 app 点击打不开（缺陷 3）【BLOCKED：串在 B′ 后】

Status: ready（原 blocked 已由 Main 解除：Wave B′ Reviewer PASS 并合并，2026-09-01；基线 1033/0）
Wave: BUG7 C′（**BLOCKED 条件：Wave B′ Reviewer PASS 并合并后**由 Main 解除派发 —— AppDelegate.swift 共享，防写冲突；与 A′ 无冲突）
Role: Worker (implement + verify; do not modify Docs/, PROVENANCE/, frozen trees)

## 1. Root cause (verified — 候选链；先取证，不定论)

- 现象：建夹后**主界面顶层** app 单击无反应（同一 cell 连点 6 次：有 pointerDown、无启动无反馈，DBG 日志实证）；**folder 内成员启动正常**（用户澄清）。Wave C（BUG6）修的是 fallback `endSession` 泄漏；用户走的是正常 click 路径，那次修复未覆盖。
- 点击链路（实测）：`AppGridCellView.mouseDown`（AppGridCellView.swift:184-187）→ `DragUISessionCoordinator.pointerDown`（DragUISessionCoordinator.swift:107-141）→ `pointerUp` click 路径（:206-214，state == .pressed → controller.pointerUp → `.clicked`）→ handleEvents（:287 调 dispatchClick :335）→ `onCellClick`（AppDelegate.swift:578-580）→ `handleDragCellClick`（:640-654）→ app cell 且 folder 未开 → `launchController?.handleCell(cell)`（:651）。
- `handleCell` 校验链（AppLaunchController.swift:129-143，**冻结不可改**）：① :134-136 `token.catalogRevision == served` else `.rejectedStaleRevision` ② :138 `assembly.bundleURL(for:)` else `.rejectedMissingApp` ③ :140 `fileExists` else `.rejectedMissingFile` ④ :142 `launcher.open` → `.launched`/`.failedToLaunch`。全部**静默**，仅记 `lastOutcome`（:65）/`outcomeCounts`（:67）/`record`（:146-152）。
- 主因候选（高置信）：建夹 commit → `applyCommittedLayout` 不 mint CatalogRevision，但 `applyPresentationUpdate`（AppDelegate.swift:663-670：cancel :666 + refreshPresentation :667 + setPageCount :669）重建 cell；重建后 live cell 的 `bindingToken.catalogRevision` 与 served 的关系、`bundleURL(for:)` identity 映射是否仍命中 → 静默拒绝（与"连点 6 次无反应"吻合）。
- 成员路径（健康，**必须不回归**）：`launchMember`（AppDelegate.swift:750-756）= `AppCatalogAssembly.makeMemberLaunchCell(appID:servedRevision:)`（AppCatalogAssembly.swift:450）+ `handleCell` —— 合成 cell 带当前 servedRevision。

## 2. Fix spec

### 2.1 第一层取证（强制，先于任何结构修改）

在 `handleDragCellClick` 读 `launchController.lastOutcome`（并记录是否进入该函数），中性方式取证，按**六态处置表**：

| lastOutcome | 处置 |
|---|---|
| `rejectedStaleRevision` / `rejectedMissingApp` / `rejectedNoBinding`（`rejectedMissingFile` 同拒绝族） | 顶层 app 改走 `launchMember(appID)`（或抽 `launchApp(appID)` 共用；身份仍从 `cell.bindingToken?.appID as? AppID` 读） |
| `nil` | 点击没到 `handleCell`：查 `pointerUp` 是 `.clicked`/fallback/idle + `sourcePresent`，查证后再修 |
| `launched` | 不在本波（启动器域） |
| `failedToLaunch` | 不在本波（启动器域） |

**取证结论必须写进结果文件后，才实施结构性修改**（红线 mandate；先猜后修 = 违规）。

### 2.2 结构性修法（取证后实施）

- 顶层与成员共用**合成 cell + 当前 servedRevision** 路径：不信任重建后 live token 做启动校验；身份从 `cell.bindingToken?.appID as? AppID` 读。
- **不改 `AppLaunchController.swift`**（冻结；`handleCell` 校验链保持原样）。

### 2.3 顺手收口（同波，小）

1. `QuitOnBlankClickWindow.sendEvent`（AppDelegate.swift:1016-1037）：现状 = 任何 `leftMouseDown` 只要 `isSessionActive`（`onDragActiveCancel` :239-242）即 `cancel` + 吞事件，注释却写"空白才吞"；收窄为"**仅空白**（`!blankClickResolvesToCell(hit)`）+ session active"才 cancel。
2. 删 `DragUISessionCoordinator.swift` 的 `DBG pointerDown` 打印（:105、:106、:110、:120、:123）。

### 2.4 测试

- 建夹 commit 后顶层 app 单击 → 启动管线被调用（可用 fake launcher 断言）。
- folder 成员启动不回归；空白点击退出不回归；交替拖拽/点击不回归。

## 3. Write scope

- `Sources/PagingPrototypeApp/AppDelegate.swift`（`handleDragCellClick` / QuitOnBlankClickWindow 空白吞事件收窄）
- `Sources/AppGridUI/DragUI/DragUISessionCoordinator.swift`（DBG 清理；取证需要可加中性 outcome 观察）
- 对应 `Tests/AppGridUITests/` 测试

## 4. Forbidden writes

- 冻结树全列：`Sources/PagingCore/`、`Sources/AppCatalogCore/`、`Sources/MacAppCatalog/`、`Sources/AppIconPipeline/`、`Sources/PagingTelemetry/`、`Sources/PagingUI/`、`Package.swift`、**`Sources/PagingPrototypeApp/AppLaunchController.swift`**（评估/修复均不得触碰）
- Wave B′ 写范围（`DragGeometry.swift`/`DropIntent.swift`/`makeDragGeometry`）—— C′ 串行防冲突
- `Docs/`、`PROVENANCE/`；`Workflow/results/` 仅本任务结果文件

## 5. Required reading (minimal, ≤4 files)

1. `Sources/PagingPrototypeApp/AppDelegate.swift` — handleDragCellClick :636-654、launchMember :748-756、applyPresentationUpdate :663-670、QuitOnBlankClickWindow :987-1037
2. `Sources/PagingPrototypeApp/AppLaunchController.swift` — lastOutcome :65、handleCell :123-125、launch(from:) :129-143（只读）
3. `Sources/AppGridUI/DragUI/DragUISessionCoordinator.swift` — click 路径 :206-214、dispatchClick :335、DBG :105-123
4. `Sources/PagingPrototypeApp/AppCatalogAssembly.swift` — makeMemberLaunchCell :450（只读）

## 6. Verification

- `swift build -c debug` → exit 0
- `swift test`（全量）：基线 1026 + 新测试全绿；范围外失败只报告不修
- `swift build -c release` → exit 0

## 7. Acceptance（缺陷 3 映射）

- 建夹后主界面任意顶层 app 单击**可启动**；空白单击仍可退出；folder 内成员启动保持正常；交替拖拽/点击 20 次无退化。

## 8. Output discipline

- 解除 blocked 后先写 `Workflow/results/T-1F-B7-wave-c.md` 为 in-progress；**取证段先落盘**（六态结论 + 证据），再实施结构性修改；终版含取证结论、改动清单、验收映射、测试证据。
- 回复 <250 词；无大代码块；隐私中性 A/B/C；无 git；声明 AccessDeclaration。