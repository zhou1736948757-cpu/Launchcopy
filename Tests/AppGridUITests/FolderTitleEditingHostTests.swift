import AppCatalogCore
import AppIconPipeline
import AppKit
import PagingUI
@testable import AppGridUI
import XCTest

/// Host-only coverage: synthetic views/events, no windows, catalog scans or application editor.
@MainActor
final class FolderTitleEditingHostTests: XCTestCase {
    private struct FixtureIconLoader: IconLoading {
        enum Failure: Error { case synthetic }
        func load(key: IconKey) async throws -> NSImage { throw Failure.synthetic }
    }

    /// Models a focus-loss finish during removal without changing an AppKit responder.
    private final class RemovalProbe: NSView {
        var onRemoval: (() -> Void)?
        override func viewWillMove(toSuperview newSuperview: NSView?) {
            if superview != nil && newSuperview == nil { onRemoval?() }
            super.viewWillMove(toSuperview: newSuperview)
        }
    }

    private func makeOverlay(_ pipeline: IconPipeline, title: String = "Tools") -> FolderOverlayView {
        let overlay = FolderOverlayView(iconPipeline: pipeline)
        overlay.frame = NSRect(x: 0, y: 0, width: 800, height: 600)
        overlay.configure(entry: FolderEntry(id: FolderID(), title: title, members: []),
                          innerPage: 0, reduceMotion: true) { _ in nil }
        overlay.layout()
        return overlay
    }

    private func titleLabel(_ overlay: FolderOverlayView) throws -> NSTextField {
        try XCTUnwrap(overlay.titleEditorHostView.subviews.compactMap { $0 as? NSTextField }
            .first { $0.frame == overlay.titleEditorFrame })
    }

    private func titlePoint(_ overlay: FolderOverlayView, in host: NSView) -> NSPoint {
        let frame = overlay.titleEditorFrame
        return overlay.titleEditorHostView.convert(NSPoint(x: frame.midX, y: frame.midY), to: host)
    }

