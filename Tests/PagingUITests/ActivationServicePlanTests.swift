//
//  ActivationServicePlanTests.swift
//  PagingUITests
//
//  Phase 1G §9.8-7/§9.8-8 服务启停计划（T-G-P3）：
//  changing corner stops old service before new service；shortcut rollback。
//  原子（diff 整体计算/应用）、幂等（同计划零转换）、可回滚（反向 diff 恢复旧计划）。
//  纯值逻辑，不触碰任何 defaults。
//

import XCTest
@testable import PagingPrototypeApp

final class ActivationServicePlanTests: XCTestCase {

    private let cornerA = HotCorner.topLeft
    private let cornerB = HotCorner.bottomRight
    private let specA = ShortcutSpec(keyCode: 3, modifiers: [.command])
    private let specB = ShortcutSpec(keyCode: 4, modifiers: [.command, .option])

    // MARK: 计划派生

    func testPlanFromSettingsAndFourFinger() {
        var settings = ActivationSettings()
        settings.hotCornerEnabled = true
        settings.selectedCorner = .topLeft
        settings.globalShortcutEnabled = true
        settings.shortcut = specA

        let plan = ActivationServicePlan(settings: settings, fourFingerEnabled: true)
        XCTAssertEqual(plan.hotCorner, .topLeft)
        XCTAssertEqual(plan.globalShortcut, specA)
        XCTAssertTrue(plan.fourFingerEnabled)
    }

    func testPlanFromSettingsIgnoresDisabledTriggers() {
        var settings = ActivationSettings()
        settings.hotCornerEnabled = false
        settings.selectedCorner = .topLeft // 未启用但选了角 → 不运行
        settings.globalShortcutEnabled = false
        settings.shortcut = specA

        let plan = ActivationServicePlan(settings: settings, fourFingerEnabled: false)
        XCTAssertNil(plan.hotCorner)
        XCTAssertNil(plan.globalShortcut)
        XCTAssertFalse(plan.fourFingerEnabled)
    }

    // MARK: 幂等（同计划零转换）

    func testSamePlanNoTransitions() {
        let plan = ActivationServicePlan(hotCorner: cornerA, globalShortcut: specA, fourFingerEnabled: true)
        XCTAssertEqual(ActivationServicePlanDiff.transitions(from: plan, to: plan), [],
                       "同计划 → 零转换（幂等）")
    }

    // MARK: hot corner

    func testCornerOffToOnStarts() {
        let old = ActivationServicePlan()
        let new = ActivationServicePlan(hotCorner: cornerA)
        XCTAssertEqual(ActivationServicePlanDiff.transitions(from: old, to: new),
                       [.startHotCorner(cornerA)])
    }

    func testCornerOnToOffStops() {
        let old = ActivationServicePlan(hotCorner: cornerA)
        let new = ActivationServicePlan()
        XCTAssertEqual(ActivationServicePlanDiff.transitions(from: old, to: new),
                       [.stopHotCorner])
    }

    func testCornerChangeRestartsStopsOldBeforeNew() {
        let old = ActivationServicePlan(hotCorner: cornerA)
        let new = ActivationServicePlan(hotCorner: cornerB)
        XCTAssertEqual(ActivationServicePlanDiff.transitions(from: old, to: new),
                       [.restartHotCorner(cornerB)],
                       "换 corner：先停旧服务再启新服务（§9.8-7）")
    }

    // MARK: global shortcut

    func testShortcutOffToOnStarts() {
        let old = ActivationServicePlan()
        let new = ActivationServicePlan(globalShortcut: specA)
        XCTAssertEqual(ActivationServicePlanDiff.transitions(from: old, to: new),
                       [.startShortcut(specA)])
    }

    func testShortcutOnToOffStops() {
        let old = ActivationServicePlan(globalShortcut: specA)
        let new = ActivationServicePlan()
        XCTAssertEqual(ActivationServicePlanDiff.transitions(from: old, to: new),
                       [.stopShortcut])
    }

    func testShortcutChangeRestarts() {
        let old = ActivationServicePlan(globalShortcut: specA)
        let new = ActivationServicePlan(globalShortcut: specB)
        XCTAssertEqual(ActivationServicePlanDiff.transitions(from: old, to: new),
                       [.restartShortcut(specB)])
    }

