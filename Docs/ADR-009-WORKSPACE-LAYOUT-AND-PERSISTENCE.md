# ADR-009 — WORKSPACE LAYOUT AND PERSISTENCE

- **状态**：Accepted（T-1F-A 交付并合并后由 Main 转正，2026-08-31；实现注记见文末）
- **阶段**：Phase 1F（PHASE1F_DRAG_PERSISTENCE_PROMPT §4、§6.1；权威依据）
- **关联**：ADR-004（AppID 不透明身份/revision 所有权/remap 五级降级）；ADR-008（folder 呈现/dissolve/标题 64 上限）；ADR-006（焦点迁移/ESC/空白两段式）；PRIVACY_DATA_MAP §8（folder 内存边界）；PARAMETER_RATIONALE
- **回答**：Prompt §6.1 全部 16 问（§Q1–Q16 一一对应）
- **范围**：逻辑布局的持久化模型、身份、schema、存储、恢复、reconcile、reset、隐私边界

## 背景

1E 已交付 folder 呈现与打开层，但顶层序目前由 `TopLevelComposition.build` 派生（folders 在前 + 未分组 apps 在后，catalog 稳定序）——这是**派生投影**，不是用户布局真相源。`FolderSnapshot` 只表达 folder 集合，不能表达 app/folder 任意交错的全域顶层顺序，且 catalog rebase 会收缩暂缺成员。1F 引入唯一持久真相 `PersistentWorkspaceLayout`，由用户成功的 drag/无障碍 mutation 驱动，安全存本机，重启与目录刷新后恢复。

## 所有权模型（Q1）

| 事物 | 拥有者 | 可变 | 说明 |
|---|---|---|---|
| `PersistentWorkspaceLayout` | **逻辑布局层**（T-1F-A 新 LayoutDomain；不属 AppCatalogCore） | 仅经 `LayoutMutation(expectedGeneration:)` | 唯一持久真相源；专用 DTO/envelope，非自动 Codable |
| `PersistentAppReference` | 逻辑布局层 | 不可变 | 独立 DTO ≠ `AppID`；bundle-ID 主 + 确定性 fallback（Q2） |
| `VisibleWorkspaceProjection` | 逻辑布局层（纯函数） | 派生 | expected layout + 当前 `CatalogSnapshot` → 运行时呈现 |
| `LayoutGeneration` | 逻辑布局层 | 仅 mutation 成功时单调递增 | 只属逻辑布局；与 `CatalogRevision`/`FolderGeneration`/search generation/surface generation 完全分离；layout 层绝不 mint/forge `CatalogRevision` |
| `CatalogSnapshot` | `MacAppCatalog.CatalogRepository`（actor，ADR-004 冻结所有权） | 仅 refresh 流水线 | 1F 不改所有权 |
| `FolderSnapshot`（运行时） | 呈现层（1E 既有） | 1E 组合规则 | 1F 中由 projection 喂入；不落盘 |

**10 不变量**（T-1F-A 纯测试锁定，Prompt §3.1）：①同一逻辑 app reference 全局最多出现一次；②folder 不嵌套；③folder 只含 app；④空 folder 不存在；⑤用户主动变更后单成员 dissolve（1E 决策延续）；⑥拖拽不删改真实 .app；⑦不建第二条启动路径；⑧失败 mutation 无半提交；⑨layout generation 与 CatalogRevision/FolderGeneration/search/surface generation 分离；⑩UI 只消费已提交 layout。只有**明确成功的用户 mutation** 修改 PersistentWorkspaceLayout；refresh/部分扫描/暂缺/视觉 dissolve/search 只改派生投影，不反向删改期望布局。

## Q2. app 持久引用格式（≥3 方案比较）

**方案 1（选定）**：**bundle identifier 主 + canonical path 确定性 fallback**。
- 写盘值：`{case: bundleID, value: "com.example.app"}` 或 `{case: pathFallback, value: "<确定性规范化文件路径>"}`；二者带**中性字段类别**描述，原值只进布局文件这一受控例外。
- fallback 触发条件：app 无 bundle ID（`ApplicationProxy.bundleIdentifier == nil`）或 bundle ID 为空。
- fallback 的确定性：canonical path 按既有 ADR-004 的 canonical URL 归一化逻辑（去 symlink/大小写规范化）生成**稳定字符串形式**；比较时大小写不敏感、忽略尾部 `/`。
- 恢复语义：move 后以新 bundle ID 定位；重装后 bundle ID 不变则恢复；bundle ID 改变（如更新后变更）→ 用 path fallback 二级匹配；两者皆失配 → 引用保留为 **latent（未解析）**，不销毁、可手工移除。
- 无 bundle ID 且 path fallback 也失效 → latent。

