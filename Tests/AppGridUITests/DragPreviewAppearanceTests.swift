import AppIconPipeline
import AppKit
import PagingUI
import XCTest
@testable import AppGridUI

/// Native subview assertions with synthetic in-memory icons and no preferences.
@MainActor
final class DragPreviewAppearanceTests: XCTestCase {
    private let point = NSPoint(x: 100, y: 200)
    private let custom = GridItemAppearance(preferredIconSide: 64, appLabelFontSize: 16)

    private func makeHost() -> NSView {
        NSView(frame: NSRect(x: 0, y: 0, width: 500, height: 400))
    }

    private func makeCell(name: String = "Synthetic Preview",
                          appearance: GridItemAppearance = .default,
                          showsLabels: Bool = true) -> AppGridCellView {
        let cell = AppGridCellView(frame: NSRect(x: 0, y: 0, width: 96, height: 88))
        cell.itemAppearance = appearance
        cell.showsAppLabels = showsLabels
        cell.bind(name: name, token: ItemBindingToken(
            catalogRevision: 1,
            pageIdentity: PagePresentationID(revision: 1, pageIndex: 0),
            itemSlot: 0, appID: AnyHashable(makeAppID("fixture.preview.appearance")),
            reuseGeneration: 1, iconKey: nil, surfaceGeneration: 1))
        cell.iconView.image = makeIconImage()
        cell.layout()
        return cell
    }

    private func nativePreview(in host: NSView) throws
        -> (view: NSView, icon: NSImageView, name: NSTextField) {
        let view = try XCTUnwrap(host.subviews.first {
            $0.subviews.contains { $0 is NSImageView }
                && $0.subviews.contains { $0 is NSTextField }
        })
        let icon = try XCTUnwrap(view.subviews.compactMap { $0 as? NSImageView }.first)
        let name = try XCTUnwrap(view.subviews.compactMap { $0 as? NSTextField }.first)
        return (view, icon, name)
    }

    private func assertAppearance(_ preview: (view: NSView, icon: NSImageView, name: NSTextField),
                                  appearance: GridItemAppearance, showsLabels: Bool,
                                  name: String, file: StaticString = #filePath, line: UInt = #line) {
        let geometry = GridItemContentGeometry(
            bounds: NSRect(x: 0, y: 0, width: 96, height: 88),
            appearance: appearance, showsLabels: showsLabels, isFolderCell: false)
        XCTAssertEqual(preview.view.frame.size, NSSize(width: 96, height: 88), file: file, line: line)
        XCTAssertEqual(preview.icon.frame, geometry.iconFrame, file: file, line: line)
        XCTAssertEqual(preview.name.frame, geometry.nameFrame, file: file, line: line)
        XCTAssertEqual(preview.name.font?.pointSize, CGFloat(appearance.appLabelFontSize), file: file, line: line)
        XCTAssertEqual(preview.name.font?.fontName,
                       NSFont.systemFont(ofSize: CGFloat(appearance.appLabelFontSize)).fontName,
                       file: file, line: line)
        XCTAssertEqual(preview.name.isHidden, !showsLabels, file: file, line: line)
        XCTAssertEqual(preview.name.stringValue, name, file: file, line: line)
        XCTAssertEqual(preview.name.maximumNumberOfLines, 1, file: file, line: line)
        XCTAssertEqual(preview.name.lineBreakMode, .byTruncatingTail, file: file, line: line)
    }

