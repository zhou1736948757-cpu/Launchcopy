# VALIDATION_PLAN.md — Phase 1A 验证计划

- **日期**：2026-08-28（T-step1，Main）
- **依据**：Prompt §7（自动化）、§8（物理验收矩阵）、§13（状态分类）、§16（最终汇报）

## 1. 自动化测试范围（Prompt §7）

### 1.1 Core 单元测试（Tests/PagingCoreTests，Prompt §7.1）

至少覆盖：

- page count = 0、1、2、多页
- current page 首、中、尾
- 小位移回弹
- 达到翻页条件
- 高速度 + 小位移
- 低速度 + 大位移
- 首页向前越界
- 末页向后越界
- transition 中断
- 连续两次反向中断
- 旧 completion 晚到
- page count 在 tracking 时减少
- page count 在 settling 时减少
- resize / page width 变化
- cancel
- teardown
- Reduce Motion

### 1.2 可重复事件序列测试（Prompt §7.2）

结构化输入序列（不依赖旧项目），每条验证：最终页、视觉偏移、transition 状态、commit 次数、stale callback 数量：

```text
begin → changes → end
begin → changes → end → momentum
settling → begin opposite direction
settling → resize
settling → pageCount reduction
tracking → window close
```

### 1.3 UI 正确性测试（Tests/PagingUITests，Prompt §7.3）

- 页面 frame 与 page width 一致
- resize 后所有页面重新对齐
- 当前页可访问性描述更新
- 页面不重叠在错误层级
- page count 变化后页码合法
- teardown 后无活跃动画驱动器

### 1.4 性能测试边界（Prompt §7.4）

自动化性能测试**只作回归预警，不能替代真实触控板**。自动化可测：

- 纯 Core 处理开销
- 单帧 update 的 CPU 时间
- 页面 view 数量
- layout 调用次数
- 预热与缓存
- 长序列内存增长
- stale completion 是否为零提交

## 2. 真实触控板物理验收矩阵（Prompt §8，T-step8 执行，等待用户）

### 2.1 环境证据（每组正式测试前记录，11 项）

```text
Mac 型号 / macOS 版本 / 显示器 / 分辨率与缩放 / 实际刷新率 /
触控板类型 / Reduce Motion 状态 / Debug 或 Release / commit/hash /
是否接电 / 是否有明显后台负载
```

### 2.2 页面矩阵

```text
1 页 / 2 页 / 5 页 / 10 页 / 20 页压力模式
```

### 2.3 手势矩阵（每个关键配置至少测试）

```text
1. 慢速拖动后回弹        7. 连续快速来回
2. 慢速拖动后翻页        8. 首页向外拉
3. 快速甩动              9. 末页向外拉
4. 小幅快速输入         10. 滑动时 resize
5. settle 中同向接管    11. 滑动时关闭窗口
6. settle 中反向接管    12. Reduce Motion
```

### 2.4 正确性硬门（出现任何一项即不能 PASS）

```text
跳回旧位置 / 一次手势 commit 多次 / 旧 completion 改写新页 /
空白、重复或错页 / 越界 / resize 后错位 / 关闭后仍有 callback /
崩溃 / telemetry 无法对应 gesture 和 transition / 删除异常 run 美化结论
```

### 2.5 初始性能目标（工程初始目标，非法律/平台保证）

**60Hz**
- 正式 run 无无法解释的 >50ms 主线程 hitch
- 手势热路径无同步重资源加载
- frame miss 比例 ≤ 1%（建议初始目标）
- 中断时无可见跳变
- 主观"跟手、连续、settle"三项中位数均 ≥ 4/5

**120Hz**（只有能证明实际 120Hz 才执行与标记）
- 不使用 60Hz 结果推断 120Hz
- 不使用 synthetic probe
- frame miss ≤ 2%（建议初始目标）
- 无无法解释的 >33ms hitch
- 主观三项中位数均 ≥ 4/5
- 无 120Hz 设备或无法证明刷新率 → `MANUAL_PHYSICAL_GATE_120HZ = BLOCKED`（不写 PASS）

### 2.6 主观评分（每个正式 run 保存原始分与备注，保留异常/低分 run）

```text
跟手性：1–5 / 中断连续性：1–5 / settle 自然度：1–5 / 边界反馈：1–5 / 总体丝滑度：1–5 / 备注
```

## 3. 状态分类（Prompt §13，VALIDATION_RESULTS.md 分开记录）

```text
BUILD_DEBUG
BUILD_RELEASE
AUTOMATED_TESTS
CODE_REVIEWED
SOURCE_REVIEWED
VISUAL_NEUTRALITY_REVIEWED
MANUAL_PHYSICAL_GATE_60HZ
MANUAL_PHYSICAL_GATE_120HZ
```

未执行写 `NOT_RUN` 或 `BLOCKED`，不能写 PASS。另保留自动化/代码审查/物理门三类验证的边界说明（Prompt §16.C 诚实边界）。

## 4. 执行顺序

1. T-worker-b/c/d：各模块单元/UI 测试（自动化）
2. T-step6：性能 baseline 与优化实验（自动化，回归预警）
3. T-step7：清洁构建（Debug + Release）+ 全量测试 + 来源扫描 + `git diff --check`，产出 VALIDATION_RESULTS.md 初始状态
4. T-reviewer：独立只读审查（CODE_REVIEWED / SOURCE_REVIEWED / VISUAL_NEUTRALITY_REVIEWED）
5. T-step8：生成物理验收手工步骤与环境证据模板，**等待用户**在真实 GUI + 触控板执行（60Hz；120Hz 视设备）

## 5. 变更记录

| 日期 | 变更 | 执行人 |
|---|---|---|
| 2026-08-28 | 创建 v1.0 | Main（T-step1） |
