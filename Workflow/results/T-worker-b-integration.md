# T-worker-b-integration — Wave 3 装配收口：真实内容接线 + 集成冒烟 + §8 帧源实验（Phase 1B t10）

**Worker**: worker-integration（deepseek-v4-flash:0731, max）
**任务**: t10（Wave 3 装配：AppGridDataSource 注入 / AppGridUIPageContentProvider → PagingSurface / SystemIconLoader / telemetry 扩展字段 / CLI 新参数 / §8 帧源实验）
**日期**: 2026-08-28
**接口契约**: `wave1-interfaces.md`（§B AppCatalogCore / §C MacAppCatalog / §D Icon / §E seam / §G telemetry）+ PHASE1B_REAL_APP_CONTENT_PROMPT.md §5.2（扫描根上界）/ §6.2–6.4（latest-wins、anchor remap、七字段 token）/ §7（热路径）/ §8（帧源实验）/ §9（accessibility）/ §10.3–10.5（资源隔离、红线、测试）
**Scope（互斥）**: `Sources/PagingPrototypeApp/`、`Tests/PagingUITests/`（仅 AppArguments / AppParameters / AppTelemetryBridge 相关文件 + 本 worker 新增文件）、`Workflow/results/T-worker-b-integration.md`、`Workflow/results/T-worker-b-launchsmoke.md`
**未触碰**: Package.swift / Sources/PagingCore / PagingUI / PagingTelemetry / AppCatalogCore / MacAppCatalog / AppIconPipeline / AppGridUI / Docs / PROVENANCE / Workflow（结果文件除外）
**AccessDeclaration: NO_PRIOR_EXPOSURE**（亲笔声明：未读取 §2.2 任何禁止来源；仅依据 PHASE1B_REAL_APP_CONTENT_PROMPT.md、wave1-interfaces.md、PagingPrototype 既有源码与本团队 Main 任务指令）

---

## 一、实现（Sources/PagingPrototypeApp/，3 新文件 + 3 修改文件）

| 文件 | 内容 |
|---|---|
| `AppCatalogAssembly.swift`（新） | 装配根：`IconURLResolver`（NSLock 运行时 identity/AppID→URL 映射，每次提交重建，latest-wins 即 stale 失效；无磁盘缓存）；`CatalogRepositoryDataSource`（AppGridDataSource 适配：缓存已提交快照 + 匿名扫描/刷新时长，NSLock 非 actor——协议要求非隔离同步 currentSnapshot）；`AppGridRenderer`（PagingPageRendering + TargetBinding：**每页独立 AppGridPageView 实例**包装，placeholder 不创建实例，host 复用换页/离开范围双向清理回池，onIconApplyResult 透传）；`AppCatalogAssembly`（@MainActor composition root：CatalogRepository(policy:scanning:) + ScanConfiguration + SystemIconLoader(resolver: urlResolver) + IconPipeline + AppGridRefreshController；begin/refreshNow/scheduleRescan/bundleURL(for:)/teardown）；`AppRuntimeFactory.makeAssembly`（`--neutral-content` → nil = Phase 1A 回归模式） |
| `FrameDriverExperiment.swift`（新） | §8 实验：`DisplayLinkProviding` 抽象 + `CADisplayLinkProvider`（**macOS 公开创建路径 `NSScreen.displayLink(target:selector:)`**——`CADisplayLink.displayLinkWithTarget:` 在 macOS 不可用，SDK 头明确指引）+ `DisplayLinkFrameDriver`（探测式：**帧源恒为 RunLoopFrameDriver**（Phase 1A 稳定路径，零回调从构造上不破坏 60Hz 泵）；display link 只作观测探针，窗口固定 0.4s、`stop()` 不打断探测（首个动画短于窗口时证据仍落定）；零回调 → 记录 fallback reason；回调到达 → 记录 callbacks + observedInterval，**不宣称 vsync**；evidenceHandler 输出 stdout + AppDelegate 保留） |
| `AppLaunchController.swift`（新，详见 T-worker-b-launchsmoke.md） | 单击启动 smoke（t11 交付） |
| `PagingTelemetryBridge.swift`（改） | 新增：`onPagePrepared(reused)` → `session.registerCellReuse()`；`recordCatalogPresentation(_:assembly:)`（phase `catalog.presentation`：snapshot_revision / catalog_scan_duration_ms / refresh_duration_ms）；`recordIconAsyncState(_:)`（phase `icon.async`：applied→.completed、rejectedStale→.staleRejected、failed→.failed、cancelled→.cancelled、ignoredAfterTeardown→不记录） |
| `AppDelegate.swift`（改） | 装配接线：neutralContent → 不装配（回归模式）；否则 `AppRuntimeFactory.makeAssembly` → contentProvider/renderer 注入、`onPresentationUpdate`（**先 refreshPresentation 再 setPageCount(update 对齐页数)**，非默认 itemsPerPage 时以后者为准）、`onIdleBoundary`/`onStateChange`（**启动首扫提交路径**：PagingCore 初始化不触发 idle 事件，扫描完成且 surface idle 时经 onStateChange 提交）、`onIconApplyResult` → telemetry、`begin()`；`--frame-driver` 接线；teardownAll 增加 assembly.teardown（幂等） |
| `AppArguments.swift`（改） | `FrameDriverMode`（runloop/displaylink/auto，缺省 runloop）；`--catalog-root <path>`（可多次，覆盖 4 默认根）；`--neutral-content`；`--frame-driver`；helpText 更新 |
| `AppMain.swift`（改） | smoke 输出新增 catalogRoots/neutralContent/frameDriver |

