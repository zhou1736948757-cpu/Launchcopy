# T-1F-B10-regression-fix — 主页面点击全死回归（§2.1 取证步：E5-fix + E6a'/E6a'' + E6b + E6c）

状态：**completed**（**按回合4任务包执行**：§2.1 步骤 2/3/4/5/6/7/8——E5-fix relayout 相关度重测 +
E6a' 中间层投递观测 + E6a'' 分发入口监视 + E6b 事件元数据 + E6c 真空白对照 + 构建状态核验 +
复测脚本；**E4 不执行**——E6 无果后置；**§2.2 条件修复未命中，零实现**）
任务包：Workflow/tasks/T-1F-B10-regression-fix.md（§2.1 取证步；**§2.2 条件修复未命中，零实现**）
判别依据：Workflow/BUG10-REGRESSION-REPORT.md（§7 读数回填/§8 判读/§9 判别实验表/§10 回合3判读）
角色：Worker（deepseek-v4-flash:0731，fresh context）

## 1. 取证布点清单（本波）

### 1.1 E5-fix：relayout 相关度重测（§2.1 步骤 2，零行为）

- **替代已降级的 E5 funnel**：直接读 `PagingSurface.layoutPerformedCount`（PagingUI 冻结树
  :169 `public private(set)`，只读不调用；Reviewer r2 M1 指定入口）。
- **接线**：`QuitOnBlankClickWindow` 新增只读提供者闭包 `layoutPerformedCountProvider: (() -> Int)?`
  （nil = 无 surface，按 0 计）；AppDelegate 启动装配处接线
  `{ [weak self] in self?.surface?.layoutPerformedCount ?? 0 }`。
- **观测点**：sendEvent leftMouseDown 分支（E1 观测之后）——`layoutPerformedCountProvider?() ?? 0`
  与窗口 ivar `lastLayoutPerformedCountAtPreviousClick` 差分 > 0 → `sE5_relayout_between_clicks_yes`
  （沿用既有 sink 名，判别口径不变）；基线随每次点击滚动。
- **移除**：`applyPresentationUpdate` :718 的降级计数行 `ClickCensus.hit(Sink.layoutOpTotal)` 与
  `sE5_layout_ops_total` sink 声明（被直接读替代；纯观测移除，零行为变更）。
- **判别**：`s18_internal_hittest_absent` 与 `_yes`（absent 前有点击间 relayout）强相关 → 命中 f。

### 1.2 E6a'：中间层投递观测（回合4重定义，§2.1 步骤 3，零行为）

- `AppGridPageView`（AppGridUI 非冻结）新增 `mouseDown` / `mouseUp` **纯转发 census**
  （sE6_page_down/up，中性计数，隐私合规；转发 super 原样，响应链与普通 NSView 完全一致）。
- sinks：`sE6_page_down` / `sE6_page_up`（extension ClickCensus.Sink，AppGridPageView.swift 内）。
- **判别**：>0 → 投递目标=AppGridPageView → **f 族定罪**（AppKit 缓存/跟踪会话指向中间层视图）；
  mouseUp 目标同步记录（事件对完整性）。
- 注：回合3 的探针（contentView）四事件 census（sE6a_probe_*）保留为补充观测（Main 已核验
  s18_delivered_contentview 零输出 → contentView 层投递面由 E6a'/E6a'' 主判）。

### 1.3 E6a''：分发入口监视（回合4新增，§2.1 步骤 4，零行为）

- AppDelegate 侧 `NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown, .leftMouseUp])`
  中性计数（sE6_monitor_down/up；仅计数，返回 event 原样 = 零行为变更；local monitor 只收
  本 app 窗口事件，非全局 monitor，隐私 A/B/C）。安装于 applicationDidFinishLaunching（telemetry
  后），移除于 teardownAll（幂等）。
- sinks：`sE6_monitor_down` / `sE6_monitor_up`（helper `ClickCensus.observeMonitorEvent(type:)`）。
- **判别**：monitor 有而视图全零 → 事件进入 AppKit 分发但投递到 PagingUI 冻结层或内部吞（h）；
  monitor 无 → 分发前即被吞。

### 1.4 E6b：事件元数据（§2.1 步骤 5，零行为）

- sendEvent 对 **mouseDown 家族事件**（leftMouseDown/rightMouseDown/otherMouseDown）记录
  `event.type.rawValue` / `event.subtype.rawValue` / `event.buttonNumber` 三中性 int，
  编码进 sink 名（仅入内存 snapshot；stderr 只打 sink 名+计数，无坐标/窗口标题/应用名，
  隐私 A/B/C）。