    func testFirstDefaultShowHasExactNativeGeometryFontAndPlacement() throws {
        let host = makeHost()
        let visuals = DragUIVisuals(host: host, reduceMotionProvider: { false })
        defer { visuals.teardown() }
        let cell = makeCell()
        let sourceImage = try XCTUnwrap(cell.iconView.image)
        let binding = cell.bindingToken
        visuals.showPreview(sourceCell: cell, at: point)
        let preview = try nativePreview(in: host)
        assertAppearance(preview, appearance: .default, showsLabels: true, name: cell.boundName)
        XCTAssertEqual(preview.icon.frame, NSRect(x: 24, y: 28, width: 48, height: 48))
        XCTAssertEqual(preview.name.frame, NSRect(x: 2, y: 0, width: 92, height: 14))
        XCTAssertEqual(preview.icon.frame, cell.iconView.frame)
        XCTAssertEqual(preview.name.frame, cell.nameLabel.frame)
        XCTAssertEqual(visuals.previewFrame, NSRect(x: 52, y: 224, width: 96, height: 88))
        XCTAssertFalse(preview.view.isHidden)
        XCTAssertEqual(preview.view.alphaValue, 1)
        XCTAssertNotNil(preview.icon.image)
        XCTAssertFalse(preview.icon.image === sourceImage)
        XCTAssertTrue(preview.icon.image === visuals.previewIconImage)
        XCTAssertEqual(preview.name.stringValue, visuals.previewNameText)
        XCTAssertTrue(cell.iconView.image === sourceImage)
        XCTAssertEqual(cell.bindingToken, binding)
        XCTAssertEqual(cell.accessibilityLabel(), cell.boundName)
        XCTAssertEqual(host.subviews.count, 1)
    }

    func testPreviewHasNoDecorativeBackingAcrossContextsHostsAndReuse() throws {
        for context in [GridItemLayoutContext.standard, .mainGrid, .folderGrid] {
            for reduceMotion in [false, true] {
                let host = makeHost()
                let nextHost = makeHost()
                let visuals = DragUIVisuals(host: host, reduceMotionProvider: { reduceMotion })
                defer { visuals.teardown() }
                let source = makeCell()
                source.contentLayoutContext = context
                visuals.showPreview(sourceCell: source, at: point)
                let preview = try nativePreview(in: host)
                let layer = try XCTUnwrap(preview.view.layer)
                func assertTransparentBacking() {
                    XCTAssertFalse(preview.view.isOpaque)
                    XCTAssertEqual(layer.backgroundColor?.alpha ?? 0, 0)
                    XCTAssertEqual(layer.borderWidth, 0)
                    XCTAssertEqual(layer.shadowOpacity, 0)
                    XCTAssertFalse(preview.name.drawsBackground)
                    XCTAssertNotNil(preview.icon.image)
                    XCTAssertEqual(preview.view.alphaValue, 1)
                }
                assertTransparentBacking()
                source.clearContent()
                visuals.setHost(nextHost)
                visuals.reaffirmPreview(at: point)
                visuals.capturePreview(from: nil)
                XCTAssertTrue(preview.view.superview === nextHost)
                assertTransparentBacking()
                visuals.clearAll()
                let next = makeCell(name: "Next Transparent Preview")
                next.contentLayoutContext = context
                visuals.showPreview(sourceCell: next, at: point)
                assertTransparentBacking()
            }
        }
    }

    func testVisibleHiddenAndCustomPreviewsUseSourcePolicyWithoutRemovingAccessibleName() throws {
        let host = makeHost()
        let visuals = DragUIVisuals(host: host, reduceMotionProvider: { true })
        defer { visuals.teardown() }
        for appearance in [.default, GridItemAppearance(preferredIconSide: 32, appLabelFontSize: 9), custom] {
            for showsLabels in [true, false] {
                let cell = makeCell(appearance: appearance, showsLabels: showsLabels)
                visuals.showPreview(sourceCell: cell, at: point)
                let preview = try nativePreview(in: host)
                assertAppearance(preview, appearance: appearance, showsLabels: showsLabels, name: cell.boundName)
                XCTAssertEqual(preview.icon.frame, cell.iconView.frame)
                XCTAssertEqual(preview.name.frame, cell.nameLabel.frame)
                XCTAssertEqual(cell.accessibilityLabel(), "Synthetic Preview")
                XCTAssertEqual(cell.nameLabel.stringValue, "Synthetic Preview")
                XCTAssertEqual(cell.nameLabel.isHidden, !showsLabels)
                XCTAssertEqual(visuals.previewNameText, "Synthetic Preview")
                XCTAssertNotNil(preview.icon.image)
                if showsLabels {
                    XCTAssertGreaterThanOrEqual(preview.icon.frame.minY, preview.name.frame.maxY + 2)
                }
                XCTAssertEqual(host.subviews.count, 1)
            }
        }
    }

