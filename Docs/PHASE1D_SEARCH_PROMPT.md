# Phase 1D Prompt — 本地应用名搜索、搜索结果分页与现有交互集成

> 创建日期：2026-08-30（Asia/Tokyo）
> 项目：`PagingPrototype`
> 项目路径：`/Users/mac/Projects/Launch_Copy/PagingPrototype/`
> 阶段建议：**Phase 1D = 搜索 vertical slice**
> 性质：下一阶段的自包含开发 Prompt，不是已完成报告，也不是帧卡顿修复声明。

---

## 0. 任务身份与总目标

你是本任务的 Main/Orchestrator。你要在 Phase 1A–1C 已完成的独立 macOS AppKit 分页应用原型上，只增加一个主要产品变量：

> **在当前已提交的本机应用目录快照上，按应用显示名进行纯内存搜索，用现有分页引擎展示搜索结果，并与 Phase 1C 键盘焦点、Return/Enter 启动、鼠标启动、刷新、页面复用、空白单击退出和触控板分页正确集成。**

本阶段不是“一次做完所有 Launchpad 功能”。搜索完成后，文件夹、拖拽、Hot Corner、正式视觉和发布仍然是后续独立阶段。

用户与 Prompt 都可能不完整；执行模型不得机械附和。必须把“已测事实”、“架构推断”、“产品决策”和“待物理验收”分开记录。

---

## 1. 当前权威基线

### 1.1 已完成阶段

- Phase 1A：分页状态机、真实触控板跟手、settle、中断接管、边界反馈、页面复用；
- Phase 1B：受限根本机 `.app` 目录、不可变 catalog snapshot、运行时系统图标管道、真实网格、单击启动、刷新与 stale 防线；
- Phase 1C：键盘焦点、方向键网格导航、跨页焦点调和、Return/Enter 启动、ESC 清除键盘选择、延迟焦点、全屏模式、空白单击退出。

### 1.2 Phase 1C 当前验收

```text
AUTOMATED_TESTS_1C = 526 tests, 0 failures
BUILD_DEBUG_1C = PASS
BUILD_RELEASE_1C = PASS
MANUAL_KEYBOARD_GUI_GATE = PASS_USER_REPORTED_WITH_EVIDENCE
MANUAL_BLANKCLICK_GUI_GATE = PASS_USER_REPORTED_WITH_EVIDENCE
PHASE = PHASE_1C_COMPLETE
RECOMMEND_PROCEED_TO_PHASE_1D = EFFECTIVE
```

这些是历史已记录基线。Phase 1D 开始时必须在当前工作树重新执行并记录实际数字，不能盲信 526。

### 1.3 帧卡顿与 Timer tolerance 当前边界（T-A5 定案后修正）

```text
CAUSALITY_UNRESOLVED
PARTIAL_CONTRIBUTOR_SUPPORTED
SHORT_TAIL_MITIGATED_BY_TOLERANCE
PRODUCT_TIMER_TOLERANCE_0MS
```

T-A5 已通过用户物理验收并定案：生产默认 `Timer.tolerance = 0ms`。现有证据允许把 `SHORT_TAIL_MITIGATED_BY_TOLERANCE` 用于 `20–25ms` 短尾；此前 SELFDRIVE 观察到的 commit 增幅未在物理轨复现，归档为合成伪影。该结论**只覆盖短尾缓解**，不等于解释或修复全部帧间隔异常。

严格 `>25ms` 长尾仍为 `CAUSALITY_UNRESOLVED`。此前真实触控板中观察到的 RunLoop `exit → entry ≈10ms` 只是一条受支持的部分贡献，不是全部卡顿根因。Phase 1D 不得宣称：

```text
ROOT_CAUSE_FOUND
ALL_HITCHES_FIXED
FIX_VALIDATED
SCHEDULER_CONFIRMED
RUNLOOP_CONFIRMED
WINDOWSERVER_CONFIRMED
GPU_CONFIRMED
```

生产默认 `Timer.tolerance = 0ms` 已由 T-A5 物理门定案；本搜索阶段不得再次修改该默认值，不切换默认帧源，不顺手重开 System Trace 支线。历史报告中的 `8.333ms`、旧 gate 和旧 token 作为当时记录保留，不做追溯改写。

---

## 2. 必读文件与项目纪律

执行前至少读取：

```text
/Users/mac/Projects/Launch_Copy/PagingPrototype/AGENTS.md
/Users/mac/Projects/Launch_Copy/PagingPrototype/MEMORY.md
/Users/mac/Projects/Launch_Copy/PagingPrototype/Workflow/STATE.json
/Users/mac/Projects/Launch_Copy/PagingPrototype/Workflow/PLAN.md
/Users/mac/Projects/Launch_Copy/PagingPrototype/Workflow/MAIN_BRIEF.md
/Users/mac/Projects/Launch_Copy/PagingPrototype/Docs/PHASE1C_REPORT.md
/Users/mac/Projects/Launch_Copy/PagingPrototype/Docs/PHASE1C_VALIDATION_PLAN.md
/Users/mac/Projects/Launch_Copy/PagingPrototype/Docs/ADR-006-KEYBOARD-FOCUS.md
/Users/mac/Projects/Launch_Copy/PagingPrototype/Docs/PHASE1B_SPEC.md
/Users/mac/Projects/Launch_Copy/PagingPrototype/Docs/ADR-003-PAGING-CONTENT-PROVIDER.md
/Users/mac/Projects/Launch_Copy/PagingPrototype/Docs/ADR-004-APP-CATALOG-SNAPSHOT.md
/Users/mac/Projects/Launch_Copy/PagingPrototype/Docs/ADR-005-ICON-PIPELINE.md
/Users/mac/Projects/Launch_Copy/PagingPrototype/Docs/PRIVACY_DATA_MAP.md
/Users/mac/Projects/Launch_Copy/PagingPrototype/Docs/FRAME_HITCH_ROOT_CAUSE_CORRELATION_RESULTS.md
```

