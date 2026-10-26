//
//  LauncherWindowControllerTests.swift
//  PagingUITests
//
//  Phase 1G T-1G-B：LauncherWindowController 生命周期验收。
//  present→visible；dismiss→hidden；stale completeTransition no-op；show while visible 幂等；
//  teardown once；Reduce Motion 仍 complete；screen fallback 确定性。
//

import AppKit
import XCTest
@testable import PagingPrototypeApp

@MainActor
private final class BackgroundUITestWindow: NSWindow {
    private(set) var keyAndFrontRequests = 0
    private(set) var backRequests = 0
    override func makeKeyAndOrderFront(_ sender: Any?) {
        keyAndFrontRequests += 1
        super.makeKeyAndOrderFront(sender)
    }
    override func orderBack(_ sender: Any?) {
        backRequests += 1
        super.orderBack(sender)
    }
}

@MainActor
final class LauncherWindowControllerTests: XCTestCase {

    private let screenA = ScreenID(index: 0)
    private let screenMissing = ScreenID(index: 99)

    private var controllers: [LauncherWindowController] = []

    override func tearDown() {
        for controller in controllers {
            if !controller.isTornDown {
                _ = controller.terminate()
            }
        }
        controllers.removeAll()
        super.tearDown()
    }

    // MARK: - Helpers

    private func makeController(
        reduceMotion: Bool = true,
        frames: [Int: NSRect] = [0: NSRect(x: 10, y: 20, width: 800, height: 600)]
    ) -> LauncherWindowController {
        let fallback = NSRect(x: 100, y: 200, width: 1024, height: 768)
        let controller = LauncherWindowController(
            reduceMotionProvider: { reduceMotion },
            screenFrameProvider: { id in
                frames[id.index] ?? fallback
            }
        )
        // RM 路径时长为 0；非 RM 测试将 duration 压到极短并 spin RunLoop。
        controller.presentDuration = 0.02
        controller.dismissDuration = 0.02
        controllers.append(controller)
        return controller
    }

    private func spinRunLoop(for seconds: TimeInterval = 0.05) {
        RunLoop.current.run(until: Date().addingTimeInterval(seconds))
    }

    // MARK: - present → visible complete

    func testBackgroundUIModePreservesFrameAndDoesNotRequestKeyOrHideChrome() {
        _ = NSApplication.shared
        let originalChrome = NSApp.presentationOptions
        let controller = makeController(reduceMotion: false)
        XCTAssertFalse(controller.backgroundUITestMode)
        controller.backgroundUITestMode = true
        let window = BackgroundUITestWindow(
            contentRect: NSRect(x: 40, y: 80, width: 700, height: 500),
            styleMask: [.titled, .closable, .resizable], backing: .buffered, defer: false
        )
        window.contentView = NSView(frame: window.contentLayoutRect)
        window.isReleasedWhenClosed = false
        let originalFrame = window.frame
        controller.attach(window: window)
        _ = controller.show(source: .testHarness, targetScreen: screenA)
        XCTAssertEqual(window.frame, originalFrame)
        XCTAssertTrue(window.styleMask.contains(.titled))
        XCTAssertFalse(window.styleMask.contains(.fullScreen))
        XCTAssertEqual(window.collectionBehavior, [])
        XCTAssertEqual(window.level, .normal)
        XCTAssertEqual(window.keyAndFrontRequests, 0)
        XCTAssertEqual(window.backRequests, 1)
        XCTAssertEqual(NSApp.presentationOptions, originalChrome)
        XCTAssertEqual(window.contentView?.frame.size, window.contentLayoutRect.size)
        XCTAssertEqual(controller.coordinator.activeRequestID, 0)

        _ = controller.hide(source: .testHarness, reason: .escape)
        XCTAssertFalse(window.isVisible)
        let resized = NSRect(x: 100, y: 120, width: 720, height: 540)
        window.setFrame(resized, display: false)
        _ = controller.show(source: .testHarness, targetScreen: screenA)
        XCTAssertEqual(window.frame, resized)
        XCTAssertEqual(window.keyAndFrontRequests, 0)
        XCTAssertEqual(window.backRequests, 2)
        XCTAssertEqual(NSApp.presentationOptions, originalChrome)
    }

    func testPresentBecomesVisibleAndCoversTargetFrame() {
        let controller = makeController(reduceMotion: true)
        let effect = controller.show(source: .initialLaunch, targetScreen: screenA)
        XCTAssertEqual(
            effect,
            .present(requestID: 1, targetScreen: screenA, source: .initialLaunch)
        )
        XCTAssertEqual(controller.coordinator.state, .visible(screenID: screenA))
        XCTAssertEqual(controller.coordinator.activeRequestID, 0)
        XCTAssertNotNil(controller.window)
        XCTAssertEqual(controller.window?.frame, NSRect(x: 10, y: 20, width: 800, height: 600))
        XCTAssertTrue(controller.window?.styleMask.contains(.borderless) == true)
        XCTAssertFalse(controller.window?.styleMask.contains(.fullScreen) == true)
        XCTAssertTrue(controller.window?.isVisible == true)
    }

