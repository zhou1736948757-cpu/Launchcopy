// PagingPrototypeApp — AppSearchController（Phase 1D §7.2 搜索 UI / responder 层）
// 实现：T-1D-D（Worker D）。
//
// 职责：
// - 拥有 AppSearchFieldView（NSSearchField）；
// - Command-F → 搜索框成为 first responder + 清除旧网格焦点视觉（避免双焦点）；
// - 实时输入 → AppGridSearchPresentationController.updateQuery（latest-wins 查询代）；
// - Escape 非空 query → 清空 query、恢复全 catalog、保持搜索框 first responder；
// - Escape 空 query → 离开搜索框、恢复 KeyboardFocusController first responder、保持延迟焦点；
// - ↓ / Return/Enter（有已提交结果）→ 仅把焦点转移到当前已显示页第一个有效结果（首次不启动）；
// - 网格焦点建立后 Return/Enter 走现有启动管线（KeyboardFocusController.onActivate）；
// - Tab → 交给 AppKit responder chain，不非法吞键；
// - 无已提交结果或 pending generation → Return/Enter 不启动旧结果；
// - F3 follow-up：搜索进入/退出、窗口重新成为 key、系统控件夺焦后按明确规则重建 first responder。
//
// 隐私：query 原文/归一化文本/结果 app 名绝不进入 telemetry/log/stdout/signpost/profile/report。

import AppCatalogCore
import AppGridUI
import AppKit
import PagingUI

/// 搜索 UI / responder 编排器：拥有搜索框，桥接 field 与 presentation controller，
/// 处理 Command-F / Escape / Down / Return/Enter / Tab 语义与 first responder 转移/恢复。
@MainActor
public final class AppSearchController: NSObject, NSSearchFieldDelegate {

    /// 搜索框（中性 NSSearchField；装配层作为 overlay/sibling 加入全屏窗口）。
    public let field: AppSearchFieldView

    /// 搜索呈现编排器（T-1D-B；拥有查询代 + idle 边界提交）。
    public let presentation: AppGridSearchPresentationController

    /// 搜索进入回调（装配层可接；中性，无身份信息）。
    public var onSearchEntered: (() -> Void)?
    /// 搜索退出回调（装配层可接；中性）。
    public var onSearchExited: (() -> Void)?
    public var gridInputIsAvailable: (() -> Bool)?

    /// T-1E-D：当前模式 first responder 提供者（T-1E-E 接线）。返回当前应成为 first responder
    /// 的 responder（标题编辑 → FolderTitleEditor；folder 打开 → KeyboardFocusController）；
    /// nil = 由本控制器按搜索/顶层规则决定。key-window 重建按模式优先级：标题编辑 > folder
    /// 打开 > 搜索 > 顶层（ADR-008 §3 Q10）。
    public var modeFirstResponderProvider: (() -> NSResponder?)?

    /// Composition-root commit hook: stages dependent folder data before applying search.
    /// Standalone search controllers continue to commit their own presentation directly.
    public var pendingCommitter: ((Int) -> AppGridPresentationUpdate?)?

    private weak var keyboardController: KeyboardFocusController?
    private weak var surface: PagingSurface?
    /// 内部激活标记（Command-F / 转移焦点置位；空白退出与 responder 重建共用）。
    private var isSearchActiveFlag = false
    private var windowObserver: NSObjectProtocol?

    public init(presentation: AppGridSearchPresentationController,
                keyboardController: KeyboardFocusController?,
                surface: PagingSurface?) {
        self.presentation = presentation
        self.keyboardController = keyboardController
        self.surface = surface
        self.field = AppSearchFieldView()
        super.init()
        self.field.delegate = self
    }

    deinit {
        if let windowObserver {
            NotificationCenter.default.removeObserver(windowObserver)
        }
    }

    // MARK: - 生命周期 / 装配

