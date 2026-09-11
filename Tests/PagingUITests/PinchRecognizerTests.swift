//
//  PinchRecognizerTests.swift
//  PagingUITests
//
//  Phase 1G §23.1 P01-P20 纯逻辑部分（T-G-P1；T-G-P6 重构 R-05）：
//  P01 严格四指内收一次触发；P02 同会话持续收缩只一次；P03 全指释放后新会话可再触发；
//  P04 二指/三指/五指不误触；P05 四指平移/旋转/微抖动不误触；P06 顺次落指不把成员加入当收缩；
//  P07 四变三再变四不重复触发；P08 触点/设备更换不继承基线；P09 两设备各两指不组合；
//  P10 零触点/取消/断开/过期正确结束或取消；P11 NaN/Infinity/近零半径/非法计数拒绝；
//  P12 乱序/时间回退/过载丢帧不错误 Show；P17 pinchOut 无 Hide；P19 输入交接不误翻页/不永久禁用。
//  判定模型（T-G-P6 R-05）：候选段首帧（恰好 4 触点）建立基线半径，次帧起逐帧判定相对收缩
//  ≥ shrinkThreshold 触发；无稳定窗口/无噪声容忍/无重锚定。负样本断言"不该触发"，不只 happy path。
//  合成匿名触点夹具；不提交真实触控板轨迹。
//
//  测试默认 cooldown=0 以隔离锁存语义；冷却合同由
//  testCooldownSuppressesRapidRetriggerAcrossSessions 用生产默认参数显式覆盖。
//

import XCTest
@testable import PagingPrototypeApp

// MARK: - 共享夹具（PinchRecognizerLifecycleTests 复用）

/// 可注入 fake clock（测试单线程使用；nonisolated(unsafe) 仅为满足 Sendable 协议要求）。
final class FakePinchClock: PinchClock {
    nonisolated(unsafe) var current: TimeInterval = 0
    func now() -> TimeInterval { current }
    func advance(_ delta: TimeInterval) { current += delta }
}

/// 测试默认参数：cooldown=0 隔离锁存语义（冷却合同单独显式覆盖）。
func makeRecognizer(clock: FakePinchClock, parameters: PinchParameters = PinchParameters(cooldown: 0)) -> PinchRecognizer {
    var r = PinchRecognizer(parameters: parameters, clock: clock)
    r.start()
    return r
}

/// 处理帧并把时钟对齐到帧时间戳（单调时间域一致）。
@discardableResult
func processAt(_ r: inout PinchRecognizer, _ clock: FakePinchClock, _ f: PinchFrame) -> [PinchEvent] {
    clock.current = f.timestamp
    return r.process(f)
}

/// 以中心 (0.5, 0.5) 的方形生成 4 触点；半径 = halfSize × √2。
func squareContacts(halfSize: Double, ids: [Int] = [1, 2, 3, 4]) -> [PinchContact] {
    let cx = 0.5
    let cy = 0.5
    return [
        PinchContact(id: PinchContactID(rawValue: ids[0]), position: PinchPoint(x: cx - halfSize, y: cy - halfSize)),
        PinchContact(id: PinchContactID(rawValue: ids[1]), position: PinchPoint(x: cx + halfSize, y: cy - halfSize)),
        PinchContact(id: PinchContactID(rawValue: ids[2]), position: PinchPoint(x: cx + halfSize, y: cy + halfSize)),
        PinchContact(id: PinchContactID(rawValue: ids[3]), position: PinchPoint(x: cx - halfSize, y: cy + halfSize)),
    ]
}

func frame(_ device: PinchDeviceID, _ t: TimeInterval, _ phase: PinchFramePhase, _ contacts: [PinchContact]) -> PinchFrame {
    PinchFrame(deviceID: device, timestamp: t, phase: phase, contacts: contacts)
}

/// 标准手势：t0 落 4 指（h=0.2，首帧基线）→ t0+0.1 次帧进入判定 → t0+0.11 收缩 h=0.16（收缩量 0.2 ≥ 0.15）触发。
@discardableResult
func runStandardPinch(_ r: inout PinchRecognizer, _ clock: FakePinchClock,
                      device: PinchDeviceID = PinchDeviceID(rawValue: 1), start: TimeInterval = 0) -> [PinchEvent] {
    _ = processAt(&r, clock, frame(device, start, .began, squareContacts(halfSize: 0.2)))
    _ = processAt(&r, clock, frame(device, start + 0.1, .moved, squareContacts(halfSize: 0.2)))
    return processAt(&r, clock, frame(device, start + 0.11, .moved, squareContacts(halfSize: 0.16)))
}

final class PinchRecognizerTests: XCTestCase {

    private let device = PinchDeviceID(rawValue: 1)

    // MARK: P01 严格四指内收超过阈值一次触发

    func testP01StrictFourFingerPinchTriggersOnce() {
        let clock = FakePinchClock()
        var r = makeRecognizer(clock: clock)

        let events = runStandardPinch(&r, clock, device: device)
        XCTAssertEqual(events.count, 1)
        XCTAssertEqual(r.fireCount, 1)
        XCTAssertEqual(r.state, .fired)
        XCTAssertEqual(r.lastFireLatency ?? -1, 0.11, accuracy: 0.001, "候选建立 → 触发延迟")
        guard case .showRequested(let token) = events[0] else {
            return XCTFail("事件必须是 showRequested")
        }
        XCTAssertEqual(token.generation, r.generation)
        XCTAssertEqual(token.sessionID, r.activeSessionID, "事件 token 携带当前会话")
    }

    // MARK: P02 同一接触会话持续收缩超过冷却也只触发一次

    func testP02SameSessionContinuousContractionFiresOnce() {
        let clock = FakePinchClock()
        var r = makeRecognizer(clock: clock)

        let first = runStandardPinch(&r, clock, device: device)
        XCTAssertEqual(first.count, 1)
        XCTAssertEqual(r.state, .fired)

        // 持续收缩远超冷却：仍只一次（锁存）
        for i in 0..<20 {
            let t = 0.2 + Double(i) * 0.1
            let events = processAt(&r, clock, frame(device, t, .moved, squareContacts(halfSize: 0.05)))
            XCTAssertEqual(events, [], "锁存会话持续收缩不重复触发")
        }
        XCTAssertEqual(r.fireCount, 1)
        XCTAssertEqual(r.state, .fired)
    }

