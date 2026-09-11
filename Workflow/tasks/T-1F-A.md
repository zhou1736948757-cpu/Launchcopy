# T-1F-A — ADR 定稿 + 纯 layout/mutation 域（Worker）

- 创建：2026-08-30（Asia/Tokyo）
- 依赖：T-1F-planning（已完成；PLAN.md §7 写集 + ADR-009/010 草案为依据）
- 角色：Worker（纯 Foundation 域，无 AppKit/I/O）
- 依据：Docs/PHASE1F_DRAG_PERSISTENCE_PROMPT.md §3.1/§6.1/§10.1；Docs/ADR-009-WORKSPACE-LAYOUT-AND-PERSISTENCE.md（Chief Draft）；Workflow/PLAN.md §7

## 范围

新增纯逻辑布局域（Sources/AppGridUI/LayoutDomain/ 新目录）：
- `PersistentWorkspaceLayout`：唯一持久真相源；顶层有序条目（app/folder 任意交错）；folder 稳定身份/标题/有序成员；未分组顺序；layout generation/mutation generation；专用 DTO/envelope（**不得**自动 Codable FolderSnapshot/TopLevelEntry/FolderOpenState）。
- `PersistentAppReference`：独立 DTO ≠ AppID；bundle-ID 主 + canonical path 确定性 fallback（ADR-009 Q2 方案 1；禁 Swift Hasher/displayName/redactedDescription 当持久身份；`AppID.storage` 不公开、不读取）。
- `VisibleWorkspaceProjection`：expected layout + 当前 CatalogSnapshot → 派生可见投影（app 暂缺可隐藏，latent reference 保留；app 重现恢复原位置/成员；新 app 确定性追加）。
- `LayoutGeneration`：只属逻辑布局；成功 mutation 单调递增；与 CatalogRevision/FolderGeneration/search/surface generation 分离；layout 层绝不 mint/forge CatalogRevision。
- `LayoutMutation(expectedGeneration:)`：唯一写入口；mutation 结果含 success/rejected/cancelled/no-op；失败 mutation 无半提交。
- `PresentationAnchor`：重排/解散后稳定落点（无 hashValue）。
- 10 不变量（Prompt §3.1）+ invariant validator。
- `renameFolder` 真 mutation：64-grapheme 规范化（复用 FolderTitle.normalized 既有语义）+ 持久化语义（改名 = layout mutation，generation 递增）。可扩展 `Sources/AppGridUI/FolderDomain.swift` 或在 LayoutDomain 新文件委托——禁止改变既有 FolderTitle/FolderID 语义。
- 纯测试（Tests/AppGridUITests/）：Prompt §10.1 矩阵——deterministic default layout；top-level reorder 前/后/首/尾；app/folder 互换；create folder 目标/源顺序；add to folder；cross-folder atomic move；folder inner reorder；move out；zero/one member dissolve（区分用户逻辑变更 vs 当前不可用投影）；duplicate app reject；nested folder reject；stale generation reject；no-op 不增 generation；invalid target 不改变原布局；property/fuzz 保持不变量。

## 写集（仅这些）

```
Sources/AppGridUI/LayoutDomain/（新文件）
Sources/AppGridUI/FolderDomain.swift（只读+renameFolder 扩展，或新 LayoutDomain 文件委托——二选一最小改）
Tests/AppGridUITests/（新测试文件）
Docs/ADR-009-WORKSPACE-LAYOUT-AND-PERSISTENCE.md、Docs/ADR-010-DRAG-SESSION-AND-DROP-SEMANTICS.md（如实现揭示草案偏差，追加实现注记；转正由 Main 做）
Workflow/results/T-1F-A.md（先写 in-progress）
```

## 禁止写（只读）

```
Sources/PagingPrototypeApp/（含 AppDelegate、AppLaunchController）
Sources/PagingUI/、Sources/PagingCore/、Sources/MacAppCatalog/、Sources/AppCatalogCore/、Sources/AppIconPipeline/、Sources/PagingTelemetry/
Sources/AppGridUI/AppGridUIPageContentProvider.swift、AppGridSearchPresentationController.swift、AppGridUIState.swift、AppGridCellView.swift、AppGridPageView.swift、AppGridFocusNavigator.swift、FolderOpenState.swift、FolderOverlayView.swift、FolderKeyboardLogic.swift、AppGridFocusLayout.swift、AppGridFocusIdentity.swift、AppGridCellFocus.swift
Package.swift
Tests/PagingUITests/
```

## 红线

- 禁止读取：/Users/mac/Projects/LaunchBetter/、/Users/mac/Projects/BuhoReverseNotes/、2026-08-25-buho-launchpad-reverse、任何反编译 dump；如有接触必须标注 PRIOR_EXPOSURE。
- 隐私：app 名/bundle ID/path 原值/FolderID 原值/标题/成员/布局正文绝不进 telemetry/JSONL/stdout/log/report；测试与代码只写中性类别描述。布局文件的字段类别在 ADR-009 中描述。
- 冻结树 mtime 不得改变（除允许写集）。
- 无 git 操作。

## 验证

- `swift build -c debug` exit 0；`swift test` 全量跑（基线 789；新增纯测试须全绿，既有测试不得回归——若写集外失败，如实报告不修改）。
- 验证后更新 Docs/ADR-009 与 ADR-010：在草案末尾加「T-1F-A 实现注记」（如有偏差），不改草案主体。

## 验收（对 Prompt §10.1）

全部 layout model/invariants 测试 PASS；10 不变量锁定；no-op 不 bump generation；stale 拒绝；renameFolder 真 mutation + 64-grapheme + 重启恢复语义测试；ADR 注记完整。

## 输出纪律

- 先写 Workflow/results/T-1F-A.md（"in progress" + 交付摘要），完成后更新为完整结果；
- 最终回复 <250 词，列出：新增文件、测试数、验证命令结果、偏差与理由、PRIOR_EXPOSURE（如无则写 NO_PRIOR_EXPOSURE）。不要贴大代码块。
