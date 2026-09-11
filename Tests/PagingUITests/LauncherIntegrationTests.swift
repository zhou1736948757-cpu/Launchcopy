//
//  LauncherIntegrationTests.swift
//  PagingUITests
//
//  Phase 1G T-1G-E：驻留 launcher 组合根集成测试（fakes；无真实 trackpad / 热键）。
//  - blank/hide 不 terminate
//  - quit → terminating + activation teardown once
//  - hot corner show while hidden
//  - shortcut toggle show/hide
//  - four-finger process+flush 每 token 一次 present
//  - last-window-closed policy false
//

import AppKit
import XCTest
@testable import PagingPrototypeApp

@MainActor
final class LauncherIntegrationTests: XCTestCase {

    private let screenA = ScreenID(index: 0)
    private var compositions: [ActivationComposition] = []

    override func tearDown() {
        for composition in compositions {
            composition.teardownActivationServices()
            if composition.launcher.coordinator.teardownCount == 0 {
                _ = composition.launcher.terminate()
            }
        }
        compositions.removeAll()
        super.tearDown()
    }

    // MARK: - Harness

    private struct Harness {
        let launcher: LauncherWindowController
        let composition: ActivationComposition
        let shortcut: FakeGlobalShortcutRegistrar
        let scheduler: FakeHotCornerScheduler
        let pointer: FakeHotCornerPointerLocator
        let hotCornerClock: HotCornerTestClock
        let session: FakeWorkspaceSessionObserver
        let clock: FakePinchClock
    }

    private func makeHarness(
        reduceMotion: Bool = true
    ) -> Harness {
        let launcher = LauncherWindowController(
            reduceMotionProvider: { reduceMotion },
            screenFrameProvider: { _ in NSRect(x: 0, y: 0, width: 800, height: 600) }
        )
        launcher.presentDuration = 0
        launcher.dismissDuration = 0

        let shortcut = FakeGlobalShortcutRegistrar()
        shortcut.fireDebounce = 0 // 测试关闭防抖，允许连续 toggle
        let scheduler = FakeHotCornerScheduler()
        let pointer = FakeHotCornerPointerLocator(point: LauncherPoint(x: 5, y: 895))
        let geometry = FakeHotCornerGeometryProvider(
            geometry: ScreenGeometrySnapshot(screens: [
                ScreenGeometrySnapshot.Screen(
                    id: screenA,
                    frame: LauncherRect(
                        origin: LauncherPoint(x: 0, y: 0),
                        size: LauncherSize(width: 1440, height: 900)
                    ),
                    scale: 2
                )
            ])
        )
        let hotCornerClock = HotCornerTestClock()
        let hotCorner = HotCornerMonitor(
            configuration: HotCornerMonitorConfiguration(
                parameters: HotCornerParameters(
                    zoneSize: 10,
                    dwellDuration: 0.01,
                    hysteresisInset: 2,
                    cooldown: 0
                ),
                pollInterval: 0.05
            ),
            clock: hotCornerClock,
            pointerLocator: pointer,
            geometryProvider: geometry,
            scheduler: scheduler
        )
        let session = FakeWorkspaceSessionObserver()
        let clock = FakePinchClock()
        let composition = ActivationComposition(
            launcher: launcher,
            shortcutRegistrar: shortcut,
            hotCornerMonitor: hotCorner,
            sessionObserver: session,
            pinchClock: clock,
            onRequestTerminate: {}
        )
        compositions.append(composition)
        return Harness(
            launcher: launcher,
            composition: composition,
            shortcut: shortcut,
            scheduler: scheduler,
            pointer: pointer,
            hotCornerClock: hotCornerClock,
            session: session,
            clock: clock
        )
    }

    private func presentHiddenReady(_ h: Harness) {
        _ = h.launcher.show(source: .initialLaunch, targetScreen: screenA)
        XCTAssertEqual(h.launcher.coordinator.state, .visible(screenID: screenA))
        _ = h.composition.hide(source: .statusItem, reason: .statusItem)
        XCTAssertEqual(h.launcher.coordinator.state, .hidden)
    }

    // MARK: - Policy

