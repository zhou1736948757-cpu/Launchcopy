import AppKit
import PagingCore

/// Folder-local input and frame ownership. Use on the main thread, like PagingCore.
/// The owner renders offsets in page units and remains authoritative for discrete navigation.
public final class FolderPagingController {
    /// Observe this core; route mutations through the controller's input/lifecycle methods.
    /// Reconfiguration may replace it, so callers must not retain it as the current engine.
    public private(set) var core: PagingCore

    public var onOffsetChange: ((Double) -> Void)?
    public var onCommit: ((Int) -> Void)?
    public var onActivityChange: ((Bool) -> Void)?

    public var automaticallyDrivesFrames = true {
        didSet { updateFrameTimer() }
    }

    /// Finger tracking, momentum, release wait, or settling. Tracking alone needs no Timer.
    public var isActive: Bool {
        !isTornDown && (core.state == .tracking || core.state == .settling
            || core.state == .interrupted || pendingFinishSince != nil)
    }

    /// Frame demand, independent of input ownership. Finger tracking alone needs no
    /// frames; release wait, momentum glide, and settling do, even in manual mode.
    public var needsFrames: Bool {
        !isTornDown && (core.isAnimating || pendingFinishSince != nil)
    }

    // Same monotonic clock and 100ms release window as PagingSurface. Tests inject time
    // without creating an NSApplication, window, synthetic NSEvent, or sleeping.
    internal var pendingFinishTimeSource: () -> TimeInterval = { ProcessInfo.processInfo.systemUptime }
    internal private(set) var pendingFinishSince: TimeInterval?
    internal private(set) var frameTimer: Timer?
    private static let pendingFinishThreshold: TimeInterval = 0.1
    private static let frameInterval: TimeInterval = 1.0 / 60.0

    private struct Configuration: Equatable {
        let pageCount: Int
        let pageWidth: Double
        let reduceMotion: Bool
        let hasGeometry: Bool
        let parameters: PagingParameters
    }

    private var configuration: Configuration
    private var authoritativePage = 0
    private var generation: UInt64 = 0
    private var isTornDown = false
    private var lastFrameTimestamp: TimeInterval?

    // Core callbacks only record facts. Outward callbacks run after the entire core
    // operation, including synchronous Reduce Motion completion, has returned. This
    // prevents a reentrant cancel/configure from changing an in-flight core operation.
    private var updateDepth = 0
    private var isDeliveringCallbacks = false
    private var offsetNeedsDelivery = false
    private var pendingCommit: Int?
    private var publishedActivity = false

    public init() {
        configuration = Configuration(pageCount: 0, pageWidth: 1, reduceMotion: false,
                                      hasGeometry: false, parameters: PagingParameters())
        core = PagingCore(pageCount: 0, pageWidth: 1)
        replaceCore(initialPage: 0)
    }

    deinit {
        frameTimer?.invalidate()
        core.teardown()
    }

    /// Layout calls with the same configuration are no-ops, including during tracking.
    /// A changed authoritative page (keyboard/button), geometry, count, or motion policy
    /// cancels old work and synchronizes immediately, without synthesizing a commit.
    /// Nil parameters preserve the original default folder policy. Supply the current
    /// grid parameters on every configuration when reusing this controller for a parent.
    public func configure(pageCount: Int, pageWidth: Double, currentPage: Int, reduceMotion: Bool,
                          parameters: PagingParameters? = nil) {
        guard !isTornDown else { return }
        let hasGeometry = pageWidth.isFinite && pageWidth > 0
        let next = Configuration(
            pageCount: max(pageCount, 0),
            pageWidth: hasGeometry ? max(pageWidth, 1) : 1,
            reduceMotion: reduceMotion,
            hasGeometry: hasGeometry,
            parameters: parameters ?? PagingParameters()
        )
        let page = min(max(currentPage, 0), max(next.pageCount - 1, 0))
        guard next != configuration || page != authoritativePage else { return }
        performUpdate {
            stopFrameTimer()
            clearPendingFinish()
            pendingCommit = nil
            configuration = next
            authoritativePage = page
            replaceCore(initialPage: page)
            // Width changes also require presentation, even if page units are equal.
            offsetNeedsDelivery = true
        }
    }

