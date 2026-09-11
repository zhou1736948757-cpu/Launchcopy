# T-1F-B10-regression-fix-r3 — Reviewer 独立评审（E5-fix + E6a'/E6a'' + E6b + E6c 取证步）

- 日期：2026-09-03
- 角色：Reviewer（glm-5.3-flash:cloud，只读门禁；未编辑任何实现文件）
- 任务包：Workflow/tasks/T-1F-B10-regression-fix.md（§2.1 步骤 2-8；回合4 更新：E6a'/E6a'' 写范围扩至 AppGridPageView.swift）
- Worker 结果：Workflow/results/T-1F-B10-regression-fix.md（§2.2 未命中 → 零实现；E4 不执行）
- 权威背景：Workflow/BUG10-REGRESSION-REPORT.md（§7-§11：e/f/g/h/c/j/i 候选 + E6 判别表）
- 关联：r1（s18 六测试，PASS）、r2（E1+E5 九测试，PASS；M1 建议直接读 layoutPerformedCount——本波 E5-fix 即落实该建议）

## 判定：PASS

E5-fix/E6a'/E6a''/E6b/E6c 全部布点零行为变更、写范围合规（mtime 取证）、判别口径与任务包 §2.1 一致、隐私红线零触碰、独立实跑全绿（全量 1105/0、定向 20/0、release 干净重建 exit 0、strings 新旧 sink 全对位）。2 条 MINOR、1 条 QUESTION，均不影响判定、不要求重审。

## Findings

### BLOCKER
无。

### MAJOR
无。

### MINOR

**M1. §7 验收第 1 项「读数写入结果文件」待 Main/用户实机回填**
- 证据：结果文件 §4 复测脚本完整（①-⑩ 读数项 + 判别口径），但读数区标注「待 Main/用户实机回填」；§2.2 条件修复保持零实现。
- 影响：本波交付物 = 取证装置 + 复测脚本（任务包 §2.1 步骤 8 明确定义为脚本），实机读数需人工点击 GUI 应用，Worker 无法自产——与 r2 先例一致（E1 读数由 Main 回填于 REPORT §10）。§2.2 零实现为任务包 §4 强制的安全态，正确。回填前该 checkbox 不关闭；判别命中后才可进入 §2.2。

**M2. 「无 git」表述不精确**
- 证据：仓库已 `git init`（.git mtime 2026-09-03 02:36），`git status` 显示 main 分支零提交、全文件 untracked。
- 影响：实质成立（无提交历史可 diff，r2 同判），mtime 取证已替代 diff 基线；建议后续结果文件表述为「无提交历史」。

### QUESTION

**Q1. E6b 记录面含 rightMouseDown/otherMouseDown 的判别边界**
- 若实机运行中出现右键，`sE6b_meta_type_3_subtype_0_button_1` 按字面判别口径（type≠leftMouseDown → c/j）会指向系统拦截。复测脚本全为左键点击（点 cell ×3 / 空白 ×1 / 翻页 / 再点 cell ×2），无实际影响；回填判读时建议注明仅对左键读数应用 c/j 判别。

## 逐项核验

### A. 零行为变更 — ✅ 通过（代码直读）
- **E5-fix**：provider 闭包（AppDelegate.swift:255-257 `self?.surface?.layoutPerformedCount ?? 0`）只读 `PagingSurface.swift:169 public private(set) layoutPerformedCount`（已核验 :169 声明与 :742 relayoutPages 内增量）；sendEvent :1160-1163 差分观测 + 基线 ivar :1118 滚动，纯读+计数。降级 funnel 移除属实：`layoutOpTotal`/`sE5_layout_ops_total` 源码零命中（grep 全仓仅 results/reviews 文档提及），applyPresentationUpdate 已无该计数行——纯观测移除。
- **E6a 探针四事件**：mouseUp/mouseDragged/rightMouseDown/otherMouseDown（:1313-1331）census + super 原样转发，Void 方法无返回值变更。
- **E6a' AppGridPageView**：mouseDown/mouseUp（:313-322）census + super；NSView 默认实现为空操作，覆写后行为恒等。
- **E6a'' local monitor**：`NSEvent.addLocalMonitorForEvents`（:91-94，local 非全局）返回 event 原样；安装于 applicationDidFinishLaunching :91（telemetry 后）；移除于 teardownAll :1072-1075（`if let` + nil 置空 = 幂等）。
- sendEvent 结构零变更：ESC 早退/空判定/吞点/终止路径原样；E6b switch（:1131-1139）与 E1/E5 观测均先于既有逻辑、纯观测。

### B. 写范围合规 — ✅ 通过（mtime 取证）
- 2026-09-03 改动文件恰为声明集：AppGridPageView.swift 14:52:19、AppDelegate.swift 14:53:29、ClickDeliveryProbeTests.swift 14:54:06、AppGridPageViewTests.swift 14:53:51、results 14:55:57。
- 冻结树最新 2026-08-30 15:15:30（PagingFrameDriver.swift）；Package.swift / AppLaunchController.swift 08-28——零触碰。
- wave-b 领地全为上一波：DragUIVisuals.swift 09-02 17:52:50、DragUISessionCoordinator.swift 09-02 17:52:53、FolderOverlayView.swift 09-02 18:14:22、DropIntent.swift 09-02 16:39:56——零触碰。
- AppGridPageView.swift 在回合4任务包 §3 授权内（AppGridUI 非冻结）。

