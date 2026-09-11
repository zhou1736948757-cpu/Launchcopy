//
//  HotCornerMonitorTests.swift
//  PagingUITests
//
//  Phase 1G T-1G-D：HotCornerMonitor 适配器验收。
//  disabled 零 timer；dwell 触发一次 show；离开取消；suspend 停轮询；
//  resume 需重新进入；session bridge；不记录坐标字符串。
//

import XCTest
@testable import PagingPrototypeApp

final class HotCornerMonitorTests: XCTestCase {

    private final class FakeClock: HotCornerClock {
        nonisolated(unsafe) var current: TimeInterval = 0
        func now() -> TimeInterval { current }
        func advance(_ delta: TimeInterval) { current += delta }
    }

    private let zoneSize = 20.0
    private let dwell: TimeInterval = 0.5
    private let hysteresis = 10.0
    private let cooldown: TimeInterval = 2.0
    private let pollInterval: TimeInterval = 0.075

    private let insideTopLeft = LauncherPoint(x: 5, y: 795)
    private let outsideAll = LauncherPoint(x: 500, y: 400)

    private func geometry() -> ScreenGeometrySnapshot {
        ScreenGeometrySnapshot(screens: [
            ScreenGeometrySnapshot.Screen(
                id: ScreenID(index: 0),
                frame: LauncherRect(
                    origin: LauncherPoint(x: 0, y: 0),
                    size: LauncherSize(width: 1000, height: 800)
                ),
                scale: 1.0
            ),
        ])
    }

    private func makeMonitor(
        clock: FakeClock,
        pointer: FakeHotCornerPointerLocator,
        scheduler: FakeHotCornerScheduler,
        geometryProvider: FakeHotCornerGeometryProvider? = nil
    ) -> HotCornerMonitor {
        let config = HotCornerMonitorConfiguration(
            parameters: HotCornerParameters(
                zoneSize: zoneSize,
                dwellDuration: dwell,
                hysteresisInset: hysteresis,
                cooldown: cooldown
            ),
            pollInterval: pollInterval
        )
        return HotCornerMonitor(
            configuration: config,
            clock: clock,
            pointerLocator: pointer,
            geometryProvider: geometryProvider ?? FakeHotCornerGeometryProvider(geometry: geometry()),
            scheduler: scheduler
        )
    }

    // MARK: Disabled = zero timer

    func testDisabledZeroTimerZeroPolling() {
        let clock = FakeClock()
        let pointer = FakeHotCornerPointerLocator(point: insideTopLeft)
        let scheduler = FakeHotCornerScheduler()
        let monitor = makeMonitor(clock: clock, pointer: pointer, scheduler: scheduler)

        XCTAssertFalse(monitor.isEnabled)
        XCTAssertFalse(monitor.isPolling)
        XCTAssertEqual(scheduler.startCount, 0)
        XCTAssertEqual(monitor.pollOnce(), [])
        XCTAssertEqual(monitor.pollCount, 0)
        XCTAssertEqual(monitor.showDeliveryCount, 0)
    }

    // MARK: Enable starts polling; dwell triggers once

    func testEnableStartsPollingAndDwellTriggersShowOnce() {
        let clock = FakeClock()
        let pointer = FakeHotCornerPointerLocator(point: outsideAll)
        let scheduler = FakeHotCornerScheduler()
        let monitor = makeMonitor(clock: clock, pointer: pointer, scheduler: scheduler)

        var shows: [(HotCorner, ScreenID)] = []
        monitor.onShowRequested = { corner, screen in
            shows.append((corner, screen))
        }

        monitor.enable(corner: .topLeft)
        XCTAssertTrue(monitor.isEnabled)
        XCTAssertTrue(monitor.isPolling)
        XCTAssertEqual(scheduler.startCount, 1)
        XCTAssertEqual(scheduler.interval, pollInterval)

        // 先在区外，再进入
        scheduler.tick()
        pointer.point = insideTopLeft
        scheduler.tick()
        XCTAssertEqual(shows.count, 0, "刚进入不应立即触发")

        clock.advance(dwell)
        scheduler.tick()
        XCTAssertEqual(shows.count, 1)
        XCTAssertEqual(shows[0].0, .topLeft)
        XCTAssertEqual(shows[0].1, ScreenID(index: 0))
        XCTAssertEqual(monitor.showDeliveryCount, 1)

        // 仍在区内：不重复 show
        clock.advance(0.1)
        scheduler.tick()
        XCTAssertEqual(shows.count, 1)
    }

    // MARK: Leave before dwell cancels

    func testLeaveBeforeDwellCancels() {
        let clock = FakeClock()
        let pointer = FakeHotCornerPointerLocator(point: insideTopLeft)
        let scheduler = FakeHotCornerScheduler()
        let monitor = makeMonitor(clock: clock, pointer: pointer, scheduler: scheduler)

        var shows = 0
        monitor.onShowRequested = { _, _ in shows += 1 }
        monitor.enable(corner: .topLeft)

        scheduler.tick() // enter candidate
        clock.advance(dwell * 0.4)
        pointer.point = outsideAll
        scheduler.tick() // leave → cancel
        clock.advance(dwell)
        pointer.point = insideTopLeft
        scheduler.tick() // re-enter, new dwell
        XCTAssertEqual(shows, 0)
        clock.advance(dwell - 0.01)
        scheduler.tick()
        XCTAssertEqual(shows, 0)
        clock.advance(0.02)
        scheduler.tick()
        XCTAssertEqual(shows, 1)
    }

