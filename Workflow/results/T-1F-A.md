# T-1F-A — ADR 定稿输入 + 纯 layout/mutation 域

- 状态：**complete**（已实现并验证）
- 开始：2026-08-30（Asia/Tokyo）；完成：2026-08-30
- 角色：Worker
- AccessDeclaration: NO_PRIOR_EXPOSURE（未接触任何禁止来源；无 PRIOR_EXPOSURE 标记）

## 交付摘要

新增纯逻辑布局域 `Sources/AppGridUI/LayoutDomain/`（纯 Foundation + AppCatalogCore 公开面；无 AppKit / 无 I/O / 无 Codable 落盘——编码层归 T-1F-B §10.2）：

1. `LayoutGeneration.swift`：单调 token（`value: UInt64`；`.zero`/`incremented()`），独立于 CatalogRevision/FolderGeneration/search/surface generation。
2. `PersistentAppReference.swift`：独立 DTO ≠ AppID；`bundleID` 主 + `canonicalPath` 确定性 fallback（`normalizedPath`：standardizedFileURL.path 去尾部 "/" + lowercased）；`comparisonKey`（"bundle:"/"path:" 前缀，bundle < path）；`matches(record:)` 用同一稳定串语义；无 Hashable 实现；不读 AppID.storage。
3. `PersistentWorkspaceLayout.swift`：唯一持久真相源；顶层 app/folder 任意交错有序条目（`WorkspaceTopLevelEntry`）；folder 稳定身份/标题/有序成员（`PersistentFolderRecord`）；generation；`makeDefault(catalog:)` 确定性默认布局（comparisonKey 去重保首个）。
4. `LayoutMutation.swift`：唯一写入口（`expectedGeneration` 失配 → stale 拒绝）；M1–M5 + renameFolder；结果 `success/rejected/cancelled/noOp`；失败无半提交；原子 dissolve（剩 1 逻辑成员 → 永久解散回确定顶层位 / 剩 0 → 删 folder）；跨 folder move 与源收缩单次提交；`defaultFolderTitle` = "Group N" 最小未用 N。
5. `VisibleWorkspaceProjection.swift`：expected layout + CatalogSnapshot → 派生投影；app 暂缺隐藏但 latent 保留、重现回原逻辑位；新 app 确定性追加未编排尾部；folder 可用 <2 → 视觉 dissolve（layout 不动）；catalogRevision 透传不伪造。
6. `PresentationAnchor.swift`：`.topLevelApp/.folder/.firstAvailable` + 确定性 resolver（无 hashValue）。
7. `WorkspaceInvariants.swift`：10 不变量 enum（`isStructurallyCheckable` ①–⑤）+ `WorkspaceLayoutValidator`（线性扫描；①全局唯一 ④空 ⑤单成员 标题 ≤64-grapheme；完整性 `.folderEntryWithoutRecord`/`.folderRecordWithoutEntry`）。
8. `renameFolder` 真 mutation：复用 `FolderTitle.normalized` 64-grapheme 语义（LayoutDomain 新文件委托，未动 FolderDomain.swift）。

测试 `Tests/AppGridUITests/` 新增 2 文件 48 测试：

- `LayoutDomainMutationTests.swift`（32）：§10.1 矩阵——deterministic default；顶层 reorder 前/后/首/尾 + clamp；app/folder 互换；create folder 目标/源顺序 + min 原 index 顶层位 + Group N；add to folder（tail/head/已成员 no-op）；cross-folder 原子 move（含源 dissolve 单次提交）；inner reorder；move out（确定顶层位 / 零成员删 folder / 剩 1 逻辑 dissolve 永久 + 重投影无 folder）；视觉 dissolve latent 保留 + 重现恢复；新 app 追加；duplicate/nested/stale/invalid-target 拒绝（布局原值不变）；rename 64-grapheme（含组合字形按 grapheme 计）+ 空白回退 + 同题 no-op + 重启恢复；generation 与 catalogRevision 分离。
- `WorkspaceLayoutInvariantTests.swift`（16）：10 不变量具名；validator 逐 issue 检出（7 类）；完整 mutation 序列后结构性不变量保持；fuzz 500 步 SplitMix64 seeded（成功 → validator 空 + gen+1；拒绝 → 布局原值；no-op 不增 gen；引擎永不产生 cancelled）；fallback-only（bundleID nil → canonicalPath）端到端 + 大小写/尾斜杠归一化去重；keepMultiInstance 去重；PresentationAnchor 重排/解散后解析。

## 验证输出（关键行）

```
swift build -c debug  →  Build complete! (23.73s)   [exit 0]
swift test            →  Executed 837 tests, with 0 failures (0 unexpected)   [exit 0]
```

- 基线 789 + 新增 48 = 837 全绿；既有测试（含 Tests/PagingUITests/）零回归。
- 实现期发现并修复 1 个域 bug：validator 曾把「顶层条目引用 folder 记录」误判为 `duplicateFolderRecord`（共享 Set 双重计数）——已改为 entry/record 双集合分别去重 + 双向完整性检查；被新增不变量断言当场捕获。

## 偏差

- ADR-009：无偏差（补充非偏差项：validator 增加 `.folderRecordWithoutEntry` 完整性检查；`cancelled` 为语义保留位，引擎永不产生）。
- ADR-010：无偏差。
- 两 ADR 均已追加「T-1F-A 实现注记」小节（文件末尾，草案主体未改）。

## PRIOR_EXPOSURE

- NO_PRIOR_EXPOSURE：未读取 /Users/mac/Projects/LaunchBetter/、/Users/mac/Projects/BuhoReverseNotes/、2026-08-25-buho-launchpad-reverse 或任何反编译 dump/旧源码/旧测试。
- 隐私：测试仅用中性类别 fixture（Alpha/Beta/… 派生合成 bundleID）；无真实 app 名/bundle ID/path/FolderID 原值/标题/成员/布局正文进入任何输出。
