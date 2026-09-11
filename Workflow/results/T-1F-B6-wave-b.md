# T-1F-B6-wave-b — BUG6 Wave B: createFolder 落在 drop 目标位（缺陷 1）

Status: complete
AccessDeclaration: NO_PRIOR_EXPOSURE（未读 /Users/mac/Projects/LaunchBetter/、BuhoReverseNotes/、2026-08-25-buho-launchpad-reverse）
Model declared: deepseek-v4-flash:0731, fresh context
Task package: Workflow/tasks/T-1F-B6-wave-b.md（唯一权威；未重新诊断，按 §2 fix spec 实现）

## ① 结论

缺陷 1 已修复：`LayoutMutation.createFolder` 顶层插入点从 `min(targetIndex, sourceIndex)` 改为 **drop 目标 target 原位**（source 在 target 前时 targetIndex-1，先算后删再 clamp）。全量 **1026 tests / 0 failures**（= 基线 1022 + 新增 4），debug 与 release build 均 exit 0。注释三处同波同步，契约块其余内容未动。

## ② 写范围确认（仅以下 3 个文件被改动）

1. `Sources/AppGridUI/LayoutDomain/LayoutMutation.swift` — createFolder 实现与注释（§3 授权）
2. `Tests/AppGridUITests/LayoutMutationCreateFolderBug6Tests.swift` — 新建独立测试文件（避开 Wave A/C 刚改的 DragDropTests / DragSessionControllerTests / DragUISessionCoordinatorTests）
3. `Tests/AppGridUITests/LayoutDomainMutationTests.swift` — 任务包 §3 授权的就地更新（仅一件，见下）

未触碰：冻结树、DropIntent/DragMutationEngine/DragUISessionCoordinator、Docs/、PROVENANCE/、Wave A/C 三测试文件。无 git 操作。

## ③ 改动摘要

### LayoutMutation.swift（3 处）
- **实现（原 :116-122 → 新 :119-127）**：`let first/second = min/max(...)` 两段式 → 单表达式 `let insertion = sourceIndex < targetIndex ? targetIndex - 1 : targetIndex`，随后按大 index 先删两项、`min(insertion, ordered.count)` 兜底插入——"先算后删再 clamp"，无中间态下标查询。实现代码 7 行→5 行（净 -2），另加 4 行落点说明注释；无新机制。
- **文件头 :14-16 语义速查行**："新 folder 落在 drop 目标 target 原位（source 在 target 前时 targetIndex-1，先算后删再 clamp；BUG6 wave-b 语义修订）"；:1-23 契约块其余内容（唯一写入口/原子提交/noOp/cancelled/隐私）逐字未动。
- **createFolder doc 注释 :92-94**：同向改写（"被拖走的是 source、留原地被拖到的是 target → folder 落在 target 位置"）；doc 其余行（操作数校验/标题/folderID）未动。
- **注释同步声明**：头速查、doc、实现三处语义措辞一致（Reviewer 可逐字对照）。

### LayoutDomainMutationTests.swift（授权就地更新 1 件）
`testCreateFolderTargetThenSourceMembersAtMinIndex` → 改名 `testCreateFolderLandsAtTargetPositionWhenTargetPrecedesSource`，注释 min 措辞改为 target 原位措辞。**断言数值不变**：该夹具 target(r[1]) < source(r[2])，新语义落点 = targetIndex = 1 = 旧 min(1,2)，属同值锁；文件含 createFolder 引用 29 行/35 次逐一核查（Main 复核可复现；Reviewer MINOR-1 修正原「51 处」计数），其余用例均 target 在 source 左或断言不依赖落点，全部无需改动。

## ④ 测试证据（真实执行，非复述）

- `swift build -c debug` exit 0（2.34s）；`swift build -c release` exit 0（10.02s）。
- 新文件 `LayoutMutationCreateFolderBug6Tests`：**Executed 4 tests, 0 failures**——
  1. `testBug6LeftDirectionFolderLandsAtTargetSlot`：`[A,B,C]` A 拖到 B（A 在左，target=r[1], source=r[0]）→ 断言 `[.folder, C]`，成员 `[B, A]` ✅
  2. `testBug6RightDirectionFolderLandsAtTargetSlot`：`[B,A,C]`（target=r[0], source=r[1]）→ 断言 `[.folder, C]`（索引 0），成员 `[B, A]` ✅
  3. `testBug6NonAdjacentSourceLeftFolderLandsAtTargetSlotNotSourceSlot`（判别用例）：`[A,X,B,C]` A 拖到 B → 断言 `[X, .folder, C]`；**旧 min 实现此构型落点 0（[F,X,C]）新语义 1（[X,F,C]），必 FAIL**——已用独立 Swift 片段复算两落点（old=0 / new=1，见 /tmp/bug6_check.swift 结论，未动仓库）。
  4. `testBug6RejectionPathsUnchanged`：.duplicateReference / .nestedFolder / .invalidTarget 三拒绝路径原值返回 + 布局与 generation 不变 ✅
