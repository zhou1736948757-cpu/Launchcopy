# Phase 1F 验证计划（VALIDATION_PLAN）

> 状态：**AUTOMATED_COMPLETE_PHYSICAL_PENDING**（2026-09-05 Gate 0 对账补建）

## 1. 自动化验证

| 项 | 命令 | 通过判据 |
|---|---|---|
| 全量测试 | `swift test` | executed > 0，0 failures，exit 0 |
| Debug 构建 | `swift build` | exit 0 |
| Release 构建 | `swift build -c release` | exit 0 |
| 二进制指纹 | `shasum -a 256 .build/arm64-apple-macosx/{debug,release}/PagingPrototypeApp` | 记录值 |
| 测试隔离 | 检查 Tests 中 layout store 路径 | 仅 `FileManager.default.temporaryDirectory`，无 Application Support 写入 |
| 静态红线 | grep 新增/修改源码 | 无 addGlobalMonitorForEvents / CGEvent tap / AX / IOHID / 私有 API / 外部来源引用 |

## 2. 专项回归（自动化）

- B1ManualDeliveryTests（14 用例）：门默认关/「0」/门开 down+up+drag 投递与清记录/空白/ESC/两门同开 B1 优先/仅探针门独立/全链 s10-s9b-s6-sA/5 连击/拖拽回归/ESC cancel+恢复/门关全链自证；
- Bug11RowBoundaryIndicatorTests（10 用例）：同 index 双行锚点、coordinator 同 index 刷新、双坐标方向、页索引转换、BUG10 空白区、public 兼容入口、非 insertion 刷新预算；
- BUG8/BUG6/BUG10PreviewHost/DragUIIntegration 回归（40 用例）；
- LayoutStoreActorTests：codec/validator、A/B journal、coalescing、flush barrier、失败态、reset、多实例。

## 3. 物理验证（用户实机，未完成项）

| 项 | 操作 | 状态 |
|---|---|---|
| B10 实机 A/B | 门控关基线对照（35-38 击）+ 门控开 10+ 击 s10==击数、空白 s8c、ESC、拖拽预览、搜索与 folder 开合；门控开点搜索框聚焦仍正常；开 folder→关 folder→顶层点击启动 | **PENDING（Q-1 未回填）** |
| B11 视觉验收 | 真实窗口/触控板拖拽，观察跨行/行末 insertion indicator | **PENDING（PHYSICAL_VISUAL_ACCEPTANCE_PENDING）** |
| 拖拽/持久化 | 用户实机拖拽 reorder/create/add/move-out/cross-folder + 重启布局恢复 | 用户已报告 Folder 功能实现（USER_REPORTED_PHASE1F_FUNCTIONALLY_COMPLETE）；其余按证据对账 |

## 4. 环境记录

- 工具链：Xcode 26.6 (17F113) / Swift 6.3.3 / macOS 26.5.2 (arm64)（2026-08-28 Step 0 记录）；
- 验证日期：2026-09-05（Gate 0 fresh 重跑）；
- 无诊断 env gate 参与自动化基线（B10 门控默认关）。
