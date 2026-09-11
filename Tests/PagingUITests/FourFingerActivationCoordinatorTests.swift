//
//  FourFingerActivationCoordinatorTests.swift
//  PagingUITests
//
//  Phase 1G T-G-P4 四指激活接线组件测试：
//  接线（showRequested → coordinator.show(.fourFingerPinch, targetScreen:)）、
//  去重（同一 token 只一次 show）、generation 校验、Q-1（suspend 前排队 show 不重放）、
//  QUESTION-1（重复 ready 幂等）、QUESTION-2（displayKind (enabled:true, state:.off) 组合）、
//  输入交接（fired 后新 show 去重、会话结束优先）、四指永不 hide/quit、
//  provider 状态映射、生命周期转发、LauncherActivationSource 新 case。
//  合成匿名触点夹具（复用 PinchRecognizerTests 共享夹具）；不提交真实触控板轨迹。
//

import XCTest
@testable import PagingPrototypeApp

final class FourFingerActivationCoordinatorTests: XCTestCase {

    private let screenA = ScreenID(index: 0)

    // MARK: - 夹具

    /// 标准接线：启动 + provider ready（cooldown=0 隔离锁存语义）。
    private func makeCoordinator(clock: FakePinchClock,
                                 targetScreen: ScreenID? = nil,
                                 userEnabled: Bool = true) -> FourFingerActivationCoordinator {
        var coordinator = FourFingerActivationCoordinator(
            clock: clock,
            targetScreen: targetScreen ?? screenA,
            parameters: PinchParameters(cooldown: 0),
            userEnabled: userEnabled
        )
        coordinator.start()
        coordinator.handleProviderState(.ready)
        return coordinator
    }

    /// 处理帧并把时钟对齐到帧时间戳（与 processAt 同语义，走 coordinator.process）。
    @discardableResult
    private func processFrame(_ coordinator: inout FourFingerActivationCoordinator,
                              _ clock: FakePinchClock,
                              _ f: PinchFrame) -> [PinchEvent] {
        clock.current = f.timestamp
        return coordinator.process(f)
    }

    /// 标准四指手势触发（返回识别器事件；show 事件已入队）。
    @discardableResult
    private func firePinch(_ coordinator: inout FourFingerActivationCoordinator,
                           _ clock: FakePinchClock,
                           device: PinchDeviceID = PinchDeviceID(rawValue: 1),
                           start: TimeInterval = 0) -> [PinchEvent] {
        _ = processFrame(&coordinator, clock, frame(device, start, .began, squareContacts(halfSize: 0.2)))
        _ = processFrame(&coordinator, clock, frame(device, start + 0.1, .moved, squareContacts(halfSize: 0.2)))
        return processFrame(&coordinator, clock, frame(device, start + 0.11, .moved, squareContacts(halfSize: 0.16)))
    }

    // MARK: 接线：showRequested → coordinator.show(.fourFingerPinch)

    func testShowRequestedPresentsWithFourFingerPinchSource() {
        let clock = FakePinchClock()
        var coordinator = makeCoordinator(clock: clock)
        let events = firePinch(&coordinator, clock)
        XCTAssertEqual(events.count, 1)
        guard case .showRequested(let token) = events[0] else {
            return XCTFail("expected showRequested")
        }
        XCTAssertEqual(token.generation, coordinator.recognizer.generation)
        XCTAssertEqual(coordinator.pendingShowTokens, [token], "show 事件已入队")
        let effects = coordinator.flushPendingShows()
        XCTAssertEqual(effects, [.present(requestID: 1, targetScreen: screenA, source: .fourFingerPinch)])
        XCTAssertEqual(coordinator.presentation.state, .presenting(requestID: 1, targetScreen: screenA))
        XCTAssertEqual(coordinator.showCount, 1)
    }

    func testShowUsesInjectedTargetScreen() {
        let clock = FakePinchClock()
        let screenC = ScreenID(index: 3)
        var coordinator = makeCoordinator(clock: clock, targetScreen: screenC)
        _ = firePinch(&coordinator, clock)
        XCTAssertEqual(coordinator.flushPendingShows(),
                       [.present(requestID: 1, targetScreen: screenC, source: .fourFingerPinch)])
    }

