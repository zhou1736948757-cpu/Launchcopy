# PHASE1_SPEC.md — Phase 1A 分页原型规格

- **版本**：1.0
- **日期**：2026-08-28
- **状态**：APPROVED（T-step1，Main 编写；ADR-001/002 为本规格的架构决策依据）
- **来源**：`/Users/mac/Projects/Launch_Copy/PHASE1_PAGING_PROTOTYPE_PROMPT.md`（SHA-256 `06594a34…bf16e4`）
- **性质**：需求驱动、独立设计的 Phase 1A 规格；本阶段只验证分页交互引擎与页面承载方式。

## 1. 工程目标与成功定义

### 1.1 目标

在全新目录与全新代码基线中，独立实现一个 macOS AppKit 分页滑动原型，用真实触控板验证分页是否足够**跟手、连续、可中断、稳定**。

### 1.2 成功定义（Prompt §2.1）

1. 分页交互在正确性上可靠；
2. 手势跟随连续；
3. 动画可被新手势安全中断；
4. 页面内容和异步工作不污染当前状态；
5. 在真实 60Hz（及具备条件时的 120Hz）环境中通过规定的物理验收；
6. 源码来源、架构决策和验证证据可追溯。

### 1.3 能力对标定义

只对标**用户可观察结果层能力**：连续拖动、位移/速度翻页或回弹、动画可被新手势连续接管、首尾边界稳定、多页负载无空白/重复/错页/明显卡顿、resize/页面数量变化/teardown 后状态正确。**不要求**逐帧轨迹、内部状态、类结构、字段、常量组合和异常行为与任何旧产品一致。相同能力不是相同代码。

## 2. 范围

### 2.1 必须实现

- **A. 最小 macOS App**：原生 AppKit，macOS 14+（部署目标 `.macOS(.v14)`，本机 macOS 26.5.2），公开 API，可运行窗口，支持退出/重开/resize，不依赖旧项目路径。
- **B. 中性测试页面**：程序生成占位图标/几何图形；中性背景/字体/颜色/圆角/页码；item/page 数量可配置；预设 1/2/5/10/20 页；默认每页约 35 个占位 item（**本项目测试负载选择**，非旧产品常量）。
- **C. 真实触控板分页输入**：begin/changes/end/momentum；横向主导；自然滚动方向；快/慢滑动；小位移释放；动画中再次开始/反向；首尾边界；异常 phase 防御。物理门必须真实触控板，不得以鼠标滚轮或合成 CGEvent 代替。
- **D. 连续跟随**：手势期间连续跟输入、无阶跃；首尾受控边界反馈（边界函数独立设计并参数化）；边界不使内部状态失效或累积无限位移。
- **E. 目标页决定**：释放后依策略回弹/前进/后退；策略考虑位移比例、速度、momentum、当前位置、边界、Reduce Motion；阈值集中配置并记录理由。
- **F. 动画中断（核心硬门禁）**：settle 中新手势立即接管；接管位置连续；不跳回旧动画起点/目标；旧 completion 不覆盖新状态；无双重 commit；窗口关闭/resize/pageCount 变化时安全取消或重新基准化。
- **G. 状态模型**：至少表达 idle / tracking gesture / settling to page / interrupted / cancelled；明确所有权与生命周期（见 ADR-001）。
- **H. 页面承载与性能**：比较 live AppKit views 与轻量 compositor 两种方案并记录选择理由（见 ADR-002）；手势热路径禁同步解码/扫描/DB；不每帧重建 view tree；页面 prepare/reuse/snapshot 不显示旧内容；view/内存有上界策略；resize 几何更新不触发布局风暴。
- **I. 页面内容正确性**：无空白/重复/错页/越界/旧 item 残留/resize 错位/pageCount 缩小后无效/teardown 后 callback 残留。
- **J. Reduce Motion**：检测系统偏好；减少或取消大幅位移动画；保持状态正确；不破坏中断与旧回调失效机制；单独测试。
- **K. Telemetry**：可开关（默认关闭）、JSONL、记录 run/gesture/transition ID、phase、时间戳、input delta、visual offset、semantic page、target/committed page、interruption/stale count、frame interval、layout count、page host/view count、cache hit/miss、teardown callback count（详见 §6）。
- **L. 参数管理**：集中配置；每个参数记录名称/默认值/范围/来源类别/理由/验证结果/修改日期（见 PARAMETER_RATIONALE.md）。
- **M. 来源纪律**：不读禁止来源、不复制旧代码、fresh context worker、来源类别限制、交付前扫描、诚实标记（见 PROVENANCE/ 与 §9）。

### 2.2 不实现（Non-Goals，Prompt §4）

真实 Launchpad 数据库、应用扫描、真实 App 图标、应用启动、搜索/拼音搜索、文件夹与文件夹标题编辑、拖拽重排、跨文件夹移动、Hot Corner、全局手势激活、菜单栏设置、正式品牌/Logo/App 图标、LaunchBetter 视觉系统、安装/签名/公证/发布、activation/license bypass。若某项成为分页验证的阻塞条件，先记录理由，不自行扩大范围。

## 3. 测试页面规格

### 3.1 视觉中性

- 程序生成占位图标（简单几何图形/色块）或纯文字占位；
- 中性背景、字体、颜色、圆角、页码；
- 禁止使用 Buho 或 LaunchBetter 的 Logo、截图、壁纸、图标、文案、视觉 token；
- 测试数据不包含真实第三方 App 图标。

### 3.2 可配置性与预设

