# T-worker-b-pagingui-seam — PagingUI §E 内容承载 seam（Phase 1B Wave 2）

**Worker**: worker-pagingui-seam（deepseek-v4-flash:0731, max）
**日期**: 2026-08-28
**Scope**: `Sources/PagingUI/`（PagingPageContent.swift 新增、NeutralPageRenderer.swift 新增、PageHostView.swift 重构、PagingSurface.swift 扩展）、`Tests/PagingUITests/PagingSeamTests.swift`（新增 15 tests）、`Workflow/results/T-worker-b-pagingui-seam.md`
**Forbidden 遵守**: 未触碰 Package.swift / PagingCore / PagingTelemetry / AppCatalogCore / MacAppCatalog / AppIconPipeline / AppGridUI / PagingPrototypeApp / Docs / PROVENANCE / Workflow（结果文件除外）；未读取 §2.2 任何禁止来源
**AccessDeclaration: NO_PRIOR_EXPOSURE**（本 worker 仅读取 wave1-interfaces.md §E/§G/§F/H.5、本任务消息、PagingPrototype 自身源码与测试；无 PRIOR_EXPOSURE）

## 摘要一行

PagingUI 中性内容承载 seam 落地：§E 双协议 + NeutralPageRenderer（Phase 1A tile 网格/调色板逐字迁入，零回归）+ surface pin/latest-wins/refreshPresentation/onIdleBoundary + reuseGeneration 防串图；PagingUITests 93/93 全绿（既有 78 + 新增 15），`swift build` exit 0。

## 实现要点（签名依据 wave1-interfaces.md §E 冻结 + §G 合并记录；H.5 融合决策见下）

1. **§E 类型与双协议**（`PagingPageContent.swift`）：
   - `PagePresentationID`（revision UInt64 / pageIndex，Hashable+Sendable）、`PagingPageContentItem`（slot / identity AnyHashable? / title String?）、`PagingPageContent`（presentationID / items / isPlaceholder）——与 §E 逐字一致；PagingUI 中性化：不含 AppID 语义。
   - `PagingPageContentProviding`：`content(for:itemsPerPage:)`（§E 冻结签名）+ `servedRevision`/`servedPageCount`（**UInt64?/Int?，nil = 未就绪 → 中性占位**——任务文本"servedRevision/pageCount"语义 + "nil 安全→中性占位"；与并行 AppGridUI worker 已落地的 conformance（AppGridUIPageContentProvider，同样 UInt64?/Int?）编译期对齐，见「接口融合」）。
   - `PagingPageRendering`：`render(pageIndex:content:pageCount:reuseGeneration:)` + `clearForReuse()`（§E 冻结）；`PagingPageRenderingTargetBinding`（自定义渲染器可选目标绑定，不改变冻结协议形状）。
   - **§6.4 binding token 契约写入文档注释**：reuseGeneration 单调递增（clear 时 bump）、render 携带有效 generation、异步回调到达时 generation 失配 → 丢弃（stale apply = 0）；七字段 token 属 AppGridUI 层，PagingUI 提供 `PagingSurface.surfaceGeneration`（teardown bump）作字段 7 的源之一。
   - `NeutralContentProvider`（nil provider 缺省）：任何请求回中性占位（items = itemsPerPage 个 identity/title nil 条目 → 渲染器画 slot+1 序号，Phase 1A 一致）。

2. **NeutralPageRenderer**（新文件）：Phase 1A PageHostView 的中性 tile 网格/调色板**逐字迁移**（columns=5、spacing=16、insets 24/96、maxTileHeight=64、调色板 (page×7+item)%6 系统蓝灰系 alpha 0.85、page label "Page X of M"）；title 非空显示标题、否则 slot+1 序号。`PageHostView` 默认委托它渲染（行为/测试零回归）；自定义渲染器注入路径：NSView 渲染器挂入承载层级 + 可选 renderTarget 绑定。

3. **pin + latest-wins**（PagingSurface）：
   - `beginInteraction()` 捕获 `pinnedPresentation = (servedRevision, 当前显示页)`；手势 `.gestureBegan` 自动调用，app 层也可显式调用；`endInteraction()` 仅在 idle/cancelled 边界清除 pin，**interrupted/tracking/settling 保持**（§E/Explorer B）；idle/cancelled 边界（handleCoreState）自动 endInteraction + 一次性 apply pending。
   - `refreshPresentation()`：idle/cancelled → 原子替换 presentation（`servedRevision` 采纳 + `servedPageCount` 同步 core.setPageCount + 全量 re-prepare live hosts，§E 约束①）；tracking/settling/interrupted → 只写 `pendingLatestSnapshot`（latest-wins，重复 refresh 只保留最新），边界一次性 apply（§6.2）；provider 未就绪（nil）→ 无操作。
   - **每次 relayout pass 只取一次 revision**：`effectiveRevisionForPass() = pin?.revision ?? servedRevision`；revision 基线漂移（边界态自同步采纳 / 新 provider）→ 2b 全量重渲染同基线 → **相邻页不混 revision**（§6.1）。
   - `onIdleBoundary` 事件：core 进入 idle 时通知 app 层做 anchor remap（§E 约束①；cancelled 边界只 apply pending 不发事件）。