    // MARK: four finger

    func testFourFingerOffToOnStarts() {
        let old = ActivationServicePlan()
        let new = ActivationServicePlan(fourFingerEnabled: true)
        XCTAssertEqual(ActivationServicePlanDiff.transitions(from: old, to: new),
                       [.startFourFinger])
    }

    func testFourFingerOnToOffStops() {
        let old = ActivationServicePlan(fourFingerEnabled: true)
        let new = ActivationServicePlan()
        XCTAssertEqual(ActivationServicePlanDiff.transitions(from: old, to: new),
                       [.stopFourFinger])
    }

    // MARK: 顺序（原子：先停 → 再 restart → 最后 start）

    func testStopsBeforeRestartsBeforeStarts() {
        let old = ActivationServicePlan(hotCorner: cornerA, globalShortcut: specA, fourFingerEnabled: true)
        let new = ActivationServicePlan(hotCorner: cornerB, globalShortcut: specB, fourFingerEnabled: false)
        XCTAssertEqual(ActivationServicePlanDiff.transitions(from: old, to: new),
                       [.stopFourFinger, .restartHotCorner(cornerB), .restartShortcut(specB)],
                       "顺序契约：先停旧服务，再 restart 变更服务，最后 start 新服务")
    }

    func testMixedStartStopOrdering() {
        let old = ActivationServicePlan(hotCorner: cornerA, fourFingerEnabled: true)
        let new = ActivationServicePlan(globalShortcut: specA, fourFingerEnabled: false)
        XCTAssertEqual(ActivationServicePlanDiff.transitions(from: old, to: new),
                       [.stopHotCorner, .stopFourFinger, .startShortcut(specA)],
                       "所有 stop 先于所有 start（stop 按服务种类序）")
    }

    // MARK: 应用与回滚

    func testApplyTransitionsReachesNewPlan() {
        let old = ActivationServicePlan(hotCorner: cornerA, globalShortcut: specA, fourFingerEnabled: true)
        let new = ActivationServicePlan(hotCorner: cornerB, globalShortcut: specB, fourFingerEnabled: false)
        var applied = old
        for transition in ActivationServicePlanDiff.transitions(from: old, to: new) {
            applied.apply(transition)
        }
        XCTAssertEqual(applied, new, "整体应用 diff 后到达新计划（原子）")
    }

    func testRollbackRestoresOldPlan() {
        let old = ActivationServicePlan(hotCorner: cornerA, globalShortcut: specA, fourFingerEnabled: true)
        let new = ActivationServicePlan(hotCorner: cornerB, globalShortcut: specB, fourFingerEnabled: false)
        let rollback = ActivationServicePlanDiff.rollback(from: new, to: old)
        var restored = new
        for transition in rollback {
            restored.apply(transition)
        }
        XCTAssertEqual(restored, old, "回滚后恢复旧计划（可回滚语义）")
        XCTAssertEqual(rollback, ActivationServicePlanDiff.transitions(from: new, to: old),
                       "回滚 = 反向 diff")
    }

    func testRollbackOfRestartIsRestart() {
        let old = ActivationServicePlan(hotCorner: cornerA)
        let new = ActivationServicePlan(hotCorner: cornerB)
        XCTAssertEqual(ActivationServicePlanDiff.rollback(from: new, to: old),
                       [.restartHotCorner(cornerA)],
                       "restart 的逆仍是 restart（停新启旧）")
    }

    func testRollbackOfStartIsStop() {
        let old = ActivationServicePlan()
        let new = ActivationServicePlan(fourFingerEnabled: true)
        XCTAssertEqual(ActivationServicePlanDiff.rollback(from: new, to: old),
                       [.stopFourFinger])
    }

    func testApplyIsIdempotent() {
        let plan = ActivationServicePlan(hotCorner: cornerA, fourFingerEnabled: true)
        var applied = plan
        for transition in ActivationServicePlanDiff.transitions(from: plan, to: plan) {
            applied.apply(transition)
        }
        XCTAssertEqual(applied, plan)
    }
}
