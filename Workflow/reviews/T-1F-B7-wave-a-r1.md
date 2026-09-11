# T-1F-B7-wave-a — Review r1（独立 Reviewer，只读）

**判定：PASS**
Reviewer: glm-5.3-flash:cloud（独立，不复述 Worker 结论，A–H 全部自行核验）。AccessDeclaration: NO_PRIOR_EXPOSURE（未读取 LaunchBetter/、BuhoReverseNotes/、2026-08-25-buho-launchpad-reverse、任何 Ghidra/otool dump；本次评审无 git 操作、无实现/测试文件修改，写操作仅本评审文件）。

## A. 公式正确性 — PASS（手算独立核验）

实现 `LayoutMutation.swift:123` `let insertion = targetIndex`；:124-125 先删 `max(targetIndex, sourceIndex)` 再删 `min(...)`；:126 `min(insertion, ordered.count)` clamp——与任务包 §2 定案公式逐行一致。手算：
- ① [A,B,C] source=A(0) target=B(1)：insertion=1 → 删1 [A,C] → 删0 [C] → 插1 = **[C,F]**（folder 在 index1 = B 原格）✓
- ② [B,A,C] source=A(1) target=B(0)：insertion=0 → 删1 [B,C] → 删0 [C] → 插0 = **[F,C]** ✓
- ③ [A,X,B,C] source=A(0) target=B(2)：insertion=2 → 删2 [A,X,C] → 删0 [X,C] → 插2 = **[X,C,F]**（folder 在 index2 = B 原格）✓
- 成员序 `members: [target, source]`（实现行 :116）= [B,A] ✓，未动。

## B. 注释一致性 — PASS

三处逐字核对：头速查 :14-16、createFolder doc :92-94、函数内 :120-122，均为"落点 = drop 目标 target 原 index（格子位置语义；不做 targetIndex-1，先算后删再 clamp；BUG7 wave-a 语义修订）"，与实现语义一致。全库 grep `targetIndex-1`/`targetIndex - 1`：仅 5 处**否定性注释**命中，公式零残留。

## C. 测试完整性 — PASS

`LayoutMutationCreateFolderBug6Tests.swift`：
- 左方向 :40-55 期望 [.app(r2), .folder] = [C,F]；右方向 :60-73 期望 [F,C]；非相邻 :78-90 期望 [.app(r1), .app(r3), .folder] = [X,C,F]——三构型两方向+非相邻全按格子位置。
- 判别性（我独立算）：左方向旧 min 与 wave-b 均产 [F,C]≠[C,F]，必 FAIL；非相邻旧 min → [F,X,C]、wave-b → [X,F,C]，均≠[X,C,F]，必 FAIL。判别性成立。
- 成员序 [B,A] 在三条成功用例均断言（:52/:70/:88）；generation=1 + validator 零 issue。
- 拒绝路径 :96-131 覆盖 .duplicateReference/.nestedFolder/.invalidTarget/.staleGeneration 四条 + 无半提交（generation 与布局原值不变）。

## D. 追加收尾（Main 授权）— PASS

`DragDropTests.swift` testEngineM3CreateFolderTargetThenSource（:325-345）：guard `topLevelOrder[1]` 为 folder（drop 目标 app2 原格）+ 期望 `[.app(app3), .folder(folderID)]` + 注释"格子位置语义；不做 targetIndex-1；BUG7 wave-a"——与用户原话（BUG7-REPORT §1"folder 应该是在B软件的位置上"）一致。相邻文件内其他 createFolder 测试（:463-499 等）仅拒绝路径/intent 识别断言，无落点断言，不受影响；mtime 单点编辑 18:55，与其余测试零改动的主张一致。

## E. 写范围 — PASS（mtime 取证）

全仓 `find -newermt "2026-09-01 17:30"`（排除 .build/.git/Workflow/zcode-bridge）：**恰命中 3 个授权文件**——LayoutMutation.swift(18:49)、LayoutMutationCreateFolderBug6Tests.swift(18:50)、DragDropTests.swift(18:55)。冻结树（PagingCore/AppCatalogCore/MacAppCatalog/AppIconPipeline/PagingTelemetry/PagingUI/Package.swift/AppLaunchController.swift）、AppDelegate.swift、DragSession/（DragMutationEngine 最后改动 8/31 23:52）、DragParameters.swift、Docs/、PROVENANCE/ 全部零触碰。

## F. 独立实跑 — PASS（Reviewer 本人执行）

- `swift build -c debug` → exit 0
- `swift test` 全量 → exit 0；**Executed 1026 tests, with 0 failures**（Test Suite 'All tests' passed, 19:00:08）——非 0-executed，有效执行
- `swift build -c release` → exit 0
（首轮 Reviewer 侧 swift test 的 tail 截窗只显示 swift-testing 空跑摘要，已重跑以 XCTest 汇总行取证，见上。）

## G. Deviation 评估 — 三条均可接受

1. 补 `.staleGeneration` 断言：任务包 §2 明列 4 条拒绝路径"保持不回归"；终态 4 条全覆盖即满足规格，属写范围内补齐，无语义变更。可接受。（注：repo 零提交，"原文件仅 3 条"不可独立取证，见 QUESTION-1。）
2. Main 授权写范围扩展 DragDropTests.swift：首次全量 1 failure（范围外旧语义断言）按纪律只报告不修，Main 授权后同步且记录在案，改动语义与用户期望一致。可接受。
3. guard 下标去 `?`：`topLevelOrder[1]` 为非可选数组下标，纯语法适配，行为不变。可接受。

## H. 红线与隐私 — PASS

3 个变更文件 grep LaunchBetter/BuhoReverseNotes/2026-08-25-buho-launchpad-reverse/Ghidra/otool 零匹配（结果文件中的命中是 AccessDeclaration 声明自身）；夹具中性（Alpha/Beta/Gamma 按位置赋角色、app1-3、fixture.* 合成 ID，无真实应用名/bundleID/路径）。

## Findings

- **BLOCKER**：无
- **MAJOR**：无
- **MINOR**：
  - MINOR-1：行号漂移——任务包引用实现行 :124，现文件为 :123（先算行），注释区间 :119-127→:119-126。系注释重排所致，任务包行号为近似值，无实质影响，仅记录。
- **QUESTION**：
  - QUESTION-1：Deviation-1"原文件仅 3 条拒绝路径"因 repo 零提交无 git 历史，无法独立取证；终态覆盖 4 条已满足规格，不构成风险，留档备查。

## 结论

A–H 八项全部独立核验完成并有证据记录；公式、注释、测试判别性、追加收尾语义、写范围、独立实跑（1026/0）、deviation、红线隐私全部通过。**判定 PASS**——缺陷 1（createFolder 落点重定，folder 顶替 drop 目标 B 原格）修复可合并；Wave B′（缺陷 2）与 Wave C′（缺陷 3）不在本评审范围。