- sink：`sE6b_meta_type_<t>_subtype_<s>_button_<b>`（helper `ClickCensus.observeEventMetadata`）。
- **判别**：subtype≠0 或 type≠leftMouseDown → 非正常事件 → c/j 系统拦截方向。

### 1.5 E6c：真空白对照（§2.1 步骤 6，零行为）

- **无新代码**：s8c（`s8c_window_blank_terminate`）/ s8d（`s8d_window_cell_passthrough`）既有
  布点已够；复测脚本含「点窗口极端角落（明确空白）」步骤。
- **判别**：极端角落 → s8c 触发 → 此前空白点击实为 cell（frame 错位/误判）；仍 s8d →
  窗口层 hitTest 坐标/帧问题坐实（i 升级）。

## 2. 构建状态核验（§2.1 步骤 6）

| 检查项 | 要求 | 实测 | 结论 |
|--------|------|------|------|
| `Sources/AppGridUI/AppGridCellView.swift` hitTest 漏斗 | :215-217 | `frame.contains(point) ? self : nil` | ✅ 在位 |
| 同文件 s10/s11 sink | :234-241 | `s10_cell_mousedown_fired` / `s11_cell_lookup_nil` | ✅ 在位 |
| `Sources/PagingPrototypeApp/AppDelegate.swift` s8e/s13 | :1185-1203 | s8e 基名+状态位 func、s13a/s13b 声明 | ✅ 在位 |
| 复测前 `swift build -c release` 强制重建 | exit 0 | `rm -rf .build/arm64-apple-macosx/release` + 重建 → Build complete! (24.40s) | ✅ exit 0 |
| release 二进制 strings 核验 | 新 sink 在位 / 旧 funnel 移除 | sE6_page_down/up、sE6_monitor_down/up、sE6a×4、sE6b_meta、sE5_relayout_between_clicks 全 PRESENT；`sE5_layout_ops_total` ABSENT；s10/s11/s8e/s13a/s13b/s18×4/sE1/s8c/s8d 全 PRESENT | ✅ 非陈旧 |

**任一缺失 = 二进制陈旧 → 直接报告 Main，不进入实现。** 源码侧全部在位（见上表），
复测前仍执行强制重建（rm -rf release 目录 + 重建）。

## 3. 测试证据（§6 验证；全部真实执行，exit 0）

| 测试（Tests/PagingUITests/ClickDeliveryProbeTests.swift） | 断言要点 | 结果 |
|------|---------|------|
| testSendEventE5FixReadsRealSurfaceLayoutPerformedCount | 真实 PagingSurface 接线 → provider 读 `layoutPerformedCount`；预热首击建基线 → 无增量 `_no`；`relayoutPages()`（:742 增量）后 → `_yes`；基线滚动 | ✅ PASS |
| testSendEventRecordsRelayoutBetweenClicksDeltas | provider 差分（boxed 计数模拟 surface 增量）：点击1 → `_no`；+1 → 点击2 → `_yes`；基线滚动 | ✅ PASS |
| testRelayoutObservationDirect | helper 直调：true → `_yes` 恰一 | ✅ PASS |
| testProbeMouseEventForwardingCensus | E6a：mouseUp/mouseDragged/rightMouseDown/otherMouseDown 直调 → 各 sink == 1；转发 super 不 crash | ✅ PASS |
| testEventMetadataObservationDirect | E6b helper：(1,0,0) → `sE6b_meta_type_1_subtype_0_button_0` == 1；异组合互不串扰 | ✅ PASS |
| testSendEventRecordsEventMetadataPerMouseDownFamilyClick | E6b 端到端：left/right/otherMouseDown 各记恰一（sink 名 = 事件自身 rawValue 编码）；keyDown 不记（meta 总数 == 3） | ✅ PASS |
| testE1E5E6SinkNamesAreNeutral | E1/E5-fix/E6a/E6a''/E6b sink 名中性（无 windowNumber/_win_/NSApp 原文） | ✅ PASS |
| testESinksSilentWhenGateOffByDefault | env 门控缺省关：stderr 无 `PAGING_CLICK_CENSUS` 行；计数仍维护 | ✅ PASS |
| testMonitorEventObservationDirect | E6a'' helper 直调：leftMouseDown → `sE6_monitor_down` == 1；leftMouseUp → `sE6_monitor_up` == 1；互不串扰 | ✅ PASS |
| 既有 ①-⑦（手动/内部链、探针 mouseDown、窗口 cell/空白、s18 名、E1 四测+e2e） | 回归锁：探针零行为变更 | ✅ 全 PASS |

