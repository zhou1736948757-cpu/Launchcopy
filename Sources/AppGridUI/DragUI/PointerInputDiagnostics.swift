/// Bounded, identity-free counters for explicitly enabled pointer diagnostics.
/// The caller owns the isolated-preview policy gate. Nothing is persisted or logged.
@MainActor
public enum PointerInputDiagnostics {
    /// The complete vocabulary; events cannot carry a payload.
    public enum Event: String, CaseIterable {
        case windowDown
        case windowDragged
        case windowUp
        case windowKeyActive
        case windowKeyInactive
        case windowNotKeyActive
        case windowNotKeyInactive
        case b1Down
        case b1Dragged
        case b1Up
        case folderNativeDown
        case overlayDown
        case overlayMember
        case overlayBlank
        case overlayTransitionDenied
        case overlayUnavailableDenied
        case overlayNonMember
        case coordinatorDown
        case dragGateDenied
        case titleEditingDenied
        case searchActiveDenied
        case layoutCommitDenied
        case visualHostMissing
        case clickOnly
        case sourceMissing
        case layoutMissing
        case sourceStale
        case pressed
        case pointerDragged
        case geometryMissing
        case movementProcessed
        case dragBegan
        case pointerUp
        case releaseWhilePressed
        case releaseWithoutTransaction
        case releaseDisplaced
        case committed
        case noOp
        case rejected
        case clicked
        case titleDismissed
        case leadingLibraryConsumed
        case libraryConsumed
        case interactionControl
        case blankHit
        case cancelEscape
        case cancelWindowResign
        case cancelCatalogRefresh
        case cancelSearchActivated
        case cancelTitleEditBegan
        case cancelOverlayClosed
        case cancelTeardown
        case cancelSecondDrag
        case cancelLayoutChanged
    }

    public private(set) static var isEnabled = false

    // At most one integer per finite Event; no input objects or histories are retained.
    private static var counts: [Event: UInt64] = [:]

    /// Every actual enable/disable transition starts with empty counters.
    /// Reapplying the current setting preserves the current counters.
    public static func setEnabled(_ enabled: Bool) {
        guard isEnabled != enabled else { return }
        reset()
        isEnabled = enabled
    }

    /// Clears counters while preserving the explicit opt-in setting.
    public static func reset() {
        counts.removeAll(keepingCapacity: false)
    }

    public static func record(_ event: Event) {
        // Keep this before touching storage, enumerating cases, or creating strings.
        guard isEnabled else { return }
        counts[event] = saturatingAdd(counts[event, default: 0], 1)
    }

    /// Exhaustive mapping deliberately requires an update when a reason is added.
    public static func recordCancellation(_ reason: DragCancelReason) {
        guard isEnabled else { return }
        let event: Event
        switch reason {
        case .escape:
            event = .cancelEscape
        case .windowResign:
            event = .cancelWindowResign
        case .catalogRefresh:
            event = .cancelCatalogRefresh
        case .searchActivated:
            event = .cancelSearchActivated
        case .titleEditBegan:
            event = .cancelTitleEditBegan
        case .overlayClosed:
            event = .cancelOverlayClosed
        case .teardown:
            event = .cancelTeardown
        case .secondDrag:
            event = .cancelSecondDrag
        case .layoutChanged:
            event = .cancelLayoutChanged
        }
        record(event)
    }

    public static func count(_ event: Event) -> UInt64 {
        counts[event, default: 0]
    }

    /// Returns a value snapshot containing only fixed labels and decimal integers.
    /// `total` is the saturating sum across all stage and cancellation counters.
    public static func report() -> String {
        let total = counts.values.reduce(UInt64(0)) { saturatingAdd($0, $1) }
        var lines = ["enabled=\(isEnabled ? 1 : 0)", "total=\(total)"]
        for event in Event.allCases.sorted(by: { $0.rawValue < $1.rawValue }) {
            lines.append("\(event.rawValue)=\(count(event))")
        }
        return lines.joined(separator: "\n")
    }

    // Pure arithmetic shared by counter increments and totals; never mutates diagnostics.
    static func saturatingAdd(_ value: UInt64, _ increment: UInt64) -> UInt64 {
        let (sum, overflow) = value.addingReportingOverflow(increment)
        return overflow ? .max : sum
    }
}
