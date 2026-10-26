import AppCatalogCore
import AppIconPipeline
import AppKit
import LauncherLocalization
import PagingUI
import XCTest
@testable import AppGridUI

/// Synthetic, unshown AppKit fixtures. Native CUA exposure remains a separate Main gate.
@MainActor
final class HiddenLabelAccessibilityTests: XCTestCase {
    private struct UnusedIconLoader: IconLoading {
        enum Failure: Error { case synthetic }
        func load(key: IconKey) async throws -> NSImage { throw Failure.synthetic }
    }

    private func makeCell() -> AppGridCellView {
        _ = NSApplication.shared
        return AppGridCellView(frame: NSRect(x: 0, y: 0, width: 100, height: 100))
    }

    private func token(_ identity: AnyHashable, generation: UInt64 = 1) -> ItemBindingToken {
        ItemBindingToken(catalogRevision: 7, pageIdentity: .init(revision: 7, pageIndex: 0),
                         itemSlot: 0, appID: identity, reuseGeneration: generation,
                         iconKey: nil, surfaceGeneration: 9)
    }

    private func drainText() async {
        await withCheckedContinuation { continuation in
            DispatchQueue.main.async { continuation.resume() }
        }
    }

    private func folderImage(in cell: AppGridCellView) throws -> NSImageView {
        try XCTUnwrap(cell.subviews.compactMap { $0 as? NSImageView }
            .first { $0 !== cell.iconView && !$0.isHidden })
    }

    private func descendantIdentities(in view: NSView) -> [ObjectIdentifier] {
        view.subviews.flatMap { [ObjectIdentifier($0)] + descendantIdentities(in: $0) }
    }

    private func assertVisibleNativeImage(_ image: NSImageView, in cell: AppGridCellView,
                                          file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertTrue(image.superview === cell, file: file, line: line)
        XCTAssertFalse(image.isHiddenOrHasHiddenAncestor, file: file, line: line)
        XCTAssertFalse(image.isAccessibilityElement(), "Preserve the ignored native control wrapper",
                       file: file, line: line)
        XCTAssertEqual(image.cell?.isAccessibilityElement(), true,
                       "The native image cell owns exposure", file: file, line: line)
        XCTAssertEqual(image.cell?.accessibilityRole(), .image, file: file, line: line)
        XCTAssertNotNil(image.image, file: file, line: line)
        XCTAssertGreaterThan(image.frame.width, 0, file: file, line: line)
        XCTAssertGreaterThan(image.frame.height, 0, file: file, line: line)
        XCTAssertGreaterThan(image.bounds.width, 0, file: file, line: line)
        XCTAssertGreaterThan(image.bounds.height, 0, file: file, line: line)
        XCTAssertTrue(cell.bounds.intersects(image.frame), file: file, line: line)
    }

    private func assertNoImageMetadata(_ image: NSImageView,
                                       file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertTrue((image.cell?.accessibilityLabel() ?? "").isEmpty,
                      "No stale or duplicate image name", file: file, line: line)
        XCTAssertNil(image.cell?.accessibilityHelp(), file: file, line: line)
    }

    func testAppImageCarriesFullHiddenNameAndTogglePreservesExistingContentAndDescendants() {
        let cell = makeCell()
        let name = "An application name much wider than its caption — 用户のアプリ 😀"
        let binding = token(AnyHashable(makeAppID("fixture.hidden-label.app")))
        cell.bind(name: name, token: binding)
        let icon = makeIconImage()
        XCTAssertTrue(cell.applyIconIfValid(icon, token: binding))
        cell.setFocused(true)
        cell.layout()
        let descendants = descendantIdentities(in: cell)
        let image = cell.iconView

        for showsLabels in [false, false, true, false, true] {
            cell.showsAppLabels = showsLabels
            cell.layout()
            assertVisibleNativeImage(image, in: cell)
            XCTAssertEqual(cell.nameLabel.isHidden, !showsLabels)
            XCTAssertEqual(cell.bindingToken, binding)
            XCTAssertEqual(cell.boundName, name)
            XCTAssertEqual(cell.nameLabel.stringValue, name)
            XCTAssertTrue(cell.iconView === image)
            XCTAssertTrue(image.image === icon)
            XCTAssertTrue(cell.isFocused)
            XCTAssertEqual(descendantIdentities(in: cell), descendants)
            if showsLabels {
                assertNoImageMetadata(image)
            } else {
                // The ignored custom cell's metadata alone cannot satisfy this assertion.
                XCTAssertEqual(image.cell?.accessibilityLabel(), cell.boundName)
                XCTAssertNil(image.cell?.accessibilityHelp())
            }
        }
    }

