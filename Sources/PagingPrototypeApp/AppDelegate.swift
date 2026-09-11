//
//  AppDelegate.swift
//  PagingPrototypeApp
//
//  App 生命周期：窗口创建、Reduce Motion 监听、teardown 接线。
//  Phase 1B（Wave 3，worker-integration）：真实内容装配（--neutral-content 回归模式）、
//  单击启动 smoke（AppLaunchController）、§8 帧源实验（--frame-driver）。
//

import AppCatalogCore
import AppGridUI
import AppKit
import PagingCore
import PagingTelemetry
import PagingUI

final class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {

    private let options: AppArguments.Options
    private var window: NSWindow?
    /// Phase 1G T-1G-B：presentation 窗口控制器（Option B screen-covering panel）。
    /// 全入口仲裁与 blank→hide 留给 T-1G-E；此处仅 host/attach + 去掉延迟 toggleFullScreen。
    private var launcherWindowController: LauncherWindowController?
    /// Phase 1G T-1G-C：菜单栏 status item（Show/Hide / Settings stub / Quit）。
    /// 创建失败不崩溃；teardown 移除。
    private var statusItemController: StatusItemController?
    /// Phase 1G T-1G-E：激活入口组合根（shortcut / hot corner / four-finger / session → 同一 launcher）。
    private var activationComposition: ActivationComposition?
    /// Phase 1G T-1G-E：激活偏好存储（独立 suite；失败则内存默认）。
    private var activationPreferencesStore: (any ActivationPreferencesPersisting)?
    /// Phase 1H T-1H-B/F：激活设置协调器（单实例窗 + apply 事务；启动不自动启用 login item）。
    private var activationSettingsCoordinator: ActivationSettingsCoordinator?
    /// 启动器主面板右上角设置入口（不依赖菜单栏 status item；Ice 折叠时仍可发现）。
    private var launcherSettingsButton: NSButton?
    /// Phase 1I：模糊壁纸（CALayer 挂在 contentView.layer 最底，对齐 LaunchBetter）。
    private var wallpaperBackdrop: WallpaperBackdropController?
    /// Phase 1H：Launch at Login 服务（生产 SMAppService；测试不经此路径）。
    private var launchAtLoginService: (any LaunchAtLoginServicing)?
    /// Phase 1G T-1G-E：进程 teardown 闸门（quit / willTerminate 共用；恰好一次）。
    private var didRunFinalTeardown = false
    private var surface: PagingSurface?
    /// 容器（surface + search field 的 sibling overlay 宿主；folder 打开层挂此层，覆盖全表面）。
    private var container: NSView?
    private var telemetryBridge: PagingTelemetryBridge?
    private var assembly: AppCatalogAssembly?
    private var launchController: AppLaunchController?
    /// Phase 1C：键盘焦点控制器（T-1C-B）+ 键盘启动适配器（T-1C-C）。
    private var keyboardController: KeyboardFocusController?
    private var launchAdapter: KeyboardLaunchAdapter?
    /// Phase 1D：搜索控制器（T-1D-E 装配；field/controller/presentation 接线）。
    private var search: AppSearchController?
    /// Phase 1E：folder 打开状态（会话内；T-1E-E 接线）。
    private var folderOpenState: FolderOpenState?
    /// Phase 1E：folder 打开层视图（T-1E-C；T-1E-E 接线）。
    private var folderOverlay: FolderOverlayView?
    /// Phase 1E：folder 标题编辑 first responder（T-1E-D；T-1E-E 接线）。
    private var folderTitleEditor: FolderTitleEditor?
    /// Phase 1F：drag UI 协调器（T-1F-D1；统一输入仲裁 + 中性拖拽视觉）。
    private var dragCoordinator: DragUISessionCoordinator?
    /// Phase 1F：会话内布局（T-1F-D1；commit 结果暂存于此，零磁盘写；T-1F-E 接 provider/persist）。
    private var sessionLayout: PersistentWorkspaceLayout?
    /// Phase 1F：layout store（T-1F-D1-fix-e1；commit 布局异步持久化，coalescing sink，
    /// 不阻塞主线程；teardown 置 nil）。
    private var layoutStore: LayoutStore?
    /// Phase 1F：标题编辑中（drag 门；与 keyboardController.isEditingTitle 同步维护）。
    private var isTitleEditing = false
    private var frameDriverExperiment: DisplayLinkFrameDriver?
    /// Phase 1B 帧路径耗时探针（--frame-profile；nil = 关闭）。
    private var frameProfiler: FrameProfileRecorder?
    /// Phase 1B runloop 级主线程探针（--frame-profile 同开；nil = 关闭）。
    private var runLoopProfiler: RunLoopProfileRecorder?
    /// Timer callback 边界探针（--frame-callback-profile；nil = 关闭）。
    private var frameCallbackProfiler: FrameCallbackProfileRecorder?
    /// §8 帧源实验证据（最近一次；stdout 已打印，此处保留供诊断/结果文件）。
    public private(set) var frameDriverEvidence: String?
    private var motionObserver: NSObjectProtocol?
    private var selfDriveFrameCount = 0
    /// T-1F-B10-regression-fix §2.1 取证（E6a''）：分发入口 local monitor（sE6_monitor_down/up
    /// 中性计数；nil = 未安装）。local monitor 只收本 app 窗口事件（非全局 monitor，隐私
    /// A/B/C）；返回 event 原样 = 零行为变更。
    private var clickMonitor: Any?

    init(options: AppArguments.Options) {
        self.options = options
        super.init()
    }

    // MARK: - 启动