不得自动：

```text
commit / push / tag / reset / clean / release
```

不得删除、回滚或覆盖他人当前工作。当前仓库没有 commit，大量文件为 untracked；`git diff --check` 不足以证明全部未跟踪文件清洁，必须对实际修改文件额外扫描 trailing whitespace 和 conflict markers。

---

## 3. Gate 0 — Phase 1C 基线对账与冻结

在写 Phase 1D 产品代码前，Main 必须：

1. 读取当前 `Workflow/STATE.json` 和 `events.jsonl` 末尾，确认无真实 active agent job；
2. 不伪造、不回填、不修改历史 event；
3. 执行：

```bash
swift test
swift build -c debug
swift build -c release
```

4. `exit_code == 0` 且 `executed_tests > 0` 才是有效 PASS；
5. 记录实际测试数、失败数、warning 和 Debug/Release hash；
6. 生成 Phase 1C 基线 manifest/hash，排除 `.git/`、`.build/`、临时日志、trace 和活跃 watchdog 文件；
7. 对以下冻结输入记录 hash，供后续比对：

```text
Sources/PagingCore/
Sources/PagingPrototypeApp/AppLaunchController.swift
Package.swift
Phase 1C 最终键盘/空白单击验收文档
```

Gate 0 失败时，不得开始搜索功能实现。先保存证据，对基线问题另立 Workflow task。

---

## 4. 来源隔离与禁止输入

搜索功能是独立产品能力。可以实现用户可观察的“输入名称 → 过滤应用 → 分页展示 → 启动”，但不得把相同能力解释为相同代码、相同状态机、相同常量簇或相同视觉表达。

承担 Phase 1D 新实现的 Worker 不得打开、搜索、读取、复制或总结：

```text
/Users/mac/Projects/BuhoReverseNotes/
/Users/mac/Projects/LaunchBetter/
/Users/mac/Projects/LaunchBetter/Docs/aegis/work/2026-08-25-buho-launchpad-reverse/
```

也不得从任何 Ghidra/otool/decompiler 输出逐行翻译搜索逻辑。

允许使用：

- 本 Prompt；
- 本项目自身的 Phase 1A–1C 源码、测试、ADR 和报告；
- Apple SDK 公开 AppKit/Foundation 文档；
- 纯需求驱动的搜索规格与独立实验。

如任何 Worker 误读禁止来源，立即停止其输出合并，记录 `PROVENANCE/CONTAMINATION_LOG.md`，并返回 Main/Reviewer 重新决策。

---

## 5. Phase 1D 严格范围

### 5.1 必须实现

1. **系统原生搜索控件**：全屏窗口中的中性 `NSSearchField` 或等价公开 AppKit 控件；
2. **搜索快捷键**：`Command-F` 把 first responder 从 Phase 1C 键盘代理切换到搜索框；
3. **只按应用显示名匹配**：搜索输入只与 `AppRecord.displayName` 比较；
4. **纯内存**：只过滤当前已提交 `CatalogSnapshot`，不重新扫描磁盘，不调用 Spotlight/`NSMetadataQuery`；
5. **搜索结果分页**：结果按现有 `itemsPerPage` 进入现有 PagingSurface/页面复用/图标管道；
6. **结果顺序稳定**：保留基础 catalog 的已有排序，不增加隐藏权重或不可解释排名；
7. **空查询恢复完整 catalog**：规范化后为空时，展示当前完整目录；
8. **无结果状态**：区分“目录真空”与“搜索无匹配”，文案中性；
9. **latest-wins**：快速输入、异步过滤和 catalog refresh 交错时，只最新 query generation + 最新 catalog revision 可以写回 UI；
10. **idle 边界提交**：tracking/settling/interrupted 期间不替换当前页内容，搜索结果作为 latest pending，在 idle/cancelled 边界一次提交；
11. **同 catalog revision 内容重载**：query 改变不得伪造新 `CatalogRevision`；必须用窄的 presentation reload seam 让同 revision 的过滤内容重新渲染；
12. **键盘集成**：搜索框、搜索结果和 Phase 1C 键盘焦点之间有明确 responder 转移；
13. **启动复用原管线**：搜索结果单击或键盘启动继续走 `AppLaunchController` 的 revision/AppID/文件存在性/失败非致命校验；
14. **空白单击兼容**：点击搜索框及其 editor/clear button 不退出 App；点击真实背景空白仍按 Phase 1C 首个已接收点击退出；
15. **刷新一致性**：搜索激活时 catalog refresh 完成后，在最新 snapshot 上重跑当前 query；
16. **焦点一致性**：query 改变、无结果、结果缩页、refresh、resize、reuse、teardown 后不得指向不可见或过期 cell；
17. **无隐私记录**：query 原文、规范化文本、结果 app 名称不进入 telemetry/log/signpost/profile/report；
18. **自动化 + Reviewer + 真实 GUI 验收**：不以单元测试冒充用户真实搜索体验。

