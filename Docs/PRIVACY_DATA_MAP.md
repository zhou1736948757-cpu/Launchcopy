# PRIVACY_DATA_MAP — Phase 1B 真实应用内容接入 · 隐私数据地图

- **阶段**：Phase 1B（真实应用内容接入：catalog 扫描 / 图标 / 网格 UI / telemetry）
- **作者**：worker-telemetry（deepseek-v4-flash:0731, max）；内容核验依据 = 实际落盘实现（AppCatalogCore / MacAppCatalog / AppIconPipeline / PagingTelemetry 源码）+ PHASE1B_REAL_APP_CONTENT_PROMPT.md §3.1/§3.2/§3.3/§5/§7 + wave1-interfaces.md §G
- **日期**：2026-08-28
- **状态**：与 Wave 1/Wave 2 实现同步；任何实现行为与本图不符即视为隐私回归，须走 review
- **AccessDeclaration: NO_PRIOR_EXPOSURE**（未读取 §2.2 任何禁止来源）

本文件回答三个问题：**哪些真实数据进入系统、流经哪些阶段、其中哪些可以进入 telemetry，哪些是红线**。红线由测试强制（§7 映射）。

---

## 0. 数据流总览

```text
 ┌────────────┐  受限枚举    ┌─────────────┐  匿名报告   ┌──────────────────────┐
 │ /Applications        │ ──────────▶ │ MacAppCatalog │ ──────────▶ │  AppCatalogCore     │
 │ ~/Applications       │  (只读,     │ (Scanner +   │  ScanReport │  稳定 identity/排序/ │
 │ /System/Applications │   顶层.app) │  Repository)  │  仅计数     │  snapshot/PagePlan    │
 └────────────┘          │            └─────────────┘            └──────────┬───────────┘
     无 FDA / 无 TCC / 无全局监听 / 不读 Launchpad・Dock 私有库                │ revision + AppID
                                                                             ▼
                                                   ┌─────────────────────────────────────┐
                                                   │  AppGridUI（PagingUI 承载 seam）      │
                                                   │  页面/条目 = AppID + 显示名 + 图标     │
                                                   └───────┬─────────────────────┬────────┘
                                                           │ item/复用事件        │ 图标请求
                                                           ▼                     ▼
                                            ┌────────────────────────┐  ┌───────────────────────┐
                                            │  PagingTelemetry        │  │  AppIconPipeline       │
                                            │  17 必需 + 11 可选扩展   │◀─│  NSWorkspace 公开 API  │
                                            │  （全部匿名，§4/§5）     │  │  内存缓存 only         │
                                            └────────────────────────┘  └───────────────────────┘
```

**逐 hop 数据边界**：

| Hop | 进入的数据 | 可进入 telemetry | 红线（绝不可进入） |
|---|---|---|---|
| 扫描（MacAppCatalog） | 目录条目、`Contents/Info.plist` 元数据、bundle URL（进程内） | `ScanReport` 仅计数（appCount / failureCounts / scanDuration） | bundle URL、路径原文、bundle ID 原文（report 无路径/ID 字段，分类处即保证） |
| Catalog（AppCatalogCore） | AppRecord（显示名、bundle metadata、URL、icon identity） | 仅 `snapshot_revision`（单调整数）；页索引是目录序数非身份 | identity 原文（§5.2 规则 6：telemetry 不得输出 identity 原文）、显示名、bundle ID、路径 |
| 页面/图标（AppGridUI / AppIconPipeline） | 显示名渲染、图标位图（NSImage）、IconKey | `cell_reuse_count`、`icon_async_state`、`icon_cache_count/cost`（计数/枚举/整数） | 图标字节/hash、IconKey 原文、由 bundle ID 派生的任何 key（Explorer C：key 一旦进日志即泄露身份） |
| Telemetry 落盘 | 上述匿名数值 + run ID + 时间戳 | 全部 28 字段（§4） | 见 §5 红线清单 |

---

## 1. 扫描边界（MacAppCatalog）

**根集合上界**（`CatalogRoots.defaults`，代码常量 = 文档单一事实）：

```text
/Applications
/System/Applications
/System/Applications/Utilities   （与上重叠，默认按根内含性去重）
~/Applications                   （用户自有目录）
```

- 全部为 **world-readable 系统位置或用户自有目录**：枚举**不需要 Full Disk Access、不需要 TCC 授权**；代码绝不请求 FDA/TCC（无辅助功能、无屏幕录制、无完全磁盘访问）。
- **禁止扫描**：整个 `/`、整个 `~`、网络卷、所有 mounted volumes（§3.3）。根集合是显式枚举的白名单，不是遍历。
- 仅检测根下顶层 `.app`；不递归任意深、不做卷遍历。
- **无全局事件监听**（无 Hot Corner、无全局 key/mouse 监听、无辅助功能 API）；**不读取 Launchpad 数据库或 Dock 数据库**（§3.3）。
- 扫描是只读的：不写系统布局、不写任何用户数据。