    // MARK: 去重：同一 token 只一次 show

    func testSameTokenDeliveredTwiceProducesOneShow() {
        let clock = FakePinchClock()
        var coordinator = makeCoordinator(clock: clock)
        let token = PinchEventToken(generation: 0, sessionID: PinchSessionID(rawValue: 1))
        coordinator.handlePinchEvent(.showRequested(token: token))
        coordinator.handlePinchEvent(.showRequested(token: token))
        let effects = coordinator.flushPendingShows()
        XCTAssertEqual(effects, [.present(requestID: 1, targetScreen: screenA, source: .fourFingerPinch), .none])
        XCTAssertEqual(coordinator.showCount, 1)
        XCTAssertEqual(coordinator.droppedDuplicateEventCount, 1)
    }

    // MARK: generation 校验（§19.3）

    func testStaleGenerationEventDropped() {
        let clock = FakePinchClock()
        var coordinator = makeCoordinator(clock: clock)
        let oldToken = PinchEventToken(generation: 0, sessionID: PinchSessionID(rawValue: 1))
        coordinator.restart() // generation 0 → 1
        XCTAssertEqual(coordinator.recognizer.generation, 1)
        coordinator.handlePinchEvent(.showRequested(token: oldToken))
        XCTAssertEqual(coordinator.flushPendingShows(), [.none])
        XCTAssertEqual(coordinator.droppedStaleEventCount, 1)
        XCTAssertEqual(coordinator.showCount, 0)
    }

    // MARK: Q-1：suspend 前排队 show 不重放

    func testQueuedShowBeforeSuspendNotReplayedAfterResume() {
        let clock = FakePinchClock()
        var coordinator = makeCoordinator(clock: clock)
        _ = firePinch(&coordinator, clock)
        XCTAssertEqual(coordinator.pendingShowTokens.count, 1)
        // suspend 时清队列（Q-1：suspend 不递增识别器 generation，只能靠清队列防重放）
        _ = coordinator.suspend(reason: .sleep)
        XCTAssertTrue(coordinator.pendingShowTokens.isEmpty)
        XCTAssertEqual(coordinator.flushPendingShows(), [])
        XCTAssertEqual(coordinator.presentation.state, .suspended(reason: .sleep))
        XCTAssertEqual(coordinator.showCount, 0)
        // 恢复后：排队事件不得重放
        _ = coordinator.resume()
        XCTAssertEqual(coordinator.flushPendingShows(), [])
        XCTAssertEqual(coordinator.presentation.state, .hidden)
        XCTAssertEqual(coordinator.showCount, 0)
        // 恢复后新手势可正常触发（generation 未变，但队列已清）
        _ = firePinch(&coordinator, clock, start: 2.0)
        XCTAssertEqual(coordinator.flushPendingShows(),
                       [.present(requestID: 1, targetScreen: screenA, source: .fourFingerPinch)])
    }

    func testShowEventWhileSuspendedRejected() {
        let clock = FakePinchClock()
        var coordinator = makeCoordinator(clock: clock)
        _ = coordinator.suspend(reason: .sessionInactive)
        let token = PinchEventToken(generation: 0, sessionID: PinchSessionID(rawValue: 1))
        coordinator.handlePinchEvent(.showRequested(token: token))
        XCTAssertEqual(coordinator.flushPendingShows(), [.none])
        XCTAssertEqual(coordinator.droppedSuspendedEventCount, 1)
        XCTAssertEqual(coordinator.showCount, 0)
    }

    // MARK: QUESTION-1：重复 ready 幂等

    func testRepeatedReadyIsIdempotent() {
        let clock = FakePinchClock()
        var coordinator = makeCoordinator(clock: clock)
        XCTAssertEqual(coordinator.activation.state, .ready)
        let generation = coordinator.recognizer.generation
        let enabled = coordinator.recognizer.isEnabled
        coordinator.handleProviderState(.ready) // 重复上报
        XCTAssertEqual(coordinator.activation.state, .ready, "重复 ready 幂等接受")
        XCTAssertEqual(coordinator.recognizer.generation, generation, "不重启服务（generation 不变）")
        XCTAssertEqual(coordinator.recognizer.isEnabled, enabled, "不重复启动")
        XCTAssertEqual(coordinator.recognizer.fireCount, 0)
    }