    func applicationDidFinishLaunching(_ notification: Notification) {
        // 1) telemetry session（默认关闭；开启时打印 run ID 与日志路径）。
        // `--disable-telemetry-bridge` 是 callback cadence 的严格对照：不仅关闭文件，
        // 还完全不安装 frame hook，避免 disabled session 的同步 queue 往返混入测量。
        let effectiveTelemetryEnabled = options.telemetryEnabled && !options.disableTelemetryBridge
        let session = PagingTelemetry.makeSession(enabled: effectiveTelemetryEnabled, runID: options.runID)
        session.begin()
        if effectiveTelemetryEnabled {
            print("paging-telemetry: run id = \(session.runID)")
            print("paging-telemetry: log  = \(session.logPathDescription)")
        } else if options.disableTelemetryBridge {
            let requestedNotice = options.telemetryEnabled ? "; requested telemetry suppressed" : ""
            print("paging-telemetry-bridge: disabled for controlled callback cadence experiment\(requestedNotice)")
            fflush(stdout)
        }

        // 1b) T-1F-B10-regression-fix §2.1 取证（E6a''）：分发入口监视——local monitor 中性
        // 计数（sE6_monitor_down/up；仅计数，返回 event 原样 = 零行为变更；local monitor
        // 只收本 app 窗口事件，非全局 monitor，隐私 A/B/C）。判别（任务包 §2.1 步骤 4）：
        // monitor 有而视图全零 → 事件进入 AppKit 分发但投递到 PagingUI 冻结层或内部吞（h）；
        // monitor 无 → 分发前即被吞。
        clickMonitor = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown, .leftMouseUp]) { event in
            ClickCensus.observeMonitorEvent(type: event.type)
            return event
        }

        // 2) Reduce Motion 初始值（override 优先；system 读系统偏好）。
        let initialReduceMotion: Bool
        switch options.reduceMotionOverride {
        case .on: initialReduceMotion = true
        case .off: initialReduceMotion = false
        case .system: initialReduceMotion = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
        }

        // 3) 分页表面（中性页面内容；诊断模式按 --paging-lab）。
        //    --momentum-decay / --momentum-glide-frames / --momentum-overshoot 调参接线
        //    （T-worker-b-tune/-glide/-overshoot2）：缺省 = PagingParameters 默认
        //    （0.95 / nil=跟随完整系统流 / 0.20）。
        let surface = PagingSurface(
            pageCount: options.pageCount ?? 5,
            itemsPerPage: options.itemsPerPage ?? 35,
            parameters: AppParameters.make(
                momentumDecay: options.momentumDecay,
                momentumGlideFrames: options.momentumGlideFrames,
                momentumOvershoot: options.momentumOvershoot
            ),
            initialPage: 0,
            reduceMotion: initialReduceMotion,
            labMode: options.pagingLab
        )
        surface.reduceMotionProvider = { [options] in
            switch options.reduceMotionOverride {
            case .on: return true
            case .off: return false
            case .system: return NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
            }
        }
        self.surface = surface

        // Timer tolerance 单变量 A/B：生产默认 0ms（T-A4-0ms）；显式参数只改变
        // RunLoop Timer 的允许延迟窗口，不改 PagingCore、动画参数或页面内容。
        let frameTimerTolerance = options.frameTimerToleranceMS.map { $0 / 1_000.0 } ?? 0
        let diagnosticClock = DiagnosticMonotonicClock.system
        let callbackProfiler = options.frameCallbackProfile
            ? FrameCallbackProfileRecorder(runID: session.runID, active: true, clock: diagnosticClock)
            : nil
        self.frameCallbackProfiler = callbackProfiler
        surface.frameDriver = RunLoopFrameDriver(
            owner: surface,
            tolerance: frameTimerTolerance,
            callbackProfiler: callbackProfiler
        )
        if let callbackProfiler {
            print("paging-frame-callback-profile: \(callbackProfiler.fileURL.path)")
        }
        if let configuredMS = options.frameTimerToleranceMS {
            print(String(format: "paging-frame-timer: tolerance=%.3fms (controlled experiment)", configuredMS))
            fflush(stdout)
        }

        // 3b) Phase 1B：真实内容装配（t10）。
        //     --neutral-content → 不装配：contentProvider/renderer 保持 nil →
        //     PagingSurface 走 NeutralContentProvider 中性缺省（Phase 1A 回归模式，§E 约束④）。
        //     装配组件（AppGridRefreshController/AppCatalogAssembly）为 MainActor 隔离；
        //     applicationDidFinishLaunching 恒在主线程执行 → assumeIsolated 合法且确定性。
        MainActor.assumeIsolated {
            installContentAssembly(surface: surface)
        }

        // 4) telemetry 接线（最终接线责任）。诊断对照可完全跳过 bridge/frame hook；
        // 默认仍安装，生产行为不变。
        if !options.disableTelemetryBridge {
            telemetryBridge = PagingTelemetryBridge(surface: surface, session: session)
        }

        // 4b) Phase 1B 帧路径耗时探针（--frame-profile）：独立 profile 文件 + stdout 摘要。
        //     默认关闭：缺省时 surface.frameProfiler == nil（零测量、零文件、零逻辑参与）。
        //     run ID 复用 telemetry session 的 runID（未指定时自动生成；与 telemetry 独立）。
        //     同一诊断模式同时开 runloop 级主线程探针（RunLoopProfileRecorder，独立文件）：
        //     定位帧回调之外的主线程工作（图标写回/布局/绘制提交/其他 source 或系统调度）。
        if options.frameProfile {
            let profiler = FrameProfileRecorder(runID: session.runID, active: true)
            surface.frameProfiler = profiler
            self.frameProfiler = profiler
            print("paging-frame-profile: \(profiler.fileURL.path)")
        }
        // Independent `--runloop-profile` shares one observer with `--frame-profile`.
        // Both use the same DiagnosticMonotonicClock domain as the callback recorder.
        if options.frameProfile || options.runLoopProfile {
            let runLoopProfiler = RunLoopProfileRecorder(
                runID: session.runID,
                active: true,
                clock: diagnosticClock
            )
            runLoopProfiler.start()
            self.runLoopProfiler = runLoopProfiler
            print("paging-runloop-profile: \(runLoopProfiler.fileURL.path)")
            fflush(stdout)
        }

        // 4b) Phase 1B §8 帧源实验（--frame-driver runloop|displaylink|auto）。
        //     runloop = Phase 1A 稳定路径（缺省，surface 默认驱动）；displaylink/auto 经
        //     探测式 DisplayLinkFrameDriver 接入：帧源恒为 RunLoop，display link 仅观测
        //     （零回调记录 fallback reason；证据经 evidenceHandler 打印 + 保留）。
        switch options.frameDriver {
        case .runloop:
            break
        case .displaylink, .auto:
            let experiment = DisplayLinkFrameDriver(
                owner: surface,
                forceDisplayLink: options.frameDriver == .displaylink,
                frameTimerTolerance: frameTimerTolerance,
                callbackProfiler: callbackProfiler
            )
            experiment.evidenceHandler = { [weak self] evidence in
                self?.frameDriverEvidence = evidence
                print("paging-frame-driver: \(evidence)")
                fflush(stdout)
            }
            surface.frameDriver = experiment
            self.frameDriverExperiment = experiment
        }

        // 5) 窗口（T-1G-B Option B）：**一开始就**用 borderless screen-covering panel。
        // 禁止先建 titled 再改 styleMask——AppKit 会短暂把 contentView 移出层级，
        // PagingSurface.viewDidMoveToWindow(nil) 会永久 teardown（冻结树行为），导致「有目录无应用」。
        let initialFrame = NSScreen.main?.frame
            ?? NSRect(x: 0, y: 0, width: 1470, height: 956)
        let window = QuitOnBlankClickWindow(
            contentRect: initialFrame,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        window.setFrame(initialFrame, display: false)
        // LaunchBetter 同款：窗口必须透明，壁纸由内容层绘制；不透明黑窗会盖死背景。
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = false
        window.isReleasedWhenClosed = false
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        window.level = .normal
        window.title = ""
        // 容器：surface + search field 作为 sibling overlay（field 不随页面容器平移）。
        // T-1F-B10-regression-fix §2.1 取证：容器 = 投递探针（只读观测 AppKit 实际投递目标
        // 的类名链；hitTest/mouseDown 原样转发 super，零行为变更；非探针 contentView 零影响）。
        let container = ClickDeliveryProbeView(frame: NSRect(origin: .zero, size: initialFrame.size))
        window.contentView = container
        self.container = container
        // LaunchBetter：壁纸 CALayer 挂在 root.layer 最底，前景 grid 是透明 subview。
        container.wantsLayer = true
        container.layer?.isOpaque = false
        container.layer?.backgroundColor = LaunchcopyVisualTokens.fallbackBackdropColor().cgColor
        let backdrop = WallpaperBackdropController()
        backdrop.attach(to: container)
        self.wallpaperBackdrop = backdrop
        surface.frame = container.bounds
        surface.autoresizingMask = [.width, .height]
        surface.wantsLayer = true
        surface.layer?.isOpaque = false
        surface.layer?.backgroundColor = nil
        container.addSubview(surface)
        // subview 加入后把壁纸层重新插回最底。
        backdrop.attach(to: container)
        refreshWallpaperBackdrop(for: window)
        if let search {
            let field = search.field
            field.frame = searchFieldFrame(in: container.bounds)
            field.autoresizingMask = [.minXMargin, .maxXMargin, .minYMargin]
            container.addSubview(field)
            search.install(in: window)
        }
        // Phase 1H：主面板右上角齿轮 → 激活设置（菜单栏被 Ice 折叠时的可见入口）。
        installLauncherSettingsButton(in: container)
        // T-1C-D repair：空白背景首击退出（详见下方 QuitOnBlankClickWindow 注释）。
        // T-1D 修复：搜索激活时空白点击 → 退出搜索（不终止应用）；搜索未激活 → 退出。
        // T-1E-E：folder 打开时空白点击 → 关闭 folder（不退出）；folder 关闭后下一次真实
        // 背景单击才退出（blank-click 两阶段，ADR-008 §3 Q10）。
        window.folderOpenStateProvider = { [weak self] in
            self?.folderOpenState
        }
        window.onBlankClickShouldExitSearch = { [weak self] in
            guard let self, let search = self.search, search.isSearchActive else { return false }
            search.exitSearchAndRestoreFocus()
            return true
        }
        window.onBlankClick = { [weak self] in
            self?.hideOnBackgroundClick()
        }
        // T-1F-B10-regression-fix §2.1 取证（E5-fix）：直接读 PagingSurface.layoutPerformedCount
        // （PagingUI 冻结树 :169 public private(set)，只读不调用）替代已降级的 E5 funnel
        // （applyPresentationUpdate 计数点已移除）。纯观测，零行为变更。
        window.layoutPerformedCountProvider = { [weak self] in
            self?.surface?.layoutPerformedCount ?? 0
        }
        // Phase 1F：drag 仲裁守卫（T-1F-D1）。
        // - 空白 mouseDown 时 drag 激活（防御；正常不可能）→ cancel(.escape) 并吞掉本点击（不退出）。
        // - ESC keyDown 时 drag 激活 → cancel(.escape) 并吞掉（键盘控制器不处理 drag 中 ESC）。
        window.onDragActiveCancel = { [weak self] in
            guard let self, let coordinator = self.dragCoordinator, coordinator.isSessionActive else { return false }
            coordinator.cancel(reason: .escape)
            return true
        }
        window.onEscapeDuringDrag = { [weak self] in
            guard let self, let coordinator = self.dragCoordinator, coordinator.isSessionActive else { return false }
            coordinator.cancel(reason: .escape)
            return true
        }
        window.delegate = self
        // T-1G-B：不再使用 setFrameAutosaveName 恢复非覆盖尺寸；panel 由 LauncherWindowController 放置。
        self.window = window

        // T-1F-B10-regression-fix §2.1 第 4 项（4b，并入 E4 门控构建）：启动期一次性状态补读。
        // **仅供诊断 A/B 实验，禁止作为生产路径常驻。** 仅 `PAGING_CLICK_PROBE_MANUAL_DELIVERY=1`
        // 时打印一行（中性布尔/枚举级状态，无身份/坐标/标题；风格同既有 paging-fullscreen
        // 单行 + fflush）：`window.ignoresMouseEvents` / `contentView.ignoresMouseEvents` /
        // `window.level` / `window.styleMask` / `NSApp.isActive && keyWindow==self`。
        // 每击内联 E1 复核（`event.windowNumber == self.windowNumber`）已有布点（sendEvent
        // leftMouseDown 分支），本步不重复，零行为变更。
        if E4ManualDeliveryGate.isEnabled {
            // 注：`ignoresMouseEvents` 仅存在于 NSWindow（NSView 无此属性）；contentView 槽位
            // 报告窗口级属性（该开关作用于整窗事件，也是视图层可读的唯一真值）。
            let contentView = window.contentView
            print("paging-click-probe: ignoresMouseEvents window=\(window.ignoresMouseEvents) contentView=\(window.ignoresMouseEvents) level=\(window.level.rawValue) styleMask=\(window.styleMask.rawValue) keyActive=\(NSApp.isActive && NSApp.keyWindow === window)")
            _ = contentView
            fflush(stdout)
        }

        // 5b) 最小菜单（App 退出 Cmd+Q + View 显示/隐藏）。T-1G-B：去掉“切换全屏”。
        installLauncherMenu()

        // 5c) T-1G-B/E：ADR-011 Q3 Option B — screen-covering borderless panel。
        //     内容层次（surface/search/folder/drag）保持；控制器只负责形态与 present effect。
        //     T-1G-E：多入口 → 同一 coordinator；blank/ESC/launch/close → hide；Quit → terminate。
        let reduceMotionProvider: () -> Bool = { [options] in
            switch options.reduceMotionOverride {
            case .on: return true
            case .off: return false
            case .system: return NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
            }
        }
        let launcher = LauncherWindowController(reduceMotionProvider: reduceMotionProvider)
        launcher.attach(window: window)
        launcher.preferredFirstResponder = keyboardController
        // 启动器一隐藏（空白/ESC/启动应用/菜单隐藏等）→ 强制关掉设置窗，避免「面板没了设置还在」。
        launcher.onLauncherDidHide = { [weak self] in
            MainActor.assumeIsolated {
                self?.activationSettingsCoordinator?.hideSettings()
            }
        }
        self.launcherWindowController = launcher
        let targetScreen = ScreenID(index: 0)
        _ = launcher.show(source: .initialLaunch, targetScreen: targetScreen)
        // 窗已上屏后再刷壁纸（此时 window.screen 才可靠）。
        refreshWallpaperBackdrop(for: window)
        // Option B 铺满后：若首扫在旧窗口尺寸下已 commit，refreshPresentation 会因同 revision 跳过。
        // 必须走同 revision 重载 seam，否则 live hosts 停在旧布局 → 用户看到「没有应用」。
        surface.needsLayout = true
        surface.layoutSubtreeIfNeeded()
        if assembly?.provider.servedRevision != nil {
            if let served = assembly?.provider.servedPageCount {
                surface.setPageCount(served)
            }
            surface.reloadCurrentPresentation()
        }
        let contentFrame = window.contentView?.frame ?? .zero
        let surfaceFrame = surface.frame
        print("paging-launcher-panel: optionB frame=\(window.frame) content=\(contentFrame) surface=\(surfaceFrame) styleMask=\(window.styleMask.rawValue) state=\(String(describing: launcher.coordinator.state)) servedRev=\(String(describing: assembly?.provider.servedRevision))")
        fflush(stdout)
        // 启动后延迟再诊断/修复一次（首扫可能在 panel 之后才完成；中性计数，无 app 名/路径）。
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
            guard let self, let surface = self.surface else { return }
            let servedBefore = surface.core.pageCount
            if let served = self.assembly?.provider.servedPageCount {
                print("paging-catalog-set: before=\(surface.core.pageCount) target=\(served) tearing=\(surface.core.isTearingDown) coreId=\(ObjectIdentifier(surface.core)) surfaceId=\(ObjectIdentifier(surface))")
                surface.core.setPageCount(served)
                print("paging-catalog-set: afterDirect=\(surface.core.pageCount)")
                surface.setPageCount(served)
                print("paging-catalog-set: afterSurface=\(surface.core.pageCount)")
                fflush(stdout)
            }
            surface.reloadCurrentPresentation()
            surface.needsLayout = true
            surface.layoutSubtreeIfNeeded()
            let pages = surface.core.pageCount
            let served = self.assembly?.provider.servedPageCount
            let records = self.assembly?.provider.presentationRecords.count
            let entries = self.assembly?.provider.presentationEntries.count
            let revision = self.assembly?.provider.servedRevision
            print("paging-catalog-diag: pageCountBefore=\(servedBefore) pageCount=\(pages) servedPageCount=\(String(describing: served)) presentationRecords=\(String(describing: records)) presentationEntries=\(String(describing: entries)) revision=\(String(describing: revision)) content=\(self.window?.contentView?.frame ?? .zero) surface=\(surface.frame)")
            fflush(stdout)
        }

        // 5c') T-1G-E：ActivationComposition — prefs → shortcut/hot-corner/four-finger/session。
        //      默认 shortcut/hot corner Off；fourFinger userEnabled 来自 prefs（默认 true）。
        //      四指生产路径 = process + flushPendingShows → apply 到同一 launcher。
        installActivationComposition(launcher: launcher)

        // 5c'') T-1G-C/E：StatusItemController 宿主（prefs.showStatusItem；失败降级不崩溃）。
        //       菜单 validation 读 coordinator.committedVisibility；Quit → composition.handleQuit。
        installStatusItem(launcher: launcher)

        // 5d) T-1G-E：空白背景 → hide（驻留）；folder/search/drag 优先级仍在 QuitOnBlankClickWindow。

        // 6) Reduce Motion 系统偏好变化监听。
        motionObserver = NotificationCenter.default.addObserver(
            forName: NSWorkspace.accessibilityDisplayOptionsDidChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.surface?.refreshReduceMotionFromSystem()
        }

        // 7) GUI 自驱模式（T-step6）：真实 runloop 下跑脚本化手势旅程，输出帧数/事件统计后退出。
        //    输入仍是 synthetic（物理门属 T-step8）；帧源 = RunLoopFrameDriver 60Hz 泵
        //    （T-worker-b-frame-fix：display link 在本环境零回调，Timer(.common) 泵为默认驱动）。
        if ProcessInfo.processInfo.environment["PAGING_PROTOTYPE_GUI_SELFDRIVE"] == "1" {
            startSelfDriveTour()
        }
    }

    // MARK: - Phase 1B 内容装配（t10；MainActor 隔离，调用方 = applicationDidFinishLaunching）

    /// 装配真实内容（--neutral-content → 回归模式不装配）并接线 surface/telemetry/启动。
    /// - Parameter surface: 已创建的分页表面（contentProvider/renderer 注入点）。
    @MainActor
    private func installContentAssembly(surface: PagingSurface) {
        if options.neutralContent {
            print("paging-prototype: --neutral-content 回归模式：Phase 1A 中性 placeholder（不装配真实 catalog）")
            return
        }
        guard let assembly = AppRuntimeFactory.makeAssembly(options: options) else {
            print("paging-prototype: 装配失败（AppRuntimeFactory 返回 nil）—— 以中性模式运行")
            return
        }
        surface.contentProvider = assembly.provider
        surface.renderer = assembly.renderer
        assembly.refreshController.itemsPerPage = surface.itemsPerPage
        // T-1E-H2 repair：provider.servedPageCount 用实例 itemsPerPage（与 surface 对齐），
        // 非默认 --items-per-page 下搜索激活路径不再按硬编码 35 推导页数。
        assembly.provider.itemsPerPage = surface.itemsPerPage

        // 呈现提交（idle 边界 anchor remap 后）→ surface pageCount/revision 刷新 + telemetry。
        // 顺序：先 refreshPresentation（采纳新 revision + provider.servedPageCount），
        // 再 setPageCount(update 的 itemsPerPage 对齐页数) —— 非默认 --items-per-page 时
        // provider.servedPageCount（35 基准）可能与 update.plan.pageCount 不同，以后者为准。
        assembly.onPresentationUpdate = { [weak self] update in
            self?.applyPresentationUpdate(update, overridePageCount: true)
        }

        // idle 边界（手势结束/取消 → Core 回 idle）：latest-wins pending 一次性提交 + anchor remap。
        // 回调恒在主线程（PagingSurface 事件）→ assumeIsolated 确定性成立。
        // F1（T-1C-C repair）：同一 idle 边界顺带做键盘跨页 settle 调和 —— 键盘跨页 settle
        // 完成/中断回到 idle 时，把焦点重新落定到 committed/displayed 页，避免残留旧页映射。
        // T-1D-E：搜索提交优先（处理 pending catalog snapshot 重跑查询 + pending search result），
        // 刷新控制器随后（无 pending catalog snapshot 时 no-op）。
        surface.onIdleBoundary = { [weak self] in
            guard let self else { return }
            MainActor.assumeIsolated {
                self.applyPendingAtIdleBoundary()
            }
        }

        // 扫描完成但 surface 已 idle（Core 初始化不触发 onIdleBoundary，启动首扫依赖此路径）：
        // 非 busy 状态变化时若 surface idle → 立即提交；手势进行中则交给 onIdleBoundary。
        // 回调经 @MainActor controller 触发 → assumeIsolated 确定性成立。
        assembly.refreshController.onStateChange = { [weak self] state in
            guard let self, let surface = self.surface, !state.isBusy else { return }
            if surface.core.state == .idle {
                MainActor.assumeIsolated {
                    self.applyPendingAtIdleBoundary()
                }
            }
        }

        // 图标异步结果 → telemetry（icon_async_state；中性枚举）。
        assembly.renderer.onIconApplyResult = { [weak self] _, result in
            self?.telemetryBridge?.recordIconAsyncState(result)
        }

        assembly.begin()
        self.assembly = assembly

        // 3c) t11：单击启动 smoke（cell 校验 → 当前 catalog 重新确认 → NSWorkspace 公开 API）。
        let launch = AppLaunchController(
            surface: surface,
            assembly: assembly,
            session: telemetryBridge?.session
        )
        launch.install()
        // T-1F-B8-wave-c census（S9）+ T-1G-E：成功启动 → hide launcher（驻留）；拒绝/失败保持可见。
        // AppLaunchController 冻结面只读，经公开 onLaunchAttempt 回调接线（不改 AppLaunchController.swift）。
        launch.onLaunchAttempt = { [weak self] outcome in
            switch outcome {
            case .launched:
                ClickCensus.hit(ClickCensus.Sink.launchAccepted)
            default:
                ClickCensus.hit(ClickCensus.Sink.launchRejectedPrefix + String(describing: outcome))
            }
            _ = self?.activationComposition?.handleLaunchOutcome(outcome)
        }
        self.launchController = launch

        // 3d) Phase 1C：键盘焦点 + 启动适配器接线（T-1C-C）。
        //     焦点模型（T-1C-A）→ 键盘控制器（T-1C-B，单一键盘代理）→ 启动适配器（本任务）。
        //     键盘启动复用 launch.handleCell —— 与鼠标单击共享同一校验管线，无并行启动路径。
        let focusModel = AppGridFocusModel()
        let keyboard = KeyboardFocusController(columns: 5)
        keyboard.install(on: surface, focusModel: focusModel)
        let launchAdapter = KeyboardLaunchAdapter(
            launchController: launch,
            cellResolver: { [weak surface] identity in
                guard let renderer = surface?.renderer as? AppGridRenderer else { return nil }
                return renderer.pageView(forPage: identity.pageIndex)?.cell(at: identity.slotIndex)
            }
        )
        keyboard.onActivate = { [weak launchAdapter] identity in
            launchAdapter?.activate(identity)
        }
        self.keyboardController = keyboard
        self.launchAdapter = launchAdapter
        // T-1G-E：ESC 在 title/folder/selection 耗尽后 → hide（不吞 Tab）。
        keyboard.onEscapeExhausted = { [weak self] in
            _ = self?.activationComposition?.handleEscapeExhausted()
        }
        // 若 launcher 已创建（装配在窗口之前），补挂 preferredFirstResponder。
        launcherWindowController?.preferredFirstResponder = keyboard

        // 3e) Phase 1D：搜索装配（T-1D-E）。
        //     搜索 field/controller/presentation controller 接线进既有装配。
        //     presentation controller 由装配层提供（AppCatalogAssembly.searchPresentation，
        //     provider 已连接）；AppDelegate 负责接 search controller + surface 刷新回调。
        let presentation = assembly.searchPresentation
        presentation.itemsPerPage = surface.itemsPerPage
        // 搜索结果提交（同 revision 重载）→ surface.reloadCurrentPresentation()。
        presentation.onSearchResultCommitted = { [weak self] in
            self?.surface?.reloadCurrentPresentation()
        }
        // presentation controller 应用 catalog snapshot（搜索激活路径）→ 刷新 surface +
        // urlResolver（refresh controller 未参与时需自行更新）。搜索激活时按过滤后
        // presentationRecords 刷新（不覆盖 pageCount）；非搜索时对齐 update.plan.pageCount。
        presentation.onPresentationUpdate = { [weak self] update in
            guard let self, let assembly = self.assembly else { return }
            if let snapshot = assembly.dataSource.currentSnapshot {
                assembly.urlResolver.update(from: snapshot)
            }
            let searchActive = self.search?.presentation.currentQuery != nil
            self.applyPresentationUpdate(update, overridePageCount: !searchActive)
        }
        let search = AppSearchController(presentation: presentation,
                                         keyboardController: keyboard,
                                         surface: surface)
        // Command-F → 搜索框 first responder（responder 转移 seam）。
        // Phase 1F：搜索激活先 cancel 进行中的 drag（.searchActivated 统一出口）。
        keyboard.onSearchShortcut = { [weak self, weak search] in
            self?.dragCoordinator?.cancel(reason: .searchActivated)
            search?.activateSearch()
        }
        self.search = search

        // 3f) Phase 1E：folder 打开层 / 标题编辑 / 成员启动接线（T-1E-E）。
        //     folder 打开状态（会话内）→ 打开层视图 → 键盘控制器 folder 感知 seam。
        installFolderWiring(assembly: assembly, surface: surface,
                            keyboard: keyboard, launch: launch)

        // 3g) Phase 1F：drag UI 装配（T-1F-D1）。
        //     统一输入仲裁协调器 + 中性拖拽视觉；commit 经 onCommit seam 暂存会话内布局
        //     （T-1F-E 接 provider/persist；本阶段零磁盘写）。
        // 3g') Phase 1F：layout store（T-1F-D1-fix-e1）。生产实现 = LayoutStoreActor +
        //     Application Support 中性子目录（ADR-009 Q5）；目录解析失败 → 临时目录兜底
        //     （持久化路径仍存活，不崩溃）。enqueue 为 coalescing sink，不阻塞主线程。
        let storeDirectory = (try? ApplicationSupportLayoutStoreDirectory(
            subdirectoryName: "PagingPrototypeLayout").resolveStoreDirectory())
            ?? FileManager.default.temporaryDirectory
        self.layoutStore = LayoutStoreActor(storeDirectory: storeDirectory)
        installDragUI(surface: surface, assembly: assembly)
    }

    // MARK: - Phase 1E folder 接线（T-1E-E）

    /// 装配 folder 打开层 / 标题编辑 / 成员启动，并接线到键盘控制器与搜索控制器的模式 seam。
    /// - 成员启动复用 `AppLaunchController.handleCell`（合成 cell 绑定正确 revision；无并行启动路径）。
    /// - folder cell 绝不进入 app launch：`ActivationRouter` 分支 folder → open（T-1E-D 已接线）。
    /// - 标题编辑 first responder 经 `modeFirstResponderProvider` 参与 key-window 重建。
    @MainActor
    private func installFolderWiring(assembly: AppCatalogAssembly,
                                     surface: PagingSurface,
                                     keyboard: KeyboardFocusController,
                                     launch: AppLaunchController) {
        // folder 打开状态（会话内；成员每页数与 surface 对齐）。
        let folderOpenState = FolderOpenState(membersPerPage: surface.itemsPerPage)
        self.folderOpenState = folderOpenState

        // T-1E-folderlab-membercount-repair：folder cell 成员计数接线 —— 渲染器透传
        // assembly.provider.servedFolderSnapshot（与组合渲染同一 snapshot 源，FolderID 一致）。
        // 弱捕获 assembly 防引用环；nil → folder cell 显示中性符号 + 标题（成员计数 0）。
        assembly.renderer.folderSnapshotProvider = { [weak assembly] in
            assembly?.provider.servedFolderSnapshot
        }

        // T-1E-folder-open-repair-wiring：folder cell 左键点击 → 键盘焦点 + 打开 folder。
        // 复用 folderSnapshotProvider 同源渲染器 seam（AppGridRenderer.onFolderClick 透传每页 cell）。
        // 绝不进入 AppLaunchController（folder 身份被其 as? AppID 校验拒绝）。
        assembly.renderer.onFolderClick = { [weak self] folderID in
            self?.handleFolderCellClick(folderID)
        }

        // 打开层视图（T-1E-C）：成员图标经 IconPipeline 异步 + surfaceGeneration 门控。
        let overlay = FolderOverlayView(iconPipeline: assembly.iconPipeline, displayScale: 2)
        overlay.membersPerPage = folderOpenState.membersPerPage
        overlay.onActivateMember = { [weak self] appID in
            self?.launchMember(appID)
        }
        overlay.onRequestClose = { [weak self] in
            self?.closeFolder()
        }
        overlay.onMemberDragExitPanel = { [weak self, weak overlay] in
            guard let self, let overlay else { return }
            // 1) 折叠前：缓存剩余成员图标 + 再抓一份拖拽源位图。
            overlay.prepareMoveOutIconCache()
            self.dragCoordinator?.prepareAndElevateMoveOutPreview(above: overlay)
            // 2) 折叠面板，顶层网格露出来；透明 overlay 仍承接 mouse capture。
            overlay.setMoveOutPresentationCollapsed(true)
            self.showFolderMoveOutPreview(overlay)
            // 3) 几何宿主切到 surface（顶层蓝条坐标）；preview 已挂在 contentView 最顶层。
            self.dragCoordinator?.setVisualHost(self.surface)
            // 切宿主后再抬一次 preview，防止 setHost 把它迁回 surface 下面。
            self.dragCoordinator?.prepareAndElevateMoveOutPreview(above: overlay)
        }
        overlay.onInnerPageChange = { [weak self] page in
            self?.setFolderInnerPage(page)
        }
        self.folderOverlay = overlay

        // 标题编辑 first responder（T-1E-D）。
        let titleEditor = FolderTitleEditor()
        titleEditor.onCommit = { [weak self] title in
            self?.commitFolderTitle(title)
        }
        titleEditor.onCancel = { [weak self] in
            self?.cancelFolderTitle()
        }
        self.folderTitleEditor = titleEditor

        // 键盘控制器 folder 感知 seam（T-1E-D 声明；T-1E-E 接线）。
        keyboard.folderOpenStateProvider = { [weak self] in self?.folderOpenState }
        keyboard.onOpenFolder = { [weak self] identity in self?.openFolder(identity) }
        keyboard.onCloseFolder = { [weak self] in self?.closeFolder() }
        keyboard.onActivateMember = { [weak self] appID in self?.launchMember(appID) }
        keyboard.onInnerPageChange = { [weak self] page in self?.setFolderInnerPage(page) }
        keyboard.folderOverlayProvider = { [weak self] in self?.folderOverlay }
        keyboard.onTitleEditRequest = { [weak self] in self?.beginTitleEditing() }
        keyboard.onTitleCommit = { [weak self] title in self?.commitFolderTitle(title) }
        keyboard.onTitleCancel = { [weak self] in self?.cancelFolderTitle() }

        // 搜索控制器 key-window 重建模式 seam（标题编辑 > folder 打开 > 搜索 > 顶层）。
        search?.modeFirstResponderProvider = { [weak self] in
            guard let self else { return nil }
            if let editor = self.folderTitleEditor, editor.window != nil, editor.currentEditor() != nil {
                return editor
            }
            if self.folderOpenState?.isOpen == true {
                return self.keyboardController
            }
            return nil
        }
    }

    // MARK: - Phase 1F drag UI 装配（T-1F-D1）

    /// 装配统一输入仲裁协调器 + 中性拖拽视觉（§5.1–5.7）。
    /// - 布局：会话内布局（sessionLayout ?? catalog 呈现面构建）；commit → sessionLayout
    ///   （T-1F-E 以 store 替换；本阶段零磁盘写）。
    /// - 几何：topLevel → 当前页 cell frames（host 坐标系）；folder → 成员 frames + 顶层 frames。
    /// - 翻页：topLevel → KeyboardPageTurner（与键盘翻页同一入口）；folder → overlay 翻页。
    /// - click 识别抑制：仲裁窗口内禁用 surface 上既有 NSClickGestureRecognizer（防双重派发）。
    /// - drag 门：搜索激活 / 标题编辑中 → 整个 pointerDown 静默拒绝（含 Path B click
    ///   派发路径；Path A surface 识别器不受影响）。N2 修正（T-1F-B8-wave-c Stage 2）：
    ///   原注释「点击不受影响」与实现不符。依据：census s1 + harness 测试 6。
    @MainActor
    private func installDragUI(surface: PagingSurface, assembly: AppCatalogAssembly) {
        let coordinator = DragUISessionCoordinator(host: surface)
        DragUISessionCoordinator.shared = coordinator
        let pageTurner = KeyboardPageTurner(surface: surface)

        coordinator.layoutProvider = { [weak self] in
            guard let self else { return nil }
            if let sessionLayout = self.sessionLayout { return sessionLayout }
            return DragUISessionLayoutFactory.makeSessionLayout(
                catalog: self.assembly?.provider.servedSnapshot,
                entries: self.assembly?.provider.presentationEntries ?? [],
                folderSnapshot: self.assembly?.provider.servedFolderSnapshot
            )
        }
        coordinator.catalogGenerationProvider = { [weak assembly] in
            assembly?.provider.servedRevision ?? 0
        }
        coordinator.catalogSnapshotProvider = { [weak assembly] in
            assembly?.provider.servedSnapshot
        }
        coordinator.geometryProvider = { [weak self] scope in
            self?.makeDragGeometry(scope: scope)
        }
        coordinator.onCommit = { [weak self] newLayout in
            guard let self else { return }
            // Folder 成员成功移出后立即关闭打开层。内部重排不会减少成员数，
            // 因而保持 overlay 打开；移到顶层、移入其他 folder 或触发 dissolve
            // 都会使当前打开 folder 的成员数减少（或记录消失），应走统一 closeFolder 路径。
            let shouldCloseOpenFolder: Bool
            if let state = self.folderOpenState,
               let folderID = state.openFolderID {
                let committedMemberCount = newLayout.folder(id: folderID)?.members.count ?? 0
                shouldCloseOpenFolder = committedMemberCount < state.memberCount
            } else {
                shouldCloseOpenFolder = false
            }
            // T-1F-D1-fix-e1：commit 必须落到呈现面（原实现只暂存 sessionLayout → 无可见效果）。
            // 1) 会话内布局（layoutProvider 一致性；点击/后续 drag 仍按新布局解析）。
            self.sessionLayout = newLayout
            // 代理要保持到正式 presentation refresh 完成；closeFolder 会同步清理 overlay，
            // 因而先暂存并在 closeFolder 后立即复挂（同一主线程事务内无可见闪回）。
            let moveOutOverlay = shouldCloseOpenFolder ? self.folderOverlay : nil
            let moveOutProxyHost = moveOutOverlay?.moveOutRemainingAppProxyHost
            let moveOutProxy = moveOutOverlay?.moveOutRemainingAppProxy
            let moveOutProxyFrame = moveOutProxyHost?.frame
            if shouldCloseOpenFolder {
                self.closeFolder()
                if let moveOutProxyHost, let moveOutProxyFrame, let surface = self.surface {
                    if let moveOutProxy {
                        moveOutProxyHost.addSubview(moveOutProxy)
                        moveOutProxy.frame = moveOutProxyHost.bounds
                    }
                    surface.addSubview(moveOutProxyHost, positioned: .above, relativeTo: nil)
                    moveOutOverlay?.reattachMoveOutRemainingAppProxyHost(moveOutProxyHost, frame: moveOutProxyFrame)
                }
            }
            // 2) 应用到 provider/渲染（布局顺序 → presentationEntries；folder 集合 → snapshot）。
            guard let provider = self.assembly?.provider, let surface = self.surface else {
                moveOutProxyHost?.removeFromSuperview()
                return
            }
            let update = provider.applyCommittedLayout(newLayout,
                                                       atCurrentPage: surface.core.committedPage,
                                                       itemsPerPage: surface.itemsPerPage)
            // 3) 呈现刷新（refreshPresentation + setPageCount → live hosts 重渲染 + telemetry +
            //    焦点布局重建；同 revision 下 setPageCount 仍全量刷新 live hosts）。
            if let update {
                self.applyPresentationUpdate(update, overridePageCount: true)
            }
            // 3b) folder 保持打开时：把 openEntry / overlay 与刚提交的 servedFolderSnapshot
            //     对齐。否则 applyCommittedLayout 已写入新成员序，但 overlay 仍持有打开时
            //     的旧 FolderEntry → 用户看到"拖拽有预览、放下无效果"（folder 内重排）。
            if !shouldCloseOpenFolder {
                self.resyncOpenFolderAfterLayoutCommit()
            }
            if shouldCloseOpenFolder {
                moveOutOverlay?.clearMoveOutRemainingAppProxy()
                // 防止 overlay 在 closeFolder/refresh 期间已丢失 owner，仍确保 host 不残留。
                moveOutProxyHost?.removeFromSuperview()
            }
            // 4) 异步持久化（coalescing sink；绝不阻塞主线程）。
            Task { [weak self] in
                guard let self else { return }
                await self.layoutStore?.enqueue(newLayout)
            }
        }
        coordinator.onCellClick = { [weak self] cell in
            self?.handleDragCellClick(cell)
        }
        coordinator.onOverlayBlankClick = { [weak self] in
            self?.closeFolder()
        }
        coordinator.topLevelPageTurn = { direction, timestamp in
            pageTurner.turn(direction: direction, timestamp: timestamp)
        }
        coordinator.folderPageTurn = { [weak self] delta in
            guard let overlay = self?.folderOverlay else { return }
            if delta < 0 { overlay.prevPage() } else { overlay.nextPage() }
        }
        coordinator.clickRecognitionSuppressor = { [weak surface] enabled in
            guard let surface else { return }
            // T-1F-B9-wave-b Stage 1 census（s13）：抑制闭包两向计数（仅计数，零行为变更）。
            // BUG9-REPORT §2 R2：抑制状态原只能在 pointerDown 入口（s9）间接观测——入口不跑
            // 即恒盲。本计数点在 `guard let surface` 之后 = 只计实际作用于 surface 识别器
            // 集合的 toggle。coordinator 语义：enabled=false = 抑制启用（仲裁窗口开启）→
            // s13a_enable；enabled=true = 抑制恢复（endSession）→ s13b_disable。
            ClickCensus.hit(enabled ? ClickCensus.Sink.suppressionDisable
                                    : ClickCensus.Sink.suppressionEnable)
            for recognizer in surface.gestureRecognizers where recognizer is NSClickGestureRecognizer {
                recognizer.isEnabled = enabled
            }
        }
        coordinator.dragGate = { [weak self] in
            guard let self else { return false }
            if self.search?.isSearchActive == true { return false }
            if self.isTitleEditing { return false }
            return true
        }
        coordinator.onSessionStateChange = { [weak self] state in
            guard state == .idle,
                  let self,
                  self.folderOpenState?.isOpen == true,
                  let overlay = self.folderOverlay,
                  overlay.isMoveOutPresentationCollapsed else { return }
            // no-op / reject / cancel：没有发生 move-out commit，恢复原 Folder。
            overlay.clearMoveOutRemainingAppProxy()
            overlay.setMoveOutPresentationCollapsed(false)
            self.dragCoordinator?.setVisualHost(overlay)
        }
        self.dragCoordinator = coordinator
    }

    /// 在 move-out 视觉折叠阶段，用唯一剩余成员覆盖真实顶层 Folder cell。
    /// 仅添加 transient 代理；真实 page/cell binding 与拖拽几何保持不变。
    @MainActor
    private func showFolderMoveOutPreview(_ overlay: FolderOverlayView) {
        guard let surface, let assembly,
              let folderID = folderOpenState?.openFolderID,
              let pageView = assembly.renderer.pageView(forPage: surface.core.committedPage) else {
            return
        }
        let folderCell = (0..<pageView.cellCount).compactMap { pageView.cell(at: $0) }
            .first { ($0.bindingToken?.appID as? FolderID) == folderID }
        guard let folderCell else { return }
        let frame = folderCell.convert(folderCell.bounds, to: surface)
        overlay.showMoveOutRemainingAppProxy(in: surface, frame: frame)
    }

    /// 拖拽几何（host 坐标系）：topLevel → 当前页 cell frames；folder → 成员 frames + 顶层 frames。
    ///
    /// **坐标系契约（BUG10 缺陷 B，方案 B1；FIX-PROMPT §3.3）**：
    /// - `host` = `dragCoordinator.visualHost`，与 preview/指示 attach 宿主**同源**
    ///   （refreshFolderOverlay 经 setVisualHost 同一动作切换两者）。
    /// - topLevel scope：host = surface；`itemFrames` = 顶层当前页帧（surface 系）。
    /// - folder scope：host = overlay；`itemFrames`（成员帧）与 `topLevelFrames`（顶层帧）
    ///   **均 convert 到 overlay 系**（memberDragItemFrames(convertedTo:)/dragItemFrames(convertedTo:)
    ///   的 host 参数即当前 visualHost）——两帧列表同系，move-out 时 preview 与顶层蓝条
    ///   同系不跳变。成员帧不注记分页（folder 内 insertion 不乘外层 itemsPerPage）；
    ///   顶层帧注记顶层 committedPage（绝不复用 geometry.page = innerPage）。
    @MainActor
    private func makeDragGeometry(scope: DragScope) -> DragGeometry? {
        guard let surface, let assembly, let host = dragCoordinator?.visualHost else { return nil }
        let catalog = assembly.provider.servedSnapshot
        switch scope {
        case .topLevel:
            let page = surface.core.committedPage
            guard let pageView = assembly.renderer.pageView(forPage: page) else { return nil }
            // BUG7 wave-b：顶层当前页帧注入分页注记（committedPage, surface.itemsPerPage）
            // → classifier 在 intent 产出边界换算 globalIndex = page*itemsPerPage + localIndex。
            let frames = pageView.dragItemFrames(convertedTo: host, catalog: catalog)
                .map { $0.annotated(pageIndex: page, itemsPerPage: surface.itemsPerPage) }
            return DragGeometry(itemFrames: frames,
                                containerWidth: Double(host.bounds.width),
                                page: page, pageCount: surface.core.pageCount,
                                itemsPerPage: surface.itemsPerPage)
        case .folder(let folderID):
            guard let overlay = folderOverlay, let state = folderOpenState, state.isOpen(folderID) else { return nil }
            let memberFrames = overlay.memberDragItemFrames(convertedTo: host, catalog: catalog)
            let page = state.innerPage
            let pageCount = state.innerPageCount
            let topLevelFrames: [DragItemFrame]
            if let pageView = assembly.renderer.pageView(forPage: surface.core.committedPage) {
                // BUG7 wave-b 页号陷阱：folder scope 的 geometry.page = innerPage，
                // move-out 顶层落点换算必须用顶层 committedPage —— 注记显式携带
                // 顶层页号，绝不复用 innerPage。成员帧不注记（folder 内 insertion
                // 不乘外层 itemsPerPage）。
                let topPage = surface.core.committedPage
                topLevelFrames = pageView.dragItemFrames(convertedTo: host, catalog: catalog)
                    .map { $0.annotated(pageIndex: topPage, itemsPerPage: surface.itemsPerPage) }
            } else {
                topLevelFrames = memberFrames
            }
            return DragGeometry(itemFrames: memberFrames, topLevelFrames: topLevelFrames,
                                containerWidth: Double(host.bounds.width),
                                page: page, pageCount: pageCount,
                                itemsPerPage: surface.itemsPerPage)
        }
    }

    /// drag 仲裁后的 click 派发（mouse-up 未过阈值；T-1F-D1）：
    /// - folder cell → 打开 folder（复用 handleFolderCellClick；绝不进入 app launch）。
    /// - app cell（顶层/成员统一；T-1F-B7-wave-c 缺陷 3 修复）→ launchMember 合成 cell
    ///   路径：身份取自 cell.bindingToken?.appID，启动用**当前 servedRevision** 的合成
    ///   cell，绝不信任提交重渲染后的 live token（建夹后顶层单击曾静默丢失）。
    @MainActor
    private func handleDragCellClick(_ cell: AppGridCellView) {
        if cell.isFolderCell {
            if let folderID = cell.bindingToken?.appID as? FolderID {
                handleFolderCellClick(folderID)
            } else {
                // T-1F-B8-wave-c census（S6）：folder cast 静默失败计数点（仅计数）。
                ClickCensus.hit(ClickCensus.Sink.handleClickSilent)
            }
            return
        }
        if let appID = cell.bindingToken?.appID as? AppID {
            launchMember(appID)
        } else {
            // T-1F-B8-wave-c census（S6）：app cast 静默失败计数点（仅计数）。
            ClickCensus.hit(ClickCensus.Sink.handleClickSilent)
        }
    }

    // MARK: - Phase 1D 搜索装配辅助（T-1D-E）

    /// 呈现提交统一处理：刷新 surface + telemetry + 焦点模型迁移。
    /// - Parameter overridePageCount: 是否以 update.plan.pageCount 覆盖 pageCount。
    ///   非搜索路径（catalog refresh）为 true（对齐非默认 --items-per-page）；
    ///   搜索激活路径为 false（按过滤后 presentationRecords 的 servedPageCount 刷新）。
    @MainActor
    private func applyPresentationUpdate(_ update: AppGridPresentationUpdate, overridePageCount: Bool) {
        guard let surface = self.surface, let assembly = self.assembly else { return }
        // Phase 1F：新呈现提交 → cancel 进行中的 drag（.catalogRefresh 统一出口；idle 时 no-op）。
        dragCoordinator?.cancel(reason: .catalogRefresh)
        surface.refreshPresentation()
        if overridePageCount {
            // 优先 servedPageCount（与 presentationEntries 同源）；避免 plan/pageCount 与已提交组合漂移。
            let pages = assembly.provider.servedPageCount ?? update.plan.pageCount
            surface.setPageCount(pages)
        }
        surface.needsLayout = true
        surface.layoutSubtreeIfNeeded()
        self.telemetryBridge?.recordCatalogPresentation(update, assembly: assembly)
        // Phase 1C：新 revision 呈现 → 焦点模型迁移 + 重应用视觉（settle 完成/中断后
        // 焦点始终指向已提交/已显示页面，Reviewer F1 调和）。
        // 焦点布局基于顶层组合（presentationEntries；搜索激活时 = 结果 .app 条目，语义不变）。
        if let base = assembly.provider.servedSnapshot {
            let layout = AppGridFocusLayout.build(from: base,
                                                  composition: assembly.provider.presentationEntries,
                                                  itemsPerPage: surface.itemsPerPage)
            self.keyboardController?.applyLayout(layout)
        }
    }

    /// idle 边界统一提交：搜索提交优先（处理 pending catalog snapshot 重跑查询 +
    /// pending search result），刷新控制器随后（无 pending catalog snapshot 时 no-op），
    /// 最后做键盘跨页 settle 调和。
    @MainActor
    private func applyPendingAtIdleBoundary() {
        guard let surface = self.surface, let assembly = self.assembly else { return }
        // Phase 1F：idle 边界提交 → cancel 进行中的 drag（.catalogRefresh 统一出口；idle 时 no-op）。
        dragCoordinator?.cancel(reason: .catalogRefresh)
        // 搜索提交优先：presentation controller 的 applyPendingAtIdleBoundary 会先应用
        // pending catalog snapshot（若有），再在新 base 上重跑当前查询并提交搜索结果。
        // 若刷新控制器先应用，provider.applyPending 会重置 presentationRecords 并清空
        // pendingSearchResult，导致搜索查询丢失 —— 故搜索必须先行。
        self.search?.commitPendingAtIdleBoundary()
        // Phase 1E：新 catalog base 提交后重建 folder 组合（优先级：catalog > folder > search）。
        // 生成结果暂存为 pendingFolderSnapshot，由下方刷新控制器 applyPending 原子提交。
        assembly.rebuildFolderCompositionIfNeeded()
        // 刷新控制器：无 pending catalog snapshot 时 no-op（搜索激活时已由 presentation 处理）；
        // 有 pending folder snapshot 时在此原子提交（catalog + folder 同界）。
        _ = assembly.refreshController.applyPendingAtIdleBoundary(currentPage: surface.core.committedPage)
        self.keyboardController?.reconcileSettledCrossPage(committedPage: surface.core.committedPage)
    }

    // MARK: - Phase 1E folder 打开 / 关闭 / 成员启动（T-1E-E）

    /// 打开 folder（顶层 folder 激活）：解析 FolderID → 打开状态 → 配置打开层。
    @MainActor
    private func openFolder(_ identity: AppGridFocusIdentity) {
        guard case .folder(let folderID)? = identity.entryIdentity else { return }
        openFolder(folderID: folderID)
    }

    /// 打开 folder（FolderID 直接入口；folder cell 左键点击复用同一打开路径）。
    @MainActor
    private func openFolder(folderID: FolderID) {
        guard let assembly, let folderOpenState else { return }
        guard let entry = assembly.provider.servedFolderSnapshot?.entry(for: folderID) else { return }
        folderOpenState.open(entry)
        refreshFolderOverlay()
    }

    /// folder cell 左键点击（T-1E-folder-open-click-focus-repair）：
    /// 左键点击 folder 只打开 folder，**不**设置键盘焦点 —— 鼠标交互不显示键盘焦点框
    /// （标准 macOS 行为）。键盘导航（箭头选中 → Return）仍走 KeyboardFocusController 的
    /// 既有路径，焦点框保持为键盘导航的正常反馈。
    /// T-1E-folder-mouse-open-repair：点击经键盘 seam `openFolderFromClick` 打开 —— 清除
    /// 外层焦点视觉（蓝框不残留）+ 初始化内部焦点 + 立即显示内部成员焦点环（左右键可用）。
    /// 绝不进入 AppLaunchController（folder 身份被其 as? AppID 拒绝）。
    @MainActor
    private func handleFolderCellClick(_ folderID: FolderID) {
        keyboardController?.openFolderFromClick(folderID)
    }

    /// 关闭 folder（ESC / Command-F / 空白单击 onRequestClose / overlay clear 共用）。
    ///
    /// T-1E-E handoff（T-1E-D repair）：**所有** folder-close 路径都必须结束标题编辑，
    /// 避免 stale `isEditingTitle` 导致搜索退出后箭头/Return 被吞（导航死锁）。
    @MainActor
    private func closeFolder() {
        // 关闭/取消前先移除 move-out transient 代理，避免它在 surface 上残留。
        folderOverlay?.clearMoveOutRemainingAppProxy()
        // Phase 1F：关闭 folder → cancel 进行中的 drag（.overlayClosed 统一出口；idle 时 no-op）。
        dragCoordinator?.cancel(reason: .overlayClosed)
        keyboardController?.endTitleEditing()
        isTitleEditing = false
        folderOpenState?.close()
        // BUG10 缺陷 B（方案 B1）：经 refreshFolderOverlay 统一出口移除 overlay 并
        // 把视觉宿主切回 surface（openEntry 已 nil → nil 分支）——宿主切换唯一驱动点。
        refreshFolderOverlay()
        // T-1F-B10-wave-a forensics census（s16）：closeFolder 执行后 overlay 的
        // superview 状态位（仅计数，零行为变更）。判别「移除成功但仍在命中」vs
        // 「根本没移除」：_sv1（superview == nil）= 移除执行到位；_sv0 = overlay
        // 仍挂在视图树（候选：被重挂/移除竞争）。sink 名只携带布尔位，无身份。
        if let overlay = folderOverlay {
            ClickCensus.hit(ClickCensus.Sink.closeFolderOverlayState(
                superviewIsNil: overlay.superview == nil))
        }
    }

    /// 成员/顶层 app 启动共用路径（T-1F-B7-wave-c）：解析 AppID → 以**当前 servedRevision**
    /// 合成 launch cell（makeMemberLaunchCell，不信任重建后 live token）→ 复用
    /// `AppLaunchController.handleCell` 管线（无并行启动路径）。
    @MainActor
    private func launchMember(_ appID: AppID) {
        guard let launchController, let assembly else {
            // T-1F-B8-wave-c census（S7）：guard 静默计数点（仅计数）。
            ClickCensus.hit(ClickCensus.Sink.launchMemberSilent)
            return
        }
        guard let served = assembly.provider.servedRevision else {
            // T-1F-B8-wave-c census（S7）：guard 静默计数点（仅计数）。
            ClickCensus.hit(ClickCensus.Sink.launchMemberSilent)
            return
        }
        let cell = AppCatalogAssembly.makeMemberLaunchCell(appID: appID, servedRevision: served)
        _ = launchController.handleCell(cell)
    }

    /// 内部页变更：写回打开状态 + 重配打开层。
    @MainActor
    private func setFolderInnerPage(_ page: Int) {
        folderOpenState?.setInnerPage(page)
        refreshFolderOverlay()
    }

    /// drag commit 后（folder 仍打开）：用最新 servedFolderSnapshot 替换 openEntry，
    /// 并经 refreshFolderOverlay 重配成员网格。成员数减少的移出路径走 closeFolder，
    /// 不经此方法。
    @MainActor
    private func resyncOpenFolderAfterLayoutCommit() {
        guard let state = folderOpenState,
              let folderID = state.openFolderID,
              let updated = assembly?.provider.servedFolderSnapshot?.entry(for: folderID) else {
            return
        }
        // 同内容（含成员序）→ updateOpenEntry 仍 bump generation；refresh 幂等短路
        // （entry==currentEntry）避免无意义图标重请求。成员序变化 → overlay 重绑。
        state.updateOpenEntry(updated)
        refreshFolderOverlay()
    }

    /// 重配打开层：有打开条目 → configure + 挂入容器（覆盖全表面含搜索框）；无 → 清空 + 移除。
    /// BUG10 缺陷 B（方案 B1）：**宿主切换唯一驱动点** —— folder 打开 → 视觉宿主切为
    /// overlay（preview 不再被遮罩盖住）；folder 关闭 → 切回 surface（顶层拖拽零回归）。
    /// 切换经 `dragCoordinator.setVisualHost` 同一动作同步 `visualHost`（指针坐标系）与
    /// `visuals` attach 宿主（preview/指示坐标系）——两坐标系同源，preview 不偏移。
    @MainActor
    private func refreshFolderOverlay() {
        guard let folderOpenState, let folderOverlay else { return }
        guard let entry = folderOpenState.openEntry else {
            folderOverlay.clearContent()
            folderOverlay.removeFromSuperview()
            dragCoordinator?.setVisualHost(surface)
            return
        }
        let reduceMotion = surface?.reduceMotionProvider?() ?? false
        folderOverlay.configure(entry: entry, innerPage: folderOpenState.innerPage,
                                reduceMotion: reduceMotion) { [weak self] appID in
            self?.memberName(for: appID)
        }
        if folderOverlay.superview == nil {
            let host = container ?? surface
            host?.addSubview(folderOverlay)
            folderOverlay.frame = host?.bounds ?? .zero
            folderOverlay.autoresizingMask = [.width, .height]
        }
        dragCoordinator?.setVisualHost(folderOverlay)
    }

    /// 成员显示名（中性；nil = 不在当前 catalog → 通用占位）。
    @MainActor
    private func memberName(for appID: AppID) -> String? {
        guard let assembly else { return nil }
        return assembly.provider.servedSnapshot?.records.first { $0.id == appID }?.displayName
    }

    /// 进入标题编辑：编辑器成为 first responder + 键盘控制器置位编辑态。
    /// Phase 1F：标题编辑开始 → cancel 进行中的 drag（.titleEditBegan 统一出口）。
    @MainActor
    private func beginTitleEditing() {
        guard let folderTitleEditor, let window = folderTitleEditor.window else { return }
        dragCoordinator?.cancel(reason: .titleEditBegan)
        isTitleEditing = true
        keyboardController?.beginTitleEditing()
        window.makeFirstResponder(folderTitleEditor)
    }

    /// 提交标题：结束编辑（标题文本绝不进入 telemetry/log/stdout/signpost/profile/report）。
    @MainActor
    private func commitFolderTitle(_ title: String) {
        keyboardController?.endTitleEditing()
        isTitleEditing = false
        // 本阶段标题编辑为会话内演示；提交结果不落盘、不进入任何遥测/日志。
    }

    /// 取消标题编辑：结束编辑。
    @MainActor
    private func cancelFolderTitle() {
        keyboardController?.endTitleEditing()
        isTitleEditing = false
    }

    /// 搜索框 overlay 几何：顶部居中，距顶 12pt。
    private func searchFieldFrame(in bounds: NSRect) -> NSRect {
        let width: CGFloat = 300
        let height: CGFloat = 28
        let x = bounds.midX - width / 2
        let y = bounds.maxY - height - 12
        return NSRect(x: x, y: y, width: width, height: height)
    }

    // MARK: - GUI 自驱性能旅程（PAGING_PROTOTYPE_GUI_SELFDRIVE=1）

    private func startSelfDriveTour() {
        guard let surface else { return }
        let toleranceMS = options.frameTimerToleranceMS ?? 0.0
        print(String(format: "SELFDRIVE: frame source = runloop Timer 60Hz; tolerance=%.3fms; not vsync-aligned", toleranceMS))
        // 帧计数（与 bridge 的 onAnimationFrame 组合，不覆盖它）。
        let existingFrameHook = surface.onAnimationFrame
        surface.onAnimationFrame = { [weak self] interval in
            existingFrameHook?(interval)
            self?.selfDriveFrameCount += 1
        }
        let flings = 40
        for i in 0..<flings {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6 + Double(i) * 0.4) { [weak self] in
                guard let self, let surface = self.surface, !surface.isTearingDown else { return }
                let t = ProcessInfo.processInfo.systemUptime
                let forward = i % 4 != 3
                let deltaX: CGFloat = forward ? -500 : 500
                surface.simulateScrollInput(phase: .began, momentumPhase: [], scrollingDeltaX: deltaX, scrollingDeltaY: 0, isDirectionInverted: true, timestamp: t)
                surface.simulateScrollInput(phase: .changed, momentumPhase: [], scrollingDeltaX: deltaX, scrollingDeltaY: 0, isDirectionInverted: true, timestamp: t + 0.01)
                surface.simulateScrollInput(phase: .ended, momentumPhase: [], scrollingDeltaX: 0, scrollingDeltaY: 0, isDirectionInverted: true, timestamp: t + 0.01)
                surface.simulateScrollInput(phase: [], momentumPhase: [], scrollingDeltaX: 0, scrollingDeltaY: 0, isDirectionInverted: true, timestamp: t + 0.01)
            }
        }
        let finishDelay = 0.6 + Double(flings) * 0.4 + 2.5
        DispatchQueue.main.asyncAfter(deadline: .now() + finishDelay) { [weak self] in
            guard let self else { return }
            self.printSelfDriveStats()
            self.teardownAll()
            NSApp.terminate(nil)
        }
    }

    private func printSelfDriveStats() {
        guard let surface else { return }
        print("SELFDRIVE stats: flings=40 committed=\(surface.core.commitCount) stales=\(surface.core.staleRejectionCount) live=\(surface.liveHostCount) pool=\(surface.poolHostCount) layouts=\(surface.layoutPerformedCount) telemetryEvents=\(telemetryBridge?.session.recordedEventCount ?? 0)")
    }

    // MARK: - 最小菜单（T-1G-B：Option B panel；不再提供 native 全屏切换）

    /// 最小菜单（App 退出 Cmd+Q + View 显示/隐藏 Ctrl+Cmd+F）。
    /// T-1G-C status item 提供主 Show/Hide；此处保留宿主期手动 toggle 缝。
    private func installLauncherMenu() {
        let mainMenu = NSMenu()
        let appMenuItem = NSMenuItem()
        mainMenu.addItem(appMenuItem)
        let appMenu = NSMenu()
        appMenu.addItem(withTitle: "退出 Paging Prototype", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        appMenuItem.submenu = appMenu

        let viewMenuItem = NSMenuItem()
        mainMenu.addItem(viewMenuItem)
        let viewMenu = NSMenu(title: "视图")
        let toggleItem = NSMenuItem(
            title: "显示/隐藏启动器",
            action: #selector(toggleLauncherPresentation(_:)),
            keyEquivalent: "f"
        )
        toggleItem.keyEquivalentModifierMask = [.command, .control]
        viewMenu.addItem(toggleItem)
        viewMenuItem.submenu = viewMenu
        NSApp.mainMenu = mainMenu
    }

    @objc private func toggleLauncherPresentation(_ sender: Any?) {
        MainActor.assumeIsolated {
            guard let launcher = launcherWindowController else { return }
            let screen = LauncherTargetScreenResolver.resolve()
            _ = launcher.handle(.toggle, source: .testHarness, targetScreen: screen)
        }
    }

    // MARK: - Activation composition（T-1G-E）

    /// 组合根：prefs → shortcut/hot-corner/four-finger/session；全部回调进同一 launcher。
    @MainActor
    private func installActivationComposition(launcher: LauncherWindowController) {
        let store = UserDefaultsActivationPreferencesStore()
        self.activationPreferencesStore = store
        let preferences: ActivationPreferences
        if let store {
            switch store.load() {
            case .loaded(let prefs):
                preferences = prefs
            case .futureSchema:
                preferences = ActivationPreferences()
            }
        } else {
            preferences = ActivationPreferences()
        }

        let hotCorner = HotCornerMonitor(
            pointerLocator: NSEventPointerLocator(),
            geometryProvider: NSScreenGeometryProvider(),
            scheduler: MainRunLoopHotCornerScheduler()
        )
        let composition = ActivationComposition(
            launcher: launcher,
            shortcutRegistrar: CarbonGlobalShortcutRegistrar(),
            hotCornerMonitor: hotCorner,
            sessionObserver: WorkspaceSessionObserver(),
            pinchClock: PinchSystemClock(),
            onRequestTerminate: { NSApp.terminate(nil) }
        )
        composition.onPrepareHide = { [weak self] in
            self?.prepareTransientCancellationForHide()
        }
        self.activationComposition = composition

        // four-finger：默认 userEnabled=true；后端 start 仅在 prefs 开启时（Enabled ≠ Ready）。
        print("paging-fourfinger-pref: enabled=\(preferences.fourFingerActivationEnabled)")
        fflush(stdout)
        if preferences.fourFingerActivationEnabled {
            let backend = MultitouchSupportBackend()
            composition.attachTouchProvider(backend, userEnabled: true)
            // 启动细节稍后打印（dlopen/设备注册是异步路径）。
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                print("paging-fourfinger-backend: state=\(backend.state) started=\(backend.isStarted) detail=\(backend.lastStartDetail) delivered=\(backend.deliveredFrameCount) raw=\(backend.rawCallbackCount) rejected=\(backend.rejectedFrameCount)")
                fflush(stdout)
            }
            // 捏合诊断：每 2s 打一次中性计数（确认触控回调是否到达）。
            let diagBackend = backend
            Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { timer in
                let raw = diagBackend.rawCallbackCount
                let delivered = diagBackend.deliveredFrameCount
                if raw > 0 || delivered > 0 {
                    print("paging-fourfinger-tick: raw=\(raw) delivered=\(delivered) rejected=\(diagBackend.rejectedFrameCount) state=\(diagBackend.state)")
                    fflush(stdout)
                }
                if !diagBackend.isStarted {
                    timer.invalidate()
                }
            }
        } else {
            print("paging-fourfinger-backend: skipped (pref disabled)")
            fflush(stdout)
        }
        composition.applyPreferences(preferences)
        composition.startSessionObserver()

        // Phase 1H：Settings 协调器（Fake 永不经此路径；生产 SMAppService，默认 Off，启动不自动 enable）。
        let loginService: any LaunchAtLoginServicing = SMAppServiceLaunchAtLoginService()
        self.launchAtLoginService = loginService
        let settingsStore: any ActivationPreferencesPersisting
        if let store {
            settingsStore = store
        } else {
            // suite 创建失败：内存占位 store（只服务 Settings 会话；不碰标准 defaults）。
            settingsStore = InMemoryActivationPreferencesStore(initial: preferences)
        }
        let coordinator = ActivationSettingsCoordinator(
            store: settingsStore,
            loginService: loginService,
            initialCommitted: preferences,
            applyPreferences: { [weak composition] prefs in
                composition?.applyPreferences(prefs)
            },
            setStatusItemVisible: { [weak self] show in
                self?.applyStatusItemVisibility(show)
            },
            fourFingerReadinessProvider: { [weak composition] in
                ActivationSettingsFourFingerReadiness.text(from: composition)
            }
        )
        self.activationSettingsCoordinator = coordinator
    }

    /// 启动器主面板右上角小齿轮：打开激活设置（单实例）。
    @MainActor
    private func installLauncherSettingsButton(in container: NSView) {
        let size = LaunchcopyVisualTokens.settingsButtonSize
        let inset = LaunchcopyVisualTokens.settingsButtonInset
        let button = NSButton(frame: NSRect(
            x: container.bounds.width - inset - size,
            y: container.bounds.height - inset - size,
            width: size,
            height: size
        ))
        button.bezelStyle = .regularSquare
        button.isBordered = false
        button.wantsLayer = true
        button.layer?.cornerRadius = LaunchcopyVisualTokens.chromeCornerRadius
        let policy = LaunchcopyMaterialPolicy()
        button.layer?.backgroundColor = LaunchcopyVisualTokens.chromeFill(policy: policy).cgColor
        let config = NSImage.SymbolConfiguration(pointSize: 16, weight: .medium)
        button.image = NSImage(systemSymbolName: "gearshape", accessibilityDescription: "设置")?
            .withSymbolConfiguration(config)
        button.image?.isTemplate = true
        button.contentTintColor = .white
        button.setAccessibilityLabel("设置")
        button.setAccessibilityRole(.button)
        button.toolTip = "设置"
        // 供空白点击判定识别：命中此按钮时必须放行，不能当空白隐藏。
        button.identifier = NSUserInterfaceItemIdentifier("launchcopy.launcherSettingsButton")
        button.target = self
        button.action = #selector(openActivationSettingsFromLauncher(_:))
        // 非 flipped：贴右上角。
        button.autoresizingMask = [.minXMargin, .minYMargin]
        container.addSubview(button)
        self.launcherSettingsButton = button
    }

    @MainActor
    private func refreshWallpaperBackdrop(for window: NSWindow) {
        wallpaperBackdrop?.layoutToHost()
        wallpaperBackdrop?.refresh(for: window.screen ?? NSScreen.main, policy: LaunchcopyMaterialPolicy())
    }

    @objc private func openActivationSettingsFromLauncher(_ sender: Any?) {
        MainActor.assumeIsolated {
            // 齿轮切换：已打开 → 关掉；未打开 → 打开。
            if activationSettingsCoordinator?.isSettingsVisible == true {
                activationSettingsCoordinator?.hideSettings()
                return
            }
            activationSettingsCoordinator?.showSettings()
            if let settingsWindow = ActivationSettingsWindowController.shared?.window {
                settingsWindow.makeKeyAndOrderFront(nil)
                NSApp.activate(ignoringOtherApps: true)
            }
        }
    }

    /// Phase 1H：Settings 切换「状态菜单显示」后安装/拆除 status item（可发现恢复路径仍保留 Dock reopen）。
    @MainActor
    private func applyStatusItemVisibility(_ show: Bool) {
        if show {
            if statusItemController?.isInstalled != true {
                if let launcher = launcherWindowController {
                    installStatusItem(launcher: launcher)
                }
            }
        } else {
            statusItemController?.teardown()
            statusItemController = nil
        }
    }

    /// ADR-011 Q7：hide 前取消 drag/title/folder/search 瞬态（不 teardown 服务）。
    @MainActor
    private func prepareTransientCancellationForHide() {
        dragCoordinator?.cancel(reason: .windowResign)
        if isTitleEditing {
            cancelFolderTitle()
        }
        if folderOpenState?.isOpen == true {
            closeFolder()
        }
        if search?.isSearchActive == true {
            search?.exitSearchAndRestoreFocus()
        }
        keyboardController?.endTitleEditing()
    }

    // MARK: - Status item host（T-1G-C / T-1G-E）

    /// 安装菜单栏入口：命令转发到同一 `LauncherWindowController`；Quit → composition；失败不崩溃。
    @MainActor
    private func installStatusItem(launcher: LauncherWindowController) {
        let showStatusItem: Bool
        if let store = activationPreferencesStore {
            switch store.load() {
            case .loaded(let prefs):
                showStatusItem = prefs.settings.showStatusItem
            case .futureSchema:
                showStatusItem = true
            }
        } else {
            showStatusItem = ActivationSettings().showStatusItem
        }
        let controller = StatusItemController(
            visibilityProvider: { [weak launcher] in
                launcher?.coordinator.committedVisibility ?? false
            },
            targetScreenProvider: {
                LauncherTargetScreenResolver.resolve()
            },
            onCommand: { [weak self, weak launcher] command, source, screen in
                guard let launcher else { return }
                if command == .quit {
                    // StatusItemController 随后仍会 terminateApp；此处只推进 coordinator。
                    _ = launcher.quit()
                    return
                }
                if command == .hide {
                    self?.prepareTransientCancellationForHide()
                }
                _ = launcher.handle(command, source: source, targetScreen: screen)
                self?.activationComposition?.hotCornerMonitor.setLauncherVisible(
                    launcher.coordinator.committedVisibility
                )
            },
            onActivationSettings: { [weak self] in
                self?.activationSettingsCoordinator?.showSettings()
            }
        )
        // Quit：StatusItem 先 onCommand(.quit) 再 terminateApp → applicationWillTerminate
        // 走 composition.handleApplicationWillTerminate + teardownAll。
        controller.install(showStatusItem: showStatusItem)
        self.statusItemController = controller
        if controller.installFailed {
            print("paging-status-item: install failed (degraded; Dock reopen / other entries remain)")
            fflush(stdout)
        }
    }

    // MARK: - Dock reopen（T-1G-C）

    /// Dock 图标点击：hidden→show；visible→makeKey；永不第二窗（ADR-011 Q2/Q9）。
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        MainActor.assumeIsolated {
            guard let launcher = launcherWindowController else { return }
            let screen = LauncherTargetScreenResolver.resolve()
            _ = DockReopenAdapter.handleReopen(launcher: launcher, targetScreen: screen)
        }
        // 返回 false：已自行处理，避免 AppKit 再建空白窗。
        return false
    }

    // MARK: - 单击空白背景隐藏（T-1C-D repair → T-1G-E 驻留）

    /// T-1C-D repair + T-1G-E：空白背景（非 app cell）→ **hide launcher（进程驻留）**，不再 terminate。
    /// folder/search/drag 优先级仍在 `QuitOnBlankClickWindow.sendEvent`；到达此处 = 更高优先级已耗尽。
    private func hideOnBackgroundClick() {
        MainActor.assumeIsolated {
            // 1) 设置开着 → 只关设置，启动器保留（再点空白才藏启动器）。
            if activationSettingsCoordinator?.isSettingsVisible == true {
                activationSettingsCoordinator?.hideSettings()
                return
            }
            // 2) 设置已关 → 正常隐藏启动器。
            // 若其它路径把启动器藏掉而设置还在，由 launcher.onLauncherDidHide 兜底关设置。
            _ = activationComposition?.handleBackgroundClick()
        }
    }

    // MARK: - 退出 / 关闭

    /// ADR-011 Q6：hide ≠ quit；最后一窗关闭不得终止进程。
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        LauncherResidentPolicy.terminateAfterLastWindowClosed
    }

    /// 关闭按钮 → hide（不销毁 assembly、不 quit）。
    func windowShouldClose(_ sender: NSWindow) -> Bool {
        MainActor.assumeIsolated {
            _ = activationComposition?.handleWindowCloseRequest()
        }
        return false
    }

    /// Phase 1F：窗口失焦 → cancel 进行中的 drag（.windowResign 统一出口；idle 时 no-op）。
    func windowDidResignKey(_ notification: Notification) {
        dragCoordinator?.cancel(reason: .windowResign)
    }

    /// Phase 1F：应用失活 → cancel 进行中的 drag（.windowResign 统一出口；idle 时 no-op）。
    func applicationDidResignActive(_ notification: Notification) {
        dragCoordinator?.cancel(reason: .windowResign)
    }

    func windowWillClose(_ notification: Notification) {
        // T-1G-E：正常路径 windowShouldClose 返回 false，不会到此。
        // 若系统仍关闭窗口，仅在最终 quit 路径 teardown（避免 hide 误 teardown）。
        if launcherWindowController?.coordinator.state == .terminating {
            teardownAll()
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        MainActor.assumeIsolated {
            activationComposition?.handleApplicationWillTerminate()
        }
        teardownAll()
    }

    private func teardownAll() {
        guard !didRunFinalTeardown else { return }
        didRunFinalTeardown = true
        print("paging-teardownAll: stack=\n\(Thread.callStackSymbols.prefix(15).joined(separator: "\n"))")
        fflush(stdout)
        // T-1G-E：先停激活服务（shortcut/hot-corner/four-finger/session），再拆 UI。
        MainActor.assumeIsolated {
            activationComposition?.teardownActivationServices()
            activationComposition = nil
        }
        guard let surface else { return }
        // Core teardown + 停帧泵 + 无残留动画驱动器（§7.3 末条 + D7）。
        surface.teardown()
        // Phase 1B：帧路径耗时探针落盘（缓冲记录批量写入；幂等）。
        frameProfiler?.flush()
        frameProfiler = nil
        // Phase 1B：runloop 级探针移除观察者 + 落盘（幂等）。
        runLoopProfiler?.stop()
        runLoopProfiler?.flush()
        runLoopProfiler = nil
        // callback 边界探针必须在帧驱动停止、surface teardown 后再 flush，避免尾部回调丢失。
        frameCallbackProfiler?.flush()
        frameCallbackProfiler = nil
        // Phase 1B：装配 teardown（rescan 取消 + 页实例 teardown + 图标管道 shutdown，幂等）。
        // teardownAll 恒在主线程（applicationWillTerminate）→ assumeIsolated。
        MainActor.assumeIsolated {
            // T-1G-C：先移除 status item（幂等），避免退出后残留菜单栏引用。
            statusItemController?.teardown()
            statusItemController = nil
            // T-1G-E：窗控最终 teardown（与 coordinator.terminate 对齐；幂等）。
            _ = launcherWindowController?.terminate()
            launcherWindowController = nil
            assembly?.teardown()
            search?.teardown()
            // Phase 1E：folder 打开层 teardown（零 UI 写回）+ 打开状态清空 + 标题编辑释放。
            folderOverlay?.teardown()
            folderOverlay?.removeFromSuperview()
            folderOverlay = nil
            folderOpenState = nil
            folderTitleEditor = nil
            // Phase 1F：drag UI teardown（cancel(.teardown) + 停 edge timer + 清视觉 +
            // 恢复 click 识别；幂等）+ 清 shared 与会话内布局。
            dragCoordinator?.teardown()
            dragCoordinator = nil
            DragUISessionCoordinator.shared = nil
            sessionLayout = nil
            layoutStore = nil
        }
        assembly = nil
        search = nil
        launchController = nil
        keyboardController = nil
        launchAdapter = nil
        frameDriverExperiment = nil
        telemetryBridge = nil // bridge 的 onTeardown 已写 teardown.complete 并 end session
        self.surface = nil
        self.container = nil
        self.launcherSettingsButton = nil
        self.wallpaperBackdrop = nil
        if let motionObserver {
            NotificationCenter.default.removeObserver(motionObserver)
            self.motionObserver = nil
        }
        // T-1F-B10-regression-fix §2.1 取证（E6a''）：移除分发入口 local monitor（幂等）。
        if let clickMonitor {
            NSEvent.removeMonitor(clickMonitor)
            self.clickMonitor = nil
        }
    }
}

