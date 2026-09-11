# Phase 1D 最终报告 — PagingPrototype 本地应用名搜索（搜索域 / 同 revision 重载 / 键盘与启动集成）

- **日期**：2026-08-30
- **范围**：T-1D-A（搜索域）/ T-1D-B（provider/presentation）/ T-1D-C（PagingUI 同 revision 重载 seam）/ T-1D-D（AppKit 搜索/responder）/ T-1D-E（AppDelegate/装配/空白单击/启动集成）全部完成并通过 Main 最终验证（**620 tests 全绿**）；真实全屏 GUI + 物理键盘搜索门与空白单击回归门待用户执行（`NOT_RUN`）
- **报告格式**：对齐 PHASE1A/1B/1C_REPORT（A 完成内容 / B 验证表格 / C 诚实边界 / D 唯一建议）
- **工作流**：chef-worker-reviewer-workflow v1.4.1,严格 DAG（A‖C → B → D → E 串行）,独立 Reviewer 逐任务 PASS 门禁（T-1D-A..E 各 r1 全 PASS）

---

## A. 完成内容

在既有的独立 macOS AppKit 分页原型上增量实现本地应用名搜索（能力匹配、非复制任何旧项目;未读取 BuhoReverseNotes / LaunchBetter / 2026-08-25-buho-launchpad-reverse）:

| 任务 | 内容 | 验证 |
|---|---|---|
| T-1D-A | 搜索域:`AppSearchQuery`(raw + 可注入 Locale;trim→case/diacritic/width folding 归一)/ `AppSearchMatcher`(blank→全量;折叠 displayName 字面子串;绝不匹配 bundleID/path/URL/AppID/icon 元数据;无拼音/模糊/排序)/ `AppSearchResultSet`(`AppSearchGeneration` 单调 latest-wins token,独立于 CatalogRevision;baseCatalogRevision + queryGeneration + records 基序 + resultCount + isEmpty + pageCount(itemsPerPage:) 镜像 CatalogPlanner + isCurrent(latestGeneration:latestRevision:);无 debug description 反吐 AppID) | 33 tests PASSED(Query 9 + Matcher 15 + ResultSet 9) |
| T-1D-C | PagingUI 同 revision 重载 seam:`PagingSurface` 新增 `pendingSameRevisionReload`(独立于 pendingLatestSnapshot 目录 revision pending);`reloadCurrentPresentation()`(idle/cancelled→立即,tracking/settling/interrupted→仅置 pending,latest-wins 幂等);`applySameRevisionReload()`(`surfaceGeneration &+= 1` 字段-7 门控、合法 `core.setPageCount`、显式 `relayoutPages()`、`refreshLiveHostContent(effectiveRevisionForPass())` 同 servedRevision——绝不 mint/forge CatalogRevision);`endInteraction()`(目录 revision 优先并取代同 revision 重载,否则应用 pending 同 revision 重载);`teardown()` 清 pending→零写回 | 14 tests PASSED(PagingSurfaceSearchReloadTests) |
| T-1D-B | provider/presentation:`AppGridUIPageContentProvider` 扩展(baseSnapshot + presentationRecords + activeQuery + pendingSearchResult;servedPageCount 由 presentationRecords 推导,0 结果=0 页;content(for:) 只切 committed;applyPending 新 base 提交时复位 presentationRecords;anchorCandidate/pageIndex(of:) 用 presentationRecords;stageSearchResult/discardPendingSearchResult/commitPendingSearchResult(query:) 双轴 latest-wins)/ `AppGridSearchPresentationController`(@MainActor:latestGeneration + currentQuery;updateQuery 递增 generation + 过滤 + stage;receive 转发 pendingCatalogSnapshot;applyPendingAtIdleBoundary 在 idle 边界提交,目录刷新优先→新 base 重跑 query→提交;uiState 派生 loading/empty/noResults/ready;onPresentationUpdate/onSearchResultCommitted/onStateChange 回调)/ `AppGridUIState` 增 `.noResults` 中性态 | 20 tests PASSED(Provider 11 + Presentation 9) |
| T-1D-D | AppKit 搜索/responder:`AppSearchFieldView`(中性 NSSearchField,可访问标签 'Search applications',`static isSearchFieldOrSubview(_:)` 空白单击交互区分类)/ `AppSearchController`(Command-F→field first responder + 清网格焦点视觉;实时输入→presentation.updateQuery + idle 提交;Escape 非空清 query 留 field / 空退出恢复 KeyboardFocusController;↓/Return/Enter 转移焦点到当前页首个有效结果,首次不启动;网格 Return/Enter 经既有 onActivate 启动;Tab 不吞;无 committed 结果或 pending generation 不启动旧结果;F3 follow-up 经 NSWindow.didBecomeKeyNotification 按状态重建 first responder;`commitPendingAtIdleBoundary()` 公开 seam)/ `KeyboardFocusController` 最小扩展(onSearchShortcut + Command-F + clearFocusForSearch + setFocus(to:)) | 16 tests PASSED(Controller 11 + Responder 5) |
| T-1D-E | AppDelegate/装配/空白单击/启动集成:6 项 handoff 全接线(onSearchShortcut→search.activateSearch;search.field 兄弟 overlay 非 page 容器内;install/teardown;blankClickResolvesToCell 经 isSearchFieldOrSubview 扩展交互区;idle 边界 search-first 提交;onSearchResultCommitted→reloadCurrentPresentation);启动仍复用 `AppLaunchController.handleCell` 统一校验,无并行路径 | 8 tests PASSED(AppSearchIntegration) + BlankClickToQuit 9/0(6+3) |

