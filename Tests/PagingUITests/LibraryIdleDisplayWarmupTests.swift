import AppCatalogCore
import AppGridUI
import AppIconPipeline
import AppKit
import XCTest
@testable import PagingPrototypeApp

/// Synthetic controls and icons only. Main owns serial execution. These tests
/// cover lifecycle and allocation contracts, not hardware timing or materials.
@MainActor
final class LibraryIdleDisplayWarmupTests: XCTestCase {
    private func key(_ index: Int = 1, pointSize: Double = 88, scale: Double = 2) -> IconKey {
        .init(identity: .from(appID: .bundleIdentifier("fixture.idle-display.\(index)")),
            pointSize: pointSize, displayScale: scale)
    }

    private func button(width: CGFloat = 88, height: CGFloat = 88) -> IdleWarmupButton {
        IdleWarmupButton(frame: NSRect(x: 0, y: 0, width: width, height: height))
    }

    private func bitmap(_ width: Int, _ height: Int) -> NSBitmapImageRep? {
        NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: width, pixelsHigh: height,
            bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
            colorSpaceName: .deviceRGB, bytesPerRow: width * 4, bitsPerPixel: 32)
    }

    private func eventually(_ description: String, file: StaticString = #filePath,
                            line: UInt = #line, _ predicate: @MainActor () -> Bool) async {
        let deadline = ContinuousClock.now.advanced(by: .seconds(2))
        while !predicate(), ContinuousClock.now < deadline { await Task.yield() }
        XCTAssertTrue(predicate(), description, file: file, line: line)
    }

    private func run(_ warmer: LibraryIdleDisplayWarmup, items: [LibraryIdleDisplayWarmup.Item],
                     pipeline: IconPipeline?, shouldContinue: @escaping @MainActor () -> Bool = { true }) -> IdleWarmupRun {
        IdleWarmupRun(warmer: warmer, items: items, pipeline: pipeline, shouldContinue: shouldContinue)
    }

    func testOnlyFirst64SuppliedControlsAllocateCappedTemporaryBitmaps() async {
        let controls = (0..<70).map { _ in button(width: 900, height: 700) }
        var allocations: [(Int, Int)] = []
        let warmer = LibraryIdleDisplayWarmup(makeBitmap: { width, height in
            allocations.append((width, height))
            return self.bitmap(width, height)
        })
        let completed = await warmer.prepare(items: controls.map { .init(view: $0, iconKey: nil) },
            pipeline: nil, displayScale: 3, profile: nil, shouldContinue: { true })
        XCTAssertTrue(completed)
        XCTAssertEqual(LibraryIdleDisplayWarmup.maxItems, 64)
        XCTAssertEqual(LibraryIdleDisplayWarmup.maxPixelDimension, 256)
        XCTAssertEqual(allocations.count, 64)
        XCTAssertTrue(allocations.allSatisfy { $0.0 == 256 && $0.1 == 256 })
        XCTAssertTrue(controls.prefix(64).allSatisfy { $0.displays == 1 })
        XCTAssertTrue(controls.suffix(6).allSatisfy { $0.displays == 0 })
        XCTAssertTrue(controls.allSatisfy { $0.window == nil && $0.superview == nil && $0.lastBitmap == nil })
    }

    func testFiniteGeometryIsRoundedUpClampedAndValidatedBeforeAllocation() async {
        let valid: [(NSRect, Double, Int, Int)] = [
            (.init(x: 0, y: 0, width: 0.1, height: 0.2), 1, 1, 1),
            (.init(x: 3, y: -4, width: 12.25, height: 18.25), 2, 25, 37),
            (.init(x: 0, y: 0, width: 800, height: 12), 2, 256, 24),
            (.init(x: 0, y: 0, width: CGFloat.greatestFiniteMagnitude / 4, height: 8),
                Double.greatestFiniteMagnitude, 256, 256)
        ]
        for (bounds, scale, width, height) in valid {
            let pixels = LibraryIdleDisplayWarmup.pixelDimensions(bounds: bounds, displayScale: scale)
            XCTAssertEqual(pixels?.width, width)
            XCTAssertEqual(pixels?.height, height)
        }
        let invalid: [NSRect] = [
            .zero, .init(x: 0, y: 0, width: -1, height: 2),
            .init(x: 0, y: 0, width: 2, height: 0),
            .init(x: CGFloat.nan, y: 0, width: 2, height: 2),
            .init(x: 0, y: CGFloat.infinity, width: 2, height: 2),
            .init(x: 0, y: 0, width: CGFloat.infinity, height: 2),
            .init(x: 0, y: 0, width: 2, height: CGFloat.nan),
            .init(x: 0, y: 0, width: CGFloat.leastNonzeroMagnitude, height: 2)
        ]
        let controls = invalid.map { bounds -> IdleWarmupButton in
            let control = button()
            control.syntheticBounds = bounds
            return control
        }
        var allocations = 0
        let warmer = LibraryIdleDisplayWarmup(makeBitmap: { _, _ in allocations += 1; return nil })
        let completed = await warmer.prepare(items: controls.map { .init(view: $0, iconKey: self.key()) },
            pipeline: nil, displayScale: 2, profile: nil, shouldContinue: { true })
        XCTAssertTrue(completed)
        XCTAssertEqual(allocations, 0)
        XCTAssertTrue(controls.allSatisfy { $0.displays == 0 })
        for scale in [0, -1, Double.nan, .infinity] {
            let result = await warmer.prepare(items: [.init(view: button(), iconKey: nil)],
                pipeline: nil, displayScale: scale, profile: nil, shouldContinue: { true })
            XCTAssertFalse(result)
        }
        XCTAssertEqual(allocations, 0)
    }

    func testMaterialContainersAndEditableTextNeverEnterNativeDisplayOrPrefetch() async {
        let requests = IdleWarmupRequests()
        let pipeline = IconPipeline(loader: RecordingIconLoader(), limits: .init())
        defer { pipeline.shutdown() }
        var allocations = 0
        let warmer = LibraryIdleDisplayWarmup(request: requests.register, makeBitmap: { width, height in
            allocations += 1
            return self.bitmap(width, height)
        })
        let material = IdleWarmupMaterial(frame: .init(x: 0, y: 0, width: 1000, height: 800))
        let container = NSView(frame: material.frame)
        let nestedButton = button()
        nestedButton.addSubview(material)
        let editor = NSTextField(frame: .init(x: 0, y: 0, width: 80, height: 20))
        editor.isEditable = true
        let caption = NSTextField(labelWithString: "Synthetic caption")
        caption.frame = editor.frame
        let result = await warmer.prepare(items: [material, container, nestedButton, editor, caption].map {
            .init(view: $0, iconKey: $0 === caption ? nil : self.key())
        }, pipeline: pipeline, displayScale: 2, profile: nil, shouldContinue: { true })
        XCTAssertTrue(result)
        XCTAssertEqual(allocations, 1)
        XCTAssertTrue(requests.calls.isEmpty)
        XCTAssertEqual(material.displays, 0)
        XCTAssertEqual(nestedButton.displays, 0)
        XCTAssertNil(editor.currentEditor())
        XCTAssertTrue(container.subviews.isEmpty)
    }

    func testLaidOutRealGalleryButtonWithNativeDrawingChildStillPrefetches() async {
        let id = AppID.bundleIdentifier("fixture.idle-display.real-button")
        let record = AppRecord(id: id, displayName: "Real Native Fixture", bundleIdentifier: nil,
            canonicalURL: URL(fileURLWithPath: "/SyntheticIdleDisplay/Real.app"),
            iconIdentity: .from(appID: id), sourceRootPriority: 0)
        let button = LibraryGalleryIconButton(entry: .init(record: record, displayName: record.displayName,
            category: .utilities), detailsTitle: "Details")
        button.frame = .init(x: 0, y: 0, width: 88, height: 88)
        button.needsLayout = true
        button.layoutSubtreeIfNeeded()
        button.isEnabled = false
        let image = button.image
        let pipeline = IconPipeline(loader: RecordingIconLoader(), limits: .init())
        defer { pipeline.shutdown() }
        let warmer = LibraryIdleDisplayWarmup()
        let completed = await warmer.prepare(items: [.init(view: button, iconKey: .init(identity: record.iconIdentity,
            pointSize: 88, displayScale: 2))], pipeline: pipeline, displayScale: 2, profile: nil,
            shouldContinue: { true })
        XCTAssertTrue(completed)
        XCTAssertEqual(pipeline.stats.requests, 1)
        XCTAssertTrue(button.image === image)
        XCTAssertFalse(button.isEnabled)
        XCTAssertNil(button.window)
        XCTAssertNil(button.superview)
    }

    func testDecorativeDescendantTraversalIsBounded() async {
        let excessive = button()
        for _ in 0..<17 { excessive.addSubview(NSView()) }
        let interactive = button()
        interactive.addSubview(NSButton(frame: .zero))
        let deep = button()
        var leaf: NSView = deep
        for _ in 0..<5 { let child = NSView(); leaf.addSubview(child); leaf = child }
        var allocations = 0
        let warmer = LibraryIdleDisplayWarmup(makeBitmap: { _, _ in allocations += 1; return nil })
        let completed = await warmer.prepare(items: [excessive, interactive, deep].map { .init(view: $0, iconKey: nil) },
            pipeline: nil, displayScale: 2, profile: nil, shouldContinue: { true })
        XCTAssertTrue(completed)
        XCTAssertEqual(allocations, 0)
    }

    func testNativeControlsKeepImagesKeysCallbacksActionsEditorAndDetachedHierarchy() async {
        let id = AppID.bundleIdentifier("fixture.idle-display.control")
        let record = AppRecord(id: id, displayName: "Synthetic Control", bundleIdentifier: nil,
            canonicalURL: URL(fileURLWithPath: "/SyntheticIdleDisplay/Control.app"),
            iconIdentity: .from(appID: id), sourceRootPriority: 0)
        let entry = AppLibraryEntry(record: record, displayName: record.displayName,
            category: .utilities, manualCategory: nil)
        let control = LibraryGalleryIconButton(entry: entry, detailsTitle: "Details")
        control.frame = .init(x: 10, y: 10, width: 88, height: 88)
        control.isEnabled = false
        let caption = NSTextField(labelWithString: "Synthetic caption")
        caption.frame = .init(x: 10, y: 110, width: 180, height: 24)
        let host = NSView(frame: .init(x: 0, y: 0, width: 220, height: 160))
        host.addSubview(control)
        host.addSubview(caption)
        var activations = 0
        var details = 0
        control.onActivate = { activations += 1 }
        control.onDetails = { details += 1 }
        let image = control.image
        let target = control.target
        let action = control.action
        let frame = control.frame
        let bounds = control.bounds
        let captionValue = caption.stringValue
        let warmer = LibraryIdleDisplayWarmup()
        let result = await warmer.prepare(items: [.init(view: caption, iconKey: nil),
            .init(view: control, iconKey: key())], pipeline: nil, displayScale: 2,
            profile: nil, shouldContinue: { true })
        XCTAssertTrue(result)
        XCTAssertTrue(control.image === image)
        XCTAssertTrue(control.target === target)
        XCTAssertEqual(control.action, action)
        XCTAssertEqual(control.frame, frame)
        XCTAssertEqual(control.bounds, bounds)
        XCTAssertFalse(control.isEnabled)
        XCTAssertEqual(caption.stringValue, captionValue)
        XCTAssertNil(caption.currentEditor())
        XCTAssertNil(control.window)
        XCTAssertNil(caption.window)
        XCTAssertTrue(control.superview === host)
        XCTAssertTrue(caption.superview === host)
        XCTAssertEqual(host.subviews.count, 2)
        XCTAssertEqual(activations, 0)
        XCTAssertEqual(details, 0)
        for name in ["key", "handle"] {
            let value = Mirror(reflecting: control).descendant(name)
            XCTAssertNotNil(value)
            XCTAssertEqual(value.map { Mirror(reflecting: $0).children.count }, 0)
        }
        control.onActivate?()
        control.onDetails?()
        XCTAssertEqual(activations, 1)
        XCTAssertEqual(details, 1)
    }

    func testDisabledGateDoesNoAllocationOrRequestAndReentrantGateCancelWins() async {
        let requests = IdleWarmupRequests()
        let pipeline = IconPipeline(loader: RecordingIconLoader(), limits: .init())
        defer { pipeline.shutdown() }
        var allocations = 0
        let warmer = LibraryIdleDisplayWarmup(request: requests.register, makeBitmap: { _, _ in
            allocations += 1
            return nil
        })
        let items = [LibraryIdleDisplayWarmup.Item(view: button(), iconKey: key())]
        let disabled = await warmer.prepare(items: items, pipeline: pipeline, displayScale: 2,
            profile: nil, shouldContinue: { false })
        XCTAssertFalse(disabled)
        let cancelled = await warmer.prepare(items: items, pipeline: pipeline, displayScale: 2,
            profile: nil, shouldContinue: { warmer.cancel(); return true })
        XCTAssertFalse(cancelled)
        XCTAssertEqual(allocations, 0)
        XCTAssertTrue(requests.calls.isEmpty)
        XCTAssertEqual(pipeline.stats.requests, 0)
    }

    func testReadinessRevokedAcrossControlSleepStopsBeforeRegistrationOrDrawing() async {
        let requests = IdleWarmupRequests()
        let pipeline = IconPipeline(loader: RecordingIconLoader(), limits: .init())
        defer { pipeline.shutdown() }
        let warmer = LibraryIdleDisplayWarmup(request: requests.register)
        let control = button()
        var gates = 0
        let result = await warmer.prepare(items: [.init(view: control, iconKey: key())],
            pipeline: pipeline, displayScale: 2, profile: nil) {
                gates += 1
                return gates < 3
            }
        XCTAssertFalse(result)
        XCTAssertTrue(requests.calls.isEmpty)
        XCTAssertEqual(control.displays, 0)
    }

    func testTaskCancelledBeforeEntryNeverRegistersContinuationOrRequest() async {
        let requests = IdleWarmupRequests()
        let timeouts = IdleWarmupTimeouts()
        let pipeline = IconPipeline(loader: RecordingIconLoader(), limits: .init())
        let warmer = LibraryIdleDisplayWarmup(request: requests.register, scheduleTimeout: timeouts.schedule)
        let control = button()
        let pending = run(warmer, items: [.init(view: control, iconKey: key())], pipeline: pipeline)
        pending.task?.cancel()
        defer { warmer.cancel(); pipeline.shutdown() }
        await eventually("Cancelled task returns without registration") { pending.result != nil }
        XCTAssertEqual(pending.result, false)
        XCTAssertTrue(requests.calls.isEmpty)
        XCTAssertTrue(timeouts.entries.isEmpty)
        XCTAssertEqual(control.displays, 0)
    }

    func testExplicitCancelReleasesSuppressedDeliveryAndIgnoresLateRepeatedCallbacks() async {
        let requests = IdleWarmupRequests()
        let timeouts = IdleWarmupTimeouts()
        let pipeline = IconPipeline(loader: RecordingIconLoader(), limits: .init())
        let warmer = LibraryIdleDisplayWarmup(request: requests.register, scheduleTimeout: timeouts.schedule)
        let control = button()
        let pending = run(warmer, items: [.init(view: control, iconKey: key())], pipeline: pipeline)
        defer { pending.task?.cancel(); warmer.cancel(); pipeline.shutdown() }
        await eventually("One prefetch is registered") { requests.calls.count == 1 }
        warmer.cancel()
        warmer.cancel()
        await eventually("cancel does not await a loader completion") { pending.result != nil }
        XCTAssertEqual(pending.result, false)
        XCTAssertEqual(requests.calls.first?.cancellations, 1)
        XCTAssertEqual(requests.active, 0)
        requests.deliver(0, .success(RecordingIconLoader.solidImage()))
        requests.deliver(0, .failed(.loadFailed))
        timeouts.fire(0, ignoringCancellation: true)
        XCTAssertEqual(control.displays, 0)
        XCTAssertEqual(pending.result, false)
    }

    func testTaskCancellationAlsoReleasesTheAwaitWithoutExplicitHelperCancel() async {
        let requests = IdleWarmupRequests()
        let timeouts = IdleWarmupTimeouts()
        let pipeline = IconPipeline(loader: RecordingIconLoader(), limits: .init())
        let warmer = LibraryIdleDisplayWarmup(request: requests.register, scheduleTimeout: timeouts.schedule)
        let control = button()
        let pending = run(warmer, items: [.init(view: control, iconKey: key())], pipeline: pipeline)
        defer { warmer.cancel(); pipeline.shutdown() }
        await eventually("Prefetch is awaiting delivery") { requests.calls.count == 1 }
        pending.task?.cancel()
        await eventually("Task cancellation releases continuation") { pending.result != nil }
        XCTAssertEqual(pending.result, false)
        XCTAssertEqual(requests.calls.first?.cancellations, 1)
        XCTAssertTrue(timeouts.entries.allSatisfy(\.cancelled))
        XCTAssertEqual(control.displays, 0)
    }

    func testSynchronousCancelDuringRegistrationRetiresTheReturnedHandleExactlyOnce() async {
        let requests = IdleWarmupRequests()
        let timeouts = IdleWarmupTimeouts()
        let pipeline = IconPipeline(loader: RecordingIconLoader(), limits: .init())
        let warmer = LibraryIdleDisplayWarmup(request: requests.register, scheduleTimeout: timeouts.schedule)
        requests.onRegister = { [weak warmer] _ in warmer?.cancel() }
        defer { warmer.cancel(); pipeline.shutdown() }
        let control = button()
        let pending = run(warmer, items: [.init(view: control, iconKey: key())], pipeline: pipeline)
        await eventually("Registration reentrancy returns") { pending.result != nil }
        XCTAssertEqual(pending.result, false)
        XCTAssertEqual(requests.calls.count, 1)
        XCTAssertEqual(requests.calls.first?.cancellations, 1)
        XCTAssertEqual(requests.active, 0)
        XCTAssertTrue(timeouts.entries.allSatisfy(\.cancelled))
        requests.deliver(0, .success(RecordingIconLoader.solidImage()))
        XCTAssertEqual(control.displays, 0)
    }

    func testTimeoutBeforeHandleRegistrationDoesNotStartARequest() async {
        let requests = IdleWarmupRequests()
        let pipeline = IconPipeline(loader: RecordingIconLoader(), limits: .init())
        var timeoutCancellations = 0
        let warmer = LibraryIdleDisplayWarmup(request: requests.register, scheduleTimeout: { delay, action in
            XCTAssertEqual(delay, 0.2)
            action()
            return { timeoutCancellations += 1 }
        })
        defer { warmer.cancel(); pipeline.shutdown() }
        let control = button()
        let pending = run(warmer, items: [.init(view: control, iconKey: key())], pipeline: pipeline)
        await eventually("Early timeout completes optional prefetch") { pending.result != nil }
        XCTAssertEqual(pending.result, true)
        XCTAssertTrue(requests.calls.isEmpty)
        XCTAssertEqual(timeoutCancellations, 1)
        XCTAssertEqual(control.displays, 1)
    }

    func testTimeoutSkipsSlowIconThenUsesOnlyOneConsumerAtATimeWithoutRetry() async {
        let requests = IdleWarmupRequests()
        let timeouts = IdleWarmupTimeouts()
        let pipeline = IconPipeline(loader: RecordingIconLoader(), limits: .init())
        let warmer = LibraryIdleDisplayWarmup(request: requests.register, scheduleTimeout: timeouts.schedule)
        let controls = [button(), button()]
        let pending = run(warmer, items: controls.enumerated().map {
            .init(view: $0.element, iconKey: self.key($0.offset))
        }, pipeline: pipeline)
        defer { pending.task?.cancel(); warmer.cancel(); pipeline.shutdown() }
        await eventually("First serial request") { requests.calls.count == 1 }
        XCTAssertEqual(timeouts.entries.first?.delay, 0.2)
        timeouts.fire(0)
        await eventually("Second request follows timeout of the first") { requests.calls.count == 2 }
        XCTAssertEqual(controls[0].displays, 1)
        XCTAssertEqual(requests.calls[0].cancellations, 1)
        requests.deliver(0, .success(RecordingIconLoader.solidImage()))
        XCTAssertEqual(requests.active, 1, "Old callback cannot retire a new consumer")
        requests.deliver(1, .failed(.loadFailed))
        await eventually("Optional failure still permits native preparation") { pending.result != nil }
        XCTAssertEqual(pending.result, true)
        XCTAssertEqual(requests.calls.count, 2)
        XCTAssertEqual(requests.peakActive, 1)
        XCTAssertEqual(requests.active, 0)
        XCTAssertTrue(controls.allSatisfy { $0.displays == 1 && $0.lastBitmap == nil })
    }

    func testAlreadyShutdownPipelineCannotStrandContinuation() async {
        let pipeline = IconPipeline(loader: RecordingIconLoader(), limits: .init())
        pipeline.shutdown()
        let timeouts = IdleWarmupTimeouts()
        let warmer = LibraryIdleDisplayWarmup(scheduleTimeout: timeouts.schedule)
        let control = button()
        let pending = run(warmer, items: [.init(view: control, iconKey: key())], pipeline: pipeline)
        defer { warmer.cancel() }
        await eventually("Rejected request still owns a bounded wait") { timeouts.entries.count == 1 }
        timeouts.fire(0)
        await eventually("Shutdown's missing completion is independently released") { pending.result != nil }
        XCTAssertEqual(pending.result, true)
        XCTAssertEqual(pipeline.stats.requests, 0)
        XCTAssertEqual(control.displays, 1)
    }

    func testRevokedReadinessAfterDeliveryPreventsDrawingAndFurtherRequests() async {
        let requests = IdleWarmupRequests()
        let timeouts = IdleWarmupTimeouts()
        let pipeline = IconPipeline(loader: RecordingIconLoader(), limits: .init())
        let warmer = LibraryIdleDisplayWarmup(request: requests.register, scheduleTimeout: timeouts.schedule)
        var ready = true
        let controls = [button(), button()]
        let pending = run(warmer, items: controls.map { .init(view: $0, iconKey: self.key()) },
            pipeline: pipeline, shouldContinue: { ready })
        defer { warmer.cancel(); pipeline.shutdown() }
        await eventually("First request is pending") { requests.calls.count == 1 }
        ready = false
        requests.deliver(0, .success(RecordingIconLoader.solidImage()))
        await eventually("Latest readiness is checked after suspension") { pending.result != nil }
        XCTAssertEqual(pending.result, false)
        XCTAssertEqual(requests.calls.count, 1)
        XCTAssertTrue(controls.allSatisfy { $0.displays == 0 })
    }

    func testNewPreparationOwnsItsRequestDespiteOldTaskCancellationAndLateDelivery() async {
        let requests = IdleWarmupRequests()
        let timeouts = IdleWarmupTimeouts()
        let pipeline = IconPipeline(loader: RecordingIconLoader(), limits: .init())
        let warmer = LibraryIdleDisplayWarmup(request: requests.register, scheduleTimeout: timeouts.schedule)
        let oldControl = button()
        let newControl = button()
        let old = run(warmer, items: [.init(view: oldControl, iconKey: key())], pipeline: pipeline)
        defer { old.task?.cancel(); warmer.cancel(); pipeline.shutdown() }
        await eventually("Old generation request") { requests.calls.count == 1 }
        let current = run(warmer, items: [.init(view: newControl, iconKey: key(2))], pipeline: pipeline)
        defer { current.task?.cancel() }
        await eventually("New generation replaces old") { requests.calls.count == 2 && old.result != nil }
        old.task?.cancel()
        requests.deliver(0, .success(RecordingIconLoader.solidImage()))
        timeouts.fire(0, ignoringCancellation: true)
        await Task.yield()
        XCTAssertNil(current.result)
        XCTAssertEqual(requests.active, 1)
        requests.deliver(1, .failed(.loadFailed))
        await eventually("Current generation completes") { current.result != nil }
        XCTAssertEqual(old.result, false)
        XCTAssertEqual(current.result, true)
        XCTAssertEqual(oldControl.displays, 0)
        XCTAssertEqual(newControl.displays, 1)
        XCTAssertEqual(requests.peakActive, 1)
    }

    func testPrefetchUsesTheExactExistingCacheKeyAndNeverBindsTheControl() async {
        let loader = RecordingIconLoader()
        let pipeline = IconPipeline(loader: loader, limits: .init())
        let warmer = LibraryIdleDisplayWarmup()
        defer { warmer.cancel(); pipeline.shutdown() }
        let requested = key(17, pointSize: 40, scale: 2)
        let control = button()
        let original = NSImage(size: .init(width: 8, height: 8))
        control.image = original
        let completed = await warmer.prepare(items: [.init(view: control, iconKey: requested)],
            pipeline: pipeline, displayScale: 1, profile: nil, shouldContinue: { true })
        XCTAssertTrue(completed)
        XCTAssertTrue(control.image === original)
        XCTAssertEqual(loader.requestedCount, 1)
        XCTAssertEqual(pipeline.stats.cacheMisses, 1)
        var delivered = false
        let handle = pipeline.request(key: requested, generation: 999) { key, generation, result in
            XCTAssertEqual(key, requested)
            XCTAssertEqual(generation, 999)
            if case .success = result { delivered = true }
        }
        defer { handle.cancel() }
        await eventually("The live request reuses the prefetched cache entry") { delivered }
        XCTAssertEqual(loader.requestedCount, 1)
        XCTAssertEqual(pipeline.stats.cacheHits, 1)
        XCTAssertEqual(pipeline.stats.requests, 2)
        XCTAssertTrue(control.image === original)
        XCTAssertNil(control.lastBitmap)
    }

    func testAllocationFailureCountsNoDisplayAndRetainsNoControlsOrLateCallbackOwner() async throws {
        let requests = IdleWarmupRequests()
        let timeouts = IdleWarmupTimeouts()
        let pipeline = IconPipeline(loader: RecordingIconLoader(), limits: .init())
        defer { pipeline.shutdown() }
        weak var releasedWarmer: LibraryIdleDisplayWarmup?
        weak var releasedControl: IdleWarmupButton?
        do {
            let warmer = LibraryIdleDisplayWarmup(request: requests.register,
                scheduleTimeout: timeouts.schedule, makeBitmap: { _, _ in nil })
            releasedWarmer = warmer
            let control = button()
            releasedControl = control
            let profile = LibraryEntryProfile()
            requests.onRegister = { index in requests.deliver(index, .failed(.loadFailed)) }
            let result = await warmer.prepare(items: [.init(view: control, iconKey: key())],
                pipeline: pipeline, displayScale: 2, profile: profile, shouldContinue: { true })
            requests.onRegister = nil
            XCTAssertTrue(result)
            XCTAssertEqual(control.displays, 0)
            XCTAssertEqual(requests.active, 0)
            let json = try XCTUnwrap(JSONSerialization.jsonObject(with: profile.encodedSnapshot()) as? [String: Any])
            let samples = try XCTUnwrap(json["samples"] as? [[String: Any]])
            let counts = samples.filter { ($0["tag"] as? String) == "idleControlDisplay" }.compactMap { $0["count"] as? Int }
            XCTAssertEqual(counts, [0], "Allocation failure must not report a rendered control")
        }
        await eventually("Late callbacks do not retain helper or controls") {
            releasedWarmer == nil && releasedControl == nil
        }
        requests.deliver(0, .success(RecordingIconLoader.solidImage()))
        timeouts.fire(0, ignoringCancellation: true)
        XCTAssertNil(releasedWarmer)
        XCTAssertNil(releasedControl)
    }
}

