//
//  WorkspaceSessionObserver.swift
//  PagingPrototypeApp
//
//  Phase 1G T-1G-D：sleep / session / 屏幕变化观察器。
//  向 HotCornerMonitor（及未来接线层）投递中性 WorkspaceSessionEvent；
//  测试用 Fake，不依赖真实 sleep/lock。不记录前台 app / 屏幕 UUID/名称。
//

import AppKit
import Foundation

/// 工作区/会话中性事件（允许记录 enum；不含坐标/app 身份）。
public enum WorkspaceSessionEvent: Equatable, Sendable {
    case willSleep
    case didWake
    case sessionResigned
    case sessionActivated
    case screensChanged
}

/// 观察器协议（生产 = NSWorkspace/NSApplication 通知；测试 = Fake）。
public protocol WorkspaceSessionObserving: AnyObject {
    var onEvent: ((WorkspaceSessionEvent) -> Void)? { get set }
    func start()
    func stop()
}

/// 将 WorkspaceSessionEvent 映射到 HotCornerMonitor 挂起/恢复/重配。
public enum WorkspaceSessionHotCornerBridge {
    public static func apply(_ event: WorkspaceSessionEvent, to monitor: HotCornerMonitor) {
        switch event {
        case .willSleep:
            monitor.suspend(reason: .sleep)
        case .sessionResigned:
            monitor.suspend(reason: .sessionInactive)
        case .didWake, .sessionActivated:
            monitor.resume()
        case .screensChanged:
            if monitor.isSuspended {
                // 挂起期间仅刷新几何意图：仍保持 suspended；resume 时会 rebuild。
                monitor.screensDidChange()
            } else {
                monitor.screensDidChange()
                // 非挂起：状态机 updateGeometry 已取消 dwell；保持轮询。
            }
        }
    }
}

/// 生产观察器：公开 NSWorkspace / NSApplication 通知。
public final class WorkspaceSessionObserver: WorkspaceSessionObserving {
    public var onEvent: ((WorkspaceSessionEvent) -> Void)?

    private var tokens: [NSObjectProtocol] = []
    private let notificationCenter: NotificationCenter
    private let workspace: NSWorkspace
    private var isStarted = false

    public init(
        workspace: NSWorkspace = .shared,
        notificationCenter: NotificationCenter = .default
    ) {
        self.workspace = workspace
        self.notificationCenter = notificationCenter
    }

    deinit {
        stop()
    }

    public func start() {
        guard !isStarted else { return }
        isStarted = true

        let center = notificationCenter
        let workspaceNC = workspace.notificationCenter

        tokens.append(workspaceNC.addObserver(
            forName: NSWorkspace.willSleepNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.onEvent?(.willSleep)
        })

        tokens.append(workspaceNC.addObserver(
            forName: NSWorkspace.didWakeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.onEvent?(.didWake)
        })

        tokens.append(workspaceNC.addObserver(
            forName: NSWorkspace.sessionDidResignActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.onEvent?(.sessionResigned)
        })

        tokens.append(workspaceNC.addObserver(
            forName: NSWorkspace.sessionDidBecomeActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.onEvent?(.sessionActivated)
        })

        tokens.append(center.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.onEvent?(.screensChanged)
        })
    }

    public func stop() {
        let workspaceNC = workspace.notificationCenter
        for token in tokens {
            workspaceNC.removeObserver(token)
            notificationCenter.removeObserver(token)
        }
        tokens.removeAll()
        isStarted = false
    }
}

/// 测试用 fake：手动 post，不触碰真实 workspace。
public final class FakeWorkspaceSessionObserver: WorkspaceSessionObserving {
    public var onEvent: ((WorkspaceSessionEvent) -> Void)?
    public private(set) var isStarted = false
    public private(set) var posted: [WorkspaceSessionEvent] = []

    public init() {}

    public func start() {
        isStarted = true
    }

    public func stop() {
        isStarted = false
    }

    public func post(_ event: WorkspaceSessionEvent) {
        guard isStarted else { return }
        posted.append(event)
        onEvent?(event)
    }
}
