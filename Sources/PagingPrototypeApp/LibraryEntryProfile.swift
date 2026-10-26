import Dispatch
import Foundation

/// Bounded, in-memory diagnostics. Main creates this only after candidate/profile
/// admission and owns normal-quit export. No observers or I/O are installed here.
@MainActor
final class LibraryEntryProfile {
    enum Event: String, Codable, CaseIterable {
        case shellConstruction, entry, renderProjection
        case viewApply, viewLayout, viewFocus, galleryApply, galleryLayout, cardLayout, galleryIcons
        case parentBegin, parentInput, parentFrame, parentRender, parentCommit
        case projectionRequested, projectionDelivered, materialPolicy, iconDelivery
        case runLoopEntry, runLoopExit, runLoopBeforeWaiting, runLoopAfterWaiting
        case preparedCardsReady, preparedCardsConsumed
        case idleDisplay, idleDisplayReady, idleLayerPreparation, idleControlDisplay, idleIconPrefetch
    }

    private struct Sample: Encodable {
        let tag: Event
        let timestampNS: UInt64
        let durationNS: UInt64
        let count: Int
    }

    private struct Snapshot: Encodable {
        let schemaVersion: Int
        let sampleLimit: Int
        let droppedSamples: Int
        let samples: [Sample]
    }

    private let now: () -> UInt64
    private let baseline: UInt64
    private let sampleLimit: Int
    private var samples: [Sample] = []
    private var droppedSamples = 0

    /// The injected clock must not capture catalog, view, or other source objects.
    init(capacity: Int = 8192, now: @escaping () -> UInt64 = { DispatchTime.now().uptimeNanoseconds }) {
        self.now = now
        baseline = now()
        sampleLimit = min(max(capacity, 0), 8192)
        samples.reserveCapacity(sampleLimit)
    }

    /// An opaque clock token for this instance; beginning an interval adds no sample.
    func begin() -> UInt64 {
        now()
    }

    /// Timestamp denotes completion, relative to initialization, rather than start.
    /// Backward clock readings clamp independently; they are not reordered or repaired.
    func end(_ event: Event, since: UInt64, count: Int = 0) {
        let timestamp = now()
        append(event, at: timestamp, duration: timestamp >= since ? timestamp - since : 0, count: count)
    }

    func mark(_ event: Event, count: Int = 0) {
        append(event, at: now(), duration: 0, count: count)
    }

    /// Encoding neither samples the clock nor clears the buffer or drop accounting.
    func encodedSnapshot() throws -> Data {
        try JSONEncoder().encode(Snapshot(
            schemaVersion: 1,
            sampleLimit: sampleLimit,
            droppedSamples: droppedSamples,
            samples: samples
        ))
    }

    private func append(_ event: Event, at timestamp: UInt64, duration: UInt64, count: Int) {
        guard samples.count < sampleLimit else {
            // Saturation prevents diagnostics from trapping even after extreme use.
            if droppedSamples < Int.max { droppedSamples += 1 }
            return
        }
        samples.append(Sample(
            tag: event,
            timestampNS: timestamp >= baseline ? timestamp - baseline : 0,
            durationNS: duration,
            count: max(count, 0)
        ))
    }
}
