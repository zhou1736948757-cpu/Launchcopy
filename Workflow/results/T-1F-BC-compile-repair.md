# T-1F-BC-compile-repair — 结果

## Status: PASS

## 计划
1. 读任务包与 2 个目标文件。
2. `LayoutStoreCodec.swift`：给 `AppReferenceDTO` 加确定性 `comparisonKey` 计算属性；3 处调用不改；`validateStructure` 其余逻辑不动。
3. `EdgePagingScheduler.swift`：`public init() {}` 改为显式初始化 `dwellArmed = false`。
4. 验证：debug build → 全量 test → release build。
5. 更新本文件。

## 改动摘要（仅 2 文件，写范围合规）
- `Sources/AppGridUI/LayoutStore/LayoutStoreCodec.swift:63` — `AppReferenceDTO` 新增计算属性 `var comparisonKey: String { caseName + ":" + value }`（确定性、区分不同 case/value 组合、无新依赖；caseName 白名单无 ":"，首冒号切分唯一 → 注入式无碰撞）。3 处调用（现 :213/:228/:229，原 :210/:225/:226）与 `validateStructure` 其余逻辑未动。
- `Sources/AppGridUI/DragSession/EdgePagingScheduler.swift:39-41` — `public init() { dwellArmed = false }`（显式初始化非 Optional `dwellArmed`；`currentZone`/`lastTurnTime` 为 Optional 自动 nil）。其余逻辑未动。

## 验证输出（3 项全过）
1. `swift build -c debug` → `Build complete!`，EXIT:0（无 error）。
2. `swift test` 全量 → `Executed 837 tests, with 0 failures (0 unexpected)`，EXIT:0（基线 837/0 保持；本任务未新增测试）。
3. `swift build -c release` → `Build complete!`，EXIT:0。

## 备注
- 未写任何测试文件；未改其他文件（LayoutStore/ 其余 3 文件、DragSession/ 其余 8 文件、LayoutDomain/、Tests/、冻结树均未触碰）；无 git 操作；无隐私红线输出。
- 域类型 `PersistentAppReference.comparisonKey`（LayoutDomain，冻结）用 `bundle:`/`path:` 前缀，与 DTO 键格式不同但分层独立、互不混用，不影响正确性。
