# Task Packet: T-worker-d

- **Task ID**: T-worker-d
- **Role**: Worker D (fresh context — 不继承含逆向材料的旧会话上下文)
- **Step**: 3-4 (Prompt §6 Step 3-4)


## Objective

实现最小 AppKit UI、真实触控板输入处理、settle 动画、动画中断、页面承载（live views）、页面内容正确性、Reduce Motion 支持

## Dependencies

- **T-step1**（需要 PHASE1_SPEC、ADR-001、ADR-002、PARAMETER_RATIONALE）
- **T-worker-b**（UI 依赖 PagingCore 的纯逻辑状态机；Core 必须先完成）

## Context

**Fresh Context 要求（Phase 1A 来源纪律）**：
此 Worker 必须使用不继承旧逆向上下文的 fresh context。Worker 只接收：
1. 本 Prompt（PHASE1_PAGING_PROTOTYPE_PROMPT.md）
2. Apple 官方公开文档
3. 新工程中由本阶段独立生成的规格、ADR、源码和测试

Worker **不得接收**：旧会话全文、逆向审计全文、治理文档中的来源审计细节。

**禁止读取的路径（Prompt §1.3）**：
```
/Users/mac/Projects/BuhoReverseNotes/（全部内容）
/Users/mac/Projects/LaunchBetter/Packages/
/Users/mac/Projects/LaunchBetter/LaunchBetterApp/
/Users/mac/Projects/LaunchBetter/Docs/aegis/work/2026-08-25-buho-launchpad-reverse/
```

如果意外接触禁止材料：立即停止实现 → 记录 `PROVENANCE/CONTAMINATION_LOG.md` → 标记 BLOCKED_FOR_REVIEW → 等待主控决定。

## Scope

### Step 3: 最小 AppKit 接入（Prompt §6 Step 3）
- 创建窗口（原生 AppKit，macOS 14+，公开 API）
- 显示中性测试页面（程序生成占位图标/几何图形，中性背景/字体/颜色/圆角/页码）
- 把真实 NSEvent 输入转换成 Core input
- 实现 live page hosting 的最简单路径
- 先确保正确性，再优化

### Step 4: 中断和动画（Prompt §6 Step 4，核心硬门禁）
- 实现 settle 动画
- 实现动画中断（settle 中新手势接管）
- 保证 current visual position 连续
- 处理旧完成事件（stale completion rejection）
- 处理关闭、resize、page count change

### 真实触控板分页输入（Prompt §3.C）
至少处理：
- 手势开始/连续变化/结束/momentum
- 横向主导输入
- 自然滚动方向
- 快速和慢速滑动
- 小位移后释放
- 动画进行中再次开始手势
- 动画进行中反向输入
- 首尾页边界
- 非连续或异常 phase 序列的防御处理
- 不得只依靠鼠标滚轮或合成 CGEvent 宣称真实触控板行为通过

### 连续跟随（Prompt §3.D）
- 手势期间页面连续跟输入，无阶跃
- 首尾页受控边界反馈（边界函数独立设计并参数化）
- 不因达到边界让内部状态失效或累积无限位移

### 页面承载（Prompt §3.H，方案 1: live views）
- 页面由 live AppKit view 层级直接承载
- 手势热路径不同步图标解码/扫描应用目录/数据库访问
- 不每帧重建整个页面 view tree
- 页面 prepare/reuse/snapshot 不显示旧内容
- 页面数量增长时内存和 view 数量有上界策略
- resize 后几何更新不在每帧重复触发布局风暴

### 页面内容正确性（Prompt §3.I）
- 无空白页/重复页/错页/页面索引越界
- 旧占位 item 不出现在新页面
- resize 后页面宽度与当前偏移一致
- page count 变小后 current page 无效处理
- window teardown 后 timer/display callback 不继续运行

### Reduce Motion（Prompt §3.J）
- 检测系统 Reduce Motion 偏好
- 减少或取消大幅位移动画
- 保持页状态正确
- 不因降级路径破坏中断和旧回调失效机制

### 命令行参数（Prompt §10）
- `--paging-lab`：诊断模式
- `--page-count <N>`：页面数量
- `--items-per-page <N>`：每页 item 数
- `--page-hosting live`：live views 模式
- `--reduce-motion-override on|off|system`：Reduce Motion 覆盖
- 无参数时正常打开原型
- 参数错误给出帮助，不崩溃

### 测试页面预设（Prompt §3.B）
- 1 页、2 页、5 页、10 页、20 页压力模式
- 默认每页约 35 item（标记为本项目测试负载选择，非旧产品常量）
- item 数量、页面容量和页面数量必须可配置

## Out of Scope