    // MARK: Suspend stops polling

    func testSuspendStopsPollingAndResumeRequiresReEnter() {
        let clock = FakeClock()
        let pointer = FakeHotCornerPointerLocator(point: insideTopLeft)
        let scheduler = FakeHotCornerScheduler()
        let monitor = makeMonitor(clock: clock, pointer: pointer, scheduler: scheduler)

        var shows = 0
        monitor.onShowRequested = { _, _ in shows += 1 }
        monitor.enable(corner: .topLeft)
        XCTAssertTrue(monitor.isPolling)

        scheduler.tick() // enter
        clock.advance(dwell * 0.2)
        monitor.suspend(reason: .sleep)
        XCTAssertTrue(monitor.isSuspended)
        XCTAssertFalse(monitor.isPolling)
        XCTAssertEqual(scheduler.stopCount, 1)

        // suspended 期间 tick 无效（scheduler 已 stop；即便直接 pollOnce 也应空）
        clock.advance(dwell)
        XCTAssertEqual(monitor.pollOnce(), [])
        XCTAssertEqual(shows, 0)

        // resume：仍在区内，但 requiresExitBeforeDwell → 不立即触发
        monitor.resume()
        XCTAssertFalse(monitor.isSuspended)
        XCTAssertTrue(monitor.isPolling)
        scheduler.tick()
        XCTAssertEqual(shows, 0)

        pointer.point = outsideAll
        scheduler.tick() // 离开清除标记
        pointer.point = insideTopLeft
        scheduler.tick()
        clock.advance(dwell)
        scheduler.tick()
        XCTAssertEqual(shows, 1)
    }

    // MARK: Session bridge

    func testWorkspaceSessionBridgeSuspendAndWake() {
        let clock = FakeClock()
        let pointer = FakeHotCornerPointerLocator(point: outsideAll)
        let scheduler = FakeHotCornerScheduler()
        let monitor = makeMonitor(clock: clock, pointer: pointer, scheduler: scheduler)
        monitor.enable(corner: .topLeft)
        XCTAssertTrue(monitor.isPolling)

        let observer = FakeWorkspaceSessionObserver()
        observer.onEvent = { event in
            WorkspaceSessionHotCornerBridge.apply(event, to: monitor)
        }
        observer.start()

        observer.post(.willSleep)
        XCTAssertTrue(monitor.isSuspended)
        XCTAssertFalse(monitor.isPolling)

        observer.post(.didWake)
        XCTAssertFalse(monitor.isSuspended)
        XCTAssertTrue(monitor.isPolling)

        observer.post(.sessionResigned)
        XCTAssertTrue(monitor.isSuspended)
        observer.post(.sessionActivated)
        XCTAssertFalse(monitor.isSuspended)
    }

    // MARK: Disable stops timer

    func testDisableStopsTimer() {
        let clock = FakeClock()
        let pointer = FakeHotCornerPointerLocator(point: outsideAll)
        let scheduler = FakeHotCornerScheduler()
        let monitor = makeMonitor(clock: clock, pointer: pointer, scheduler: scheduler)
        monitor.enable(corner: .bottomRight)
        XCTAssertTrue(monitor.isPolling)
        monitor.disable()
        XCTAssertFalse(monitor.isEnabled)
        XCTAssertFalse(monitor.isPolling)
        XCTAssertEqual(monitor.machine.state, .disabled)
    }

    // MARK: Screens change cancels dwell via monitor

    func testScreensDidChangeCancelsDwell() {
        let clock = FakeClock()
        let pointer = FakeHotCornerPointerLocator(point: insideTopLeft)
        let scheduler = FakeHotCornerScheduler()
        let geo = FakeHotCornerGeometryProvider(geometry: geometry())
        let monitor = makeMonitor(clock: clock, pointer: pointer, scheduler: scheduler, geometryProvider: geo)

        var shows = 0
        monitor.onShowRequested = { _, _ in shows += 1 }
        monitor.enable(corner: .topLeft)
        scheduler.tick()
        XCTAssertEqual(monitor.machine.state,
                       .insideCandidate(corner: .topLeft, screenID: ScreenID(index: 0), enteredAt: 0))

        // 几何替换（同内容也触发 updateGeometry → armed）
        geo.geometry = geometry()
        monitor.screensDidChange()
        XCTAssertEqual(monitor.machine.state, .armed)
        clock.advance(dwell)
        scheduler.tick()
        // 仍在区内：重新进入 candidate，但未满 dwell
        XCTAssertEqual(shows, 0)
    }

    // MARK: Product defaults stay Off until enable

    func testProductDefaultsDoNotAutoStart() {
        let scheduler = FakeHotCornerScheduler()
        let monitor = HotCornerMonitor(
            configuration: .productDefaults,
            clock: FakeClock(),
            pointerLocator: FakeHotCornerPointerLocator(),
            geometryProvider: FakeHotCornerGeometryProvider(geometry: geometry()),
            scheduler: scheduler
        )
        XCTAssertFalse(monitor.isEnabled)
        XCTAssertFalse(monitor.isPolling)
        XCTAssertEqual(scheduler.startCount, 0)
        XCTAssertEqual(HotCornerMonitorConfiguration.productDefaults.pollInterval, 0.075, accuracy: 0.0001)
    }
}
