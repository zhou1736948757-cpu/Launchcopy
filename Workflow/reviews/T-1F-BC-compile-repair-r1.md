# T-1F-BC-compile-repair — Review r1

## Status: PASS

## 核验点（已确认）

### 1. 改动正确性 — LayoutStoreCodec.swift
- `AppReferenceDTO`（:58-69）新增计算属性 `var comparisonKey: String { caseName + ":" + value }`（:63），确定性、区分不同 case/value 组合、无新依赖。caseName 白名单（`isValidAppRef` :235-242 仅 `bundleID`/`pathFallback`，均无 ":"）→ 键注入式无碰撞。
- 3 处调用全部使用该属性：:213（顶层 ref 全局唯一）、:228（folder 成员内唯一）、:229（成员全局唯一）。原 :210/:225/:226 → 现 :213/:228/:229，行号 +3 与插入 3 行（注释+属性+空行）一致。
- `validateStructure` 其余逻辑未动（结构、白名单、UUID、FolderID 唯一、app/folder 恰好一个均原样）。

### 2. 改动正确性 — EdgePagingScheduler.swift
- `public init() { dwellArmed = false }`（:39-41）：显式初始化非 Optional `dwellArmed: Bool`；`currentZone`/`lastTurnTime` 为 Optional 自动 nil。与根因 :39 一致，其余逻辑未动。

### 3. 写范围合规（mtime 窗口取证，2026-08-31 05:00+）
- Sources/Tests 中仅 2 目标文件被改（均 05:15）：LayoutStoreCodec.swift、EdgePagingScheduler.swift。
- 未新增/修改任何测试文件（Tests/ 最新 mtime 03:14，早于修复窗口）。
- LayoutStore/ 其余 3 文件（≤03:14）、DragSession/ 其余 8 文件（≤02:47）、LayoutDomain/（≤00:47）未动。
- 冻结树未动：PagingCore ≤08-30 11:46、AppCatalogCore ≤08-28、MacAppCatalog ≤08-28、AppIconPipeline ≤08-29、PagingTelemetry ≤08-28、PagingUI ≤08-30 15:15、Package.swift 08-28 20:42、AppLaunchController.swift 08-28 21:46。
- 窗口内非源码改动仅 Workflow/ 工件（tasks/results/STATE/events/heartbeats/watchdog），属工作流正常产物。
- 仓库无已跟踪文件（全 untracked），git 无法提供 diff 基线；mtime 取证为独立证据。

### 4. MINOR 备注核验
- 属实：`PersistentAppReference.comparisonKey`（LayoutDomain :34-39，冻结）用 `"bundle:" + id` / `"path:" + path` 前缀，与 DTO 键（`bundleID:`/`pathFallback:` + ":" + value）格式不同；分层独立（域类型 vs codec DTO），互不混用，不影响正确性。

## 验证输出（3 项全过，串行执行）
1. `swift build -c debug` → `Build complete!`，EXIT:0（无 error）。
2. `swift test` 全量 → `Executed 837 tests, with 0 failures (0 unexpected)`，EXIT:0（基线 837/0 保持；非 0-executed 无效执行）。注：末尾 `Test run with 0 tests` 为 Swift Testing 空运行，XCTest 套件实际执行 837 项。
3. `swift build -c release` → `Build complete!`，EXIT:0。

## 裁决
**PASS** — 改动正确、写范围合规、3 项验证全过、冻结树未动；MINOR 备注属实（无阻塞项）。
