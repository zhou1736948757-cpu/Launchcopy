import AppKit
import Foundation
import XCTest
@testable import AppIconPipeline

/// Generated images only. Source changes revoke work, not public icon identities.
@MainActor
final class IconSourceInvalidationTests: XCTestCase {
    func testAllCachedVariantsAreEvictedButUnchangedIdentityStillHits() {
        let old = makeIconImage(pixelWidth: 16, pixelHeight: 16, r: 210, g: 0, b: 0)
        let fresh = makeIconImage(pixelWidth: 16, pixelHeight: 16, r: 0, g: 210, b: 0)
        let loader = SourceSwapLoader(image: old)
        let pipeline = IconPipeline(loader: loader, limits: .init())
        defer { pipeline.shutdown() }
        let keys = [makeKey(8101), makeKey(8101, pointSize: 64), makeKey(8102)]
        let seeded = expectation(description: "three initial variants")
        seeded.expectedFulfillmentCount = 3
        for key in keys {
            pipeline.request(key: key, generation: 1) { _, _, result in
                Self.assertImage(result, is: old)
                seeded.fulfill()
            }
        }
        wait(for: [seeded], timeout: 3)
        XCTAssertEqual(loader.calls, 3)
        loader.setImage(fresh)
        pipeline.invalidateSources(for: [keys[0].identity])
        XCTAssertEqual(pipeline.stats.evictions, 2)
        let rebound = expectation(description: "only affected identities reload")
        rebound.expectedFulfillmentCount = 3
        for (index, key) in keys.enumerated() {
            pipeline.request(key: key, generation: 2) { _, _, result in
                Self.assertImage(result, is: index < 2 ? fresh : old)
                rebound.fulfill()
            }
        }
        wait(for: [rebound], timeout: 3)
        XCTAssertEqual(loader.calls, 5)
        XCTAssertEqual(pipeline.stats.cacheHits, 1)
        pipeline.invalidateSources(for: [])
        XCTAssertEqual(pipeline.stats.evictions, 2)
        XCTAssertEqual(pipeline.queuedDeliveryCount, 0)
    }

    func testQueuedCacheHitIsRevokedBeforeMainActorCallback() {
        let old = makeIconImage(pixelWidth: 16, pixelHeight: 16, r: 210, g: 0, b: 0)
        let fresh = makeIconImage(pixelWidth: 16, pixelHeight: 16, r: 0, g: 210, b: 0)
        let loader = SourceSwapLoader(image: old)
        let pipeline = IconPipeline(loader: loader, limits: .init())
        defer { pipeline.shutdown() }
        let key = makeKey(8103)
        let seeded = expectation(description: "old cache seeded")
        pipeline.request(key: key, generation: 1) { _, _, _ in seeded.fulfill() }
        wait(for: [seeded], timeout: 3)
        let revoked = expectation(description: "queued old cache hit stays silent")
        revoked.isInverted = true
        // No await/run-loop pump between acceptance and invalidation.
        let oldHandle = pipeline.request(key: key, generation: 2) { _, _, _ in revoked.fulfill() }
        XCTAssertEqual(pipeline.queuedDeliveryCount, 1)
        pipeline.invalidateSources(for: [key.identity])
        XCTAssertEqual(pipeline.queuedDeliveryCount, 0)
        loader.setImage(fresh)
        let delivered = expectation(description: "current source delivered")
        pipeline.request(key: key, generation: 3) { _, generation, result in
            XCTAssertEqual(generation, 3)
            Self.assertImage(result, is: fresh)
            delivered.fulfill()
        }
        oldHandle.cancel() // An old handle must not cancel the replacement.
        wait(for: [delivered], timeout: 3)
        wait(for: [revoked], timeout: 0.1)
        XCTAssertEqual(loader.calls, 2)
        XCTAssertEqual(pipeline.queuedDeliveryCount, 0)
    }

