# T-1E-H2-repair — servedPageCount 硬编码 35 修复（Gate 0 假设 H2）

- Role: Worker → Reviewer
- Created: 2026-08-30
- Objective: 修复 `AppGridUIPageContentProvider.servedPageCount` 用 `Self.defaultItemsPerPage`(35) 而非实际 itemsPerPage 计算页数的缺陷。
- Root cause: Sources/AppGridUI/AppGridUIPageContentProvider.swift:56-60 — servedPageCount = ceil(presentationRecords.count / 35)。非默认 `--items-per-page` 下搜索激活路径 `PagingSurface.applySameRevisionReload`(:662) 用此错误页数设 core.pageCount,且 AppDelegate `applyPresentationUpdate(overridePageCount: false)` 不自纠(刷新路径靠 update.plan.pageCount 自纠)。
- Impact: Phase 1E 文件夹顶层页数走同一 servedPageCount seam;例:70 结果 + itemsPerPage=20 → servedPageCount=2(实际 4 页)。
- Fix direction: provider 增加实例 `itemsPerPage`(默认 35),servedPageCount 用之;AppDelegate 装配处(与 :287 refreshController.itemsPerPage、:363 presentation.itemsPerPage 并列)设 provider.itemsPerPage = surface.itemsPerPage。
- Acceptance:
  - 新增最小复现测试:provider itemsPerPage=20 + 70 records → servedPageCount == 4(非 2);itemsPerPage=35 默认行为不变(35→1 页,36→2 页)。
  - 全量 swift test executed>0 全绿(≥631/0);debug+release exit 0。
  - 禁止树未动(PagingCore/AppCatalogCore/MacAppCatalog/AppIconPipeline/PagingTelemetry/Package.swift/AppLaunchController.swift);无 git 操作。
  - 无禁止 token;隐私无泄漏。
- Write scope: Sources/AppGridUI/AppGridUIPageContentProvider.swift, Sources/PagingPrototypeApp/AppDelegate.swift(仅 itemsPerPage 对齐行), Tests/AppGridUITests/(新测试), Workflow/results/T-1E-H2-repair.md。
- Forbidden: 其他文件;PagingUI 默认冻结(本任务不涉及)。
