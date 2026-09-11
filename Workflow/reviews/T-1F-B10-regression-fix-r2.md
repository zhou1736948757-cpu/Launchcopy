# T-1F-B10-regression-fix-r2 — Reviewer 独立评审（E1+E5 取证步）

- 日期：2026-09-03
- 角色：Reviewer（glm-5.3-flash:cloud，只读门禁；未编辑任何实现文件）
- 任务包：Workflow/tasks/T-1F-B10-regression-fix.md（§2.1 步骤 1-4 追加 E1+E5；步骤 5 E4 本波不执行属预期）
- Worker 结果：Workflow/results/T-1F-B10-regression-fix.md（叠加 s18 基线；§2.2 条件修复未命中 → 零实现）
- 权威背景：Workflow/BUG10-REGRESSION-REPORT.md（§7-§9：run2 读数 + e/f/c/b 候选 + E1/E5 判别表）
- 关联：r1（s18 六测试，PASS）；r2 范围 = E1/E5 新增（9 测试）

## 判定：PASS

E1/E5 零行为观测装置实现克制、观测点先于既有空判定、sink 中性、9 新增测试真实
可执行、写范围合规、独立实跑全绿（debug/release exit 0、strings PRESENT、swift test
1098/0）。2 条 MINOR（E5 降级前提不实 / funnel 覆盖边界未在结果文件标注）、1 条
QUESTION，均不影响判定、不要求重审。

## Findings

### BLOCKER
无。

### MAJOR
无。

### MINOR

**M1. Deviation 6「E5 无公开只读入口，降级为强制」前提不实；降级实为选择，且 funnel
覆盖有已知空洞**
- 证据：PagingSurface.swift:169 `layoutPerformedCount` 为 `public private(set)`，于
  :742（`relayoutPages()` 内）`+= 1` —— 是精确的公开只读 relayout 计数；`liveHostCount`
  :171 / `poolHostCount` :173 同为 `public private(set)`。先例：AppDelegate.swift:945
  selfdrive stats 已读 `surface.layoutPerformedCount`。liveHosts/reusePool/relayoutPages
  三者 private/internal 属实，但「无公开只读入口」不成立。
- 影响：funnel（applyPresentationUpdate :718 一行记账）欠计 resize/全屏过渡触发的
  relayout（PagingSurface `layout()` :824-840 → `relayoutPages()` :839；候选 b 场景！）
  与 page-range 类 relayout；refreshPresentation :609-625 在 idle+revision 未变时 no-op，
  而 funnel 仍计数 → 过计。E5 判别力减弱但未毁：`_yes` 为 relayout 活动下界，主路径
  相关仍可观测。建议后续波次直接读 `surface.layoutPerformedCount`（公开只读，零
  PagingUI 触碰）。

**M2. 结果文件未标注 `_yes/_no` 为运行期构名**
- 证据：strings 只见基名 `sE5_relayout_between_clicks`（独立核验 ×2），`_yes`/`_no`
  后缀在 `relayoutBetweenClicks(_:)`（AppDelegate.swift:1415-1416）运行期拼接。与
  Deviation 8 一致，但结果文件 §6 应以「基名+后缀」形式呈现 sink 清单，避免实机读数
  时按字面 strings 对不上。

### QUESTION

**Q1. E5 funnel 覆盖边界与 §9 判别表口径的一致性**
- 若实机读数出现「absent + _no（funnel 未计 relayout）」组合，按判别表将指向「未命中
  f」，但该组合可能只是 funnel 未覆盖 resize/全屏路径（M1），而非真实无 relayout。
  建议在结果文件判别口径中显式注明漏斗覆盖边界，实机回填时先按 `_yes` 判 f、`_no`
  仅作弱证据。

## 逐项核验

### A. 零行为变更 — ✅ 通过（代码直读）
- E1/E5 观测（AppDelegate.swift:1117-1129）位于 leftMouseDown 分支开头，**先于**既有
  空判定/吞点/终止早退（blank :1144、drag 吞 :1151-1155、folder :1159-1163、搜索退出
  :1167-1170、terminate :1171-1175），对每个 leftMouseDown（含被吞点击）记账 —— 仅
  计数/读 ivar，零控制流变更。
- `lastLayoutOpsAtPreviousClick` 私有 ivar :1098 仅 :1126-1129 使用（grep 证实）。
- `applyPresentationUpdate` :718 一行计数，位于 guard :710 之后、既有调用之前
  （:720-723）；三个调用点 :335/:428/:584 均属既有路径。