    func testMovesKeepCapturedContentUntilExplicitNextCapture() throws {
        let host = makeHost()
        let visuals = DragUIVisuals(host: host, reduceMotionProvider: { false })
        defer { visuals.teardown() }
        let cell = makeCell(appearance: custom, showsLabels: false)
        visuals.showPreview(sourceCell: cell, at: point)
        let preview = try nativePreview(in: host)
        let image = try XCTUnwrap(preview.icon.image)
        let font = try XCTUnwrap(preview.name.font)
        let iconFrame = preview.icon.frame
        let nameFrame = preview.name.frame
        cell.itemAppearance = GridItemAppearance(preferredIconSide: 32, appLabelFontSize: 9)
        cell.showsAppLabels = true
        let token = try XCTUnwrap(cell.bindingToken)
        cell.bind(name: "Next Capture", token: token)
        cell.iconView.image = makeIconImage(r: 200, g: 40, b: 60)
        cell.layout()
        for index in 0..<200 {
            let next = NSPoint(x: CGFloat(index), y: CGFloat(index + 10))
            visuals.movePreview(to: next)
            XCTAssertEqual(preview.view.frame, NSRect(x: next.x - 48, y: next.y + 24, width: 96, height: 88))
            XCTAssertTrue(preview.icon.image === image, "Moves must not resnapshot the source")
            XCTAssertTrue(preview.name.font === font, "Moves must not replace fonts")
            XCTAssertEqual(preview.icon.frame, iconFrame)
            XCTAssertEqual(preview.name.frame, nameFrame)
            XCTAssertTrue(preview.name.isHidden)
            XCTAssertEqual(preview.name.stringValue, "Synthetic Preview")
        }
        visuals.capturePreview(from: cell)
        assertAppearance(preview, appearance: cell.itemAppearance, showsLabels: true, name: "Next Capture")
        XCTAssertNotNil(preview.icon.image)
        XCTAssertFalse(preview.icon.image === image)
        XCTAssertEqual(host.subviews.count, 1)
    }

    func testClearedAndReleasedSourceKeepsDurableContentAcrossNilCaptureHostAndReaffirm() throws {
        let hostA = makeHost()
        let hostB = makeHost()
        let visuals = DragUIVisuals(host: hostA, reduceMotionProvider: { true })
        defer { visuals.teardown() }
        weak var weakSource: AppGridCellView?
        autoreleasepool {
            var source: AppGridCellView? = makeCell(appearance: custom, showsLabels: false)
            weakSource = source
            visuals.showPreview(sourceCell: source, at: point)
            source?.clearContent()
            source?.layoutSubtreeIfNeeded()
            source = nil
        }
        let original = try nativePreview(in: hostA)
        let image = try XCTUnwrap(original.icon.image)
        XCTAssertNil(weakSource, "The preview must not retain its source cell after AppKit autoreleases drain")
        visuals.capturePreview(from: nil)
        assertAppearance(original, appearance: custom, showsLabels: false, name: "Synthetic Preview")
        XCTAssertTrue(original.icon.image === image)
        visuals.setHost(nil)
        visuals.capturePreview(from: nil)
        visuals.setHost(hostB)
        visuals.setHost(hostB)
        for _ in 0..<3 {
            visuals.reaffirmPreview(at: point)
            visuals.capturePreview(from: nil)
        }
        let preview = try nativePreview(in: hostB)
        XCTAssertTrue(preview.view === original.view)
        XCTAssertTrue(preview.icon.image === image)
        assertAppearance(preview, appearance: custom, showsLabels: false, name: "Synthetic Preview")
        XCTAssertTrue(hostA.subviews.isEmpty)
        XCTAssertEqual(hostB.subviews.count, 1)
        XCTAssertFalse(preview.view.isHidden)
        XCTAssertEqual(preview.view.alphaValue, 1)
    }

