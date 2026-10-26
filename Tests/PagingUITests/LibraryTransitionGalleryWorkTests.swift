import AppCatalogCore
import AppGridUI
import AppIconPipeline
import AppKit
import LauncherLocalization
import QuartzCore
import XCTest
@testable import PagingPrototypeApp

/// Reports admission visibility without ordering or activating a native window.
private final class TransitionGalleryReportedWindow: NSWindow {
    var reportsVisible = false
    override var isVisible: Bool { reportsVisible }
}

private final class TransitionGalleryMaterialLayer: CALayer {
    private(set) var backgroundWrites = 0
    private(set) var borderWidthWrites = 0
    private(set) var borderColorWrites = 0
    override var backgroundColor: CGColor? { didSet { backgroundWrites += 1 } }
    override var borderWidth: CGFloat { didSet { borderWidthWrites += 1 } }
    override var borderColor: CGColor? { didSet { borderColorWrites += 1 } }
    var writes: [Int] { [backgroundWrites, borderWidthWrites, borderColorWrites] }
}

/// Synthetic catalog data and mounted, unshown controls only. These tests check
/// request admission and property writes, not physical transition smoothness.
@MainActor
final class LibraryTransitionGalleryWorkTests: XCTestCase {
    private let strings = LocalizedStrings(language: .english)

    private func entry() -> AppLibraryEntry {
        let id = AppID.bundleIdentifier("fixture.transition.gallery")
        let record = AppRecord(id: id, displayName: "Gallery Fixture",
            bundleIdentifier: "fixture.transition.gallery",
            canonicalURL: URL(fileURLWithPath: "/SyntheticGallery/Fixture.app"),
            iconIdentity: .from(appID: id), sourceRootPriority: 0)
        return .init(record: record, displayName: record.displayName, category: .utilities)
    }

    @MainActor
    private final class Fixture {
        let pipeline = IconPipeline(loader: RecordingIconLoader(), limits: IconCacheLimits())
        let window: TransitionGalleryReportedWindow
        let view: AppLibraryView

        init(strings: LocalizedStrings) {
            let frame = NSRect(x: 0, y: 0, width: 1000, height: 700)
            window = TransitionGalleryReportedWindow(contentRect: frame,
                styleMask: [.titled, .resizable], backing: .buffered, defer: false)
            window.isReleasedWhenClosed = false
            view = AppLibraryView(frame: frame, strings: strings, iconPipeline: pipeline)
            window.contentView = view
        }

        func query(_ value: String) {
            view.searchField.stringValue = value
            view.controlTextDidChange(.init(name: NSControl.textDidChangeNotification, object: view.searchField))
        }

        func apply(_ entry: AppLibraryEntry, generation: UInt64 = 1) {
            view.apply(snapshot: .init(revision: .init(generation), entries: [entry], counts: [.utilities: 1]),
                isLoading: false, catalogIsEmpty: false, actionGeneration: generation)
        }

        func synchronize() {
            NotificationCenter.default.post(name: NSWindow.didUpdateNotification, object: window)
        }

        func prepareResults(_ entry: AppLibraryEntry) throws -> NSTableCellView {
            query("Gallery")
            apply(entry)
            view.layoutSubtreeIfNeeded()
            let cell = try XCTUnwrap(view.resultsTable.view(atColumn: 0, row: 0, makeIfNecessary: true) as? NSTableCellView)
            XCTAssertFalse(view.resultsTable.isHiddenOrHasHiddenAncestor)
            XCTAssertGreaterThan(view.resultsTable.rows(in: view.resultsTable.visibleRect).length, 0)
            XCTAssertEqual(pipeline.stats.requests, 0)
            return cell
        }

        func teardown() {
            view.reset()
            pipeline.shutdown()
            window.contentView = nil
            window.close()
        }
    }