    func testRepeatedReadyFromFailureStatesRecovers() {
        let clock = FakePinchClock()
        var coordinator = makeCoordinator(clock: clock)
        coordinator.handleProviderState(.noDevice)
        XCTAssertEqual(coordinator.activation.state, .noDevice)
        coordinator.handleProviderState(.ready) // 恢复
        XCTAssertEqual(coordinator.activation.state, .ready)
        coordinator.handleProviderState(.unavailable)
        coordinator.handleProviderState(.ready)
        XCTAssertEqual(coordinator.activation.state, .ready)
        coordinator.handleProviderState(.permissionNotConfirmed)
        coordinator.handleProviderState(.ready)
        XCTAssertEqual(coordinator.activation.state, .ready)
    }

    // MARK: QUESTION-2：displayKind (enabled:true, state:.off) 组合

    func testDisplayKindEnabledOffCombinationIsDisabled() {
        let clock = FakePinchClock()
        // 未启动：activation.state == .off，开关开
        var coordinator = FourFingerActivationCoordinator(clock: clock, targetScreen: screenA, userEnabled: true)
        XCTAssertEqual(coordinator.activation.state, .off)
        XCTAssertEqual(coordinator.displayStatus.displayKind, .disabled,
                       "开关开 + 后端 off → .disabled：后端 off = 无活动，事实展示（不冒充就绪）")
        XCTAssertFalse(coordinator.isReady)
        // 对照：开关关 + 后端 ready → .disabled
        coordinator.start()
        coordinator.handleProviderState(.ready)
        coordinator.userEnabled = false
        XCTAssertEqual(coordinator.displayStatus.displayKind, .disabled)
        XCTAssertFalse(coordinator.isReady)
        // 开关开 + 后端 ready → .ready
        coordinator.userEnabled = true
        XCTAssertEqual(coordinator.displayStatus.displayKind, .ready)
        XCTAssertTrue(coordinator.isReady)
    }

    // MARK: 输入交接（§21.1 会话结束优先）

    func testHandoffSuppressesNewShowUntilSessionEnd() {
        let clock = FakePinchClock()
        var coordinator = makeCoordinator(clock: clock)
        // 手势 1 触发 → show
        _ = firePinch(&coordinator, clock, start: 0)
        XCTAssertEqual(coordinator.flushPendingShows(),
                       [.present(requestID: 1, targetScreen: screenA, source: .fourFingerPinch)])
        XCTAssertNotNil(coordinator.handoffToken)
        // 交接期间：另一会话的 show 去重
        let otherToken = PinchEventToken(generation: 0, sessionID: PinchSessionID(rawValue: 99))
        coordinator.handlePinchEvent(.showRequested(token: otherToken))
        XCTAssertEqual(coordinator.flushPendingShows(), [.none])
        XCTAssertEqual(coordinator.droppedHandoffEventCount, 1)
        // 会话结束（全指释放）优先：交接清除
        _ = processFrame(&coordinator, clock, frame(PinchDeviceID(rawValue: 1), 1.0, .moved, []))
        XCTAssertNil(coordinator.handoffToken)
        // 新手势可再次触发（presenting 幂等：effect .none，但已派发——showCount 递增）
        _ = firePinch(&coordinator, clock, start: 2.0)
        XCTAssertEqual(coordinator.flushPendingShows(), [.none])
        XCTAssertEqual(coordinator.showCount, 2)
        XCTAssertEqual(coordinator.presentation.state, .presenting(requestID: 1, targetScreen: screenA),
                       "四指永不反向 hide")
    }