    func testRetiredLateSuccessCannotConsumePendingReplacement() {
        let startedOld = expectation(description: "old source started")
        let startedNew = expectation(description: "current source started")
        let loader = SourceControlledLoader(started: [startedOld, startedNew])
        let pipeline = IconPipeline(loader: loader, limits: .init(maxConcurrentLoads: 2))
        defer { pipeline.shutdown(); loader.finishRemaining() }
        let key = makeKey(8104)
        let revoked = expectation(description: "old consumer revoked")
        revoked.isInverted = true
        pipeline.request(key: key, generation: 1) { _, _, _ in revoked.fulfill() }
        wait(for: [startedOld], timeout: 3)
        pipeline.invalidateSources(for: [key.identity])
        let fresh = makeIconImage(pixelWidth: 16, pixelHeight: 16, r: 0, g: 210, b: 0)
        let delivered = expectation(description: "current listeners receive own image")
        delivered.expectedFulfillmentCount = 2
        pipeline.request(key: key, generation: 2) { _, _, result in
            Self.assertImage(result, is: fresh)
            delivered.fulfill()
        }
        wait(for: [startedNew], timeout: 3)
        loader.finish(0, image: makeIconImage(pixelWidth: 16, pixelHeight: 16))
        waitForProcessedResults(1, in: pipeline) // New decoder remains gated.
        pipeline.request(key: key, generation: 3) { _, _, result in
            Self.assertImage(result, is: fresh)
            delivered.fulfill()
        }
        XCTAssertEqual(pipeline.stats.cacheHits, 0)
        XCTAssertEqual(pipeline.stats.inFlightMerged, 1)
        loader.finish(1, image: fresh)
        wait(for: [delivered], timeout: 3)
        wait(for: [revoked], timeout: 0.1)
        XCTAssertEqual(pipeline.stats.cancellations, 1)
    }

    func testRetiredLateSuccessCannotOverwriteCompletedReplacementCache() {
        let startedOld = expectation(description: "old source started")
        let startedNew = expectation(description: "current source started")
        let loader = SourceControlledLoader(started: [startedOld, startedNew])
        let pipeline = IconPipeline(loader: loader, limits: .init(maxConcurrentLoads: 2))
        defer { pipeline.shutdown(); loader.finishRemaining() }
        let key = makeKey(8105)
        let revoked = expectation(description: "old consumer revoked")
        revoked.isInverted = true
        pipeline.request(key: key, generation: 1) { _, _, _ in revoked.fulfill() }
        wait(for: [startedOld], timeout: 3)
        pipeline.invalidateSources(for: [key.identity])
        let fresh = makeIconImage(pixelWidth: 16, pixelHeight: 16, r: 0, g: 210, b: 0)
        let delivered = expectation(description: "replacement finished first")
        pipeline.request(key: key, generation: 2) { _, _, result in
            Self.assertImage(result, is: fresh)
            delivered.fulfill()
        }
        wait(for: [startedNew], timeout: 3)
        loader.finish(1, image: fresh)
        wait(for: [delivered], timeout: 3)
        loader.finish(0, image: makeIconImage(pixelWidth: 16, pixelHeight: 16))
        waitForProcessedResults(2, in: pipeline) // Fresh + old ownership decisions.
        wait(for: [revoked], timeout: 0.1)
        let cached = expectation(description: "cache still contains current image")
        pipeline.request(key: key, generation: 3) { _, _, result in
            Self.assertImage(result, is: fresh)
            cached.fulfill()
        }
        wait(for: [cached], timeout: 3)
        XCTAssertEqual(pipeline.stats.cacheHits, 1)
    }

    func testFinishedButQueuedDeliveryCanBeRevokedBeforeMainActorRunsIt() {
        let started = expectation(description: "controlled loader started")
        let loader = SourceControlledLoader(started: [started])
        let pipeline = IconPipeline(loader: loader, limits: .init())
        defer { pipeline.shutdown(); loader.finishRemaining() }
        let key = makeKey(8106)
        let revoked = expectation(description: "completed old source callback revoked")
        revoked.isInverted = true
        pipeline.request(key: key, generation: 1) { _, _, _ in revoked.fulfill() }
        wait(for: [started], timeout: 3)
        loader.finish(0, image: makeIconImage(pixelWidth: 16, pixelHeight: 16))
        // Deliberately hold MainActor only in this synchronous test fixture while
        // background finish registers its receipt. The counter, not elapsed time,
        // proves the exact queued-before-callback boundary.
        let clock = ContinuousClock()
        let deadline = clock.now.advanced(by: .seconds(3))
        while pipeline.queuedDeliveryCount == 0 && clock.now < deadline {
            Thread.sleep(forTimeInterval: 0.001)
        }
        XCTAssertEqual(pipeline.queuedDeliveryCount, 1)
        pipeline.invalidateSources(for: [key.identity])
        XCTAssertEqual(pipeline.queuedDeliveryCount, 0)
        wait(for: [revoked], timeout: 0.1)
        pipeline.shutdown()
        pipeline.invalidateSources(for: [key.identity])
        XCTAssertEqual(pipeline.queuedDeliveryCount, 0)
    }

