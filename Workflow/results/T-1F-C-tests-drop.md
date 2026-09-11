# T-1F-C-tests-drop — DropResolver/DropIntent/DragMutationEngine 测试编写

Status: PASS

## 产出
- 测试文件：`Tests/AppGridUITests/DragDropTests.swift`（新建，仅此 1 文件；未改任何源码/既有测试/冻结树）
- 测试数：39（全绿；基线 907 + 39 = 946）
- 工厂使用：makeDragLayout / ref / rowFrames / appFrame / folderFrame / topLevelGeometry / folderGeometry / assertContains（FakeDragClock 属 controller 时序测试，drop 组件无时钟依赖，未用）

## 覆盖矩阵（39 测试）
1. **consume 接受**（2）：顶层 insertion accept + consumed=true；folder scope insertion accept（folder 成员数边界分支）
2. **consume 拒绝**（7）：错误 token → .invalidToken；二次消费 → .tokenConsumed；layout generation 过期 → .staleLayout；catalog 过期 → .staleCatalog；source 不在布局 → .sourceMissing；target 缺失（insertion 越界 / createFolder 未知目标 / intoFolder 未知 folder）→ .targetMissing；.invalid intent → 见"发现"①
3. **zones 构造**（4）：insertion 带首/中/末三区几何精确断言（margin 8pt）；app 中心区（中间 1/3 strip，80/3）；folder cell 区（itemFrames + topLevelFrames 两来源）；moveOutArmed=false 无顶层落点 / true 有（几何同构断言）
4. **classify 分类**（10）：app 源他 app 中心 → .createFolder；源自身中心 → 非 createFolder（.invalid）；insertion 带 → .insertion(index)；app 源 folder cell → .intoFolder(.tail)；folder 源落 folder cell / app 中心 → .invalid；folder 源 insertion 带 → .insertion；成员源顶层落点（armed）→ .topLevelTarget(index)；成员源 folder cell → .intoFolder；成员源 app 中心 → .invalid；成员源未 armed → inner .insertion
5. **engine 5 类 mutation**（9）：M1 顶层 app 重排 / M2 顶层 folder 重排（记录不变）/ M3 createFolder（新 folder 落 min 原 index、成员先目标后源、标题 "Group 1"）/ M4 顶层 app 移入 + 跨 folder 原子 move（源剩 1 → dissolve 归并同一次提交）/ M5 move-out 三态（剩 1 dissolve / 剩 0 删 folder / 剩 ≥2 保留）/ folder 内重排——每类验证新布局正确、generation +1
6. **engine 拒绝**（7）：.invalid → .invalidTarget；createFolder 非顶层源 / 目标==源 / 未知目标 / 源已在 folder（nestedFolder）；intoFolder folder 源 / 未知 folder / 未知 app；topLevelTarget 非成员源 / 未知 folder / 成员不存在；insertion 未知身份——全部 .rejected、原布局不变、无半提交

## 验证输出（项目根目录串行执行）
1. `swift build -c debug` → Build complete!，exit 0
2. `swift test` → Executed 946 tests, with 0 failures (0 unexpected)，exit 0（DragDropTests 单独过滤：Executed 39 tests, with 0 failures）
3. `swift build -c release` → Build complete!，exit 0

## 发现：源码缺陷（未修复，超出写范围，如实报告）
① `DropResolver.consume` 中 `.invalidDropTarget` 分支**不可达**：`targetStillValid(.invalid)` 恒返回 false，故 `.invalid` intent 先命中 `guard targetStillValid` → `.reject(.targetMissing)`。测试按实际行为断言 `.targetMissing` 并注释说明；建议后续任务调整校验顺序（如先查 intent != .invalid）或删除死分支。
② `DragMutationEngine.apply` 恒以 `layout.generation` 作为 `LayoutMutation(expectedGeneration:)`，故 `staleGeneration` 拒绝在引擎入口**结构上不可达**（stale 防护由 DropResolver 层覆盖，见矩阵 2）。测试注释说明，未强行构造。