### 行为要点（逐项落点）
- **数据流**：扫描 → `CatalogRepositoryDataSource.refresh()`（时长测量）→ `AppGridRefreshController.applyOutcome`（latest-wins pending，不打断 served）→ **idle/首扫边界** `applyPendingAtIdleBoundary`（anchorCandidate + CatalogPlanner.remap 五级降级，ADR-004 冻结调用）→ `onPresentationUpdate` → surface pageCount/revision 刷新 + urlResolver.update + telemetry；
- **identity→URL 只读映射**：图标 resolver（SystemIconLoader(resolver:)）与启动 smoke 共用 `IconURLResolver`；每次提交整体重建（旧 identity 立即失效 = stale 拒绝第二道防线）；仅进程内存，无磁盘缓存、不复制图标；
- **扫描根上界**（§5.2）：缺省 = `CatalogRoots.defaults` 4 受限根（/Applications、/System/Applications、/System/Applications/Utilities、~/Applications）；`--catalog-root` 覆盖（测试只用临时 fake .app，绝不触碰真实 /Applications）；
- **热路径**：内容渲染全同步内存命中；图标经 IconPipeline 异步（generation 门控）；呈现提交只发生在 idle 边界（手势期间刷新绝不打断动画）；
- **隐私红线**：telemetry 只记中性数值/枚举（revision/时长/状态）；app 名/bundle ID/路径/图标字节/启动 URL 一律不进 JSONL（测试断言 + 真机冒烟双重验证）；
- **诚实缺口（文档化）**：`icon_cache_count` / `icon_cache_estimated_cost` 保持 nil——`IconPipelineStats` 无缓存计数/成本访问器（AppIconPipeline 冻结，不越权新增），如实记录不伪造。

## 二、集成发现（真实缺陷 + 修复 + 行为文档化）

1. **seam 单实例渲染器多 host 缺陷（真实复现）**：`PagingSurface.renderer` 是单实例注入点；`PageHostView.render` 把自定义渲染器**视图**移动进正在渲染的 host（`rendererView.superview !== self { addSubview }`）——radius 3 → 7 live host 并存时，共享渲染器视图只存在于最后渲染的 host，其余 live host 空白。**修复（App 层，不越权 PagingUI）**：`AppGridRenderer` 按 pageIndex 每页一个 `AppGridPageView` 实例直接挂入 host 层级；host 复用换页/离开范围（superview==nil）→ 实例清空回池；placeholder 不创建实例。测试断言：翻页后 page 0/1 实例分别留在各自 host 层级（`superview === hostForPage(i)`），实例总数翻页往返零增长（池化复用）。
2. **呈现提交双渲染 → 首批图标 stale 拒绝（PagingUI 冻结行为，benign）**：提交 = relayout 渲染 + `refreshLiveHostContent` 再渲染两 pass；首批图标请求在第二 pass 后按 generation 门控被拒为 stale（每 cell 一个），次批同 key 请求（各 consumer 独立 generation）正常 apply → **图标最终一致**（测试断言 stale==cell 数、图标全部就位）。telemetry 如实记录 staleRejected 事件（真机冒烟：4 个 icon.async = 2 apps × 2 pass）。
3. **启动首扫提交路径**：PagingCore 初始化不触发 onIdleBoundary（状态直接 .idle 无变迁事件）→ 启动首扫完成时经 `refreshController.onStateChange`（非 busy 且 surface idle）提交；手势进行中则仍由 onIdleBoundary 提交（测试：无手势等待即提交成功）。
4. **§8 帧源实验结果（重要，与 Phase 1A 证据矛盾，如实记录）**：
   - 真机（GUI 自驱 + 真实 runloop）：`--frame-driver auto` → **callbacks=25, observedInterval=0.01597s**；`--frame-driver displaylink`（forced）→ **callbacks=24, observedInterval=0.01594s**。**display link 在本环境确实 ~60Hz 投递回调**（≈62.6Hz），state = `.displayLink`，无需回退；
   - 与 Phase 1A 记录（T-worker-b-frame-fix：display link 零回调）矛盾。**原因定位**：本 worker 首轮冒烟同样「零证据」——探测定时器在首个动画 stop() 时被取消（动画短于 0.4s 探测窗口 → 证据永不落定）。修复（stop 不打断探测）后回调如实到达。Phase 1A 的零回调证据很可能同样是探测窗口被取消的假象，而非环境无 vsync；
   - 按 §8 纪律：只记录 callbacks/observedInterval，**不宣称 vsync 对齐**；帧源仍为 RunLoopFrameDriver（60Hz 稳定路径未改）；display link 实验结论 = 证据记录，不标 PASS/FAIL。