### 5.2 明确不实现

```text
拼音搜索
模糊搜索 / 编辑距离 / 智能排名
bundle ID / 路径 / URL / 最近使用 / 用户行为搜索
Spotlight / NSMetadataQuery / 全盘扫描
搜索历史、最近查询、磁盘索引、SQLite 持久化
文件夹/分组/文件夹标题编辑
拖拽重排/跨页移动/跨文件夹移动
Hot Corner / 全局手势 / 全局 NSEvent monitor
Accessibility 权限请求 / Input Monitoring
Launchpad/Dock 私有库读写
LaunchBetter 视觉/品牌/Swift 实现
120Hz 物理 PASS
vsync 帧源切换
Timer tolerance 调参
帧卡顿根因修复
icon-cache telemetry 字段启用
安装/签名/公证/发布
activation/license bypass
```

如果任何不在 allow-list 的能力被判定为搜索的必要依赖，Worker 不得自行扩大；应返回 `BLOCKED`，列出原因、最小变更和推荐决策。

---

## 6. 搜索匹配语义（产品决策）

### 6.1 输入规范化

搜索域层必须提供纯函数，默认规则：

1. 原始 query 仅存在搜索控制器/`NSSearchField` 内存中；
2. 去除头尾 `whitespacesAndNewlines`；
3. 使用可注入 `Locale` 执行 case-insensitive + diacritic-insensitive + width-insensitive folding；
4. 对规范化后的 `displayName` 做字面 substring match；
5. 空 query 返回全部记录；
6. 结果保留基础 snapshot 顺序；
7. 不匹配 `bundleIdentifier`、canonical URL、路径、AppID 或图标 metadata；
8. 不做拼音、首字母、token ranking、编辑距离或学习排序。

如需更改规则，必须在 `ADR-007-SEARCH-PRESENTATION.md` 中作为产品决策记录，不得以“旧产品这样”作为唯一理由。

### 6.2 顺序与分页

- 搜索结果是基础 `CatalogSnapshot.records` 的稳定子序列；
- 不为搜索结果分配新 `CatalogRevision`；
- page count = `ceil(resultCount / itemsPerPage)`，0 结果 = 0 页；
- 页内 slot 按过滤后的全局结果索引稳定生成；
- 不得把原 catalog 数组 index 当作稳定身份；AppID 仍是业务身份；
- query 改变时优先保持当前可见/焦点 AppID（如仍在结果中）；否则 successor → predecessor → clamped → empty；
- 本阶段采用“连续性优先”：不强制每次 query 都跳到第 0 页，而是按稳定 anchor 映射到搜索结果页；
- 若产品决定改为“每次回第 0 页”，必须先解决安全 programmatic page reset，不得通过临时缩小 pageCount 、重建 Core 或直改 committedPage 实现。

---

## 7. 搜索 UI 与键盘语义

### 7.1 搜索框

- 搜索框使用公开 AppKit 控件和系统字体/颜色，不引入任何第三方品牌或旧产品视觉；
- 它是全屏窗口的固定 overlay/sibling，不随页面容器左右平移；
- 必须有可访问 label，例如中性“Search applications”；
- 点击 field、field editor、clear button 或其子视图不触发空白单击退出；
- 搜索框不遮挡搜索结果网格、页标签或可访问导航。

### 7.2 Responder 和快捷键

```text
Command-F
  → 搜索框成为 first responder
  → 清除旧网格视觉焦点，避免双焦点

Escape（搜索框有非空 query）
  → 清空 query，恢复全 catalog，保持搜索框 first responder

Escape（query 已空）
  → 离开搜索框
  → 恢复 Phase 1C KeyboardFocusController first responder
  → 保持延迟焦点，不自动冒出选择框

↓ 或 Return/Enter（搜索框中，有已提交结果）
  → 仅把焦点转移到当前已显示页第一个有效结果
  → 第一次不直接启动，避免无视觉选择的意外启动
  → 网格焦点已建立后，再按 Return/Enter 走现有启动管线

Tab
  → 交给 AppKit responder chain，不非法吞键
```

搜索框没有已提交结果或尚有 pending generation 时，Return/Enter 不得启动旧结果。

本阶段应顺带关闭 Phase 1C F3 follow-up：搜索进入/退出、窗口重新成为 key window 或焦点被系统控件暂时夺走后，可以按明确规则重建正确 first responder，而不是只在初始接线时设置一次。

### 7.3 鼠标与触控板

- 搜索结果 cell 的单击启动不变；
- 搜索结果多页时，真实触控板仍使用现有分页引擎；
- 不把 search field 变成全局键盘监听；
- 不修改空白点击的已通过产品语义，只将搜索控件显式归类为“交互区”。

---

## 8. 架构硬约束

### 8.1 PagingCore 保持冻结

严格禁止修改：

```text
/Users/mac/Projects/Launch_Copy/PagingPrototype/Sources/PagingCore/
```