    // MARK: P03 全指释放后新会话可再次触发

    func testP03FullReleaseReArmsForNewSession() {
        let clock = FakePinchClock()
        var r = makeRecognizer(clock: clock)

        _ = runStandardPinch(&r, clock, device: device)
        XCTAssertEqual(r.fireCount, 1)

        // 全指释放（零触点 moved 帧 = 结束证据）
        _ = processAt(&r, clock, frame(device, 0.2, .moved, []))
        XCTAssertEqual(r.state, .idle)

        // 新会话再次触发
        let second = runStandardPinch(&r, clock, device: device, start: 0.3)
        XCTAssertEqual(second.count, 1)
        XCTAssertEqual(r.fireCount, 2)
    }

    // MARK: P04 二指缩放、三指平移、五指均不误触

    func testP04TwoAndThreeFingersDoNotTrigger() {
        let clock = FakePinchClock()
        var r = makeRecognizer(clock: clock)

        // 二指缩放
        let two = [PinchContact(id: PinchContactID(rawValue: 1), position: PinchPoint(x: 0.3, y: 0.5)),
                   PinchContact(id: PinchContactID(rawValue: 2), position: PinchPoint(x: 0.7, y: 0.5))]
        _ = processAt(&r, clock, frame(device, 0, .began, two))
        _ = processAt(&r, clock, frame(device, 0.1, .moved,
                                       [PinchContact(id: PinchContactID(rawValue: 1), position: PinchPoint(x: 0.4, y: 0.5)),
                                        PinchContact(id: PinchContactID(rawValue: 2), position: PinchPoint(x: 0.6, y: 0.5))]))
        XCTAssertEqual(r.state, .idle, "二指缩放不建立候选")
        XCTAssertEqual(r.fireCount, 0)

        // 三指平移
        let three = [PinchContact(id: PinchContactID(rawValue: 1), position: PinchPoint(x: 0.3, y: 0.3)),
                     PinchContact(id: PinchContactID(rawValue: 2), position: PinchPoint(x: 0.5, y: 0.3)),
                     PinchContact(id: PinchContactID(rawValue: 3), position: PinchPoint(x: 0.4, y: 0.7))]
        _ = processAt(&r, clock, frame(device, 0.2, .moved, three))
        XCTAssertEqual(r.state, .idle, "三指平移不建立候选")
        XCTAssertEqual(r.fireCount, 0)
    }

    func testP04FiveFingersDoNotTrigger() {
        let clock = FakePinchClock()
        var r = makeRecognizer(clock: clock)

        // 五指直接进入：不建立候选（严格四指）
        let five = squareContacts(halfSize: 0.2) + [PinchContact(id: PinchContactID(rawValue: 5), position: PinchPoint(x: 0.5, y: 0.5))]
        let events = processAt(&r, clock, frame(device, 0, .began, five))
        XCTAssertEqual(events, [])
        XCTAssertEqual(r.state, .idle)
        XCTAssertEqual(r.fireCount, 0)

        // 四指候选 → 第五指加入 → 取消候选（锁存），无事件
        _ = processAt(&r, clock, frame(device, 0.1, .began, squareContacts(halfSize: 0.2)))
        XCTAssertEqual(r.state, .candidate)
        let events2 = processAt(&r, clock, frame(device, 0.2, .moved, five))
        XCTAssertEqual(events2, [])
        XCTAssertEqual(r.state, .waitingForRelease)
        XCTAssertEqual(r.cancelCounts[.contactCountChanged], 1)

        // 释放后新会话可正常触发
        _ = processAt(&r, clock, frame(device, 0.3, .moved, []))
        XCTAssertEqual(r.state, .idle)
        let fired = runStandardPinch(&r, clock, device: device, start: 0.4)
        XCTAssertEqual(fired.count, 1)
    }

    // MARK: P05 四指平移/旋转/微抖动不误触

    func testP05FourFingerTranslationDoesNotTrigger() {
        let clock = FakePinchClock()
        var r = makeRecognizer(clock: clock)

        // 平移：半径不变 → 首帧建基线后次帧即进入判定（无稳定窗口），永不触发、永不取消
        var t: TimeInterval = 0
        for i in 0..<5 {
            let dx = Double(i) * 0.05
            let contacts = squareContacts(halfSize: 0.2).map { c in
                PinchContact(id: c.id, position: PinchPoint(x: c.position.x + dx, y: c.position.y))
            }
            let events = processAt(&r, clock, frame(device, t, i == 0 ? .began : .moved, contacts))
            XCTAssertEqual(events, [])
            t += 0.05
        }
        XCTAssertEqual(r.state, .recognizing, "平移半径不变：直接进入判定")
        XCTAssertEqual(r.fireCount, 0)
        XCTAssertEqual(r.cancelCounts[.expansion], nil, "平移不产生扩张取消")

        // 继续平移（半径不变）→ 不触发
        let moved2 = squareContacts(halfSize: 0.2).map { c in
            PinchContact(id: c.id, position: PinchPoint(x: c.position.x + 0.3, y: c.position.y))
        }
        let events = processAt(&r, clock, frame(device, t + 0.01, .moved, moved2))
        XCTAssertEqual(events, [])
        XCTAssertEqual(r.fireCount, 0)
        XCTAssertEqual(r.state, .recognizing)
    }

    func testP05FourFingerRotationDoesNotTrigger() {
        let clock = FakePinchClock()
        var r = makeRecognizer(clock: clock)

        // 建立基线
        _ = processAt(&r, clock, frame(device, 0, .began, squareContacts(halfSize: 0.2)))
        _ = processAt(&r, clock, frame(device, 0.1, .moved, squareContacts(halfSize: 0.2)))
        XCTAssertEqual(r.state, .recognizing)

        // 绕 (0.5, 0.5) 旋转 90°（半径不变）→ 不触发
        let rotated = squareContacts(halfSize: 0.2).map { c in
            PinchContact(id: c.id, position: PinchPoint(x: 0.5 - (c.position.y - 0.5), y: 0.5 + (c.position.x - 0.5)))
        }
        let events = processAt(&r, clock, frame(device, 0.11, .moved, rotated))
        XCTAssertEqual(events, [])
        XCTAssertEqual(r.fireCount, 0)
        XCTAssertEqual(r.state, .recognizing)

        // 旋转后继续收缩 → 正常触发
        let contracted = rotated.map { c in
            let dx = c.position.x - 0.5
            let dy = c.position.y - 0.5
            let scale = 0.16 / 0.2
            return PinchContact(id: c.id, position: PinchPoint(x: 0.5 + dx * scale, y: 0.5 + dy * scale))
        }
        let fired = processAt(&r, clock, frame(device, 0.12, .moved, contracted))
        XCTAssertEqual(fired.count, 1)
    }

