# T-worker-b-appgridui — AppGridUI 真实内容网格完整实现（Phase 1B Wave 2）

**Worker**: worker-appgridui（deepseek-v4-flash:0731, max）
**任务**: t8（AppGridUI 实现 + 测试 + 验证）
**日期**: 2026-08-28
**接口契约**: `wave1-interfaces.md` §E（PagingUI seam，**已落地**）+§6.2/§6.3/§6.4（latest-wins / anchor 规则 / 七字段 token）+ADR-004（remap 五级降级冻结）+§3.1.11（中性状态）+§7（热路径）+§9（accessibility）+§10.5（测试）
**Scope（互斥）**: `Sources/AppGridUI/`、`Tests/AppGridUITests/`、`Workflow/results/T-worker-b-appgridui.md`
**未触碰**: Package.swift / Sources/PagingCore / PagingUI / PagingTelemetry / AppCatalogCore / MacAppCatalog / AppIconPipeline / PagingPrototypeApp / Docs / PROVENANCE / Workflow（结果文件除外）
**AccessDeclaration: NO_PRIOR_EXPOSURE**（亲笔声明：未读取 §2.2 任何禁止来源；仅依据 PHASE1B_REAL_APP_CONTENT_PROMPT.md、wave1-interfaces.md、PagingPrototype 既有源码与 Main 任务指令）

---

## 一、实现（Sources/AppGridUI/，8 文件，替换 MAIN SEED 占位；Placeholder.swift 已删除）

| 文件 | 内容 |
|---|---|
| `ItemBindingToken.swift` | §6.4 七字段绑定令牌：catalogRevision / pageIdentity（PagePresentationID）/ itemSlot / appID（AnyHashable?）/ reuseGeneration / iconKey（IconKey?）/ surfaceGeneration；`Equatable` + `matches(_:)`（== 同义，语义化为"可 apply 门控"）；公开 init |
| `AppGridDataSource.swift` | 扫描器注入协议（AppGridUI **不拥有 scanner**，§14.A）：`currentSnapshot`/`currentRevision` + `refresh() async -> AppGridRefreshOutcome`（succeeded / appCount / failureCount / cancelled）；`AppGridRefreshOutcome: Sendable, Equatable` |
| `AppGridUIPageContentProvider.swift` | `PagingPageContentProviding`（§E 签名逐字）：servedSnapshot / servedRevision / servedPageCount（plan 默认 35，与 PagingSurface 对齐）；`receive(_:)` latest-wins pending；`discardPending()`；`applyPending(atCurrentPage:itemsPerPage:) -> AppGridPresentationUpdate?`（anchorCandidate + CatalogPlanner.remap 五级降级，ADR-004 冻结调用）；`content(for:itemsPerPage:)` 同步内存命中（revision 不匹配 / 越界 / 未就绪 → 中性占位，不抛错不等待）；槽位 = **全局 index**（page×itemsPerPage+页内序号）；identity = AnyHashable(AppID)、title = displayName |
| `AppGridUIState.swift` | `loading / ready / empty / partialFailure / refreshing`（§3.1.11）+ `accessibilityDescription`（英文中性文案）+ `isBusy` |
| `AppGridRefreshController.swift` | `@MainActor` 状态机控制器：`begin()`（已有快照 → 立即呈现；否则 loading + 首扫）；`refreshNow()`（进行中 → queued latest-wins）；`scheduleRescan()` / `cancelScheduledRescan()`（DispatchWorkItem + 0.5s 默认 debounce，可取消、多次调度只留最后一次）；`applyPendingAtIdleBoundary(currentPage:)`（§6.2 idle：commit pending + onPresentationUpdate）；状态解析（cancelled 恢复刷新前态；失败计数 → .partialFailure；0 条 → .empty） |
| `AppGridCellView.swift` | cell：48pt 图标（NSImageView，上）+ 11pt 截尾名称（NSTextField，下）；`bind(name:token:)` 先清空再写（防旧名残留）；`applyIconIfValid(_:token:)` **全字段 token 门控**（bindingToken == token 才落图）；accessibilityLabel = 完整名称（截断安全，§9） |
| `AppGridPageView.swift` | `PagingPageRendering` 真实网格渲染器：`render`（名称同步 + 图标异步请求，generation = surfaceGeneration 注入；占位 → 无 cell）；`clearForReuse()`（generation bump 作废在途 + 全清空）；`teardown()`（bump + 移除全部 cell + 此后零写回）；cell 复用池（count 变才重建数组，否则只清内容）；`onIconApplyResult` 观察钩子（telemetry 桥接面）；5 列 × 16 间距 × 88pt cell 高布局，页标签 "Page N of M" |
| `AppGridStatusView.swift` | 中性状态视图：label（15pt secondaryLabel）+ spinner（仅 busy 态显示）；`update(state:)` 幂等（状态变才改视图）；`statusText` 只读访问器 |

### 行为要点（逐项落点）
- **idle 边界 anchor remap**：手势期间刷新只进 pending（latest-wins，绝不打断 served）；idle/取消边界 `applyPending` 用当前页 anchor（`anchorCandidate(nearPage:)`，AppID 确定性排序）走 `CatalogPlanner.remap` 五级降级（located → successor → predecessor → clamped → emptyCatalog，ADR-004 冻结）；规则 6 由 remap 签名保证（不传旧快照 → 绝不复用旧数组下标）；
- **stale async UI apply = 0**：三层防线——(a) pipeline generation 回传门控（deliveredGeneration ≠ surfaceGeneration → rejectedStale 计数）；(b) cell 级 token 全字段匹配（含 page/slot/appID/revision）；(c) teardown 后一律 .ignoredAfterTeardown。stale 只计数、不写 UI；
- **复用无残留**：clearForReuse 清 token/名/图标；新内容同步可见；旧图标到达被拒（旧名/旧图标 0 残留，测试断言）；
- **热路径**：`content(for:)` 纯内存同步；图标请求在 render 外异步；渲染仅在 relayout 时发生；
- **隐私**：AppGridUI 无 telemetry 直连；仅暴露中性回调（onIconApplyResult / staleIconApplyCount / 状态枚举）供 Explorer C 合成 icon_async_state；不落任何 app 名/bundle ID/路径/图标字节。

