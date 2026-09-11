# T-1F-B-resume — LayoutStore 收尾（Worker）

- 创建：2026-08-31（Asia/Tokyo）
- 依赖：T-1F-A（已合并）；原 T-1F-B Worker（af6eec21）中途失败，源码已落盘
- 角色：Worker（resume——完成测试、验证、ADR 注记、结果文件；源码缺陷可修）

## 背景

原 Worker B 已落盘 `Sources/AppGridUI/LayoutStore/` 4 文件（LayoutStore.swift 协议+状态类型、LayoutStoreCodec.swift schema v1、LayoutStoreIO.swift 注入 IO、LayoutStoreActor.swift A/B journal actor），结果文件 Workflow/results/T-1F-B.md 为 in-progress（含完整交付计划）。**未完成**：测试文件、swift build/test 验证、ADR-009 注记、结果文件 complete。

## 范围（resume）

1. **只读审查**已落盘 4 个 LayoutStore 文件：与 Workflow/tasks/T-1F-B.md 包 + ADR-009（Accepted）对照，确认协议/actor/codec/IO 语义完整（schema v1 确定性编码、A/B 双槽 journal、writeGeneration 单调、LKG、temp+原子替换、PERSISTENCE_DEGRADED 重试不清 LKG、coalescing latest-wins、flush barrier、reset、未知未来版本只读保护、多实例策略、注入 storeDirectory）。发现缺陷 → 修复（resume 授权）。
2. **写测试**：Tests/AppGridUITests/ 新增持久化测试（全部 injected temp dirs，测试后清理自己的目录）——按 Workflow/tasks/T-1F-B.md 验收矩阵：首启无文件；save/load/restart；原子替换；中断写；主 corrupt + backup 有效；双 corrupt → 安全默认；权限拒绝；磁盘满；coalescing latest-wins；flush barrier；reset；未知未来版本绝不覆盖；多实例策略；全部 temp roots。
3. **验证**：`swift build -c debug` exit 0；`swift test` 全量（基线 789 + A 48 + B 新增；既有不得回归；写集外失败如实报告不修改）。.build 锁争用则等待重试一次。
4. **ADR-009 末尾追加「T-1F-B 实现注记」**（不改草案主体）。
5. **结果文件更新为 complete**。

## 写集（仅这些）

```
Sources/AppGridUI/LayoutStore/（已落盘 4 文件——可修）
Tests/AppGridUITests/（新持久化测试文件）
Docs/ADR-009-WORKSPACE-LAYOUT-AND-PERSISTENCE.md（末尾注记）
Workflow/results/T-1F-B.md（更新 complete）
```

## 禁止写（只读）

```
Sources/AppGridUI/LayoutDomain/（A 的产物）
Sources/AppGridUI/DragSession/（C 的产物，并行 resume Worker 在写）
Sources/AppGridUI/ 下全部既有文件
Sources/PagingPrototypeApp/、Sources/PagingUI/、Sources/PagingCore/、Sources/MacAppCatalog/、Sources/AppCatalogCore/、Sources/AppIconPipeline/、Sources/PagingTelemetry/
Package.swift
Tests/PagingUITests/
```

## 红线

- 禁止读取：/Users/mac/Projects/LaunchBetter/、/Users/mac/Projects/BuhoReverseNotes/、2026-08-25-buho-launchpad-reverse、任何反编译 dump；接触即标 PRIOR_EXPOSURE。
- 隐私：布局正文/app 名/bundle ID/path/FolderID/标题绝不进 telemetry/JSONL/stdout/log/report/测试输出；测试只写中性类别描述。
- 冻结树 mtime 不得改变（除允许写集）；无 git 操作；不触碰真实 Application Support 目录。

## 输出纪律

- 先更新 Workflow/results/T-1F-B.md（"in progress（resume）"），完成后 complete；
- 最终回复 <250 词：审查结论、测试数、验证输出关键行、修复（如有）、PRIOR_EXPOSURE。不贴大代码块。
