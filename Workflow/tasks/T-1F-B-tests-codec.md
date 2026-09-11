# T-1F-B-tests-codec — LayoutStoreCodec 测试编写

## 背景
T-1F-B（LayoutStore）Worker 在完成源码后因上下文耗尽中断，测试文件未写。编译修复（T-1F-BC-compile-repair）已合并，基线 837/0。本任务只写 codec 测试，不写 actor 测试（后续任务）、不改源码。

## 任务
新建 `Tests/AppGridUITests/LayoutStoreCodecTests.swift`，覆盖 LayoutStoreCodec 测试矩阵（见下）。测试风格参照现有 `Tests/AppGridUITests/LayoutDomainMutationTests.swift`（XCTest、`@MainActor` 视需要、中文测试名或英文均可，与现有文件一致即可）。

## 只读范围（仅此 4 文件，不要读其他文件）
- `Sources/AppGridUI/LayoutStore/LayoutStoreCodec.swift`（codec 实现）
- `Sources/AppGridUI/LayoutStore/LayoutStore.swift`（LayoutStoreLoadResult 等类型）
- `Sources/AppGridUI/LayoutDomain/PersistentWorkspaceLayout.swift`（域类型构造，若测试需要构造布局）
- `Tests/AppGridUITests/LayoutDomainMutationTests.swift`（模式参考）

## 公开 API 摘要（Main 已提取，供快速定位）
- `LayoutStoreCodec.schemaVersion = 1`；上限：`maxFileBytes = 1<<20`、`maxFolders = 512`、`maxAppReferences = 10_000`、`maxMembersPerFolder = 2_048`
- `static func encode(_ layout: PersistentWorkspaceLayout, writeGeneration: UInt64) throws -> Data`（域校验+上限校验→payload→SHA-256→envelope；同布局两次 encode 逐字节一致）
- `static func decode(_ data: Data) -> LayoutStoreDecodeResult`（大小上限→JSON→版本→校验和→结构→上限→域不变量）
- `LayoutStoreDecodeResult`：`.loaded(DecodedLayout)` / `.corrupt` / `.unknownFutureVersion(UInt64)` / `.overLimit`（以源码为准）
- `LayoutStoreCodecError`：含 `.overLimit` 等（以源码为准）

## 测试矩阵（Prompt §10.1 store 部分）
1. **往返**：合法布局 encode→decode = .loaded，layout 与 writeGeneration 一致。
2. **确定性**：同布局同 writeGeneration 两次 encode 逐字节相等。
3. **校验和篡改**：encode 后翻转 payload 字节 → .corrupt。
4. **结构校验**：FolderID 重复 / app ref 重复（顶层或成员）/ folder 成员重复 / 顶层条目 app+folder 同时非 nil 或同时 nil → .corrupt（构造非法 envelope 需绕过 encode 的域校验——可用 JSONEncoder 手构 envelope 或对合法数据做字节级篡改，以源码 validateStructure 逻辑为准）。
5. **上限**：超过 maxFileBytes（>1MiB 数据）→ .overLimit；超过 maxFolders/maxAppReferences/maxMembersPerFolder → .overLimit（构造超限布局，encode 应抛 .overLimit 或 decode 返回 .overLimit，以源码行为为准）。
6. **未知未来版本**：schemaVersion > 1 的合法结构 envelope → .unknownFutureVersion(版本号)；decode 绝不返回 .loaded。
7. **域不变量**：encode 对违反域不变量（如 title 超 64 grapheme、成员引用不存在等，以 WorkspaceLayoutValidator 为准）的布局抛错。
8. **垃圾数据**：随机字节 / 空 Data / 截断 JSON → .corrupt。

## 写范围（仅此 1 文件）
- `Tests/AppGridUITests/LayoutStoreCodecTests.swift`（新建）

## 禁止
- 不改任何源码文件（LayoutStore/ 全部 4 文件、LayoutDomain/、冻结树一律不动）。
- 不写 actor 测试（后续任务）。
- 不读禁止来源；无 git 操作；隐私红线（无 app 名/bundleID/路径入测试名或输出——测试用中性假数据如 "com.example.app1" 或 "app-1"）。

## 验证（必须全部通过）
1. `swift build -c debug` exit 0。
2. `swift test` 全量：期望 837 + 新增全绿、0 failures（写范围外失败如实报告、不修改）。
3. `swift build -c release` exit 0。

## 输出纪律
- 先写 `Workflow/results/T-1F-B-tests-codec.md`（状态 in progress + 计划），再动手。
- 完成后更新结果文件：测试文件路径、测试数、3 项验证输出、Status: PASS。
- 回复 <250 词，无大代码块。
