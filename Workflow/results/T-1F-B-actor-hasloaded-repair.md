# T-1F-B-actor-hasloaded-repair — ensureLoaded 主路径缺失 hasLoaded 置位修复

Status: PASS

## 改动摘要

文件：`Sources/AppGridUI/LayoutStore/LayoutStoreActor.swift`（唯一写范围文件；未改任何测试文件）

1. **hasLoaded 全路径置位（按 packet 规格）**：`ensureLoaded()` 在 `guard !hasLoaded` 之后加 `defer { hasLoaded = true }`，覆盖主分类 switch 结束、unknownFutureVersion/overLimit 提前 return、既有 catch 分支（保留原显式置位，幂等）。修复后 enqueue/flush 等不再重跑 load 重分类 state，只读保护 no-op 语义恢复（test 4 实证通过）。

2. **附带修复（同文件、同回归测试暴露的第二处真实缺陷）**：`runPersistLoop()` 的 `.failed` 分支 `if pendingLayout == layout { break }` 中，Swift 的 `break` 在 switch case 内只退出 switch、不退出外层 while → 写失败时 drain 循环无限自旋、`isPersisting` 永不复位 → flush barrier 必然 2s 超时（test 7 :268 timedOut / :281 nothingPending 的根因）。改为带标签 `drain:` 的 `break drain`，语义不变（pending 保留待 flush/下次 enqueue），一行标签 + 一行改动。已用最小 Swift 脚本实证 break-in-switch 语义。

## 验证输出（项目根目录串行执行）

1. `swift build -c debug` → Build complete!，exit 0 ✅
2. `swift test` → Executed 885 tests, with 0 failures (0 unexpected)；LayoutStoreActorTests 12/12 通过（含 test 4 / test 7 两个回归测试）；exit 0 ✅
3. `swift build -c release` → Build complete!，exit 0 ✅

## 备注

- 无 git 操作；仅读 packet 指定的 3 个文件；隐私红线遵守（无真实数据）。
- 调试期曾在源文件临时加 print 探针，已全部移除，最终 diff 仅上述两处。
