# ADR-005 — ICON-PIPELINE（异步图标管线）

- **状态**：Accepted（2026-08-28，Main 确认；实现随 Wave 1 落地）
- **关联**：PHASE1B Prompt §3.1.10/§5.3；wave1-interfaces.md §D；ADR-003（防串图配合）

## 背景

真实 app 图标需运行时读取 + 异步加载；不得复制第三方图标进 repo/发布包；不得磁盘缓存；缓存 key 不得泄露身份。

## 决策

1. **IconKey 无身份**：仅 `identity（IconIdentity 不透明）+ pointSize + displayScale + appearance`；不含 catalog revision（revision 用于 UI apply 资格，不使缓存失效）、不含 bundle ID 原文/路径/哈希。
2. **有界内存缓存**：count（256）+ cost（64MB）双上界 + LRU（lastAccess + 插入序确定性 tie-break）+ memory pressure 双通道清理（冻结通知名 + DispatchSource 兜底）；**无磁盘持久化**。
3. **异步契约**：`IconLoading` 协议 + `SystemIconLoader`（仅 `NSWorkspace.icon(forFile:)`/`icon(for: UTType.application)` 公开 API 运行时读取；`resolver` 注入 identity→URL 映射）；同 key in-flight 请求合并（单次加载）；`IconRequestHandle` 单 consumer 取消（幂等、不影响他人）；`cancelAll`/`purgeAll`/`shutdown`（teardown 零回调）。
4. **MainActor 写回 + generation 门控**：每 consumer 携带自己的 generation；过期 generation 完成回调不落图（stale apply = 0）；与 AppGridUI `ItemBindingToken`（七字段）+ teardown 构成三层防线。
5. **统计无隐私**：`IconPipelineStats` 仅计数（requests/hits/misses 等；不变量 requests == hits + misses），无字节/哈希/路径；telemetry `icon_cache_count/cost` 预留（Wave 2 时 stats 无访问器 → 如实记录恒 nil，标注"预留未启用"）。

## 后果

- 测试全隔离：程序生成图像（NSBitmapImageRep 内存）+ FakeLoader 注入；绝不触碰真实 /Applications 图标。
- 偏离记录：`@unchecked Sendable`（NSImage 非 Sendable，冻结签名要求）；macOS 26 SDK 移除 `NSApplication.didReceiveMemoryWarningNotification` → 稳定字符串 + DispatchSource 兜底。
