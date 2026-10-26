import AppCatalogCore
import AppIconPipeline
import AppKit
import AppGridUI
import XCTest

/// Synthetic host-only coverage; no system preference changes, scans or real icons.
@MainActor
final class FolderMaterialPolicyTests: XCTestCase {
    private final class RecordingIconLoader: IconLoading, @unchecked Sendable {
        enum Failure: Error { case synthetic }
        private let lock = NSLock()
        private var recordedKeys: [IconKey] = []
        private let onLoad: (@Sendable () -> Void)?

        init(onLoad: (@Sendable () -> Void)? = nil) {
            self.onLoad = onLoad
        }

        var keys: [IconKey] {
            lock.lock()
            defer { lock.unlock() }
            return recordedKeys
        }

        private func record(_ key: IconKey) {
            lock.lock()
            recordedKeys.append(key)
            lock.unlock()
        }

        func load(key: IconKey) async throws -> NSImage {
            record(key)
            onLoad?()
            throw Failure.synthetic
        }
    }

    private final class RemovalProbe: NSView {
        var onRemoval: (() -> Void)?
        override func viewWillMove(toSuperview newSuperview: NSView?) {
            if superview != nil && newSuperview == nil { onRemoval?() }
            super.viewWillMove(toSuperview: newSuperview)
        }
    }

    private let policies: [(opaque: Bool, contrast: Bool)] = [
        (false, false), (true, false), (false, true), (true, true)
    ]

    private func configure(_ overlay: FolderOverlayView, reduceMotion: Bool = false) {
        let entry = overlay.currentEntry ?? FolderEntry(
            id: FolderID(), title: "Tools",
            members: (0..<3).map { makeAppID("fixture.material.member\($0)") })
        overlay.membersPerPage = 2
        overlay.configure(entry: entry, innerPage: 0, reduceMotion: reduceMotion,
                          catalogRevision: 7) { _ in "Synthetic member" }
        overlay.layout()
    }

    private func makeOverlay(_ pipeline: IconPipeline) -> FolderOverlayView {
        let overlay = FolderOverlayView(iconPipeline: pipeline, iconPointSize: 32, displayScale: 1)
        overlay.frame = NSRect(x: 0, y: 0, width: 800, height: 600)
        configure(overlay)
        return overlay
    }

    private func footer(_ overlay: FolderOverlayView) throws -> NSTextField {
        try XCTUnwrap(overlay.titleEditorHostView.subviews.compactMap { $0 as? NSTextField }
            .first { $0.frame != overlay.titleEditorFrame })
    }

    private func assertMaterial(_ overlay: FolderOverlayView, opaque: Bool, contrast: Bool,
                                collapsed: Bool = false,
                                file: StaticString = #filePath, line: UInt = #line) throws {
        let backdrop = try XCTUnwrap(overlay.layer?.backgroundColor, file: file, line: line)
        let panel = try XCTUnwrap(overlay.titleEditorHostView.layer, file: file, line: line)
        let fill = try XCTUnwrap(panel.backgroundColor, file: file, line: line)
        XCTAssertEqual(backdrop, NSColor.clear.cgColor, file: file, line: line)
        XCTAssertEqual(overlay.isMoveOutPresentationCollapsed, collapsed, file: file, line: line)
        let needsOpaquePanel = opaque || contrast
        XCTAssertEqual(fill, needsOpaquePanel ? NSColor.windowBackgroundColor.withAlphaComponent(1).cgColor
            : NSColor.clear.cgColor, file: file, line: line)
        let effect = try materialView(overlay)
        XCTAssertEqual(effect.isHidden, needsOpaquePanel || overlay.isTornDown, file: file, line: line)
        let shouldRender = overlay.window != nil && !needsOpaquePanel && !collapsed && !overlay.isTornDown
        XCTAssertEqual(effect.state, shouldRender ? .active : .inactive, file: file, line: line)
        if needsOpaquePanel { XCTAssertEqual(fill.alpha, 1, file: file, line: line) }
        XCTAssertEqual(panel.borderColor, contrast ? NSColor.labelColor.cgColor
            : NSColor.separatorColor.cgColor, file: file, line: line)
        XCTAssertEqual(panel.borderWidth, contrast ? 2 : 1, file: file, line: line)
        XCTAssertEqual(try footer(overlay).textColor, contrast ? NSColor.labelColor
            : NSColor.secondaryLabelColor, file: file, line: line)
    }

