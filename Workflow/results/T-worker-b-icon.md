# T-worker-b-icon — AppIconPipeline 完整实现（Phase 1B Wave 1）

**Worker**: worker-icon（deepseek-v4-flash:0731, max）
**任务**: t6（AppIconPipeline 实现 + 测试 + 验证）
**日期**: 2026-08-28
**接口契约**: `wave1-interfaces.md` §D（+§G Explorer C 约束：IconKey 禁 bundle ID 原文/路径/哈希；stats 无隐私字段）
**Scope（互斥）**: `Sources/AppIconPipeline/`、`Tests/AppIconPipelineTests/`、`Workflow/results/T-worker-b-icon.md`
**未触碰**: Package.swift / Sources/AppCatalogCore / MacAppCatalog / PagingUI / PagingCore / AppGridUI / PagingPrototypeApp / Docs / PROVENANCE / Workflow（结果文件除外）
**AccessDeclaration: NO_PRIOR_EXPOSURE**（亲笔声明：未读取 §2.2 任何禁止来源；仅依据 PHASE1B_REAL_APP_CONTENT_PROMPT.md、wave1-interfaces.md、PagingPrototype 既有源码与 Main 任务指令）

---

## 一、实现（Sources/AppIconPipeline/，5 文件，替换 MAIN SEED 占位）

| 文件 | 内容 |
|---|---|
| `IconKey.swift` | `IconKey`（identity+pointSize+displayScale+appearance；`pixelSize`；不含 revision/bundle ID 原文/路径/哈希）+ `AppearanceVariant(.system)`。**附加** `CustomStringConvertible`：description 一律 `identity: <redacted>`（防调试日志/telemetry 经默认 Mirror 描述意外泄露 identity 原文——实测默认描述会递归进 AppID 私有 storage） |
| `IconResult.swift` | `IconResult.success(NSImage)/failed(IconFailure)`、`IconFailure(.cancelled/.loadFailed/.pipelineShutdown)`。注：NSImage 非 Sendable → `@unchecked Sendable`（签名冻结要求 `Sendable`，此为编译必需；对象创建线程产生、MainActor 只读投递） |
| `IconCache.swift` | `IconCacheLimits`（maxCount 256 / maxCost 64<<20 / maxConcurrentLoads 4，冻结签名）+ 内部 `IconCache`：**内存 only、无磁盘持久化**；count/cost 双上界 + LRU（lastAccess + 插入序 tie-break，确定性）；单条目 cost > maxCost 不入缓存；`purgeExpired(before:)`；同 key 重插先替换 |
| `IconLoading.swift` | `IconLoading` 协议 + `SystemIconLoader`：仅公开 NSWorkspace API 运行时读取（`icon(forFile:)` / `icon(for: UTType.application)`）；无磁盘缓存、不复制。冻结 `init()` 返回系统通用应用图标（身份不透明 → 无法自解析路径）；**附加** `init(resolver:)` 供 Wave 3 装配层注入 identity→URL 映射（不破坏冻结签名） |
| `IconPipeline.swift` | `IconPipeline` + `IconRequestHandle` + `IconPipelineStats`；私有 `AsyncSemaphore`（最大并发）；`Consumer`（pending/delivered/cancelled 三态锁，投递/取消先到者胜） |

### 行为要点（§5.3 逐项落点）
- **in-flight 合并**：同 key 未完成 → 追加 consumer（`inFlightMerged`），单次底层加载；
- **缓存**：cache hit 不重载；`estimatedCost = max(w×h)×4`（估计解码成本，非真实字节）；
- **取消**：单 consumer `cancel()` 幂等、不影响他人；全部取消 → 取消底层 Task（`Task.isCancelled` 短路零投递）；`cancelAll(for:)` 批量；
- **MainActor 写回 + generation**：所有 `onApply` 经 `Task { @MainActor }` 投递，携带调用方注入的 generation 原样回传；Consumer 状态机保证**过期（已取消）completion = 0 回调**（stale completion 不落图；新 generation 的 UI 门控由 onApply 参数完成）；
- **shutdown**：置位 + 清缓存 + 取消全部 in-flight + 移除通知观察者 + 取消 DispatchSource；此后（含已入队未执行的 MainActor 任务）零回调；shutdown 后 request 返回惰性 handle（拒新请求，零回调，不计 stats）；幂等；
- **memory pressure**：监听 `NSApplicationDidReceiveMemoryWarningNotification`（冻结契约）+ **DispatchSource memory-pressure 源**双通道（生产兜底）；清理计数走 `memoryPressurePurges`；
- **stats**：仅 7 个 Int 计数，无字节/哈希/路径/bundle/url；不变量 `requests == cacheHits + cacheMisses`（合并请求计为未命中，语义文档化）。

