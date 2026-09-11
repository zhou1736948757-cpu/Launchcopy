# T-1C-D-blankclick-repair — 结果（repair Worker）

- 状态: **DONE**
- Worker: repair（chef-worker-reviewer-workflow）
- 日期: 2026-08-30
- 改动范围: 仅 `Sources/PagingPrototypeApp/AppDelegate.swift` + 新增一个测试文件
- 验证: `swift test` **526 / 0**（基线 520，+6 新增）｜`swift build -c debug` **exit 0**｜`swift build -c release` **exit 0**

---

## 1. 症状与根因（对齐 spec）

用户 verbatim：全屏下单击空白背景**首次点击经常不退出**，需连点 2–3 次。

原实现 `installBackgroundClickToQuit(on:)` 给 surface 挂 `NSClickGestureRecognizer(numberOfClicksRequired:1)`；
`backgroundClick` 只在 recognizer **被识别**的点上触发。根因：
- **识别器吞首击**：全屏过渡（0.3s 延迟 + 约一秒动画）期间 recognizer 常不触发；
- **allowableMovement/jitter**：mouseDown+mouseUp 位移 ≤ 默认 10pt 才 fire，点击轻微抖动即静默失败，无任何反馈 → 用户以为没点到，连点数次才命中一次。

修复：**在每次真实 mouseDown 上评估命中**，不再依赖 may-not-fire 的点击识别。

## 2. 方案选择（为何不用字面「NSView 容器 mouseDown」）

Spec 期待的容器视图方案存在一个硬性技术障碍：`PagingSurface` 是 **`public final`**（冻结，不可子类化覆盖 `mouseDown(with:)`），且它是仅有的、**铺满窗口**的交互视图。要让「容器/背景视图」的 `mouseDown` 在空白点击时触发，必须把容器 `hitTest` 重写成把空白命中重定向到自身——但 AppKit 的 **scrollWheel 事件目标正是经 hitTest 决定的**，改写 hitTest 会破坏滚轮翻页（红线：scrollWheel 翻页不许坏）。

因此选用 **`QuitOnBlankClickWindow: NSWindow` 子类，覆盖 `sendEvent(_:)`**（窗口内单点拦截）：
- **不是**红线下禁止的「全局 NSEvent monitor」（`NSEvent.addGlobalMonitorForEvents`）——拦截点是**本窗口**的 `sendEvent`，窗口外/其他 app 完全不触碰；
- **不改写 hitTest** → scrollWheel 翻页、键盘导航的事件路由零改动；
- 每次真实的 `leftMouseDown` 都会评估命中，空白即退。

## 3. Diff

### 3.1 `Sources/PagingPrototypeApp/AppDelegate.swift`

**(a) 窗口创建：`NSWindow` → `QuitOnBlankClickWindow` + 挂退出回调**
```swift
// Before
let window = NSWindow(contentRect:…, styleMask:…, backing:…, defer:false)
window.title = "Paging Prototype"
window.contentView = surface
window.delegate = self

// After
let window = QuitOnBlankClickWindow(contentRect:…, styleMask:…, backing:…, defer:false)
window.title = "Paging Prototype"
window.contentView = surface
window.onBlankClick = { [weak self] in self?.terminateOnBackgroundClick() }   // 空白首击退出
window.delegate = self
```
其余窗口时序（makeKeyAndOrderFront / activate / 0.3s toggleFullScreen / 全屏诊断）**原样未动**。

**(b) 删除旧的 recognizer 安装点（原 L227 `installBackgroundClickToQuit(on: surface)`）**，注释改为说明拦截点已随窗口创建生效、无需手势识别器。

**(c) 替换 `MARK: 单击空白背景退出` 段**：删除 `installBackgroundClickToQuit` + `backgroundClick(_:)`（NSClickGestureRecognizer 方案），仅保留 `terminateOnBackgroundClick()`。

**(d) 文件末尾新增宿主窗口子类 + 分类 helper**
```swift
private final class QuitOnBlankClickWindow: NSWindow {
    var onBlankClick: (() -> Void)?
    override func sendEvent(_ event: NSEvent) {
        if event.type == .leftMouseDown {
            if let contentView {
                let point = contentView.convert(event.locationInWindow, from: nil)
                let hit = contentView.hitTest(point)
                if !blankClickResolvesToCell(hit) {   // 空白背景 → 首击即退
                    onBlankClick?()
                    return
                }
            }
        }
        super.sendEvent(event)                          // 命中 cell → 放行给 cell 识别器
    }
}

/// 空白-vs-cell 命中分类：命中链（含 icon/label 子视图）是否含 AppGridCellView。
func blankClickResolvesToCell(_ hit: NSView?) -> Bool {
    var node = hit
    while let current = node {
        if current is AppGridCellView { return true }
        node = current.superview
    }
    return false
}
```

### 3.2 新增测试文件 `Tests/PagingUITests/BlankClickToQuitTests.swift`（+6）
| 测试 | 断言 |
|---|---|
| testBlankRootIsNotCell | 空白根视图 → **非 cell**（走退出） |
| testBlankNilIsNotCell | nil hit → 空白 |
| testUnrelatedNestedViewIsNotCell | 无关嵌套视图 → 非 cell |
| testCellItselfIsCell | cell 本身 → cell（放行启动） |
| testCellIconSubviewIsCell | cell 内图标子视图 → cell（不误判退出） |
| testCellNameLabelSubviewIsCell | cell 内名称标签子视图 → cell（不误判退出） |

