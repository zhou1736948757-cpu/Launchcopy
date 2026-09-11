# Phase 1C Prompt — 键盘焦点、键盘导航与键盘启动

> 创建日期：2026-08-29（Asia/Tokyo）  
> 项目：`PagingPrototype`  
> 项目路径：`/Users/mac/Projects/Launch_Copy/PagingPrototype/`  
> 目标：在 Phase 1B 的真实应用内容基础上，补齐一层**本地窗口内的键盘交互能力**。  
> 本 Prompt 是下一阶段的开发输入，不是根因诊断报告，也不是最终产品验收报告。

---

## 0. 给执行模型的最重要说明

请先谨慎阅读项目现状，再决定实现方式。用户提供的判断和本 Prompt 的判断都可能不完整；不得为了“完成阶段”而把假设写成事实。

本阶段的目标不是继续追踪上一轮帧卡顿根因，也不是宣称卡顿已修复。当前诊断状态必须原样保留：

```text
CAUSALITY_UNRESOLVED
PARTIAL_CONTRIBUTOR_SUPPORTED
PRODUCT_DEFAULT_UNCHANGED
```

上一阶段已经发现：

- `advanceFrame` 和 JSON 记账通常不是大头；
- 某些真实触控板 `20–25ms` 区间存在 RunLoop `exit → entry` 约 10ms 的部分贡献；
- 该机制不是全部卡顿的根因；
- System Trace 会改变/放大表现，不能用它把 scheduler、WindowServer、AppKit、Core Animation 或 GPU 定性；
- 没有修复前后的物理 ABBA，因此不能写 `FIX_VALIDATED` 或 `ALL_HITCHES_FIXED`。

**Phase 1C 不得修改生产默认值 `Timer tolerance = 8.333ms`，不得为了键盘功能顺便“修复”分页动画或帧源。**

---

## 1. 背景与当前基线

项目是一个独立实现的 macOS AppKit 分页原型：

- Phase 1A：分页状态机、连续拖动、settle、中断接管、边界反馈、页面复用；
- Phase 1B：受限应用枚举、不可变 catalog snapshot、异步系统图标管道、真实应用网格、应用单击启动、刷新与 stale 防线；
- 默认帧源：`RunLoopFrameDriver`，约 60Hz Timer，非 vsync 对齐；
- 部署目标：macOS 14+；
- Swift Package；
- `Sources/PagingCore/` 是纯逻辑分页核心，当前冻结；
- Phase 1B 已有单击 cell 启动能力；键盘焦点和键盘启动被明确延后；
- 最新诊断收口报告记录过 Swift 462 tests / 0 failures、Python 40 tests / 0 failures、Release build PASS，但执行时必须以当前工作树实际复验结果为准，不可盲信历史数字。

优先阅读：

```text
/Users/mac/Projects/Launch_Copy/PagingPrototype/AGENTS.md
/Users/mac/Projects/Launch_Copy/PagingPrototype/Workflow/STATE.json
/Users/mac/Projects/Launch_Copy/PagingPrototype/Workflow/MAIN_BRIEF.md
/Users/mac/Projects/Launch_Copy/PagingPrototype/Docs/PHASE1B_REPORT.md
/Users/mac/Projects/Launch_Copy/PagingPrototype/Docs/PHASE1B_SPEC.md
/Users/mac/Projects/Launch_Copy/PagingPrototype/Docs/VALIDATION_RESULTS.md
/Users/mac/Projects/Launch_Copy/PagingPrototype/Docs/FRAME_HITCH_ROOT_CAUSE_CORRELATION_RESULTS.md
/Users/mac/Projects/Launch_Copy/PagingPrototype/Docs/FRAME_HITCH_ROOT_CAUSE_CORRELATION_CHECKPOINT.md
/Users/mac/Projects/Launch_Copy/PagingPrototype/Docs/ADR-001-PAGING-STATE-MODEL.md
/Users/mac/Projects/Launch_Copy/PagingPrototype/Docs/ADR-002-PAGE-HOSTING.md
/Users/mac/Projects/Launch_Copy/PagingPrototype/Docs/ADR-003-PAGING-CONTENT-PROVIDER.md
/Users/mac/Projects/Launch_Copy/PagingPrototype/Docs/ADR-004-APP-CATALOG-SNAPSHOT.md
/Users/mac/Projects/Launch_Copy/PagingPrototype/Docs/ADR-005-ICON-PIPELINE.md
```

