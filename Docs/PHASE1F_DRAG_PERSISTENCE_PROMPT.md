# Phase 1F Prompt — 拖拽编排、文件夹变更与本地持久化

> 创建日期：2026-08-30（Asia/Tokyo）
> 项目：`PagingPrototype`
> 项目路径：`/Users/mac/Projects/Launch_Copy/PagingPrototype/`
> 阶段建议：**Phase 1F = Drag & Persistence vertical slice**
> 性质：下一阶段的自包含开发 Prompt；不是已完成报告、不是发布授权，也不是对任何旧产品内部实现的复刻要求。

---

## 0. 任务身份与总目标

你是本阶段的 Main/Orchestrator。请先读取项目当前状态，再让 Chief 形成 Phase 1F 的正式计划和 ADR。用户、本 Prompt、历史文档与任何 Reviewer 判断都可能不完整；不得机械附和，也不得为了推进而把假设写成事实。

本阶段只增加一个主要产品变量：

> **让用户通过本应用自己的拖拽和等价无障碍操作重新排列顶层应用/文件夹，创建文件夹、把应用移入或移出文件夹、调整文件夹内顺序和跨页位置，并把逻辑布局安全地保存到本机，在重新启动及目录刷新后恢复。**

必须保持既有分页、搜索、文件夹打开层、键盘焦点、启动校验、目录刷新、页面复用、隐私和来源纪律。

本阶段不是：

- Finder 文件拖放；
- 系统 Launchpad/Dock 布局读写；
- 云同步；
- Hot Corner；
- 正式品牌视觉；
- 安装、签名、公证或发布。

必须严格分开记录：

```text
当前磁盘事实
用户实机验收事实
自动化测试事实
架构/产品决策
受支持推断
未解决问题
隐私与持久化风险
物理 GUI 验收
```

---

## 1. 当前权威起点与 Gate 0 对账

### 1.1 已完成能力

- Phase 1A：分页状态机、触控板跟随、settle、中断、边界反馈和页面复用；
- Phase 1B：本机应用目录、不可变 catalog snapshot、运行时图标、真实网格、刷新和启动；
- Phase 1C：键盘焦点、方向键、Return/Enter、ESC、全屏和空白单击；
- Phase 1D：纯内存应用名搜索及搜索结果分页；
- Phase 1E：顶层 app/folder 统一呈现、文件夹打开层、内部分页、标题编辑、搜索/刷新/启动集成和打字机式键盘导航。

当前已记录的最新自动化证据为：

```text
789 tests, 0 failures
Debug build = PASS
Release build = PASS
```

该数字来自 Phase 1E 打字机波次的 Worker/Reviewer 记录，不是 Phase 1F 编写会话重新执行的结果。Gate 0 必须重新运行并记录实际数字。

### 1.2 Phase 1E 收尾不一致

开始任何 Phase 1F 产品代码前，先基于真实 task/result/review/event 做对账，不得补造历史：

1. `Workflow/STATE.json` 的 `T-1E-folder-open-repair` 仍显示 `EXECUTING`，而其拆分任务已有 PASS 证据；
2. `workflow_status` 仍为 `ACTIVE`；
3. `next_action` 仍写 Phase 1E 手动门 pending；
4. `Docs/PHASE1E_REPORT.md`、`PHASE1E_SPEC.md`、`PHASE1E_VALIDATION_PLAN.md`、`VALIDATION_RESULTS.md`、`PROVENANCE/COMPONENTS.md` 仍主要停在 756 tests；
5. 打字机波次最终证据为 789/0，并有 `decision_recorded` sequence 511；
6. `Docs/ADR-006-KEYBOARD-FOCUS.md` §9 标题日期写为 2026-08-31，而事件发生于 2026-08-30 22:23 JST；先判断是否为日期笔误再修正；
7. 用户已报告全屏打字机实机验收“没问题了”，但是否覆盖完整 `MANUAL_TRACKPAD_60HZ_REGRESSION_GATE` 必须按原始验收范围记录，不能从键盘验收自动推导。

允许的对账结果：

```text
PHASE_1E_FUNCTIONALLY_ACCEPTED
PHASE_1E_WORKFLOW_RECONCILED
```

若触控板门没有明确证据，可以保持：

```text
PHASE_1E_KEYBOARD_AND_FOLDER_GUI_ACCEPTED
PHASE_1E_TRACKPAD_60HZ_REGRESSION_PENDING
```

这不必阻止 Phase 1F 纯规划，但必须进入 Phase 1F 的回归门。

### 1.3 Timer 与长尾诊断边界

当前基线保持：

```text
PRODUCT_TIMER_TOLERANCE_0MS
SHORT_TAIL_MITIGATED_BY_TOLERANCE
CAUSALITY_UNRESOLVED_FOR_GT25MS
```

边界：

- `SHORT_TAIL_MITIGATED_BY_TOLERANCE` 只覆盖 20–25ms 短尾；
- 严格 `>25ms` 长尾根因仍未解决；
- Phase 1F 不调整 Timer tolerance、分页阈值、动量参数或默认帧源；
- 不得宣称 `ALL_HITCHES_FIXED`、`ROOT_CAUSE_FOUND`、`FIX_VALIDATED`；
- 拖拽性能验收只能说明本阶段是否引入回退，不能扩大为全部卡顿因果结论。

### 1.4 Gate 0 命令与冻结

必须执行：

```bash
swift test
swift build -c debug
swift build -c release
```

要求：

- exit 0 且 executed tests > 0；
- 记录真实 executed/passed/failed 数；
- 记录当前 Debug/Release executable SHA-256；
- 创建 `Docs/PHASE1F_BASELINE_MANIFEST.sha256`；
- 当前无 commit、大量文件 untracked，不能只用 `git diff --check` 证明清洁；
- 对本阶段实际修改文件额外扫描 trailing whitespace、冲突标记和禁止来源路径。

---

## 2. 必读文件与禁止来源

执行前至少读取：