搜索不得：

- 直接改 `committedPage`、`visualOffset` 或 transition token；
- 重建 Core 以强行回第 0 页；
- 用 pageCount 先缩到 1 再恢复的方式伪造搜索重置；
- 改分页阈值、惯性、过冲、边界、settle 时长或帧驱动。

### 8.2 CatalogRevision 单一拥有者不变

`CatalogRepository` 仍是 `CatalogRevision` 唯一分配者。query 每次变化不得：

- mint 假 revision；
- 将 query hash 塞进 revision；
- 把 query generation 冒充 snapshot revision；
- 通过数值编码让 revision 看似单调。

必须区分：

```text
baseCatalogRevision   // 来自 CatalogRepository
queryGeneration       // 搜索控制器内部 latest-wins token
presentationRecords   // 当前已提交的过滤记录
```

### 8.3 同 revision reload seam

现有 `PagingSurface.refreshPresentation()` 主要为“provider revision 变化”设计。Phase 1D 需要一个窄的、可测的同 revision 重载 seam，例如独立命名的：

```text
reloadCurrentPresentation()
```

具体命名由 ADR 决定，但语义必须是：

- idle/cancelled：从 provider 读取当前 `servedPageCount` 和同 revision 内容，原子更新 pageCount + live hosts；
- tracking/settling/interrupted：只记录 latest pending reload，到 idle/cancelled 再一次应用；
- 不丢失已有 pending catalog revision；
- 不让旧 same-revision reload 覆盖新 catalog revision；
- 强制重渲染必须使旧图标回调无法写入新 query 的 cell；
- teardown 后零写回。

只允许修改 `PagingUI` 中这个窄 seam 及相关测试；不得借机重写分页架构。

### 8.4 七字段 binding token 默认保持

首选方案不扩展 `ItemBindingToken` 七字段契约。同 revision query reload 必须通过：

- re-render 导致 view `surfaceGeneration` bump；
- appID/slot/iconKey 全字段重绑定；
- 旧图标回调被 generation/token 拒绝；
- 达成 UI 上 stale apply = 0。

必须用乱序图标回调测试证明这些防线足够。如测试证明七字段无法表达搜索代隔，停止并提交 ADR/Chief 决策，不得自行加第八字段。

---

## 9. 推荐状态模型

### 9.1 纯搜索域

建议在 `AppGridUI` 新增 Foundation-only 值类型（文件名可调整）：

```text
AppSearchQuery
AppSearchGeneration
AppSearchResultSet
AppSearchMatcher
AppSearchState
```

`AppSearchResultSet` 至少包含：

```text
baseCatalogRevision
queryGeneration
records       // 保留基础 snapshot 顺序
resultCount
```

不实现可逆向输出 AppID 原文的 debug description。

### 9.2 搜索控制器

建议实现一个可注入 scheduler/clock/filter executor 的控制器：

```text
query edit
  → generation +1
  → cancel/coalesce previous work
  → filter immutable base snapshot off the animation-frame path
  → result(baseRevision, generation)
  → validate latest generation + latest base revision
  → stage pending result if PagingSurface busy
  → commit once at idle boundary
```

如实测显示当前 catalog 纯同步过滤足够快，可以保持同步纯函数，但必须：

- 不在 frame callback 内执行；
- 有大型合成 catalog 性能证据；
- 不因为“应用一般不多”而无证据地忽略上界。

如加 debounce，参数必须可配置、来源标为 `PRODUCT_DECISION` 或 `INDEPENDENT_EXPERIMENT`，记入参数文档；不得使用未经证明的旧产品常量。

### 9.3 结果呈现

`AppGridUIPageContentProvider` 或一个窄包装器应区分：

```text
baseSnapshot             // 完整目录，来自 refresh commit
presentationRecords      // 完整目录或搜索结果
pendingCatalogSnapshot   // 已有 latest-wins 语义
pendingSearchResult      // 同 revision 的 latest query result
```

必须保证：

- `servedRevision` 仍是 `baseSnapshot.revision.value`；
- `servedPageCount` 基于 `presentationRecords`；
- `content(for:)` 仅命中已提交呈现，不读 pending；
- catalog refresh commit 后，在新 base snapshot 上重新计算当前 query；
- 空 query 将 `presentationRecords` 恢复为 base records；
- 无结果时 pageCount = 0，但 search field 仍可交互以便清除或修改 query。

---

## 10. UI 状态与优先级

搜索状态不得与 catalog 扫描状态混为同一含义。至少区分：

```text
catalog loading
catalog refreshing with old content retained
catalog empty
catalog partial failure
search inactive / empty query
search active with results
search active with zero results
search result pending apply
```

推荐呈现优先级：

1. 未有任何成功 catalog 时的 initial loading；
2. base catalog 真空：“No applications found”类中性状态；
3. base catalog 非空 + active non-empty query + 0 结果：“No matching applications”类中性状态；
4. refreshing/partial failure 不得清空已提交的旧结果；
5. pending query 不得偷偷让旧结果成为 Return 启动对象。

空状态文案不包含 query 原文，避免日志、截图工件或可访问公告中不必要复制用户输入。搜索框自身显示用户正在编辑的文本是必要 UI 行为，不属于 telemetry 记录。

---

## 11. 生命周期与并发矩阵

