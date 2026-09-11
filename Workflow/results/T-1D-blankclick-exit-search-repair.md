# T-1D-blankclick-exit-search-repair — 结果（Worker T-1D-blankclick-exit-search-repair）

- 状态: **DONE**
- Worker: chef-worker-reviewer-workflow（Worker T-1D-blankclick-exit-search-repair / PagingPrototype）
- 日期: 2026-08-30
- 改动范围: `Sources/PagingPrototypeApp/AppDelegate.swift`、`Sources/PagingPrototypeApp/AppSearchController.swift`、`Tests/PagingUITests/BlankClickToQuitTests.swift`、`Tests/PagingUITests/AppSearchControllerTests.swift` + 本结果文件
- 验证: `swift test` **631 / 0**（基线 622，+9 新增）｜`swift build -c debug` **exit 0**｜`swift build -c release` **exit 0**

---

## 1. 目标与规格（对齐 spec）

**GOAL（authoritative spec：**Workflow/tasks/T-1D-blankclick-exit-search-repair.md**）**：
- 搜索状态 **ACTIVE**（field first-responder/编辑中，或已暂存 query，含「canonical 空 query + field 聚焦」点击情形）时，点击 **BLANK 区域**必须 **只退出搜索**：清空 query → 停用搜索 UI → 恢复 catalog → 把 `KeyboardFocusController` 恢复为 first responder，并且 **吞掉（consume）该点击**。
- 普通模式空白点击仍必须 **退出（terminate）app**。
- cell 点击 → 启动 app；field / clear-button 点击 → pass-through（交互区）。

**GATE**：过滤测试 `BlankClickToQuitTests` + `AppSearchControllerTests` 全绿；全量 `swift test` 绿 ≥622（suite baseline，velocityThreshold 800→700 调优后为 622；本次实测 **631 / 0**）；`swift build -c debug` exit 0；`swift build -c release` exit 0；禁止树不碰；无 git 操作（repo 全 untracked）；无隐私泄漏。

## 2. 根因

`QuitOnBlankClickWindow.sendEvent(_:)` 的 `.leftMouseDown` 分支对每个空白命中都会无条件 `onBlankClick?()` → `terminateOnBackgroundClick()`。当搜索正激活时点空白，会**整退 app** 而非只退搜索 —— 缺少「搜索激活时空白点击应改为 exit-search 且 consume」的接管逻辑。

## 3. 方案选择

在现有窗口级 `sendEvent` 空白命中分支内插入**搜索接管优先**：先问「空白点击是否应退出搜索」，命中才走原 terminate。
- 判定走 `AppSearchController` 新增的 computed seam `isSearchActive`（字段聚焦 / 编辑中 / 非空 currentQuery 任一即 active），**不**依赖旧私有布尔 flag——覆盖「canonical 空 query + field 聚焦」这类 flag 未置但仍处于搜索 UI 的情形。
- 退出路径复用共享 routine `exitSearchAndRestoreFocus()`：清 field → `presentation.clearQuery()` → `commitIfIdle()` → 恢复 `KeyboardFocusController` 为 first responder → 触发 `onSearchExited?()`。
- 不触碰冻结的 `AppLaunchController`（cell 启动）、`PagingCore`、`MacAppCatalog`、`Package.swift`。

## 4. Diff

### 4.1 `Sources/PagingPrototypeApp/AppSearchController.swift`

**(a) 私有布尔 flag 更名，避免与 computed seam 重名冲突**
`private var isSearchActive = false` → `private var isSearchActiveFlag = false`（line 42；`activateSearch` ~94 置 true，teardown ~83 / `exitSearchAndRestoreFocus` ~127 / `transferFocusToFirstResult` ~188 置 false）。

