# T-1F-B-tests-actor — LayoutStoreActor 测试编写

## 背景
T-1F-B（LayoutStore）Worker 在完成源码后因上下文耗尽中断，测试文件未写。编译修复（T-1F-BC-compile-repair）已合并，基线 837/0。codec 测试（T-1F-B-tests-codec）由另一 Worker 并行/串行编写中——本任务只写 actor 测试，不写 codec 测试、不改源码。

## 任务
新建 `Tests/AppGridUITests/LayoutStoreActorTests.swift`，覆盖 LayoutStoreActor 测试矩阵（见下）。测试风格参照现有 `Tests/AppGridUITests/LayoutDomainMutationTests.swift`。

## 只读范围（仅此 5 文件，不要读其他文件）
- `Sources/AppGridUI/LayoutStore/LayoutStoreActor.swift`（actor 实现）
- `Sources/AppGridUI/LayoutStore/LayoutStore.swift`（LayoutStoreLoadResult/LayoutStoreState/LayoutStoreFlushResult/LayoutStoreResetResult/LayoutStoreLockMode 等类型）
- `Sources/AppGridUI/LayoutStore/LayoutStoreIO.swift`（IO 协议；如需模拟失败可注入自定义 IO）
- `Sources/AppGridUI/LayoutDomain/PersistentWorkspaceLayout.swift`（域类型构造）
- `Tests/AppGridUITests/LayoutDomainMutationTests.swift`（模式参考：布局构造方式）

## 公开 API 摘要（Main 已提取，供快速定位）
- `public actor LayoutStoreActor: LayoutStore`；`public init(storeDirectory: URL, io: any LayoutStoreIO = FileManagerLayoutStoreIO(), retrySchedule: [TimeInterval] = [0.05, 0.1, 0.2], flushTimeout: TimeInterval = 2.0)`
- 协议方法：`load() async -> LayoutStoreLoadResult`、`enqueue(_ layout:) async`、`flush() async -> LayoutStoreFlushResult`、`reset(defaultLayout:) async -> LayoutStoreResetResult`、`currentState() async -> LayoutStoreState`、`lockMode() async -> LayoutStoreLockMode`、`staleRejectionCount() async -> UInt64`
- `LayoutStoreLoadResult`：`.firstLaunch` / `.loaded(...)` / `.loadedFromBackup(...)` / `.readOnlyProtection(...)`（以源码为准）
- `LayoutStoreState`：`.healthy` / `.persistenceDegraded` / `.readOnlyProtection`（以源码为准）
- `LayoutStoreIO` 协议：`createDirectoryIfNeeded/writeFile/replaceFile/readFile/removeFileIfExists/moveFile/fileExists/contentsOfDirectory/acquireLock/fsyncDirectory`（以源码为准）——测试可用自定义 IO 注入模拟写失败/磁盘满/权限拒绝
- 文件命名：A/B 双槽 `workspace-layout-v1-{a,b}.json` + 锁文件（以源码为准）

## 测试矩阵（Prompt §10.1 store 部分）
1. **首启**：空目录 load → .firstLaunch（不报错）。
2. **save-load-restart 往返**：enqueue 合法布局 → flush → 新 actor 实例 load → .loaded，布局与 generation 一致。
3. **原子替换**：持久化后目录无残留 temp 文件；文件内容可被 codec decode 为 .loaded。
4. **中断写**：目录中预置损坏/截断文件 → load → 只读保护（证据保留、不自动覆盖）；enqueue 为 no-op（持久化暂停）。
5. **主槽损坏 + 备份有效**：预置主槽 corrupt、备份槽合法 → load → .loadedFromBackup。
6. **双槽损坏**：两槽均 corrupt → load → 只读保护安全默认。
7. **写失败（权限拒绝/磁盘满）**：注入抛错 IO → enqueue/flush → state = .persistenceDegraded；重试后恢复 healthy；LKG 绝不清除。
8. **coalescing latest-wins**：连续多次 enqueue（不同 generation）→ flush 后落盘为最后一次（最高 generation）。
9. **flush barrier**：flush 等待在途持久化完成并同步落盘 pending；幂等。
10. **reset**：reset(defaultLayout:) → 归档文件（中性命名 *.reset-<stamp>）→ 状态清空 → 立即持久化默认布局 → 新 actor load 得默认布局。
11. **未知未来版本绝不覆盖**：预置 schemaVersion > 1 文件 → load 只读保护 → enqueue no-op → 文件字节不变。
12. **多实例**：两 actor 同目录（flock 单写者）→ 第二实例 lockMode 反映锁被占；更高 generation 可落盘（last-writer-wins）、stale 拒绝计数递增（以源码行为为准）。
13. **全部 temp roots**：每个测试用独立临时目录（FileManager.temporaryDirectory + UUID），测试结束清理。

## 写范围（仅此 1 文件）
- `Tests/AppGridUITests/LayoutStoreActorTests.swift`（新建）

## 禁止
- 不改任何源码文件（LayoutStore/ 全部 4 文件、LayoutDomain/、冻结树一律不动）。
- 不写 codec 测试（T-1F-B-tests-codec 负责）。
- 不读禁止来源；无 git 操作；隐私红线（无 app 名/bundleID/路径入测试名或输出——中性假数据）。

## 验证（必须全部通过）
1. `swift build -c debug` exit 0。
2. `swift test` 全量：期望 837 + 新增全绿、0 failures（写范围外失败如实报告、不修改）。
3. `swift build -c release` exit 0。

## 输出纪律
- 先写 `Workflow/results/T-1F-B-tests-actor.md`（状态 in progress + 计划），再动手。
- 完成后更新结果文件：测试文件路径、测试数、3 项验证输出、Status: PASS。
- 回复 <250 词，无大代码块。