**方案 2**：bundle identifier 主 + 本地随机 salt + 稳定 keyed digest 表示 fallback path。
- 写盘值：`{bundleID}` 或 `{digest}`（digest = HMAC/salted hash of canonical path，salt 存本地 keychain/App Support 私有文件）。
- 优点：path 原文不出布局文件（防第三方备份泄露路径）。
- 缺点：跨机器/恢复备份后 salt 丢失 → digest 永久不可逆，引用不可解析（除非同机）；引入 salt 生命周期与 keychain 依赖，复杂度高、可测性差；本项目布局文件已定义为"本地敏感受控例外"，digest 的额外安全性收益 < 恢复可靠性损失。

**方案 3**：security-scoped bookmark（`NSURL.bookmarkData`）。
- 优点：系统级稳定，自动跟随移动/重命名。
- 缺点：bookmark 需持有权限语义（沙盒外应用可创建但恢复需 security-scoped 访问）；bookmark data 为不透明 blob，**不可读、不可调试、不可确定性排序/比较**（validator 无法证明唯一性与顺序）；与"布局文件可审计"目标冲突；无 bundle ID 的 app 同样可能失效。
- 结论：不选；可在未来若沙盒化再评估。

**选型理由**：方案 1 满足"确定性、可审计、可恢复、跨重启稳定、写盘值可描述"；与 ADR-004 的 canonical URL 归一化既有逻辑一脉相承；不依赖持久 salt/keychain；validator 可对每一条 ref 证明格式合法。**明确禁止**：`Swift Hasher`/`displayName`/`redactedDescription` 作为持久身份（进程内不稳定/用户可见名可变/设计为不可逆）。

**AppID.storage 边界**：`AppID` 的原始 storage（bundle URL 等）**绝不公开、绝不直接 Codable**；持久引用经 LayoutDomain 内**受控投影**（读 canonical 归一化结果转成 `PersistentAppReference` DTO，写回时逆投影），不破坏 ADR-004 的不透明性与 telemetry 边界。此投影在 `AppGridUI/` 内完成 → **AppCatalogCore 默认冻结成立（Q13）**。

## Q3. FolderID 安全持久化

- `FolderID`（UUID storage）经受控 Codable 投影落盘：encode 时序列化 UUID storage（仅 LayoutStore 内专用 adapter 有访问权），decode 时经 `FolderID(uuid:)` 重建——**UUID 原值绝不进 telemetry/stdout/signpost/profile/错误报告/日志**（保持 `redactedDescription = "FolderID(<redacted>)"`）。
- schema v1 校验：重复 FolderID / 无效 UUID → 拒绝整文件（只读 fallback，Q7）或确定性修复（丢弃重复项，保留首个）；**绝不**从 title 派生 ID。
- 重启稳定性：folder 的 ID 由创建时生成一次，此后不变；layout 校验证明 FolderID 全局唯一。

## Q4. schema v1 结构与上限

```
WorkspaceLayoutEnvelope v1:
  schemaVersion: 1
  writeGeneration: UInt64          // 单调；A/B 双槽 journal 用（Q6）
  topLevelOrder: [EntryRef]        // .app(PersistentAppReference) | .folder(FolderID)
  folders: [FolderRecord]          // id: FolderID, title: String(≤64 grapheme), members: [PersistentAppReference]
  metadata: { migration: [String] /* 最少中性迁移元数据，含版本路径 */ }
  checksum: SHA-256                // 仅意外损坏检测，非防篡改
```

