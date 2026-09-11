# T-1F-B6-wave-b — BUG6 Wave B: createFolder 落在 drop 目标位（缺陷 1）

Status: ready（依赖声明：依赖 Wave A 的方案结论 —— 方案 ii 时强制串行 A→B，方案 i 经 Main `concurrency_check` 可并行）
Wave: BUG6 B
Role: Worker (implement + verify; do not modify Docs/, PROVENANCE/, frozen trees)

## 1. Root cause (verified — 固化自 BUG6-FIX-PROMPT §1 缺陷 1，不要重新诊断)

- `Sources/AppGridUI/LayoutDomain/LayoutMutation.swift:116-122` `createFolder` 用 `min(targetIndex, sourceIndex)` 当插入点。A 在 B 左边时 `min` = A 的位置 → folder 长在被拖源 A 处，用户期望 drop 目标 B 处（BUG6-REPORT §1 逐字报告）。
- **这不是实现偏离设计** —— 文件头 :15 注释明确写"新 folder 落在两原位置区间内（min 原 index）"，:91 doc 注释同。是**当初的规格就写错了**，本次改规格本身，注释必须一起改。

## 2. Fix spec（BUG6-FIX-PROMPT §3 全量固化；Chief 决策 D1 见 decisions/D-2026-08-31-bug6-fix-plan.md §2）
- 顶层位置语义：新 folder 落在 **drop 目标（target）的原顶层位**。A 是"被拖走的"，B 是"留在原地被拖到的"。
- **下标移位陷阱**：source 在 target 之前时，移除 source 使 target 左移一位。**先算后删再 clamp**：直接从 `targetIndex`/`sourceIndex` 相对关系算移除两项后的落点下标 —— source 在前 → `targetIndex - 1`，否则 → `targetIndex`；再 `min(..., ordered.count)` 兜底。**禁**"先删 source 再查 target 下标"这类依赖中间态的写法。
- 只改 `createFolder` 函数体这两三行语义 + 以下注释，**不动**其他 mutation（reorderTopLevel/addToFolder/moveOutOfFolder/reorderFolderMembers/renameFolder 语义不变）：
  - 文件头 :14-15 语义速查行（当前"落在两原位置区间内（min 原 index）"→ 改为"落在 drop 目标 target 原位（source 在 target 前时 targetIndex-1，先算后删再 clamp）"）。
  - `createFolder` doc 注释 :91（同向改写）。
  - 保持 :1-23 契约块其余内容（唯一写入口/原子提交/noOp/cancelled 语义）原样。
- **注释与实现不一致会被 Reviewer 判 FAIL**（:1-23 语义速查块是本文件的契约声明）。

### 2.1 必须新增的测试
- **左方向**：`[A, B, C]`，A 拖到 B（A 在 B 左）→ folder 在**索引 1**（B 原位），结果 `[folder, C]`。
- **右方向**：`[B, A, C]`，A 拖到 B（A 在 B 右）→ folder 在**索引 0**（B 原位），结果 `[folder, C]`。**两个方向都必须测** —— 只测一个区分不了"target 位置"与"min"（target 恰为较小下标时两者相同，这正是旧 bug 长期存活的原因）。
- **成员序锁**：folder 成员仍为 `[target, source]`（先目标后源，:114），本波不改，测试锁住它没被顺手改掉。
- 重复/嵌套/未知 target 拒绝路径不回归（.duplicateReference / .nestedFolder / .invalidTarget）。

## 3. Write scope
- Sources/AppGridUI/LayoutDomain/LayoutMutation.swift（仅 createFolder 实现与注释）
- 对应测试：`Tests/` 下新建或本包授权更新的 createFolder 测试文件（旧 expected 中编码 min 语义的用例可更新为新语义；其余测试文件禁改）

## 4. Forbidden writes
- 冻结树：Sources/PagingCore/、Sources/AppCatalogCore/、Sources/MacAppCatalog/、Sources/AppIconPipeline/、Sources/PagingTelemetry/、Sources/PagingUI/、Package.swift、Sources/PagingPrototypeApp/AppLaunchController.swift
- DropIntent.swift / DragMutationEngine.swift（Wave A 文件）；DragUISessionCoordinator.swift（Wave C）；AppDelegate.swift；FolderOverlayView.swift
- Docs/（ADR-010 的 M3 修订由 Main 在合并时誊写，Worker 不动 Docs/）、PROVENANCE/；Workflow/results/ 只允许本任务结果文件

## 5. Required reading (minimal, ≤4 files)
1. Sources/AppGridUI/LayoutDomain/LayoutMutation.swift — :1-23 头契约、:66-84 reorderTopLevel（对照 remove-then-insert）、:86-126 createFolder
2. Sources/AppGridUI/DragSession/DragMutationEngine.swift — `.createFolder` 分支 :33-38（了解调用方，不改）
3. Tests/ 现有 createFolder / LayoutMutation 测试文件（定位需同步的旧预期）
4. Docs/ADR-010-DRAG-SESSION-AND-DROP-SEMANTICS.md — 仅读 §Q4 M3 与文末实现注记（理解被修订语义，不修改该文件）

## 6. Verification
- swift test 全量：基线 1012 全绿 + 新增两方向/成员序测试全绿；真实执行标准同前；范围外失败报而不修
- swift build -c debug 与 release 均 exit 0
- 行为变化极小，行数应基本持平或微减；若实现需要净增行，结果文件说明理由（净删总原则对本波以"不加新机制"为准）

## 7. Acceptance（对用户缺陷 1）
- 拖 A 到 B 上建夹 → folder 出现在 **B** 的位置（两种相对方向都过）。
- 成员序仍 `[target, source]`；stale/重复/嵌套拒绝路径不回归。
- 文件头语义速查 + doc 注释与实现逐字一致；实机脚本 1（drag A onto B 后 folder 在 B 原 slot）通过。

## 8. Output discipline
- 先写 `Workflow/results/T-1F-B6-wave-b.md`（in progress → 终态）；终态附：改动 diff 摘要、两方向测试证据、注释同步声明、验收映射。
- 回复 <250 词；不贴大代码块；中性 A/B/C 夹具；无 git 操作；事件记录前提 = 本任务包文件已存在。