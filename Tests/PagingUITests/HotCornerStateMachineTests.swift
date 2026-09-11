//
//  HotCornerStateMachineTests.swift
//  PagingUITests
//
//  Phase 1G §9.6 Hot Corner pure state（14 项）+ 负样本：
//  disabled zero action；starts inside zone no trigger；outside→inside→dwell trigger once；
//  exit before dwell cancel；hysteresis re-arm；cooldown；repeated samples no duplicate；
//  launcher visible pause；mouse button/drag suppression；sleep/session inactive suppression；
//  wake requires exit/re-enter；screen geometry change cancels dwell；stale timer/session ignored；
//  timer stop on disable/teardown。
//

import XCTest
@testable import PagingPrototypeApp

final class HotCornerStateMachineTests: XCTestCase {

    /// 可注入 fake clock（测试单线程使用；nonisolated(unsafe) 仅为满足 Sendable 协议要求）。
    private final class FakeClock: HotCornerClock {
        nonisolated(unsafe) var current: TimeInterval = 0
        func now() -> TimeInterval { current }
        func advance(_ delta: TimeInterval) { current += delta }
    }

    private let zoneSize = 20.0
    private let dwell = 0.5
    private let hysteresis = 10.0
    private let cooldown = 2.0

    /// 单屏几何：frame (0,0,1000,800)。
    private func singleScreenGeometry() -> ScreenGeometrySnapshot {
        ScreenGeometrySnapshot(screens: [
            ScreenGeometrySnapshot.Screen(id: ScreenID(index: 0),
                                          frame: LauncherRect(origin: LauncherPoint(x: 0, y: 0),
                                                              size: LauncherSize(width: 1000, height: 800)),
                                          scale: 1.0),
        ])
    }

    private func makeMachine(clock: FakeClock) -> HotCornerStateMachine {
        HotCornerStateMachine(
            parameters: HotCornerParameters(zoneSize: zoneSize,
                                            dwellDuration: dwell,
                                            hysteresisInset: hysteresis,
                                            cooldown: cooldown),
            clock: clock,
            geometry: singleScreenGeometry()
        )
    }

    /// topLeft 热区内的点（zone 20pt：x∈[0,20], y∈[780,800]）。
    private let insideTopLeft = LauncherPoint(x: 5, y: 795)
    private let outsideAll = LauncherPoint(x: 500, y: 400)

    // MARK: §9.6-1 disabled zero action

    func testDisabledZeroAction() {
        let clock = FakeClock()
        var machine = makeMachine(clock: clock)
        XCTAssertEqual(machine.state, .disabled)
        XCTAssertFalse(machine.isActive)

        clock.advance(10)
        XCTAssertEqual(machine.sample(pointer: insideTopLeft), [], "disabled 时采样零动作")
        XCTAssertEqual(machine.state, .disabled)
        XCTAssertEqual(machine.triggerCount, 0)
    }

    // MARK: §9.6-2 starts inside zone no trigger

    func testStartsInsideZoneNoImmediateTrigger() {
        let clock = FakeClock()
        var machine = makeMachine(clock: clock)
        machine.enable(corner: .topLeft)

        // 启动时指针已在角落：不立即触发，进入 dwell
        XCTAssertEqual(machine.sample(pointer: insideTopLeft), [])
        XCTAssertEqual(machine.state, .insideCandidate(corner: .topLeft, screenID: ScreenID(index: 0), enteredAt: 0))

        clock.advance(dwell - 0.01)
        XCTAssertEqual(machine.sample(pointer: insideTopLeft), [], "dwell 未满不触发")
        clock.advance(0.02)
        let events = machine.sample(pointer: insideTopLeft)
        XCTAssertEqual(events, [.showRequested(corner: .topLeft, screenID: ScreenID(index: 0))], "dwell 满只触发一次")
    }

    // MARK: §9.6-3 outside→inside→dwell trigger once