    func testGalleryApplyDoesNotRequestResultIconsBeforeDeferredLayout() throws {
        let f = Fixture(strings: strings)
        defer { f.teardown() }
        let cell = try f.prepareResults(entry())
        f.window.reportsVisible = true
        f.synchronize()
        XCTAssertGreaterThan(f.pipeline.stats.requests, 0, "The fixture must admit result requests first")
        let requests = f.pipeline.stats.requests
        cell.imageView?.image = RecordingIconLoader.solidImage()

        f.query("")
        f.apply(entry(), generation: 2) // Intentionally do not lay out the new gallery yet.
        XCTAssertTrue(f.view.showsGallery)
        XCTAssertEqual(f.pipeline.stats.requests, requests)
        XCTAssertNil(cell.imageView?.image)

        f.view.layoutSubtreeIfNeeded()
        XCTAssertGreaterThan(f.pipeline.stats.requests, requests, "Visible gallery icons must still be admitted")
        let galleryRequests = f.pipeline.stats.requests
        f.synchronize()
        f.view.needsLayout = true
        f.view.layoutSubtreeIfNeeded()
        XCTAssertEqual(f.pipeline.stats.requests, galleryRequests)
    }

    func testNarrowDetailsIntentCancelsResultsBeforeVisibilityLayoutAndResumesWhenWide() throws {
        let f = Fixture(strings: strings)
        defer { f.teardown() }
        let cell = try f.prepareResults(entry())
        f.view.resultsTable.selectRowIndexes(IndexSet(integer: 0), byExtendingSelection: false)
        f.view.tableViewSelectionDidChange(.init(name: NSTableView.selectionDidChangeNotification, object: f.view.resultsTable))
        f.window.reportsVisible = true
        f.synchronize()
        let requests = f.pipeline.stats.requests
        XCTAssertGreaterThan(requests, 0)
        cell.imageView?.image = RecordingIconLoader.solidImage()

        f.view.setFrameSize(.init(width: 360, height: 700))
        f.view.showDetails(nil)
        XCTAssertTrue(f.view.detailsOpen)
        f.synchronize() // No layout: the old list may still have its visible flag.
        XCTAssertEqual(f.pipeline.stats.requests, requests)
        XCTAssertNil(cell.imageView?.image)
        f.view.layoutSubtreeIfNeeded()
        XCTAssertTrue(f.view.resultsTable.isHiddenOrHasHiddenAncestor)

        f.view.setFrameSize(.init(width: 1000, height: 700))
        f.view.needsLayout = true
        f.view.layoutSubtreeIfNeeded()
        XCTAssertFalse(f.view.resultsTable.isHiddenOrHasHiddenAncestor)
        XCTAssertGreaterThan(f.pipeline.stats.requests, requests)
    }

    func testQueuedResultDeliveryCannotPopulateNarrowDetailsBeforeLayout() async throws {
        let f = Fixture(strings: strings)
        defer { f.teardown() }
        let cell = try f.prepareResults(entry())
        f.window.reportsVisible = true
        f.synchronize()
        let deadline = ContinuousClock.now.advanced(by: .seconds(2))
        while cell.imageView?.image == nil, ContinuousClock.now < deadline { await Task.yield() }
        XCTAssertNotNil(cell.imageView?.image, "Prime the synthetic image cache before testing queued delivery")

        f.view.isHidden = true
        XCTAssertNil(cell.imageView?.image)
        f.view.isHidden = false
        let hits = f.pipeline.stats.cacheHits
        f.synchronize() // Cache delivery is enqueued on MainActor.
        XCTAssertGreaterThan(f.pipeline.stats.cacheHits, hits)
        f.view.resultsTable.selectRowIndexes(IndexSet(integer: 0), byExtendingSelection: false)
        f.view.tableViewSelectionDidChange(.init(name: NSTableView.selectionDidChangeNotification, object: f.view.resultsTable))
        f.view.setFrameSize(.init(width: 360, height: 700))
        f.view.showDetails(nil)
        XCTAssertTrue(f.view.detailsOpen)
        await drainDeferredPresentationTurns()
        XCTAssertNil(cell.imageView?.image, "A queued result must recheck presentation intent")
    }