```text
/Users/mac/Projects/Launch_Copy/PagingPrototype/AGENTS.md
/Users/mac/Projects/Launch_Copy/PagingPrototype/MEMORY.md
/Users/mac/Projects/Launch_Copy/PagingPrototype/Workflow/config.json
/Users/mac/Projects/Launch_Copy/PagingPrototype/Workflow/STATE.json
/Users/mac/Projects/Launch_Copy/PagingPrototype/Workflow/events.jsonl
/Users/mac/Projects/Launch_Copy/PagingPrototype/Workflow/PLAN.md
/Users/mac/Projects/Launch_Copy/PagingPrototype/Workflow/MAIN_BRIEF.md
/Users/mac/Projects/Launch_Copy/PagingPrototype/Docs/PHASE1E_REPORT.md
/Users/mac/Projects/Launch_Copy/PagingPrototype/Docs/PHASE1E_SPEC.md
/Users/mac/Projects/Launch_Copy/PagingPrototype/Docs/PHASE1E_VALIDATION_PLAN.md
/Users/mac/Projects/Launch_Copy/PagingPrototype/Docs/ADR-004-APP-CATALOG-SNAPSHOT.md
/Users/mac/Projects/Launch_Copy/PagingPrototype/Docs/ADR-006-KEYBOARD-FOCUS.md
/Users/mac/Projects/Launch_Copy/PagingPrototype/Docs/ADR-007-SEARCH-PRESENTATION.md
/Users/mac/Projects/Launch_Copy/PagingPrototype/Docs/ADR-008-FOLDER-PRESENTATION.md
/Users/mac/Projects/Launch_Copy/PagingPrototype/Docs/PRIVACY_DATA_MAP.md
/Users/mac/Projects/Launch_Copy/PagingPrototype/Docs/PARAMETER_RATIONALE.md
/Users/mac/Projects/Launch_Copy/PagingPrototype/PROVENANCE/ACCESS_DECLARATION.md
/Users/mac/Projects/Launch_Copy/PagingPrototype/PROVENANCE/CONTAMINATION_LOG.md
/Users/mac/Projects/Launch_Copy/RISK_REDUCTION_PLAN.md
```

严禁读取、使用或复制：

```text
/Users/mac/Projects/LaunchBetter/
/Users/mac/Projects/BuhoReverseNotes/
/Users/mac/Projects/LaunchBetter/Docs/aegis/work/2026-08-25-buho-launchpad-reverse/
任何反编译 dump、地址映射、旧源码、旧测试、旧类图、截图、资源、文案或精确参数簇
```

实现依据仅限：

1. 本 Prompt 的可观察需求；
2. 当前 `PagingPrototype` 自身源码、测试、ADR 和实测记录；
3. Apple 公开 API/公开文档；
4. 本阶段独立设计和实验。

优先使用不继承逆向上下文的新 Worker。如实际已有接触，必须标 `PRIOR_EXPOSURE`；不得虚构严格 clean-room 历史。

---

## 3. Phase 1F 必须完成的产品能力

### 3.1 逻辑布局模型

建立独立、纯逻辑、可测试的 workspace layout 模型，至少表达：

- 顶层有序条目：app 或 folder；
- folder 稳定身份、标题及有序成员；
- 未分组应用顺序；
- layout generation / mutation generation；
- 当前 catalog 可用性与持久化逻辑布局的区别；
- 拖拽 session identity 与 stale 防线；
- mutation 的成功、拒绝、取消和无变化结果；
- 所有布局不变量与校验错误。

核心不变量：

1. 同一逻辑 app reference 在可见布局中最多出现一次；
2. folder 不嵌套；
3. folder 只包含 app，不包含 folder；
4. 空 folder 不存在；
5. 用户主动变更后单成员 folder 按 Phase 1E 决策 dissolve；
6. 拖拽不删除、移动或修改真实 `.app` 文件；
7. 拖拽不创建第二条应用启动路径；
8. 失败 mutation 不产生半提交状态；
9. layout generation 与 `CatalogRevision`、`FolderGeneration`、search generation、surface generation 分离；
10. UI 只消费已提交 layout，不读取半写入状态。

静态源码审查已经暴露出三个必须先消除的架构缺口：

1. Phase 1E 的 `FolderSnapshot` 只是当前 folder 呈现快照，不能表达 app/folder 任意交错的完整顶层顺序，也会在 catalog rebase 时收缩暂缺成员；**不得把它直接 Codable 后落盘**；
2. 现有 `TopLevelComposition` 的“folders + 未分组 apps”派生顺序不是用户布局真相源；
3. mixed-entry remap 中的 `hashValue` 只适合进程内散列，跨进程不稳定，不能参与持久顺序、恢复顺序或冲突裁决。

因此至少建立并明确所有权：

```text
PersistentWorkspaceLayout             用户期望布局，唯一持久真相源
PersistentAppReference                独立 DTO，不等同于 AppID
VisibleWorkspaceProjection            expected layout + current catalog 的派生可见投影
LayoutGeneration                      只属于逻辑布局
LayoutMutation(expectedGeneration:)   唯一写入口
PresentationAnchor                    重排/解散后的稳定落点，不依赖 hashValue
```

只有明确成功的用户 mutation 才能改变 `PersistentWorkspaceLayout`。catalog refresh、部分扫描、app 暂时缺失、视觉 dissolve 和 search projection 只能改变派生可见投影，不能反向删改期望布局。

### 3.2 顶层重排

支持：

- app 在同页内改变位置；
- app 跨页改变位置；
- folder 在顶层重排；
- app 与 folder 互换前后位置；
- 拖到列表开头/末尾；
- 部分页、空插槽和 page count 变化；
- 顶层顺序在退出/重开后恢复。

要求：

- drop insertion 位置明确、可视；
- 未发生有效位移的 drop 是 no-op，不写盘；
- reorder 不改变 app identity、folder identity 或 catalog revision；
- 新扫描到的应用按 ADR 规定追加到确定位置，不随机打乱用户布局。

### 3.3 创建文件夹

支持把一个顶层 app 拖到另一个顶层 app 的明确 folder-create drop zone，创建新 folder：

- 目标 app 与源 app 成为初始成员；
- 初始成员顺序必须由产品决策固定并测试；
- 新 folder 占据确定的顶层位置；
- 新 folder 使用独立中性默认标题；
- FolderID 稳定并可持久恢复；
- 创建成功后可打开、键盘导航、启动成员和编辑标题；
- 取消、无效 drop 或 stale target 不创建 folder。

不得通过拖拽一个 folder 到另一个 folder 创建嵌套或隐式合并。

### 3.4 把 app 加入既有文件夹