    func testFolderUsesExistingVisibleSymbolAndClearsImageNameAndHelpWhenCaptionsReturn() async throws {
        let cell = makeCell()
        let binding = token(AnyHashable(FolderID()))
        cell.bindFolder(title: "A full folder title — 个人のツール 📁", memberCount: 2, token: binding)
        await drainText()
        cell.setFocused(true)
        cell.layout()
        let symbol = try folderImage(in: cell)
        let symbolImage = symbol.image
        let descendants = descendantIdentities(in: cell)

        for showsLabels in [false, false, true, false, true] {
            cell.showsAppLabels = showsLabels
            cell.layout()
            XCTAssertTrue(try folderImage(in: cell) === symbol)
            assertVisibleNativeImage(symbol, in: cell)
            XCTAssertTrue(symbol.image === symbolImage)
            XCTAssertEqual(cell.nameLabel.isHidden, !showsLabels)
            XCTAssertEqual(cell.bindingToken, binding)
            XCTAssertTrue(cell.isFocused)
            XCTAssertEqual(descendantIdentities(in: cell), descendants)
            assertNoImageMetadata(cell.iconView)
            if showsLabels {
                assertNoImageMetadata(symbol)
            } else {
                XCTAssertEqual(symbol.cell?.accessibilityLabel(), cell.boundName)
                XCTAssertEqual(symbol.cell?.accessibilityHelp(), "Folder with 2 items")
            }
        }
    }

    func testClearAndAppFolderAppReuseRetireBothImagesMetadataIncludingPendingFolderText() async throws {
        let cell = makeCell()
        cell.showsAppLabels = false
        let first = token(AnyHashable(makeAppID("fixture.hidden-label.first")))
        cell.bind(name: "First application", token: first)
        XCTAssertTrue(cell.applyIconIfValid(makeIconImage(), token: first))
        cell.layout()
        XCTAssertEqual(cell.iconView.cell?.accessibilityLabel(), "First application")

        cell.bindFolder(title: "Old folder", memberCount: 23,
                        token: token(AnyHashable(FolderID()), generation: 2))
        assertNoImageMetadata(cell.iconView)
        cell.layout()
        let symbol = try folderImage(in: cell)
        await drainText()
        XCTAssertEqual(symbol.cell?.accessibilityLabel(), "Old folder")
        XCTAssertEqual(symbol.cell?.accessibilityHelp(), "Folder with 23 items")
        assertNoImageMetadata(cell.iconView)

        // Queue a different folder's text, then replace it before the deferred write.
        cell.bindFolder(title: "Pending folder", memberCount: 1,
                        token: token(AnyHashable(FolderID()), generation: 3))
        cell.relabel(strings: LocalizedStrings(language: .japanese))
        let last = token(AnyHashable(makeAppID("fixture.hidden-label.last")), generation: 4)
        cell.bind(name: "Last application", token: last)
        assertNoImageMetadata(symbol)
        XCTAssertEqual(cell.iconView.cell?.accessibilityLabel(), "Last application")
        XCTAssertNil(cell.iconView.cell?.accessibilityHelp())
        let icon = makeIconImage()
        XCTAssertTrue(cell.applyIconIfValid(icon, token: last))
        await drainText()
        cell.layout()
        assertVisibleNativeImage(cell.iconView, in: cell)
        XCTAssertEqual(cell.iconView.cell?.accessibilityLabel(), "Last application")
        XCTAssertNil(cell.iconView.cell?.accessibilityHelp())
        XCTAssertTrue(cell.iconView.image === icon)
        XCTAssertEqual(cell.bindingToken, last)
        XCTAssertTrue(symbol.isHidden)
        assertNoImageMetadata(symbol)
        XCTAssertFalse(cell.applyIconIfValid(makeIconImage(), token: first))

        cell.bindFolder(title: "Cleared before formatting", memberCount: 7,
                        token: token(AnyHashable(FolderID()), generation: 5))
        cell.clearContent()
        assertNoImageMetadata(cell.iconView)
        assertNoImageMetadata(symbol)
        await drainText()
        XCTAssertNil(cell.bindingToken)
        XCTAssertEqual(cell.boundName, "")
        XCTAssertNil(cell.iconView.image)
        assertNoImageMetadata(cell.iconView)
        assertNoImageMetadata(symbol)
    }