    private func materialView(_ overlay: FolderOverlayView) throws -> NSVisualEffectView {
        let effects = overlay.titleEditorHostView.subviews.compactMap { $0 as? NSVisualEffectView }
        XCTAssertEqual(effects.count, 1, "One retained material, not stacked blur surfaces")
        return try XCTUnwrap(effects.first)
    }

    func testGlassMaterialIsClippedBehindStablePanelContentAndPassesInput() throws {
        let pipeline = IconPipeline(loader: RecordingIconLoader(), limits: .init())
        defer { pipeline.shutdown() }
        let overlay = makeOverlay(pipeline)
        defer { overlay.teardown() }
        let panel = overlay.titleEditorHostView
        let effect = try materialView(overlay)
        XCTAssertTrue(panel.subviews.first === effect)
        XCTAssertEqual(effect.frame, panel.bounds)
        XCTAssertEqual(effect.blendingMode, .withinWindow)
        XCTAssertEqual(effect.material, .popover)
        XCTAssertEqual(effect.state, .inactive, "Host-only retained material has no active window")
        XCTAssertEqual(effect.layer?.cornerRadius, panel.layer?.cornerRadius)
        XCTAssertEqual(effect.layer?.masksToBounds, true)
        XCTAssertNil(effect.hitTest(NSPoint(x: 10, y: 10)))
        XCTAssertFalse(effect.isAccessibilityElement())
        XCTAssertEqual(effect.accessibilityChildren()?.count ?? 0, 0)
        XCTAssertEqual(panel.layer?.backgroundColor, NSColor.clear.cgColor)
        XCTAssertFalse(effect.isHidden)
        for size in [NSSize(width: 500, height: 340), NSSize(width: 1200, height: 850)] {
            overlay.frame.size = size
            overlay.layout()
            XCTAssertTrue(overlay.titleEditorHostView === panel)
            XCTAssertTrue(try materialView(overlay) === effect)
            XCTAssertEqual(effect.frame, panel.bounds)
        }
    }

    func testGlassFallbackAndEditorIdentitySurviveRepeatedMaterialChanges() throws {
        let pipeline = IconPipeline(loader: RecordingIconLoader(), limits: .init())
        defer { pipeline.shutdown() }
        let overlay = makeOverlay(pipeline)
        defer { overlay.teardown() }
        let effect = try materialView(overlay)
        let panel = overlay.titleEditorHostView
        let editor = NSTextField(string: "Uncommitted title")
        XCTAssertTrue(overlay.mountTitleEditor(editor))
        let generation = overlay.surfaceGeneration
        let requests = pipeline.stats.requests
        for policy in policies + policies.reversed() {
            overlay.applyMaterialPolicy(reduceTransparency: policy.opaque, increaseContrast: policy.contrast)
            XCTAssertTrue(try materialView(overlay) === effect)
            XCTAssertEqual(effect.isHidden, policy.opaque || policy.contrast)
            XCTAssertEqual(panel.layer?.backgroundColor?.alpha, policy.opaque || policy.contrast ? 1 : 0)
            XCTAssertTrue(editor.superview === panel)
            XCTAssertEqual(editor.stringValue, "Uncommitted title")
            XCTAssertEqual(overlay.surfaceGeneration, generation)
            XCTAssertEqual(pipeline.stats.requests, requests)
        }
    }