- 顶层 app drop 到 folder cell 的明确目标区 → 加入 folder；
- app 从一个 folder 移到另一个 folder → 原子跨 folder move；
- 已经是该 folder 成员的 app drop → no-op；
- stale/已删除 app → 拒绝；
- 源 folder 因移出成员变成单成员时，按 dissolve 规则处理；
- 目标 folder 的成员顺序和插入位置确定；
- 成功后 layout 只提交一次、持久化只入队一次。

### 3.5 文件夹内重排

支持：

- 同页成员重排；
- 文件夹内跨页重排；
- 拖到开头/末尾；
- 部分页与空槽；
- 打字机键盘导航、焦点和 inner page 在 drop 后调和；
- 关闭/重开 folder 后顺序保持；
- 应用重启后顺序恢复。

文件夹内 drag 不得驱动外层 `PagingCore` offset，也不得让外层页面意外 commit。

### 3.6 把成员移出文件夹

支持把 folder member 拖到明确的顶层 drop target：

- app 成为顶层条目并插入指定位置；
- 从源 folder 移除；
- 源 folder 剩 1 个成员 → dissolve，剩余成员回到确定顶层位置；
- 源 folder 剩 0 个成员 → 删除 folder；
- 所有变化作为一个原子 mutation；
- 取消/窗口失焦/stale revision 不产生部分移出。

如果 UI 需要“先退出 overlay 再落到顶层”，必须有显式 drag coordinator 和可测试状态，不允许靠多个独立回调碰运气。

### 3.7 跨页拖拽与边缘翻页

支持顶层及 folder 内的跨页移动：

- 指针进入左/右边缘区并保持一定时间后一次翻一页；
- 有 hysteresis/dwell，避免边缘抖动反复翻页；
- 离开边缘区取消 pending edge turn；
- 到全局首尾页不越界；
- 每次 edge turn 完成后重新命中合法 drop target；
- edge timer/session token 过期后零写回；
- ESC、mouseUp、window resign、refresh、teardown 都取消 edge turn；
- Reduce Motion 下可以缩短/取消视觉动画，但逻辑页仍正确。

所有 dwell、边缘宽度、drag threshold、动画时长都必须集中配置，标明来源类别并进入 `PARAMETER_RATIONALE.md`。不得从禁止来源寻找数值。

ADR 必须定义 `DragScope = .topLevel | .folder(id)`：顶层 edge turn 只能调用已经接受的外层分页入口，不得直接写 `visualOffset`；folder scope 只能改变 inner page，不能触发外层分页。每次翻页完成后暂停旧 target 解析，重新 hit-test，并重新验证 drag token、layout generation 和 catalog generation。

### 3.8 拖拽取消与异常生命周期

至少覆盖：

- ESC 取消；
- mouseUp 在无效区域；
- window resign key；
- 进入搜索；
- 标题编辑开始；
- catalog refresh 到达；
- layout store 失败；
- app/window teardown；
- drag source/target 在中途被复用；
- folder 在拖拽期间 dissolve 或消失；
- 连续快速开始第二个 drag。

取消后：

- 已提交布局不变；
- 无 insertion indicator/drag preview/edge timer 残留；
- 焦点回到合法身份或进入文档化 fallback；
- 无磁盘写；
- 无旧 completion 覆盖新 drag。

### 3.9 搜索、刷新和输入模式兼容

本阶段固定：

- 搜索 active 时禁用布局拖拽，避免对扁平搜索结果定义含糊顺序；
- Command-F 在 drag 中先取消 drag，再进入搜索；
- 标题编辑 active 时不开始 drag；
- folder overlay 打开时只允许 folder member drag，不允许同时操作外层，除非进入明确的 move-out 模式；
- catalog refresh 在 drag 中到达 → 取消当前 drag，先提交新 catalog，再 reconcile layout；
- 触控板滚动与 mouse drag 不得同时驱动两个分页状态；
- app/folder 单击、Return/Enter 和空白点击既有语义不回归；
- 拖拽 app 不得误启动 app；拖拽 folder 不得误打开 folder；
- click 与 drag 由最小移动阈值/状态机区分。

不得把 catalog、layout、folder projection 和 search 作为四次互相覆盖的 provider 提交。集成层必须建立一个可测试的单一事务顺序：

```text
catalog snapshot
→ visible workspace projection
→ optional search projection
→ provider commit
→ open-state/focus reconcile
```

`FolderOpenState` 当前持有打开时的 `FolderEntry` 副本。layout/catalog 提交后必须按 folder identity 显式重配成员并 clamp inner page；folder 消失或视觉 dissolve 时关闭 overlay、取消旧图标回调并恢复合法焦点；app 以后重现时不得自动重新打开 folder。

统一输入仲裁是硬门：pointer-down 只能进入 `pressed`，不能在 `mouseDown` 立即启动成员或打开 folder；越过阈值后进入 drag，只有 mouse-up 且未越过阈值时才派发既有 click/open/launch。顶层 cell、folder member 和空白点击必须服从同一个 coordinator，避免双重识别。

### 3.10 无障碍等价操作

拖拽不是唯一操作路径。必须为不能精确使用指针的用户提供与同一 mutation engine 对齐的等价操作，至少包含：

- Move Before / Move After；
- Move to Previous Page / Next Page；
- Move Into Folder；
- Move Out of Folder；
- 在 folder 内 Move Before / After；
- 取消当前重排模式。

可以通过菜单、上下文菜单、键盘重排模式或 NSAccessibility custom actions 实现，但：

- 不得创建语义不同的第二套布局算法；
- 所有入口调用同一纯 mutation engine；
- 操作结果有可理解的 accessibility announcement/label；
- 无需 Accessibility/Input Monitoring 权限；
- VoiceOver/键盘至少完成手动门。

---

## 4. 持久化要求

### 4.1 只持久化逻辑布局

允许写入：

- schema version；
- 顶层逻辑顺序；
- folder 稳定 ID；
- folder 标题；
- folder 成员逻辑顺序；
- app 的持久化引用；
- 为冲突/迁移所需的最少中性元数据。

禁止持久化：

```text
搜索词
当前搜索状态
当前打开 folder
当前焦点
当前页/visual offset
拖拽临时状态
drag pasteboard token
图标或缩略图数据
telemetry/profile/runloop 数据
窗口标题
用户输入历史
Timer/分页诊断参数
```

