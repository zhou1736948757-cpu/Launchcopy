# T-1D-layout-centering-repair — 搜索后内容面板水平居中丢失修复

**Objective:** 修复搜索输入后内容面板被挤到窗口左侧、右侧大片空白的缺陷——搜索 commit 后(尤其 pageCount 变化时)内容容器必须保持水平居中。

**Evidence (user, real GUI):** 用户在真实全屏窗口搜索输入 `z` 后截图:整个内容面板挤到窗口左侧,右侧大片空白;网格可见且只剩搜索匹配的图标;顶栏 "Page 1 of 1" + 搜索框正常(截图 sha256:316aa9bb02ad4fcca3462a5cf4822f905e673f20f0030ad53d73e6528581c658;vision 确认: content 偏左、right 大空白、仅 1 个图标可见)。搜索匹配本身正确(输入 z → 1 个结果 ZCode)。

**Suspected area (worker must investigate, not assume):**
- `Sources/PagingUI/PagingSurface.swift` 同 revision 重载路径:`applySameRevisionReload()` → `core.setPageCount` + `relayoutPages()` + `refreshLiveHostContent`;pageCount 4→1(或任意变化)后内容容器 frame/居中是否被破坏。
- `Sources/AppGridUI/AppGridUIPageContentProvider.swift` servedPageCount/presentationRecords 变化后视图容器宽度/居中逻辑。
- 顶栏 layout / contentView 宿主容器是否与搜索 field overlay 冲突。
- 对比:清空搜索(回到全目录)布局是否恢复居中;无搜索时全目录居中正常(Phase 1C 用户确认过 4 页网格正常)。

**Required fix criteria:**
1. 搜索输入(0/1/多结果)后内容面板仍水平居中(与全目录一致)。
2. 清空搜索恢复全目录时布局也必须居中。
3. 不得破坏搜索匹配、键盘导航、空白单击、启动路径。
4. 新测试:至少 1 个断言同 revision 重载 + pageCount 变化后内容容器保持水平居中(可断言容器 frame 中心 == 窗口/宿主中心,或等价 invariants);既有 620 tests 全量不得 regress。

**Write scope (allowed):**
- `Sources/PagingUI/PagingSurface.swift`
- `Sources/AppGridUI/`(presentation 相关)
- `Sources/PagingPrototypeApp/AppDelegate.swift` / `AppCatalogAssembly.swift`(仅若确为接线问题,最小改动)
- `Tests/PagingUITests/`、`Tests/AppGridUITests/`(新测试)
- `Workflow/results/T-1D-layout-centering-repair.md`

**Forbidden write scope:** `Sources/PagingCore/`、`Sources/MacAppCatalog/`、`Package.swift`、`Sources/PagingPrototypeApp/AppLaunchController.swift`(冻结/禁止树,永不修改)。

**Constraints / red lines:**
- 不读禁止来源(BuhoReverseNotes/LaunchBetter/2026-08-25-buho-launchpad-reverse)。
- 隐私:搜索 query/结果名绝不入 telemetry/log;无 schema 变更。
- 不 commit/push/tag/reset/clean;不全局 NSEvent monitor、不 Accessibility、不同步 I/O。
- Timer tolerance 8.333ms 不动;三诊断 token 保留;不宣称修 hitch。

**Verification (worker must run all):**
```sh
swift test --filter <new tests>
swift test                 # 全量 >= 620/0,新增测试计入
swift build -c debug
swift build -c release
```
Gate: exit_code == 0 AND executed_tests > 0(非 INVALID_TEST_EXECUTION);禁止树 mtime/hash 未变。

**Result contract:** 写 `Workflow/results/T-1D-layout-centering-repair.md`(根因分析 + 改动文件/行 + 测试清单 + 测试计数 + 禁止树核验)。

**Dependencies:** T-1D-E(搜索集成已 PASSED)。