    func testSecondDeviceShowDuringHandoffDropped() {
        let clock = FakePinchClock()
        var coordinator = makeCoordinator(clock: clock)
        let deviceA = PinchDeviceID(rawValue: 1)
        let deviceB = PinchDeviceID(rawValue: 2)
        _ = firePinch(&coordinator, clock, device: deviceA, start: 0)
        XCTAssertEqual(coordinator.flushPendingShows(),
                       [.present(requestID: 1, targetScreen: screenA, source: .fourFingerPinch)])
        // 交接期间：设备 B 触发 → 去重
        _ = firePinch(&coordinator, clock, device: deviceB, start: 0.5)
        XCTAssertEqual(coordinator.flushPendingShows(), [.none])
        XCTAssertEqual(coordinator.droppedHandoffEventCount, 1)
        // 全部会话结束（A 与 B 都释放）→ 交接清除
        _ = processFrame(&coordinator, clock, frame(deviceA, 1.0, .moved, []))
        XCTAssertNotNil(coordinator.handoffToken, "B 仍锁存：交接保持")
        _ = processFrame(&coordinator, clock, frame(deviceB, 1.1, .moved, []))
        XCTAssertNil(coordinator.handoffToken, "全指释放：交接清除")
    }

    // MARK: 四指永不 hide/quit（PLAN §9 不变量 3）

    func testFourFingerNeverHidesOrQuits() {
        let clock = FakePinchClock()
        var coordinator = makeCoordinator(clock: clock)
        _ = firePinch(&coordinator, clock)
        XCTAssertEqual(coordinator.flushPendingShows(),
                       [.present(requestID: 1, targetScreen: screenA, source: .fourFingerPinch)])
        // 同会话锁存：识别器不重复触发，无 hide/quit 路径
        _ = firePinch(&coordinator, clock, start: 0.5)
        XCTAssertEqual(coordinator.flushPendingShows(), [])
        XCTAssertEqual(coordinator.presentation.state, .presenting(requestID: 1, targetScreen: screenA))
        // 会话结束 + 新手势：仍只发 show（presenting 幂等），永不反向 hide
        _ = processFrame(&coordinator, clock, frame(PinchDeviceID(rawValue: 1), 1.0, .moved, []))
        _ = firePinch(&coordinator, clock, start: 2.0)
        XCTAssertEqual(coordinator.flushPendingShows(), [.none])
        XCTAssertEqual(coordinator.presentation.state, .presenting(requestID: 1, targetScreen: screenA))
        XCTAssertEqual(coordinator.showCount, 2)
    }

    func testShowWhileVisibleIsNoop() {
        let clock = FakePinchClock()
        var coordinator = FourFingerActivationCoordinator(
            recognizer: PinchRecognizer(parameters: PinchParameters(cooldown: 0), clock: clock),
            presentation: LauncherPresentationCoordinator(initialState: .visible(screenID: screenA)),
            activation: FourFingerActivationStateMachine(state: .ready),
            targetScreen: screenA,
            userEnabled: true
        )
        coordinator.start() // 识别器 idle；activation ready + start = no-op；presentation 不受影响
        let token = PinchEventToken(generation: 0, sessionID: PinchSessionID(rawValue: 1))
        coordinator.handlePinchEvent(.showRequested(token: token))
        XCTAssertEqual(coordinator.flushPendingShows(), [.none], "已显示：无副作用（§21.1）")
        XCTAssertEqual(coordinator.presentation.state, .visible(screenID: screenA))
        XCTAssertEqual(coordinator.showCount, 1)
    }

    func testShowWhileTerminatingRejected() {
        let clock = FakePinchClock()
        var coordinator = FourFingerActivationCoordinator(
            recognizer: PinchRecognizer(parameters: PinchParameters(cooldown: 0), clock: clock),
            presentation: LauncherPresentationCoordinator(initialState: .terminating),
            activation: FourFingerActivationStateMachine(state: .ready),
            targetScreen: screenA,
            userEnabled: true
        )
        let token = PinchEventToken(generation: 0, sessionID: PinchSessionID(rawValue: 1))
        coordinator.handlePinchEvent(.showRequested(token: token))
        XCTAssertEqual(coordinator.flushPendingShows(), [.none], "正在 Quit：拒绝新请求（§21.1）")
        XCTAssertEqual(coordinator.droppedTerminatingEventCount, 1)
        XCTAssertEqual(coordinator.showCount, 0)
    }

    // MARK: provider 状态映射