**新增/修改源文件**(禁止树 `Sources/PagingCore/`、`Sources/MacAppCatalog/`、`Package.swift`、`AppLaunchController.swift` 未动;`Sources/PagingUI/PagingSurface.swift` 与 `Sources/AppGridUI/*` 属本阶段允许写范围):
- `Sources/AppGridUI/AppSearchQuery.swift`(NEW,1906B)
- `Sources/AppGridUI/AppSearchMatcher.swift`(NEW,1747B)
- `Sources/AppGridUI/AppSearchResultSet.swift`(NEW,3413B,含 `AppSearchGeneration`)
- `Sources/AppGridUI/AppGridUIPageContentProvider.swift`(MODIFIED,baseSnapshot/presentationRecords/搜索提交)
- `Sources/AppGridUI/AppGridSearchPresentationController.swift`(NEW,5711B)
- `Sources/AppGridUI/AppGridUIState.swift`(MODIFIED,增 `.noResults`)
- `Sources/PagingUI/PagingSurface.swift`(MODIFIED,同 revision 重载 seam)
- `Sources/PagingPrototypeApp/AppSearchFieldView.swift`(NEW,2240B)
- `Sources/PagingPrototypeApp/AppSearchController.swift`(NEW,9766B)
- `Sources/PagingPrototypeApp/AppDelegate.swift`(MODIFIED,搜索接线 + 空白单击交互区)
- `Sources/PagingPrototypeApp/AppCatalogAssembly.swift`(MODIFIED,搜索装配)
- `Sources/PagingPrototypeApp/KeyboardFocusController.swift`(MODIFIED,onSearchShortcut/Command-F/clearFocusForSearch/setFocus)

**新增测试文件**:`Tests/AppGridUITests/AppSearchQueryTests.swift`(9)、`AppSearchMatcherTests.swift`(15)、`AppSearchResultSetTests.swift`(9)、`AppGridUIPageContentProviderSearchPresentationTests.swift`(11)、`AppGridSearchPresentationControllerTests.swift`(9)、`Tests/PagingUITests/PagingSurfaceSearchReloadTests.swift`(14)、`AppSearchControllerTests.swift`(11)、`AppSearchResponderTests.swift`(5)、`AppSearchIntegrationTests.swift`(8);`BlankClickToQuitTests.swift` 增 3。

文档:`Docs/ADR-007-SEARCH-PRESENTATION.md`(定稿 Accepted,10 决策),`Docs/PHASE1D_SPEC.md`,`Docs/PHASE1D_VALIDATION_PLAN.md`,`Docs/PHASE1D_REPORT.md`(本报告),`Docs/PHASE1D_SEARCH_PROMPT.md`。

## B. 验证表格

