import AppIconPipeline
import AppKit
import Dispatch

/// Optional, serial preparation of an owner's supplied first-viewport controls.
/// Temporary bitmap drawing and icon decoding do not realize window materials
/// or establish compositor readiness. No presentation objects or pixels are kept.
@MainActor
final class LibraryIdleDisplayWarmup {
    struct Item {
        let view: NSView
        let iconKey: IconKey?
    }

    static let maxItems = 64
    static let maxPixelDimension = 256

    typealias Cancellation = @MainActor () -> Void
    typealias Delivery = @MainActor @Sendable (IconKey, UInt64, IconResult) -> Void
    typealias Request = @MainActor (IconPipeline, IconKey, UInt64, @escaping Delivery) -> Cancellation
    typealias ScheduleTimeout = @MainActor (TimeInterval, @escaping @MainActor () -> Void) -> Cancellation
    typealias MakeBitmap = @MainActor (Int, Int) -> NSBitmapImageRep?

    private struct PendingIcon {
        let id: UUID
        let continuation: CheckedContinuation<IconResult?, Never>
        var cancelRequest: Cancellation?
        var cancelTimeout: Cancellation?
    }

    private let request: Request
    private let scheduleTimeout: ScheduleTimeout
    private let makeBitmap: MakeBitmap
    private var generation: UInt64 = 0
    private var pendingIcon: PendingIcon?

