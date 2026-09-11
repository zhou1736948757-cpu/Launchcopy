# Review r1 — T-1D-layout-centering-repair

- **Task:** T-1D-layout-centering-repair — 搜索后内容面板水平居中丢失修复
- **Reviewer:** Independent Reviewer (chef-worker-reviewer-workflow, PagingPrototype)
- **Date:** 2026-08-30 11:45 JST
- **Scope:** 独立复核 worker 声明的根因、修复、测试与红线约束；不编辑除本报告外的任何文件（READ-ONLY）。
- **Method:** 阅读任务 spec + worker 结果；阅读 `Sources/AppGridUI/AppGridPageView.swift` layout 代码独立验算几何；阅读新增测试；`git status` + 禁止树 mtime 核验；串行运行 `swift test`（filter 全量）与 debug/release 构建；SwiftPM `.build` lock 冲突最多重试 3 次。

---

## 独立验证结果

| 步骤 | 命令 | 独立结果 |
|---|---|---|
| 新增定向测试 | `swift test --filter 'AppGridPageViewTests'` | exit 0，**12/12 通过，0 failures** |
| 全量测试 | `swift test` | exit 0，**622 tests（620 基线 + 2 新增），0 failures / 0 unexpected** |
| Debug 构建 | `swift build -c debug` | **exit 0** |
| Release 构建 | `swift build -c release` | **exit 0** |

- 定向运行输出确认执行 12 tests、0 failures（Attemp 1 EC=0，无 lock contention）。
- 全量运行输出确认 `Executed 622 tests, with 0 failures (0 unexpected)`；三诊断 PROBE 输出正常，未宣称修 hitch。
- 与 worker 声明的计数完全一致（12/0、622/0、双构建 exit 0）。

## 几何独立验算（Sources/AppGridUI/AppGridPageView.swift)

以测试宽度 `pageWidth = 1000`（`bounds.width = 1000`）验算：

- `inset = 24`，`area = CGRect(x:24, y:24, width:952, height:···)`；`tileWidth = (952 − 4×16)/5 = 177.6`。
- **满行（5 列，35 项全页）**：`colsInThisRow = 5`，`rowContentWidth = 5×177.6 + 4×16 = 952 == area.width` → `rowStartX = 24 + (952−952)/2 = 24 == area.minX`。cell0.minX = 24。→ 满行几何与旧左锚布局**逐位一致，零回归**；测试 `XCTAssertEqual(fullFirst.frame.minX, 24)` 成立。
- **单结果（1 项）**：`colsInThisRow = 1`，`rowContentWidth = 177.6`，`rowStartX = 24 + (952−177.6)/2 = 411.2`；`cell.frame.midX = 411.2 + 88.8 = 500.0 == page.bounds.midX (500)`。→ 单结果 cell 中心 == 页中心（页 = 全窗口宽）。测试 `XCTAssertEqual(cell.frame.midX, page.bounds.midX, accuracy:0.5)` 成立。
- **7 项末行（2 项）**：第 0 行满 5 项左锚 `cell(at:0).minX = 24`；末行 `colsInThisRow = min(5, 7−5) = 2`，`rowContentWidth = 2×177.6+16 = 371.2`，`rowStartX = 24+(952−371.2)/2 = 314.4`；`cell(at:5).minX = 314.4`，`cell(at:6).maxX = 685.6`，行几何中心 `314.4 + 371.2/2 = 500 == page.bounds.midX`。测试 `XCTAssertEqual(lastRowFirst.frame.minX + rowSpan/2, page.bounds.midX, accuracy:0.5)` 成立。

**Fix-quality 确认（4c）：** layout 数学仅依赖 `cells.count`、静态 `columns`/`spacing`/`tileWidth`、`area`（bounds 派生）——**不引用 pageCount、provider 搜索态或 presentationRecords**（AppGridPageView.swift:247-261）。同 revision 重载路径下仅 cell 数变化即改变居中行为，机制与根因一致。

## 根因复核

Worker 根因：cell 恒从网格区域左缘 `x = area.minX + column×(tileWidth+spacing)` 锚定；全页铺满宽时无感，部分页（1 项/末行不足）被挤左。现代码（AppGridPageView.swift:254-257）确证该机制：每行按实际 cell 数 `colsInThisRow`、`rowContentWidth`、`rowStartX` 居中。`PagingSurface`/host 几何恒全窗口（任务文件与 worker 论证一致），缺陷确在 AppGridUI 呈现层 cell 布局，根因认定成立。仓库全为 untracked、无 git 基线，无法 diff 原代码逐字核对"改造前 246-252"，但当前代码 + 测试守卫（满行左锚 24）已足以确认修复语义正确。（见 MINOR-1。）

## Findings

### BLOCKER
- 无。

### MAJOR
- 无。

### MINOR
- **MINOR-1（证据局限，非缺陷）** 仓库无 git 跟踪基线（`git status` 全为 `??` untracked），无法提供字节级"改造前 vs 后" diff。worker 声称的"满行 BYTE-IDENTICAL 零回归"无法用 git 独立取证；但可由当前几何算式 + 满行左锚回归守卫（AppGridPageViewTests.swift:370,400）独立还原，且实测通过。结论不受影响。

### QUESTION
- **Q-1** 新增测试（AppGridPageViewTests.swift:353,386）均以固定宽度 `1000` 且 `page.layout()` 手动触发。若 host 实际宽度可变（如响应式窗口），居中仍成立（公式不依赖具体宽度），但未覆盖极端窄宽（`area.width ≤ 0` guard 分支 AppGridPageView.swift:245 已安全返回，无断言）。非阻塞；建议后续可选补一行极端尺寸断言提升覆盖。

### 红线 / 范围 / 隐私核验
- **禁止树未触碰（可取证）**：`PagingCore/PagingParameters.swift` mtime **2026-08-29 21:16:32**、`Package.swift` **08-28 20:42:55**、`AppLaunchController.swift` **08-28 21:46:54**、`MacAppCatalog` 目录 **08-28 21:01:55** —— 全部早于本次改动（允许文件编辑于 08-30 11:42–11:44）。`PagingParameters.swift` 的 mtime 早于本次会话、且非本任务产物，符合"并行 T-1D-velocity700-tuning 并发编辑"的声明；本任务未触碰。
- **本次改动仅两个允许文件**：`Sources/AppGridUI/AppGridPageView.swift`（layout 246-261 行内居中）、`Tests/AppGridUITests/AppGridPageViewTests.swift`（+2 测试，行 353/386），加结果/报告文件。
- 允许但未改动：`PagingSurface.swift`、`AppDelegate.swift`、`AppCatalogAssembly.swift` —— 与根因（缺陷在 AppGridUI 呈现层）一致，合理。
- **隐私**：改动仅在 layout cell x 数学（AppGridPageView.swift:254-257）；文件全量阅读未见任何 telemetry/log/stdout 新增，无 query/结果名入日志，无 schema 变更。
- **无 git ops / 无全局 NSEvent monitor / 无 Accessibility / 无同步 I/O**：本任务改动不含此类代码；Timer tolerance 8.333ms、三诊断 token 未动；未宣称修 hitch。

## 结论

新增 2 测试断言（同 revision 重载 pageCount 缩小后单元格水平居中 + 部分行末行居中 + 满行左锚零回归守卫）与任务 criteria 1/2/4 对齐；几何独立验算完全一致；全量 622 tests 0 failures、双构建 exit 0；禁止树未触碰、无隐私/红线违规。修复正确、完整、无回归。

**VERDICT: PASS**
