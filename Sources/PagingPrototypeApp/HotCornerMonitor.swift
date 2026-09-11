//
//  HotCornerMonitor.swift
//  PagingPrototypeApp
//
//  Phase 1G T-1G-D：Hot Corner 低频可暂停轮询适配器。
//  ADR-012 Q3：主线程 Timer（50–100ms）+ NSEvent.mouseLocation + ScreenGeometrySnapshot
//  + HotCornerStateMachine；disabled = 零 timer 零轮询；只回调 .show（永不 hide）。
//  禁止 global NSEvent monitor / CGEvent tap / Accessibility / IOHID。
//  隐私：不记录鼠标坐标、屏幕 UUID/名称；日志仅中性 enum/计数。
//

import AppKit
import Foundation

// MARK: - Configuration

/// Hot Corner 监视器配置（poll 与纯状态机参数分离；§3.9）。
public struct HotCornerMonitorConfiguration: Equatable, Sendable {
    public var parameters: HotCornerParameters
    /// 轮询间隔（s）；合法候选 0.05–0.10。
    public var pollInterval: TimeInterval

    public init(parameters: HotCornerParameters, pollInterval: TimeInterval) {
        self.parameters = parameters
        self.pollInterval = pollInterval
    }

    /// 产品默认（PRODUCT_DECISION / 工程判断；非 reverse-derived）。
    public static let productDefaults = HotCornerMonitorConfiguration(
        parameters: HotCornerParameters(
            zoneSize: 10,
            dwellDuration: 0.15,
            hysteresisInset: 6,
            cooldown: 1.0
        ),
        pollInterval: 0.075
    )
}

// MARK: - Injected seams

/// 指针位置提供（生产 = NSEvent.mouseLocation；测试注入固定/脚本点）。
public protocol HotCornerPointerLocating: AnyObject {
    func currentPointer() -> LauncherPoint
}

/// 几何快照提供（生产 = NSScreen.screens 映射；测试注入）。
public protocol HotCornerGeometryProviding: AnyObject {
    func currentGeometry() -> ScreenGeometrySnapshot
}

/// 可暂停调度器（生产 = 主线程 Timer；测试 = 手动 tick）。
public protocol HotCornerScheduling: AnyObject {
    var isRunning: Bool { get }
    func start(interval: TimeInterval, fire: @escaping () -> Void)
    func stop()
}

/// 生产指针定位：公开 `NSEvent.mouseLocation`（AppKit 坐标系，原点左下）。
public final class NSEventPointerLocator: HotCornerPointerLocating {
    public init() {}

    public func currentPointer() -> LauncherPoint {
        let point = NSEvent.mouseLocation
        return LauncherPoint(x: point.x, y: point.y)
    }
}

/// 生产几何：`NSScreen.screens` → 中性 ScreenID(index:)；不读/不存 UUID/名称。
public final class NSScreenGeometryProvider: HotCornerGeometryProviding {
    public init() {}

    public func currentGeometry() -> ScreenGeometrySnapshot {
        ScreenGeometrySnapshotBuilder.fromNSScreens(NSScreen.screens)
    }
}

/// 从 NSScreen 列表构建纯几何快照（不持久化 UUID/名称）。
public enum ScreenGeometrySnapshotBuilder {
    public static func fromNSScreens(_ screens: [NSScreen]) -> ScreenGeometrySnapshot {
        let mapped: [ScreenGeometrySnapshot.Screen] = screens.enumerated().map { index, screen in
            let frame = screen.frame
            return ScreenGeometrySnapshot.Screen(
                id: ScreenID(index: index),
                frame: LauncherRect(
                    origin: LauncherPoint(x: frame.origin.x, y: frame.origin.y),
                    size: LauncherSize(width: frame.size.width, height: frame.size.height)
                ),
                scale: Double(screen.backingScaleFactor)
            )
        }
        return ScreenGeometrySnapshot(screens: mapped)
    }
}

/// 主线程 Timer 调度（ADR-012 Q3 ACCEPTED）。disabled 时调用方不 start → 零 timer。
public final class MainRunLoopHotCornerScheduler: HotCornerScheduling {
    private var timer: Timer?
    /// Timer.tolerance 比例（能耗友好；不绑 60Hz frame pump）。
    public var toleranceRatio: TimeInterval = 0.25

    public init() {}

    public var isRunning: Bool { timer != nil }

    public func start(interval: TimeInterval, fire: @escaping () -> Void) {
        stop()
        let timer = Timer(timeInterval: interval, repeats: true) { _ in
            fire()
        }
        timer.tolerance = max(0, interval * toleranceRatio)
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    public func stop() {
        timer?.invalidate()
        timer = nil
    }
}

/// 测试调度器：手动 tick；记录 start/stop。
public final class FakeHotCornerScheduler: HotCornerScheduling {
    public private(set) var isRunning = false
    public private(set) var interval: TimeInterval?
    public private(set) var startCount = 0
    public private(set) var stopCount = 0
    private var fireHandler: (() -> Void)?

    public init() {}

    public func start(interval: TimeInterval, fire: @escaping () -> Void) {
        self.interval = interval
        self.fireHandler = fire
        if !isRunning {
            startCount += 1
        }
        isRunning = true
    }

    public func stop() {
        if isRunning {
            stopCount += 1
        }
        isRunning = false
        fireHandler = nil
    }

    public func tick() {
        fireHandler?()
    }
}

/// 测试指针定位。
public final class FakeHotCornerPointerLocator: HotCornerPointerLocating {
    public var point: LauncherPoint

