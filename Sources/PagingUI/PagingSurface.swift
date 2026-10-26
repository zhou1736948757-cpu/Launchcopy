//
//  PagingSurface.swift
//  PagingUI
//
//  分页交互表面（AppKit NSView）：
//  - 持有 PagingCore（唯一输入出口，UI 不绕过状态机）；
//  - 页面承载（ADR-002 方案 1：live AppKit views，容器随 visualOffset 平移）；
//  - NSEvent scrollWheel → ScrollInputMapper → Core 输入（D10 归一化）；
//  - settle 动画：frameDriver（runloop 60Hz 帧泵，见 PagingFrameDriver.swift）每帧 core.tick + 应用 visualOffset；
//  - 中断接管位置连续（接管点 = 当前显示位置；Core D4 保证，UI 照实呈现）；
//  - finishGesture 时机：ended 后无 momentum 事件由本层调用（Worker B 偏差 #1）；
//  - 页面 view 上界 = ceil(livePageRadius + prewarmDistance)（参数化，ADR-002 §4）；
//  - resize：layout() 中事件驱动单次重新布局（宽度守卫，无每帧布局风暴）；
//  - Reduce Motion：setReduceMotion 转发 + refreshReduceMotionFromSystem()；
//  - teardown：停 driver → core.teardown() → 清页面 → 无残留动画驱动器。
//

import AppKit
import PagingCore
import LauncherLocalization

/// 弱引用盒：避免 init 完成前 self 捕获（events 闭包在 core 创建前构造）。
private final class SurfaceReference {
    weak var surface: PagingSurface?
}

/// Phase 1I：页容器必须声明非不透明，否则会用黑底填满 surface，挡住窗内壁纸。
private final class TransparentPageContainerView: NSView {
    override var isOpaque: Bool { false }
}

/// 分页交互表面。
public final class PagingSurface: NSView {

    // MARK: - 配置

    /// Core 状态机（唯一状态/偏移所有权，ADR-001 D1）。
    public let core: PagingCore

    /// 每页占位 item 数（页面内容负载，默认 35 —— 本项目测试负载选择，非旧产品常量）。
    public var itemsPerPage: Int {
        didSet {
            guard itemsPerPage != oldValue, itemsPerPage > 0 else { return }
            relayoutPages()
        }
    }

    /// 诊断模式（--paging-lab）：显示状态/偏移叠加层。
    public var labMode: Bool {
        didSet {
            labOverlay.isHidden = !labMode
            updateLabOverlay()
        }
    }

    /// Reduce Motion 来源（nil = 系统 NSWorkspace 查询；App 层按 --reduce-motion-override 注入）。
    public var reduceMotionProvider: (() -> Bool)?

    /// 帧驱动器（默认 RunLoopFrameDriver：runloop 60Hz 帧泵，见 PagingFrameDriver.swift；
    /// 测试可置 nil 手动 advanceFrame）。
    public var frameDriver: PagingFrameDriving?

    /// 帧路径耗时探针（--frame-profile；nil = 关闭，零测量零开销）。
    /// 见 FrameProfileRecorder.swift：帧回调/输入事件各阶段耗时（纳秒级）→ 独立 JSONL。
    public var frameProfiler: FrameProfileRecorder?

    /// App 层事件出口（App 层在此挂 telemetry 等观察者；触发时读取最新值）。
    public var appEvents = PagingCoreEvents()

    // MARK: - §E 内容承载 seam 注入（Wave 2）

    /// 内容提供者（§E seam；nil → NeutralContentProvider 中性缺省，Phase 1A 回归模式）。
    /// 只请求承载；PagingUI 不拥有 scanner/icon loader（§14.A）。
    public var contentProvider: PagingPageContentProviding? {
        willSet { cancelDirectNavigation() }
        didSet {
            guard !isTearingDown else { return }
            if let revision = contentProvider?.servedRevision {
                servedRevision = revision // 未就绪（nil）→ 保持现值，app 层就绪后 refreshPresentation 驱动
            }
            if oldValue != nil, core.state == .idle, let count = contentProvider?.servedPageCount {
                core.setPageCount(count)
            }
            refreshLiveHostContent(revision: effectiveRevisionForPass())
            relayoutPages()
            onPageNavigationChange?()
        }
    }

    /// 自定义页面渲染器（nil → 中性缺省 NeutralPageRenderer，经每个 live host 委托渲染）。
    /// 注入后应用到全部 live 页面；渲染目标 = 各承载视图自身。
    public var renderer: PagingPageRendering? {
        didSet {
            guard !isTearingDown else { return }
            for host in liveHosts.values {
                host.customRenderer = renderer
            }
            refreshLiveHostContent(revision: effectiveRevisionForPass())
        }
    }

    // MARK: - 观测 hooks（PagingUI 不依赖 PagingTelemetry）

    /// 归一化手势事件（phase, deltaPx, gestureID, visualOffset）——telemetry 用。
    public var onGestureEvent: ((GesturePhase, Double, UInt64, Double) -> Void)?
    /// 布局完成（live host 数）——telemetry 用。
    public var onLayoutPerformed: ((Int) -> Void)?
    /// 页面 prepare（pageIndex, 是否来自复用池）——telemetry 用。
    public var onPagePrepared: ((Int, Bool) -> Void)?
    /// 动画帧（dt）——telemetry frame 事件用。
    public var onAnimationFrame: ((TimeInterval) -> Void)?
    /// Additional work on the existing frame pump, independent of telemetry.
    /// Called once per shared frame; the owner must make inactive advancement a no-op.
    public var supplementalFrameStep: ((TimeInterval) -> Void)?
    /// Additional frame demand (for example a manually driven parent pager).
    /// Install/clear both supplemental hooks, then call refreshFrameDemand().
    public var supplementalFrameDemand: (() -> Bool)?
    /// 页面宽度变化（resize）——telemetry 用。
    public var onResize: (() -> Void)?
    /// teardown 完成——telemetry teardown.complete 用。
    public var onTeardown: (() -> Void)?