- 确定性编码：字段序固定、字典/数组按稳定序、无时间戳/随机数入正文 → 同布局两次 encode 逐字节一致（可测）。
- **上限（建议初始评估值，标「待验证工程上限，非既有产品事实」）**：文件 ≤ 1 MiB；folders ≤ 512；总 app references ≤ 10,000；每 folder members ≤ 2,048；title ≤ 64 grapheme（沿用 `FolderTitle.normalized` 语义，Character 截断不劈 grapheme）。超限 → 拒写 + PERSISTENCE_DEGRADED + 中性 UI 提示。
- validator 证明：FolderID 全局唯一；app reference 全局至多一个位置（顶层或某 folder 成员）；folder 无重复成员；顶层/folder 成员顺序原样保留；title 64-grapheme 规范化；未知枚举值拒绝。
- 未知未来版本：读为只读（Q7），**绝不静默降级覆盖**；旧版程序遇到新版文件 → 中性提示 + 只读呈现默认序。
- v1 往返测试 + 确定性编码测试 + 拒绝测试（重复/嵌套/无效/超限）进自动化矩阵 §10.2。

## Q5. Application Support 路径与注入

- 生产默认：`FileManager.default.urls(for: .applicationSupportDirectory)` 下**独立中性子目录**（如 `PagingPrototypeLayout/`），文件名中性（如 `workspace-layout-v1` + journal 槽后缀）。
- 明确**不选**：Launchpad/Dock 私有路径；任何 LaunchBetter/Buho 名称或 bundle ID 相关路径；`Documents`/`Desktop`/iCloud Drive；`/tmp` 作生产持久化；源码/项目目录；`UserDefaults` 存大 blob（仅作退化保护可存"已启用持久化"布尔与路径，不存正文）。
- 权限：目录与文件权限收紧当前用户（`posixPermissions 0o600` 文件 / `0o700` 目录）；创建时 `FileManager.createDirectory` + 显式 attributes；stdout **不打印完整路径**（只打印中性如 `layout store at <Application Support>/...` 或计数）。
- 注入：store protocol 定义 `LayoutStore`（`load/enqueue/reset/flush` 等）；生产实现接收路径注入点；**所有测试/自动化/--folder-lab/--catalog-root/smoke 默认注入内存或临时目录 store**，绝不读写真实 Application Support；folder lab 只 seed 显式空 store。
- 无网络/云/共享容器访问。

## Q6. 原子写、backup、flush、多实例

- store 为可注入协议；生产实现 = **actor/串行队列**（进程内严格串行）。
- 写入路径：temp write（同目录临时文件）→ fsync → **atomic rename/replace** → 更新目录元数据（尽力）。写失败不回滚已呈现内存状态，标 `PERSISTENCE_DEGRADED`（可重试、不清 last-known-good、不崩溃）。
- **恢复格式（选定）：同目录 A/B 双槽 generation journal**。每个有效槽 = `workspace-layout-{a,b}.<ext>` 携带单调 `writeGeneration` + 校验（结构校验 + checksum）。读：取最新有效 generation；主槽坏 → 备槽 last-known-good（**加载但不立即覆盖损坏证据**）；双坏/超限/未知版本 → 保留原文件 + 安全只读/默认空布局呈现，未经 reset 不静默清空。
- 备选方案（未选）：单一文件 + 独立 backup 文件"先覆盖主再复制 backup"——崩溃窗口在 rename 后、backup 复制前会两槽同代不同内容，无法证明不丢最近有效布局；**非双槽方案必须 fault injection 证明覆盖 rename 前/后崩溃**（Prompt §4.6 明文：该模式"不合格"除非证明）。
- 热路径：commit 后**异步持久化**（协程/后台队列，绝不阻塞 drag/animation 热路径；§5.4 禁同步写）。
- Coalesce：连续 drag mutation 可合并（latest-wins），**绝不乱序**；layout generation 单调裁决。
- **Flush barrier**：termination/teardown（挂 `applicationWillTerminate`/`windowWillClose`，即 1E `teardownAll()` 既有入口链）执行 **bounded flush**——等待在途持久化完成（带超时，超时则中性记录，不阻塞退出）；`flush()` 幂等。
- **多实例策略（显式裁决）**：默认 **single-writer + file coordination（`NSFileCoordinator`/flock 级）**；同机第二实例检测到持有锁 → 降级为 **explicit last-writer-wins**：以各自 layout generation 比较，仅写入更高 generation 的实例可落盘（避免旧 generation 覆盖新 generation）；两实例都按此规则写入 A/B 槽，读端仍取最新有效 generation。不静默双写同一槽。此策略写入 ADR 与 §10.3 多实例测试。