    /// Discrete navigation through the same Core spring and deferred callback path.
    /// Manual mode leaves all frame advancement to the shared surface pump.
    @discardableResult
    public func requestPage(_ targetPage: Int,
                            timestamp: TimeInterval = ProcessInfo.processInfo.systemUptime) -> Bool {
        guard !isTornDown, configuration.hasGeometry, pendingFinishSince == nil,
              timestamp.isFinite, core.canRequestPage(targetPage) else { return false }
        var accepted = false
        performUpdate {
            accepted = core.requestPage(targetPage, timestamp: timestamp)
        }
        return accepted
    }

    public func handleScroll(
        phase: NSEvent.Phase,
        momentumPhase: NSEvent.Phase,
        deltaX: CGFloat,
        deltaY: CGFloat,
        isDirectionInverted: Bool,
        timestamp: TimeInterval
    ) {
        guard !isTornDown, configuration.hasGeometry, configuration.pageCount > 0,
              deltaX.isFinite, deltaY.isFinite, timestamp.isFinite else { return }
        let actions = ScrollInputMapper.map(
            phase: phase,
            momentumPhase: momentumPhase,
            scrollingDeltaX: deltaX,
            scrollingDeltaY: deltaY,
            isDirectionInverted: isDirectionInverted,
            needsFinish: pendingFinishSince != nil
        )
        let inputGeneration = generation
        for action in actions {
            guard !isTornDown, generation == inputGeneration else { break }
            // A new began can first complete a pending release. Deliver that old
            // commit before beginning the new gesture, so owner cleanup cannot
            // accidentally cancel the gesture that is just taking over.
            performUpdate { apply(action, timestamp: timestamp) }
        }
    }

    /// Restore the last authoritative/committed page; never emit onCommit for cancellation.
    /// Offset and activity notifications still let the owner reset its presentation.
    public func cancel() {
        guard !isTornDown else { return }
        performUpdate {
            stopFrameTimer()
            clearPendingFinish()
            pendingCommit = nil
            core.cancel()
        }
    }

    /// Terminal and idempotent. No outward callbacks occur during or after teardown.
    public func tearDown() {
        guard !isTornDown else { return }
        isTornDown = true
        generation &+= 1
        stopFrameTimer()
        clearPendingFinish()
        offsetNeedsDelivery = false
        pendingCommit = nil
        publishedActivity = false
        onOffsetChange = nil
        onCommit = nil
        onActivityChange = nil
        core.teardown()
    }

    /// Manual test seam and the production Timer's single frame path.
    public func advanceFrame(deltaTime: TimeInterval) {
        guard !isTornDown, deltaTime.isFinite, deltaTime > 0 else { return }
        performUpdate {
            if let since = pendingFinishSince,
               pendingFinishTimeSource() - since >= Self.pendingFinishThreshold {
                clearPendingFinish()
                _ = core.finishGesture(timestamp: since)
            }
            _ = core.tick(deltaTime: min(deltaTime, 0.1))
        }
    }

