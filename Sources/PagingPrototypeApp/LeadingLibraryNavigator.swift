import AppKit
import PagingCore
import PagingUI

/// Parent presentation identity, deliberately separate from canonical application pages.
enum LeadingLibraryLocation: Int { case library = 0, grid = 1 }

/// Whether the original current event continues through the window's normal gates.
struct LeadingLibraryScrollDecision {
    let destination: LeadingLibraryScrollRouter.Destination
    var consumesOriginalEvent: Bool {
        switch destination {
        case .pass, .native, .grid: return false
        default: return true
        }
    }
}

/// Locks a whole physical scroll sequence to one consumer, including late momentum.
/// A zero-delta began is held until direction is known; callers retain that original event.
struct LeadingLibraryScrollRouter {
    enum Destination: Equatable { case hold, grid, native, parent, drain, pass }
    private(set) var destination: Destination = .pass

    mutating func route(phase: NSEvent.Phase, momentum: NSEvent.Phase,
                        deltaX: CGFloat, deltaY: CGFloat, inverted: Bool,
                        eligible: Bool, location: LeadingLibraryLocation,
                        parentIsMoving: Bool) -> Destination {
        let fresh = phase.contains(.began)
        let wheel = phase.isEmpty && momentum.isEmpty
        if fresh || wheel {
            if parentIsMoving { destination = .parent; return destination }
            guard eligible else { destination = .pass; return destination }
            destination = .hold
        }
        guard destination == .hold else { return destination }
        if abs(deltaX) > 0 || abs(deltaY) > 0 {
            let horizontal = abs(deltaX) >= abs(deltaY)
            let previous = ScrollInputMapper.normalizedDelta(scrollingDeltaX: deltaX, isDirectionInverted: inverted) < 0
            destination = horizontal && (location == .library || previous) ? .parent
                : (location == .library ? .native : .grid)
        } else if phase.contains(.ended) || phase.contains(.cancelled) || !momentum.isEmpty {
            destination = location == .library ? .native : .grid
        }
        return destination
    }

    mutating func drain() { destination = .drain }
}

/// Boundary-only parent navigation. Its manual pager shares the existing surface's pump;
/// neither the catalog provider nor the canonical application paging domain is modified.
@MainActor
final class LeadingLibraryNavigator {
    var entryProfile: LibraryEntryProfile?
    let pager = FolderPagingController()
    private(set) var location: LeadingLibraryLocation = .grid
    private var router = LeadingLibraryScrollRouter()
    private var heldBegin: NSEvent?
    private var reconciling = false
    private var tornDown = false
    private weak var surface: PagingSurface?
    private weak var owner: AppLibraryOwnerController?

    var canNavigate: () -> Bool = { false }
    var canEnterFromGrid: () -> Bool = { false }
    var canForwardGridInput: () -> Bool = { true }
    var width: () -> CGFloat = { 0 }
    var render: (_ offset: Double, _ reduceMotion: Bool) -> Void = { _, _ in }
    var resetPresentation: () -> Void = {}
    var setGridPreviewVisible: (Bool) -> Void = { _ in }
    var forwardNative: (NSEvent) -> Void = { _ in }
    var onReadinessChange: () -> Void = {}
    var prepareFirstGridPage: () -> Void = {}

    var isTransitioning: Bool {
        !tornDown && (router.destination == .hold || pager.isActive || owner?.isPreviewing == true)
    }

    init(surface: PagingSurface, owner: AppLibraryOwnerController) {
        self.surface = surface
        self.owner = owner
        pager.automaticallyDrivesFrames = false
        pager.onOffsetChange = { [weak self] offset in
            guard let self, !self.reconciling, !self.tornDown else { return }
            let profile = self.entryProfile
            let start = profile?.begin()
            defer { if let start { profile?.end(.parentRender, since: start) } }
            self.render(offset, self.surface?.core.reduceMotion ?? false)
        }
        pager.onCommit = { [weak self] page in self?.commit(page) }
        surface.supplementalFrameStep = { [weak self] dt in
            guard let self, !self.tornDown else { return }
            let profile = self.pager.isActive ? self.entryProfile : nil
            let start = profile?.begin()
            defer { if let start { profile?.end(.parentFrame, since: start) } }
            self.pager.advanceFrame(deltaTime: dt)
        }
        surface.supplementalFrameDemand = { [weak self] in self?.pager.needsFrames == true }
    }