    // MARK: - dismiss → hidden complete

    func testDismissHidesWithoutDestroyingWindow() {
        let controller = makeController(reduceMotion: true)
        _ = controller.show(source: .statusItem, targetScreen: screenA)
        XCTAssertEqual(controller.coordinator.state, .visible(screenID: screenA))
        let windowBefore = controller.window

        let effect = controller.hide(source: .statusItem, reason: .statusItem)
        XCTAssertEqual(
            effect,
            .dismiss(requestID: 2, reason: .statusItem, source: .statusItem)
        )
        XCTAssertEqual(controller.coordinator.state, .hidden)
        XCTAssertTrue(controller.window === windowBefore, "hide 必须复用同一 assembly")
        XCTAssertFalse(controller.window?.isVisible ?? true, "dismiss 后窗口应 orderOut")
        XCTAssertFalse(controller.isTornDown)
    }

    // MARK: - stale completeTransition no-op

    func testStaleCompleteTransitionIsNoOp() {
        let controller = makeController(reduceMotion: true)
        _ = controller.show(source: .hotCorner, targetScreen: screenA)
        XCTAssertEqual(controller.coordinator.state, .visible(screenID: screenA))

        // 模拟旧动画回调经控制器入口提交陈旧 requestID。
        let stale = controller.completeTransition(requestID: 999)
        XCTAssertEqual(stale, .none)
        XCTAssertEqual(controller.coordinator.state, .visible(screenID: screenA))
    }

    func testInterruptPresentWithDismissCompletesOnlyNewRequest() {
        // 非 RM：present 动画尚未完成时 hide 中断；旧 completion 不得覆盖。
        let controller = makeController(reduceMotion: false)
        let presentEffect = controller.show(source: .globalShortcut, targetScreen: screenA)
        XCTAssertEqual(presentEffect, .present(requestID: 1, targetScreen: screenA, source: .globalShortcut))
        XCTAssertEqual(controller.coordinator.state, .presenting(requestID: 1, targetScreen: screenA))

        let dismissEffect = controller.hide(source: .globalShortcut, reason: .globalShortcut)
        XCTAssertEqual(
            dismissEffect,
            .dismiss(requestID: 2, reason: .globalShortcut, source: .globalShortcut)
        )

        // 中断路径现为同步 complete（duration→0）；仍轮询以防回归为异步动画。
        let deadline = Date().addingTimeInterval(0.5)
        while Date() < deadline {
            if case .hidden = controller.coordinator.state { break }
            RunLoop.current.run(until: Date().addingTimeInterval(0.01))
        }

        XCTAssertEqual(controller.coordinator.state, .hidden)
        XCTAssertEqual(controller.coordinator.activeRequestID, 0)
        XCTAssertFalse(controller.window?.isVisible ?? true)
    }

    // MARK: - show while visible idempotent

    func testShowWhileVisibleIsIdempotentViaController() {
        let controller = makeController(reduceMotion: true)
        _ = controller.show(source: .dockReopen, targetScreen: screenA)
        XCTAssertEqual(controller.coordinator.state, .visible(screenID: screenA))
        let windowBefore = controller.window

        let effect = controller.show(source: .statusItem, targetScreen: ScreenID(index: 1))
        XCTAssertEqual(effect, .none)
        XCTAssertEqual(controller.coordinator.state, .visible(screenID: screenA))
        XCTAssertTrue(controller.window === windowBefore)
        XCTAssertEqual(controller.window?.frame, NSRect(x: 10, y: 20, width: 800, height: 600))
    }

    // MARK: - teardown once

    func testTeardownOnceClearsWindow() {
        let controller = makeController(reduceMotion: true)
        _ = controller.show(source: .testHarness, targetScreen: screenA)
        XCTAssertNotNil(controller.window)

        let first = controller.terminate()
        XCTAssertEqual(first, .teardown)
        XCTAssertTrue(controller.isTornDown)
        XCTAssertNil(controller.window)
        XCTAssertEqual(controller.coordinator.teardownCount, 1)
        XCTAssertEqual(controller.coordinator.state, .terminating)

        let second = controller.terminate()
        XCTAssertEqual(second, .none)
        XCTAssertEqual(controller.coordinator.teardownCount, 1)
    }

