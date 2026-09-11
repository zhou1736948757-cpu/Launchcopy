# PHASE1B_REPORT.md — Phase 1B 最终报告（§16）

- **日期**：2026-08-28
- **项目**：PagingPrototype（独立实现，`/Users/mac/Projects/Launch_Copy/PagingPrototype/`）
- **范围**：Phase 1B 真实应用内容接入（AppCatalogCore / MacAppCatalog / AppIconPipeline / AppGridUI / PagingUI seam / PagingTelemetry 扩展 / 装配）
- **工作流**：chef-worker-reviewer-workflow v1.4.1（Main + Chief + 8 Worker + Reviewer A/B/C/D + Explorer A/B/C；AgentTeams `phase1b-real-app-content`）
- **Prompt**：`PHASE1B_REAL_APP_CONTENT_PROMPT.md`（SHA-256 `2b164b3f3a54be948e469296e2f39bc94eb3666d4614a7cb8ccd4d43442e83b3`）

## A. 完成内容

1. **Gate 0（§1）**：清洁基线 181 tests 0 failures；manifest 117 文件 shasum -c 全绿（Explorer A 核验修复 7/118 失配 + 停 stale watchdog 77071；watchdog.json/heartbeats.json 活写排除）。
2. **AppCatalogCore**：AppID（bundleID 主身份 + canonicalURL 回退）、CatalogSnapshot/CatalogRevision、CatalogBuilder（canonicalURL 去重 → bundleID 去重 rootPriorityFirst → 稳定排序）、CatalogDiff、SnapshotGate、CatalogPlanner.remap 五级降级（located→successor→predecessor→clamped→emptyCatalog，签名不含旧快照 → 结构性杜绝旧 index）、PagePlan 0/35/36、CatalogFixture。56 tests。
3. **MacAppCatalog**：CatalogRoots.defaults 4 受限根、ScanConfiguration、URLNormalizer、ScanFailureKind（仅计数）、CatalogScanning+ScanTask（幂等取消）、CatalogScanner（symlink 策略 + 回边检测 + visited 去重）、CatalogRepository actor（revision 单调唯一拥有者、latest-wins、coalesced）。45 tests。
4. **AppIconPipeline**：IconKey（identity+pointSize+displayScale+appearance，无 bundleID/路径/hash）、IconCache（256 项/64MB LRU + memory pressure）、SystemIconLoader（NSWorkspace 公开 API，resolver 注入）、IconPipeline（in-flight 合并、单 consumer 取消、cancelAll/purgeAll/shutdown 零回调、MainActor 写回 + generation 门控）、IconPipelineStats（7 计数，无隐私字段）。23 tests。
5. **PagingUI seam（§E）**：双协议 PagingPageContentProviding（servedRevision/servedPageCount/content(for:itemsPerPage:)，同步内存命中，nil→中性）+ PagingPageRendering（render/clearForReuse + reuseGeneration）；surface 显式 pin（beginInteraction 捕获、endInteraction idle/cancelled 清除、interrupted 保持）；latest-wins pendingLatestSnapshot；refreshPresentation + onIdleBoundary；ItemBindingToken 7 字段；stale async UI apply = 0（三层：pipeline generation + token + teardown）。15 tests（seam）。
6. **AppGridUI**：AppGridDataSource 注入协议、AppGridUIPageContentProvider（§E 实现 + remap 五级）、五态 UI 状态、AppGridRefreshController（手动 + 可取消 debounced rescan）、AppGridCellView/PageView（名称同步 + 图标 generation 门控写回 + 复用无残留 + teardown 零写回）、AppGridStatusView。49 tests。
7. **PagingTelemetry 扩展**：7 新可选字段（snapshot_revision/cell_reuse_count/icon_cache_count/icon_cache_estimated_cost/catalog_scan_duration_ms/refresh_duration_ms/IconAsyncState enum），17 必需契约零改动；registerCellReuse()；maxFileEventsPerRun=100,000 → 10,000 环形缓冲降级；四层红线测试（28 冻结键白名单/Mirror 表面/类型表面/哨兵缺席）。21 tests（扩展）。
8. **装配（Wave 3）**：AppCatalogAssembly（IconURLResolver/CatalogRepositoryDataSource/AppGridRenderer 每页包装/AppRuntimeFactory）、AppLaunchController、FrameDriverExperiment（§8）、CLI 3 新参数（--catalog-root/--neutral-content/--frame-driver）、PagingTelemetryBridge。24 tests（集成）。
9. **APP_LAUNCH_SMOKE（§3.2）**：PASS——单击触发、NSWorkspace 公开 API、stale revision/缺失 app/磁盘消失全部拒绝、启动失败非致命 + 中性错误状态、telemetry 无真实 URL、无进程管理/最近使用/自动重启。键盘层按 §9 文档化延 Phase 1C。
10. **§8 帧源实验**：display link 本环境确实 ~60Hz 回调（25 @0.01597s auto；24 @0.01594s forced）；Phase 1A "零回调" = 探测定时器 stop 假象；只记录证据，未标 PASS，帧源未改（RunLoopFrameDriver 保持默认）。
11. **Review（§14）**：Reviewer A（Source/Architecture）PASS、B（Privacy）PASS、C（Resource/Provenance）PASS、D（Physical Evidence）PASS——无 BLOCKER/MAJOR；4 MINOR 全部处理（陈旧注释修复、icon_cache 字段预留标注、PROVENANCE 回填、注释同步）。
12. **物理门**：60Hz 真实内容 PASS（用户实机，主观 4/4/4/4/3.6，阈值 0.43/0.36）；**后续调参 0.42/0.35**（2026-08-29 用户确认"挺好的"）；120Hz BLOCKED（硬件 60Hz 面板）。

