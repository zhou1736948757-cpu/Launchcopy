# Phase 1E Prompt — 文件夹/分组基础、打开层与现有交互集成

> 创建日期：2026-08-30（Asia/Tokyo）
> 项目：`PagingPrototype`
> 项目路径：`/Users/mac/Projects/Launch_Copy/PagingPrototype/`
> 阶段建议：**Phase 1E = Folder Foundation vertical slice**
> 性质：下一阶段的自包含开发 Prompt；不是已完成报告、不是发布授权，也不是全部帧卡顿修复声明。

---

## 0. 执行原则

请先谨慎读取项目当前状态，再决定具体实现。用户提供的判断、本 Prompt 的判断以及历史文档都可能过期；不得为了“完成阶段”把假设写成事实。

必须严格分开记录：

```text
当前磁盘测量事实
用户实机验收事实
架构决策
产品决策
受支持推断
未解决问题
自动化验证
真实 GUI / 物理输入验收
```

本阶段只增加一个主要变量：

> **在现有本机应用目录、分页、搜索、键盘和启动能力上，增加独立设计的文件夹/分组呈现基础：顶层文件夹条目、打开/关闭文件夹层、文件夹内分页、键盘/鼠标启动、目录刷新和全局搜索兼容。**

本阶段不是完整 Launchpad，也不是视觉复刻。不要同时加入拖拽创建、跨页重排、持久化布局、Hot Corner、正式品牌视觉或发布流程。

---

## 1. 当前权威起点

### 1.1 已完成能力

- Phase 1A：分页状态机、真实触控板跟随、settle、中断、边界反馈和页面复用；
- Phase 1B：受限根本机应用目录、不可变 catalog snapshot、运行时图标、真实网格、刷新和启动；
- Phase 1C：键盘焦点、方向键导航、Return/Enter 启动、ESC 清选择、全屏和空白单击退出；
- Phase 1D：纯内存应用名搜索、搜索结果分页、搜索 responder、刷新/启动/键盘集成。

Phase 1D 报告记录的自动化完成基线为 `620 tests, 0 failures`；T-A4-0ms 后最新记录为 `631 tests, 0 failures`。这些是历史证据，Phase 1E Gate 0 必须重新执行测试并以当前输出为准。

当前 Release 可执行文件的已观察 SHA-256：

```text
c7873a6cb2b59f7585262e39186d4fdd7979cf84e76f6ceebebc87cabb042df2
```

该 hash 只是 Phase 1E 开始前的现有产物证据。任何源码修改后都必须生成并记录新的 Debug/Release hash，不得继续把它称为最终 hash。

### 1.2 T-A5 Timer tolerance 定案修正

当前产品基线必须写成：

```text
PRODUCT_TIMER_TOLERANCE_0MS
SHORT_TAIL_MITIGATED_BY_TOLERANCE
CAUSALITY_UNRESOLVED_FOR_GT25MS
```

事实边界：

1. 生产默认 `Timer.tolerance = 0ms` 已按用户定案通过 T-A5 产品物理门；这是 `PASS_USER_REPORTED_WITH_EVIDENCE`，不是本 Prompt 编写会话重新完成的独立实机复测；
2. `SHORT_TAIL_MITIGATED_BY_TOLERANCE` **仅用于 20–25ms 短尾改善**；
3. SELFDRIVE 中观察到的 commit 增幅未在物理轨复现，按 T-A5 决策归档为合成伪影；
4. 严格 `>25ms` 长尾仍为 `CAUSALITY_UNRESOLVED`；
5. 不得写 `ALL_HITCHES_FIXED`、`ROOT_CAUSE_FOUND`、`FIX_VALIDATED`；
6. Phase 1E 不得再次调整 Timer tolerance、分页参数或默认帧源；
7. 历史文档中的旧默认值、旧 gate 和旧 token 是历史记录，不追溯篡改。

T-A5 的定案不应扩大成“完整物理 ABBA、能耗和所有性能维度均已复核”。Phase 1E Gate 0 仍须重新验证当前工作树的自动测试/build；文件夹功能仍须执行自己的真实 GUI/物理门。

### 1.3 Phase 1D 手动门

当前 `Workflow/STATE.json`/Phase 1D 报告曾把搜索 GUI、物理键盘、真实触控板搜索分页和空白单击回归标记为 `NOT_RUN`。Phase 1E 开始时必须读取最新事件和报告：

