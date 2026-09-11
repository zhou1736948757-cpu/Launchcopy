# T-worker-b-maccatalog — MacAppCatalog 完整实现（Wave 1 Phase 1B）

**Worker**: worker-maccatalog（deepseek-v4-flash:0731, max）
**任务**: t5（团队任务 id：t5；session task-id：T-worker-b-maccatalog）
**日期**: 2026-08-28
**Scope**: `Sources/MacAppCatalog/`、`Tests/MacAppCatalogTests/`、`Workflow/results/T-worker-b-maccatalog.md`
**Forbidden 遵守**: 未触碰 Package.swift / Sources/AppCatalogCore / Sources/AppIconPipeline / Sources/AppGridUI /
Sources/PagingCore / Sources/PagingUI / Sources/PagingTelemetry / Sources/PagingPrototypeApp / Docs / PROVENANCE /
Workflow（结果文件除外）；未读取 §2.2 任何禁止来源（BuhoReverseNotes / LaunchBetter 相关路径全部未打开）。
**AccessDeclaration: NO_PRIOR_EXPOSURE**（只读了 PHASE1B prompt §2.1 允许的 PagingPrototype 自身文件 +
wave1-interfaces.md 团队规划草案 + PHASE1A 既有结果文件样本；未读取任何治理材料/禁止来源）。

## 摘要一行

实现 MacAppCatalog 全部 6 项职责（受限根/扫描配置/Bundle metadata/URLNormalizer/可取消扫描/actor 仓库），
45 个测试全绿（0 failures），swift build exit 0、swift test --filter MacAppCatalogTests exit 0（3 次重跑稳定），
构建 0 warning。

## 实现要点（Sources/MacAppCatalog/，替换 MAIN SEED 占位）

| 文件 | 职责 |
|---|---|
| `CatalogRoots.swift` | `defaults` = 4 受限根（/Applications、/System/Applications、/System/Applications/Utilities、~/Applications）；隐私上界注释（§5.2/§3.3，Explorer C 约束） |
| `ScanConfiguration.swift` | 冻结签名；`dedupeOverlappingRoots`（默认 true）/`followDirectorySymlinks`（默认 false）/`stopAtAppBundle`（默认 true）/`fileManager` 测试注入 |
| `URLNormalizer.swift` | `canonicalize` = standardized + 根内含性；`isContained` 用「根路径+尾斜杠」前缀判定（防 /ApplicationsX 前缀陷阱） |
| `ScanFailure.swift` | `ScanFailureKind`（5 类，仅计数）+ `ScanReport`（appCount/failureCounts/scanDuration，**无任何路径/名称/ID 原文**） |
| `CatalogScanning.swift` | 冻结签名：`CatalogScanning` 协议 + `ScanTask`（NSLock 幂等取消，@unchecked Sendable）+ `CatalogScanResult` |
| `CatalogScanner.swift` | 具体扫描器：专用串行队列（qos .utility，热路径外）；递归目录遍历、`.app` 为终点；Bundle metadata 读取（Info.plist 合法/损坏/缺 ID/无效分类）；symlink 策略 + 祖先链回边检测（symlinkCycleDetected）+ visited 去重（防 DAG 重复）；条目间取消检查（取消 → 快照 nil 丢弃部分结果）；重叠根去重；internal `BundleMetadataReading` 注入点（测试用确定性中途取消） |
| `CatalogRepository.swift` | actor：revision 单调唯一拥有者；latest-wins（新 refresh 到达 → 旧任务 cancel；token 判取代 → coalesced 计数）；取消/半成品绝不写 current；deinit 防御性唤醒在途等待者；以自身 policy 经 `CatalogBuilder` 收敛最终快照 |

**关键语义决策（文档化）**：
1. **缺 bundle ID = 软失败**：合法 plist 但无 CFBundleIdentifier 的 app **仍以 canonical URL fallback 身份入册**
   （§5.2 规则 4 硬要求），同时计入 `failureCounts[.missingBundleIdentifier]`（诊断计数，非排除）。