## Q7. corruption / unknown version 恢复（只读保护，不覆盖证据）

- 主坏备好 → 加载备槽；**不立即用备槽内容覆盖主槽**（证据保留；若用户显式 save 或下一个成功 mutation 才正常轮换）。
- 双坏 / 超限 / 未来版本 → 保留原文件（可挪入中性命名 quarantine，如 `workspace-layout-<stamp>.corrupt`，**不打印内容**）；呈现 = 安全默认布局（确定性默认序，不伪造用户布局）；UI 中性提示（不含路径/原始 JSON）。
- unknown future schemaVersion → 只读保护：绝不降级写回；用户操作只作用于内存投影，持久化暂停（PERSISTENCE_DEGRADED），reset 才重建。
- 自动化必须证明：corruption 后 catalog 呈现与 launch 仍可用。

## Q8. reconcile：missing / reappearing / new

| 情形 | 持久布局 | 呈现 |
|---|---|---|
| app 暂缺（当前 catalog 无此引用） | **引用保留**（latent；一次扫描缺失绝不改布局） | 隐藏即可；重现后回原逻辑位置/成员 |
| app 重现 | 不动 | 恢复原位置/成员 |
| 新 app（catalog 新增） | 不动 | 追加到确定性「未编排尾部」（ADR 固定位置：顶层序末尾，folder 之外） |
| 用户主动移出（真 mutation） | 更新 | 按 mutation |
| duplicate / identity 冲突 | 确定性处理（ref 全局唯一校验；重复 bundle-ID 多实例按 `DuplicateResolution`/`.keepMultiInstance` 语义区分） | 确定性呈现 |
| folder 仅 1 个**可用**成员（其余 latent） | **不删 latent membership** | 可视觉 dissolve（1E 规则） |
| 用户移出后剩 1 个**逻辑**成员 | **永久 dissolve**（唯一允许的持久 dissolve） | 成员回确定顶层位 |
| reset | 重建默认 | 全默认 |

- refresh 到达时拖拽进行中 → 取消 drag（统一 cancel，Q/ADR-010）→ 先提交新 catalog → 再 reconcile。
- 绝不伪造/改写 `CatalogRevision`（revision 所有权仍在 CatalogRepository）。

## Q9. 单成员 dissolve：用户逻辑 vs 不可用投影

区分两类 dissolve，语义不同（1E 的 dissolve 是**呈现组合规则**，1F 明确其为派生行为）：
- **视觉 dissolve（投影层）**：folder 的可用成员 < 2（含 latent 缺失）时呈现为 app/空；**不触碰 PersistentWorkspaceLayout**；成员重现则 folder 呈现恢复。
- **逻辑 dissolve（mutation 层）**：仅用户主动 move-out 致剩余 1 逻辑成员 → 一次原子 mutation 永久解散：剩余成员移到确定顶层位、folder 记录删除、LayoutGeneration++。
测试（§10.1/§10.4）：2 成员 1 不可用不丢 latent；用户移出 1 逻辑成员永久 dissolve 且重启仍解散。

## Q10. store 失败：内存状态 / UI / retry

- 内存中的已提交 layout 是权威即时视图：写失败**不回滚**已 commit 的 mutation（进程内一致性优先）。
- 标 `PERSISTENCE_DEGRADED`：中性 UI（如状态行徽标"布局保存暂不可用"，不含路径/正文）；后续成功写入自动清除。
- 有界重试（非阻塞、指数退避、上限）；teardown 时 flush 失败中性记录。
- 绝不因写失败崩溃、绝不自动清 last-known-good。

## Q11. reset

- 入口：菜单/设置 + 显式 CLI（如 `--reset-layout`，与普通启动参数不同名防误触）；reset 需要显式确认（CLI 需 `--confirm` 或交互确认）。
- 动作：删除/归档布局文件（归档到中性命名）→ 重建默认布局（现有 app 按确定性默认序；folder 全清）→ 立即持久化默认。**不删真实 app/图标/catalog**。
- reset 后重启仍是默认；测试仅注入临时目录。
- ADR 决定：保留归档（`*.reset-<stamp>`）而非物理删除——证据保留 + 可恢复；归档文件名中性（含时间戳，不含正文）。

