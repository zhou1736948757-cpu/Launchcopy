//
//  PageHostBackdropTests.swift
//  PagingUITests
//
//  Synthetic compositing regression for the real PageHostView. The saturated
//  backdrop is generated in memory and never reads desktop wallpaper data.
//


import AppKit
import XCTest
@testable import PagingUI

private final class TransparentTestRenderer: NSView, PagingPageRendering, PagingPageRenderingTargetBinding {
    weak var renderTarget: NSView?
    private(set) var renderCount = 0
    private(set) var clearCount = 0

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.backgroundColor = nil
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    func render(pageIndex: Int, content: PagingPageContent, pageCount: Int, reuseGeneration: UInt64) {
        renderCount += 1
    }

    func clearForReuse() {
        clearCount += 1
    }
}

private final class TargetBindingTestRenderer: PagingPageRendering, PagingPageRenderingTargetBinding {
    weak var renderTarget: NSView?
    private(set) var renderCount = 0

    func render(pageIndex: Int, content: PagingPageContent, pageCount: Int, reuseGeneration: UInt64) {
        renderCount += 1
    }

    func clearForReuse() {}
}

final class PageHostBackdropTests: XCTestCase {
    private let backdropColor = NSColor(deviceRed: 1, green: 0, blue: 0, alpha: 1)

    func testSyntheticBackdropRemainsVisibleThroughCustomRendererHost() throws {
        let size = NSSize(width: 180, height: 120)
        let renderer = TargetBindingTestRenderer()
        let host = makeRenderedHost(size: size, renderer: renderer)
        let root = makeBackdropRoot(size: size, host: host)

        let image = try renderBitmap(root)
        try writeArtifactIfRequested(image)
        let center = try XCTUnwrap(image.colorAt(x: image.pixelsWide / 2, y: image.pixelsHigh / 2))

        assertSaturatedRed(center)
        XCTAssertNil(host.layer?.backgroundColor, "The presentation host must not fill over the backdrop")
        XCTAssertEqual(renderer.renderCount, 1)
        XCTAssertTrue(renderer.renderTarget === host)
    }

    func testResizeAndReuseKeepCustomRendererHostTransparent() throws {
        let renderer = TransparentTestRenderer()
        let host = makeRenderedHost(size: NSSize(width: 160, height: 100), renderer: renderer)
        XCTAssertEqual(renderer.frame, host.bounds)

        let generationBeforeReuse = host.reuseGeneration
        host.clearForReuse()
        XCTAssertEqual(host.reuseGeneration, generationBeforeReuse &+ 1)
        XCTAssertEqual(renderer.clearCount, 1)
        XCTAssertNil(renderer.superview)

        let resized = NSSize(width: 240, height: 150)
        host.frame = NSRect(origin: .zero, size: resized)
        host.render(
            pageIndex: 1,
            content: makeContent(pageIndex: 1),
            pageCount: 3,
            reuseGeneration: host.reuseGeneration
        )
        host.layoutSubtreeIfNeeded()

        XCTAssertEqual(renderer.frame, host.bounds)
        XCTAssertEqual(renderer.renderCount, 2)
        XCTAssertTrue(renderer.superview === host)
        XCTAssertNil(host.layer?.backgroundColor)

        let root = makeBackdropRoot(size: resized, host: host)
        let image = try renderBitmap(root)
        let center = try XCTUnwrap(image.colorAt(x: image.pixelsWide / 2, y: image.pixelsHigh / 2))
        assertSaturatedRed(center)
    }

    func testNeutralRendererRetainsLaboratoryChrome() {
        let host = PageHostView(frame: NSRect(x: 0, y: 0, width: 240, height: 180))
        host.render(
            pageIndex: 0,
            content: PagingPageContent(
                presentationID: PagePresentationID(revision: 1, pageIndex: 0),
                items: [PagingPageContentItem(slot: 0, identity: nil, title: "Neutral")],
                isPlaceholder: true
            ),
            pageCount: 1,
            reuseGeneration: host.reuseGeneration
        )
        host.layoutSubtreeIfNeeded()

        XCTAssertEqual(host.visibleItemCount, 1)
        XCTAssertNotNil(host.layer?.backgroundColor, "The neutral lab renderer keeps its existing host chrome")
        XCTAssertEqual(host.layer?.borderWidth, 1)
        XCTAssertEqual(host.layer?.cornerRadius, 12)
    }

    private func makeRenderedHost(size: NSSize, renderer: PagingPageRendering) -> PageHostView {
        let host = PageHostView(frame: NSRect(origin: .zero, size: size))
        host.customRenderer = renderer
        host.render(
            pageIndex: 0,
            content: makeContent(pageIndex: 0),
            pageCount: 3,
            reuseGeneration: host.reuseGeneration
        )
        host.layoutSubtreeIfNeeded()
        return host
    }

    private func makeContent(pageIndex: Int) -> PagingPageContent {
        PagingPageContent(
            presentationID: PagePresentationID(revision: 1, pageIndex: pageIndex),
            items: [],
            isPlaceholder: false
        )
    }

    private func makeBackdropRoot(size: NSSize, host: PageHostView) -> NSView {
        let root = NSView(frame: NSRect(origin: .zero, size: size))
        root.wantsLayer = true
        root.layer?.backgroundColor = backdropColor.cgColor
        host.frame = root.bounds
        root.addSubview(host)
        root.layoutSubtreeIfNeeded()
        return root
    }

    private func renderBitmap(_ view: NSView) throws -> NSBitmapImageRep {
        let bounds = view.bounds
        let image = try XCTUnwrap(view.bitmapImageRepForCachingDisplay(in: bounds))
        view.cacheDisplay(in: bounds, to: image)
        return image
    }

    private func writeArtifactIfRequested(_ image: NSBitmapImageRep) throws {
        let environment = ProcessInfo.processInfo.environment
        guard let directory = environment["PAGING_BACKDROP_ARTIFACT_DIR"],
              let label = environment["PAGING_BACKDROP_ARTIFACT_LABEL"] else {
            return
        }
        let directoryURL = URL(fileURLWithPath: directory, isDirectory: true)
        try FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)
        let data = try XCTUnwrap(image.representation(using: .png, properties: [:]))
        try data.write(to: directoryURL.appendingPathComponent("\(label)-synthetic-backdrop.png"))
    }

    private func assertSaturatedRed(
        _ actual: NSColor,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let actualRGB = actual.usingColorSpace(.deviceRGB)
        XCTAssertNotNil(actualRGB, file: file, line: line)
        guard let actualRGB else { return }
        XCTAssertGreaterThan(actualRGB.redComponent, 0.9, file: file, line: line)
        XCTAssertGreaterThan(actualRGB.redComponent - actualRGB.greenComponent, 0.7, file: file, line: line)
        XCTAssertLessThan(actualRGB.blueComponent, 0.1, file: file, line: line)
        XCTAssertGreaterThan(actualRGB.alphaComponent, 0.99, file: file, line: line)
    }
}
