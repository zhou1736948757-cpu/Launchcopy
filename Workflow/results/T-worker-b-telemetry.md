# T-worker-b-telemetry — PagingTelemetry schema 扩展 + Privacy 文档（Phase 1B Wave 2）

**Worker**: worker-telemetry（deepseek-v4-flash:0731, max）
**任务**: t9（Telemetry schema 扩展 + privacy docs）
**日期**: 2026-08-28
**契约依据**: PHASE1B_REAL_APP_CONTENT_PROMPT.md §3.1.14/§3.2/§3.3/§5/§7、wave1-interfaces.md §G（Explorer C 建议 5 类扩展字段）、Explorer C 边界清单（t3）
**Scope（互斥）**: `Sources/PagingTelemetry/`、`Tests/PagingTelemetryTests/`、`Docs/PRIVACY_DATA_MAP.md`、`Workflow/results/T-worker-b-telemetry.md`
**未触碰**: Package.swift / PagingCore / PagingUI / AppCatalogCore / MacAppCatalog / AppIconPipeline / AppGridUI / PagingPrototypeApp / Docs（PRIVACY_DATA_MAP.md 除外）/ PROVENANCE / Workflow（结果文件除外）
**AccessDeclaration: NO_PRIOR_EXPOSURE**（亲笔声明：未读取 §2.2 任何禁止来源；仅依据 PHASE1B_REAL_APP_CONTENT_PROMPT.md、PagingPrototype 既有源码/测试/ADR、wave1-interfaces.md、Explorer C 报告与 Main 任务指令）

---

## 一、实现（Sources/PagingTelemetry/，3 文件增量修改；17 必需字段契约零改动）

| 文件 | 变更 |
|---|---|
| `TelemetryEvent.swift` | 新增 `IconAsyncState` 枚举（idle/inflight/completed/failed/cancelled/stale_rejected，rawValue=JSON 值，CaseIterable）+ **7 个可选扩展字段**（snapshotRevision/cellReuseCount/iconAsyncState/iconCacheCount/iconCacheEstimatedCost/catalogScanDurationMS/refreshDurationMS）+ 7 个 CodingKeys（snake_case）；文件头与 struct 契约注释更新 |
| `TelemetrySession.swift` | 新增 `cellReuseCount` 累计计数 + `registerCellReuse()`（复用 register* 模式）；`recordLocked` 对可选计数「事件显式值优先、仅累计值 > 0 时盖章」（保持可选字段缺省省略语义）；**每 run 文件事件数上界**：`fileCapacityReached` + 截断转内存缓冲；`logPathDescription` 新增容量达成说明 |
| `PagingTelemetry.swift` | `TelemetryConfiguration` 新增 `maxFileEventsPerRun: Int = 100_000`（构造 `max(1,·)` 兜底）——Phase 1B 容量边界（Explorer C 建议 (a)），默认值下既有调用方零影响 |

### 7 个新字段（全部可选、全部匿名、仅设置时编码）

| JSON 键 | Swift 属性 | 类型 |
|---|---|---|
| `snapshot_revision` | snapshotRevision | Int? |
| `cell_reuse_count` | cellReuseCount | Int?（session 盖章） |
| `icon_async_state` | iconAsyncState | IconAsyncState? |
| `icon_cache_count` | iconCacheCount | Int? |
| `icon_cache_estimated_cost` | iconCacheEstimatedCost | Int? |
| `catalog_scan_duration_ms` | catalogScanDurationMS | Double? |
| `refresh_duration_ms` | refreshDurationMS | Double? |

**未做**（按要求）：不改 17 必需字段语义；不改 PagingCore/PagingUI/其他模块；无新 CLI 参数（容量上界走配置默认值，不触碰 Phase 1A 参数冻结）。

## 二、测试（Tests/PagingTelemetryTests/，33 既有零破坏 + 21 新增 = 54 全绿）

### 既有 33 测试零破坏
`TelemetrySessionTests` 17 / `TelemetryArgumentsTests` 11 / `TelemetryEventTests` 5 —— 全绿（改动前跑基线确认，改动后重跑确认）。