    func testHiddenFolderImageHelpFollowsDeferredLocalizedZeroOneAndManyCounts() async throws {
        let cell = makeCell()
        cell.showsAppLabels = false
        let cases: [(InterfaceLanguage, [String])] = [
            (.english, ["Folder containing 0 items", "Folder containing 1 item", "Folder containing 23 items"]),
            (.simplifiedChinese, ["文件夹，含 0 项", "文件夹，含 1 项", "文件夹，含 23 项"]),
            (.japanese, ["0 項目を含むフォルダ", "1 項目を含むフォルダ", "23 項目を含むフォルダ"])
        ]
        for (index, count) in [0, 1, 23].enumerated() {
            let binding = token(AnyHashable(FolderID()), generation: UInt64(index + 1))
            cell.bindFolder(title: "Personal 用户のフォルダ 📁", memberCount: count, token: binding)
            cell.layout()
            let symbol = try folderImage(in: cell)
            for (language, helps) in cases {
                let before = cell.languageFormattingCount
                cell.relabel(strings: LocalizedStrings(language: language))
                XCTAssertEqual(cell.languageFormattingCount, before, "Formatting stays deferred")
                await drainText()
                XCTAssertEqual(cell.languageFormattingCount - before, 2)
                assertVisibleNativeImage(symbol, in: cell)
                XCTAssertEqual(symbol.cell?.accessibilityLabel(), cell.boundName)
                XCTAssertEqual(symbol.cell?.accessibilityHelp(), helps[index])
                XCTAssertEqual(cell.accessibilityHelp(), helps[index])
                XCTAssertEqual(cell.bindingToken, binding)
                XCTAssertTrue(cell.nameLabel.isHidden)
            }
        }
        cell.showsAppLabels = true
        let symbol = try folderImage(in: cell)
        cell.relabel(strings: LocalizedStrings(language: .english))
        await drainText()
        assertNoImageMetadata(symbol)
        XCTAssertEqual(cell.accessibilityHelp(), "Folder containing 23 items")
    }

    func testHiddenCaptionPolicyBeforeInitialBindNamesAppAndFolderImages() async throws {
        let app = makeCell()
        app.showsAppLabels = false
        let binding = token(AnyHashable(makeAppID("fixture.hidden-label.initial")))
        app.bind(name: "Initial application full name", token: binding)
        XCTAssertTrue(app.applyIconIfValid(makeIconImage(), token: binding))
        app.layout()
        assertVisibleNativeImage(app.iconView, in: app)
        XCTAssertTrue(app.nameLabel.isHidden)
        XCTAssertEqual(app.iconView.cell?.accessibilityLabel(), app.boundName)

        let folder = makeCell()
        folder.showsAppLabels = false
        folder.bindFolder(title: "Initial folder full name", memberCount: 1,
                          token: token(AnyHashable(FolderID())))
        await drainText()
        folder.layout()
        let symbol = try folderImage(in: folder)
        assertVisibleNativeImage(symbol, in: folder)
        XCTAssertTrue(folder.nameLabel.isHidden)
        XCTAssertEqual(symbol.cell?.accessibilityLabel(), folder.boundName)
        XCTAssertEqual(symbol.cell?.accessibilityHelp(), "Folder with 1 item")
    }