    func testP05MicroJitterDoesNotTrigger() {
        let clock = FakePinchClock()
        var r = makeRecognizer(clock: clock)

        // 落指 + 微抖动（±0.003，半径波动 ≈0.007 < 阈值 0.15）→ 次帧进入判定，不触发
        _ = processAt(&r, clock, frame(device, 0, .began, squareContacts(halfSize: 0.2)))
        var t: TimeInterval = 0.05
        for _ in 0..<3 {
            let jittered = jitteredSquare()
            _ = processAt(&r, clock, frame(device, t, .moved, jittered))
            t += 0.05
        }
        XCTAssertEqual(r.state, .recognizing, "抖动半径波动低于阈值，直接进入判定")

        // 识别中微抖动：半径波动低于阈值 → 不触发
        for _ in 0..<10 {
            let events = processAt(&r, clock, frame(device, t, .moved, jitteredSquare()))
            XCTAssertEqual(events, [])
            t += 0.05
        }
        XCTAssertEqual(r.fireCount, 0)
        XCTAssertEqual(r.state, .recognizing)
    }

    /// 非均匀微抖动（质心不动，半径波动 ≈0.007 < 阈值 0.15）。
    private func jitteredSquare() -> [PinchContact] {
        squareContacts(halfSize: 0.2).enumerated().map { i, c in
            let dx = (i % 2 == 0) ? 0.003 : -0.003
            let dy = (i < 2) ? 0.003 : -0.003
            return PinchContact(id: c.id, position: PinchPoint(x: c.position.x + dx, y: c.position.y + dy))
        }
    }

    // MARK: P06 顺次落指不把成员加入当成收缩

    func testP06SequentialLandingDoesNotCountAsContraction() {
        let clock = FakePinchClock()
        var r = makeRecognizer(clock: clock)

        // 顺次落指：1 → 2 → 3 → 4
        _ = processAt(&r, clock, frame(device, 0, .began,
                                       [PinchContact(id: PinchContactID(rawValue: 1), position: PinchPoint(x: 0.3, y: 0.3))]))
        XCTAssertEqual(r.state, .idle)
        _ = processAt(&r, clock, frame(device, 0.02, .moved,
                                       [PinchContact(id: PinchContactID(rawValue: 1), position: PinchPoint(x: 0.3, y: 0.3)),
                                        PinchContact(id: PinchContactID(rawValue: 2), position: PinchPoint(x: 0.7, y: 0.3))]))
        XCTAssertEqual(r.state, .idle)
        _ = processAt(&r, clock, frame(device, 0.04, .moved,
                                       [PinchContact(id: PinchContactID(rawValue: 1), position: PinchPoint(x: 0.3, y: 0.3)),
                                        PinchContact(id: PinchContactID(rawValue: 2), position: PinchPoint(x: 0.7, y: 0.3)),
                                        PinchContact(id: PinchContactID(rawValue: 3), position: PinchPoint(x: 0.5, y: 0.7))]))
        XCTAssertEqual(r.state, .idle)

        // 第 4 指落下：建立候选（基线 = 当前几何），不产生收缩事件
        let events = processAt(&r, clock, frame(device, 0.06, .moved, squareContacts(halfSize: 0.2)))
        XCTAssertEqual(events, [])
        XCTAssertEqual(r.state, .candidate)
        XCTAssertEqual(r.fireCount, 0)

        // 次帧进入判定（无稳定窗口要求）→ 收缩 → 触发
        _ = processAt(&r, clock, frame(device, 0.16, .moved, squareContacts(halfSize: 0.2)))
        XCTAssertEqual(r.state, .recognizing)
        let fired = processAt(&r, clock, frame(device, 0.17, .moved, squareContacts(halfSize: 0.16)))
        XCTAssertEqual(fired.count, 1)
    }

    // MARK: P07 四变三再变四不重复触发已锁存会话

    func testP07FourThreeFourDoesNotRetriggerLatchedSession() {
        let clock = FakePinchClock()
        var r = makeRecognizer(clock: clock)

        _ = runStandardPinch(&r, clock, device: device)
        XCTAssertEqual(r.fireCount, 1)
        XCTAssertEqual(r.state, .fired)

        // 四变三
        let three = Array(squareContacts(halfSize: 0.1).prefix(3))
        _ = processAt(&r, clock, frame(device, 0.2, .moved, three))
        XCTAssertEqual(r.state, .fired, "锁存保持")

        // 三变四（同一接触会话）→ 不重复触发
        let events = processAt(&r, clock, frame(device, 0.3, .moved, squareContacts(halfSize: 0.1)))
        XCTAssertEqual(events, [])
        XCTAssertEqual(r.fireCount, 1)
        XCTAssertEqual(r.state, .fired)

        // 释放 → 新会话可再次触发
        _ = processAt(&r, clock, frame(device, 0.4, .moved, []))
        XCTAssertEqual(r.state, .idle)
        let second = runStandardPinch(&r, clock, device: device, start: 0.5)
        XCTAssertEqual(second.count, 1)
        XCTAssertEqual(r.fireCount, 2)
    }

    // MARK: P08 更换 contact identity 或 device 不继承基线

    func testP08ContactReplacementDoesNotInheritBaseline() {
        let clock = FakePinchClock()
        var r = makeRecognizer(clock: clock)

        _ = processAt(&r, clock, frame(device, 0, .began, squareContacts(halfSize: 0.2)))
        XCTAssertEqual(r.state, .candidate)

        // 触点身份更换（4 → 1,2,3,5）→ 取消候选，不继承基线
        var replaced = squareContacts(halfSize: 0.2)
        replaced[3] = PinchContact(id: PinchContactID(rawValue: 5), position: PinchPoint(x: 0.3, y: 0.7))
        let events = processAt(&r, clock, frame(device, 0.1, .moved, replaced))
        XCTAssertEqual(events, [])
        XCTAssertEqual(r.state, .waitingForRelease)
        XCTAssertEqual(r.cancelCounts[.contactReplaced], 1)

        // 释放后新会话正常
        _ = processAt(&r, clock, frame(device, 0.2, .moved, []))
        XCTAssertEqual(r.state, .idle)
    }

