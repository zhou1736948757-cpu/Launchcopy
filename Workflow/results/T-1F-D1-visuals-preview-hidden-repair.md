# T-1F-D1-visuals-preview-hidden-repair: DragUIVisuals 初始隐藏修复

Status: PASS
Phase: 1F
Depends: T-1F-D1-test-repair（已 PASS，997 执行 1 失败——本包消除该失败）
Created: 2026-08-31（Main）

## 计划

1. 只读确认根因（已读本包 + T-1F-D1-test-repair.md + DragUIVisuals.swift 全文）：
   - :22-26 四个指示视图 `NSView()`，`isHidden` 默认 false。
   - :31 `isPreviewVisible` 创建即 true；:186-189 `hide(_:)` 助手存在但 `configureViews()`（:191）从未调用。
2. 修改 `Sources/AppGridUI/DragUI/DragUIVisuals.swift`：`configureViews()` 末尾调用
   `hide(previewView, insertionIndicator, folderHighlight, createFolderIndicator)`。
   不改 show/attach/clearAll/teardown 及其他任何逻辑。
3. 串行验证：
   - `swift build -c debug` → exit 0
   - `swift test` 全量 → 期望 997 项 0 失败（`${PIPESTATUS[0]}` 取退出码）
   - `swift build -c release` → exit 0
4. 更新本文件为 PASS，附文件 mtime、验证证据、偏差说明。

## 执行记录

### 变更（1 文件）

`Sources/AppGridUI/DragUI/DragUIVisuals.swift`（mtime 2026-08-31 09:46:19）：
- `configureViews()` 末尾（`createFolderIndicator.addSubview(createFolderBadge)` 之后）新增一行：
  `hide(previewView, insertionIndicator, folderHighlight, createFolderIndicator)`，
  附一行注释说明 NSView isHidden 默认 false、可观测状态须从 false 起步。
- 复用既有 :187 `hide(_ views: NSView...)` 助手；show/attach/clearAll/teardown/updateIntent
  及其他逻辑零改动。

### 验证证据（串行）

1. `swift build -c debug` → exit 0（Build complete! 1.11s）。
2. `swift test` 全量 → **997 tests, 0 failures (0 unexpected)**，exit 0
   （`Executed 997 tests, with 0 failures (0 unexpected) in 13.144 (13.182) seconds`；
   含 testSubThresholdMoveStaysPressedThenClick 通过，最后失败已消除）。
3. `swift build -c release` → exit 0（Build complete! 4.07s）。

### 偏差

- 无功能偏差。仅两处既有编译警告（未改动、非本包引入）：
  - DragUIVisuals.swift:47 `guard let host` 值未使用（既有代码）。
  - FolderOverlayView.swift:276 `index` 未使用（禁止写文件，未触碰）。

### 验收对照

- ✅ 997/0 全绿；debug/release 双构建 exit 0。
- ✅ isPreviewVisible 初始为 false（configureViews 末尾统一 hide 四视图）；
  showPreview 后 true、clearAll/teardown 后 false 由既有测试覆盖（全绿证实）。