持久化模型必须是专用 DTO/envelope，而不是给 `CatalogSnapshot`、`FolderSnapshot`、`TopLevelEntry`、`FolderOpenState` 或整个运行时对象图自动合成 Codable。读取路径固定为：

```text
Persisted expected layout
  + fresh CatalogSnapshot
  → validated VisibleWorkspaceProjection
  → runtime FolderSnapshot/TopLevelEntry presentation
```

### 4.2 App 身份持久化是架构硬门

当前 `AppID` 与 `FolderID` 的原始 storage 不公开、不可直接 Codable。不得用 `redactedDescription`、displayName 或不稳定的 Swift `Hasher` 充当持久身份。

ADR 必须比较至少三种方案：

1. bundle identifier 为主，canonical path fallback；
2. bundle identifier 为主，本地随机 salt + 稳定 keyed digest 表示 fallback path；
3. security-scoped bookmark 或其他公开平台标识。

必须明确：

- 哪些值会真实写入磁盘；
- 哪些值属于本地敏感应用清单；
- app 移动/重装/改 bundle ID 时如何恢复；
- 无 bundle ID 的 app 如何处理；
- `.keepMultiInstance` 下如何区分同 bundle ID 多实例；
- identity 冲突如何降级；
- 未解析 reference 是否保留为 latent entry；
- 是否需要对 `AppCatalogCore` 增加窄 public projection；
- 为什么选择方案不会破坏 `AppID` 的现有不透明/telemetry 边界。

优先保持 `Sources/AppCatalogCore/` 冻结。如果确需新增持久身份 projection，必须是单独 Chief 决策和 Reviewer 任务；不得公开 `AppID.storage` 或把原值加入 description/log。

### 4.3 FolderID 持久化

- FolderID 必须在重启后稳定；
- 允许新增受控的 persistence projection/Codable adapter；
- 不能让 UUID 原值进入 telemetry、stdout、signpost、profile 或错误报告；
- decode 重复/无效 folder ID 必须拒绝或确定性修复；
- 不以 folder title 派生 ID。

### 4.4 版本化 schema

创建独立 ADR 和版本化 envelope，至少包含：

```text
schemaVersion
layout payload
必要的兼容/校验字段
```

要求：

- v1 decode/encode round trip；
- deterministic encoding（便于测试，不代表加密）；
- unknown future version 不应被旧版本静默覆盖；
- 迁移失败进入安全只读 fallback；
- 不把 decode 原始正文写日志；
- 限制文件大小、folder 数、entry 数、每 folder 成员数和标题长度；
- 拒绝重复 app、嵌套 folder、无效引用和超限 payload；
- schema migration 必须显式、可测试、可回滚。

schema validator 还必须证明：folder UUID 全局唯一、逻辑 app reference 全局最多归属一个位置、folder 内无重复成员、成员/顶层顺序原样保留、标题按既有 64-grapheme 规则规范化。限制值必须由 ADR 固化；建议初始评估 1 MiB 文件、512 folders、10,000 总 app references、每 folder 2,048 members，但这些是待验证的工程上限，不是既有产品事实。

### 4.5 存储位置与权限

生产默认应使用本应用独立的 Application Support 子目录，不使用：

```text
Launchpad/Dock 私有路径
LaunchBetter/Buho 名称或 bundle ID
Documents/Desktop/iCloud Drive
/tmp 作为生产持久化
源码目录或项目目录
UserDefaults 存大体量结构化布局
```

要求：

- 目录和文件名为本项目独立中性命名；
- 文件权限尽可能收紧为当前用户读写；
- 测试必须注入临时目录，不触碰真实用户 Application Support；
- 不在 stdout 打印完整路径；
- 无网络、无云同步、无共享容器；
- 布局文件是本地敏感数据，进入 `PRIVACY_DATA_MAP.md` 和第三方/备份边界说明。

### 4.6 原子写、串行化和崩溃恢复

必须设计一个可注入 store abstraction；生产实现建议 actor/串行队列，满足：

- temp write + atomic replace；
- last-known-good backup 或等价恢复策略；
- 同一进程内写入严格串行；
- layout generation latest-wins；
- 连续 drag mutation 可 coalesce，但顺序不能颠倒；
- 成功 mutation 后异步持久化，不阻塞输入/动画热路径；
- application termination/teardown 有 bounded flush barrier；
- 写失败不回滚已安全呈现的内存状态，但必须标记 `PERSISTENCE_DEGRADED` 并允许重试；
- 不因写失败崩溃或清空旧 last-known-good；
- 半写、空文件、截断、权限拒绝、磁盘满和 replace 失败均有测试；
- 多实例并发写策略必须明确：single-writer、file coordination 或显式 last-writer-wins，不能忽略。

恢复策略优先采用同目录 A/B 双槽或等价的 generation journal：每个有效槽带单调 `writeGeneration` 与意外损坏校验，读取选择最新有效 generation。必须考虑 temp write、file fsync、atomic rename/replace 以及目录元数据持久化；checksum 只用于发现意外损坏，不得宣传为防篡改。若不用双槽，ADR 必须用 fault injection 证明替代方案覆盖 rename 前/后崩溃且不会失去最近有效布局；普通“先覆盖主文件、再复制 backup”不自动视为合格。

### 4.7 损坏与未知版本

- 主文件损坏时尝试 last-known-good；
- 主文件和 backup 都不可用时回到安全默认布局；
- 不自动把损坏正文覆盖掉，除非有明确恢复流程；
- 可以保留中性命名的 quarantine 文件，但不得把内容打印进报告；
- unknown future version 默认只读保护，不降级覆盖；
- UI 提供中性错误/恢复提示，不显示路径或原始 JSON；
- 自动化必须证明 catalog/启动仍可用。

主槽坏而备槽有效时加载备槽，但不得因一次恢复读取就立即覆盖证据；两槽都坏、超限或 schema 未来版本时，保留原文件、以中性只读/空布局 fallback 继续运行，未经明确用户 reset 不得静默清空或写回降级数据。

### 4.8 缺失、重现和新增 app 的 reconcile

必须区分：

```text
用户逻辑布局
当前 catalog 中可用的 app 投影
```

规则：