    // MARK: - §E seam 状态（pin / latest-wins / 生命周期）

    /// 当前对外服务的 content revision（latest-wins 采纳源：provider 响应 / refreshPresentation）。
    /// 每次 relayout pass 只取一次（相邻页不混 revision，§6.1）。
    public private(set) var servedRevision: UInt64 = 0

    /// 显式 pin：beginInteraction 捕获 (servedRevision, 当前页)；endInteraction 在
    /// idle/cancelled 边界清除；interrupted 保持（Explorer B）。
    public private(set) var pinnedPresentation: PagePresentationID?

    /// tracking/settling/interrupted 期间的最新快照（latest-wins，§6.2）：只缓存最新，
    /// 回到 idle/cancelled 边界一次性 apply。
    public private(set) var pendingLatestSnapshot: (revision: UInt64, content: PagingPageContent)?

    /// 同 revision 重载的 latest pending（§8.3 / ADR-007 §2.4）：busy 期间只记录最新（幂等），
    /// idle/cancelled 边界一次应用。与 `pendingLatestSnapshot`（catalog revision）**独立**：
    /// 同 revision 重载绝不覆盖 catalog revision；新 catalog revision 优先（latest-wins 双轴）。
    public private(set) var pendingSameRevisionReload = false

    /// surface 生命周期 generation：teardown 时递增 —— §6.4 七字段 binding token 字段 7 的源
    /// （作废跨页面生命周期的在途异步绑定）。同 revision 重载也 bump（ADR-007 §2.6：
    /// re-render → surfaceGeneration/reuseGeneration bump → 旧图标回调被 generation/token 拒绝）。
    public private(set) var surfaceGeneration: UInt64 = 0

    /// idle 边界事件：core 进入 idle 时通知 app 层做 anchor remap（§E 约束①）。
    public var onIdleBoundary: (() -> Void)?
    /// Discrete count/commit/presentation observation, independent of telemetry and offset ticks.
    public var onPageNavigationChange: (() -> Void)?

    // MARK: - 内部状态

    private let containerView = TransparentPageContainerView()
    private let labOverlay = NSTextField(labelWithString: "")
    private var liveHosts: [Int: PageHostView] = [:]
    private var reusePool: [PageHostView] = []
    private var lastLayoutWidth: CGFloat = 0
    private var lastLayoutHeight: CGFloat = 0
    /// live hosts 当前显示内容对应的 revision（相邻页不混的渲染基线；§6.1）。
    internal private(set) var renderedRevision: UInt64 = 0
    /// 中性缺省内容提供者（contentProvider == nil 时使用）。
    private let neutralProvider = NeutralContentProvider()

    // MARK: - 释放决策自动触发（T-worker-b-input-fix：真实触控板 ended 后零事件路径）

    /// ended 后等待释放决策的最长窗口（秒）。快甩的 momentum 事件在 ended 后 1–3 帧内到达
    /// （<50ms）；100ms 不误伤 fling。慢滑释放后无任何后续事件 → 帧驱动在窗口期满后自动
    /// finishGesture（回弹/翻页/吸住）——修复物理门 FAIL「滚筒式自由滑动」。
    internal var pendingFinishThreshold: TimeInterval = 0.1
    /// 时间源（内部可注入：测试用合成时钟；生产默认单调系统时钟，与 NSEvent.timestamp 同基）。
    internal var pendingFinishTimeSource: () -> TimeInterval = { ProcessInfo.processInfo.systemUptime }
    /// ended 时刻（时间源同基）；nil = 无待决释放。internal 只读：测试断言待决状态。
    internal private(set) var pendingFinishSince: TimeInterval?
    internal private(set) var needsFinish = false
    private var gestureSequence: UInt64 = 0
    private var isCancellingDirectNavigation = false

    // MARK: - 测试/观察入口

    /// 页面容器（测试断言用）。
    internal var pageContainer: NSView { containerView }
    /// 取某页的 live host（测试断言用；不存在返回 nil）。
    internal func hostForPage(_ index: Int) -> PageHostView? {
        liveHosts[index]
    }

    /// 已执行的布局次数（§7.4 可观测）。
    public private(set) var layoutPerformedCount = 0
    /// 当前 live 页面数（§7.4 可观测）。
    public private(set) var liveHostCount = 0
    /// 复用池大小（§7.4 可观测，内存上界代理）。
    public private(set) var poolHostCount = 0
    /// 是否已 teardown。
    public private(set) var isTearingDown = false
    /// 当前页可访问性描述（"Page X of M"）。
    public private(set) var accessibilityDescription = ""
    private var displayedStrings: LocalizedStrings?
    private var textUpdateScheduled = false
    private var textUpdateGeneration: UInt64 = 0
    internal private(set) var languageFormattingCount = 0
    internal private(set) var diagnosticFormattingCount = 0

    /// The application separately injects the same snapshot into its renderer page cache.
    public func relabel(strings: LocalizedStrings) {
        guard !isTearingDown else { return }
        displayedStrings = strings
        for host in liveHosts.values { host.relabel(strings: strings) }
        for host in reusePool { host.relabel(strings: strings) }
        queuePresentationText()
    }