### C. 判别有效性 — ✅ 通过
- sE6_page_down/up >0 → f 族定罪：sink 布于 AppGridPageView.mouseDown 入口，投递即触发；健康态投递直达 cell（s10），page 恒 0——判别成立。
- monitor 有而视图全零 → h；monitor 无 → 分发前被吞：monitor 计分发入口（先于窗口路由），视图 sink 计投递终点，组合可判别。
- E6b 三中性 int 编码进 sink 名（type/subtype/buttonNumber），正常左键 = type_1_subtype_0_button_0，subtype≠0/type≠leftMouseDown → c/j 判别成立。
- E6c：s8c/s8d 既有布点（AppGridCellView.swift:215-217 漏斗、:234-241 s10/s11 在位核验）足够。

### D. 测试真实性 — ✅ 通过（Reviewer 独立实跑）
- 全量 `swift test`：**Executed 1105 tests, with 0 failures (0 unexpected) in 19.797 (19.902) seconds**；`Test Suite 'All tests' passed`；exit 0（Worker 声称 1105/0 一致；时长 16.793s vs 19.797s 为运行差异，计数一致）。
- 定向 ClickDeliveryProbeTests：**Executed 20 tests, with 0 failures (0 unexpected) in 0.466 (0.470) seconds**。
- 定向 AppGridPageViewTests：**Executed 14 tests, with 0 failures**（12 基线 + 新增 2：testPageViewMouseDownUpForwardingCensus / testPageViewSinkNamesAreNeutral，代码直读确认）。
- `swift build -c release`（rm -rf 干净重建）：**Build complete! (31.86s)**，exit 0。
- release 二进制 strings 独立核验：sE6_page_down/up、sE6_monitor_down/up、sE6b_meta、sE5_relayout_between_clicks（×2）、sE6a_probe×4 全 PRESENT；`sE5_layout_ops_total` ABSENT；s10/s11/s8c/s8d/sE1/s18×3/s8e/s13a/s13b 全 PRESENT——非陈旧。
- 全部 executed_tests > 0（无 INVALID_TEST_EXECUTION）。

### E. 隐私红线 — ✅ 通过
- sink 名全中性（无 windowNumber/_win_/NSApp/坐标/标题/应用名/bundleID/路径；测试字符串断言锁死）。
- local monitor 仅计数、返回 event 原样、不打印事件内容；E6b 仅三中性 int。
- Sources/Tests grep：LaunchBetter/BuhoReverseNotes/2026-08-25-buho-launchpad-reverse/Ghidra/otool 零命中（grep_exit=1）。
- 夹具中性（fixture.* / A/B/C 代称与纯数值）。

### F. Deviation 逐条 — ✅ 通过（可接受）
1. provider 闭包接线：窗口不持 surface，AppDelegate 接线只读闭包——与「AppDelegate 侧观测」语义一致。
2. 降级 funnel 移除：源码核验属实，纯观测移除；既有测试改写为 provider 差分语义。
3. E6b 范围 = mouseDown 家族：判别口径含 type≠leftMouseDown，记录面覆盖三按钮按下，合理。
4. 数值编码进 sink 名：沿用 s8e/s17 状态位先例，仅中性 int。
5. E6c 零代码：既有布点足够。
6. E6a 按回合4重定义：任务包 §2.1 步骤 3/4 + §3 写范围确认；探针四事件保留为补充观测（sE6a_probe_*）。
7. E6a'' 测试面 = helper 直调：monitor 生命周期需真实事件分发无法单测，安装/移除代码 4 行经代码评审 + 构建覆盖——可接受。

### G. 复测脚本完整性 — ✅ 通过
- ①-⑩ 读数项齐全（s18 手动/内部链、delivered_contentview、E5-fix 差分、sE6_page、sE6_monitor、sE6a_probe×4、sE6b_meta、s10/sA、s8c/s8d 对照）；判别口径与任务包 §2.1 逐条一致。

## 验收对照（任务包 §7）

- [x] §2.1 取证装置完成（E5-fix/E6a'/E6a''/E6b/E6c 全部布点 + 复测脚本）；读数待 Main/用户实机回填（M1）
- [x] E4 未执行属预期（E6 无果后置）；env 门控缺省关自证（testESinksSilentWhenGateOffByDefault 独立实跑通过）
- [x] §2.2 未命中 → 零实现（正确安全态）；冻结树/领地零触碰（mtime 自证）
- [x] `swift test` 全量 1105/0（独立实跑）；debug（测试构建）+ release 干净重建 exit 0

## 结论

E5-fix 落实 r2 M1（直接读 layoutPerformedCount），E6a'/E6a''/E6b/E6c 布点全部符合零行为观测契约，证据链完整，独立实跑全绿，写范围与隐私红线零触碰。M1/M2 为记录性 MINOR：读数回填后关闭 §7 第 1 项并据判别决定是否进入 §2.2；结果文件表述「无提交历史」更精确。无需重审。判定 **PASS**。