| 配置 | 说明 |
|---|---|
| `--page-count <N>` | 页面数量（1/2/5/10/20 预设） |
| `--items-per-page <N>` | 每页 item 数（默认约 35） |

默认负载 = 每页约 35 个占位 item：**本项目测试负载选择，不是从旧产品复制的不可变常量**（记录于本规格）。

## 4. 模块边界

| 模块 | 目录 | 责任 | 独占写入者 |
|---|---|---|---|
| PagingCore | `Sources/PagingCore/` | 纯逻辑状态机、页索引/边界、gesture session、visual offset、target page policy、interruption、transition identity、stale rejection、resize/pageCount rebasing、cancel/teardown。**不依赖 AppKit/Core Animation/窗口/真实事件** | Worker B |
| PagingTelemetry | `Sources/PagingTelemetry/` | 可开关 JSONL telemetry、run/gesture/transition ID、事件与性能指标 | Worker C |
| PagingUI | `Sources/PagingUI/` | AppKit 视图、页面承载（live views）、NSEvent 输入转换、settle 动画、中断、Reduce Motion、页面内容正确性 | Worker D |
| PagingPrototypeApp | `Sources/PagingPrototypeApp/` | App 入口（NSApplication）、窗口、命令行参数解析、退出/重开/resize | Worker D |
| 测试 | `Tests/PagingCoreTests/` `Tests/PagingTelemetryTests/` `Tests/PagingUITests/` | 见 VALIDATION_PLAN.md | 对应 Worker |

`Package.swift` 由 **Main 独占**维护。Docs/ 与 PROVENANCE/ 由 Main 维护。

## 5. 命令行参数规格（Prompt §10）

| 参数 | 含义 | 默认 |
|---|---|---|
| `--paging-lab` | 诊断模式 | off |
| `--page-count <N>` | 页面数量 | 5（预设可选 1/2/5/10/20） |
| `--items-per-page <N>` | 每页 item 数 | 35 |
| `--paging-telemetry` | 开启 telemetry | off |
| `--page-hosting live\|composited` | 页面承载方式 | live |
| `--reduce-motion-override on\|off\|system` | Reduce Motion 覆盖 | system |
| `--run-id <id>` | 指定 run ID | 自动生成 |

要求：
- 无参数时可正常打开原型；
- 参数错误给出帮助，不崩溃；
- telemetry 默认关闭，release 默认不产生大量日志；
- 日志不记录个人数据；日志路径与 run ID 明确输出；每次正式 run 独立日志文件；
- 自动诊断模式不视为人工真实体验模式。

## 6. Telemetry 规格（Prompt §5）

输出文件：`/tmp/launch-copy-paging-prototype-<run-id>.jsonl`（禁止 Buho 品牌前缀）。

每条事件至少含（17 字段）：

```text
run ID, gesture ID, transition ID, event phase, timestamp,
input delta, visual offset, semantic current page,
proposed target, committed page, interruption count,
stale completion rejection count, frame interval, layout count,
page host/view count, page prepare/cache hit/miss, teardown callback count
```

## 7. 参数管理规格（Prompt §9）

- 所有交互参数集中在明确配置结构（`PagingParameters`），禁止散落 magic number；
- 每个参数在 `Docs/PARAMETER_RATIONALE.md` 登记：参数 | 默认值 | 合法范围 | 来源类别 | 选择理由 | 验证结果（+ 修改日期）；
- 来源类别仅限：`PRODUCT_DECISION` / `PLATFORM_REQUIREMENT` / `ACCESSIBILITY_REQUIREMENT` / `INDEPENDENT_EXPERIMENT` / `PUBLIC_DOCUMENTATION`；
- 禁用：`REVERSE_ENGINEERING_COPY` / `OLD_SOURCE_TRANSLATION` / `UNKNOWN_ORIGIN`；
- 无法解释的参数使用明显实验值并标 `TUNING_REQUIRED`，**不得去读旧实现找答案**；
- 至少参数化：input sensitivity、boundary resistance、displacement threshold、velocity contribution、settle duration/spring、maximum overscroll、live page radius、prewarm distance、Reduce Motion 行为。

## 8. 架构决策引用

| 决策 | 文档 | 要点 |
|---|---|---|
| 状态模型 | `Docs/ADR-001-PAGING-STATE-MODEL.md` | 状态语义、所有权、settle 识别/取消、旧回调资格、resize/pageCount/teardown |
| 页面承载 | `Docs/ADR-002-PAGE-HOSTING.md` | 方案 1 live views vs 方案 2 compositor 比较与选择 |

ADR 自查通过前不得进入完整 UI 实现。

## 9. 来源与命名纪律（Prompt §11）

- 禁止迁移：源文件、测试、注释、类图、字段列表、状态机映射、精确参数簇、日志文本、bundle identifier、临时文件名、视觉资源；
- 中性命名：`PagingState`、`GestureSession`、`TransitionContext`、`PageTargetPolicy`、`PageHost`、`PagingSurface`、`FrameTelemetry` 等；禁止 Buho 身份/反编译地址/"原类型一一对应"含义；
- 改名不是独立实现证明：需要需求驱动状态模型 + 架构记录；
- 交付前扫描 8 类内容（源码/测试/文档/资源/Info.plist/Git history/构建产物 strings/绝对路径）；扫描仅泄漏预警，不是原创性或法律证明。

## 10. 变更记录

| 日期 | 变更 | 执行人 |
|---|---|---|
| 2026-08-28 | 创建 v1.0 | Main（T-step1） |