- 临时缺失 app 可以隐藏，但其 persisted reference 默认保留；
- app 重新出现时恢复原逻辑位置/成员关系；
- 不因一次扫描缺失就永久修改持久化布局；
- 用户主动把 app 移出/重排则更新 persisted layout；
- 新 app 进入确定的“未编排尾部”或 ADR 规定位置；
- duplicate/identity collision 确定性处理；
- folder 当前只有一个**可用**成员时，呈现可以沿用 dissolve 视觉，但不能因此无意删除 latent persisted membership；
- 用户主动移出导致逻辑成员只剩一个时，才执行永久 dissolve mutation；
- reset layout 后所有 app 回到确定默认顺序，folder 清除。

`--folder-lab`、`--catalog-root`、`--neutral-content`、smoke 和所有自动化默认必须注入内存/临时 store，不得读写正式 Application Support。folder lab 只能在显式空 store 测试中作为 seed，不能在 refresh 或下次启动时覆盖真实持久布局。

### 4.9 重置和删除本地布局

提供明确、用户主动的 reset：

- 可通过菜单、设置或显式 CLI；
- 必须与普通启动区分，不能误触；
- reset 删除/归档布局后重建默认布局；
- 不删除真实 app、图标或 catalog；
- 测试仅使用注入临时目录；
- reset 后重启仍为默认；
- 是否保留 backup 必须由 ADR 决定并向用户说明。

---

## 5. AppKit 拖拽实现边界

### 5.1 公开 API 与本地 session

优先评估 AppKit 公共拖拽 API（如 `NSDraggingSession`/`NSDraggingSource`/`NSDraggingDestination`）与自定义 pointer state machine 两种方案，写 ADR 比较：

- click-vs-drag 区分；
- 跨 page/overlay；
- drop target 可测试性；
- drag image/Reduce Motion；
- pasteboard 隐私；
- 外部进程伪造；
- teardown/cancel；
- 与现有 `NSClickGestureRecognizer`、scrollWheel 和 blank-click 的冲突。

在当前仅支持应用内、单窗口拖拽且需要精确跨页/overlay 控制的范围下，**默认优先自定义窗口内 state machine**；选择 `NSDraggingSession` 必须证明它在取消、edge dwell、overlay move-out 和自动化方面更合适，不能只因为它是系统 API。无论选择哪种实现，都必须存在独立事务：

```text
DragTransaction(
  opaqueToken,
  scope,
  sourceIdentity,
  layoutGeneration,
  catalogGeneration
)
```

状态至少为 `idle → pressed → dragging/edgeTurnPending → commit | cancel → idle`。每个 session 最多一个 preview 和一个 edge timer；ESC、失焦、app resign active、refresh、search、title edit、overlay/window close、teardown 和第二次 drag 必须走统一 cancel，清理所有临时 UI，拒绝旧 callback，且取消路径零持久化写入。

不得使用：

```text
全局 NSEvent monitor
CGEvent tap
Accessibility/Input Monitoring 权限
私有 AppKit API
Finder file URL drag
```

### 5.2 Pasteboard 隐私

macOS drag pasteboard 可能被其他进程观察。不得把以下内容放入 pasteboard：

```text
AppID 原值
bundle ID
canonical path/URL
app 名称
folder title
folder UUID 原值
成员列表
layout JSON
```

如使用 AppKit drag session，只允许放随机、短期、进程内验证的 opaque session token；真实 source identity 保留在内存 active-drag registry。Drop 时必须验证：

- token 与当前 active session 完全匹配；
- 来源窗口/进程/drag generation 合法；
- catalog/layout generation 未过期；
- target 仍存在；
- session 未取消或消费。

拒绝所有外部 pasteboard payload 和重复 drop。

### 5.3 拖拽视觉

- 使用本阶段独立设计的中性 drag preview、插入线/占位和 folder-create/highlight 状态；
- 不复制 Buho 或 LaunchBetter 的 drag ghost、spring-open、缩放、阴影、颜色、间距或动画；
- 视觉 token 记录来源类别；
- insertion 与 create-folder target 视觉必须可区分；
- 不能只靠颜色表达合法/非法；
- Reduce Motion 禁止不必要的大幅缩放/飞行动画；
- drag preview 不进入资源或报告，不包含真实用户 app 截图。

### 5.4 热路径性能

drag move 热路径禁止：

```text
磁盘写
JSON encode
catalog scan
Bundle 读取
图标同步解码
重建整个 view tree
对全布局做无界 O(n²) 搜索
同步等待 actor/queue
```

允许：内存 hit-test、局部 preview 更新、纯 mutation 预演、必要的有界布局计算。

真正持久化只在成功 commit 后异步入队；drag move 期间不得每个 mouse event 写盘。

---

## 6. 架构决策要求

实现前必须创建并定稿：

```text
Docs/ADR-009-WORKSPACE-LAYOUT-AND-PERSISTENCE.md
Docs/ADR-010-DRAG-SESSION-AND-DROP-SEMANTICS.md
Docs/PHASE1F_SPEC.md
Docs/PHASE1F_VALIDATION_PLAN.md
```

### 6.1 ADR-009 至少回答

1. persisted layout、runtime projection、catalog snapshot 和 folder snapshot 分别由谁拥有？
2. app 持久引用采用什么格式，为什么？
3. FolderID 如何安全持久化？
4. schema v1 结构和合法上限是什么？
5. Application Support 路径如何决定和注入？
6. 原子写、backup、flush、多实例策略是什么？
7. corruption/unknown version 如何恢复而不覆盖证据？
8. missing/reappearing/new app 如何 reconcile？
9. 单成员 dissolve 如何区分“用户逻辑变更”和“当前不可用投影”？
10. store failure 时内存状态、UI 和 retry 怎么处理？
11. reset layout 如何实现？
12. 哪些字段是本地敏感数据，如何限制暴露？
13. 是否需要修改 AppCatalogCore；若需要，为什么无其他更窄方案？
14. 为什么不使用 Launchpad/Dock DB、UserDefaults 大 blob 或云同步？
15. 为什么不能直接持久化 `FolderSnapshot`，以及如何替换 `hashValue` 相关的非稳定顺序？
16. title rename 是否已经是真实 layout mutation；若现状只是结束 editor，如何补成 `renameFolder` 并验证重启恢复？

### 6.2 ADR-010 至少回答