    func testTerminateAfterLastWindowClosedPolicyIsFalse() {
        XCTAssertFalse(LauncherResidentPolicy.terminateAfterLastWindowClosed)
        // AppDelegate 必须返回同一常量（抽取后可直接断言，无需启动 NSApp）。
        let delegate = AppDelegate(options: .default)
        XCTAssertFalse(delegate.applicationShouldTerminateAfterLastWindowClosed(NSApplication.shared))
    }

    // MARK: - Hide vs terminate

    func testBlankHideDoesNotRequestTerminate() {
        let h = makeHarness()
        _ = h.launcher.show(source: .initialLaunch, targetScreen: screenA)
        XCTAssertEqual(h.launcher.coordinator.state, .visible(screenID: screenA))

        let effect = h.composition.handleBackgroundClick()
        XCTAssertEqual(h.composition.terminateRequestCount, 0)
        XCTAssertNotEqual(effect, .terminate)
        XCTAssertNotEqual(effect, .teardown)
        switch h.launcher.coordinator.state {
        case .hidden, .dismissing:
            break
        default:
            XCTFail("expected hidden/dismissing after blank hide, got \(h.launcher.coordinator.state)")
        }
        XCTAssertEqual(h.launcher.coordinator.teardownCount, 0)
        XCTAssertFalse(h.launcher.isTornDown)
    }

    func testQuitSetsTerminatingAndTeardownOnce() {
        let h = makeHarness()
        _ = h.launcher.show(source: .initialLaunch, targetScreen: screenA)

        h.composition.handleQuit()
        XCTAssertEqual(h.launcher.coordinator.state, .terminating)
        XCTAssertEqual(h.launcher.coordinator.teardownCount, 1)
        XCTAssertEqual(h.composition.activationTeardownCount, 1)
        XCTAssertEqual(h.composition.terminateRequestCount, 1)

        // 再入幂等：不重复激活 teardown / 不重复 terminate 请求。
        h.composition.handleQuit()
        XCTAssertEqual(h.composition.activationTeardownCount, 1)
        XCTAssertEqual(h.launcher.coordinator.teardownCount, 1)
        XCTAssertEqual(h.composition.terminateRequestCount, 1)
    }

    func testApplicationWillTerminateWithoutPriorQuitStillTeardownsOnce() {
        let h = makeHarness()
        _ = h.launcher.show(source: .initialLaunch, targetScreen: screenA)
        h.composition.handleApplicationWillTerminate()
        XCTAssertEqual(h.launcher.coordinator.state, .terminating)
        XCTAssertEqual(h.launcher.coordinator.teardownCount, 1)
        XCTAssertEqual(h.composition.activationTeardownCount, 1)
        // willTerminate 路径不经 onRequestTerminate（进程已在退出）。
        XCTAssertEqual(h.composition.terminateRequestCount, 0)
    }

    // MARK: - Hot corner

    func testHotCornerShowWhileHiddenPresents() {
        let h = makeHarness()
        presentHiddenReady(h)

        var prefs = ActivationPreferences()
        prefs.settings.hotCornerEnabled = true
        prefs.settings.selectedCorner = .topLeft
        prefs.fourFingerActivationEnabled = false
        h.composition.applyPreferences(prefs)

        XCTAssertTrue(h.scheduler.isRunning, "enabled hot corner must start poll timer")
        XCTAssertEqual(h.launcher.coordinator.state, .hidden)

        // 指针已在 topLeft 区；enter → dwell → show。
        _ = h.composition.hotCornerMonitor.pollOnce()
        h.hotCornerClock.advance(0.02)
        _ = h.composition.hotCornerMonitor.pollOnce()

        switch h.launcher.coordinator.state {
        case .presenting(_, let screen), .visible(let screen):
            XCTAssertEqual(screen, screenA)
        default:
            XCTFail("hot corner should present while hidden, got \(h.launcher.coordinator.state)")
        }
        XCTAssertEqual(h.composition.terminateRequestCount, 0)
    }

    // MARK: - Shortcut toggle