    func testP08DeviceChangeDoesNotInheritBaseline() {
        let clock = FakePinchClock()
        var r = makeRecognizer(clock: clock)
        let deviceA = PinchDeviceID(rawValue: 1)
        let deviceB = PinchDeviceID(rawValue: 2)

        // A 建立候选
        _ = processAt(&r, clock, frame(deviceA, 0, .began, squareContacts(halfSize: 0.2)))
        XCTAssertEqual(r.state, .candidate)

        // B 独立会话（4 触点）→ 不继承 A 的基线
        _ = processAt(&r, clock, frame(deviceB, 0.1, .began, squareContacts(halfSize: 0.2)))
        XCTAssertEqual(r.state, .candidate)

        // A 收缩 → A 触发（自己的会话）
        _ = processAt(&r, clock, frame(deviceA, 0.2, .moved, squareContacts(halfSize: 0.2)))
        XCTAssertEqual(r.state, .recognizing)
        let aEvents = processAt(&r, clock, frame(deviceA, 0.21, .moved, squareContacts(halfSize: 0.16)))
        XCTAssertEqual(aEvents.count, 1)
        XCTAssertEqual(r.fireCount, 1)

        // B 收缩 → B 触发（独立会话）
        _ = processAt(&r, clock, frame(deviceB, 0.3, .moved, squareContacts(halfSize: 0.2)))
        XCTAssertEqual(r.state, .recognizing)
        let bEvents = processAt(&r, clock, frame(deviceB, 0.31, .moved, squareContacts(halfSize: 0.16)))
        XCTAssertEqual(bEvents.count, 1)
        XCTAssertEqual(r.fireCount, 2)
    }

    // MARK: P09 两设备各两指不能组合触发

    func testP09TwoDevicesTwoFingersEachDoNotCombine() {
        let clock = FakePinchClock()
        var r = makeRecognizer(clock: clock)
        let deviceA = PinchDeviceID(rawValue: 1)
        let deviceB = PinchDeviceID(rawValue: 2)

        let twoA = [PinchContact(id: PinchContactID(rawValue: 1), position: PinchPoint(x: 0.3, y: 0.3)),
                    PinchContact(id: PinchContactID(rawValue: 2), position: PinchPoint(x: 0.7, y: 0.3))]
        let twoB = [PinchContact(id: PinchContactID(rawValue: 10), position: PinchPoint(x: 0.3, y: 0.7)),
                    PinchContact(id: PinchContactID(rawValue: 11), position: PinchPoint(x: 0.7, y: 0.7))]

        // 交错帧：两设备各两指 → 不组合
        for i in 0..<4 {
            let t = Double(i) * 0.05
            let eventsA = processAt(&r, clock, frame(deviceA, t, i == 0 ? .began : .moved, twoA))
            let eventsB = processAt(&r, clock, frame(deviceB, t + 0.01, i == 0 ? .began : .moved, twoB))
            XCTAssertEqual(eventsA, [])
            XCTAssertEqual(eventsB, [])
        }
        XCTAssertEqual(r.state, .idle)
        XCTAssertEqual(r.fireCount, 0)
        XCTAssertTrue(r.cancelCounts.isEmpty, "无会话建立，无取消")
    }

    // MARK: P10 零触点/取消/断开/过期数据正确结束或取消

    func testP10ZeroContactFrameEndsSession() {
        let clock = FakePinchClock()
        var r = makeRecognizer(clock: clock)

        _ = processAt(&r, clock, frame(device, 0, .began, squareContacts(halfSize: 0.2)))
        XCTAssertEqual(r.state, .candidate)

        // 零触点 moved 帧 = 全部离面 = 结束证据
        _ = processAt(&r, clock, frame(device, 0.1, .moved, []))
        XCTAssertEqual(r.state, .idle)

        // 新会话可正常触发
        let fired = runStandardPinch(&r, clock, device: device, start: 0.2)
        XCTAssertEqual(fired.count, 1)
    }

    func testP10CancelledFrameEndsSession() {
        let clock = FakePinchClock()
        var r = makeRecognizer(clock: clock)

        _ = processAt(&r, clock, frame(device, 0, .began, squareContacts(halfSize: 0.2)))
        _ = processAt(&r, clock, frame(device, 0.1, .moved, squareContacts(halfSize: 0.2)))
        XCTAssertEqual(r.state, .recognizing)

        // 系统取消 → 结束会话，无事件
        let events = processAt(&r, clock, frame(device, 0.2, .cancelled, []))
        XCTAssertEqual(events, [])
        XCTAssertEqual(r.state, .idle)
        XCTAssertEqual(r.fireCount, 0)
    }

    func testP10DeviceDisconnectEndsSession() {
        let clock = FakePinchClock()
        var r = makeRecognizer(clock: clock)

        _ = processAt(&r, clock, frame(device, 0, .began, squareContacts(halfSize: 0.2)))
        XCTAssertEqual(r.state, .candidate)

        r.deviceDisconnected(device)
        XCTAssertEqual(r.state, .idle)
        XCTAssertEqual(r.cancelCounts[.disconnected], 1)
    }

    func testP10ExpiredDataRejected() {
        let clock = FakePinchClock()
        var r = makeRecognizer(clock: clock)

        _ = processAt(&r, clock, frame(device, 0, .began, squareContacts(halfSize: 0.2)))
        XCTAssertEqual(r.state, .candidate)

        // 过期帧（now - timestamp = 0.6 > 0.5）→ 拒绝，状态不变
        clock.current = 0.7
        let events = r.process(frame(device, 0.1, .moved, squareContacts(halfSize: 0.16)))
        XCTAssertEqual(events, [])
        XCTAssertEqual(r.state, .candidate, "过期帧不改变状态")
        XCTAssertEqual(r.rejectedFrameCount, 1)
    }