    func testRetainedMaterialParksOnDetachAndRestoresOnlyForLiveTransparentHost() throws {
        let pipeline = IconPipeline(loader: RecordingIconLoader(), limits: .init())
        defer { pipeline.shutdown() }
        let overlay = makeOverlay(pipeline)
        defer { overlay.teardown() }
        let effect = try materialView(overlay)
        XCTAssertEqual(effect.state, .inactive, "A detached retained material is parked")
        let window = NSWindow(contentRect: overlay.bounds, styleMask: [.borderless], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        defer { window.contentView = nil; window.close() }
        let host = NSView(frame: overlay.bounds)
        window.contentView = host
        for policy in policies {
            overlay.applyMaterialPolicy(reduceTransparency: policy.opaque, increaseContrast: policy.contrast)
            host.addSubview(overlay)
            XCTAssertTrue(overlay.window === window)
            XCTAssertEqual(effect.state, policy.opaque || policy.contrast ? .inactive : .active)
            overlay.setVisualOnly(true)
            XCTAssertEqual(effect.state, policy.opaque || policy.contrast ? .inactive : .active,
                           "Mounted drawing-only exit retains its appearance")
            overlay.removeFromSuperview()
            XCTAssertEqual(effect.state, .inactive)
            overlay.clearContent()
            overlay.setVisualOnly(false)
            configure(overlay)
            XCTAssertTrue(try materialView(overlay) === effect)
            host.addSubview(overlay)
            XCTAssertEqual(effect.state, policy.opaque || policy.contrast ? .inactive : .active)
            overlay.setMoveOutPresentationCollapsed(true)
            XCTAssertEqual(effect.state, .inactive)
            overlay.setMoveOutPresentationCollapsed(false)
            XCTAssertEqual(effect.state, policy.opaque || policy.contrast ? .inactive : .active)
            overlay.removeFromSuperview()
        }
        overlay.applyMaterialPolicy(reduceTransparency: false, increaseContrast: false)
        overlay.teardown()
        host.addSubview(overlay)
        XCTAssertEqual(effect.state, .inactive, "Reattaching cannot revive terminal rendering")
        XCTAssertTrue(effect.isHidden)
        overlay.removeFromSuperview()
    }

    func testDefaultAndAllPolicyCombinationsPreserveNormalAppearance() throws {
        let pipeline = IconPipeline(loader: RecordingIconLoader(), limits: .init())
        defer { pipeline.shutdown() }
        for appearanceName in [NSAppearance.Name.aqua, .darkAqua] {
            let appearance = try XCTUnwrap(NSAppearance(named: appearanceName))
            var failure: Error?
            appearance.performAsCurrentDrawingAppearance {
                do {
                    let overlay = makeOverlay(pipeline)
                    defer { overlay.teardown() }
                    try assertMaterial(overlay, opaque: false, contrast: false)
                    for reduceMotion in [false, true] {
                        configure(overlay, reduceMotion: reduceMotion)
                        for policy in policies + [(opaque: false, contrast: false)] {
                            overlay.applyMaterialPolicy(reduceTransparency: policy.opaque,
                                                        increaseContrast: policy.contrast)
                            try assertMaterial(overlay, opaque: policy.opaque, contrast: policy.contrast)
                            XCTAssertEqual(overlay.reduceMotion, reduceMotion)
                        }
                    }
                } catch {
                    failure = error
                }
            }
            if let failure { throw failure }
        }
    }

    func testPolicyAppliedBeforeConfigureSurvivesOpening() throws {
        let pipeline = IconPipeline(loader: RecordingIconLoader(), limits: .init())
        defer { pipeline.shutdown() }
        for policy in policies {
            let overlay = FolderOverlayView(iconPipeline: pipeline)
            defer { overlay.teardown() }
            overlay.frame = NSRect(x: 0, y: 0, width: 800, height: 600)
            overlay.applyMaterialPolicy(reduceTransparency: policy.opaque,
                                        increaseContrast: policy.contrast)
            configure(overlay)
            try assertMaterial(overlay, opaque: policy.opaque, contrast: policy.contrast)
        }
    }

    func testRepeatedPolicyTogglesPreserveCellsBindingsIconsAndGeometry() async throws {
        let loaded = expectation(description: "Both synthetic loads recorded")
        loaded.expectedFulfillmentCount = 2
        let loader = RecordingIconLoader(onLoad: { loaded.fulfill() })
        let pipeline = IconPipeline(loader: loader, limits: .init())
        defer { pipeline.shutdown() }
        let overlay = makeOverlay(pipeline)
        defer { overlay.teardown() }
        await fulfillment(of: [loaded], timeout: 3)
        let cells = try (0..<overlay.memberCellCount).map { try XCTUnwrap(overlay.memberCell(at: $0)) }
        let tokens = try cells.map { try XCTUnwrap($0.bindingToken) }
        let image = makeIconImage()
        for (cell, token) in zip(cells, tokens) { XCTAssertTrue(cell.applyIconIfValid(image, token: token)) }
        let frames = cells.map(\.frame)
        let iconFrames = cells.map { $0.iconView.frame }
        let names = cells.map(\.boundName)
        let labelsVisible = cells.map(\.showsAppLabels)
        let fields = overlay.titleEditorHostView.subviews.compactMap { $0 as? NSTextField }
        let text = fields.map(\.stringValue)
        let fonts = fields.map(\.font)
        let textFrames = fields.map(\.frame)
        let entry = overlay.currentEntry
        let generation = overlay.surfaceGeneration
        let panelFrame = overlay.panelFrame
        let requests = pipeline.stats.requests
        let keys = loader.keys
        XCTAssertEqual(requests, 2)
        XCTAssertEqual(keys.count, 2)

        for _ in 0..<3 {
            for policy in policies + Array(policies.reversed()) {
                overlay.applyMaterialPolicy(reduceTransparency: policy.opaque,
                                            increaseContrast: policy.contrast)
                try assertMaterial(overlay, opaque: policy.opaque, contrast: policy.contrast)
                XCTAssertEqual(overlay.currentEntry, entry)
                XCTAssertEqual(overlay.currentInnerPage, 0)
                XCTAssertEqual(overlay.surfaceGeneration, generation)
                XCTAssertEqual(overlay.memberCellCount, cells.count)
                XCTAssertEqual(overlay.panelFrame, panelFrame)
                for (index, cell) in cells.enumerated() {
                    XCTAssertTrue(overlay.memberCell(at: index) === cell)
                    XCTAssertEqual(cell.bindingToken, tokens[index])
                    XCTAssertTrue(cell.iconView.image === image)
                    XCTAssertEqual(cell.frame, frames[index])
                    XCTAssertEqual(cell.iconView.frame, iconFrames[index])
                    XCTAssertEqual(cell.boundName, names[index])
                    XCTAssertEqual(cell.showsAppLabels, labelsVisible[index])
                }
                XCTAssertEqual(fields.map(\.stringValue), text)
                XCTAssertEqual(fields.map(\.font), fonts)
                XCTAssertEqual(fields.map(\.frame), textFrames)
                XCTAssertEqual(pipeline.stats.requests, requests)
                XCTAssertEqual(loader.keys, keys)
            }
        }
    }

    func testMaterialUpdatesPreserveTitleEditorAndCallbackLifetimes() throws {
        let pipeline = IconPipeline(loader: RecordingIconLoader(), limits: .init())
        defer { pipeline.shutdown() }
        let overlay = makeOverlay(pipeline)
        defer { overlay.teardown() }
        let editor = RemovalProbe()
        var editRequests = 0
        var invalidations = 0
        var removals = 0
        overlay.onRequestTitleEdit = { editRequests += 1 }
        overlay.onWillInvalidateTitleEditor = {
            invalidations += 1
            XCTAssertTrue(editor.superview === overlay.titleEditorHostView)
        }
        editor.onRemoval = { removals += 1 }
        overlay.titleEditButton.performClick(nil)
        XCTAssertEqual(editRequests, 1)
        XCTAssertTrue(overlay.mountTitleEditor(editor))
        let editorFrame = editor.frame
        let generation = overlay.surfaceGeneration
        let requests = pipeline.stats.requests
        for policy in policies + policies {
            overlay.applyMaterialPolicy(reduceTransparency: policy.opaque,
                                        increaseContrast: policy.contrast)
            XCTAssertTrue(overlay.titleEditorView === editor)
            XCTAssertTrue(editor.superview === overlay.titleEditorHostView)
            XCTAssertEqual(editor.frame, editorFrame)
            XCTAssertTrue(overlay.titleEditButton.isHidden)
            XCTAssertEqual(editRequests, 1)
            XCTAssertEqual(invalidations, 0)
            XCTAssertEqual(removals, 0)
            XCTAssertEqual(overlay.surfaceGeneration, generation)
            XCTAssertEqual(pipeline.stats.requests, requests)
        }
        overlay.unmountTitleEditor()
        XCTAssertEqual(removals, 1)
        XCTAssertEqual(invalidations, 0)
        overlay.titleEditButton.performClick(nil)
        XCTAssertEqual(editRequests, 2, "The original request callback remains connected")
        XCTAssertTrue(overlay.mountTitleEditor(editor))
        overlay.clearContent()
        XCTAssertEqual(invalidations, 1, "The original cancellation callback survives material updates")
        XCTAssertEqual(removals, 2)
        XCTAssertNil(overlay.titleEditorView)
    }

    func testCollapsedBackdropStaysClearAndEveryRestoreUsesCurrentPolicy() throws {
        let pipeline = IconPipeline(loader: RecordingIconLoader(), limits: .init())
        defer { pipeline.shutdown() }
        for policy in policies {
            for restore in 0..<4 {
                let overlay = makeOverlay(pipeline)
                defer { overlay.teardown() }
                overlay.applyMaterialPolicy(reduceTransparency: !policy.opaque,
                                            increaseContrast: !policy.contrast)
                overlay.setMoveOutPresentationCollapsed(true)
                XCTAssertTrue(overlay.titleEditorHostView.isHidden)
                let generation = overlay.surfaceGeneration
                let token = overlay.memberCell(at: 0)?.bindingToken
                let requests = pipeline.stats.requests
                for _ in 0..<2 {
                    overlay.applyMaterialPolicy(reduceTransparency: policy.opaque,
                                                increaseContrast: policy.contrast)
                    try assertMaterial(overlay, opaque: policy.opaque, contrast: policy.contrast,
                                       collapsed: true)
                    XCTAssertTrue(overlay.isMoveOutPresentationCollapsed)
                    XCTAssertTrue(overlay.titleEditorHostView.isHidden)
                    XCTAssertEqual(overlay.surfaceGeneration, generation)
                    XCTAssertEqual(overlay.memberCell(at: 0)?.bindingToken, token)
                    XCTAssertEqual(pipeline.stats.requests, requests)
                }
                // Exercise the private restore through its existing public lifecycle callers.
                switch restore {
                case 0: overlay.setMoveOutPresentationCollapsed(false)
                case 1: configure(overlay)
                case 2: overlay.clearContent()
                default: overlay.teardown()
                }
                XCTAssertFalse(overlay.isMoveOutPresentationCollapsed)
                XCTAssertFalse(overlay.titleEditorHostView.isHidden)
                try assertMaterial(overlay, opaque: policy.opaque, contrast: policy.contrast)
                XCTAssertEqual(pipeline.stats.requests, requests)
            }
        }
    }

    func testVisualOnlyUpdatesAreIgnoredIncludingStoredPolicyOnCleanupAndResume() throws {
        let pipeline = IconPipeline(loader: RecordingIconLoader(), limits: .init())
        defer { pipeline.shutdown() }
        for original in policies {
            for collapsed in [false, true] {
                let overlay = makeOverlay(pipeline)
                defer { overlay.teardown() }
                overlay.applyMaterialPolicy(reduceTransparency: original.opaque,
                                            increaseContrast: original.contrast)
                overlay.setMoveOutPresentationCollapsed(collapsed)
                overlay.setVisualOnly(true)
                let generation = overlay.surfaceGeneration
                let token = overlay.memberCell(at: 0)?.bindingToken
                let requests = pipeline.stats.requests
                for ignored in policies + [(opaque: !original.opaque, contrast: !original.contrast)] {
                    overlay.applyMaterialPolicy(reduceTransparency: ignored.opaque,
                                                increaseContrast: ignored.contrast)
                    try assertMaterial(overlay, opaque: original.opaque, contrast: original.contrast,
                                       collapsed: collapsed)
                    XCTAssertEqual(overlay.surfaceGeneration, generation)
                    XCTAssertEqual(overlay.memberCell(at: 0)?.bindingToken, token)
                    XCTAssertEqual(overlay.isMoveOutPresentationCollapsed, collapsed)
                    XCTAssertEqual(overlay.titleEditorHostView.isHidden, collapsed)
                    XCTAssertEqual(pipeline.stats.requests, requests)
                }
                overlay.clearContent()
                overlay.setVisualOnly(false)
                try assertMaterial(overlay, opaque: original.opaque, contrast: original.contrast)
                configure(overlay)
                try assertMaterial(overlay, opaque: original.opaque, contrast: original.contrast)
            }
        }
    }

    func testTornDownMaterialUpdatesDoNotMutateRetainedView() throws {
        let pipeline = IconPipeline(loader: RecordingIconLoader(), limits: .init())
        defer { pipeline.shutdown() }
        for original in policies {
            let overlay = makeOverlay(pipeline)
            overlay.applyMaterialPolicy(reduceTransparency: original.opaque,
                                        increaseContrast: original.contrast)
            overlay.teardown()
            let generation = overlay.surfaceGeneration
            let requests = pipeline.stats.requests
            for ignored in policies + [(opaque: !original.opaque, contrast: !original.contrast)] {
                overlay.applyMaterialPolicy(reduceTransparency: ignored.opaque,
                                            increaseContrast: ignored.contrast)
                try assertMaterial(overlay, opaque: original.opaque, contrast: original.contrast)
                XCTAssertTrue(overlay.isTornDown)
                XCTAssertEqual(overlay.surfaceGeneration, generation)
                XCTAssertEqual(overlay.memberCellCount, 0)
                XCTAssertNil(overlay.currentEntry)
                XCTAssertNil(overlay.titleEditorView)
                XCTAssertEqual(pipeline.stats.requests, requests)
            }
        }
    }
    func testClearBackdropPreservesOutsideHitDismissalAndInertExit() throws {
        let pipeline = IconPipeline(loader: RecordingIconLoader(), limits: .init())
        defer { pipeline.shutdown() }
        let overlay = makeOverlay(pipeline)
        defer { overlay.teardown() }
        overlay.layoutSubtreeIfNeeded()
        let outside = NSPoint(x: 2, y: 2)
        XCTAssertFalse(overlay.panelFrame.contains(outside))
        var closes = 0
        overlay.onRequestClose = { closes += 1 }
        XCTAssertEqual(overlay.layer?.backgroundColor, NSColor.clear.cgColor)
        XCTAssertTrue(overlay.hitTest(outside) === overlay, "Transparent exterior remains modal, not click-through")
        overlay.handleClick(at: outside)
        XCTAssertEqual(closes, 1)
        overlay.setVisualOnly(true)
        XCTAssertEqual(overlay.layer?.backgroundColor, NSColor.clear.cgColor)
        XCTAssertNil(overlay.hitTest(outside))
        overlay.handleClick(at: outside)
        XCTAssertEqual(closes, 1)
        overlay.setVisualOnly(false)
        XCTAssertEqual(overlay.layer?.backgroundColor, NSColor.clear.cgColor)
        overlay.handleClick(at: outside)
        XCTAssertEqual(closes, 2)
    }

}