| 测试（Tests/AppGridUITests/AppGridPageViewTests.swift） | 断言要点 | 结果 |
|------|---------|------|
| testPageViewMouseDownUpForwardingCensus | E6a'：AppGridPageView.mouseDown/mouseUp 直调 → `sE6_page_down`/`sE6_page_up` == 1；转发 super 不 crash | ✅ PASS |
| testPageViewSinkNamesAreNeutral | E6a' sink 名中性（无 windowNumber/_win_/NSApp 原文） | ✅ PASS |

- 定向 ClickDeliveryProbeTests：**Executed 20 tests, with 0 failures**（基线 15 + 新增 5）。
- 全量 `swift test`：**Executed 1105 tests, with 0 failures (0 unexpected) in 16.793 (16.871) seconds**；
  `Test Suite 'All tests' passed`；exit 0 且 executed_tests=1105 > 0（基线 1098 + 新增 7）。
- 首击差分语义注记：窗口基线自 0 起算，**首击差分含启动期布局计数**（surface init/初始装配
  relayout）——与候选 f「启动期 relayout 即污染缓存」判别口径一致，非缺陷（测试以预热首击
  建立基线后断言确定性）。

## 4. 复测脚本（§2.1 步骤 7；PAGING_CLICK_CENSUS=1，读数由 Main/用户实机回填）

```
PAGING_CLICK_CENSUS=1 冷启动（最新 release 二进制；复测前已强制重建）
→ 点顶层 app cell ×3
→ 点窗口极端角落（明确空白）×1
→ 翻页（记录翻页方式：滚轮/按钮/键盘）
→ 再点 cell ×2
→ 记录：
    ① s18_hit_manual_chain_*（窗口手动 hitTest 视图链；应含 AppGridCellView）
    ② s18_hit_internal_chain_*（AppKit 实际投递视图链）+ s18_internal_hittest_absent/_present
    ③ s18_delivered_contentview（投递目标 = contentView 自身）
    ④ sE5_relayout_between_clicks_yes/_no（E5-fix：自上次点击以来 layoutPerformedCount 增量）
    ⑤ sE6_page_down/_up（E6a'：投递目标 = AppGridPageView 中间层；事件对完整性）
    ⑥ sE6_monitor_down/_up（E6a''：事件进入 AppKit 分发入口）
    ⑦ sE6a_probe_mouseup/_mousedragged/_rightmousedown/_othermousedown（探针投递，补充观测）
    ⑧ sE6b_meta_type_*_subtype_*_button_*（事件元数据；正常左键 = type_1_subtype_0_button_0）
    ⑨ s10 / sA 增量（cell.mouseDown / surface 手势启动）
    ⑩ s8c（极端角落空白终止）/ s8d（cell 放行）对照
→ 对照 run2 正常段：s8d→s10→s13a→s13b/s9b→s6→sA
```

判别（回填后按 §1.1-1.5 口径判定，命中 §2.2 某行才可进入实现；未命中禁止实现）：
- ④ `_absent` 前紧邻 `_yes`（relayout 后首击即 absent）→ 候选 f 命中方向。
- ⑤ `sE6_page_down` > 0 → 投递目标=AppGridPageView → **f 族定罪**；mouseUp 同步记录（事件对）。
- ⑥ monitor 有而视图全零 → 事件进入分发但投递到冻结层/内部吞（h）；monitor 无 → 分发前被吞。
- ⑧ subtype≠0 或 type≠leftMouseDown → c/j 系统拦截方向。
- ⑩ 极端角落 s8c 触发 → 空白误判排除；仍 s8d → i 升级。

## 5. Deviation（本波逐条）

1. **E5-fix 接线经 provider 闭包**：窗口（QuitOnBlankClickWindow）不直接持有 surface——
   经 AppDelegate 接线的只读闭包读取 `surface.layoutPerformedCount`（冻结树 :169 public
   private(set)，只读不调用；nil 按 0 计）。观测语义与任务包「AppDelegate 侧观测」一致。
2. **降级 funnel 移除**：`applyPresentationUpdate` :718 计数行与 `sE5_layout_ops_total` sink
   声明随 E5-fix 移除（被直接读替代；纯观测移除，零行为变更）。既有测试中引用
   `layoutOpTotal` 的用例改写为 provider 差分语义。
3. **E6b 记录范围 = mouseDown 家族**（left/right/other）：判别口径含「type≠leftMouseDown」，
   故记录面覆盖三按钮按下事件；mouseUp/dragged 投递面由 E6a'/E6a'' 覆盖，不重复记录。
4. **E6b 数值编码进 sink 名**：type/subtype/buttonNumber 三中性 int 随 sink 名入内存
   snapshot（沿用 s8e/s17 状态位先例）；stderr 只打 sink 名+计数（无坐标/标题/身份）。