    func testP10SilenceInCandidateConservativelyResets() {
        let clock = FakePinchClock()
        var r = makeRecognizer(clock: clock)

        _ = processAt(&r, clock, frame(device, 0, .began, squareContacts(halfSize: 0.2)))
        XCTAssertEqual(r.state, .candidate)

        // 静默超限后新帧：候选保守重置（dataExpired），新帧建立新候选，不凭不完整轨迹触发
        let events = processAt(&r, clock, frame(device, 0.6, .moved, squareContacts(halfSize: 0.2)))
        XCTAssertEqual(events, [])
        XCTAssertEqual(r.cancelCounts[.dataExpired], 1)
        XCTAssertEqual(r.state, .candidate, "新帧建立新候选")
        XCTAssertEqual(r.fireCount, 0)
    }

    // MARK: P11 NaN/Infinity、近零半径、超大计数、安全边界拒绝

    func testP11NaNRejected() {
        let clock = FakePinchClock()
        var r = makeRecognizer(clock: clock)

        _ = processAt(&r, clock, frame(device, 0, .began, squareContacts(halfSize: 0.2)))
        XCTAssertEqual(r.state, .candidate)

        var bad = squareContacts(halfSize: 0.16)
        bad[0] = PinchContact(id: PinchContactID(rawValue: 1), position: PinchPoint(x: .nan, y: 0.3))
        let events = processAt(&r, clock, frame(device, 0.1, .moved, bad))
        XCTAssertEqual(events, [])
        XCTAssertEqual(r.state, .candidate, "NaN 帧拒绝，状态不变")
        XCTAssertEqual(r.rejectedFrameCount, 1)
    }

    func testP11InfinityRejected() {
        let clock = FakePinchClock()
        var r = makeRecognizer(clock: clock)

        _ = processAt(&r, clock, frame(device, 0, .began, squareContacts(halfSize: 0.2)))
        XCTAssertEqual(r.state, .candidate)

        var bad = squareContacts(halfSize: 0.16)
        bad[1] = PinchContact(id: PinchContactID(rawValue: 2), position: PinchPoint(x: .infinity, y: 0.3))
        let events = processAt(&r, clock, frame(device, 0.1, .moved, bad))
        XCTAssertEqual(events, [])
        XCTAssertEqual(r.state, .candidate, "Infinity 帧拒绝，状态不变")
        XCTAssertEqual(r.rejectedFrameCount, 1)
    }

    func testP11ExcessiveContactCountRejected() {
        let clock = FakePinchClock()
        var r = makeRecognizer(clock: clock)

        _ = processAt(&r, clock, frame(device, 0, .began, squareContacts(halfSize: 0.2)))
        XCTAssertEqual(r.state, .candidate)

        var many = squareContacts(halfSize: 0.2)
        for i in 5...9 {
            many.append(PinchContact(id: PinchContactID(rawValue: i), position: PinchPoint(x: 0.5, y: 0.5)))
        }
        let events = processAt(&r, clock, frame(device, 0.1, .moved, many))
        XCTAssertEqual(events, [])
        XCTAssertEqual(r.state, .candidate, "超上限计数帧拒绝")
        XCTAssertEqual(r.rejectedFrameCount, 1)
    }

    func testP11NearZeroBaselineRadiusCancels() {
        let clock = FakePinchClock()
        var r = makeRecognizer(clock: clock)

        // 4 触点几乎重合 → 候选首帧基线半径 < minBaselineRadius → 立即取消（无稳定窗口可依，T-G-P6）
        let bunched = [PinchContact(id: PinchContactID(rawValue: 1), position: PinchPoint(x: 0.5, y: 0.5)),
                       PinchContact(id: PinchContactID(rawValue: 2), position: PinchPoint(x: 0.5001, y: 0.5)),
                       PinchContact(id: PinchContactID(rawValue: 3), position: PinchPoint(x: 0.5, y: 0.5001)),
                       PinchContact(id: PinchContactID(rawValue: 4), position: PinchPoint(x: 0.5001, y: 0.5001))]
        let events = processAt(&r, clock, frame(device, 0, .began, bunched))
        XCTAssertEqual(events, [])
        XCTAssertEqual(r.state, .waitingForRelease, "近零基线半径首帧取消")
        XCTAssertEqual(r.cancelCounts[.degenerateGeometry], 1)

        // 锁存至释放：后续帧不改变状态
        _ = processAt(&r, clock, frame(device, 0.1, .moved, bunched))
        XCTAssertEqual(r.state, .waitingForRelease)
        XCTAssertEqual(r.fireCount, 0)
    }

    func testP11NegativeTimestampRejected() {
        let clock = FakePinchClock()
        var r = makeRecognizer(clock: clock)

        let events = processAt(&r, clock, frame(device, -1, .began, squareContacts(halfSize: 0.2)))
        XCTAssertEqual(events, [])
        XCTAssertEqual(r.state, .idle)
        XCTAssertEqual(r.rejectedFrameCount, 1)
    }

    func testP11DuplicateContactIDsRejected() {
        let clock = FakePinchClock()
        var r = makeRecognizer(clock: clock)

        var dup = squareContacts(halfSize: 0.2)
        dup[3] = dup[0] // 重复 id 1
        let events = processAt(&r, clock, frame(device, 0, .began, dup))
        XCTAssertEqual(events, [])
        XCTAssertEqual(r.state, .idle)
        XCTAssertEqual(r.rejectedFrameCount, 1)
    }

    // MARK: P12 回调乱序、时间回退、过载丢帧不会错误 Show

    func testP12OutOfOrderFrameRejected() {
        let clock = FakePinchClock()
        var r = makeRecognizer(clock: clock)

        _ = processAt(&r, clock, frame(device, 1.0, .began, squareContacts(halfSize: 0.2)))
        XCTAssertEqual(r.state, .candidate)

        // 乱序帧（时间回退）→ 拒绝
        let events = processAt(&r, clock, frame(device, 0.9, .moved, squareContacts(halfSize: 0.16)))
        XCTAssertEqual(events, [])
        XCTAssertEqual(r.state, .candidate, "乱序帧不改变状态")
        XCTAssertEqual(r.rejectedFrameCount, 1)

        // 后续正常帧仍可进入判定并触发
        _ = processAt(&r, clock, frame(device, 1.1, .moved, squareContacts(halfSize: 0.2)))
        XCTAssertEqual(r.state, .recognizing)
        let fired = processAt(&r, clock, frame(device, 1.11, .moved, squareContacts(halfSize: 0.16)))
        XCTAssertEqual(fired.count, 1)
    }