// MARK: - T-1F-B10-regression-fix §2.1 第 4 项（E4）：env 门控手动投递 A/B 实验门（仅诊断）

/// E4 env 门控（**仅供诊断 A/B 实验，禁止作为生产路径常驻**）：
/// `PAGING_CLICK_PROBE_MANUAL_DELIVERY=1` 时在 cell 放行分支手动 `hit?.mouseDown(with:)` 并
/// return（不调 super）；默认未设 env = 门控关，生产路径逐字不变（零行为变更）。
/// 经 `getenv` 每次实读（不用 ProcessInfo.environment 字典，避免进程级缓存歧义；
/// 测试可 setenv/unsetenv 确定性控制）。中性：仅布尔判断，不携带任何身份/坐标。
private enum E4ManualDeliveryGate {
    static var isEnabled: Bool {
        guard let raw = getenv("PAGING_CLICK_PROBE_MANUAL_DELIVERY") else { return false }
        return String(cString: raw) == "1"
    }
}

// MARK: - T-1F-B10-regression-fix §2.2 B1（REPORT §15 定案）：env 门控手动投递闭环（生产候选）

/// B1 env 门控（**生产路径，默认开；转正 2026-09-06 实机定案**）：
/// `PAGING_CLICK_MANUAL_DELIVERY` 未设或 =1 时，cell 命中的 leftMouseDown 手动投递
/// `hit?.mouseDown(with:)` 并记录 `lastManualMouseDownView`（weak），leftMouseUp /
/// leftMouseDragged 在记录存在时投给记录视图——与 E4 诊断探针门（无闭环二分器，
/// `PAGING_CLICK_PROBE_MANUAL_DELIVERY`）**分离**：本门含完整 up/dragged 闭环
/// （cell.mouseUp → coordinator.pointerUp → endSession → dispatchClick → onCellClick
/// → sA launch），消除 E4-B 运行「手动 down 后 state 卡 .pressed」死态。
/// 两门同时开启时 **B1 优先**（E4 分支不执行，行为确定可测）；`PAGING_CLICK_MANUAL_DELIVERY=0`
/// 显式关闭（诊断对照：AppKit 正常投递 = B10 修复前死路径，点击 cell 不启动）。
/// 转正依据（2026-09-06 实机 A/B）：默认关时点击 cell 仅 s8d 放行、s10 恒 0、软件不启动；
/// 门控开时 s10 → s6 → sA_launch_accepted 完整闭环（/tmp/b10-run1-gated.log 证据）。
/// 经 `getenv` 每次实读（不用 ProcessInfo.environment 字典，避免进程级缓存歧义；
/// 测试可 setenv/unsetenv 确定性控制）。中性：仅布尔判断，不携带任何身份/坐标。
private enum B1ManualDeliveryGate {
    static var isEnabled: Bool {
        guard let raw = getenv("PAGING_CLICK_MANUAL_DELIVERY") else { return true }
        return String(cString: raw) == "1"
    }
}

