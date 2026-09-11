//
//  MultitouchFrameSynthesisTests.swift
//  PagingUITests
//
//  Phase 1G T-G-P6：帧序列分类（began → moved* → ended）、
//  零触点/全离面结束证据、设备隔离、单调时间锚定、触点身份映射。
//  R-02 定案（rawdiag 64905 帧）：state 为位掩码（4=在表面静止 / 5=接触 / 6=移动 / 7=接触+移动；
//  回调从不报 0；离面 = 触点从帧消失），began/ended 由帧间 identifier 集合 diff 判定，
//  cancelled 概念删除（触点消失即 ended）。
//  纯逻辑测试（MultitouchFrameSynthesizer），不触碰真实设备。
//

import XCTest
@testable import PagingPrototypeApp

final class MultitouchFrameSynthesisTests: XCTestCase {

    private let device = PinchDeviceID(rawValue: 1)

    private func makeSynthesizer() -> MultitouchFrameSynthesizer {
        MultitouchFrameSynthesizer()
    }

    private func touch(_ id: Int32, _ state: Int32, _ x: Float = 0.5, _ y: Float = 0.5) -> RawTouch {
        RawTouch(identifier: id, state: state, x: x, y: y)
    }

    /// 四指平放静止帧（R-02 位掩码：state=4 = 在表面）。
    private func fourFingers(_ state: Int32) -> [RawTouch] {
        [touch(1, state), touch(2, state), touch(3, state), touch(4, state)]
    }

    // MARK: 位掩码常量

    func testMTTouchStateConstantsAreRealBitmask() {
        XCTAssertEqual(MTTouchState.notTouching, 0)
        XCTAssertEqual(MTTouchState.contactEventBit, 1)
        XCTAssertEqual(MTTouchState.moveEventBit, 2)
        XCTAssertEqual(MTTouchState.onSurfaceBit, 4)
        // 旧枚举常量（began=1/moved=2/ended=3/cancelled=4）已整体删除（R-02 定案），
        // 编译期已无按枚举值判定路径；相位一律由帧间 identifier diff 产出。
    }

    // MARK: 序列分类（帧间 identifier diff；R-02 定案）

    func testBeganMovedEndedSequence() {
        var s = makeSynthesizer()
        // 首帧（state=5 接触事件）：会话未开 && active 非空 → .began
        let began = s.synthesize(deviceID: device, callbackTimestamp: 100.0,
                                 touches: fourFingers(5), uptimeNow: 10.0)
        XCTAssertEqual(began.map(\.phase), [.began])
        XCTAssertEqual(began[0].contacts.count, 4)

        // 同 identifier 集合、state=6（移动）→ .moved
        let moved = s.synthesize(deviceID: device, callbackTimestamp: 100.1,
                                 touches: fourFingers(6), uptimeNow: 10.1)
        XCTAssertEqual(moved.map(\.phase), [.moved])

        // 触点从帧消失（count=0 空帧）= 结束证据 → .ended
        let ended = s.synthesize(deviceID: device, callbackTimestamp: 100.2,
                                 touches: [], uptimeNow: 10.2)
        XCTAssertEqual(ended.map(\.phase), [.ended])
        XCTAssertTrue(ended[0].contacts.isEmpty)

        // 会话关闭后可重新 began（重新武装条件）
        let again = s.synthesize(deviceID: device, callbackTimestamp: 100.3,
                                 touches: [touch(1, 5)], uptimeNow: 10.3)
        XCTAssertEqual(again.map(\.phase), [.began])
    }

    func testFourFingerRestFramesAreMovedNotCancelled() {
        // R-02 核心回归：四指平放连续帧 [4,4,4,4]×N 必须 began 1 次 + moved N-1 次，
        // 绝不产出 cancelled（旧假设 state==4=cancelled 每帧关会话）。
        var s = makeSynthesizer()
        var phases: [PinchFramePhase] = []
        var contactCounts: [Int] = []
        for i in 0..<6 {
            let frames = s.synthesize(deviceID: device, callbackTimestamp: Double(i) * 0.01,
                                      touches: fourFingers(4), uptimeNow: Double(i) * 0.01)
            XCTAssertEqual(frames.count, 1)
            phases.append(frames[0].phase)
            contactCounts.append(frames[0].contacts.count)
        }
        XCTAssertEqual(phases, [.began, .moved, .moved, .moved, .moved, .moved],
                       "began 1 次 + moved 5 次，无 cancelled")
        XCTAssertFalse(phases.contains(.cancelled))
        XCTAssertEqual(contactCounts, [4, 4, 4, 4, 4, 4], "每帧 4 触点保持")
    }

    func testStateFourOnSurfaceFrameIsMovedNotCancelled() {
        var s = makeSynthesizer()
        _ = s.synthesize(deviceID: device, callbackTimestamp: 0, touches: [touch(1, 5)], uptimeNow: 0)
        // state=4（在表面静止）会话中帧 → .moved（旧假设判 cancelled）
        let rest = s.synthesize(deviceID: device, callbackTimestamp: 0.1,
                                touches: [touch(1, 4)], uptimeNow: 0.1)
        XCTAssertEqual(rest.map(\.phase), [.moved])
        XCTAssertFalse(rest.map(\.phase).contains(.cancelled))
    }