## B. 验证表格

| 状态项 | 状态 | 证据 |
|---|---|---|
| BUILD_1B | PASS | swift build -c release exit 0，0 warning（Main 复验） |
| AUTOMATED_TESTS_1B | PASS | 414 tests, 0 failures（Gate 0 181 → Wave1 306 → Wave2 390 → Wave3 414） |
| APP_LAUNCH_SMOKE_1B | PASS | §3.2 全项（详见 A.9） |
| REVIEWER_A_SOURCE_ARCH | PASS | 8 项全过；PagingCore 冻结值逐行核对；热路径无同步 I/O；stale apply 三层防线完整 |
| REVIEWER_B_PRIVACY | PASS | 5 项全过；四层红线测试与 PRIVACY_DATA_MAP 逐项一致；grep 0 命中全局监听/TCC/FDA |
| REVIEWER_C_RESOURCE_PROVENANCE | PASS | 泄漏预警（非原创性证明）；图标仅 NSWorkspace 公开 API 运行时读取；仓库 0 图片二进制 |
| REVIEWER_D_PHYSICAL_EVIDENCE | PASS | 证据链真实（telemetry 时间线与用户操作一致）；无合成证据冒充物理 PASS；调参链完整；代码与最终值一致 |
| MANUAL_PHYSICAL_GATE_60HZ_REAL_CONTENT | **PASS** | 用户真实内容全屏复测（1470pt 基准）；主观五项 4/4/4/4/3.6；phys1b-04 telemetry 423s/41 尝试/30 commit（28 跨页 + 2 同页 bounce）/11 interrupted（stale_rejected 11/11）/835 frame/icon 236 |
| MANUAL_PHYSICAL_GATE_120HZ | **BLOCKED** | 硬件实锤：主屏 60.0Hz 固定（MacBook Air M3 无 ProMotion），无 120Hz 设备证据 |

最终参数（固化默认）：displacementThreshold **0.42**、retreatDisplacementFactor **35/42**（回退 0.35）、momentumGlideFrames 1、momentumDecay 0.55、momentumMaxOvershoot 0.20（软阻尼 0.2×delta）、velocityThreshold 800px/s、settleDuration 250ms 等（详见 PARAMETER_RATIONALE.md）。

