import AppKit

/// Window-level unreadability suppression, independent of the parent pane's owner.
/// Observe a boundary before any consumer can hold the original began event.
struct MainGridScrollSequenceGate {
    private(set) var isSuppressing = false

    mutating func observeBoundary(phase: NSEvent.Phase, momentumPhase: NSEvent.Phase,
                                 inputIsAvailable: Bool) {
        if inputIsAvailable, Self.isNewSequence(phase: phase, momentumPhase: momentumPhase) {
            isSuppressing = false
        }
    }

    mutating func shouldSuppress(phase: NSEvent.Phase, momentumPhase: NSEvent.Phase,
                                inputIsAvailable: Bool) -> Bool {
        guard inputIsAvailable else { isSuppressing = true; return true }
        if isSuppressing {
            guard Self.isNewSequence(phase: phase, momentumPhase: momentumPhase) else { return true }
            isSuppressing = false
        }
        return false
    }

    private static func isNewSequence(phase: NSEvent.Phase, momentumPhase: NSEvent.Phase) -> Bool {
        phase.contains(.began) || phase.contains(.mayBegin) || (phase.isEmpty && momentumPhase.isEmpty)
    }
}