    private func apply(_ action: ScrollInputAction, timestamp: TimeInterval) {
        switch action {
        case .gestureBegan:
            if pendingFinishSince != nil {
                clearPendingFinish()
                _ = core.finishGesture(timestamp: timestamp)
            }
            _ = core.handleGesturePhase(.began, timestamp: timestamp)
        case .gestureChanged(let delta):
            _ = core.handleGesturePhase(.changed, delta: delta, timestamp: timestamp)
        case .gestureEnded:
            if core.handleGesturePhase(.ended, timestamp: timestamp) {
                pendingFinishSince = pendingFinishTimeSource()
            }
        case .gestureCancelled:
            clearPendingFinish()
            _ = core.handleGesturePhase(.cancelled, timestamp: timestamp)
        case .momentumBegan:
            let hadPendingFinish = pendingFinishSince != nil
            clearPendingFinish()
            if !core.handleGesturePhase(.momentumBegan, timestamp: timestamp), hadPendingFinish {
                _ = core.finishGesture(timestamp: timestamp)
            }
        case .momentumChanged(let delta):
            _ = core.handleGesturePhase(.momentumChanged, delta: delta, timestamp: timestamp)
        case .momentumEnded:
            _ = core.handleGesturePhase(.momentumEnded, timestamp: timestamp)
        case .finishPendingGesture:
            clearPendingFinish()
            _ = core.finishGesture(timestamp: timestamp)
        case .legacyScroll(let delta):
            clearPendingFinish()
            _ = core.legacyScrollDelta(delta, timestamp: timestamp)
        case .ignore:
            break
        }
    }

    private func clearPendingFinish() {
        pendingFinishSince = nil
    }

    private func replaceCore(initialPage: Int) {
        generation &+= 1
        core.teardown()
        let expectedGeneration = generation
        var events = PagingCoreEvents()
        events.onVisualOffsetChange = { [weak self] _ in
            guard let self, !self.isTornDown, self.generation == expectedGeneration else { return }
            self.offsetNeedsDelivery = true
        }
        events.onCommit = { [weak self] context in
            guard let self, !self.isTornDown, self.generation == expectedGeneration else { return }
            self.authoritativePage = context.targetPage
            self.pendingCommit = context.targetPage
        }
        core = PagingCore(
            pageCount: configuration.pageCount,
            pageWidth: configuration.pageWidth,
            parameters: configuration.parameters,
            initialPage: initialPage,
            reduceMotion: configuration.reduceMotion,
            events: events
        )
    }

    private func performUpdate(_ body: () -> Void) {
        updateDepth += 1
        body()
        updateDepth -= 1
        guard updateDepth == 0 else { return }
        updateFrameTimer()
        deliverCallbacks()
    }

    private func deliverCallbacks() {
        guard !isDeliveringCallbacks else { return }
        isDeliveringCallbacks = true
        defer { isDeliveringCallbacks = false }
        while !isTornDown {
            // Notify activation before the first moving offset so the owner can prepare
            // bounded neighbor hosts. Every callback may synchronously replace all work.
            if isActive && !publishedActivity {
                publishedActivity = true
                onActivityChange?(true)
            } else if offsetNeedsDelivery {
                offsetNeedsDelivery = false
                onOffsetChange?(core.visualOffset)
            } else if let page = pendingCommit {
                pendingCommit = nil
                onCommit?(page)
            } else if publishedActivity != isActive {
                publishedActivity = isActive
                onActivityChange?(publishedActivity)
            } else {
                return
            }
        }
    }

    private func updateFrameTimer() {
        guard automaticallyDrivesFrames, needsFrames else {
            stopFrameTimer()
            return
        }
        guard frameTimer == nil else { return }
        lastFrameTimestamp = nil
        let timer = Timer(timeInterval: Self.frameInterval, repeats: true) { [weak self] timer in
            guard let self, self.frameTimer === timer, !self.isTornDown else { return }
            let now = ProcessInfo.processInfo.systemUptime
            let elapsed = self.lastFrameTimestamp.map { now - $0 } ?? Self.frameInterval
            self.lastFrameTimestamp = now
            self.advanceFrame(deltaTime: min(max(elapsed, 0), 0.1))
        }
        timer.tolerance = 0
        frameTimer = timer
        RunLoop.main.add(timer, forMode: .common)
    }

    private func stopFrameTimer() {
        frameTimer?.invalidate()
        frameTimer = nil
        lastFrameTimestamp = nil
    }
}
