// PagingPrototypeApp — KeyboardFocusController（Phase 1C §4.2 单一键盘代理）
// 实现：T-1C-B（Worker B）。
//
// 本地 responder chain：单一键盘代理成为 first responder，keyDown/performKeyEquivalent 分发。
// - 方向键路由到焦点模型（AppGridFocusModel/Navigator/Layout）；
// - 边界跨页经 KeyboardPageTurner（合成手势 seam，仅 idle 时翻页）；
// - 焦点视觉增量应用（unhighlight 旧 / highlight 新，经 AppGridCellFocus.setFocused）；
// - 未支持按键 fall through 到 AppKit responder chain；
// - 无全局 NSEvent monitor、无 Accessibility 权限、无同步 I/O、不每按键重建 view tree。
// - onActivate 回调供 T-1C-C 接键盘启动。
// - reconcileSettledCrossPage(committedPage:) —— F1（T-1C-C repair）：键盘跨页 settle
//   完成/中断后由集成层（AppDelegate onIdleBoundary）把焦点调和到 committed/displayed 页，
//   避免旧页/未显示页映射残留；复用既有 applyFocusVisual + currentLayout，不触碰 PagingCore。
//
// 隐私：不记录 app 名 / bundle ID / 路径 / URL / 图标数据 / 用户输入。

import AppCatalogCore
import AppGridUI
import AppKit
import PagingUI

@MainActor
public final class KeyboardFocusController: NSView {

    /// 激活回调（T-1C-C 接启动；携带当前焦点身份）。
    public var onActivate: ((AppGridFocusIdentity) -> Void)?

    /// T-1D-D：Command-F 搜索快捷键回调（装配层接到后进入搜索；responder 转移 seam）。
    public var onSearchShortcut: (() -> Void)?

    /// Supplied by the owner from Surface direct-navigation state; nil means inactive.
    public var isPointerPageNavigationActive: (() -> Bool)?
    /// Does not affect the independent folder responder path or Escape/search.
    public var gridInputIsAvailable: (() -> Bool)?

    // MARK: - Folder 打开状态感知（T-1E-D；T-1E-E 接线）

    /// 当前文件夹打开状态提供者（T-1E-E 接线；nil = 无 folder 打开层）。
    public var folderOpenStateProvider: (() -> FolderOpenState?)?

    /// 打开文件夹回调（顶层 folder 激活；T-1E-E 接线到 FolderOpenState.open + overlay configure）。
    public var onOpenFolder: ((AppGridFocusIdentity) -> Void)?

    /// 关闭文件夹回调（ESC / Command-F；T-1E-E 接线到 FolderOpenState.close + overlay clear）。
    public var onCloseFolder: (() -> Void)?

    /// 成员激活回调（folder 打开时 Return/Enter 成员；T-1E-E 接线到 AppLaunchController）。
    public var onActivateMember: ((AppID) -> Void)?

    /// 内部分页回调（inner 跨页；T-1E-E 接线到 FolderOpenState.setInnerPage）。
    public var onInnerPageChange: ((Int) -> Void)?

    /// 打开层视图提供者（内部成员焦点视觉；T-1E-E 接线到 FolderOverlayView）。
    public var folderOverlayProvider: (() -> FolderOverlayView?)?

    /// 标题编辑请求回调（显式进入编辑；T-1E-E 接线到 FolderTitleEditor）。
    public var onTitleEditRequest: (() -> Void)?

    /// 标题提交回调（Enter 提交；T-1E-E 接线到 FolderTitleEditor）。
    public var onTitleCommit: ((String) -> Void)?

    /// 标题取消回调（Escape 取消；T-1E-E 接线到 FolderTitleEditor）。
    public var onTitleCancel: (() -> Void)?

    /// T-1G-E：ESC 在 title/folder/selection 优先级耗尽后的最终 seam（宿主 → hide launcher）。
    /// 不吞 Tab；仅在顶层且无网格选择时触发。
    public var onEscapeExhausted: (() -> Void)?

    /// 布局提供者（返回当前网格布局；缺省从 surface.contentProvider 的 servedSnapshot 构建）。
    public var layoutProvider: (() -> AppGridFocusLayout?)?

    /// cell 解析器（焦点身份 → cell；缺省经 surface.renderer 的 AppGridRenderer 解析）。
    public var cellResolver: ((AppGridFocusIdentity) -> AppGridCellView?)?

