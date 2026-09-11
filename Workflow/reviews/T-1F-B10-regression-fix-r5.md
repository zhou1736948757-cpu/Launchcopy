# T-1F-B10-regression-fix — Reviewer r5：B1 生产修复候选（env 门控手动投递闭环）独立评审

- 角色：独立 Reviewer（glm-5.3-flash:cloud，只读，未编辑任何实现/测试文件）
- 评审对象：任务包 §2.2 B1 定案行实现（AppDelegate.swift sendEvent + 门控常量 + B1ManualDeliveryTests.swift 14 测试）
- 起点：原任务包 T-1F-B10-regression-fix.md（§1 h 定罪 / §2.2 B1 行 / §3 写范围 / §4 禁写 / §6 验证 / §7 验收）
- 独立实跑：debug/release 双构建 + B1 定向 14/0 + 全量 1123/0（本次评审者本机执行，与 Worker 互证）
- 评审日期：2026-09-04

## 判定：PASS（显式 PASS，行为变更实现可进入转正路线——**转正仍需 Main/Chief 定案 + §6 实机 A/B 读数回填，见 QUESTION-1**）

分类计数：BLOCKER 0 / MAJOR 0 / MINOR 1 / QUESTION 2。

---

## Findings

### BLOCKER
无。

### MAJOR
无。

### MINOR

**M-1（证据卫生）：`Tests/PagingUITests/DragCommitIntegrationTests.swift` 存在 B1 波窗口内未声明的 mtime**
- mtime 2026-09-04 23:38:49，落在 B1 实现窗口（AppDelegate 23:20:24 → results 23:41:24），但 results §10.7 声明本段仅改 3 文件（AppDelegate + B1ManualDeliveryTests + results）。
- 内容核查：该文件零 B1 标记（无 `PAGING_CLICK_MANUAL_DELIVERY` / B1 注释 / 门控引用；仅既有 wave-a forensics 注解）。全量 1123/0 通过 → 无功能影响可测。
- 建议：Worker/Chief 补充说明该 mtime（疑为 B1 夹具复刻 CommitFixture 时的编辑器落盘；无 git 基线无法 diff 证实净内容变更）。

### QUESTION

**Q-1（转正前置，非本评审覆盖）：§6「B1 候选（门控开）A/B 实机对照」读数未回填**
- 本评审的 PASS 覆盖代码实现、闭环语义、测试真实性与独立实跑；results §10.3 自述「全量执行后回填总账；B1 定向已执行」，§10.4 多项 [x] 以 Fixture 测试证据勾销。任务包 §6/§7 的实机门槛（门控关 10+ 击与 A 运行 s10=0/sA=0 一致、门控开 10+ 击 s10 增量=击数、空白 s8c、ESC key53、拖拽预览、搜索/建夹开folder-关folder 交互）仍待 Main/用户回填。**转正前的硬前置，建议在 results 补充 /tmp/bug10_b1_*.log 读数段。**

**Q-2（门控开覆盖面）：B1 down 分支范围 = `blankClickResolvesToCell==true`（含搜索 field/editor/clear 交互区 :1459-1461 与 overlay 成员 cell），非仅 AppGridCellView**
- 与任务包「复用现有 cell 判定」字面一致；Fixture B 仅覆盖 topLevel 腿，门控开下搜索/overlay 交互投递未被 B1 套件断言。
- 缓解：E4 探针同分支实机 16/16（sE4==s10）先例证明手动投递机制在实机成立；门控默认关 → 生产零影响。Q-1 实机回填建议纳入搜索点击与 folder 开合步骤覆盖。

---

## Evidence（独立实跑，本 reviewer 本机执行）

| 项 | 结果 |
|---|---|
| `swift build -c debug` | exit 0（Build complete） |
| `swift build -c release` | exit 0（Build complete） |
| `swift test --filter B1ManualDeliveryTests` | **Executed 14 tests, 0 failures (0 unexpected)** — 14 用例逐一 passed（门默认关/「0」/门开 down+up+drag 投递与清记录/空白 s8+s8c/ESC 清记录/两门同开 B1 优先/仅探针门独立/全链 s10-s9b-s6-sA/5 连击/拖拽回归/ESC cancel+恢复/门关全链自证） |
| `swift test` 全量 | **Executed 1123 tests, 0 failures (0 unexpected) in 17.701s**；`Test Suite 'All tests' passed`；exit 0 |