    func testProviderStateMapping() {
        let clock = FakePinchClock()
        var coordinator = makeCoordinator(clock: clock)
        coordinator.handleProviderState(.noDevice)
        XCTAssertEqual(coordinator.activation.state, .noDevice)
        coordinator.handleProviderState(.unavailable)
        XCTAssertEqual(coordinator.activation.state, .unavailable)
        coordinator.handleProviderState(.ready)
        XCTAssertEqual(coordinator.activation.state, .ready)
        coordinator.handleProviderState(.permissionNotConfirmed)
        XCTAssertEqual(coordinator.activation.state, .permissionNotConfirmed)
        coordinator.handleProviderState(.suspended(reason: .sleep))
        XCTAssertEqual(coordinator.activation.state, .suspended(reason: .sleep))
        coordinator.resume() // suspended → checking（resume 驱动，非 provider 报告）
        XCTAssertEqual(coordinator.activation.state, .checking)
        coordinator.handleProviderState(.ready)
        XCTAssertEqual(coordinator.activation.state, .ready)
        coordinator.handleProviderState(.off)
        XCTAssertEqual(coordinator.activation.state, .off)
        // 无合法转换的 provider 报告被安全忽略（不崩溃、状态不变）
        coordinator.handleProviderState(.checking) // off + checking：无合法转换
        XCTAssertEqual(coordinator.activation.state, .off)
        coordinator.handleProviderState(.ready) // off + ready：无合法转换
        XCTAssertEqual(coordinator.activation.state, .off)
    }

    // MARK: 生命周期转发

    func testSuspendForwardsToAllComponents() {
        let clock = FakePinchClock()
        var coordinator = makeCoordinator(clock: clock)
        let effect = coordinator.suspend(reason: .screenConfigurationChanged)
        XCTAssertEqual(effect, .suspend(reason: .screenConfigurationChanged))
        XCTAssertEqual(coordinator.recognizer.state, .suspended(reason: .screenConfigurationChanged))
        XCTAssertEqual(coordinator.activation.state, .suspended(reason: .screenConfigurationChanged))
        XCTAssertEqual(coordinator.presentation.state, .suspended(reason: .screenConfigurationChanged))
    }

    func testResumeRestoresIdleCheckingHidden() {
        let clock = FakePinchClock()
        var coordinator = makeCoordinator(clock: clock)
        _ = coordinator.suspend(reason: .sleep)
        _ = coordinator.resume()
        XCTAssertEqual(coordinator.recognizer.state, .idle)
        XCTAssertEqual(coordinator.activation.state, .checking)
        XCTAssertEqual(coordinator.presentation.state, .hidden)
    }

    func testStopClearsPendingAndHandoff() {
        let clock = FakePinchClock()
        var coordinator = makeCoordinator(clock: clock)
        _ = firePinch(&coordinator, clock)
        _ = coordinator.flushPendingShows() // show 派发 → handoffToken 设置
        XCTAssertNotNil(coordinator.handoffToken)
        coordinator.stop()
        XCTAssertTrue(coordinator.pendingShowTokens.isEmpty)
        XCTAssertNil(coordinator.handoffToken)
        XCTAssertEqual(coordinator.recognizer.state, .disabled)
        XCTAssertEqual(coordinator.activation.state, .off)
    }

    func testRestartBumpsGenerationAndClearsPending() {
        let clock = FakePinchClock()
        var coordinator = makeCoordinator(clock: clock)
        let generation = coordinator.recognizer.generation
        _ = firePinch(&coordinator, clock)
        XCTAssertEqual(coordinator.pendingShowTokens.count, 1)
        coordinator.restart()
        XCTAssertEqual(coordinator.recognizer.generation, generation + 1)
        XCTAssertEqual(coordinator.recognizer.state, .idle)
        XCTAssertEqual(coordinator.activation.state, .checking)
        XCTAssertTrue(coordinator.pendingShowTokens.isEmpty)
        XCTAssertNil(coordinator.handoffToken)
    }

    // MARK: LauncherActivationSource 新 case（T-1G-A 回归适配）

    func testLauncherActivationSourceIncludesFourFingerPinch() {
        let sources = LauncherActivationSource.allCases
        XCTAssertEqual(sources.count, 7, "6 既有入口 + fourFingerPinch")
        XCTAssertTrue(sources.contains(.fourFingerPinch))
        XCTAssertEqual(sources, [.initialLaunch, .dockReopen, .statusItem, .globalShortcut,
                                 .hotCorner, .fourFingerPinch, .testHarness])
    }
}
