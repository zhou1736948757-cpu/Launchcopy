# Task Packet: Wave-1（Phase 1B 互斥实现波）

- **Task ID**: Wave-1
- **Role**: Main（收口）
- **来源**: PHASE1B_REAL_APP_CONTENT_PROMPT.md §12 Wave 1
- **日期**: 2026-08-28

## 结果

- AppCatalogCore（t4）：56 tests；MacAppCatalog（t5）：45 tests；AppIconPipeline（t6）：23 tests。
- Main 收口全量：**306 tests, 0 failures**；swift build exit 0。
- 写集互斥零越界；隐私红线（无路径/ID/图标数据原文）内化；测试全隔离（fake .app/程序生成图像）。
- 待 ADR-004：DuplicateResolution.rootPriorityFirst 默认 + validate canonicalURL 身份解读。
