# T-1F-B — 版本化 layout store（Worker）

- 创建：2026-08-31（Asia/Tokyo）——预写骨架，A 合并后若有 API 名称偏差以实际为准
- 依赖：T-1F-A（LayoutDomain 纯域，含 `PersistentWorkspaceLayout`/`LayoutGeneration`/`LayoutMutation`）；ADR-009 转正后为权威
- 角色：Worker（文件系统 I/O 只走注入抽象；测试一律 injected temp dirs）
- 依据：Docs/PHASE1F_DRAG_PERSISTENCE_PROMPT.md §3.2/§6.1；Docs/ADR-009-WORKSPACE-LAYOUT-AND-PERSISTENCE.md；Workflow/PLAN.md §7/§10

## 范围

新增 `Sources/AppGridUI/LayoutStore/`：
- `LayoutStore` 协议 + actor 实现（注入 Application Support 位置抽象；`storeDirectory` 可注入）
- schema v1 codec + validator（确定性编码；版本字段；未知未来版本 → 只读保护，绝不覆盖写入）
- A/B 双槽 generation journal：单调 `writeGeneration` + 校验和；最新成功代 = last-known-good；temp 写 + 原子替换；写失败 → PERSISTENCE_DEGRADED 状态（重试策略，绝不清除 LKG）
- coalescing sink（合并 pending 写，latest-wins）+ 有界 flush barrier（flush 时同步落盘）
- 失败态处理 + `reset`（清空 store 恢复默认）
- 显式多实例策略：single-writer / 文件协调 / 显式 last-writer-wins（按 ADR-009 Q7 决策实现其一，其余记录策略）
- 启动读入：首启无文件 → 默认布局（不报错）；corrupt/unknown version → 读入只读保护状态，证据保留，不自动覆盖

## 写集（仅这些）

```
Sources/AppGridUI/LayoutStore/（新文件）
Tests/AppGridUITests/（新持久化测试——全部用 injected temp dirs，测试后清理自己的目录）
Docs/ADR-009-WORKSPACE-LAYOUT-AND-PERSISTENCE.md（末尾追加「T-1F-B 实现注记」，不改草案主体）
Workflow/results/T-1F-B.md（先写 in-progress）
```

## 禁止写（只读）

```
Sources/AppGridUI/LayoutDomain/（A 的产物，只读）
Sources/AppGridUI/DragSession/（C 的产物）
Sources/AppGridUI/ 下全部既有文件（AppGridUIPageContentProvider.swift、FolderDomain.swift 等）
Sources/PagingPrototypeApp/（含 AppDelegate、AppLaunchController）
Sources/PagingUI/、Sources/PagingCore/、Sources/MacAppCatalog/、Sources/AppCatalogCore/、Sources/AppIconPipeline/、Sources/PagingTelemetry/
Package.swift
Tests/PagingUITests/
```

## 红线

- 禁止读取：/Users/mac/Projects/LaunchBetter/、/Users/mac/Projects/BuhoReverseNotes/、2026-08-25-buho-launchpad-reverse、任何反编译 dump；接触即标 PRIOR_EXPOSURE。
- 隐私：布局正文/app 名/bundle ID/path/FolderID/标题绝不进 telemetry/JSONL/stdout/log/report/测试输出；测试只写中性类别描述；持久化文件的字段类别按 ADR-009。
- 冻结树 mtime 不得改变（除允许写集）。
- 无 git 操作；不触碰用户真实 Application Support 目录——只用注入的 storeDirectory（测试 temp root 或显式 fake path）。

## 验证

- `swift build -c debug` exit 0；`swift test` 全量（基线 789 + A 新增 + B 新增；既有不得回归；写集外失败如实报告不修改）。
- 验证后更新 ADR-009 末尾「T-1F-B 实现注记」。

## 验收（对 Prompt §10.2）

持久化测试矩阵全覆盖（如 PLAN.md §10 B 行）：首启无文件；save/load/restart；原子替换；中断写；主文件 corrupt + backup 有效；双 corrupt → 安全默认；权限拒绝；磁盘满；coalescing latest-wins；flush barrier；reset；未知未来版本绝不覆盖；多实例策略；全部注入 temp roots。

## 输出纪律

- 先写 Workflow/results/T-1F-B.md（"in progress" + 交付摘要），完成后更新完整结果；
- 最终回复 <250 词：新增文件、测试数、验证命令结果、偏差与理由、PRIOR_EXPOSURE（无则 NO_PRIOR_EXPOSURE）。不贴大代码块。
