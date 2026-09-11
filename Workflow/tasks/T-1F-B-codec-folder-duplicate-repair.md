# T-1F-B-codec-folder-duplicate-repair — validateStructure folder 重复误判修复

## 背景
T-1F-B（LayoutStore）中断 Worker 落盘的 `LayoutStoreCodec.validateStructure` 存在真实缺陷：`seenFolderIDs` 集合在顶层条目循环与 folder records 循环之间共享。合法布局中每个顶层 folder 条目必然对应一个 folder record（配对是必需结构），因此任何含 folder 的布局 decode 时第二个 insert 失败 → 返回 false → `.corrupt`。该缺陷由 T-1F-B-tests-codec Worker 在写测试时实证发现（临时探针确认后移除），如实报告未修。

## 根因（Main 只读诊断，已确认）
`Sources/AppGridUI/LayoutStore/LayoutStoreCodec.swift` `validateStructure`（约 :200-228）：
- 顶层循环（约 :207-213）：folder 条目做 `UUID(uuidString:)` 校验后 `seenFolderIDs.insert(folderID)`。
- folders 循环（约 :216-220）：record 做 UUID 校验后再次 `seenFolderIDs.insert(record.id)`。
- 同一 folder 两处都出现 → 第二次 insert 返回 false → 整体 false → `.corrupt`。

## 修复规格
1. **顶层循环**：folder 条目保留 `UUID(uuidString:)` 校验，但**不再**向 `seenFolderIDs` 插入（顶层 folder 条目的唯一性由 folders 循环独占保证）。
2. **folders 循环**：保持现状（UUID 校验 + `seenFolderIDs.insert(record.id)` 唯一性 + 成员去重 + 全局 ref 唯一性）。
3. **可选加固（建议做）**：顶层 folder 条目应存在于 `envelope.folders` records 中（悬空引用 → false）。若实现，注意与修复 1 的集合语义一致。
4. 头注释（若提及"FolderID 全局唯一"语义）无需改动，语义不变。

## 写范围（仅此 2 文件）
- `Sources/AppGridUI/LayoutStore/LayoutStoreCodec.swift`（仅 validateStructure 相关行）
- `Tests/AppGridUITests/LayoutStoreCodecTests.swift`（追加 1-2 个回归测试：含 folder 的合法布局 round-trip decode = .loaded；可选：悬空顶层 folder 引用 → .corrupt）

## 只读范围（仅此 3 文件）
- `Sources/AppGridUI/LayoutStore/LayoutStoreCodec.swift`
- `Sources/AppGridUI/LayoutStore/LayoutStore.swift`（类型）
- `Tests/AppGridUITests/LayoutStoreCodecTests.swift`（现有测试，追加前先读）

## 禁止
- 不改 LayoutStore/ 其余 3 文件、LayoutDomain/、冻结树。
- 不写 actor 测试（T-1F-B-tests-actor 负责）。
- 不读禁止来源；无 git 操作；隐私红线（中性假数据）。

## 验证（必须全部通过）
1. `swift build -c debug` exit 0。
2. `swift test` 全量：期望 871 + 新增全绿、0 failures（写范围外失败如实报告、不修改）。
3. `swift build -c release` exit 0。

## 输出纪律
- 先写 `Workflow/results/T-1F-B-codec-folder-duplicate-repair.md`（状态 in progress + 计划），再动手。
- 完成后更新结果文件：改动摘要、测试数、3 项验证输出、Status: PASS。
- 回复 <250 词，无大代码块。
