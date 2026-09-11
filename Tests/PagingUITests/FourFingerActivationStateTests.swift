//
//  FourFingerActivationStateTests.swift
//  PagingUITests
//
//  Phase 1G §21.2 四指入口状态模型（T-G-P3）：
//  七态 Off/Checking/Ready/NoDevice/Unavailable/PermissionNotConfirmed/Suspended
//  （与 T-G-P2 TouchProviderState 对齐）；Enabled ≠ Ready（用户打开开关但后端失败时显示事实）；
//  状态转换纯值模型（合法/非法转换、幂等 start/stop、挂起/恢复、全生命周期）。
//  纯值逻辑，不触碰任何 defaults。
//

import XCTest
@testable import PagingPrototypeApp

final class FourFingerActivationStateTests: XCTestCase {

    // MARK: §21.2 七态对齐（与 TouchProviderState）

    func testSevenStatesAlignWithTouchProviderState() {
        let providerStates: [TouchProviderState] = [
            .off, .checking, .ready, .noDevice, .unavailable, .permissionNotConfirmed,
            .suspended(reason: .sleep),
        ]
        let expected: [FourFingerActivationState] = [
            .off, .checking, .ready, .noDevice, .unavailable, .permissionNotConfirmed,
            .suspended(reason: .sleep),
        ]
        for (provider, entry) in zip(providerStates, expected) {
            XCTAssertEqual(FourFingerActivationState(providerState: provider), entry,
                           "provider 状态 \(provider) 必须 1:1 映射到入口状态")
        }
    }

    func testSuspensionReasonPreservedInConversion() {
        for reason in [PinchSuspensionReason.sleep, .sessionInactive, .screenConfigurationChanged] {
            XCTAssertEqual(FourFingerActivationState(providerState: .suspended(reason: reason)),
                           .suspended(reason: reason))
        }
    }

    // MARK: 初始与启动

    func testInitialStateOff() {
        XCTAssertEqual(FourFingerActivationStateMachine().state, .off)
    }

    func testStartFromOffGoesChecking() {
        var machine = FourFingerActivationStateMachine()
        XCTAssertTrue(machine.apply(.start))
        XCTAssertEqual(machine.state, .checking)
    }

    func testStartIsIdempotentFromAnyActiveState() {
        let active: [FourFingerActivationState] = [.checking, .ready, .noDevice, .unavailable,
                                                   .permissionNotConfirmed, .suspended(reason: .sleep)]
        for state in active {
            var machine = FourFingerActivationStateMachine(state: state)
            XCTAssertTrue(machine.apply(.start), "已启动时 start = no-op（幂等，与 provider 对齐）")
            XCTAssertEqual(machine.state, state)
        }
    }

    // MARK: checking 解析

    func testCheckingResolvesToEachBackendState() {
        let cases: [(FourFingerActivationTransition, FourFingerActivationState)] = [
            (.backendReady, .ready),
            (.backendNoDevice, .noDevice),
            (.backendUnavailable, .unavailable),
            (.permissionNotConfirmed, .permissionNotConfirmed),
        ]
        for (transition, expected) in cases {
            var machine = FourFingerActivationStateMachine(state: .checking)
            XCTAssertTrue(machine.apply(transition))
            XCTAssertEqual(machine.state, expected)
        }
    }

    // MARK: ready 降级

    func testReadyDegradesToNoDeviceUnavailablePermission() {
        let cases: [(FourFingerActivationTransition, FourFingerActivationState)] = [
            (.backendNoDevice, .noDevice),
            (.backendUnavailable, .unavailable),
            (.permissionNotConfirmed, .permissionNotConfirmed),
        ]
        for (transition, expected) in cases {
            var machine = FourFingerActivationStateMachine(state: .ready)
            XCTAssertTrue(machine.apply(transition))
            XCTAssertEqual(machine.state, expected)
        }
    }

    // MARK: 失败态恢复

    func testNoDeviceRecoversToReady() {
        var machine = FourFingerActivationStateMachine(state: .noDevice)
        XCTAssertTrue(machine.apply(.backendReady))
        XCTAssertEqual(machine.state, .ready)
    }

