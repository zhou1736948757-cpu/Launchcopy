# PROVENANCE / COMPONENTS.md

- **日期**：2026-08-28（创建）；2026-08-28（T-reviewer PASS 后回填）
- **阶段**：Phase 1A（PagingPrototype）
- **用途**：组件清单与来源归属。规格版本/hash、实现者访问声明、来源审查结果、验证证据已回填。

## 组件清单

| 组件 | 目录 | 职责 | 独占实现者 | 需求来源 | 状态 |
|---|---|---|---|---|---|
| PagingCore | `Sources/PagingCore/` | 纯逻辑状态机、页索引/边界、gesture session、target page policy、interruption、transition identity、stale rejection、resize/pageCount rebasing、cancel/teardown | Worker B | Prompt §3.F/G, §6 Step 2, §7.1–7.2 | **DELIVERED + VERIFIED** |
| PagingTelemetry | `Sources/PagingTelemetry/` | 可开关 JSONL telemetry、run/gesture/transition ID、事件与性能指标 | Worker C | Prompt §5, §6 Step 5, §10 | **DELIVERED + VERIFIED** |
| PagingUI | `Sources/PagingUI/` | AppKit 视图、页面承载（live views）、触控板输入、settle 动画、中断、Reduce Motion、页面内容正确性 | Worker D | Prompt §3.B/C/D/E/F/H/I/J, §6 Step 3-4 | **DELIVERED + VERIFIED** |
| PagingPrototypeApp | `Sources/PagingPrototypeApp/` | App 入口、窗口、命令行参数解析、退出/重开/resize | Worker D | Prompt §3.A, §10 | **DELIVERED + VERIFIED** |
| PagingCoreTests | `Tests/PagingCoreTests/` | Core 单元测试 + 可重复事件序列测试（51 用例） | Worker B | Prompt §7.1–7.2 | **DELIVERED + VERIFIED** |
| PagingTelemetryTests | `Tests/PagingTelemetryTests/` | Telemetry 单元测试（33 用例） | Worker C | Prompt §7.4 | **DELIVERED + VERIFIED** |
| PagingUITests | `Tests/PagingUITests/` | UI 正确性测试 + 自动化性能边界测试（51 用例） | Worker D | Prompt §7.3–7.4 | **DELIVERED + VERIFIED** |
| Docs/ | `Docs/` | 规格、ADR、参数说明、验证计划/结果、实现日志 | Main | Prompt §5, §13 | **COMPLETE** |
| PROVENANCE/ | `PROVENANCE/` | 访问声明、组件清单、污染日志 | Main | Prompt §1.2, §17 | **COMPLETE** |

## 回填项

- **规格基线**：`Docs/PHASE1_SPEC.md` v1.0，基于 PHASE1_PAGING_PROTOTYPE_PROMPT.md（SHA-256 `06594a34…bf16e4`）。
- **实现者访问声明**：全部登记于 `PROVENANCE/ACCESS_DECLARATION.md`（Worker B/C/D/Explorer/Reviewer = NO_PRIOR_EXPOSURE 亲笔；Main/Chief = PRIOR_EXPOSURE 仅治理文档）。
- **来源审查结果**：Reviewer E 独立审查 **PASS**（`Workflow/reviews/T-reviewer-r1.md`）：命名中立、结构无未解释一一映射、8 类扫描复验 0 泄漏（命中均为规格要求禁止性说明/工程自身路径）。
- **验证证据**：清洁构建 Debug/Release exit 0；`swift test` 140 tests 0 failures；产物 hash 见 `Docs/IMPLEMENTATION_LOG.md` Step 7；性能 baseline 见 Step 6（自动可测指标全部达标）。
- **污染日志**：`PROVENANCE/CONTAMINATION_LOG.md` —— 无事件。

## 来源纪律摘要

- 所有组件：需求驱动、全新代码、中性命名；禁用 REVERSE_ENGINEERING_COPY / OLD_SOURCE_TRANSLATION / UNKNOWN_ORIGIN 参数来源。
- 实现 worker：fresh context，不继承含逆向材料的旧会话上下文（见 ACCESS_DECLARATION.md §3）。
- 来源扫描 = 泄漏预警，不是原创性或法律证明（Reviewer 报告同样声明此局限）。

## 更新记录

| 日期 | 更新 | 执行人 |
|---|---|---|
| 2026-08-28 | 创建骨架 | Main |
| 2026-08-28 | 全部组件回填 DELIVERED + VERIFIED（T-reviewer PASS 后） | Main |

## Phase 1B 组件（2026-08-28）