**(b) 新增 public computed seam `isSearchActive`（位于 activateSearch 之后）**
```swift
public var isSearchActive: Bool {
    isSearchActiveFlag
        || field.window?.firstResponder === field
        || field.window?.firstResponder === field.currentEditor()
        || !currentText.isEmpty
        || (presentation.currentQuery != nil && !query.isEmpty)
}
```
注意：必须用 `!query.isEmpty`（**不是** `!= nil`）——`AppGridSearchPresentationController.clearQuery()` 用 `updateQuery(raw:"")` 清空，会留下一个**非 nil 的空 currentQuery**；若用 `!= nil`，退出后 `isSearchActive` 仍为 true，空白点击会持续被接管、永远退不出。

**(c) 新增共享 routine `public func exitSearchAndRestoreFocus()`**
`clearFieldText()` → `presentation.clearQuery()` → `commitIfIdle()` → `guard field.window` → `window.makeFirstResponder(keyboardController)` → `isSearchActiveFlag = false` → `onSearchExited?()`。

**(d) `handleEscape` 空 query 分支**改为调用 `exitSearchAndRestoreFocus()`（原 `exitSearch()`）；**删除旧 private `exitSearch()`**（原 ~185–192）。`rebuildFirstResponder` 改读 computed `isSearchActive`。
隐私：不 log 任何 query / result 名字。

### 4.2 `Sources/PagingPrototypeApp/AppDelegate.swift`

**(a) `applicationDidFinishLaunching`（原 ~line 204）接线**
```swift
window.onBlankClickShouldExitSearch = { [weak self] in
    guard let self, let search = self.search, search.isSearchActive else { return false }
    search.exitSearchAndRestoreFocus()
    return true
}
window.onBlankClick = { self?.terminateOnBackgroundClick() }   // 既有，保留
```
注：`self.search` 在 `installContentAssembly`（~line 124，先于窗口创建 ~183）内创建，时序安全。

**(b) `private final class QuitOnBlankClickWindow` → `final class`**（去掉 `private`，使 `@testable import PagingUI` 测试可实例化；class 注释同步更新）；新增存储属性 `@MainActor var onBlankClickShouldExitSearch: (() -> Bool)?`。

**(c) 改 `override func sendEvent(_ event: NSEvent)` 的 `.leftMouseDown` 分支**：计算 contentView 命中；若 `!blankClickResolvesToCell(hit)`：
- 若 `onBlankClickShouldExitSearch` 已设置且 `MainActor.assumeIsolated({ exitSearch() })` 返回 true → `return`（**consume**，不 terminate）；
- 否则 `onBlankClick?(); return`。
cell 命中 → fall-through `super.sendEvent`。`blankClickResolvesToCell` 不变（field/editor/clear-button → 交互区，superview 链到 `AppGridCellView` → cell）。

### 4.3 新增/补充测试

**`Tests/PagingUITests/BlankClickToQuitTests.swift`**（+4 新；原 9 个分类测试未动）：
`@testable import PagingUI`；新增 `@MainActor makeClickHarness()` 返回 `(window: QuitOnBlankClickWindow, container: NSView, surface: PagingSurface, keyboard: KeyboardFocusController, search: AppSearchController)` —— 构建 `QuitOnBlankClickWindow` + `PagingSurface(pageCount:2, itemsPerPage:8)` + KeyboardFocusController 安装 + `AppGridSearchPresentationController()` 默认 provider + `AppSearchController` + `search.install(in:)`；field.frame=(x:350,y:660,w:300,h:28)；`makeFirstResponder(keyboard)`；按生产接线 `onBlankClickShouldExitSearch`。新增 `blankMouseDown(at:)` helper（`NSEvent.mouseEvent(.leftMouseDown…)`）。

| 测试 | 断言 |
|---|---|
| testBlankClickWhileSearchFocusedEmptyQueryExitsAndStaysAlive | `makeFirstResponder(search.field)` → `isSearchActive` true；sendEvent(20,20) → `isSearchActive` false、firstResponder===keyboard、terminated **未**调用 |
| testBlankClickWhileSearchQueryClearsQueryExitsAndStaysAlive | `activateSearch`+type "e" → 点空白后 query 清空 / field 空 / `isSearchActive` false / keyboard focused / terminated false |
| testBlankClickWhileSearchInactiveTerminates | 非搜索态点空白 → terminated closure **被**调用 |
| testCellClickDuringSearchPassesThrough | 空白处加 `AppGridCellView`(100,100,60,60)，`activateSearch`，断言 `blankClickResolvesToCell(cell)` true；sendEvent(130,130) → `isSearchActive` 仍 true + terminated false |

