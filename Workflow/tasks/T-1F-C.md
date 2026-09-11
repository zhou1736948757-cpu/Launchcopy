# T-1F-C — Drag session state machine + drop resolver（Worker）

- 创建：2026-08-31（Asia/Tokyo）——预写骨架，A 合并后若有 API 名称偏差以实际为准
- 依赖：T-1F-A（LayoutDomain 纯域）；ADR-010 转正后为权威
- 角色：Worker（纯逻辑状态机，无 AppKit 视图代码；AppKit 集成属 T-1F-D）
- 依据：Docs/PHASE1F_DRAG_PERSISTENCE_PROMPT.md §3.3/§6.2；Docs/ADR-010-DRAG-SESSION-AND-DROP-SEMANTICS.md；Workflow/PLAN.md §7/§10

## 范围

新增 `Sources/AppGridUI/DragSession/` 纯文件：
- `DragTransaction(opaqueToken, scope, sourceIdentity, layoutGeneration, catalogGeneration)`：不透明 token（本阶段仅进程内生成/校验，绝不进入 pasteboard）
- pointer state machine：`idle → pressed → dragging/edgeTurnPending → commit | cancel → idle`（ADR-010 决策 1：默认自定义窗口内 pointer state machine，非 NSDraggingSession；可测性优先）
- 按下阈值仲裁（click vs drag）、drop resolver、hit-zone/drop intent 分类（insertion vs create-folder 视觉异构——分类决策输出 enum，视觉执行在 D 层）
- 5 类 mutation 统一引擎：top-level reorder / create folder / add to folder / cross-folder move / move out（全部通过 `LayoutMutation(expectedGeneration:)` 单一写入口）
- edge paging 纯 seam：edge enter/dwell/turn/leave/cancel/first-last 调度器（只产事件，不碰视图）
- 统一 cancel 策略：ESC / resign / refresh / search / title edit / overlay close / teardown / second drag → 零写盘、无 preview/edge-timer 残留
- stale 防护：stale source/target/layout/catalog generation 拒绝；duplicate drop consumed once；invalid/external token rejected；second drag invalidates first

## 写集（仅这些）

```
Sources/AppGridUI/DragSession/（新文件）
Tests/AppGridUITests/（新 drag-intent 测试）
Docs/ADR-010-DRAG-SESSION-AND-DROP-SEMANTICS.md（末尾追加「T-1F-C 实现注记」，不改草案主体）
Workflow/results/T-1F-C.md（先写 in-progress）
```

## 禁止写（只读）

```
Sources/AppGridUI/LayoutDomain/（A 的产物，只读）
Sources/AppGridUI/LayoutStore/（B 的产物）
Sources/AppGridUI/ 下全部既有文件
Sources/PagingPrototypeApp/（含 AppDelegate、AppLaunchController；D 层才碰 AppKit）
Sources/PagingUI/、Sources/PagingCore/、Sources/MacAppCatalog/、Sources/AppCatalogCore/、Sources/AppIconPipeline/、Sources/PagingTelemetry/
Package.swift
Tests/PagingUITests/
```

## 红线

- 禁止读取：/Users/mac/Projects/LaunchBetter/、/Users/mac/Projects/BuhoReverseNotes/、2026-08-25-buho-launchpad-reverse、任何反编译 dump；接触即标 PRIOR_EXPOSURE。
- 隐私：app 名/bundle ID/path/FolderID/标题/身份数据绝不进 telemetry/JSONL/stdout/log/report/测试输出；opaqueToken 零身份（本阶段不落 pasteboard）；参数来源 5 类（禁 REVERSE_ENGINEERING_COPY/OLD_SOURCE_TRANSLATION/UNKNOWN_ORIGIN）。
- 冻结树 mtime 不得改变（除允许写集）。
- 无 git 操作。

## 验证

- `swift build -c debug` exit 0；`swift test` 全量（基线 789 + A 新增 + B 新增 + C 新增；既有不得回归；写集外失败如实报告不修改）。
- 验证后更新 ADR-010 末尾「T-1F-C 实现注记」。

## 验收（对 Prompt §10.3）

drag-intent 测试矩阵全覆盖（如 PLAN.md §10 C 行）：click below threshold vs drag above；reorder / create / insert / move-into / move-out / cross-folder 分类；invalid/external token rejected；duplicate drop consumed once；stale source/target/layout/catalog rejected；全部 cancel 路径可测；edge enter/dwell/turn/leave/cancel/first-last；second drag invalidates first。

## 输出纪律

- 先写 Workflow/results/T-1F-C.md（"in progress" + 交付摘要），完成后更新完整结果；
- 最终回复 <250 词：新增文件、测试数、验证命令结果、偏差与理由、PRIOR_EXPOSURE（无则 NO_PRIOR_EXPOSURE）。不贴大代码块。