    /// Called only from the window's pre-dispatch hook. No NSEvent is synthesized.
    func handleScroll(_ event: NSEvent) -> Bool {
        guard !tornDown, let surface, !surface.isTearingDown, let owner else { return false }
        let wasMoving = pager.isActive || owner.isPreviewing
        let decision = routeScrollInput(phase: event.phase, momentumPhase: event.momentumPhase,
            deltaX: event.scrollingDeltaX, deltaY: event.scrollingDeltaY,
            isDirectionInverted: event.isDirectionInvertedFromDevice)
        switch decision.destination {
        case .hold:
            if event.phase.contains(.began) { heldBegin = event }
            return true
        case .pass:
            heldBegin = nil
            return false
        case .drain:
            heldBegin = nil
            return true
        case .native, .grid:
            // Only parent navigation owns delivery. Ordinary events continue through
            // Window readability/mode gates and AppKit's original responder targeting.
            if let began = heldBegin { heldBegin = nil; forwardNative(began) }
            return decision.consumesOriginalEvent
        case .parent:
            if !wasMoving {
                guard beginTransition() else {
                    heldBegin = nil; router.drain(); return true
                }
            }
            if let began = heldBegin { heldBegin = nil; feed(began) }
            feed(event)
            return true
        }
    }

    /// Pure event values exercise the same ownership decision without synthesizing input.
    func routeScrollInput(phase: NSEvent.Phase, momentumPhase: NSEvent.Phase,
                          deltaX: CGFloat, deltaY: CGFloat, isDirectionInverted: Bool)
        -> LeadingLibraryScrollDecision {
        guard !tornDown, surface?.isTearingDown == false else { return .init(destination: .pass) }
        if phase.contains(.began) || (phase.isEmpty && momentumPhase.isEmpty) {
            owner?.suspendPreparationForInput()
        }
        let wasHolding = router.destination == .hold
        defer {
            // A zero-delta sequence can release without starting a pager. Resume
            // deferred idle preparation even when no animation/commit notifies us.
            if wasHolding {
                switch router.destination {
                case .grid, .native, .drain, .pass: onReadinessChange()
                case .hold, .parent: break
                }
            }
        }
        let eligible = canNavigate() && (location == .library || canEnterFromGrid())
        let destination = router.route(phase: phase, momentum: momentumPhase,
            deltaX: deltaX, deltaY: deltaY, inverted: isDirectionInverted,
            eligible: eligible, location: location,
            parentIsMoving: pager.isActive || owner?.isPreviewing == true)
        if destination == .grid, !canForwardGridInput() {
            router.drain()
            return .init(destination: .drain)
        }
        return .init(destination: destination)
    }

    /// Shared admission path for native routing and deterministic component tests.
    @discardableResult
    func beginTransition() -> Bool {
        let profile = entryProfile
        let profileStart = profile?.begin()
        defer { if let profileStart { profile?.end(.parentBegin, since: profileStart, count: location.rawValue) } }
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        defer { CATransaction.commit() }
        guard !tornDown, let surface, !surface.isTearingDown, let owner,
              canNavigate(), location == .library || canEnterFromGrid(),
              width().isFinite, width() > 0 else { return false }
        if location == .grid, !owner.enter(preview: true) { return false }
        configure()
        setGridPreviewVisible(true)
        render(pager.core.visualOffset, surface.core.reduceMotion)
        owner.revealPreviewPresentation()
        return true
    }

