# T-worker-b-catalogcore — AppCatalogCore 完整实现（Phase 1B Wave 1）

**Worker**: worker-catalogcore（deepseek-v4-flash:0731, max）
**日期**: 2026-08-28
**Scope**: `Sources/AppCatalogCore/AppCatalogCore.swift`、`Tests/AppCatalogCoreTests/`（占位已替换）、`Workflow/results/T-worker-b-catalogcore.md`
**Forbidden 遵守**: 未触碰 Package.swift / PagingCore / PagingTelemetry / PagingUI / MacAppCatalog / AppIconPipeline / AppGridUI / PagingPrototypeApp / Docs / PROVENANCE / Workflow（结果文件除外）；未读取 §2.2 任何禁止来源
**AccessDeclaration: NO_PRIOR_EXPOSURE**（本 worker 全程仅读取 wave1-interfaces.md §B、PHASE1B_REAL_APP_CONTENT_PROMPT.md、PagingPrototype 自身源码；无 PRIOR_EXPOSURE）

## 实现要点（签名保持 wave1-interfaces.md §B 冻结；WORKER 标记全部补全）

1. **`CatalogBuilder.build`**：canonical URL 去重（规则 1）→ bundleID 去重（规则 3 policy）→ 稳定排序 → 校验。
   - canonical URL 去重胜者：sourceRootPriority 最小 → displayName 升序 → 输入顺序（最后手段，仅完全同键重复）；**与输入顺序无关**（测试证明 reversed 输入同输出）。
   - `.rootPriorityFirst`：保留 root 优先级更高者（sourceRootPriority 更小）；同优先级 → canonical path 字典序升序。deterministic。
   - `.keepMultiInstance`：全部保留（稳定多实例，AppID 相同、canonicalURL 区分）。
   - 排序：displayName 主序（`locale ?? .current` + caseInsensitive 选项）→ canonicalURL 升序 tie-break（去重后 URL 全局唯一 → 严格全序 → 与 Swift `sorted` 稳定性无关）。
   - `validate`：无重复 canonical URL（对象身份）+ 严格递增有序；**解读**（ADR-004 待 Main 确认）：AppID 可在 keepMultiInstance 快照中重复（同一 app 稳定多实例），故身份判重收敛到 canonical URL；公开 `validate` 以默认 ordering 校验，自定义 ordering 的快照由 `build` 内部以同一 ordering 校验。
   - 新增 `CatalogValidationError`（throws 所需；非 §B 签名偏差，仅补全 throws 的错误类型）。
2. **`CatalogPlanner`**：
   - `plan`：itemsPerPage > 0（precondition 契约）；`pageCount = itemCount == 0 ? 0 : ceil(itemCount/itemsPerPage)`（35=1 页、36=2 页、0=0 页）。
   - `PagePlan.appID(page:slot:)`：越界/空 → nil；planner 构造的 plan 经内部 records 索引（§B 未冻结 PagePlan init 细节，公开 4 参 init 保留、内部 init 携带 records——公开 API 形状不变）。
   - `remap` 五级降级：emptyCatalog → located（新快照页）→ successor → predecessor → clamped(page 0)；**结构性杜绝旧数组 index**（签名不含旧快照，结果完全由新 snapshot + anchor 推导；测试 testRemapUsesNewIndexNotOldIndex 证明旧 index 3/2=1 ≠ 实际 located(0)）。
   - 消失锚点的后继/前驱：锚点 AppID 不透明（无 displayName），以 **AppID 身份全序**（bundleID 键 < fallback 键，同类字符串升序；`AppID.anchorOrderLessThan`，fileprivate 扩展，不改变公共 API）近似"稳定排序中的后继/前驱"——确定性实现，代码注释已说明近似语义。
   - `pageIndex(of:in:itemsPerPage:)`、`anchorCandidate(nearPage:...)`（= committed page 首个可见 AppID）。
3. **`CatalogDiffBuilder.diff`**：前置 `to.revision > from.revision`（否则 `CatalogGateError.nonMonotonic`）；`added`（to 顺序）、`removed`（from 顺序）、`moved` = 索引在 from→to 间变化的全部 AppID（新增/移除/重排/位移；to 顺序 + from-only 补尾）——统一"索引变化"语义，注释说明。
4. **`SnapshotGate`**：严格递增；拒绝不改变内部状态（拒绝后可继续接受更新 revision）。
5. **`CatalogFixture`**：保持 §B 签名；`tempURL` 收敛到进程级唯一子目录（并行测试命名隔离）。

## 测试（Tests/AppCatalogCoreTests/，占位 Placeholder.swift 已删除；6 文件 33 tests）

