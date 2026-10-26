import Foundation

/// In-memory diagnostic state. Every clock value is supplied by the caller.
@MainActor
final class FolderDropLatencyProbe {
    enum Stage: String, CaseIterable {
        case commitStart
        case providerReturn
        case presentationReturn
        case folderRefreshReturn
        case commitReturn
    }

    struct Sample {
        let id: UInt64
        let eventToWindowMS: Double?
        let windowToOverlayMS: Double?
        let eventToOverlayMS: Double?
        let releaseToReturnMS: Double?
        let stageOffsetsMS: [Stage: Double]
        var nextTurnMS: Double?
        var willDrawMS: Double?
        let readyIcons: Int
        let visibleMembers: Int
        var invalidClock: Bool

        // All stage/async offsets use the overlay release origin, in seconds.
        // Absolute clock values are never included in the report.
        fileprivate let releaseOrigin: Double?
        fileprivate var lastObservedClock: Double?
        fileprivate var nextTurnObserved = false
    }

    private struct WindowRelease {
        let eventTimestamp: Double
        let now: Double
    }

    private struct Release {
        let origin: Double?
        let eventToWindowMS: Double?
        let windowToOverlayMS: Double?
        let eventToOverlayMS: Double?
        var seenStages: Set<Stage> = []
        var stageOffsetsMS: [Stage: Double] = [:]
        var lastClock: Double?
        var invalidClock: Bool
    }

    private(set) var samples: [Sample] = []
    private var pendingWindow: WindowRelease?
    private var release: Release?
    private var lastID: UInt64 = 0

    func noteWindowRelease(eventTimestamp: Double, now: Double) {
        pendingWindow = WindowRelease(eventTimestamp: eventTimestamp, now: now)
    }

    func beginRelease(eventTimestamp: Double, now: Double) {
        let window = pendingWindow
        pendingWindow = nil
        let origin = validClock(now)
        let eventToOverlay = milliseconds(from: eventTimestamp, to: now)
        var eventToWindow: Double?
        var windowToOverlay: Double?
        var invalidClock = eventToOverlay == nil

        // An unrelated window observation is consumed, never carried forward.
        if let window, window.eventTimestamp == eventTimestamp {
            eventToWindow = milliseconds(from: eventTimestamp, to: window.now)
            windowToOverlay = milliseconds(from: window.now, to: now)
            invalidClock = invalidClock || eventToWindow == nil || windowToOverlay == nil
        }

        // Starting another release discards any unfinished release.
        release = Release(
            origin: origin,
            eventToWindowMS: eventToWindow,
            windowToOverlayMS: windowToOverlay,
            eventToOverlayMS: eventToOverlay,
            lastClock: origin,
            invalidClock: invalidClock
        )
    }

    func mark(_ stage: Stage, now: Double) {
        guard var current = release, !current.seenStages.contains(stage) else { return }
        let inOrder = Stage.allCases[current.seenStages.count] == stage
        current.seenStages.insert(stage)
        let offset = milliseconds(from: current.origin, to: now)
        let forward = milliseconds(from: current.lastClock, to: now) != nil
        if inOrder, forward, let offset {
            current.stageOffsetsMS[stage] = offset
        } else {
            current.invalidClock = true
        }
        if forward { current.lastClock = validClock(now) }
        release = current
    }

    @discardableResult
    func endRelease(now: Double, readyIcons: Int, visibleMembers: Int) -> UInt64? {
        defer { release = nil }
        // Only the complete within-folder owner path has all five markers.
        guard let current = release,
              current.seenStages.count == Stage.allCases.count,
              lastID < UInt64.max else { return nil }
        let forward = milliseconds(from: current.lastClock, to: now) != nil
        let returnOffset = forward ? milliseconds(from: current.origin, to: now) : nil
        lastID += 1
        samples.append(Sample(
            id: lastID,
            eventToWindowMS: current.eventToWindowMS,
            windowToOverlayMS: current.windowToOverlayMS,
            eventToOverlayMS: current.eventToOverlayMS,
            releaseToReturnMS: returnOffset,
            stageOffsetsMS: current.stageOffsetsMS,
            nextTurnMS: nil,
            willDrawMS: nil,
            readyIcons: readyIcons,
            visibleMembers: visibleMembers,
            invalidClock: current.invalidClock || returnOffset == nil,
            releaseOrigin: current.origin,
            lastObservedClock: forward ? validClock(now) : nil
        ))
        if samples.count > 8 { samples.removeFirst(samples.count - 8) }
        return lastID
    }

    func noteNextTurn(for id: UInt64, now: Double) {
        guard let index = samples.firstIndex(where: { $0.id == id }),
              !samples[index].nextTurnObserved else { return }
        samples[index].nextTurnObserved = true
        guard milliseconds(from: samples[index].lastObservedClock, to: now) != nil,
              let offset = milliseconds(from: samples[index].releaseOrigin, to: now) else {
            samples[index].invalidClock = true
            return
        }
        samples[index].lastObservedClock = now
        samples[index].nextTurnMS = offset
    }

    func noteWillDraw(now: Double) {
        // A synchronous draw during release cannot be a post-return boundary.
        guard release == nil, let index = samples.indices.last,
              samples[index].willDrawMS == nil else { return }
        guard milliseconds(from: samples[index].lastObservedClock, to: now) != nil,
              let offset = milliseconds(from: samples[index].releaseOrigin, to: now) else {
            samples[index].invalidClock = true
            return
        }
        // Invalid notifications do not prevent the first later valid marker.
        samples[index].lastObservedClock = now
        samples[index].willDrawMS = offset
    }

    func reset() {
        pendingWindow = nil
        release = nil
        samples.removeAll(keepingCapacity: true)
        // Keep the ordinal so queued pre-reset closures cannot match new data.
    }

    var summary: String {
        var lines = [
            "Folder drop timing",
            "Retained samples: \(samples.count); limit: 8; shown: \(min(samples.count, 3))",
            "viewWillDraw is a pre-draw boundary."
        ]
        for sample in samples.suffix(3) {
            lines.append("Sample ordinal: \(sample.id)")
            lines.append("eventToWindowMS: \(formatted(sample.eventToWindowMS))")
            lines.append("windowToOverlayMS: \(formatted(sample.windowToOverlayMS))")
            lines.append("eventToOverlayMS: \(formatted(sample.eventToOverlayMS))")
            lines.append("releaseToReturnMS: \(formatted(sample.releaseToReturnMS))")
            for stage in Stage.allCases {
                lines.append("\(stage.rawValue)MS: \(formatted(sample.stageOffsetsMS[stage]))")
            }
            lines.append("nextTurnMS: \(formatted(sample.nextTurnMS))")
            lines.append("willDrawMS: \(formatted(sample.willDrawMS))")
            lines.append("readyIcons: \(sample.readyIcons); visibleMembers: \(sample.visibleMembers)")
            lines.append("invalidClock: \(sample.invalidClock ? 1 : 0)")
        }
        return lines.joined(separator: "\n")
    }

    private func validClock(_ value: Double) -> Double? {
        value.isFinite && value >= 0 ? value : nil
    }

    private func milliseconds(from start: Double?, to end: Double) -> Double? {
        guard let start, validClock(start) != nil, validClock(end) != nil,
              end >= start else { return nil }
        let result = (end - start) * 1_000
        return result.isFinite ? result : nil
    }

    private func formatted(_ value: Double?) -> String {
        guard let value else { return "unavailable" }
        return String(format: "%.3f", locale: Locale(identifier: "en_US_POSIX"), value)
    }
}
