import AppKit
import AppCatalogCore
import AppGridUI
import XCTest
@testable import PagingUI
@testable import PagingPrototypeApp

private final class HandoffRenderer: NSView, PagingPageRendering, PagingPageRenderingTargetBinding {
    weak var renderTarget: NSView?
    var renders = 0
    var clears = 0
    var lastReuseGeneration: UInt64?
    func render(pageIndex: Int, content: PagingPageContent, pageCount: Int, reuseGeneration: UInt64) {
        renders += 1
        lastReuseGeneration = reuseGeneration
    }
    func clearForReuse() { clears += 1 }
}

@MainActor
final class PageHostRendererHandoffTests: XCTestCase {
    private func content(placeholder: Bool = false) -> PagingPageContent {
        .init(presentationID: .init(revision: 1, pageIndex: 0),
              items: [.init(slot: 0, identity: nil, title: "Synthetic neutral tile")], isPlaceholder: placeholder)
    }

    func testNeutralChildrenRetireAtCustomAdoptionWithoutClearingHostOrUnownedViews() throws {
        let host = PageHostView(frame: .init(x: 0, y: 0, width: 400, height: 300))
        host.render(pageIndex: 0, content: content(), pageCount: 5, reuseGeneration: host.reuseGeneration)
        let label = try XCTUnwrap(host.subviews.compactMap { $0 as? NSTextField }.first)
        XCTAssertEqual(label.stringValue, "Page 1 of 5")
        let tiles = host.subviews.filter { $0 !== label }
        XCTAssertEqual(tiles.count, 1)
        let unowned = NSView(frame: .zero)
        host.addSubview(unowned)
        let generation = host.reuseGeneration
        let renderer = HandoffRenderer(frame: .zero)
        host.customRenderer = renderer
        XCTAssertTrue(label.isHidden)
        XCTAssertEqual(label.stringValue, "")
        XCTAssertTrue(tiles.allSatisfy { $0.superview == nil })
        XCTAssertTrue(unowned.superview === host, "Retire only the neutral renderer's owned children")
        XCTAssertEqual(host.reuseGeneration, generation, "A renderer handoff is not host reuse")
        host.render(pageIndex: 0, content: content(), pageCount: 2, reuseGeneration: generation)
        XCTAssertEqual(renderer.renders, 1)
        XCTAssertEqual(renderer.clears, 0)
        XCTAssertEqual(renderer.lastReuseGeneration, generation)
        XCTAssertTrue(renderer.renderTarget === host)
    }

    func testInitialPlaceholderLabelCannotSurviveRealRendererHandoffOrCountUpdate() async throws {
        let host = PageHostView(frame: .init(x: 0, y: 0, width: 400, height: 300))
        host.render(pageIndex: 0, content: content(placeholder: true), pageCount: 5, reuseGeneration: 0)
        let obsolete = try XCTUnwrap(host.subviews.compactMap { $0 as? NSTextField }.first)
        let renderer = HandoffRenderer(frame: .zero)
        host.customRenderer = renderer
        host.render(pageIndex: 0, content: content(), pageCount: 2, reuseGeneration: 0)
        await withCheckedContinuation { continuation in
            DispatchQueue.main.async { continuation.resume() }
        }
        XCTAssertEqual(host.accessibilityLabel(), "Page 1 of 2")
        XCTAssertTrue(obsolete.isHidden)
        XCTAssertEqual(obsolete.stringValue, "")
        XCTAssertFalse(host.subviews.compactMap { $0 as? NSTextField }.contains { $0.stringValue == "Page 1 of 5" })
        host.customRenderer = renderer
        XCTAssertEqual(renderer.clears, 0, "Normal live-host reassignment must not clear custom content")
        XCTAssertEqual(host.reuseGeneration, 0)
        host.clearForReuse()
        XCTAssertEqual(renderer.clears, 1)
        XCTAssertEqual(host.reuseGeneration, 1)
    }

    func testActualCatalogRendererReplacesInitialFivePageNeutralContentWithTwoRealPages() async throws {
        let surface = makeSurface(pageCount: 5, itemsPerPage: 35)
        let assembly = AppCatalogAssembly(roots: [URL(fileURLWithPath: "/SyntheticHandoff")], loader: RecordingIconLoader())
        let app = AppDelegate(options: .default)
        app.surface = surface
        app.assembly = assembly
        defer { assembly.teardown(); surface.teardown() }
        let initialHost = try XCTUnwrap(surface.hostForPage(0))
        let initialGeneration = initialHost.reuseGeneration
        let obsolete = try XCTUnwrap(initialHost.subviews.compactMap { $0 as? NSTextField }.first)
        XCTAssertEqual(obsolete.stringValue, "Page 1 of 5")
        surface.contentProvider = assembly.provider
        surface.renderer = assembly.renderer
        app.installFinalCatalogRuntimeCallbacks(assembly: assembly, surface: surface)
        let records: [AppRecord] = (0..<40).map { index in
            let bundle = "fixture.handoff.\(index)"
            let id = AppID.bundleIdentifier(bundle)
            return .init(id: id, displayName: "Synthetic \(index)", bundleIdentifier: bundle,
                         canonicalURL: URL(fileURLWithPath: "/SyntheticHandoff/\(index).app"),
                         iconIdentity: .from(appID: id), sourceRootPriority: 0)
        }
        assembly.provider.receive(.init(revision: .init(1), records: records))
        app.applyPendingAtIdleBoundary()
        await withCheckedContinuation { continuation in
            DispatchQueue.main.async { continuation.resume() }
        }
        XCTAssertEqual(surface.core.pageCount, 2)
        XCTAssertTrue(surface.hostForPage(0) === initialHost)
        XCTAssertEqual(initialHost.accessibilityLabel(), "Page 1 of 2")
        XCTAssertEqual(assembly.renderer.pageView(forPage: 0)?.pageLabelText, "Page 1 of 2")
        XCTAssertEqual(assembly.renderer.pageView(forPage: 0)?.cell(at: 0)?.bindingToken?.reuseGeneration, initialGeneration)
        XCTAssertTrue(obsolete.isHidden)
        XCTAssertEqual(obsolete.stringValue, "")
    }
}