    /// Coalesces Core's transitive callbacks without formatting or resource access.
    private func queuePresentationText() {
        guard !isTearingDown, !textUpdateScheduled else { return }
        textUpdateScheduled = true
        let generation = textUpdateGeneration
        DispatchQueue.main.async { [weak self] in
            guard let self, !self.isTearingDown, generation == self.textUpdateGeneration else { return }
            self.textUpdateScheduled = false
            self.renderAccessibilityDescription()
            self.renderLabOverlay()
        }
    }
    /// 当前手势序号（began 时递增）。
    public private(set) var lastGestureID: UInt64 = 0

    // MARK: - 初始化

    public init(
        pageCount: Int,
        pageWidth: Double = 1000,
        itemsPerPage: Int = 35,
        parameters: PagingParameters = .init(),
        initialPage: Int = 0,
        reduceMotion: Bool = false,
        reduceMotionProvider: (() -> Bool)? = nil,
        labMode: Bool = false,
        appEvents: PagingCoreEvents = .init()
    ) {
        self.itemsPerPage = max(itemsPerPage, 1)
        self.reduceMotionProvider = reduceMotionProvider
        self.labMode = labMode
        self.appEvents = appEvents

        // Core events 包装：init 完成前不得捕获 self → 经 SurfaceReference 间接调用；
        // core 须在 super.init 前赋值（let 属性）。
        // 注意：闭包必须**强捕获** box（box 弱引用 surface）——若弱捕获，box 在 init 返回后
        // 即被释放，Core 事件将永远无法送达 UI（曾导致 §7.3 可访问性/容器跟随静默失效）。
        let reference = SurfaceReference()
        var events = PagingCoreEvents()
        events.onStateChange = { reference.surface?.handleCoreState($0) }
        events.onVisualOffsetChange = { reference.surface?.handleCoreOffset($0) }
        events.onTransitionBegin = { reference.surface?.handleCoreTransitionBegin($0) }
        events.onCommit = { reference.surface?.handleCoreCommit($0) }
        events.onStaleRejection = { reference.surface?.handleCoreStaleRejection($0) }
        events.onInterruption = { reference.surface?.handleCoreInterruption($0) }
        core = PagingCore(
            pageCount: pageCount,
            pageWidth: pageWidth,
            parameters: parameters,
            initialPage: initialPage,
            reduceMotion: reduceMotion,
            events: events
        )

        super.init(frame: .zero)

        reference.surface = self

        wantsLayer = true
        // Phase 1I：壁纸合成需要非不透明 surface（LaunchBetter: surface.layer.backgroundColor=nil）。
        // SDK 上 isOpaque 为 get-only，只能 override；行为仍为完整事件/分页路径。
        layer?.isOpaque = false
        layer?.backgroundColor = nil
        frameDriver = RunLoopFrameDriver(owner: self) // T-worker-b-frame-fix：runloop 60Hz 泵（display link 在本环境零回调）

        containerView.wantsLayer = true
        containerView.layer?.isOpaque = false
        containerView.layer?.backgroundColor = nil
        containerView.frame = bounds
        addSubview(containerView)

        labOverlay.font = .monospacedSystemFont(ofSize: 12, weight: .regular)
        labOverlay.textColor = .secondaryLabelColor
        labOverlay.isHidden = !labMode
        addSubview(labOverlay)

        relayoutPages()
        updateAccessibilityDescription()
    }

    @available(*, unavailable)
    public required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    /// Phase 1I：壁纸合成需要非不透明 surface（否则 AppKit 用黑底填实，壁纸不可见）。
    public override var isOpaque: Bool { false }

    deinit {
        frameDriver?.stop()
    }

    // MARK: - 对外控制（转发 Core；保持单一入口）

    public var presentedOffset: Double { core.visualOffset }
    public var isDirectNavigationActive: Bool { core.isDirectNavigationActive }

    public func canRequestPage(_ targetPage: Int) -> Bool {
        !isTearingDown && !isCancellingDirectNavigation && !needsFinish && pendingFinishSince == nil && core.canRequestPage(targetPage)
    }

    @discardableResult
    public func requestPage(_ targetPage: Int, timestamp: TimeInterval = ProcessInfo.processInfo.systemUptime) -> Bool {
        guard canRequestPage(targetPage), timestamp.isFinite else { return false }
        if pinnedPresentation == nil { beginInteraction() }
        let accepted = core.requestPage(targetPage, timestamp: timestamp)
        updateAnimationDriver()
        onPageNavigationChange?()
        return accepted
    }

    /// Scoped lifecycle cancellation; physical tracking/settling policy is unchanged.
    public func cancelDirectNavigation() {
        guard !isTearingDown, !isCancellingDirectNavigation, isDirectNavigationActive else { return }
        isCancellingDirectNavigation = true
        defer { isCancellingDirectNavigation = false }
        core.cancel()
        updateAnimationDriver()
        onPageNavigationChange?()
    }

    /// pageCount 变化（转发 Core + 重算可见范围 + 刷新 live 页面内容）。
    public func setPageCount(_ count: Int) {
        guard !isTearingDown else { return }
        if count != core.pageCount { cancelDirectNavigation() }
        core.setPageCount(count)
        relayoutPages()
        // 既有 live 页面也要刷新页码标签/内容（"Page N of M" 中的 M 已变）：
        // seam 全量刷新（同 revision，相邻页不混）。
        refreshLiveHostContent(revision: effectiveRevisionForPass())
        onPageNavigationChange?()
    }

    /// Reduce Motion 动态切换（转发 Core）。
    public func setReduceMotion(_ enabled: Bool) {
        guard !isTearingDown else { return }
        core.setReduceMotion(enabled)
        updateAnimationDriver()
        onPageNavigationChange?()
    }

    /// 从系统偏好（或 override provider）刷新 Reduce Motion。
    public func refreshReduceMotionFromSystem() {
        guard !isTearingDown else { return }
        let value = reduceMotionProvider?() ?? NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
        setReduceMotion(value)
    }

