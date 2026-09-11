# ADR-003 — PAGING-CONTENT-PROVIDER（PagingUI 中性内容承载抽象）

- **状态**：Accepted（2026-08-28，Main 确认；实现随 Wave 2 落地）
- **关联**：PHASE1B Prompt §5.4/§6；wave1-interfaces.md §E；ADR-001/002（PagingCore 不动）

## 背景

Phase 1A 的 `PageHostView.prepare` 同时拥有"内容是什么"与"怎么渲染"；Phase 1B 需承载真实 catalog 内容而不破坏 PagingCore 纯逻辑边界。

## 决策

1. **双协议**（PagingUI 定义，AppGridUI 实现）：
   - `PagingPageContentProviding`：`servedRevision: UInt64?`（nil=未就绪→中性占位）、`servedPageCount: Int?`、`content(for:itemsPerPage:) -> PagingPageContent?`（**同步内存命中契约**，nil 安全，热路径禁止同步 I/O）
   - `PagingPageRendering`：`render(pageIndex:content:pageCount:reuseGeneration:)`（宿主保证先清空；不阻塞手势）、`clearForReuse()`（清空层级 + **generation bump 作废全部在途异步绑定**）
2. **中性化**：PagingUI 不依赖 AppCatalogCore——revision 用 `UInt64`、页面内容用中性槽位（无 AppID）；业务身份（AppID/IconKey）落在 AppGridUI 层（七字段 `ItemBindingToken`）。
3. **surface 显式 pin**：`beginInteraction` 捕获 servedRevision，tracking/momentum/settle 全程冻结；`endInteraction` 在 idle/cancelled 边界清除；interrupted 保持。每次 relayout pass 只取一次 revision（相邻页不混）。
4. **latest-wins + idle 边界**：手势中 catalog 更新只写 `pendingLatestSnapshot`；idle 边界触发 `refreshPresentation()`（原子替换 + 批量 re-prepare）+ `onIdleBoundary` 事件（app 层做 anchor remap）。
5. **回归模式**：nil 注入 → 中性缺省（NeutralPageRenderer，Phase 1A 行为零回归）；`--neutral-content` 强制回归模式。

## 后果

- seam 单点 = `relayoutPages()` 的 prepare/clearForReuse；热路径纪律保持（范围比较先行）。
- stale async UI apply = 0（三层防线：pipeline generation 回传 + token 七字段 + teardown 零写回）。
- PagingUI 不拥有 scanner/icon loader（§14.A）；PagingCore 零改动。