// MARK: - 单击空白背景退出的宿主窗口（T-1C-D repair）

/// 全屏「单击空白背景退出」宿主窗口。
///
/// 为什么要用窗口级 `sendEvent` 拦截而不是给 surface 挂手势识别器：
/// - `PagingSurface` 是 `public final`（冻结），无法通过子类覆盖 `mouseDown(with:)`，且
///   它是仅有的、铺满窗口的交互视图——任何「容器视图 mouseDown」方案都得改 hitTest 重定向命中，
///   而 AppKit 的 scrollWheel 事件目标正是经 hitTest 决定的，那样会破坏翻页。因此把拦截点放在
///   窗口 `sendEvent`：这是**本窗口内**的一次事件入口（每次真实鼠标事件都经过），**不是**红线
///   「全局 NSEvent monitor」（`NSEvent.addGlobalMonitorForEvents`），窗口外/其他 app 完全不触碰。
/// - 每次真实的 `leftMouseDown` 都会评估命中（不再依赖 may-not-fire 的点击识别），且不做 hitTest
///   改写 → scrollWheel 翻页、键盘导航的事件路由零改动。
///
/// 行为：命中空白背景（非 app cell，含 grid 间隙/边距/page 空白）→ 搜索激活时退出搜索、
/// 否则首击即退出；命中 app cell（或其 icon/label 子视图）→ 原样交给 super 分发，surface 上
/// AppLaunchController 的 cell 单击识别器照常启动。cell 判定走下方 `blankClickResolvesToCell`
/// （沿 superview 链校验，点击 cell 内部子视图不误判）。
final class QuitOnBlankClickWindow: NSWindow {
    /// 空白背景被首次实击时回调（AppDelegate 据此退出；搜索未激活路径）。
    var onBlankClick: (() -> Void)?
    /// T-1D 修复：空白背景 + 搜索激活时的退出搜索 seam。返回 true = 已退出搜索并吞掉本点击；
    /// false = 搜索未激活，调用方按原路径终止。由 AppDelegate 接 AppSearchController.
    @MainActor var onBlankClickShouldExitSearch: (() -> Bool)?
    /// T-1E-E：folder 打开状态提供者（nil = 无 folder 打开层）。folder 打开时空白点击
    /// 只关闭 folder（不退出）；folder 关闭后下一次真实背景单击才退出（两阶段，ADR-008 §3 Q10）。
    @MainActor var folderOpenStateProvider: (() -> FolderOpenState?)?
    /// Phase 1F（T-1F-D1）：drag 仲裁守卫。**空白** mouseDown 时 drag 激活 → cancel(.escape)
    /// 并吞掉本点击（返回 true；不退出）。false = 无 drag，调用方按原路径处理。
    /// T-1F-B7-wave-c 收窄：本 seam 仅在空白命中（!blankClickResolvesToCell）时评估；
    /// cell 命中不吞（secondDrag 归 coordinator 仲裁）。
    @MainActor var onDragActiveCancel: (() -> Bool)?
    /// Phase 1F（T-1F-D1）：ESC keyDown 时 drag 激活 → cancel(.escape) 并吞掉（返回 true）。
    /// false = 无 drag，事件放行给键盘控制器（既有 ESC 语义不变）。
    @MainActor var onEscapeDuringDrag: (() -> Bool)?
    /// T-1F-B10-regression-fix §2.1 取证（E5-fix）：`PagingSurface.layoutPerformedCount`
    /// 只读提供者（AppDelegate 接线；nil = 无 surface，按 0 计）。纯观测，零行为变更。
    var layoutPerformedCountProvider: (() -> Int)?
    /// T-1F-B10-regression-fix §2.1 取证（E5-fix）：上次 leftMouseDown 观测时的
    /// `layoutPerformedCount` 基线（纯观测状态，零行为变更；每窗口实例从 0 起算）。
    private var lastLayoutPerformedCountAtPreviousClick = 0
    /// T-1F-B10-regression-fix §2.2 B1（REPORT §15 ②）：手动投递闭环的记录视图
    /// （weak；**仅 B1 门控开时非 nil**——门控关时恒 nil，本属性零行为影响）。
    /// cell 命中 leftMouseDown 手动投递后记录；leftMouseUp/leftMouseDragged 投递到
    /// 记录视图；窗口失 key / ESC 打断时清空（防 stale 记录，B 运行边界外防护）。
    private weak var lastManualMouseDownView: NSView?