    /// 当前焦点模型（只读；T-1C-C 读取 current 做启动校验）。
    public private(set) var focusModel: AppGridFocusModel

    private weak var surface: PagingSurface?
    private var pageTurner: KeyboardPageTurner?
    private var navigator: AppGridFocusNavigator?
    private var columns: Int
    private var lastAppliedIdentity: AppGridFocusIdentity?
    /// F1（T-1C-C repair）→ T-1C-D（bug-1 修复）：进行中的键盘跨页 settle 完整目标身份（页+槽）。
    /// handleArrow 在一次被接受的键盘跨页后置位完整 target；settle 完成/中断（Core 回 idle）后
    /// 由集成层调用 reconcileSettledCrossPage(committedPage:) 把焦点调和到实际 committed/displayed 页。
    /// reconcile 保留 pending 指定的行感知落点（只要其仍落在 committed 页有效），消除 ← 跨页
    /// 被无条件钳制到页内首 cell 的回归。nil = 无进行中的键盘跨页 settle（调和为 no-op）。
    private var pendingCrossPageSettleTarget: AppGridFocusIdentity?
    /// T-1C-D：延迟焦点。进入后不显示焦点框（current == nil）；按任意方向键才播种到
    /// 当前 committed 页首行首格并显示。ESC 退出键盘选择后重新置 true。
    private var isDeferredSelection = true

    /// T-1E-D：打开 folder 的顶层条目身份（关闭后恢复焦点用；nil = 无打开 folder）。
    private var openedFolderIdentity: TopLevelEntryIdentity?
    /// Opening preserves the accepted first-arrow movement from index zero without selection.
    private var innerNavigationSeedIndex: Int? = 0
    /// Real selection is an identity, so a capacity change never reinterprets an old slot.
    private var innerSelectedMember: AppID?
    /// T-1E-D：标题编辑模式（编辑中 → ESC 取消、箭头/Return 不启动 app）。
    private var isEditingTitle = false

    public init(columns: Int = 5) {
        precondition(columns > 0, "columns 必须 > 0")
        self.columns = columns
        self.focusModel = AppGridFocusModel()
        super.init(frame: .zero)
        self.wantsLayer = true
    }

    @available(*, unavailable)
    public required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    // MARK: - 安装

    /// 安装到 surface：成为其子视图（进入 responder chain），持有焦点模型与跨页 seam。
    public func install(on surface: PagingSurface, focusModel: AppGridFocusModel) {
        self.surface = surface
        self.focusModel = focusModel
        self.pageTurner = KeyboardPageTurner(surface: surface)
        self.navigator = AppGridFocusNavigator(columns: columns)
        surface.addSubview(self)
        self.frame = surface.bounds
        self.autoresizingMask = [.width, .height]
        // T-1C-D（延迟焦点）：进入后**不**自动播种初始焦点（current 保持 nil，无焦点框）。
        // 按任意方向键才播种到当前 committed 页（见 handleArrow 的 deferred 分支）。
        // 调用方若显式预置 focusModel（测试），current 非 nil → 直接进入活动选择态。
        applyFocusVisual()
    }

    // MARK: - Responder

    public override var acceptsFirstResponder: Bool { true }

    public override func becomeFirstResponder() -> Bool { true }

    /// 不拦截鼠标/触控板命中（透明代理；不参与 hit-test）。
    public override func hitTest(_ point: NSPoint) -> NSView? { nil }

    public override func keyDown(with event: NSEvent) {
        if !isFolderOpen, gridInputIsAvailable?() == false,
           arrowDirection(for: event) != nil || isActivationKey(event) { return }
        if [UInt16(123), 124, 125, 126, 36, 76, 53].contains(event.keyCode) {
            folderOverlayProvider?()?.cancelTrackpadPaging()
        }
        // T-1E-D：ESC 优先级（编辑标题 → 取消；folder 打开 → 关闭；否则 → 清除网格选择）。
        if event.keyCode == KeyCodes.escape {
            handleEscape()
            return
        }
        // T-1E-D：标题编辑中箭头/Return 不启动 app（编辑器为 first responder，正常不达此处；防御）。
        if isEditingTitle {
            super.keyDown(with: event)
            return
        }
        if !isFolderOpen,
           arrowDirection(for: event) != nil || isActivationKey(event),
           isPointerPageNavigationActive?() == true {
            return
        }
        if let direction = arrowDirection(for: event) {
            // T-1E-D：folder 打开 → 内部成员导航；否则 → 顶层导航。
            if isFolderOpen {
                handleInnerArrow(direction)
            } else {
                handleArrow(direction)
            }
            return
        }
        if isActivationKey(event) {
            // T-1E-D：folder 打开 → 激活成员；否则 → 顶层激活分流（folder 打开 / app 启动）。
            if isFolderOpen {
                activateInnerMember()
                return
            }
            if let identity = focusModel.current {
                routeActivation(identity)
                return
            }
            // 无焦点 → fall through。
        }
        super.keyDown(with: event)
    }

