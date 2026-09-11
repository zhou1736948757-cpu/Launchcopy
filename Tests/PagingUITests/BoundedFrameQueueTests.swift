//
//  BoundedFrameQueueTests.swift
//  PagingUITests
//
//  Phase 1G T-G-P6：有界缓冲丢弃策略（§20.2）——过载只丢 moved，
//  保留 began/ended/cancelled（重新武装条件）；无 moved 可丢时拒绝新帧。
//  与 MockTouchProvider 的 maxQueueSize=64 语义一致。
//

import XCTest
@testable import PagingPrototypeApp

final class BoundedFrameQueueTests: XCTestCase {

    private let device = PinchDeviceID(rawValue: 1)

    private func frame(_ phase: PinchFramePhase, contacts: Int = 4) -> PinchFrame {
        PinchFrame(deviceID: device, timestamp: 0, phase: phase,
                   contacts: (0..<contacts).map {
                       PinchContact(id: PinchContactID(rawValue: $0),
                                    position: PinchPoint(x: 0.1 * Double($0), y: 0.1))
                   })
    }

    func testBoundedDropsMovedKeepsBeginEndCancel() {
        let q = BoundedFrameQueue(maxSize: 2)
        XCTAssertEqual(q.enqueue(frame(.began)), .accepted)
        XCTAssertEqual(q.enqueue(frame(.moved)), .accepted)
        XCTAssertEqual(q.enqueue(frame(.moved)), .droppedMoved)
        XCTAssertEqual(q.enqueue(frame(.moved)), .droppedMoved)
        XCTAssertEqual(q.enqueue(frame(.ended)), .droppedMoved, "ended 入队也丢一个 moved 腾位（不拒绝关键帧）")
        XCTAssertEqual(q.count, 2, "缓冲有界")
        XCTAssertEqual(q.droppedMovedCount, 3, "过载只丢 moved")
        XCTAssertEqual(q.rejectedCount, 0, "关键帧不丢")
        let drained = q.drain()
        XCTAssertEqual(drained.map(\.phase), [.began, .ended], "保留 begin/end（重新武装条件）")
    }

    func testFullWithoutMovedRejects() {
        let q = BoundedFrameQueue(maxSize: 2)
        _ = q.enqueue(frame(.began))
        _ = q.enqueue(frame(.ended))
        XCTAssertEqual(q.enqueue(frame(.began)), .rejected, "无 moved 可丢时拒绝新帧")
        XCTAssertEqual(q.rejectedCount, 1)
        XCTAssertEqual(q.count, 2)
    }

    func testDrainPreservesOrder() {
        let q = BoundedFrameQueue(maxSize: 8)
        _ = q.enqueue(frame(.began))
        _ = q.enqueue(frame(.moved))
        _ = q.enqueue(frame(.ended))
        XCTAssertEqual(q.drain().map(\.phase), [.began, .moved, .ended])
        XCTAssertEqual(q.count, 0)
    }

    func testRemoveAllClears() {
        let q = BoundedFrameQueue(maxSize: 4)
        _ = q.enqueue(frame(.began))
        q.removeAll()
        XCTAssertEqual(q.count, 0)
        XCTAssertEqual(q.drain().count, 0)
    }

    func testMaxSizeClampedToAtLeastOne() {
        let q = BoundedFrameQueue(maxSize: 0)
        XCTAssertEqual(q.enqueue(frame(.began)), .accepted)
        XCTAssertEqual(q.enqueue(frame(.moved)), .rejected, "maxSize=1：满且无 moved 可丢")
    }
}