    /// T-1F-B10-regression-fix §2.2 B1（REPORT §15 ④）：窗口失 key → 清手动投递记录
    /// （防 stale；门控关时记录恒 nil，零行为变更）。原失 key 语义（AppDelegate
    /// `windowDidResignKey` → dragCoordinator cancel(.windowResign)）逐字不变。
    override func resignKey() {
        lastManualMouseDownView = nil
        super.resignKey()
    }

    override func sendEvent(_ event: NSEvent) {
        // T-1F-B10-regression-fix §2.2 B1（REPORT §15 ②③）：env 门控 `PAGING_CLICK_MANUAL_DELIVERY=1`
        //（默认关）时，leftMouseUp/leftMouseDragged 在记录非 nil（经 B1 down 分支配对记录
        // 的唯一视图）时手动投递给记录视图并 return。闭环关键环：cell.mouseUp →
        // coordinator.pointerUp（s9b endSession）→ dispatchClick（s6）→ onCellClick → sA
        // launch；拖拽链 → coordinator s4a-s4c（预览/拖拽不回归）。**记录 nil（无配对 down
        // / 门控关）→ 本块整体不执行，维持原 super.sendEvent 语义逐字不变。**
        if B1ManualDeliveryGate.isEnabled {
            switch event.type {
            case .leftMouseUp:
                if let target = lastManualMouseDownView {
                    target.mouseUp(with: event)
                    lastManualMouseDownView = nil
                    return
                }
            case .leftMouseDragged:
                if let target = lastManualMouseDownView {
                    target.mouseDragged(with: event)
                    return
                }
            default:
                break
            }
        }
        // Phase 1F：ESC 且 drag 激活 → cancel(.escape) 并吞掉（drag 中 ESC 不落入键盘控制器）。
        if event.type == .keyDown, event.keyCode == 53 {
            // T-1F-B10-regression-fix §2.2 B1（REPORT §15 ④）：ESC 打断 → 清手动投递记录
            // （防 stale；门控关时记录恒 nil，零行为变更）。原 ESC 语义（onEscapeDuringDrag
            // 判定吞点 / 放行键盘控制器）逐字不变。
            lastManualMouseDownView = nil
            if let onEscapeDuringDrag, MainActor.assumeIsolated({ onEscapeDuringDrag() }) {
                return
            }
        }
        // T-1F-B10-regression-fix §2.1 取证（E6b）：事件元数据中性观测——mouseDown 家族
        // （leftMouseDown/rightMouseDown/otherMouseDown）每点击记录 type/subtype/buttonNumber
        // 三中性 int（编码进 sink 名，仅入内存 snapshot；stderr 只打 sink 名+计数，无坐标/
        // 无窗口标题/无应用名，隐私 A/B/C）。判别（BUG10-REGRESSION-REPORT §10 E6b）：
        // subtype≠0 或 type≠leftMouseDown → 非正常事件 → c/j 系统拦截。
        switch event.type {
        case .leftMouseDown, .rightMouseDown, .otherMouseDown:
            ClickCensus.observeEventMetadata(
                type: event.type.rawValue,
                subtype: event.subtype.rawValue,
                buttonNumber: event.buttonNumber)
        default:
            break
        }
        // T-1F-B10-regression-fix §2.1 取证：投递探针（只读观测，零行为变更）。记录
        // 「窗口手动 hitTest 结果」vs「AppKit 内部路由目标」的类名链（ClickDeliveryProbeView
        // 为 contentView 时生效；非探针 contentView 下全部 no-op，行为与既有完全一致）。
        var deliveryProbe: ClickDeliveryProbeView?
        var observedManualHit = false
        if event.type == .leftMouseDown {
            // T-1F-B10-regression-fix §2.1 取证（E1）：event 窗口归属一致性中性观测——
            // event.windowNumber vs self.windowNumber vs NSApp.keyWindow?.windowNumber
            // 三者一致性布尔位（仅计数 + 布尔，零行为变更；隐私 A/B/C：窗口号码只在
            // 进程内做相等比较，绝不出现在 sink 名/输出中，禁窗口身份/标题/坐标原文）。
            // 判别（BUG10-REGRESSION-REPORT §9 E1）：任一不一致 → 命中候选 e。
            ClickCensus.observeWindowOwnership(
                eventWindowNumber: event.windowNumber,
                selfWindowNumber: windowNumber,
                keyWindowNumber: NSApp.keyWindow?.windowNumber)
            // T-1F-B10-regression-fix §2.1 取证（E5-fix）：命中视图缓存失效对照——直接读
            // PagingSurface.layoutPerformedCount（冻结树 :169 public private(set)，只读不调用）
            // 替代已降级的 E5 funnel（applyPresentationUpdate 计数点已移除）；本点击与上一次
            // leftMouseDown 之间的计数增量 > 0 = 发生过 relayout（中性布尔，零行为变更）。
            // 判别：s18_internal_hittest_absent 与 relayout 时机强相关 → 命中候选 f。
            let layoutOpsNow = layoutPerformedCountProvider?() ?? 0
            ClickCensus.observeRelayoutSincePreviousClick(
                relayoutOccurred: layoutOpsNow - lastLayoutPerformedCountAtPreviousClick > 0)
            lastLayoutPerformedCountAtPreviousClick = layoutOpsNow
            // T-1F-B9-wave-b Stage 1 census（s8e）：窗口 key 态观测（仅计数 + 读状态，零行为变更）。
            // BUG9-REPORT §2 R5：全屏 0.3s 延迟 toggle 后 key 状态从未被观测过。sink 名携带
            // key/active 两状态位（`isKeyWindow` / `NSApp.isActive`）仅入内存 snapshot；stderr
            // 只打 sink 名+计数（无身份原则：无窗口标题/无坐标/无应用名，隐私 A/B/C）。
            ClickCensus.hit(ClickCensus.Sink.windowKeyState(
                isKeyWindow: isKeyWindow, appActive: NSApp.isActive))
            // 每次真实的鼠标左键按下都评估命中。
            if let contentView {
                deliveryProbe = contentView as? ClickDeliveryProbeView
                // 探针：把下一次 hitTest 标记为「窗口手动调用」（与 AppKit 内部路由调用区分）。
                deliveryProbe?.markNextHitTestAsManual()
                let point = contentView.convert(event.locationInWindow, from: nil)
                let hit = contentView.hitTest(point)
                observedManualHit = true
                // 设置齿轮等主面板 chrome：必须走完整 AppKit 分发（含 mouseUp→action），
                // 不能当空白隐藏，也不能只手动 mouseDown（B1）导致点一下却退出。
                if blankClickResolvesToLauncherChrome(hit) {
                    super.sendEvent(event)
                    return
                }
                if !blankClickResolvesToCell(hit) {
                    // T-1F-B8-wave-c census（S8）：空白命中计数点（仅计数）。
                    ClickCensus.hit(ClickCensus.Sink.windowBlankUnclassified)
                    // Phase 1F：空白 mouseDown 且 drag 激活 → cancel(.escape) 并吞掉（防御；
                    // 正常不可能）。T-1F-B7-wave-c 收窄：drag cancel 仅评估**空白命中**——
                    // cell 命中（含活动会话内的第二次 pointerDown）放行 super，由 coordinator
                    // secondDrag 仲裁处理，不再被窗口层吞掉（曾致 cell 单击静默丢失）。
                    if let onDragActiveCancel, MainActor.assumeIsolated({ onDragActiveCancel() }) {
                        // T-1F-B8-wave-c census（S8）：drag 激活吞点计数点（仅计数）。
                        ClickCensus.hit(ClickCensus.Sink.windowDragActiveSwallow)
                        return
                    }
                    // T-1E-E：folder 打开 → 打开层是显式 interaction zone（点击关闭 folder，
                    // 不退出）。事件放行给打开层（FolderOverlayView.mouseDown → handleClick →
                    // onRequestClose → closeFolder）。folder 关闭后下一次真实背景单击才退出。
                    if let folderOpenState = MainActor.assumeIsolated({ folderOpenStateProvider?() }),
                       folderOpenState.isOpen {
                        super.sendEvent(event)
                        return
                    }
                    // 空白背景：
                    // - 搜索激活 → 退出搜索（清 query / 恢复目录 / 恢复焦点），吞掉本点击，应用保持存活；
                    // - 搜索未激活 → 维持既有空白退出（终止）。
                    if let exitSearch = onBlankClickShouldExitSearch,
                       MainActor.assumeIsolated({ exitSearch() }) {
                        return
                    }
                    // 空白 + 搜索未激活 → 既有空白退出（终止），吞掉本点击。
                    // T-1F-B8-wave-c census（S8）：terminate 通路计数点（仅计数）。
                    ClickCensus.hit(ClickCensus.Sink.windowBlankTerminate)
                    onBlankClick?()
                    return
                } else {
                    // T-1F-B8-wave-c census（S8）：cell 命中放行 super 计数点（仅计数）。
                    ClickCensus.hit(ClickCensus.Sink.windowCellPassthrough)
                    // T-1F-B10-regression-fix §2.2 B1（REPORT §15 ①；**生产修复候选，默认关**）：
                    // `PAGING_CLICK_MANUAL_DELIVERY=1` 且命中 cell（复用上方 blankClickResolvesToCell
                    // 判定）→ 手动 `hit?.mouseDown(with: event)` + 记录 `lastManualMouseDownView`
                    // （weak）→ return（不调 super）。与 E4 探针门分离：本分支含 up/dragged
                    // 闭环（sendEvent 顶部投递到记录视图），消除 E4-B 运行「手动 down 后无
                    // mouseUp 投递、state 卡 .pressed」死态。两门同开时 **B1 优先**（E4 分支
                    // 不执行）——行为确定可测。默认未设 env = 本分支不进，走既有
                    // super.sendEvent 生产路径逐字不变（s8d / s18 记账照旧）。
                    if B1ManualDeliveryGate.isEnabled {
                        if let hit {
                            lastManualMouseDownView = hit
                            hit.mouseDown(with: event)
                        }
                        return
                    }
                    // T-1F-B10-regression-fix §2.1 第 4 项（E4）：env 门控手动投递 A/B 实验。
                    // **仅供诊断 A/B 实验，禁止作为生产路径常驻。** `PAGING_CLICK_PROBE_MANUAL_DELIVERY=1`
                    // 时，在放行 super.sendEvent 之前手动 `hit?.mouseDown(with: event)` 并 return
                    // （不调 super）——判别断点在 AppKit 内部分发层 vs 事件/视图链自身（REPORT
                    // §14：A1 证 subtype=0 亦死 → h 候选；E4 二分：结果 A = 手动投递触发 s10 →
                    // 事件与视图链健全、断点纯在 AppKit 分发；结果 B = 仍零 → 事件被标记 handled
                    // / 命中视图非 cell → 升级「重建事件 + 手动投递」）。默认未设 env = 本分支
                    // 不进，走既有 super.sendEvent 生产路径逐字不变（s8d / s18 absent+present 记账照旧）。
                    if E4ManualDeliveryGate.isEnabled {
                        ClickCensus.hit(ClickCensus.Sink.e4ManualDelivery)
                        hit?.mouseDown(with: event)
                        return
                    }
                }
            }
        }
        // 探针：仅对放行 super 的 leftMouseDown 观测 AppKit 内部路由——super.sendEvent 前后
        // 对照内部 hitTest 调用计数：未增 = AppKit 未咨询视图树（投递目标来自其他来源，
        // 如 tracking 缓存/坐标系基准失配 → 锁定 BUG10-REGRESSION-REPORT §3.2 候选 ①）。
        if observedManualHit {
            deliveryProbe?.beginInternalObservation()
        }
        let internalHitTestBefore = deliveryProbe?.internalHitTestCallCount
        super.sendEvent(event)
        if observedManualHit, let deliveryProbe, let before = internalHitTestBefore {
            deliveryProbe.endInternalObservation()
            if deliveryProbe.internalHitTestCallCount == before {
                ClickCensus.hit(ClickCensus.Sink.deliveryProbeInternalHitTestAbsent)
            } else {
                ClickCensus.hit(ClickCensus.Sink.deliveryProbeInternalHitTestPresent)
            }
        }
    }
}