- 实现 PagingCore 纯逻辑状态机（属于 T-worker-b，Worker D 使用其接口）
- 实现 Telemetry 模块（属于 T-worker-c，Worker D 在 T-step6 中集成使用）
- 修改 Package.swift（报告给 Main 整合）
- 性能实验和 compositor 方案（属于 T-step6）
- 搜索、文件夹、拖拽、Hot Corner、数据库、应用扫描、真实 App 图标

## Expected / Allowed Write Scope

- `Sources/PagingUI/`
- `Sources/PagingPrototypeApp/`
- `Tests/PagingUITests/`


## Forbidden Write Scope

**禁止写入**：
- `Sources/PagingCore/`、`Sources/PagingTelemetry/`
- `Package.swift`
- `Docs/`、`PROVENANCE/`
- 其他 worker 的 test 目录

## Constraints

- UI 使用 PagingCore 的纯逻辑接口，不绕过 Core 状态机
- 状态模型须符合 ADR-001 设计
- 页面承载须符合 ADR-002 方案 1（live views）
- 参数使用 PARAMETER_RATIONALE.md 集中配置
- 参数来源类别禁用 REVERSE_ENGINEERING_COPY / OLD_SOURCE_TRANSLATION / UNKNOWN_ORIGIN
- 不从旧项目搬运视觉 token、字段名、动画曲线或精确参数簇
- 不使用 Buho 或 LaunchBetter 的 Logo/截图/壁纸/图标/文案/视觉 token
- 测试数据不包含真实第三方 App 图标
- 不回滚他人改动
- 不修改 Package.swift
- 命名使用中性项目语言（PagingSurface/PageHost 等）
- 自动化输入可用于回归测试，但物理门必须使用真实触控板

## Acceptance Criteria

### UI 正确性测试（Prompt §7.3）
- [ ] 页面 frame 和 page width 一致
- [ ] resize 后所有页面重新对齐
- [ ] 当前页可访问性描述更新
- [ ] 页面不会同时重叠在错误层级
- [ ] page count 变化后页码合法
- [ ] teardown 后无活跃动画驱动器

### 中断安全硬门禁（Prompt §3.F）
- [ ] settle 动画未结束时新手势可立即接管
- [ ] 接管位置与用户当前看到的位置连续
- [ ] 不跳回旧动画逻辑起点或目标点
- [ ] 旧动画完成事件不覆盖新状态
- [ ] 快速连续正反向操作不出现双重 commit
- [ ] 窗口关闭/resize/pageCount 变化时 transition 安全取消或重新基准化

### 页面内容正确性（Prompt §3.I）
- [ ] 无空白页/重复页/错页/索引越界
- [ ] 旧占位 item 不出现在新页面
- [ ] resize 后页面宽度与当前偏移一致
- [ ] page count 变小后 current page 合法
- [ ] window teardown 后无残留 timer/display callback

### Reduce Motion
- [ ] 检测系统 Reduce Motion 偏好
- [ ] 减少或取消大幅位移动画
- [ ] 保持页状态正确
- [ ] 降级路径不破坏中断和旧回调失效机制

### 命令行参数
- [ ] `--paging-lab`、`--page-count`、`--items-per-page`、`--page-hosting live`、`--reduce-motion-override` 全部可用
- [ ] 无参数时正常打开
- [ ] 参数错误给出帮助，不崩溃

### 视觉中立性
- [ ] 不使用 Buho 或 LaunchBetter 的 Logo/截图/壁纸/图标/文案/视觉 token
- [ ] 使用中性背景/字体/颜色/圆角/页码
- [ ] 使用程序生成占位图标或简单几何图形

## Required Verification

- `swift build` 成功（PagingUI + PagingPrototypeApp target 编译通过）
- `swift test` 全部 UI 正确性测试通过
- `exit_code == 0` 且 `executed_tests > 0`
- App 可启动并显示中性测试页面
- resize 行为正确
- teardown 后无残留 callback

## Reviewer Focus

- UI 是否正确使用 Core 状态机接口（不绕过）
- 中断硬门禁是否全部满足（§3.F 6 条）
- 页面内容正确性是否全部满足（§3.I 7 条）
- 是否有旧项目视觉 token / 字段名 / 动画曲线痕迹
- Reduce Motion 降级路径是否保持中断机制正确
- 命令行参数是否全部可用且错误处理健壮
- 手势热路径是否有同步重资源操作
- teardown 是否确实无残留 callback

## Deliverables

- Sources/PagingUI/ 全部源文件
- Sources/PagingPrototypeApp/ 全部源文件
- Tests/PagingUITests/ 全部测试文件
- Workflow/results/T-worker-d.md（Worker Result）