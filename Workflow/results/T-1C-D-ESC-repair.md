# T-1C-D-ESC-repair — 结果（Repair Worker）

Phase: 1C follow-up repair
Task: `Workflow/tasks/T-1C-D-ESC-repair.md`
Owner: Repair Worker → Independent Reviewer
Verdict: **DONE**

## 1. 修复内容（`exitKeyboardSelection`）

`Sources/PagingPrototypeApp/KeyboardFocusController.swift`

**Before（T-1C-D Worker 实现，约原 L226-231）：**
```swift
private func exitKeyboardSelection() {
    focusModel = AppGridFocusModel(current: nil)
    lastAppliedIdentity = nil      // ← 提前置 nil（Bug：defeat nil-current 分支 unhighlight）
    isDeferredSelection = true
    applyFocusVisual()
}
```

**After：**
```swift
private func exitKeyboardSelection() {
    focusModel = AppGridFocusModel(current: nil)
    // 保留 lastAppliedIdentity：applyFocusVisual() 的 nil-current 分支依赖它
    // 对旧 cell 调 setFocused(false) 完成 unhighlight；之后再自清。
    isDeferredSelection = true
    applyFocusVisual()
}
```

**Diff 摘要：** 删除提前的 `lastAppliedIdentity = nil` 一行（即 spec 的「删除」方案；等价于移动到 `applyFocusVisual()` 之后）。因 `applyFocusVisual()` 的 nil-current 分支
（`guard let identity = focusModel.current else { if let last = lastAppliedIdentity { cell(for: last)?.setFocused(false) }; lastAppliedIdentity = nil; return }`）
会先基于 `lastAppliedIdentity` 对旧 cell 调 `setFocused(false)` 完成 unhighlight 后自清，故保留该状态即可正确清除高亮框。保持
`focusModel = AppGridFocusModel(current: nil)` + `isDeferredSelection = true` + `applyFocusVisual()` 不变。

## 2. 测试断言补充

`Tests/PagingUITests/KeyboardFocusControllerTests.swift` `testEscClearsFocusAndReseedsOnNextArrow`：
- 选中 slot 1 后，在 ESC 前记录被聚焦的 cell 引用：
  `let selectedCell = assembly.renderer.pageView(forPage: 0)?.cell(at: 1)`，并在 ESC 前断言其 `isFocused == true`（前置确认）。
- ESC 后新增关键断言：`XCTAssertEqual(selectedCell?.isFocused, false, "ESC 后旧 cell 焦点视觉清除")`。
- 既有断言 `current == nil` 及其余断言全部保留未删。

## 3. 验证结果

| 步骤 | 结果 |
|------|------|
| `swift test` | **520 tests, 0 failures** (Executed 520 tests, with 0 failures) |
| `testEscClearsFocusAndReseedsOnNextArrow`（含新 isFocused==false 断言） | ✅ PASS (0.076s) |
| `swift build -c debug` | **exit 0** |
| `swift build -c release` | **exit 0** |
| 禁止树 mtime 核验 | 空（无改动） |

## 4. 禁止树核验

以会话起始时刻 `2026-08-30 01:26:56 JST` 为基准：
```
find Sources/PagingCore Sources/PagingUI Sources/AppGridUI Sources/MacAppCatalog -type f -newermt "2026-08-30 01:26:56"
find Sources/PagingPrototypeApp/AppLaunchController.swift Package.swift -newermt "2026-08-30 01:26:56"
```
两者输出均为空 → 未触碰任何禁止树文件。未 commit/push/tag。未读 BuhoReverseNotes/LaunchBetter。

## 5. 视觉清除验证结论

ESC 后旧 cell 的 `AppGridCellFocus.isFocused` 变为 `false`（`layer.borderWidth` 随之归零，高亮框消失）——已由新断言
`XCTAssertEqual(selectedCell?.isFocused, false)` 在真实渲染 cell 上验证通过，修复前该断言会失败（因为 `lastAppliedIdentity` 被提前置 nil）。
