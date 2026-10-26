import AppKit
import LauncherLocalization

/// Inert root-overlay feedback. Main owns outcome routing, snapshots and mounting.
/// All APIs and injected callbacks run on the main actor. Schedulers must defer
/// callbacks, return a cancellation function, and use the clock's elapsed seconds.
@MainActor
public final class ActionFeedbackNoticeView: NSView {
    public typealias Clock = @MainActor () -> TimeInterval
    public typealias Cancellation = @MainActor () -> Void
    public typealias Scheduler = @MainActor (TimeInterval, @escaping @MainActor () -> Void) -> Cancellation

    public static let presentationDuration: TimeInterval = 6
    public var onPresentationApplied: (() -> Void)?
    public private(set) var reason: ActionFeedbackTextKey?
    private(set) var removalReason: AppRemovalTextKey?
    public private(set) var expirationDeadline: TimeInterval?
    public var statusText: String { label.stringValue }

    internal private(set) var languageFormattingCount = 0
    internal private(set) var presentationApplyCount = 0
    internal private(set) var sizingMeasurementCount = 0
    internal private(set) var materialApplyCount = 0

    private let label = NSTextField(wrappingLabelWithString: "")
    private let clock: Clock
    private let scheduler: Scheduler
    private var strings: LocalizedStrings?
    private var textDirty = false
    private var materialDirty = true
    private var reduceTransparency = false
    private var increaseContrast = false
    private var isTornDown = false
    private var nextTicket: UInt64 = 0
    private var presentationTicket: UInt64?
    private var expiryTicket: UInt64?
    private var cancelPresentation: Cancellation?
    private var cancelExpiry: Cancellation?
    private var requestedWidth: CGFloat
    private var measuredWidth: CGFloat?
    private var measuredHeight: CGFloat = 0
    private var cachedRequiredHeight: CGFloat = 0

    public override convenience init(frame frameRect: NSRect) {
        self.init(frame: frameRect, strings: nil)
    }

    /// nil uses only key-specific fallbacks; initialization never builds a snapshot.
    public convenience init(frame frameRect: NSRect, strings: LocalizedStrings?) {
        self.init(frame: frameRect, strings: strings,
                  clock: { Double(DispatchTime.now().uptimeNanoseconds) / 1_000_000_000 },
                  scheduler: Self.scheduleOnMain)
    }

    public init(frame frameRect: NSRect, strings: LocalizedStrings?,
                clock: @escaping Clock, scheduler: @escaping Scheduler) {
        self.strings = strings
        self.clock = clock
        self.scheduler = scheduler
        requestedWidth = Self.boundedDimension(frameRect.width)
        super.init(frame: frameRect)
        identifier = NSUserInterfaceItemIdentifier("launchcopy.chrome.action-feedback")
        label.font = .systemFont(ofSize: 15)
        label.textColor = .white
        label.alignment = .center
        label.lineBreakMode = .byWordWrapping
        label.maximumNumberOfLines = 0
        label.isSelectable = false
        label.isEditable = false
        label.refusesFirstResponder = true
        label.focusRingType = .none
        label.setAccessibilityElement(false)
        addSubview(label)
        wantsLayer = true
        layer?.cornerRadius = LaunchcopyVisualTokens.chromeCornerRadius
        layer?.masksToBounds = true
        isHidden = true
        setAccessibilityRole(.staticText)
        setAccessibilityElement(false)
    }

    @available(*, unavailable)
    public required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    /// Each real error starts six seconds at receipt, even if rendering is delayed.
    /// The accessibility-only key cannot manufacture an error presentation.
    public func show(reason: ActionFeedbackTextKey, strings: LocalizedStrings) {
        guard !isTornDown, reason != .feedbackAccessibility else { return }
        self.reason = reason
        removalReason = nil
        self.strings = strings
        expirationDeadline = clock() + Self.presentationDuration
        textDirty = true
        invalidateExpiry()
        queuePresentation()
    }