2. **损坏/无效 = 排除**：`corruptedBundle`（Info.plist 存在但不可解析）与 `invalidAppBundle`（无 Info.plist）不入册。
3. **快照收敛归属**：扫描器产出 raw draft snapshot（仅携带 records+revision），`CatalogRepository` 以自身 policy
   重建最终快照（canonical URL 去重 → bundleID 去重 → 稳定排序为 AppCatalogCore 领域；冻结接口未规定构造方，
   此设计使 policy 唯一权威在 repository，与「revision 唯一拥有者」一致）。
4. **symlink 枚举语义**：实测 Foundation `contentsOfDirectory(at:)` **不跟随末级 symlink**（ENOTDIR）→ 统一以
   `resolvingSymlinksInPath().standardizedFileURL` 枚举；`.app` symlink 按发现路径入册（canonical = 链接 URL），
   目录 symlink 在 follow 开启时经 resolved 路径遍历（visited 防重复、祖先链防回边）。
5. **stopAtAppBundle=false**：顶层 `.app` 先入册、再进入 bundle 内部继续遍历（可发现内嵌 helper；显式放弃 §5.2 默认安全行为，默认 true 时 helper 绝不可见）。

## 测试（Tests/MacAppCatalogTests/，45 tests，0 failures）

**测试资源隔离（§10.3/§3.3/§14.C）**：全部用例只用 `FileManager.default.temporaryDirectory` 下程序生成的
fake `.app`（合法 Info.plist / 缺 CFBundleIdentifier / 损坏 plist / 无效 bundle / symlink 变体 / 不可读目录 /
内嵌 helper）；**绝不扫描真实 /Applications、绝不复制真实 app 或图标**；FakeAppFactory deinit 清理临时根。

| 套件 | 测试数 | 覆盖 |
|---|---|---|
| `URLNormalizerTests` | 10 | 根内含性（子路径/相等/前缀陷阱/外部/尾斜杠/根"/"）、canonicalize（内/外/去 ".."/重复斜杠） |
| `CatalogRootsAndConfigurationTests` | 6 | 4 受限根精确路径、绝不包含 / 与整个 ~、配置默认值、重叠根去重（含后到者吞并先到者、完全相同去重） |
| `CatalogScannerTests` | 20 | 顶层枚举、metadata 携带、displayName fallback、目录递归、helper 不可见（stopAtAppBundle 默认）、stopAtAppBundle=false 显式进入、缺 ID fallback 入册+计数、损坏/无效分类排除、不可读目录（chmod 0，root 下 XCTSkip）、symlink 默认不跟随/开启跟随、symlink 自环检测终止、DAG symlink 不重复不误报、重叠根去重（开/关 2 vs 3 条）、多根优先级、隐藏 app 跳过、**失败报告无路径/名称/ID 原文**（序列化断言）、立即取消丢部分结果、确定性中途取消（internal reader 注入，读满 10 个 bundle 后取消 → 快照 nil、appCount=10） |
| `ScanTaskTests` | 4 | 初始态、cancel 翻转、幂等、32 线程并发取消安全 |
| `CatalogRepositoryTests` | 5 | 顺序刷新单调 revision（1→2）+ current/lastReport、latest-wins（旧结果 coalesced+cancelled、current 不被覆盖、旧任务被取消观察）、晚到 completion 仍判 coalesced、取消刷新保持旧 current 且 revision 仍按调用递增（1→3）、repository 以自身 policy 收敛（记录集合一致） |

**编排工具**：`ScriptedScanner`（手动 complete + 按任务取消状态模拟回报，latest-wins 确定性测试）；
`CancellingAfterNReader`/`CancellingTaskBox`（真实扫描器确定性中途取消）。

## Verification（命令 + 退出码，3 次重跑稳定）

| 命令 | 结果 |
|---|---|
| `swift build` | **exit 0，0 warning**（@preconcurrency + @unchecked Sendable 处理 §H.4） |
| `swift test --filter MacAppCatalogTests` | **45 tests, 0 failures, exit 0**（重跑 3 次一致） |

