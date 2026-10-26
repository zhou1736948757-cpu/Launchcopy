import AppKit
import XCTest
@testable import AppIconPipeline

final class IconPipelineReplacementTests: XCTestCase {
    func testCancelledLateSuccessCannotConsumePendingReplacement() {
        let startedOld = expectation(description: "old loader admitted")
        let startedNew = expectation(description: "replacement loader admitted")
        let loader = ReplacementControlledLoader(started: [startedOld, startedNew])
        let pipeline = IconPipeline(loader: loader, limits: .init())
        defer { pipeline.shutdown(); loader.finishRemaining() }
        let oldDelivered = expectation(description: "cancelled consumer must stay silent")
        oldDelivered.isInverted = true
        let key = makeKey(7101)
        let old = pipeline.request(key: key, generation: 1) { _, _, _ in oldDelivered.fulfill() }
        wait(for: [startedOld], timeout: 3)
        old.cancel()

        let releasedNew = ValueBox(false)
        let earlyNew = expectation(description: "old work cannot finish replacement")
        earlyNew.isInverted = true
        let newDelivered = expectation(description: "new consumer receives its own image")
        let fresh = makeIconImage(pixelWidth: 16, pixelHeight: 16, r: 0, g: 220, b: 0)
        pipeline.request(key: key, generation: 2) { _, generation, result in
            if !releasedNew.value { earlyNew.fulfill() }
            XCTAssertEqual(generation, 2)
            guard case .success(let image) = result else { return XCTFail("Expected fresh success") }
            XCTAssertTrue(image === fresh, "A replacement must not receive the cancelled load's image.")
            newDelivered.fulfill()
        }
        wait(for: [startedNew], timeout: 3)
        loader.finish(ordinal: 0, image: makeIconImage(pixelWidth: 16, pixelHeight: 16, r: 220, g: 0, b: 0))
        wait(for: [earlyNew, oldDelivered], timeout: 0.2)

        // While the new load is held, another consumer must merge, not hit an old cache entry.
        let mergedDelivered = expectation(description: "merged consumer receives fresh image")
        pipeline.request(key: key, generation: 3) { _, generation, result in
            XCTAssertEqual(generation, 3)
            guard case .success(let image) = result else { return XCTFail("Expected fresh success") }
            XCTAssertTrue(image === fresh)
            mergedDelivered.fulfill()
        }
        XCTAssertEqual(pipeline.stats.cacheHits, 0)
        XCTAssertEqual(pipeline.stats.inFlightMerged, 1)
        releasedNew.set(true)
        loader.finish(ordinal: 1, image: fresh)
        wait(for: [newDelivered, mergedDelivered], timeout: 3)
    }

    func testCancelAllLateSuccessCannotOverwriteCompletedReplacementCache() {
        let startedOld = expectation(description: "old loader admitted")
        let startedNew = expectation(description: "replacement loader admitted")
        let loader = ReplacementControlledLoader(started: [startedOld, startedNew])
        let pipeline = IconPipeline(loader: loader, limits: .init())
        defer { pipeline.shutdown(); loader.finishRemaining() }
        let oldDelivered = expectation(description: "cancelAll consumers stay silent")
        oldDelivered.isInverted = true
        let key = makeKey(7102)
        pipeline.request(key: key, generation: 1) { _, _, _ in oldDelivered.fulfill() }
        wait(for: [startedOld], timeout: 3)
        pipeline.cancelAll(for: key)

        let fresh = makeIconImage(pixelWidth: 16, pixelHeight: 16, r: 0, g: 220, b: 0)
        let newDelivered = expectation(description: "fresh result finishes first")
        pipeline.request(key: key, generation: 2) { _, _, result in
            guard case .success(let image) = result else { return XCTFail("Expected fresh success") }
            XCTAssertTrue(image === fresh)
            newDelivered.fulfill()
        }
        wait(for: [startedNew], timeout: 3)
        loader.finish(ordinal: 1, image: fresh)
        wait(for: [newDelivered], timeout: 3)
        loader.finish(ordinal: 0, image: makeIconImage(pixelWidth: 16, pixelHeight: 16, r: 220, g: 0, b: 0))
        wait(for: [oldDelivered], timeout: 0.2)

        let cachedDelivered = expectation(description: "cache retains fresh result")
        pipeline.request(key: key, generation: 3) { _, _, result in
            guard case .success(let image) = result else { return XCTFail("Expected cached success") }
            XCTAssertTrue(image === fresh, "Cancelled late work must not overwrite the fresh cache entry.")
            cachedDelivered.fulfill()
        }
        wait(for: [cachedDelivered], timeout: 3)
        XCTAssertEqual(pipeline.stats.cacheHits, 1)
    }
}

/// Intentionally ignores cancellation to model a non-cooperative native decoder.
/// Ordinals distinguish concurrent requests for the same key. No files or real icons.
private final class ReplacementControlledLoader: IconLoading, @unchecked Sendable {
    private let lock = NSLock()
    private let started: [XCTestExpectation]
    private var nextOrdinal = 0
    private var isClosed = false
    private var pending: [Int: CheckedContinuation<NSImage, Error>] = [:]

    init(started: [XCTestExpectation]) { self.started = started }

    func load(key: IconKey) async throws -> NSImage {
        try await withCheckedThrowingContinuation { continuation in
            lock.lock()
            guard !isClosed else {
                lock.unlock()
                continuation.resume(throwing: CancellationError())
                return
            }
            let ordinal = nextOrdinal
            nextOrdinal += 1
            pending[ordinal] = continuation
            lock.unlock()
            if ordinal < started.count { started[ordinal].fulfill() }
        }
    }

    func finish(ordinal: Int, image: NSImage) {
        lock.lock()
        let continuation = pending.removeValue(forKey: ordinal)
        lock.unlock()
        continuation?.resume(returning: image)
    }

    func finishRemaining() {
        lock.lock()
        isClosed = true
        let continuations = Array(pending.values)
        pending.removeAll()
        lock.unlock()
        for continuation in continuations { continuation.resume(throwing: CancellationError()) }
    }
}
