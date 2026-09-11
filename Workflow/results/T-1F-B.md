# T-1F-B — 版本化 layout store（schema v1 codec/validator、A/B journal、coalescing、flush barrier、失败态、reset、多实例策略）

- 状态：**in progress**
- 开始：2026-08-31（Asia/Tokyo）
- 角色：Worker
- AccessDeclaration: NO_PRIOR_EXPOSURE（截至本文件写入，未接触任何禁止来源）

## 交付摘要（计划）

新增 `Sources/AppGridUI/LayoutStore/`（4 文件）：

1. `LayoutStore.swift`：`LayoutStore` 协议（`load/enqueue/flush/reset/currentState/storeDirectory`）+ 结果/状态类型（`LayoutStoreLoadResult`：`.loaded/.loadedFromBackup/.firstLaunch/.readOnlyProtection`；`LayoutStoreState`：`.healthy/.persistenceDegraded/.readOnlyProtection`；`LayoutStoreFlushResult`；`LayoutStoreResetResult`；`LayoutStoreReadOnlyReason`；`LayoutStoreDegradation`；`LayoutStoreLockMode`）+ `LayoutStoreDirectoryProviding` 注入抽象（生产 `ApplicationSupportLayoutStoreDirectory` = Application Support 下中性子目录 `PagingPrototypeLayout/`）。
2. `LayoutStoreCodec.swift`：schema v1 envelope（`schemaVersion/writeGeneration/layoutGeneration/topLevelOrder/folders/metadata/checksum`）+ 确定性编码（sortedKeys、固定字段序、无时间戳/随机数）+ SHA-256 校验和（CryptoKit，仅意外损坏检测）+ 结构校验（FolderID 全局唯一、app ref 全局唯一、folder 无重复成员、title ≤64 grapheme、未知枚举拒绝、上限 1 MiB/512 folders/10,000 refs/2,048 members）+ 域校验器复核；未知未来版本 → 只读保护。
3. `LayoutStoreIO.swift`：`LayoutStoreIO` 协议（目录创建/写/原子替换/读/删/移/存在/lock/fsync）+ `FileManagerLayoutStoreIO` 生产实现（temp 写 + fsync + atomic rename + 目录 fsync 尽力；文件 0o600/目录 0o700）+ flock 锁（`workspace-layout.lock`）。
4. `LayoutStoreActor.swift`：actor 实现——A/B 双槽 generation journal（`workspace-layout-v1-{a,b}.json`，按 writeGeneration 轮换，最新有效 = LKG）；coalescing sink（pending latest-wins，单 in-flight + 单 pending）；有界 flush barrier（等 in-flight + 同步落盘 + 超时）；写失败 → PERSISTENCE_DEGRADED（有界指数退避重试，绝不清除 LKG）；corrupt/unknown version → 只读保护 + 证据保留（quarantine 中性命名）；reset（归档 `*.reset-<stamp>` + 立即持久化默认）；多实例策略（flock single-writer；锁被占 → explicit last-writer-wins，按 layout generation 比较，仅更高代可落盘，stale 拒绝计数）。

测试 `Tests/AppGridUITests/` 新增 2 文件（全部 injected temp dirs，测试后清理）：

- `LayoutStoreCodecTests.swift`：确定性编码（两次逐字节一致 + 往返稳定）；v1 round trip（bundleID/fallback/FolderID/title Unicode）；校验和篡改拒绝；重复/嵌套/无效/超限拒绝；未知未来版本识别。
- `LayoutStoreDurabilityTests.swift`：§10.3 全矩阵——首启无文件；save/load/restart；原子替换（无 temp 残留）；中断写（temp 残留忽略 + 截断槽 corrupt）；主 corrupt + backup 有效（加载 backup、证据保留至下次写）；双 corrupt → 安全默认只读保护；权限拒绝（chmod 只读目录）；磁盘满/注入写失败（fault-injecting IO，LKG 保留）；coalescing latest-wins（gated IO 确定性）；flush barrier；reset；未知未来版本绝不覆盖；多实例策略（双 actor 同目录）；全部 temp roots。

验证后追加 ADR-009「T-1F-B 实现注记」（不改草案主体）。

## 验证计划

- `swift build -c debug` exit 0；`swift test` 全量（基线 789 + A 48 + B 新增；既有零回归；写集外失败如实报告不修改）。
- 注意并行 Worker C 的 .build 锁争用：若报 build 争用错误，等待后重试一次。

## PRIOR_EXPOSURE

- NO_PRIOR_EXPOSURE（截至本文件写入）。