    func testZeroTouchFrameIsEndEvidence() {
        var s = makeSynthesizer()
        _ = s.synthesize(deviceID: device, callbackTimestamp: 0, touches: [touch(1, 5)], uptimeNow: 0)
        let zero = s.synthesize(deviceID: device, callbackTimestamp: 0.1, touches: [], uptimeNow: 0.1)
        XCTAssertEqual(zero.map(\.phase), [.ended])
        XCTAssertTrue(zero[0].contacts.isEmpty)
    }

    func testOffSurfaceFrameIsEndEvidence() {
        var s = makeSynthesizer()
        _ = s.synthesize(deviceID: device, callbackTimestamp: 0, touches: [touch(1, 5)], uptimeNow: 0)
        // state=0（离面）→ active 空 → 结束证据（R-02：回调实际不报 0，但保留防御）
        let off = s.synthesize(deviceID: device, callbackTimestamp: 0.1,
                               touches: [touch(1, 0)], uptimeNow: 0.1)
        XCTAssertEqual(off.map(\.phase), [.ended], "全部离面 = 结束证据")
    }

    func testEndedWithoutSessionRejected() {
        var s = makeSynthesizer()
        let ended = s.synthesize(deviceID: device, callbackTimestamp: 0, touches: [], uptimeNow: 0)
        XCTAssertTrue(ended.isEmpty, "无会话 ended（空帧）拒绝")
    }

    func testActiveFrameWithoutSessionOpensSession() {
        // R-02 语义：任意非零 state 帧（含旧 state=2『moved』/state=3 值）在无会话时 → .began
        var s = makeSynthesizer()
        let began = s.synthesize(deviceID: device, callbackTimestamp: 0,
                                 touches: [touch(1, 6)], uptimeNow: 0)
        XCTAssertEqual(began.map(\.phase), [.began], "无会话的活动帧开新会话")
    }

    func testMidSessionNewFingerStaysMoved() {
        var s = makeSynthesizer()
        _ = s.synthesize(deviceID: device, callbackTimestamp: 0, touches: [touch(1, 5)], uptimeNow: 0)
        // 部分新 identifier 出现（会话中段新指落面）→ 保持 .moved（不重复 began）
        let mid = s.synthesize(deviceID: device, callbackTimestamp: 0.1,
                               touches: [touch(1, 6), touch(2, 5)], uptimeNow: 0.1)
        XCTAssertEqual(mid.map(\.phase), [.moved], "会话中段新指落面降级为 moved（不重复 began）")
        XCTAssertEqual(mid[0].contacts.count, 2)
    }

    func testPartialVanishKeepsRemainingContacts() {
        var s = makeSynthesizer()
        let began = s.synthesize(deviceID: device, callbackTimestamp: 0,
                                 touches: [touch(1, 5), touch(2, 5)], uptimeNow: 0)
        // 触点 2 从帧消失（部分消失）→ 剩余触点继续 .moved；会话保持开
        let moved = s.synthesize(deviceID: device, callbackTimestamp: 0.1,
                                 touches: [touch(1, 6)], uptimeNow: 0.1)
        XCTAssertEqual(moved.map(\.phase), [.moved])
        XCTAssertEqual(moved[0].contacts.count, 1)
        XCTAssertEqual(moved[0].contacts[0].id, began[0].contacts[0].id,
                       "剩余触点身份保持稳定")
        // 消失触点重现身 = 新触点（新 PinchContactID）
        let again = s.synthesize(deviceID: device, callbackTimestamp: 0.2,
                                 touches: [touch(1, 6), touch(2, 5)], uptimeNow: 0.2)
        XCTAssertEqual(again.map(\.phase), [.moved])
        XCTAssertNotEqual(again[0].contacts[1].id, began[0].contacts[1].id,
                          "消失后重现身的新触点获得新身份")
    }

    func testAllNewIdentifiersReanchorBegan() {
        var s = makeSynthesizer()
        _ = s.synthesize(deviceID: device, callbackTimestamp: 0,
                         touches: [touch(1, 5), touch(2, 5)], uptimeNow: 0)
        // 全部触点均为新 identifier（重锚定/首帧类场景）→ .began 重开会话
        let reanchor = s.synthesize(deviceID: device, callbackTimestamp: 0.1,
                                    touches: [touch(7, 5), touch(8, 5)], uptimeNow: 0.1)
        XCTAssertEqual(reanchor.map(\.phase), [.began], "全部新出现 → 重锚定 .began")
        XCTAssertEqual(reanchor[0].contacts.count, 2)
        // 新会话全新触点 ID（不沿用旧会话身份）
        XCTAssertNotEqual(reanchor[0].contacts[0].id, s.devices[device]?.contactIDs[1])
        XCTAssertFalse(reanchor[0].contacts.contains { $0.id == s.devices[device]?.contactIDs[1] })
    }