    /// Injection is limited to callback registration, time and allocation so tests
    /// can exercise suppressed, synchronous and late delivery without app data.
    init(request: Request? = nil, scheduleTimeout: ScheduleTimeout? = nil,
         makeBitmap: MakeBitmap? = nil) {
        self.request = request ?? { pipeline, key, generation, delivery in
            let handle = pipeline.request(key: key, generation: generation, onApply: delivery)
            return { handle.cancel() }
        }
        self.scheduleTimeout = scheduleTimeout ?? { delay, action in
            let work = DispatchWorkItem { MainActor.assumeIsolated { action() } }
            DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: work)
            return { work.cancel() }
        }
        self.makeBitmap = makeBitmap ?? { width, height in
            NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: width, pixelsHigh: height,
                bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                colorSpaceName: .deviceRGB, bytesPerRow: width * 4, bitsPerPixel: 32)
        }
    }

    /// True means the bounded list was visited while admitted; unsupported or
    /// invalid controls and unavailable icons are skipped. False means revoked
    /// admission, task cancellation, or a control acquiring a window.
    func prepare(items: [Item], pipeline: IconPipeline?, displayScale: Double,
                 profile: LibraryEntryProfile?,
                 shouldContinue: @escaping @MainActor () -> Bool) async -> Bool {
        cancel()
        let token = generation
        guard displayScale.isFinite, displayScale > 0,
              allowed(token: token, shouldContinue: shouldContinue) else { return false }

        for item in items.prefix(Self.maxItems) {
            guard allowed(token: token, view: item.view, shouldContinue: shouldContinue) else { return false }
            // A short cancellable sleep gives the main run loop an opportunity
            // between native rasters; yield alone may immediately reschedule us.
            do { try await Task.sleep(for: .milliseconds(1)) }
            catch { return false }
            guard allowed(token: token, view: item.view, shouldContinue: shouldContinue) else { return false }
            guard Self.isNativeControl(item.view),
                  Self.pixelDimensions(bounds: item.view.bounds, displayScale: displayScale) != nil else { continue }

            var image: NSImage?
            if let pipeline, let key = item.iconKey, Self.isValid(key) {
                let start = profile?.begin()
                guard allowed(token: token, view: item.view, shouldContinue: shouldContinue) else { return false }
                let result = await requestIcon(pipeline: pipeline, key: key, token: token,
                    view: item.view, shouldContinue: shouldContinue)
                guard allowed(token: token, view: item.view, shouldContinue: shouldContinue) else { return false }
                if let start { profile?.end(.idleIconPrefetch, since: start, count: 1) }
                if case .success(let delivered)? = result { image = delivered }
            }

            guard allowed(token: token, view: item.view, shouldContinue: shouldContinue) else { return false }
            let start = profile?.begin()
            let displayed = autoreleasepool {
                draw(item.view, image: image, displayScale: displayScale) {
                    self.allowed(token: token, view: item.view, shouldContinue: shouldContinue)
                }
            }
            if let start { profile?.end(.idleControlDisplay, since: start, count: displayed ? 1 : 0) }
            guard allowed(token: token, view: item.view, shouldContinue: shouldContinue) else { return false }
        }
        return allowed(token: token, shouldContinue: shouldContinue)
    }

    /// Retire ownership before calling the handle: cancellation may reenter with
    /// a callback. Neither shutdown nor source invalidation owes us a delivery.
    func cancel() {
        generation &+= 1
        if let pendingIcon { finishIcon(id: pendingIcon.id, result: nil) }
    }

    private func allowed(token: UInt64, view: NSView? = nil,
                         shouldContinue: @MainActor () -> Bool) -> Bool {
        guard generation == token, !Task.isCancelled, view?.window == nil else { return false }
        guard shouldContinue() else { return false }
        // The owner's gate may itself cancel, dispose or attach a presentation.
        return generation == token && !Task.isCancelled && view?.window == nil
    }

    private func requestIcon(pipeline: IconPipeline, key: IconKey, token: UInt64,
                             view: NSView, shouldContinue: @escaping @MainActor () -> Bool) async -> IconResult? {
        let id = UUID()
        return await withTaskCancellationHandler(operation: {
            guard allowed(token: token, view: view, shouldContinue: shouldContinue) else { return nil }
            return await withCheckedContinuation { continuation in
                guard allowed(token: token, view: view, shouldContinue: shouldContinue) else {
                    continuation.resume(returning: nil)
                    return
                }
                pendingIcon = PendingIcon(id: id, continuation: continuation)
                let cancelTimeout = scheduleTimeout(0.2) { [weak self] in
                    self?.finishIcon(id: id, result: nil)
                }
                guard pendingIcon?.id == id else {
                    cancelTimeout()
                    return
                }
                pendingIcon?.cancelTimeout = cancelTimeout
                guard allowed(token: token, view: view, shouldContinue: shouldContinue) else {
                    finishIcon(id: id, result: nil)
                    return
                }

                // The callback captures no control, editor or owner gate. The
                // exact live IconKey goes through the existing pipeline cache.
                let cancelRequest = request(pipeline, key, token) { [weak self] deliveredKey, deliveredToken, result in
                    guard let self else { return }
                    let current = self.generation == token && deliveredToken == token && deliveredKey == key
                    self.finishIcon(id: id, result: current ? result : nil)
                }
                if pendingIcon?.id == id {
                    pendingIcon?.cancelRequest = cancelRequest
                    if !allowed(token: token, view: view, shouldContinue: shouldContinue) {
                        finishIcon(id: id, result: nil)
                    }
                } else {
                    // A synchronous delivery/cancel can precede handle return.
                    cancelRequest()
                }
            }
        }, onCancel: { [weak self] in
            // Cancellation handlers can run off actor, including before
            // registration. The operation also checks Task.isCancelled there.
            DispatchQueue.main.async {
                MainActor.assumeIsolated { self?.finishIcon(id: id, result: nil) }
            }
        })
    }

    private func finishIcon(id: UUID, result: IconResult?) {
        guard let pending = pendingIcon, pending.id == id else { return }
        pendingIcon = nil
        pending.cancelTimeout?()
        pending.cancelRequest?()
        pending.continuation.resume(returning: result)
    }

    private static func isNativeControl(_ view: NSView) -> Bool {
        // AppKit may give an image-only button a framework-owned drawing child
        // during layout. A blanket empty-subviews test skips real buttons.
        if let caption = view as? NSTextField {
            guard !caption.isEditable && !caption.isSelectable else { return false }
        } else if !(view is NSButton) { return false }
        // cacheDisplay can recurse: admit only a small decorative subtree, never
        // materials, editors, scroll containers or another interactive control.
        var pending = view.subviews.map { ($0, 1) }
        var visited = 0
        guard pending.count <= 16 else { return false }
        while let (child, depth) = pending.popLast() {
            visited += 1
            guard visited <= 16, depth <= 4,
                  !(child is NSVisualEffectView), !(child is NSScrollView), !(child is NSTextView) else { return false }
            if let field = child as? NSTextField {
                guard !field.isEditable && !field.isSelectable else { return false }
            } else if child is NSControl, !(child is NSImageView) { return false }
            let descendants = child.subviews
            guard visited + pending.count + descendants.count <= 16 else { return false }
            pending += descendants.map { ($0, depth + 1) }
        }
        return true
    }

    private static func isValid(_ key: IconKey) -> Bool {
        key.pointSize.isFinite && key.pointSize > 0 && key.displayScale.isFinite
            && key.displayScale > 0 && key.pixelSize.isFinite && key.pixelSize > 0
    }

    /// Clamp before integer conversion, including finite inputs whose product
    /// overflows. Reject non-finite rects and unsafe bitmap-to-point transforms.
    static func pixelDimensions(bounds: NSRect, displayScale: Double) -> (width: Int, height: Int)? {
        guard displayScale.isFinite, displayScale > 0,
              bounds.origin.x.isFinite, bounds.origin.y.isFinite,
              bounds.size.width.isFinite, bounds.size.height.isFinite,
              bounds.size.width > 0, bounds.size.height > 0,
              bounds.maxX.isFinite, bounds.maxY.isFinite else { return nil }
        let cap = Double(maxPixelDimension)
        let width = Int(max(1, min(cap, (Double(bounds.width) * displayScale).rounded(.up))))
        let height = Int(max(1, min(cap, (Double(bounds.height) * displayScale).rounded(.up))))
        let scaleX = CGFloat(width) / bounds.width
        let scaleY = CGFloat(height) / bounds.height
        guard scaleX.isFinite, scaleY.isFinite, scaleX > 0, scaleY > 0,
              (bounds.origin.x * scaleX).isFinite,
              (bounds.origin.y * scaleY).isFinite else { return nil }
        return (width, height)
    }

    private func draw(_ view: NSView, image: NSImage?, displayScale: Double,
                      shouldContinue: () -> Bool) -> Bool {
        guard shouldContinue(), Self.isNativeControl(view) else { return false }
        let bounds = view.bounds
        guard let pixels = Self.pixelDimensions(bounds: bounds, displayScale: displayScale),
              let bitmap = makeBitmap(pixels.width, pixels.height),
              bitmap.pixelsWide == pixels.width, bitmap.pixelsHigh == pixels.height,
              shouldContinue(), view.bounds == bounds, Self.isNativeControl(view) else { return false }
        // Logical size selects the point-to-pixel mapping; allocation stays at
        // <= 256 on each axis. Never ask AppKit to allocate a full-view bitmap.
        bitmap.size = bounds.size
        view.cacheDisplay(in: bounds, to: bitmap)
        guard let image, shouldContinue(), view.bounds == bounds else { return true }
        // Decode into the same disposable allocation without assigning the
        // image/key/handle to the supplied control or storing output pixels.
        bitmap.size = NSSize(width: pixels.width, height: pixels.height)
        guard let context = NSGraphicsContext(bitmapImageRep: bitmap) else { return true }
        NSGraphicsContext.saveGraphicsState()
        defer { NSGraphicsContext.restoreGraphicsState() }
        NSGraphicsContext.current = context
        image.draw(in: NSRect(origin: .zero, size: bitmap.size), from: .zero,
            operation: .copy, fraction: 1, respectFlipped: false, hints: nil)
        return true
    }
}