必须有自动化证据覆盖：

1. 连续快速输入 `q1 → q2 → q3`，q1/q2 乱序完成，只 q3 可提交；
2. query 过滤进行中 catalog refresh 到新 revision，旧 revision 结果被拒绝；
3. catalog refresh 完成时 query 仍激活，在新 snapshot 上重跑最新 query；
4. 触控板 tracking 中 query 结果完成，当前页不中途换内容；
5. settling/interrupted 中多个 query 结果完成，idle 只应用最新一个；
6. query 变化导致 pageCount 缩小，committed page 合法 clamp，焦点不指向消失页；
7. 当前焦点 AppID 仍在结果中时保留；不在时按明确降级；
8. 搜索结果 re-render 与旧图标回调乱序，旧图标零错写；
9. resize 时 search field 与结果页几何正确；
10. `Escape` 清空/退出后 first responder 和延迟焦点正确；
11. 窗口 resign/become key 后 first responder 可按状态重建；
12. teardown 发生在 debounce/filter/pending apply 之前，此后零 UI 写回、零启动、零日志原文；
13. 重开窗口后不恢复上一次 query（本阶段无持久化）。

---

## 12. 启动安全不变

搜索只改变“当前呈现哪些 AppID”，不改变启动授权边界。

搜索结果的所有启动必须复用：

```text
AppLaunchController.handleCell(_:) / 已有统一入口
  → token.catalogRevision == provider.servedRevision
  → AppID 仍在当前权威 URL resolver
  → 文件仍存在
  → NSWorkspace 公开 API
  → 失败非致命
```

禁止：

- 搜索控制器从 cell 直接取 URL 并调 `NSWorkspace`；
- 搜索为了启动另建并行 validation path；
- 将过滤 snapshot 当成新权威磁盘目录；
- pending query 期间启动已不可见的旧 cell。

`AppLaunchController.swift` 默认保持不变。如确实需要提取更通用的已有入口，先以 `BLOCKED` 返回 Main/Chief，不得由搜索 Worker 顺手改。

---

## 13. 隐私红线

搜索是用户输入功能，隐私红线必须比 Phase 1B/1C 更严格。

不得记录或输出到 telemetry、JSONL、stdout/stderr、`os_signpost`、profile、错误报告、Workflow evidence 或持久文件：

```text
query 原文
query 规范化文本
搜索历史
搜索结果 app 名称
bundle ID
AppID 原文
应用路径 / URL
图标数据
窗口标题
其他用户输入内容
```

允许的中性运行时统计仅限进程内存或经审批的数值计数，例如：

```text
query generation count
result count
stale search result rejected count
search apply duration (numeric only)
```

本阶段默认**不修改 PagingTelemetry schema**。如不影响验收，只用可注入记录器的内存计数做测试。

必须新增至少四层隐私测试：

1. 事件 key allow-list；
2. 类型/属性表面检查；
3. 敏感哨兵 query/app/path 不出现在 JSONL/stdout；
4. teardown 后不会延迟写出 query。

---

## 14. 性能纪律

1. 不在触控板 input/frame callback 中过滤 catalog；
2. 不在 `content(for:)` 中扫描磁盘、读 Bundle、加载图标、等待异步或重算全量 query；
3. `content(for:)` 继续只做已提交内存结果的切片；
4. 每次 query edit 不重建整棵 view tree；
5. 只有结果提交时重绑必要 live page/cell；
6. 旧图标任务可被 token/generation 拒绝，不得为每次键入全量 purge 图标 cache；
7. 对小/中/大合成 catalog 记录过滤和应用耗时，但不使用不稳定 wall-clock 阈值伪造硬 PASS；
8. 保留既有触控板帧节奏证据，但不将搜索优化写成旧卡顿修复。

推荐性能证据：

- 100 / 1,000 / 10,000 条纯合成 displayName 过滤；
- 快速连续 query 的 completion/rejection 计数；
- query 提交时 live page/host/cell 数上界；
- 搜索结果冷/暖图标管道完成与 stale rejection；
- 真实搜索结果多页触控板主观复测。

---

## 15. 推荐模块和写入拆分

最终文件名由 Chief 在 `Workflow/PLAN.md` 确认。以下是为了并发隔离的建议，不是允许 Worker 自行改范围。

### Worker A — 纯搜索域

可写：

```text
Sources/AppGridUI/AppSearchQuery.swift
Sources/AppGridUI/AppSearchMatcher.swift
Sources/AppGridUI/AppSearchResultSet.swift
Tests/AppGridUITests/AppSearch*.swift
Workflow/results/T-1D-A.md
```

职责：规范化、字面包含匹配、稳定顺序、generation/revision 值类型、纯单元测试。

### Worker B — provider/search presentation

可写：

```text
Sources/AppGridUI/AppGridUIPageContentProvider.swift
Sources/AppGridUI/AppGridSearchPresentationController.swift
Sources/AppGridUI/AppGridUIState.swift
Sources/AppGridUI/AppGridStatusView.swift
Tests/AppGridUITests/*SearchPresentation*.swift
Workflow/results/T-1D-B.md
```

职责：base snapshot / presentation records / pending search result / refresh recompute / no-results state。

### Worker C — PagingUI 同 revision reload seam

可写：