5. **E6c 零代码**：s8c/s8d 既有布点已够，仅复测脚本新增「点极端角落」步骤。
6. **E6a 按回合4重定义**：原「探针（contentView）四事件 census」保留为补充观测
   （sE6a_probe_*，Main 已核验 s18_delivered_contentview 零输出）；主判面改为
   E6a'（AppGridPageView 中间层，sE6_page_down/up）+ E6a''（local monitor 分发入口，
   sE6_monitor_down/up）。E6a'' 安装于 applicationDidFinishLaunching、移除于 teardownAll
   （幂等）；monitor 返回 event 原样 = 零行为变更；local monitor 非全局（隐私 A/B/C）。
7. **E6a'' 测试面 = helper 直调**：monitor 安装/移除生命周期无法单测（需真实事件分发），
   由构建 + 代码评审覆盖；计数逻辑经 `ClickCensus.observeMonitorEvent(type:)` 直调断言。

## 6. 未触碰声明

- 冻结树全列（PagingCore/AppCatalogCore/MacAppCatalog/AppIconPipeline/PagingTelemetry/
  PagingUI/Package.swift/AppLaunchController.swift）：**零改动**。
- `Sources/AppGridUI/DragUI/DragUIVisuals.swift`、`DragUISessionCoordinator.swift`
  （wave-b 领地）：**零改动**（未以任何理由改宿主切换）。
- `FolderOverlayView.swift`、`DropIntent.swift`、`DragParameters`、Docs/：**零改动**。
- 无 git（仓库无提交历史）；改动文件清单：
  - `Sources/PagingPrototypeApp/AppDelegate.swift`（仅：provider 闭包声明+接线、sendEvent
    E5-fix 差分替换 + E6b 元数据观测、探针 E6a 四事件转发、E6a'' local monitor 安装/移除 +
    sink 声明 [E5-fix 沿用 / E6a / E6a'' / E6b]、`applyPresentationUpdate` 降级计数行移除；
    **零分支条件/返回值/吞点/终止路径变更**）
  - `Sources/AppGridUI/AppGridPageView.swift`（**仅加 mouseDown/mouseUp 纯转发 census sink
    [sE6_page_down/up]，零行为变更**——回合4任务包 §3 写范围）
  - `Tests/PagingUITests/ClickDeliveryProbeTests.swift`（追加 E5-fix/E6a/E6a''/E6b 测试；
    既有 E5 用例改写为 provider 语义）
  - `Tests/AppGridUITests/AppGridPageViewTests.swift`（追加 E6a' 转发计数 + sink 名中性测试）
  - `Workflow/results/T-1F-B10-regression-fix.md`（本文件）
- **§2.2 条件修复未命中 → 零实现**（本波仅取证装置）；**E4（env 门控手动投递）本波不执行**
  ——按任务包，E6 无果后置。

## 7. AccessDeclaration

**NO_PRIOR_EXPOSURE**：本波未读取 LaunchBetter/BuhoReverseNotes/2026-08-25-buho-launchpad-
reverse 及任何 Ghidra/otool dump；E5-fix 只读 `layoutPerformedCount` 计数（无身份）；E6a'
仅中性计数（sE6_page_down/up）；E6a'' local monitor 仅计数（sE6_monitor_down/up，返回 event
原样，不读坐标/窗口/应用信息）；E6b 仅三中性 int（type/subtype/buttonNumber，编码进 sink 名，
无坐标/窗口标题/应用名）；测试夹具中性（fixture.* / A/B/C 代称与纯数值），无真实 app 名 /
bundle ID / 路径 / 标题。

## 8. 验证记录

- `swift build -c debug`：**exit 0**（Build complete! 5.11s，回合4增量后）。
- `swift build -c release`（强制重建：`rm -rf .build/arm64-apple-macosx/release` + 重建）：
  **exit 0**（Build complete! 24.40s）。
- release 二进制 strings 核验：回合4新增 sink（sE6_page_down/up、sE6_monitor_down/up）全
  PRESENT；既有（sE6a×4 / sE6b_meta / sE5_relayout_between_clicks / s10/s11/s8e/s13a/s13b/
  s18×4/sE1/s8c/s8d）全 PRESENT；已移除 `sE5_layout_ops_total` ABSENT → **二进制非陈旧**。
- 定向测试 ClickDeliveryProbeTests：**Executed 20 tests, with 0 failures**。
- `swift test` 全量：**Executed 1105 tests, with 0 failures (0 unexpected) in 16.793 (16.871)
  seconds**；`Test Suite 'All tests' passed`；exit 0 且 executed_tests=1105 > 0（基线 1098 + 新增 7）。