    private func feed(_ event: NSEvent) {
        handleParentInput(phase: event.phase, momentumPhase: event.momentumPhase,
            deltaX: event.scrollingDeltaX, deltaY: event.scrollingDeltaY,
            isDirectionInverted: event.isDirectionInvertedFromDevice, timestamp: event.timestamp)
    }

    /// Value-input seam used by the real event path and deterministic lifecycle tests.
    func handleParentInput(phase: NSEvent.Phase, momentumPhase: NSEvent.Phase,
                           deltaX: CGFloat, deltaY: CGFloat, isDirectionInverted: Bool,
                           timestamp: TimeInterval) {
        let profile = entryProfile
        let profileStart = profile?.begin()
        defer { if let profileStart { profile?.end(.parentInput, since: profileStart, count: 0) } }
        guard !tornDown else { return }
        if phase.contains(.cancelled) { cancel(); return }
        pager.handleScroll(phase: phase, momentumPhase: momentumPhase, deltaX: deltaX,
            deltaY: deltaY, isDirectionInverted: isDirectionInverted, timestamp: timestamp)
        // Tracking -> ended keeps isActive true, so activity-change alone is insufficient.
        surface?.refreshFrameDemand()
    }

    private func configure() {
        guard let surface else { return }
        pager.configure(pageCount: 2, pageWidth: Double(width()), currentPage: location.rawValue,
            reduceMotion: surface.core.reduceMotion, parameters: surface.core.parameters)
    }

    private func commit(_ page: Int) {
        let profile = entryProfile
        let profileStart = profile?.begin()
        defer { if let profileStart { profile?.end(.parentCommit, since: profileStart, count: page) } }
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        defer { CATransaction.commit() }
        guard !tornDown, !reconciling, let owner else { return }
        reconciling = true
        defer { reconciling = false; surface?.refreshFrameDemand(); onReadinessChange() }
        router.drain()
        if page == LeadingLibraryLocation.library.rawValue {
            if owner.isPreviewing, !owner.commitPreview() {
                owner.cancelPreview()
                location = .grid
            } else { location = .library }
        } else {
            location = .grid
            if owner.isPreviewing { owner.cancelPreview() }
            else if owner.isOpen, !owner.backToFirstGridPage() { location = .library }
        }
        // Accepted writes or catalog invalidation can revoke admission during tracking.
        // Reconcile the engine to the actual terminal pane, never a failed target.
        configure()
        resetPresentation()
        setGridPreviewVisible(false)
    }

    /// Owner notifications include ordinary button entry, Close/Escape and feature disable.
    func ownerDidChange() {
        guard !tornDown, !reconciling, let owner else { return }
        if !owner.preferences.committed.enabled { cancel() }
        guard !owner.isPreviewing, !pager.isActive else { return }
        let next: LeadingLibraryLocation = owner.isOpen ? .library : .grid
        if next != location {
            // Button entry or an external hide also transfers semantic ownership.
            // The previous grid/list stream may still have late momentum to drain.
            heldBegin = nil
            router.drain()
            location = next
            configure()
            resetPresentation()
            if next == .library { prepareFirstGridPage() }
        }
    }

    /// Cancel to the last semantic pane and drain the rest of the interrupted stream.
    func cancel() {
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        defer { CATransaction.commit() }
        guard !tornDown, !reconciling else { return }
        reconciling = true
        heldBegin = nil
        router.drain()
        pager.cancel()
        if owner?.isPreviewing == true { owner?.cancelPreview() }
        location = owner?.isOpen == true ? .library : .grid
        resetPresentation()
        setGridPreviewVisible(false)
        reconciling = false
        surface?.refreshFrameDemand()
        onReadinessChange()
    }

    func teardown() {
        guard !tornDown else { return }
        cancel()
        tornDown = true
        pager.tearDown()
        surface?.supplementalFrameStep = nil
        surface?.supplementalFrameDemand = nil
        surface?.refreshFrameDemand()
        surface = nil
        owner = nil
    }
}
