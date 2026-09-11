# FOUR_FINGER_REFERENCE_AUDIT — LaunchBetter 四指手势参考审计

> 读取日期：2026-09-05（Asia/Shanghai）
> 依据：Phase 1G Prompt §17 用户授权白名单（有限例外，仅读下列文件）
> 角色接触声明：Main 直接读取（`REFERENCE_EXPOSED`）；未读取 BuhoReverseNotes / 2026-08-25-buho-launchpad-reverse / 任何逆向资料
> 性质：源码阅读证据，**不是运行结论**。本轮未做后台触控板验证、权限验证或能耗采样。

## 1. 已读文件清单（白名单内）

| 文件（相对 /Users/mac/Projects/LaunchBetter） | 行数 | 读取日期 | 用途 |
|---|---|---|---|
| `Packages/LaunchPlatform/Sources/LaunchPlatform/PinchAnalyzer.swift` | 107 | 2026-09-05 | 有效触点计数、质心平均半径、收缩/扩张识别 |
| `Packages/LaunchPlatform/Sources/LaunchPlatform/MultitouchSupport.swift` | 205 | 2026-09-05 | 动态加载、C 回调、设备订阅、owner 管理 |
| `Packages/LaunchPlatform/Sources/LaunchPlatform/GestureCaptureEngine.swift` | 300 | 2026-09-05 | start/stop/restart、状态通知、回调到离散事件 |
| `LaunchBetterApp/ActivationCoordinator.swift` | 195 | 2026-09-05 | onGesture 到主线程窗口入口的接线 |

测试文件（PinchAnalyzerTests.swift / GestureEngineLifecycleTests.swift）仅定位未读取内容，不当作已执行证据。

## 2. 逐文件审计

### 2.1 PinchAnalyzer.swift（纯逻辑分析器）

**代码事实**：
- `ContactSample`：`normalized: CGPoint`（0.0-1.0 左上原点）+ `isOnSurface: Bool`（L5-15）。
- `GestureEvent`：`.pinchIn` / `.pinchOut`（L18-21）。
- 参数默认值：`requiredFingerCount=4`、`threshold=0.18`、`cooldown=0.2s`（L38-46）；**判定用 `>=`**（L56），实际接受四指及以上（§17.2 事实 1 确认）。
- 算法（L61-101）：质心 → 平均欧氏距离 → 首帧建立 `startDistance` → `magnitude = (meanDistance - start) / start`；`> +threshold` → pinchOut，`< -threshold` → pinchIn；触发后 `startDistance = meanDistance` 更新（§17.2 事实 2/3 确认）。
- 冷却（L85-87）：`now.timeIntervalSince(lastEmittedAt) < cooldown` 时返回 nil；**冷却结束后持续手势可再次触发**（§17.2 事实 4 确认）。
- `gestureActive` 字段（L34）声明但从未读写（死代码）。
- `reset()`（L103-106）只清 `gestureActive`/`startDistance`，**不清 `lastEmittedAt`**。

**注释 vs 事实**：L25 注释"参数(§91 旧版经验, 需实测复核)"——参数来源标注为旧版经验，非本机实测。

**推断**：无接触结束（全部离面）的显式信号——`guard onSurface.count >= requiredFingerCount else { reset() }` 用"手指不足"隐式重置，无独立 end 事件。

**时钟**：`now: Date`（墙钟），`timeIntervalSince` 差值可受系统时间修改影响（§17.2 事实 10 确认）。

### 2.2 MultitouchSupport.swift（私有框架窄包装）