- 复测读数：**待 Main/用户实机回填**（§4 脚本；PAGING_CLICK_CENSUS=1）。

---

## 9. E4 段（追加 2026-09-04；任务包 §2.1 第 4 项 env 门控手动投递 A/B + 4b 顺带补读）

> 本段执行 E4（此前第 5 节「E4 本波不执行——E6 无果后置」由 A1 换输入（REPORT §14：
> subtype=0 30/43 亦死、s10 恒 0 → 触摸假说数值排除、h 升为现行最强、B1 资格达成）
> 转正的既定分支「subtype=0 且 s10=0 → 转 E4」触发。**§2.2 条件修复依旧零实现**
> （T1 作废 / H1 独立任务 / B1 待 E4 实机读数二分后由 Main/Chief 定案）。

### 9.1 改动清单（写范围：仅 AppDelegate.swift + 新测试文件）

`Sources/PagingPrototypeApp/AppDelegate.swift`（共 4 处，全部 E4/4b 自身）：

1. **E4 门控 helper**：文件尾 `private enum E4ManualDeliveryGate`——`getenv("PAGING_CLICK_PROBE_MANUAL_DELIVERY") == "1"` 每次实读（不用 ProcessInfo 字典，避免进程级缓存歧义；测试 setenv/unsetenv 确定性可控）。注释：**仅供诊断 A/B 实验，禁止作为生产路径常驻**。
2. **sendEvent cell 放行分支（else 块，s8d 计数后、:1213 原仅一行处）**：门控开 → `ClickCensus.hit(Sink.e4ManualDelivery)` + `hit?.mouseDown(with: event)` + `return`（**不调 super**）；门控关 → 原路径逐字不变（s8d / s18 absent+present 记账照旧）。`hit` 为该分支既有 `contentView.hitTest(point)` 结果（作用域内，未新增变量）。
3. **4b 启动期一次性补读**（`NSApp.activate(ignoringOtherApps:)` 后、5b 全屏前）：仅门控开时打印单行 `paging-click-probe: ...`（风格同既有 paging-fullscreen 单行 + fflush；中性：布尔/枚举级状态，无身份/坐标/标题）。每击内联 E1 复核（`event.windowNumber == self.windowNumber`）已有布点（sendEvent leftMouseDown 分支），未重复。
4. **sE4 sink 声明**：`extension ClickCensus.Sink` 新增 `e4ManualDelivery = "sE4_manual_delivery"`（仅命名空间声明 + 计数，机制沿用 ClickCensus）。

`Tests/PagingUITests/E4ManualDeliveryTests.swift`（新文件，4 测试，见 9.3）。

### 9.2 门控自证（任务包 §7 验收「E4 env 默认关自证」；Reviewer 复检门控分支）

- **env 未设（默认关）**：`testGateOffByDefaultCellHitTakesUnchangedSuperPath` —— cell 命中 →
  s8d==1、s18 absent+present 合计==1（**super.sendEvent 完整走完、观测窗闭合 = 生产路径逐字不变**）、
  sE4==0（门控分支不进）、手动 hitTest 链照常记录。零行为变更实证。
- **env="1"（门控开）**：`testGateOnManuallyDeliversMouseDownToHitBeforeSuper` —— sE4==1、
  **s10==1（手动 `hit?.mouseDown` 到达同一 cell，s10 布点联动断言）**、s18 absent+present==0
  （手动投递后 return，super 未调）、手动链含 AppGridCellView（投递目标 = 手动 hitTest 命中 cell）。
- **env="0"（非 "1"）**：`testGateValueNonOneBehavesAsOff` —— 同默认关（判断严格等于 "1"）。
- **sink 名中性**：`testE4SinkNameIsNeutral` —— 无 windowNumber/_win_/NSApp 原文。

### 9.3 测试证据（全部真实执行，exit 0）

- `swift test --filter E4ManualDeliveryTests`：**Executed 4 tests, with 0 failures (0 unexpected)
  in 0.102 (0.103) seconds**。
- `swift test` 全量：**Executed 1109 tests, with 0 failures (0 unexpected)**；`Test Suite 'All tests'
  passed`；exit 0 且 executed_tests=1109 > 0（基线 1105 + 新增 4）。
- `swift build -c debug`：**exit 0**（Build complete! 2.33s）。
- `swift build -c release`：**exit 0**（Build complete! 6.00s）。
- release 二进制 strings 核验（非陈旧）：`sE4_manual_delivery`、`paging-click-probe:`、
  `PAGING_CLICK_PROBE_MANUAL_DELIVERY` 全 PRESENT（count=1 各一）。

