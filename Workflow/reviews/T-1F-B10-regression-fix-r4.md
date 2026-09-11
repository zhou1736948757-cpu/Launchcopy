# T-1F-B10-regression-fix — r4 独立评审（E4 取证步：env 门控手动投递 A/B + 4b 补读）

判定：**PASS**（E4 取证步可合并；§2.2 条件修复依旧零实现，B1 定案等待真机 A/B 实读数回填后由 Main/Chief 执行）

评审对象：任务包 §2.1 第 4 项（E4）+ 4b；Worker 结果 §9 段；AppDelegate.swift（E4ManualDeliveryGate、sendEvent 放行分支、4b 打印、sE4 sink）；Tests/PagingUITests/E4ManualDeliveryTests.swift（4 测试）。
角色：独立 Reviewer（只读）；从原任务包开始审查。

## Findings

| 级别 | 计数 |
|---|---|
| BLOCKER | 0 |
| MAJOR | 0 |
| MINOR | 1 |
| QUESTION | 2 |

### MINOR-1（cosmetic，不阻合并）
4b 块内 `let contentView = window.contentView` + `_ = contentView`（AppDelegate.swift:293-295）为死局部；两槽位均打印 `window.ignoresMouseEvents`。deviation 已在代码注释（:291-292）与结果 §9.5.1 双重说明（NSView 无该属性，contentView 槽报告窗口级真值）——可接受。建议：删死局部，或注释说明保留意图。

### QUESTION-1（结果 A 先验的证据强度与局限，重点裁决面）
门控开测试 `s10==1` 是**代码路径级先验（结果 A 先验）**，证据强度成立且充分：
- 强度：证明 E4 分支接线正确——合成事件经 `window.sendEvent` 进分支 → sE4=1 → 手动 `hit?.mouseDown` 直接调用到达 `AppGridCellView.mouseDown`（:188 先打 s10 再仲裁，不调 super）→ s10=1；s18 absent+present==0 证明 return 先于内部路由观测窗（super 未调），与门控关（恰一）构成判别对。
- 局限（须注明）：测试事件为 `NSEvent.mouseEvent` 合成（windowNumber 已设），与真实 window-server NSEvent（tracking session/device/subtype 元数据）不同；手动投递是直接方法调用，**按设计绕开 AppKit 内部分发层**——测试通过只能证明「事件/视图/响应链健全 + 分支接线健全」，不能缩小真实运行时断点空间。真机 A/B（门控关/开各 10+ 击、s10/sA 增量 + subtype + present/absent）仍是权威判别，Worker §9.4 已正确将其留待 Main/用户回填、未越权断言结论。先验判定结果 A 的前提（手动投递能触发 s10）在测试粒度上成立，可支撑 B1 进入定案评估流程，但**不替代**真机读数。
- 确认项：真机命中时 `hit` = cell 自身（hitTest 漏斗 AppGridCellView.swift:207-212 将子视图路由回 self），与测试夹具投递目标一致；`blankClickResolvesToCell(hit)==true` ⇒ hit 非 nil，`hit?.` 可选链纯防御。

### QUESTION-2（证据上限声明）
4b 不做单测（结果 §9.5.5；依赖真实启动序），由构建 + 代码评审 + 实机读数覆盖——接受；strings 核验已证 `paging-click-probe:` 入 release 二进制。真机 4b 期望值（styleMask=15/keyActive）由回填读数验证。

## 审查焦点逐项（A–G）

**A. 门控默认关 = 生产零行为变更：✅ 通过**
- 未设 env：`E4ManualDeliveryGate.isEnabled`（:1102-1107，computed property）`getenv` 每次实读、无缓存；guard nil → false。关态下 E4 分支不进，控制流逐字落到既有 `beginInternalObservation → super.sendEvent → absent/present 记账`（:1259-1274）；关态唯一新增开销 = 一次 getenv + 布尔比较，无分支泄漏/无额外调用/无 return 变化。
- 测试 ① 实证：s8d==1、absent+present==1、sE4==0、手动链==1（super 完整走完、观测窗闭合）。测试 ③（env="0"）同默认关（严格等于 "1"）。
- sE4 门控关恒 0：测试 ①/③ 双断言。代码审读确认 E4 分支在 s8d 之后、return 之前唯一入口。

