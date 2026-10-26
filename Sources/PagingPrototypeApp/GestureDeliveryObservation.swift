import Foundation

/// Opt-in delivery counters. The caller owns serial access and the observation lifetime.
/// Only counts and one flush flag are stored; input values never outlive a record call.
struct GestureDeliveryObservation {
    static let maxFrames = 20_000

    private(set) var frames = 0
    private(set) var fourContactFrames = 0
    private(set) var emptyTerminalFrames = 0
    private(set) var admittedFourContactFrames = 0
    private(set) var preCutoffFrames = 0
    private(set) var futureFrames = 0
    private(set) var expiredFrames = 0
    private(set) var nonfiniteTimeFrames = 0
    private(set) var showEvents = 0
    private(set) var hideEvents = 0
    private(set) var acceptedHides = 0

    private var awaitingEventFlush = false

    init() {}

    /// Call before cutoff rejection, using the delivered frame and the current host admission.
    /// Categories describe delivery facts, not recognizer rejection or Hide eligibility.
    mutating func record(frame: PinchFrame, now: TimeInterval, admission: Bool,
                         cutoff: TimeInterval?, expiry: TimeInterval) {
        awaitingEventFlush = false
        guard frames < Self.maxFrames else { return }
        frames += 1
        awaitingEventFlush = true

        if frame.contacts.count == 4 {
            fourContactFrames += 1
            if admission { admittedFourContactFrames += 1 }
        }
        if frame.contacts.isEmpty,
           frame.phase == .moved || frame.phase == .ended || frame.phase == .cancelled {
            emptyTerminalFrames += 1
        }

        // The mode cutoff is independent of the frame's age relative to the clock.
        if frame.timestamp.isFinite, let cutoff, cutoff.isFinite, frame.timestamp < cutoff {
            preCutoffFrames += 1
        }
        guard frame.timestamp.isFinite, now.isFinite else {
            nonfiniteTimeFrames += 1
            return
        }
        if frame.timestamp > now {
            futureFrames += 1
        } else if now - frame.timestamp > expiry + 1e-9 {
            // Match PinchRecognizer's existing expiry comparison tolerance.
            expiredFrames += 1
        }
    }

    /// Call once after process/flush for the latest recorded frame, including frame 20,000.
    /// `hideRequested` is the accepted flush result, not proof of a presentation effect.
    /// A rejected cutoff frame may skip this call. A later frame replaces its flush slot.
    mutating func record(events: [PinchEvent], hideRequested: Bool) {
        guard awaitingEventFlush else { return }
        awaitingEventFlush = false
        for event in events {
            // Saturation also bounds counters for an unexpectedly oversized event batch.
            switch event {
            case .showRequested:
                if showEvents < Self.maxFrames { showEvents += 1 }
            case .hideRequested:
                if hideEvents < Self.maxFrames { hideEvents += 1 }
            }
        }
        if hideRequested { acceptedHides += 1 }
    }

    /// Strip associated request/screen identities from the on-demand presentation report.
    static func presentationSummary(_ state: LauncherPresentationState) -> String {
        let kind: String
        switch state {
        case .hidden: kind = "hidden"
        case .presenting: kind = "presenting"
        case .visible: kind = "visible"
        case .dismissing: kind = "dismissing"
        case .suspended: kind = "suspended"
        case .terminating: kind = "terminating"
        }
        return "presentation=\(kind); acceptedHides counts request dequeues, not visible effects"
    }

    /// On-demand neutral aggregate only; no formatting occurs while recording.
    var summary: String {
        "frames=\(frames) maxFrames=\(Self.maxFrames) "
            + "fourContactFrames=\(fourContactFrames) emptyTerminalFrames=\(emptyTerminalFrames) "
            + "admittedFourContactFrames=\(admittedFourContactFrames) preCutoffFrames=\(preCutoffFrames) "
            + "futureFrames=\(futureFrames) expiredFrames=\(expiredFrames) "
            + "nonfiniteTimeFrames=\(nonfiniteTimeFrames) showEvents=\(showEvents) "
            + "hideEvents=\(hideEvents) acceptedHides=\(acceptedHides)"
    }
}