### 9.4 4b 读数占位（启动期一次性行，门控开时出现一次）

```
paging-click-probe: ignoresMouseEvents window=<bool> contentView=<bool> level=<int> styleMask=<int> keyActive=<bool>
```

- 期望值：`ignoresMouseEvents` 两槽 false（正常窗口；注：NSView 无该属性，contentView 槽
  报告窗口级属性）；`level` = 0（`.normal` rawValue）；`styleMask` = 15（titled 1 | closable 2 |
  miniaturizable 4 | resizable 8，4b 打印于异步全屏 toggle 之前）；`keyActive` = true
  （activate 后 keyWindow==self；false 则指向 H1 激活顺序旁证）。
- A/B 实机读数（`PAGING_CLICK_CENSUS=1 PAGING_CLICK_PROBE_MANUAL_DELIVERY=1`，门控关 / 门控开
  各 10+ 击，记 s10/sA 增量 + subtype + present/absent）由 Main/用户按 §4/§7 回填后判：
  **结果 A**（s10 增）→ 事件与视图链健全、断点纯在 AppKit 分发 → B1 式 sendEvent 手动/规范化
  投递评估；**结果 B**（s10 恒 0）→ 事件被标 handled → 升级「重建事件 + 手动投递」（去 subtype
  门，仍 env 门控 + Reviewer 显式 PASS）。

### 9.5 Deviation（本波逐条）

1. **4b contentView ignoresMouseEvents 槽 = 窗口级属性**：NSView 无 `ignoresMouseEvents`
   （仅 NSWindow 有）；该开关作用于整窗事件，contentView 槽报告窗口级真值（代码注释说明）。
2. **E4 门控用 `getenv` 而非 ProcessInfo.environment**：进程级缓存歧义规避；测试可确定性
   setenv/unsetenv。语义仍为严格等于 "1"。
3. **新增中性 sink `sE4_manual_delivery`**：门控分支进入计数（门控关时恒 0 = 「分支不进」
   的可测判别位；辅助 A/B 日志相关性），非顺带功能改动。
4. **门控开启时 s18 absent+present 恒 0**：E4 分支在内部路由观测窗（beginInternalObservation）
   之前 return——测试以此断言「super 未调」，与门控关（恰一）形成判别对。
5. **4b 不做单测**：启动期一次性打印（依赖真实启动序），由构建 + 代码评审 + 实机 A/B 读数覆盖。

### 9.6 AccessDeclaration

**NO_PRIOR_EXPOSURE**：本段未读取 LaunchBetter/BuhoReverseNotes/2026-08-25-buho-launchpad-reverse
及任何 Ghidra/otool dump；B1 仅按任务包/RESPORT §14 收敛路径描述（env 门控先行、Main/Chief
定案），**未照搬任何外部实现**；E4/4b 输出中性（仅布尔/枚举级状态与计数，无真实 app 名 /
bundle ID / 路径 / 坐标）；strings 核验仅针对本项目自身 release 构建产物（既有 rounds 同款
做法），非外部二进制分析。

### 9.7 冻结树/wave-b 领地零触碰声明

- 冻结树全列（PagingCore/AppCatalogCore/MacAppCatalog/AppIconPipeline/PagingTelemetry/
  PagingUI/Package.swift/AppLaunchController.swift）：**零改动**。
- `DragUIVisuals.swift`/`DragUISessionCoordinator.swift`（wave-b 领地）：**零改动**。
- `FolderOverlayView.swift`、`DropIntent.swift`、`DragParameters`、Docs/：**零改动**；无 git 操作。
- 本段改动文件：`Sources/PagingPrototypeApp/AppDelegate.swift`（仅 9.1 四处）、
  `Tests/PagingUITests/E4ManualDeliveryTests.swift`（新增）、本结果文件。

## 10. B1 段（追加 2026-09-04；任务包 §2.2 B1 生产修复候选 — **[completed]**）

> 状态：**completed**（代码实现 + 测试全量通过；转正仍需 Main/Chief 定案 + Reviewer 显式
> PASS——默认关状态不得擅自转正，任务包 §2.2 B1 行）。

### 10.1 改动清单