## 2. 图标数据（AppIconPipeline）

- **读取方式**：仅运行时经 **NSWorkspace 公开 API**（`icon(forFile:)` / `icon(for: UTType.application)`）读取并显示；无任何磁盘缓存、不复制图标文件。
- **缓存**：仅内存有界缓存（count 上界 + 估计 cost 上界，LRU 驱逐；memory pressure 清理）；**绝无磁盘持久化**（§3.3 禁磁盘图标缓存）。
- **不进 repo / 不进测试 fixture / 不进发布包**：不复制第三方 App 图标到 Sources、Resources、测试产物或 README（§3.3 + §14.C）。测试全部使用程序生成色块图像。
- **IconKey**：只含 `IconIdentity`（AppID 派生，不透明）+ 尺寸/scale/appearance；**不含 bundle ID 原文、路径、字节、哈希**（§G 约束，AppIconPipelineTests 断言字段形状 + 描述脱敏）。

## 3. Telemetry 字段地图（PagingTelemetry）

**默认关闭**：`TelemetryConfiguration.enabled == false`（缺省）时 begin/record/end 全部 no-op，**Release 不自动开启**（仅显式 `--paging-telemetry` 参数 opt-in）。

### 3.1 17 个必需字段（PHASE1_SPEC §6，契约冻结不动）

| JSON 键 | 类型 | 隐私分类 |
|---|---|---|
| `run_id` | String | run 标识（时间戳+4 位 hex；任意输入经净化，禁路径逃逸；非用户/app 身份） |
| `gesture_id` / `transition_id` | UInt64 | 会话内单调序号，0=不适用；无身份 |
| `event_phase` | String | 状态机阶段常量；无身份 |
| `timestamp` | Double | 1970 秒；无身份 |
| `input_delta` / `visual_offset` / `frame_interval` | Double | 分页物理量；无身份 |
| `semantic_current_page` / `proposed_target` / `committed_page` | Int | 目录中的序数，非身份 |
| `interruption_count` / `stale_rejection_count` / `layout_count` / `teardown_callback_count` | Int | 会话累计计数；无身份 |
| `page_host_view_count` | Int | 视图数；无身份 |
| `page_prepare_cache` | enum n/a\|hit\|miss | 缓存结果；无身份 |

### 3.2 11 个可选扩展字段（仅设置时编码；Phase 1A 4 个 + Phase 1B 7 个）

| JSON 键 | 类型 | 语义 | 隐私分类 |
|---|---|---|---|
| `transition_token` | UInt64? | ADR-001 D3 token | 单调序号；无身份 |
| `stale_callback_fired` | Bool? | stale 观测 | 无身份 |
| `interrupt_source_offset` | Double? | 接管偏移 | 分页物理量；无身份 |
| `reduce_motion_enabled` | Bool? | 系统设置 | 无身份 |
| `snapshot_revision` | Int? | catalog revision/generation | **单调整数；无身份**（§6 snapshot 一致性归因） |
| `cell_reuse_count` | Int? | 会话累计 cell 复用计数 | 累计计数；无身份 |
| `icon_async_state` | enum? idle\|inflight\|completed\|failed\|cancelled\|stale_rejected | 图标异步状态 | **枚举；无任何身份**（§6.4 binding token 观测） |
| `icon_cache_count` | Int? | 内存缓存条目数 | 计数；无身份 |
| `icon_cache_estimated_cost` | Int? | 缓存估计成本 | 整数；非真实字节/hash |
| `catalog_scan_duration_ms` | Double? | 扫描耗时 | 匿名时序指标（热路径外） |
| `refresh_duration_ms` | Double? | 刷新耗时 | 匿名时序指标 |

> 设计要点：**没有任何字段可以承载身份原文** —— 无 String 字段可装 app 名/bundle ID（仅 run_id/event_phase，语义冻结）、无 URL/Data/图像/字典字段（杜绝 key 派生与字节夹带）。由 `TelemetryPrivacyRedLineTests` 以四层冻结强制（§7）。

## 4. 红线清单（绝不记录）

以下内容**任何形式**（原文、编码、派生、description、key 派生）都不得进入 telemetry 事件或日志文件（§3.1.14 / §3.2 / §3.3 / Explorer C）：