| 验证项 | 结果 | 证据 |
|---|---|---|
| AUTOMATED_TESTS | **PASS** | `swift test` **620 tests, 0 failures**,exit 0(本会话独立复跑确认;T-1D-A 33 + T-1D-C 14 + T-1D-B 20 + T-1D-D 16 + T-1D-E 8 + BlankClickToQuit 3 = 94 新增,526→620) |
| BUILD_DEBUG | **PASS** | `swift build -c debug` exit 0 |
| BUILD_RELEASE | **PASS** | `swift build -c release` exit 0 |
| REVIEW_T-1D-A-r1 | **PASS** | Reviewer 3e630bd2:AppSearch 33/0,full 620/0,debug+release exit 0;无 BLOCKER/MAJOR/MINOR;隐私 clean(纯 Foundation 值类型,无 print/signpost/telemetry/JSONL/I-O);禁止树未动;deviation 接受(AppSearchGeneration 置于 AppSearchResultSet.swift 以守 3 文件写范围) |
| REVIEW_T-1D-B-r1 | **PASS** | Reviewer 5809a8bc:SearchPresentation 20/0,full 620/0,debug+release exit 0;红线保持;**MINOR-1 `AppGridSearchPresentationController.onStateChange` 声明但从未被调用(死回调,T-1D-E 装配潜在缺口,记 follow-up)**;MINOR-2 结果文档 593 计数过期;MINOR-3/4 记录 deviation |
| REVIEW_T-1D-C-r1 | **PASS** | Reviewer 7c9434e4:PagingSurfaceSearchReload 14/14,full 620/0,debug+release exit 0;PagingCore 6 hash 与 `Docs/PHASE1C_BASELINE_MANIFEST.sha256` 精确一致;7 字段 ItemBindingToken 完整;无 CatalogRevision 伪造;F1 MINOR(pageCount 变化时同 revision 重载对 in-range host 渲染两次——relayoutPages() 后 refreshLiveHostContent,幂等、spec 固有),F2/F3 QUESTION |
| REVIEW_T-1D-D-r1 | **PASS** | Reviewer a0ce1810:AppSearch 57/0(16 新 T-1D-D + 8 T-1D-E 集成),full 620/0,debug+release exit 0;无 BLOCKER/MAJOR;M1 MINOR(filter 49→57 因 T-1D-E 测试后落,非缺陷),M2 MINOR(isSearchFieldOrSubview 匹配任意 NSSearchField editor,应用仅一个 field),Q1/Q2 QUESTION |
| REVIEW_T-1D-E-r1 | **PASS** | Reviewer a72bb82d:AppSearchIntegration 8/0,BlankClickToQuit 9/0,full 620/0,debug+release exit 0;6 项 handoff 全接线(AppDelegate:377 onSearchShortcut,:190-202 兄弟 overlay,:201/:545 install/teardown,:604-617 blankClickResolvesToCell 经 isSearchFieldOrSubview,:412-422 search-first idle 提交,:359-361 onSearchResultCommitted→reloadCurrentPresentation);红线保持;2 MINOR + 1 QUESTION(idle 边界 search-first 顺序,testRefreshRerunsQueryOnNewBase 验证可靠) |
| CORE_FROZEN | **PASS** | `Sources/PagingCore/` 最新 08-29 21:16;`Package.swift` 08-28 20:42;`AppLaunchController.swift` 08-28 21:46,均早于全部 1D 工作;PagingCore 6 hash 与基线清单一致 |
| CONFLICT/WHITESPACE | **PASS** | 无 `<<<<<<<`/`=======`/`>>>>>>>` 冲突标记;无尾部空白 |
| PRIVACY_REDLINE | **PASS** | 搜索 query raw/normalized/result 应用名绝不入 telemetry/JSONL/stdout/signpost/profile/report;仅内存中性计数(query-generation 计数、result 计数、stale-rejected 计数、apply-duration 数值);无 PagingTelemetry schema 变更;无持久化/无 Spotlight;纯内存过滤 committed CatalogSnapshot |
| DIAGNOSTICS_DISCIPLINE | **PASS** | 三 token `CAUSALITY_UNRESOLVED / PARTIAL_CONTRIBUTOR_SUPPORTED / PRODUCT_DEFAULT_UNCHANGED` 保留;无 `FIX_VALIDATED/ALL_HITCHES_FIXED/ROOT_CAUSE_FOUND` 声称 |
| MANUAL_SEARCH_GUI_GATE | **NOT_RUN** | 待用户真实全屏 GUI 执行 §17 清单(Command-F 进入搜索无双重焦点框;输入子串结果更新;大小写/变音符;无结果中性空态 field 仍可编辑;Escape 先清 query 再退出;↓/Return/Enter 转移焦点后 Return/Enter 启动;点搜索 field/清除按钮不退出、点结果启动;点真实背景空白首击退出;宽多页 query 真实触控板 + 方向键跨页;多页搜索无错页/重复/旧名/旧图标/焦点错位;清搜索恢复全目录键盘/触控板正常;关/开 query 不恢复无残留回调) |
| MANUAL_SEARCH_KEYBOARD_GATE | **NOT_RUN** | 待用户物理键盘执行(Command-F/Escape/Down/Return/Enter/responder 矩阵) |
| MANUAL_SEARCH_TRACKPAD_PAGING_GATE_60HZ | **NOT_RUN** | 待用户真实触控板分页 + 搜索跨页 |
| MANUAL_BLANKCLICK_REGRESSION_GATE | **NOT_RUN** | 待用户确认搜索 field/清除按钮不退出、真实背景空白首击仍退出 |
| MANUAL_120HZ_GATE | **BLOCKED_BY_HARDWARE** | 60Hz 面板,无 120Hz 证据;最终状态 BLOCKED |

