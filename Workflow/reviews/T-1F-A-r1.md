# T-1F-A-r1 — 独立 Reviewer 核验报告（纯 layout/mutation 域）

- 日期：2026-08-31（JST）
- 角色：Reviewer（只读；未修改任何实现文件）
- 依据：Workflow/tasks/T-1F-A.md（任务包）、Workflow/results/T-1F-A.md（Worker 结果）、Docs/ADR-009（草案 + 实现注记）、Docs/ADR-010（实现注记）、Docs/PHASE1F_DRAG_PERSISTENCE_PROMPT.md §3.1/§10.1、Sources/AppGridUI/LayoutDomain/ 全部 7 文件、Tests/AppGridUITests/ 新增 2 测试文件
- 裁决：**PASS**

## 1. 写集合规 — 通过

- 新增仅限：`Sources/AppGridUI/LayoutDomain/` 7 文件（LayoutGeneration / PersistentAppReference / PersistentWorkspaceLayout / LayoutMutation / VisibleWorkspaceProjection / PresentationAnchor / WorkspaceInvariants，mtime 2026-08-31 00:33–00:47）、`Tests/AppGridUITests/` 2 文件（LayoutDomainMutationTests.swift、WorkspaceLayoutInvariantTests.swift，mtime 08-31 01:15）、两 ADR 末尾「T-1F-A 实现注记」（mtime 08-31 01:15）、Workflow/results/T-1F-A.md（01:16）。
- 冻结树 mtime 抽查（`stat -f` 全量）：Sources/PagingPrototypeApp/ 最晚 08-30 21:20:09（AppDelegate.swift、KeyboardFocusController.swift）；PagingUI/PagingCore/MacAppCatalog/AppCatalogCore/AppIconPipeline/PagingTelemetry 全部 ≤ 08-30 21:16；12 个 1E AppGridUI 文件最晚 08-30 22:03:53（FolderKeyboardLogic.swift）；FolderDomain.swift 08-30 16:12:03（未动——renameFolder 走 LayoutDomain 新文件委托，符合任务包二选一）；Package.swift 08-28 20:42:55；Tests/PagingUITests/ 全部 ≤ 08-30 21:58:49。全部早于新文件，冻结树零触碰。
- 无 git 操作：未运行任何 git 命令（红线遵守）；以 mtime 证据 + 文件清单核验。

## 2. 域语义 — 通过（逐项）

- **PersistentAppReference**（PersistentAppReference.swift:20-58）：bundle-ID 主 + canonicalPath fallback（`from(record:)` 仅用 AppRecord 公开面 bundleIdentifier/canonicalURL，不读 AppID.storage）；无 Hashable（仅 Equatable+Sendable）；`comparisonKey` 稳定（"bundle:"/"path:" 前缀，bundle < path）；`matches(record:)` 同稳定串语义；`normalizedPath` = standardizedFileURL.path 去尾 "/" + lowercased（ADR-009 Q2 大小写不敏感/忽略尾斜杠）。
- **LayoutMutation(expectedGeneration:)**（LayoutMutation.swift:57-314）：唯一写入口；每个 mutation 首行 guard generation 相等 → stale 拒绝（`.staleGeneration`）；失败路径全部返回 rejected，输入为值类型、无任何原地修改 → 无半提交（不变量⑧）；no-op 路径（reorder 无位移 / add 已成员 / inner reorder 同下标 / rename 同标题）返回 `.noOp(layout)` 不增 generation；`.cancelled` 仅声明（:34），引擎零产出（grep 证实无 return）。
- **dissolve**：moveOutOfFolder 剩 1 → 原子逻辑 dissolve（剩余成员回 folder 原顶层位 `min(i, ordered.count)`、记录删除、gen+1）；剩 0 → 删 folder；跨 folder move（crossFolderMove :279-314）源收缩 + 目标追加单次提交 gen 只 +1。
- **VisibleWorkspaceProjection**（:72-134）：暂缺 app → 隐藏 + latent 保留（layout 不动）；重现 → 按 layout 序回原逻辑位；新 app → 未编排尾部确定性追加（catalog 稳定序）；folder 可用 <2 → 视觉 dissolve（1 可用 → .app 呈现；0 → 隐藏），layout 不触碰；catalogRevision 透传（:130 `catalog.revision`），不伪造。
- **PresentationAnchor**（:14-40）：无 hashValue；resolver 用 firstIndex + matches 确定性解析。
- **10 不变量 validator**（WorkspaceInvariants.swift:80-133）：entry/record 双集合（entryFolderIDs/recordFolderIDs）分别去重 + 双向完整性（folderEntryWithoutRecord / folderRecordWithoutEntry）；seenRefKeys 全局唯一（①）；空/单成员/超 64-grapheme 标题检出；Worker 声称的共享 Set 双重计数 bug 修复在代码中成立（:83-84 分离集合）。
- **renameFolder**（:247-262）：复用 FolderTitle.normalized（FolderDomain.swift:77-81 trim → 空白回退 → 64-Character 截断），空白回退为原标题 → noOp；成功 gen+1；重投影即恢复（重启语义）。