1. `Sources/PagingPrototypeApp/AppDelegate.swift`（仅 §3 写范围：sendEvent + 门控常量 +
   记录属性）：
   - `private enum B1ManualDeliveryGate`（QuitOnBlankClickWindow 前）：env
     `PAGING_CLICK_MANUAL_DELIVERY=1`（**默认关**；经 `getenv` 每次实读，与 E4 探针门
     `PAGING_CLICK_PROBE_MANUAL_DELIVERY` 分离）。
   - `QuitOnBlankClickWindow`：`private weak var lastManualMouseDownView: NSView?`（B1 门控开
     时非 nil；门控关恒 nil，零行为影响）+ `override func resignKey()` 清记录（原失 key
     语义不变）。
   - `sendEvent`：①顶部门控块——leftMouseUp/leftMouseDragged 在记录非 nil 时投记录视图并
     return（记录清空仅 up）；②ESC key53 分支清记录后维持原 onEscapeDuringDrag 语义逐字；
     ③leftMouseDown cell 命中 else 分支（既有 s8d 计数后）：B1 门开 → 手动
     `hit?.mouseDown(with: event)` + 记录 + return（**位于 E4 探针分支之前**，同开 B1 优先）。
   - 空白分支 / 记录 nil 的 up/dragged / 门控关：全部维持原 `super.sendEvent` 语义逐字不变。
2. `Tests/PagingUITests/B1ManualDeliveryTests.swift`（新增；§3 测试写范围）：
   - Fixture A（轻量：探针 contentView + 计数 cell 子类，不触碰冻结树）：门默认关/「0」/门开
     down+up+drag 投递与清记录/空白 s8+s8c/ESC 清记录/两门同开 B1 优先/仅探针门独立。
   - Fixture B（全链：真实 QuitOnBlankClickWindow + coordinator 全 wiring 复刻
     DragCommitIntegrationTests 装配，store 持久化腿未建模）：click 闭环
     s10/s9b/s6/sA 全链、5 连击无 stuck-.pressed、拖拽回归、ESC cancel + 恢复、门关全链自证。
   - **零新增 census sink**：全部断言复用既有 sink（s8d/s8/s8b/s8c/s10/s11/s13a/s13b/s9b/
     s9_leak/s5/s6/sA/sE4/s18 家族）。

### 10.2 门控语义声明（两门互斥/分离）

- B1 门 = 生产修复候选（含 up/dragged 闭环）；E4 探针门 = 诊断二分器（无闭环），**保留原位
  不动**。两门判断各自独立经 getenv 实读：仅 B1 开 → B1 分支执行（sE4 恒 0）；仅探针开 →
  E4 分支执行（sE4==1，独立可测）；两门同开 → **B1 优先**（B1 分支先行 return，E4 分支不可达，
  行为确定）。
- 闭环语义（REPORT §15 ②）：cell.mouseUp → coordinator.pointerUp（活动会话）→ endSession
  （s9b）→ dispatchClick（s6）→ onCellClick → sA launch；记录 nil / 门控关 → up/dragged 维持
  super 原语义。
- 「s5 增量≥击数」验收字面映射（deviation）：现行 `s5_up_idle_swallow` 是 pointerUp 在
  controller idle 时**吞点**标记（健康 click 路径恒 0），任务验收字面在此 sink 语义下不可达
  且禁止新增 sink → 测试断言以 s10==击数 / s9b==击数 / s6==击数 / sA==击数 / **s5==0**（健康、
  无 idle-swallow）等价覆盖「up 闭环」。

### 10.3 测试证据（全量执行后回填总账；B1 定向已执行）

- `swift build -c debug`：exit 0（Build complete 5.99s）。
- `swift build -c release`：exit 0（Build complete 11.98s）。
- `swift test --filter B1ManualDeliveryTests`：**Executed 14 tests, with 0 failures (0
  unexpected)**（14/14 通过；覆盖门默认关/「0」/门开 down/up/drag 投递与清记录/空白 s8+s8c/
  ESC 清记录/两门同开 B1 优先/仅探针门独立/全链 click 闭环/5 连击/拖拽回归/ESC cancel+恢复/
  门关全链自证）。
- `swift test` 全量：**Executed 1123 tests, with 0 failures (0 unexpected) in 16.813s**，
  exit 0（真实执行，executed_tests>0）。注：任务包 §6 基线 1089 为波次中途口径；本机现树
  1123 = 既有累计（含 forensics/E4 波在树测试）+ 本段新增 14；0 failures 为权威判据。

### 10.4 验收逐条（§7 B1 项映射；最终态待全量回填）

- [x] §2.1 取证完成 → 判别命中 §2.2 **B1**（h 定罪，§15 E4 结果 A 实机确认；§9 E4 段已载）。
- [x] env 默认关自证：未设两门 → sendEvent 行为零变更（Fixture A `s8d==1`、s18 闭合恰一、
  s10==0、sE4==0、s4c==0；Fixture B 全链 s10/s6/sA 恒 0、s8d 照计——生产死路径复现自证）。