重点代码位置：

```text
/Users/mac/Projects/Launch_Copy/PagingPrototype/Sources/AppGridUI/AppGridCellView.swift
/Users/mac/Projects/Launch_Copy/PagingPrototype/Sources/AppGridUI/AppGridPageView.swift
/Users/mac/Projects/Launch_Copy/PagingPrototype/Sources/AppGridUI/AppGridUIPageContentProvider.swift
/Users/mac/Projects/Launch_Copy/PagingPrototype/Sources/PagingUI/PagingSurface.swift
/Users/mac/Projects/Launch_Copy/PagingPrototype/Sources/PagingUI/PageHostView.swift
/Users/mac/Projects/Launch_Copy/PagingPrototype/Sources/PagingPrototypeApp/AppLaunchController.swift
/Users/mac/Projects/Launch_Copy/PagingPrototype/Sources/PagingPrototypeApp/AppDelegate.swift
```

---

## 2. 本阶段目标

补齐以下能力：

1. 窗口获得键盘焦点后，有明确、可测试、可访问的焦点模型；
2. 用户可以用方向键在当前应用网格中移动焦点；
3. 焦点移动不会绕过 `PagingCore` 的状态所有权，也不会破坏正在进行的触控板手势或 settle；
4. 必要时，键盘导航可以安全地切换到相邻页面，并把焦点放到确定的目标 cell；
5. 用户可以对当前聚焦的 cell 使用 Return/Enter 触发应用启动；
6. 键盘启动必须复用已有 `AppLaunchController` 的 revision、AppID、文件存在性和失败非致命校验，不得复制一套绕过 stale 防线的启动逻辑；
7. 刷新、异步图标写回、页面复用、页面数量变化、窗口 resize、teardown 后，焦点不能指向不存在或过期的 cell；
8. 键盘交互不引入全局监听、辅助功能权限、同步磁盘 I/O、同步图标读取或每次按键重建整棵 view tree；
9. 现有触控板分页体验、PagingCore 不变量、隐私红线和现有自动化测试不得回归。

本阶段**不要求**：

- 搜索、拼音搜索；
- 文件夹/分组；
- 拖拽重排或跨页移动；
- Hot Corner、全局手势、全局 NSEvent monitor；
- Launchpad/Dock 私有库访问；
- LaunchBetter 品牌/视觉系统接入；
- 120Hz 物理验收；
- vsync 帧源切换；
- icon cache telemetry 字段启用；
- 帧卡顿根因修复；
- 安装、签名、公证、发布；
- activation/license bypass。

以上事项如果被认为是键盘功能的必要依赖，不要自行扩大范围，先记录为 `BLOCKED` 或提出最小变更建议。

---

## 3. 建议的产品交互语义（先核对，再实现）

以下是一个可执行的初始方案，但不是不可质疑的事实。执行模型必须先检查现有 view 层、分页 seam 和测试能力；若发现该方案与当前架构冲突，应记录理由并选择最小替代方案。

### 3.1 焦点身份

焦点不要只保存一个裸数组下标。建议至少包含：

```text
catalogRevision
pageIndex
slotIndex
AppID（或当前项目已有的稳定身份类型）
surfaceGeneration / presentation identity（按实际架构选择）
```

焦点必须能够回答：

- 当前聚焦的是哪一页、哪一个有效 item；
- 它属于哪个 snapshot revision；
- 页面刷新或复用后，当前焦点是否仍然有效；
- 如果 item 消失，如何确定性地迁移到 successor / predecessor / clamped / empty。

不得把旧 page index 当作跨 snapshot 的稳定身份。

### 3.2 初始焦点

