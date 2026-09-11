# PHASE1E_REPORT — 文件夹基础垂直切片（Phase 1E）

- 日期：2026-08-30
- 范围：Phase 1E（chef-worker-reviewer-workflow v1.4.1）
- 报告格式：与 PHASE1C_REPORT 一致（A 完成内容 / B 验证 / C 诚实边界 / D 唯一建议）
- 基线：Phase 1D closeout 631 tests；release SHA `c7873a6cb2b59f7585262e39186d4fdd7979cf84e76f6ceebebc87cabb042df2`

## A. 完成内容

| 任务 | 内容 | 验证 |
|---|---|---|
| Gate 0 | 631/0 基线 + 基线清单 `Docs/PHASE1E_BASELINE_MANIFEST.sha256`（31 行）；四假设：H1 NOT_REPRODUCED / H2 CONFIRMED→repair / H3 CONFIRMED 死回调→T-1E-B 移除 / H4 NOT_REPRODUCED | 631/0 + debug/release exit 0 |
| T-1E-H2-repair | `AppGridUIPageContentProvider` 实例 `itemsPerPage`（:74），servedPageCount 用之（:58-61）；`AppDelegate.swift:290` 一处接线覆盖 provider+searchPresentation 双路径 | 633/0；Reviewer 8f555c7f PASS |
| T-1E-A | 领域模型：`FolderDomain.swift`（FolderID/FolderGeneration/FolderTitle/FolderEntry/FolderSnapshot/TopLevelEntryIdentity/TopLevelEntry/ActivationRouter/FolderMembership.rebase/TopLevelComposition.build）+ `FolderLabFixture.swift`（makeGroups，默认 off，groupSize 35，中性 `Group N`）+ `AppGridFocusIdentity.swift` 泛化（entryIdentity 存储、appID 计算属性） | 27 新测试；660/0；Reviewer 22616319 PASS |
| T-1E-B | `AppGridUIPageContentProvider` 顶层组合 `[TopLevelEntry]`（app+folder）、folder snapshot latest-wins + idle 提交、页数/锚点/5 级 remap、搜索扁平化（app-only 显示名，退出恢复）；`AppGridSearchPresentationController` 死 `onStateChange` 移除（记录决策） | 20 新测试；709/0（与 C 并行）；Reviewer 32d4e433 PASS |
| T-1E-C | `AppGridCellView` folder cell 模式（SF Symbol folder + 标题 + 成员数，`applyIconIfValid` 拒 app 图标写回）、`AppGridPageView` folder 分支（L129-138）、`FolderOpenState.swift`、`FolderOverlayView.swift`（层外点击只关文件夹、成员激活、内部分页、generation 门控、Reduce Motion）；修复 attempt-1 遗留 overlay 点击坐标 bug（`panel.convert(point, from: self)`） | 29 新测试；689/0；Reviewer 607b9a0a PASS |
| T-1E-D | `FolderKeyboardLogic.swift`（FolderInnerNavigator/FolderKeyboardPriority/FolderFocusRestore/FolderTitleEditing 纯逻辑）+ `KeyboardFocusController` folder 感知 seam + `AppSearchController` modeFirstResponderProvider + `FolderTitleEditor.swift`（first responder，Enter/Escape/失焦，无磁盘/telemetry） | 32 新测试；741/0 → MAJOR（Command-F 残留 isEditingTitle）→ repair 744/0；Reviewer 5d79a69b r1 PASS(1 MAJOR) → 0ee0c875 r2 PASS |
| T-1E-E | `--folder-lab` 标志（默认 off）、`AppCatalogAssembly` folder 接线 + `makeMemberLaunchCell(appID:servedRevision:)`（成员启动复用 AppLaunchController.handleCell 精确管线，无并行路径）、`AppDelegate` installFolderWiring + 两段式空白单击（folder 开→关文件夹，下一真实背景点击退出）、teardown 全链 | 12 新测试；756/0；Reviewer 8facb79c PASS（synthetic-cell 启动路径逐级核验 SOUND） |