    /// 取消当前手势/动画（转发 Core）。
    public func cancel() {
        guard !isTearingDown else { return }
        core.cancel()
        updateAnimationDriver()
    }

    /// 销毁：停驱动 → Core teardown → 清空页面（幂等；窗口关闭路径）。
    public func teardown() {
        guard !isTearingDown else { return }
        isTearingDown = true
        textUpdateGeneration &+= 1
        textUpdateScheduled = false
        onPageNavigationChange = nil
        surfaceGeneration &+= 1 // §6.4 字段 7：surface 生命周期 generation bump → 在途绑定全部作废
        pinnedPresentation = nil
        pendingLatestSnapshot = nil
        pendingSameRevisionReload = false // teardown 后零写回（同 revision 重载 pending 一并作废）
        clearPendingFinish() // §7.3：teardown 后零回调（待决释放不得在关闭后触发）
        supplementalFrameStep = nil
        supplementalFrameDemand = nil
        frameDriver?.stop()
        frameDriver = nil
        core.teardown()
        for (_, host) in liveHosts {
            host.invalidatePendingLanguageText()
            host.removeFromSuperview()
        }
        for host in reusePool { host.invalidatePendingLanguageText() }
        liveHosts.removeAll()
        liveHostCount = 0
        reusePool.removeAll()
        poolHostCount = 0
        containerView.removeFromSuperview()
        labOverlay.removeFromSuperview()
        accessibilityDescription = ""
        setAccessibilityValue("")
        onTeardown?()
    }