    func show(removalReason: AppRemovalTextKey, strings: LocalizedStrings) {
        guard !isTornDown else { return }
        reason = nil
        self.removalReason = removalReason
        self.strings = strings
        expirationDeadline = clock() + Self.presentationDuration
        textDirty = true
        invalidateExpiry()
        queuePresentation()
    }

    public func relabel(strings: LocalizedStrings) {
        guard !isTornDown else { return }
        self.strings = strings
        guard reason != nil || removalReason != nil else { return }
        textDirty = true
        queuePresentation()
    }

    /// Main calls clear on hide/success/namespace replacement; a later show is valid.
    public func clear() {
        guard !isTornDown else { return }
        reason = nil
        removalReason = nil
        expirationDeadline = nil
        textDirty = false
        invalidateExpiry()
        invalidatePresentation()
        queuePresentation()
    }

    /// Terminal owner hook, called outside frame callbacks before discarding the view.
    public func teardown() {
        guard !isTornDown else { return }
        isTornDown = true
        invalidatePresentation()
        invalidateExpiry()
        reason = nil
        removalReason = nil
        expirationDeadline = nil
        strings = nil
        onPresentationApplied = nil
        hidePresentation()
    }

    public func applyMaterialPolicy(reduceTransparency: Bool, increaseContrast: Bool) {
        guard !isTornDown,
              self.reduceTransparency != reduceTransparency || self.increaseContrast != increaseContrast else { return }
        self.reduceTransparency = reduceTransparency
        self.increaseContrast = increaseContrast
        materialDirty = true
        queuePresentation()
    }

    /// Returns a cached height. A different width requests deferred measurement;
    /// onPresentationApplied lets Main reserve the complete new height next turn.
    /// No resource read, text formatting or cell measurement occurs on this stack.
    public func requiredPresentationHeight(forWidth width: CGFloat) -> CGFloat {
        guard !isTornDown, reason != nil || removalReason != nil else { return 0 }
        let width = Self.boundedDimension(width)
        if requestedWidth != width {
            requestedWidth = width
            queuePresentation()
        }
        return cachedRequiredHeight
    }

    public override func setFrameSize(_ newSize: NSSize) {
        let changed = frame.size != newSize
        super.setFrameSize(newSize)
        guard changed, !isTornDown else { return }
        requestedWidth = Self.boundedDimension(bounds.width)
        queuePresentation()
    }

    public override func setBoundsSize(_ newSize: NSSize) {
        let changed = bounds.size != newSize
        super.setBoundsSize(newSize)
        guard changed, !isTornDown else { return }
        requestedWidth = Self.boundedDimension(bounds.width)
        queuePresentation()
    }

    public override func layout() {
        super.layout()
        guard !isTornDown else { return }
        queuePresentation()
    }

    public override func viewWillMove(toSuperview newSuperview: NSView?) {
        if newSuperview == nil, superview != nil { clear() }
        super.viewWillMove(toSuperview: newSuperview)
    }

    public override var acceptsFirstResponder: Bool { false }
    public override func becomeFirstResponder() -> Bool { false }
    public override func hitTest(_ point: NSPoint) -> NSView? { nil }

    private static func scheduleOnMain(after delay: TimeInterval,
                                       action: @escaping @MainActor () -> Void) -> Cancellation {
        let item = DispatchWorkItem { MainActor.assumeIsolated { action() } }
        DispatchQueue.main.asyncAfter(deadline: .now() + max(0, delay), execute: item)
        return { item.cancel() }
    }

    private func ticket() -> UInt64 {
        nextTicket &+= 1
        return nextTicket
    }

    private func queuePresentation() {
        guard !isTornDown, presentationTicket == nil else { return }
        let token = ticket()
        presentationTicket = token
        cancelPresentation = scheduler(0) { [weak self] in
            guard let self, !self.isTornDown, self.presentationTicket == token else { return }
            self.presentationTicket = nil
            self.cancelPresentation = nil
            self.applyPresentation()
        }
    }