```text
app 显示名（任何形式）
bundle identifier / bundle ID
bundle URL / 文件路径（绝对、相对、scan root、文件名）
图标字节 / 图标 hash / 由 bundle ID 派生的缓存 key
启动 URL（§3.2："不将真实 bundle URL 写入 telemetry"）
搜索文字（本阶段无搜索）
窗口标题、截图、剪贴板、键盘内容
用户标识
```

配套纪律（其他模块已落地）：`ScanReport` 仅计数（无路径/ID 字段）；`IconKey` 无 bundle ID 原文；`IconPipelineStats` 仅 7 个计数。

## 5. 日志生命周期（容量 / 保留 / 降级）

| 项 | 边界 | 实现 |
|---|---|---|
| 默认关闭 | Release 不得自动开启 | `enabled == false` 缺省；无参数 run 不产生任何文件（测试 `testDefaultDisabledProducesNoOutput`） |
| 日志位置 | `/tmp` | `TelemetryConfiguration.defaultOutputDirectory = /tmp`；文件名 `<prefix>-<runID>.jsonl`（前缀冻结 `launch-copy-paging-prototype`） |
| **每 run 容量上界** | **100,000 事件/文件** | `TelemetryConfiguration.maxFileEventsPerRun`（默认 100,000，构造时 `max(1,·)` 兜底）：达到后置 `fileCapacityReached`、**截断文件写入**，后续事件转入有界内存环形缓冲（10,000 条）；事件总数仍累计于 `recordedEventCount`。**文件不可能无限增长** |
| 内存降级缓冲上界 | 10,000 条 | `memoryCapacity` 环形缓冲，超出丢最旧（`testMemoryBufferIsBounded`） |
| 保留策略 | 系统临时目录 | 文件位于 `/tmp`（OS 清理管辖）；**不自动复制到项目目录/repo**；每 run 独立文件互不覆盖；`deinit`/`end` 关闭句柄 |
| 失败降级 | 绝不崩溃、不阻塞分页 | 目录创建/打开/写入失败 → `writeFailureCount` + `degradedToMemory` + 内存缓冲；telemetry 与分页解耦（§4 冻结不变量） |
| run ID 安全 | 禁路径逃逸 | `sanitizedRunID` 仅保留 `[A-Za-z0-9._-]`、上限 64 字符（测试 `testPathTraversalRunIDIsSanitized` / `testVeryLongRunIDIsCapped`） |

## 6. 测试与验证映射（红线由测试强制）

| 边界 | 测试 |
|---|---|
| 17 必需字段契约不破坏 | `TelemetrySessionTests.testEveryLineCarriesAllSeventeenFields` 等 33 个既有测试零改动全绿 |
| 新字段编码/缺省省略/边界 | `TelemetryExtensionFieldsTests`（13 个：raw value 稳定性、未知状态解码失败、snake_case 键、nil 省略、往返、Int/Double 边界、session 盖章、容量截断） |
| **红线 ①编码键白名单**（JSON 键 ⊆ 28 冻结键） | `TelemetryPrivacyRedLineTests.testEncodedKeysStayWithinFrozenWhitelist` + `testFullRunJSONLLinesContainNoPrivacySentinels` |
| **红线 ②属性表面冻结**（新增属性立即失配） | `testPropertySurfaceMatchesFrozenWhitelist` |
| **红线 ③类型表面**（无 URL/Data/图像/字典/集合承载；String 仅 runID/phase） | `testNoFieldTypeCanCarryIdentityPayload` + `testOnlyStringFieldsAreRunIDAndPhase` |
| **红线 ④敏感哨兵缺席**（JSON / JSONL / description） | `testSerializedJSONContainsNoPrivacySentinels` + `testDescriptionContainsNoPrivacySentinels` + `testFullRunJSONLLinesContainNoPrivacySentinels` |
| run ID 净化（路径形式不落盘） | `testPathLikeRunIDNeverWritesRawPathIntoFile`（+ 既有 sanitize 测试） |
| 容量上界 | `TelemetryExtensionFieldsTests.testFileCapacityBoundTruncatesToMemory` |
| 图标/扫描红线（他模块） | `AppIconPipelineTests.IconKeyTests`（字段形状+描述脱敏）、`IconPipelineStatsTests`（无隐私字段）、`MacAppCatalogTests`（ScanReport 无路径原文） |

---

**AccessDeclaration: NO_PRIOR_EXPOSURE** — 本文件仅依据 PHASE1B_REAL_APP_CONTENT_PROMPT.md、PagingPrototype 自身源码/测试/ADR、wave1-interfaces.md 与团队报告撰写；未读取 §2.2 任何禁止来源。

## 7. 搜索 query 内存边界（Phase 1D 追加）