```text
Sources/PagingUI/PagingSurface.swift
Tests/PagingUITests/PagingSurfaceSearchReloadTests.swift
Workflow/results/T-1D-C.md
```

职责：窄 seam、idle/pending latest-wins、pageCount 更新、同 revision re-render、stale icon 防线对接证据。不得修改 `PagingCore`。

### Worker D — AppKit search UI/responder

可写：

```text
Sources/PagingPrototypeApp/AppSearchController.swift
Sources/PagingPrototypeApp/AppSearchFieldView.swift
Sources/PagingPrototypeApp/KeyboardFocusController.swift（只在任务明确分配后）
Tests/PagingUITests/AppSearchControllerTests.swift
Tests/PagingUITests/AppSearchResponderTests.swift
Workflow/results/T-1D-D.md
```

职责：`Command-F`、first responder 转移/恢复、Escape/Down/Return 语义、F3 follow-up、teardown 零回调。

### Integration Worker E — 装配、空白点击和启动集成

必须等 A–D 稳定后串行执行。可写：

```text
Sources/PagingPrototypeApp/AppDelegate.swift
Sources/PagingPrototypeApp/AppCatalogAssembly.swift（只限搜索接线）
Tests/PagingUITests/AppSearchIntegrationTests.swift
Tests/PagingUITests/BlankClickToQuitTests.swift
Workflow/results/T-1D-E.md
```

职责：全局装配、search field overlay 几何、交互区命中分类、现有单击/键盘启动管线复用、真实 GUI 启动准备。

### Main 独占

```text
Package.swift
Docs/ADR-007-SEARCH-PRESENTATION.md
Docs/PHASE1D_SPEC.md
Docs/PHASE1D_VALIDATION_PLAN.md
Docs/PHASE1D_REPORT.md
Docs/VALIDATION_RESULTS.md
Docs/PRIVACY_DATA_MAP.md
PROVENANCE/*
Workflow/STATE.json
Workflow/events.jsonl
```

本阶段推荐不新增 Swift target，因此不应需要改 `Package.swift`。如 Worker 认为必须新建 target/依赖，返回 Main，不得自行修改。

### Reviewer

Reviewer 只读，不修改实现文件。必须独立检查：

- 原始 Prompt + task packet + 实际 diff；
- 测试是否真执行；
- CatalogRevision 是否被伪造；
- query 是否泄漏；
- 同 revision reload 是否破坏 pin/latest-wins；
- 搜索结果启动是否绕过原管线；
- search field 点击是否被错判为空白退出；
- 触控板、键盘、图标复用、refresh、teardown 是否回归；
- 禁止来源、品牌、资产、私有 API 扫描；
- 自动化 PASS 是否被误写为真实 GUI PASS。

---

## 16. 测试要求

### 16.1 搜索域

至少覆盖：

- 空 query / 纯空白 / 换行 query 返回完整 catalog；
- case-insensitive；
- diacritic-insensitive；
- width-insensitive；
- substring 匹配；
- 不匹配 bundle ID/path/URL/AppID；
- 不做拼音/模糊/首字母扩展；
- 结果顺序 = base snapshot 子序列；
- 0/1/35/36/70 结果分页；
- 固定 Locale 下输出确定；
- query generation 单调；
- 旧 generation / 旧 catalog revision 结果拒绝。

### 16.2 provider/presentation

- 空 query = base records；
- non-empty query = filtered records；
- `servedRevision` 不因 query 变化；
- page count 基于 result count；
- content 只命中已提交 result；
- pending search 不泄露到当前手势页；
- query 快速变化 latest-wins；
- catalog refresh + active query 重跑；
- anchor 保留/降级；
- base catalog empty 与 no search results 状态区分。

### 16.3 PagingUI 同 revision reload

- idle 立即 reload；
- tracking/settling/interrupted 只 pending；
- 多次 pending 只应用最新；
- 新 catalog revision 优先级高于旧 same-revision reload；
- pageCount 缩小/0/1/多页；
- host/view 数上界不变；
- query 变化后旧图标乱序回调零错写；
- teardown 零回调。

### 16.4 AppKit/responder

- `Command-F` 搜索框成为 first responder；
- 旧网格焦点视觉清除；
- Escape 非空先清 query；
- Escape 空 query 退出并恢复 KeyboardFocusController；
- 恢复后仍是延迟焦点；
- Down/Return/Enter 在 field 中只把焦点转到首个已显示结果，不意外启动；
- 网格焦点后 Return/Enter 启动一次；
- Tab/未支持按键不被非法吞掉；
- window resign/become key 后 first responder 恢复；
- no-results 时不建立伪焦点、不启动；
- resize/teardown 安全。

### 16.5 空白单击和启动

- search field 本体/editor/clear button/子视图点击不退出；
- result cell/icon/label 点击继续启动；
- 背景空白首个已接收点击仍退出；
- stale revision 搜索结果拒绝启动；
- AppID 消失/文件消失/启动失败与 Phase 1B/1C 结果一致；
- 鼠标和键盘仍共享同一 validation funnel。

### 16.6 隐私和性能

- 敏感 query 哨兵不出现在 JSONL/stdout/profile/report；
- 不搜 bundle ID/path；
- query 不持久化；
- 快速 query 旧结果拒绝计数正确；
- 大型合成 catalog 不在 frame callback 过滤；
- 搜索应用不导致 live host/cell 无上界增长；
- 图标 cache 不因每次 query 全量 purge。

