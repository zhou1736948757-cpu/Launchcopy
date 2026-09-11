# T-1F-BC-compile-repair — LayoutStore/DragSession 已落盘源码编译修复

## 背景
T-1F-B（LayoutStore）与 T-1F-C（DragSession）的 Worker 在完成源码后因上下文耗尽中断，测试文件未写。Main 只读诊断 `swift build -c debug` 发现 2 类编译错误（见下）。本任务只修编译错误，不写测试、不改语义。

## 根因（Main 诊断证据，`swift build -c debug` 输出）
1. `Sources/AppGridUI/LayoutStore/LayoutStoreCodec.swift:210,225,226` — `error: value of type 'AppReferenceDTO' has no member 'comparisonKey'`。`AppReferenceDTO`（:58-66）只有 `caseName: String` 与 `value: String` 两字段；`validateStructure`（:200-228）在 3 处调用 `ref.comparisonKey` / `member.comparisonKey` 做全局唯一性检查，该成员不存在。
2. `Sources/AppGridUI/DragSession/EdgePagingScheduler.swift:39` — `error: return from initializer without initializing all stored properties`。`public init() {}` 未初始化非 Optional 的 `dwellArmed: Bool`（`currentZone`/`lastTurnTime` 为 Optional 自动 nil）。

## 修复规格
1. `LayoutStoreCodec.swift`：为 `AppReferenceDTO` 添加确定性 `comparisonKey` 计算属性（如 `var comparisonKey: String { caseName + ":" + value }`），或等价地把 3 处调用改为显式组合。要求：确定性、区分不同 case/value 组合、不引入新依赖。`validateStructure` 其余逻辑不动。
2. `EdgePagingScheduler.swift`：`public init() { dwellArmed = false }`（或等价显式初始化）。其余逻辑不动。

## 写范围（仅此 2 文件）
- `Sources/AppGridUI/LayoutStore/LayoutStoreCodec.swift`
- `Sources/AppGridUI/DragSession/EdgePagingScheduler.swift`

## 禁止
- 不写任何测试文件（后续任务负责）。
- 不修改任何其他文件：冻结树（PagingCore/AppCatalogCore/MacAppCatalog/AppIconPipeline/PagingTelemetry/PagingUI/Package.swift/AppLaunchController.swift）与 LayoutStore/ 其余 3 文件、DragSession/ 其余 8 文件、LayoutDomain/、Tests/ 一律不动。
- 不读禁止来源（BuhoReverseNotes/LaunchBetter/2026-08-25-buho-launchpad-reverse）；无 git 操作；隐私红线（无 app 名/bundleID/路径入任何输出）。

## 验证（必须全部通过）
1. `swift build -c debug` exit 0（无 error）。
2. `swift test` 全量：期望 837/0（基线 837；本任务不新增测试）。写范围外失败如实报告、不修改。
3. `swift build -c release` exit 0。

## 输出纪律
- 先写 `Workflow/results/T-1F-BC-compile-repair.md`（状态 in progress + 计划），再动手。
- 完成后更新结果文件：改动摘要（文件+行）、验证输出（3 项）、Status: PASS。
- 回复 <250 词，无大代码块。