**新增源文件**：`Sources/AppGridUI/FolderDomain.swift`、`FolderLabFixture.swift`、`FolderKeyboardLogic.swift`、`FolderOpenState.swift`、`FolderOverlayView.swift`；`Sources/PagingPrototypeApp/FolderTitleEditor.swift`。

**修改源文件**：`Sources/AppGridUI/AppGridFocusIdentity.swift`、`AppGridUIPageContentProvider.swift`、`AppGridSearchPresentationController.swift`（死回调移除）、`AppGridCellView.swift`、`AppGridPageView.swift`；`Sources/PagingPrototypeApp/KeyboardFocusController.swift`、`AppSearchController.swift`、`AppDelegate.swift`、`AppCatalogAssembly.swift`、`AppArguments.swift`。

**新增测试**：`Tests/AppGridUITests/FolderDomainTests.swift`(15)、`FolderLabFixtureTests.swift`(5)、`AppGridFocusIdentityGeneralizationTests.swift`(7)、`TopLevelCompositionTests.swift`(15)、`FolderSearchFlatteningTests.swift`(5)、`FolderCellTests.swift`(5)、`FolderOverlayTests.swift`(11)、`FolderInnerPagingTests.swift`(4)、`FolderOpenStateTests.swift`(9)、`FolderKeyboardLogicTests.swift`(32)；`Tests/PagingUITests/FolderIntegrationTests.swift`(12)；`AppGridUIPageContentProviderTests.swift` +2（H2）。

**文档**：`Docs/ADR-008-FOLDER-PRESENTATION.md`（ACCEPTED）、`Docs/PHASE1E_SPEC.md`、`Docs/PHASE1E_VALIDATION_PLAN.md`、`Docs/PHASE1E_REPORT.md`、`Docs/PHASE1E_BASELINE_MANIFEST.sha256`；`Docs/VALIDATION_RESULTS.md` / `IMPLEMENTATION_LOG.md` / `PARAMETER_RATIONALE.md` / `PRIVACY_DATA_MAP.md` / `PROVENANCE/COMPONENTS.md` 追加。

## B. 验证

| 项 | 结果 | 证据 |
|---|---|---|
| AUTOMATED_TESTS | PASS | 789 tests, 0 failures, exit 0（Main Gate 0 复跑 2026-08-30；打字机波次后基线，见 `Docs/PHASE1F_BASELINE_MANIFEST.sha256`） |
| BUILD_DEBUG | PASS | exit 0；debug SHA `e4d7da2847fdea84645e422661af0e87559c1ce1f1a533af6e3b2de85add466a` |
| BUILD_RELEASE | PASS | exit 0；release SHA `9537f8ddc370c8ff4d04565b7306fa7b2578efc183a76ca0fa7688595e252fb9` |
| REVIEW_T-1E-H2-repair-r1 | PASS | 8f555c7f（0 BLOCKER/0 MAJOR/0 MINOR/0 QUESTION） |
| REVIEW_T-1E-A-r1 | PASS | 22616319（1 MINOR：FolderTitle.normalized 回退值未 trim/cap；2 QUESTION） |
| REVIEW_T-1E-B-r1 | PASS | 32d4e433（0 BLOCKER/0 MAJOR/0 MINOR；3 QUESTION 记录） |
| REVIEW_T-1E-C-r1 | PASS | 607b9a0a（1 MINOR 证据注记；1 QUESTION mtime 非密码学证明） |
| REVIEW_T-1E-D-r1 | PASS(1 MAJOR) | 5d79a69b：Command-F 标题编辑残留 isEditingTitle → repair |
| REVIEW_T-1E-D-repair-r2 | PASS | 0ee0c875（MAJOR 真修复；1 MINOR：回归测试走纯逻辑 seam） |
| REVIEW_T-1E-E-r1 | PASS | 8facb79c（synthetic-cell 启动路径核验 SOUND；1 MINOR 覆盖注记） |
| CORE_FROZEN | PASS | 冻结树最新 mtime 均 08-29（PagingCore 21:16 / AppCatalogCore 20:50 / MacAppCatalog 21:01 / AppIconPipeline 20:58 / PagingTelemetry 21:09 / PagingUI 22:44；Package.swift 08-28 20:42；AppLaunchController 08-28 21:46），早于 1E 工作 08-30 16:00+ |
| CONFLICT_WHITESPACE | PASS | 无冲突标记；无新增尾部空白 |
| PRIVACY_REDLINE | PASS | 新 1E 文件无 PagingTelemetry/JSONEncoder/UserDefaults/os_signpost/NSLog/print；PRIVACY_DATA_MAP §8 |
| DIAGNOSTICS_DISCIPLINE | PASS | 无 hitch-fix 宣称；token 保持 PRODUCT_TIMER_TOLERANCE_0MS / SHORT_TAIL_MITIGATED_BY_TOLERANCE(20–25ms) / CAUSALITY_UNRESOLVED_FOR_GT25MS |
| MANUAL_FOLDER_GUI_GATE | PASS_USER_REPORTED_WITH_EVIDENCE | 用户实机验收"没问题了"（打字机波次 6 项复测清单：folder+Return 打开 / app 槽位 Return 启动 / 文件夹内下键钳制 / 鼠标打开后蓝框清除 / 打开时成员 1 无蓝框 / Escape 关闭后焦点恢复；decision_recorded T-1E-nav-typewriter-user-accepted） |
| MANUAL_FOLDER_KEYBOARD_GATE | PASS_USER_REPORTED_WITH_EVIDENCE | 同上（打字机四方向 + 文件夹内 ↓/↑ 环绕实机验收通过） |
| MANUAL_TRACKPAD_60HZ_REGRESSION_GATE | NOT_RUN | 无触控板 60Hz 回归的独立实机证据；不得从键盘验收自动推导（Gate 0 对账，Prompt §1.2.7） |
| MANUAL_120HZ_GATE | BLOCKED_BY_HARDWARE | 60Hz 面板 |