1. AppKit drag session 与自定义 state machine 如何取舍？
2. drag states、所有者和 session token 是什么？
3. click/drag threshold、edge dwell、drop zones 如何独立确定？
4. app reorder、folder reorder、create folder、move into/out/cross-folder 各自 mutation 是什么？
5. insertion drop 与 folder-create drop 如何区分？
6. 顶层/inner/跨页输入如何隔离？
7. active search/title edit/refresh/window resign/teardown 怎么取消？
8. source/target view reuse 和 stale generation 怎么防？
9. pasteboard 如何保持无身份数据？
10. drag commit、UI commit、persist enqueue 顺序是什么？
11. keyboard/VoiceOver 等价入口如何调用同一 mutation engine？
12. Reduce Motion 和 drag visual 如何处理？
13. 哪些参数进入 `PARAMETER_RATIONALE.md`？
14. 为什么不支持 nested folder、folder merge、外部 file drop？

Chief 可以更改类名和文件拆分，但不能改变用户可观察语义、隐私边界、冻结树或验收门。

---

## 7. 冻结树与允许写集

默认冻结：

```text
Sources/PagingCore/
Sources/MacAppCatalog/
Sources/AppIconPipeline/
Sources/PagingTelemetry/
Sources/PagingUI/
Package.swift
Sources/PagingPrototypeApp/AppLaunchController.swift
```

`Sources/AppCatalogCore/` 默认冻结。只有 ADR-009 证明无法在 AppGridUI/PagingPrototypeApp 建立安全持久引用 projection 时，才允许 Main/Chief 创建窄任务；不得暴露 `AppID.storage`、改变 catalog revision 所有权或修改扫描行为。

原则上允许：

```text
Sources/AppGridUI/
Tests/AppGridUITests/
Sources/PagingPrototypeApp/（除 AppLaunchController.swift）
Tests/PagingUITests/
Docs/
PROVENANCE/
Workflow/
```

若现有 PagingUI seam 无法支持 edge page turn 或 drag overlay，不得顺手改 `PagingCore`/`PagingUI`。先停止，写最小架构冲突证据，由 Chief 决定是否建立单独、向后兼容的中性 seam 任务。

`Package.swift` 仍由 Main 独占；优先不新增第三方依赖。Apple 系统框架使用必须记录公开 API 和最低系统版本。

---

## 8. 建议 Task DAG

Chief 可在保持语义的前提下调整文件级划分，但必须保留依赖关系。

### Gate 0 — Phase 1E 对账与 789 基线冻结

- 关闭或对账遗留 `EXECUTING` task；
- 更新 test count/manual gate/ADR 日期等当前态；
- 重新跑 tests/builds/hash；
- 创建 Phase1F baseline manifest；
- 不伪造历史 review/dispatch。

### T-1F-A — ADR + 纯 layout/mutation 领域

范围：纯 Foundation、无 AppKit/I/O。

交付：

- workspace layout；
- persistent app reference projection 设计；
- mutation engine；
- invariants/validation；
- reorder/create/add/remove/cross-folder/dissolve/reset 的纯测试；
- renameFolder 的真实 mutation、64-grapheme 规范化与持久化语义；
- layout generation/latest-wins/stale rejection。

### T-1F-B — 版本化 layout store

依赖 A。若写集与 C 完全分离，可以并发。

交付：

- store protocol + production actor；
- schema v1 codec/validator；
- Application Support location abstraction；
- atomic write/backup/recovery/unknown version/limits；
- injected temp-directory tests；
- coalescing + flush barrier + failure state；
- reset layout。

### T-1F-C — Drag state machine 与 drop resolver

依赖 A；纯逻辑为主，可与 B 并发。

交付：

- drag state/session token；
- hit-zone/drop intent；
- insertion vs create-folder；
- edge paging scheduler 纯 seam；
- cancel/stale/refresh/teardown；
- pointer 与 accessibility action 都映射到同一 mutation。

### T-1F-D — AppKit drag UI

依赖 C。

交付：

- cell/overlay drag source/destination；
- opaque pasteboard token；
- drag preview/insertion/folder highlight；
- edge page turn；
- top-level、folder inner、move-out UI；
- click/open/launch/blank-click 不回归；
- Reduce Motion/accessibility。

### T-1F-E — Provider/AppDelegate/persistence 集成

依赖 A/B/C/D，串行集成共享文件。

交付：

- startup load → reconcile catalog → runtime layout；
- drag commit → provider presentation → focus reconcile → async persist；
- refresh cancel/reconcile；
- search 禁拖；
- title rename persist；
- 将 catalog → visible layout → search → provider → open-state/focus 合并为单一可测试提交链，禁止后一次 provider commit 清掉前一次 search state；
- folder open-state 迁移；
- termination flush；
- reset command；
- store failure 中性 UI。

### T-1F-F — 独立审查、物理门与收尾

- 每任务独立 Reviewer；
- Main 全量 tests/builds/hash；
- privacy/provenance/persistence file inspection；
- crash/corruption/permission tests；
- 真实鼠标/触控板/键盘/VoiceOver 或 accessibility 手动门；
- 重启恢复门；
- final report 和唯一下一阶段建议。

---

## 9. 并发和 workflow 纪律

读取 `Workflow/config.json` 并简要报告声明模型；配置不证明真实上游路由。

Subagent 模式为 `ENABLED` 时，每个 Worker wave、Reviewer wave、repair 和 final verification 前记录：

```text
依赖是否满足？
写入范围是否完全不重叠？
测试目录/持久化目录是否隔离？
SwiftPM build 是否会争用共享 .build？
Reviewer 是否拥有稳定独立证据？
并发是否降低质量？
```

并发规则：

- A 完成后，B（store）与 C（pure drag）可在写集和 temp roots 完全分离时并发；
- D 依赖 C；E 依赖 A/B/C/D，必须串行；
- AppDelegate、provider、folder domain、Package.swift、schema canonical file 不允许多 Worker 并发写；
- persistence tests 每个 Worker 使用独立临时目录；
- SwiftPM 构建若共享 `.build`，Main 应串行；
- Reviewer 只读，不修代码；
- Worker 不得自证 PASS；
- 只有正式 Reviewer FAIL 增加 worker_failures；
- provider/network/context 中断优先恢复原 session；
- `events.jsonl` append-only，使用 workflow 脚本，不手写历史。

---

## 10. 自动化验证矩阵

### 10.1 Layout model/invariants