## C. 诚实边界

1. **搜索为纯内存过滤**:query 只过滤 committed CatalogSnapshot,无磁盘索引、无 Spotlight、无持久化;结果集为派生内存切片,不触碰 CatalogRepository/CatalogRevision。
2. **同 revision 重载的渲染双次**:pageCount 变化时 `applySameRevisionReload` 对 in-range host 渲染两次(relayoutPages() 后 refreshLiveHostContent),幂等、spec 固有(Reviewer T-1D-C F1 MINOR)。
3. **`onStateChange` 死回调**:`AppGridSearchPresentationController.onStateChange` 声明但未被调用(Reviewer T-1D-B MINOR-1),记 open follow-up,不影响本阶段行为。
4. **AppDelegate 集成由检查核验**:搜索接线的方法与 seam 契约被充分单测,但真实 AppDelegate 接线靠 review 检查而非 AppDelegate 集成测试(与 Phase 1C 一致)。
5. **手动 GUI 门未执行**:搜索 GUI/键盘/触控板/空白单击回归门均为 `NOT_RUN`,待用户真实全屏 + 物理键盘验收;120Hz 保持 `BLOCKED_BY_HARDWARE`。
6. **禁止树纪律**:`PagingCore`/`MacAppCatalog`/`Package.swift`/`AppLaunchController` 未改(按 mtime + hash 核验);不 commit/push。
7. **诊断诚实**:本阶段不宣称修复触控板卡顿;三 token 保留。
8. **来源纪律**:未读取任何禁止来源;能力匹配独立实现,非原创性/法律证明。

## D. 唯一建议

**现状态**:Phase 1D(T-1D-A..E)架构、实现、自动化、独立审查全部通过;620 tests 全绿,debug/release 0 告警,Core 冻结,隐私/诊断纪律 clean。手动 GUI 门(搜索 GUI/键盘/触控板/空白单击回归)尚未执行。

**建议:RECOMMEND_PROCEED_TO_PHASE_1E(或下一里程碑)——待手动 GUI 门通过后生效** —— 依据:严格 DAG 全任务 PASSED、独立 Reviewer 逐任务 PASS(T-1D-A..E 各 r1 全 PASS)、620 tests 全绿、debug/release 0 告警、Core 冻结、隐私/诊断纪律 clean;无证据指向需要架构返工。

**生效条件**:用户执行 §17 手动 GUI 清单(搜索 GUI/键盘/触控板/空白单击回归)并确认无问题后,`RECOMMEND_PROCEED_TO_PHASE_1E` 正式生效;在此之前保持 `NOT_RUN`。

**不适用项**:无环境/来源阻塞(环境齐备、来源纪律登记);120Hz 门因硬件面板限制保持 BLOCKED,不阻塞 1E 推进。