**代码事实**：
- dlopen 路径：`/System/Library/PrivateFrameworks/MultitouchSupport.framework/MultitouchSupport`，`RTLD_LAZY`（L120-125）。
- 符号（L127-141）：`MTDeviceCreateList`、`MTRegisterContactFrameCallback`、`MTUnregisterContactFrameCallback`、`MTDeviceStart`、`MTDeviceStop`；任一缺失 → dlclose + nil（优雅不可用）。
- `MTTouch` 结构布局（L20-36）：frame/timestamp/identifier/state/fingerID/handID/normalized/size/zero1/angle/majorAxis/minorAxis/absolute/zero2/density——**注释明示"与 legacy 验证可用布局完全对齐"**（L18-19，来源为 legacy 本机验证，非 Apple 文档）。
- 回调签名（L49-50）：`@convention(c) (MTDeviceRef, UnsafeMutableRawPointer, Int32, Double, Int32) -> Int32`。
- 回调体（L70-95）：`guard count > 0`；锁内取盒快照、锁外调用闭包；`state != 0` 解释为活跃（L82 注释"与 legacy 一致"）；**不保留 device 参数给下游**（L70 回调首参 `_` 丢弃）。
- 全局单盒 `contactCallbackBox` + `contactCallbackOwner`（L65-67）：owner token 防旧 wrapper 清新 box（L200-202）。
- startDevices（L160-184）：锁内注册全部设备 + `deviceStart(device, 0)`；stopDevices（L188-204）：锁内 `deviceStop` + `unregisterCallback`，owner 匹配才清 box。
- deinit `dlclose(handle)`（L154-156）。

**注释 vs 事实**：L5"与 legacy 验证可用布局完全对齐"、L24"state = 0 未触摸, 非0 = 活跃"、L99"函数签名与 legacy 本机验证可用实现逐行对齐"——**ABI 布局与状态语义均来自 legacy 验证，非 Apple 公开文档**（§17.2 事实 7 确认）。

**推断**：`state != 0` 无条件当作活跃，未区分 hover/开始/结束/取消分类。

### 2.3 GestureCaptureEngine.swift（生命周期与回调引擎）

**代码事实**：
- `Status`：`.unavailable` / `.running` / `.waitingForPermission`（L17-21）。
- 单一 `NSLock` 保护全部可变状态（L23）；start/stop/restart 整段持锁（L74-136、L138-154、L257-276），注册/注销设备亦在锁内（消除交错窗口）。
- `running` 标志：stop 先置 false，迟到回调直接丢弃（L167-170）。
- `receive()`（L163-225）：锁内更新最新帧 + **就地分析**（PinchAnalyzer 纯计算，注释称微秒级）；`GESTURE_DEBUG` 环境变量输出 frames/sec + analysis us/frame（L202-212）；锁外派发事件（L214-224）。
- 权限检测（L122-130、L242-254）：启动后 3s 单次 DispatchSourceTimer，无回调且设备枚举 0 → `.waitingForPermission`；**不做周期轮询**。
- `restart()`（L257-276）：stop → generation 校验（`lifecycleGeneration == gen`）→ start（意图竞态防护）。
- 回调频率注释：125-250Hz 系统线程（L156）。
- 三指拖动识别器（ThreeFingerDragRecognizer）与诊断计数（L186-199、L227-240）——**本轮不采纳**（新需求只做四指捏合）。

**注释 vs 事实**：L9"输入监控权限缺失: 回调不到达 → 启动后无回调超时检测"——权限缺失的表现是"无回调"，非错误返回；L33"设备是否成功枚举(>0 = 授权已生效, 回调只在触摸时到达, 不能据此判断权限)"——**设备枚举成功不能单独证明权限已授予**（§18.2 确认）。

**推断**：`pendingSamples` 只保留最新一帧（L31、L172-177）——**丢弃 begin/end/cancel 语义**，重新武装条件依赖"手指不足 → reset"隐式路径。

### 2.4 ActivationCoordinator.swift（窗口接线）

**代码事实**：
- `pinchIn → windowController.show()`；`pinchOut → windowController.hide()`（L144-149）——**新需求仅采纳前者**（§17.2 事实 8 确认）。
- 权限弹窗（L166-180）：NSAlert + `x-apple.systempreferences:com.apple.preference.security?Privacy_ListenEvent`（Input Monitoring 设置页）；非交互 flag（--smoke 等 20 个）不弹窗（L21-32）。
- 热键（L35-50）：`RegisterEventHotKey` 风格 keyCode + modifiers 位掩码（cmd=256/shift=512/opt=2048/ctrl=4096）。
- HotCornerMonitor（L52-69）：`NSEvent.mouseLocation` + `NSScreen.frame` 几何判定，24pt 阈值（L82-87）。
- 旧版冲突检查（L182-189）：`com.Eric-Yang.Launchpad-Back` bundle ID 探测。