@MainActor
private final class IdleWarmupButton: NSButton {
    var displays = 0
    weak var lastBitmap: NSBitmapImageRep?
    var syntheticBounds: NSRect?

    override var bounds: NSRect {
        get { syntheticBounds ?? super.bounds }
        set { super.bounds = newValue }
    }

    override func cacheDisplay(in rect: NSRect, to bitmapImageRep: NSBitmapImageRep) {
        displays += 1
        lastBitmap = bitmapImageRep
        XCTAssertNil(window)
        XCTAssertTrue((1...256).contains(bitmapImageRep.pixelsWide))
        XCTAssertTrue((1...256).contains(bitmapImageRep.pixelsHigh))
    }
}

@MainActor
private final class IdleWarmupMaterial: NSVisualEffectView {
    var displays = 0
    override func cacheDisplay(in rect: NSRect, to bitmapImageRep: NSBitmapImageRep) { displays += 1 }
}

@MainActor
private final class IdleWarmupRun {
    var result: Bool?
    var task: Task<Void, Never>?

    init(warmer: LibraryIdleDisplayWarmup, items: [LibraryIdleDisplayWarmup.Item], pipeline: IconPipeline?,
         shouldContinue: @escaping @MainActor () -> Bool) {
        task = Task { @MainActor [weak self] in
            let result = await warmer.prepare(items: items, pipeline: pipeline, displayScale: 2,
                profile: nil, shouldContinue: shouldContinue)
            self?.result = result
        }
    }
}