### 新增 `TelemetryExtensionFieldsTests.swift`（13 测试）
- IconAsyncState：raw value 稳定 snake_case、JSON 往返、**未知状态解码失败**（严格 schema）；
- 编码：7 键 snake_case 无大写 + 值正确 + 17 必需不受影响；
- 缺省省略：nil 时 7 新键 + 4 旧扩展键全省略；
- 往返：全字段解码相等（含 0 值、负值无损透传）；
- 边界：Int.max / 0 显式值 / 1e300 / 1e-9 编码无损；负 snapshot_revision 无损透传（编码层绝不改写）；
- session 盖章：`registerCellReuse` 后事件携带累计值、登记前省略、run.end 携带、显式事件值优先、从未登记整 run 无该键；
- **容量上界**：cap=120 截断 → 文件恰 120 条、`fileCapacityReached`、非 `degradedToMemory`、writeFailureCount=0、recordedEventCount 完整累计（202）、溢出入内存缓冲（202-120）、文件内每条仍含 17 必需字段；正常 run 不触发。

### 新增 `TelemetryPrivacyRedLineTests.swift`（8 测试，四层冻结）
1. **编码键白名单**：全字段事件 JSON 键 == 28 冻结键（17 必需 + 11 扩展），无白名单外键；
2. **属性表面冻结**：Mirror 属性名集合 == `telemetryPropertyNames`（新增 appName/bundleID/path 等属性立即失配）；
3. **类型表面**：无 URL/Data/Image/Dictionary/Array/Set 承载（杜绝 key 派生与字节夹带）；**String 字段仅 runID/phase**；
4. **敏感哨兵缺席**：`privacySentinels`（app 名 "SekritApp"、bundle ID、绝对/相对路径、启动 URL、图标 base64/hex）在编码 JSON、`String(describing:)`、真实 session 全 run JSONL 行中均不出现；路径型 runID 净化后原始路径形式不落盘、无文件逃逸。

### 支撑扩展 `TestSupport.swift`
新增 `extensionTelemetryKeys`（11）、`allTelemetryKeys`（28）、`telemetryPropertyNames`（28）、`privacySentinels`（7）——红线测试与文档共享单一事实来源。

## 三、文档（Docs/PRIVACY_DATA_MAP.md，新建）

按任务 §3 全部覆盖：
- **扫描上界**：4 个受限根（/Applications、/System/Applications、/System/Applications/Utilities 重叠去重、~/Applications）——全部 world-readable/用户自有，**无 FDA、无 TCC、无全局监听、不读 Launchpad/Dock 私有库**；禁扫 `/`、整个 `~`、网络卷、所有挂载卷；
- **图标**：仅运行时 NSWorkspace 公开 API；内存缓存 only（count/cost 双上界 + LRU + memory pressure）；无磁盘缓存；不进 repo/测试 fixture/发布包；IconKey 无 bundle ID 原文；
- **telemetry 默认关闭**（Release 不得自动开启）、日志位置 /tmp、**每 run 容量上界 100,000 事件**（文件截断转内存）、保留策略（OS 清理管辖、不复制进 repo）、失败降级（10,000 条环形缓冲、绝不崩溃不阻塞分页）；
- **数据流图**：扫描 → catalog → 页面/图标 → telemetry，逐 hop 标注可入字段与红线；
- 28 字段地图（类型/语义/隐私分类）、红线清单（含依据 §3.1.14/§3.2/§3.3）、测试↔边界映射表。

## 四、验证结果

| 项 | 结果 |
|---|---|
| 改动前基线 `swift test --filter PagingTelemetryTests` | ✅ 33/33（2026-08-28 21:08） |
| 改动后 `swift test --filter PagingTelemetryTests` | ✅ **54/54**（33 既有 + 21 新增，0 failure） |
| `swift build`（全包） | ✅ exit 0 |

## 五、给 Main 的备注

1. **容量上界新增配置**：`TelemetryConfiguration.maxFileEventsPerRun`（默认 100,000）——若 Main 希望改为 CLI 参数（如 `--telemetry-max-events`）需新开参数评审（本任务按"不加新参数"执行，Phase 1A 参数冻结未触碰）；
2. **§G 建议全部落地**：snapshot_revision / cell_reuse_count / icon_async_state / icon_cache_count+cost / scan·refresh_duration_ms 均已实现并测试；`ScanReport.scanDuration`（秒）→ `catalog_scan_duration_ms`（毫秒）换算留给装配层（Wave 3）；
3. **红线四层冻结**已随测试落盘：后续任何给 TelemetryEvent 加字段的改动必须同步更新 `TestSupport.swift` 三张白名单，否则测试红——这是有意设计的评审点；
4. 文档失修提醒（Explorer C 已提）：PROVENANCE/COMPONENTS.md 陈旧测试数（51→70/78）建议 Wave 3 回填时一并修正。