**B. 门控开行为正确且受限：✅ 通过**
- 分支序：s8d（:1242）→ 门控（:1251）→ sE4 计数（:1252）→ `hit?.mouseDown(with: event)`（:1253）→ return（:1254，不调 super）。与 Worker §9.1.2 逐字一致（:1213 现为 :1251 区域，行号漂移因前序取证布点，语义一致）。
- 诊断注释在位三处：门（:1097-1099）、4b（:284-285）、sendEvent 分支（:1244-1250）；「仅供诊断 A/B 实验，禁止作为生产路径常驻」语义明确。空白/搜索/folder/drag 分支（:1208-1239）零改动。

**C. 测试真实性：✅ 通过（4/4 真实执行）**
- ① 默认关零行为自证、② 门控开 sE4=1/s10=1/super 未调、③ env="0" 同默认关、④ sink 名中性——断言语义与 9.2 声明一致；tearDown 兜底 unsetenv、ClickCensus.resetForTesting 每测试隔离。
- 先验强度与局限见 QUESTION-1（合成事件 vs 真实 NSEvent 差异已注明）。

**D. 4b 补读：✅ 通过（deviation 可接受）**
- 启动期一次性（:290-297）、E4 门控包裹、`fflush(stdout)`、风格同既有 paging-fullscreen 单行；输出仅布尔/枚举级（ignoresMouseEvents×2、level、styleMask、keyActive），无身份/坐标/标题。
- contentView ignoresMouseEvents 槽 = 窗口级属性（deviation 显式记录、代码注释在位）：NSWindow 唯一真值，标签明确，可接受。位置（activate 后、5b 全屏前）与任务包一致。

**E. 写范围：✅ 通过（mtime 取证独立复核）**
- E4 轮（2026-09-04）仅 3 文件：AppDelegate.swift 22:43:01、E4ManualDeliveryTests.swift 22:42:32、result 22:45:10。其余全部 ≤09-03（上一波 E6 的 AppGridPageView.swift/两测试文件）或 ≤09-02（FolderOverlayView 17:14、DragUISessionCoordinator/DragUIVisuals 16:52、DropIntent 15:39、Package.swift 08-28、Docs 09-01 18:01）；AppGridCellView.swift 09-01（s10 联动点，本波零触碰）。冻结树/wave-b 领地/AppGridPageView/Docs 零触碰；无 git。

**F. 独立实跑（Reviewer 实测，与 Worker 声称互证）：✅ 全部一致**
- `swift build -c debug`：exit 0（增量 0.31s）。
- `swift build -c release`（rm -rf release 强制重建）：exit 0（21.70s，Build complete）。
- `swift test` 全量：Executed 1109 tests, 0 failures (0 unexpected) in 15.48s；All tests passed；exit 0。
- `swift test --filter E4ManualDeliveryTests`：Executed 4 tests, 0 failures in 0.081s；exit 0。

**G. 红线：✅ 通过**
- 结果 §9.6 AccessDeclaration NO_PRIOR_EXPOSURE（未读 LaunchBetter/BuhoReverseNotes/2026-08-25-buho-launchpad-reverse/Ghidra/otool dump；B1 未照搬外部实现——本步零实现）；代码中性已核（sink 名无 windowNumber/_win_/NSApp 原文，测试 ④ 断言；4b 打印无 app 名/bundleID/路径/坐标；strings 核验仅针对自身构建产物）。
- 无 git 操作；本波对 §2.2 零实现（T1 作废/H1 独立/B1 待定案），符合「未完成取证禁止实现」纪律。

## 结论与验收对照

- 任务包 §7「E4 env 默认关自证」：✅（代码 + 测试 ①③ + 独立构建/测试复核）。
- Reviewer 显式 PASS 范围：**E4 取证步（门控装置 + 4b + 4 测试）**。真机 A/B 读数（§9.4 占位）与「结果 A→B1 定案 / 结果 B→重建事件升级」的二分，按任务包属 Main/Chief 定案流程，需真机回填后另行裁决——本 PASS 不代表 B1 已放行。
- 回归风险：生产路径零风险（默认关）；残留风险仅「用户环境意外设置该 env 触发诊断分支」（有注释警示，属预期诊断面）。

Confidence：**High**（源码逐行审读 + 双向独立实跑 + mtime 取证 + 结果文件与代码逐条对照）。

Reviewer：chef-worker-reviewer-workflow 独立 Reviewer（glm-5.3-flash:cloud，只读）；2026-09-04。