    func testRetirementCancelsOutsideLockSoHandlerCanReadPipelineStats() {
        let started = expectation(description: "cancellable loader admitted")
        let cancelled = expectation(description: "handler reentered pipeline without deadlock")
        let loader = SourceCancellationLoader(started: started)
        let pipeline = IconPipeline(loader: loader, limits: .init())
        defer {
            pipeline.shutdown()
            loader.finish()
            loader.onCancellation.set(nil)
        }
        loader.onCancellation.set {
            XCTAssertEqual(pipeline.stats.cancellations, 1)
            cancelled.fulfill()
        }
        let revoked = expectation(description: "cancelled source stays silent")
        revoked.isInverted = true
        let key = makeKey(8107)
        pipeline.request(key: key, generation: 1) { _, _, _ in revoked.fulfill() }
        wait(for: [started], timeout: 3)
        pipeline.invalidateSources(for: [key.identity])
        wait(for: [cancelled], timeout: 3)
        loader.finish()
        wait(for: [revoked], timeout: 0.1)
    }

    private func waitForProcessedResults(_ count: UInt64, in pipeline: IconPipeline,
                                         file: StaticString = #filePath, line: UInt = #line) {
        // MainActor is deliberately held to keep queued callbacks from admitting.
        // Positive state acknowledgment proves the finish decision, not decoder return.
        let clock = ContinuousClock()
        let deadline = clock.now.advanced(by: .seconds(3))
        while pipeline.processedLoadResultCount < count && clock.now < deadline {
            Thread.sleep(forTimeInterval: 0.001)
        }
        XCTAssertGreaterThanOrEqual(pipeline.processedLoadResultCount, count, file: file, line: line)
    }

    private static func assertImage(_ result: IconResult, is expected: NSImage,
                                    file: StaticString = #filePath, line: UInt = #line) {
        guard case .success(let image) = result else {
            return XCTFail("Expected generated image", file: file, line: line)
        }
        XCTAssertTrue(image === expected, "Unexpected source incarnation", file: file, line: line)
    }
}

private final class SourceSwapLoader: IconLoading, @unchecked Sendable {
    private let lock = NSLock()
    private var image: NSImage
    private var count = 0
    init(image: NSImage) { self.image = image }
    var calls: Int { lock.lock(); defer { lock.unlock() }; return count }
    func setImage(_ image: NSImage) { lock.lock(); self.image = image; lock.unlock() }
    private func snapshot() -> NSImage {
        lock.lock(); defer { lock.unlock() }
        count += 1
        return image
    }
    func load(key: IconKey) async throws -> NSImage { snapshot() }
}

/// Non-cooperative decoder: an old continuation may complete after invalidation.
private final class SourceControlledLoader: IconLoading, @unchecked Sendable {
    private let lock = NSLock()
    private let started: [XCTestExpectation]
    private var next = 0
    private var closed = false
    private var pending: [Int: CheckedContinuation<NSImage, Error>] = [:]
    init(started: [XCTestExpectation]) { self.started = started }
    func load(key: IconKey) async throws -> NSImage {
        try await withCheckedThrowingContinuation { continuation in
            lock.lock()
            guard !closed else {
                lock.unlock()
                continuation.resume(throwing: CancellationError())
                return
            }
            let ordinal = next
            next += 1
            pending[ordinal] = continuation
            lock.unlock()
            if ordinal < started.count { started[ordinal].fulfill() }
        }
    }
    func finish(_ ordinal: Int, image: NSImage) {
        lock.lock()
        let continuation = pending.removeValue(forKey: ordinal)
        lock.unlock()
        continuation?.resume(returning: image)
    }
    func finishRemaining() {
        lock.lock()
        closed = true
        let continuations = Array(pending.values)
        pending.removeAll()
        lock.unlock()
        for continuation in continuations { continuation.resume(throwing: CancellationError()) }
    }
}

/// Only the test uses a synchronous cancellation observer; production loaders may
/// also register one, so invalidation must not invoke it while owning the lock.
private final class SourceCancellationLoader: IconLoading, @unchecked Sendable {
    let onCancellation = ValueBox<(@Sendable () -> Void)?>(nil)
    private let started: XCTestExpectation
    private let lock = NSLock()
    private var continuation: CheckedContinuation<NSImage, Error>?
    private var closed = false
    init(started: XCTestExpectation) { self.started = started }
    func load(key: IconKey) async throws -> NSImage {
        try await withTaskCancellationHandler(operation: {
            try await withCheckedThrowingContinuation { continuation in
                lock.lock()
                guard !closed else {
                    lock.unlock()
                    continuation.resume(throwing: CancellationError())
                    return
                }
                self.continuation = continuation
                lock.unlock()
                started.fulfill()
            }
        }, onCancel: { self.onCancellation.value?() })
    }
    func finish() {
        lock.lock()
        let pending = continuation
        closed = true
        continuation = nil
        lock.unlock()
        pending?.resume(throwing: CancellationError())
    }
}