    func testActualTitleButtonSelectorRequestsWithoutChangingContentOrIcons() throws {
        let pipeline = IconPipeline(loader: FixtureIconLoader(), limits: .init())
        defer { pipeline.shutdown() }
        let overlay = makeOverlay(pipeline)
        defer { overlay.teardown() }
        let root = NSView(frame: overlay.frame)
        root.addSubview(overlay)
        var requests = 0
        overlay.onRequestTitleEdit = { requests += 1 }
        let button = overlay.titleEditButton
        let entry = overlay.currentEntry
        let generation = overlay.surfaceGeneration
        let stats = pipeline.stats

        XCTAssertTrue(button.target === overlay)
        XCTAssertEqual(button.action, #selector(FolderOverlayView.requestTitleEdit(_:)))
        XCTAssertTrue(button.superview === overlay.titleEditorHostView)
        XCTAssertEqual(button.frame, overlay.titleEditorFrame)
        XCTAssertEqual(button.title, "Tools")
        XCTAssertEqual(button.toolTip, "Rename folder")
        XCTAssertEqual(button.accessibilityLabel(), "Rename folder: Tools")
        XCTAssertEqual(button.accessibilityIdentifier(), "folder-title-edit")
        XCTAssertEqual(button.accessibilityRole(), .button)
        XCTAssertTrue(button.isEnabled)
        XCTAssertTrue(button.isTransparent)
        XCTAssertEqual(button.font, try titleLabel(overlay).font)
        XCTAssertEqual(button.keyEquivalent, "")
        XCTAssertTrue(overlay.hitTest(titlePoint(overlay, in: root)) === button)
        button.performClick(nil)

        XCTAssertEqual(requests, 1)
        XCTAssertNil(overlay.titleEditorView)
        XCTAssertEqual(overlay.currentEntry, entry)
        XCTAssertEqual(overlay.surfaceGeneration, generation)
        XCTAssertEqual(pipeline.stats, stats)
        XCTAssertFalse(try titleLabel(overlay).isHidden)
    }

    func testMountUsesRealPanelAndRoutesEditorDescendantsThenRestoresTitle() throws {
        let pipeline = IconPipeline(loader: FixtureIconLoader(), limits: .init())
        defer { pipeline.shutdown() }
        let overlay = makeOverlay(pipeline)
        defer { overlay.teardown() }
        let root = NSView(frame: overlay.frame)
        root.addSubview(overlay)
        let label = try titleLabel(overlay)
        let editor = NSView()
        let control = NSTextField(frame: NSRect(x: 0, y: 0, width: 40, height: 20))
        editor.addSubview(control)
        var requests = 0
        var invalidations = 0
        overlay.onRequestTitleEdit = { requests += 1 }
        overlay.onWillInvalidateTitleEditor = { invalidations += 1 }
        let stats = pipeline.stats

        XCTAssertTrue(overlay.mountTitleEditor(editor))
        XCTAssertTrue(overlay.titleEditorView === editor)
        XCTAssertTrue(editor.superview === overlay.titleEditorHostView)
        XCTAssertEqual(editor.frame, overlay.titleEditorFrame)
        XCTAssertTrue(label.isHidden)
        XCTAssertTrue(overlay.titleEditButton.isHidden)
        XCTAssertFalse(overlay.titleEditButton.isEnabled)
        let point = control.convert(NSPoint(x: 10, y: 10), to: root)
        XCTAssertTrue(overlay.hitTest(point) === control)
        overlay.requestTitleEdit(nil)
        XCTAssertEqual(requests, 0)
        XCTAssertTrue(overlay.mountTitleEditor(editor), "Same editor mount is idempotent")
        XCTAssertFalse(overlay.mountTitleEditor(NSView()), "A live session cannot be replaced")

        overlay.unmountTitleEditor()
        overlay.unmountTitleEditor()
        XCTAssertNil(editor.superview)
        XCTAssertNil(overlay.titleEditorView)
        XCTAssertFalse(label.isHidden)
        XCTAssertFalse(overlay.titleEditButton.isHidden)
        XCTAssertTrue(overlay.titleEditButton.isEnabled)
        XCTAssertEqual(invalidations, 0, "Explicit owner finish does not invalidate again")
        XCTAssertEqual(pipeline.stats, stats)
    }

    func testResizeAndIndependentHostsNeverStealAnotherHostsEditor() {
        let pipeline = IconPipeline(loader: FixtureIconLoader(), limits: .init())
        defer { pipeline.shutdown() }
        let first = makeOverlay(pipeline)
        let second = makeOverlay(pipeline, title: "Other")
        defer { first.teardown(); second.teardown() }
        let firstRoot = NSView(frame: first.frame)
        let secondRoot = NSView(frame: second.frame)
        firstRoot.addSubview(first)
        secondRoot.addSubview(second)
        first.autoresizingMask = [.width, .height]
        second.autoresizingMask = [.width, .height]
        let firstEditor = NSView()
        let secondEditor = NSView()
        XCTAssertTrue(first.mountTitleEditor(firstEditor))
        XCTAssertFalse(second.mountTitleEditor(firstEditor))
        XCTAssertTrue(firstEditor.superview === first.titleEditorHostView)
        XCTAssertTrue(second.mountTitleEditor(secondEditor))
        let original = firstEditor.frame
        let otherFrame = secondEditor.frame

        firstRoot.setFrameSize(NSSize(width: 1200, height: 850))
        first.layout()
        XCTAssertEqual(first.frame.size, firstRoot.frame.size)
        XCTAssertNotEqual(firstEditor.frame, original)
        XCTAssertEqual(firstEditor.frame, first.titleEditorFrame)
        XCTAssertEqual(first.titleEditButton.frame, firstEditor.frame)
        XCTAssertTrue(first.titleEditorHostView.bounds.contains(firstEditor.frame))
        XCTAssertEqual(secondEditor.frame, otherFrame)
        XCTAssertTrue(secondEditor.superview === second.titleEditorHostView)
        first.unmountTitleEditor()
        XCTAssertFalse(first.mountTitleEditor(firstRoot), "Ancestor mounts cannot form a cycle")
        XCTAssertFalse(first.mountTitleEditor(first))
        XCTAssertFalse(first.mountTitleEditor(first.titleEditorHostView))
    }

    func testClearCancelsBeforeRemovalAndAllowsOwnerUnmountInsideCallback() throws {
        let pipeline = IconPipeline(loader: FixtureIconLoader(), limits: .init())
        defer { pipeline.shutdown() }
        let overlay = makeOverlay(pipeline)
        defer { overlay.teardown() }
        let label = try titleLabel(overlay)
        let editor = RemovalProbe()
        var active = true
        var commits = 0
        var invalidations = 0
        var removals = 0
        editor.onRemoval = {
            removals += 1
            XCTAssertNil(overlay.titleEditorView, "Clear host reference before removal callbacks")
            if active { commits += 1 }
        }
        overlay.onRequestTitleEdit = { XCTFail("Invalidation must reject reentrant requests") }
        overlay.onWillInvalidateTitleEditor = {
            invalidations += 1
            XCTAssertTrue(editor.superview === overlay.titleEditorHostView)
            active = false
            overlay.unmountTitleEditor()
            overlay.requestTitleEdit(nil)
            XCTAssertFalse(overlay.mountTitleEditor(NSView()))
        }
        XCTAssertTrue(overlay.mountTitleEditor(editor))

        overlay.clearContent()
        overlay.clearContent()
        XCTAssertEqual(invalidations, 1)
        XCTAssertEqual(removals, 1)
        XCTAssertEqual(commits, 0)
        XCTAssertNil(overlay.currentEntry)
        XCTAssertNil(overlay.titleEditorView)
        XCTAssertNil(editor.superview)
        XCTAssertEqual(label.stringValue, "")
        XCTAssertFalse(label.isHidden)
        XCTAssertEqual(overlay.titleEditButton.title, "")
        XCTAssertNil(overlay.titleEditButton.toolTip)
        XCTAssertFalse(overlay.titleEditButton.isEnabled)
        XCTAssertTrue(overlay.titleEditButton.isHidden)
        XCTAssertFalse(overlay.mountTitleEditor(NSView()))
    }

    func testVisualExitCancelsBeforeRemovalAndRetainedExitRemainsInert() {
        let pipeline = IconPipeline(loader: FixtureIconLoader(), limits: .init())
        defer { pipeline.shutdown() }
        let overlay = makeOverlay(pipeline)
        defer { overlay.teardown() }
        let editor = RemovalProbe()
        var cancelled = false
        var invalidations = 0
        var requests = 0
        overlay.onRequestTitleEdit = { requests += 1 }
        overlay.onWillInvalidateTitleEditor = { cancelled = true; invalidations += 1 }
        editor.onRemoval = { XCTAssertTrue(cancelled) }
        XCTAssertTrue(overlay.mountTitleEditor(editor))
        overlay.setVisualOnly(true)
        XCTAssertEqual(invalidations, 1)
        XCTAssertNil(overlay.titleEditorView)
        XCTAssertNil(overlay.onRequestTitleEdit)
        XCTAssertNil(overlay.onWillInvalidateTitleEditor)
        XCTAssertFalse(overlay.titleEditButton.isAccessibilityElement())
        XCTAssertNil(overlay.hitTest(.zero))
        XCTAssertFalse(overlay.mountTitleEditor(NSView()))
        // Even callbacks assigned to an already-frozen view must not be invoked by cleanup.
        overlay.onRequestTitleEdit = { XCTFail("Retained exit cannot request editing") }
        overlay.onWillInvalidateTitleEditor = { XCTFail("Retained exit cannot mutate the owner") }
        overlay.requestTitleEdit(nil)
        overlay.titleEditButton.performClick(nil)
        overlay.clearContent()
        overlay.teardown()
        XCTAssertEqual(requests, 0)
        XCTAssertEqual(invalidations, 1)
    }

    func testVisualResumeRestoresRequestButDoesNotResurrectEditor() {
        let pipeline = IconPipeline(loader: FixtureIconLoader(), limits: .init())
        defer { pipeline.shutdown() }
        let overlay = makeOverlay(pipeline)
        defer { overlay.teardown() }
        var requests = 0
        overlay.onRequestTitleEdit = { requests += 1 }
        XCTAssertTrue(overlay.mountTitleEditor(NSView()))
        overlay.setVisualOnly(true)
        overlay.setVisualOnly(false)
        XCTAssertNil(overlay.titleEditorView)
        XCTAssertTrue(overlay.titleEditButton.isEnabled)
        overlay.titleEditButton.performClick(nil)
        XCTAssertEqual(requests, 1)
    }

    func testCollapsedMoveOutAndActualDrawingProxyCannotRequestOrMountTitleEditor() throws {
        let pipeline = IconPipeline(loader: FixtureIconLoader(), limits: .init())
        defer { pipeline.shutdown() }
        let overlay = makeOverlay(pipeline)
        defer { overlay.teardown() }
        let root = NSView(frame: overlay.frame)
        root.addSubview(overlay)
        let coordinator = DragUISessionCoordinator(reduceMotionProvider: { true })
        defer { coordinator.teardown() }
        overlay.dragCoordinator = coordinator
        let ids = [makeAppID("fixture.title.dragged"), makeAppID("fixture.title.remaining")]
        overlay.configure(entry: FolderEntry(id: FolderID(), title: "Pair", members: ids),
                          innerPage: 0, reduceMotion: true) { _ in "Member" }
        overlay.layout()
        let source = try XCTUnwrap(overlay.memberCell(at: 0))
        let event = try XCTUnwrap(NSEvent.mouseEvent(
            with: .leftMouseDown,
            location: source.convert(NSPoint(x: source.bounds.midX, y: source.bounds.midY), to: nil),
            modifierFlags: [], timestamp: 0, windowNumber: 0, context: nil,
            eventNumber: 0, clickCount: 1, pressure: 1))
        overlay.mouseDown(with: event)
        XCTAssertEqual(overlay.moveOutRemainingAppID, ids[1])
        var requests = 0
        var invalidations = 0
        overlay.onRequestTitleEdit = { requests += 1 }
        overlay.onWillInvalidateTitleEditor = { invalidations += 1 }
        let editor = NSView()
        XCTAssertTrue(overlay.mountTitleEditor(editor))
        overlay.prepareMoveOutIconCache()
        overlay.setMoveOutPresentationCollapsed(true)
        XCTAssertEqual(invalidations, 1)
        XCTAssertNil(editor.superview)
        XCTAssertFalse(overlay.titleEditButton.isEnabled)
        XCTAssertFalse(overlay.mountTitleEditor(NSView()))
        overlay.requestTitleEdit(nil)
        overlay.showMoveOutRemainingAppProxy(in: root, frame: NSRect(x: 20, y: 30, width: 100, height: 88))
        let proxyHost = try XCTUnwrap(overlay.moveOutRemainingAppProxyHost)
        XCTAssertNil(proxyHost.hitTest(NSPoint(x: 40, y: 50)))
        XCTAssertFalse(proxyHost.subviews.contains { $0 is NSButton })
        XCTAssertEqual(requests, 0)
        overlay.setMoveOutPresentationCollapsed(false)
        overlay.titleEditButton.performClick(nil)
        XCTAssertEqual(requests, 1)
        XCTAssertNil(overlay.titleEditorView)
    }

    func testConfigureKeepsIdempotentSessionButCancelsOnFolderSwitch() {
        let pipeline = IconPipeline(loader: FixtureIconLoader(), limits: .init())
        defer { pipeline.shutdown() }
        let overlay = makeOverlay(pipeline)
        defer { overlay.teardown() }
        let entry = overlay.currentEntry!
        let editor = NSView()
        var invalidations = 0
        overlay.onWillInvalidateTitleEditor = { invalidations += 1 }
        XCTAssertTrue(overlay.mountTitleEditor(editor))
        let generation = overlay.surfaceGeneration
        overlay.configure(entry: entry, innerPage: 0, reduceMotion: true) { _ in nil }
        XCTAssertTrue(overlay.titleEditorView === editor)
        XCTAssertEqual(overlay.surfaceGeneration, generation)
        XCTAssertEqual(invalidations, 0)
        overlay.configure(entry: FolderEntry(id: FolderID(), title: "Switched", members: []),
                          innerPage: 0, reduceMotion: true) { _ in nil }
        XCTAssertEqual(invalidations, 1)
        XCTAssertNil(editor.superview)
        XCTAssertEqual(overlay.titleEditButton.title, "Switched")
    }

    func testTeardownNotifiesOnceThenRejectsStaleActionsAndMounts() {
        let pipeline = IconPipeline(loader: FixtureIconLoader(), limits: .init())
        defer { pipeline.shutdown() }
        let overlay = makeOverlay(pipeline)
        let editor = RemovalProbe()
        var cancelled = false
        var invalidations = 0
        overlay.onRequestTitleEdit = { XCTFail("Torn-down overlay must stay inert") }
        overlay.onWillInvalidateTitleEditor = { cancelled = true; invalidations += 1 }
        editor.onRemoval = { XCTAssertTrue(cancelled) }
        XCTAssertTrue(overlay.mountTitleEditor(editor))
        overlay.teardown()
        overlay.teardown()
        XCTAssertEqual(invalidations, 1)
        XCTAssertNil(editor.superview)
        XCTAssertNil(overlay.titleEditorView)
        XCTAssertNil(overlay.onRequestTitleEdit)
        XCTAssertNil(overlay.onWillInvalidateTitleEditor)
        XCTAssertEqual(overlay.titleEditButton.title, "")
        XCTAssertFalse(overlay.titleEditButton.isEnabled)
        XCTAssertFalse(overlay.mountTitleEditor(NSView()))
        overlay.onRequestTitleEdit = { XCTFail("Late callback cannot revive a torn-down host") }
        overlay.requestTitleEdit(nil)
        overlay.titleEditButton.performClick(nil)
        XCTAssertNil(overlay.hitTest(.zero))
    }

    func testDefaultConsumerIsInertAndLegacyCatalogRevisionRemainsZero() throws {
        let pipeline = IconPipeline(loader: FixtureIconLoader(), limits: .init())
        defer { pipeline.shutdown() }
        let overlay = FolderOverlayView(iconPipeline: pipeline)
        defer { overlay.teardown() }
        XCTAssertNil(overlay.onRequestTitleEdit)
        XCTAssertNil(overlay.onWillInvalidateTitleEditor)
        XCTAssertFalse(overlay.titleEditButton.isEnabled)
        XCTAssertFalse(overlay.mountTitleEditor(NSView()))
        overlay.requestTitleEdit(nil)
        let ids = [makeAppID("fixture.title.legacy")]
        overlay.configure(entry: FolderEntry(id: FolderID(), title: "Legacy", members: ids),
                          innerPage: 0, reduceMotion: true) { _ in "Member" }
        let token = try XCTUnwrap(overlay.memberCell(at: 0)?.bindingToken)
        XCTAssertEqual(token.catalogRevision, 0)
        XCTAssertEqual(token.pageIdentity, PagePresentationID(revision: 0, pageIndex: 0))
        let generation = overlay.surfaceGeneration
        overlay.titleEditButton.performClick(nil)
        overlay.requestTitleEdit(nil)
        XCTAssertFalse(overlay.titleEditButton.isEnabled)
        XCTAssertNil(overlay.titleEditorView)
        XCTAssertEqual(overlay.surfaceGeneration, generation)
    }
}