    /// 装配层在把 field 加入窗口后调用：观察窗口 key 状态以重建 first responder（F3）。
    public func install(in window: NSWindow) {
        windowObserver = NotificationCenter.default.addObserver(
            forName: NSWindow.didBecomeKeyNotification,
            object: window,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.rebuildFirstResponder()
            }
        }
    }

    /// 装配层在 teardown 时调用：移除观察者，零回调。
    public func teardown() {
        if let observer = windowObserver {
            NotificationCenter.default.removeObserver(observer)
            windowObserver = nil
        }
        isSearchActiveFlag = false
    }

    // MARK: - Command-F 进入搜索

    /// Command-F 入口（装配层接到 KeyboardFocusController.onSearchShortcut 后调用）。
    public func activateSearch() {
        guard let window = field.window else { return }
        // 清除旧网格焦点视觉（避免双焦点）。
        keyboardController?.clearFocusForSearch()
        window.makeFirstResponder(field)
        isSearchActiveFlag = true
        onSearchEntered?()
    }

    // MARK: - 空白点击退出搜索 seam（T-1D 修复）

    /// 搜索是否激活（空白单击→退出搜索而非退出的公共同步 seam）。
    /// 定义（OR）：搜索框或其 field editor 是 first responder / 正在编辑，
    /// 或有当前/暂存 query。canonical case —— 用户只点击了搜索框（空 query，还没开始
    /// 搜索）→ 由 first-responder 分支返回 true。
    public var isSearchActive: Bool {
        if isSearchActiveFlag { return true }
        if let window = field.window,
           let first = window.firstResponder,
           first === field || first === field.currentEditor() {
            return true
        }
        if !currentText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { return true }
        if let query = presentation.currentQuery, !query.isEmpty { return true }
        return false
    }

    /// 共享退出搜索例程（Escape 空 query 与空白单击退出合用，避免重复退出逻辑）。
    /// 语义：清空 query（若有）→ 恢复全 catalog → 恢复 KeyboardFocusController
    /// first responder → 去激活搜索 UI。调用方据此 CONSUME 空白点击且不终止应用。
    public func exitSearchAndRestoreFocus() {
        clearFieldText()
        surface?.cancelDirectNavigation()
        presentation.clearQuery()
        commitIfIdle()
        guard let window = field.window else { return }
        if let keyboardController {
            window.makeFirstResponder(keyboardController)
        }
        isSearchActiveFlag = false
        onSearchExited?()
    }

    /// Restores an ephemeral Library return context through the existing query
    /// transaction; no catalog revision is minted and no search history is saved.
    func restoreAfterLibrary(query: String, focusSearch: Bool) {
        field.stringValue = query
        if let editor = field.currentEditor() { editor.string = query }
        surface?.cancelDirectNavigation()
        let requested = AppSearchQuery(raw: query)
        let unchanged = requested.isEmpty
            ? (presentation.currentQuery?.isEmpty ?? true)
            : presentation.currentQuery == requested
        // The grid remains retained under Library. Re-submitting the same query
        // invalidates visible cells/icons at the exact return boundary for no gain.
        if !unchanged {
            if requested.isEmpty { presentation.clearQuery() }
            else { presentation.updateQuery(requested) }
        }
        // Still admit a pending catalog/search transaction on the current query.
        commitIfIdle()
        isSearchActiveFlag = focusSearch
        if focusSearch { field.window?.makeFirstResponder(field) }
    }

    // MARK: - 实时输入 → 查询代

    public func controlTextDidChange(_ obj: Notification) {
        let raw = currentText
        surface?.cancelDirectNavigation()
        presentation.updateQuery(AppSearchQuery(raw: raw))
        commitIfIdle()
    }

    // MARK: - 命令处理（Return/Escape/Down/Tab）

    public func control(_ control: NSControl, textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
        // The input method owns commands while composing. Do not clear its
        // draft or resign the editor to navigate launcher results.
        guard !textView.hasMarkedText() else { return false }
        switch commandSelector {
        case #selector(NSResponder.insertNewline(_:)):
            return handleReturnOrEnter()
        case #selector(NSResponder.cancelOperation(_:)):
            return handleEscape()
        case #selector(NSResponder.moveDown(_:)):
            return handleDown()
        case #selector(NSResponder.insertTab(_:)),
             #selector(NSResponder.insertBacktab(_:)):
            return false // Tab → AppKit responder chain，不非法吞键
        default:
            return false
        }
    }

    // MARK: - 内部：Escape / Return / Down

    private func handleEscape() -> Bool {
        if currentText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            // 空 query → 离开搜索框，恢复键盘控制器（与空白单击退出共享同一条退出例程）。
            exitSearchAndRestoreFocus()
        } else {
            // 非空 query → 清空 query，恢复全 catalog，保持搜索框 first responder。
            clearFieldText()
            surface?.cancelDirectNavigation()
            presentation.clearQuery()
            commitIfIdle()
        }
        return true
    }

    private func handleReturnOrEnter() -> Bool {
        if gridInputIsAvailable?() == false { return true }
        if surface?.isDirectNavigationActive == true { return true }
        return transferFocusToFirstResult()
    }

    private func handleDown() -> Bool {
        if gridInputIsAvailable?() == false { return true }
        if surface?.isDirectNavigationActive == true { return true }
        return transferFocusToFirstResult()
    }

    /// 把焦点转移到当前已显示页第一个有效结果（首次不启动）。
    /// 无已提交结果或 pending generation → 不转移（不启动旧结果）。
    private func transferFocusToFirstResult() -> Bool {
        guard canTransferFocus() else { return false }
        guard let target = firstValidResultOnCurrentPage() else { return false }
        guard let window = field.window else { return false }
        keyboardController?.setFocus(to: target)
        window.makeFirstResponder(keyboardController)
        isSearchActiveFlag = false
        onSearchExited?()
        return true
    }

    private func canTransferFocus() -> Bool {
        guard gridInputIsAvailable?() != false else { return false }
        guard let surface, !surface.isTearingDown else { return false }
        // 无已提交结果 → 不转移。
        guard !presentation.provider.presentationRecords.isEmpty else { return false }
        // pending generation（新 query 尚未提交）→ 不转移到旧结果。
        guard !presentation.provider.hasPendingSearchResult else { return false }
        return true
    }

    private func firstValidResultOnCurrentPage() -> AppGridFocusIdentity? {
        guard let surface, !surface.isTearingDown else { return nil }
        guard let base = presentation.provider.servedSnapshot else { return nil }
        let records = presentation.provider.presentationRecords
        guard !records.isEmpty else { return nil }
        // 用已提交呈现记录构建布局（同 revision；不伪造 CatalogRevision）。
        let snapshot = CatalogSnapshot(revision: base.revision, records: records)
        let layout = AppGridFocusLayout.build(from: snapshot, itemsPerPage: surface.itemsPerPage)
        let page = surface.core.committedPage
        guard let slot = layout.validSlots(on: page).first,
              let appID = layout.validAppID(page: page, slot: slot) else { return nil }
        return AppGridFocusIdentity(catalogRevision: layout.revision, pageIndex: page,
                                    slotIndex: slot, appID: appID)
    }

    // MARK: - 内部：退出 / 提交 / 重建

    /// idle 边界提交（搜索控制器触发；装配层也应在 surface.onIdleBoundary 调用以覆盖 busy 态）。
    @discardableResult
    public func commitPendingAtIdleBoundary() -> AppGridPresentationUpdate? {
        guard let surface, !surface.isTearingDown else { return nil }
        let page = surface.core.committedPage
        if let pendingCommitter { return pendingCommitter(page) }
        return presentation.applyPendingAtIdleBoundary(currentPage: page)
    }

    private func commitIfIdle() {
        guard let surface, !surface.isTearingDown else { return }
        if surface.core.state == .idle {
            _ = commitPendingAtIdleBoundary()
        }
    }

    /// F3 + T-1E-D：窗口重新成为 key 后按当前模式重建 first responder。
    /// 优先级：标题编辑 > folder 打开 > 搜索 > 顶层（经 modeFirstResponderProvider 或既有规则）。
    private func rebuildFirstResponder() {
        guard let window = field.window else { return }
        // T-1E-D：模式提供者优先（标题编辑 / folder 打开等非搜索模式）。
        if let responder = modeFirstResponderProvider?() {
            if window.firstResponder === responder { return }
            // A control's native field editor already owns its input. Asking
            // for the control again can resign it and commit a title draft.
            if let editor = (responder as? NSControl)?.currentEditor(),
               window.firstResponder === editor { return }
            window.makeFirstResponder(responder)
            return
        }
        if isSearchActive {
            // 搜索激活 → 搜索框（或其 field editor）应为 first responder。
            let editor = field.currentEditor()
            if window.firstResponder !== field && window.firstResponder !== editor {
                window.makeFirstResponder(field)
            }
        } else {
            // 搜索未激活 → 键盘控制器应为 first responder。
            if let keyboardController, window.firstResponder !== keyboardController {
                window.makeFirstResponder(keyboardController)
            }
        }
    }

    private var currentText: String {
        field.currentEditor()?.string ?? field.stringValue
    }

    private func clearFieldText() {
        field.stringValue = ""
        if let editor = field.currentEditor() {
            editor.string = ""
        }
    }
}