    public override func performKeyEquivalent(with event: NSEvent) -> Bool {
        if !isFolderOpen, gridInputIsAvailable?() == false,
           arrowDirection(for: event) != nil || isActivationKey(event) { return true }
        if [UInt16(123), 124, 125, 126, 36, 76, 53].contains(event.keyCode) {
            folderOverlayProvider?()?.cancelTrackpadPaging()
        }
        // T-1E-D：Command-F → folder 打开先安全关闭再搜索；否则直接搜索。
        if isSearchShortcut(event) {
            handleCommandF()
            return true
        }
        if isEditingTitle {
            return false
        }
        if !isFolderOpen,
           arrowDirection(for: event) != nil || isActivationKey(event),
           isPointerPageNavigationActive?() == true {
            return true
        }
        if isActivationKey(event) {
            // T-1E-D：folder 打开 → 激活成员；否则 → 顶层激活分流。
            if isFolderOpen {
                activateInnerMember()
                return true
            }
            if let identity = focusModel.current {
                routeActivation(identity)
                return true
            }
        }
        return false
    }

    // MARK: - 焦点视觉

    /// 重新应用焦点视觉（settle 完成 / 布局变化后由集成层调用）。
    public func refreshFocusVisual() {
        applyFocusVisual()
    }

    /// T-1D-D：进入搜索时清除网格焦点视觉（避免双焦点）。等价于 ESC 退出键盘选择
    /// （清空焦点模型 + 回到 deferred 态；下次方向键重新播种）。
    public func clearFocusForSearch() {
        exitKeyboardSelection()
    }

    /// Clear before forwarding an accepted pointer page request, which may commit synchronously.
    public func clearFocusForPointerNavigation() {
        pendingCrossPageSettleTarget = nil
        exitKeyboardSelection()
    }

    /// T-1D-D：搜索转移焦点——把焦点设置到指定身份并显示焦点框（退出 deferred 态）。
    /// 供搜索控制器在 ↓/Return/Enter 时把焦点转移到当前已显示页第一个有效结果。
    public func setFocus(to identity: AppGridFocusIdentity) {
        guard let surface, !surface.isTearingDown else { return }
        isDeferredSelection = false
        focusModel = AppGridFocusModel(current: identity)
        applyFocusVisual()
    }

    /// 应用新布局（catalog refresh / pageCount 变化）：迁移焦点模型 + 重应用视觉。
    public func applyLayout(_ layout: AppGridFocusLayout) {
        guard let surface, !surface.isTearingDown else { return }
        // T-1C-D（延迟焦点）：deferred 态下 current == nil → 跳过 focusModel.apply。
        // （AppGridFocusModel.apply 在空 current 时会播种到 page 0 首个 cell——禁止修改行为；
        //   首次方向键播种经 committedPageTarget 派生当前 committed 页布局，无需现下播种。）
        if !isDeferredSelection {
            focusModel.apply(layout: layout)
        }
        applyFocusVisual()
    }

    /// A layout transaction, not a catalog migration: same-revision identities
    /// relocate explicitly, while deferred keyboard selection remains deferred.
    public func reconfigureGrid(capacity: MainGridCapacity, layout: AppGridFocusLayout,
                                selectedIdentity: TopLevelEntryIdentity?) {
        guard let surface, !surface.isTearingDown else { return }
        columns = capacity.columns
        navigator = AppGridFocusNavigator(columns: columns)
        pendingCrossPageSettleTarget = nil
        let position = selectedIdentity.flatMap { layout.position(of: $0) }
        if let selectedIdentity, let position {
            let target = AppGridFocusIdentity(catalogRevision: layout.revision,
                pageIndex: position.page, slotIndex: position.slot, entryIdentity: selectedIdentity)
            isDeferredSelection = false
            if target.pageIndex == surface.core.committedPage {
                focusModel = AppGridFocusModel(current: target)
            } else {
                // Existing direct-page navigation will settle this identity.
                focusModel = AppGridFocusModel(current: nil)
                pendingCrossPageSettleTarget = target
            }
        } else {
            focusModel = AppGridFocusModel(current: nil)
            isDeferredSelection = true
        }
        applyFocusVisual()
    }