    func testOutsideInsideDwellTriggersOnce() {
        let clock = FakeClock()
        var machine = makeMachine(clock: clock)
        machine.enable(corner: .topLeft)

        XCTAssertEqual(machine.sample(pointer: outsideAll), [], "热区外保持 armed")
        XCTAssertEqual(machine.state, .armed)

        clock.advance(1)
        XCTAssertEqual(machine.sample(pointer: insideTopLeft), [], "进入热区开始 dwell")
        XCTAssertEqual(machine.state, .insideCandidate(corner: .topLeft, screenID: ScreenID(index: 0), enteredAt: 1))

        clock.advance(dwell)
        let events = machine.sample(pointer: insideTopLeft)
        XCTAssertEqual(events.count, 1)
        XCTAssertEqual(events, [.showRequested(corner: .topLeft, screenID: ScreenID(index: 0))])
        XCTAssertEqual(machine.state, .triggeredAwaitingExit(corner: .topLeft, screenID: ScreenID(index: 0)))
        XCTAssertEqual(machine.triggerCount, 1)
    }

    // MARK: §9.6-4 exit before dwell cancel

    func testExitBeforeDwellCancels() {
        let clock = FakeClock()
        var machine = makeMachine(clock: clock)
        machine.enable(corner: .topLeft)
        _ = machine.sample(pointer: insideTopLeft) // enteredAt = 0

        clock.advance(dwell - 0.01)
        XCTAssertEqual(machine.sample(pointer: outsideAll), [], "dwell 未满离开 → 取消，不触发")
        XCTAssertEqual(machine.state, .armed)
        XCTAssertEqual(machine.triggerCount, 0)
    }

    // MARK: §9.6-5 hysteresis re-arm

    func testHysteresisReArmRequiresLeavingReArmZone() {
        let clock = FakeClock()
        var machine = makeMachine(clock: clock)
        machine.enable(corner: .topLeft)
        _ = machine.sample(pointer: insideTopLeft)
        clock.advance(dwell)
        _ = machine.sample(pointer: insideTopLeft) // trigger
        XCTAssertEqual(machine.state, .triggeredAwaitingExit(corner: .topLeft, screenID: ScreenID(index: 0)))

        // 仍在热区内（re-arm 区内）→ 保持 triggeredAwaitingExit，不重复触发
        clock.advance(1)
        XCTAssertEqual(machine.sample(pointer: insideTopLeft), [])
        XCTAssertEqual(machine.state, .triggeredAwaitingExit(corner: .topLeft, screenID: ScreenID(index: 0)))

        // 进入 hysteresis 余量区（zone 20 + 10 = 30：x∈[0,30], y∈[770,800]）→ 仍不 re-arm
        let inHysteresis = LauncherPoint(x: 25, y: 775)
        XCTAssertEqual(machine.sample(pointer: inHysteresis), [])
        XCTAssertEqual(machine.state, .triggeredAwaitingExit(corner: .topLeft, screenID: ScreenID(index: 0)))

        // 离开 re-arm 区 → 重新武装
        let outsideReArm = LauncherPoint(x: 35, y: 765)
        XCTAssertEqual(machine.sample(pointer: outsideReArm), [])
        XCTAssertEqual(machine.state, .armed)
    }

    // MARK: §9.6-6 cooldown

    func testCooldownSuppressesRapidRetrigger() {
        let clock = FakeClock()
        var machine = makeMachine(clock: clock)
        machine.enable(corner: .topLeft)
        _ = machine.sample(pointer: insideTopLeft) // enteredAt 0
        clock.advance(dwell)
        _ = machine.sample(pointer: insideTopLeft) // trigger at 0.5
        XCTAssertEqual(machine.triggerCount, 1)

        // 离开 re-arm 区 → armed
        _ = machine.sample(pointer: outsideAll)
        XCTAssertEqual(machine.state, .armed)

        // 快速重新进入 + dwell 满（t = 0.5 + 0.1 + 0.5 = 1.1 < cooldown 2.0）→ 不触发
        clock.advance(0.1)
        _ = machine.sample(pointer: insideTopLeft) // enteredAt 0.6
        clock.advance(dwell)
        XCTAssertEqual(machine.sample(pointer: insideTopLeft), [], "cooldown 内不触发")
        XCTAssertEqual(machine.state, .insideCandidate(corner: .topLeft, screenID: ScreenID(index: 0), enteredAt: 0.6))
        XCTAssertEqual(machine.triggerCount, 1)

        // 冷却满（t = 2.5 = lastTrigger 0.5 + cooldown 2.0）且仍在热区 → 触发
        clock.advance(1.4)
        let events = machine.sample(pointer: insideTopLeft)
        XCTAssertEqual(events, [.showRequested(corner: .topLeft, screenID: ScreenID(index: 0))])
        XCTAssertEqual(machine.triggerCount, 2)
    }