需要明确并记录一个确定性策略。推荐：

- 当前 snapshot 有有效 item 时，初始聚焦当前页第一个有效 cell；
- 空 catalog 不产生虚假焦点；
- 用户刚从某个 cell 失焦后重新获得焦点，若该 AppID 仍存在则优先恢复该 AppID，否则按当前页的 successor / predecessor / first-valid 策略迁移；
- 不因为图标还没加载完成而阻塞焦点，名称和稳定身份即可决定焦点。

如果实现选择不同策略，必须在 Phase 1C 文档中写清楚原因和可验证规则。

### 3.3 方向键

推荐的基础语义：

- `←` / `→`：在当前网格行内移动；到达边界时，按文档化策略切换相邻页；
- `↑` / `↓`：在同一列尽量移动到上一/下一行；目标行不存在时采用确定性 clamp，不越界；
- 不能把固定 `5×7` 当成不可变事实；应从当前网格布局、`itemsPerPage` 和有效 item 数推导行列与末页边界；
- 空 slot、placeholder、状态页、loading 页不可被当作可启动 app；
- 相邻页切换必须使用现有 PagingUI/PagingCore 的合法入口，不能直接篡改 `visualOffset`、`committedPage` 或私有状态。

需要特别审查“方向键跨页”的实现方式：如果现有 PagingCore 没有直接的 programmatic page API，优先增加一个**窄的 UI 适配 seam**或通过已有公开行为入口表达键盘翻页，不得修改 `Sources/PagingCore/` 以迁就键盘。

### 3.4 Return/Enter

- Return 和 keypad Enter 是否都支持，需以 AppKit 事件语义实际验证；
- 只有当前有有效焦点、当前 binding token/revision 仍有效时才可启动；
- 调用已有 `AppLaunchController` 的统一入口或提取出的共享入口；
- 不允许键盘路径直接从 cell 读取 URL 后调用 `NSWorkspace`，以免绕过 stale 校验；
- 启动失败必须仍是非致命、中性结果；
- 不记录 app 名称、bundle ID、路径、URL 或用户输入到 telemetry。

### 3.5 Escape、Tab 和其他按键

不要未经证据或产品决策扩大语义。至少要：

- 明确 `Escape` 是取消焦点、取消当前键盘操作、关闭窗口，还是本阶段不处理；
- 明确 `Tab` 是否交给 AppKit responder chain；
- 明确 `Space`、Home/End、PageUp/PageDown 是否属于本阶段；
- 对未支持的按键保持原有 AppKit 行为，不吞掉事件。

推荐 Phase 1C 先完成方向键 + Return/Enter + 明确记录 Escape/Tab 策略，其余按键延后，避免无边界扩展。

---

## 4. 技术约束

### 4.1 PagingCore 冻结

严格禁止修改：

```text
/Users/mac/Projects/Launch_Copy/PagingPrototype/Sources/PagingCore/
```

以下内容保持不变，除非先停止并报告计划级冲突：

- committed page 语义；
- visual offset 所有权；
- transition token / stale rejection；
- 中断接管；
- 当前 Phase 1B 固化参数；
- Reduce Motion 行为；
- teardown 语义。

键盘层应放在 `AppGridUI`、`PagingUI` 的窄 seam 或 `PagingPrototypeApp` 装配层。不要把 AppKit、catalog、启动、焦点或资源依赖塞进 Core。

### 4.2 AppKit responder 设计

优先采用本地 responder chain：

- 只让必要的表面或 cell/焦点代理成为 first responder；
- 正确实现 `acceptsFirstResponder`、`becomeFirstResponder`、必要的 `keyDown` / `performKeyEquivalent`；
- 不使用全局 event monitor；
- 不请求 Accessibility 权限；
- 不依赖系统全局快捷键才能完成窗口内导航；
- 鼠标/触控板输入继续走已有 `PagingSurface` 路径；
- 键盘事件处理不得进行同步扫描、同步 I/O、同步图标获取或昂贵的全量 layout。