    func testTouchDisappearanceEndsSession() {
        // R-02 触点消失语义：消失 → ended（触点从帧消失），会话仅全部消失后关闭
        var s = makeSynthesizer()
        let began = s.synthesize(deviceID: device, callbackTimestamp: 0,
                                 touches: [touch(1, 5), touch(2, 5)], uptimeNow: 0)
        XCTAssertEqual(began.map(\.phase), [.began])
        // 空帧（全部消失）→ ended，会话关
        let ended = s.synthesize(deviceID: device, callbackTimestamp: 0.1, touches: [], uptimeNow: 0.1)
        XCTAssertEqual(ended.map(\.phase), [.ended])
        // 会话关后可再 began
        let again = s.synthesize(deviceID: device, callbackTimestamp: 0.2,
                                 touches: [touch(3, 5)], uptimeNow: 0.2)
        XCTAssertEqual(again.map(\.phase), [.began])
    }

    func testUnknownStateTreatedAsActive() {
        var s = makeSynthesizer()
        _ = s.synthesize(deviceID: device, callbackTimestamp: 0, touches: [touch(1, 5)], uptimeNow: 0)
        // state=7（接触+移动位组合）会话中帧 → .moved（未知/组合状态视为活跃）
        let unknown = s.synthesize(deviceID: device, callbackTimestamp: 0.1,
                                   touches: [touch(1, 7)], uptimeNow: 0.1)
        XCTAssertEqual(unknown.map(\.phase), [.moved], "非零 state 视为活跃")
    }

    // MARK: 设备隔离

    func testDeviceIsolation() {
        var s = makeSynthesizer()
        let d1 = PinchDeviceID(rawValue: 1)
        let d2 = PinchDeviceID(rawValue: 2)
        _ = s.synthesize(deviceID: d1, callbackTimestamp: 0, touches: [touch(1, 5)], uptimeNow: 0)
        // d2 无会话：空帧 ended 拒绝
        XCTAssertTrue(s.synthesize(deviceID: d2, callbackTimestamp: 0, touches: [], uptimeNow: 0).isEmpty)
        // d2 独立 began
        XCTAssertEqual(s.synthesize(deviceID: d2, callbackTimestamp: 0, touches: [touch(1, 5)], uptimeNow: 0).map(\.phase), [.began])
        // d1 会话不受 d2 影响
        XCTAssertEqual(s.synthesize(deviceID: d1, callbackTimestamp: 0.1, touches: [touch(1, 6)], uptimeNow: 0.1).map(\.phase), [.moved])
    }

    // MARK: 单调时间域

    func testTimestampsAnchoredToSystemUptimeDomain() {
        var s = makeSynthesizer()
        let first = s.synthesize(deviceID: device, callbackTimestamp: 1000.0,
                                 touches: [touch(1, 5)], uptimeNow: 42.0)
        XCTAssertEqual(first[0].timestamp, 42.0, accuracy: 1e-9, "首帧锚定到 systemUptime")
        let second = s.synthesize(deviceID: device, callbackTimestamp: 1000.1,
                                  touches: [touch(1, 6)], uptimeNow: 42.1)
        XCTAssertEqual(second[0].timestamp, 42.1, accuracy: 1e-9, "相对增量保持（systemUptime 域）")
    }

    func testTimestampsMonotonic() {
        var s = makeSynthesizer()
        var last: TimeInterval = -1
        for i in 0..<10 {
            let frames = s.synthesize(deviceID: device, callbackTimestamp: Double(i) * 0.1,
                                      touches: [touch(1, i == 0 ? 5 : 6)],
                                      uptimeNow: Double(i) * 0.1)
            XCTAssertEqual(frames.count, 1)
            XCTAssertGreaterThanOrEqual(frames[0].timestamp, last)
            last = frames[0].timestamp
        }
    }

    // MARK: 触点身份

    func testContactIDsStableWithinSession() {
        var s = makeSynthesizer()
        let began = s.synthesize(deviceID: device, callbackTimestamp: 0,
                                 touches: [touch(1, 5), touch(2, 5)], uptimeNow: 0)
        let moved = s.synthesize(deviceID: device, callbackTimestamp: 0.1,
                                 touches: [touch(1, 6), touch(2, 6)], uptimeNow: 0.1)
        XCTAssertEqual(began[0].contacts.map(\.id), moved[0].contacts.map(\.id), "会话内触点身份稳定")
    }

    func testContactIDsFreshPerSession() {
        var s = makeSynthesizer()
        _ = s.synthesize(deviceID: device, callbackTimestamp: 0, touches: [touch(1, 5)], uptimeNow: 0)
        _ = s.synthesize(deviceID: device, callbackTimestamp: 0.1, touches: [], uptimeNow: 0.1) // ended
        let again = s.synthesize(deviceID: device, callbackTimestamp: 0.2, touches: [touch(1, 5)], uptimeNow: 0.2)
        XCTAssertEqual(again.map(\.phase), [.began])
        XCTAssertNotEqual(again[0].contacts[0].id.rawValue, 1, "新会话全新触点 ID")
    }
}
