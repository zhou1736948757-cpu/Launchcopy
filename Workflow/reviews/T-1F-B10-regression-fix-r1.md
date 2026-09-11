# T-1F-B10-regression-fix-r1 — Reviewer 独立评审（§2.1 取证步）

- 日期：2026-09-03
- 角色：Reviewer（glm-5.3-flash:cloud，只读门禁；未编辑任何实现文件）
- 任务包：Workflow/tasks/T-1F-B10-regression-fix.md（§2.1 取证步；§2.2 未命中 → 零实现）
- Worker 结果：Workflow/results/T-1F-B10-regression-fix.md（Worker 0d7332ab）
- 权威背景：Workflow/BUG10-REGRESSION-REPORT.md（Chief 诊断）

## 判定：PASS

§2.1 取证装置落地正确、零行为变更、sink 中性、测试真实覆盖、写范围合规、独立实跑全绿；
§2.2 未命中 → 零实现（符合任务包「未命中禁止实现」）。1 条 MINOR（结果文件文档性表述不准确），
不影响判定。

## Findings

### BLOCKER
无。

### MAJOR
无。

### MINOR

**M1. 结果文件 §1.3/Deviation 3「folder 打开路径其内部链仍被探针记录」表述不准确**
- 证据：AppDelegate.swift:1130-1133 folder 打开分支内 `super.sendEvent(event)` 后立即 `return`；
  `beginInternalObservation()` 仅在 :1157（放行点前）调用，该路径不可达 → 该次 super.sendEvent
  期间 `observingInternalRouting == false`，探针 hitTest（:1229 `else if observingInternalRouting`）
  不记录内部链。实际行为 = folder 打开路径完全不记账（与设计一致，非本波目标面）。
- 影响：仅结果文件文档性表述错误；观测装置行为与设计一致，无行为风险。建议 Worker 修订该句
  为「folder 打开路径不记账（含内部链），其内部路由不在本波观测面」。

### QUESTION

**Q1. 内部 hitTest 计数对照的精度边界**
- 证据：absent/present 判别基于 super.sendEvent 前后 `internalHitTestCallCount` 对照（:1159-1167）。
  若 AppKit 在观测窗内因非 mouseDown 路由原因（cursor rect/tooltip 等）调用 hitTest，present 会
  误触发；absent 信号不受影响（仍 = 未咨询视图树）。
- 影响：判别口径「absent → 候选 ①」仍成立；present 需结合内部链 sink 判读。无行为风险，实机
  回填读数时注意即可。

## 逐项核验（A-H）

### A. 零行为变更 — ✅ 通过（代码直读）
- `ClickDeliveryProbeView.hitTest`（AppDelegate.swift:1223-1235）：`let result = super.hitTest(point)`
  后仅记账，原样返回 result。纯转发。
- `mouseDown`（:1237-1241）：记账后 `super.mouseDown(with: event)`。纯转发。
- 容器 :210：`ClickDeliveryProbeView(frame: window.contentLayoutRect)` — 与普通 NSView 同 frame
  （contentLayoutRect）、同子视图（surface :215、search field :220）、同存储类型（`container: NSView?`
  :23）。类型变更仅此一处；探针为纯 NSView 子类，尺寸/层级/坐标零差异。
- sendEvent 观测（:1098-1099、:1109-1114、:1156-1168）：纯增量。既有分支条件/返回值/吞点/终止
  路径（:1090-1151）逐字未动；非探针 contentView（`as?` 为 nil）全部 no-op（:1109、:1156-1168
  守卫）。空白早退路径（drag 吞点 :1125 / 退出搜索 :1140 / 终止 :1146）均 return 于观测点之前，
  不记账 — 与既有早退语义一致。

### B. s18 sink 中性 — ✅ 通过
- 链编码仅 `type(of:)` 类名（:1211-1221），封顶 8 层，禁坐标/身份/标题。
- 计数经 `ClickCensus.hit`（DragUISessionCoordinator.swift:87-95）：内存计数恒维护；stderr 输出仅
  env `PAGING_CLICK_CENSUS=1` 门控。ClickCensus 核心零改动（本波仅 AppDelegate 内 extension
  命名空间声明 :1331-1359）。
- s18 编号无冲突：全库 grep 无其他 s18 sink（wave-a 预留未落地，复用成立）。

### C. 观测有效性 — ✅ 通过（含 M1）
- `markNextHitTestAsManual()`（:1111）在手动 hitTest（:1113）之前设置；探针即 contentView，
  标志必被本次调用消费，无跨调用滞留。