    // MARK: §9.6-7 repeated samples no duplicate

    func testRepeatedSamplesNoDuplicate() {
        let clock = FakeClock()
        var machine = makeMachine(clock: clock)
        machine.enable(corner: .topLeft)
        _ = machine.sample(pointer: insideTopLeft)
        clock.advance(dwell)
        XCTAssertEqual(machine.sample(pointer: insideTopLeft).count, 1)

        // 触发后持续采样（仍在热区）→ 零重复事件
        for _ in 0..<5 {
            clock.advance(0.1)
            XCTAssertEqual(machine.sample(pointer: insideTopLeft), [])
        }
        XCTAssertEqual(machine.triggerCount, 1)
    }

    // MARK: §9.6-8 launcher visible pause

    func testLauncherVisiblePausesTrigger() {
        let clock = FakeClock()
        var machine = makeMachine(clock: clock)
        machine.enable(corner: .topLeft)
        _ = machine.sample(pointer: insideTopLeft) // enteredAt 0

        machine.setLauncherVisible(true)
        clock.advance(dwell * 3)
        XCTAssertEqual(machine.sample(pointer: insideTopLeft), [], "launcher 可见时暂停，不发重复请求")
        XCTAssertEqual(machine.triggerCount, 0)

        // 隐藏后 dwell 重新计时（不立即触发）
        machine.setLauncherVisible(false)
        clock.advance(dwell - 0.01)
        XCTAssertEqual(machine.sample(pointer: insideTopLeft), [])
        clock.advance(0.02)
        XCTAssertEqual(machine.sample(pointer: insideTopLeft).count, 1)
    }

    // MARK: §9.6-9 mouse button / drag suppression

    func testInputSuppressedCancelsDwell() {
        let clock = FakeClock()
        var machine = makeMachine(clock: clock)
        machine.enable(corner: .topLeft)
        _ = machine.sample(pointer: insideTopLeft) // enteredAt 0

        machine.setInputSuppressed(true)
        XCTAssertEqual(machine.state, .armed, "按键按下/drag 取消 dwell")
        clock.advance(dwell)
        XCTAssertEqual(machine.sample(pointer: insideTopLeft), [], "抑制期间不触发")
        XCTAssertEqual(machine.triggerCount, 0)

        // 释放后重新进入 → 重新计时
        machine.setInputSuppressed(false)
        _ = machine.sample(pointer: insideTopLeft)
        clock.advance(dwell)
        XCTAssertEqual(machine.sample(pointer: insideTopLeft).count, 1)
    }

    // MARK: §9.6-10 sleep / session inactive suppression

    func testSleepSuspendsAndSuppresses() {
        let clock = FakeClock()
        var machine = makeMachine(clock: clock)
        machine.enable(corner: .topLeft)
        _ = machine.sample(pointer: insideTopLeft)

        machine.suspend(reason: .sleep)
        XCTAssertEqual(machine.state, .suspended(reason: .sleep))
        clock.advance(dwell * 3)
        XCTAssertEqual(machine.sample(pointer: insideTopLeft), [], "sleep 中采样零动作")
        XCTAssertEqual(machine.triggerCount, 0)
    }

    func testSessionInactiveSuspends() {
        let clock = FakeClock()
        var machine = makeMachine(clock: clock)
        machine.enable(corner: .topLeft)
        machine.suspend(reason: .sessionInactive)
        XCTAssertEqual(machine.state, .suspended(reason: .sessionInactive))
        XCTAssertEqual(machine.sample(pointer: insideTopLeft), [])
    }

    // MARK: §9.6-11 wake requires exit/re-enter

    func testWakeRequiresExitReenter() {
        let clock = FakeClock()
        var machine = makeMachine(clock: clock)
        machine.enable(corner: .topLeft)
        _ = machine.sample(pointer: insideTopLeft)
        machine.suspend(reason: .sleep)
        machine.resume()
        XCTAssertEqual(machine.state, .armed)

        // 唤醒后指针仍在角落：不进入 dwell（要求先离开）
        clock.advance(1)
        XCTAssertEqual(machine.sample(pointer: insideTopLeft), [])
        XCTAssertEqual(machine.state, .armed, "唤醒后要求指针重新离开/进入")

        // 离开 → 再进入 → 正常 dwell
        _ = machine.sample(pointer: outsideAll)
        XCTAssertEqual(machine.state, .armed)
        _ = machine.sample(pointer: insideTopLeft)
        XCTAssertEqual(machine.state, .insideCandidate(corner: .topLeft, screenID: ScreenID(index: 0), enteredAt: 1))
        clock.advance(dwell)
        XCTAssertEqual(machine.sample(pointer: insideTopLeft).count, 1)
    }