@MainActor
private final class IdleWarmupRequests {
    struct Call {
        let key: IconKey
        let generation: UInt64
        let delivery: LibraryIdleDisplayWarmup.Delivery
        var cancellations = 0
    }

    var calls: [Call] = []
    var active = 0
    var peakActive = 0
    var onRegister: ((Int) -> Void)?

    func register(_ pipeline: IconPipeline, _ key: IconKey, _ generation: UInt64,
                  _ delivery: @escaping LibraryIdleDisplayWarmup.Delivery) -> LibraryIdleDisplayWarmup.Cancellation {
        let index = calls.count
        calls.append(Call(key: key, generation: generation, delivery: delivery))
        active += 1
        peakActive = max(peakActive, active)
        onRegister?(index)
        return { [weak self] in
            guard let self else { return }
            self.calls[index].cancellations += 1
            if self.calls[index].cancellations == 1 { self.active -= 1 }
        }
    }

    func deliver(_ index: Int, _ result: IconResult) {
        guard calls.indices.contains(index) else { return }
        let call = calls[index]
        call.delivery(call.key, call.generation, result)
    }
}

@MainActor
private final class IdleWarmupTimeouts {
    struct Entry {
        let delay: TimeInterval
        let action: @MainActor () -> Void
        var cancelled = false
    }
    var entries: [Entry] = []

    func schedule(_ delay: TimeInterval, _ action: @escaping @MainActor () -> Void) -> LibraryIdleDisplayWarmup.Cancellation {
        let index = entries.count
        entries.append(Entry(delay: delay, action: action))
        return { [weak self] in self?.entries[index].cancelled = true }
    }

    func fire(_ index: Int, ignoringCancellation: Bool = false) {
        guard entries.indices.contains(index), ignoringCancellation || !entries[index].cancelled else { return }
        entries[index].action()
    }
}