注：并行 worker（AppCatalogCore/AppIconPipeline）中途在途文件曾导致全量测试构建瞬时失败（如
AppCatalogCoreTests 引用未落地的 `posixOrdering`），属编译期顺序等待（§F 矩阵），非本 target 问题；
其完成后再跑即全绿。期间我以 `swift build --target MacAppCatalog(Test)` 独立验证了本 target 编译。

## Changed Files

- `Sources/MacAppCatalog/CatalogRoots.swift`（新）
- `Sources/MacAppCatalog/ScanConfiguration.swift`（新）
- `Sources/MacAppCatalog/URLNormalizer.swift`（新）
- `Sources/MacAppCatalog/ScanFailure.swift`（新）
- `Sources/MacAppCatalog/CatalogScanning.swift`（新）
- `Sources/MacAppCatalog/CatalogScanner.swift`（新）
- `Sources/MacAppCatalog/CatalogRepository.swift`（新）
- `Sources/MacAppCatalog/Placeholder.swift`（删除，MAIN SEED 占位）
- `Tests/MacAppCatalogTests/FakeAppFactory.swift`（新）
- `Tests/MacAppCatalogTests/URLNormalizerTests.swift`（新）
- `Tests/MacAppCatalogTests/CatalogRootsAndConfigurationTests.swift`（新）
- `Tests/MacAppCatalogTests/CatalogScannerTests.swift`（新）
- `Tests/MacAppCatalogTests/ScanTaskTests.swift`（新）
- `Tests/MacAppCatalogTests/CatalogRepositoryTests.swift`（新）
- `Tests/MacAppCatalogTests/Placeholder.swift`（删除，MAIN SEED 占位）
- `Workflow/results/T-worker-b-maccatalog.md`（本文件）

## Deviations

1. `ScanConfiguration` 声明为 `@unchecked Sendable` 而非字面 `Sendable`：冻结接口含非 Sendable 的
   `fileManager: FileManager` 字段（§H 待决点 4 明示"编译期处理，不影响接口形状"）——@unchecked 为
   该编译期冲突的唯一零警告解；对外仍满足 `Sendable` 契约。
2. `CatalogScanResult.snapshot` 由扫描器以 raw records 构造、repository 以自身 policy 重建：冻结接口
   未指定快照构造方；该划分保证 policy 权威与 revision 分配同在 repository（§5.2 要点 ③"revision 拥有者单一"）。
3. `stopAtAppBundle=false` 语义为「先入册再进入 bundle 内部」：与字面"关闭停止"一致且不会漏掉顶层 app；
   默认 true 的 §5.2 职责与 §10.3 helper 测试点不受影响。
4. 失败分类含 `missingBundleIdentifier` 的"软失败"计数：app 仍入册（§5.2 规则 4 要求），计数仅供 telemetry
   诊断——已在代码与本文档双处说明。

## Memory Candidates

- Foundation `contentsOfDirectory(at:)` 不跟随末级 symlink（ENOTDIR）：symlink 目录遍历必须用
  `resolvingSymlinksInPath()` 后的 URL 枚举，否则 symlink 子树静默丢失且 visited 标记会污染真实路径。
- 同时请求 `.isDirectoryKey` + `.isSymbolicLinkKey` 时，symlink 的 `isDirectory` 返回链接自身类型（恒 false）；
  判定 symlink 目录性需解析目标后再查。
- 冻结接口含非 Sendable 字段时（§H.4 类），`@preconcurrency` 属性标注与 `@preconcurrency import` 均不能
  消除 "Sendable-conforming struct has non-Sendable type" 警告；`@unchecked Sendable` 是零警告解。
- 并行 worker 在途文件会瞬时破坏全量 `swift test` 构建；用 `swift build --target <自己target>` 独立验证
  编译，全量绿由 Main 收口（§F 矩阵已预期）。
- actor 测试中 `XCTAssert*(await repo.prop)` 非法（autoclosure 不支持并发）——必须先把值提到局部变量。