如果选择“单一键盘代理”而不是让每个 cell 成为 responder，必须确保辅助功能焦点、视觉焦点和实际启动对象仍保持一致。

### 4.3 焦点与异步/刷新一致性

至少覆盖这些时序：

1. 图标尚未加载时移动焦点；
2. 图标异步回调与键盘移动交错；
3. 键盘切页动画进行中再次按方向键；
4. 触控板手势进行中按方向键；
5. catalog refresh 在 idle、tracking、settling、interrupted 四种状态发生；
6. 当前焦点 App 被扫描结果移除；
7. pageCount 缩小；
8. cell/page 被复用；
9. 窗口 resize；
10. teardown 后仍有旧事件或旧异步回调抵达。

焦点视觉状态不能因为 cell 复用而残留在错误的 app 上。焦点变更的 token/identity 必须和当前 presentation 一致；旧 revision 不得重新夺回焦点。

### 4.4 性能和卡顿诊断边界

本阶段可以保留并继续输出已有诊断字段，但不得新增会改变热路径的重型探针作为“修复”。

任何性能判断必须区分：

```text
自动化/SELFDRIVE
真实触控板
60Hz/120Hz 硬件
未受工具干扰/受工具干扰
功能正确性/物理手感/根因因果
```

如果键盘层改变了帧统计，必须报告“新增键盘路径的影响”，不能声称解决既有触控板卡顿。除非另有独立批准，本阶段不做 Timer tolerance AB 或 System Trace 诊断。

---

## 5. 来源、独立实现与隐私纪律

这是一个独立工程。可以实现相同的用户可观察能力，但必须自己设计状态模型、接口和代码。不得：

- 读取、引用或复制禁止来源树；
- 逐行翻译任何反编译代码；
- 复制第三方图标、图片、文案、品牌、Logo 或视觉组合；
- 在源码、测试、文档、字符串、构建产物中引入 Buho/LaunchBetter 身份性内容；
- 以改名或换变量名冒充独立实现。

允许使用：

- Apple SDK 和公开 AppKit/Foundation/NSWorkspace 文档；
- 本项目自身现有代码和测试；
- 需求驱动的键盘焦点状态模型；
- 中性占位和运行时系统图标。

隐私红线继续冻结，不得记录或输出：

```text
app 名
bundle ID
应用路径
URL
搜索词
图标二进制/图标数据
窗口标题
用户输入内容
原始 RunLoop mode
```

RunLoop mode 如必须出现在已有诊断输出中，只允许匿名枚举：

```text
default | eventTracking | modalPanel | other | none
```

---

## 6. 推荐实现拆分（写入范围互不冲突）

如果启用 Main/Chief/Worker/Reviewer 工作流，请按项目 `AGENTS.md` 操作。下面只是建议的互斥拆分，不能绕过当前 workflow 的 Chief 决策和状态记录。

### Worker A — 焦点 domain / 导航策略

建议写入：

```text
Sources/AppGridUI/*Focus*.swift
Sources/AppGridUI/*Keyboard*.swift（若为纯导航策略）
Tests/AppGridUITests/*Focus*.swift
Tests/AppGridUITests/*Keyboard*.swift
Docs/ADR-006-KEYBOARD-FOCUS.md（或由 Main 整合）
```

职责：焦点身份、网格导航、边界/末页策略、snapshot revision 迁移、纯逻辑测试。

### Worker B — AppKit responder / 页面表面接线

建议写入：

```text
Sources/PagingUI/Keyboard*.swift
Sources/PagingPrototypeApp/*Keyboard*.swift
Tests/PagingUITests/*Keyboard*.swift
```

职责：本地 responder chain、first responder、keyDown 分发、与现有 PagingSurface 的合法 seam 对接。

### Worker C — 键盘启动适配与集成

建议写入：

```text
Sources/PagingPrototypeApp/AppLaunchController.swift（只有明确分配后）
Sources/PagingPrototypeApp/*KeyboardLaunch*.swift
Tests/PagingUITests/*Launch*.swift
Docs/PHASE1C_VALIDATION_PLAN.md（由 Main 最终整合）
```