    func testQuitThenTerminateTeardownOnce() {
        let controller = makeController(reduceMotion: true)
        _ = controller.show(source: .initialLaunch, targetScreen: screenA)
        let quitEffect = controller.quit()
        XCTAssertEqual(quitEffect, .terminate)
        XCTAssertEqual(controller.coordinator.state, .terminating)
        XCTAssertEqual(controller.coordinator.teardownCount, 0)

        let teardown = controller.terminate()
        XCTAssertEqual(teardown, .teardown)
        XCTAssertEqual(controller.coordinator.teardownCount, 1)
        XCTAssertTrue(controller.isTornDown)
    }

    // MARK: - Reduce Motion path still completes

    func testReduceMotionPresentAndDismissStillComplete() {
        let controller = makeController(reduceMotion: true)
        XCTAssertTrue(controller.reduceMotionProvider())

        _ = controller.show(source: .hotCorner, targetScreen: screenA)
        XCTAssertEqual(controller.coordinator.state, .visible(screenID: screenA))
        XCTAssertEqual(controller.coordinator.activeRequestID, 0)

        let effect = controller.hide(source: .testHarness, reason: .escape)
        XCTAssertEqual(
            effect,
            .dismiss(requestID: 2, reason: .escape, source: .testHarness)
        )
        XCTAssertEqual(controller.coordinator.state, .hidden)
        XCTAssertEqual(controller.coordinator.activeRequestID, 0)
        XCTAssertFalse(controller.isTornDown)
    }

    // MARK: - screen fallback deterministic

    func testScreenFallbackIsDeterministicWhenIndexMissing() {
        let fallback = NSRect(x: 100, y: 200, width: 1024, height: 768)
        let controller = makeController(
            reduceMotion: true,
            frames: [0: NSRect(x: 0, y: 0, width: 800, height: 600)]
        )
        // Provider 层确定性：越界 ScreenID 恒回同一 fallback（不读 UUID/名称）。
        XCTAssertEqual(controller.resolvedScreenFrame(for: screenMissing), fallback)
        XCTAssertEqual(
            controller.resolvedScreenFrame(for: ScreenID(index: 12345)),
            fallback,
            "同一 provider 对任意越界 index 返回同一 fallback"
        )

        _ = controller.show(source: .hotCorner, targetScreen: screenMissing)
        XCTAssertEqual(controller.coordinator.state, .visible(screenID: screenMissing))
        // WindowServer 可能微调 origin（菜单栏等）；尺寸必须覆盖 fallback。
        XCTAssertEqual(controller.window?.frame.size, fallback.size)
    }

    func testDefaultScreenFrameProviderFallbackOrder() {
        // 越界 index：不得崩溃；返回 main/first/合成之一（确定性非空）。
        let frame = LauncherWindowController.defaultScreenFrameProvider(ScreenID(index: 9_999))
        XCTAssertGreaterThan(frame.width, 0)
        XCTAssertGreaterThan(frame.height, 0)
    }

    // MARK: - attach seam preserves content view

    func testAttachReusesHostWindowAndContentView() {
        let host = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 400, height: 300),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        let content = NSView(frame: host.contentLayoutRect)
        host.contentView = content

        let controller = makeController(reduceMotion: true)
        controller.attach(window: host)
        _ = controller.show(source: .initialLaunch, targetScreen: screenA)

        XCTAssertTrue(controller.window === host)
        XCTAssertTrue(host.contentView === content, "attach 不得拆掉宿主内容层次")
        XCTAssertTrue(host.styleMask.contains(.borderless))
        XCTAssertEqual(host.frame, NSRect(x: 10, y: 20, width: 800, height: 600))
    }

    // MARK: - first responder seam

    func testPresentRestoresPreferredFirstResponder() {
        let controller = makeController(reduceMotion: true)
        let window = controller.ensureWindow()
        let responder = NSView(frame: .zero)
        window.contentView?.addSubview(responder)
        controller.preferredFirstResponder = responder

        _ = controller.show(source: .initialLaunch, targetScreen: screenA)
        XCTAssertTrue(window.firstResponder === responder)
    }

    // MARK: - suspend hides without teardown

    func testSuspendOrdersOutWithoutTeardown() {
        let controller = makeController(reduceMotion: true)
        _ = controller.show(source: .initialLaunch, targetScreen: screenA)
        let effect = controller.suspend(reason: .sessionInactive)
        XCTAssertEqual(effect, .suspend(reason: .sessionInactive))
        XCTAssertEqual(controller.coordinator.state, .suspended(reason: .sessionInactive))
        XCTAssertFalse(controller.isTornDown)
        XCTAssertNotNil(controller.window)
        XCTAssertFalse(controller.window?.isVisible ?? true)
    }
}
