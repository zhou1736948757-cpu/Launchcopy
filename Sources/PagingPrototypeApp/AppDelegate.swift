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
import MacAppCatalog
import PagingCore
import PagingTelemetry
import PagingUI
import QuartzCore
import LauncherLocalization

final class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate, NSMenuItemValidation {

    private let options: AppArguments.Options
    private(set) var uiTestProfile: UITestProfile?
    var folderDropLatencyProbe: FolderDropLatencyProbe?
    private var libraryEntryProfileSession: LibraryEntryProfileSession?
    var window: NSWindow?
    /// Phase 1G T-1G-B：presentation 窗口控制器（Option B screen-covering panel）。
    /// 全入口仲裁与 blank→hide 留给 T-1G-E；此处仅 host/attach + 去掉延迟 toggleFullScreen。
    private var launcherWindowController: LauncherWindowController?
    /// Phase 1G T-1G-C：菜单栏 status item（Show/Hide / Settings stub / Quit）。
    /// 创建失败不崩溃；teardown 移除。
    private var statusItemController: StatusItemController?
    /// Phase 1G T-1G-E：激活入口组合根（shortcut / hot corner / four-finger / session → 同一 launcher）。
    private var activationComposition: ActivationComposition?
    private var fourFingerDiagnostics: FourFingerDiagnostics?
    /// Phase 1G T-1G-E：激活偏好存储（独立 suite；失败则内存默认）。
    private var activationPreferencesStore: (any ActivationPreferencesPersisting)?
    /// Phase 1H T-1H-B/F：激活设置协调器（单实例窗 + apply 事务；启动不自动启用 login item）。
    private var activationSettingsCoordinator: ActivationSettingsCoordinator?
    private var appearanceSettingsCoordinator: AppearanceSettingsCoordinator?
    private(set) var liveAppearanceCoordinator: LiveAppearanceSettingsCoordinator?
    private(set) var mainGridCapacityCoordinator: MainGridCapacityCoordinator?
    private(set) var mainGridCapacity = MainGridCapacity.default
    private(set) var pendingMainGridCapacity: MainGridCapacity?
    private(set) var mainGridIsReadable = true
    private(set) var mainGridLayoutEpoch: UInt64 = 0
    private var mainGridCapacityLoadTask: Task<Void, Never>?
    private var mainGridCapacityRetryScheduled = false
    private var isApplyingMainGridCapacity = false
    private var mainGridHiddenForLibrary = false
    private var mainGridPreviewForLibrary = false
    private(set) var leadingLibraryNavigator: LeadingLibraryNavigator?
    private var mainGridSpaceNotice: NSTextField?
    private weak var configuredMainGridCapacityView: MainGridCapacitySettingsView?
    var mainGridCapacityReadinessCheck: (() -> Bool)?
    private(set) var appLibraryOwner: AppLibraryOwnerController?
    private var pendingLibraryGridFocus: AppGridFocusIdentity?
    private(set) var languageSettingsCoordinator: LanguageSettingsCoordinator?
    private(set) var languagePresentationController: LanguagePresentationController?
    private(set) var languageStrings: LocalizedStrings?
    private weak var configuredLanguageSettingsController: ActivationSettingsWindowController?
    private var languageRuntimeObservers: LanguageRuntimeObservers?
    private var languageRetryScheduled = false
    private var languageGeneration: UInt64 = 0
    private(set) var languagePresentationApplyCount = 0
    private weak var localizedQuitMenuItem: NSMenuItem?
    private weak var localizedToggleMenuItem: NSMenuItem?
    private weak var localizedLibraryMenuItem: NSMenuItem?
    private weak var localizedViewMenu: NSMenu?
    private var editMenuController: LauncherEditMenuController?
    private var appManagementCoordinator: AppManagementCoordinator?
    private var managementRefreshPending = false
    private var managementRefreshScheduled = false
    private(set) var appSourcesCoordinator: AppSourcesCoordinator?
    private var appContextMenuController: AppContextMenuController?
    var appRemovalCoordinator: AppRemovalCoordinator?
    private var appRemovalAlert: NSAlert?
    private var appRemovalQuitFailure = false
    private(set) var appRemovalPresentationGeneration: UInt64 = 0
    private var appFolderAssignmentMenus: AppFolderAssignmentMenuController?
    private var layoutRestoreTask: Task<Void, Never>?
    @MainActor private lazy var workspacePersistence = WorkspacePersistenceQueue()
    @MainActor private lazy var workspaceQuit: WorkspaceQuitCoordinator = {
        let coordinator = WorkspaceQuitCoordinator()
        coordinator.onPhaseChange = { [weak self] in self?.refreshTitleEditReadiness() }
        return coordinator
    }()
    private(set) var workspaceNeedsSave = false
    private var quitSaveAlert: NSAlert?
    private var isQuitSaveModalRunning = false
    @MainActor var isWorkspaceQuitPending: Bool { workspaceQuit.isPending }
    private var layoutRestoreGeneration: UInt64 = 0
    private(set) var isRestoringLayout = false
    private(set) var layoutPersistenceState: LayoutStoreState = .healthy
    private(set) var lastWorkspacePersistenceOutcome: LayoutStoreFlushResult?
    private(set) var workspaceSaveNotice: NSTextField?
    private(set) var catalogStatusView: AppGridStatusView?
    private(set) var actionFeedbackView: ActionFeedbackNoticeView?
    private var actionFeedbackGeneration: UInt64 = 0
    private weak var launchFeedbackAssembly: AppCatalogAssembly?
    var actionFileExists: (URL) -> Bool = { FileManager.default.fileExists(atPath: $0.path) }
    var fileRevealRequester: (URL) -> Void = { NSWorkspace.shared.activateFileViewerSelecting([$0]) }
    private var catalogStatusRefreshScheduled = false
    private var catalogStatusGeneration: UInt64 = 0
    /// Semantic visibility from the last completed status render, before any mode mask.
    private var catalogStatusPresentationIsHidden = true
    /// Native API seam: tests retain completions without ordering an actual sheet/window.
    var applicationSheetPresenter: (NSAlert, NSWindow, @escaping (NSApplication.ModalResponse) -> Void) -> Void = {
        alert, window, finish in alert.beginSheetModal(for: window, completionHandler: finish)
    }
    private var resolvedLayoutCache: (revision: UInt64, generation: UInt64, folderGeneration: UInt64,
                                      layout: PersistentWorkspaceLayout, indices: DragLogicalIndexMap)?
    private(set) var resolvedLayoutBuildCount = 0
    private(set) var appManagementPreferences = AppManagementPreferences.default
    private(set) var pendingIdentifierSearchEnabled: Bool?
    private var identifierSearchRetryScheduled = false
    private var appManagementGeneration: UInt64 = 0
    private var isApplyingIdentifierSearch = false
    private weak var identifierSearchSettingsView: AppManagementSettingsView?
    /// Tests can restrict readiness, never bypass actual lifecycle/input owners.
    var identifierSearchPresentationReadinessCheck: (() -> Bool)?
    private(set) var appearancePreferences = AppearancePreferences.default
    private(set) var pendingAppearancePreferences: AppearancePreferences?
    private var isApplyingAppearance = false
    private var appearanceRetryScheduled = false
    private weak var configuredAppearanceSettingsView: AppearanceSettingsView?
    /// Test-only additional readiness restriction; never bypasses real input ownership.
    var appearancePresentationReadinessCheck: (() -> Bool)?
    /// Native dialog ownership is instance-counted and release is idempotent.
    @MainActor
    func acquireApplicationModalLease() -> () -> Void {
        let owner = languagePresentationController
        let token = owner?.acquire(.modal)
        let gate = ApplicationSheetCompletionGate()
        return { [weak self] in
            guard gate.claim() else { return }
            if let token { owner?.release(token) }
            self?.scheduleLanguageReadinessRetry()
        }
    }

    @MainActor
    func installActionFeedback(in host: NSView) {
        guard !didRunFinalTeardown else { return }
        teardownActionFeedback()
        let view = ActionFeedbackNoticeView(frame: .zero, strings: languageStrings)
        view.applyMaterialPolicy(reduceTransparency: effectiveMaterialPolicy.reduceTransparency,
                                 increaseContrast: effectiveMaterialPolicy.increaseContrast)
        host.addSubview(view)
        actionFeedbackView = view
        view.onPresentationApplied = { [weak self] in self?.layoutActionFeedback() }
        layoutActionFeedback()
        rebindCurrentPresentationActions()
    }

    @MainActor
    func teardownActionFeedback() {
        actionFeedbackGeneration &+= 1
        actionFeedbackView?.onPresentationApplied = nil
        actionFeedbackView?.teardown()
        actionFeedbackView?.removeFromSuperview()
        actionFeedbackView = nil
    }

    @MainActor
    func layoutActionFeedback() {
        guard let view = actionFeedbackView, let root = view.superview else { return }
        let width = min(560, max(0, root.bounds.width - 48))
        let height = view.requiredPresentationHeight(forWidth: width)
        let top: CGFloat
        if let field = search?.field, field.superview === root { top = field.frame.minY - 12 }
        else { top = root.bounds.maxY - 80 }
        view.frame = NSRect(x: root.bounds.midX - width / 2,
                            y: max(root.bounds.minY, top - height), width: width, height: height)
        view.autoresizingMask = [.minXMargin, .maxXMargin, .minYMargin]
    }

    /// Startup creates controllers before the root. Rebind genuine actions after root/realm changes.
    @MainActor
    private func rebindCurrentPresentationActions() {
        guard !didRunFinalTeardown, let assembly else { return }
        if let launch = launchController, launchFeedbackAssembly === assembly {
            installLaunchAttemptFeedback(launch, assembly: assembly)
        }
        if appContextMenuController != nil { installAppContextMenu(assembly: assembly) }
    }

    /// Failure feedback is inert; the shared launch controller still owns every validation/API call.
    @MainActor
    func installLaunchAttemptFeedback(_ launch: AppLaunchController, assembly: AppCatalogAssembly) {
        self.launchController = launch
        launchFeedbackAssembly = assembly
        launch.interactionIsAvailable = { [weak self] in
            guard let self else { return false }
            return !self.options.gestureValidation && self.appRemovalCoordinator?.isBusy != true
        }
        let rootEpoch = actionFeedbackGeneration
        let languageEpoch = languageGeneration
        launch.onLaunchAttempt = { [weak self, weak launch, weak assembly] outcome in
            guard let self, !self.didRunFinalTeardown, self.actionFeedbackGeneration == rootEpoch,
                  self.languageGeneration == languageEpoch, self.launchController === launch,
                  self.assembly === assembly else { return }
            switch outcome {
            case .launched: ClickCensus.hit(ClickCensus.Sink.launchAccepted)
            default: ClickCensus.hit(ClickCensus.Sink.launchRejectedPrefix + String(describing: outcome))
            }
            if outcome == .launched { self.actionFeedbackView?.clear() }
            else if let reason = ApplicationActionFeedback.launchReason(outcome) { self.showActionFeedback(reason) }
            _ = self.activationComposition?.handleLaunchOutcome(outcome)
        }
    }

    @MainActor
    private func showActionFeedback(_ reason: ActionFeedbackTextKey) {
        guard !didRunFinalTeardown, let strings = languageStrings, let view = actionFeedbackView else { return }
        // Retain one view, but put the passive message above any currently open folder visual.
        if let parent = view.superview { parent.addSubview(view, positioned: .above, relativeTo: nil) }
        view.show(reason: reason, strings: strings)
    }

    @MainActor
    @discardableResult
    func handleFinderReveal(_ record: AppRecord) -> FinderRevealOutcome {
        guard !options.gestureValidation, !didRunFinalTeardown, let provider = assembly?.provider,
              let current = provider.record(for: record.id), current.canonicalURL == record.canonicalURL,
              !provider.isHidden(current.id), !appManagementPreferences.isHidden(current) else {
            if !didRunFinalTeardown { showActionFeedback(.finderUnavailable) }
            return .rejectedUnavailable
        }
        guard actionFileExists(current.canonicalURL) else {
            showActionFeedback(.finderMissing)
            return .rejectedMissingFile
        }
        fileRevealRequester(current.canonicalURL)
        actionFeedbackView?.clear()
        return .requested
    }

    /// The existing root gets one inert status view, never a new window or grid geometry.
    @MainActor
    func installCatalogStatus(in host: NSView) {
        guard !didRunFinalTeardown else { return }
        catalogStatusGeneration &+= 1
        catalogStatusRefreshScheduled = false
        catalogStatusView?.teardown()
        catalogStatusView?.removeFromSuperview()
        let status = AppGridStatusView(frame: .zero, strings: languageStrings)
        status.applyMaterialPolicy(reduceTransparency: effectiveMaterialPolicy.reduceTransparency,
                                   increaseContrast: effectiveMaterialPolicy.increaseContrast)
        host.addSubview(status)
        catalogStatusView = status
        catalogStatusPresentationIsHidden = true
        status.onPresentationApplied = { [weak self, weak status] in
            guard let self, let status, self.catalogStatusView === status else { return }
            // The renderer has just applied its own semantic visibility. Preserve
            // that committed result before composing the Library mode mask.
            self.catalogStatusPresentationIsHidden = status.isHidden
            self.applyCatalogStatusVisibility()
            self.layoutCatalogStatus()
        }
        layoutCatalogStatus()
        scheduleCatalogStatusRefresh()
    }

    /// Reads committed presentation only; pending query text cannot fabricate no-results.
    @MainActor
    var displayedCatalogStatus: AppGridUIState {
        guard let assembly else { return .ready } // Neutral lab is not a loading catalog.
        let provider = assembly.provider
        let hasVisibleApps = provider.servedSnapshot?.records.contains { !provider.managementPreferences.isHidden($0) } ?? false
        return CatalogStatusPresentation.resolve(refresh: assembly.refreshController.state,
            hasSnapshot: provider.servedSnapshot != nil, hasVisibleApps: hasVisibleApps,
            hasCommittedQuery: provider.activeQuery?.isEmpty == false,
            committedResultIsEmpty: provider.presentationRecords.isEmpty)
    }

    /// Data and locale events coalesce. Never lookup/format state text on a Core callback.
    @MainActor
    func scheduleCatalogStatusRefresh() {
        guard !didRunFinalTeardown, catalogStatusView != nil, !catalogStatusRefreshScheduled else { return }
        catalogStatusRefreshScheduled = true
        let generation = catalogStatusGeneration
        DispatchQueue.main.async { [weak self] in
            guard let self, !self.didRunFinalTeardown, self.catalogStatusGeneration == generation else { return }
            self.catalogStatusRefreshScheduled = false
            self.catalogStatusView?.update(state: self.displayedCatalogStatus)
            self.applyCatalogStatusVisibility()
            self.layoutCatalogStatus()
        }
    }

    @MainActor
    private func applyCatalogStatusVisibility() {
        guard !didRunFinalTeardown, let status = catalogStatusView else { return }
        let hidden = catalogStatusPresentationIsHidden || appLibraryOwner?.isOpen == true
        status.isHidden = hidden
        status.setAccessibilityElement(!hidden)
    }

    @MainActor
    func layoutCatalogStatus() {
        guard let status = catalogStatusView, let host = status.superview else { return }
        let hasContent = assembly?.provider.presentationEntries.isEmpty == false
        let compact = hasContent && (status.state == .refreshing || status.state == .partialFailure)
        status.setCompactPresentation(compact)
        if compact {
            let geometry = MainGridLayoutMetrics.geometry(bounds: host.bounds,
                itemCount: mainGridCapacity.itemsPerPage, mode: .ordinary,
                capacity: mainGridCapacity, appearance: appearancePreferences.mainItemAppearance)
            let contentMinY = geometry.frame(for: mainGridCapacity.itemsPerPage - 1,
                itemCount: mainGridCapacity.itemsPerPage)?.minY ?? host.bounds.minY
            let dotsFrame = pageDotsView.flatMap { $0.superview === host ? $0.frame : nil }
            status.frame = CatalogStatusLayout.compactFrame(in: host.bounds, gridContentMinY: contentMinY,
                pageDotsFrame: dotsFrame, height: AppGridStatusView.compactPresentationHeight,
                gridContentMaxY: geometry.area.maxY,
                searchFrame: search?.field.superview === host ? search?.field.frame : nil,
                settingsFrame: launcherSettingsButton?.superview === host ? launcherSettingsButton?.frame : nil)
            status.autoresizingMask = [.minXMargin, .maxYMargin]
            return
        }
        let width = min(440, max(100, host.bounds.width * 0.75))
        let height = max(100, status.requiredPresentationHeight(forWidth: width))
        status.frame = NSRect(x: host.bounds.midX - width / 2,
                              y: host.bounds.midY - height / 2,
                              width: width, height: height)
        status.autoresizingMask = [.minXMargin, .maxXMargin, .minYMargin, .maxYMargin]
    }

    @MainActor
    func teardownCatalogStatus() {
        catalogStatusView?.onPresentationApplied = nil
        catalogStatusGeneration &+= 1
        catalogStatusRefreshScheduled = false
        catalogStatusView?.teardown()
        catalogStatusView?.removeFromSuperview()
        catalogStatusView = nil
        catalogStatusPresentationIsHidden = true
    }

    /// 启动器主面板右上角设置入口（不依赖菜单栏 status item；Ice 折叠时仍可发现）。
    private var launcherSettingsButton: NSButton?
    private(set) var pageDotsView: PageDotsView?
    /// Test injection only; default always uses real application/window lifecycle.
    var pageNavigationLifecycleCheck: (() -> Bool)?
    private var currentMaterialPolicy: LaunchcopyMaterialPolicy?
    @MainActor private var effectiveMaterialPolicy: LaunchcopyMaterialPolicy {
        currentMaterialPolicy ?? LaunchcopyMaterialPolicy()
    }
    /// Phase 1I：模糊壁纸（CALayer 挂在 contentView.layer 最底，对齐 LaunchBetter）。
    var wallpaperBackdrop: WallpaperBackdropController?
    /// Phase 1H：Launch at Login 服务（生产 SMAppService；测试不经此路径）。
    private var launchAtLoginService: (any LaunchAtLoginServicing)?
    /// Phase 1G T-1G-E：进程 teardown 闸门（quit / willTerminate 共用；恰好一次）。
    private var didRunFinalTeardown = false
    var surface: PagingSurface?
    /// 容器（surface + search field 的 sibling overlay 宿主；folder 打开层挂此层，覆盖全表面）。
    var container: NSView?
    private var telemetryBridge: PagingTelemetryBridge?
    var assembly: AppCatalogAssembly?
    private var launchController: AppLaunchController?
    /// Phase 1C：键盘焦点控制器（T-1C-B）+ 键盘启动适配器（T-1C-C）。
    var keyboardController: KeyboardFocusController?
    private var launchAdapter: KeyboardLaunchAdapter?
    /// Phase 1D：搜索控制器（T-1D-E 装配；field/controller/presentation 接线）。
    var search: AppSearchController?
    /// Phase 1E：folder 打开状态（会话内；T-1E-E 接线）。
    private(set) var folderOpenState: FolderOpenState?
    /// Phase 1E：folder 打开层视图（T-1E-C；T-1E-E 接线）。
    private(set) var folderOverlay: FolderOverlayView?
    private var isResolvingFolderLayout = false
    private var pendingFolderLayout: FolderLayoutSnapshot?
    private var folderLayoutRetryScheduled = false
    /// Pointer close may retain the real overlay as a drawing-only visual while logical state
    /// closes immediately. Retaining the view avoids a model-pixel bitmap snapshot losing the
    /// presentation transform that was visible at the interruption point.
    private var folderExitVisual: FolderExitVisualState?
    private var folderMotionGeneration: UInt64 = 0
    private var folderEntranceAppearanceGeneration: UInt64?
    private var pendingPointerFolderID: FolderID?
    /// Phase 1E：folder 标题编辑 first responder（T-1E-D；T-1E-E 接线）。
    private(set) var folderTitleEditor: FolderTitleEditor?
    private struct FolderRenameContext {
        let token: UInt64
        let folderID: FolderID
        let revision: UInt64
        let layout: PersistentWorkspaceLayout
        let storeEpoch: UInt64
    }
    private var folderRenameContext: FolderRenameContext?
    private var folderRenameGeneration: UInt64 = 0
    private(set) var lastFolderRenameResult: LayoutMutationResult?
    /// Phase 1F：drag UI 协调器（T-1F-D1；统一输入仲裁 + 中性拖拽视觉）。
    private(set) var dragCoordinator: DragUISessionCoordinator?
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

    enum UITestConfigurationError: Error { case requiresWindowed, outsideSyntheticCatalog }