- 若用户已验收并且已有记录，引用该证据；
- 若用户只口头确认但尚未落档，如实记录 `PASS_USER_REPORTED` 并补充最小证据指针；
- 若没有证据，保持 `NOT_RUN`，不得伪造 PASS；
- 未完成的 Phase 1D 手动门不一定阻止代码探索，但在 Phase 1E 最终产品建议中必须作为明确边界。

### 1.4 Phase 1D 静态审查待验证项

本 Prompt 编写时的只读 Terra 审查提出四个**待验证假设**。它们不是已确认 bug，不得未经复现就顺手改代码：

1. 搜索结果同 revision 提交后，surface reload 与键盘派生 layout 是否始终在同一提交边界更新；
2. `servedPageCount` 是否在非默认 `--items-per-page` 下仍错误使用固定 35；
3. `AppGridSearchPresentationController.onStateChange` 是否仍是未调用的死回调；
4. `clearQuery()` 后 `currentQuery` 的空查询语义是否与集成层的 `searchActive` 判断一致。

Gate 0 必须用现有源码和新增的最小复现测试确认。只有复现并证明影响本阶段时，才创建独立 repair task，经 Reviewer 后进入 Phase 1E；不能把 Reviewer 假设写成事实，也不能在文件夹实现中夹带无记录修复。

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
/Users/mac/Projects/Launch_Copy/PagingPrototype/Docs/PHASE1D_REPORT.md
/Users/mac/Projects/Launch_Copy/PagingPrototype/Docs/PHASE1D_SPEC.md
/Users/mac/Projects/Launch_Copy/PagingPrototype/Docs/PHASE1D_VALIDATION_PLAN.md
/Users/mac/Projects/Launch_Copy/PagingPrototype/Docs/ADR-003-PAGING-CONTENT-PROVIDER.md
/Users/mac/Projects/Launch_Copy/PagingPrototype/Docs/ADR-004-APP-CATALOG-SNAPSHOT.md
/Users/mac/Projects/Launch_Copy/PagingPrototype/Docs/ADR-005-ICON-PIPELINE.md
/Users/mac/Projects/Launch_Copy/PagingPrototype/Docs/ADR-006-KEYBOARD-FOCUS.md
/Users/mac/Projects/Launch_Copy/PagingPrototype/Docs/ADR-007-SEARCH-PRESENTATION.md
/Users/mac/Projects/Launch_Copy/PagingPrototype/Docs/PARAMETER_RATIONALE.md
/Users/mac/Projects/Launch_Copy/PagingPrototype/Docs/PRIVACY_DATA_MAP.md
/Users/mac/Projects/Launch_Copy/PagingPrototype/PROVENANCE/ACCESS_DECLARATION.md
/Users/mac/Projects/Launch_Copy/RISK_REDUCTION_PLAN.md
```

严禁读取或使用：

```text
/Users/mac/Projects/LaunchBetter/
/Users/mac/Projects/BuhoReverseNotes/
/Users/mac/Projects/LaunchBetter/Docs/aegis/work/2026-08-25-buho-launchpad-reverse/
任何 Ghidra/otool dump、地址映射、反编译正文、旧项目源码、截图、资源或精确视觉参数
```

本阶段只能依据：

1. 本 Prompt 的可观察需求；
2. 当前 `PagingPrototype` 自己的源码、测试、ADR 和已记录实验；
3. Apple 公开 API/公开文档；
4. 本阶段独立产生的设计和实验。

如果 Worker 已接触受限材料，必须如实标记 `PRIOR_EXPOSURE`；不得虚构 clean-room 身份。优先使用没有受限逆向上下文的新 Worker。

---

## 3. Phase 1E 范围

### 3.1 必须完成

#### A. 独立文件夹领域模型

建立中性、独立的文件夹/分组领域模型，至少能表达：

- 稳定、不包含名称/路径原文的 folder identity；
- 文件夹标题；
- 有序成员列表；
- 顶层呈现中“应用条目”和“文件夹条目”两种类型；
- 当前 catalog revision 与文件夹呈现 generation 的关系；
- latest-wins 暂存/提交语义；
- 目录刷新后成员消失、文件夹为空或只剩一个成员时的确定性规则；
- 标题编辑的会话内语义。

模型应从可测试需求重新推导，不得映射旧项目的类、字段或状态机。

#### B. 文件夹数据来源：仅会话内、显式测试入口

本阶段不做持久化，也不做拖拽创建。为了真实 GUI 验收，允许增加一个明确的 **folder lab/demo** 入口，用当前已提交 catalog 中的应用生成会话内测试分组。

要求：

- 默认产品启动不得偷偷重排用户应用；
- lab/demo 必须显式启用，例如命令行参数或仅测试注入；
- 组成员选择规则必须简单、确定、独立记录，例如按当前稳定目录顺序取前 N 项；
- 默认标题使用中性本地文案，例如 `Group 1`，不得复用任何旧产品文案；
- 不读取应用类别、Launchpad/Dock 私有数据库或系统布局；
- 不把 lab 分组写入磁盘；关闭应用后自然消失；
- 自动测试必须能完全注入 folder snapshot，不依赖本机安装了哪些应用。

如果 Chief 认为没有会话内 lab 就无法做可重复的真实 GUI 验收，可以采用等价的显式测试入口，但必须记录理由和隐私边界。

#### C. 顶层呈现

空查询时，顶层分页应能同时呈现应用和文件夹：

- 一个文件夹只占一个顶层槽位；
- 顶层 page count 根据实际顶层条目数计算；
- 文件夹成员不应同时以散落应用重复出现在顶层；
- 顶层顺序稳定、可预测；
- 目录刷新在 idle 边界提交，不得在手势/settle 中途造成错页、重复或旧内容；
- 页面复用后不得残留旧文件夹标题、缩略图或旧应用图标；
- folder identity、catalog revision、页面 identity 和 view reuse generation 必须有明确 stale 防线。

#### D. 文件夹视觉与打开层

实现独立设计的中性文件夹条目与打开层：

- 文件夹条目优先使用本阶段独立设计的中性符号、标题和成员数量，不默认采用多枚 App 图标拼贴；
- 若确有产品理由使用成员运行时图标预览，必须在 ADR 中说明独立设计理由，通过现有异步图标管道和 stale 校验，并单独做视觉来源审查；
- 不复制 Buho 或 LaunchBetter 文件夹缩略图、背景、圆角、阴影、间距、动画或文案；
- 打开层必须与顶层有明确层级和 hit-test 边界；
- 打开后显示标题和成员网格；
- 成员超过单页容量时支持文件夹内分页；
- 文件夹内分页不得驱动或污染外层分页状态；
- Reduce Motion 开启时减少大幅位移/缩放，仍保持状态正确；
- 打开/关闭动画参数必须来自 `PRODUCT_DECISION`、`ACCESSIBILITY_REQUIREMENT` 或独立实验，并登记在参数文档；
- 点击打开层外部应只关闭文件夹，不应直接退出整个应用；关闭后再次点击真实窗口背景才执行既有退出语义。

#### E. 指针与键盘行为

必须定义并实现：

- 指针激活文件夹条目 → 打开文件夹，不调用应用启动；
- 指针激活文件夹成员应用 → 复用现有 `AppLaunchController` 校验和启动管线；
- Return/Enter 聚焦文件夹条目 → 打开文件夹；
- Return/Enter 聚焦文件夹成员 → 复用现有启动管线；
- 文件夹打开时方向键只在文件夹成员范围内移动；
- 文件夹成员跨页时焦点和视觉页保持一致；
- ESC 优先级：若正在编辑标题则取消/结束编辑；否则关闭文件夹；文件夹关闭后才回到既有 ESC 清网格选择语义；
- Tab 不得被无依据吞掉；
- 关闭文件夹后，焦点恢复到刚才的文件夹条目；若该条目因刷新失效，使用文档化的最近合法回退；
- 窗口重新成为 key window 后按当前模式重建正确 first responder；
- teardown 后无 responder、通知或动画回调残留。

不得用全局 NSEvent monitor、Accessibility 权限或 Input Monitoring 来实现这些行为。

#### F. 标题编辑（仅会话内）

允许编辑 folder lab 中的文件夹标题，但本阶段只承诺会话内有效：

- 明确进入编辑的交互；
- 空白标题的规范化/回退规则；
- 合理长度上限和 Unicode 安全处理；
- Enter 提交、Escape 取消、失焦行为确定；
- 编辑期间方向键/Return 不得误启动应用；
- 标题不得进入 telemetry、stdout、JSONL、signpost、profile 或报告；
- 不写磁盘，不宣称持久化完成。

#### G. 搜索兼容

Phase 1E 的搜索语义固定为：

- 全局搜索仍按 **应用显示名** 过滤；
- 搜索结果只显示应用，自动扁平化文件夹成员；
- 不匹配 folder title；
- 不增加文件夹内搜索、模糊搜索、拼音、排名或 Spotlight；
- 在文件夹打开时按 Command-F：先安全关闭文件夹，再进入现有全局搜索；
- 清除/退出搜索后恢复顶层文件夹呈现；
- search generation 与 folder presentation generation 必须互不冒充；
- 旧搜索结果不得覆盖更新后的 folder/catalog 呈现；
- 搜索结果中的应用启动继续使用现有统一启动管线。

#### H. 目录刷新兼容

目录 refresh 必须遵守：

- 新 catalog snapshot 仍由现有 revision 所有者分配；文件夹层不得伪造 `CatalogRevision`；
- refresh 在手势、文件夹内分页、开合动画或标题编辑期间到达时先暂存；
- 在安全 idle 边界原子提交；
- 已删除应用从文件夹成员移除；
- 新增应用默认进入顶层未分组区域；
- 空文件夹从呈现中移除；
- 单成员文件夹本阶段默认保留或解散必须由 ADR 明确选择，并有测试；
- 若当前打开文件夹被移除，关闭打开层并恢复到最近合法顶层状态；
- 在途旧图标写回必须被拒绝；
- 不因刷新阻塞触控板热路径。

#### I. 无障碍与 Reduce Motion

- 文件夹条目有明确 accessibility role/label/描述；
- 打开层标题和成员层级可理解；
- 焦点顺序可预测；
- 不能用视觉缩略图作为唯一状态表达；
- Reduce Motion 下打开/关闭和文件夹内分页仍正确；
- lab/demo 模式也必须满足相同基本无障碍语义。

### 3.2 明确不做

```text
拖拽创建文件夹
拖拽重排应用或文件夹
跨页拖拽
移入/移出文件夹
跨文件夹移动
持久化布局、SQLite、UserDefaults 布局存储或云同步
读取/写入 Launchpad 或 Dock 私有数据库
系统布局导入
文件夹内搜索
按 folder title 搜索
拼音、模糊、前缀、分词、排名或 Spotlight 搜索
Hot Corner、全局手势、全局 NSEvent monitor
Accessibility/Input Monitoring 权限
默认帧源切换、DisplayLink 产品接入
Timer tolerance 或分页参数继续调优
严格 >25ms 长尾根因修复
LaunchBetter/Buho 视觉、品牌、资源、文案或截图复刻
安装、签名、公证、发布、commit、push、tag、release
activation/license bypass
```

若实现文件夹基础必须增加拖拽或持久化，停止并标记 `SCOPE_EXPANSION_REQUIRES_USER_DECISION`，不得顺手扩大范围。

---

## 4. 架构决策要求

实现前创建并定稿：

```text
Docs/ADR-008-FOLDER-PRESENTATION.md
Docs/PHASE1E_SPEC.md
Docs/PHASE1E_VALIDATION_PLAN.md
```

ADR 至少比较两种方案：

1. 在现有顶层 provider 中引入统一 presentation item；
2. 保留应用 provider，增加独立 folder composition/overlay provider。

至少回答：

1. catalog snapshot、folder snapshot、search result 和当前打开状态分别由谁拥有？
2. 文件夹 generation 与 catalog revision 如何区分？
3. 顶层应用/文件夹共存时 page count、anchor 和焦点身份如何计算？
4. 搜索为何扁平化应用，退出搜索如何恢复文件夹呈现？
5. 外层分页和文件夹内分页如何隔离输入和动画？
6. refresh、search、folder open/close 同时 pending 时提交优先级是什么？
7. 文件夹 cell 如何避免走应用启动路径？
8. 文件夹成员如何复用现有启动安全校验？
9. 异步缩略图/成员图标如何防 stale、串图和 teardown 写回？
10. blank click、ESC、Command-F 和 key-window 恢复的优先级是什么？
11. 标题编辑如何管理 first responder，如何避免记录隐私文本？
12. 为什么不在本阶段加入拖拽和持久化？
13. Reduce Motion 如何影响打开/关闭和内部分页？
14. 方案与现有公共接口的兼容性及迁移风险是什么？

现有焦点身份、网格布局和启动入口以 `AppID` 为核心；“文件夹就是普通 app cell”不是当前事实。ADR 必须比较：

- 泛化为 app/folder 的中性 grid-entry identity + 统一 activation router；
- 用独立 folder selector/overlay 避免混合 cell；

如果选择泛化身份，folder 分支只能打开文件夹，app 分支仍委托现有 `AppLaunchController`；不得让 folder identity 穿过 app 启动校验。

不要在 Prompt 层机械规定类结构或字段名称。Chief 应以当前代码和可测试性做独立选择，并记录被否决方案。

---

## 5. 冻结与允许写入范围

默认冻结：

```text
Sources/PagingCore/
Sources/AppCatalogCore/
Sources/MacAppCatalog/
Sources/AppIconPipeline/
Sources/PagingTelemetry/
Package.swift
Sources/PagingPrototypeApp/AppLaunchController.swift
```

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

`Sources/PagingUI/` 默认冻结。只有 ADR 证明现有中性 `PagingPageContentItem.identity` seam 无法表达必要的独立 folder item kind，且修改保持中性、向后兼容并有 Reviewer 审核时，才允许创建单独的 Main/Chief 批准任务。不得为了方便修改 `PagingCore`。

`Package.swift` 仍由 Main 独占；本阶段优先不新增 target/第三方依赖。

所有 Worker 必须有互不重叠的写入范围。共享文件（尤其 provider、AppDelegate、ADR、Package.swift）由 Main 串行集成，不允许多个 Worker 在共享工作树并发写。

---

## 6. 建议 Task DAG

Chief 可以在不改变目标和验收语义的前提下调整文件级拆分，但必须保留依赖关系。

### Gate 0 — 当前态对账

- 读取最新 `STATE.json`/events/task/review；
- 确认 T-A5 status 为 `PASSED`，0ms 当前默认只有一个活状态；
- 重新运行全量测试、Debug/Release build；
- 记录当前测试数与新产物 hash；
- 核对 Phase 1D 手动门是否已有用户证据；
- 对 §1.4 四个静态审查假设做最小复现；确认无问题则记录 `NOT_REPRODUCED`，确认问题则先创建独立 repair task；
- 创建 Phase 1E baseline manifest；
- 不删除或重写历史报告。

### T-1E-A — ADR、纯领域模型与 lab fixture

建议写入：新 folder domain 文件、新 domain tests、ADR-008 草案。

验收：

- identity/title/membership/top-level composition 纯逻辑；
- generation/revision 不混用；
- 目录刷新成员收缩规则可测试；
- lab fixture 确定、无 I/O、无本机依赖；
- 不记录真实名称/路径。

### T-1E-B — 顶层组合与 provider

依赖 T-1E-A。

验收：

- 空查询显示应用+文件夹；
- 搜索显示扁平应用；
- page count/anchor/idle commit/latest-wins 正确；
- refresh 不重复、不漏项、不伪造 revision；
- 现有 Phase1B/1D provider 测试保持通过。

### T-1E-C — 文件夹 cell、缩略图与打开层

依赖 T-1E-A；若文件写入范围与 T-1E-B 完全分离，可在 Main 明确记录后并行。

验收：

- 中性独立视觉；
- 文件夹条目和 app 条目类型可区分；
- 缩略图 stale 防线；
- 内部分页与外层隔离；
- click outside 只关闭文件夹；
- Reduce Motion 正确；
- teardown 零回调。

### T-1E-D — 键盘、焦点与标题编辑

依赖 T-1E-B/C。

验收：

- Return/Enter open-vs-launch 分流；
- 内部方向键/分页/焦点恢复；
- ESC 优先级；
- Command-F 关闭文件夹后进入搜索；
- 标题编辑 Enter/Escape/失焦；
- key-window responder 重建；
- 无全局监听。

### T-1E-E — AppDelegate 集成、刷新、搜索、启动与 blank-click

依赖 T-1E-B/C/D，必须串行集成。

验收：

- lab flag/test injection 接线；
- 文件夹成员启动复用 `AppLaunchController`；
- folder cell 绝不进入 app launch；
- search/refresh/folder pending 优先级实现；
- overlay 外单击关闭、下一次真实背景单击退出；
- teardown 全链关闭。

### T-1E-F — 独立 Reviewer、文档和物理验收

- 每个实现任务经独立 Reviewer；
- Main 重新跑全量测试和 builds；
- 来源/隐私/视觉中立扫描；
- 真实全屏 GUI、物理键盘和触控板门；
- 定稿报告与唯一下一阶段建议。

---

## 7. 并发与工作流纪律

当前 workflow 配置以 `Workflow/config.json` 为准。执行时简要报告已声明的 Main/Chief/Worker/Reviewer model 和 thinking depth；本地配置不证明上游真实路由。

Subagent 模式若为 `ENABLED`，每个 Worker wave、Reviewer wave、repair 和 final verification 前都必须记录并发检查：

```text
依赖是否满足？
写入范围是否完全不重叠？
测试资源是否隔离？
Reviewer 是否拥有独立稳定证据？
并发是否会降低质量？
```

建议：

- 只读 Explorer/Reviewer 可以并发；
- T-1E-B 与 T-1E-C 只有在文件写集完全不重叠时才可并发；
- AppDelegate/共享 provider/共享 ADR/Package.swift 集成必须串行；
- Reviewer 只读，不修代码；
- Worker 不得自证 PASS；
- 正式 Reviewer FAIL 才增加 `worker_failures`；
- 临时 provider/network/context 中断优先恢复原 session，不能算 FAIL。

`Workflow/events.jsonl` append-only，只能用项目 workflow 脚本追加。不得修改历史事件、补造旧 dispatch/review 或删除 watchdog 记录。

---

## 8. 关键状态优先级

实现必须通过 ADR 和测试固定以下可观察优先级；具体内部机制由实现者独立设计。

### 8.1 输入优先级

```text
标题编辑中的 Enter/Escape
    > 文件夹打开层的 Escape/方向键/激活
    > 搜索 field responder
    > 顶层键盘焦点
    > 窗口背景退出
