# T-1E-folderlab-membercount-repair — Reviewer r1

- 角色：Reviewer（chef-worker-reviewer-workflow；READ-ONLY，未编辑任何实现文件）
- 日期：2026-08-30
- 审查对象：Worker 结果 `Workflow/results/T-1E-folderlab-membercount-repair.md`
- 结论：**PASS**

## 独立验证（不依赖 Worker 自述）

### 1. 生产接线可达性 — 通过

- `AppDelegate.installFolderWiring`（AppDelegate.swift:418）由 `installContentAssembly`（:407-408）调用，
  后者在 `applicationDidFinishLaunching`（:133）非 `--neutral-content` 时执行 → 生产路径可达。
- 接线（AppDelegate.swift:429-431）：
  `assembly.renderer.folderSnapshotProvider = { [weak assembly] in assembly?.provider.servedFolderSnapshot }`
  — **弱捕获**，无引用环。
- 渲染器透传（AppCatalogAssembly.swift）：
  - `didSet`（:161-167）透传到全部既有页实例；
  - `render()`（:228）每次选页后 `page.folderSnapshotProvider = folderSnapshotProvider`（含池化复用页）。
- 同一 snapshot 源：`assembly.provider.servedFolderSnapshot` 即组合渲染所用源
  （`rebuildFolderCompositionIfNeeded` → `provider.receiveFolderSnapshot` → `servedFolderSnapshot`），
  FolderID 一致。`AppGridPageView.swift:131` 消费 `folderSnapshotProvider?()?.entry(for: folderID)?.members.count ?? 0`。

### 2. 回归测试 — 通过

- `testFolderCellMemberCountWiredFromServedSnapshot`（FolderIntegrationTests.swift:102-144）复刻生产接线
  （renderer.folderSnapshotProvider → assembly.provider.servedFolderSnapshot，弱捕获），
  经 FakeAppFactory 假 .app 临时目录 + folder lab 组合提交后渲染含 folder 条目的一页，
  断言 `cell.memberCountText == "\(expectedCount) items"`（expectedCount ≥ 2，非 0）。
- 未扫描真实 /Applications（roots = factory.root，loader = RecordingIconLoader）。
- Package.swift 未改（mtime 2026-08-28 20:42 未动）。

### 3. 全量测试 + 构建 — 通过（本人实跑）

- `swift test`：**758 tests, 0 failures, exit 0**（≥757 达标；新增 1 测试）。
- 新测试单独运行 `--filter FolderIntegrationTests/testFolderCellMemberCountWiredFromServedSnapshot`：passed。
- `swift build -c debug`：exit 0。
- `swift build -c release`：exit 0。

### 4. 冻结树未动 — 通过

- `find` 冻结树（PagingCore/AppCatalogCore/MacAppCatalog/AppIconPipeline/PagingTelemetry/PagingUI）
  在 2026-08-30 17:00 后无任何文件被改（修复窗口 ~17:12）。
- Package.swift（08-28 20:42）、AppLaunchController.swift（08-28 21:46）未动。
- 仅 3 文件改动：AppDelegate.swift / AppCatalogAssembly.swift / FolderIntegrationTests.swift（均 17:12-17:13）。

### 5. 无 git / 隐私 / 参数不变 — 通过

- git：`No commits yet`，仅 untracked —— 无提交操作。
- 隐私：修改文件无 folder 标题/成员/身份原值或图标数据写入 telemetry/JSONL/stdout/signpost/profile/report；
  测试用假 temp URL，不触碰真实 /Applications。
- Timer tolerance / paging 参数 / frame source：修改文件中的相关引用均为既有代码，修复未改动。

## 发现分类

- **BLOCKER**：无。
- **MAJOR**：无。
- **MINOR**：无。
- **QUESTION**：写集仅列 AppDelegate.swift + 测试 + 结果文件；Worker 额外修改了
  `AppCatalogAssembly.swift`（非冻结树）。已核实为**合理且必要**的偏差：`AppGridPageView` 由
  `AppGridRenderer` 工厂按页创建，`folderSnapshotProvider` 必须在渲染器层透传才能到达每页实例；
  改动最小且镜像既有 `onIconApplyResult` 透传模式（didSet + render 时重设）。不构成失败项。

## 结论

修复正确、最小、可复现：生产接线可达、弱捕获无环、与组合同一 snapshot 源、回归测试真实断言非零成员数、
全量 758 测试 0 失败、debug/release 构建 exit 0、冻结树与隐私红线未动。偏差（AppCatalogAssembly.swift）
已核实合理。

VERDICT: PASS