    func testP12FutureFrameRejected() {
        let clock = FakePinchClock()
        var r = makeRecognizer(clock: clock)

        _ = processAt(&r, clock, frame(device, 1.0, .began, squareContacts(halfSize: 0.2)))
        XCTAssertEqual(r.state, .candidate)

        // 未来帧（timestamp > now）→ 拒绝
        clock.current = 1.0
        let events = r.process(frame(device, 1.5, .moved, squareContacts(halfSize: 0.16)))
        XCTAssertEqual(events, [])
        XCTAssertEqual(r.state, .candidate)
        XCTAssertEqual(r.rejectedFrameCount, 1)
    }

    func testP12OverloadFrameDropDoesNotWronglyShow() {
        let clock = FakePinchClock()
        var r = makeRecognizer(clock: clock)

        _ = processAt(&r, clock, frame(device, 0, .began, squareContacts(halfSize: 0.2)))
        XCTAssertEqual(r.state, .candidate)

        // 过载丢帧：2s 后恢复，期间用户已收缩到 h=0.1。
        // 静默超限 → 候选重置；恢复帧建立新候选（基线 = 当前几何），不凭不完整轨迹触发。
        let events = processAt(&r, clock, frame(device, 2.0, .moved, squareContacts(halfSize: 0.1)))
        XCTAssertEqual(events, [])
        XCTAssertEqual(r.cancelCounts[.dataExpired], 1)
        XCTAssertEqual(r.state, .candidate, "恢复帧建立新候选，不立即触发")
        XCTAssertEqual(r.fireCount, 0)

        // 新基线次帧判定后再收缩 → 正常触发
        _ = processAt(&r, clock, frame(device, 2.1, .moved, squareContacts(halfSize: 0.1)))
        XCTAssertEqual(r.state, .recognizing)
        let fired = processAt(&r, clock, frame(device, 2.11, .moved, squareContacts(halfSize: 0.08)))
        XCTAssertEqual(fired.count, 1)
    }

    // MARK: P17 pinchOut 无 Hide

    func testP17PinchOutProducesNoHideAndCancels() {
        let clock = FakePinchClock()
        var r = makeRecognizer(clock: clock)

        _ = processAt(&r, clock, frame(device, 0, .began, squareContacts(halfSize: 0.2)))
        _ = processAt(&r, clock, frame(device, 0.1, .moved, squareContacts(halfSize: 0.2)))
        XCTAssertEqual(r.state, .recognizing)

        // 扩张超限（h=0.24 → contraction = -0.2 ≤ -0.15）→ 无事件（无 Hide），取消候选
        let events = processAt(&r, clock, frame(device, 0.11, .moved, squareContacts(halfSize: 0.24)))
        XCTAssertEqual(events, [], "pinchOut 无 Hide 事件")
        XCTAssertEqual(r.state, .waitingForRelease)
        XCTAssertEqual(r.cancelCounts[.expansion], 1)
        XCTAssertEqual(r.fireCount, 0)

        // 锁存至释放：扩张后继续收缩也不触发
        let more = processAt(&r, clock, frame(device, 0.2, .moved, squareContacts(halfSize: 0.1)))
        XCTAssertEqual(more, [])
        XCTAssertEqual(r.state, .waitingForRelease)

        // 释放 → 新会话可触发
        _ = processAt(&r, clock, frame(device, 0.3, .moved, []))
        XCTAssertEqual(r.state, .idle)
        let fired = runStandardPinch(&r, clock, device: device, start: 0.4)
        XCTAssertEqual(fired.count, 1)
    }

    func testP17EventTypeIsShowOnly() {
        // 编译期保证：PinchEvent 只有 .showRequested 一个 case（无 hide 事件）。
        let event: PinchEvent = .showRequested(token: PinchEventToken(generation: 0, sessionID: PinchSessionID(rawValue: 1)))
        switch event {
        case .showRequested:
            break
        }
    }

    // MARK: P19 输入交接不引发误翻页/误启动，不永久禁键盘鼠标

    func testP19InputHandoffDoesNotBreakRecognizerOrOtherInput() {
        let clock = FakePinchClock()
        var r = makeRecognizer(clock: clock)

        // 触发一次
        _ = runStandardPinch(&r, clock, device: device)
        XCTAssertEqual(r.fireCount, 1)

        // 释放
        _ = processAt(&r, clock, frame(device, 0.2, .moved, []))
        XCTAssertEqual(r.state, .idle)

        // 交接后：二指帧（其他输入）不干扰、不误触发
        let two = [PinchContact(id: PinchContactID(rawValue: 1), position: PinchPoint(x: 0.3, y: 0.5)),
                   PinchContact(id: PinchContactID(rawValue: 2), position: PinchPoint(x: 0.7, y: 0.5))]
        _ = processAt(&r, clock, frame(device, 0.3, .began, two))
        XCTAssertEqual(r.state, .idle)
        XCTAssertEqual(r.fireCount, 1)

        // 新四指手势正常触发（识别器未被永久禁用）
        let fired = runStandardPinch(&r, clock, device: device, start: 0.4)
        XCTAssertEqual(fired.count, 1)
        XCTAssertEqual(r.fireCount, 2)
    }

    // MARK: §19.2 合同 1/2（T-G-P6 首帧基线）：落指不同步不以第 4 指落下当收缩

    func testContract2FourthFingerLandingIsNotContraction() {
        let clock = FakePinchClock()
        var r = makeRecognizer(clock: clock)

        // 3 指已处于收缩位（h=0.16），第 4 指落下
        let three = [PinchContact(id: PinchContactID(rawValue: 1), position: PinchPoint(x: 0.34, y: 0.34)),
                     PinchContact(id: PinchContactID(rawValue: 2), position: PinchPoint(x: 0.66, y: 0.34)),
                     PinchContact(id: PinchContactID(rawValue: 3), position: PinchPoint(x: 0.5, y: 0.66))]
        _ = processAt(&r, clock, frame(device, 0, .began, three))
        XCTAssertEqual(r.state, .idle)

        // 第 4 指落下（h=0.16 完整方形）→ 基线 = 当前几何，不产生收缩
        let events = processAt(&r, clock, frame(device, 0.05, .moved, squareContacts(halfSize: 0.16)))
        XCTAssertEqual(events, [])
        XCTAssertEqual(r.state, .candidate)
        XCTAssertEqual(r.fireCount, 0)

        // 次帧进入判定 → 从 h=0.16 基线继续收缩才触发
        _ = processAt(&r, clock, frame(device, 0.15, .moved, squareContacts(halfSize: 0.16)))
        XCTAssertEqual(r.state, .recognizing)
        let fired = processAt(&r, clock, frame(device, 0.16, .moved, squareContacts(halfSize: 0.12)))
        XCTAssertEqual(fired.count, 1, "从落指基线收缩 0.25 ≥ 0.15 → 触发")
    }