sendEvent cell pass-through 已证明 headless-safe。

**`Tests/PagingUITests/AppSearchControllerTests.swift`**（+5 新；原 11 个测试未动）：
| 测试 | 断言 |
|---|---|
| testIsSearchActiveTrueWhenFieldFocusedEmptyQuery | `window.makeFirstResponder(search.field)`、不 activateSearch → `isSearchActive` true（canonical 情形） |
| testIsSearchActiveTrueWithNonEmptyQuery | 非空 query → active |
| testIsSearchActiveFalseByDefaultWhenInactive | 默认 inactive → false |
| testIsSearchActiveFalseAfterEscapeEmptyExit | Escape 空 query 退出 → false |
| testExitSearchAndRestoreFocusClearsQueryRestoresFocus | type "e" → [Beta]；`exitSearchAndRestoreFocus()` → field 空、`presentation.currentQuery?.isEmpty` true、`presentationRecords.count==3`、firstResponder===keyboard |

## 5. 验证结果

| 项 | 结果 |
|---|---|
| `swift test --filter BlankClickToQuitTests` | **13 tests, 0 failures** |
| `swift test --filter AppSearchControllerTests` | **16 tests, 0 failures** |
| `swift test`（全量） | **631 tests, 0 failures (0 unexpected)** in 14.8s（PagingPrototypePackageTests.xctest；suite baseline ≥622 达成） |
| `swift build -c debug` | **exit 0**（Build complete） |
| `swift build -c release` | **exit 0**（Build complete, 6.14s） |

## 6. 禁止树核验

逐文件 `ls -lt` / mtime 核验（repo 全 untracked，故用文件系统证据，不做 git）：

```
Sources/PagingPrototypeApp/AppDelegate.swift         8月30 11:53  （本次改动）
Tests/PagingUITests/BlankClickToQuitTests.swift      8月30 11:53  （本次改动）
Tests/PagingUITests/AppSearchControllerTests.swift   8月30 11:53  （本次改动）
Sources/PagingPrototypeApp/AppSearchController.swift 8月30 11:52  （本次改动）

Sources/PagingPrototypeApp/AppLaunchController.swift 8月28 21:46  UNCHANGED（冻结，未动）
Package.swift                                        8月28 20:42  UNCHANGED（冻结，未动）
Sources/PagingCore/PagingParameters.swift            8月30 11:46  UNCHANGED（pre-landed velocityThreshold 800→700 调优，本次未碰）
Sources/PagingCore/ （其余）                          8月28/8月29  UNCHANGED
Sources/MacAppCatalog/                               8月28 21:01  UNCHANGED
```
STATUS: forbidden trees **UNCHANGED**。变更文件仅 4 个允许文件 + 本结果文件。无 git op（未 commit/push/tag）；无全局 `NSEvent` monitor；无 Accessibility 权限；无隐私泄漏（不 log query/结果名）。

## 7. 交付给 Reviewer/Main

verdict：**PASS**。
- diff：见 §4；改动仅 4 个允许文件 + results 文件。
- test：过滤 `BlankClickToQuitTests` **13/0**、`AppSearchControllerTests` **16/0**；全量 **631 / 0**（≥ 基线 622）。
- build：debug exit 0，release exit 0。
- 禁止树：mtime 全部核验未变。
- 结论：搜索 ACTIVE（含 canonical 空 query + field 聚焦）空白点击 → **仅退搜索并 consume**（清 query、恢复 catalog、KeyboardFocusController 回 first responder）；普通模式空白点击仍 terminate；cell→launch、field/clear-button→pass-through。独立 Reviewer 复核后可交 Main。