## C. 诚实边界

1. **帧源非 vsync**：帧泵 = 主 runloop 60Hz Timer ≈16.67ms，非 vsync 对齐；§8 实验证明 display link 本环境可回调，但帧源未改（诚实标注，vsync 对齐留后续阶段）。
2. **120Hz 未验证**：硬件 60Hz 固定，120Hz 目标 BLOCKED（非失败，按 §8 纪律不写 PASS）；需 120Hz 设备后重跑。
3. **调参基准 = 全屏 1470pt 真实内容**：phys1b-03/04 全屏真实应用内容为调参基准；窗口形态仅测试。
4. **主观评分**：4/4/4/4/3.6 为用户真实触控板主观感受；自动化/合成事件（SELFDRIVE、simulate*、无头探针）从未作为物理 PASS 证据。
5. **隐私红线**：telemetry 永不记录 app 名称/bundle ID/路径/图标数据/启动 URL；IconKey 无 bundleID/路径/hash；ScanReport 仅计数；scan roots = 4 受限根；无 FDA/TCC/全局监听；图标仅 NSWorkspace 公开 API 运行时读取（无磁盘缓存/复制）。
6. **Reviewer C 结论**：资源/来源审查为泄漏预警，非原创性或法律证明。
7. **icon_cache_count/icon_cache_estimated_cost**：预留未启用（恒 nil），非泄露，文档已标注。
8. **git**：按 §15 无提交；产物 hash 见 IMPLEMENTATION_LOG.md。
9. **键盘层**：APP_LAUNCH_SMOKE 的键盘焦点模型按 §9 文档化延 Phase 1C（非缺陷，范围裁剪）。

## D. 唯一建议

**RECOMMEND_PROCEED_TO_PHASE_1C**

- 60Hz 真实内容物理门 PASS（用户确认"OK的" + 主观 4/4/4/4/3.6 + 414 测试全绿 + telemetry 全链路正常）；
- 120Hz 为硬件 BLOCKED（非实现缺陷），换 120Hz 设备后重跑该目标；
- 无架构级阻塞（ADR-003/004/005 决策全部落地，无 REWORK 触发项）；
- 隐私红线四层测试冻结，无泄漏预警升级项；
- 遗留项（Phase 1C 候选）：键盘焦点模型、120Hz 设备复验、icon_cache 字段启用、vsync 帧源对齐。

## E. 后续优化附录（2026-08-29，Phase 1B 之后）

- **阈值第 15 轮**：0.43/0.36 → 0.42/0.35（用户决策；0.42×35/42==0.35 精确零 1-ulp；phys1b-06 复测用户确认"挺好的"；462 tests 全绿）。
- **图标尺寸上限 256×256**（t19）：写回缓存前统一缩略，缓存 cost 4MB→256KB/张；用户指示"最大256*256"。
- **卡顿深挖**（t20/t21 + 用户/GPT 深挖）：帧回调内耗时 max 2.7ms（人手）——卡顿不在 input/state/view；runloop 探针归因：帧间隔 >20ms 窗口主线程工作 max 1.08ms，卡顿 = **系统调度/唤醒延迟**（afterWaiting gap 60.7ms/54.6ms 铁证；runloop Timer 合并/节流）；SELFDRIVE 对照：图标非主因（中性内容卡顿更多）；用户帧驱动重构（PagingFrameDriver 协议 + callback-boundary profiler）后基线 462 tests；GPT 深挖结论 CAUSALITY_UNRESOLVED（详见 IMPLEMENTATION_LOG.md 与 Docs/FRAME_HITCH_*）。
- **深挖 Prompt**：`Docs/FRAME_HITCH_DEEP_DIVE_PROMPT.md`（自包含任务书，供外部 GPT 深挖）。