    // MARK: §19.2 合同 3：阈值/时间上限分别命名且生效

    func testContract3ThresholdIsEffectiveParameter() {
        let clock = FakePinchClock()

        // 高阈值：0.2 收缩不触发
        var strict = makeRecognizer(clock: clock, parameters: PinchParameters(shrinkThreshold: 0.5, cooldown: 0))
        _ = processAt(&strict, clock, frame(device, 0, .began, squareContacts(halfSize: 0.2)))
        _ = processAt(&strict, clock, frame(device, 0.1, .moved, squareContacts(halfSize: 0.2)))
        let noFire = processAt(&strict, clock, frame(device, 0.11, .moved, squareContacts(halfSize: 0.16)))
        XCTAssertEqual(noFire, [], "收缩 0.2 < 阈值 0.5 → 不触发")
        XCTAssertEqual(strict.state, .recognizing)

        // 低阈值：0.2 收缩触发
        var lenient = makeRecognizer(clock: clock, parameters: PinchParameters(shrinkThreshold: 0.1, cooldown: 0))
        _ = processAt(&lenient, clock, frame(device, 0, .began, squareContacts(halfSize: 0.2)))
        _ = processAt(&lenient, clock, frame(device, 0.1, .moved, squareContacts(halfSize: 0.2)))
        let fired = processAt(&lenient, clock, frame(device, 0.11, .moved, squareContacts(halfSize: 0.16)))
        XCTAssertEqual(fired.count, 1)
    }

    func testContract3TimeLimitCancelsCandidate() {
        // dataExpiryInterval 放大到 2.0，隔离时间上限语义（避免静默重置先于时间上限触发）
        let clock = FakePinchClock()
        var r = makeRecognizer(clock: clock, parameters: PinchParameters(maxGestureDuration: 0.5, cooldown: 0, dataExpiryInterval: 2.0))

        _ = processAt(&r, clock, frame(device, 0, .began, squareContacts(halfSize: 0.2)))
        XCTAssertEqual(r.state, .candidate)

        // 候选超过时间上限 → 取消（锁存至释放），无事件
        let events = processAt(&r, clock, frame(device, 0.6, .moved, squareContacts(halfSize: 0.2)))
        XCTAssertEqual(events, [])
        XCTAssertEqual(r.state, .waitingForRelease)
        XCTAssertEqual(r.cancelCounts[.timeLimitExceeded], 1)
        XCTAssertEqual(r.fireCount, 0)
    }

    // MARK: T-G-P6 R-05：首帧基线模型（快速/慢速捏合触发 + 默认时间上限 3.5s）

    func testFastPinchNoStableFrameTriggers() {
        let clock = FakePinchClock()
        var r = makeRecognizer(clock: clock)

        // 快速捏合：全程移动、无静止帧（每帧触点位移 ≈0.0141，超旧噪声容忍上限 ≈0.0057×半径）
        // 无稳定窗口要求：首帧基线后次帧即判定，收缩达阈值即触发
        _ = processAt(&r, clock, frame(device, 0, .began, squareContacts(halfSize: 0.2)))
        XCTAssertEqual(r.state, .candidate)

        _ = processAt(&r, clock, frame(device, 0.017, .moved, squareContacts(halfSize: 0.19)))
        XCTAssertEqual(r.state, .recognizing, "次帧进入判定（无静止段）")
        XCTAssertEqual(r.fireCount, 0)

        _ = processAt(&r, clock, frame(device, 0.033, .moved, squareContacts(halfSize: 0.18)))
        XCTAssertEqual(r.fireCount, 0, "收缩 ≈0.10 < 0.15 未触发")

        // 收缩 (0.2828-0.2263)/0.2828 ≈ 0.20 ≥ 0.15 → 触发（候选建立后 0.05s，无任何静止帧）
        let fired = processAt(&r, clock, frame(device, 0.05, .moved, squareContacts(halfSize: 0.16)))
        XCTAssertEqual(fired.count, 1)
        XCTAssertEqual(r.fireCount, 1)
        XCTAssertEqual(r.state, .fired)
        XCTAssertEqual(r.lastFireLatency ?? -1, 0.05, accuracy: 0.001)
        XCTAssertTrue(r.cancelCounts.isEmpty, "快速捏合不产生取消")
    }

    func testSlowPinchStartsWithRestThenContractsTriggers() {
        let clock = FakePinchClock()
        var r = makeRecognizer(clock: clock)

        // 慢速捏合（实机 §R-03 轨迹形态）：先平放 1.6s（静止，半径不变），再开始捏合
        _ = processAt(&r, clock, frame(device, 0, .began, squareContacts(halfSize: 0.2)))
        XCTAssertEqual(r.state, .candidate)
        var t: TimeInterval = 0.1
        while t <= 1.5 {
            let events = processAt(&r, clock, frame(device, t, .moved, squareContacts(halfSize: 0.2)))
            XCTAssertEqual(events, [], "平放期不触发")
            t += 0.1
        }
        XCTAssertEqual(r.state, .recognizing)
        XCTAssertEqual(r.fireCount, 0)

        // 平放 1.6s 后捏合：候选→触发 1.6s 在默认时间上限 3.5s 内 → 触发
        // （旧 1.5s 上限会在捏合开始前取消，§R-03）
        let fired = processAt(&r, clock, frame(device, 1.6, .moved, squareContacts(halfSize: 0.16)))
        XCTAssertEqual(fired.count, 1)
        XCTAssertEqual(r.fireCount, 1)
        XCTAssertEqual(r.state, .fired)
        XCTAssertEqual(r.lastFireLatency ?? -1, 1.6, accuracy: 0.001)
    }

