# T-1F-planning — Phase 1F 正式计划 + ADR-009/ADR-010 草案（Chief）

- 创建：2026-08-30（Asia/Tokyo）
- 角色：Chief（规划/ADR 草案，零业务代码）
- 依据：Docs/PHASE1F_DRAG_PERSISTENCE_PROMPT.md（1251 行，SHA-256 d6819a4e3c34b51cf214197b878e9cf6dfd884ba211dfac3a2b5f5db709c8134）

## 必读

- Phase 1F Prompt 全文（§0-§17）
- Workflow/PLAN.md、Workflow/MAIN_BRIEF.md、Workflow/STATE.json、Workflow/config.json
- Docs/ADR-004-APP-CATALOG-SNAPSHOT.md、ADR-006-KEYBOARD-FOCUS.md、ADR-007-SEARCH-PRESENTATION.md、ADR-008-FOLDER-PRESENTATION.md、PRIVACY_DATA_MAP.md、PARAMETER_RATIONALE.md
- Sources/AppGridUI/FolderDomain.swift（TopLevelEntry/TopLevelEntryIdentity/FolderID/ActivationRouter/TopLevelComposition）、Sources/PagingPrototypeApp/AppDelegate.swift 的 folder wiring

## 交付物

1. **Phase 1F 正式计划**：追加/更新 Workflow/PLAN.md 的 Phase 1F 部分——DAG（Gate 0 已过 → T-1F-A → B∥C → D → E → F）、每任务最小写集（文件级）、依赖、并发波次、测试隔离（每 Worker 独立临时目录）、SwiftPM .build 串行策略。
2. **Docs/ADR-009-WORKSPACE-LAYOUT-AND-PERSISTENCE.md（草案）**：必须回答 Prompt §6.1 全部 16 问：
   - layout/projection/catalog/folder snapshot 所有权；
   - app 持久引用格式（bundle-ID 为主 + fallback 方案比较 ≥3 种，§4.2）；
   - FolderID 安全持久化（§4.3，UUID 不进 telemetry/stdout）；
   - schema v1 结构与上限（§4.4 建议评估：1 MiB / 512 folders / 10,000 refs / 2,048 members——待验证工程上限，非既有产品事实）；
   - Application Support 路径与注入（§4.5，独立中性命名）；
   - 原子写/backup/flush/多实例策略（§4.6，A/B 双槽或等价 generation journal，fault injection 证明）；
   - corruption/unknown version 恢复不覆盖证据（§4.7）；
   - missing/reappearing/new app reconcile（§4.8）；
   - 单成员 dissolve 区分用户逻辑变更 vs 当前不可用投影（§4.8）；
   - store failure 内存态/UI/retry（§4.6）；
   - reset layout（§4.9，测试仅注入临时目录）；
   - 本地敏感数据清单（§4.5/§10.8）；
   - 是否需要改 AppCatalogCore（默认冻结；§7 只允许窄任务，绝不公开 AppID.storage）；
   - 为什么不用 Launchpad/Dock DB、UserDefaults 大 blob、云同步；
   - 为什么不能直接持久化 FolderSnapshot + 替换 hashValue 非稳定顺序（§3.1 架构缺口 1-3）；
   - renameFolder 是否真实 mutation + 64-grapheme 规范化 + 重启恢复验证。
3. **Docs/ADR-010-DRAG-SESSION-AND-DROP-SEMANTICS.md（草案）**：必须回答 Prompt §6.2 全部 14 问：
   - AppKit NSDraggingSession vs 自定义 state machine 取舍（§5.1 默认优先自定义窗口内 state machine）；
   - drag states/owner/session token（DragTransaction：opaqueToken/scope/sourceIdentity/layoutGeneration/catalogGeneration；idle→pressed→dragging/edgeTurnPending→commit|cancel→idle）；
   - click/drag 阈值、edge dwell、drop zones 独立确定 + 来源类别（PRODUCT_DECISION/PLATFORM_REQUIREMENT/ACCESSIBILITY_REQUIREMENT/INDEPENDENT_EXPERIMENT/PUBLIC_DOCUMENTATION，禁 REVERSE_ENGINEERING_COPY/OLD_SOURCE_TRANSLATION/UNKNOWN_ORIGIN）；
   - 5 类 mutation（reorder/create/add/cross-move/dissolve/move-out）语义；
   - insertion vs folder-create drop 区分；
   - 顶层/inner/跨页输入隔离（DragScope = .topLevel | .folder(id)；edge turn 只走已接受入口）；
   - search/title edit/refresh/window resign/teardown 取消；
   - 防 stale generation / source-target 复用；
   - pasteboard 无身份数据（§5.2，只放随机短期 opaque token）；
   - commit → UI commit → persist enqueue 顺序；
   - 无障碍等价操作（§3.10，同一纯 mutation engine）；
   - Reduce Motion + drag visual（§5.3，中性独立设计，禁旧产品视觉）；
   - 进 PARAMETER_RATIONALE.md 的参数清单；
   - 为什么不支持 nested folder/merge/外部 file drop。

## 约束

- 零业务代码（不碰 Sources/、Tests/）；
- 冻结树红线：PagingCore/MacAppCatalog/AppIconPipeline/PagingTelemetry/PagingUI/Package.swift/AppLaunchController.swift 默认冻结；AppCatalogCore 默认冻结（仅当 ADR-009 证明无法在 AppGridUI/PagingPrototypeApp 建立安全引用 projection 时才建议窄任务，且不得公开 AppID.storage）；
- 禁止来源：/Users/mac/Projects/LaunchBetter/、/Users/mac/Projects/BuhoReverseNotes/、2026-08-25-buho-launchpad-reverse、任何反编译 dump；参数/视觉只能来自公开文档或独立设计；
- 隐私：app 名/bundle ID/path/URL/FolderID 原值/布局正文绝不进 telemetry/JSONL/stdout/report；
- 诚实：工程上限与物理门状态按 Prompt 原样记录，不得写成既有产品事实。

## 验收

- PLAN.md Phase 1F 部分含文件级写集与并发波次方案；
- ADR-009/010 草案回答全部问题且有明示决策（状态 Draft，待实现后 ACCEPTED）；
- 结果文件 Workflow/results/T-1F-planning.md（先写 in-progress）；回复 <250 词，无大代码块。