职责：Return/Enter 统一调用现有 launch validation；不重复实现启动校验；集成测试。

### Reviewer

Reviewer 只读，不修改实现文件；独立检查：

- 实际 diff 与任务边界；
- Core 是否冻结；
- 键盘路径是否绕过 stale 校验；
- 是否误用全局监听/权限/同步 I/O；
- refresh/reuse/teardown 时焦点是否安全；
- 隐私和 provenance；
- 测试是否真的执行且数量可信。

如果并发写入不能稳定隔离，宁可串行并记录原因，不要制造 merge 冲突。

---

## 7. 测试要求

至少新增并执行以下测试；测试名可以不同，但覆盖的语义不能缺失。

### 7.1 纯逻辑焦点测试

- 空 catalog 无焦点；
- 首次聚焦策略确定性；
- 左/右/上/下在 5 列及非 5 列配置下正确；
- 最后一页不完整网格不越界；
- placeholder/空 slot 不可启动；
- 边缘跨页策略正确；
- pageCount=0/1/多页；
- catalog revision 更新后保留同一 AppID；
- 焦点 App 消失后的 successor/predecessor/clamped/empty 迁移；
- 旧 index 不会在新 snapshot 中错误复用；
- 重复方向键、快速方向键序列可预测；
- Reduce Motion 下键盘切页状态仍正确。

### 7.2 AppKit / responder 测试

- surface 或键盘代理可成为 first responder；
- 未聚焦窗口不响应不该响应的键；
- 支持的按键被处理，未支持按键不被错误吞掉；
- 触控板 scrollWheel 路径未回归；
- keyboard navigation 与 settle/interruption 不产生双重 commit；
- 页面切换期间焦点视觉状态没有落到旧 page host；
- teardown 后按键/异步回调零 UI 写回；
- resize 后焦点仍映射到正确 cell 或按文档化规则迁移。

### 7.3 键盘启动测试

- Return/Enter 对有效焦点调用一次 launcher；
- stale revision 拒绝；
- 当前 snapshot 缺少 AppID 拒绝；
- 文件消失拒绝；
- 启动失败非致命；
- 无焦点、空 cell、placeholder 不启动；
- 鼠标单击启动路径与键盘启动共享相同校验；
- 不产生真实 URL/path/bundle ID telemetry。

### 7.4 回归验证

必须至少执行：

```bash
swift test
swift build -c debug
swift build -c release
```

如果项目已有 Python analyzer tests，也应执行当前适用的 Python 测试，但不要把 Python/SELFDRIVE PASS 当作真实触控板验收。

必须记录：

- 实际执行的测试数量与失败数；
- Debug/Release build exit code 和 warning；
- 修改文件列表；
- Core 是否确实未修改；
- trailing whitespace / conflict marker 扫描；
- telemetry 隐私扫描结果；
- 是否有物理触控板复测，若没有必须写 `NOT_RUN` 或 `BLOCKED`。

---

## 8. 物理验收门

键盘功能的自动化测试通过，不等于物理门通过。

本阶段至少需要一个真实 GUI 冒烟检查（用户实际窗口、实际键盘），覆盖：

1. 窗口聚焦；
2. 方向键移动焦点；
3. 跨页；
4. Return/Enter 启动一个仍存在的应用；
5. refresh/resize 后焦点没有错位；
6. 触控板分页仍能操作；
7. 关闭/重开窗口后没有残留回调。

如果没有用户在真实机器上执行，状态只能是：

```text
MANUAL_KEYBOARD_GATE = NOT_RUN
```

不能由 SELFDRIVE、合成 NSEvent、鼠标或单元测试替代。

120Hz 仍按现有状态处理：当前机器为 60Hz 固定面板时写 `BLOCKED_BY_HARDWARE`，不写 PASS。

---

## 9. 停止条件

遇到以下情况应停止扩大实现，保存证据，并向 Main 返回 `BLOCKED` 或提出决策包：

