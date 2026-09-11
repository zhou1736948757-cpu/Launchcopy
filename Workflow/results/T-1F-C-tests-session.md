# T-1F-C-tests-session — DragSessionController 测试编写

Status: PASS

## 产出
- 测试文件：`Tests/AppGridUITests/DragSessionControllerTests.swift`（新建，21 个测试方法）
- 覆盖 8 项测试矩阵：①click vs drag 阈值仲裁（3）②状态机全路径 idle→pressed→dragging→edgeTurnPending→commit→idle（1）③stale source/layout/catalog 拒绝（4）④无活动 session/重复 drop 拒绝（2）⑤second drag 使旧 session 失效（1）⑥统一 cancel 全路径（DragCancelReason 全 case + idle + dwell 武装，3）⑦edge 全序列 enter/dwell/turn/leave + atFirstPage/atLastPage + 过期 timer + stale cancel（5）⑧commit 路径 committed/noOp/rejected（3）
- 全部使用 DragSessionTestSupport 工厂（FakeDragClock / makeDragLayout / ref / rowFrames / topLevelGeometry）；fixture 为中性假数据（bundleID "fixture.*"）
- 未修改任何源码文件；未写 DropResolver/DropIntent/DragMutationEngine/EdgePagingScheduler 的独立测试（属后续任务）

## 验证（项目根目录串行执行）
1. `swift build -c debug` → exit 0（Build complete）
2. `swift test` → Executed 907 tests, with 0 failures (0 unexpected)（基线 886 + 新增 21；无写范围外失败）
3. `swift build -c release` → exit 0（Build complete）

## 备注
- 测试期间发现并锁定源码行为：page 0 左缘 / 末页右缘为边界（atFirstPage/atLastPage，不武装 dwell）；dwell 武装时统一 cancel 先发 .edge(.dwellCancelled)；second drag 新 session 启动清空 lastOutcome。