## 三、测试（Tests/PagingUITests/，新增 4 文件 + 2 扩展，24 新测试全绿）

| 文件 | 测试 |
|---|---|
| `AppArgumentsTests.swift`（+6） | catalog-root 缺省空/单根/可多次/缺值失败；neutral-content（缺省 false + 与既有参数共存）；frame-driver 三模式/缺省 runloop/非法失败；helpText 含 3 新参数 |
| `AppCatalogAssemblyTests.swift`（新，6） | ① 冒烟：6 fake apps → 扫描提交 → page 0 六个 cell 名=fixture 名（扫描序非字母序 → 集合比较）、图标异步就位、stale==6（双渲染首批，文档化）；② 多页：36 apps → 2 页（35/页），翻页往返 live 实例=2、totalInstancesCreated 零增长、page 实例留在各自 host 层级（缺陷修复断言）；③ neutral 回归决策（factory → nil）；④ 空根 → 4 受限默认根（不 begin，隔离）；⑤ `--catalog-root` 覆盖；⑥ 红线：JSONL 含 catalog.presentation/icon.async/snapshot_revision/catalog_scan_duration_ms/refresh_duration_ms/icon_async_state，**不含** fixture 名/bundle ID/`.app`/临时根路径 |
| `AppLaunchControllerTests.swift`（新，8） | 见 T-worker-b-launchsmoke.md |
| `FrameDriverExperimentTests.swift`（新，4） | 零回调→回退+reason；回调→保留+observedInterval 精确 1/60；forced 零回调也如实回退（不假装 PASS）；探测期间帧源恒在（不冻结）+stop 幂等（全部可编程 fake，不依赖真实 CADisplayLink） |

**验证证据**：
- `swift test` 全量：**414 tests, 0 failures**（414 = 声明的全部测试方法，无跳过；新增 24，收口前 390 全绿保持）；
- `swift build -c release`：**exit 0，0 warnings/errors**；
- 真机 GUI 冒烟（release 二进制 + `PAGING_PROTOTYPE_GUI_SELFDRIVE=1`）：
  - `--frame-driver auto --neutral-content`：exit 0，SELFDRIVE stats 正常，帧源证据如上；
  - `--frame-driver displaylink --neutral-content`：exit 0，证据如上；
  - `--catalog-root /tmp/paging-fakeapps --frame-driver runloop --paging-telemetry --run-id smoke-real-001`：exit 0，committed=22/40 flings，754 telemetry 事件；JSONL 含 `catalog.presentation`（snapshot_revision=1, catalog_scan_duration_ms=0.98, refresh_duration_ms=1.44）+ 4×`icon.async`；**红线扫描：JSONL 0 命中 fixture/Alpha/Beta/.app/paging-fakeapps**。

## 四、对冻结契约的偏离（编译必需，均已文档化在源码头注）
1. `CatalogRepositoryDataSource` 为非 actor 类 + NSLock（协议要求非隔离同步 currentSnapshot；refresh 在 async 上下文经同步辅助拿锁——NSLock 在 async 函数直调为 Swift 6 弃用）；`IconURLResolver`/`AppGridRenderer` 以 `@unchecked Sendable`（NSView/NSLock 持有；代码库先例 = AppIconPipeline/AppGridUI）。
2. AppDelegate 装配块经 `MainActor.assumeIsolated`（applicationDidFinishLaunching / windowWillClose 恒在主线程；装配组件为 MainActor 隔离——确定性成立，非猜测）。
3. `PagingSurface.onIdleBoundary`/`refreshController.onStateChange` 回调体内经 `MainActor.assumeIsolated` 调 `applyPendingAtIdleBoundary`（回调触发点恒为主线程/MainActor）。
4. 与既有 seam 契约核对：`PagingPageRendering.render(pageIndex:content:pageCount:reuseGeneration:)` 逐字实现；placeholder 内容（`content.isPlaceholder`）不创建页实例（无 cell 可展示，空转为零）。

**任务状态**: t10 完成（装配 + 冒烟 + §8 实验证据 + 红线验证全绿；全量 414 测试通过，release 零警告）。**t11 状态见 T-worker-b-launchsmoke.md（PASS）**。