- 探针 hitTest :1252-1264 / mouseDown :1266-1270 纯转发（super 结果原样返回），r1
  已核验。s17/blank 逻辑 :1277-1307 未动。

### B. E1/E5 sink 中性 — ✅ 通过
- 窗号仅进程内三对相等比较，sink 名不含 windowNumber/_win_/NSApp（:1397-1404；
  test ⑨ 字符串断言锁死）；计数经 ClickCensus（PAGING_CLICK_CENSUS=1 门控），核心
  机制零改动。
- 隐私：不落盘、不传参、无类名/坐标注入。

### C. 观测有效性 — ✅ 通过（含 M1 边界）
- E1 语义：三数两两比较 → match/evSelf/evKey/selfKey 四 sink 恰一互斥成立；
  (11,22,22)→evSelf+evKey 两位（=任务焦点）、(33,33,nil)→evKey+selfKey、nil≠任何 Int。
- E5：点击间差分（layoutOpTotal 增量 > 0 → _yes），基线每次 leftMouseDown 滚动。
- 判别力：E1 无损；E5 因 M1 funnel 覆盖边界存在空洞 → 判别力减弱（下界信号仍有效）。

### D. 测试 — ✅ 通过（独立实跑 15/15）
- 本波 9 测试真实可执行：E1 五测（三对比较语义 + e2e 每点击一致性）、E5 二测（直调
  helper + e2e 差分基线滚动）、⑨ sink 名中性断言、⑩ 门控关闭静默（dup2 捕获 stderr）。
- 夹具全中性；首轮 1 failure 为夹具断言误设（三数两两比较语义），修正断言非实现 ——
  Deviation 7 合理。

### E. 写范围 — ✅ 通过（mtime 取证）
- 任务包 13:56:41 之后仅 AppDelegate.swift（14:02:38）+ ClickDeliveryProbeTests.swift
  （14:04:09）+ results（14:07:39）。冻结树/领地全部早于任务（DragUISessionCoordinator
  09-02 17:52:53、FolderOverlayView 09-02 18:14:22、PagingSurface 08-30、Package.swift
  08-28、AppLaunchController 08-28 等）。无 git 操作。

### F. 独立实跑 — ✅ 通过（Reviewer 亲自执行）
- `swift build -c debug`：exit 0。
- `swift build -c release`（rm -rf 干净重建）：exit 0，Build complete! (22.76s)，
  二进制 2,891,680 B @ 14:11（与 Worker 声称同尺寸）。
- strings：sE1_window_owner_match / _mismatch_evSelf / _mismatch_evKey /
  _mismatch_selfKey 各 1、sE5_layout_ops_total 1、sE5_relayout_between_clicks（基名）2、
  PAGING_CLICK_CENSUS 2 —— PRESENT。
- `swift test` 全量：`Executed 1098 tests, with 0 failures`，exit 0（= 1089 基线 + 9
  新增，与 Worker 声称一致）；其中 ClickDeliveryProbeTests 15/15。

### G. Deviation 合理性 — ✅ 通过
1-5. 同 r1 成立（contentView 即探针 / 手动标记先于调用 / folder 路径不记账 /
   测试入 PagingUITests 新文件 / s18 编号复用无冲突）。
6. 降级动机成立（不改 PagingUI 的约束），但「强制」前提不实 → M1。
7. 夹具修正合理。8. 基名+运行期后缀 → M2。

### H. 红线 — ✅ 通过
- Sources/Tests grep：LaunchBetter / BuhoReverseNotes / 2026-08-25-buho-launchpad-
  reverse / Ghidra / otool 零命中。
- E4 未执行属预期（§2.1 步骤 5，env 门控手动投递，等 E1 读数不中后由 Main 决策）。

## 验收对照（任务包 §7）

- [x] §2.1 步骤 1-4 取证完成：E1 布尔位 + E5 时序中性计数装置落地，判别口径入结果文件
- [x] 构建状态核验：debug/release 双构建 exit 0；strings PRESENT（复测脚本口径一致）
- [x] §2.2 未命中 → 零实现；§4 冻结树/领地零触碰（mtime 自证）
- [x] `swift test` 全量 1098/0（独立实跑）；步骤 5 E4 按流程未执行（预期）

## 结论

E1/E5 装置设计与实现符合零行为观测契约，证据链完整，独立实跑全绿。M1/M2 为记录性
MINOR：建议后续波次直接用 `surface.layoutPerformedCount` 增强 E5 覆盖并修订结果文件
表述与 sink 清单。无需重审。判定 **PASS**。
