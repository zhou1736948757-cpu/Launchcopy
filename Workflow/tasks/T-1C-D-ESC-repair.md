# Task T-1C-D-ESC-repair — 修复 ESC 视觉清除（Reviewer r1 MAJOR）

Phase: 1C follow-up repair
Owner: Repair Worker → Independent Reviewer
Parent: T-1C-D
Baseline: T-1C-D 已实现（520 tests green），Reviewer r1 FAIL（1 MAJOR）。其余 4 项 + bug-1 均 PASS。

## Objective

修复唯一 MAJOR：**ESC 未真正清除选择框高亮**。修复后 `swift test` 仍 520/0，且新增断言验证视觉清除。

### 根因（Reviewer + Main 已定位）
`Sources/PagingPrototypeApp/KeyboardFocusController.swift` 中 `exitKeyboardSelection()`（T-1C-D Worker 新增，约 L226-231）当前逻辑：
```swift
focusModel = AppGridFocusModel(current: nil)
lastAppliedIdentity = nil      // ← 提前置 nil
isDeferredSelection = true
applyFocusVisual()
```
`applyFocusVisual()` 的 nil-current 分支（约 L211-217）依赖：
```swift
guard let identity = focusModel.current else {
    if let last = lastAppliedIdentity { cell(for: last)?.setFocused(false) }
    lastAppliedIdentity = nil
    return
}
```
因 `lastAppliedIdentity` 已被提前置 nil，旧 cell 永远不会被 `setFocused(false)` → `AppGridCellFocus.isFocused == (layer.borderWidth > 0)` 仍 true → 高亮框不消失。ESC 后再播种还会双框。

### 修复方案
`exitKeyboardSelection()`：**删除**提前的 `lastAppliedIdentity = nil`（`applyFocusVisual` 的 nil 分支本会 unhighlight last 并自清）；或把该行移到 `applyFocusVisual()` 之后。二者等价。保持 `focusModel = AppGridFocusModel(current: nil)` + `isDeferredSelection = true` + `applyFocusVisual()`。

### 测试（必须补）
`Tests/PagingUITests/KeyboardFocusControllerTests.swift` 中 `testEscClearsFocusAndReseedsOnNextArrow`（或新增）补关键断言：ESC 后旧 cell 的 `isFocused == false`——即选中某 cell → 记录该 cell 引用 `let cell = renderer.pageView(forPage:…)?cell(at:…)` → 按 ESC → `XCTAssertEqual(cell?.isFocused, false)`（可复用 `assembly.renderer.pageView(...)`，与本文件既有测试一致）。不得删减既有断言（current==nil 保留）。

## Expected / Allowed Write Scope
- 允许：`Sources/PagingPrototypeApp/KeyboardFocusController.swift`（仅 `exitKeyboardSelection` 一处）、`Tests/PagingUITests/KeyboardFocusControllerTests.swift`（仅该测试断言）、`Workflow/results/T-1C-D-ESC-repair.md`。
- 禁止（不得修改）：`Sources/PagingCore/`、`Sources/PagingUI/`、`Sources/AppGridUI/`、`Sources/MacAppCatalog/`、`Package.swift`、`Sources/PagingPrototypeApp/AppLaunchController.swift`；不读 BuhoReverseNotes/LaunchBetter。
- 红线：不 commit/push/tag；隐私不变；生产 Timer tolerance 8.333ms 不动；不宣称修 hitch。

## Done criteria
- `swift test` 全绿 **≥520 / 0 fail**，且 `testEscClearsFocusAndReseedsOnNextArrow`（含新 isFocused==false 断言）绿。
- `swift build -c debug`、`-c release` 各 exit 0。
- 禁止树 mtime 未动。
- 结果写 `Workflow/results/T-1C-D-ESC-repair.md`（改动 diff 说明、测试计数、视觉清除验证、禁止树核验）。