    func testShortcutToggleShowAndHide() {
        let h = makeHarness()
        presentHiddenReady(h)

        let spec = ShortcutSpec(keyCode: 0x31, modifiers: [.command, .option]) // Space-ish
        var prefs = ActivationPreferences()
        prefs.settings.globalShortcutEnabled = true
        prefs.settings.shortcut = spec
        prefs.fourFingerActivationEnabled = false
        h.composition.applyPreferences(prefs)

        XCTAssertTrue(h.shortcut.registration.isConfigured)
        XCTAssertEqual(h.shortcut.registerCallCount, 1)

        h.shortcut.simulateFire()
        switch h.launcher.coordinator.state {
        case .presenting, .visible:
            break
        default:
            XCTFail("shortcut toggle from hidden should show, got \(h.launcher.coordinator.state)")
        }

        // 完成 present（RM 时长 0 已 complete）；若仍 presenting，手动 complete。
        if case .presenting(let requestID, _) = h.launcher.coordinator.state {
            _ = h.launcher.completeTransition(requestID: requestID)
        }
        XCTAssertEqual(h.launcher.coordinator.state, .visible(screenID: screenA))

        h.shortcut.simulateFire()
        switch h.launcher.coordinator.state {
        case .dismissing, .hidden:
            break
        default:
            XCTFail("shortcut toggle from visible should hide, got \(h.launcher.coordinator.state)")
        }
        XCTAssertEqual(h.composition.terminateRequestCount, 0)
    }

    // MARK: - Four-finger process + flush

    func testFourFingerProcessFlushPresentsOncePerToken() {
        let h = makeHarness()
        presentHiddenReady(h)

        let mock = MockTouchProvider(clock: h.clock, deliveryMode: .synchronous)
        mock.startupState = .ready
        h.composition.attachTouchProvider(mock, userEnabled: true)

        XCTAssertNotNil(h.composition.fourFinger)
        XCTAssertEqual(mock.state, .ready)

        let device = PinchDeviceID(rawValue: 1)
        // 标准四指收缩：began → moved 基线 → moved 收缩触发。
        let frames: [PinchFrame] = [
            frame(device, 0, .began, squareContacts(halfSize: 0.2)),
            frame(device, 0.1, .moved, squareContacts(halfSize: 0.2)),
            frame(device, 0.11, .moved, squareContacts(halfSize: 0.16)),
        ]
        var effects: [LauncherPresentationEffect] = []
        for f in frames {
            h.clock.current = f.timestamp
            effects.append(contentsOf: h.composition.processFourFingerFrame(f))
        }

        let presents = effects.filter {
            if case .present(_, _, .fourFingerPinch) = $0 { return true }
            return false
        }
        XCTAssertEqual(presents.count, 1, "同一手势 token 只 present 一次")
        switch h.launcher.coordinator.state {
        case .presenting(_, let screen), .visible(let screen):
            XCTAssertEqual(screen, screenA)
        default:
            XCTFail("four-finger flush should present on launcher, got \(h.launcher.coordinator.state)")
        }
        XCTAssertEqual(h.composition.fourFinger?.showCount, 1)
        XCTAssertEqual(h.composition.terminateRequestCount, 0)

        // 重复 flush 空队列 → 无第二 present。
        let again = h.composition.processFourFingerFrame(
            frame(device, 0.12, .moved, squareContacts(halfSize: 0.16))
        )
        let morePresents = again.filter {
            if case .present = $0 { return true }
            return false
        }
        XCTAssertEqual(morePresents.count, 0)
        XCTAssertEqual(h.composition.fourFinger?.showCount, 1)
    }

    func testDefaultsKeepShortcutAndHotCornerOff() {
        let h = makeHarness()
        let prefs = ActivationPreferences() // fourFinger default true；其余 Off
        h.composition.applyPreferences(prefs)
        XCTAssertFalse(h.shortcut.registration.isConfigured)
        XCTAssertEqual(h.shortcut.registerCallCount, 0)
        XCTAssertFalse(h.composition.hotCornerMonitor.isEnabled)
        XCTAssertFalse(h.scheduler.isRunning)
        XCTAssertTrue(prefs.fourFingerActivationEnabled)
    }
}

// MARK: - Test clock for hot corner dwell

final class HotCornerTestClock: HotCornerClock {
    nonisolated(unsafe) var current: TimeInterval = 0
    func now() -> TimeInterval { current }
    func advance(_ delta: TimeInterval) { current += delta }
}