    // MARK: §9.6-12 screen geometry change cancels dwell

    func testGeometryChangeCancelsDwell() {
        let clock = FakeClock()
        var machine = makeMachine(clock: clock)
        machine.enable(corner: .topLeft)
        _ = machine.sample(pointer: insideTopLeft)
        XCTAssertEqual(machine.state, .insideCandidate(corner: .topLeft, screenID: ScreenID(index: 0), enteredAt: 0))

        // 屏幕变化：原子替换 geometry + 取消旧 dwell
        let newGeometry = ScreenGeometrySnapshot(screens: [
            ScreenGeometrySnapshot.Screen(id: ScreenID(index: 0),
                                          frame: LauncherRect(origin: LauncherPoint(x: 0, y: 0),
                                                              size: LauncherSize(width: 800, height: 600)),
                                          scale: 1.0),
        ])
        machine.updateGeometry(newGeometry)
        XCTAssertEqual(machine.state, .armed, "屏幕变化取消 dwell")

        clock.advance(dwell)
        XCTAssertEqual(machine.sample(pointer: insideTopLeft), [], "旧热区坐标不再命中")
        XCTAssertEqual(machine.triggerCount, 0)
    }

    // MARK: §9.6-13 stale timer/session ignored

    func testStaleSampleIgnored() {
        let clock = FakeClock()
        var machine = makeMachine(clock: clock)
        machine.enable(corner: .topLeft)
        _ = machine.sample(pointer: insideTopLeft) // enteredAt = 0

        // 时钟回拨（乱序/过期样本）：now < enteredAt → 忽略
        clock.current = -1
        XCTAssertEqual(machine.sample(pointer: insideTopLeft), [])
        XCTAssertEqual(machine.state, .insideCandidate(corner: .topLeft, screenID: ScreenID(index: 0), enteredAt: 0))
        XCTAssertEqual(machine.triggerCount, 0)
    }

    // MARK: §9.6-14 timer stop on disable/teardown

    func testDisableStopsAllActivity() {
        let clock = FakeClock()
        var machine = makeMachine(clock: clock)
        machine.enable(corner: .topLeft)
        _ = machine.sample(pointer: insideTopLeft)
        machine.disable()
        XCTAssertEqual(machine.state, .disabled)
        XCTAssertFalse(machine.isActive)

        clock.advance(dwell * 3)
        XCTAssertEqual(machine.sample(pointer: insideTopLeft), [], "disable 后零动作")
        XCTAssertEqual(machine.triggerCount, 0)
    }

    func testTeardownIsIdempotent() {
        let clock = FakeClock()
        var machine = makeMachine(clock: clock)
        machine.enable(corner: .topLeft)
        machine.teardown()
        XCTAssertEqual(machine.state, .disabled)
        machine.teardown()
        XCTAssertEqual(machine.state, .disabled, "teardown 幂等")
        XCTAssertEqual(machine.sample(pointer: insideTopLeft), [])
    }

    // MARK: 负样本（不该触发的场景）

    func testOnlySelectedCornerTriggers() {
        let clock = FakeClock()
        var machine = makeMachine(clock: clock)
        machine.enable(corner: .topLeft)

        // 指针在 topRight 热区（x∈[980,1000], y∈[780,800]）→ 不触发
        let insideTopRight = LauncherPoint(x: 995, y: 795)
        _ = machine.sample(pointer: insideTopRight)
        XCTAssertEqual(machine.state, .armed, "未选中的 corner 不进入 dwell")
        clock.advance(dwell)
        XCTAssertEqual(machine.sample(pointer: insideTopRight), [])
        XCTAssertEqual(machine.triggerCount, 0)
    }

