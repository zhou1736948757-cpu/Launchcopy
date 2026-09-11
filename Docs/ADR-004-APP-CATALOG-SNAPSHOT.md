# ADR-004 — APP-CATALOG-SNAPSHOT（Phase 1B catalog 领域决策）

- **状态**：Accepted（2026-08-28，Main 确认；实现已随 Wave 1 落地）
- **关联**：PHASE1B_REAL_APP_CONTENT_PROMPT.md §5.1/§6；Chief 草案 wave1-interfaces.md §B；ADR-001/002（PagingCore 不动，本 ADR 仅 Phase 1B 新组件）

## 背景

Phase 1B 需要稳定 catalog 身份、不可变快照与刷新一致性；不得依赖 Launchpad/Dock 私有库；telemetry 不得泄露 app 身份。

## 决策

1. **AppID 不透明身份**：bundleIdentifier 主身份；缺失时 canonicalURL fallback；displayName 绝不参与身份。对外不可还原原文（`redactedDescription`）。
2. **CatalogSnapshot 不可变 + 单调 revision**：revision 严格递增由 `SnapshotGate`/`CatalogRepository` 双门禁保证。
3. **去重顺序**：canonical URL 去重（规则 1）→ bundleID 去重（policy）。
4. **DuplicateResolution 默认 = `.rootPriorityFirst`**：root 优先级 + canonical path 字典序（确定性）；`.keepMultiInstance` 为显式可选（保留稳定多实例）。
5. **validate 身份判定 = canonicalURL**：`keepMultiInstance` 快照允许 AppID 重复（同一 app 多实例）；默认 rootPriorityFirst 下无重复。
6. **revision 唯一拥有者 = MacAppCatalog.CatalogRepository**（actor）：AppCatalogCore 只定义类型与门禁。
7. **PagePlan/remap 五级降级**：located → successor → predecessor → clamped → emptyCatalog；remap 签名不含旧快照 → 结构性杜绝沿用旧数组 index（§6.3 规则 6）。
8. **PagePlan 页数语义**：0 记录 → 0 页；`ceil(itemCount/itemsPerPage)`（35=1 页、36=2 页，与 Phase 1A 默认对齐）。

## 后果

- 排序/去重/锚点规则全部收敛在 `CatalogBuilder`/`CatalogPlanner`；MacAppCatalog 只产出 raw records。
- 隐私硬边界前置到 domain 层（AppID/IconIdentity 不透明）。
- Phase 1A 冻结参数（§4）零改动；PagingCore 零改动。