| 文件 | 覆盖（§10.2） |
|---|---|
| `AppIDIdentityTests`（6） | bundleID 主身份 / 无 ID → canonicalURL fallback（含 ./. 规范化）/ displayName 不参与身份 / redactedDescription 不含 bundleID 与路径原文 / IconIdentity 派生 |
| `CatalogBuilderTests`（19） | 相同 canonical URL 去重（含输入顺序无关）/ rootPriorityFirst（root 优先级 + canonical path 字典序 tie）/ keepMultiInstance 双实例 / nil bundleID 不冲突 / caseInsensitive（en_US；注：en_US_POSIX C-locale 不折叠大小写，已注释）/ caseSensitive 字面序 / locale 注入（de_DE ä<z vs sv_SE z<ä 反转）/ tieBreaker URL 升序 / 同 displayName 双记录保留 / 稳定排序重复执行 / 输入顺序无关 / 空快照 / validate 通过（默认构建/空/单条）与拒绝（重复 canonical URL、逆序、tie 逆序） |
| `CatalogPlannerTests`（18） | pageCount 0/1/35/36/70/71 / appID(page:slot:) 全边界（含负、超页、超 slot、超 itemCount）/ 空 plan 恒 nil / remap located / **新 index 非旧 index** / successor（锚点移除）/ predecessor（无后继）/ predecessor 跨页 / nil anchor → clamped(0) / 空 catalog → emptyCatalog / pageCount shrink（38→36→35→20 条；锚点保留 → located、锚点消失 → 前驱）/ pageIndex / anchorCandidate（0/1 页、越界、空）/ anchorCandidate→remap 闭环 |
| `CatalogDiffAndGateTests`（9） | add / remove（含位移项进 moved）/ reorder（de_DE vs sv_SE ordering 变更）/ combined / 同内容不同 revision 空 diff / 非单调拒绝（== 与 <）/ gate 严格递增（含 zero）/ stale 与相等拒绝（状态不变）/ 拒绝后可继续 |
| `CatalogPropertyTests`（4） | 固定种子 LCG 随机属性：25 轮 × 200 条内无重复 page slot、无越界、无遗漏 / 重复构建 deterministic / reversed 输入同输出 / remap 一致性（存在锚点 → located 且 == pageIndex；幽灵锚点 → successor/predecessor/clamped） |

**合计 56 个测试方法**（6+19+18+9+4）。

## 测试期望修正记录（实现零改动；初跑 6 失败全部为测试期望错误）

1. `en_US_POSIX`（ICU C-locale）不折叠大小写："apple" vs "Banana" caseInsensitive 得 descending（'a' 0x61 > 'B' 0x42）→ caseInsensitive 测试改用 `en_US`（实测 -1）。
2. ICU en_US_POSIX 非字节序（ä<z）→ locale 反转对照改用 `sv_SE`（瑞典语 ä 排 z 后；实测 z<ä）。
3. `records(36)` 实际含 app000..app035（无 app37，off-by-one）；且未填充 id 字符串序 "app37" < "app4"（'3'<'4'）→ 后继搜索命中 app4 → 测试记录 id 零填充为 `app%03d`（字符串序 == 数值序），shrink 测试按真实语义重写（锚点保留 → located；消失 → 前驱）。

## Verification

| 命令 | 结果 |
|---|---|
| `swift build --target AppCatalogCore`（项目内） | exit 0 |
| `swift test --filter AppCatalogCoreTests`（**项目内**，终态复验） | **56 tests, 0 failures，exit 0** |
| `swift build`（全量，项目内） | exit 0 |
| `swift test`（隔离 scratch harness `/tmp/acc-scratch`，仅 AppCatalogCore + 同一份测试源） | 56 tests, 0 failures，exit 0（早于项目内复验，见下） |

**并行冲突说明（§12 纪律，未触碰他人文件）**：20:49–20:55 期间 MacAppCatalog / AppIconPipeline worker 正在写入各自源码，全包测试构建一度被 `Sources/AppIconPipeline/IconPipeline.swift` 的 in-flight 编译错误阻塞（该 worker 自己的文件，后续已修复）。期间我以 `/tmp/acc-scratch` 隔离 harness（复制同一份实现 + 同一份测试源，本地 target）先行验证全绿；worker 稳定后项目内 `swift test --filter AppCatalogCoreTests` 复验同样 **56/0，exit 0**。全量 `swift test` 由 Main 于 Wave 1 收口时执行（任务约定）。

## Changed Files

- `Sources/AppCatalogCore/AppCatalogCore.swift`（WORKER 标记全部补全；新增 CatalogValidationError + AppID 全序扩展 + PagePlan 内部 records 索引）
- `Tests/AppCatalogCoreTests/`（删除 Placeholder.swift；新增 TestSupport.swift + 5 个测试文件）
- `Workflow/results/T-worker-b-catalogcore.md`