    public init(point: LauncherPoint = LauncherPoint(x: 0, y: 0)) {
        self.point = point
    }

    public func currentPointer() -> LauncherPoint { point }
}

/// 测试几何提供。
public final class FakeHotCornerGeometryProvider: HotCornerGeometryProviding {
    public var geometry: ScreenGeometrySnapshot

    public init(geometry: ScreenGeometrySnapshot) {
        self.geometry = geometry
    }

    public func currentGeometry() -> ScreenGeometrySnapshot { geometry }
}

// MARK: - Monitor

/// Hot Corner 监视器：把采样喂入纯状态机；触发时只回调 show。
public final class HotCornerMonitor {
    public private(set) var configuration: HotCornerMonitorConfiguration
    public private(set) var machine: HotCornerStateMachine
    public private(set) var isEnabled: Bool = false
    public private(set) var isSuspended: Bool = false

    /// show 回调（corner + 触发屏 ScreenID）；永不 hide。
    public var onShowRequested: ((HotCorner, ScreenID) -> Void)?

    /// 中性计数（允许记录）。
    public private(set) var pollCount: Int = 0
    public private(set) var showDeliveryCount: Int = 0

    private let pointerLocator: HotCornerPointerLocating
    private let geometryProvider: HotCornerGeometryProviding
    private let scheduler: HotCornerScheduling
    private let clock: HotCornerClock

    public init(
        configuration: HotCornerMonitorConfiguration = .productDefaults,
        clock: HotCornerClock = HotCornerSystemClock(),
        pointerLocator: HotCornerPointerLocating,
        geometryProvider: HotCornerGeometryProviding,
        scheduler: HotCornerScheduling
    ) {
        self.configuration = configuration
        self.clock = clock
        self.pointerLocator = pointerLocator
        self.geometryProvider = geometryProvider
        self.scheduler = scheduler
        self.machine = HotCornerStateMachine(
            parameters: configuration.parameters,
            clock: clock,
            geometry: nil
        )
    }

    /// 调度器是否在跑（disabled/suspended 时必须为 false）。
    public var isPolling: Bool { scheduler.isRunning }

    // MARK: Enable / disable

    /// 用户显式选择 corner 后启用；启动低频轮询。
    public func enable(corner: HotCorner) {
        isEnabled = true
        rebuildGeometry()
        machine.enable(corner: corner)
        if !isSuspended {
            startPollingIfNeeded()
        }
    }

    /// 禁用：停 timer、状态机 disabled。幂等。
    public func disable() {
        isEnabled = false
        stopPolling()
        machine.disable()
    }

    /// teardown 别名（停轮询 + disabled）。
    public func teardown() {
        disable()
        onShowRequested = nil
    }

    /// 更新参数（保持启用状态；下一 tick 起生效）。
    public func updateConfiguration(_ configuration: HotCornerMonitorConfiguration) {
        self.configuration = configuration
        machine.parameters = configuration.parameters
        if isPolling {
            // 重启以应用新 interval。
            stopPolling()
            startPollingIfNeeded()
        }
    }

    // MARK: Session / launcher

    /// sleep / session inactive / 屏幕重配 → 挂起（停轮询 + 取消 dwell）。
    public func suspend(reason: LauncherSuspensionReason) {
        isSuspended = true
        stopPolling()
        machine.suspend(reason: reason)
    }

    /// 唤醒 / session active：重建几何 + 要求重新离开/进入；若仍启用则恢复轮询。
    public func resume() {
        guard isSuspended else { return }
        isSuspended = false
        rebuildGeometry()
        machine.resume()
        if isEnabled {
            startPollingIfNeeded()
        }
    }

    /// 屏幕几何变化：原子替换 + 取消旧 dwell（状态机已编码）；不改变挂起标志。
    public func screensDidChange() {
        rebuildGeometry()
        // updateGeometry 已取消 insideCandidate；若 suspended 保持 suspended。
        if case .suspended = machine.state {
            return
        }
    }

    /// launcher 可见时暂停触发（状态机内）；隐藏时重置 dwell 起点。
    public func setLauncherVisible(_ visible: Bool) {
        machine.setLauncherVisible(visible)
    }

    /// 鼠标按键/drag 抑制（由接线层可选接入）。
    public func setInputSuppressed(_ suppressed: Bool) {
        machine.setInputSuppressed(suppressed)
    }

    // MARK: Poll

    /// 单次采样（测试可直接调用；生产由 scheduler 驱动）。
    @discardableResult
    public func pollOnce() -> [HotCornerEvent] {
        guard isEnabled, !isSuspended else { return [] }
        pollCount += 1
        let pointer = pointerLocator.currentPointer()
        let events = machine.sample(pointer: pointer)
        for event in events {
            switch event {
            case .showRequested(let corner, let screenID):
                showDeliveryCount += 1
                onShowRequested?(corner, screenID)
            }
        }
        return events
    }

    // MARK: Private

    private func rebuildGeometry() {
        let snapshot = geometryProvider.currentGeometry()
        machine.updateGeometry(snapshot)
    }

    private func startPollingIfNeeded() {
        guard isEnabled, !isSuspended else { return }
        guard !scheduler.isRunning else { return }
        scheduler.start(interval: configuration.pollInterval) { [weak self] in
            self?.pollOnce()
        }
    }

    private func stopPolling() {
        if scheduler.isRunning {
            scheduler.stop()
        }
    }
}