- [x] **B1 闭环验收（门控开）**：Fixture B 全链——s10 增量=击数、s9b 配平、s6>0、
  **sA_launch_accepted>0**（launcher.opened==1、lastOutcome==.launched、state .idle、
  recognizer 恢复）；5 连击 s13a/s13b 各 5 配平、s9_leak==0、每击后 .idle（无 stuck-.pressed）。
- [x] **空白 + ESC 强制回归（门控开）**：空白 s8+s8c 正常（onBlankClick 回调、s10==0）；
  ESC key53 → cancel(.escape) → .idle + s9b 恢复（对照 B-run 双失效态翻转）+ 新一轮点击恢复。
- [x] 命中行 B1 实现 + 回归锁（门控开冷启动路径 click s10 正常增、sA 正常增——Fixture B 全链）。
- [x] 拖拽回归：down→dragged 过阈值→.dragging→up → `.committed`（commits==1）+ s6/sA 零
  （拖拽不派发 click/不启动）+ up 后 .idle。
- [x] `swift test` 全量（现树 1123）通过：**0 failures**，exit 0；debug/release 双构建 exit 0。
- [x] 零新增 census sink（复用 s8d/s8/s8c/s10/s11/s13a/s13b/s9b/s9_leak/s5/s6/sA/sE4/s18
  + s4c fallbackArmed 既有计数；无任何新 Sink 名）。
- [x] 冻结树零改动 + 无照搬外部实现（10.5/10.6/10.7 声明）。
- [ ] H1（潜因加固）：**本波未执行**（不属 B1 行；§13 裁决独立提交，留 Main/Chief 定案）。

### 10.5 Deviation（本段逐条）

1. **s5 验收字面映射**（见 10.2）。
2. **Fixture B store 持久化腿未建模**：B1 全链断言不依赖 store（复刻装配去除 makeTempStore/
   LayoutStoreActor；onCommit 保留呈现刷新 + commits 记录）。
3. **ESC 清记录为防御性**：正常流程（记录视图配对 up 后已清）下 stale 场景仅存于「down →
   ESC 打断 → 无后续 down」；测试断言 cancel 至 .idle + 新一轮闭环恢复（详见测试注释）。
4. **resignKey 清记录**：窗口失 key 原语义（AppDelegate windowDidResignKey →
   cancel(.windowResign)）零触碰，仅叠加记录清空（门控关恒 nil → 零行为）。
5. **Fixture A 投递观测走 fallback 链而非 .pressed**：`AppGridCellView` 为 final（不可测试
   子类化—冻结树），裸 cell 无 bindingToken → source 解析失败走既有 fallback 武装（s4c）→
   up 经 fallback 分支派发（onCellClick 计数断言投递）；dragged 过阈值 → fallback 清除 +
   endSession → 随后 up 落 idle → s5（拖拽投递判别对）。.pressed 全链验收在 Fixture B。
6. **拖拽回归落点需跨 slot**：源 slot 自身 drop zone 内落点 = mutation noOp（不 commit，
   控制器语义）；测试拖至 +350 跨列落点（既有 DragCommit reorder 测试因未挂窗 cell 零
   frame、落点 (0,0)→520 意外等效跨 zone commit——本 harness 用真实坐标，修正落点后
   commit 语义一致）。B1 投递路径本身与该差异无关（bisect 验证：同落点直接 coordinator
   调用同样 noOp）。

### 10.6 AccessDeclaration

**NO_PRIOR_EXPOSURE**：本段实现仅依据任务包 §2.2 B1 定案行 + REPORT §15 行为层结论（本项目
census 与代码结构）；未读取 LaunchBetter/BuhoReverseNotes/2026-08-25-buho-launchpad-reverse/
Ghidra/otool dump，**未照搬 Buho 或任何外部实现**（digest 仅参考、禁止作为实现依据的红线
遵守）；日志/断言中性（仅计数与枚举，无 app 名/bundleID/路径/坐标）。

### 10.7 冻结树/wave-b 领地零触碰声明（本段）

- 冻结树全列（PagingCore/AppCatalogCore/MacAppCatalog/AppIconPipeline/PagingTelemetry/
  PagingUI/Package.swift/AppLaunchController.swift）：**零改动**。
- `DragUIVisuals.swift`/`DragUISessionCoordinator.swift`（wave-b 领地）/
  `AppGridCellView.swift`/`FolderOverlayView.swift`/`DropIntent.swift`/`DragParameters`/
  Docs/：**零改动**；无 git 操作。
- 本段改动文件：`Sources/PagingPrototypeApp/AppDelegate.swift`（仅 10.1 所列三处）、
  `Tests/PagingUITests/B1ManualDeliveryTests.swift`（新增）、本结果文件。