    func testVisualOnlyOverlayExcludesNamedImagesThroughParentGateAndResumesHiddenPolicy() throws {
        _ = NSApplication.shared
        let pipeline = IconPipeline(loader: UnusedIconLoader(), limits: .init())
        defer { pipeline.shutdown() }
        let overlay = FolderOverlayView(iconPipeline: pipeline)
        defer { overlay.teardown() }
        overlay.frame = NSRect(x: 0, y: 0, width: 800, height: 700)
        overlay.showsAppLabels = false
        let entry = FolderEntry(id: FolderID(), title: "Synthetic group", members: [
            makeAppID("fixture.hidden-label.member")
        ])
        overlay.configure(entry: entry, innerPage: 0, reduceMotion: true) { _ in "Member full name" }
        overlay.layout()
        let cell = try XCTUnwrap(overlay.memberCell(at: 0))
        let binding = try XCTUnwrap(cell.bindingToken)
        let originalWrapperExposure = cell.isAccessibilityElement()
        XCTAssertFalse(originalWrapperExposure, "The member name belongs to its existing native child")
        let icon = makeIconImage()
        XCTAssertTrue(cell.applyIconIfValid(icon, token: binding))
        cell.layout()
        let descendants = descendantIdentities(in: overlay)
        assertVisibleNativeImage(cell.iconView, in: cell)
        XCTAssertEqual(cell.iconView.cell?.accessibilityLabel(), cell.boundName)
        XCTAssertFalse(try XCTUnwrap(overlay.accessibilityChildren()).isEmpty,
                       "The interactive overlay starts with its automatic native children")

        overlay.setVisualOnly(true)
        overlay.showsAppLabels = true
        XCTAssertTrue(overlay.isVisualOnly)
        XCTAssertFalse(overlay.isAccessibilityElement())
        XCTAssertEqual(cell.isAccessibilityElement(), originalWrapperExposure)
        // Read the real parent child list. Ignored cells alone do not exclude native images.
        // Child metadata need not be erased when the retained parent excludes the subtree.
        XCTAssertEqual(overlay.accessibilityChildren()?.count, 0,
                       "A retained drawing-only overlay must explicitly exclude its named descendants")
        XCTAssertTrue(cell.nameLabel.isHidden)
        XCTAssertFalse(overlay.showsAppLabels)
        XCTAssertEqual(cell.bindingToken, binding)
        XCTAssertTrue(cell.iconView.image === icon)
        XCTAssertEqual(descendantIdentities(in: overlay), descendants)

        overlay.setVisualOnly(false)
        overlay.layout()
        XCTAssertTrue(overlay.memberCell(at: 0) === cell)
        cell.layout()
        XCTAssertFalse(overlay.isVisualOnly)
        XCTAssertTrue(overlay.isAccessibilityElement())
        XCTAssertEqual(cell.isAccessibilityElement(), originalWrapperExposure,
                       "Resuming must not create a second named owner around the image cell")
        XCTAssertFalse(try XCTUnwrap(overlay.accessibilityChildren()).isEmpty,
                       "Resume must restore automatic children instead of retaining an empty override")
        XCTAssertTrue(cell.nameLabel.isHidden)
        XCTAssertEqual(cell.iconView.cell?.accessibilityLabel(), cell.boundName)
        XCTAssertEqual(cell.iconView.cell?.isAccessibilityElement(), true)
        XCTAssertEqual(descendantIdentities(in: overlay), descendants)

        // Completed close may clear the retained overlay before it resumes and
        // binds a same-count folder. That reuse must not expose its wrappers.
        overlay.setVisualOnly(true)
        overlay.clearContent()
        overlay.setVisualOnly(false)
        overlay.configure(entry: entry, innerPage: 0, reduceMotion: true) { _ in "Rebound full member name" }
        XCTAssertTrue(overlay.memberCell(at: 0) === cell)
        XCTAssertEqual(cell.isAccessibilityElement(), originalWrapperExposure)
        XCTAssertEqual(cell.iconView.cell?.accessibilityLabel(), "Rebound full member name")
        XCTAssertTrue(cell.nameLabel.isHidden)
        for visible in [true, false] {
            overlay.showsAppLabels = visible
            XCTAssertEqual(cell.isAccessibilityElement(), originalWrapperExposure)
            XCTAssertEqual(cell.iconView.cell?.accessibilityLabel(), visible ? "" : "Rebound full member name")
            XCTAssertEqual(cell.nameLabel.isHidden, !visible)
        }
        XCTAssertEqual(descendantIdentities(in: overlay), descendants)
    }

