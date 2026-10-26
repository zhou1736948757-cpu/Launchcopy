import AppKit
import XCTest
@testable import AppIconPipeline

/// A held synthetic load intentionally ignores cancellation, like native decoding.
private actor PermitCancellationLoader: IconLoading {
    let blockedKey: IconKey
    private(set) var seen: [IconKey] = []
    private var continuation: CheckedContinuation<NSImage, Never>?
    private var released = false
    init(blockedKey: IconKey) { self.blockedKey = blockedKey }
    func load(key: IconKey) async throws -> NSImage {
        seen.append(key)
        if key == blockedKey && !released {
            return await withCheckedContinuation { continuation = $0 }
        }
        return makeIconImage(pixelWidth: 16, pixelHeight: 16)
    }
    func release() {
        released = true
        continuation?.resume(returning: makeIconImage(pixelWidth: 16, pixelHeight: 16))
        continuation = nil
    }
}

@MainActor
final class IconPipelinePermitCancellationTests: XCTestCase {
    private func eventually(_ condition: () async -> Bool, file: StaticString = #filePath, line: UInt = #line) async {
        let deadline = ContinuousClock.now.advanced(by: .seconds(3))
        while !(await condition()), ContinuousClock.now < deadline { try? await Task.sleep(for: .milliseconds(1)) }
        let met = await condition()
        XCTAssertTrue(met, file: file, line: line)
    }

    func testCanceledQueuedWarmupCannotInvokeLoaderAheadOfLiveRequest() async {
        let blocker = makeKey(8100), idle = makeKey(8101), live = makeKey(8102)
        let loader = PermitCancellationLoader(blockedKey: blocker)
        let pipeline = IconPipeline(loader: loader, limits: .init(maxConcurrentLoads: 1))
        let liveDelivered = ValueBox(false)
        let canceledCallbacks = CallbackBox()
        pipeline.request(key: blocker, generation: 1) { _, _, _ in }
        await eventually { await loader.seen == [blocker] }
        let handle = pipeline.request(key: idle, generation: 1) { _, _, _ in canceledCallbacks.increment() }
        await eventually { await pipeline.waitingLoadCount == 1 }
        handle.cancel()
        await eventually { await pipeline.waitingLoadCount == 0 }
        pipeline.request(key: live, generation: 2) { _, _, result in
            if case .success = result { liveDelivered.set(true) }
        }
        await eventually { await pipeline.waitingLoadCount >= 1 }
        await loader.release()
        await eventually { liveDelivered.value }
        let seen = await loader.seen
        XCTAssertEqual(seen, [blocker, live])
        XCTAssertEqual(canceledCallbacks.count, 0)
        pipeline.shutdown()
    }

    func testRepeatedCanceledWaitersAreReclaimedBeforeHeldNativeWorkReturns() async {
        let blocker = makeKey(8200), live = makeKey(8299)
        let loader = PermitCancellationLoader(blockedKey: blocker)
        let pipeline = IconPipeline(loader: loader, limits: .init(maxConcurrentLoads: 1))
        let delivered = ValueBox(false)
        let canceledCallbacks = CallbackBox()
        pipeline.request(key: blocker, generation: 1) { _, _, _ in }
        await eventually { await loader.seen == [blocker] }
        for index in 1...12 {
            let handle = pipeline.request(key: makeKey(8200 + index), generation: 1) { _, _, _ in canceledCallbacks.increment() }
            await eventually { await pipeline.waitingLoadCount == 1 }
            handle.cancel()
            await eventually { await pipeline.waitingLoadCount == 0 }
        }
        let seenWhileBlocked = await loader.seen
        XCTAssertEqual(seenWhileBlocked, [blocker])
        pipeline.request(key: live, generation: 2) { _, _, result in
            if case .success = result { delivered.set(true) }
        }
        await eventually { await pipeline.waitingLoadCount == 1 }
        await loader.release()
        await eventually { delivered.value }
        let seen = await loader.seen
        XCTAssertEqual(seen, [blocker, live])
        XCTAssertEqual(canceledCallbacks.count, 0)
        pipeline.shutdown()
    }

    func testCancelOneQueuedConsumerPreservesMergedLiveDemand() async {
        let blocker = makeKey(8300), shared = makeKey(8301)
        let loader = PermitCancellationLoader(blockedKey: blocker)
        let pipeline = IconPipeline(loader: loader, limits: .init(maxConcurrentLoads: 1))
        let delivered = ValueBox(false)
        let canceledCallbacks = CallbackBox()
        pipeline.request(key: blocker, generation: 1) { _, _, _ in }
        await eventually { await loader.seen == [blocker] }
        let idle = pipeline.request(key: shared, generation: 1) { _, _, _ in canceledCallbacks.increment() }
        await eventually { await pipeline.waitingLoadCount == 1 }
        pipeline.request(key: shared, generation: 2) { _, generation, result in
            XCTAssertEqual(generation, 2)
            if case .success = result { delivered.set(true) }
        }
        idle.cancel()
        let waiting = await pipeline.waitingLoadCount
        XCTAssertEqual(waiting, 1)
        await loader.release()
        await eventually { delivered.value }
        let seen = await loader.seen
        XCTAssertEqual(seen, [blocker, shared])
        XCTAssertEqual(canceledCallbacks.count, 0)
        XCTAssertEqual(pipeline.stats.inFlightMerged, 1)
        pipeline.shutdown()
    }

    func testShutdownRemovesQueuedWaitersWithoutWaitingForBlockedDecoder() async {
        let blocker = makeKey(8400)
        let loader = PermitCancellationLoader(blockedKey: blocker)
        let pipeline = IconPipeline(loader: loader, limits: .init(maxConcurrentLoads: 1))
        let callbacks = CallbackBox()
        pipeline.request(key: blocker, generation: 1) { _, _, _ in callbacks.increment() }
        await eventually { await loader.seen == [blocker] }
        for index in 1...4 { pipeline.request(key: makeKey(8400 + index), generation: 1) { _, _, _ in callbacks.increment() } }
        await eventually { await pipeline.waitingLoadCount == 4 }
        pipeline.shutdown()
        await eventually { await pipeline.waitingLoadCount == 0 }
        let seen = await loader.seen
        XCTAssertEqual(seen, [blocker])
        await loader.release()
        XCTAssertEqual(callbacks.count, 0)
    }

}