    func testDefaultMaxGestureDurationIs3Point5Seconds() {
        let clock = FakePinchClock()
        var r = makeRecognizer(clock: clock)

        XCTAssertEqual(r.parameters.maxGestureDuration, 3.5, accuracy: 0.001, "R-03 定案：默认时间上限 3.5s")

        // 长时间平放不收缩：3.5s 边界帧仍保持（不取消）
        _ = processAt(&r, clock, frame(device, 0, .began, squareContacts(halfSize: 0.2)))
        var t: TimeInterval = 0.1
        while t <= 3.5 {
            let events = processAt(&r, clock, frame(device, t, .moved, squareContacts(halfSize: 0.2)))
            XCTAssertEqual(events, [])
            t += 0.1
        }
        XCTAssertEqual(r.state, .recognizing, "3.5s 边界内不取消")
        XCTAssertEqual(r.cancelCounts[.timeLimitExceeded], nil)
        XCTAssertEqual(r.fireCount, 0)

        // 超过 3.5s → 取消（锁存至释放）
        let events = processAt(&r, clock, frame(device, 3.6, .moved, squareContacts(halfSize: 0.2)))
        XCTAssertEqual(events, [])
        XCTAssertEqual(r.state, .waitingForRelease)
        XCTAssertEqual(r.cancelCounts[.timeLimitExceeded], 1)
        XCTAssertEqual(r.fireCount, 0)
    }

    // MARK: §19.2 合同 7：冷却只是附加保护

    func testCooldownSuppressesRapidRetriggerAcrossSessions() {
        // 生产默认参数（cooldown 0.5）
        let clock = FakePinchClock()
        var r = makeRecognizer(clock: clock, parameters: PinchParameters())

        // 第一次触发：t=0 落指，t=0.1 基线，t=0.11 收缩 → fire（lastFireTime=0.11）
        _ = runStandardPinch(&r, clock, device: device)
        XCTAssertEqual(r.fireCount, 1)

        // 释放
        _ = processAt(&r, clock, frame(device, 0.2, .moved, []))
        XCTAssertEqual(r.state, .idle)

        // 冷却内新会话（0.41 - 0.11 = 0.3 < 0.5）→ 抑制（无事件，仍锁存）
        _ = processAt(&r, clock, frame(device, 0.3, .began, squareContacts(halfSize: 0.2)))
        _ = processAt(&r, clock, frame(device, 0.4, .moved, squareContacts(halfSize: 0.2)))
        let suppressed = processAt(&r, clock, frame(device, 0.41, .moved, squareContacts(halfSize: 0.16)))
        XCTAssertEqual(suppressed, [])
        XCTAssertEqual(r.suppressedFireCount, 1)
        XCTAssertEqual(r.fireCount, 1)
        XCTAssertEqual(r.state, .fired)

        // 释放
        _ = processAt(&r, clock, frame(device, 0.5, .moved, []))
        XCTAssertEqual(r.state, .idle)

        // 冷却满（0.71 - 0.11 = 0.6 ≥ 0.5）→ 触发
        _ = processAt(&r, clock, frame(device, 0.6, .began, squareContacts(halfSize: 0.2)))
        _ = processAt(&r, clock, frame(device, 0.7, .moved, squareContacts(halfSize: 0.2)))
        let second = processAt(&r, clock, frame(device, 0.71, .moved, squareContacts(halfSize: 0.16)))
        XCTAssertEqual(second.count, 1)
        XCTAssertEqual(r.fireCount, 2)
    }

    // MARK: §19.2 合同 12：无回调超时 ≠ 全指释放

    func testContract12SilenceIsNotReleaseForLatchedSession() {
        let clock = FakePinchClock()
        var r = makeRecognizer(clock: clock)

        _ = runStandardPinch(&r, clock, device: device)
        XCTAssertEqual(r.state, .fired)

        // 长时间静默（无结束证据）→ 锁存保持，不重新武装、不重复触发
        clock.current = 10.0
        let events = r.process(frame(device, 10.0, .moved, squareContacts(halfSize: 0.1)))
        XCTAssertEqual(events, [], "静默不重新武装，不重复触发")
        XCTAssertEqual(r.state, .fired)
        XCTAssertEqual(r.fireCount, 1)

        // 显式结束证据 → 释放
        _ = processAt(&r, clock, frame(device, 10.1, .moved, []))
        XCTAssertEqual(r.state, .idle)
    }

    // MARK: T-G-P7 R-08（M-1 回归）：静默过期移除会话后必须刷新聚合状态

    func testM1SilentExpiryWithNonFourContactsRefreshesToIdle() {
        let clock = FakePinchClock()
        var r = makeRecognizer(clock: clock)

        // A: t=0 四指 → 候选（首帧基线）
        _ = processAt(&r, clock, frame(device, 0, .began, squareContacts(halfSize: 0.2)))
        XCTAssertEqual(r.state, .candidate)

        // B: 静默超限（0.6 - 0 = 0.6 > 0.5）后同帧仅 2 触点（≠4）→ 会话被 dataExpired 移除，
        //    无会话分支提前 return；state 必须刷新为 .idle（M-1：不得停留在 .candidate）
        let twoContacts = Array(squareContacts(halfSize: 0.2).prefix(2))
        let events = processAt(&r, clock, frame(device, 0.6, .moved, twoContacts))
        XCTAssertEqual(events, [])
        XCTAssertEqual(r.cancelCounts[.dataExpired], 1)
        XCTAssertEqual(r.state, .idle, "静默过期移除会话后同帧触点数≠4，state 必须回到 .idle")
        XCTAssertNil(r.activeSessionID, "sessions 已空，activeSessionID 必须清空")
        XCTAssertNil(r.activeDeviceID, "sessions 已空，activeDeviceID 必须清空")
        XCTAssertEqual(r.fireCount, 0)

        // C: 后续 4 触点帧 → 新候选（识别器仍可正常工作）
        _ = processAt(&r, clock, frame(device, 0.7, .began, squareContacts(halfSize: 0.2)))
        XCTAssertEqual(r.state, .candidate)

        // D: 结束证据 → idle
        _ = processAt(&r, clock, frame(device, 0.8, .moved, []))
        XCTAssertEqual(r.state, .idle)
    }
}
