# PHASE1E_VALIDATION_PLAN — 文件夹基础垂直切片

- 日期：2026-08-30
- 状态：FINAL（自动化验收全部 PASS；手动门 NOT_RUN）
- 依据：`Docs/PHASE1E_FOLDER_FOUNDATION_PROMPT.md`、`Docs/ADR-008-FOLDER-PRESENTATION.md`（ACCEPTED）

## 1. 范围

验证 Phase 1E 文件夹基础切片：领域模型、顶层组合、文件夹视觉/打开层、键盘/焦点/标题编辑、搜索/刷新兼容、AppDelegate 集成、隐私红线、冻结树完好。

## 2. 验收标准

| # | 标准 | 验证 |
|---|---|---|
| AC1 | 领域模型纯 Foundation，无 AppKit 依赖 | FolderDomainTests 15/15 |
| AC2 | 单成员文件夹 dissolve、空文件夹移除、稳定序 + 去重 | FolderDomainTests（rebase/dissolve 用例） |
| AC3 | folder generation 独立单调 token，不伪造 CatalogRevision | FolderDomainTests + 代码审查 |
| AC4 | 顶层组合 `[TopLevelEntry]` 页数 = ceil(entryCount/itemsPerPage)，锚点/5 级 remap | TopLevelCompositionTests 15/15 |
| AC5 | 搜索扁平化：仅 app 显示名过滤，退出恢复完整组合 | FolderSearchFlatteningTests 5/5 |
| AC6 | 文件夹 cell 中性视觉（SF Symbol folder + 标题 + 成员数），永不请求 app 图标 | FolderCellTests 5/5 |
| AC7 | 打开层：层外点击只关文件夹、成员激活、内部分页、generation 门控 | FolderOverlayTests 11/11 + FolderInnerPagingTests 4/4 + FolderOpenStateTests 9/9 |
| AC8 | 键盘：内层方向键/跨页、ESC 优先级、Command-F 先关文件夹、标题编辑 Enter/Escape/失焦 | FolderKeyboardLogicTests 32/32 |
| AC9 | Command-F 在标题编辑中不残留 isEditingTitle 脏状态 | 3 回归测试（repair） |
| AC10 | 集成：--folder-lab 接线、成员启动复用 AppLaunchController.handleCell 精确管线、两段式空白单击 | FolderIntegrationTests 12/12 |
| AC11 | 隐私：folder 标题/成员/identity 原值 + 图标数据不入 telemetry/JSONL/stdout/signpost/profile/report | 隐私扫描 + PRIVACY_DATA_MAP §8 |
| AC12 | 冻结树未改、无冲突标记、Debug/Release 构建通过 | mtime/hash 核验 + 构建 |

## 3. 测试矩阵

| 文件 | 用例数 | 覆盖 |
|---|---|---|
| Tests/AppGridUITests/FolderDomainTests.swift | 15 | FolderID/FolderTitle/FolderEntry/FolderSnapshot/rebase/dissolve/TopLevelComposition/ActivationRouter |
| Tests/AppGridUITests/FolderLabFixtureTests.swift | 5 | makeGroups 分组规则、默认 off、groupSize<=0 防御 |
| Tests/AppGridUITests/AppGridFocusIdentityGeneralizationTests.swift | 7 | entryIdentity 泛化、appID 计算属性、folder/placeholder→nil |
| Tests/AppGridUITests/TopLevelCompositionTests.swift | 15 | 顶层组合、页数、锚点、5 级 remap |
| Tests/AppGridUITests/FolderSearchFlatteningTests.swift | 5 | 搜索扁平化、退出恢复 |
| Tests/AppGridUITests/FolderCellTests.swift | 5 | folder cell 模式、图标写回拒绝 |
| Tests/AppGridUITests/FolderOverlayTests.swift | 11 | 打开层、层外点击、成员激活、坐标转换 |
| Tests/AppGridUITests/FolderInnerPagingTests.swift | 4 | 内部分页 |
| Tests/AppGridUITests/FolderOpenStateTests.swift | 9 | open-state 所有者、generation 门控 |
| Tests/AppGridUITests/FolderKeyboardLogicTests.swift | 32 | 内层导航、ESC 优先级、Command-F、标题编辑 |
| Tests/PagingUITests/FolderIntegrationTests.swift | 12 | --folder-lab、成员启动、两段式空白单击 |
| Tests/AppGridUITests/AppGridUIPageContentProviderTests.swift | +2 | servedPageCount 用实例 itemsPerPage（H2） |

## 4. 隐私红线

- folder 标题/成员/identity 原值 + 图标数据绝不入 telemetry/JSONL/stdout/signpost/profile/report。
- 仅内存中性计数：folder_count、member_count、open-close outcome enum、stale rejection count、apply duration 数值。
- 无持久化、无 Spotlight、无 PagingTelemetry schema 变更。
- `FolderID` redactedDescription = `FolderID(<redacted>)`，非名称派生。

## 5. 验证命令

```bash
swift test                      # 期望 789 tests, 0 failures（Gate 0 复跑确认 2026-08-30）
swift build -c debug            # exit 0
swift build -c release          # exit 0
# 冻结树 mtime/hash 核验 + 冲突标记 grep + 隐私 grep（见 PHASE1E_REPORT B 表）
```

## 6. Reviewer 焦点

- 每任务独立只读 Reviewer，自跑 swift test + debug/release。
- 重点：dissolve 语义、folder identity 不穿启动校验、无弱化第二启动路径、generation 门控、两段式空白单击、隐私红线、冻结树。

## 7. 每任务验收

| 任务 | 结果 | Reviewer |
|---|---|---|
| T-1E-H2-repair | 633/0 | 8f555c7f r1 PASS |
| T-1E-A | 660/0 | 22616319 r1 PASS |
| T-1E-B | 709/0（与 C 并行） | 32d4e433 r1 PASS |
| T-1E-C | 689/0（独立） | 607b9a0a r1 PASS |
| T-1E-D | 741/0 → MAJOR → repair 744/0 | 5d79a69b r1 PASS(1 MAJOR) → 0ee0c875 r2 PASS |
| T-1E-E | 756/0 | 8facb79c r1 PASS |
| T-1E-folder-inner-nav-repair | 772/0 | r1 PASS（Bug 1 下键钳制） |
| T-1E-folder-mouse-open-repair | 772/0 | r1 PASS（Bug 2 鼠标打开清外框） |
| T-1E-folder-deferred-inner-focus-repair | 772/0 | r1 PASS（Bug 3 打开不显成员 1 蓝框） |
| T-1E-folder-focus-layout-repair | 782/0 | r1 PASS（Bug 4 布局组合化） |
| T-1E-folder-keyboard-return-repair | 785/0 | r1 PASS（Bug 4 Return 打开 folder） |
| T-1E-nav-typewriter-outer-repair | 787/0 | r1 PASS（打字机外层） |
| T-1E-nav-typewriter-launch-test-repair | 787/0 | r1 PASS（启动测试适配） |
| T-1E-nav-typewriter-inner-repair | 789/0 | r1 PASS（打字机内层） |

## 8. 手动 GUI 结果表

| 门 | 状态 | 证据 |
|---|---|---|
| MANUAL_FOLDER_GUI_GATE | NOT_RUN | 待用户实机测试 |
| MANUAL_FOLDER_KEYBOARD_GATE | NOT_RUN | 待用户实机测试 |
| MANUAL_TRACKPAD_60HZ_REGRESSION_GATE | NOT_RUN | 待用户实机测试 |
| MANUAL_120HZ_GATE | BLOCKED_BY_HARDWARE | 60Hz 面板 |
