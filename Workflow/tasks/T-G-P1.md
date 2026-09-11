# T-G-P1 — 独立四指识别器（纯值状态机）

## Objective
实现纯逻辑四指捏合识别器（不依赖真实采集后端）：
- 状态：Disabled/Idle/Candidate/Recognizing/Fired/WaitingForRelease/Suspended（可合并，保留 §19.2 十二条可测语义）
- 可注入单调时钟（不用墙钟 Date 差值）
- 严格四个有效触点（不是 >=4）；落指不同步需短稳定窗口建基线；归一化收缩量阈值/稳定窗口/时间上限/噪声容忍分别命名
- 四指平移/旋转/抖动不误触；五指进入/触点替换/设备改变/数据过期取消或重建候选
- 触发后锁存 Fired，同一接触会话只发一次；全指释放才 re-arm；四变三再变四不绕过锁存
- 缺帧/乱序/NaN/Infinity/近零半径/非法计数安全拒绝
- Suspend/stop/disable/restart 清基线/会话/待派发意图
- 设备标识=进程内不透明 token，不写盘
- 测试覆盖 Prompt §23.1 P01-P20（纯逻辑部分；P09 两设备各两指不组合、P10 零触点/取消/断开/过期、P11 NaN/边界、P12 乱序/时间回退/过载、P13 late callback 丢弃、P14 start/stop 重入、P15 同步重入假后端无死锁、P17 pinchOut 无 Hide、P19 输入交接不误翻页）

## Expected / Allowed Write Scope
- 新文件 `Sources/PagingPrototypeApp/`（PinchRecognizer.swift 等，纯 Foundation）
- 新测试 `Tests/PagingUITests/`（PinchRecognizerTests.swift 等，合成匿名触点夹具）
- 禁止：provider/后端、窗口代码、AppDelegate、冻结树、Package.swift、真实触控板轨迹提交

## 验收
- P01-P20 纯逻辑部分全部 executed > 0 且 0 failures
- 测试断言"不该触发"（负样本），不只 happy path
- 无 AppKit import；无真实设备访问
- 不 commit/push/tag
