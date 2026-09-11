# T-1D-layout-centering-repair — 搜索结果后内容面板水平居中修复

**Status:** 修复完成，验证全绿。
**Task owner:** Worker (chef-worker-reviewer-workflow v1.4.1, PagingPrototype)
**Evidence basis:** 用户真实 GUI 截图 sha256:316aa9bb02ad4fcca3462a5cf4822f905e673f20f0030ad53d73e6528581c658
（vision 确认 content 偏左、right 大空白、仅 1 个图标可见；搜索匹配本身正确，z→ZCode，header "Page 1 of 1"）。

---

## 1. 根因分析

**根因：`AppGridPageView` 的网格布局对部分结果页不做水平居中，cell 恒从网格区域左缘锚定；当搜索把结果压到不足一整行（页）时，内容被挤到窗口左侧、右侧大片空白。**

### 关键证据（file:line）

- `Sources/AppGridUI/AppGridPageView.swift` 原 `layout()`（改造前 246-252）：
  ```swift
  let x = area.minX + CGFloat(column) * (tileWidth + spacing)
  ```
  每个 cell 的 x 都从 `area.minX`（网格区域左缘，`inset=24`，见 AppGridPageView.swift:236-243）起按列偏移。整页 35 项（5 列 × 7 行）时，每行 5 格铺满 `area.width`，视觉上"铺满/居中"（Phase 1C 用户确认全目录 4 页网格正常）；但**部分页**（如搜索 `z` 后的单结果页）只有 1 个 cell，被放在 `x ≈ 24` 的最左下角，右侧整片空白 —— 即截图所见"内容被挤到左侧、右侧大空白、仅 1 个图标可见"。

- 为何与 `pageCount` 变化 4→1 强相关（任务描述）：
  搜索走 ADR-007 呈现切片（同 revision 重载）：`AppDelegate` 的
  `presentation.onSearchResultCommitted` → `PagingSurface.reloadCurrentPresentation()` →
  `applySameRevisionReload()`（PagingSurface.swift:659-667，做 `surfaceGeneration &+= 1`、
  `core.setPageCount`、`relayoutPages()`、`refreshLiveHostContent`）。`relayoutPages()`
  （PagingSurface.swift:740-820）始终把每个 live host 的 frame 设成全窗口宽
  （`width = bounds.width`，host.frame = `CGRect(x: index*width, y: 0, width: width, height: height)`，
  `containerView` 随 `visualOffset` 平移，page0 offset0 即铺满窗口）—— **page/容器级几何在
  pageCount 变化前后都保持全窗口宽，并不丢居中**。真正改变视觉的是
  `AppGridUIPageContentProvider.servedPageCount`（AppGridUIPageContentProvider.swift:56-60）
  → presentationRecords 从 35 项降到 1 项，页面渲染的 **cell 数从 35 降到 1**，
  触发了"部分行不居中"的分支。故根因是 AppGridPageView（AppGridUI 呈现层）的单元格布局，
  而不是 PagingSurface/page-container 几何。

### 验证过的无关路径（排除）
- `PagingSurface` 容器几何：`containerView.frame`/live host frame 恒用当前 `bounds.width`，
  page0 铺满窗口，pageCount 变化不改变容器中心 → 无需改动 PagingSurface。
- `AppGridUIPageContentProvider`：servedPageCount/presentationRecords 驱动正确（4→1 页数合法），
  非缺陷源。
- 搜索 field overlay（`searchFieldFrame` 顶中、`[.minXMargin,.maxXMargin,.minYMargin]`
  autoresizing，AppDelegate.swift:425-431 / 196-202）：仅叠加在 contentView 上，不挤压/平移
  surface 或页面容器，与缺陷无关。

## 2. 改动

