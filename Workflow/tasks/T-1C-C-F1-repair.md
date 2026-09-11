# Task T-1C-C-F1-repair — 修复键盘跨页 settle 调和 (F1 MAJOR) + F2 文档虚报 + 辅助功能焦点断言

- **Task ID**: `T-1C-C-F1-repair`
- **Kind**: repair (post-PASS with MAJOR finding)
- **Parent gate**: `T-1C-C` (Reviewer `1df03f81` verdict **PASS rev r1**, report `Workflow/reviews/T-1C-C-r1.md`)
- **Phase**: Phase 1C — 键盘交互（焦点 + 方向键导航 + Return/Enter 启动）
- **Author**: Main（2026-08-30）。修复已由用户批准（授权小修复）。
- **Model**: normal Worker（fresh context）

---

## Objective

修复 Reviewer 在 T-1C-C rev r1 中带回的 **F1 (MAJOR)**，并顺带修正 **F2 (MINOR)** 文档虚报与 **F3 (MINOR)** first-responder 持久性（仅当与 F1 同处一处、改动最小时才纳入；否则 F3 记为 open follow-up，不在本任务强制）。

**F1 问题定义**：键盘**跨页**（方向键在页边界触发 `KeyboardPageTurner` 合成手势切页）在 settle/中断后，**键盘焦点没有与 committed/displayed 页重新调和**。

- 现因：`AppDelegate` 只在 `onPresentationUpdate` 里做 `applyLayout`，而该回调仅由 catalog-refresh 驱动（`AppGridRefreshController.swift`），**键盘翻页 settle/中断/committedPage 变化不触发它**；`KeyboardFocusController.refreshFocusVisual()` 从未被 `AppDelegate` 调用。
- 后果：键盘翻页落定后，焦点视觉/cell 映射可能停在旧页。影响低（键盘翻页确定性，坏映射最多 `rejectedNoBinding`，不会错启动 app），但确实是焦点一致性缺口（违反 Prompt §4.3 / 接受准则 7）。

**修复目标**：键盘路径页变化在 settle/中断后，触发一次焦点视觉 + cell 映射重算——复用/扩展现有键盘控制器已有的调和机制，落到 committed/displayed 页的确定目标，且**绝不动 `Sources/PagingCore/` 或不变量**。

## Expected / Allowed Write Scope（互斥，仅以下）

- `Sources/PagingPrototypeApp/KeyboardFocusController.swift`（新增 settle/中断→调和入口/接线；仅在现有结构内扩展，不重构 Core 语义）
- `Sources/PagingPrototypeApp/AppDelegate.swift`（键盘页 settle/中断后调用调和；接线只增不改既有行为）
- `Tests/PagingUITests/*Launch*.swift` 或 `Tests/PagingUITests/*Keyboard*.swift`（新增键盘跨页 settle 调和测试 + 辅助功能焦点一致性断言）
- `Docs/PHASE1C_VALIDATION_PLAN.md`（修正 F2：AC9 虚报的跨页 settle 测试——测试补上后改为真实引用；删/改虚报行）

**明确禁止**（不可触碰）：
- `Sources/PagingCore/`（冻结）、`Package.swift`、`AppLaunchController.swift`
- 任何禁止来源（BuhoReverseNotes / LaunchBetter / 2026-08-25-buho-launchpad-reverse）
- 不新增全局 NSEvent monitor、不请求 Accessibility 权限、不引入同步磁盘 I/O / 同步图标读取 / 每次按键重建整棵 view tree
- 不改生产默认 `Timer tolerance = 8.333ms`、帧源、PagingCore 参数
- 诊断状态保持三 token：`CAUSALITY_UNRESOLVED` / `PARTIAL_CONTRIBUTOR_SUPPORTED` / `PRODUCT_DEFAULT_UNCHANGED`（不得把任何修复标为 `FIX_VALIDATED`/`ALL_HITCHES_FIXED`）
- 不 commit/push/tag/reset/clean

## Acceptance（本修复）

1. 键盘跨页在 settle/中断落到 committed/displayed 页后，焦点视觉与 cell 映射被重算到该页确定目标；旧页映射不残留。
2. 新增测试真实断言上述行为（不是把不存在的测试写进文档）——测试名/位置自由，但语义必须真实存在且可执行。
3. 新增至少一条**辅助功能焦点一致性**断言：辅助功能焦点（accessibility focus）与视觉焦点 / 实际启动对象一致（Prompt §4.2）。
4. F2：`PHASE1C_VALIDATION_PLAN.md` AC9 改为真实测试引用（第 2 点的测试），或删除虚报行。
5. 回归不破：`swift test` 全量、`swift build -c debug`、`swift build -c release` 均 exit 0；既有 514 + 新增测试全绿。
6. 禁止树 / `AppLaunchController.swift` / `AppLaunchController` 未改。
7. 在 `Workflow/results/T-1C-C-F1-repair.md` 写出实际修改列表、新增测试数、构建/测试 exit code、Core 未改证据、隐私扫描结果。

## Notes

- 与触控板帧卡顿无关；本修复只关键盘焦点一致性，不得宣称修复分页卡顿。
- 若发现 F1 无法在不触碰 Core 或不改架构语义的前提下实现，返回 `BLOCKED` 并说明，不要硬扩范围。
- F3（first-responder 持久性）若与 F1 改动独立且改动小，可一并纳入；否则在本结果里注明留作 open follow-up。