    public func refreshGridInputAvailability() { applyFocusVisual() }

    /// F1（T-1C-C repair）+ T-1C-D（bug-1 修复）：键盘跨页 settle 完成/中断后的焦点调和。
    ///
    /// 键盘跨页在 handleArrow 中被接受时，焦点会立即指向目标页（settle 尚未 commit）。
    /// 若该 settle 被触控板接管/中断，最终 committed/displayed 页可能与键盘目标页背离。
    /// 集成层在 Core 回 idle（settle 完成/中断）时调用本方法：仅当存在进行中的键盘跨页
    /// settle（pendingCrossPageSettleTarget != nil）才重新落定焦点。
    /// - 若 pending 目标页 == 实际 committed 页，且 pending 槽位在 committed 页仍有效：
    ///   在 pending 槽位处保留行感知落点（针对当前 layout.revision 重建身份）——修复 ←
    ///   跨页行末落点被无条件钳制到页内首 cell 的回归。
    /// - 否则回退到 committed 页确定性首 cell（committedPageTarget）或空态清空 —— 绝不
    ///   残留旧页/未显示页映射。完全复用既有机理（currentLayout + applyFocusVisual），不触碰 PagingCore。
    public func reconcileSettledCrossPage(committedPage: Int) {
        guard let pending = pendingCrossPageSettleTarget else { return }
        pendingCrossPageSettleTarget = nil
        guard let surface, !surface.isTearingDown else { return }
        // bug-1 修复：pending 目标 == committed 页且槽位有效 → 保留行感知落点。
        if pending.pageIndex == committedPage,
           let layout = currentLayout(),
           layout.validEntry(page: pending.pageIndex, slot: pending.slotIndex) == pending.entryIdentity {
            let target = AppGridFocusIdentity(catalogRevision: layout.revision,
                                              pageIndex: pending.pageIndex,
                                              slotIndex: pending.slotIndex,
                                              entryIdentity: pending.entryIdentity)
            focusModel = AppGridFocusModel(current: target)
            applyFocusVisual()
            return
        }
        // 回退：committed 页确定性首 cell；无有效 cell（空态）→ 清空焦点，确保旧页映射不残存。
        guard let target = committedPageTarget(committedPage: committedPage) else {
            focusModel = AppGridFocusModel(current: nil)
            applyFocusVisual()
            return
        }
        focusModel = AppGridFocusModel(current: target)
        applyFocusVisual()
    }

    // MARK: - Folder 打开 / 内部导航 / 标题编辑（T-1E-D）

    /// 当前是否 folder 打开（经 folderOpenStateProvider）。
    private var isFolderOpen: Bool {
        folderOpenStateProvider?()?.isOpen == true
    }

    /// Actual selected member, excluding deferred navigation seeds and removed members.
    /// Retained while presentation is unavailable so a later reflow can restore its anchor.
    public var focusedFolderMember: AppID? {
        guard let selected = innerSelectedMember,
              let entry = folderOpenStateProvider?()?.openEntry,
              entry.members.contains(selected) else { return nil }
        return selected
    }

    /// Reapply only the existing identity after the owner commits the new folder snapshot.
    public func reconcileFolderLayout() {
        if focusedFolderMember == nil { innerSelectedMember = nil }
        applyInnerFocusVisual()
    }

    /// Explicit page controls clear selection; keyboard page crossings must not call this.
    public func clearInnerSelectionForPageChange() {
        innerSelectedMember = nil
        innerNavigationSeedIndex = nil
        applyInnerFocusVisual()
    }

    /// 打开 folder（顶层 folder 激活）：记录条目身份、重置内部焦点、清除顶层焦点视觉、回调装配层。
    /// T-1E-folder-deferred-inner-focus-repair：打开时不显示内环，首次方向键后延迟显示
    /// （与 isDeferredSelection 一致）。
    private func openFolder(_ identity: AppGridFocusIdentity) {
        openedFolderIdentity = identity.entryIdentity
        innerNavigationSeedIndex = 0
        innerSelectedMember = nil
        focusModel = AppGridFocusModel(current: nil)
        applyFocusVisual()
        onOpenFolder?(identity)
    }