4. **复用防串图**（§6.4）：`PageHostView.reuseGeneration` 每次 `clearForReuse()` bump；render 携带当前 generation；`isReuseGenerationCurrent(_:)` 作废守卫（stale apply = 0 测试直接断言）；teardown bump `surfaceGeneration`。

5. **热路径纪律**（§7）：`relayoutPagesIfRangeChanged` 范围比较先行（既有，未改）；content 同步内存命中（无同步 I/O）；pass 内无重复请求（2b 仅基线漂移时触发，漂移只发生在 refresh/注入事件，非每帧）；PagingUI 不拥有 scanner/icon loader（协议注入，§14.A）。

6. **接口融合（H.5 拍板项，契约形状不变）**：seam 挂点命名沿用 §E 注释（`contentProvider`/`renderer`/`pinnedPresentation`/`pendingLatestSnapshot`/`beginInteraction`/`endInteraction`）；`renderer` 注入语义 = 经每个 live host（PageHostView.customRenderer）委托渲染，渲染目标 = 承载视图自身。`PagingSurface` 初始化签名不变（provider/renderer 为注入属性，装配层接线方式与 AppGridUI 任务一致）。

## 测试（Tests/PagingUITests/PagingSeamTests.swift，新增 15）

| 测试 | 覆盖 |
|---|---|
| testInitialPassRendersSingleRevision | 初始 pass 全页同 revision；seam 请求全携带 pass revision |
| testTrackingKeepsSingleRevisionAcrossFling | 长旅程 tracking/settling 全程同 revision；手势中不采纳新 revision |
| testAdjacentPagesNeverMixRevisionsAfterRefresh | refresh 后全量同新 revision；新页进入不混版 |
| testPinLifecycleBeganAndIdleClear | began 捕获 servedRevision+当前页 / idle 清除 / tracking 中 endInteraction 保持 |
| testPinSurvivesInterruptionUntilIdle | settle 中接管（interrupted 瞬时态）pin 保持；idle 才清除 |
| testRefreshDuringTrackingCachesPendingAndAppliesAtIdle | tracking 中 refresh 只写 pending、live 不跳版；idle 边界一次性 apply 全量 re-prepare |
| testLatestWinsMultipleRefreshDuringGesture | 连续 refresh 只缓存最新 revision（不堆积） |
| testRefreshPresentationBatchRePrepareAllLiveHosts | 批量 re-prepare = 全部 live hosts 数 |
| testClearForReuseBumpsGenerationAndInvalidatesInflightBinding | clear 时 generation bump；旧 generation 作废（stale apply = 0 守卫） |
| testRecycleCallsClearForReuseAndRenderCarriesBumpedGeneration | 回收路径 clearForReuse；复用 host render 携带 bump 后 generation |
| testNilProviderServesNeutralPlaceholder | nil provider → 中性占位（Phase 1A 行为：itemsPerPage tiles + 页码 a11y）；refresh 无操作 |
| testNilProviderContentIsPlaceholderViaRenderer | nil provider → 渲染器收到 isPlaceholder 内容 |
| testProviderNotReadyServesNeutralPlaceholderUntilRefresh | servedRevision nil（未就绪）→ 全占位、refresh 无操作；就绪后 refresh 生效 |
| testOnIdleBoundaryFiresOncePerSettle | idle 边界事件每 settle 一次；tracking 不触发 |
| testSetPageCountRefreshesLiveHostsViaSeam | setPageCount 经 seam 刷新 live hosts 页码 |

## 验证

- `swift test --filter PagingUITests`：**93 tests，0 failures**（既有 78 + 新增 15，零回归）
- `swift build`：exit 0（含并行 AppGridUI worker 已落地代码 —— 其 conformance 与 §E seam 编译期对齐，编译期顺序等待已解除）
- 全量 `swift test`：364 tests，6 failures **全部位于 AppGridUITests**（AppGridUIPageContentProviderTests.testRemap* ×4 + ItemBindingTokenTests.testRejectsNilAppID ×1 用例含 2 断言）——并行 worker 自身逻辑/期望问题（remap outcome 与其 fixture 期望不符、token nil-appID 判定），与 PagingUI seam 无关（其测试不触达 PagingSurface，仅消费 PagingUI 数据类型的纯值语义）；超出本 worker 写范围（Forbidden: Tests/AppGridUITests/），由 AppGridUI worker 收口。

## 变更文件

- `Sources/PagingUI/PagingPageContent.swift`（新增：§E 类型 + 双协议 + NeutralContentProvider + binding token 契约文档）
- `Sources/PagingUI/NeutralPageRenderer.swift`（新增：Phase 1A tile 网格/调色板迁移）
- `Sources/PagingUI/PageHostView.swift`（重构：PagingPageRendering seam / reuseGeneration / customRenderer；prepare 保留为兼容包装）
- `Sources/PagingUI/PagingSurface.swift`（扩展：provider/renderer 注入、pin/latest-wins、refreshPresentation、onIdleBoundary、relayoutPages seam 单点、setPageCount/teardown 走 seam）
- `Tests/PagingUITests/PagingSeamTests.swift`（新增 15 tests）