    /// Resolve before opening preferences or touching the ordinary workspace.
    /// Existing test roots may contain deliberate fault fixtures; no chmod/reset.
    @MainActor
    func configureUITestProfile(bundleURL: URL) throws {
        guard let id = options.uiTestProfile else {
            if options.gestureValidation || options.integratedPreview { throw UITestConfigurationError.requiresWindowed }
            return
        }
        guard options.uiTestWindowed, !(options.gestureValidation && options.integratedPreview) else {
            throw UITestConfigurationError.requiresWindowed
        }
        if options.integratedPreview, !options.catalogRoots.isEmpty {
            throw UITestConfigurationError.outsideSyntheticCatalog
        }
        let profile = try UITestProfile.resolve(bundleURL: bundleURL, profileID: id)
        if options.integratedPreview { try IntegratedPreviewEntry.validateStorage(profile) }
        let allowed = profile.applicationsDirectoryURL.pathComponents
        for root in options.catalogRoots {
            let actual = root.standardizedFileURL.resolvingSymlinksInPath().pathComponents
            guard root.isFileURL, actual.starts(with: allowed) else {
                throw UITestConfigurationError.outsideSyntheticCatalog
            }
        }
        for directory in [profile.rootURL, profile.layoutDirectoryURL, profile.applicationsDirectoryURL,
                          profile.wallpaperCacheDirectoryURL] {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true,
                                                   attributes: [.posixPermissions: 0o700])
        }
        // Recheck after directory creation before accepting any storage namespaces.
        let acceptedProfile = try UITestProfile.resolve(bundleURL: bundleURL, profileID: id)
        if options.integratedPreview { try IntegratedPreviewEntry.validateStorage(acceptedProfile) }
        uiTestProfile = acceptedProfile
    }

    // MARK: - 启动

    func applicationDidFinishLaunching(_ notification: Notification) {
        do { try configureUITestProfile(bundleURL: Bundle.main.bundleURL) }
        catch {
            // Invalid isolation is fatal for this test process, never production fallback.
            print("paging-ui-test: isolated profile configuration rejected")
            NSApp.terminate(nil)
            return
        }
        installLanguagePreferences()
        installAppearancePreferences()
        installMainGridCapacityPreferences()
        installAppManagementPreferences()
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
        if let languageStrings { surface.relabel(strings: languageStrings) }
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

        // Choose the final style before mounting content: changing it later can detach
        // PagingSurface and permanently tear down its runtime. Production stays screen-covering.
        let screen = NSScreen.main
        let fallbackFrame = NSRect(x: 0, y: 0, width: 1470, height: 956)
        let configuration = Self.initialWindowConfiguration(
            screenFrame: screen?.frame ?? fallbackFrame,
            visibleFrame: screen?.visibleFrame ?? fallbackFrame,
            uiTestWindowed: options.uiTestWindowed)
        let initialFrame = configuration.frame
        let window = QuitOnBlankClickWindow(
            contentRect: initialFrame,
            styleMask: configuration.styleMask,
            backing: .buffered,
            defer: false
        )
        window.setFrame(initialFrame, display: false)
        // LaunchBetter 同款：窗口必须透明，壁纸由内容层绘制；不透明黑窗会盖死背景。
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = false
        window.isReleasedWhenClosed = false
        window.collectionBehavior = configuration.collectionBehavior
        window.level = .normal
        window.title = uiTestProfile == nil ? "" : "Launchcopy — Isolated UI Test"
        // 容器：surface + search field 作为 sibling overlay（field 不随页面容器平移）。
        // T-1F-B10-regression-fix §2.1 取证：容器 = 投递探针（只读观测 AppKit 实际投递目标
        // 的类名链；hitTest/mouseDown 原样转发 super，零行为变更；非探针 contentView 零影响）。
        let container = ClickDeliveryProbeView(frame: NSRect(origin: .zero, size: initialFrame.size))
        window.contentView = container
        self.container = container
        window.mainGridInputIsAvailable = { [weak self] in
            self?.mainGridIsReadable ?? false
        }
        container.onLayout = { [weak self] in self?.layoutSearchField() }
        // LaunchBetter：壁纸 CALayer 挂在 root.layer 最底，前景 grid 是透明 subview。
        container.wantsLayer = true
        container.layer?.isOpaque = false
        container.layer?.backgroundColor = LaunchcopyVisualTokens.fallbackBackdropColor().cgColor
        let backdrop: WallpaperBackdropController
        if let profile = uiTestProfile {
            let provider = WallpaperBackdropProvider(cacheDirectory: profile.wallpaperCacheDirectoryURL)
            backdrop = WallpaperBackdropController(imageLoader: WallpaperBackdropController.backgroundLoader { request, sourceURL in
                provider.blurredWallpaper(for: request, sourceURL: sourceURL)
            }, sourceInspector: WallpaperBackdropController.backgroundSourceInspector())
        } else { backdrop = WallpaperBackdropController() }
        backdrop.attach(to: container)
        self.wallpaperBackdrop = backdrop
        installIsolatedWallpaperDiagnostics(backdrop: backdrop, window: window)
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
            if let languageStrings { field.relabel(strings: languageStrings) }
            field.frame = Self.searchFieldFrame(in: container.bounds,
                                                safeAreaTop: window.screen?.safeAreaInsets.top ?? 0)
            field.autoresizingMask = [.minXMargin, .maxXMargin, .minYMargin]
            container.addSubview(field)
            search.install(in: window)
        }
        // Phase 1H：主面板右上角齿轮 → 激活设置（菜单栏被 Ice 折叠时的可见入口）。
        installLauncherSettingsButton(in: container)
        installMainGridSpaceNotice(in: container)
        installPageDots(in: container)
        installCatalogStatus(in: container)
        installActionFeedback(in: container)
        installAppLibrary(in: container)
        // T-1C-D repair：空白背景首击退出（详见下方 QuitOnBlankClickWindow 注释）。
        // T-1D 修复：搜索激活时空白点击 → 退出搜索（不终止应用）；搜索未激活 → 退出。
        // T-1E-E：folder 打开时空白点击 → 关闭 folder（不退出）；folder 关闭后下一次真实
        // 背景单击才退出（blank-click 两阶段，ADR-008 §3 Q10）。
        installFolderWindowInput(on: window)
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
            self?.handleEscapeDuringDrag() ?? false
        }
        window.delegate = self
        // T-1G-B：不再使用 setFrameAutosaveName 恢复非覆盖尺寸；panel 由 LauncherWindowController 放置。
        self.window = window
        configureFolderDropTimingObservers()
        installLeadingLibraryWindowInput(on: window)
        window.libraryActiveProvider = { [weak self] in self?.appLibraryOwner?.isOpen == true }
        window.onLibraryEscape = { [weak self] in self?.appLibraryOwner?.handleEscape() ?? false }

        // T-1F-B10-regression-fix §2.1 第 4 项（4b，并入 E4 门控构建）：启动期一次性状态补读。
        // **仅供诊断 A/B 实验，禁止作为生产路径常驻。** 仅 `PAGING_CLICK_PROBE_MANUAL_DELIVERY=1`
        // 时打印一行（中性布尔/枚举级状态，无身份/坐标/标题；风格同既有 paging-fullscreen
        // 单行 + fflush）：`window.ignoresMouseEvents` / `contentView.ignoresMouseEvents` /
        // `window.level` / `window.styleMask` / `NSApp.isActive && keyWindow==self`。
        // 每击内联 E1 复核（`event.windowNumber == self.windowNumber`）已有布点（sendEvent
        // leftMouseDown 分支），本步不重复，零行为变更。
        if QuitOnBlankClickWindow.isManualDeliveryProbeEnabled {
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
        launcher.backgroundUITestMode = options.uiTestWindowed
        if options.gestureValidation || options.integratedPreview {
            launcher.backgroundUITestTitle = options.integratedPreview
                ? "Launchcopy — Integrated Preview" : "Launchcopy — Real Gesture Validation"
            launcher.foregroundWindowedPresentation = true
        }
        launcher.attach(window: window)
        launcher.preferredFirstResponder = keyboardController
        // 启动器一隐藏（空白/ESC/启动应用/菜单隐藏等）→ 强制关掉设置窗，避免「面板没了设置还在」。
        launcher.onLauncherDidHide = launcherDidHideHandler()
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
        refreshMainGridReadability()
        schedulePendingMainGridCapacityPresentation()
        // Catalog presentation is applied by the authoritative idle-boundary callbacks.
        // Diagnostic sampling must not force a delayed Core/UI mutation.

        // 5c') T-1G-E：ActivationComposition — prefs → shortcut/hot-corner/four-finger/session。
        //      默认 shortcut/hot corner Off；fourFinger userEnabled 来自 prefs（默认 true）。
        //      四指生产路径 = process + flushPendingShows → apply 到同一 launcher。
        installActivationComposition(launcher: launcher)

        // 5c'') T-1G-C/E：StatusItemController 宿主（prefs.showStatusItem；失败降级不崩溃）。
        //       菜单 validation 读 coordinator.committedVisibility；Quit → composition.handleQuit。
        installStatusItem(launcher: launcher)

        // 5d) T-1G-E：空白背景 → hide（驻留）；folder/search/drag 优先级仍在 QuitOnBlankClickWindow。

        // 6) Reduce Motion 系统偏好变化监听。
        motionObserver = Self.observeAccessibilityDisplayChanges { [weak self] in
            self?.handleAccessibilityDisplayChange()
        }

        // 7) GUI 自驱模式（T-step6）：真实 runloop 下跑脚本化手势旅程，输出帧数/事件统计后退出。
        //    输入仍是 synthetic（物理门属 T-step8）；帧源 = RunLoopFrameDriver 60Hz 泵
        //    （T-worker-b-frame-fix：display link 在本环境零回调，Timer(.common) 泵为默认驱动）。
        if ProcessInfo.processInfo.environment["PAGING_PROTOTYPE_GUI_SELFDRIVE"] == "1" {
            startSelfDriveTour()
        }
    }

    /// Shared runtime/test assembly seam; never substitute ordinary roots for a profile.
    @MainActor
    func makeContentAssembly() -> AppCatalogAssembly? {
        guard options.uiTestProfile == nil || uiTestProfile != nil else { return nil }
        var contentOptions = options
        if options.integratedPreview {
            guard uiTestProfile != nil, !options.gestureValidation, options.catalogRoots.isEmpty else { return nil }
            // Writable profile ownership is independent of read-only catalog access.
            contentOptions.catalogRoots = CatalogRoots.defaults
        } else if let profile = uiTestProfile, contentOptions.catalogRoots.isEmpty {
            contentOptions.catalogRoots = [profile.applicationsDirectoryURL]
        }
        return AppRuntimeFactory.makeAssembly(options: contentOptions)
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
        guard let assembly = makeContentAssembly() else {
            print("paging-prototype: 装配失败（AppRuntimeFactory 返回 nil）—— 以中性模式运行")
            return
        }
        if let languageStrings {
            assembly.provider.relabel(strings: languageStrings)
            assembly.renderer.relabel(strings: languageStrings)
        }
        surface.contentProvider = assembly.provider
        surface.renderer = assembly.renderer
        assembly.renderer.committedPageProvider = { [weak surface] in
            surface?.core.committedPage ?? 0
        }
        assembly.refreshController.itemsPerPage = surface.itemsPerPage
        // T-1E-H2 repair：provider.servedPageCount 用实例 itemsPerPage（与 surface 对齐），
        // 非默认 --items-per-page 下搜索激活路径不再按硬编码 35 推导页数。
        assembly.provider.itemsPerPage = surface.itemsPerPage

        // 呈现提交（idle 边界 anchor remap 后）→ surface pageCount/revision 刷新 + telemetry。
        // 顺序：先 refreshPresentation（采纳新 revision + provider.servedPageCount），
        // 再 setPageCount(update 的 itemsPerPage 对齐页数) —— 非默认 --items-per-page 时
        // provider.servedPageCount（35 基准）可能与 update.plan.pageCount 不同，以后者为准。

        // idle 边界（手势结束/取消 → Core 回 idle）：latest-wins pending 一次性提交 + anchor remap。
        // 回调恒在主线程（PagingSurface 事件）→ assumeIsolated 确定性成立。
        // F1（T-1C-C repair）：同一 idle 边界顺带做键盘跨页 settle 调和 —— 键盘跨页 settle
        // 完成/中断回到 idle 时，把焦点重新落定到 committed/displayed 页，避免残留旧页映射。
        // T-1D-E：搜索提交优先（处理 pending catalog snapshot 重跑查询 + pending search result），
        // 刷新控制器随后（无 pending catalog snapshot 时 no-op）。


        // 扫描完成但 surface 已 idle（Core 初始化不触发 onIdleBoundary，启动首扫依赖此路径）：
        // 非 busy 状态变化时若 surface idle → 立即提交；手势进行中则交给 onIdleBoundary。
        // 回调经 @MainActor controller 触发 → assumeIsolated 确定性成立。
        installFinalCatalogRuntimeCallbacks(assembly: assembly, surface: surface)

        // 图标异步结果 → telemetry（icon_async_state；中性枚举）。
        assembly.renderer.onIconApplyResult = { [weak self] _, result in
            self?.telemetryBridge?.recordIconAsyncState(result)
        }

        self.assembly = assembly
        installAppSources(assembly: assembly)
        assembly.begin()
        assembly.provider.receiveManagementPreferences(appManagementPreferences)
        installAppContextMenu(assembly: assembly)
        assembly.renderer.showsAppLabels = appearancePreferences.showsAppLabels
        assembly.renderer.itemAppearance = appearancePreferences.mainItemAppearance

        // 3c) t11：单击启动 smoke（cell 校验 → 当前 catalog 重新确认 → NSWorkspace 公开 API）。
        let launch = AppLaunchController(
            surface: surface,
            assembly: assembly,
            launcher: options.gestureValidation ? GestureValidationAppLauncher() : NSWorkspaceAppLauncher(),
            session: telemetryBridge?.session
        )
        launch.prepareLaunchObservation = { [weak self] record in
            self?.appLibraryOwner?.activity?.prepareObservation(for: record)
        }
        launch.install()
        // T-1F-B8-wave-c census（S9）+ T-1G-E：成功启动 → hide launcher（驻留）；拒绝/失败保持可见。
        // AppLaunchController 冻结面只读，经公开 onLaunchAttempt 回调接线（不改 AppLaunchController.swift）。
        installLaunchAttemptFeedback(launch, assembly: assembly)

        // 3d) Phase 1C：键盘焦点 + 启动适配器接线（T-1C-C）。
        //     焦点模型（T-1C-A）→ 键盘控制器（T-1C-B，单一键盘代理）→ 启动适配器（本任务）。
        //     键盘启动复用 launch.handleCell —— 与鼠标单击共享同一校验管线，无并行启动路径。
        let focusModel = AppGridFocusModel()
        let keyboard = KeyboardFocusController(columns: 5)
        keyboard.install(on: surface, focusModel: focusModel)
        keyboard.gridInputIsAvailable = { [weak self] in
            self?.mainGridIsReadable == true && self?.appRemovalCoordinator?.isBusy != true
        }
        let launchAdapter = KeyboardLaunchAdapter(
            launchController: launch,
            cellResolver: { [weak surface] identity in
                guard let renderer = surface?.renderer as? AppGridRenderer else { return nil }
                return renderer.pageView(forPage: identity.pageIndex)?.cell(at: identity.slotIndex)
            }
        )
        keyboard.onActivate = { [weak self, weak launchAdapter] identity in
            guard self?.mainGridIsReadable == true else { return }
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

        // presentation controller 应用 catalog snapshot（搜索激活路径）→ 刷新 surface +
        // urlResolver（refresh controller 未参与时需自行更新）。搜索激活时按过滤后
        // presentationRecords 刷新（不覆盖 pageCount）；非搜索时对齐 update.plan.pageCount。

        let search = AppSearchController(presentation: presentation,
                                         keyboardController: keyboard,
                                         surface: surface)
        // Command-F → 搜索框 first responder（responder 转移 seam）。
        // Phase 1F：搜索激活先 cancel 进行中的 drag（.searchActivated 统一出口）。
        keyboard.onSearchShortcut = { [weak self, weak search] in
            self?.dragCoordinator?.cancel(reason: .searchActivated)
            search?.activateSearch()
        }
        search.pendingCommitter = { [weak assembly] page in
            assembly?.commitPendingAtIdleBoundary(currentPage: page)
        }
        search.gridInputIsAvailable = { [weak self] in
            self?.mainGridIsReadable == true && self?.appRemovalCoordinator?.isBusy != true
        }
        self.search = search

        // 3f) Phase 1E：folder 打开层 / 标题编辑 / 成员启动接线（T-1E-E）。
        //     folder 打开状态（会话内）→ 打开层视图 → 键盘控制器 folder 感知 seam。
        installFolderWiring(assembly: assembly, surface: surface,
                            keyboard: keyboard, launch: launch)

        // 3g) Phase 1F：drag UI 装配（T-1F-D1）。
        //     统一输入仲裁协调器 + 中性拖拽视觉；commit 经 onCommit seam 暂存会话内布局
        //     （T-1F-E 接 provider/persist；本阶段零磁盘写）。
        // Dedicated persistence only: resolution failure admits no shared-temp I/O.
        installLayoutStore(makeLayoutStore())
        installDragUI(surface: surface, assembly: assembly)
    }

    // MARK: - Phase 1E folder 接线（T-1E-E）

    /// 装配 folder 打开层 / 标题编辑 / 成员启动，并接线到键盘控制器与搜索控制器的模式 seam。
    /// - 成员启动复用 `AppLaunchController.handleCell`（合成 cell 绑定正确 revision；无并行启动路径）。
    /// - folder cell 绝不进入 app launch：`ActivationRouter` 分支 folder → open（T-1E-D 已接线）。
    /// - 标题编辑 first responder 经 `modeFirstResponderProvider` 参与 key-window 重建。
    /// Window-owned routes are installed after the actual window exists, independently
    /// of whether the content assembly or window was created first.
    @MainActor
    func installFolderWindowInput(on window: QuitOnBlankClickWindow) {
        window.folderOpenStateProvider = { [weak self] in self?.folderOpenState }
        window.onFolderTitlePointerDown = { [weak self] event in self?.handleFolderTitlePointerDown(event) ?? false }
        // Resolve at event time: content may be assembled before or after the window,
        // and a subsequent assembly must not leave this window targeting an old overlay.
        window.onFolderScroll = { [weak self] event in
            guard let self, let overlay = self.folderOverlay else { return }
            overlay.scrollWheel(with: event)
            // Isolated native diagnostics are in-memory and identity/path-free.
            // No event monitor, persistence, or formal-app accessibility change.
            if self.uiTestProfile != nil {
                let pager = overlay.trackpadPager
                overlay.titleEditButton.setAccessibilityHelp(
                    "Folder input: phase=\(event.phase.rawValue); momentum=\(event.momentumPhase.rawValue); "
                    + "horizontal=\(event.scrollingDeltaX != 0); dominant=\(abs(event.scrollingDeltaX) >= abs(event.scrollingDeltaY)); "
                    + "admitted=\(overlay.canBeginTrackpadPaging?() != false); "
                    + "transition=\(overlay.isPanelTransitionActive); available=\(overlay.isMemberPresentationAvailable); "
                    + "state=\(pager.core.state); offset=\(pager.core.visualOffset); page=\(overlay.currentInnerPage)")
            }
        }
        configureFolderDropTimingObservers()
    }

    @MainActor
    func installFolderWiring(assembly: AppCatalogAssembly,
                                     surface: PagingSurface,
                                     keyboard: KeyboardFocusController,
                                     launch: AppLaunchController) {
        // Inner capacity is independent of the outer pager; first open resolves its viewport.
        let folderOpenState = FolderOpenState(membersPerPage: 15)
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
        if let languageStrings { overlay.relabel(strings: languageStrings) }
        overlay.membersPerPage = folderOpenState.membersPerPage
        overlay.onActivateMember = { [weak self] appID in
            self?.launchMember(appID)
        }
        overlay.onRequestClose = { [weak self] in
            self?.closeFolder(animatedFromPointer: true)
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
            // Restore stacking from the pre-collapse capture; the source may be reused now.
            self.dragCoordinator?.elevateMoveOutPreview(above: overlay)
        }
        overlay.onInnerPageChange = { [weak self] page in
            self?.setFolderInnerPage(page, clearsSelection: true)
        }
        overlay.canBeginTrackpadPaging = { [weak self] in
            guard let self else { return false }
            return !self.didRunFinalTeardown && !self.isTitleEditing
                && self.folderRenameContext == nil && !self.workspaceQuit.isPending
                && self.folderEntranceAppearanceGeneration == nil && self.folderExitVisual == nil
                && self.appLibraryOwner?.hasPresentationOwnership != true
                && self.window?.attachedSheet == nil && NSApp?.modalWindow == nil
                && self.languagePresentationController?.hasInteractionOwners != true
        }
        overlay.onTrackpadPagingActivity = { [weak self] active in
            guard let self else { return }
            if active { self.keyboardController?.clearInnerSelectionForPageChange() }
            else {
                self.schedulePendingAppearancePresentation()
                self.scheduleFolderLayoutRefresh()
                self.scheduleLanguageReadinessRetry()
            }
        }
        self.folderOverlay = overlay
        configureFolderDropTimingObservers()

        // A fresh editor per session prevents a late old focus-loss notification
        // from committing into a newly opened folder.
        overlay.onRequestTitleEdit = { [weak self] in self?.beginTitleEditing() }
        overlay.onWillInvalidateTitleEditor = { [weak self] in self?.finishFolderTitleEditing(returnFocus: false) }
        let previousStateChange = surface.appEvents.onStateChange
        surface.appEvents.onStateChange = { [weak self] state in
            previousStateChange?(state)
            MainActor.assumeIsolated { self?.refreshTitleEditReadiness() }
        }

        // 键盘控制器 folder 感知 seam（T-1E-D 声明；T-1E-E 接线）。
        keyboard.folderOpenStateProvider = { [weak self] in self?.folderOpenState }
        keyboard.onOpenFolder = { [weak self] identity in self?.openFolder(identity) }
        keyboard.onCloseFolder = { [weak self] in self?.closeFolder() }
        keyboard.onActivateMember = { [weak self] appID in self?.launchMember(appID) }
        keyboard.onInnerPageChange = { [weak self] page in self?.setFolderInnerPage(page) }
        keyboard.folderOverlayProvider = { [weak self] in self?.folderOverlay }
        keyboard.onTitleEditRequest = { [weak self] in self?.beginTitleEditing() }
        keyboard.onTitleCommit = nil
        keyboard.onTitleCancel = nil

        // 搜索控制器 key-window 重建模式 seam（标题编辑 > folder 打开 > 搜索 > 顶层）。
        search?.modeFirstResponderProvider = { [weak self] in
            guard let self else { return nil }
            if let responder = self.appLibraryOwner?.preferredFirstResponder { return responder }
            // Restore the current mounted title request even before AppKit has
            // acquired its field editor. Falling back would end the edit.
            if self.folderRenameContext != nil, let editor = self.folderTitleEditor,
               self.folderOverlay?.titleEditorView === editor,
               let editorWindow = editor.window, editorWindow === self.window {
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
    /// - Title editing rejects pointer arbitration; active search allows thresholded clicks
    ///   while preventing entry into the drag controller.
    @MainActor
    func installDragUI(surface: PagingSurface, assembly: AppCatalogAssembly) {
        let coordinator = DragUISessionCoordinator(host: surface)
        DragUISessionCoordinator.shared = coordinator
        let pageTurner = KeyboardPageTurner(surface: surface)

        coordinator.layoutProvider = { [weak self] in
            guard let self else { return nil }
            return self.currentPersistentLayout()
        }
        coordinator.catalogGenerationProvider = { [weak assembly] in
            assembly?.provider.servedRevision ?? 0
        }
        coordinator.catalogSnapshotProvider = { [weak assembly] in
            assembly?.provider.servedSnapshot
        }
        coordinator.folderCreationTitleProvider = { [weak self, weak assembly] target, source, layout in
            guard let self, let provider = assembly?.provider,
                  let catalog = provider.servedSnapshot else { return nil }
            return FolderCreationNaming.title(target: target, source: source, layout: layout,
                catalog: catalog,
                libraryPreferences: self.appLibraryOwner?.preferences.committed ?? .default,
                strings: self.languageStrings)
        }
        coordinator.geometryProvider = { [weak self] scope in
            self?.makeDragGeometry(scope: scope)
        }
        coordinator.onCommit = { [weak self] newLayout in
            self?.commitWorkspaceLayout(newLayout)
        }
        coordinator.onCellClick = { [weak self] cell in
            self?.handleDragCellClick(cell)
        }
        coordinator.onOverlayBlankClick = { [weak self] in
            self?.closeFolder(animatedFromPointer: true)
        }
        coordinator.topLevelPageTurn = { direction, timestamp in
            pageTurner.turn(direction: direction, timestamp: timestamp)
        }
        coordinator.folderPageTurn = { [weak self] delta in
            guard let self, let state = self.folderOpenState else { return }
            // Drag edge turns are not page-button clicks and must keep their session alive.
            self.setFolderInnerPage(state.innerPage + delta)
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
            if self.isTitleEditing { PointerInputDiagnostics.record(.titleEditingDenied); return false }
            return true
        }
        coordinator.dragStartGate = { [weak self] in
            guard let self else { return false }
            if !self.canCommitWorkspaceLayout { PointerInputDiagnostics.record(.layoutCommitDenied); return false }
            if self.search?.isSearchActive == true { PointerInputDiagnostics.record(.searchActiveDenied); return false }
            if self.isTitleEditing { PointerInputDiagnostics.record(.titleEditingDenied); return false }
            return true
        }
        coordinator.onSessionStateChange = { [weak self] state in
            defer {
                self?.schedulePendingAppearancePresentation()
                self?.scheduleFolderLayoutRefresh()
            }
            self?.refreshTitleEditReadiness()
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

    /// Single owner transaction for drag and context-menu organization commits.
    @MainActor
    @discardableResult
    func commitWorkspaceLayout(_ newLayout: PersistentWorkspaceLayout) -> Bool {
        guard canCommitWorkspaceLayout else { return false }
        recordFolderDropStage(.commitStart)
        let previousMainContent = assembly?.provider.presentationEntries ?? []
        let retainedFolderID: FolderID?
        if let provider = assembly?.provider, let previous = provider.expectedLayout,
           let folderID = folderOpenState?.openFolderID, let overlay = folderOverlay,
           overlay.currentEntry == provider.servedFolderSnapshot?.entry(for: folderID),
           folderOpenState?.openEntry == overlay.currentEntry,
           !overlay.isVisualOnly, !overlay.isPanelTransitionActive,
           currentPersistentLayout() == previous, !provider.hasPendingPresentationChanges,
           assembly?.searchPresentation.currentQuery?.isEmpty != false,
           provider.activeQuery?.isEmpty != false,
           surface?.core.state == .idle, surface?.isDirectNavigationActive != true,
           FolderReorderPresentationPolicy.isPureMemberPermutation(
               from: previous, to: newLayout, folderID: folderID) {
            retainedFolderID = folderID
        } else {
            retainedFolderID = nil
        }
        // Folder 成员成功移出后立即关闭打开层。内部重排不会减少成员数，
        // 因而保持 overlay 打开；移到顶层、移入其他 folder 或触发 dissolve
        // 都会使当前打开 folder 的成员数减少（或记录消失），应走统一 closeFolder 路径。
        let shouldCloseOpenFolder: Bool
        if let state = self.folderOpenState,
           let folderID = state.openFolderID {
            let nextMembers = newLayout.folder(id: folderID)?.members ?? []
            shouldCloseOpenFolder = state.openEntry?.members.contains { id in
                guard let record = self.assembly?.provider.record(for: id) else { return true }
                return !nextMembers.contains { $0.matches(record: record) }
            } ?? true
        } else {
            shouldCloseOpenFolder = false
        }
        // T-1F-D1-fix-e1：commit 必须落到呈现面（原实现只暂存 sessionLayout → 无可见效果）。
        // 1) 会话内布局（layoutProvider 一致性；点击/后续 drag 仍按新布局解析）。
        self.sessionLayout = newLayout
        self.workspaceNeedsSave = true
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
        guard self.assembly?.provider != nil, let surface = self.surface else {
            moveOutProxyHost?.removeFromSuperview()
            return false
        }
        self.assembly?.searchPresentation.itemsPerPage = surface.itemsPerPage
        let update = self.assembly?.searchPresentation.commitLayout(newLayout, currentPage: surface.core.committedPage)
        recordFolderDropStage(.providerReturn)
        // 3) 呈现刷新（refreshPresentation + setPageCount → live hosts 重渲染 + telemetry +
        //    焦点布局重建；同 revision 下 setPageCount 仍全量刷新 live hosts）。
        if let update {
            let retainingMainGrid = retainedFolderID.map { folderID in
                update.previousRevision == update.newRevision
                    && self.assembly?.provider.servedPageCount == surface.core.pageCount
                    && FolderReorderPresentationPolicy.hasUnchangedMainContent(
                        from: previousMainContent,
                        to: self.assembly?.provider.presentationEntries ?? [], folderID: folderID)
            } ?? false
            self.applyPresentationUpdate(update, overridePageCount: true,
                                         retainingMainGrid: retainingMainGrid)
        }
        recordFolderDropStage(.presentationReturn)
        // 3b) folder 保持打开时：把 openEntry / overlay 与刚提交的 servedFolderSnapshot
        //     对齐。否则 applyCommittedLayout 已写入新成员序，但 overlay 仍持有打开时
        //     的旧 FolderEntry → 用户看到"拖拽有预览、放下无效果"（folder 内重排）。
        if !shouldCloseOpenFolder {
            self.resyncOpenFolderAfterLayoutCommit()
            recordFolderDropStage(.folderRefreshReturn)
        }
        if shouldCloseOpenFolder {
            moveOutOverlay?.clearMoveOutRemainingAppProxy()
            // 防止 overlay 在 closeFolder/refresh 期间已丢失 owner，仍确保 host 不残留。
            moveOutProxyHost?.removeFromSuperview()
        }
        // 4) 异步持久化（coalescing sink；绝不阻塞主线程）。
        let persistenceGeneration = layoutRestoreGeneration
        if let store = layoutStore {
            workspacePersistence.submit(newLayout, to: store, epoch: persistenceGeneration,
                isCurrent: { [weak self] in
                    guard let self else { return false }
                    return !self.didRunFinalTeardown && self.layoutRestoreGeneration == persistenceGeneration
                }, observeState: { [weak self] in
                    self?.layoutPersistenceState = $0
                    self?.refreshTitleEditReadiness()
                },
                observeOutcome: { [weak self] in self?.handleWorkspacePersistenceOutcome($0) })
        }
        recordFolderDropStage(.commitReturn)
        return true
    }

    /// One neutral notice is updated, not a modal-alert storm. Accepted in-memory
    /// organization and last-known-good disk data remain intact on failure.
    @MainActor
    func handleWorkspacePersistenceOutcome(_ result: LayoutStoreFlushResult) {
        lastWorkspacePersistenceOutcome = result
        switch result {
        case .persisted, .nothingPending:
            workspaceNeedsSave = false
            workspaceSaveNotice?.isHidden = true
            return
        case .timedOut, .failed, .readOnly, .staleRejected, .rejectedOverLimit: break
        }
        guard !didRunFinalTeardown, let container else { return }
        if workspaceSaveNotice == nil {
            let notice = NSTextField(wrappingLabelWithString: "")
            notice.font = .systemFont(ofSize: 13)
            notice.textColor = .white
            notice.wantsLayer = true
            notice.layer?.backgroundColor = NSColor.black.withAlphaComponent(0.7).cgColor
            notice.layer?.cornerRadius = 6
            notice.frame = NSRect(x: 24, y: 18, width: min(440, max(container.bounds.width - 48, 100)), height: 38)
            notice.autoresizingMask = [.maxXMargin, .maxYMargin]
            notice.setAccessibilityRole(.staticText)
            notice.setAccessibilityLabel("布局保存状态")
            container.addSubview(notice)
            workspaceSaveNotice = notice
        }
        relabelWorkspaceSaveNotice()
        workspaceSaveNotice?.isHidden = false
    }

    @MainActor
    private func relabelWorkspaceSaveNotice() {
        guard let notice = workspaceSaveNotice else { return }
        let text = languageStrings.map {
            LauncherNoticePresentation.workspaceMessage(lastWorkspacePersistenceOutcome, strings: $0)
        } ?? "布局尚未保存，当前排列保留在内存中。请重试或检查磁盘空间。"
        notice.setAccessibilityLabel(languageStrings?.noticeText(.workspaceSaveAccessibility) ?? "布局保存状态")
        notice.stringValue = text
        notice.setAccessibilityValue(text)
        notice.toolTip = text
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
            _ = currentPersistentLayout()
            let mapped = resolvedLayoutCache?.indices.topLevel(frames) ?? frames
            return DragGeometry(itemFrames: mapped,
                                containerWidth: Double(host.bounds.width),
                                page: page, pageCount: surface.core.pageCount,
                                itemsPerPage: surface.itemsPerPage)
        case .folder(let folderID):
            guard let overlay = folderOverlay, let state = folderOpenState, state.isOpen(folderID),
                  state.isMemberPresentationAvailable else { return nil }
            let isMovingOut = overlay.isMoveOutPresentationCollapsed
            let originalMemberFrames = isMovingOut ? [] : overlay.memberDragItemFrames(convertedTo: host, catalog: catalog)
            _ = currentPersistentLayout()
            let memberFrames = resolvedLayoutCache?.indices.members(originalMemberFrames, folderID: folderID) ?? originalMemberFrames
            let page = isMovingOut ? surface.core.committedPage : state.innerPage
            let pageCount = isMovingOut ? surface.core.pageCount : state.innerPageCount
            let topLevelFrames: [DragItemFrame]
            if let pageView = assembly.renderer.pageView(forPage: surface.core.committedPage) {
                // BUG7 wave-b 页号陷阱：folder scope 的 geometry.page = innerPage，
                // move-out 顶层落点换算必须用顶层 committedPage —— 注记显式携带
                // 顶层页号，绝不复用 innerPage。成员帧不注记（folder 内 insertion
                // 不乘外层 itemsPerPage）。
                let topPage = surface.core.committedPage
                let frames = pageView.dragItemFrames(convertedTo: host, catalog: catalog)
                    .map { $0.annotated(pageIndex: topPage, itemsPerPage: surface.itemsPerPage) }
                topLevelFrames = resolvedLayoutCache?.indices.topLevel(frames) ?? frames
            } else {
                topLevelFrames = memberFrames
            }
            return DragGeometry(itemFrames: memberFrames, topLevelFrames: topLevelFrames,
                                containerWidth: Double(host.bounds.width),
                                page: page, pageCount: pageCount,
                                itemsPerPage: surface.itemsPerPage,
                                topLevelMoveOutBounds: isMovingOut ? DragRect(
                                    x: Double(host.bounds.minX), y: Double(host.bounds.minY),
                                    width: Double(host.bounds.width), height: Double(host.bounds.height)) : nil)
        }
    }

    /// drag 仲裁后的 click 派发（mouse-up 未过阈值；T-1F-D1）：
    /// - folder cell → 打开 folder（复用 handleFolderCellClick；绝不进入 app launch）。
    /// - app cell（顶层/成员统一；T-1F-B7-wave-c 缺陷 3 修复）→ launchMember 合成 cell
    ///   路径：身份取自 cell.bindingToken?.appID，启动用**当前 servedRevision** 的合成
    ///   cell，绝不信任提交重渲染后的 live token（建夹后顶层单击曾静默丢失）。
    @MainActor
    private func handleDragCellClick(_ cell: AppGridCellView) {
        guard folderOpenState?.isOpen == true || mainGridIsReadable else { return }
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
    private func applyPresentationUpdate(_ update: AppGridPresentationUpdate, overridePageCount: Bool,
                                         retainingMainGrid: Bool = false) {
        guard let surface = self.surface, let assembly = self.assembly else { return }
        // Only a certified member permutation retains these unchanged hosts.
        // The provider commit and all non-grid notifications still run normally.
        if !retainingMainGrid {
            dragCoordinator?.cancel(reason: .catalogRefresh)
            if update.previousRevision == update.newRevision {
                // Both seams reconcile provider pageCount. Do not bind every cell twice.
                surface.reloadCurrentPresentation()
            } else {
                surface.refreshPresentation()
            }
            if overridePageCount {
                let pages = assembly.provider.servedPageCount ?? update.plan.pageCount
                if pages != surface.core.pageCount { surface.setPageCount(pages) }
            }
            surface.needsLayout = true
            surface.layoutSubtreeIfNeeded()
        }
        self.telemetryBridge?.recordCatalogPresentation(update, assembly: assembly)
        // Phase 1C：新 revision 呈现 → 焦点模型迁移 + 重应用视觉（settle 完成/中断后
        // 焦点始终指向已提交/已显示页面，Reviewer F1 调和）。
        // 焦点布局基于顶层组合（presentationEntries；搜索激活时 = 结果 .app 条目，语义不变）。
        if !retainingMainGrid, let base = assembly.provider.servedSnapshot {
            let layout = AppGridFocusLayout.build(from: base,
                                                  composition: assembly.provider.presentationEntries,
                                                  itemsPerPage: surface.itemsPerPage)
            self.keyboardController?.applyLayout(layout)
        }
        refreshAppManagementSettings()
        refreshPageDots()
        scheduleCatalogStatusRefresh()
        appLibraryOwner?.catalogDidCommit()
    }

    /// One final composition point, used by startup and fixtures. Install the idle
    /// consumer before the presentation/status/Library fanout; no later assignment
    /// can silently discard source-state delivery, including busy early returns.
    @MainActor
    func installFinalCatalogRuntimeCallbacks(assembly: AppCatalogAssembly, surface: PagingSurface) {
        let previous = assembly.refreshController.onStateChange
        assembly.refreshController.onStateChange = { [weak self] state in
            previous?(state)
            guard let self else { return }
            self.scheduleCatalogStatusRefresh()
            guard let surface = self.surface, !state.isBusy else { return }
            if surface.isDirectNavigationActive { surface.cancelDirectNavigation() }
            if surface.core.state == .idle { self.applyPendingAtIdleBoundary() }
        }
        installCatalogPresentationCallbacks(assembly: assembly, surface: surface)
    }

    /// Shared production wiring, also used by unshown pending-catalog/frame fixtures.
    @MainActor
    func installCatalogPresentationCallbacks(assembly: AppCatalogAssembly, surface: PagingSurface) {
        let previousStateChange = assembly.refreshController.onStateChange
        assembly.refreshController.onStateChange = { [weak self] state in
            previousStateChange?(state)
            self?.scheduleCatalogStatusRefresh()
            self?.appLibraryOwner?.noteCatalogRefreshState(state)
        }
        assembly.searchPresentation.onSearchResultCommitted = { [weak self] in
            self?.surface?.reloadCurrentPresentation()
            self?.scheduleCatalogStatusRefresh()
        }
        assembly.onPresentationUpdate = { [weak self] update in
            self?.applyPresentationUpdate(update, overridePageCount: true)
        }
        surface.onIdleBoundary = { [weak self] in
            guard let self else { return }
            MainActor.assumeIsolated {
                self.applyPendingAtIdleBoundary()
            }
        }
        assembly.searchPresentation.onPresentationUpdate = { [weak self] update in
            guard let self, let assembly = self.assembly else { return }
            assembly.synchronizeIconSourcesWithCommittedCatalog()
            let searchActive = self.search?.presentation.currentQuery != nil
            self.applyPresentationUpdate(update, overridePageCount: !searchActive)
        }
    }

    /// One production idle boundary: stage folders, commit the catalog/query, then reconcile focus.
    @MainActor
    func applyPendingAtIdleBoundary() {
        defer { schedulePendingAppearancePresentation() }
        guard let surface, let assembly, !surface.isTearingDown else { return }
        // Idle is a scheduling boundary, not evidence that the catalog changed.
        // Preserve a real pointer transaction (including its pre-threshold press)
        // when there is no presentation work. Otherwise a late pager/scan callback
        // can consume the first drag while the next attempt appears to work.
        // Click-only search fallbacks and blank presses have no transaction and
        // retain their existing cancellation; real updates still invalidate below.
        let continuingPointerTransaction = dragCoordinator?.controller.activeTransaction != nil
            && !assembly.provider.hasPendingPresentationChanges
        if !continuingPointerTransaction {
            dragCoordinator?.cancel(reason: .catalogRefresh)
        }
        _ = assembly.commitPendingAtIdleBoundary(currentPage: surface.core.committedPage)
        keyboardController?.reconcileSettledCrossPage(committedPage: surface.core.committedPage)
        restorePendingLibraryGridFocus()
        refreshPageDots()
        scheduleCatalogStatusRefresh()
    }

    // MARK: - Phase 1E folder 打开 / 关闭 / 成员启动（T-1E-E）

    /// 打开 folder（顶层 folder 激活）：解析 FolderID → 打开状态 → 配置打开层。
    @MainActor
    private func openFolder(_ identity: AppGridFocusIdentity) {
        guard case .folder(let folderID)? = identity.entryIdentity else { return }
        // pendingPointerFolderID 专属消费点（r1-m1）：该标记是「指针点击打开」的一次性归属
        // token —— 仅由 handleFolderCellClick 设置，仅在此读取并立即清零；folderID 不匹配
        // 时 pointerTriggered = false（丢弃归属而非错配到其他 folder）。此外
        // openFolder(folderID:) 顶部的 cancelFolderVisualTransition() 在每条打开路径上兜底
        // 清零，故键盘打开/跨 folder 打开不会继承陈旧指针归属（残留边界仅同 folder 重开
        // 归属，已审阅记录为可接受）。
        let pointerTriggered = pendingPointerFolderID == folderID
        pendingPointerFolderID = nil
        openFolder(folderID: folderID, animatedFromPointer: pointerTriggered)
    }

    /// 打开 folder（FolderID 直接入口；folder cell 左键点击复用同一打开路径）。
    @MainActor
    func openFolder(folderID: FolderID, animatedFromPointer: Bool = false) {
        guard mainGridIsReadable else { return }
        guard let assembly, let folderOpenState else { return }
        guard assembly.provider.servedFolderSnapshot?.entry(for: folderID) != nil else { return }
        // A background search editor must not consume the folder's first Escape
        // or direction key. Negotiate natively before opening; do not clear the
        // query, force-unmark composition, or bypass an editor's refusal to resign.
        if let search, let currentWindow = search.field.window, currentWindow === window,
           let keyboardController, let first = currentWindow.firstResponder,
           first === search.field || first === search.field.currentEditor() {
            guard currentWindow.makeFirstResponder(keyboardController),
                  self.window === currentWindow, self.search === search,
                  self.keyboardController === keyboardController,
                  self.assembly === assembly, self.folderOpenState === folderOpenState else { return }
        }
        // Resigning a native editor can run delegate callbacks. Resolve current
        // folder data only after that negotiation, never reuse a stale entry.
        guard let entry = assembly.provider.servedFolderSnapshot?.entry(for: folderID) else { return }
        finishFolderTitleEditing(returnFocus: false)
        // Capture the same folder's rendered exit before cancellation removes its layer state.
        let resuming = animatedFromPointer && folderExitVisual?.folderID == folderID
            ? folderExitVisual.map { folderPresentation(for: $0.overlay) } : nil
        cancelFolderVisualTransition()
        surface?.cancelDirectNavigation()
        folderOpenState.open(entry)
        refreshPageDots()
        // Prepare panel invisibility before mount; the full-window modal host stays fixed.
        folderOverlay?.setPanelTransitionActive(animatedFromPointer)
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        defer { CATransaction.commit() }
        if animatedFromPointer { folderOverlay?.motionPresentationView.layer?.opacity = resuming?.opacity ?? 0 }
        refreshFolderOverlay()
        if animatedFromPointer {
            animateFolderEntrance(folderID: folderID, resuming: resuming)
        }
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
        pendingPointerFolderID = folderID
        keyboardController?.openFolderFromClick(folderID)
    }

    /// 关闭 folder（ESC / Command-F / 空白单击 onRequestClose / overlay clear 共用）。
    ///
    /// T-1E-E handoff（T-1E-D repair）：**所有** folder-close 路径都必须结束标题编辑，
    /// 避免 stale `isEditingTitle` 导致搜索退出后箭头/Return 被吞（导航死锁）。
    @MainActor
    func closeFolder(animatedFromPointer: Bool = false) {
        defer { schedulePendingAppearancePresentation() }
        finishFolderTitleEditing(returnFocus: false)
        let closingFolderID = folderOpenState?.openFolderID
        var shouldAnimateExit = false
        if animatedFromPointer, let closingFolderID {
            shouldAnimateExit = prepareFolderExitVisual(folderID: closingFolderID)
        } else {
            cancelFolderVisualTransition()
        }
        // 关闭/取消前先移除 move-out transient 代理，避免它在 surface 上残留。
        folderOverlay?.clearMoveOutRemainingAppProxy()
        // Phase 1F：关闭 folder → cancel 进行中的 drag（.overlayClosed 统一出口；idle 时 no-op）。
        dragCoordinator?.cancel(reason: .overlayClosed)
        keyboardController?.endTitleEditing()
        isTitleEditing = false
        folderOpenState?.close()
        refreshPageDots()
        // BUG10 缺陷 B（方案 B1）：经 refreshFolderOverlay 统一出口把视觉宿主切回 surface。
        // Pointer close may intentionally retain the overlay as an inert exit visual until its
        // generation-gated fade completes; non-pointer close still removes it synchronously.
        refreshFolderOverlay()
        // T-1F-B10-wave-a forensics census（s16）：closeFolder 执行后 overlay 的
        // superview 状态位（仅计数，零行为变更）。判别「移除成功但仍在命中」vs
        // 「根本没移除」：_sv1（superview == nil）= 移除执行到位；_sv0 = overlay
        // 仍挂在视图树（候选：被重挂/移除竞争）。sink 名只携带布尔位，无身份。
        if let overlay = folderOverlay {
            ClickCensus.hit(ClickCensus.Sink.closeFolderOverlayState(
                superviewIsNil: overlay.superview == nil))
        }
        if shouldAnimateExit {
            animatePreparedFolderExitVisual()
        }
    }

    @MainActor
    private func animateFolderEntrance(folderID: FolderID, resuming: FolderMotionPresentation? = nil) {
        guard let overlay = folderOverlay else { return }
        // The source cell is optional: a just-committed page, resize, or recycled
        // page can legitimately make it unavailable. The transition still runs as
        // an opacity-only fade in that case; an invalid anchor must never suppress
        // the visible Folder opening.
        let sourceFrame = assembly?.renderer.liveFolderIconFrame(for: folderID, convertedTo: overlay)
        let generation = nextFolderMotionGeneration()
        let params = FolderOverlayView.MotionParams.forReduceMotion(overlay.reduceMotion)
        folderEntranceAppearanceGeneration = generation
        overlay.layoutSubtreeIfNeeded()
        let enteringTransform = overlay.reduceMotion ? CGAffineTransform.identity
            : FolderMotionGeometry.sourceTransform(sourceFrame: sourceFrame,
                panelFrame: overlay.panelFrame, visibleBounds: overlay.bounds,
                anchorPoint: overlay.motionPresentationView.layer?.anchorPoint ?? .zero)
        if let layer = overlay.motionPresentationView.layer {
            let initialOpacity = resuming?.opacity ?? 0
            let initialTransform = overlay.reduceMotion ? CGAffineTransform.identity
                : (resuming?.transform ?? enteringTransform)
            animateFolderLayer(layer, fromOpacity: initialOpacity, toOpacity: 1,
                               fromTransform: initialTransform, toTransform: .identity,
                               duration: params.duration, key: "folder.enter")
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + params.duration) { [weak self, weak overlay] in
            MainActor.assumeIsolated {
                guard let self, let overlay,
                      FolderMotionGate.accepts(completionGeneration: generation,
                                               currentGeneration: self.folderMotionGeneration) else { return }
                overlay.motionPresentationView.layer?.opacity = 1
                overlay.motionPresentationView.layer?.setAffineTransform(.identity)
                self.folderEntranceAppearanceGeneration = nil
                overlay.setPanelTransitionActive(false)
                self.schedulePendingAppearancePresentation()
            }
        }
    }

    /// Retains the already-rendered overlay as a drawing-only visual. A bitmap made with
    /// `cacheDisplay(in:to:)` captures model/local pixels and cannot faithfully include an
    /// interrupted presentation transform, so the original view and its subviews stay mounted
    /// while logical Folder state is closed synchronously by the caller.
    @MainActor
    @discardableResult
    private func prepareFolderExitVisual(folderID: FolderID) -> Bool {
        guard let overlay = folderOverlay, overlay.superview != nil else {
            cancelFolderVisualTransition()
            return false
        }
        overlay.layoutSubtreeIfNeeded()
        let sourceFrame = assembly?.renderer.liveFolderIconFrame(for: folderID, convertedTo: overlay)
        guard FolderMotionGeometry.isReliableSourceFrame(sourceFrame, visualFrame: overlay.bounds) else {
            // D-1J: an exit visual without a reliable source/geometry anchor is not a
            // trustworthy interrupted snapshot. Close synchronously and leave no visual behind.
            cancelFolderVisualTransition()
            return false
        }
        // Sample the rendered layer before removing its entrance animation. The model layer is
        // already at its settled target, so reading it after cancellation causes an interrupted
        // open to jump to opacity 1 / identity before the exit visual begins.
        let presentation = folderPresentation(for: overlay)
        // Cancel stale visual work only after the snapshot has been captured. Logical close is
        // still performed synchronously by the caller's subsequent refreshFolderOverlay().
        cancelFolderVisualTransition(resetInteractiveOverlay: false)
        overlay.setVisualOnly(true)
        overlay.alphaValue = 1
        overlay.motionPresentationView.layer?.opacity = presentation.opacity
        overlay.motionPresentationView.layer?.setAffineTransform(presentation.transform)
        folderExitVisual = FolderExitVisualState(
            folderID: folderID,
            overlay: overlay,
            sourceFrame: sourceFrame,
            reduceMotion: overlay.reduceMotion,
            initialOpacity: presentation.opacity,
            initialTransform: presentation.transform)
        return true
    }

    @MainActor
    private func animatePreparedFolderExitVisual() {
        guard let visual = folderExitVisual else { return }
        let overlay = visual.overlay
        let generation = nextFolderMotionGeneration()
        let params = FolderOverlayView.MotionParams.forReduceMotion(visual.reduceMotion)
        let transform = visual.reduceMotion ? CGAffineTransform.identity
            : FolderMotionGeometry.sourceTransform(sourceFrame: visual.sourceFrame,
                panelFrame: overlay.panelFrame, visibleBounds: overlay.bounds,
                anchorPoint: overlay.motionPresentationView.layer?.anchorPoint ?? .zero)
        overlay.wantsLayer = true
        if let layer = overlay.motionPresentationView.layer {
            layer.opacity = visual.initialOpacity
            layer.setAffineTransform(visual.initialTransform)
            animateFolderLayer(layer, fromOpacity: visual.initialOpacity, toOpacity: 0,
                               fromTransform: visual.initialTransform, toTransform: transform,
                               duration: params.exitDuration, key: "folder.exit")
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + params.exitDuration) { [weak self, weak visual] in
            MainActor.assumeIsolated {
                guard let self, let visual,
                      FolderMotionGate.accepts(completionGeneration: generation,
                                               currentGeneration: self.folderMotionGeneration) else { return }
                visual.overlay.motionPresentationView.layer?.removeAllAnimations()
                visual.overlay.removeFromSuperview()
                // Clear while visual-only so cleanup cannot issue fresh icon work. The next
                // interactive configure will bind a new current entry normally.
                visual.overlay.clearContent()
                visual.overlay.setVisualOnly(false)
                visual.overlay.alphaValue = 1
                visual.overlay.motionPresentationView.layer?.opacity = 1
                visual.overlay.motionPresentationView.layer?.setAffineTransform(.identity)
                if self.folderExitVisual === visual { self.folderExitVisual = nil }
                self.schedulePendingAppearancePresentation()
            }
        }
    }

    @MainActor
    private func cancelFolderVisualTransition(resetInteractiveOverlay: Bool = true) {
        folderOverlay?.cancelTrackpadPaging()
        folderEntranceAppearanceGeneration = nil
        folderOverlay?.setPanelTransitionActive(false)
        _ = nextFolderMotionGeneration()
        // Always remove stale animations. The false mode is used while preparing a synchronous
        // logical close and intentionally leaves the model layer untouched until refresh removes
        // the interactive overlay.
        folderOverlay?.motionPresentationView.layer?.removeAllAnimations()
        if let visual = folderExitVisual {
            visual.overlay.motionPresentationView.layer?.removeAllAnimations()
            visual.overlay.removeFromSuperview()
            // The retained visual is no longer usable after cancellation. Clear it before
            // restoring interaction so resume cannot re-request icons for a closed entry.
            visual.overlay.clearContent()
            visual.overlay.setVisualOnly(false)
            visual.overlay.alphaValue = 1
            visual.overlay.motionPresentationView.layer?.opacity = 1
            visual.overlay.motionPresentationView.layer?.setAffineTransform(.identity)
        }
        folderExitVisual = nil
        pendingPointerFolderID = nil
        guard resetInteractiveOverlay, let overlay = folderOverlay else { return }
        overlay.alphaValue = 1
        overlay.motionPresentationView.layer?.opacity = 1
        overlay.motionPresentationView.layer?.setAffineTransform(.identity)
    }

    /// Reads the presentation layer while it still exists, with a finite/clamped model fallback.
    @MainActor
    private func folderPresentation(for overlay: FolderOverlayView) -> FolderMotionPresentation {
        let layer = overlay.motionPresentationView.layer
        let fallback = FolderMotionPresentation.sanitized(
            opacity: layer?.opacity ?? Float(overlay.alphaValue),
            transform: layer?.affineTransform() ?? .identity)
        guard let presentationLayer = layer?.presentation() else { return fallback }
        return FolderMotionPresentation.sanitized(
            opacity: presentationLayer.opacity,
            transform: presentationLayer.affineTransform(),
            fallback: fallback)
    }

    @MainActor
    @discardableResult
    private func nextFolderMotionGeneration() -> UInt64 {
        folderMotionGeneration &+= 1
        return folderMotionGeneration
    }

    private func animateFolderLayer(_ layer: CALayer, fromOpacity: Float, toOpacity: Float,
                                    fromTransform: CGAffineTransform, toTransform: CGAffineTransform,
                                    duration: TimeInterval, key: String) {
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        defer { CATransaction.commit() }
        let opacity = CABasicAnimation(keyPath: "opacity")
        opacity.fromValue = fromOpacity
        opacity.toValue = toOpacity
        let transform = CABasicAnimation(keyPath: "transform")
        transform.fromValue = CATransform3DMakeAffineTransform(fromTransform)
        transform.toValue = CATransform3DMakeAffineTransform(toTransform)
        let group = CAAnimationGroup()
        group.animations = [opacity, transform]
        group.duration = duration
        group.timingFunction = CAMediaTimingFunction(name: .easeOut)
        layer.opacity = toOpacity
        layer.setAffineTransform(toTransform)
        layer.add(group, forKey: key)
    }

    /// 成员/顶层 app 启动共用路径（T-1F-B7-wave-c）：解析 AppID → 以**当前 servedRevision**
    /// 合成 launch cell（makeMemberLaunchCell，不信任重建后 live token）→ 复用
    /// `AppLaunchController.handleCell` 管线（无并行启动路径）。
    @MainActor
    private func launchMember(_ appID: AppID) {
        guard appRemovalCoordinator?.isBusy != true else { return }
        if let state = folderOpenState, state.isOpen, !state.isMemberPresentationAvailable { return }
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
    private func setFolderInnerPage(_ page: Int, clearsSelection: Bool = false) {
        guard folderOpenState?.isMemberPresentationAvailable == true else { return }
        if clearsSelection, dragCoordinator?.isSessionActive == true { return }
        folderOverlay?.cancelTrackpadPaging()
        if clearsSelection { keyboardController?.clearInnerSelectionForPageChange() }
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
            pendingFolderLayout = nil
            if let exitVisual = folderExitVisual, exitVisual.overlay === folderOverlay {
                // Logical state is closed, but pointer exit animation owns the actual view until
                // its generation-gated completion. It is already visual-only and inert.
            } else {
                folderOverlay.setVisualOnly(false)
                folderOverlay.clearContent()
                folderOverlay.removeFromSuperview()
            }
            dragCoordinator?.setVisualHost(surface)
            return
        }
        folderOverlay.setVisualOnly(false)
        let material = effectiveMaterialPolicy
        folderOverlay.applyMaterialPolicy(reduceTransparency: material.reduceTransparency,
                                          increaseContrast: material.increaseContrast)
        folderOverlay.showsAppLabels = appearancePreferences.showsAppLabels
        folderOverlay.itemAppearance = appearancePreferences.itemAppearance
        refreshFolderLayoutIfReady(rebind: false)
        folderOverlay.titleEditingEnabled = canApplyFolderAssignment
        folderOverlay.appContextMenuProvider = { [weak self] cell in self?.appContextMenuController?.menu(for: cell) }
        let reduceMotion = surface?.reduceMotionProvider?() ?? false
        folderOverlay.configure(entry: entry, innerPage: folderOpenState.innerPage,
                                reduceMotion: reduceMotion,
                                catalogRevision: assembly?.provider.servedRevision ?? 0) { [weak self] appID in
            self?.memberName(for: appID)
        }
        if folderOverlay.superview == nil {
            let host = container ?? surface
            folderOverlay.frame = host?.bounds ?? .zero
            folderOverlay.autoresizingMask = [.width, .height]
            folderOverlay.layoutSubtreeIfNeeded()
            if let host {
                if let notice = actionFeedbackView, notice.superview === host {
                    host.addSubview(folderOverlay, positioned: .below, relativeTo: notice)
                } else { host.addSubview(folderOverlay) }
            }
        }
        folderOverlay.layoutSubtreeIfNeeded()
        keyboardController?.reconcileFolderLayout()
        dragCoordinator?.setVisualHost(folderOverlay)
    }

    /// Resolve only on viewport/appearance/input-owner boundaries, never a frame callback.
    @MainActor
    func refreshFolderLayoutIfReady(rebind: Bool = true) {
        guard !didRunFinalTeardown, !isResolvingFolderLayout,
              let state = folderOpenState, state.isOpen,
              let overlay = folderOverlay, !overlay.isVisualOnly, !overlay.isTornDown,
              let host = container ?? surface else { return }
        let safe = host.safeAreaInsets
        var usable = host.bounds
        usable.origin.x += safe.left; usable.origin.y += safe.bottom
        usable.size.width = max(usable.width - safe.left - safe.right, 0)
        usable.size.height = max(usable.height - safe.top - safe.bottom, 0)
        if let search, search.field.superview === host {
            // Initial/open transactions can precede AppKit's first chrome layout pass.
            // Share the authoritative resolver rather than treating an old zero-origin frame
            // as a real obstruction that consumes the entire content area.
            let searchFrame = searchFieldFrame(in: host.bounds)
            usable.size.height = max(min(usable.maxY, searchFrame.minY - 12) - usable.minY, 0)
        }
        let proposed = FolderLayoutPolicy.resolve(usableBounds: usable,
                                                  appearance: appearancePreferences.itemAppearance)
        let busy = overlay.isTrackpadPagingActive || isTitleEditing || overlay.titleEditorView != nil
            || dragCoordinator?.isSessionActive == true || overlay.isMoveOutPresentationCollapsed
            || folderEntranceAppearanceGeneration != nil || folderExitVisual != nil
            || surface?.pinnedPresentation != nil
        if busy {
            pendingFolderLayout = proposed
            // Keep the same native editor and index mapping; an unsafe frozen grid is inert.
            let fits = overlay.appliedFolderLayout.map {
                $0.canPresentMembers && usable.contains($0.panelFrame)
            } ?? false
            overlay.setMemberPresentationAvailable(fits)
            overlay.constrainMountedTitleEditor(using: fits ? nil : proposed)
            state.reconfigure(columns: state.columns, membersPerPage: state.membersPerPage,
                              anchor: keyboardController?.focusedFolderMember, isAvailable: fits)
            return
        }
        pendingFolderLayout = nil
        guard proposed != overlay.appliedFolderLayout
                || proposed.canPresentMembers != state.isMemberPresentationAvailable else { return }
        isResolvingFolderLayout = true
        defer { isResolvingFolderLayout = false }
        let selected = keyboardController?.focusedFolderMember
        state.reconfigure(columns: proposed.columns, membersPerPage: proposed.capacity,
                          anchor: selected, isAvailable: proposed.canPresentMembers)
        overlay.applyFolderLayout(proposed)
        if rebind { refreshFolderOverlay() }
    }

    @MainActor
    private func scheduleFolderLayoutRefresh() {
        guard !didRunFinalTeardown, folderOpenState?.isOpen == true, !folderLayoutRetryScheduled else { return }
        folderLayoutRetryScheduled = true
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.folderLayoutRetryScheduled = false
            self.refreshFolderLayoutIfReady()
        }
    }

    /// 成员显示名（中性；nil = 不在当前 catalog → 通用占位）。
    @MainActor
    private func memberName(for appID: AppID) -> String? {
        guard let assembly else { return nil }
        return assembly.provider.displayName(for: appID)
    }

    /// 进入标题编辑：编辑器成为 first responder + 键盘控制器置位编辑态。
    /// Phase 1F：标题编辑开始 → cancel 进行中的 drag（.titleEditBegan 统一出口）。
    @MainActor
    func beginTitleEditing() {
        guard folderRenameContext == nil, canApplyFolderAssignment,
              let folderID = folderOpenState?.openFolderID, let overlay = folderOverlay,
              !overlay.isVisualOnly, let window = overlay.window else { return }
        cancelFolderVisualTransition()
        surface?.cancel()
        guard canApplyFolderAssignment, folderOpenState?.openFolderID == folderID,
              let layout = currentPersistentLayout(), let folder = layout.folder(id: folderID),
              let revision = assembly?.provider.servedRevision else { return }
        dragCoordinator?.cancel(reason: .titleEditBegan)
        folderRenameGeneration &+= 1
        let token = folderRenameGeneration
        let editor = FolderTitleEditor()
        if let languageStrings { editor.relabel(strings: languageStrings) }
        editor.font = overlay.titleEditButton.font
        editor.alignment = .center
        editor.fallbackTitle = folder.title
        editor.stringValue = folder.title
        editor.onDraftSizeChange = { [weak overlay] in
            overlay?.needsLayout = true
            overlay?.layoutSubtreeIfNeeded()
        }
        editor.onCommit = { [weak self] title in self?.commitFolderTitle(title, token: token) }
        editor.onCancel = { [weak self] in
            guard self?.folderRenameContext?.token == token else { return }
            self?.cancelFolderTitle()
        }
        folderRenameContext = .init(token: token, folderID: folderID, revision: revision, layout: layout,
                                   storeEpoch: layoutRestoreGeneration)
        folderTitleEditor = editor
        keyboardController?.onTitleCommit = { [weak self] title in self?.commitFolderTitle(title, token: token) }
        keyboardController?.onTitleCancel = { [weak self] in
            guard self?.folderRenameContext?.token == token else { return }
            self?.cancelFolderTitle()
        }
        guard overlay.mountTitleEditor(editor) else { finishFolderTitleEditing(returnFocus: false); return }
        isTitleEditing = true
        keyboardController?.beginTitleEditing()
        guard window.makeFirstResponder(editor) else { finishFolderTitleEditing(returnFocus: false); return }
    }

    /// A dismissal click belongs to editing, not to the app or blank space behind it.
    /// The window retains down/drag/up ownership even if commit removes this editor.
    @MainActor
    func handleFolderTitlePointerDown(_ event: NSEvent) -> Bool {
        guard isTitleEditing, folderRenameContext != nil, let editor = folderTitleEditor,
              let editorWindow = editor.window, editorWindow === window,
              event.type == .leftMouseDown, event.windowNumber == editorWindow.windowNumber else { return false }
        let point = editor.convert(event.locationInWindow, from: nil)
        guard !editor.bounds.contains(point) else { return false }
        // Native negotiation permits validation/composition to refuse resignation.
        // Never endEditing(for:), unmarkText(), or replay this down to another target.
        guard editorWindow.makeFirstResponder(nil) else { return true }
        if folderTitleEditor === editor { editor.commit() }
        if !isTitleEditing, let keyboardController, editorWindow.attachedSheet == nil {
            _ = editorWindow.makeFirstResponder(keyboardController)
        }
        return true
    }

    /// 提交标题：结束编辑（标题文本绝不进入 telemetry/log/stdout/signpost/profile/report）。
    @MainActor
    private func commitFolderTitle(_ title: String, token: UInt64) {
        guard let context = folderRenameContext, token == context.token else { return }
        guard canCommitWorkspaceLayout, folderOpenState?.openFolderID == context.folderID,
              layoutRestoreGeneration == context.storeEpoch,
              assembly?.provider.servedRevision == context.revision,
              let current = currentPersistentLayout(), current == context.layout else {
            lastFolderRenameResult = .rejected(.invalidTarget)
            finishFolderTitleEditing()
            return
        }
        let result = LayoutMutation(expectedGeneration: current.generation)
            .renameFolder(in: current, folderID: context.folderID, to: title)
        // Invalidate callbacks before unmount and responder changes trigger focus loss.
        finishFolderTitleEditing()
        if case .success(let renamed) = result {
            guard commitWorkspaceLayout(renamed) else { lastFolderRenameResult = .cancelled; return }
        }
        lastFolderRenameResult = result
    }

    /// 取消标题编辑：结束编辑。
    @MainActor
    private func cancelFolderTitle() {
        finishFolderTitleEditing()
    }

    @MainActor
    private func finishFolderTitleEditing(returnFocus: Bool = true) {
        let editor = folderTitleEditor
        let window = editor?.window
        let ownedResponder = editor?.currentEditor() != nil || window?.firstResponder === editor
        folderRenameContext = nil
        folderTitleEditor = nil
        editor?.dismissWithoutCallback()
        folderOverlay?.unmountTitleEditor()
        keyboardController?.endTitleEditing()
        keyboardController?.onTitleCommit = nil
        keyboardController?.onTitleCancel = nil
        isTitleEditing = false
        refreshTitleEditReadiness()
        scheduleFolderLayoutRefresh()
        if returnFocus, ownedResponder, let keyboardController { window?.makeFirstResponder(keyboardController) }
    }

    @MainActor
    private func refreshTitleEditReadiness() {
        folderOverlay?.titleEditingEnabled = canApplyFolderAssignment
        schedulePendingAppearancePresentation()
    }

    /// The opt-in UI test window stays inside the current screen's visible frame.
    /// Production retains the original frame, style, and Space participation.
    static func initialWindowConfiguration(screenFrame: NSRect, visibleFrame: NSRect,
                                           uiTestWindowed: Bool)
        -> (frame: NSRect, styleMask: NSWindow.StyleMask, collectionBehavior: NSWindow.CollectionBehavior) {
        guard uiTestWindowed else {
            return (screenFrame, [.borderless], [.canJoinAllSpaces, .fullScreenAuxiliary])
        }
        let size = NSSize(width: min(1000, max(0, visibleFrame.width)),
                          height: min(700, max(0, visibleFrame.height)))
        let frame = NSRect(x: visibleFrame.midX - size.width / 2,
                           y: visibleFrame.midY - size.height / 2,
                           width: size.width, height: size.height)
        return (frame, [.titled, .closable, .resizable], [])
    }

    /// Search field in the non-flipped content host, below the screen's camera exclusion.
    static func searchFieldFrame(in bounds: NSRect, safeAreaTop: CGFloat) -> NSRect {
        LauncherSearchHeader.frame(in: bounds, safeAreaTop: safeAreaTop)
    }

    private func searchFieldFrame(in bounds: NSRect) -> NSRect {
        Self.searchFieldFrame(in: bounds, safeAreaTop: window?.screen?.safeAreaInsets.top ?? 0)
    }

    private func layoutSearchField() {
        MainActor.assumeIsolated {
            if let container, let search {
                search.field.frame = searchFieldFrame(in: container.bounds)
                appLibraryOwner?.layout(searchFrame: search.field.frame)
            }
            // Dependent chrome must observe the current screen-safe search geometry.
            layoutPageDots()
            layoutCatalogStatus()
            layoutActionFeedback()
            refreshMainGridReadability()
            refreshFolderLayoutIfReady()
        }
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

    // MARK: - Native application menus

    /// Keep app/view commands while registering standard text-editor shortcuts.
    /// Internal visibility permits unshown production-menu regression tests.
    @MainActor
    func installLauncherMenu() {
        let mainMenu = NSMenu()
        let appMenuItem = NSMenuItem()
        mainMenu.addItem(appMenuItem)
        let appMenu = NSMenu()
        let quit = appMenu.addItem(withTitle: languageStrings?.text(.quitLauncher) ?? "退出 Launchcopy",
            action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        localizedQuitMenuItem = quit
        appMenuItem.submenu = appMenu

        let editMenu = LauncherEditMenuController(strings: languageStrings)
        editMenuController = editMenu
        mainMenu.addItem(editMenu.menuItem)

        let viewMenuItem = NSMenuItem()
        mainMenu.addItem(viewMenuItem)
        let viewMenu = NSMenu(title: languageStrings?.settingsText(.viewMenuTitle) ?? "视图")
        localizedViewMenu = viewMenu
        let toggleItem = NSMenuItem(
            title: languageStrings?.settingsText(.toggleLauncherTitle) ?? "显示/隐藏启动器",
            action: #selector(toggleLauncherPresentation(_:)),
            keyEquivalent: "f"
        )
        toggleItem.keyEquivalentModifierMask = [.command, .control]
        viewMenu.addItem(toggleItem)
        localizedToggleMenuItem = toggleItem
        let libraryItem = NSMenuItem(title: languageStrings?.libraryText(.title) ?? "App Library",
            action: #selector(showAppLibraryFromMenu(_:)), keyEquivalent: "")
        libraryItem.identifier = .init("library.menu.entry")
        libraryItem.target = self
        viewMenu.addItem(libraryItem)
        localizedLibraryMenuItem = libraryItem
        installFolderDropTimingMenu(in: viewMenu)
        installPointerInputDiagnosticMenu(in: viewMenu)
        installGestureValidationObservationMenu(in: viewMenu)
        viewMenuItem.submenu = viewMenu
        NSApp.mainMenu = mainMenu
    }

    /// Explicit dedicated-only diagnostics. No timer, persistence or raw input export.
    @MainActor
    func installGestureValidationObservationMenu(in menu: NSMenu) {
        guard options.gestureValidation else { return }
        let actions: [(String, String, Selector)] = [
            ("开始／重置四指诊断", "diagnostics.fourFinger.start", #selector(startGestureValidationObservation(_:))),
            ("四指诊断结果…", "diagnostics.fourFinger.report", #selector(showGestureValidationObservation(_:))),
            ("停止四指诊断", "diagnostics.fourFinger.stop", #selector(stopGestureValidationObservation(_:)))
        ]
        for (title, identifier, action) in actions {
            let item = NSMenuItem(title: title, action: action, keyEquivalent: "")
            item.identifier = .init(identifier); item.target = self; menu.addItem(item)
        }
    }

    @MainActor @objc func startGestureValidationObservation(_ sender: Any?) {
        guard options.gestureValidation else { return }
        activationComposition?.startGestureDeliveryObservation()
    }

    @MainActor @objc func stopGestureValidationObservation(_ sender: Any?) {
        guard options.gestureValidation else { return }
        activationComposition?.stopGestureDeliveryObservation()
    }

    @MainActor @objc func showGestureValidationObservation(_ sender: Any?) {
        guard options.gestureValidation, let window, let composition = activationComposition else { return }
        var lines = [composition.gestureDeliveryObservation?.summary ?? "observation=off",
                     "hostReadyNow=\(fourFingerOutwardHideIsReady)"]
        lines.append(GestureDeliveryObservation.presentationSummary(composition.launcher.coordinator.state))
        let pagerIdle = surface?.core.state == .idle || surface?.core.state == .cancelled
        lines.append("hostNow visible=\(window.isVisible) restore=\(isRestoringLayout) dirty=\(workspaceNeedsSave) pending=\(workspacePersistence.pendingCount) settings=\(activationSettingsCoordinator?.isSettingsVisible == true) folder=\(folderOpenState?.isOpen == true) drag=\(dragCoordinator?.isSessionActive == true) pagerIdle=\(pagerIdle)")
        if let backend = composition.touchProvider as? MultitouchSupportBackend {
            lines.append("backendLifetime raw=\(backend.rawCallbackCount) delivered=\(backend.deliveredFrameCount) rejected=\(backend.rejectedFrameCount)")
        }
        if let recognizer = composition.fourFinger?.recognizer {
            lines.append("recognizerLifetime rejected=\(recognizer.rejectedFrameCount) fire=\(recognizer.fireCount) suppressed=\(recognizer.suppressedFireCount) state=\(recognizer.state)")
            let cancels = recognizer.cancelCounts.map { "\($0.key)=\($0.value)" }.sorted().joined(separator: ", ")
            lines.append("cancelLifetime \(cancels.isEmpty ? "none" : cancels)")
        }
        let alert = NSAlert()
        alert.messageText = "四指诊断（仅内存）"
        alert.informativeText = lines.joined(separator: "\n")
        alert.addButton(withTitle: "关闭")
        presentApplicationSheet(alert, for: window)
    }

    /// A discoverable keyboard/accessibility route without a permanent grid button.
    @MainActor
    @objc func showAppLibraryFromMenu(_ sender: Any?) {
        guard libraryMenuEntryIsAvailable else { return }
        _ = appLibraryOwner?.enter()
    }

    @MainActor
    private var libraryMenuEntryIsAvailable: Bool {
        window?.isVisible == true && leadingLibraryNavigator?.isTransitioning != true
            && appLibraryOwner?.canPreviewEntry == true
    }

    @MainActor
    func validateMenuItem(_ menuItem: NSMenuItem) -> Bool {
        if menuItem.action == #selector(showAppLibraryFromMenu(_:)) { return libraryMenuEntryIsAvailable }
        return true
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
        let store = UserDefaultsActivationPreferencesStore(suiteName: uiTestProfile?.activationSuiteName ?? UserDefaultsActivationPreferencesStore.defaultSuiteName)
        self.activationPreferencesStore = store
        var preferences: ActivationPreferences
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

        let composition: ActivationComposition
        if options.integratedPreview {
            preferences = IntegratedPreviewPolicy.preferences(preferences)
            composition = LauncherRuntimeServices.integratedPreviewActivation(launcher: launcher,
                requestTerminate: { NSApp.terminate(nil) })
        } else if options.gestureValidation {
            preferences = GestureValidationPolicy.preferences(preferences)
            composition = LauncherRuntimeServices.gestureValidationActivation(launcher: launcher,
                requestTerminate: { NSApp.terminate(nil) })
        } else {
            composition = LauncherRuntimeServices.activation(launcher: launcher,
                isolated: uiTestProfile != nil, requestTerminate: { NSApp.terminate(nil) })
        }
        composition.onPrepareHide = { [weak self] in
            self?.prepareTransientCancellationForHide()
        }
        composition.canHideFromFourFinger = { [weak self] in
            self?.fourFingerOutwardHideIsReady == true
        }
        composition.onScreensChanged = { [weak self] in
            self?.surface?.cancelDirectNavigation()
            self?.refreshPageDots()
            self?.cancelFolderVisualTransition()
        }
        self.activationComposition = composition

        // Four-finger activation stays unchanged; observation is opt-in lab work only.
        fourFingerDiagnostics?.stop()
        fourFingerDiagnostics = nil
        if options.integratedPreview {
            LauncherRuntimeServices.applyIntegratedPreviewPreferences(preferences, to: composition)
        } else if options.gestureValidation {
            LauncherRuntimeServices.applyGestureValidationPreferences(preferences, to: composition)
        } else {
            LauncherRuntimeServices.applyActivationPreferences(preferences, to: composition, isolated: uiTestProfile != nil)
        }
        composition.startSessionObserver()
        if options.pagingLab {
            let diagnostics = FourFingerDiagnostics(enabled: true)
            diagnostics.start(for: composition)
            fourFingerDiagnostics = diagnostics
        }

        // Phase 1H：Settings 协调器（Fake 永不经此路径；生产 SMAppService，默认 Off，启动不自动 enable）。
        let loginService = LauncherRuntimeServices.login(isolated: uiTestProfile != nil)
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
            applyPreferences: { [weak composition, isolated = self.uiTestProfile != nil, validation = options.gestureValidation,
                                              integrated = options.integratedPreview] prefs in
                guard let composition else { return }
                if integrated { LauncherRuntimeServices.applyIntegratedPreviewPreferences(prefs, to: composition) }
                else if validation { LauncherRuntimeServices.applyGestureValidationPreferences(prefs, to: composition) }
                else { LauncherRuntimeServices.applyActivationPreferences(prefs, to: composition, isolated: isolated) }
            },
            setStatusItemVisible: { [weak self] show in
                self?.applyStatusItemVisibility(show)
            },
            fourFingerReadinessProvider: { [weak self, weak composition] in
                ActivationSettingsFourFingerReadiness.text(from: composition, strings: self?.languageStrings)
            }
        )
        if options.integratedPreview { coordinator.normalizeDraft = IntegratedPreviewPolicy.draft }
        else if options.gestureValidation { coordinator.normalizeDraft = GestureValidationPolicy.draft }
        self.activationSettingsCoordinator = coordinator
        coordinator.interfaceStringsProvider = { [weak self] in self?.languageStrings }
        coordinator.preservesInterfaceDraftsOnReopen = true
        coordinator.refreshAcceptedInterfaceLanguage = { [weak self, weak coordinator] in
            guard let self, let controller = coordinator?.retainedSettingsController else { return }
            // Rebind after language-store replacement without reloading unrelated drafts.
            self.configureLanguageSettings(controller)
        }
        coordinator.configureAdditionalSettings = { [weak self] controller in
            controller.fourFingerValidationOnly = self?.options.gestureValidation == true
                || self?.options.integratedPreview == true
            self?.configureAppearanceSettings(controller.appearanceView)
            self?.configureMainGridCapacitySettings(controller.mainGridCapacityView)
            self?.configureAppManagementSettings(controller)
            self?.configureAppSourcesSettings(controller)
            self?.configureLanguageSettings(controller)
            self?.configureAppLibrarySettings(controller)
        }
    }

    /// Runtime-only default/home lookup. Tests inject synthetic baseline/admission/watcher.
    @MainActor
    func installAppSources(assembly: AppCatalogAssembly,
                           store injectedStore: (any AppSourcesPersisting)? = nil,
                           admission injectedAdmission: (any AppSourceRootAdmitting)? = nil,
                           watcher injectedWatcher: (any AppSourceWatching)? = nil,
                           context injectedContext: AppSourceRootAdmissionContext? = nil) {
        guard options.uiTestProfile == nil || uiTestProfile != nil else { return }
        appSourcesCoordinator?.teardown()
        if options.gestureValidation || options.integratedPreview { appSourcesCoordinator = nil; return }
        let fixedRoots = assembly.scanRoots
        let context = injectedContext ?? AppSourceRootAdmissionContext(
            homeURL: FileManager.default.homeDirectoryForCurrentUser, fixedRoots: fixedRoots,
            allowedSyntheticRoot: uiTestProfile?.applicationsDirectoryURL)
        let admission: any AppSourceRootAdmitting = injectedAdmission ?? LocalAppSourceRootAdmitter()
        let store: any AppSourcesPersisting = injectedStore
            ?? UserDefaultsAppSourcesStore(suiteName: uiTestProfile?.sourcesSuiteName
                                           ?? UserDefaultsAppSourcesStore.defaultSuiteName)
            ?? InMemoryAppSourcesStore()
        let watcher: any AppSourceWatching = injectedWatcher ?? FSEventsAppSourceWatcher()
        let coordinator = AppSourcesCoordinator(store: store, admission: admission,
            context: context, fixedRoots: fixedRoots, watcher: watcher,
            replaceRoots: { [weak self, weak assembly] roots in
                self?.appLibraryOwner?.invalidateSourceTargets()
                self?.surface?.cancelDirectNavigation()
                assembly?.replaceScanRoots(roots, fixedRoots: fixedRoots, context: context, admission: admission)
            }, requestRefresh: { [weak assembly] immediate in
                if immediate { assembly?.refreshNow() } else { assembly?.scheduleRescan() }
            })
        appSourcesCoordinator = coordinator
        coordinator.activate()
    }

    @MainActor
    func configureAppSourcesSettings(_ controller: ActivationSettingsWindowController) {
        let view = controller.appSourcesView
        guard !options.gestureValidation, !options.integratedPreview,
              let coordinator = appSourcesCoordinator, assembly != nil else {
            view.onRefresh = nil; view.onApply = nil; view.onAdmit = nil
            view.reload(preferences: .default, fixedRoots: [], watchStatus: .unavailable)
            if options.gestureValidation || options.integratedPreview {
                for control in [view.rootsPopup, view.automaticCheckbox, view.addButton, view.removeButton,
                                view.applyButton, view.refreshButton] as [NSControl] { control.isEnabled = false }
            }
            return
        }
        // Baseline remains fixed; custom sources are shown only in the separate draft.
        let baseline = options.catalogRoots.isEmpty
            ? (uiTestProfile.map { [$0.applicationsDirectoryURL] } ?? CatalogRoots.defaults)
            : options.catalogRoots
        view.onAdmit = { [weak coordinator] url in
            guard let coordinator else { return .rejected(.unreadable) }
            return await coordinator.admitDraftRoot(url)
        }
        view.onApply = { [weak coordinator] draft in
            guard let coordinator else { return .failed }
            return await coordinator.apply(draft)
        }
        view.onRefresh = { [weak coordinator] in coordinator?.refreshNow() }
        view.reload(preferences: coordinator.committed, fixedRoots: baseline,
                    loadResult: coordinator.loadResult, watchStatus: coordinator.watchStatus)
        coordinator.onWatchStatusChange = { [weak view] status in view?.updateWatchStatus(status) }
    }

    @MainActor
    func installAppearancePreferences(
        store injectedStore: (any AppearancePreferencesPersisting)? = nil,
        makePersistentStore: @MainActor (String) -> (any AppearancePreferencesPersisting)? = {
            UserDefaultsAppearancePreferencesStore(suiteName: $0)
        }
    ) {
        if let previous = liveAppearanceCoordinator {
            _ = previous.flush()
            guard !previous.requiresQuitProtection else { return }
            previous.invalidate()
        }
        liveAppearanceCoordinator = nil
        let store: any AppearancePreferencesPersisting
        if let injectedStore { store = injectedStore }
        else if let persisted = makePersistentStore(uiTestProfile?.appearanceSuiteName ?? UserDefaultsAppearancePreferencesStore.defaultSuiteName) { store = persisted }
        else {
            // A missing persistent owner must not acknowledge session-only edits.
            // Preserve any style already accepted by the previous owner.
            appearanceSettingsCoordinator = nil
            return
        }
        let coordinator = AppearanceSettingsCoordinator(store: store) { _ in }
        coordinator.onAcknowledged = { [weak self, weak coordinator] preferences in
            guard let self, let coordinator,
                  self.appearanceSettingsCoordinator === coordinator,
                  let live = self.liveAppearanceCoordinator,
                  live.persistence === coordinator, !live.isFlushing else { return }
            live.acceptPersistenceCommand(preferences)
        }
        appearanceSettingsCoordinator = coordinator
        let live = LiveAppearanceSettingsCoordinator(persistence: coordinator)
        liveAppearanceCoordinator = live
        live.onPreview = { [weak self, weak live] preferences in
            guard let self, let live, self.liveAppearanceCoordinator === live else { return }
            self.applyAppearancePreferences(preferences)
        }
        live.onChange = { [weak self, weak live] in
            guard let self, let live, self.liveAppearanceCoordinator === live else { return }
            self.refreshAppearancePresentationStatus()
        }
        appearancePreferences = coordinator.committed
        pendingAppearancePreferences = nil
    }

    @MainActor
    func configureAppearanceSettings(_ view: AppearanceSettingsView) {
        configuredAppearanceSettingsView = view
        view.mainIconFitProvider = { [weak self, weak view] preferences in
            guard let self, let view, !self.didRunFinalTeardown, let surface = self.surface else { return nil }
            return MainGridLayoutMetrics.fittedIconSides(bounds: surface.bounds,
                capacity: view.mainGridSection?.draft ?? self.mainGridCapacity,
                appearance: preferences.mainItemAppearance,
                showsLabels: preferences.showsAppLabels)
        }
        guard let coordinator = appearanceSettingsCoordinator, let live = liveAppearanceCoordinator else {
            view.presentationStateProvider = { .unavailable }
            view.reload(preferences: pendingAppearancePreferences ?? appearancePreferences)
            view.onChange = nil; view.onApply = nil; view.onFlush = nil
            view.onDiscardDraft = nil
            view.updateLiveStatus(.unavailable, presentation: .unavailable)
            return
        }
        view.presentationStateProvider = { [weak self] in self?.appearancePresentationState ?? .unavailable }
        view.reload(preferences: live.requested, loadResult: coordinator.loadResult)
        let isCurrent: @MainActor () -> Bool = { [weak self, weak live, weak view] in
            guard let self, let live, let view else { return false }
            return !self.didRunFinalTeardown && self.liveAppearanceCoordinator === live
                && self.configuredAppearanceSettingsView === view
        }
        view.onChange = { [weak self, weak live] value in
            guard isCurrent(), self?.workspaceQuit.isPending == false else { return false }
            return live?.submit(value) == true
        }
        view.onFlush = { [weak live] in
            guard isCurrent() else { return }
            live?.flush()
        }
        view.onDiscardDraft = view.onFlush // Dismissal flushes, never rolls back accepted live edits.
        view.onApply = { [weak self, weak live] value in
            guard isCurrent(), self?.workspaceQuit.isPending == false else { return .encodingFailed }
            return live?.retry(value) ?? .encodingFailed
        }
        refreshAppearancePresentationStatus()
    }

    /// Workspace display notifications are not sent through NotificationCenter.default.
    @MainActor
    static func observeAccessibilityDisplayChanges(
        center: NotificationCenter = NSWorkspace.shared.notificationCenter,
        onChange: @escaping @MainActor () -> Void
    ) -> NSObjectProtocol {
        center.addObserver(forName: NSWorkspace.accessibilityDisplayOptionsDidChangeNotification,
                           object: nil, queue: .main) { _ in
            MainActor.assumeIsolated { onChange() }
        }
    }

    @MainActor
    func handleAccessibilityDisplayChange(wallpaperPolicy: LaunchcopyMaterialPolicy = .init()) {
        defer { schedulePendingAppearancePresentation() }
        guard !didRunFinalTeardown else { return }
        // Cancel the unaccepted draft before drag cancellation can transfer focus.
        finishFolderTitleEditing(returnFocus: false)
        currentMaterialPolicy = wallpaperPolicy
        refreshLauncherChromeMaterial(policy: wallpaperPolicy)
        surface?.refreshReduceMotionFromSystem()
        // Reconfiguring folder cells must not leave a press/drag bound to old views.
        dragCoordinator?.cancel(reason: .layoutChanged)
        cancelFolderVisualTransition()
        if folderOpenState?.isOpen == true { refreshFolderOverlay() }
        if let window {
            wallpaperBackdrop?.refresh(for: window.screen ?? NSScreen.main, policy: wallpaperPolicy,
                                       blurRadius: Double(appearancePreferences.wallpaperBlurRadius))
        }
    }

    /// A valid live intent or durable command requests presentation; save state is separate.
    @MainActor
    func applyAppearancePreferences(_ preferences: AppearancePreferences) {
        guard !didRunFinalTeardown, preferences.isValid else { return }
        if preferences == appearancePreferences {
            pendingAppearancePreferences = nil
            refreshAppearancePresentationStatus()
            return
        }
        pendingAppearancePreferences = preferences
        flushPendingAppearanceIfReady()
    }

    @MainActor
    var appearancePresentationState: AppearancePresentationState {
        if didRunFinalTeardown || surface?.isTearingDown == true { return .unavailable }
        return pendingAppearancePreferences == nil ? .applied : .queued
    }

    @MainActor
    private var appearancePresentationIsReady: Bool {
        guard leadingLibraryNavigator?.isTransitioning != true,
              appRemovalCoordinator?.isBusy != true, !didRunFinalTeardown, !isApplyingAppearance, !isRestoringLayout,
              !workspaceQuit.isPending, !isTitleEditing, folderTitleEditor == nil,
              folderRenameContext == nil, dragCoordinator?.isSessionActive != true,
              folderEntranceAppearanceGeneration == nil, folderExitVisual == nil,
              folderOverlay?.isTrackpadPagingActive != true,
              folderOverlay?.isMoveOutPresentationCollapsed != true,
              appLibraryOwner?.hasPresentationOwnership != true,
              window?.attachedSheet == nil, NSApp?.modalWindow == nil,
              (window?.firstResponder as? NSTextView)?.hasMarkedText() != true,
              languagePresentationController?.hasInteractionOwners != true,
              appearancePresentationReadinessCheck?() != false else { return false }
        guard let surface else { return true }
        return !surface.isTearingDown && surface.pinnedPresentation == nil
            && (surface.core.state == .idle || surface.core.state == .cancelled)
    }

    @MainActor
    func flushPendingAppearanceIfReady() {
        guard appearancePresentationIsReady, let preferences = pendingAppearancePreferences else { return }
        pendingAppearancePreferences = nil
        isApplyingAppearance = true
        let blurChanged = preferences.wallpaperBlurRadius != appearancePreferences.wallpaperBlurRadius
        appearancePreferences = preferences
        assembly?.renderer.itemAppearance = preferences.mainItemAppearance
        assembly?.renderer.showsAppLabels = preferences.showsAppLabels
        folderOverlay?.itemAppearance = preferences.itemAppearance
        folderOverlay?.showsAppLabels = preferences.showsAppLabels
        refreshFolderLayoutIfReady()
        if blurChanged, let window { refreshWallpaperBackdrop(for: window) }
        isApplyingAppearance = false
        refreshMainGridReadability()
        layoutPageDots()
        layoutCatalogStatus()
        refreshAppearancePresentationStatus()
        if pendingAppearancePreferences != nil { schedulePendingAppearancePresentation() }
    }

    /// Readiness events can run inside Core's terminal frame; do not restyle on that stack.
    @MainActor
    func schedulePendingAppearancePresentation() {
        scheduleLanguageReadinessRetry()
        schedulePendingMainGridCapacityPresentation()
        scheduleFolderLayoutRefresh()
        guard !didRunFinalTeardown, pendingAppearancePreferences != nil, !appearanceRetryScheduled else { return }
        appearanceRetryScheduled = true
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.appearanceRetryScheduled = false
            self.flushPendingAppearanceIfReady()
        }
    }

    @MainActor
    private func refreshAppearancePresentationStatus() {
        guard !didRunFinalTeardown else { return }
        if let live = liveAppearanceCoordinator {
            configuredAppearanceSettingsView?.updateLiveStatus(live.state, presentation: appearancePresentationState)
        } else { configuredAppearanceSettingsView?.refreshPresentationStatus() }
    }

    // MARK: - Approved optional App Library

    @MainActor
    func installAppLibrary(in host: NSView, store injectedStore: (any AppLibraryPersisting)? = nil,
                           activityStore injectedActivityStore: (any LaunchActivityPersisting)? = nil) {
        guard !didRunFinalTeardown, appLibraryOwner == nil else { return }
        let store: any AppLibraryPersisting
        if let injectedStore { store = injectedStore }
        else {
            let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            guard let file = AppLibraryStoreLocation.resolve(testProfileRequested: options.uiTestProfile != nil,
                profile: uiTestProfile, applicationSupportURL: support) else { return }
            store = AppLibraryFileStore(fileURL: file)
        }
        let activity: LaunchActivityCoordinator?
        if options.gestureValidation || options.integratedPreview { activity = nil }
        else if let injectedActivityStore { activity = LaunchActivityCoordinator(store: injectedActivityStore) }
        else if injectedStore == nil {
            let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            guard let file = LaunchActivityStoreLocation.resolve(testProfileRequested: options.uiTestProfile != nil,
                profile: uiTestProfile, applicationSupportURL: support) else { return }
            activity = LaunchActivityCoordinator(store: LaunchActivityFileStore(fileURL: file))
        } else { activity = nil } // Existing injected Library tests never inspect formal activity data.
        let preferences = AppLibraryPreferencesCoordinator(store: store)
        let owner = AppLibraryOwnerController(preferences: preferences,
            strings: languageStrings ?? LocalizedStrings(language: .english), iconPipeline: assembly?.iconPipeline, activity: activity)
        owner.allowsExternalApplicationActions = !options.gestureValidation
        owner.allowsApplicationRemoval = !options.gestureValidation && !options.integratedPreview
        appLibraryOwner = owner
        owner.catalogProvider = { [weak self] in self?.assembly?.provider.servedSnapshot }
        // The owner may be mounted after the first refresh-state event. Seed from
        // the shared controller, without starting another scan or touching disk.
        owner.noteCatalogRefreshState(assembly?.refreshController.state ?? .ready)
        owner.managementProvider = { [weak self] in self?.appManagementPreferences ?? .default }
        owner.canTransition = { [weak self] in self?.libraryTransitionIsReady == true }
        owner.canExecuteAction = { [weak self] in
            self?.leadingLibraryNavigator?.isTransitioning != true && self?.libraryTransitionIsReady == true && self?.window?.isVisible == true
                && self?.window?.isKeyWindow == true && NSApp.isActive
        }
        owner.captureGrid = { [weak self] in
            guard let self, let window = self.window, window.isVisible, let search = self.search, let surface = self.surface else { return nil }
            return AppLibraryGridReturnContext(query: search.field.currentEditor()?.string ?? search.field.stringValue,
                page: surface.core.committedPage, selection: self.keyboardController?.focusModel.current,
                searchWasFocused: window.firstResponder === search.field || window.firstResponder === search.field.currentEditor())
        }
        owner.prepareEntry = { [weak self] in
            self?.closeFolder()
            self?.cancelFolderVisualTransition()
            self?.surface?.cancel()
            self?.keyboardController?.clearFocusForSearch()
            self?.pendingLibraryGridFocus = nil
        }
        owner.setGridHidden = { [weak self] hidden in
            self?.mainGridHiddenForLibrary = hidden
            self?.applyMainGridVisibility()
            self?.search?.field.isHidden = hidden
            self?.keyboardController?.isHidden = hidden
            self?.pageDotsView?.isHidden = hidden || self?.mainGridIsReadable == false
            self?.applyCatalogStatusVisibility()
            self?.launcherSettingsButton?.isHidden = hidden
            self?.refreshPageDots()
        }
        owner.restoreGrid = { [weak self] context in self?.restoreGridAfterLibrary(context) }
        owner.onReadinessChange = { [weak self] in
            self?.scheduleLanguageReadinessRetry()
            self?.schedulePendingAppearancePresentation()
        }
        owner.openApp = { [weak self] request, _ in
            _ = self?.launchController?.handleApp(appID: request.appID,
                expectedRevision: request.catalogRevision, expectedURL: request.canonicalURL)
        }
        owner.revealApp = { [weak self] record in _ = self?.handleFinderReveal(record) }
        owner.setHidden = { [weak self] record, hidden in
            guard let self, let coordinator = self.appManagementCoordinator else { return }
            let result = coordinator.apply(coordinator.committed.settingHidden(hidden, for: record))
            if result != .saved { self.showAppManagementError(result) }
        }
        owner.editAlias = { [weak self, weak owner] request, record in
            self?.showAppAliasEditor(record, additionalValidation: { [weak self, weak owner] in
                self?.libraryNonmodalLifecycleIsReady == true && owner?.resolve(request, checkingReadiness: false) != nil
            })
        }
        owner.assignFolder = { [weak self] request, record in self?.showLibraryFolderAssignment(request, record: record) }
        owner.moveToTrash = { [weak self, weak owner] request, record in
            self?.beginAppRemoval(record, additionalValidation: { [weak owner] in
                owner?.resolve(request, checkingReadiness: false) != nil
            })
        }
        owner.onRecoveryRequested = { [weak self] in self?.presentLibraryRecovery() }
        owner.onActivityClearRequested = { [weak self] in self?.presentLaunchActivityConfirmation(recovering: false) }
        owner.onActivityRecoveryRequested = { [weak self] in self?.presentLaunchActivityConfirmation(recovering: true) }
        owner.onCategorySaveFailure = { [weak self, weak owner] in
            guard let self, self.appLibraryOwner === owner, owner?.isOpen == true,
                  self.libraryNonmodalLifecycleIsReady,
                  let window = self.window, window.isVisible, window.attachedSheet == nil,
                  let strings = self.languageStrings else { return }
            let alert = NSAlert()
            alert.alertStyle = .warning
            alert.messageText = strings.libraryText(.saveFailed)
            alert.addButton(withTitle: strings.text(.close))
            self.presentApplicationSheet(alert, for: window)
        }
        if libraryEntryProfileSession == nil, let profile = uiTestProfile {
            libraryEntryProfileSession = LibraryEntryProfileSession.make(profile: profile,
                marker: Bundle.main.object(forInfoDictionaryKey: "LaunchcopyLibraryEntryProfiling"))
        }
        owner.entryProfile = libraryEntryProfileSession?.recorder
        owner.attach(to: host, showsEntryButton: false)
        installLeadingLibraryNavigation(owner: owner, host: host)
        if let field = search?.field { owner.layout(searchFrame: field.frame) }
        if let window = window as? QuitOnBlankClickWindow {
            window.libraryActiveProvider = { [weak owner] in owner?.isOpen == true }
            window.onLibraryEscape = { [weak owner] in owner?.handleEscape() ?? false }
        }
    }

    @MainActor
    private func installLeadingLibraryNavigation(owner: AppLibraryOwnerController, host: NSView) {
        guard let surface else { return }
        leadingLibraryNavigator?.teardown()
        let navigator = LeadingLibraryNavigator(surface: surface, owner: owner)
        navigator.entryProfile = libraryEntryProfileSession?.recorder
        owner.canPrepare = { [weak navigator] in navigator?.isTransitioning == false }
        owner.prepareGridLayerBackings = { [weak self] in
            guard let self else { return 0 }
            return LeadingLibraryPresentation.prepareLayerBackings(for: self.leadingLibraryGridViews)
        }
        libraryEntryProfileSession?.isCapturingInteraction = { [weak navigator] in
            navigator?.isTransitioning == true
        }
        leadingLibraryNavigator = navigator
        navigator.width = { [weak host] in host?.bounds.width ?? 0 }
        navigator.canNavigate = { [weak self, weak owner] in
            guard let self, let owner else { return false }
            return self.libraryTransitionIsReady && self.mainGridIsReadable
                && owner.preferences.isLoaded && owner.preferences.committed.enabled
                && owner.preferences.pendingCount == 0 && owner.view?.detailsOpen != true
        }
        navigator.canEnterFromGrid = { [weak self, weak surface] in
            self?.folderOpenState?.isOpen != true && surface?.core.committedPage == 0
                && surface?.pinnedPresentation == nil
        }
        navigator.canForwardGridInput = { [weak self] in
            guard let self else { return false }
            return !self.didRunFinalTeardown && self.mainGridIsReadable
                && self.appLibraryOwner?.isOpen != true && self.folderOpenState?.isOpen != true
        }
        navigator.forwardNative = { [weak self] event in
            (self?.window as? QuitOnBlankClickWindow)?.deliverOriginalNativeEvent(event)
        }
        navigator.render = { [weak self, weak owner] offset, reduced in
            guard let self else { return }
            LeadingLibraryPresentation.render(offset: offset, width: self.container?.bounds.width ?? 0,
                reduceMotion: reduced, gridViews: self.leadingLibraryGridViews, libraryView: owner?.view)
        }
        navigator.resetPresentation = { [weak self, weak owner] in
            guard let self else { return }
            LeadingLibraryPresentation.reset(gridViews: self.leadingLibraryGridViews, libraryView: owner?.view)
        }
        navigator.setGridPreviewVisible = { [weak self] visible in
            guard let self else { return }
            self.mainGridPreviewForLibrary = visible
            self.applyMainGridVisibility()
            let hidden = self.mainGridHiddenForLibrary && !visible
            self.search?.field.isHidden = self.mainGridHiddenForLibrary
            self.launcherSettingsButton?.isHidden = hidden
            self.surface?.setAccessibilityHidden(self.mainGridHiddenForLibrary || visible)
            if visible { self.pageDotsView?.isHidden = !self.mainGridIsReadable || (self.surface?.core.pageCount ?? 0) < 2 }
            else { self.refreshPageDots() }
        }
        navigator.onReadinessChange = { [weak self, weak owner] in
            owner?.refreshReadiness()
            self?.schedulePendingAppearancePresentation()
        }
        navigator.prepareFirstGridPage = { [weak self, weak surface] in
            // The return context remains intact. Only the hidden rendering moves to first
            // page, ready for a swipe return; Close/Escape still resolves the saved anchor.
            guard self?.appLibraryOwner?.isOpen == true, let surface, surface.core.committedPage != 0 else { return }
            _ = surface.requestPage(0)
        }
        owner.onBeforeBack = { [weak navigator] in navigator?.cancel() }
        owner.onPresentationChange = { [weak navigator] in navigator?.ownerDidChange() }
        if let window = window as? QuitOnBlankClickWindow { installLeadingLibraryWindowInput(on: window) }
    }

    @MainActor
    func installLeadingLibraryWindowInput(on window: QuitOnBlankClickWindow) {
        guard let navigator = leadingLibraryNavigator else { return }
        window.onLeadingLibraryEvent = { [weak navigator] event in
            guard let navigator else { return false }
            if event.type == .scrollWheel { return navigator.handleScroll(event) }
            guard navigator.isTransitioning else { return false }
            if event.type == .keyDown, event.keyCode == 53 { navigator.cancel(); return true }
            switch event.type {
            case .leftMouseDown, .leftMouseUp, .leftMouseDragged, .rightMouseDown,
                 .rightMouseUp, .otherMouseDown, .otherMouseUp, .keyDown, .keyUp: return true
            default: return false
            }
        }
    }

    @MainActor
    private var leadingLibraryGridViews: [NSView] {
        [surface, pageDotsView, launcherSettingsButton,
         mainGridSpaceNotice, catalogStatusView, appLibraryOwner?.entryButton].compactMap { $0 }
    }

    @MainActor
    private var libraryNonmodalLifecycleIsReady: Bool {
        guard !didRunFinalTeardown, workspaceQuit.phase == .idle, !isRestoringLayout,
              folderOpenState?.isOpen != true, !isTitleEditing, folderRenameContext == nil, dragCoordinator?.isSessionActive != true,
              let surface, !surface.isTearingDown else { return false }
        switch surface.core.state {
        case .idle, .cancelled: return true
        default: return false
        }
    }

    @MainActor
    private var libraryTransitionIsReady: Bool {
        libraryNonmodalLifecycleIsReady && appRemovalCoordinator?.isBusy != true && window?.attachedSheet == nil
            && ActivationSettingsWindowController.shared?.window?.attachedSheet == nil
            && (window?.firstResponder as? NSTextView)?.hasMarkedText() != true
    }

    @MainActor
    func configureAppLibrarySettings(_ controller: ActivationSettingsWindowController) {
        if let owner = appLibraryOwner { owner.configureSettings(controller.appLibrarySettingsView) }
        else {
            controller.appLibrarySettingsView.applyState(preferences: .default, loadResult: .unavailable,
                pendingCount: 0, saveResult: nil, isLoaded: true)
        }
    }

    @MainActor
    private func restoreGridAfterLibrary(_ context: AppLibraryGridReturnContext) {
        guard !didRunFinalTeardown, let surface, !surface.isTearingDown, let provider = assembly?.provider else { return }
        search?.restoreAfterLibrary(query: context.query, focusSearch: context.searchWasFocused && context.selection == nil)
        guard let catalog = provider.servedSnapshot else { return }
        let layout = AppGridFocusLayout.build(from: catalog, composition: provider.presentationEntries,
                                             itemsPerPage: surface.itemsPerPage)
        let target = AppLibraryGridReturnPolicy.resolve(context, in: layout)
        keyboardController?.clearFocusForPointerNavigation()
        pendingLibraryGridFocus = target.selection
        if target.page != surface.core.committedPage {
            if !surface.requestPage(target.page) { pendingLibraryGridFocus = nil }
        } else { restorePendingLibraryGridFocus() }
        if context.selection != nil || !context.searchWasFocused { window?.makeFirstResponder(keyboardController) }
        refreshPageDots()
    }

    @MainActor
    private func restorePendingLibraryGridFocus() {
        guard appLibraryOwner?.isOpen != true, let target = pendingLibraryGridFocus,
              let surface, surface.core.state == .idle || surface.core.state == .cancelled else { return }
        pendingLibraryGridFocus = nil
        guard let catalog = assembly?.provider.servedSnapshot, let provider = assembly?.provider else { return }
        let layout = AppGridFocusLayout.build(from: catalog, composition: provider.presentationEntries,
                                             itemsPerPage: surface.itemsPerPage)
        guard let entry = target.entryIdentity, let position = layout.position(of: entry),
              position.page == surface.core.committedPage else { return }
        keyboardController?.setFocus(to: .init(catalogRevision: layout.revision,
            pageIndex: position.page, slotIndex: position.slot, entryIdentity: entry))
    }

    @MainActor
    private func presentLibraryRecovery() {
        guard libraryTransitionIsReady, let owner = appLibraryOwner,
              owner.preferences.loadResult == .corrupt || owner.preferences.latestSaveResult == .recoveryRequired,
              let settings = ActivationSettingsWindowController.shared?.window,
              settings.attachedSheet == nil, let strings = languageStrings else { return }
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = strings.libraryText(.loadCorrupt)
        alert.addButton(withTitle: strings.text(.cancel))
        alert.addButton(withTitle: strings.libraryText(.recover))
        let release = acquireApplicationModalLease()
        alert.beginSheetModal(for: settings) { [weak self, weak owner] response in
            defer { release() }
            guard response == .alertSecondButtonReturn, let self,
                  self.libraryNonmodalLifecycleIsReady, self.appLibraryOwner === owner else { return }
            _ = owner?.recoverPreferences()
        }
    }

    @MainActor
    private func presentLaunchActivityConfirmation(recovering: Bool) {
        guard libraryTransitionIsReady, let owner = appLibraryOwner, let activity = owner.activity,
              recovering ? activity.canRecover : (activity.canWrite && !activity.isClearing),
              let settings = ActivationSettingsWindowController.shared?.window,
              settings.attachedSheet == nil, let strings = languageStrings else { return }
        let epoch = activity.generation
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = strings.launchActivityText(recovering ? .recover : .clearTitle)
        alert.informativeText = strings.launchActivityText(recovering ? .recoveryRequired : .clearMessage)
        alert.addButton(withTitle: strings.launchActivityText(.cancel))
        alert.addButton(withTitle: strings.launchActivityText(recovering ? .recover : .clearConfirm))
        let release = acquireApplicationModalLease()
        alert.beginSheetModal(for: settings) { [weak self, weak owner, weak activity] response in
            defer { release(); owner?.refreshReadiness() }
            guard response == .alertSecondButtonReturn, let self, let activity,
                  self.libraryNonmodalLifecycleIsReady, self.appLibraryOwner === owner,
                  owner?.activity === activity, activity.generation == epoch else { return }
            if recovering { _ = activity.recover() } else { _ = activity.clear(expectedGeneration: epoch) }
        }
    }

    @MainActor
    private func showLibraryFolderAssignment(_ request: AppLibraryActionRequest, record: AppRecord) {
        guard canApplyFolderAssignment, let owner = appLibraryOwner, owner.resolve(request) != nil,
              let window, window.attachedSheet == nil, let layout = currentPersistentLayout(),
              let writer = layoutStore, let strings = languageStrings,
              let choices = FolderAssignmentChoices(record: record, layout: layout),
              !choices.destinations.isEmpty || choices.canMoveOut else { return }
        let writerEpoch = layoutRestoreGeneration
        let writerDirectory = writer.storeDirectory
        let currentOrigin: () -> Bool = { [weak self, weak owner] in
            guard let self, self.appLibraryOwner === owner,
                  self.layoutRestoreGeneration == writerEpoch,
                  self.layoutStore?.storeDirectory == writerDirectory else { return false }
            return owner?.resolve(request, checkingReadiness: false) != nil
        }
        let alert = NSAlert()
        alert.messageText = strings.menuText(.organizeApps)
        alert.addButton(withTitle: strings.noticeText(.save))
        alert.addButton(withTitle: strings.text(.cancel))
        let popup = NSPopUpButton(frame: .init(x: 0, y: 0, width: 300, height: 28), pullsDown: false)
        let menu = NSMenu()
        menu.autoenablesItems = false
        popup.menu = menu
        func appendChoice(title: String, action: FolderAssignmentAction) {
            // Title-based popup insertion collapses duplicates, including a folder
            // whose literal name matches the localized move-out operation.
            let item = NSMenuItem(title: title, action: nil, keyEquivalent: "")
            item.representedObject = action
            item.setAccessibilityLabel(title)
            menu.addItem(item)
        }
        for destination in choices.destinations {
            appendChoice(title: destination.title, action: .moveToFolder(destination.id))
        }
        if choices.canMoveOut {
            if !choices.destinations.isEmpty { menu.addItem(.separator()) }
            appendChoice(title: strings.menuText(.moveToTopLevel), action: .moveToTopLevel)
        }
        popup.selectItem(at: 0)
        popup.setAccessibilityLabel(strings.menuText(.moveToFolder))
        alert.accessoryView = popup
        presentApplicationSheet(alert, for: window) { [weak self, weak owner] response in
            guard response == .alertFirstButtonReturn, currentOrigin(), let self, let owner,
                  let current = owner.resolve(request, checkingReadiness: false),
                  let action = popup.selectedItem?.representedObject as? FolderAssignmentAction else { return }
            let result = self.applyFolderAssignment(record: current, action: action, expectedLayout: layout,
                validateBinding: currentOrigin)
            if case .rejected = result { self.showFolderAssignmentError(result) }
        }
    }

    // MARK: - Approved interface language runtime

    /// Profile resolution precedes persistent access; tests inject owned stores.
    @MainActor
    func installLanguagePreferences(store injected: (any LanguagePreferencesPersisting)? = nil,
                                    preferredLanguages: @escaping () -> [String] = { Locale.preferredLanguages },
                                    center: NotificationCenter = .default) {
        guard !didRunFinalTeardown else { return }
        teardownLanguagePresentation()
        let store: any LanguagePreferencesPersisting
        if let injected { store = injected }
        else if options.uiTestProfile != nil && uiTestProfile == nil {
            store = UnavailableLanguagePreferencesStore()
        } else if let persisted = UserDefaultsLanguagePreferencesStore(
            suiteName: uiTestProfile?.languageSuiteName ?? UserDefaultsLanguagePreferencesStore.defaultSuiteName) {
            store = persisted
        } else { store = UnavailableLanguagePreferencesStore() }
        let epoch = languageGeneration
        let coordinator = LanguageSettingsCoordinator(store: store) { [weak self] preference in
            guard let self, self.languageGeneration == epoch else { return }
            self.languagePresentationController?.request(preference)
        }
        let owner = LanguagePresentationController(preference: coordinator.committed.language,
            preferredLanguages: preferredLanguages, isReady: { [weak self] in
                self?.languagePresentationIsReady == true
            })
        languageSettingsCoordinator = coordinator
        languagePresentationController = owner
        languageStrings = LocalizedStrings(language: owner.displayedLanguage)
        owner.onPresent = { [weak self] language in self?.presentLanguage(language) }
        owner.onStateChange = { [weak self] _ in
            self?.configuredLanguageSettingsController?.languageView.refreshPresentationStatus()
        }
        languageRuntimeObservers = LanguageRuntimeObservers(center: center, owner: owner) { [weak self] in
            self?.schedulePendingAppearancePresentation()
        }
        rebindCurrentPresentationActions()
    }

    @MainActor
    func configureLanguageSettings(_ controller: ActivationSettingsWindowController) {
        guard !didRunFinalTeardown, let coordinator = languageSettingsCoordinator,
              let owner = languagePresentationController, let strings = languageStrings else { return }
        let alreadyConfigured = configuredLanguageSettingsController === controller
        configuredLanguageSettingsController = controller
        controller.relabel(strings: strings)
        controller.languageView.onApply = { [weak coordinator] draft in
            coordinator?.apply(draft) ?? .unavailable
        }
        controller.languageView.presentationStateProvider = { [weak owner] in owner?.state ?? .unavailable }
        if !alreadyConfigured {
            controller.languageView.reload(preferences: coordinator.committed, loadResult: coordinator.loadResult)
        }
        let epoch = languageGeneration
        controller.onDiscardLanguageDraft = { [weak self, weak coordinator, weak controller] in
            guard let self, self.languageGeneration == epoch, let coordinator else { return }
            controller?.languageView.reload(preferences: coordinator.committed, loadResult: coordinator.loadResult)
        }
        controller.acquireModalOwnership = { [weak self] in self?.acquireApplicationModalLease() ?? {} }
        controller.appSourcesView.acquireModalOwnership = { [weak self] in self?.acquireApplicationModalLease() ?? {} }
        controller.onLanguageReadinessChange = { [weak self] in
            guard let self, self.languageGeneration == epoch else { return }
            self.scheduleLanguageReadinessRetry()
        }
        controller.appSourcesView.onPresentationOwnershipChange = { [weak self] in
            guard let self, self.languageGeneration == epoch else { return }
            self.scheduleLanguageReadinessRetry()
        }
        // Resolve the accepted Follow System choice without touching any other draft.
        coordinator.refreshAcceptedPresentation()
    }

    @MainActor
    var languagePresentationIsReady: Bool {
        guard leadingLibraryNavigator?.isTransitioning != true,
              appRemovalCoordinator?.isBusy != true, !didRunFinalTeardown, !isRestoringLayout, !workspaceQuit.isPending,
              !isQuitSaveModalRunning, !isTitleEditing, folderTitleEditor == nil,
              folderRenameContext == nil, dragCoordinator?.isSessionActive != true,
              folderEntranceAppearanceGeneration == nil, folderExitVisual == nil,
              folderOverlay?.isTrackpadPagingActive != true,
              folderOverlay?.isMoveOutPresentationCollapsed != true,
              configuredLanguageSettingsController?.hasLanguagePresentationOwnership != true,
              appLibraryOwner?.hasPresentationOwnership != true,
              window?.attachedSheet == nil, NSApp?.modalWindow == nil,
              (window?.firstResponder as? NSTextView)?.hasMarkedText() != true else { return false }
        guard let surface else { return true }
        return !surface.isTearingDown && surface.pinnedPresentation == nil
            && (surface.core.state == .idle || surface.core.state == .cancelled)
    }

    /// Events may arrive before AppKit finishes unmarking text or closing a sheet.
    /// Retry on the next turn, then the owner schedules presentation separately.
    @MainActor
    func scheduleLanguageReadinessRetry() {
        schedulePendingManagementPresentation()
        schedulePendingIdentifierSearchPresentation()
        schedulePendingMainGridCapacityPresentation()
        guard !didRunFinalTeardown, languagePresentationController?.pendingLanguage != nil,
              !languageRetryScheduled else { return }
        languageRetryScheduled = true
        let epoch = languageGeneration
        DispatchQueue.main.async { [weak self] in
            guard let self, self.languageGeneration == epoch else { return }
            self.languageRetryScheduled = false
            self.languagePresentationController?.readinessDidChange()
        }
    }

    @MainActor
    private func presentLanguage(_ language: InterfaceLanguage) {
        guard !didRunFinalTeardown else { return }
        let strings = LocalizedStrings(language: language)
        languagePresentationApplyCount += 1
        languageStrings = strings
        configuredLanguageSettingsController?.relabel(strings: strings)
        search?.field.relabel(strings: strings)
        assembly?.provider.relabel(strings: strings)
        assembly?.renderer.relabel(strings: strings)
        surface?.relabel(strings: strings)
        folderOverlay?.relabel(strings: strings)
        pageDotsView?.relabel(strings: strings)
        folderTitleEditor?.relabel(strings: strings)
        relabelWorkspaceSaveNotice()
        actionFeedbackView?.relabel(strings: strings)
        catalogStatusView?.relabel(strings: strings)
        scheduleCatalogStatusRefresh()
        statusItemController?.relabel(strings: strings)
        appLibraryOwner?.relabel(strings: strings)
        localizedQuitMenuItem?.title = strings.text(.quitLauncher)
        localizedToggleMenuItem?.title = strings.settingsText(.toggleLauncherTitle)
        localizedLibraryMenuItem?.title = strings.libraryText(.title)
        localizedViewMenu?.title = strings.settingsText(.viewMenuTitle)
        editMenuController?.relabel(strings: strings)
        launcherSettingsButton?.setAccessibilityLabel(strings.settingsText(.settingsButtonAccessibility))
        launcherSettingsButton?.toolTip = strings.settingsText(.settingsButtonAccessibility)
        refreshMainGridSpaceNotice()
    }

    @MainActor
    func teardownLanguagePresentation() {
        languageGeneration &+= 1
        languageSettingsCoordinator?.invalidate()
        languagePresentationController?.teardown()
        languageRuntimeObservers?.teardown()
        languageRuntimeObservers = nil
        languageRetryScheduled = false
        actionFeedbackView?.clear()
        managementRefreshPending = false
        managementRefreshScheduled = false
        configuredLanguageSettingsController?.onLanguageReadinessChange = nil
        configuredLanguageSettingsController?.onDiscardLanguageDraft = nil
        configuredLanguageSettingsController?.appSourcesView.onPresentationOwnershipChange = nil
        configuredLanguageSettingsController?.languageView.onApply = nil
        configuredLanguageSettingsController?.languageView.presentationStateProvider = nil
        configuredLanguageSettingsController = nil
    }

    @MainActor
    func installAppManagementPreferences(store injectedStore: (any AppManagementPersisting)? = nil) {
        appManagementGeneration &+= 1
        pendingIdentifierSearchEnabled = nil
        identifierSearchRetryScheduled = false
        let store: any AppManagementPersisting
        if let injectedStore { store = injectedStore }
        else if options.uiTestProfile != nil && uiTestProfile == nil { store = UnavailableAppManagementStore() }
        else if let persisted = UserDefaultsAppManagementStore(suiteName: uiTestProfile?.managementSuiteName ?? UserDefaultsAppManagementStore.defaultSuiteName) { store = persisted }
        else { store = InMemoryAppManagementStore() }
        let coordinator = AppManagementCoordinator(store: store) { [weak self] preferences in
            self?.applyAppManagementPreferences(preferences)
        }
        appManagementCoordinator = coordinator
        if assembly == nil { appManagementPreferences = coordinator.committed }
        else { applyAppManagementPreferences(coordinator.committed) }
        refreshIdentifierSearchSettingsState()
        rebindCurrentPresentationActions()
    }

    @MainActor
    func applyAppManagementPreferences(_ preferences: AppManagementPreferences) {
        guard !didRunFinalTeardown, preferences.isValid else { return }
        pendingIdentifierSearchEnabled = preferences.searchByBundleIdentifier != appManagementPreferences.searchByBundleIdentifier
            ? preferences.searchByBundleIdentifier : nil
        // A policy-only preference does not cancel input or close a folder.
        if preferences.hiddenKeys == appManagementPreferences.hiddenKeys,
           preferences.aliases == appManagementPreferences.aliases {
            schedulePendingIdentifierSearchPresentation()
            refreshIdentifierSearchSettingsState()
            return
        }
        var effective = preferences
        effective.searchByBundleIdentifier = appManagementPreferences.searchByBundleIdentifier
        appManagementPreferences = effective
        guard let assembly else { return }
        closeFolder()
        assembly.provider.receiveManagementPreferences(effective)
        dragCoordinator?.cancel(reason: .catalogRefresh)
        surface?.cancel()
        applyPendingAtIdleBoundary()
        refreshAppManagementSettings()
        schedulePendingIdentifierSearchPresentation()
        refreshIdentifierSearchSettingsState()
    }

    @MainActor
    @discardableResult
    func setSearchByBundleIdentifier(_ enabled: Bool) -> AppManagementSaveResult {
        guard !didRunFinalTeardown, let coordinator = appManagementCoordinator else { return .failed }
        let result = coordinator.applySearchByBundleIdentifier(enabled)
        refreshIdentifierSearchSettingsState()
        return result
    }

    @MainActor
    private var identifierSearchPresentationIsReady: Bool {
        languagePresentationIsReady && !isApplyingIdentifierSearch
            && languagePresentationController?.hasInteractionOwners != true
            && workspacePersistence.pendingCount == 0
            && (appLibraryOwner?.preferences.pendingCount ?? 0) == 0
            && identifierSearchSettingsView?.aliasField.currentEditor() == nil
            && identifierSearchPresentationReadinessCheck?() != false
    }

    /// Invoked by existing readiness events. No polling or work on a frame stack.
    @MainActor
    private func schedulePendingIdentifierSearchPresentation() {
        guard !didRunFinalTeardown, pendingIdentifierSearchEnabled != nil,
              !identifierSearchRetryScheduled else { return }
        identifierSearchRetryScheduled = true
        let epoch = appManagementGeneration
        let coordinator = appManagementCoordinator
        DispatchQueue.main.async { [weak self, weak coordinator] in
            guard let self, !self.didRunFinalTeardown, self.appManagementGeneration == epoch,
                  self.appManagementCoordinator === coordinator else { return }
            self.identifierSearchRetryScheduled = false
            self.flushPendingIdentifierSearchIfReady()
        }
    }

    @MainActor
    func flushPendingIdentifierSearchIfReady() {
        guard identifierSearchPresentationIsReady, let enabled = pendingIdentifierSearchEnabled else { return }
        pendingIdentifierSearchEnabled = nil
        isApplyingIdentifierSearch = true
        defer {
            isApplyingIdentifierSearch = false
            refreshIdentifierSearchSettingsState()
        }
        let oldSelection = keyboardController?.focusModel.current
        let oldPage = surface?.core.committedPage ?? 0
        let libraryIsOpen = appLibraryOwner?.isOpen == true
        var anchor = oldSelection
        if anchor == nil, let assembly, let surface, let catalog = assembly.provider.servedSnapshot {
            let layout = AppGridFocusLayout.build(from: catalog, composition: assembly.provider.presentationEntries,
                                                 itemsPerPage: surface.itemsPerPage)
            if let slot = layout.validSlots(on: oldPage).first {
                anchor = .init(catalogRevision: layout.revision, pageIndex: oldPage, slotIndex: slot,
                               entryIdentity: layout.validEntry(page: oldPage, slot: slot))
            }
        }
        appManagementPreferences.searchByBundleIdentifier = enabled
        guard let assembly else { return }
        assembly.provider.receiveManagementPreferences(appManagementPreferences)
        // Existing catalog/query transaction re-evaluates the SAME query generation
        // boundary and notifies Library. No scan, forged revision or layout write.
        applyPendingAtIdleBoundary()
        guard !libraryIsOpen, let surface, let catalog = assembly.provider.servedSnapshot else { return }
        let layout = AppGridFocusLayout.build(from: catalog, composition: assembly.provider.presentationEntries,
                                             itemsPerPage: surface.itemsPerPage)
        let context = AppLibraryGridReturnContext(query: "", page: oldPage, selection: anchor, searchWasFocused: false)
        let target = AppLibraryGridReturnPolicy.resolve(context, in: layout)
        let selectionSurvives = (oldSelection?.entryIdentity).flatMap { layout.position(of: $0) } != nil
        keyboardController?.clearFocusForPointerNavigation()
        pendingLibraryGridFocus = selectionSurvives ? target.selection : nil
        if target.page != surface.core.committedPage {
            if !surface.requestPage(target.page) { pendingLibraryGridFocus = nil }
        } else { restorePendingLibraryGridFocus() }
    }

    @MainActor
    private func refreshIdentifierSearchSettingsState() {
        guard !didRunFinalTeardown, let coordinator = appManagementCoordinator else { return }
        identifierSearchSettingsView?.refreshIdentifierSearchState(
            storedEnabled: coordinator.committed.searchByBundleIdentifier,
            isPending: pendingIdentifierSearchEnabled != nil)
    }

    @MainActor
    func currentPersistentLayout() -> PersistentWorkspaceLayout? {
        guard let provider = assembly?.provider, let catalog = provider.servedSnapshot else { return sessionLayout }
        let persisted = sessionLayout ?? provider.expectedLayout
        let generation = persisted?.generation.value ?? 0
        let folderGeneration = provider.canonicalPresentationGeneration
        if let cached = resolvedLayoutCache, cached.revision == catalog.revision.value,
           cached.generation == generation, cached.folderGeneration == folderGeneration { return cached.layout }
        let base = persisted ?? DragUISessionLayoutFactory.makeSessionLayout(
            catalog: catalog, entries: provider.canonicalPresentationEntries,
            folderSnapshot: provider.canonicalFolderSnapshot)
        guard let base else { return nil }
        let tail = VisibleWorkspaceProjection.project(layout: base, catalog: catalog).unorchestratedAppRecords
        let layout = PersistentWorkspaceLayout(generation: base.generation,
            topLevelOrder: base.topLevelOrder + tail.map { .app(PersistentAppReference.from(record: $0)) },
            folders: base.folders)
        resolvedLayoutCache = (catalog.revision.value, generation, folderGeneration,
                               layout, DragLogicalIndexMap(layout: layout, catalog: catalog))
        resolvedLayoutBuildCount += 1
        return layout
    }

    /// Resolve before opening a journal; failure remains an explicit read-only backend.
    @MainActor
    func makeLayoutStore(directoryProvider: any LayoutStoreDirectoryProviding =
                         ApplicationSupportLayoutStoreDirectory()) -> any LayoutStore {
        if let profile = uiTestProfile {
            return LayoutStoreActor(storeDirectory: profile.layoutDirectoryURL)
        }
        // An unresolved isolated request must not open production storage.
        guard options.uiTestProfile == nil else { return UnavailableLayoutStore() }
        do {
            return LayoutStoreActor(storeDirectory: try directoryProvider.resolveStoreDirectory())
        } catch {
            return UnavailableLayoutStore()
        }
    }

    @MainActor
    func installLayoutStore(_ store: any LayoutStore) {
        cancelPendingWorkspaceQuit()
        finishFolderTitleEditing(returnFocus: false)
        layoutStore = store
        beginLayoutRestore(store: store)
    }

    /// Also used by tests to verify just-accepted writes reach the private journal.
    @MainActor
    func drainAcceptedWorkspaceWrites(enqueueWait: Duration = .seconds(2)) async -> LayoutStoreFlushResult {
        guard let store = layoutStore else { return .nothingPending }
        let epoch = layoutRestoreGeneration
        return await workspacePersistence.drain(to: store, epoch: epoch, enqueueWait: enqueueWait) { [weak self] in
            guard let self else { return false }
            return !self.didRunFinalTeardown && self.layoutRestoreGeneration == epoch
        }
    }

    @MainActor
    func beginLayoutRestore(store: any LayoutStore) {
        cancelPendingWorkspaceQuit()
        finishFolderTitleEditing(returnFocus: false)
        layoutRestoreTask?.cancel()
        layoutRestoreGeneration &+= 1
        let generation = layoutRestoreGeneration
        isRestoringLayout = true
        refreshTitleEditReadiness()
        layoutRestoreTask = Task { [weak self] in
            let result = await store.load()
            guard !Task.isCancelled, let self, !self.didRunFinalTeardown,
                  self.layoutRestoreGeneration == generation else { return }
            self.isRestoringLayout = false
            defer { self.rebindCurrentPresentationActions() }
            self.schedulePendingAppearancePresentation()
            if case .readOnlyProtection(let reason) = result {
                self.layoutPersistenceState = .readOnlyProtection(reason)
            } else { self.layoutPersistenceState = .healthy }
            self.refreshTitleEditReadiness()
            guard self.sessionLayout == nil else { return }
            let layout: PersistentWorkspaceLayout
            switch result {
            case .loaded(let value, _), .loadedFromBackup(let value, _): layout = value
            default: return
            }
            self.sessionLayout = layout
            self.resolvedLayoutCache = nil
            self.assembly?.provider.receiveExpectedLayout(layout)
            if let surface = self.surface, surface.core.state == .idle || surface.core.state == .cancelled {
                self.applyPendingAtIdleBoundary()
            }
        }
    }

    @MainActor
    private func refreshAppManagementSettings() {
        guard !didRunFinalTeardown,
              (configuredLanguageSettingsController ?? ActivationSettingsWindowController.shared) != nil,
              appManagementCoordinator != nil else { return }
        managementRefreshPending = true
        schedulePendingManagementPresentation()
    }

    /// The catalog commit stays synchronous; text/settings refresh never runs on its frame stack.
    @MainActor
    private func schedulePendingManagementPresentation() {
        guard managementRefreshPending, !managementRefreshScheduled, !didRunFinalTeardown else { return }
        managementRefreshScheduled = true
        let epoch = languageGeneration
        let coordinator = appManagementCoordinator
        DispatchQueue.main.async { [weak self, weak coordinator] in
            guard let self, self.languageGeneration == epoch, !self.didRunFinalTeardown else { return }
            self.managementRefreshScheduled = false
            guard self.managementRefreshPending, let coordinator,
                  self.appManagementCoordinator === coordinator,
                  let controller = self.configuredLanguageSettingsController ?? ActivationSettingsWindowController.shared else {
                self.managementRefreshPending = false
                return
            }
            guard self.languagePresentationIsReady,
                  self.languagePresentationController?.hasInteractionOwners != true,
                  controller.appManagementView.aliasField.currentEditor() == nil else { return }
            self.managementRefreshPending = false
            controller.appManagementView.refreshCatalog(
                records: self.assembly?.provider.servedSnapshot?.records ?? [],
                preferences: coordinator.committed, loadResult: coordinator.loadResult)
        }
    }

    @MainActor
    func configureAppManagementSettings(_ controller: ActivationSettingsWindowController) {
        guard let coordinator = appManagementCoordinator else { return }
        identifierSearchSettingsView = controller.appManagementView
        controller.appManagementView.onSetSearchByBundleIdentifier = { [weak self, weak coordinator] enabled in
            guard let self, let coordinator, self.appManagementCoordinator === coordinator else { return .failed }
            return self.setSearchByBundleIdentifier(enabled)
        }
        controller.appManagementView.identifierSearchPendingProvider = { [weak self] in
            self?.pendingIdentifierSearchEnabled != nil
        }
        controller.appManagementView.reload(records: assembly?.provider.servedSnapshot?.records ?? [],
                                           preferences: coordinator.committed, loadResult: coordinator.loadResult)
        refreshIdentifierSearchSettingsState()
        controller.appManagementView.onSetHidden = { [weak self] record, hidden in
            guard let self, let current = self.assembly?.provider.servedSnapshot?.records.first(where: { $0.id == record.id }),
                  let coordinator = self.appManagementCoordinator else { return .failed }
            return coordinator.apply(coordinator.committed.settingHidden(hidden, for: current))
        }
        controller.appManagementView.onSetAlias = { [weak self] record, alias in
            self?.setAppAlias(alias, for: record) ?? .failed
        }
        controller.appManagementView.onRestoreAll = { [weak coordinator] in
            guard let coordinator else { return .failed }
            var preferences = coordinator.committed
            preferences.hiddenKeys.removeAll()
            return coordinator.apply(preferences)
        }
    }

    @MainActor
    private func setAppAlias(_ alias: String?, for record: AppRecord) -> AppManagementSaveResult {
        guard let current = assembly?.provider.servedSnapshot?.records.first(where: { $0.id == record.id }),
              let coordinator = appManagementCoordinator else { return .failed }
        guard let preferences = coordinator.committed.settingAlias(alias, for: current) else { return .invalidPreferences }
        return coordinator.apply(preferences)
    }

    @MainActor
    func beginAppRemoval(_ record: AppRecord, additionalValidation: @escaping () -> Bool) {
        guard !options.gestureValidation, !options.integratedPreview,
              appRemovalCoordinator?.isBusy != true, libraryTransitionIsReady,
              folderEntranceAppearanceGeneration == nil, folderExitVisual == nil,
              let window, window.isVisible, window.isKeyWindow, NSApp.isActive,
              let assembly, let revision = assembly.provider.servedRevision else { return }
        // An unresolved test profile must never acquire a formal deletion realm.
        guard options.uiTestProfile == nil || uiTestProfile != nil else { return }
        if appRemovalCoordinator == nil {
            appRemovalCoordinator = AppRemovalCoordinator(files: LocalAppRemovalFileAccess(),
                allowedTestRoot: uiTestProfile?.applicationsDirectoryURL, selfBundleURL: Bundle.main.bundleURL,
                isRunning: { url in
                    // Snapshot AppKit objects here; canonicalization can touch
                    // the filesystem, so never do it on the UI executor.
                    let urls = NSWorkspace.shared.runningApplications.filter { !$0.isTerminated }.compactMap(\.bundleURL)
                    return await Task.detached(priority: .userInitiated) {
                        urls.contains { runningURL in
                            AppRemovalRunningPolicy.matches(candidate: url,
                                runningURL: runningURL.standardizedFileURL.resolvingSymlinksInPath(),
                                isTerminated: false)
                        }
                    }.value
                })
        }
        guard let removal = appRemovalCoordinator else { return }
        if removal.requiresQuitProtection {
            presentAppRemovalFailureAcknowledgment(removal, window: window)
            return
        }
        let root = window.contentView
        let rootEpoch = actionFeedbackGeneration, languageEpoch = languageGeneration
        let capacityEpoch = mainGridLayoutEpoch, writerEpoch = layoutRestoreGeneration
        let presentationEpoch = appRemovalPresentationGeneration
        let validate: () -> Bool = { [weak self, weak assembly, weak window] in
            guard let self, !self.didRunFinalTeardown, self.assembly === assembly,
                  self.actionFeedbackGeneration == rootEpoch, self.languageGeneration == languageEpoch,
                  self.mainGridLayoutEpoch == capacityEpoch, self.layoutRestoreGeneration == writerEpoch,
                  self.window === window, window?.contentView === root, window?.isVisible == true,
                  NSApp.isActive, self.libraryNonmodalLifecycleIsReady,
                  self.folderEntranceAppearanceGeneration == nil, self.folderExitVisual == nil,
                  assembly?.provider.servedRevision == revision,
                  let current = assembly?.provider.record(for: record.id),
                  current.canonicalURL == record.canonicalURL,
                  assembly?.provider.isHidden(record.id) == false,
                  !self.appManagementPreferences.isHidden(current) else { return false }
            return additionalValidation()
        }
        removal.onChange = { [weak self, weak removal] in
            guard let self, self.appRemovalCoordinator === removal, let removal else { return }
            switch removal.phase {
            case .inspecting: self.showAppRemovalFeedback(.inspecting)
            case .moving: self.showAppRemovalFeedback(.moving)
            case .confirming, .idle:
                if self.actionFeedbackView?.removalReason != nil { self.actionFeedbackView?.clear() }
            }
            self.appLibraryOwner?.refreshReadiness()
            self.appLibraryOwner?.view?.setAppActionsBlocked(removal.isBusy)
            self.scheduleLanguageReadinessRetry()
            self.schedulePendingAppearancePresentation()
        }
        removal.onComplete = { [weak self, weak removal, weak assembly] outcome in
            guard let self, !self.didRunFinalTeardown, self.appRemovalCoordinator === removal else { return }
            // An accepted platform receipt is meaningful even if its old view hid.
            if outcome == .moved, self.assembly === assembly { assembly?.refreshNow() }
            guard self.actionFeedbackGeneration == rootEpoch, self.languageGeneration == languageEpoch,
                  self.appRemovalPresentationIsCurrent(presentationEpoch),
                  self.window === window, window.isVisible, NSApp.isActive else { return }
            let key: AppRemovalTextKey
            switch outcome {
            case .cancelled: return
            case .moved: key = .moved
            case .unavailable: key = .unavailable
            case .running: key = .running
            case .changed: key = .changed
            case .failed: key = .failed
            }
            self.showAppRemovalFeedback(key)
            if outcome == .failed, let removal { self.presentAppRemovalFailureAcknowledgment(removal, window: window) }
        }
        _ = removal.request(url: record.canonicalURL, validate: validate) { [weak self, weak removal] _, decide in
            guard let self, self.appRemovalCoordinator === removal, validate(),
                  window.attachedSheet == nil, let strings = self.languageStrings else { decide(false); return }
            let alert = Self.makeAppRemovalConfirmation(record: record, strings: strings)
            self.appRemovalAlert = alert
            self.presentApplicationSheet(alert, for: window) { [weak self] response in
                let owns = self?.appRemovalAlert === alert
                if owns { self?.appRemovalAlert = nil }
                decide(owns && response == .alertSecondButtonReturn)
            }
        }
    }

    @MainActor
    func appRemovalPresentationIsCurrent(_ generation: UInt64) -> Bool {
        !didRunFinalTeardown && appRemovalPresentationGeneration == generation
    }

    @MainActor
    private func presentAppRemovalFailureAcknowledgment(_ removal: AppRemovalCoordinator, window: NSWindow) {
        guard !removal.isBusy, window.attachedSheet == nil, let strings = languageStrings else { return }
        let alert = NSAlert()
        alert.messageText = strings.removalText(.failed)
        alert.addButton(withTitle: strings.text(.close))
        presentApplicationSheet(alert, for: window) { [weak removal] _ in removal?.acknowledgeResult() }
    }

    @MainActor
    static func makeAppRemovalConfirmation(record: AppRecord, strings: LocalizedStrings) -> NSAlert {
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = strings.removalText(.confirmTitle)
        alert.informativeText = strings.removalText(.confirmMessage) + "\n\n" + record.displayName + "\n" + record.canonicalURL.path
        let cancel = alert.addButton(withTitle: strings.removalText(.cancel))
        cancel.keyEquivalent = "\r"
        alert.addButton(withTitle: strings.removalText(.confirmMove)).keyEquivalent = ""
        alert.window.defaultButtonCell = cancel.cell as? NSButtonCell
        return alert
    }

    @MainActor
    private func showAppRemovalFeedback(_ key: AppRemovalTextKey) {
        guard !didRunFinalTeardown, window?.isVisible == true, let strings = languageStrings,
              let view = actionFeedbackView else { return }
        if let parent = view.superview { parent.addSubview(view, positioned: .above, relativeTo: nil) }
        view.show(removalReason: key, strings: strings)
    }

    @MainActor
    private func cancelUnacceptedAppRemoval() {
        appRemovalPresentationGeneration &+= 1
        appRemovalCoordinator?.cancelUnaccepted()
        if let alert = appRemovalAlert {
            appRemovalAlert = nil
            if let parent = alert.window.sheetParent { parent.endSheet(alert.window, returnCode: .cancel) }
        }
    }

    @MainActor
    func installAppContextMenu(assembly: AppCatalogAssembly) {
        guard !options.gestureValidation else { return }
        let rootEpoch = actionFeedbackGeneration
        let languageEpoch = languageGeneration
        let management = appManagementCoordinator
        let writerEpoch = layoutRestoreGeneration
        let capacityEpoch = mainGridLayoutEpoch
        let isCurrent: () -> Bool = { [weak self, weak assembly, weak management] in
            guard let self, !self.didRunFinalTeardown, self.assembly === assembly,
                  self.actionFeedbackGeneration == rootEpoch, self.languageGeneration == languageEpoch,
                  self.appManagementCoordinator === management,
                  self.mainGridLayoutEpoch == capacityEpoch else { return false }
            return true
        }
        let isCurrentAssignment: () -> Bool = { [weak self] in
            isCurrent() && self?.layoutRestoreGeneration == writerEpoch
        }
        let menus = AppContextMenuController(recordProvider: { [weak assembly] id in
            assembly?.provider.record(for: id)
        }, revisionProvider: { [weak assembly] in assembly?.provider.servedRevision },
        hiddenProvider: { [weak self] in self?.appManagementPreferences.isHidden($0) ?? true })
        menus.interfaceStringsProvider = { [weak self] in self?.languageStrings }
        menus.actionsAreBusyProvider = { [weak self] in self?.appRemovalCoordinator?.isBusy == true }
        menus.bindingIsAvailable = { [weak self] cell in
            isCurrent() && self?.mainGridMenuBindingIsAvailable(cell) == true
        }
        menus.isReadOnlyProvider = { [weak self] in
            guard isCurrent() else { return true }
            guard let coordinator = self?.appManagementCoordinator else { return true }
            if case .futureVersion = coordinator.loadResult { return true }
            return false
        }
        menus.onLaunch = { [weak self] id in
            guard isCurrent(), let self else { return }
            self.launchMember(id)
        }
        menus.onHide = { [weak self] record in
            guard isCurrent(), let self, let coordinator = self.appManagementCoordinator else { return }
            self.showAppManagementError(coordinator.apply(coordinator.committed.settingHidden(true, for: record)))
        }
        menus.onClearAlias = { [weak self] record in
            guard isCurrent(), let self else { return }
            self.showAppManagementError(self.setAppAlias(nil, for: record))
        }
        menus.onAlias = { [weak self] record in
            guard isCurrent() else { return }
            self?.showAppAliasEditor(record)
        }
        menus.onReveal = { [weak self] record in
            guard isCurrent(), let self else { return }
            _ = self.handleFinderReveal(record)
        }
        if !options.integratedPreview {
            menus.onMoveToTrash = { [weak self] record, validateBinding in
                guard isCurrent() else { return }
                self?.beginAppRemoval(record, additionalValidation: { isCurrent() && validateBinding() })
            }
        }
        let assignments = AppFolderAssignmentMenuController(currentLayoutProvider: { [weak self] in
            guard isCurrentAssignment() else { return nil }
            return self?.currentPersistentLayout()
        }, recordProvider: { [weak assembly] in assembly?.provider.record(for: $0) },
        revisionProvider: { [weak assembly] in assembly?.provider.servedRevision },
        hiddenProvider: { [weak self, weak assembly] record in
            (self?.appManagementPreferences.isHidden(record) ?? true) || (assembly?.provider.isHidden(record.id) ?? true)
        })
        assignments.interfaceStringsProvider = { [weak self] in self?.languageStrings }
        assignments.bindingIsAvailable = { [weak self] cell in
            isCurrentAssignment() && self?.mainGridMenuBindingIsAvailable(cell) == true
        }
        assignments.isReadOnlyProvider = { [weak self] in
            guard isCurrentAssignment(), let self else { return true }
            if case .readOnlyProtection = self.layoutPersistenceState { return true }
            return self.isRestoringLayout
        }
        assignments.canApplyProvider = { [weak self] in isCurrentAssignment() && (self?.canApplyFolderAssignment ?? false) }
        assignments.onApply = { [weak self] record, action, expected, validateBinding in
            guard isCurrentAssignment() else { return .cancelled }
            return self?.applyFolderAssignment(record: record, action: action, expectedLayout: expected,
                                       validateBinding: validateBinding) ?? .cancelled
        }
        assignments.onRejected = { [weak self] result in
            guard isCurrentAssignment() else { return }
            self?.showFolderAssignmentError(result)
        }
        appFolderAssignmentMenus = assignments
        menus.organizationMenuProvider = { [weak assignments] cell, record, revision in
            guard isCurrentAssignment() else { return nil }
            return assignments?.menu(for: cell, record: record, revision: revision)
        }
        appContextMenuController = menus
        assembly.renderer.appContextMenuProvider = { [weak menus] cell in menus?.menu(for: cell) }
    }

    @MainActor
    var canCommitWorkspaceLayout: Bool {
        guard !didRunFinalTeardown, workspaceQuit.phase == .idle, !isRestoringLayout, let surface,
              !surface.isTearingDown, assembly?.provider.servedSnapshot != nil else { return false }
        if case .readOnlyProtection = layoutPersistenceState { return false }
        return true
    }

    @MainActor
    var canApplyFolderAssignment: Bool {
        if let state = folderOpenState, state.isOpen, !state.isMemberPresentationAvailable { return false }
        guard canCommitWorkspaceLayout, !isTitleEditing, let surface,
              dragCoordinator?.isSessionActive != true else { return false }
        switch surface.core.state {
        case .idle, .cancelled, .settling: return true
        case .tracking, .interrupted: return false
        }
    }

    @MainActor
    func applyFolderAssignment(record: AppRecord, action: FolderAssignmentAction,
                               expectedLayout: PersistentWorkspaceLayout,
                               validateBinding: () -> Bool = { true }) -> LayoutMutationResult {
        guard canApplyFolderAssignment, validateBinding(), let provider = assembly?.provider,
              let revision = provider.servedRevision, let current = provider.record(for: record.id),
              current.canonicalURL == record.canonicalURL,
              !appManagementPreferences.isHidden(current), !provider.isHidden(current.id),
              let layout = currentPersistentLayout() else { return .cancelled }
        let result = FolderAssignmentPolicy.apply(action: action, record: current,
                                                  expectedLayout: expectedLayout, currentLayout: layout)
        guard case .success(let committed) = result else { return result }
        // Cancellation may deliver a staged catalog. Revalidate after that idle
        // boundary before the single layout/persistence transaction.
        surface?.cancel()
        guard canApplyFolderAssignment, validateBinding(), provider.servedRevision == revision,
              currentPersistentLayout() == expectedLayout,
              !appManagementPreferences.isHidden(current), !provider.isHidden(current.id),
              provider.record(for: current.id)?.canonicalURL == current.canonicalURL else {
            return .rejected(.invalidTarget)
        }
        closeFolder()
        guard commitWorkspaceLayout(committed) else { return .cancelled }
        return .success(committed)
    }

    @MainActor
    private func showFolderAssignmentError(_ result: LayoutMutationResult) {
        guard let window, window.attachedSheet == nil, let strings = languageStrings,
              let alert = LauncherNoticePresentation.assignmentError(result, strings: strings) else { return }
        presentApplicationSheet(alert, for: window)
    }

    @MainActor
    private func showAppAliasEditor(_ record: AppRecord, additionalValidation: @escaping () -> Bool = { true }) {
        guard !didRunFinalTeardown, let window, window.attachedSheet == nil,
              let assembly, let revision = assembly.provider.servedRevision, let strings = languageStrings else { return }
        let (alert, field) = LauncherNoticePresentation.aliasEditor(
            strings: strings, alias: appManagementPreferences.alias(for: record) ?? "")
        let coordinator = appManagementCoordinator
        presentApplicationSheet(alert, for: window) { [weak self, weak coordinator, weak assembly] response in
            guard response == .alertFirstButtonReturn, additionalValidation(), let self, let coordinator, let assembly,
                  self.assembly === assembly, self.appManagementCoordinator === coordinator,
                  assembly.provider.servedRevision == revision,
                  let current = assembly.provider.record(for: record.id),
                  current.canonicalURL == record.canonicalURL,
                  !assembly.provider.isHidden(current.id),
                  !self.appManagementPreferences.isHidden(current) else { return }
            self.showAppManagementError(self.setAppAlias(field.stringValue, for: record))
        }
    }

    @MainActor
    private func showAppManagementError(_ result: AppManagementSaveResult) {
        guard let window, window.attachedSheet == nil, let strings = languageStrings,
              let alert = LauncherNoticePresentation.managementError(result, strings: strings) else { return }
        presentApplicationSheet(alert, for: window)
    }

    /// Acquire before presenting and release on every completion, including Cancel/errors.
    /// An obsolete namespace/teardown may release its old owner but cannot apply edits.
    @MainActor
    func presentApplicationSheet(_ alert: NSAlert, for window: NSWindow,
                                         completion: @escaping (NSApplication.ModalResponse) -> Void = { _ in }) {
        guard !didRunFinalTeardown, self.window === window, window.attachedSheet == nil else { return }
        let root = window.contentView
        let owner = languagePresentationController
        let lease = owner?.acquire(.modal)
        let epoch = languageGeneration
        let gate = ApplicationSheetCompletionGate()
        applicationSheetPresenter(alert, window) { [weak self] response in
            MainActor.assumeIsolated {
                guard gate.claim() else { return }
                defer {
                    if let lease { owner?.release(lease) }
                    self?.scheduleLanguageReadinessRetry()
                }
                guard let self, !self.didRunFinalTeardown, self.languageGeneration == epoch,
                      self.window === window, window.contentView === root else { return }
                completion(response)
            }
        }
    }

    /// 启动器主面板右上角小齿轮：打开激活设置（单实例）。
    @MainActor
    func installLauncherSettingsButton(in container: NSView) {
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
        let config = NSImage.SymbolConfiguration(pointSize: 16, weight: .medium)
        button.image = NSImage(systemSymbolName: "gearshape", accessibilityDescription: languageStrings?.settingsText(.settingsButtonAccessibility) ?? "设置")?
            .withSymbolConfiguration(config)
        button.image?.isTemplate = true
        button.contentTintColor = .white
        button.setAccessibilityLabel(languageStrings?.settingsText(.settingsButtonAccessibility) ?? "设置")
        button.setAccessibilityRole(.button)
        button.toolTip = languageStrings?.settingsText(.settingsButtonAccessibility) ?? "设置"
        // 供空白点击判定识别：命中此按钮时必须放行，不能当空白隐藏。
        button.identifier = NSUserInterfaceItemIdentifier("launchcopy.launcherSettingsButton")
        button.target = self
        button.action = #selector(openActivationSettingsFromLauncher(_:))
        // 非 flipped：贴右上角。
        button.autoresizingMask = [.minXMargin, .minYMargin]
        container.addSubview(button)
        self.launcherSettingsButton = button
        refreshLauncherChromeMaterial(policy: effectiveMaterialPolicy)
    }

    /// Material changes update only this control's layer, never catalog/cell bindings.
    @MainActor
    func refreshLauncherChromeMaterial(policy: LaunchcopyMaterialPolicy) {
        actionFeedbackView?.applyMaterialPolicy(reduceTransparency: policy.reduceTransparency,
                                               increaseContrast: policy.increaseContrast)
        catalogStatusView?.applyMaterialPolicy(reduceTransparency: policy.reduceTransparency,
                                              increaseContrast: policy.increaseContrast)
        pageDotsView?.applyMaterialPolicy(reduceTransparency: policy.reduceTransparency,
                                         increaseContrast: policy.increaseContrast)
        guard !didRunFinalTeardown, let layer = launcherSettingsButton?.layer else { return }
        layer.backgroundColor = LaunchcopyVisualTokens.chromeFill(policy: policy).cgColor
        layer.isOpaque = policy.prefersOpaqueChrome
        layer.borderWidth = policy.emphasizesBorders ? 2 : 0
        layer.borderColor = (policy.emphasizesBorders ? NSColor.white : NSColor.clear).cgColor
    }

    @MainActor
    func installPageDots(in host: NSView) {
        guard let surface, !surface.isTearingDown, !didRunFinalTeardown else { return }
        pageDotsView?.teardown()
        pageDotsView?.removeFromSuperview()
        let dots = PageDotsView(frame: .zero)
        if let languageStrings { dots.relabel(strings: languageStrings) }
        dots.onRequestPage = { [weak self] page in _ = self?.requestPageFromDots(page) }
        host.addSubview(dots); pageDotsView = dots
        dots.applyMaterialPolicy(reduceTransparency: effectiveMaterialPolicy.reduceTransparency,
                                 increaseContrast: effectiveMaterialPolicy.increaseContrast)
        keyboardController?.isPointerPageNavigationActive = { [weak surface] in surface?.isDirectNavigationActive ?? false }
        // Separate seam is not overwritten by telemetry's appEvents installation.
        surface.onPageNavigationChange = { [weak self] in self?.refreshPageDots() }
        layoutPageDots(); refreshPageDots()
    }

    @MainActor
    private var pageNavigationLifecycleIsReady: Bool {
        if let check = pageNavigationLifecycleCheck { return check() }
        return window?.isVisible == true && window?.isKeyWindow == true && NSApp.isActive
    }

    @MainActor
    private var pageNavigationInputIsFree: Bool {
        !didRunFinalTeardown && !isTitleEditing && folderRenameContext == nil
            && leadingLibraryNavigator?.isTransitioning != true
            && appLibraryOwner?.isOpen != true
            && folderOpenState?.isOpen != true && dragCoordinator?.isSessionActive != true
            && mainGridIsReadable && pageNavigationLifecycleIsReady
    }

    @MainActor
    @discardableResult
    func requestPageFromDots(_ page: Int) -> Bool {
        guard pageNavigationInputIsFree, let surface, surface.canRequestPage(page) else { return false }
        if let assembly, assembly.provider.servedPageCount != surface.core.pageCount { return false }
        // Clear before forwarding: Reduce Motion can synchronously commit/idle.
        keyboardController?.clearFocusForPointerNavigation()
        pendingLibraryGridFocus = nil
        let accepted = surface.requestPage(page)
        refreshPageDots()
        return accepted
    }

    @MainActor
    func refreshPageDots() {
        appLibraryOwner?.refreshReadiness()
        if appLibraryOwner?.isOpen == true || !mainGridIsReadable { pageDotsView?.isHidden = true; return }
        schedulePendingAppearancePresentation()
        guard let surface, let pageDotsView, !didRunFinalTeardown else { return }
        let free = pageNavigationInputIsFree
            && (surface.core.state == .idle || surface.core.state == .settling)
        let count = assembly.map { $0.provider.servedPageCount ?? 0 } ?? surface.core.pageCount
        pageDotsView.update(pageCount: count, committedPage: surface.core.committedPage,
                            isEnabled: free && count == surface.core.pageCount)
    }

    @MainActor
    private func layoutPageDots() {
        guard let dots = pageDotsView, let host = dots.superview else { return }
        let width = min(320, max(0, host.bounds.width - 32))
        // Respect the existing grid's bottom gutter without changing its spacing.
        let geometry = MainGridLayoutMetrics.geometry(bounds: host.bounds,
            itemCount: mainGridCapacity.itemsPerPage, mode: .ordinary,
            capacity: mainGridCapacity, appearance: appearancePreferences.mainItemAppearance)
        let gutter = max(0, (geometry.frame(for: mainGridCapacity.itemsPerPage - 1,
            itemCount: mainGridCapacity.itemsPerPage)?.minY ?? host.bounds.minY) - host.bounds.minY)
        let height = min(32, gutter)
        let inset = min(20, max(0, (gutter - height) / 2))
        dots.frame = NSRect(x: host.bounds.midX - width / 2, y: host.bounds.minY + inset,
                            width: width, height: height)
    }

    @MainActor
    private func refreshWallpaperBackdrop(for window: NSWindow) {
        wallpaperBackdrop?.layoutToHost()
        wallpaperBackdrop?.refresh(for: window.screen ?? NSScreen.main, policy: effectiveMaterialPolicy,
                                   blurRadius: Double(appearancePreferences.wallpaperBlurRadius))
    }

    /// Only a successfully resolved test profile exposes path-free diagnostic state.
    /// Production windows keep their accessibility help unchanged.
    @MainActor
    func installIsolatedWallpaperDiagnostics(backdrop: WallpaperBackdropController, window: NSWindow) {
        guard uiTestProfile != nil else { return }
        let update: (WallpaperBackdropController.Diagnostic) -> Void = { [weak window] diagnostic in
            window?.setAccessibilityHelp(diagnostic.summary)
        }
        backdrop.onDiagnosticChange = update
        update(backdrop.diagnostic)
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

    /// Admission is sampled throughout the contact session, then rechecked at
    /// dispatch. A focused empty search is idle; any actual text draft is not.
    @MainActor
    var fourFingerOutwardHideIsReady: Bool {
        guard let window, window.isVisible, let surface, !surface.isTearingDown,
              !didRunFinalTeardown, !isRestoringLayout, !isApplyingAppearance,
              !isApplyingMainGridCapacity, !workspaceQuit.isPending, !isQuitSaveModalRunning,
              !workspaceNeedsSave, workspacePersistence.pendingCount == 0,
              activationSettingsCoordinator?.isSettingsVisible != true,
              appRemovalCoordinator?.requiresQuitProtection != true,
              liveAppearanceCoordinator?.requiresQuitProtection != true,
              mainGridCapacityCoordinator?.requiresQuitProtection != true,
              appLibraryOwner?.preferences.requiresQuitProtection != true,
              appLibraryOwner?.activity?.requiresQuitProtection != true,
              !isTitleEditing, folderTitleEditor == nil, folderRenameContext == nil,
              search?.field.stringValue.isEmpty != false,
              folderOpenState?.isOpen != true, folderEntranceAppearanceGeneration == nil,
              folderExitVisual == nil, folderOverlay?.isTrackpadPagingActive != true,
              folderOverlay?.isMoveOutPresentationCollapsed != true,
              dragCoordinator?.isSessionActive != true,
              leadingLibraryNavigator?.isTransitioning != true,
              appLibraryOwner?.isPreviewing != true,
              window.attachedSheet == nil, NSApp?.modalWindow == nil,
              surface.pinnedPresentation == nil, !surface.isDirectNavigationActive,
              surface.core.state == .idle || surface.core.state == .cancelled else { return false }
        if appLibraryOwner?.isOpen == true, appLibraryOwner?.hasSettledPresentation != true { return false }
        if appLibraryOwner?.isOpen == true,
           appLibraryOwner?.view?.searchField.stringValue.isEmpty != true { return false }
        if let editor = window.firstResponder as? NSTextView {
            guard !editor.hasMarkedText(), editor.string.isEmpty else { return false }
            let isEmptySearch = search?.field.currentEditor() === editor
                || appLibraryOwner?.view?.searchField.currentEditor() === editor
            guard isEmptySearch else { return false }
        }
        return true
    }

    /// ADR-011 Q7：hide 前取消 drag/title/folder/search 瞬态（不 teardown 服务）。
    @MainActor
    func prepareTransientCancellationForHide() {
        leadingLibraryNavigator?.cancel()
        actionFeedbackView?.clear()
        defer { schedulePendingAppearancePresentation() }
        surface?.cancelDirectNavigation()
        appLibraryOwner?.hide()
        pendingLibraryGridFocus = nil
        refreshPageDots()
        cancelPendingWorkspaceQuit()
        finishFolderTitleEditing(returnFocus: false)
        cancelFolderVisualTransition()
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

    @MainActor
    func launcherDidHideHandler() -> () -> Void {
        { [weak self] in
            guard let self else { return }
            self.cancelUnacceptedAppRemoval()
            self.actionFeedbackView?.clear()
            self.leadingLibraryNavigator?.cancel()
            self.appLibraryOwner?.hide()
            self.pendingLibraryGridFocus = nil
            self.surface?.cancelDirectNavigation()
            self.refreshPageDots()
            // Also covers sleep/session suspension, which may bypass normal hide preparation.
            self.cancelPendingWorkspaceQuit()
            self.cancelFolderVisualTransition()
            self.activationSettingsCoordinator?.hideSettings()
            self.schedulePendingAppearancePresentation()
        }
    }

    @MainActor
    private func cancelPendingWorkspaceQuit(replyCancellation: Bool = true) {
        let alert = quitSaveAlert
        quitSaveAlert = nil
        // Invalidate choice callbacks BEFORE closing a sheet/nested modal loop.
        workspaceQuit.cancelPending(replyCancellation: replyCancellation)
        if let alert, let parent = alert.window.sheetParent {
            parent.endSheet(alert.window, returnCode: .cancel)
        } else if alert != nil, isQuitSaveModalRunning {
            NSApp.abortModal()
        }
    }

    // MARK: - Status item host（T-1G-C / T-1G-E）

    /// 安装菜单栏入口：命令转发到同一 `LauncherWindowController`；Quit → composition；失败不崩溃。
    @MainActor
    private func installStatusItem(launcher: LauncherWindowController) {
        let showStatusItem: Bool
        if options.gestureValidation || options.integratedPreview { showStatusItem = true }
        else if let store = activationPreferencesStore {
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
            onCommand: statusItemCommandHandler(for: launcher),
            onActivationSettings: { [weak self] in
                self?.activationSettingsCoordinator?.showSettings()
            }
        )
        // Only applicationWillTerminate advances final launcher/service teardown,
        // after the asynchronous save barrier and any explicit failure decision.
        if let languageStrings { controller.relabel(strings: languageStrings) }
        controller.install(showStatusItem: showStatusItem)
        self.statusItemController = controller
        if controller.installFailed {
            print("paging-status-item: install failed (degraded; Dock reopen / other entries remain)")
            fflush(stdout)
        }
    }

    /// The installed menu and detached tests use exactly the same command routing.
    @MainActor
    func statusItemCommandHandler(for launcher: LauncherWindowController)
        -> (LauncherCommand, LauncherActivationSource, ScreenID) -> Void {
        { [weak self, weak launcher] command, source, screen in
            guard let launcher, command != .quit else { return }
            // Quit is a process request, not an irreversible presentation effect.
            // StatusItemController next invokes NSApp.terminate and the save gate.
            if command == .hide { self?.prepareTransientCancellationForHide() }
            _ = launcher.handle(command, source: source, targetScreen: screen)
            self?.activationComposition?.hotCornerMonitor.setLauncherVisible(launcher.coordinator.committedVisibility)
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
            guard appLibraryOwner?.isOpen != true else { return }
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

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        MainActor.assumeIsolated {
            requestWorkspaceQuit(reply: { sender.reply(toApplicationShouldTerminate: $0) },
                chooseOnFailure: { [weak self] result, completion in
                    self?.presentQuitSaveFailure(result, completion: completion)
                })
        }
    }

    /// Tests inject replies/decisions without ever asking NSApp to stop a process.
    @MainActor
    func requestWorkspaceQuit(enqueueWait: Duration = .seconds(2), flushWait: Duration = .seconds(2),
                              reply: @escaping (Bool) -> Void,
                              chooseOnFailure: @escaping (LayoutStoreFlushResult, @escaping (Bool) -> Void) -> Void
    ) -> NSApplication.TerminateReply {
        if didRunFinalTeardown || workspaceQuit.phase == .approved { return .terminateNow }
        if workspaceQuit.isPending { return .terminateLater }
        appRemovalQuitFailure = false
        cancelUnacceptedAppRemoval()
        let hasWorkspaceWrites = workspaceNeedsSave || workspacePersistence.pendingCount > 0
        let library = appLibraryOwner
        let capacity = mainGridCapacityCoordinator
        let live = liveAppearanceCoordinator
        let activity = library?.activity
        let removal = appRemovalCoordinator
        _ = live?.flush() // Include a still-debounced edit before deciding fast termination.
        guard hasWorkspaceWrites || library?.preferences.requiresQuitProtection == true
            || capacity?.requiresQuitProtection == true
            || live?.requiresQuitProtection == true
            || activity?.requiresQuitProtection == true
            || removal?.requiresQuitProtection == true else { return .terminateNow }
        finishFolderTitleEditing(returnFocus: false)
        dragCoordinator?.cancel(reason: .escape)
        cancelFolderVisualTransition()
        let store = layoutStore, epoch = layoutRestoreGeneration
        workspaceQuit.request(drain: { [weak self] in
            guard let self else { return .failed }
            let result: LayoutStoreFlushResult
            if hasWorkspaceWrites, let store {
                result = await self.workspacePersistence.drain(to: store, epoch: epoch,
                    enqueueWait: enqueueWait, flushWait: flushWait) { [weak self] in
                        guard let self else { return false }
                        return !self.didRunFinalTeardown && self.layoutRestoreGeneration == epoch
                    }
                if !self.didRunFinalTeardown, self.layoutRestoreGeneration == epoch {
                    self.handleWorkspacePersistenceOutcome(result)
                }
            } else { result = hasWorkspaceWrites ? .failed : .nothingPending }
            // Always drain both accepted owners, even if the workspace failed.
            let libraryResult = await library?.preferences.drain(timeout: enqueueWait) ?? .nothingPending
            let capacityResult = await capacity?.drain(timeout: enqueueWait) ?? .nothingPending
            let activityResult = await activity?.drain(timeout: enqueueWait) ?? .nothingPending
            let removalResult = await removal?.drain(timeout: enqueueWait) ?? .nothingPending
            let appearanceResult: LayoutStoreFlushResult = live?.requiresQuitProtection == true ? .failed : .nothingPending
            guard !self.didRunFinalTeardown, self.layoutRestoreGeneration == epoch,
                  self.appLibraryOwner === library,
                  self.mainGridCapacityCoordinator === capacity,
                  self.liveAppearanceCoordinator === live,
                  self.appLibraryOwner?.activity === activity,
                  self.appRemovalCoordinator === removal else { return .staleRejected }
            switch removalResult {
            case .persisted, .nothingPending: break
            default:
                self.appRemovalQuitFailure = true
                return removalResult
            }
            switch result {
            case .persisted, .nothingPending:
                switch libraryResult {
                case .persisted, .nothingPending:
                    switch capacityResult {
                    case .persisted, .nothingPending:
                        switch activityResult {
                        case .persisted, .nothingPending: return appearanceResult
                        default: return activityResult
                        }
                    default: return capacityResult
                    }
                default: return libraryResult
                }
            default: return result
            }
        }, chooseOnFailure: chooseOnFailure, reply: reply)
        return .terminateLater
    }

    @MainActor
    private func presentQuitSaveFailure(_ result: LayoutStoreFlushResult,
                                       completion: @escaping (Bool) -> Void) {
        let alert = Self.makeQuitSaveFailureAlert(strings: languageStrings)
        if appRemovalQuitFailure, let strings = languageStrings {
            alert.messageText = strings.removalText(.quitTitle)
            alert.informativeText = strings.removalText(.quitMessage)
        }
        quitSaveAlert = alert
        let owner = languagePresentationController
        let lease = owner?.acquire(.quit)
        let gate = ApplicationSheetCompletionGate()
        let finish: (NSApplication.ModalResponse) -> Void = { [weak self, weak alert] response in
            guard gate.claim() else { return }
            defer {
                if let lease { owner?.release(lease) }
                self?.scheduleLanguageReadinessRetry()
            }
            if let self, self.quitSaveAlert === alert { self.quitSaveAlert = nil }
            completion(response == .alertSecondButtonReturn)
        }
        if let window, window.isVisible { alert.beginSheetModal(for: window, completionHandler: finish) }
        else {
            isQuitSaveModalRunning = true
            let response = alert.runModal()
            isQuitSaveModalRunning = false
            finish(response)
        }
    }

    @MainActor
    static func makeQuitSaveFailureAlert(strings: LocalizedStrings? = nil) -> NSAlert {
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = "排列尚未保存"
        alert.informativeText = "保存失败或超时。取消退出可保留当前内存中的改动；仍然退出可能丢失尚未保存的排列。"
        let cancel = alert.addButton(withTitle: "取消退出")
        cancel.keyEquivalent = "\r"
        alert.addButton(withTitle: "仍然退出").keyEquivalent = ""
        alert.window.defaultButtonCell = cancel.cell as? NSButtonCell
        if let strings {
            alert.messageText = strings.noticeText(.quitSaveTitle)
            alert.informativeText = strings.noticeText(.quitSaveMessage)
            alert.buttons[0].title = strings.noticeText(.cancelQuit)
            alert.buttons[1].title = strings.noticeText(.quitAnyway)
        }
        return alert
    }

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
    func windowDidBecomeKey(_ notification: Notification) { refreshPageDots() }

    func applicationDidBecomeActive(_ notification: Notification) { refreshPageDots() }

    func windowDidResignKey(_ notification: Notification) {
        leadingLibraryNavigator?.cancel()
        folderOverlay?.cancelTrackpadPaging()
        defer { schedulePendingAppearancePresentation() }
        surface?.cancelDirectNavigation()
        refreshPageDots()
        dragCoordinator?.cancel(reason: .windowResign)
    }

    func windowDidResize(_ notification: Notification) {
        leadingLibraryNavigator?.cancel()
        defer { schedulePendingAppearancePresentation() }
        surface?.cancelDirectNavigation()
        dragCoordinator?.cancel(reason: .layoutChanged)
        cancelFolderVisualTransition()
        layoutSearchField()
        refreshMainGridReadability()
        refreshFolderLayoutIfReady()
    }

    func windowDidChangeScreen(_ notification: Notification) {
        leadingLibraryNavigator?.cancel()
        defer { schedulePendingAppearancePresentation() }
        surface?.cancelDirectNavigation()
        finishFolderTitleEditing(returnFocus: false)
        cancelFolderVisualTransition()
        layoutSearchField()
        refreshMainGridReadability()
    }

    /// A pointer exit can coexist with a new top-level press. Escape cancels both
    /// immediately, rather than waiting for the visual completion or the next release.
    @MainActor
    func handleEscapeDuringDrag() -> Bool {
        defer { schedulePendingAppearancePresentation() }
        let hadExitVisual = folderExitVisual != nil
        if hadExitVisual {
            cancelFolderVisualTransition()
        }
        guard let coordinator = dragCoordinator, coordinator.isSessionActive else { return hadExitVisual }
        coordinator.cancel(reason: .escape)
        return true
    }

    /// Phase 1F：应用失活 → cancel 进行中的 drag（.windowResign 统一出口；idle 时 no-op）。
    func applicationDidResignActive(_ notification: Notification) {
        leadingLibraryNavigator?.cancel()
        folderOverlay?.cancelTrackpadPaging()
        defer { schedulePendingAppearancePresentation() }
        surface?.cancelDirectNavigation()
        refreshPageDots()
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
            libraryEntryProfileSession?.exportOnTermination()
            libraryEntryProfileSession = nil
        }
        teardownAll()
    }

    private func teardownAll() {
        guard !didRunFinalTeardown else { return }
        MainActor.assumeIsolated {
            stopFolderDropTiming()
            PointerInputDiagnostics.setEnabled(false)
            cancelUnacceptedAppRemoval()
            liveAppearanceCoordinator?.invalidate()
            liveAppearanceCoordinator = nil
        }
        didRunFinalTeardown = true
        // T-1G-E：先停激活服务（shortcut/hot-corner/four-finger/session），再拆 UI。
        MainActor.assumeIsolated {
            teardownActionFeedback()
            appRemovalCoordinator?.teardown()
            appRemovalCoordinator = nil
            leadingLibraryNavigator?.teardown()
            leadingLibraryNavigator = nil
            appLibraryOwner?.teardown()
            appLibraryOwner = nil
            pendingLibraryGridFocus = nil
            teardownCatalogStatus()
            teardownLanguagePresentation()
            mainGridCapacityCoordinator?.invalidate()
            mainGridCapacityLoadTask?.cancel()
            mainGridCapacityLoadTask = nil
            pendingMainGridCapacity = nil
            configuredMainGridCapacityView = nil
            mainGridSpaceNotice?.removeFromSuperview()
            mainGridSpaceNotice = nil
            pendingAppearancePreferences = nil
            appearanceRetryScheduled = false
            pendingIdentifierSearchEnabled = nil
            identifierSearchRetryScheduled = false
            appManagementGeneration &+= 1
            identifierSearchSettingsView?.onSetSearchByBundleIdentifier = nil
            identifierSearchSettingsView?.identifierSearchPendingProvider = nil
            identifierSearchSettingsView = nil
            pageDotsView?.teardown()
            pageDotsView?.onRequestPage = nil
            pageDotsView?.removeFromSuperview()
            pageDotsView = nil
            appSourcesCoordinator?.teardown()
            appSourcesCoordinator = nil
            activationSettingsCoordinator?.hideSettings()
            cancelPendingWorkspaceQuit(replyCancellation: false)
            finishFolderTitleEditing(returnFocus: false)
            layoutRestoreTask?.cancel()
            layoutRestoreTask = nil
            isRestoringLayout = false
            cancelFolderVisualTransition()
            fourFingerDiagnostics?.stop()
            fourFingerDiagnostics = nil
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
        self.workspaceSaveNotice = nil
        self.wallpaperBackdrop = nil
        if let motionObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(motionObserver)
            self.motionObserver = nil
        }
        // T-1F-B10-regression-fix §2.1 取证（E6a''）：移除分发入口 local monitor（幂等）。
        if let clickMonitor {
            NSEvent.removeMonitor(clickMonitor)
            self.clickMonitor = nil
        }
    }
}

private final class FolderExitVisualState {
    let folderID: FolderID
    let overlay: FolderOverlayView
    /// Source glyph in the retained overlay's local coordinate space.
    let sourceFrame: NSRect?
    let reduceMotion: Bool
    let initialOpacity: Float
    let initialTransform: CGAffineTransform

    init(folderID: FolderID,
         overlay: FolderOverlayView,
         sourceFrame: NSRect?,
         reduceMotion: Bool,
         initialOpacity: Float,
         initialTransform: CGAffineTransform) {
        self.folderID = folderID
        self.overlay = overlay
        self.sourceFrame = sourceFrame
        self.reduceMotion = reduceMotion
        self.initialOpacity = initialOpacity
        self.initialTransform = initialTransform
    }
}

// MARK: - Main-grid capacity composition (independent of folder layout)

extension AppDelegate {
    @MainActor
    func installMainGridCapacityPreferences(store injected: (any MainGridCapacityPersisting)? = nil) {
        guard !didRunFinalTeardown,
              mainGridCapacityCoordinator?.requiresQuitProtection != true else { return }
        cancelPendingWorkspaceQuit()
        mainGridCapacityCoordinator?.invalidate()
        mainGridCapacityLoadTask?.cancel()
        let store: any MainGridCapacityPersisting
        if let injected { store = injected }
        else if options.uiTestProfile != nil && uiTestProfile == nil {
            store = UnavailableMainGridCapacityStore()
        } else if let root = uiTestProfile?.rootURL
            ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first?
                .appendingPathComponent("Launchcopy", isDirectory: true) {
            store = FileMainGridCapacityStore(directory: root.appendingPathComponent("MainGridCapacity", isDirectory: true))
        } else { store = UnavailableMainGridCapacityStore() }
        let owner = MainGridCapacityCoordinator(store: store)
        mainGridCapacityCoordinator = owner
        mainGridCapacityRetryScheduled = false
        owner.onChange = { [weak self, weak owner] in
            guard let self, let owner, !self.didRunFinalTeardown,
                  self.mainGridCapacityCoordinator === owner else { return }
            if owner.isLoaded, owner.pendingCount == 0 {
                let desired = owner.latestSaveResult == nil ? owner.committed : owner.requestedCapacity
                self.pendingMainGridCapacity = desired == self.mainGridCapacity ? nil : desired
                self.schedulePendingMainGridCapacityPresentation()
            }
            self.refreshMainGridCapacitySettingsStatus()
        }
        mainGridCapacityLoadTask = Task { [weak self, weak owner] in
            await owner?.loadIfNeeded()
            guard let self, let owner, !self.didRunFinalTeardown,
                  self.mainGridCapacityCoordinator === owner else { return }
            if let view = self.configuredMainGridCapacityView {
                self.configureMainGridCapacitySettings(view)
            }
        }
    }

    @MainActor
    func configureMainGridCapacitySettings(_ view: MainGridCapacitySettingsView) {
        configuredMainGridCapacityView = view
        guard let owner = mainGridCapacityCoordinator, owner.isLoaded else {
            view.reload(capacity: mainGridCapacity, loadResult: .unavailable)
            view.onApply = nil
            return
        }
        view.reload(capacity: owner.requestedCapacity, loadResult: owner.loadResult)
        view.onDiscardDraft = { [weak self, weak owner, weak view] in
            guard let self, let owner, let view, !self.didRunFinalTeardown,
                  self.mainGridCapacityCoordinator === owner,
                  self.configuredMainGridCapacityView === view else { return }
            self.refreshMainGridCapacitySettingsStatus()
            self.schedulePendingMainGridCapacityPresentation()
        }
        view.onApply = { [weak self, weak owner, weak view] draft in
            guard let self, let owner, let view, !self.didRunFinalTeardown,
                  !self.workspaceQuit.isPending, self.mainGridCapacityCoordinator === owner,
                  self.configuredMainGridCapacityView === view else { return false }
            let recovering = view.isExplicitRecoveryRequest
                && (owner.loadResult == .corrupt || owner.latestSaveResult == .recoveryRequired)
            let admitted = owner.submit(draft, recoveringCorruptPayload: recovering)
            if admitted {
                self.pendingMainGridCapacity = draft == self.mainGridCapacity ? nil : draft
                self.schedulePendingMainGridCapacityPresentation()
            }
            return admitted
        }
        refreshMainGridCapacitySettingsStatus()
    }

    @MainActor
    private func refreshMainGridCapacitySettingsStatus() {
        guard let owner = mainGridCapacityCoordinator, !didRunFinalTeardown else { return }
        configuredMainGridCapacityView?.updateStatus(pendingCount: owner.pendingCount,
            saveResult: owner.latestSaveResult,
            presentation: pendingMainGridCapacity == nil ? .applied : .queued)
    }

    @MainActor
    private var mainGridCapacityPresentationIsReady: Bool {
        guard languagePresentationIsReady, !isApplyingMainGridCapacity,
              !isApplyingAppearance, !isApplyingIdentifierSearch,
              appLibraryOwner?.isOpen != true, folderOpenState?.isOpen != true,
              search?.field.currentEditor() == nil,
              identifierSearchSettingsView?.aliasField.currentEditor() == nil,
              languagePresentationController?.hasInteractionOwners != true,
              mainGridCapacityReadinessCheck?() != false,
              let surface, assembly != nil else { return false }
        return !surface.isTearingDown && surface.pinnedPresentation == nil
            && !surface.isDirectNavigationActive
            && (surface.core.state == .idle || surface.core.state == .cancelled)
    }

    @MainActor
    private func schedulePendingMainGridCapacityPresentation() {
        guard !didRunFinalTeardown, pendingMainGridCapacity != nil,
              !mainGridCapacityRetryScheduled else { return }
        mainGridCapacityRetryScheduled = true
        let owner = mainGridCapacityCoordinator
        DispatchQueue.main.async { [weak self, weak owner] in
            guard let self, !self.didRunFinalTeardown,
                  self.mainGridCapacityCoordinator === owner else { return }
            self.mainGridCapacityRetryScheduled = false
            self.flushPendingMainGridCapacityIfReady()
        }
    }

    /// One idle transaction updates all capacity copies, then uses the existing
    /// direct-page spring. It never invents a catalog revision or changes physics.
    @MainActor
    func flushPendingMainGridCapacityIfReady() {
        guard mainGridCapacityPresentationIsReady, let capacity = pendingMainGridCapacity,
              let assembly, let surface else { return }
        let entries = assembly.provider.presentationEntries.map { entry -> TopLevelEntryIdentity in
            switch entry {
            case .app(let record): return .app(record.id)
            case .folder(let folder): return .folder(folder.id)
            }
        }
        let focus = keyboardController?.focusModel.current
        let selected: TopLevelEntryIdentity?
        if let focus, focus.catalogRevision == assembly.provider.servedRevision,
           focus.pageIndex == surface.core.committedPage, let identity = focus.entryIdentity,
           let index = entries.firstIndex(of: identity),
           index / mainGridCapacity.itemsPerPage == focus.pageIndex,
           index % mainGridCapacity.itemsPerPage == focus.slotIndex {
            selected = identity
        } else { selected = nil }
        let relocation = MainGridCapacityAnchorRelocation.relocate(previousEntries: entries,
            currentEntries: entries, currentPageIndex: surface.core.committedPage,
            selectedIdentity: selected, from: mainGridCapacity, to: capacity)
        isApplyingMainGridCapacity = true
        pendingMainGridCapacity = nil
        mainGridLayoutEpoch &+= 1
        mainGridCapacity = capacity
        // No suspension or external acceptance callback inside this boundary.
        assembly.provider.itemsPerPage = capacity.itemsPerPage
        assembly.refreshController.itemsPerPage = capacity.itemsPerPage
        assembly.searchPresentation.itemsPerPage = capacity.itemsPerPage
        assembly.renderer.gridCapacity = capacity
        surface.itemsPerPage = capacity.itemsPerPage
        surface.reloadCurrentPresentation()
        // Page-count reconciliation preserves the Core's soft edge behavior.
        // At this admitted idle boundary a clamped page can therefore retain
        // a fractional overscroll. Normalize through the existing lifecycle
        // operation before issuing the independently chosen anchor navigation.
        if surface.presentedOffset != Double(surface.core.committedPage) {
            surface.cancel()
        }
        // Revoke old user input before creating our owned relocation. Otherwise
        // a true→false mask transition cancels the spring we just requested.
        refreshMainGridReadability()
        if let catalog = assembly.provider.servedSnapshot {
            let layout = AppGridFocusLayout.build(from: catalog,
                composition: assembly.provider.presentationEntries, itemsPerPage: capacity.itemsPerPage)
            keyboardController?.reconfigureGrid(capacity: capacity, layout: layout,
                                                selectedIdentity: relocation.selectedIdentity)
        }
        // Invalidates retained old menu actions even when catalog revision matches.
        installAppContextMenu(assembly: assembly)
        if relocation.pageIndex != surface.core.committedPage {
            _ = surface.requestPage(relocation.pageIndex)
        }
        isApplyingMainGridCapacity = false
        layoutPageDots()
        layoutCatalogStatus()
        refreshPageDots()
        refreshMainGridCapacitySettingsStatus()
    }

    @MainActor
    private func installMainGridSpaceNotice(in host: NSView) {
        let notice = NSTextField(wrappingLabelWithString: "")
        notice.identifier = NSUserInterfaceItemIdentifier("launchcopy.mainGrid.insufficientSpace")
        notice.alignment = .center
        notice.textColor = .labelColor
        notice.font = .systemFont(ofSize: 15)
        notice.isHidden = true
        host.addSubview(notice)
        mainGridSpaceNotice = notice
        refreshMainGridReadability()
    }

    @MainActor
    func refreshMainGridReadability() {
        guard !didRunFinalTeardown else { return }
        configuredAppearanceSettingsView?.refreshMainIconFit()
        guard let surface, assembly != nil else { return }
        let readable = MainGridReadability.isReadable(bounds: surface.bounds, capacity: mainGridCapacity,
            appearance: appearancePreferences.mainItemAppearance, showsLabels: appearancePreferences.showsAppLabels)
        let wasReadable = mainGridIsReadable
        mainGridIsReadable = readable
        if wasReadable && !readable {
            surface.cancel()
            dragCoordinator?.cancel(reason: .layoutChanged)
        }
        applyMainGridVisibility()
        keyboardController?.refreshGridInputAvailability()
        refreshMainGridSpaceNotice()
        refreshPageDots()
    }

    @MainActor
    private func applyMainGridVisibility() {
        surface?.isHidden = (mainGridHiddenForLibrary && !mainGridPreviewForLibrary) || !mainGridIsReadable
        mainGridSpaceNotice?.isHidden = mainGridHiddenForLibrary || mainGridIsReadable
        if mainGridHiddenForLibrary || !mainGridIsReadable { pageDotsView?.isHidden = true }
        applyCatalogStatusVisibility()
    }

    @MainActor
    private func mainGridMenuBindingIsAvailable(_ cell: AppGridCellView) -> Bool {
        guard !cell.isHiddenOrHasHiddenAncestor else { return false }
        if let overlay = folderOverlay, cell.isDescendant(of: overlay) {
            guard let state = folderOpenState, state.isOpen,
                  !overlay.isVisualOnly, !overlay.isMoveOutPresentationCollapsed,
                  folderEntranceAppearanceGeneration == nil, folderExitVisual == nil,
                  overlay.currentEntry?.id == state.openFolderID,
                  let id = cell.bindingToken?.appID as? AppID else { return false }
            return state.openEntry?.members.contains(id) == true
        }
        guard mainGridIsReadable, folderOpenState?.isOpen != true,
              let surface, !surface.isTearingDown,
              cell.isDescendant(of: surface), let token = cell.bindingToken,
              token.pageIdentity.pageIndex == surface.core.committedPage,
              token.catalogRevision == assembly?.provider.servedRevision else { return false }
        return true
    }

    @MainActor
    private func refreshMainGridSpaceNotice() {
        guard let notice = mainGridSpaceNotice, let host = notice.superview else { return }
        let strings = languageStrings ?? LocalizedStrings(language: .english)
        let text = strings.mainGridCapacityText(.insufficientSpace)
        notice.stringValue = text
        notice.setAccessibilityLabel(text)
        let width = min(620, max(0, host.bounds.width - 64))
        notice.frame = CGRect(x: host.bounds.midX - width / 2, y: host.bounds.midY - 50,
                               width: width, height: 100)
    }
}

private struct UnavailableMainGridCapacityStore: MainGridCapacityPersisting {
    func load() async -> MainGridCapacityLoadResult { .unavailable }
    func save(_ capacity: MainGridCapacity, recoveringCorruptPayload: Bool) async -> MainGridCapacitySaveResult { .failed }
}