    func testUnavailableRecoversToReady() {
        var machine = FourFingerActivationStateMachine(state: .unavailable)
        XCTAssertTrue(machine.apply(.backendReady))
        XCTAssertEqual(machine.state, .ready)
    }

    func testPermissionNotConfirmedRecoversToReady() {
        var machine = FourFingerActivationStateMachine(state: .permissionNotConfirmed)
        XCTAssertTrue(machine.apply(.backendReady))
        XCTAssertEqual(machine.state, .ready)
    }

    func testRecheckFromFailureStatesGoesChecking() {
        let failureStates: [FourFingerActivationState] = [.noDevice, .unavailable, .permissionNotConfirmed]
        for state in failureStates {
            var machine = FourFingerActivationStateMachine(state: state)
            XCTAssertTrue(machine.apply(.recheck), "\(state) 可重新检查")
            XCTAssertEqual(machine.state, .checking)
        }
    }

    // MARK: 挂起/恢复

    func testSuspendFromEveryActiveState() {
        let active: [FourFingerActivationState] = [.checking, .ready, .noDevice, .unavailable,
                                                   .permissionNotConfirmed]
        for state in active {
            var machine = FourFingerActivationStateMachine(state: state)
            XCTAssertTrue(machine.apply(.suspend(reason: .sleep)))
            XCTAssertEqual(machine.state, .suspended(reason: .sleep))
        }
    }

    func testSuspendFromOffRejected() {
        var machine = FourFingerActivationStateMachine()
        XCTAssertFalse(machine.apply(.suspend(reason: .sleep)), "off 状态挂起无意义 → 拒绝")
        XCTAssertEqual(machine.state, .off)
    }

    func testSuspendWhileSuspendedUpdatesReason() {
        var machine = FourFingerActivationStateMachine(state: .suspended(reason: .sleep))
        XCTAssertTrue(machine.apply(.suspend(reason: .sessionInactive)), "挂起原因更新保持显示事实")
        XCTAssertEqual(machine.state, .suspended(reason: .sessionInactive))
    }

    func testResumeFromSuspendedGoesChecking() {
        var machine = FourFingerActivationStateMachine(state: .suspended(reason: .screenConfigurationChanged))
        XCTAssertTrue(machine.apply(.resume))
        XCTAssertEqual(machine.state, .checking,
                       "恢复后重新检查；不自动弹权限、不呼出窗口（§21.2）")
    }

    func testResumeFromNonSuspendedRejected() {
        let states: [FourFingerActivationState] = [.off, .checking, .ready, .noDevice]
        for state in states {
            var machine = FourFingerActivationStateMachine(state: state)
            XCTAssertFalse(machine.apply(.resume), "\(state) 下 resume 非法")
            XCTAssertEqual(machine.state, state)
        }
    }

    // MARK: 停止

    func testStopFromAnyStateGoesOff() {
        let states: [FourFingerActivationState] = [.checking, .ready, .noDevice, .unavailable,
                                                   .permissionNotConfirmed, .suspended(reason: .sleep)]
        for state in states {
            var machine = FourFingerActivationStateMachine(state: state)
            XCTAssertTrue(machine.apply(.stop))
            XCTAssertEqual(machine.state, .off)
        }
    }

    func testStopFromOffIsIdempotentNoop() {
        var machine = FourFingerActivationStateMachine()
        XCTAssertTrue(machine.apply(.stop), "未启动时 stop = no-op（幂等，与 provider 对齐）")
        XCTAssertEqual(machine.state, .off)
    }

    // MARK: 非法转换

    func testIllegalTransitionsRejected() {
        let cases: [(FourFingerActivationState, FourFingerActivationTransition)] = [
            (.off, .backendReady),
            (.off, .backendNoDevice),
            (.off, .backendUnavailable),
            (.off, .permissionNotConfirmed),
            (.off, .recheck),
            (.off, .resume),
            (.checking, .recheck),
            (.ready, .recheck),
            (.ready, .backendReady),
            (.suspended(reason: .sleep), .backendReady),
            (.suspended(reason: .sleep), .recheck),
        ]
        for (state, transition) in cases {
            var machine = FourFingerActivationStateMachine(state: state)
            XCTAssertFalse(machine.apply(transition), "\(state) + \(transition) 必须拒绝")
            XCTAssertEqual(machine.state, state, "拒绝时状态不变")
        }
    }