**推断**：`handleCornerAction` 直接调 windowController.show/hide/toggle（L92-99）——无统一 coordinator 仲裁（新需求要求单一 coordinator）。

## 3. 提取的行为规格（拟重新设计）

1. 四指捏合 = 有效触点（isOnSurface）计数 ≥ 4 时，平均半径相对基线收缩超过阈值 → 一次 pinchIn。
2. 基线 = 手势起始帧的平均半径；触发后基线更新。
3. 冷却期抑制重复触发（但非"一次接触会话只触发一次"）。
4. 手指不足 → 重置基线。
5. 事件为离散请求，与 UI/Store 解耦；回调在系统线程，主线程只收离散事件。

## 4. 明确拒绝沿用的部分

| 项 | 理由 |
|---|---|
| `>= 4` 判定（接受五指） | 新需求 §16.1 严格四个有效接触点；实机证明不合理才经决策修改 |
| pinchOut → hide | 新需求 §16.1 向外张开不触发呼出，本轮不实现张开关闭 |
| 墙钟 `Date` 计时 | §19.3 要求单调时钟 |
| 冷却 = 重新武装条件 | §19.2 要求"全部离面/可靠接触结束才可重新武装"，冷却只是附加保护 |
| 只留最新帧（丢 begin/end/cancel） | §20.1/§20.2 要求保留 begin/end/cancel，零触点帧不可吞 |
| `state != 0` 无条件活跃 | §20.1 要求核实 hover/开始/结束/取消分类 |
| 三指拖动识别 | 新需求 §16.2 不扩张 |
| 权限弹窗自动跳系统设置 | §18.2 未经同意不申请、不自动打开系统设置 |
| 旧版冲突 bundle ID 探测 | 记录前台 app 身份，违反 §4.3 隐私红线 |

## 5. 风险清单

### 5.1 私有 ABI
- `MTTouch` 布局与函数签名**无 Apple 公开文档**，来源为 legacy 本机验证（注释自述）；系统更新可能改变布局 → 崩溃或误读。
- dlopen/dlsym 符号缺失可优雅失败，但**布局错误无法在注册前检测**。
- 需记录系统版本与架构（macOS 26.5.2 arm64），跨版本不保证。

### 5.2 触点状态
- `state != 0` 未区分 hover/开始/结束/取消；零触点帧被 `count > 0` 直接丢弃（L71）→ 重新武装条件依赖隐式"手指不足"。
- 无接触结束显式事件 → 需保守且可验证的恢复策略（§19.2 第 12 条）。

### 5.3 设备混流
- 回调首参 device 被丢弃（L70）→ 无法区分设备；两设备各两指可能被合并为四指（§20.1 要求保留设备区分）。
- 热插拔/重枚举无处理逻辑（参考实现无此能力）。

### 5.4 锁序与生命周期
- 全局单盒 + owner token 方案可行，但 `deinit` 中 `dlclose`（L154-156）与回调线程并发 → 需验证 dlclose 后迟到回调行为。
- 回调在锁内读快照、锁外派发——正确；但 `receive` 就地分析在回调线程执行，积压策略未定义（§20.2 要求记录）。
- `start/start`、`stop/stop`、`start-stop-start` 重入语义需新实现独立测试（参考实现有 `guard multitouch == nil` 幂等，但无重入测试证据）。

### 5.5 权限
- 参考实现依赖 Input Monitoring 权限（弹窗跳 Privacy_ListenEvent）；**新需求 §18.2 要求独立说明用途、实测依据、拒绝后的功能降级**；未经同意不申请。
- 设备枚举成功 ≠ 权限已授予（参考实现注释亦承认）。

## 6. 来源与权利依据