注：真实的「首次实击必退」依赖窗口事件分发/全屏动画，属 **GUI 手工门禁**；单测锁定**分类正确性**（可无头构造 NSView 层次验证），不替代交互验收。

## 4. 验证结果

| 项 | 结果 |
|---|---|
| `swift test`（全量） | **526 tests, 0 failures**（基线 520 → +6）|
| `swift test --filter BlankClickToQuitTests` | 6 tests, 0 failures |
| `swift build -c debug` | **exit 0** |
| `swift build -c release` | **exit 0** |

## 5. 禁止树核验

对冻结树逐文件 `stat -f '%m'` 前后对比（写 `/tmp/frozen_before.txt` ↔ `/tmp/frozen_after.txt`）：

```
diff /tmp/frozen_before.txt /tmp/frozen_after.txt  →  空（无差异）
STATUS: forbidden trees UNCHANGED
```

- `Sources/PagingCore/`, `Sources/PagingUI/`, `Sources/AppGridUI/`, `Sources/MacAppCatalog/`：**mtime 全部未变**。
- `Package.swift`：md5 **50998b66f34c68d3a842ebc9ae8432ec**（不变）。
- `Sources/PagingPrototypeApp/AppLaunchController.swift`：mtime **1787921214**（不变，冻结 cell 启动识别器未动）。
- 变更文件仅：`Sources/PagingPrototypeApp/AppDelegate.swift`、`Tests/PagingUITests/BlankClickToQuitTests.swift`。
- 无 git commit/push/tag；无 `NSEvent.addGlobalMonitorForEvents`；无 Accessibility 权限；无同步 I/O；telemetry / Timer tolerance 8.333ms 未动。

## 6. 「为何首击现在可靠」— 一页论证

**A. 每次真实 mouseDown 都评估命中。**
拦截点在本窗口的 `sendEvent`：AppKit 对发往该窗口的每个鼠标事件都必然经过 `sendEvent`。对每个 `leftMouseDown` 用 `contentView.hitTest` 评估命中并分类。空白命中 → **当次按下即 `NSApp.terminate`**，不需要 mouseUp、不需要「被识别」，也无 allowableMovement 位移门限——第一下就退。不再有任何「这个点击可能不 fire」的路径。

**B. 与 cell 启动互斥为假（无冲突）。**
cell 命中 → 分类为 cell → `super.sendEvent(event)` 原样放行。surface 上 `AppLaunchController` 的 cell `NSClickGestureRecognizer`（冻结文件 L95–96）照常收到 mouseDown/mouseUp 而启动。cell 判定沿 superview 链校验（含 iconView/nameLabel），点击 cell 内部子视图不误判为空。空白与 cell 的分支在窗口层严格互斥、单进。

**C. scrollWheel 翻页不受影响。**
`PagingSurface.scrollWheel(with:)` 是唯一翻页路径；本修复**没有改 hitTest、没有改 responder/事件路由**，scrollWheel 事件照常送达 surface → `ScrollInputMapper`。翻页逻辑（冻结 `PagingSurface.swift`）零改动。

**D. 键盘导航不受影响。**
`sendEvent` 只拦截 `leftMouseDown`，其余事件（箭头键/Return 等 key 事件）走 `super.sendEvent` 原路径；键盘代理与 `KeyboardLaunchAdapter` 未动（冻结 `AppLaunchController.swift` 未改）。

**E. 红线合规。**
窗口级 `sendEvent` ≠ 全局 `NSEvent.addGlobalMonitorForEvents`（后者拦截**全系统**事件并常需 Accessibility 授权；本实现只在本窗口事件分发内、无需额外权限）。不做 hitTest 改写 → 不引入 scrollWheel/点击的额外交互面。

**F. 唯一残余窗口 = 系统侧全屏动画吞点击。**
如果用户在 `toggleFullScreen` 过渡动画进行**中**点击，事件在到达窗口前即被 window server 丢弃，任何应用内拦截都接不到——这是**瞬时**（约 1s）且不可由应用修复的窗口期。过渡结束后的每次实击都必达 `sendEvent` 并退出，正是用户症状（稳态下连点 2–3 次）被根治的部分。稳态首击可靠性由 A–D 保障。

## 7. 交付给 Reviewer/Main

verdict：**DONE**。
- diff：见 §3；改动仅 2 个允许文件（AppDelegate.swift + 新增测试）。
- test：**526 / 0**（基线 520 + 6 新增 single-vs-blank 分类单测；纯 UI 点击可靠性为 GUI 手工门禁）。
- build：debug exit 0，release exit 0。
- 禁止树：mtime/md5 全部核验未变。
- 结论：全屏空白任意位置单击 → **首击可靠退出**；cell 启动、scrollWheel 翻页、键盘导航零回归（代码论证见 §6，独立 Reviewer 复核后可交 Main 重建重开供用户实测）。
