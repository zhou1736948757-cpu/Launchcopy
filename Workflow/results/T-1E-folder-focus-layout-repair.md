# T-1E-folder-focus-layout-repair（Task A：焦点布局/导航器组合化）

Status: PASS

## 改动文件

1. `Sources/AppGridUI/AppGridFocusLayout.swift`
   - 新增存储 `entries: [TopLevelEntry]`（统一组合）；新构建
     `build(from:composition:itemsPerPage:)`；`build(from:itemsPerPage:)` 保留为
     `records.map { .app($0) }` 便捷路径（app-only 兼容）。
   - `validItemCount`/`pageCount` 基于 entries；新增主 API
     `validEntry(page:slot:) -> TopLevelEntryIdentity?`；`validAppID` 改为兼容助手
     （validEntry 的 .app case；folder/占位 → nil）。
   - `firstValidIdentity`/`contains`/`position(of:)` 改 entryIdentity 基（position 搜 entries，
     含文件夹偏移）；`validIdentities`/`validSlots`/`rowCount`/`lastValidSlot` 保持。
   - `migrate(identity:)`：anchor = `identity.entryIdentity`；`.app` → entries 定位 located /
     消失 → CatalogPlanner.remap 五级降级（既有路径）；`.folder` → 存在 .located /
     消失 → .clamped(firstValidIdentity())（确定性）；nil → 既有 clamped 首有效路径。

2. `Sources/AppGridUI/AppGridFocusNavigator.swift`
   - 守卫（:33-34）→ `layout.validEntry(page:slot:) == identity.entryIdentity`
     （folder 身份不再被 validAppID 误拦）。
   - `makeIdentity`（:67-70）→ validEntry + `entryIdentity:` 构造。

3. `Tests/AppGridUITests/AppGridFocusCompositionTests.swift`（新增，10 测试）
   - 组合布局：3 folder + 32 app → pageCount 1、validSlots 0..<35、
     validEntry(0,0..2) == .folder、validEntry(0,3) == .app(未分组首 app)、
     validAppID(0,0) == nil、validAppID(0,3) == 首 app id、越界 nil。
   - 导航器：folder 身份 ↑/↓/←/→ 均可移动（守卫不误拦）；目标 entryIdentity 正确
     （↓ slot0→slot5 仍 .folder；↓ slot2→slot7 == .app 首 app）；stale folder 身份不导航。
   - migrate：folder anchor 存在 → .located（新位置）；消失 → .clamped（首有效）；
     app anchor 组合偏移（app-only slot 6 → 组合 slot 3）→ .located 正确位置。
   - app-only 构建兼容：validEntry/validAppID/firstValidIdentity/position/contains。

## 测试计数

- 基线 772 + 新增 10 = **782 测试，0 failures**（XCTest "Executed 782 tests, with 0 failures"）。
- 既有 AppGridFocusTests / AppGridFocusNavigatorTests 全部保持通过（app-only 构建兼容）。

## 构建结果

- `swift build -c debug`：exit 0，Build complete。
- `swift build -c release`：exit 0，Build complete。

## 冻结树 mtime 核验

- 修改前记录 50 个冻结文件 mtime（Sources/PagingCore、AppCatalogCore、MacAppCatalog、
  AppIconPipeline、PagingTelemetry、PagingUI、PagingPrototypeApp、Package.swift）。
- 修改后 diff 为空 → **冻结树未动**。FolderDomain.swift / AppGridUIPageContentProvider.swift /
  AppGridFocusModel.swift 未修改（只读）。

## 偏差

- 无。未触碰 Task B 范围（Sources/PagingPrototypeApp/）；未运行 app；无 git 操作。
- 隐私红线：测试仅用中性标识（AppNN / Group N），无真实 app/folder 名称。

## Reviewer 关注点

- validEntry/validAppID 兼容语义；position 按 entries 搜索（含文件夹偏移）。
- migrate folder 分支（located/clamped）与 app 分支（remap 五级降级）边界。
- 导航器守卫 entryIdentity 比对（nil==nil 边界与旧 validAppID 行为一致，未扩大）。
