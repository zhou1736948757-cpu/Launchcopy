# T-1F-B-actor-hasloaded-repair — ensureLoaded 主路径缺失 hasLoaded 置位修复

## 背景
T-1F-B（LayoutStore）中断 Worker 落盘的 `LayoutStoreActor.ensureLoaded()` 存在真实缺陷：`hasLoaded` 仅在 createDirectory 失败分支（:167）置 true，主路径（读槽 + 分类）从不设置。后果：每个 actor 方法调用（enqueue/flush/currentState 等）都重跑完整 load、从磁盘重新分类 state，导致：
- 只读保护被绕过：load 返回 .readOnlyProtection 后，enqueue 重载发现槽已 quarantine → (.absent, .absent) → state = .healthy → 持久化继续（违反 ADR-009 只读保护 no-op 语义）。
- 语义错乱：flush 结果 .timedOut/.nothingPending 与预期不符（每次调用重载干扰）。

该缺陷由 T-1F-B-tests-actor Worker 的 2 个失败测试实证暴露（testInterruptedWriteTriggersReadOnlyProtectionAndPreservesEvidence :188 state 变 healthy；testWriteFailureDegradesThenRecoversAndKeepsLKG :268/.281 flush 结果不符）。Main 只读诊断已确认（grep hasLoaded 仅 :48 声明/:160 守卫/:167 catch 分支置位）。

## 根因（Main 只读诊断，已确认）
`Sources/AppGridUI/LayoutStore/LayoutStoreActor.swift` `ensureLoaded()`（约 :158-225）：
- :160 `guard !hasLoaded else { return }`
- :167 catch 分支 `hasLoaded = true`（唯一置位点）
- 主路径（acquireLock → cleanupTempFiles → readSlot a/b → 分类 switch）结束处**无** `hasLoaded = true`；unknownFutureVersion/overLimit 两个提前 return 分支（经 setReadOnly）也无。

## 修复规格
1. `ensureLoaded()` 的**每一条路径**都必须置 `hasLoaded = true`：主 switch 结束处、unknownFutureVersion 提前 return、overLimit 提前 return、既有 catch 分支（保持）。
2. 实现方式自选（如：各 return 前显式置位，或 `defer { hasLoaded = true }` 置于函数入口——注意 catch 分支已置位，defer 方案需去重或保持幂等；以最小改动、无行为副作用为准）。
3. 不改其他逻辑（读槽顺序、分类、quarantine、setReadOnly 均不动）。

## 写范围（仅此 1 文件）
- `Sources/AppGridUI/LayoutStore/LayoutStoreActor.swift`（仅 ensureLoaded 的 hasLoaded 置位）

## 只读范围（仅此 3 文件）
- `Sources/AppGridUI/LayoutStore/LayoutStoreActor.swift`
- `Tests/AppGridUITests/LayoutStoreActorTests.swift`（现有 12 测试；修复后应全绿——test 1/test 2 的期望与修复后语义一致，**不要改测试**）
- `Sources/AppGridUI/LayoutStore/LayoutStore.swift`（类型）

## 禁止
- 不改任何测试文件（LayoutStoreActorTests.swift 的 2 个失败测试是正确回归测试，修复后应通过）。
- 不改 LayoutStore/ 其余 3 文件、LayoutDomain/、冻结树。
- 不读禁止来源；无 git 操作；隐私红线。

## 验证（必须全部通过）
1. `swift build -c debug` exit 0。
2. `swift test` 全量：期望 885（873 + 12 actor）全绿、0 failures（写范围外失败如实报告、不修改）。
3. `swift build -c release` exit 0。

## 输出纪律
- 先写 `Workflow/results/T-1F-B-actor-hasloaded-repair.md`（状态 in progress + 计划），再动手。
- 完成后更新结果文件：改动摘要、3 项验证输出、Status: PASS。
- 回复 <250 词，无大代码块。
