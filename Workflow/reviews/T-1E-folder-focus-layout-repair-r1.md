# T-1E-folder-focus-layout-repair — Reviewer r1（独立核验）

- Reviewer: 独立 Reviewer（chef-worker-reviewer-workflow）
- 审查对象: Task A 实现（焦点布局/导航器组合化）
- 审查方式: 只读；从任务包规格独立核验，不信任 Worker 报告
- 日期: 2026-08-30

## 结论

**PASS** — 全部验收标准独立核验通过；无 BLOCKER / MAJOR；2 条 MINOR 观察（非阻塞）。

## 验证清单（对照任务包规格逐项）

### 1. AppGridFocusLayout（Sources/AppGridUI/AppGridFocusLayout.swift）

| 规格项 | 核验结果 | 证据 |
|---|---|---|
| 存储 `entries: [TopLevelEntry]` | ✅ | :23 `public let entries: [TopLevelEntry]`；:26-31 init 保留 snapshot + entries + itemsPerPage |
| 新构建 `build(from:composition:itemsPerPage:)` | ✅ | :34-37 |
| 既有 `build(from:itemsPerPage:)` 保留（records → .app） | ✅ | :40-43 `snapshot.records.map { .app($0) }` |
| `validItemCount` → entries.count | ✅ | :46 |
| `pageCount` → ceil(entries/itemsPerPage) | ✅ | :47 `(validItemCount + itemsPerPage - 1) / itemsPerPage`，空 → 0 |
| 主 API `validEntry(page:slot:) -> TopLevelEntryIdentity?` | ✅ | :61-66 越界/超 itemCount → nil；`entries[index].identity` |
| `validAppID` 兼容助手（.app case → id；folder/占位 → nil） | ✅ | :69-72 `if case .app(let id)? = validEntry(...)` |
| `firstValidIdentity` entryIdentity 基 | ✅ | :84-89 经 validEntry 构造 `entryIdentity:` 身份 |
| `contains` / `position(of:)` 按 entries 搜索 | ✅ | :91-93 / :97-100 `entries.firstIndex` → (page, slot)，含文件夹偏移 |
| `migrate` .folder 分支 | ✅ | :161-170 存在 → `.located`（新位置）；消失 → `.clamped(firstValidIdentity())` |
| `migrate` .app 分支（remap 五级） | ✅ | :139-160 `CatalogPlanner().remap(snapshot:anchor:itemsPerPage:)` 签名匹配（AppCatalogCore.swift:440 返回 `(plan:outcome:)`，:147 解构 `let (_, outcome)`）；AnchorOutcome 五 case 全映射（:150-159） |
| `migrate` nil anchor → clamped 首有效 | ✅ | :135-137 |
| `migrate` 旧 revision 不夺回 | ✅ | :129-131 `identity.catalogRevision >= revision → .unchanged` |
| Equatable 保持 | ✅ | :20 `Equatable, Sendable`（TopLevelEntry Equatable，FolderDomain.swift:143） |

### 2. AppGridFocusNavigator（Sources/AppGridUI/AppGridFocusNavigator.swift）

| 规格项 | 核验结果 | 证据 |
|---|---|---|
| 守卫换 entryIdentity 比对 | ✅ | :33-34 `layout.validEntry(page:slot:) == identity.entryIdentity`（folder 身份不被 validAppID 误拦） |
| makeIdentity 用 entryIdentity 构造 | ✅ | :67-71 `guard let entry = layout.validEntry(...)` → `AppGridFocusIdentity(..., entryIdentity: entry)` |

### 3. 测试（Tests/AppGridUITests/AppGridFocusCompositionTests.swift，10 测试）