- deterministic default layout；
- top-level reorder 前/后/首/尾；
- app/folder 互换位置；
- create folder 目标/源顺序；
- add to folder；
- cross-folder atomic move；
- folder inner reorder；
- move out；
- zero/one member dissolve；
- duplicate app reject；
- nested folder reject；
- stale generation reject；
- no-op 不增 generation/不写盘；
- invalid target 不改变原布局；
- property/fuzz sequences 保持不变量。

### 10.2 Persistence identity/schema

- bundle-ID app round trip；
- fallback-only app round trip；
- multi-instance collision；
- FolderID round trip；
- title Unicode/64-character cap；
- deterministic encoding；
- v1 decode；
- unknown future version read-only；
- duplicate/oversize/deep/invalid payload reject；
- 无 displayName/icon/query/focus/page 状态进入文件；
- raw IDs/path 不进入日志/description。

### 10.3 Store durability

- first launch no file；
- save/load/restart；
- atomic replace；
- interrupted/partial write；
- corrupt primary + valid backup；
- both corrupt → safe default；
- permission denied；
- disk-full/injected write failure；
- coalesced writes latest-wins；
- flush on teardown；
- reset；
- unknown future version not overwritten；
- multiple instance policy；
- all tests use temp roots and clean up only their own directory。

### 10.4 Catalog reconcile

- missing app hidden but latent reference retained；
- app reappears at previous position/folder；
- new app deterministic append；
- user removal vs scan absence distinguished；
- persisted 2-member folder with one unavailable member does not lose latent membership；
- user move-out causing one logical member permanently dissolves；
- duplicate bundle IDs/fallback refs deterministic；
- refresh during drag cancels then reconciles；
- no forged CatalogRevision。

### 10.5 Drag intent/state

- below threshold = click；above threshold = drag；
- app reorder；folder reorder；
- center drop create folder；insertion zone reorder；
- app onto folder；member reorder；move out；cross-folder；
- invalid/external token reject；
- duplicate drop consumed once；
- stale source/target/layout/catalog reject；
- ESC/window resign/search/refresh/teardown cancel；
- second drag invalidates first completion；
- edge enter/dwell/turn/leave/cancel/first-last boundary；
- mouseUp before dwell no page turn。

### 10.6 AppKit integration

- app click still launches；drag app never launches；
- folder click/Return still opens；drag folder never opens；
- blank click two-stage unchanged；
- search active disables drag；
- Command-F cancels drag then searches；
- title editing blocks drag；
- folder inner drag does not move outer page；
- cross-page drop updates visible content and focus；
- source/target cell reuse zero stale apply；
- Reduce Motion；
- teardown zero gesture/session/timer/store callbacks。

### 10.7 Accessibility actions

- keyboard/menu Move Before/After；
- previous/next page；
- move into/out folder；
- same mutation result as pointer；
- illegal action unavailable or safely rejected；
- focus follows moved item；
- screen-reader labels contain no path/ID；
- no Accessibility permission required。

### 10.8 Privacy/provenance scan

禁止进入 telemetry/JSONL/stdout/signpost/profile/report/pasteboard：

```text
app 名称
bundle ID
canonical path/URL
AppID/FolderID 原值
folder 标题
成员列表
布局顺序
layout 文件正文
drag source/target identity
用户输入
```

布局文件本身是产品功能的本地敏感存储，是唯一受控例外；其字段必须由 ADR/PRIVACY_DATA_MAP 明确列出，不得被复制到诊断或 Workflow 报告。

---

## 11. 真实 GUI / 物理验收

自动化不能替代实际拖拽。至少在真实全屏窗口执行以下矩阵，并记录设备、刷新率、macOS、Reduce Motion、运行参数、异常 run 和用户结论。

### 11.1 顶层拖拽

1. 同页 app reorder；
2. 跨页 app reorder；
3. folder reorder；
4. app 与 folder 前后互换；
5. 首/尾位置；
6. 无效区域取消；
7. 快速 drag 后立即再次 drag；
8. 单击启动/打开不回归。

### 11.2 Folder mutation

1. app→app 创建 folder；
2. app→folder 加入；
3. folder 内同页/跨页 reorder；
4. member 移出到顶层；
5. member 跨 folder；
6. 单成员 dissolve；
7. 标题编辑后重启恢复；
8. folder 打开/关闭/键盘导航和成员启动不回归。

### 11.3 Edge paging/cancel

1. 左右边缘 dwell 翻页；
2. 离开边缘取消；
3. 首尾不越界；
4. ESC 取消；
5. window 切换/失焦取消；
6. drag 中刷新取消；
7. drag 中 Command-F 取消并进入搜索；
8. 无 ghost/insertion/timer 残留。

### 11.4 Persistence/restart

1. 完成多种布局后退出重开；
2. 顶层顺序恢复；
3. folder ID/title/member order 恢复；
4. app 暂时缺失后恢复；
5. 新 app 进入确定位置；
6. reset layout；
7. 注入损坏文件后应用安全启动；
8. 写权限失败时 UI 不崩溃并提示持久化降级。

### 11.5 输入/性能回归

1. 真实鼠标拖拽；
2. 真实触控板分页；
3. 物理键盘打字机导航；
4. accessibility 等价操作；
5. Reduce Motion；
6. 60Hz 手感无明显回退；
7. 120Hz 无设备继续 `BLOCKED_BY_HARDWARE`。

若未执行物理门，最多写：

```text
AUTOMATED_DRAG_AND_PERSISTENCE_VERIFIED
PHYSICAL_ACCEPTANCE_PENDING
```

---

## 12. 性能与可靠性门

至少记录：

- drag move 主线程 p95/max；
- drop mutation wall time；
- presentation apply wall time；
- async encode/write wall time（非热路径）；
- edge turn 触发/取消计数；
- stale session rejection；
- persistence retry/failure count（仅中性数字）；
- live view/drag preview 上界；
- teardown callback count。

禁止记录 source/target identity 或布局正文。

通过条件不应预设未经实验的绝对数字。Chief 应基于当前 60Hz 基线、公开平台约束和独立实验设预算，并说明来源。任何参数只能标：

```text
PRODUCT_DECISION
PLATFORM_REQUIREMENT
ACCESSIBILITY_REQUIREMENT
INDEPENDENT_EXPERIMENT
PUBLIC_DOCUMENTATION
```