## Q12. 本地敏感字段清单与暴露限制

| 字段类别 | 位置 | 允许暴露 |
|---|---|---|
| app bundle ID / canonical path / URL | 布局文件正文（唯一受控例外） | 绝不进 telemetry/JSONL/stdout/signpost/profile/report/pasteboard/Workflow 报告 |
| AppID 原始 storage | 内存（AppGridUI 内私有） | 绝不公开/Codable 直出 |
| FolderID UUID 原值 | 布局文件（受控投影） | 绝不出进程（除文件）；`redactedDescription` 保持 `<redacted>` |
| folder 标题 | 布局文件（≤64 grapheme） | 绝不进任何诊断输出 |
| 成员列表 / 布局顺序 / 布局正文 | 布局文件 | 绝不复制进诊断或 Workflow 报告 |
| 中性计数器 | telemetry | 允许：write_count/save_failure_count/stale_rejection_count/persist_wall_ms 等 |

PRIVACY_DATA_MAP 追加「布局存储」段（字段类别表 + 唯一受控例外声明 + 备份/第三方边界说明）。测试：§10.8 privacy scan（键白名单/属性表面/类型表面/哨兵缺席 四层冻结模式沿用 1B）。

## Q13. 是否改 AppCatalogCore？为何无更窄方案

**不改（默认冻结）**。原因链条：
1. 持久引用所需的一切（canonical 归一化读取、bundle ID 读取、FolderID 受控投影）都可通过 `AppRecord`/`AppID` 的**既有公开面**在 `AppGridUI/` 内完成——ADR-004 已公开 canonical URL 归一化语义与 `DuplicateResolution`；`FolderID` 的 `init(uuid:)` 已公开。
2. `AppID.storage` 不公开是 ADR-004 安全边界；在 AppGridUI 内做投影适配反而更安全（AppCatalogCore 少一个暴露面）。
3. 若 T-1F-B/E 实现中发现确实无法在 AppGridUI/PagingPrototypeApp 层安全构建投影（例如需要读取 AppID 内部未公开字段），**停止**并记录最小架构冲突证据 → Chief 决策是否派发窄任务（改 AppCatalogCore 仍**不公开 AppID.storage**、不改 revision 所有权、不改扫描行为、加 Reviewer 门）。默认路径不含此任务。

## Q14. 为什么不用 Launchpad/Dock DB、UserDefaults 大 blob、云同步

- **Launchpad/Dock private DB**：私有格式、无公开写入 API、有品牌/复刻与隐私红线（Prompt §13 非目标）；且与「本应用自己的布局」产品语义不符（用户可能想与 Launchpad 不同）。
- **UserDefaults 大 blob**：非事务、无原子替换语义、易被系统/备份截断、不适合结构正文；仅可存路径/开关。
- **云同步**：无账号体系、无网络边界（§4.5 无网络）；同步/协作合并是显式非目标（§13），跨设备一致性超出 1F。

## Q15. 为何不能直接持久化 FolderSnapshot？替代 hashValue 的顺序

- `FolderSnapshot`（1E）表达 folder 集合，**不表达** app/folder 任意交错的顶层全序——用户拖拽产生的顺序真相无法编码；且 `FolderMembership.rebase` 在 catalog 刷新时收缩暂缺成员/解散单成员，直接 Codable 会**把派生投影固化进持久真相**（与 Q9 视觉 dissolve 冲突）。
- `TopLevelComposition` 的派生序（folders 前 + ungrouped 后）是组合规则的结果，非用户意图。
- **hashValue 问题**：`Hashable.hashValue` 进程内随机化（Swift 默认 seeding），跨进程/重启不稳定 → 不能作持久顺序或冲突裁决；ADR-004 的 remap 用 located→successor→… 五级降级是**运行时 remap**，不依赖 hash 值。持久层用**显式 order + 确定性比较**（PersistentAppReference 的 bundle-ID/canonical path 比较键）取代一切 hashValue。
- 因此：布局 = 专用 DTO/envelope + 显式顺序数组 + 独立 validator；`FolderSnapshot` 仅在运行时由 projection 喂入呈现层。

## Q16. title rename 是否真 mutation？

