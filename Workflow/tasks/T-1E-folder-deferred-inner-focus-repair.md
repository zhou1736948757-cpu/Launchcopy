# T-1E-folder-deferred-inner-focus-repair

- Status: OPEN
- Phase: 1E (folder foundation)
- Reported by: user real-GUI test (Chinese, verbatim): "现在的话，我一打开这个文件夹，它会就是第一行第一个软件就会进入这个蓝框。默认情况下应该不会进入这个蓝框。"
- Root cause: T-1E-folder-mouse-open-repair 在两条打开路径都加了打开瞬间的 `applyInnerFocusVisual()` 调用（`Sources/PagingPrototypeApp/KeyboardFocusController.swift` openFolder :275、openFolderFromClick :293），导致打开文件夹时成员 1（slot 0）立即显示蓝框。用户要求默认不显示蓝框，首次按方向键才出现（延迟选中，与外层网格 `isDeferredSelection` 行为一致）。
- Fix spec (exact):
  1. `KeyboardFocusController.swift` `openFolder(_ identity:)`（:269-276）：删除 :275 的 `applyInnerFocusVisual()` 调用。保留其余全部（openedFolderIdentity = identity.entryIdentity；innerFocusIndex = 0；focusModel = AppGridFocusModel(current: nil)；applyFocusVisual()；onOpenFolder?(identity)）。同步更新 :267-268 文档注释（"打开后立即应用内部成员焦点视觉" → "打开时不显示内环，首次方向键后延迟显示（与 isDeferredSelection 一致）"）。
  2. `openFolderFromClick(_ folderID:)`（:285-294）：删除 :293 的 `applyInnerFocusVisual()` 调用。保留其余全部（openedFolderIdentity = .folder(folderID)；innerFocusIndex = 0；focusModel = AppGridFocusModel(current: nil)；applyFocusVisual()；合成 identity；onOpenFolder?(identity)）。同步更新 :282-284 文档注释。
  3. 不得改动：`handleInnerArrow`（:330-344，首次方向键 move 后调 applyInnerFocusVisual 即天然延迟显示）、`applyInnerFocusVisual`（:356-363）、`closeFolder`、`restoreFocusAfterClose`、`activateInnerMember`、`isFolderOpen`。
  4. Bug 2 要求保持：两条打开路径仍清除外层焦点（focusModel = nil）并初始化 innerFocusIndex = 0（首次方向键从成员 1 起算）。
- Tests (Tests/PagingUITests/FolderIntegrationTests.swift):
  - `testMouseOpenClearsOuterRingAndShowsInnerRing`（:543）→ 改名 `testMouseOpenClearsOuterRingAndDefersInnerRing`：保留 focusModel.current == nil 断言；:571-572 改为 `XCTAssertEqual(overlay.memberCell(at: 0)?.isFocused, false, "打开后无内环（延迟选中）")`；追加 `keyboard.keyDown(with: rightArrow())` 后断言 `memberCell(at: 1)?.isFocused == true`。
  - `testKeyboardOpenShowsInnerRingOnMemberOne`（:575）→ 改名 `testKeyboardOpenDefersInnerRingUntilFirstArrow`：:596-597 改为 `isFocused == false`（"键盘打开后无内环（延迟选中）"）；追加 rightArrow keyDown 后 `memberCell(at: 1)?.isFocused == true`。
  - `testMouseOpenThenRightArrowMovesInnerRing`（:600）：:617 改为 `XCTAssertEqual(overlay.memberCell(at: 0)?.isFocused, false, "打开后无环（延迟选中）")`；:620-623 保留（右箭头后成员 2 聚焦、成员 1 取消）。
  - 辅助函数 `rightArrow()` / `returnKey()` / `makeFolderSeamFixture()` 已存在，直接复用。
- Write scope: `Sources/PagingPrototypeApp/KeyboardFocusController.swift` + `Tests/PagingUITests/FolderIntegrationTests.swift`。
- Forbidden (NEVER modify): 冻结树 `Sources/PagingCore/`、`Sources/AppCatalogCore/`、`Sources/MacAppCatalog/`、`Sources/AppIconPipeline/`、`Sources/PagingTelemetry/`、`Sources/PagingUI/`、`Package.swift`、`Sources/PagingPrototypeApp/AppLaunchController.swift`；以及本任务范围外文件 `Sources/AppGridUI/`（含 FolderOverlayView.swift）、`Sources/PagingPrototypeApp/AppDelegate.swift`、`Sources/PagingPrototypeApp/AppCatalogAssembly.swift`。无 git 操作（仓库无提交）。
- Verification: `swift build -c debug` exit 0；`swift test` 真实执行（XCTest "Executed N tests" 行，N > 0）且 0 失败（基线 772）；`swift build -c release` exit 0。冻结树 mtime 检查（全部早于本任务编辑）。
- Output discipline: 第一步先写 `Workflow/results/T-1E-folder-deferred-inner-focus-repair.md` 内容 "in progress"；最终回复 <250 词、无大段代码块。
- Acceptance: 打开文件夹（鼠标或键盘）时成员区无蓝框；首次按方向键后蓝框出现在移动目标成员；外层蓝框在鼠标打开后仍清除；←/→ 可选中成员。