    /// 鼠标点击打开 folder（T-1E-folder-mouse-open-repair）：镜像键盘打开路径。
    ///
    /// Resets the deferred navigation seed and selected identity through the same seam as keyboard opening.
    /// T-1E-folder-deferred-inner-focus-repair：打开时不显示内环，首次方向键后延迟显示
    /// （与 isDeferredSelection 一致）。`onOpenFolder` 仍负责打开状态 + overlay 配置
    /// （`openFolder(folderID:)` 作为 state+overlay 原语保留）。
    public func openFolderFromClick(_ folderID: FolderID) {
        openedFolderIdentity = .folder(folderID)
        innerNavigationSeedIndex = 0
        innerSelectedMember = nil
        focusModel = AppGridFocusModel(current: nil)
        applyFocusVisual()
        let identity = AppGridFocusIdentity(catalogRevision: 0, pageIndex: 0, slotIndex: 0,
                                            entryIdentity: .folder(folderID))
        onOpenFolder?(identity)
    }

    /// 关闭 folder（ESC / Command-F）：回调装配层关闭 + 恢复焦点到 folder 条目。
    ///
    /// T-1E-D repair：folder 关闭是 folder-close 状态的单一事实源——任何关闭路径
    /// （ESC `.closeFolder` / Command-F `.closeFolderThenSearch`）都必须结束标题编辑。
    /// 否则 Command-F 在标题编辑中关闭 folder 后残留 stale `isEditingTitle`，搜索退出、
    /// 键盘控制器重获 first responder 时箭头/Return 仍被吞掉（导航死锁，需 ESC 才恢复）。
    private func closeFolder() {
        isEditingTitle = false
        onCloseFolder?()
        restoreFocusAfterClose()
        openedFolderIdentity = nil
        innerNavigationSeedIndex = nil
        innerSelectedMember = nil
    }

    /// 关闭后恢复焦点：folder 条目仍存在 → 定位到它；消失 → 回退到组合首条目（确定性）。
    private func restoreFocusAfterClose() {
        guard let surface, !surface.isTearingDown else { return }
        guard let provider = surface.contentProvider as? AppGridUIPageContentProvider else { return }
        let entries = provider.presentationEntries
        let itemsPerPage = surface.itemsPerPage
        let revision = provider.servedRevision ?? 0
        guard let target = FolderFocusRestore.restoreTarget(
            folderIdentity: openedFolderIdentity, in: entries, itemsPerPage: itemsPerPage,
            revision: revision) else {
            focusModel = AppGridFocusModel(current: nil)
            applyFocusVisual()
            return
        }
        isDeferredSelection = false
        focusModel = AppGridFocusModel(current: target)
        applyFocusVisual()
    }

    /// 内部成员导航（folder 打开时箭头）：四方向 + 跨页（焦点/页一致）。
    private func handleInnerArrow(_ direction: AppGridFocusDirection) {
        guard let folderOpenState = folderOpenStateProvider?(),
              folderOpenState.isMemberPresentationAvailable,
              let entry = folderOpenState.openEntry else {
            applyInnerFocusVisual()
            return
        }
        let memberCount = entry.members.count
        guard memberCount > 0 else { return }
        let membersPerPage = folderOpenState.membersPerPage
        let navigator = FolderInnerNavigator(columns: folderOpenState.columns,
                                             membersPerPage: membersPerPage)
        let selectedIndex = focusedFolderMember.flatMap { entry.members.firstIndex(of: $0) }
        let candidateIndex = selectedIndex ?? innerNavigationSeedIndex
        guard let currentIndex = candidateIndex, currentIndex >= 0, currentIndex < memberCount,
              currentIndex / membersPerPage == folderOpenState.innerPage else {
            // After an explicit page change, the first arrow selects rather than moves.
            innerSelectedMember = folderOpenState.members(onPage: folderOpenState.innerPage).first
            innerNavigationSeedIndex = nil
            applyInnerFocusVisual()
            return
        }
        guard let move = navigator.move(currentIndex: currentIndex, memberCount: memberCount,
                                        direction: direction) else { return }
        innerSelectedMember = entry.members[move.memberIndex]
        innerNavigationSeedIndex = nil
        if move.crossedPage {
            onInnerPageChange?(move.memberIndex / membersPerPage)
        }
        applyInnerFocusVisual()
    }