| 组件 | 内容 | 测试 | 交付状态 |
|---|---|---|---|
| AppCatalogCore | AppID/AppRecord/CatalogSnapshot/CatalogBuilder/CatalogPlanner/SnapshotGate/CatalogDiff/CatalogFixture（Foundation-only domain） | 56 | DELIVERED + VERIFIED（414/414 全绿） |
| MacAppCatalog | 4 受限根枚举/ScanConfiguration/URLNormalizer/ScanTask/CatalogRepository actor（revision 单调 + latest-wins） | 45 | DELIVERED + VERIFIED |
| AppIconPipeline | IconKey/有界缓存/IconLoading+SystemIconLoader/in-flight 合并/取消/shutdown 零回调/stats 无隐私 | 23 | DELIVERED + VERIFIED |
| PagingUI seam | PagingPageContentProviding/PagingPageRendering/NeutralPageRenderer/pin+latest-wins/refreshPresentation/reuseGeneration | 93（78 既有 + 15） | DELIVERED + VERIFIED |
| AppGridUI | ItemBindingToken 七字段/AppGridUIPageContentProvider/五态 UI/RefreshController/AppGridCellView+PageView | 49 | DELIVERED + VERIFIED |
| PagingTelemetry 扩展 | 7 可选扩展字段/容量上界/四层红线测试/PRIVACY_DATA_MAP.md | 54（33 既有 + 21） | DELIVERED + VERIFIED |
| PagingPrototypeApp 装配 | AppCatalogAssembly/AppLaunchController/FrameDriverExperiment/CLI 3 新参数 | 24 新增 | DELIVERED + VERIFIED |

- **规格基线**：`Docs/PHASE1B_SPEC.md`（基于 PHASE1B_REAL_APP_CONTENT_PROMPT.md，SHA-256 `2b164b3f…e83b3`）。
- **测试总数**：**414 tests, 0 failures**（Gate 0 冻结 181 基线 + Phase 1B 233 新增）。
- **审查**：Reviewer 三份独立 review 全 PASS（§14.A 源码/架构、§14.B 隐私、§14.C 来源/资源=泄漏预警）；§14.D 物理证据 review PASS（t18）。
- **调参轮**（worker-pagingcore2，NO_PRIOR_EXPOSURE）：0.46/0.40 → 0.45/0.38（t16）→ 0.43/0.36（t17，用户确认 OK 4/4/4/4/3.6）→ 0.42/0.35（t22，用户确认"挺好的"）；结果文件 `Workflow/results/T-worker-b-thresh45.md` / `T-worker-b-thresh43.md` / `T-worker-b-thresh42.md`。
- **后续优化轮**（worker-icondim / worker-frameprofile，NO_PRIOR_EXPOSURE）：图标尺寸上限 256×256（t19，用户指示）；帧路径耗时探针（t20）+ runloop 级主线程探针（t21，用户确认"去深挖"）；结果文件 `T-worker-b-icondim.md` / `T-worker-b-frameprofile.md` / `T-worker-b-runloopprofile.md`。
- **污染日志**：CONTAMINATION_LOG.md 无事件。

## 更新记录（Phase 1B）

| 日期 | 更新 | 执行人 |
|---|---|---|
| 2026-08-28 | Phase 1B 组件行追加 + 测试数修正（51→70/78、基线 181→414）+ 审查结果回填（Reviewer §14.C MINOR-3） | Main |
| 2026-08-28 | 调参轮回填（t16/t17：0.45/0.38 → 0.43/0.36）+ Reviewer D PASS | Main |
| 2026-08-29 | 后续优化轮回填（t19 图标 256 / t20 帧探针 / t21 runloop 探针 / t22 阈值 0.42/0.35）+ 用户帧驱动重构说明 | Main |

## Phase 1D 组件（搜索）