- 需要修改 `Sources/PagingCore/`；
- 需要修改 `Package.swift` 或新增依赖；
- 需要全局监听或 Accessibility 权限；
- 无法在不绕过 stale validation 的情况下接入键盘启动；
- 键盘切页会破坏触控板中断/settle 的连续性；
- 焦点无法绑定到稳定 AppID/revision；
- 需要读取禁止来源或第三方资源；
- 现有协议不足以表达键盘行为，且新增 seam 会改变 Phase 1A/1B 的架构语义；
- 测试执行结果为 0 个测试但 exit 0；
- 需要修改生产默认 Timer tolerance、帧源或 PagingCore 参数才能通过测试；
- 发现当前工作树与报告描述严重不一致。

---

## 10. 交付物

完成后必须交付：

1. 键盘焦点/导航/启动实现；
2. 新增和修改的测试；
3. `Docs/ADR-006-KEYBOARD-FOCUS.md`：记录状态模型、导航边界、事件分发和未支持按键；
4. `Docs/PHASE1C_VALIDATION_PLAN.md`：自动化、GUI 冒烟、物理门、120Hz 状态；
5. `Docs/PHASE1C_REPORT.md`：完成项、未完成项、证据、边界和后续建议；
6. `Workflow/results/<task-id>.md`：按项目 workflow 报告实际修改和验证；
7. 若有参数或产品决策，追加到 `Docs/PARAMETER_RATIONALE.md` 或新的 ADR，不覆盖旧历史；
8. 如有新的隐私/provenance 判断，更新对应文档，但不把扫描写成原创性或法律证明；
9. 当前卡顿诊断状态在报告中保持：

```text
CAUSALITY_UNRESOLVED
PRODUCT_DEFAULT_UNCHANGED
```

---

## 11. 完成判定

Phase 1C 只有在以下证据都齐全后，才能写成 `PHASE1C_AUTOMATED_PASS`：

- 新增测试实际执行且通过；
- 原有测试无回归；
- Debug/Release 构建通过；
- PagingCore 未修改；
- 键盘路径和鼠标路径共享启动安全校验；
- refresh/reuse/resize/teardown 时焦点一致性有测试；
- 隐私扫描无新增红线命中；
- Reviewer 独立检查通过。

只有用户在真实 GUI + 真实键盘上执行并反馈后，才能额外写：

```text
MANUAL_KEYBOARD_GATE = PASS_USER_REPORTED_WITH_EVIDENCE
```

没有真实物理复测时，不得写物理键盘门 PASS。

本阶段不得把以下状态写成 PASS：

```text
ROOT_CAUSE_FOUND
ALL_HITCHES_FIXED
FIX_VALIDATED
SCHEDULER_CONFIRMED
120HZ_VALIDATED
```

---

## 12. 给 Main 的启动指令

执行顺序建议：

1. 读取本 Prompt、`AGENTS.md`、`STATE.json`、`MAIN_BRIEF.md` 和 Phase 1B/帧卡顿收口文档；
2. 检查当前工作树、实际测试基线和未完成 agent 状态；
3. 先让 Chief 判断本阶段是否确实属于已批准的 Phase 1C，以及是否需要缩小为“键盘焦点 + Return 启动”；
4. 记录并发检查：只有写入范围互斥、依赖已满足、测试资源隔离时才并发；
5. 先完成纯逻辑焦点策略，再接 AppKit responder，再接键盘启动；
6. 每个 Worker 只写自己的文件范围，并写 `Workflow/results/<task-id>.md`；
7. Reviewer 只读检查实际 diff，不让 Worker 自证；
8. Main 最后运行 Swift 测试和 Debug/Release 构建，扫描未跟踪文件中的 trailing whitespace/conflict markers，核对 Core 未改；
9. 把自动化结果、GUI 冒烟结果、物理门状态和卡顿诊断状态分开报告；
10. 不 commit、push、tag、reset、clean，不修改 LaunchBetter 或 BuhoReverseNotes。

**最终原则：先把键盘能力做成一个独立、可验证、可回滚的交互层；不要借机改分页核心，不要把尚未解决的卡顿包装成已解决。**