// MARK: - T-1F-B10-regression-fix §2.1 取证：窗口内部投递目标探针（只读观测，零行为变更）

/// 窗口 contentView 链上的只读投递探针（T-1F-B10-regression-fix §2.1.1）：
/// 记录「窗口手动 hitTest 结果」vs「AppKit 内部路由目标」的类名链，判别事件在窗口层与
/// cell 之间被整体吞掉的机制（BUG10-REGRESSION-REPORT §3.2 候选 ①：窗口内部投递目标与
/// sendEvent 覆盖层手动 `contentView.hitTest` 不同源）。
///
/// - 中性：只记 `type(of:)` 类名链（禁坐标/身份/标题，隐私 A/B/C）。
/// - 零行为变更：`hitTest`/`mouseDown` 均原样转发 super，返回值/响应链与普通 NSView 完全一致；
///   非探针 contentView 下（`contentView as? ClickDeliveryProbeView` 为 nil）零观测零影响。
/// - 计数：经 `ClickCensus.hit`（内存计数恒维护；env `PAGING_CLICK_CENSUS=1` 时 stderr 输出）。
/// - 挂载：作为窗口 contentView（AppDelegate :208 容器；全屏过渡不替换 contentView，探针常驻）。
final class ClickDeliveryProbeView: NSView {
    /// 透出壁纸：contentView 不得声明不透明。
    override var isOpaque: Bool { false }