### 16.7 全量回归

Main 最后必须执行：

```bash
swift test
swift build -c debug
swift build -c release
```

如项目保留 Python analyzer tests，执行当前适用的 Python 测试；但不把 analyzer PASS 扩大为搜索 GUI 或触控板物理 PASS。

---

## 17. 真实 GUI + 物理键盘/触控板验收

自动化和合成 NSEvent 不能代替真实验收。由用户在重新拉起的真实全屏 App 中执行：

1. `Command-F` 立即进入搜索框，无双焦点框；
2. 输入应用名子串，结果更新正确；
3. 大小写与可验证的重音符号场景符合规格；
4. 无结果显示中性空状态，搜索框仍可编辑；
5. Escape 第一次清查询，再次退出搜索框；
6. Down/Return/Enter 把焦点转到结果，再 Return/Enter 启动正确 App；
7. 单击搜索框、clear button 不退出；单击结果可启动；
8. 单击真实背景空白仍首击退出；
9. 选一个可产生多页结果的宽查询，用真实触控板和方向键跨页；
10. 搜索多页下无错页、重复、旧名、旧图标或焦点错位；
11. 清空搜索后回到完整 catalog，键盘/触控板仍正常；
12. 关闭/重开后 query 不恢复，无残留回调。

用户回填至少区分：

```text
MANUAL_SEARCH_GUI_GATE
MANUAL_SEARCH_KEYBOARD_GATE
MANUAL_SEARCH_TRACKPAD_PAGING_GATE_60HZ
MANUAL_BLANKCLICK_REGRESSION_GATE
MANUAL_120HZ_GATE
```

没有用户真实操作时写 `NOT_RUN`，不得写 PASS。当前硬件仍是 60Hz 固定面板时，120Hz 保持 `BLOCKED_BY_HARDWARE`。

本阶段不允许因搜索手感问题直接改 PagingCore 参数。若搜索结果页的触控板体验回归，先保留 telemetry 和用户复现证据，另立 repair task。

---

## 18. Workflow 和多代理纪律

项目已启用 Main/Chief/Worker/Reviewer workflow。必须按 `AGENTS.md` 执行。

1. Main 先让 Chief 读本 Prompt 和当前项目状态，生成 Phase 1D `Workflow/PLAN.md`、`MAIN_BRIEF.md` 和 task packets；
2. Chief 先决定 `ADR-007` 的 provider/filter/reload 架构，不让 Worker 各自发明不兼容协议；
3. `subagent_mode = ENABLED` 时，每个 Worker/Reviewer/repair wave 必须重复并发检查；
4. 只有依赖已满足、写入范围互斥、测试资源隔离时才并发；
5. 不并发时记录具体原因，不能默认串行不说明；
6. Worker 只实现一个有界任务，不得改全局验收标准，不得自证 PASS；
7. Reviewer 只读，不修改实现；
8. Reviewer 正式 FAIL 才进入已定义 repair/escalation 策略；
9. 每个缺陷/改动单独建 task，Main 不得在无 task/Reviewer 的情况下顺手修代码；
10. `events.jsonl` append-only，使用 `python3 record_workflow_event.py` 或 skill 指定的脚本，不手写历史 event；
11. `active_agent_jobs` 必须与真实 agent 状态一致；
12. 完成 task 必须有 Worker result、独立 Reviewer PASS、Main 最终验证和状态记录。

推荐运行时 DAG：

```text
Gate 0
  → Chief / ADR-007 / Phase1D task packets
  → [A 纯搜索域] || [C PagingUI reload seam]
  → B provider/presentation（依赖 A，对接 C 契约）
  → D AppKit search/responder（依赖 A/B/C 稳定协议）
  → E AppDelegate/assembly/blank-click/launch integration
  → independent Reviewer waves
  → Main full verification
  → user real GUI/keyboard/trackpad gates
  → Phase 1D final report
```

---

## 19. 必须交付的文档

```text
Docs/PHASE1D_SPEC.md
Docs/ADR-007-SEARCH-PRESENTATION.md
Docs/PHASE1D_VALIDATION_PLAN.md
Docs/PHASE1D_REPORT.md
Docs/PHASE1C_BASELINE_MANIFEST.sha256（或经 Main 决定的等价名称）
Docs/VALIDATION_RESULTS.md 追加 Phase 1D 状态
Docs/PRIVACY_DATA_MAP.md 追加 search query 内存边界
Docs/PARAMETER_RATIONALE.md 追加任何 debounce/搜索参数
PROVENANCE/COMPONENT_INVENTORY.md 追加 Phase 1D 文件
Workflow/tasks/T-1D-*.md
Workflow/results/T-1D-*.md
Workflow/reviews/T-1D-*-r*.md
```

`ADR-007` 至少比较并记录：

1. 修改现有 provider 持有 base/presentation records；
2. 用 search-filtering provider 包装现有 provider；
3. same-revision reload 如何不破坏 catalog revision 单一拥有者；
4. query generation 与 catalog revision 的独立性；
5. busy-state pending 与 catalog refresh 优先级；
6. 焦点/anchor/pageCount 收缩规则；
7. 七字段 binding token 是否足够；
8. search field 与 blank-click window dispatch 边界；
9. 为何不修改 PagingCore；
10. 隐私、无持久化与无 Spotlight 决策。