- **规格基线**：`Docs/PHASE1D_SPEC.md`（基于 PHASE1D_SEARCH_PROMPT.md，SHA-256 `78a0e5acdc4f082f1f274a94cd11ea93200a150c1c20d94fd87b279e56c00154`）。
- **架构**：`Docs/ADR-007-SEARCH-PRESENTATION.md`（Accepted，10 决策）。
- **新增源文件**：`Sources/AppGridUI/AppSearchQuery.swift`、`AppSearchMatcher.swift`、`AppSearchResultSet.swift`（含 `AppSearchGeneration`）、`AppGridSearchPresentationController.swift`；`Sources/PagingPrototypeApp/AppSearchFieldView.swift`、`AppSearchController.swift`。
- **修改源文件**：`Sources/AppGridUI/AppGridUIPageContentProvider.swift`、`AppGridUIState.swift`；`Sources/PagingUI/PagingSurface.swift`（同 revision 重载 seam）；`Sources/PagingPrototypeApp/AppDelegate.swift`、`AppCatalogAssembly.swift`、`KeyboardFocusController.swift`。
- **新增测试**：`Tests/AppGridUITests/AppSearchQueryTests.swift`(9)、`AppSearchMatcherTests.swift`(15)、`AppSearchResultSetTests.swift`(9)、`AppGridUIPageContentProviderSearchPresentationTests.swift`(11)、`AppGridSearchPresentationControllerTests.swift`(9)；`Tests/PagingUITests/PagingSurfaceSearchReloadTests.swift`(14)、`AppSearchControllerTests.swift`(11)、`AppSearchResponderTests.swift`(5)、`AppSearchIntegrationTests.swift`(8)；`BlankClickToQuitTests.swift` +3。
- **测试总数**：**620 tests, 0 failures**（Phase 1C 526 基线 + Phase 1D 94 新增）。
- **审查**：Reviewer T-1D-A..E 各 r1 全 PASS（独立只读,各自复跑 swift test + debug/release）。
- **禁止树**：`Sources/PagingCore/`、`Sources/MacAppCatalog/`、`Package.swift`、`AppLaunchController.swift` 未改（mtime + hash 核验）。
- **污染日志**：CONTAMINATION_LOG.md 无事件。

## 更新记录（Phase 1D）

| 日期 | 更新 | 执行人 |
|---|---|---|
| 2026-08-30 | Phase 1D 组件行追加 + 测试数 526→620 + 审查结果回填（T-1D-A..E r1 全 PASS）+ 禁止树核验 | Main |

## Phase 1E 组件（文件夹基础垂直切片）

- **新增源文件**：`Sources/AppGridUI/FolderDomain.swift`、`FolderLabFixture.swift`、`FolderKeyboardLogic.swift`、`FolderOpenState.swift`、`FolderOverlayView.swift`；`Sources/PagingPrototypeApp/FolderTitleEditor.swift`。
- **修改源文件**：`Sources/AppGridUI/AppGridFocusIdentity.swift`、`AppGridUIPageContentProvider.swift`、`AppGridSearchPresentationController.swift`（死回调移除）、`AppGridCellView.swift`、`AppGridPageView.swift`；`Sources/PagingPrototypeApp/KeyboardFocusController.swift`、`AppSearchController.swift`、`AppDelegate.swift`、`AppCatalogAssembly.swift`、`AppArguments.swift`。
- **新增测试**：`Tests/AppGridUITests/FolderDomainTests.swift`(15)、`FolderLabFixtureTests.swift`(5)、`AppGridFocusIdentityGeneralizationTests.swift`(7)、`TopLevelCompositionTests.swift`(15)、`FolderSearchFlatteningTests.swift`(5)、`FolderCellTests.swift`(5)、`FolderOverlayTests.swift`(11)、`FolderInnerPagingTests.swift`(4)、`FolderOpenStateTests.swift`(9)、`FolderKeyboardLogicTests.swift`(32)；`Tests/PagingUITests/FolderIntegrationTests.swift`(12)；`AppGridUIPageContentProviderTests.swift` +2（H2）。
- **测试总数**：**789 tests, 0 failures**（Phase 1D 631 基线 + Phase 1E 125 新增 + 修复波次 33：inner-nav 16 / focus-layout 10 / keyboard-return 3 / typewriter-outer 2 / typewriter-inner 2；Gate 0 复跑确认 2026-08-30）。
- **审查**：Reviewer T-1E-H2-repair-r1 / T-1E-A-r1 / T-1E-B-r1 / T-1E-C-r1 / T-1E-D-r1(1 MAJOR) / T-1E-D-repair-r2 / T-1E-E-r1 全 PASS（独立只读，各自复跑 swift test + debug/release）。
- **禁止树**：`Sources/PagingCore/`、`Sources/AppCatalogCore/`、`Sources/MacAppCatalog/`、`Sources/AppIconPipeline/`、`Sources/PagingTelemetry/`、`Sources/PagingUI/`、`Package.swift`、`AppLaunchController.swift` 未改（mtime + hash 核验）。
- **污染日志**：CONTAMINATION_LOG.md 无事件。

## 更新记录（Phase 1E）

| 日期 | 更新 | 执行人 |
|---|---|---|
| 2026-08-30 | Phase 1E 组件行追加 + 测试数 631→756 + 审查结果回填（T-1E-A..E + H2 + D-repair 全 PASS）+ 禁止树核验 | Main |
