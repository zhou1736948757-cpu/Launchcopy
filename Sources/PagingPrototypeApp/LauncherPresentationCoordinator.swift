//
//  LauncherPresentationCoordinator.swift
//  PagingPrototypeApp
//
//  Phase 1G 纯 presentation 状态机（T-1G-A）。
//  语义（PHASE1G_ACTIVATION_ENTRY_HOT_CORNER_PROMPT §3.1 / PLAN §9 不变量 1-3）：
//  - 一进程最多一个有效 transition、一个 active request ID；旧 completion 永不覆盖新状态。
//  - show 在 visible/presenting 幂等；hide 在 hidden/dismissing 幂等。
//  - toggle 在 committed state 原子决策（本机是唯一写者，天然原子，无先读后写竞态）。
//  - presenting/dismissing 中收到相反命令 → 中断（interrupt）：旧 transition 作废（其
//    completion 变 stale），立即开始反向 transition。
//  - quit dominates：任何状态 → .terminating，后续命令全部拒绝。
//  - terminate() 只执行一次 teardown（teardownCount 0→1）。
//  纯 Foundation，无 AppKit。
//

import Foundation

/// 纯 presentation 状态机（值类型；UI 层持有并执行其输出的 effect）。
public struct LauncherPresentationCoordinator: Equatable, Sendable {
    public private(set) var state: LauncherPresentationState
    /// 当前 in-flight transition 的 request ID；无 transition 时为 0。
    public private(set) var activeRequestID: UInt64
    /// teardown 已执行次数（验收：terminate teardown once）。
    public private(set) var teardownCount: Int

    private var nextRequestID: UInt64

    public init(initialState: LauncherPresentationState = .hidden) {
        self.state = initialState
        self.activeRequestID = 0
        self.teardownCount = 0
        self.nextRequestID = 1
    }

    // MARK: - 查询

    /// committed 可见性（菜单 validation 用）：presenting 视为将可见，dismissing 视为将隐藏。
    public var committedVisibility: Bool {
        switch state {
        case .hidden, .dismissing, .suspended, .terminating:
            return false
        case .presenting, .visible:
            return true
        }
    }

    // MARK: - 命令

    /// show：hidden/suspended → presenting；visible/presenting 幂等；dismissing → 中断反向。
    public mutating func show(source: LauncherActivationSource, targetScreen: ScreenID) -> LauncherPresentationEffect {
        switch state {
        case .hidden, .suspended:
            return beginPresent(source: source, targetScreen: targetScreen)
        case .presenting, .visible:
            return .none // 幂等
        case .dismissing:
            return beginPresent(source: source, targetScreen: targetScreen) // 中断反向
        case .terminating:
            return .none // quit dominates
        }
    }

    /// hide：visible → dismissing；hidden/dismissing 幂等；presenting → 中断反向；suspended 已隐藏。
    public mutating func hide(source: LauncherActivationSource, reason: DismissReason) -> LauncherPresentationEffect {
        switch state {
        case .hidden, .dismissing, .suspended:
            return .none // 幂等 / 已隐藏
        case .presenting:
            return beginDismiss(source: source, reason: reason) // 中断反向
        case .visible:
            return beginDismiss(source: source, reason: reason)
        case .terminating:
            return .none
        }
    }

    /// toggle：在 committed state 上原子决策。hidden/suspended → show；visible → hide；
    /// presenting → hide（中断）；dismissing → show（中断）；terminating → 拒绝。
    public mutating func toggle(source: LauncherActivationSource, targetScreen: ScreenID) -> LauncherPresentationEffect {
        switch state {
        case .hidden, .suspended:
            return beginPresent(source: source, targetScreen: targetScreen)
        case .presenting:
            return beginDismiss(source: source, reason: dismissReason(for: source))
        case .visible:
            return beginDismiss(source: source, reason: dismissReason(for: source))
        case .dismissing:
            return beginPresent(source: source, targetScreen: targetScreen)
        case .terminating:
            return .none
        }
    }

    /// quit dominates：任何状态 → .terminating；后续命令全部拒绝。
    public mutating func quit() -> LauncherPresentationEffect {
        guard state != .terminating else { return .none }
        state = .terminating
        activeRequestID = 0
        return .terminate
    }

    /// 最终 teardown：恰好一次（可被 quit 后或系统终止直接调用）。
    public mutating func terminate() -> LauncherPresentationEffect {
        guard teardownCount == 0 else { return .none } // teardown once
        teardownCount = 1
        state = .terminating
        activeRequestID = 0
        return .teardown
    }

    /// 通用命令入口（LauncherCommand 分发）。
    public mutating func handle(
        _ command: LauncherCommand,
        source: LauncherActivationSource,
        targetScreen: ScreenID
    ) -> LauncherPresentationEffect {
        switch command {
        case .show:
            return show(source: source, targetScreen: targetScreen)
        case .hide:
            return hide(source: source, reason: dismissReason(for: source))
        case .toggle:
            return toggle(source: source, targetScreen: targetScreen)
        case .quit:
            return quit()
        }
    }

    // MARK: - Transition 完成（UI 层在动画结束后调用）

    /// 仅当 requestID == activeRequestID 时生效；stale completion 一律拒绝（.none）。
    public mutating func completeTransition(requestID: UInt64) -> LauncherPresentationEffect {
        guard requestID == activeRequestID else { return .none } // stale rejected
        switch state {
        case .presenting(_, let targetScreen):
            activeRequestID = 0
            state = .visible(screenID: targetScreen)
            return .none
        case .dismissing:
            activeRequestID = 0
            state = .hidden
            return .none
        default:
            return .none
        }
    }

    // MARK: - 挂起 / 恢复（sleep / session inactive / 屏幕重配）

    /// 挂起：取消 in-flight transition（其 completion 变 stale），进入 .suspended。
    public mutating func suspend(reason: LauncherSuspensionReason) -> LauncherPresentationEffect {
        switch state {
        case .hidden, .presenting, .dismissing, .visible:
            activeRequestID = 0
            state = .suspended(reason: reason)
            return .suspend(reason: reason)
        case .suspended:
            return .none // 已挂起
        case .terminating:
            return .none
        }
    }

    /// 恢复：确定性回到 .hidden（唤醒后保持隐藏，用户重新激活；不自动弹窗）。
    public mutating func resume() -> LauncherPresentationEffect {
        guard case .suspended = state else { return .none }
        state = .hidden
        return .none
    }

    // MARK: - 私有

    private mutating func beginPresent(
        source: LauncherActivationSource,
        targetScreen: ScreenID
    ) -> LauncherPresentationEffect {
        let requestID = nextRequestID
        nextRequestID &+= 1
        activeRequestID = requestID
        state = .presenting(requestID: requestID, targetScreen: targetScreen)
        return .present(requestID: requestID, targetScreen: targetScreen, source: source)
    }

    private mutating func beginDismiss(
        source: LauncherActivationSource,
        reason: DismissReason
    ) -> LauncherPresentationEffect {
        let requestID = nextRequestID
        nextRequestID &+= 1
        activeRequestID = requestID
        state = .dismissing(requestID: requestID, reason: reason)
        return .dismiss(requestID: requestID, reason: reason, source: source)
    }

    /// toggle/handle(.hide) 的关闭原因映射：statusItem/globalShortcut 各自归因，其余中性回退。
    private func dismissReason(for source: LauncherActivationSource) -> DismissReason {
        switch source {
        case .statusItem:
            return .statusItem
        case .globalShortcut:
            return .globalShortcut
        default:
            return .statusItem // 中性回退（testHarness 等）
        }
    }
}