### 对冻结契约的两处必要偏离（编译/平台必需，均已文档化在源码头注）
1. `IconResult`/`IconRequestHandle`/`IconPipeline` 以 `@unchecked Sendable` 满足 `Sendable` 要求（NSImage 非 Sendable；内部全锁保护）；
2. macOS 26 SDK **已移除** `NSApplication.didReceiveMemoryWarningNotification` 常量 → 用稳定运行时字符串 `"NSApplicationDidReceiveMemoryWarningNotification"`（通知仍由系统投递；测试可直接 post 触发），并加 DispatchSource 兜底。

### 附加（不破坏冻结签名，供 Main 决策）
- `SystemIconLoader.init(resolver:)`：identity→URL 注入，仍仅 NSWorkspace 公开 API；
- `IconPipelineStats` 全字段默认参数 `init`；
- `IconKey: CustomStringConvertible` 脱敏描述。

## 二、测试（Tests/AppIconPipelineTests/，7 文件，23 tests，全部程序生成图像 + fake loader）

| 文件 | 测试 | 断言要点 |
|---|---|---|
| `TestSupport.swift` | （支持） | `makeIconImage`（NSBitmapImageRep 内存填充，零文件系统）；`FakeLoader`（延迟/失败注入、loadCount、并发峰值 maxActive）；`CallbackBox`/`ValueBox`（@Sendable 捕获盒）；memory warning 通知名常量 |
| `IconKeyTests.swift` | 4 | pixelSize；appearance 默认 .system；相等/hash 按四字段；**字段形状断言（仅 4 字段，无 revision/bundle/path/hash/url）+ 描述不泄露 bundle ID 原文** |
| `IconPipelineCacheTests.swift` | 6 | miss→load→hit 不重载；**count 上界 LRU 驱逐**；**cost 上界驱逐**；purgeExpired；purgeAll；memory pressure 清理（post 通知 → 重请求 miss，memoryPressurePurges=1） |
| `IconPipelineMergeTests.swift` | 3 | **同 key 并发 → 单次加载**（loadCount=1，两 consumer 各自 generation）；**maxConcurrentLoads=2 并发峰值 ≤2**；loader 失败 → `.failed(.loadFailed)` placeholder、失败不缓存 |
| `IconPipelineCancelTests.swift` | 5 | 单 consumer 取消 0 回调 + 幂等 + 重请求全新加载；多 consumer 取消其一、其余照常；cancelAll 0 回调 + 全新加载；**generation 过期拒绝（stale completion = 0，幸存者收自己的新 generation）**；投递后 cancel 空操作 |
| `IconPipelineShutdownTests.swift` | 3 | in-flight 时 shutdown 0 回调；shutdown 后 request 拒收 0 回调 0 加载；shutdown 幂等 + teardown 清空不计 eviction |
| `IconPipelineStatsTests.swift` | 2 | **stats 无隐私字段断言**（Mirror 字段名集合 = 冻结 7 字段，无 byte/hash/path/bundle/url）；确定性计数序列（3 请求/1 hit/2 miss/1 merge，含 generation 逐一回传） |

测试资源隔离（§10.4）：**绝不触碰真实 /Applications、绝不读取真实 app**；无第三方图标写入 test artifacts（全部 64×64 程序生成色块）。

## 三、验证结果

| 项 | 结果 |
|---|---|
| `swift build --target AppIconPipeline` | ✅ exit 0，0 warning |
| `swift build --target AppIconPipelineTests` | ✅ exit 0，0 warning |
| `swift build`（全包） | ✅ exit 0（Build complete） |
| 隔离验证包（/tmp/icon-pipeline-verify，symlink 本 worker 文件 + 冻结桩快照） | ✅ **23 tests 全绿**（4+6+3+5+3+2，0 failures） |
| `swift test --filter AppIconPipelineTests`（仓库级） | ⏳ 依赖他 worker 测试 target 编译（见下） |

**仓库级 `swift test` 的编译期等待**（计划 §F 已预见的"编译期顺序等待，非开发期串行等待"）：并行 worker 中途状态曾阻塞全包测试编译——先为 MacAppCatalogTests（worker-maccatalog，`actor-isolated ... autoclosure` 等），随后其已收敛（全包 `swift build` 已绿）；最后为 AppCatalogCoreTests（worker-catalogcore，`posixOrdering` 未定义等，本文件落盘时仍在编辑中）。**本 worker 不越界修改他人 target**；Main 收口全量测试时，本 target 已按冻结契约实现并全绿验证。

## 四、给 Main 的收口提示
1. Wave 2 AppGridUI 消费点：`IconPipeline.request(key:generation:onApply:)` 的 generation 由 UI 注入（reuse/surface 代），过期 generation 在 UI 侧门控（onApply 参数原样回传）；failed 显示中性 placeholder；
2. Wave 3 装配：真实 per-app 图标用 `SystemIconLoader(resolver:)` 注入 identity→URL（MacAppCatalog 侧提供映射）；
3. `icon_cache_count/cost` telemetry ← `IconPipelineStats` 计数（count 可由 stats 派生；cost 上界为估计值，未暴露单条 cost——如需可后续扩展）；
4. 测试全绿后建议：`swift test --filter AppIconPipelineTests`（23 用例）纳入 Main 全量验证。