- 判别力：内部链 sink（:1231-1232）记录观测窗内每次 hitTest 的实际命中链（cell/pageHost/
  containerView/搜索框/其他）；absent/present（:1163-1167）判别 AppKit 是否咨询视图树。
  内部链 = cell → 同源；≠ cell → 候选 ①；absent → 不同源。口径成立。
- 语义清晰：`s18_hit_manual_chain_*` = s8d 判定依据；`s18_hit_internal_chain_*` = AppKit 实际
  投递目标；`s18_delivered_contentview` = 投递目标为容器自身（Chief 候选直接证据）；
  `s18_internal_hittest_absent|present` = 放行后是否咨询视图树。

### D. 测试 — ✅ 通过（独立实跑 6/6）
- ① 手动链 + super 返回值一致（=== cell）+ 内部链/计数零污染；
- ② 观测窗闭合语义（窗外零记录、窗内记录、关窗后不增）；
- ③ mouseDown 投递记账 + 转发 super 不 crash；
- ④ 真实 QuitOnBlankClickWindow.sendEvent 全链路（手动链含 AppGridCellView、s8d==1、不终止、
  absent/present 恰一）；
- ⑤ 探针 contentView 下空白终止路径不变（s8c==1、无 s8d）— 零行为变更回归锁；
- ⑥ 5 个 sink 名字符串断言 + 链编码仅类名。
- 夹具中性：合成数据（无真实 app 名/bundle ID/路径/标题），fixture 代称。

### E. 写范围 — ✅ 通过（mtime 取证）
- 任务包 mtime 02:31:53 之后仅 2 个源码/测试文件变更：AppDelegate.swift（02:38:15）、
  ClickDeliveryProbeTests.swift（02:38:33）；results（02:40:01）为任务产物。
- 冻结树零触碰：AppGridCellView.swift（09-01 23:05）、Package.swift（08-28）、
  AppLaunchController.swift（08-28）mtime 均早于任务。
- wave-b 领地零触碰：DragUIVisuals.swift / DragUISessionCoordinator.swift（09-02 17:52）早于任务。
- FolderOverlayView.swift / DropIntent.swift 未变。Workflow 运行时文件（STATE/heartbeats/
  watchdog/events）更新属正常。

### F. 独立实跑 — ✅ 通过（Reviewer 亲自执行）
- `swift build -c debug`：exit 0（Build complete!）
- `swift build -c release`：exit 0（Build complete!）
- `swift test` 全量：`Test Suite 'All tests' passed … Executed 1089 tests, with 0 failures
  (0 unexpected) in 25.307 (25.468) seconds`，exit 0，executed_tests > 0（= 1083 基线 + 6 新增，
  与 Worker 声称一致）。
- `swift test --filter ClickDeliveryProbeTests`：`Executed 6 tests, with 0 failures`，exit 0。

### G. Deviation 合理性 — ✅ 通过
1. 探针挂载 = contentView 本身：成立。子视图探针的 `super.hitTest` 会返回探针自身（普通 NSView
   命中即 self），劫持命中 = 行为变更；contentView 即探针是唯一零行为变更挂载点。
2. 手动标记须在调用前设置：成立（标志调用即消费，:1111 先于 :1113）。
3. folder 打开路径不记账：设计成立（非本波目标面）；但「内部链仍被探针记录」子句不实（M1）。
4. 测试分布（新文件入 PagingUITests，Package.swift 未改）：任务包 §3 明示「新文件或并入既有」，
   合规。
5. s18 编号复用：wave-a 预留未落地，无冲突（grep 证实）。
- 全部 deviation 无行为风险。

### H. 红线 — ✅ 通过
- 代码与结果文件无 LaunchBetter/BuhoReverseNotes/2026-08-25-buho-launchpad-reverse 任何引用
  （grep 仅命中结果文件 AccessDeclaration 的否认声明）。
- 隐私中性：sink 仅类名+计数+布尔位，无坐标/身份/标题。

## 验收对照（任务包 §7）

- [x] §2.1 取证完成：装置落地 + 判别口径写入结果文件；实机读数由 Main/用户按 §4 脚本回填
  （无头测试环境无真实投递，Worker 已如实标注为环境工件，非死态信号）
- [x] §2.2 未命中 → 零实现（符合「未命中禁止实现」）
- [x] `swift test` 全量 1089/0；debug+release 双构建 exit 0；冻结树零改动（mtime 自证）

## 结论

取证装置设计正确、实现克制、证据链完整。M1 为文档性 MINOR，建议 Worker 修订结果文件表述；
无需重审。判定 **PASS**。