    /// 类名链最大深度（命中视图 → 沿 superview 链向上至本探针；封顶防 sink 名过长）。
    private static let maxChainDepth = 8

    /// 下一次 hitTest 调用标记为「窗口手动调用」（sendEvent 在手动 hitTest 前设置；调用即消费）。
    private var nextHitTestIsManual = false
    /// 内部路由观测窗（sendEvent 放行 super 前开启、super.sendEvent 返回后关闭）。
    private var observingInternalRouting = false
    /// 观测窗内 AppKit 内部路由 hitTest 调用计数（sendEvent 前后对照判「未咨询视图树」）。
    private(set) var internalHitTestCallCount = 0

    /// sendEvent 手动 hitTest 前调用：把下一次 hitTest 标记为 manual（窗口自身调用）。
    func markNextHitTestAsManual() {
        nextHitTestIsManual = true
    }

    /// sendEvent 放行 `super.sendEvent` 前调用：开启内部路由观测窗。
    func beginInternalObservation() {
        observingInternalRouting = true
    }

    /// `super.sendEvent` 返回后调用：关闭内部路由观测窗。
    func endInternalObservation() {
        observingInternalRouting = false
    }

    /// 命中视图 → 类名链（中性：仅 `type(of:)` 字符串，沿 superview 向上至本探针，封顶）。
    private static func chainString(from view: NSView?, stoppingAt selfView: NSView) -> String {
        guard let view else { return "nil" }
        var names: [String] = []
        var node: NSView? = view
        while let current = node, names.count < maxChainDepth {
            names.append(String(describing: type(of: current)))
            if current === selfView { break }
            node = current.superview
        }
        return names.joined(separator: "_")
    }

    public override func hitTest(_ point: NSPoint) -> NSView? {
        let result = super.hitTest(point)
        if nextHitTestIsManual {
            nextHitTestIsManual = false
            ClickCensus.hit(ClickCensus.Sink.deliveryProbeManualHitChain(
                chain: Self.chainString(from: result, stoppingAt: self)))
        } else if observingInternalRouting {
            internalHitTestCallCount += 1
            ClickCensus.hit(ClickCensus.Sink.deliveryProbeInternalHitChain(
                chain: Self.chainString(from: result, stoppingAt: self)))
        }
        return result
    }

    public override func mouseDown(with event: NSEvent) {
        // AppKit 把 mouseDown 投递给 contentView 自身（内部路由目标 = 容器；Chief 候选之一）。
        ClickCensus.hit(ClickCensus.Sink.deliveryProbeDeliveredToContentView)
        super.mouseDown(with: event)
    }

    // T-1F-B10-regression-fix §2.1 取证（E6a）：探针投递观测——mouseUp/mouseDragged/
    // rightMouseDown/otherMouseDown 纯转发 census（中性计数，隐私合规；转发 super 原样，
    // 返回值/响应链与普通 NSView 完全一致，零行为变更）。判别（BUG10-REGRESSION-REPORT
    // §10 E6a）：探针收 mouseDown → 投递目标=contentView（滞留跟踪会话）→ 命中 g/f；
    // 只收 mouseUp 不收 mouseDown → 事件对被拆散 → 识别器滞留（b/f 系）；两者皆零 →
    // 窗口级消费（h）。

    public override func mouseUp(with event: NSEvent) {
        ClickCensus.hit(ClickCensus.Sink.deliveryProbeMouseUp)
        super.mouseUp(with: event)
    }

    public override func mouseDragged(with event: NSEvent) {
        ClickCensus.hit(ClickCensus.Sink.deliveryProbeMouseDragged)
        super.mouseDragged(with: event)
    }

    public override func rightMouseDown(with event: NSEvent) {
        ClickCensus.hit(ClickCensus.Sink.deliveryProbeRightMouseDown)
        super.rightMouseDown(with: event)
    }

    public override func otherMouseDown(with event: NSEvent) {
        ClickCensus.hit(ClickCensus.Sink.deliveryProbeOtherMouseDown)
        super.otherMouseDown(with: event)
    }
}

/// 空白-vs-cell 命中分类（T-1C-D repair）：命中视图链（含 icon/label 子视图）是否含 AppGridCellView。
/// 供 `QuitOnBlankClickWindow.sendEvent` 与单测（blank-vs-cell）共用；纯视图逻辑、无副作用。
/// T-1D-E：搜索 field/editor/clear button 是显式 "interaction zone"（ADR-007 §2.7）——
/// 点击它们不触发空白单击退出；真实背景空白仍首击退出。
/// 主面板 chrome（设置齿轮等）：空白点击不得吞掉。
func blankClickResolvesToLauncherChrome(_ hit: NSView?) -> Bool {
    var node = hit
    while let current = node {
        if let button = current as? NSButton {
            let id = button.identifier?.rawValue ?? ""
            if id == "launchcopy.launcherSettingsButton" || id.hasPrefix("launchcopy.chrome.") {
                return true
            }
        }
        node = current.superview
    }
    return false
}