    func testDrawingOnlyMoveOutProxyHostExcludesChildrenThroughCreationReattachmentAndLabelToggles() throws {
        _ = NSApplication.shared
        let pipeline = IconPipeline(loader: UnusedIconLoader(), limits: .init())
        defer { pipeline.shutdown() }
        let host = NSView(frame: NSRect(x: 0, y: 0, width: 800, height: 700))
        let overlay = FolderOverlayView(iconPipeline: pipeline)
        defer { overlay.teardown() }
        host.addSubview(overlay)
        overlay.frame = host.bounds
        // Use the existing pointer seam without starting a drag, timer or shown window.
        let coordinator = DragUISessionCoordinator(reduceMotionProvider: { true })
        defer { coordinator.teardown() }
        overlay.dragCoordinator = coordinator
        overlay.showsAppLabels = false
        let ids = [makeAppID("fixture.hidden-label.dragged"), makeAppID("fixture.hidden-label.remaining")]
        overlay.configure(entry: FolderEntry(id: FolderID(), title: "Synthetic group", members: ids),
                          innerPage: 0, reduceMotion: true) { $0 == ids[0] ? "Dragged" : "Remaining full name" }
        overlay.layout()
        let source = try XCTUnwrap(overlay.memberCell(at: 0))
        let remaining = try XCTUnwrap(overlay.memberCell(at: 1))
        let icon = makeIconImage()
        XCTAssertTrue(remaining.applyIconIfValid(icon, token: try XCTUnwrap(remaining.bindingToken)))
        let point = source.convert(NSPoint(x: source.bounds.midX, y: source.bounds.midY), to: nil)
        let down = try XCTUnwrap(NSEvent.mouseEvent(with: .leftMouseDown, location: point,
                                                  modifierFlags: [], timestamp: 0, windowNumber: 0,
                                                  context: nil, eventNumber: 0, clickCount: 1, pressure: 1))
        overlay.mouseDown(with: down)
        XCTAssertEqual(overlay.moveOutRemainingAppID, ids[1])
        overlay.prepareMoveOutIconCache()
        overlay.setMoveOutPresentationCollapsed(true)
        let proxyFrame = NSRect(x: 20, y: 30, width: 100, height: 88)
        overlay.showMoveOutRemainingAppProxy(in: host, frame: proxyFrame)
        let proxy = try XCTUnwrap(overlay.moveOutRemainingAppProxy)
        let proxyHost = try XCTUnwrap(overlay.moveOutRemainingAppProxyHost)
        let descendants = descendantIdentities(in: proxyHost)
        let binding = proxy.bindingToken
        let proxyImage = proxy.iconView.image
        XCTAssertNotNil(proxyImage)
        XCTAssertEqual(proxy.iconView.cell?.accessibilityLabel(), "Remaining full name")
        XCTAssertEqual(proxyHost.accessibilityChildren()?.count, 0,
                       "The drawing-only host must exclude even a named native image child")

        for showsLabels in [true, false] {
            overlay.showsAppLabels = showsLabels
            proxy.layout()
            XCTAssertEqual(proxy.nameLabel.isHidden, !showsLabels)
            XCTAssertEqual(proxyHost.accessibilityChildren()?.count, 0)
            if showsLabels {
                assertNoImageMetadata(proxy.iconView)
            } else {
                XCTAssertEqual(proxy.iconView.cell?.accessibilityLabel(), "Remaining full name")
            }
        }

        // The existing commit seam detaches and remounts the same host and proxy.
        overlay.clearMoveOutRemainingAppProxy()
        proxyHost.addSubview(proxy)
        host.addSubview(proxyHost)
        proxy.showsAppLabels = true
        XCTAssertEqual(proxyHost.accessibilityChildren()?.count, 0)
        overlay.reattachMoveOutRemainingAppProxyHost(proxyHost, frame: proxyFrame)
        XCTAssertTrue(overlay.moveOutRemainingAppProxyHost === proxyHost)
        XCTAssertTrue(overlay.moveOutRemainingAppProxy === proxy)
        XCTAssertTrue(proxy.nameLabel.isHidden)
        XCTAssertEqual(proxy.iconView.cell?.accessibilityLabel(), "Remaining full name")
        XCTAssertEqual(proxyHost.accessibilityChildren()?.count, 0)
        for showsLabels in [true, false] {
            overlay.showsAppLabels = showsLabels
            XCTAssertEqual(proxy.nameLabel.isHidden, !showsLabels)
            XCTAssertEqual(proxyHost.accessibilityChildren()?.count, 0)
        }
        XCTAssertEqual(proxy.bindingToken, binding)
        XCTAssertTrue(proxy.iconView.image === proxyImage)
        XCTAssertEqual(descendantIdentities(in: proxyHost), descendants)
    }
}