| 包 §3 要求 | 覆盖测试 | 结果 |
|---|---|---|
| 组合布局：3 folder + 32 app → pageCount 1、validSlots 0..<35 | testCompositionLayoutPageAndSlots | ✅ |
| validEntry(0,0..2) == .folder；validEntry(0,3) == 未分组首 app | testCompositionLayoutFolderSlots / testCompositionLayoutAppSlots | ✅ |
| validAppID(0,0) == nil（folder 槽位）；validAppID(0,3) == 首 app id | 同上 | ✅ |
| 导航器：folder 身份 ↓ → 同列下一行 .folder；↑/↓/←/→ 均可移动 | testNavigatorMovesFromFolderIdentity | ✅ |
| app 槽位身份 == .app(正确 app) | testNavigatorAppSlotIdentity（slot2 folder ↓ → slot7 == .app(app00)） | ✅ |
| migrate：folder 存在 → .located；消失 → .clamped；app 组合偏移 → .located 正确位置 | testMigrateFolderAnchorLocated / testMigrateFolderAnchorClamped / testMigrateAppAnchorOffsetInComposition | ✅ |
| 既有 AppGridFocusTests / AppGridFocusNavigatorTests 保持通过 | 全套 782 测试 0 失败 | ✅ |

- 组合 fixture 走真实 `TopLevelComposition.build` 路径（FolderDomain.swift:239）；导航器 fixture 直接构造 entries（合法，测导航机制）。
- 测试仅中性标识（AppNN / Group N / fixture.appNN / 确定性 UUID）——无隐私泄漏。

### 4. 写范围合规（mtime 扫描）

- 任务窗口（2026-08-30 21:15–21:16）内仅 3 个允许文件被修改：
  - `Sources/AppGridUI/AppGridFocusLayout.swift` 21:15:33
  - `Sources/AppGridUI/AppGridFocusNavigator.swift` 21:15:36
  - `Tests/AppGridUITests/AppGridFocusCompositionTests.swift` 21:16:07
- 冻结树最新 mtime = `Sources/PagingUI/PagingFrameDriver.swift` 15:15:30（早于任务窗口 6 小时）；`Package.swift` 08-28、`AppLaunchController.swift` 08-28 → 未动。
- 禁止文件：`FolderDomain.swift` 16:12、`AppGridUIPageContentProvider.swift` 16:28、`AppGridFocusModel.swift` 08-29 → 未动。
- `Sources/PagingPrototypeApp/` 最新 = `KeyboardFocusController.swift` 21:06:47（早于本任务窗口 9 分钟，属其他任务）→ 本任务未触碰。
- 注：无法独立复现 Worker 声称的"修改前 50 文件 mtime 记录"，但独立扫描结果与"冻结树未动"结论一致。

### 5. 无 git 操作 / 无隐私泄漏

- ✅ 无 git 操作证据；测试与实现仅中性标识。

## 构建 / 测试结果（独立运行）

| 命令 | 结果 |
|---|---|
| `swift build -c debug` | exit 0，Build complete |
| `swift test` | **Executed 782 tests, with 0 failures (0 unexpected)**，exit 0（真实计数，N=782 > 0；基线 772 + 新增 10） |
| `swift test --filter AppGridFocusCompositionTests` | Executed 10 tests, 0 failures（确认新测试真实执行，非跳过） |
| `swift build -c release` | exit 0，Build complete |

## 发现

### BLOCKER
无。

### MAJOR
无。

### MINOR
1. 导航器守卫 `nil == nil` 边界：`entryIdentity == nil` 且 `validEntry` 返回 nil（无效槽位）时守卫通过（:34）。与旧实现 `validAppID == appID` 的 nil==nil 行为一致，非回归；Worker 结果已显式声明。留给 Task B 关注。
2. `testNavigatorMovesFromFolderIdentity` 的文件夹成员为空（`members: []`），与 `TopLevelComposition.build` 的"空文件夹不贡献条目"规则不一致——但该 fixture 直接构造 entries，仅测导航机制，组合 fixture 已走真实构建路径，不影响有效性。

### QUESTION
无。

## 验收判定

- 组合布局 API 正确（validEntry / validAppID 兼容 / pageCount / position / migrate folder 分支）✅
- 导航器守卫 + makeIdentity 用 entryIdentity；folder 身份可导航 ✅
- 全部测试通过（含既有 app-only 测试）；双构建 exit 0；冻结树未动 ✅

**Verdict: PASS**