func blankClickResolvesToCell(_ hit: NSView?) -> Bool {
    // 搜索 field/editor/clear button → interaction zone（不退出）。
    if AppSearchFieldView.isSearchFieldOrSubview(hit) {
        return true
    }
    if blankClickResolvesToLauncherChrome(hit) {
        return true
    }
    var node = hit
    while let current = node {
        if current is AppGridCellView {
            // 命中链是否含 FolderOverlayView：从被命中 cell 沿祖先链向上检查（overlay 是
            // cell 的祖先；「cell 在 overlay 内」= 成员 cell，祖先链含打开层）。
            var ancestor = current.superview
            var chainHasOverlay = false
            while let parent = ancestor {
                if parent is FolderOverlayView {
                    chainHasOverlay = true
                    break
                }
                ancestor = parent.superview
            }
            // T-1F-B10-wave-a forensics census（s17）：返回 true 时命中链是否含
            // FolderOverlayView 的布尔位（仅计数，零行为变更）。判别「cell 在 overlay 内
            // vs 在 grid 内」关键位：_ov1 = 命中链经 overlay（成员 cell 在打开层内——
            // 窗口层判 cell 放行 super，但 AppKit 事件仍可能被 overlay.hitTest 吞掉）；
            // _ov0 = cell 在 grid 内（健康路径）。sink 名只携带布尔位，无身份。
            ClickCensus.hit(ClickCensus.Sink.blankHitChainHasOverlay(hasOverlay: chainHasOverlay))
            return true
        }
        node = current.superview
    }
    return false
}

// MARK: - T-1F-B9-wave-b Stage 1 census sink 声明（任务包 §3：可放 AppDelegate.swift 同文件）

/// s8e/s13 sink（仅命名空间声明；计数机制与 env 门控沿用 `ClickCensus`，本文件零机制改动）。
extension ClickCensus.Sink {
    /// s8e 基名：窗口 key 态观测（QuitOnBlankClickWindow.sendEvent leftMouseDown 处）。
    /// 实际 sink 为基名 + `_key{n}_active{n}` 状态位变体（`isKeyWindow` / `NSApp.isActive`），
    /// 状态位仅随 sink 名入内存 snapshot；stderr 只打 sink 名+计数（无身份：无窗口标题/
    /// 无坐标/无应用名，隐私 A/B/C）。
    public static let windowKeyStateBase = "s8e_window_key_state"

    /// s8e 状态位 sink 名（两 bool → 四变体；变体名不含任何身份信息）。
    public static func windowKeyState(isKeyWindow: Bool, appActive: Bool) -> String {
        "\(windowKeyStateBase)_key\(isKeyWindow ? 1 : 0)_active\(appActive ? 1 : 0)"
    }

    /// s13a：抑制闭包启用向（闭包收到 enabled = false → 抑制开启；AppDelegate.installDragUI 闭包；
    /// 与 coordinator beginArbitration → suppressor(false) 对应）。
    public static let suppressionEnable = "s13a_enable"

    /// s13b：抑制闭包恢复向（闭包收到 enabled = true → endSession 恢复；与 s9b_endsession_restored 对照）。
    public static let suppressionDisable = "s13b_disable"
}

// MARK: - T-1F-B10-wave-a forensics census sink 声明（AppDelegate 层布点；仅命名空间声明，
// 计数机制与 env 门控沿用 `ClickCensus`，本文件零机制改动）

extension ClickCensus.Sink {
    /// s16 基名：closeFolder 执行后 overlay 的 superview 状态（AppDelegate.closeFolder 末行）。
    /// 实际 sink 为基名 + `_sv1`/`_sv0` 布尔位变体（`overlay.superview == nil`），
    /// 状态位仅随 sink 名入内存 snapshot；stderr 只打 sink 名+计数（无身份，隐私 A/B/C）。
    public static let closeFolderOverlayStateBase = "s16_closefolder_overlay_state"

    /// s16 状态位 sink 名（superview.nil → _sv1；superview 非 nil → _sv0）。
    public static func closeFolderOverlayState(superviewIsNil: Bool) -> String {
        "\(closeFolderOverlayStateBase)_sv\(superviewIsNil ? 1 : 0)"
    }

    /// s17 基名：blankClickResolvesToCell 返回 true 时命中链是否含 FolderOverlayView。
    /// 实际 sink 为基名 + `_ov1`/`_ov0` 布尔位变体（链中是否出现打开层），
    /// 状态位仅随 sink 名入内存 snapshot；stderr 只打 sink 名+计数（无身份，隐私 A/B/C）。
    public static let blankHitChainHasOverlayBase = "s17_blankhit_chain_has_overlay"

    /// s17 状态位 sink 名（链含 overlay → _ov1；不含 → _ov0）。
    public static func blankHitChainHasOverlay(hasOverlay: Bool) -> String {
        "\(blankHitChainHasOverlayBase)_ov\(hasOverlay ? 1 : 0)"
    }
}

// MARK: - T-1F-B10-regression-fix §2.1 census sink 声明（窗口投递探针；仅命名空间声明，
// 计数机制与 env 门控沿用 `ClickCensus`，本文件零机制改动）

extension ClickCensus.Sink {
    /// s18 基名：窗口手动 hitTest 结果类名链（sendEvent 手动调用；链 = `type(of:)` 类名沿
    /// superview 向上至探针，"_" 连接，封顶 8 层）。sink 名只含类名（中性，隐私 A/B/C）。
    public static let deliveryProbeManualHitChainBase = "s18_hit_manual_chain"

    /// s18 手动 hitTest 结果链 sink 名（链编码进 sink 名；每链独立计数）。
    public static func deliveryProbeManualHitChain(chain: String) -> String {
        "\(deliveryProbeManualHitChainBase)_\(chain)"
    }

    /// s18 基名：AppKit 内部路由 hitTest 结果类名链（super.sendEvent 期间的非手动调用）。
    public static let deliveryProbeInternalHitChainBase = "s18_hit_internal_chain"

    /// s18 内部路由 hitTest 结果链 sink 名。
    public static func deliveryProbeInternalHitChain(chain: String) -> String {
        "\(deliveryProbeInternalHitChainBase)_\(chain)"
    }

    /// s18：AppKit 把 mouseDown 投递给 contentView 自身（探针 mouseDown 到达；Chief 候选
    /// 「containerView」的直接证据）。
    public static let deliveryProbeDeliveredToContentView = "s18_delivered_contentview"

    /// s18：leftMouseDown 放行 super.sendEvent 后未观察到任何内部 hitTest 调用
    /// （AppKit 未咨询视图树 → 投递目标来自其他来源，如 tracking 缓存/坐标系基准失配）。
    public static let deliveryProbeInternalHitTestAbsent = "s18_internal_hittest_absent"

    /// s18：leftMouseDown 放行 super.sendEvent 后观察到 ≥1 次内部 hitTest 调用。
    public static let deliveryProbeInternalHitTestPresent = "s18_internal_hittest_present"
}

// MARK: - T-1F-B10-regression-fix §2.1 取证 E6a/E6b sink 声明与观测（仅命名空间声明 +
// 纯观测 helper；计数机制与 env 门控沿用 `ClickCensus`，本文件零机制改动）

extension ClickCensus.Sink {
    /// E6a（探针投递观测，BUG10-REGRESSION-REPORT §10 E6a）：ClickDeliveryProbeView
    /// （contentView）mouseUp 纯转发 census（中性计数，隐私合规）。
    public static let deliveryProbeMouseUp = "sE6a_probe_mouseup"
    /// E6a：mouseDragged 纯转发 census。
    public static let deliveryProbeMouseDragged = "sE6a_probe_mousedragged"
    /// E6a：rightMouseDown 纯转发 census。
    public static let deliveryProbeRightMouseDown = "sE6a_probe_rightmousedown"
    /// E6a：otherMouseDown 纯转发 census。
    public static let deliveryProbeOtherMouseDown = "sE6a_probe_othermousedown"

    /// E6a''（分发入口监视，任务包 §2.1 步骤 4）：local monitor 收到 leftMouseDown。
    public static let monitorMouseDown = "sE6_monitor_down"
    /// E6a''：local monitor 收到 leftMouseUp。
    public static let monitorMouseUp = "sE6_monitor_up"

    /// E6b 基名（事件元数据，BUG10-REGRESSION-REPORT §10 E6b）：每点击记录
    /// `event.type.rawValue`/`subtype.rawValue`/`buttonNumber` 三中性 int，编码进 sink 名
    /// `sE6b_meta_type_<t>_subtype_<s>_button_<b>`。仅入内存 snapshot；stderr 只打
    /// sink 名+计数（无坐标/无窗口标题/无应用名，隐私 A/B/C）。判别：subtype≠0 或
    /// type≠leftMouseDown → 非正常事件 → c/j 系统拦截。
    public static let eventMetadataBase = "sE6b_meta"
    /// E6b 状态位 sink 名（type/subtype/buttonNumber 三中性 int 编码）。
    public static func eventMetadata(type: UInt, subtype: Int16, buttonNumber: Int) -> String {
        "\(eventMetadataBase)_type_\(type)_subtype_\(subtype)_button_\(buttonNumber)"
    }
}

// MARK: - T-1F-B10-regression-fix §2.1 第 4 项（E4）sink 声明（env 门控手动投递 A/B 实验；
// 仅命名空间声明，计数机制与 env 门控沿用 `ClickCensus`，本文件零机制改动）

extension ClickCensus.Sink {
    /// E4（手动投递 A/B 实验，任务包 §2.1 第 4 项 / REPORT §9 E4）：门控
    /// `PAGING_CLICK_PROBE_MANUAL_DELIVERY=1` 开启且 cell 命中时，手动投递分支执行
    /// （仅计数，中性；**仅供诊断，禁止作为生产路径常驻**）。判别：
    /// `sE4_manual_delivery` > 0 且 `s10` > 0 = 结果 A（事件与视图链健全，断点在 AppKit
    /// 分发）；`sE4_manual_delivery` > 0 且 `s10` == 0 = 结果 B（升级「重建事件 + 手动投递」）。
    /// 门控关时恒 0。
    public static let e4ManualDelivery = "sE4_manual_delivery"
}

extension ClickCensus {
    /// E6b 观测（仅计数；零行为变更）：记录一次 mouseDown 家族事件的 type/subtype/
    /// buttonNumber 三中性 int（编码进 sink 名；数值仅入内存 snapshot，stderr 只打
    /// sink 名+计数）。入参为 `NSEvent.EventType.rawValue`（UInt）、
    /// `NSEvent.EventSubtype.rawValue`（Int16）、`event.buttonNumber`（Int）。
    static func observeEventMetadata(type: UInt, subtype: Int16, buttonNumber: Int) {
        ClickCensus.hit(ClickCensus.Sink.eventMetadata(
            type: type, subtype: subtype, buttonNumber: buttonNumber))
    }

    /// E6a'' 观测（仅计数；零行为变更）：local monitor 收到 mouseDown 家族事件时调用
    /// （monitor 匹配面 = [.leftMouseDown, .leftMouseUp]，故仅两型可达）。
    static func observeMonitorEvent(type: NSEvent.EventType) {
        ClickCensus.hit(type == .leftMouseDown
            ? ClickCensus.Sink.monitorMouseDown
            : ClickCensus.Sink.monitorMouseUp)
    }
}

// MARK: - T-1F-B10-regression-fix §2.1 取证 E1/E5 sink 声明与观测（仅命名空间声明 +
// 纯观测 helper；计数机制与 env 门控沿用 `ClickCensus`，本文件零机制改动）

extension ClickCensus.Sink {
    /// E1（窗口归属一致性，BUG10-REGRESSION-REPORT §9 E1）：event / self / keyWindow 三者
    /// 窗口号码完全一致 → match。sink 名只携带一致/不一致布尔位；窗口号码只在进程内做相等
    /// 比较，绝不出现在 sink 名/输出中（隐私 A/B/C：禁窗口号码/标题/坐标/身份原文）。
    public static let windowOwnerMatch = "sE1_window_owner_match"
    /// E1：event.windowNumber != self.windowNumber（事件窗口号码与宿主窗口不一致）。
    public static let windowOwnerMismatchEvSelf = "sE1_window_owner_mismatch_evSelf"
    /// E1：event.windowNumber != NSApp.keyWindow?.windowNumber（事件与 key 窗口号码不一致）。
    public static let windowOwnerMismatchEvKey = "sE1_window_owner_mismatch_evKey"
    /// E1：self.windowNumber != NSApp.keyWindow?.windowNumber（宿主与 key 窗口号码不一致；
    /// 含 keyWindow 为 nil 的情形）。
    public static let windowOwnerMismatchSelfKey = "sE1_window_owner_mismatch_selfKey"

    /// E5-fix（缓存失效对照，BUG10-REGRESSION-REPORT §9 E5 / §10）：直接读
    /// `PagingSurface.layoutPerformedCount`（PagingUI 冻结树 :169 public private(set)，
    /// 只读不调用）替代已降级的 E5 funnel（applyPresentationUpdate 计数点已移除）。
    /// 基名：本点击与上一次 leftMouseDown 之间 `layoutPerformedCount` 是否增量 ≥1。
    /// 实际 sink 为基名 + `_yes`/`_no` 布尔位变体（仅布尔，无身份）。
    public static let relayoutBetweenClicksBase = "sE5_relayout_between_clicks"
    /// E5-fix 状态位 sink 名（两次点击间有 relayout → _yes；无 → _no）。
    public static func relayoutBetweenClicks(_ occurred: Bool) -> String {
        "\(relayoutBetweenClicksBase)_\(occurred ? "yes" : "no")"
    }
}

extension ClickCensus {
    /// E1 观测（仅计数 + 布尔位；零行为变更，不改任何分支条件）：
    /// event / self / keyWindow 三者窗口号码一致性。入参号码仅在进程内做相等比较，
    /// 绝不出现在 sink 名/输出中（隐私 A/B/C）。判别：任一不一致 → 候选 e。
    static func observeWindowOwnership(eventWindowNumber: Int,
                                       selfWindowNumber: Int,
                                       keyWindowNumber: Int?) {
        let evSelfConsistent = eventWindowNumber == selfWindowNumber
        let evKeyConsistent = eventWindowNumber == keyWindowNumber
        let selfKeyConsistent = selfWindowNumber == keyWindowNumber
        if evSelfConsistent && evKeyConsistent && selfKeyConsistent {
            ClickCensus.hit(ClickCensus.Sink.windowOwnerMatch)
        } else {
            if !evSelfConsistent { ClickCensus.hit(ClickCensus.Sink.windowOwnerMismatchEvSelf) }
            if !evKeyConsistent { ClickCensus.hit(ClickCensus.Sink.windowOwnerMismatchEvKey) }
            if !selfKeyConsistent { ClickCensus.hit(ClickCensus.Sink.windowOwnerMismatchSelfKey) }
        }
    }

    /// E5 观测（仅计数；零行为变更）：两次 leftMouseDown 之间是否发生已知布局触发
    /// （sendEvent 处由窗口基线计数差分后调用；`relayoutOccurred` 为中性布尔）。
    static func observeRelayoutSincePreviousClick(relayoutOccurred: Bool) {
        ClickCensus.hit(ClickCensus.Sink.relayoutBetweenClicks(relayoutOccurred))
    }
}