    /// 激活内部成员（folder 打开时 Return/Enter）。
    private func activateInnerMember() {
        guard let folderOpenState = folderOpenStateProvider?(),
              folderOpenState.isMemberPresentationAvailable else { return }
        let visibleMembers = folderOpenState.members(onPage: folderOpenState.innerPage)
        if let selected = focusedFolderMember, visibleMembers.contains(selected) {
            onActivateMember?(selected)
        } else if let first = visibleMembers.first {
            onActivateMember?(first)
        }
    }

    /// 内部成员焦点视觉（经 overlay 的 memberCell；slot = 全局 index % membersPerPage）。
    private func applyInnerFocusVisual() {
        guard let overlay = folderOverlayProvider?() else { return }
        let state = folderOpenStateProvider?()
        let selected = focusedFolderMember
        var slot: Int?
        if let state, state.isMemberPresentationAvailable, let selected,
           let index = state.openEntry?.members.firstIndex(of: selected),
           index / state.membersPerPage == state.innerPage {
            slot = index % state.membersPerPage
        }
        for i in 0..<overlay.memberCellCount {
            overlay.memberCell(at: i)?.setFocused(i == slot && overlay.memberAppID(at: i) == selected)
        }
    }

    /// ESC 优先级：编辑标题 → 取消；folder 打开 → 关闭；否则 → 清除网格选择。
    private func handleEscape() {
        switch FolderKeyboardPriority.escAction(editingTitle: isEditingTitle, folderOpen: isFolderOpen) {
        case .cancelTitleEdit:
            onTitleCancel?()
            isEditingTitle = false
        case .closeFolder:
            closeFolder()
        case .clearGridSelection:
            // ADR-011 Q6：有选择 → 清选择；已无选择 → 宿主 hide（驻留，不 terminate）。
            if focusModel.current != nil {
                exitKeyboardSelection()
            } else {
                onEscapeExhausted?()
            }
        case .closeFolderThenSearch, .search:
            break
        }
    }

    /// Command-F：folder 打开 → 先安全关闭再搜索；否则直接搜索。
    private func handleCommandF() {
        switch FolderKeyboardPriority.commandFAction(folderOpen: isFolderOpen) {
        case .closeFolderThenSearch:
            closeFolder()
            onSearchShortcut?()
        case .search:
            onSearchShortcut?()
        case .cancelTitleEdit, .closeFolder, .clearGridSelection:
            break
        }
    }

    /// 激活分流（ADR-008 §2.2）：folder → 打开；app → 既有启动；nil → 拒绝。
    private func routeActivation(_ identity: AppGridFocusIdentity) {
        switch ActivationRouter.decide(for: identity.entryIdentity) {
        case .openFolder:
            openFolder(identity)
        case .launchApp:
            onActivate?(identity)
        case .reject:
            break
        }
    }

    /// 显式进入标题编辑（T-1E-E 接线到 FolderTitleEditor）。
    public func beginTitleEditing() {
        isEditingTitle = true
    }

    /// 结束标题编辑（T-1E-E 接线到 FolderTitleEditor 提交/取消后）。
    public func endTitleEditing() {
        isEditingTitle = false
    }

    // MARK: - 内部

    private func handleArrow(_ direction: AppGridFocusDirection) {
        guard let surface, !surface.isTearingDown else { return }
        guard let navigator, let layout = currentLayout() else { return }
        // T-1C-D（延迟焦点）：deferred 态（current == nil）——按任意方向键才显示焦点框，
        // 播种到当前 committed 页首行首格（仅显示，不移动）。
        if focusModel.current == nil {
            isDeferredSelection = false
            if let target = committedPageTarget(committedPage: surface.core.committedPage) {
                focusModel = AppGridFocusModel(current: target)
                applyFocusVisual()
            }
            return
        }
        guard let current = focusModel.current else { return }
        guard let target = navigator.move(current, direction: direction, in: layout) else { return }

        let crossPage = target.pageIndex != current.pageIndex
        if crossPage {
            let turnDirection: KeyboardPageDirection = target.pageIndex > current.pageIndex ? .next : .previous
            guard let result = pageTurner?.turn(direction: turnDirection, timestamp: timestamp()) else { return }
            // 仅当翻页被接受（idle）才更新焦点；deferred/atBoundary/tornDown → 不改变焦点。
            guard result == .turned(target.pageIndex) else { return }
            // F1（+ bug-1 修复）：记录进行中的键盘跨页 settle **完整目标身份**（页+槽），
            // settle 完成/中断后 reconcile 据此保留行感知落点或回退到实际 committed 页。
            pendingCrossPageSettleTarget = target
        }

        focusModel = AppGridFocusModel(current: target)
        applyFocusVisual()
    }

