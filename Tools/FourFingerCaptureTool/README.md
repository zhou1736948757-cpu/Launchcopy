# FourFingerCaptureTool — 四指采集实验工具（T-G-P6 交付物 2）

Phase 1G 真实 MultitouchSupport 采集实验工具。用户已确认风险清单
`Docs/FOUR_FINGER_RISK_REGISTER.md`（R-01..R-07，2026-09-05）后运行。

## 用途（实验目标）

- 验证私有 MultitouchSupport ABI（R-01）：符号存在性、MTTouch 布局、回调签名
- 核实触点状态分类（R-02）：记录 phase 枚举分布（began/moved/ended/cancelled）
- 核实设备枚举与回调频率（参考实现注释预期 125-250Hz）
- 采集 slow-pinch / fast-pinch / spread / negative 四类手势样本供分析

## 构建（独立脚本，不动 Package.swift）

```bash
Tools/FourFingerCaptureTool/build.sh
# 产物：/tmp/fourfinger-capture-tool
```

## 运行

```bash
/tmp/fourfinger-capture-tool
```

交互：

1. 输入场景名（`slow-pinch` / `fast-pinch` / `spread` / `negative`）开始一段采集；
2. 做手势；实时打印每帧触点计数与状态枚举（中性：不打印坐标原始值）；
3. 按 Enter 结束当前段（打印该场景统计摘要）；
4. 输入下一个场景名继续；`quit` 或 Ctrl-C 整体停止。

## 数据义务（重要）

- 匿名帧记录（含 normalized 坐标）仅保存在内存，实验结束后写入
  `/tmp/fourfinger-capture-<时间戳>.jsonl`（临时文件）。
- **仅实验用途；实验完成后必须删除该文件**（删除义务）。
- 实时输出与统计摘要只含计数与状态枚举，不打印坐标原始值。

## 输出统计

每场景：帧数、触点计数分布、会话数（began→ended/cancelled/零触点 moved 闭合序列）、
began/moved/ended/cancelled 帧数。

## 实现说明

- 复用 app 纯逻辑源文件（`PinchRecognizer.swift` / `TouchProvider.swift` /
  `MultitouchSupportBackend.swift` / `FourFingerCaptureStats.swift`）编译为独立可执行，
  不修改 `Package.swift`（Main 独占）。
- 后端默认 `.asynchronous` 交付（串行派发队列），与生产路径一致。