```

### 8.2 pending 提交优先级

建议基线：

```text
新 catalog snapshot
    > 基于新 catalog 重建 folder composition
    > 在新 base 上重跑当前 search query
    > 恢复或关闭当前 folder open state
    > relayout / focus reconcile
```

Chief 可以调整，但必须保证：

- catalog revision 单一来源；
- search generation、folder generation 和 surface generation 不互相冒充；
- 不向旧页面/旧 cell 写回；
- 用户当前看到的层在 commit 边界内一致；
- 任何选择都写入 ADR 和测试。

### 8.3 激活分流

```text
top-level app      -> existing AppLaunchController
top-level folder   -> open folder
folder member app  -> existing AppLaunchController
placeholder/stale  -> reject safely
```

不得复制一条弱化校验的第二启动路径。

---

## 9. 自动化验证矩阵

### 9.1 Gate 0

```text
swift test
swift build -c debug
swift build -c release
```

要求：

- exit 0；
- executed tests > 0；
- 记录真实 executed/passed/failed 数，不预写最终总数；
- 现有 631 基线测试不得减少或静默跳过；
- 若测试发现数量改变，说明新增/删除/重命名原因；
- 记录 Debug/Release executable SHA-256。

### 9.2 领域模型

至少覆盖：

- folder identity 稳定且不依赖标题；
- 标题规范化、空白和长度边界；
- 成员顺序稳定、无重复；
- folder generation 单调/latest-wins；
- catalog revision 不被 folder 层 mint/forge；
- refresh 删除成员、新增应用、空文件夹、单成员决策；
- lab fixture 确定且默认关闭；
- Unicode 标题不会崩溃或泄漏日志。

### 9.3 顶层 provider/composition

- 文件夹占一个槽位；
- 成员不在顶层重复；
- 空查询与搜索扁平结果切换；
- page count 缩小/扩大；
- anchor 在应用和文件夹条目之间确定性回退；
- busy 时只 stage，idle 才 commit；
- 多次 refresh/latest query/latest folder generation 只提交最新；
- 同 revision presentation reload 不出现错页或旧内容。

### 9.4 视图、复用和图标

- app cell 与 folder cell 不混淆；
- reuse 后标题、缩略图、焦点清空；
- 旧 member icon 回调被拒；
- overlay 打开/关闭幂等；
- 打开 A 后立即打开 B，A 的旧回调不能覆盖 B；
- 内部分页不改变外层 committed page；
- resize/全屏切换后布局合法；
- Reduce Motion 路径正确；
- teardown 后 callback count 为 0。

### 9.5 键盘和 responder

- 顶层 folder Return/Enter 打开且不 launch；
- 成员 Return/Enter launch；
- 文件夹内四方向移动；
- 内部跨页焦点和页一致；
- Escape 标题编辑 → 文件夹 → 顶层的优先级；
- Command-F 关闭文件夹并进入全局搜索；
- 关闭后恢复原 folder focus；
- folder 消失时安全回退；
- Tab 交给 AppKit；
- key-window 重建；
- blank click 两阶段语义。

### 9.6 搜索、刷新、启动集成

- 搜索不匹配 folder title；
- folder member 在全局搜索结果中可见且只出现一次；
- 清搜索恢复 folder composition；
- refresh 时打开 folder 成员变化；
- folder cell 不走 launch；
- member app 走同一 stale revision/file existence/NSWorkspace 管线；
- stale member、missing app、missing file 非致命拒绝；
- 旧搜索或旧 folder pending 不覆盖新 catalog。

### 9.7 隐私和来源测试

禁止进入 telemetry/JSONL/stdout/signpost/profile/report：

```text
真实应用名
bundle ID
应用路径或用户路径
URL
搜索词
文件夹标题
folder membership
folder identity 原值
图标数据或哈希
窗口标题
用户输入正文
原始 RunLoop mode
```

允许的中性数据仅限必要计数/枚举，例如：

```text
folder_count
member_count
open/close outcome enum
stale rejection count
apply duration numeric
```

除非 ADR 证明必要，本阶段不修改 PagingTelemetry schema。优先保留内存测试计数，避免新增诊断热路径。

---

## 10. 真实 GUI / 物理验收

自动化通过不等于真实交互通过。最终至少由用户在真实全屏窗口执行：

### 10.1 文件夹基础

1. 用显式 folder lab 启动；
2. 顶层能看到中性文件夹条目，无成员重复；
3. 指针打开文件夹；
4. 点击成员应用可启动；
5. 点击打开层外只关闭文件夹，不退出；
6. 再点真实背景才退出；
7. 快速重复开关不同文件夹，无旧标题/缩略图/闪回。

### 10.2 键盘

1. 方向键聚焦 folder；
2. Return/Enter 打开而不是启动；
3. 文件夹内方向键和跨页正确；
4. Return/Enter 启动成员；
5. ESC 关闭并恢复 folder 焦点；
6. 编辑标题时 Enter/Escape 正确；
7. Command-F 从文件夹进入全局搜索；
8. 清搜索后恢复顶层 folder。

### 10.3 触控板与刷新

1. 顶层多页真实触控板分页仍跟手；
2. 文件夹内多页分页不带动外层；
3. 动画中快速反向/关闭无跳页；
4. refresh 到达时无错页、重复、旧图标或崩溃；
5. 60Hz 手感不得明显回退。

### 10.4 Reduce Motion 与 resize

1. Reduce Motion 开启后开合状态正确；
2. 全屏切换/resize 后文件夹层不越界；
3. 关闭/重开应用后 lab 分组不持久化，符合本阶段边界。

记录：设备、实际刷新率证据、macOS 版本、Reduce Motion、运行参数、测试轮次、异常 run 和用户主观结论。120Hz 无设备继续写 `BLOCKED_BY_HARDWARE`，不得写 PASS。

---

## 11. 性能边界

- 触控板与动画热路径禁止同步扫描、Bundle 读取、磁盘 I/O、图标解码或等待 async；
- 文件夹缩略图只能消费内存状态和现有异步 icon pipeline；
- 不应每帧重建整个文件夹 view tree；
- 外层和内层 page hosts 必须有上界；
- lab 分组不应改变默认产品路径性能；
- 如新增视觉造成 frame interval 回退，先测量具体路径，不得把长尾归因给某系统组件；
- 0ms Timer tolerance 保持冻结；
- 本阶段最多报告“文件夹功能未引入可测回退”或“观察到回退”，不得写“全部卡顿已修”。

---

## 12. 文档交付物

至少交付：

```text
Docs/ADR-008-FOLDER-PRESENTATION.md
Docs/PHASE1E_SPEC.md
Docs/PHASE1E_VALIDATION_PLAN.md
Docs/PHASE1E_REPORT.md
Docs/PHASE1E_BASELINE_MANIFEST.sha256
Docs/VALIDATION_RESULTS.md（追加）
Docs/IMPLEMENTATION_LOG.md（追加）
Docs/PARAMETER_RATIONALE.md（只追加新参数）
Docs/PRIVACY_DATA_MAP.md（追加 folder 数据流）
PROVENANCE/COMPONENTS.md（追加）
PROVENANCE/ACCESS_DECLARATION.md（按实际参与者追加）
Workflow/tasks/T-1E-*.md
Workflow/results/T-1E-*.md
Workflow/reviews/T-1E-*-r*.md
```

报告必须包含：

1. 完成能力；
2. 修改文件与理由；
3. 实际测试数和 build/hash；
4. 每个 Reviewer 结论；
5. 手动门 PASS/NOT_RUN/BLOCKED；
6. 隐私与来源扫描；
7. 已知限制；
8. 拖拽/持久化明确未完成；
9. `>25ms` 长尾仍未解决；
10. 下一阶段唯一建议。

---

## 13. 停止条件

出现以下任一情况立即停止相关分支并报告：

- 需要读取禁止来源才能继续；
- 需要复制旧源码/视觉/资源/文案；
- 需要修改 PagingCore 才能做文件夹基础；
- 需要读取或写入 Launchpad/Dock 私有数据库；
- 需要拖拽、持久化或全局监听才能满足本阶段目标；
- 需要修改 Timer tolerance、帧源或分页参数让测试变绿；
- 无法区分 app identity 与 folder identity；
- 无法保证 folder/search/catalog generation 不互相覆盖；
- 真实名称、标题、路径或 query 将进入日志；
- 并发 Worker 会修改同一文件或共享 mutable state；
- 测试 exit 0 但 executed tests = 0；
- 需要自动 commit/push/tag/release。

停止状态应写：

```text
BLOCKED
阻塞事实
受影响范围
已经保存的证据
是否需要 Chief 或用户决策
最小下一步
```

不得为了继续而弱化验收或制造结论。

---

## 14. 最终通过条件

只有全部满足才能建议 Phase 1E 完成：

```text
ADR-008 = ACCEPTED
FOLDER_DOMAIN_TESTS = PASS
TOP_LEVEL_COMPOSITION_TESTS = PASS
FOLDER_OVERLAY_TESTS = PASS
KEYBOARD_RESPONDER_TESTS = PASS
SEARCH_REFRESH_LAUNCH_INTEGRATION_TESTS = PASS
FULL_SWIFT_TESTS = PASS_WITH_EXECUTED_COUNT
BUILD_DEBUG = PASS
BUILD_RELEASE = PASS
INDEPENDENT_REVIEW = PASS
PRIVACY_REDLINE = PASS
PROVENANCE_REVIEW = PASS
MANUAL_FOLDER_GUI_GATE = PASS_USER_REPORTED_WITH_EVIDENCE
MANUAL_KEYBOARD_GATE = PASS_USER_REPORTED_WITH_EVIDENCE
MANUAL_TRACKPAD_60HZ_REGRESSION_GATE = PASS_USER_REPORTED_WITH_EVIDENCE
MANUAL_120HZ_GATE = BLOCKED_BY_HARDWARE_OR_REAL_PASS
```

若自动化通过但用户尚未实测，最多写：

```text
AUTOMATED_IMPLEMENTATION_VERIFIED
PHYSICAL_ACCEPTANCE_PENDING
```

不得把它扩大成产品物理门 PASS。

---

## 15. 阶段完成后的建议边界

若 Phase 1E 全部通过，下一阶段建议为：

```text
RECOMMEND_PROCEED_TO_PHASE_1F_DRAG_AND_PERSISTENCE
```

Phase 1F 才考虑：拖拽创建文件夹、顶层/文件夹内重排、跨页移动、移入/移出文件夹和持久化布局。即使 Phase 1E 通过，也不代表这些能力已经完成。

如果 Phase 1E 未完成物理门，则只能写：

```text
PHASE1E_AUTOMATED_COMPLETE_PHYSICAL_PENDING
```

并保留：

```text
PRODUCT_TIMER_TOLERANCE_0MS
SHORT_TAIL_MITIGATED_BY_TOLERANCE
CAUSALITY_UNRESOLVED_FOR_GT25MS
```