### 修复（allowed: `Sources/AppGridUI/`）
- `Sources/AppGridUI/AppGridPageView.swift`（`layout()`，改造后 246-262；居中逻辑 247-261）：
  - 每行按实际 cell 数计算行内容宽 `rowContentWidth`，并令行起始
    `rowStartX = area.minX + (area.width - rowContentWidth)/2`，cell 从 `rowStartX` 起排列。
  - 满行（`colsInThisRow == columns`，即全页 35 项）时
    `rowContentWidth == area.width` → `rowStartX == area.minX`，几何与改造前**逐位一致（零回归）**。
  - 部分行（搜索单结果/不足整页的末行）整行水平居中于网格区域（= 页 = 窗口宽）
    → 单结果 cell 中心 == 页中心 == 宿主/窗口中心。

### 新增测试（allowed: `Tests/AppGridUITests/`）
- `Tests/AppGridUITests/AppGridPageViewTests.swift`（新增 2 个，行 353 / 386）：
  1. `testSameRevisionReloadPartialResultStaysHorizontallyCentered`（行 353）——
     先渲染全目录页（35 项，pageCount 4）断言左锚原点无回归（cell0.minX == 24），
     再**同 revision 重载**渲染单结果（pageCount 1）断言 `cell.frame.midX == page.bounds.midX`
     （== 窗口/宿主中心）。
  2. `testPartialRowCenteredForMultiResultLastRow`（行 386）——7 项（末行 2 项）时末行整体居中，
     满行仍左锚（cell0.minX == 24，回归守卫）。

### 未改动（allowed 但非必要）
- `Sources/PagingUI/PagingSurface.swift`、`Sources/PagingPrototypeApp/AppDelegate.swift`、
  `Sources/PagingPrototypeApp/AppCatalogAssembly.swift` —— 调查确认无需改动（见根因）。

## 3. 测试计数

- 新增：**2**（AppGridPageViewTests 内）
- 全量 `swift test`：**622 tests，0 failures / 0 unexpected**（620 基线 + 2 新增）
- 新增定向运行 `swift test --filter AppGridPageViewTests`：12 tests, 0 failures（含新增 2）

## 4. 构建验证

| 步骤 | 命令 | 结果 |
|---|---|---|
| 新增定向测试 | `swift test --filter 'AppGridPageViewTests'` | exit 0，12/12 通过 |
| 全量测试 | `swift test` | exit 0，**622 tests，0 failures** |
| Debug 构建 | `swift build -c debug` | exit 0 |
| Release 构建 | `swift build -c release` | exit 0 |

Gate 判定：**exit_code == 0 且 executed_tests（622）> 0** → 通过（非 INVALID_TEST_EXECUTION）。

## 5. 禁止树核验（FROZEN 未触碰）

改动的文件仅：`Sources/AppGridUI/AppGridPageView.swift`、`Tests/AppGridUITests/AppGridPageViewTests.swift`、
（结果文件）本文件。禁止树的 mtime 均在改动之前（昨日 8 月 29），本次未触碰：

| 禁止树 | 状态 |
|---|---|
| `Sources/PagingCore/` | 未改动（mtime 全为昨日/更早） |
| `Sources/MacAppCatalog/` | 未改动 |
| `Package.swift` | 未改动（mtime 昨日 20:42:55） |
| `Sources/PagingPrototypeApp/AppLaunchController.swift` | 未改动（mtime 昨日 21:46:54） |

> 注：本仓库文件全为 untracked（无 git 跟踪基线），故核验以"仅改两个允许文件的编辑记录 + 禁止树 mtime 早于本次会话编辑时间"为凭证；本次会话没有任何写禁止树的文件写操作。

## 6. 回归与红线核验

- 搜索匹配 / 键盘导航 / 空白单击退出 / 启动路径：均未触碰相关代码（本次仅改 AppGridPageView 单元格 x 布局）。
- 未读禁止来源（BuhoReverseNotes / LaunchBetter / 2026-08-25-buho-launchpad-reverse）。
- 无 git commit/push/tag/reset/clean。
- 无全局 NSEvent monitor / Accessibility / 同步 I/O；Timer tolerance 8.333ms 未动；
  三诊断 token 未改；未宣称修 hitch。
- 隐私：无 query/结果名入 telemetry/log/stdout；无 PagingTelemetry schema 变更。
- App 未启动、未终止（遵守"勿 launch/kill 正在运行的既有构建"）。