不得使用 `REVERSE_ENGINEERING_COPY`、`OLD_SOURCE_TRANSLATION` 或 `UNKNOWN_ORIGIN`。

---

## 13. 明确不做

```text
嵌套文件夹
folder-on-folder 合并
多选/批量拖拽
把真实 app 从磁盘移动、复制或删除
Finder/桌面/外部应用拖放
系统 Launchpad/Dock 数据库读写
系统布局导入或导出
iCloud/网络/账号同步
协作冲突合并
跨设备同步
复杂 undo/redo 历史（除非 Chief 证明是本阶段硬门）
拖拽搜索结果直接改变布局
Hot Corner/全局手势/全局 NSEvent monitor
Accessibility/Input Monitoring 权限
默认帧源/Timer/PagingCore 调参
严格 >25ms 长尾根因修复
LaunchBetter/Buho 视觉、资源、文案、品牌或内部结构复刻
安装、签名、公证、发布
commit/push/tag/reset/clean/release
activation/license bypass
```

如这些能力成为硬依赖，停止并写 `SCOPE_EXPANSION_REQUIRES_USER_DECISION`。

---

## 14. 文档交付物

至少交付：

```text
Docs/ADR-009-WORKSPACE-LAYOUT-AND-PERSISTENCE.md
Docs/ADR-010-DRAG-SESSION-AND-DROP-SEMANTICS.md
Docs/PHASE1F_SPEC.md
Docs/PHASE1F_VALIDATION_PLAN.md
Docs/PHASE1F_REPORT.md
Docs/PHASE1F_BASELINE_MANIFEST.sha256
Docs/VALIDATION_RESULTS.md（追加）
Docs/IMPLEMENTATION_LOG.md（追加）
Docs/PARAMETER_RATIONALE.md（追加 drag 参数）
Docs/PRIVACY_DATA_MAP.md（追加 layout store 与 pasteboard 数据流）
PROVENANCE/COMPONENTS.md（追加）
PROVENANCE/ACCESS_DECLARATION.md（按参与者追加）
Workflow/tasks/T-1F-*.md
Workflow/results/T-1F-*.md
Workflow/reviews/T-1F-*-r*.md
```

最终报告必须包含：

1. 完成的 drag mutation；
2. persistence schema 和实际磁盘字段；
3. changed files；
4. 实际测试数、build 和 hashes；
5. 每个 Reviewer 结果；
6. store failure/corruption/restart 证据；
7. privacy/pasteboard/provenance 审计；
8. 物理门状态；
9. 未完成能力；
10. Timer/长尾诊断边界；
11. 唯一下一阶段建议。

---

## 15. 停止条件

出现任一情况立即停止相关分支：

- 需要读取禁止来源；
- 需要复制旧源码/视觉/参数；
- 需要读取或写入 Launchpad/Dock 私有 DB；
- 无法定义安全稳定的 app persistence reference；
- 必须公开 `AppID.storage` 或在日志输出原值；
- pasteboard 必须携带 app/folder 身份或布局正文；
- 无法原子区分 user mutation 与 catalog 暂时缺失；
- persistence 会在 drag hot path 同步写盘；
- 需要修改 PagingCore 或 Timer 参数才能实现拖拽；
- search/refresh/drag generation 可能互相覆盖；
- 多 Worker 写同一 schema/provider/AppDelegate；
- tests exit 0 但 executed tests = 0；
- 需要自动 commit/push/tag/release；
- 未知 schema version 会被旧版本覆盖；
- 测试会写真实用户 Application Support。

记录格式：

```text
BLOCKED
测量事实
受影响范围
已保存证据
需要 Chief 还是用户决策
最小下一步
```

---

## 16. 最终通过条件

只有全部满足才能建议 Phase 1F 完成：

```text
PHASE_1E_WORKFLOW_RECONCILED
ADR_009 = ACCEPTED
ADR_010 = ACCEPTED
LAYOUT_DOMAIN_TESTS = PASS
DRAG_INTENT_TESTS = PASS
PERSISTENCE_SCHEMA_TESTS = PASS
STORE_DURABILITY_TESTS = PASS
CATALOG_RECONCILIATION_TESTS = PASS
APPKIT_DRAG_INTEGRATION_TESTS = PASS
ACCESSIBILITY_REORDER_TESTS = PASS
FULL_SWIFT_TESTS = PASS_WITH_EXECUTED_COUNT
BUILD_DEBUG = PASS
BUILD_RELEASE = PASS
INDEPENDENT_REVIEW = PASS
PRIVACY_AND_PASTEBOARD_REDLINE = PASS
PROVENANCE_REVIEW = PASS
MANUAL_TOP_LEVEL_DRAG_GATE = PASS_USER_REPORTED_WITH_EVIDENCE
MANUAL_FOLDER_DRAG_GATE = PASS_USER_REPORTED_WITH_EVIDENCE
MANUAL_EDGE_PAGING_GATE = PASS_USER_REPORTED_WITH_EVIDENCE
MANUAL_RESTART_PERSISTENCE_GATE = PASS_USER_REPORTED_WITH_EVIDENCE
MANUAL_KEYBOARD_ACCESSIBILITY_GATE = PASS_USER_REPORTED_WITH_EVIDENCE
MANUAL_TRACKPAD_60HZ_REGRESSION_GATE = PASS_USER_REPORTED_WITH_EVIDENCE
MANUAL_120HZ_GATE = BLOCKED_BY_HARDWARE_OR_REAL_PASS
```

若自动化通过、物理门未全部完成，只能写：

```text
PHASE1F_AUTOMATED_COMPLETE_PHYSICAL_PENDING
```

不得写产品 drag/persistence 已最终验收。

---

## 17. 下一阶段建议边界

若 Phase 1F 全部通过，下一阶段候选为：

```text
RECOMMEND_PROCEED_TO_PHASE_1G_ACTIVATION_ENTRY_AND_HOT_CORNER
```

Phase 1G 才评估 Hot Corner、菜单/快捷入口或其他激活方式，并继续禁止全局监听/权限扩大，除非另有独立产品和隐私决策。

无论 Phase 1F 是否通过，都保持：

```text
PRODUCT_TIMER_TOLERANCE_0MS
SHORT_TAIL_MITIGATED_BY_TOLERANCE
CAUSALITY_UNRESOLVED_FOR_GT25MS
```