    private func invalidatePresentation() {
        presentationTicket = nil
        cancelPresentation?()
        cancelPresentation = nil
    }

    private func invalidateExpiry() {
        expiryTicket = nil
        cancelExpiry?()
        cancelExpiry = nil
    }

    private func armExpiry(deadline: TimeInterval, now: TimeInterval) {
        guard expiryTicket == nil else { return }
        let token = ticket()
        expiryTicket = token
        cancelExpiry = scheduler(max(0, deadline - now)) { [weak self] in
            guard let self, !self.isTornDown, self.expiryTicket == token else { return }
            self.expiryTicket = nil
            self.cancelExpiry = nil
            // Even a timer delivery only stages work; it never renders in that stack.
            self.queuePresentation()
        }
    }

    private func applyPresentation() {
        let now = clock()
        if let deadline = expirationDeadline, now >= deadline {
            reason = nil
            removalReason = nil
            expirationDeadline = nil
            textDirty = false
            invalidateExpiry()
        }
        if materialDirty {
            layer?.backgroundColor = NSColor.black.withAlphaComponent(reduceTransparency ? 1 : 0.7).cgColor
            layer?.isOpaque = reduceTransparency
            layer?.borderWidth = increaseContrast ? 2 : 0
            layer?.borderColor = increaseContrast ? NSColor.white.cgColor : nil
            materialApplyCount += 1
            materialDirty = false
        }
        guard reason != nil || removalReason != nil, let deadline = expirationDeadline else {
            hidePresentation()
            presentationApplyCount += 1
            onPresentationApplied?()
            return
        }
        let refresh = textDirty
        if refresh {
            languageFormattingCount += 2
            if let removalReason {
                label.stringValue = strings?.removalText(removalReason) ?? removalReason.englishFallback
            } else if let reason {
                label.stringValue = strings?.actionFeedbackText(reason) ?? reason.englishFallback
            }
            setAccessibilityLabel(strings?.actionFeedbackText(.feedbackAccessibility)
                ?? ActionFeedbackTextKey.feedbackAccessibility.englishFallback)
            setAccessibilityValue(label.stringValue)
            textDirty = false
        }
        isHidden = false
        setAccessibilityElement(true)
        if refresh || measuredWidth != requestedWidth {
            let width = max(0, requestedWidth - 16)
            measuredHeight = width > 0
                ? ceil(label.cell?.cellSize(forBounds: NSRect(x: 0, y: 0, width: width,
                    height: CGFloat.greatestFiniteMagnitude)).height ?? 20) : 0
            measuredHeight = Self.boundedDimension(measuredHeight)
            cachedRequiredHeight = ceil(max(20, measuredHeight)) + 16
            measuredWidth = requestedWidth
            sizingMeasurementCount += 1
        }
        applyLabelFrame()
        // Sizing time must not be added to the timer's remaining duration.
        armExpiry(deadline: deadline, now: clock())
        presentationApplyCount += 1
        onPresentationApplied?()
    }

    private func hidePresentation() {
        isHidden = true
        label.stringValue = ""
        label.frame = .zero
        setAccessibilityElement(false)
        setAccessibilityLabel(nil)
        setAccessibilityValue(nil)
        cachedRequiredHeight = 0
        measuredWidth = nil
    }

    private func applyLabelFrame() {
        let width = Self.boundedDimension(bounds.width)
        let height = Self.boundedDimension(bounds.height)
        let xInset = min(8, width / 2)
        let yInset = min(8, height / 2)
        let textHeight = min(measuredHeight, max(0, height - 2 * yInset))
        label.frame = NSRect(x: bounds.minX + xInset, y: bounds.minY + (height - textHeight) / 2,
                             width: max(0, width - 2 * xInset), height: textHeight)
    }

    private static func boundedDimension(_ value: CGFloat) -> CGFloat {
        value.isFinite ? max(0, value) : 0
    }
}