    func testRepeatedMaterialPolicyAndVisibilityDoNotRewriteLayerProperties() throws {
        let card = makeCard()
        let (material, layer) = try instrumentMaterial(card)
        card.applyMaterial(visible: true, reduceTransparency: false, increaseContrast: false)
        let writes = layer.writes
        XCTAssertTrue(writes.allSatisfy { $0 > 0 })
        XCTAssertFalse(material.isHidden)
        XCTAssertEqual(material.state, .active)
        for _ in 0..<5 {
            card.applyMaterial(visible: true, reduceTransparency: false, increaseContrast: false)
            card.needsLayout = true
            card.layoutSubtreeIfNeeded()
        }
        XCTAssertEqual(layer.writes, writes)
        card.applyMaterial(visible: false, reduceTransparency: false, increaseContrast: false)
        XCTAssertEqual(material.state, .inactive)
        XCTAssertEqual(layer.writes, writes, "Visibility only changes material activation")
        card.applyMaterial(visible: true, reduceTransparency: false, increaseContrast: false)
        XCTAssertEqual(material.state, .active)
        XCTAssertEqual(layer.writes, writes)
    }

    func testEffectiveMaterialPolicyTracksTransparencyContrastAndAppearance() throws {
        let card = makeCard()
        let (material, layer) = try instrumentMaterial(card)
        card.appearance = try XCTUnwrap(NSAppearance(named: .aqua))
        card.applyMaterial(visible: true, reduceTransparency: true, increaseContrast: false)
        XCTAssertTrue(material.isHidden)
        XCTAssertEqual(layer.borderWidth, 0.5)
        let solidWrites = layer.writes
        card.applyMaterial(visible: true, reduceTransparency: true, increaseContrast: true)
        XCTAssertEqual(layer.borderWidth, 2)
        XCTAssertEqual(layer.backgroundWrites, solidWrites[0])
        XCTAssertEqual(layer.borderColorWrites, solidWrites[2])
        let contrastWrites = layer.writes
        card.applyMaterial(visible: true, reduceTransparency: false, increaseContrast: true)
        XCTAssertEqual(layer.writes, contrastWrites, "Contrast already supplies the same effective solid policy")

        card.appearance = try XCTUnwrap(NSAppearance(named: .darkAqua))
        card.applyMaterial(visible: true, reduceTransparency: true, increaseContrast: false)
        var expectedBackground = NSColor.clear.cgColor
        card.effectiveAppearance.performAsCurrentDrawingAppearance {
            expectedBackground = NSColor.windowBackgroundColor.cgColor
        }
        XCTAssertEqual(layer.backgroundColor, expectedBackground)
        let darkWrites = layer.writes
        card.applyMaterial(visible: true, reduceTransparency: true, increaseContrast: false)
        XCTAssertEqual(layer.writes, darkWrites)
        card.applyMaterial(visible: false, reduceTransparency: false, increaseContrast: false)
        XCTAssertFalse(material.isHidden)
        XCTAssertEqual(material.state, .inactive)
        XCTAssertEqual(layer.backgroundColor, NSColor.clear.cgColor)
        XCTAssertEqual(layer.borderWidth, 0.5)
    }

    private func makeCard() -> LibraryCategoryCard {
        LibraryCategoryCard(category: .utilities, entries: [entry()], title: "Utilities", detailsTitle: "Details")
    }

    private func instrumentMaterial(_ card: LibraryCategoryCard) throws -> (NSVisualEffectView, TransitionGalleryMaterialLayer) {
        let panel = try XCTUnwrap(card.iconButtons.first?.superview)
        let material = try XCTUnwrap(panel.subviews.compactMap { $0 as? NSVisualEffectView }.first)
        let layer = TransitionGalleryMaterialLayer()
        panel.layer = layer
        return (material, layer)
    }
}