    func testFastCrossingCornerDoesNotTrigger() {
        let clock = FakeClock()
        var machine = makeMachine(clock: clock)
        machine.enable(corner: .topLeft)
        _ = machine.sample(pointer: insideTopLeft) // enteredAt 0

        // 快速跨越到另一角落：旧 dwell 取消，新角落重新计时
        let insideTopRight = LauncherPoint(x: 995, y: 795)
        clock.advance(0.1)
        _ = machine.sample(pointer: insideTopRight)
        XCTAssertEqual(machine.state, .insideCandidate(corner: .topRight, screenID: ScreenID(index: 0), enteredAt: 0.1))
        XCTAssertEqual(machine.triggerCount, 0)

        // 新角落 dwell 未满 → 不触发
        clock.advance(dwell - 0.01)
        XCTAssertEqual(machine.sample(pointer: insideTopRight), [])
        XCTAssertEqual(machine.triggerCount, 0)
    }

    func testTriggerScreenBecomesTarget() {
        // §9.7-8：Hot Corner show 的 target screen = 实际触发 screen
        // 左右排列下 B 的有效外角是 topRight/bottomRight（topLeft 是共享边内角）
        let clock = FakeClock()
        let twoScreens = ScreenGeometrySnapshot(screens: [
            ScreenGeometrySnapshot.Screen(id: ScreenID(index: 0),
                                          frame: LauncherRect(origin: LauncherPoint(x: 0, y: 0),
                                                              size: LauncherSize(width: 1000, height: 800)),
                                          scale: 1.0),
            ScreenGeometrySnapshot.Screen(id: ScreenID(index: 1),
                                          frame: LauncherRect(origin: LauncherPoint(x: 1000, y: 0),
                                                              size: LauncherSize(width: 1000, height: 800)),
                                          scale: 1.0),
        ])
        var machine = HotCornerStateMachine(
            parameters: HotCornerParameters(zoneSize: zoneSize, dwellDuration: dwell,
                                            hysteresisInset: hysteresis, cooldown: cooldown),
            clock: clock,
            geometry: twoScreens
        )
        machine.enable(corner: .topRight)

        // 屏幕 B 的 topRight 热区（x∈[1980,2000], y∈[780,800]）
        let insideBTopRight = LauncherPoint(x: 1995, y: 795)
        _ = machine.sample(pointer: insideBTopRight)
        clock.advance(dwell)
        let events = machine.sample(pointer: insideBTopRight)
        XCTAssertEqual(events, [.showRequested(corner: .topRight, screenID: ScreenID(index: 1))],
                       "触发屏（B）成为 target screen")
    }

    func testScreenRemovedDuringDwellCancels() {
        // §9.7-7：dwell 中屏幕被移除 → 取消 dwell
        let clock = FakeClock()
        let twoScreens = ScreenGeometrySnapshot(screens: [
            ScreenGeometrySnapshot.Screen(id: ScreenID(index: 0),
                                          frame: LauncherRect(origin: LauncherPoint(x: 0, y: 0),
                                                              size: LauncherSize(width: 1000, height: 800)),
                                          scale: 1.0),
            ScreenGeometrySnapshot.Screen(id: ScreenID(index: 1),
                                          frame: LauncherRect(origin: LauncherPoint(x: 1000, y: 0),
                                                              size: LauncherSize(width: 1000, height: 800)),
                                          scale: 1.0),
        ])
        var machine = HotCornerStateMachine(
            parameters: HotCornerParameters(zoneSize: zoneSize, dwellDuration: dwell,
                                            hysteresisInset: hysteresis, cooldown: cooldown),
            clock: clock,
            geometry: twoScreens
        )
        machine.enable(corner: .topRight)
        let insideBTopRight = LauncherPoint(x: 1995, y: 795)
        _ = machine.sample(pointer: insideBTopRight)
        XCTAssertEqual(machine.state, .insideCandidate(corner: .topRight, screenID: ScreenID(index: 1), enteredAt: 0))

        // 屏幕 B 被移除 → 原子替换 + 取消 dwell
        machine.updateGeometry(ScreenGeometrySnapshot(screens: [twoScreens.screens[0]]))
        XCTAssertEqual(machine.state, .armed)
        clock.advance(dwell)
        XCTAssertEqual(machine.sample(pointer: insideBTopRight), [], "已移除屏幕的坐标不再命中")
        XCTAssertEqual(machine.triggerCount, 0)
    }
}