- 代码所在目录由用户持有并明确指定为参考（Prompt §17）；**不等于每段代码来源和使用权已验证**。
- 参考实现注释自述"与 legacy 验证可用布局对齐"——legacy 来源未在本轮核实，不宣称 clean-room。
- 本轮**不直接复用任何参考代码**；全部行为规格重新实现。若未来拟直接移植（如 MTTouch 布局），先提交移植范围与权利依据，经 Main/Chief 批准。

## 7. 未核实事项

- 未做本机后台触控板验证（采集实验需用户确认风险清单后运行，§18.2 路线 B）。
- 未验证 Input Monitoring 权限实际行为。
- 未验证私有 ABI 在当前系统（macOS 26.5.2）的实际可用性。
- 未做能耗采样。
- Apple 在线资料本轮未取得可用正文（§17.2 末段确认），不宣称已完成官方 API/分发政策核验。

## 8. 复核记录（T-G-P0 Worker，2026-09-05）

> 复核人：T-G-P0 Worker（deepseek-v4-flash:0731，fresh context）
> 复核方式：仅对照 Prompt §17.3 要求逐项检查本文档；**未重读 LaunchBetter 源码**（审计由 Main 2026-09-05 完成，白名单 4 文件）
> 结论：**基本完整**；补 3 项缺口（§8.2），无内容性错误。

### 8.1 §17.3 逐项覆盖清单

| §17.3 要求 | 覆盖位置 | 状态 |
|---|---|---|
| 文件、行号、内容摘要、读取日期 | §1 清单表（4 文件 + 行数 + 日期 + 用途）；§2 逐文件审计（行号齐全） | ✅ |
| 只摘必要短段，不复制整份参考源代码 | 全文仅行号 + 短摘，无整文件复制 | ✅ |
| 代码事实 vs 注释 vs 推断 | §2 每文件分「代码事实」「注释 vs 事实」「推断」小节 | ✅ |
| 哪些经本机验证 | 头部性质声明 + §7 未核实事项；**本轮零项本机验证**（§8.2 补 1 显式化） | ⚠️ 已补 |
| 来源标注及未核实的权利依据 | §6（用户持有目录 ≠ 权利已验证；legacy 对齐注释未核实；不宣称 clean-room） | ✅ |
| 提取出的行为规格 | §3（5 条，拟重新设计） | ✅ |
| 准备重新设计的部分 | §3 标题「拟重新设计」+ §6「全部行为规格重新实现」 | ✅ |
| 明确拒绝沿用的部分 | §4（10 项拒绝表，逐项给理由） | ✅ |
| 私有 ABI / 触点状态 / 零触点事件 / 设备混流 / 锁序风险清单 | §5.1–5.4（5.2 含零触点帧；5.4 含锁序与生命周期） | ✅ |
| 拟直接复用代码：先提交范围与依据 | §6 末条（MTTouch 布局等直接移植须先经 Main/Chief 批准） | ✅ |
| 测试文件处理 | §1 末行：仅定位未读取，不当作已执行证据（对齐 §17.1） | ✅ |

### 8.2 补缺（本轮追加）

1. **「经本机验证」显式声明**：本轮**零项**经本机验证——全部「代码事实」来自源码阅读；「与 legacy 验证可用布局完全对齐」等注释属**未核实声明**（legacy 来源未核实），不是本机验证结论。任何后续采集实验（用户确认风险清单后）产出的验证结果须回填本文档并标注日期。
2. **LaunchBetter AGENTS.md 读取状态**：§17.1 允许读取参考库 AGENTS.md 以遵守只读边界；本轮**未读取**（Main 仅读白名单 4 文件，无边界歧义）。
3. **复核元数据**：本复核由 T-G-P0 Worker 于 2026-09-05 执行，未重读 LaunchBetter 源码；本文档与 `Docs/ADR-013-FOUR-FINGER-ACTIVATION-BACKEND.md`、`Docs/FOUR_FINGER_RISK_REGISTER.md`、`PROVENANCE/REFERENCE_EXPOSED.md` 配套使用。