    public override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        // 窗口关闭/视图从层级移除 → teardown（幂等；也覆盖 App 退出路径）。
        if window == nil {
            teardown()
        }
    }

    // MARK: - 输入（scrollWheel → 归一化 → Core；测试可直接调用 handleScrollInput）

    public override func scrollWheel(with event: NSEvent) {
        handleScrollInput(
            phase: event.phase,
            momentumPhase: event.momentumPhase,
            scrollingDeltaX: event.scrollingDeltaX,
            scrollingDeltaY: event.scrollingDeltaY,
            isDirectionInverted: event.isDirectionInvertedFromDevice,
            timestamp: event.timestamp
        )
    }

    /// 归一化输入入口（scrollWheel 与测试共用同一路径）。
    internal func handleScrollInput(
        phase: NSEvent.Phase,
        momentumPhase: NSEvent.Phase,
        scrollingDeltaX: CGFloat,
        scrollingDeltaY: CGFloat,
        isDirectionInverted: Bool,
        timestamp: TimeInterval
    ) {
        guard !isTearingDown else { return }
        let profiler = frameProfiler
        profiler?.beginInput(
            timestamp: timestamp,
            phase: FrameProfileRecorder.phaseName(phase: phase, momentumPhase: momentumPhase)
        )
        let actions = ScrollInputMapper.map(
            phase: phase,
            momentumPhase: momentumPhase,
            scrollingDeltaX: scrollingDeltaX,
            scrollingDeltaY: scrollingDeltaY,
            isDirectionInverted: isDirectionInverted,
            needsFinish: needsFinish
        )
        for action in actions {
            apply(action, timestamp: timestamp)
        }
        profiler?.markInputDispatchDone()
        updateAnimationDriver()
        profiler?.markInputViewDone()
        profiler?.endInput(gestureActive: core.state != .idle)
    }

    /// 自动化/探针输入缝（T-step6）：与 scrollWheel 完全相同的归一化路径。
    /// 仅供自动化回归与无头性能探针（PAGING_PROTOTYPE_PERF）；**不作物理验收门**
    /// （真实触控板验收见 T-step8）。
    public func simulateScrollInput(
        phase: NSEvent.Phase,
        momentumPhase: NSEvent.Phase,
        scrollingDeltaX: CGFloat,
        scrollingDeltaY: CGFloat,
        isDirectionInverted: Bool,
        timestamp: TimeInterval
    ) {
        handleScrollInput(
            phase: phase,
            momentumPhase: momentumPhase,
            scrollingDeltaX: scrollingDeltaX,
            scrollingDeltaY: scrollingDeltaY,
            isDirectionInverted: isDirectionInverted,
            timestamp: timestamp
        )
    }

    /// 自动化/探针帧缝（T-step6）：advanceFrame 的公开转发（帧驱动每帧调用的同一实现）。
    public func simulateFrame(deltaTime: TimeInterval) {
        advanceFrame(deltaTime: deltaTime)
    }

    /// 探针：core 调用计时（输入记录 state_ns 归属；探针不参与逻辑）。
    @discardableResult
    private func profileCoreWork<T>(_ body: () -> T) -> T {
        let profiler = frameProfiler
        profiler?.coreWorkBegin()
        defer { profiler?.coreWorkEnd() }
        return body()
    }

    /// 探针：视图/观察回调计时（view_ns 归属；探针不参与逻辑）。
    private func profileViewWork(_ body: () -> Void) {
        let profiler = frameProfiler
        profiler?.viewWorkBegin()
        defer { profiler?.viewWorkEnd() }
        body()
    }

    private func apply(_ action: ScrollInputAction, timestamp: TimeInterval) {
        switch action {
        case .gestureBegan:
            if needsFinish {
                // ended 后无 momentum 的新手势接管：先释放旧手势（偏差 #1）。
                _ = profileCoreWork { core.finishGesture(timestamp: timestamp) }
                clearPendingFinish()
            }
            beginInteraction() // §E pin：手势 began 捕获 servedRevision（显式 API 供 app 层手动控制）
            gestureSequence &+= 1
            lastGestureID = gestureSequence
            _ = profileCoreWork { core.handleGesturePhase(.began, timestamp: timestamp) }
            profileViewWork { onGestureEvent?(.began, 0, gestureSequence, core.visualOffset) }

        case .gestureChanged(let delta):
            let accepted = profileCoreWork { core.handleGesturePhase(.changed, delta: delta, timestamp: timestamp) }
            if accepted {
                profileViewWork { onGestureEvent?(.changed, delta, gestureSequence, core.visualOffset) }
            }

        case .gestureEnded:
            needsFinish = true
            pendingFinishSince = pendingFinishTimeSource()
            if profileCoreWork({ core.handleGesturePhase(.ended, timestamp: timestamp) }) {
                profileViewWork { onGestureEvent?(.ended, 0, gestureSequence, core.visualOffset) }
            }

        case .gestureCancelled:
            clearPendingFinish()
            if profileCoreWork({ core.handleGesturePhase(.cancelled, timestamp: timestamp) }) {
                profileViewWork { onGestureEvent?(.cancelled, 0, gestureSequence, core.visualOffset) }
            }

        case .momentumBegan:
            let hadPendingFinish = needsFinish
            clearPendingFinish()
            if !profileCoreWork({ core.handleGesturePhase(.momentumBegan, timestamp: timestamp) }), hadPendingFinish {
                // 防御：Core 拒绝 momentum（如未经历 ended）→ 改为释放决策。
                _ = profileCoreWork { core.finishGesture(timestamp: timestamp) }
            } else {
                profileViewWork { onGestureEvent?(.momentumBegan, 0, gestureSequence, core.visualOffset) }
            }

        case .momentumChanged(let delta):
            if profileCoreWork({ core.handleGesturePhase(.momentumChanged, delta: delta, timestamp: timestamp) }) {
                profileViewWork { onGestureEvent?(.momentumChanged, delta, gestureSequence, core.visualOffset) }
            }

        case .momentumEnded:
            if profileCoreWork({ core.handleGesturePhase(.momentumEnded, timestamp: timestamp) }) {
                profileViewWork { onGestureEvent?(.momentumEnded, 0, gestureSequence, core.visualOffset) }
            }

        case .finishPendingGesture:
            clearPendingFinish()
            _ = profileCoreWork { core.finishGesture(timestamp: timestamp) }

        case .legacyScroll(let delta):
            clearPendingFinish()
            _ = profileCoreWork { core.legacyScrollDelta(delta, timestamp: timestamp) }

        case .ignore:
            break
        }
    }

    // MARK: - 帧推进（帧驱动每帧调用；测试手动调用）

    /// 取消待决释放（momentum 接管 / 新手势 / 取消 / legacy 输入 / finishPendingGesture / teardown）。
    private func clearPendingFinish() {
        needsFinish = false
        pendingFinishSince = nil
    }

    internal func advanceFrame(deltaTime: TimeInterval) {
        guard !isTearingDown else { return }
        let profiler = frameProfiler
        profiler?.beginFrame(timestamp: ProcessInfo.processInfo.systemUptime)
        defer {
            profiler?.endFrame(gestureActive: !isTearingDown && (core.isAnimating || pendingFinishSince != nil))
        }
        // T-worker-b-input-fix：真实触控板 ended 后无任何下一事件 → 帧驱动在窗口期满后自动
        // 触发释放决策（回弹/翻页/吸住）。窗口内 momentumBegan/新 began 等已清除待决状态，
        // 故不误伤 fling；timestamp 用 ended 时刻（释放速度语义一致）。
        if needsFinish, let since = pendingFinishSince,
           pendingFinishTimeSource() - since >= pendingFinishThreshold {
            guard !isTearingDown else { return }
            let finishTime = since
            clearPendingFinish()
            _ = core.finishGesture(timestamp: finishTime)
        }
        guard !isTearingDown else { return }
        profiler?.markFrameInputDone()
        onAnimationFrame?(deltaTime)
        guard !isTearingDown else { return }
        _ = core.tick(deltaTime: deltaTime)
        guard !isTearingDown else { return }
        profiler?.markFrameStateDone()
        supplementalFrameStep?(deltaTime)
        guard !isTearingDown else { return }
        updateAnimationDriver()
        guard !isTearingDown else { return }
        profiler?.markFrameViewDone()
    }

    // MARK: - Core 事件处理

    private func handleCoreState(_ state: PagingState) {
        let profiler = frameProfiler
        profiler?.viewWorkBegin()
        defer { profiler?.viewWorkEnd() }
        appEvents.onStateChange?(state)
        // §E seam：idle/cancelled 边界 → 解除 pin + 一次性 apply pendingLatestSnapshot（§6.2）；
        // idle 边界另发 onIdleBoundary 通知 app 层做 anchor remap（§E 约束①）。
        if (state == .idle || state == .cancelled) && core.state == state && !isTearingDown {
            endInteraction()
            if state == .idle && core.state == .idle && !isTearingDown {
                onIdleBoundary?()
            }
        }
        updateAnimationDriver()
        relayoutPagesIfRangeChanged()
        updateAccessibilityDescription()
        updateLabOverlay()
        if !isTearingDown { onPageNavigationChange?() }
    }

    private func handleCoreOffset(_ offset: Double) {
        let profiler = frameProfiler
        profiler?.viewWorkBegin()
        defer { profiler?.viewWorkEnd() }
        appEvents.onVisualOffsetChange?(offset)
        guard !isTearingDown else { return }
        let width = max(bounds.width, 64)
        // Outward observers may have synchronously cancelled or replaced the offset.
        containerView.frame.origin.x = -CGFloat(core.visualOffset) * width
        relayoutPagesIfRangeChanged()
        updateAccessibilityDescription()
        updateLabOverlay()
    }

    private func handleCoreTransitionBegin(_ context: TransitionContext) {
        let profiler = frameProfiler
        profiler?.viewWorkBegin()
        defer { profiler?.viewWorkEnd() }
        appEvents.onTransitionBegin?(context)
        updateAccessibilityDescription()
        updateLabOverlay()
    }

    private func handleCoreCommit(_ context: TransitionContext) {
        let profiler = frameProfiler
        profiler?.viewWorkBegin()
        defer { profiler?.viewWorkEnd() }
        appEvents.onCommit?(context)
        relayoutPagesIfRangeChanged()
        updateAccessibilityDescription()
        updateLabOverlay()
        if !isTearingDown { onPageNavigationChange?() }
    }

    /// stale completion 拒绝（D3 三防线之一）→ 转发给 appEvents 消费者（telemetry 桥）。
    /// （缺失此转发曾是 T-step6 探针发现的真实缺陷：Core 计数正确但外部观察不到 stale 事件。）
    private func handleCoreStaleRejection(_ token: UInt64) {
        appEvents.onStaleRejection?(token)
    }

    /// 活跃动画被打断（D4/D5 接管）→ 转发给 appEvents 消费者（telemetry 桥）。
    private func handleCoreInterruption(_ info: PagingInterruption) {
        appEvents.onInterruption?(info)
    }

    /// Reconcile supplemental demand without replacing the driver or telemetry hook.
    /// Call when the supplemental owner starts, finishes, cancels, or detaches work.
    public func refreshFrameDemand() {
        updateAnimationDriver()
    }

    private func updateAnimationDriver() {
        guard !isTearingDown else { return }
        let supplementalNeedsFrames = supplementalFrameDemand?() ?? false
        // The demand callback may synchronously tear down this surface.
        guard !isTearingDown else { return }
        // 待决释放窗口内也保持驱动运行：帧驱动（runloop 60Hz 泵）每帧检查窗口期满 → 自动释放决策
        // （真实触控板慢滑 ended 后 runloop 停在 eventTracking mode，普通 Timer 不可靠）。
        if core.isAnimating || pendingFinishSince != nil || supplementalNeedsFrames {
            frameDriver?.start()
        } else {
            frameDriver?.stop()
        }
    }

    // MARK: - §E seam：pin / latest-wins / refresh（内容承载）

    /// 显式 pin：捕获当前 servedRevision + 当前显示页（手势 began 自动调用；app 层可手动）。
    public func beginInteraction() {
        guard !isTearingDown else { return }
        let page = min(max(Int(core.visualOffset.rounded()), 0), max(core.pageCount - 1, 0))
        pinnedPresentation = PagePresentationID(revision: servedRevision, pageIndex: page)
    }

    /// 解除 pin：仅在 idle/cancelled 边界清除（tracking/settling/**interrupted 保持**，§E）；
    /// 清除前把 pendingLatestSnapshot 一次性 apply（§6.2 latest-wins）。
    /// 同 revision 重载 pending（§8.3）在 idle/cancelled 边界一次应用，但**新 catalog revision
    /// 优先**：若已有 pending catalog revision，先 apply 它并丢弃同 revision 重载（ADR-007 §2.4）。
    public func endInteraction() {
        guard !isTearingDown else { return }
        switch core.state {
        case .idle, .cancelled:
            let pending = pendingLatestSnapshot
            pinnedPresentation = nil
            if let pending {
                applyPresentation(revision: pending.revision)
                pendingSameRevisionReload = false // catalog revision 优先，同 revision 重载被取代
            } else if pendingSameRevisionReload {
                applySameRevisionReload()
                pendingSameRevisionReload = false
            }
        default:
            break // tracking / settling / interrupted：保持 pin
        }
    }

    /// 刷新呈现：provider 有新 revision 时调用（扫描/刷新完成回调，app 层驱动）。
    /// - idle/cancelled（边界态）→ 原子替换 presentation + 更新合法 pageCount + 刷新
    ///   live hosts（§E 约束①）；
    /// - tracking/settling/interrupted → 只写 pendingLatestSnapshot（§6.2），回到
    ///   idle/cancelled 边界一次性 apply。
    public func refreshPresentation() {
        guard !isTearingDown, let provider = contentProvider else { return }
        guard let latest = provider.servedRevision else { return } // 未就绪（nil）→ 中性占位，不刷新
        if latest != servedRevision { cancelDirectNavigation() }
        switch core.state {
        case .idle, .cancelled:
            if latest != servedRevision {
                applyPresentation(revision: latest)
            }
        default:
            // latest-wins：只缓存最新（重复 refresh 覆盖旧快照，不堆积）。
            if pendingLatestSnapshot == nil || pendingLatestSnapshot!.revision != latest {
                let page = pinnedPresentation?.pageIndex
                    ?? min(max(Int(core.visualOffset.rounded()), 0), max(core.pageCount - 1, 0))
                pendingLatestSnapshot = (latest, requestContent(pageIndex: page, revision: latest))
            }
        }
    }

    /// 原子替换 presentation：新 revision + 合法 pageCount + 全量刷新 live hosts（§E 约束①）。
    private func applyPresentation(revision: UInt64) {
        guard !isTearingDown, let provider = contentProvider else { return }
        servedRevision = revision
        if let newPageCount = provider.servedPageCount, newPageCount != core.pageCount {
            core.setPageCount(newPageCount) // D6 三分支；内部触发 relayout（范围变化）
        }
        refreshLiveHostContent(revision: revision)
        // A count change at idle offset zero may emit no Core offset/state event.
        // Reconcile missing hosts after refreshing retained ones, without rebinding
        // the existing range twice or waiting for a viewport resize.
        relayoutPagesIfRangeChanged()
        pendingLatestSnapshot = nil
        onPageNavigationChange?()
    }

    /// 同 revision 重载 seam（§8.3 / ADR-007 §2.2）：以**相同 `servedRevision`** 重渲染 live
    /// hosts，但使用 provider 当前 presentation records（pageCount 可能变化）。query 变化时调用；
    /// **绝不 mint/forge CatalogRevision**（servedRevision 保持 base snapshot revision）。
    /// - idle/cancelled → 立即原子应用（pageCount + live hosts）；
    /// - tracking/settling/interrupted → 只记录 latest pending，idle/cancelled 边界一次应用；
    /// - 不丢失已有 pending catalog revision；新 catalog revision 优先于旧同 revision 重载；
    /// - 强制重渲染（surfaceGeneration bump + 全量 live host re-render）使旧图标回调无法写入
    ///   新 query 的 cell（stale apply = 0）；teardown 后零写回。
    public func reloadCurrentPresentation() {
        guard !isTearingDown, let provider = contentProvider else { return }
        guard provider.servedRevision != nil else { return } // 未就绪 → 无操作（中性占位）
        cancelDirectNavigation()
        switch core.state {
        case .idle, .cancelled:
            applySameRevisionReload()
        default:
            pendingSameRevisionReload = true // latest-wins：只记录最新（幂等，不堆积）
        }
    }

    /// 原子应用同 revision 重载：bump surfaceGeneration（作废在途绑定）+ 合法 pageCount +
    /// 全量刷新 live hosts（同 servedRevision，不改变 revision）。
    private func applySameRevisionReload() {
        guard !isTearingDown, let provider = contentProvider else { return }
        surfaceGeneration &+= 1 // §6.4 字段 7：surface 级 generation bump → 在途绑定作废
        if let newPageCount = provider.servedPageCount, newPageCount != core.pageCount {
            core.setPageCount(newPageCount) // D6 三分支
            relayoutPages() // 显式 relayout：pageCount 变化（含缩小）后重算可见范围
        }
        refreshLiveHostContent(revision: effectiveRevisionForPass())
        onPageNavigationChange?()
    }

    /// 本次 relayout pass 的有效 revision：pin 激活 → pin revision（手势全程同 revision）；
    /// 否则 → servedRevision（相邻页不混，§6.1）。
    private func effectiveRevisionForPass() -> UInt64 {
        pinnedPresentation?.revision ?? servedRevision
    }

    /// seam 单点内容请求：同步内存命中（无同步 I/O，§5.4/§7）；nil provider → 中性占位。
    /// 边界态（idle/cancelled）防御性采纳 provider 实际服务的 revision（latest-wins 自同步）；
    /// 手势中不采纳（revision 由 pin/缓存纪律决定）。
    private func requestContent(pageIndex: Int, revision: UInt64) -> PagingPageContent {
        let provider: PagingPageContentProviding = contentProvider ?? neutralProvider
        let content = provider.content(
            for: PagePresentationID(revision: revision, pageIndex: pageIndex),
            itemsPerPage: itemsPerPage
        )
        switch core.state {
        case .idle, .cancelled:
            servedRevision = content.presentationID.revision
        default:
            break
        }
        return content
    }

    /// 全量刷新 live hosts 内容（同一 revision 基线；revision/pageCount/provider 变化时调用）。
    private func refreshLiveHostContent(revision: UInt64) {
        guard !isTearingDown else { return }
        for (index, host) in liveHosts {
            let content = requestContent(pageIndex: index, revision: revision)
            host.render(
                pageIndex: index,
                content: content,
                pageCount: core.pageCount,
                reuseGeneration: host.reuseGeneration
            )
        }
        renderedRevision = effectiveRevisionForPass()
    }

    // MARK: - 页面承载（ADR-002 方案 1：live views + 参数化上界）

    /// 可见范围半径：ceil(livePageRadius + prewarmDistance)（ADR-002 §4 参数化上界）。
    internal static func pageRadius(for parameters: PagingParameters) -> Int {
        Int(ceil(Double(parameters.livePageRadius) + parameters.prewarmDistance))
    }

    /// 当前可见页面范围（含两端；pageCount == 0 返回 nil）。
    private func currentRange() -> (min: Int, max: Int)? {
        guard core.pageCount > 0 else { return nil }
        let radius = Self.pageRadius(for: core.parameters)
        let center = min(max(Int(core.visualOffset.rounded()), 0), core.pageCount - 1)
        return (max(0, center - radius), min(core.pageCount - 1, center + radius))
    }

    /// 范围变化时重新布局（热路径只做范围比较，不每帧重建页面）。
    private func relayoutPagesIfRangeChanged() {
        guard !isTearingDown else { return }
        let wanted = currentRange()
        let liveKeys = Set(liveHosts.keys)
        if let wanted {
            let wantedKeys = Set(wanted.min...wanted.max)
            if wantedKeys != liveKeys {
                relayoutPages()
            }
        } else if !liveHosts.isEmpty {
            relayoutPages()
        }
    }

    /// 事件驱动单次重新布局：对齐页面 frame、容器尺寸，回收/复用页面。
    /// §E seam 单点：每 pass 只取一次 revision（相邻页不混）；host.render 承载内容。
    internal func relayoutPages() {
        guard !isTearingDown else { return }
        layoutPerformedCount += 1
        let width = max(bounds.width, 64)
        let height = max(bounds.height, 64)

        guard let range = currentRange() else {
            // pageCount == 0：清空全部页面。
            for (_, host) in liveHosts {
                host.removeFromSuperview()
                // Detach first so the existing renderer cleanup can recognize
                // this host as retired, then revoke bindings before returning.
                host.clearForReuse()
            }
            liveHosts.removeAll()
            liveHostCount = 0
            containerView.frame = CGRect(x: 0, y: 0, width: width, height: height)
            updateAccessibilityDescription()
            onLayoutPerformed?(0)
            return
        }

        // pass revision：每 pass 只取一次（pin 激活 → pin revision；否则 servedRevision）。
        let passRevision = effectiveRevisionForPass()

        // 1) 回收范围外页面（clearForReuse → reuseGeneration bump → 在途异步绑定作废，§6.4）。
        for (index, host) in liveHosts where index < range.min || index > range.max {
            host.clearForReuse()
            host.removeFromSuperview()
            liveHosts.removeValue(forKey: index)
            reusePool.append(host)
        }

        // 2) 补充缺失页面（优先复用池；seam 单点：request content → host.render）。
        var addedThisPass: [Int] = []
        for index in range.min...range.max where liveHosts[index] == nil {
            let reused = !reusePool.isEmpty
            let host: PageHostView = reused ? reusePool.removeLast() : PageHostView()
            if let displayedStrings { host.relabel(strings: displayedStrings) }
            host.customRenderer = renderer
            let content = requestContent(pageIndex: index, revision: passRevision)
            host.render(
                pageIndex: index,
                content: content,
                pageCount: core.pageCount,
                reuseGeneration: host.reuseGeneration
            )
            host.frame = CGRect(x: CGFloat(index) * width, y: 0, width: width, height: height)
            containerView.addSubview(host)
            liveHosts[index] = host
            addedThisPass.append(index)
            onPagePrepared?(index, reused)
        }

        // 2b) revision 基线漂移（边界态自同步采纳 / 新 provider）→ 全量重渲染同基线，
        //     保证相邻页不混 revision（§6.1）。
        let adoptedRevision = effectiveRevisionForPass()
        if adoptedRevision != renderedRevision {
            for (index, host) in liveHosts where !addedThisPass.contains(index) {
                let content = requestContent(pageIndex: index, revision: adoptedRevision)
                host.render(
                    pageIndex: index,
                    content: content,
                    pageCount: core.pageCount,
                    reuseGeneration: host.reuseGeneration
                )
            }
            renderedRevision = adoptedRevision
        }

        // 2c) 已有 live 页面全部按当前 page width 重新对齐（resize 后必做；
        //     事件驱动调用，非每帧，成本 = live 数量级，远小于每帧重建）。
        for (index, host) in liveHosts {
            host.stagePageCount(core.pageCount)
            host.frame = CGRect(x: CGFloat(index) * width, y: 0, width: width, height: height)
        }

        // 3) 容器：页面绝对坐标，容器随 visualOffset 平移。
        containerView.frame = CGRect(
            x: -CGFloat(core.visualOffset) * width,
            y: 0,
            width: CGFloat(range.max + 1) * width,
            height: height
        )
        liveHostCount = liveHosts.count
        poolHostCount = reusePool.count
        updateAccessibilityDescription()
        onLayoutPerformed?(liveHostCount)
    }

    // MARK: - resize（事件驱动单次重新布局，宽度守卫防每帧风暴）

    public override func layout() {
        super.layout()
        guard !isTearingDown else { return }
        let widthChanged = abs(bounds.width - lastLayoutWidth) > 0.5
        let heightChanged = abs(bounds.height - lastLayoutHeight) > 0.5
        guard widthChanged || heightChanged else { return }
        lastLayoutWidth = bounds.width
        lastLayoutHeight = bounds.height
        cancelDirectNavigation()
        if widthChanged {
            // 宽度变化 → Core pageWidth rebase（D6）+ 布局。
            core.setPageWidth(Double(bounds.width))
        }
        // 高度单独变化（或与宽度同时）→ 全部 live 页面按新尺寸重新对齐。
        // 宽度未变时高度变化不触碰 Core（偏移语义不变），仍事件驱动单次布局。
        onResize?()
        relayoutPages()
    }

    // MARK: - 可访问性（§7.3）

    private func updateAccessibilityDescription() {
        queuePresentationText()
    }

    private func renderAccessibilityDescription() {
        guard !isTearingDown else { return }
        guard core.pageCount > 0 else {
            let text = displayedStrings?.gridText(.noPages) ?? GridTextKey.noPages.englishFallback
            accessibilityDescription = text
            setAccessibilityValue(text)
            return
        }
        let page: Int
        switch core.state {
        case .settling:
            page = core.activeTransition?.targetPage ?? core.committedPage
        case .tracking:
            page = min(max(Int(core.visualOffset.rounded()), 0), core.pageCount - 1)
        default:
            page = core.committedPage
        }
        languageFormattingCount += 1
        let text = displayedStrings?.page(page + 1, total: core.pageCount)
            ?? "Page \(page + 1) of \(core.pageCount)"
        guard text != accessibilityDescription else { return }
        accessibilityDescription = text
        setAccessibilityValue(text)
    }

    // MARK: - 诊断叠加（--paging-lab）

    private func updateLabOverlay() {
        queuePresentationText()
    }

    private func renderLabOverlay() {
        guard labMode, !isTearingDown else { return }
        let stateName: String
        switch core.state {
        case .idle: stateName = "idle"
        case .tracking: stateName = "tracking"
        case .settling: stateName = "settling"
        case .interrupted: stateName = "interrupted"
        case .cancelled: stateName = "cancelled"
        }
        diagnosticFormattingCount += 1
        labOverlay.stringValue = String(
            format: "state=%@  page=%d  offset=%.3f  hosts=%d  rm=%@",
            stateName, core.committedPage, core.visualOffset, liveHostCount,
            core.reduceMotion ? "on" : "off"
        )
        labOverlay.sizeToFit()
        labOverlay.frame.origin = CGPoint(x: bounds.width - labOverlay.frame.width - 12, y: bounds.height - labOverlay.frame.height - 12)
    }
}