    private func applyFocusVisual() {
        guard let surface, !surface.isTearingDown else { return }
        if !isFolderOpen, gridInputIsAvailable?() == false {
            if let last = lastAppliedIdentity { cell(for: last)?.setFocused(false) }
            lastAppliedIdentity = nil
            return
        }
        guard let identity = focusModel.current else {
            if let last = lastAppliedIdentity {
                cell(for: last)?.setFocused(false)
            }
            lastAppliedIdentity = nil
            return
        }
        if let last = lastAppliedIdentity, last != identity {
            cell(for: last)?.setFocused(false)
        }
        cell(for: identity)?.setFocused(true)
        lastAppliedIdentity = identity
    }

    /// T-1C-D：ESC 退出键盘选择——清除焦点框，回到 deferred 态（下次方向键重新播种）。
    private func exitKeyboardSelection() {
        focusModel = AppGridFocusModel(current: nil)
        // 保留 lastAppliedIdentity：applyFocusVisual() 的 nil-current 分支依赖它
        // 对旧 cell 调 setFocused(false) 完成 unhighlight；之后再自清。
        isDeferredSelection = true
        applyFocusVisual()
    }

    private func currentLayout() -> AppGridFocusLayout? {
        if let provider = layoutProvider {
            return provider()
        }
        guard let surface,
              let provider = surface.contentProvider as? AppGridUIPageContentProvider,
              let snapshot = provider.servedSnapshot else { return nil }
        // T-1E-folder-keyboard-return-repair：布局由顶层组合（app + folder）构建——
        // folder 槽位身份 = .folder（app-only 布局会把 folder 槽位误标为 .app）。
        return AppGridFocusLayout.build(from: snapshot, composition: provider.presentationEntries,
                                        itemsPerPage: surface.itemsPerPage)
    }

    /// F1：committed 页的确定性焦点目标 = 该页首个有效 cell（placeholder/空 slot 排除）。
    private func committedPageTarget(committedPage: Int) -> AppGridFocusIdentity? {
        guard let layout = currentLayout() else { return nil }
        guard let slot = layout.validSlots(on: committedPage).first,
              let entry = layout.validEntry(page: committedPage, slot: slot) else { return nil }
        return AppGridFocusIdentity(catalogRevision: layout.revision, pageIndex: committedPage,
                                    slotIndex: slot, entryIdentity: entry)
    }

    private func cell(for identity: AppGridFocusIdentity) -> AppGridCellView? {
        if let resolver = cellResolver {
            return resolver(identity)
        }
        guard let renderer = surface?.renderer as? AppGridRenderer else { return nil }
        return renderer.pageView(forPage: identity.pageIndex)?.cell(at: identity.slotIndex)
    }

    private func arrowDirection(for event: NSEvent) -> AppGridFocusDirection? {
        switch event.keyCode {
        case KeyCodes.leftArrow: return .left
        case KeyCodes.rightArrow: return .right
        case KeyCodes.downArrow: return .down
        case KeyCodes.upArrow: return .up
        default: return nil
        }
    }

    private func isActivationKey(_ event: NSEvent) -> Bool {
        event.keyCode == KeyCodes.returnKey || event.keyCode == KeyCodes.keypadEnter // Return / keypad Enter
    }

    /// T-1D-D：Command-F 搜索快捷键判定。
    private func isSearchShortcut(_ event: NSEvent) -> Bool {
        event.keyCode == KeyCodes.commandF && event.modifierFlags.contains(.command)
    }

    /// 本地虚拟键码常量（AVR 布局）。ESC 走 exitKeyboardSelection（T-1C-D）。
    private enum KeyCodes {
        static let escape: UInt16 = 53
        static let returnKey: UInt16 = 36
        static let keypadEnter: UInt16 = 76
        static let leftArrow: UInt16 = 123
        static let rightArrow: UInt16 = 124
        static let downArrow: UInt16 = 125
        static let upArrow: UInt16 = 126
        static let commandF: UInt16 = 3
    }

    private func timestamp() -> TimeInterval {
        ProcessInfo.processInfo.systemUptime
    }
}