---

## 20. 停止条件

遇到以下任一项，停止相关实现扩大，保存证据并返回 Main/Chief：

- Gate 0 不是当前绿色基线；
- 需要修改 `Sources/PagingCore/`；
- 需要伪造 `CatalogRevision`；
- 同 revision reload 无法不破坏 pin/latest-wins；
- 七字段 token 无法拒绝旧 query 图标写回；
- 需要搜索 bundle ID/path/URL 才能达到主目标；
- 需要 Spotlight/FDA/Accessibility/Input Monitoring/全局 monitor；
- 需要新建磁盘索引或持久化 query；
- 需要绕过 `AppLaunchController` 才能启动结果；
- 搜索框的 hit testing 会破坏触控板 `scrollWheel` 路由；
- query 原文不可避免地进入 telemetry/log/profile；
- 需要读取禁止来源或复制第三方资产；
- 需要改 Timer tolerance/帧源/分页参数才能让搜索测试变绿；
- Worker 写入范围与其他 active task 冲突；
- `exit_code == 0` 但测试执行数为 0；
- 真实 GUI 暴露搜索输入、焦点、空白点击或分页路由缺陷。

停止不等于项目失败。应记录阻塞、受影响范围、已保存证据和最小下一步，不得为了“继续”制造伪根因或弱化验收。

---

## 21. Phase 1D 完成门

只有以下全部有证据时，才可以写：

```text
PHASE_1D_AUTOMATED_PASS
```

- Gate 0 当前基线 PASS；
- 纯搜索域规则与测试完整；
- query generation + catalog revision latest-wins 有乱序测试；
- query 不伪造 CatalogRevision；
- same-revision reload 在 idle/busy/teardown 下正确；
- 搜索结果 0/1/35/36/多页正确；
- stale icon apply = 0 或全部被可观测拒绝，不得错写 UI；
- Command-F/Escape/Down/Return/Enter/responder 测试完整；
- search field 与 blank-click 路由正确；
- 启动复用现有统一 validation path；
- 隐私红线测试无泄漏；
- 当前全量 Swift 测试、Debug/Release build PASS；
- `PagingCore` 未修改；
- Reviewer 独立 PASS；
- 所有修改文件无 conflict marker/trailing whitespace 问题；
- 未 commit/push/tag/reset/clean/release。

只有用户在真实全屏 GUI + 物理键盘 + 真实触控板执行第 17 节后，才可额外写：

```text
MANUAL_SEARCH_GUI_GATE = PASS_USER_REPORTED_WITH_EVIDENCE
MANUAL_SEARCH_KEYBOARD_GATE = PASS_USER_REPORTED_WITH_EVIDENCE
MANUAL_SEARCH_TRACKPAD_PAGING_GATE_60HZ = PASS_USER_REPORTED_WITH_EVIDENCE
```

无用户物理复测时只能写 `NOT_RUN`。

Phase 1D 不得把以下状态写成 PASS：

```text
PINYIN_SEARCH_COMPLETE
FUZZY_SEARCH_COMPLETE
FOLDER_COMPLETE
DRAG_REORDER_COMPLETE
HOT_CORNER_COMPLETE
120HZ_VALIDATED
ROOT_CAUSE_FOUND
ALL_HITCHES_FIXED
FIX_VALIDATED
```

阶段最终报告只能给出一个主建议：

```text
RECOMMEND_PROCEED_TO_PHASE_1E
RECOMMEND_REWORK_PHASE_1D
BLOCKED_PENDING_USER_OR_HARDWARE
```

搜索通过不代表后续 Phase 1E 必须是文件夹；下一阶段仍应根据用户产品优先级单独决策。

---

## 22. 给 Main 的启动指令

1. 读本 Prompt 和第 2 节权威文件；
2. 检查当前 worktree、Workflow state、active agent jobs 和真实 526 基线；
3. 完成 Gate 0，生成 Phase 1C 基线 manifest/hash；
4. 让 Chief 重写 `Workflow/PLAN.md`/`MAIN_BRIEF.md`，不沿用 Phase 1C 过时计划；
5. 先完成 `ADR-007-SEARCH-PRESENTATION.md`，锁定 base snapshot/presentation records/query generation/same-revision reload 契约；
6. 每个 Worker wave 记录并发检查和写入边界；
7. 先纯域与 reload seam，再 provider，再 AppKit responder，最后 AppDelegate integration；
8. Worker 完成后用独立 Reviewer 审查实际 diff 和测试；
9. Main 最后执行全量 Swift/Python 适用测试、Debug/Release build、隐私/来源/冲突/空白扫描；
10. 把自动化、Reviewer、真实 GUI、60Hz 触控板、120Hz 硬件和卡顿因果状态分开报告；
11. 等待用户按第 17 节复测，未复测时不得写物理 PASS；
12. 不修改禁止项目、不读禁止来源、不自动提交或发布。

**最终原则：搜索只是 catalog 之上的独立呈现切片。它不是新 catalog，不是新启动授权边界，不是分页核心重写，也不是已有帧卡顿的修复。**