## 3. 测试质量 — 通过（§10.1 矩阵全覆盖）

- 32 + 16 = 48 测试（grep 计数与 Worker 声明一致）。§10.1 逐项：deterministic default（2）；顶层 reorder 前/后/首/尾 + clamp（4）；app/folder 互换（1）；create folder 目标/源顺序 + 默认标题 + 空白回退（4）；add to folder tail/head/已成员 no-op（3）；cross-folder 原子 move 含 dissolve 单次提交（2）；inner reorder + 同下标 no-op（2）；move out 确定顶层位/零成员删夹/剩 1 逻辑 dissolve 永久 + 重投影无 folder（3）；视觉 dissolve latent 保留 + 重现恢复（1）；duplicate/nested/stale/invalid-target 拒绝且原布局不变（4）；rename 64-grapheme + 组合字形 + 空白回退 + 重启恢复（3）；generation 与 catalogRevision 分离（1）。
- 不变量：10 不变量具名（testAllTenInvariantsEnumerated）；validator 逐 issue 检出；完整 mutation 序列后结构性不变量保持（gen 恰 +8）；fuzz 500 步 SplitMix64 固定种子（成功 → validator 空 + gen+1；拒绝 → 原值；no-op 不增 gen；引擎永不产生 cancelled）；fallback-only 端到端 + 大小写/尾斜杠归一化去重；keepMultiInstance 去重；PresentationAnchor 重排/解散/空投影解析。
- 夹具中性：makeSnapshot 派生 "fixture.<title>" 合成 bundleID + tempURL（TestSupport.swift:51-53）；无真实身份原值。

## 4. 验证复跑（串行，2026-08-31 01:5x JST）— 通过

```
swift build -c debug   → Build complete! (0.29s)   DEBUG_EXIT=0
swift test             → Executed 837 tests, with 0 failures (0 unexpected) in 22.198s   TEST_EXIT=0
swift build -c release → Build complete! (9.09s)   RELEASE_EXIT=0
```

- 837 = 基线 789 + 新增 48，与任务包/Worker 声明一致；既有测试（含 Tests/PagingUITests/）零回归。

## 5. 红线 — 通过

- 无 git 操作（本核验亦未运行 git 命令）。
- 隐私：LayoutDomain 7 文件零 print/NSLog/os_log/Logger（grep 证实）；测试 fixture 全中性；无真实 bundle ID//Applications 路径（grep 零命中）。
- PRIOR_EXPOSURE：9 个新文件 + 结果文件均带 NO_PRIOR_EXPOSURE 标记；新文件无 LaunchBetter/BuhoReverseNotes/2026-08-25-buho-launchpad-reverse/反编译 引用（唯一命中为 ADR-009 草案正文 :76 的禁止性声明，Chief 既有文本，非接触证据）。

## 6. 发现的问题

- **MINOR-1（测试覆盖缺口）**：validator 第 8 类 issue `folderRecordWithoutEntry`（WorkspaceInvariants.swift:129-131，记录无顶层条目 = 不可达 folder）无直接测试——任务包明确要求核验「entry/record 双集合去重 + 双向完整性」，现有测试只覆盖了 entry→record 方向（testValidatorDetectsDuplicateFolderRecordAndOrphanEntry）。代码路径 3 行、逻辑平凡正确，Worker 结果亦如实写「7 类」未夸大。建议后续补一条直接检出测试（非阻塞）。
- **MINOR-2（断言冗余）**：LayoutDomainMutationTests.swift:478 `XCTAssertEqual(withFolder, withFolder)` 为自比较恒真断言，无验证力（布局不被投影改动已由值语义保证）；无害但建议删除或改为与投影前快照比较。
- **QUESTION（已澄清，无需行动）**：testMoveOutOnlyMemberDeletesFolder 手构 1 逻辑成员 folder 作输入（违反不变量⑤的输入态）——注释已声明夹具前提（成员只在 folder 内、不在顶层），且 mutation 引擎必须能处理该输入、validator 负责拦截已提交布局，测试合法。

## 7. 裁决

**PASS** — 写集合规、域语义、§10.1 矩阵、复跑（837/0）、红线全部通过；2 个 MINOR（folderRecordWithoutEntry 缺直接测试、1 处恒真断言）不构成阻塞，建议随 T-1F-B 或后续修复任务顺带补齐。