### 对冻结契约的偏离（编译必需，均已文档化在源码头注）
1. `ItemBindingToken` 以 `@unchecked Sendable` 满足 Sendable（appID 为 AnyHashable，本 SDK 非 Sendable；代码库先例 = AppIconPipeline `IconResult`）；`AppGridPageView` 同（持有 NSView 层级）。
2. 与真实 seam 的核对：`PagingPageContentItem`/`PagingPageContent` 在 PagingUI 中声明为 `Sendable, Equatable`（seam worker 已处理 AnyHashable 兼容），我侧仅消费——真实包编译零警告验证通过。

---

## 二、测试（Tests/AppGridUITests/，6 文件，49 测试，全绿）

| 文件 | 测试数 | 覆盖 |
|---|---|---|
| `AppGridUIPageContentProviderTests` | 14 | 快照→页槽位映射（含 identity 承载 AppID）；35/36 条页边界（尾页 slot 35、越界占位）；无快照占位；revision 不匹配占位；latest-wins pending；无 pending no-op；discardPending；remap 五级：located / successor / predecessor / clamped / emptyCatalog（pageCount 0）+ **never-reuse-old-index**（锚点仍在 → located）；pageCount 收缩 |
| `ItemBindingTokenTests` | 9 | 七字段全匹配 → true；六类单字段失配（revision / page / slot / appID / nil appID / reuseGeneration / iconKey / surfaceGeneration）→ false |
| `AppGridPageViewTests` | 10 | 名称同步渲染（无 await 即见）；nil identity 不请求图标；占位无 cell；**复用**：清空无旧名/旧图标 → 新内容 → 旧图标到达被拒（stale==1）→ 新图标落地；**乱序到达**：rev1 双图标在 rev2 后到达 → 只落最新 generation（stale==2、颜色断言新旧不混）；**同 key 合并**：一次底层加载投两代 consumer、只落当前代；**冷/暖 cache**（miss→hit 计数、无新加载）；失败 → .failed + 中性 placeholder；teardown → 零 apply、零 stale、cell 全移除；accessibility 完整名 + 页标签 |
| `AppGridRefreshControllerTests` | 12 | begin 即时呈现/loading→ready；空目录 → .empty；整体失败 → .partialFailure；成功+失败计数 → .partialFailure；手动刷新 refreshing→ready；cancelled 恢复刷新前态；并发刷新 latest-wins（pending 只留最新、served 不被打断）；debounce 触发 / 取消不触发 / 多次调度只留最后一次；idle 边界 apply → onPresentationUpdate + served 提交 + 无 pending no-op |
| `AppGridStatusViewTests` | 4 | 初始 loading；状态切换文本/可访问描述同步；busy 态 spinner 显示/隐藏；状态文本无身份信息（无 fixture 名/路径/.app） |

**Fake 纪律**：`TestSupport.swift` 提供程序生成图像（NSBitmapImageRep 纯色）+ `GatedIconLoader`（按 key 挂起、测试控制完成顺序/失败）+ `ImmediateDataSource`（scripted 刷新结果、计数）；**全程不触碰真实 /Applications**；快照 bundleID 用 `fixture.<title>` 保证 AppID 排序与显示序一致（remap 锚点测试确定性的关键）。

---

## 三、验证证据

1. **隔离 harness**（`/tmp/appgridui-harness`，seam 未落地期间）：seam 冻结签名逐字 stub + 真实 AppCatalogCore/AppIconPipeline 复制 + AppGridUI/Tests 符号链接；`swift build` exit 0、零警告；`swift test` 49/49 全绿 ×2 轮。
2. **真实包**（seam 落地后，最终裁决）：`cd /Users/mac/Projects/Launch_Copy/PagingPrototype && swift build` → **exit 0、零警告**；`swift test --filter AppGridUITests` → **49/49 全绿 ×2 轮**（2026-08-28 21:32 与复跑），与真实 `PagingPageContentProviding`/`PagingPageRendering`/`PageHostView` 编译兼容（memberwise init 标签、servedRevision/servedPageCount 协议要求逐字命中）。
3. 测试期间定位并消除的真实缺陷：`AnyHashable` 非 Sendable（@unchecked 解决）；测试竞态——load 任务跑并发池线程，`complete()` 早于 gate 注册 → 新增 `waitForPendingLoads` 先等挂起再完成（消除 3 处偶发超时）；"App5 排序后于 App35"的字典序陷阱（零填充 %02d 修正 remap 锚点预期）。

---

## 四、交付边界与延后项

- **延后（Phase 1C）**：键盘焦点导航模型（§9 未冻结部分）；启动冒烟（launch smoke，PagingPrototypeApp 装配层依赖 Wave 3）；真实 scanner 接线（AppGridUI 只定义 `AppGridDataSource` 注入协议）。
- **未触碰**：`Package.swift`（Main 所有）；其他 worker 的 4 个目标；`Docs/`、`PROVENANCE/`。
- 基线核对：Phase 1A 181 + AppCatalogCore 56 + AppIconPipeline 23 + MacAppCatalog 45 均为他 worker 已验证范围，本 worker 仅跑/构建自身 scope。