**现状（1E 磁盘事实）**：`AppDelegate.commitFolderTitle(_:)` 目前是**会话内演示**——"提交结果不落盘、不进入任何遥测/日志"；`FolderTitleEditor` 结束编辑即结束，不存在 layout mutation。
**1F 决策**：把 rename 升级为**真实 layout mutation**：
- LayoutDomain 提供 `LayoutMutation.renameFolder(FolderID, to: title, expectedGeneration:)`：标题经 `FolderTitle.normalized`（trim → 空白回退为原标题或中性 fallback → 64-grapheme Character 截断）规范化；成功 → folder 记录更新 + LayoutGeneration++ + 原子 commit + 异步持久化；失败（folder 不存在/stale generation）→ 无副作用。
- 持久化语义：重启后恢复重命名标题（§10.1/§10.4 有重启恢复测试）。
- 编辑结束（Enter/焦点丢失）不再是唯一事件——只有 mutation 成功才写盘；取消/ESC 不产生 mutation。
- 与输入仲裁一致：标题编辑 active 期间不开始 drag（ADR-010 Q7）。

## 后果

- 唯一真相源单一、可校验、可恢复；生成分离防覆盖；hot path 零磁盘；隐私边界（布局文件=唯一受控例外）清晰。
- 成本：双槽 journal + reconcile 复杂度；上限需实验验证（当前为工程建议值，非产品事实）。
- 需 Main 转正；转正前 T-1F-B/E 实现以本草案为准，若有偏差走 Decision Delta。

## 待决 / Open items

1. 工程上限（1 MiB/512/10,000/2,048）需在 T-1F-B 以注入临时目录实测验证并回写 ADR（仍标"工程上限"）。
2. 多实例文件协调具体实现（NSFileCoordinator vs flock）由 T-1F-B 依注入测试可行性定，不改策略语义。
3. ADR-010 相关引用：pasteboard/拖拽身份边界见 ADR-010。

## T-1F-A 实现注记

- 无偏差。草案所有权模型（唯一持久真相 = 顶层 app/folder 任意交错有序条目 + folder 稳定身份/标题/有序成员 + layout generation）、Q2 引用方案（bundle-ID 主 + canonical path 确定性 fallback，大小写不敏感、忽略尾部 "/"、禁 Swift Hasher/displayName/redactedDescription 当身份、绝不读取 AppID.storage）、Q9 视觉 vs 逻辑 dissolve 区分、Q15 显式 order + comparisonKey、Q16 renameFolder 真 mutation（复用 FolderTitle.normalized 64-grapheme 语义）均按草案实现。
- 实现补充（非偏差）：`WorkspaceLayoutValidator` 在 10 不变量之外增加完整性检查 `.folderRecordWithoutEntry`（记录无顶层条目 = 不可达 folder），与 `.folderEntryWithoutRecord` 成对；`LayoutMutationResult.cancelled` 为语义保留位，引擎永不产生（取消路径由调用层映射，零写盘）。
- 编码/落盘层（§10.2 schema v1、LayoutStore adapter）归 T-1F-B；本域 DTO 不自备 Codable。


## Accepted lifecycle correction — 2026-10-13

The user explicitly approved: ordinary Quit asynchronously waits for accepted
workspace enqueue tasks and a bounded flush. Failure or timeout asks Cancel Quit
or Quit Anyway, defaulting to Cancel. This supersedes Q6's historical instruction
to record failure without preventing exit. Resident hide is not process Quit.
Do not perform irreversible launcher/service teardown before this decision.
Only accepted organization mutations are covered; an uncommitted title draft is
cancelled by lifecycle cleanup, not silently treated as accepted persisted data.

Implementation seams: WorkspacePersistenceQueue, WorkspaceQuitCoordinator and
AppDelegate.applicationShouldTerminate. In-flight IO remains owned after timeout;
late completion is epoch/batch gated. Over-limit and stale terminal rejection must
not masquerade as nothingPending. Refer to the rename repair plan and stage
summary for exact test/build/source-review evidence; this ADR is not a GUI or
real-process restart PASS.

Q5's test-storage requirement still applies. The historical current command-line
windowed/catalog-root paths do not by themselves isolate production storage.
Do not use those switches alone for a mutating real GUI test; the explicit
isolated-profile proposal awaits approval before cross-module implementation.