（注：swift-testing 空 banner「0 tests」为 XCTest 工程的正常空跑段，XCTest 汇总为上方权威计数。）

代码级核验：
- **门默认关**：`B1ManualDeliveryGate` 每次 `getenv` 实读、严格 `== "1"`、无缓存；门关时顶块不执行、cell 分支落 E4 检查后 super 逐字（s8d / s18 记账照旧）。门控块 switch 仅 .leftMouseUp/.leftMouseDragged，default break → 不泄漏其他事件类型。
- **闭环**：down（s8d 计数后）→ 记录 `hit`（weak）+ `hit.mouseDown` + return（位于 E4 分支前 → 两门同开 B1 优先，测试证 sE4==0）；up → `mouseUp` + 清记录 + return；dragged → `mouseDragged` + return（仅 up 清记录，符合 §2.2）；记录 nil / 空白 / ESC 原语义逐字（ESC key53 清记录处于门块外，门关时恒 nil 零影响）；`resignKey()` 清记录后 super（原语义不变）。
- **s5 字面映射（deviation 1）**：`s5_up_idle_swallow` 为 idle 吞点标记，健康 click 恒 0 且禁新增 sink → 以 s10==s9b==s6==sA==击数 + s5==0 等价覆盖「up 闭环」，语义自洽（up 未达则 s9b/s6/sA 不可能配平）。
- **测试判别力**：Fixture A 拖拽投递判别对成立（dragged 未投 → fallback 未清 → up 仍派发 click → counter==1 必失败；断言 counter==0+s5==1 恰证 dragged 已投）；Fixture B 逐事件断言 state（down→.pressed / up→.idle）与抑制器启停配平（s13a/s13b==击数、s9_leak==0）；拖拽跨 slot 落点 +350 与 bisect 佐证（deviation 6）。
- **写范围**：Sources 仅 AppDelegate.swift（09-04 23:20）在 B1 窗口；冻结树/wave-b 领地/AppGridCellView/FolderOverlayView/DropIntent/Docs 全零触碰（mtimes 验证，见 §D）；无 git；零新增 census sink（全断言复用既有 sink，唯一新名仅 E4 波 `e4ManualDelivery`）。

---

## Likely Root Cause（仅针对 M-1）

B1 Fixture B 装配与 DragCommitIntegrationTests.CommitFixture 复刻（results §10.1/测试头注释），作者从该文件提取夹具模板时编辑器落盘 → mtime 前置、内容净零变更（无 B1 标记 + 全量通过佐证）。无 git 基线无法铁证，倾向「提取夹具时的触碰」而非功能改动。

## Recommended Solution

- M-1：results 补记 DragCommitIntegrationTests.swift 的 mtime 说明（或 Chief 确认无净变更）。
- Q-1：Main/用户按 §6/§7 回填实机 A/B 读数（门控关基线对照 A 运行 35-38 击 / 门控开 10+ 击 s10==击数、空白 s8c、ESC、拖拽预览、搜索与 folder 开合），写入 results 后再由 Chief 定案转正。
- Q-2：实机回填步骤内加入「门控开点搜索框聚焦仍正常」「开 folder→关 folder→顶层点击启动」两项（wave-a-fix 验收顺带复核）。

## Affected Scope

仅 sendEvent 门控路径（B1/E4 两门语义分离、同开 B1 优先已测）；门控关生产路径逐字不变；冻结树零触碰。风险最坏情形=门控开时搜索/overlay 交互走手动投递的路径差异，均以默认关+实机回填兜底。

## Regression Risks

低。门默认关 = 生产零行为变更（Fixture A/B 双自证：s8d==1、s18 闭合恰一、s10/s6/sA 恒 0）；门开全链 14/14 + 全量 1123/0 无回归；残余风险限于门控开下的实机交互差异（Q-2），由 Q-1 实机兜底。

## Confidence

高（代码结构逐点核验 + 独立实跑与 Worker 读数互证；唯一不确定项 M-1 为证据卫生、非功能）。