    // MARK: 全生命周期

    func testFullLifecycleSequence() {
        var machine = FourFingerActivationStateMachine()
        XCTAssertTrue(machine.apply(.start))                    // off → checking
        XCTAssertEqual(machine.state, .checking)
        XCTAssertTrue(machine.apply(.backendReady))            // checking → ready
        XCTAssertEqual(machine.state, .ready)
        XCTAssertTrue(machine.apply(.suspend(reason: .sleep)))  // ready → suspended
        XCTAssertEqual(machine.state, .suspended(reason: .sleep))
        XCTAssertTrue(machine.apply(.resume))                  // suspended → checking
        XCTAssertEqual(machine.state, .checking)
        XCTAssertTrue(machine.apply(.backendNoDevice))         // checking → noDevice
        XCTAssertEqual(machine.state, .noDevice)
        XCTAssertTrue(machine.apply(.backendReady))           // noDevice → ready
        XCTAssertEqual(machine.state, .ready)
        XCTAssertTrue(machine.apply(.stop))                   // ready → off
        XCTAssertEqual(machine.state, .off)
    }

    // MARK: Enabled ≠ Ready（§21.2）

    func testEnabledNotReadySemantics() {
        // 用户打开开关但后端失败：显示事实，不冒充就绪
        let failureStates: [FourFingerActivationState] = [.checking, .noDevice, .unavailable,
                                                          .permissionNotConfirmed,
                                                          .suspended(reason: .sleep)]
        for state in failureStates {
            let status = FourFingerActivationStatus(enabled: true, state: state)
            XCTAssertFalse(status.isReady, "enabled=true 但后端 \(state) → 不是 ready")
        }
        XCTAssertTrue(FourFingerActivationStatus(enabled: true, state: .ready).isReady)
        XCTAssertFalse(FourFingerActivationStatus(enabled: false, state: .ready).isReady,
                       "开关关 → 即使后端就绪也不可用")
        XCTAssertFalse(FourFingerActivationStatus(enabled: false, state: .off).isReady)
    }

    func testDisplayKindShowsFactsWhenEnabled() {
        let cases: [(FourFingerActivationState, FourFingerActivationDisplayKind)] = [
            (.checking, .enabledChecking),
            (.ready, .ready),
            (.noDevice, .enabledNoDevice),
            (.unavailable, .enabledUnavailable),
            (.permissionNotConfirmed, .enabledPermissionNotConfirmed),
            (.suspended(reason: .sleep), .enabledSuspended(reason: .sleep)),
        ]
        for (state, expected) in cases {
            XCTAssertEqual(FourFingerActivationStatus(enabled: true, state: state).displayKind,
                           expected, "开关开 → 按后端事实展示")
        }
    }

    func testDisplayKindDisabledWhenSwitchOff() {
        let states: [FourFingerActivationState] = [.off, .checking, .ready, .noDevice, .unavailable,
                                                   .permissionNotConfirmed, .suspended(reason: .sleep)]
        for state in states {
            XCTAssertEqual(FourFingerActivationStatus(enabled: false, state: state).displayKind,
                           .disabled, "开关关 → 展示 disabled（无论后端状态）")
        }
    }

    func testEnabledAndReadyAreIndependentDimensions() {
        // 两个维度独立：enabled 与 state 可任意组合
        let status = FourFingerActivationStatus(enabled: true, state: .noDevice)
        XCTAssertTrue(status.enabled)
        XCTAssertEqual(status.state, .noDevice)
        XCTAssertFalse(status.isReady)

        // 后端就绪但开关关：事实是"未开启"，不是"就绪"
        let off = FourFingerActivationStatus(enabled: false, state: .ready)
        XCTAssertFalse(off.enabled)
        XCTAssertEqual(off.state, .ready)
        XCTAssertFalse(off.isReady)
    }
}