    func testElevationKeepsDurableStyleAndImageAcrossHostChangesAndNilCapture() throws {
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 500, height: 400),
                              styleMask: [.borderless], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        let content = makeHost()
        let overlay = makeHost()
        window.contentView = content
        content.addSubview(overlay)
        let nextHost = makeHost()
        let visuals = DragUIVisuals(host: overlay, reduceMotionProvider: { true })
        defer { visuals.teardown(); window.close() }
        let source = makeCell(appearance: custom, showsLabels: false)
        visuals.showPreview(sourceCell: source, at: point)
        let image = try XCTUnwrap(visuals.previewIconImage)
        source.clearContent()
        visuals.elevatePreviewAbove(overlay, at: point)
        visuals.setHost(nextHost)
        visuals.capturePreview(from: nil)
        visuals.movePreview(to: point)
        let preview = try nativePreview(in: content)
        XCTAssertTrue(preview.view.superview === content)
        XCTAssertTrue(content.subviews.last === preview.view)
        XCTAssertTrue(nextHost.subviews.isEmpty)
        XCTAssertTrue(preview.icon.image === image)
        assertAppearance(preview, appearance: custom, showsLabels: false, name: "Synthetic Preview")
        XCTAssertEqual(preview.view.alphaValue, 1)
        visuals.clearAll()
        XCTAssertNil(preview.view.superview)
        XCTAssertNil(preview.icon.image)
        XCTAssertEqual(preview.name.stringValue, "")
        let next = makeCell(name: "After Elevation")
        visuals.showPreview(sourceCell: next, at: point)
        let nextPreview = try nativePreview(in: nextHost)
        assertAppearance(nextPreview, appearance: .default, showsLabels: true, name: "After Elevation")
        visuals.setHost(overlay)
        XCTAssertTrue(nextPreview.view.superview === overlay, "Reset must clear elevation ownership")
    }

    func testWindowlessElevationFallbackAndReduceMotionPreserveNativeAppearance() throws {
        for reduceMotion in [false, true] {
            let host = makeHost()
            let visuals = DragUIVisuals(host: host, reduceMotionProvider: { reduceMotion })
            let cell = makeCell(appearance: custom, showsLabels: true)
            visuals.showPreview(sourceCell: cell, at: point)
            let preview = try nativePreview(in: host)
            let image = try XCTUnwrap(preview.icon.image)
            cell.clearContent()
            visuals.elevatePreviewAbove(NSView(), at: point)
            visuals.capturePreview(from: nil)
            assertAppearance(preview, appearance: custom, showsLabels: true, name: "Synthetic Preview")
            XCTAssertTrue(preview.icon.image === image)
            XCTAssertEqual(preview.view.alphaValue, 1)
            XCTAssertTrue(preview.view.layer?.animationKeys()?.isEmpty ?? true)
            XCTAssertEqual(visuals.reduceMotion, reduceMotion)
            visuals.teardown()
        }
    }

    func testClearAllAndTeardownClearNativeContentAndRestoreNextSourceOrDefaults() throws {
        let host = makeHost()
        let visuals = DragUIVisuals(host: host, reduceMotionProvider: { true })
        defer { visuals.teardown() }
        let customSource = makeCell(appearance: custom, showsLabels: false)
        visuals.showPreview(sourceCell: customSource, at: point)
        let preview = try nativePreview(in: host)
        for _ in 0..<2 { visuals.clearAll() }
        XCTAssertTrue(preview.view.isHidden)
        XCTAssertNil(preview.icon.image)
        XCTAssertNil(visuals.previewIconImage)
        XCTAssertEqual(visuals.previewNameText, "")
        assertAppearance(preview, appearance: .default, showsLabels: true, name: "")
        visuals.capturePreview(from: nil)
        visuals.reaffirmPreview(at: point)
        XCTAssertNil(preview.icon.image)
        assertAppearance(preview, appearance: .default, showsLabels: true, name: "")
        visuals.showPreview(sourceCell: customSource, at: point)
        assertAppearance(preview, appearance: custom, showsLabels: false, name: "Synthetic Preview")
        for _ in 0..<2 { visuals.teardown() }
        XCTAssertTrue(host.subviews.isEmpty)
        XCTAssertTrue(visuals.visualViewSuperviews.allSatisfy { $0 == nil })
        XCTAssertTrue(preview.view.isHidden)
        XCTAssertNil(preview.icon.image)
        assertAppearance(preview, appearance: .default, showsLabels: true, name: "")
        visuals.setHost(host)
        XCTAssertTrue(host.subviews.isEmpty, "setHost must not reattach torn-down visuals")
        visuals.showPreview(sourceCell: makeCell(name: "Default Again"), at: point)
        let next = try nativePreview(in: host)
        XCTAssertTrue(next.view === preview.view)
        assertAppearance(next, appearance: .default, showsLabels: true, name: "Default Again")
    }

    func testNewNilShowClearsPreviousSessionWhileNilCaptureContinuesIt() throws {
        let host = makeHost()
        let visuals = DragUIVisuals(host: host, reduceMotionProvider: { true })
        defer { visuals.teardown() }
        visuals.showPreview(sourceCell: makeCell(appearance: custom, showsLabels: false), at: point)
        let preview = try nativePreview(in: host)
        let image = try XCTUnwrap(preview.icon.image)
        visuals.capturePreview(from: nil)
        XCTAssertTrue(preview.icon.image === image)
        assertAppearance(preview, appearance: custom, showsLabels: false, name: "Synthetic Preview")
        for _ in 0..<2 {
            visuals.showPreview(sourceCell: nil, at: point)
            visuals.capturePreview(from: nil)
            visuals.reaffirmPreview(at: point)
            XCTAssertNil(preview.icon.image)
            assertAppearance(preview, appearance: .default, showsLabels: true, name: "")
        }
        visuals.showPreview(sourceCell: makeCell(name: "Fresh", appearance: custom), at: point)
        assertAppearance(preview, appearance: custom, showsLabels: true, name: "Fresh")
        XCTAssertNotNil(preview.icon.image)
        visuals.setHost(nil)
        visuals.showPreview(sourceCell: nil, at: point)
        visuals.setHost(host)
        visuals.reaffirmPreview(at: point)
        XCTAssertNil(preview.icon.image)
        assertAppearance(preview, appearance: .default, showsLabels: true, name: "")
        XCTAssertEqual(host.subviews.count, 1)
    }

    func testNewSourceWithoutSnapshotOrImageCannotReusePreviousIcon() throws {
        let host = makeHost()
        let visuals = DragUIVisuals(host: host, reduceMotionProvider: { false })
        defer { visuals.teardown() }
        visuals.showPreview(sourceCell: makeCell(appearance: custom, showsLabels: false), at: point)
        let source = makeCell(name: "No Icon")
        source.iconView.image = nil
        source.frame = .zero
        source.iconView.frame = .zero
        visuals.showPreview(sourceCell: source, at: point)
        let preview = try nativePreview(in: host)
        XCTAssertNil(preview.icon.image)
        assertAppearance(preview, appearance: .default, showsLabels: true, name: "No Icon")
    }

    func testFlippedHostPreservesPointerPlacementAndCustomNativeFrames() throws {
        let host = DragPreviewFlippedHost(frame: NSRect(x: 0, y: 0, width: 500, height: 400))
        let visuals = DragUIVisuals(host: host, reduceMotionProvider: { true })
        defer { visuals.teardown() }
        visuals.showPreview(sourceCell: makeCell(appearance: custom), at: point)
        let preview = try nativePreview(in: host)
        assertAppearance(preview, appearance: custom, showsLabels: true, name: "Synthetic Preview")
        XCTAssertEqual(preview.view.frame, NSRect(x: 52, y: 100, width: 96, height: 88))
        visuals.movePreview(to: NSPoint(x: 120, y: 250))
        XCTAssertEqual(preview.view.frame, NSRect(x: 72, y: 150, width: 96, height: 88))
        assertAppearance(preview, appearance: custom, showsLabels: true, name: "Synthetic Preview")
    }
}

@MainActor
private final class DragPreviewFlippedHost: NSView {
    override var isFlipped: Bool { true }
}