## C. 诚实边界

1. 手动门：文件夹 GUI/键盘门已获用户实机验收 PASS（打字机波次，2026-08-30）；触控板 60Hz 回归门仍 NOT_RUN——自动化 789/0 不替代真实 GUI + 物理键盘/触控板验收，触控板门不得从键盘验收自动推导。
2. Phase 1D 搜索手动门无正式记录（用户实机证据存在但未落事件），保持 NOT_RUN 不伪造。
3. T-1E-D 的 AppKit-only 行为（Tab/key-window/空白单击）无自动化测试覆盖——由手动门或后续阶段覆盖。
4. 打开文件夹时初始内层焦点视觉未立即应用（与 deferred-focus 一致，用户实机确认后定案）。
5. `FolderGeneration.incremented()` 在 UInt64.max 可溢出——镜像既有 AppSearchGeneration 模式，实际不可达。
6. `FolderEntry` 构造无 ≥2 成员不变量——由 `FolderMembership.rebase` dissolve 语义保证，构造点不重复校验。
7. 成员启动经 synthetic cell 复用 handleCell 管线（overlay 成员 cell 携带 catalogRevision: 0 会被冻结的 AppLaunchController 拒为 stale）——管线逐级核验 SOUND，无绕过 stale/identity/file-existence 校验。
8. 120Hz 门 BLOCKED_BY_HARDWARE（60Hz 面板），不宣称 120Hz 验证。

## D. 唯一建议

**RECOMMEND_PROCEED_TO_PHASE_1F_DRAG_AND_PERSISTENCE**

- 生效条件：用户实机通过 MANUAL_FOLDER_GUI_GATE / MANUAL_FOLDER_KEYBOARD_GATE / MANUAL_TRACKPAD_60HZ_REGRESSION_GATE（PASS_USER_REPORTED_WITH_EVIDENCE）。
- 未通过前保持 `PHASE1E_AUTOMATED_COMPLETE_PHYSICAL_PENDING`。
- 不适用项：拖拽创建/重排/跨页移动、持久化、Hot Corner、品牌视觉（Phase 1F 范围）；120Hz 验证（硬件阻塞）。