- 既有 `LayoutDomainMutationTests`：**Executed 32 tests, 0 failures**（旧 createFolder 预期零改动通过）。
- 全量 `swift test`：**Executed 1026 tests, with 0 failures**（PagingPrototypePackageTests.xctest passed；1022 基线 + 4 新增，计数严格吻合）。
- 判别性数学：独立复算确认左相邻 `[A,B,C]`（old=new=0）与右方向 `[B,A,C]`（old=new=0）在新旧语义下同值——与任务包自述"target 恰为较小下标时两者相同"一致；故两方向夹具定位为**同值回归锁**（锁成员序/落点/generation），target-vs-min 的可观测区分由非相邻判别用例承担（该构型即 BUG6 报告"folder 长在被拖源 A 处"的发生条件：source 与 target 间有间隔条目）。

## ⑤ 验收映射（§7）

| 验收项 | 证据 |
|---|---|
| 拖 A 到 B → folder 在 B 的位置（两方向） | 测试①②（相邻两方向同值锁）+ 测试③（非相邻判别，旧实现 FAIL 新实现 PASS） |
| 成员序锁 `[target, source]` | 测试①②③均断言 `[B, A]`/`[B, A]`/`[B, A]`；实现 :117 `members: [target, source]` 未动 |
| stale/重复/嵌套拒绝不回归 | 测试④ + 既有 rejection 测试 32/32 + 全量 1026 绿 |
| 注释与实现一致 | 头速查 :14-16 与 doc :92-94 均为新语义措辞，与 :120-127 实现逐字一致 |
| 实机脚本 1（drag A onto B 后 folder 在 B 原 slot） | Worker 无实机环境未执行；静态链路成立：GUI 拖 A→B 产出 `.createFolder(target: B)`（Bug6DropZoneGeometryTests :87 锁定意图），engine :49-54 直传不改 target，mutation 落 target 位。实机验收留给 Main/Reviewer，风险记 ⑦ |

## ⑥ 与任务包的偏差披露（不自作主张改判，留 Reviewer 裁定）

1. **§2.1 左方向"folder 在索引 1"的读法**：按 §2 权威公式（source 在前 → targetIndex-1）与 §2.1 自写结果 `[folder, C]`，"索引 1（B 原位）"指 **B 在原布局的下标锚点**（folder 替代 B 的逻辑位），非最终数组下标（[F,C] 中 folder 在 0）。H2 读法（字面插入 targetIndex 原值）会产出 `[C, F]`，使 C 莫名左移越夹——与 §2.1 结果列表矛盾，未采用。
2. **两方向夹具的新旧同值性**：相邻构型下旧 min 与新 target 落点相等（已验证 old=new=0），故 §2.1"只测一个区分不了 target vs min"的判别性实际由**非相邻**构型实现——已补测试③（超出 §2.1 清单 1 条，同一新文件内，理由如上；不属语义改动）。
3. `DragDropTests.swift:336` 注释仍以"min 原 index = 0"框架描述（断言 `[F, app3]` 在新语义下同值成立：targetIndex-1=0=min=0）。该文件属 Wave A 刚改动三文件，按授权**未触碰**；数值断言不受影响，仅注释框架陈旧，建议 Main 合并时顺带誊写。
4. ADR-010 M3/实现注记仍写 min 语义——按 §4 禁写，由 Main 合并时修订誊写（本结果文件附上：修订措辞可直接采用 :14-16 新速查行）。

## ⑦ 风险

- 相邻区间（source 紧邻 target 左侧）新旧落点同值，用户可见行为变化仅出现在 source 与 target 非相邻（中间隔条目）或 target 在 source 右且跨条目的构型——判别用例③已覆盖前者；后者（target 在左）本就同值。
- 测试日志中 `DBG7 flush1 result: failed` 为预存在测试体诊断打印（全部用例 PASS），非失败信号，范围外不修。
- 其余 mutation（reorderTopLevel/addToFolder/moveOutOfFolder/reorderFolderMembers/renameFolder/crossFolderMove）零改动；DragMutationEngine 未触碰，Wave A 的 reorderAdjustedIndex 换算路径独立未动。