| 边界 | 实现 |
|---|---|
| query raw/normalized/result 应用名绝不入 telemetry/JSONL/stdout/signpost/profile/report | `AppSearchQuery`/`AppSearchMatcher`/`AppSearchResultSet` 为纯 Foundation 值类型,无 print/signpost/telemetry/JSONEncoder/write/UserDefaults 调用;`AppSearchResultSet` 无 debug description 反吐 AppID |
| 仅内存中性计数 | query-generation 计数、result 计数、stale-rejected 计数、apply-duration 数值;无 PagingTelemetry schema 变更 |
| 无持久化 / 无 Spotlight | 纯内存过滤 committed CatalogSnapshot;无磁盘索引、无 query 持久化、无 Spotlight 调用 |
| 搜索 field 空白单击交互区 | `AppSearchFieldView.isSearchFieldOrSubview(_:)` 分类;`QuitOnBlankClickWindow.sendEvent` 命中搜索 field/清除按钮不退出,真实背景空白首击退出;不记录任何点击目标 |

## 8. 文件夹内存边界（Phase 1E 追加）

| 边界 | 实现 |
|---|---|
| folder 标题/成员/identity 原值 + 图标数据绝不入 telemetry/JSONL/stdout/signpost/profile/report | `FolderDomain.swift`/`FolderLabFixture.swift`/`FolderOverlayView.swift`/`FolderTitleEditor.swift` 无 PagingTelemetry/JSONEncoder/UserDefaults/os_signpost/NSLog/print 调用；`FolderID.redactedDescription = "FolderID(<redacted>)"` 非名称派生 |
| 仅内存中性计数 | folder_count、member_count、open-close outcome enum、stale rejection count、apply duration 数值；无 PagingTelemetry schema 变更 |
| 无持久化 / 无 Spotlight | 文件夹组合会话内派生自 committed CatalogSnapshot；无磁盘索引、无 folder 持久化、无 Spotlight 调用 |
| 标题编辑 | first responder NSTextField，Enter/Escape/失焦语义，无磁盘写入、无 telemetry；标题长度 64 字符上限、空白回退 |
| 启动身份隔离 | `FolderID` 独立 Hashable 类型；启动路径 `as? AppID` cast 天然拒绝 folder identity；成员启动复用 AppLaunchController.handleCell 精确管线（无弱化第二启动路径） |

## 9. 激活入口与 Hot Corner 数据边界（Phase 1G 追加）

| 边界 | 实现 |
|---|---|
| 严禁记录/持久化（PLAN §11 / Prompt §4.3） | raw pointer 坐标/轨迹、screen UUID/name/serial、frontmost app、按键流、真实快捷键文本（默认日志）、app 身份、folder 数据、搜索词、窗口标题 —— 全部不进入 telemetry/JSONL/stdout/signpost/profile/report/UserDefaults |
| 允许中性（仅内存判定 + 中性 enum/计数） | activation source enum（initialLaunch/dockReopen/statusItem/globalShortcut/hotCorner/testHarness）、show/hide/toggle/quit outcome enum、corner enum（topLeft 等）、dwell/cooldown state enum、screen count、registration outcome enum（configured/conflict/unavailable）、transition duration aggregate、counter（如 `triggerCount`） |
| 坐标只存在于一次内存判定 | `HotCornerStateMachine.sample(pointer:)` 单次采样即弃；无坐标存储/日志/持久化；`ScreenGeometrySnapshot` 为纯值模型，不持久化 display UUID/名称/几何 |
| 屏幕身份中性化 | `ScreenID` = 当前屏幕列表序号（非 UUID/名称/序列号）；`ScreenGeometrySnapshot` 公开面仅 id/frame/scale（§9.7 项 9 测试锁定） |
| 快捷键中性表示 | `ShortcutSpec` 仅 keyCode + 修饰键位掩码，不存按键文本；持久化字段白名单由 `ActivationSettingsTests.testNoCoordinatesOrAppDataInDefaults` 锁定（§9.8 项 9） |
| 无全局监听/权限 | 无 `addGlobalMonitorForEvents`/CGEvent tap/Accessibility/Input Monitoring/Screen Recording/IOHID（四指获批窄例外除外，ADR-013）；静态红线扫描 §9.10 |
| 配置持久化边界 | 只持久化 hotCornerEnabled/selectedCorner、globalShortcutEnabled/shortcut representation、showStatusItem、schemaVersion（T-G-P3 ActivationPreferences，专用 namespace，与 layout store 分离）；非法值回安全 Off |
| 测试强制 | `LauncherPresentationCoordinatorTests`（§9.1 12 项）、`HotCornerStateMachineTests`（§9.6 14 项）、`ScreenGeometrySnapshotTests`（§9.7 10 项）、`ActivationSettingsTests`（§9.8 9 项） |
