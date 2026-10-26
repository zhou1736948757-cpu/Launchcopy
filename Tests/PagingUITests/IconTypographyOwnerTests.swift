import AppCatalogCore
import AppGridUI
import AppKit
import LauncherLocalization
import XCTest
@testable import PagingPrototypeApp
@testable import PagingUI

@MainActor
final class IconTypographyOwnerTests: XCTestCase {
    @MainActor
    private final class Fixture {
        let owner = AppDelegate(options: .default)
        let surface = makeSurface(pageCount: 3, itemsPerPage: 35)
        let assembly = AppCatalogAssembly(roots: [URL(fileURLWithPath: "/SyntheticStyle")], loader: RecordingIconLoader())
        let host = NSView(frame: NSRect(x: 0, y: 0, width: 1000, height: 900))
        let keyboard = KeyboardFocusController(columns: 5)
        let store = InMemoryAppearancePreferencesStore()
        let view = AppearanceSettingsView(frame: NSRect(x: 0, y: 0, width: 500, height: 500))
        let window: NSWindow
        let catalog: CatalogSnapshot
        let folder = FolderID(uuid: UUID(uuidString: "00000000-0000-0000-0000-000000000071")!)
        init() {
            catalog = .init(revision: CatalogRevision(7), records: (0..<105).map { number in
                let id = CatalogFixture.appID("fixture.style.\(number)")
                return CatalogFixture.record(id: id, displayName: "App \(number)", bundleID: "fixture.style.\(number)",
                    url: CatalogFixture.tempURL(named: "Style\(number).app"), icon: .from(appID: id), rootPriority: 0)
            })
            window = NSWindow(contentRect: host.bounds, styleMask: [.titled], backing: .buffered, defer: false)
            window.isReleasedWhenClosed = false; window.contentView = host
            surface.frame = host.bounds; host.addSubview(surface)
            surface.contentProvider = assembly.provider; surface.renderer = assembly.renderer
            assembly.renderer.committedPageProvider = { [weak surface] in surface?.core.committedPage ?? -1 }
            owner.surface = surface; owner.container = host; owner.assembly = assembly; owner.window = window
            owner.keyboardController = keyboard; keyboard.install(on: surface, focusModel: .init())
            owner.installFolderWiring(assembly: assembly, surface: surface, keyboard: keyboard,
                launch: AppLaunchController(surface: surface, assembly: assembly, session: nil))
            owner.installDragUI(surface: surface, assembly: assembly)
            assembly.provider.receive(catalog); _ = assembly.commitPendingAtIdleBoundary(currentPage: 0)
            surface.refreshPresentation()
            owner.pageNavigationLifecycleCheck = { true }; owner.installPageDots(in: host)
            surface.onIdleBoundary = { [weak owner] in owner?.applyPendingAtIdleBoundary() }
            owner.installAppearancePreferences(store: store)
            // Mirror the production startup renderer assignment after preferences load.
            assembly.renderer.itemAppearance = owner.appearancePreferences.mainItemAppearance
            owner.folderOverlay?.itemAppearance = owner.appearancePreferences.itemAppearance
            owner.configureAppearanceSettings(view)
        }
        func apply(side: Int, font: Int, mainSide: Int? = nil) {
            view.iconSlider.integerValue = side; view.fontSlider.integerValue = font
            view.mainIconSlider.integerValue = mainSide ?? side
            view.controlChanged(view.mainIconSlider)
            view.onFlush?()
        }
        func teardown() {
            owner.dragCoordinator?.teardown(); owner.closeFolder(); surface.teardown(); assembly.teardown()
            owner.pageDotsView?.removeFromSuperview(); window.delegate = nil; window.contentView = nil
        }
        func installFolder() {
            let refs = catalog.records.prefix(2).map { PersistentAppReference.from(record: $0) }
            let layout = PersistentWorkspaceLayout(generation: .zero,
                topLevelOrder: [.folder(folder)] + catalog.records.dropFirst(2).map { .app(PersistentAppReference.from(record: $0)) },
                folders: [.init(id: folder, title: "Style group", members: refs)])
            _ = assembly.provider.applyCommittedLayout(layout, atCurrentPage: 0, itemsPerPage: 35)
            surface.reloadCurrentPresentation(); surface.layoutSubtreeIfNeeded()
            owner.openFolder(folderID: folder); owner.folderOverlay?.layoutSubtreeIfNeeded()
        }
    }
    private func nextMainTurn() async {
        await withCheckedContinuation { continuation in
            DispatchQueue.main.async { continuation.resume() }
        }
    }

    func testFitEstimateUsesSelectedCapacityBeforeItsPresentation() throws {
        let f = Fixture(); defer { f.teardown() }
        let section = MainGridCapacitySettingsView(frame: .zero, strings: f.view.strings, embedded: true)
        let initial = MainGridCapacity(columns: 6, rows: 5)!
        section.reload(capacity: initial, loadResult: .loaded(initial))
        section.onApply = { _ in true } // Admit a draft without presenting it.
        f.view.attachMainGridSection(section)
        f.view.refreshMainIconFit()
        let oldLabel = f.view.mainIconFitLabel.stringValue
        let expectedFirst = try XCTUnwrap(MainGridLayoutMetrics.fittedIconSides(
            bounds: f.surface.bounds, capacity: initial,
            appearance: f.view.draft.mainItemAppearance, showsLabels: true))
        XCTAssertEqual(oldLabel, f.view.strings.mainIconFitText(
            app: Double(expectedFirst.app), folder: Double(expectedFirst.folder)))
        section.rowsPopup.selectItem(withTag: 8)
        section.controlChanged(section.rowsPopup)
        XCTAssertEqual(f.owner.mainGridCapacity, .default, "Presentation remains unchanged")
        XCTAssertNotEqual(f.view.mainIconFitLabel.stringValue, oldLabel)
        let expected = try XCTUnwrap(MainGridLayoutMetrics.fittedIconSides(
            bounds: f.surface.bounds, capacity: section.draft,
            appearance: f.view.draft.mainItemAppearance, showsLabels: true))
        XCTAssertEqual(f.view.mainIconFitLabel.stringValue, f.view.strings.mainIconFitText(
            app: Double(expected.app), folder: Double(expected.folder)))
    }

    func testIndependentMainSizeKeepsFolderAppearanceAndIconBindings() throws {
        let f = Fixture(); defer { f.teardown() }
        let page = try XCTUnwrap(f.assembly.renderer.pageView(forPage: 0))
        let folderBefore = try XCTUnwrap(f.owner.folderOverlay).itemAppearance
        let cell = try XCTUnwrap(page.cell(at: 0))
        let binding = cell.bindingToken
        let generation = page.surfaceGeneration
        let requests = f.assembly.iconPipeline.stats.requests
        f.view.mainIconSlider.integerValue = 96
        f.view.controlChanged(f.view.mainIconSlider)
        f.view.onFlush?()
        XCTAssertEqual(f.owner.appearancePreferences.mainPreferredIconSide, 96)
        XCTAssertEqual(f.assembly.renderer.itemAppearance.preferredIconSide, 96)
        XCTAssertEqual(f.owner.folderOverlay?.itemAppearance, folderBefore)
        XCTAssertEqual(f.owner.appearancePreferences.preferredIconSide, folderBefore.preferredIconSide)
        XCTAssertEqual(cell.bindingToken, binding)
        XCTAssertEqual(page.surfaceGeneration, generation)
        XCTAssertEqual(f.assembly.iconPipeline.stats.requests, requests)
        let fit = try XCTUnwrap(f.view.mainIconFitProvider?(f.view.draft))
        XCTAssertGreaterThan(fit.app, 0)
        XCTAssertLessThanOrEqual(fit.app, 96)
        XCTAssertLessThan(fit.folder, 96, "Dense selected rows report actual fit, not a false 96pt claim")
    }

    func testIdleLiveEditAndFlushChangesOnlyAppearancePreservingBindingsAndIconRequests() throws {
        let f = Fixture(); defer { f.teardown() }
        let page = try XCTUnwrap(f.assembly.renderer.pageView(forPage: 0))
        let cell = try XCTUnwrap(page.cell(at: 0)); page.layout()
        let token = cell.bindingToken, generation = page.surfaceGeneration
        let requests = f.assembly.iconPipeline.stats.requests
        let revision = f.surface.servedRevision, count = f.surface.core.pageCount
        f.apply(side: 64, font: 16)
        XCTAssertEqual(f.owner.appearancePreferences.preferredIconSide, 64)
        XCTAssertNil(f.owner.pendingAppearancePreferences)
        XCTAssertEqual(cell.itemAppearance, .init(preferredIconSide: 64, appLabelFontSize: 16))
        XCTAssertEqual(cell.bindingToken, token); XCTAssertEqual(page.surfaceGeneration, generation)
        XCTAssertEqual(f.assembly.iconPipeline.stats.requests, requests)
        XCTAssertEqual(f.surface.servedRevision, revision); XCTAssertEqual(f.surface.core.pageCount, count)
        XCTAssertEqual(f.view.statusLabel.textColor, .systemGreen)
    }
    func testIconAndFontLiveEditsNeverRequestWallpaperAndEqualEditDoesNoPresentationWork() {
        let f = Fixture(); defer { f.teardown() }
        var wallpaperRequests = 0
        let backdrop = WallpaperBackdropController(imageLoader: { _, _, _ in wallpaperRequests += 1 },
            sourceResolver: { _ in URL(fileURLWithPath: "/SyntheticWallpaper") })
        backdrop.attach(to: f.host); f.owner.wallpaperBackdrop = backdrop
        f.apply(side: 64, font: 16)
        let requests = f.assembly.iconPipeline.stats.requests
        f.apply(side: 64, font: 16)
        f.apply(side: 64, font: 9)
        XCTAssertEqual(wallpaperRequests, 0)
        XCTAssertEqual(f.assembly.iconPipeline.stats.requests, requests)
        XCTAssertNil(f.owner.pendingAppearancePreferences)
    }

    func testGestureQueuesLatestAcceptedDraftWithoutInterruptAndAppliesAtActualIdleCallback() async {
        let f = Fixture(); defer { f.teardown() }
        gestureBegan(f.surface, at: 0)
        let pin = f.surface.pinnedPresentation
        f.apply(side: 64, font: 16); f.apply(side: 32, font: 9)
        XCTAssertEqual(f.surface.core.state, .tracking); XCTAssertEqual(f.surface.pinnedPresentation, pin)
        XCTAssertEqual(f.owner.appearancePreferences, .default)
        XCTAssertEqual(f.store.load(), .loaded(.init(preferredIconSide: 32, appLabelFontSize: 9,
                                                    mainPreferredIconSide: 32)))
        XCTAssertEqual(f.owner.pendingAppearancePreferences?.preferredIconSide, 32)
        XCTAssertEqual(f.view.statusLabel.stringValue,
                       f.view.strings.liveAppearanceText(.saved) + "\n" + f.view.strings.liveAppearanceText(.queued))
        gestureEnded(f.surface, at: 0.02); finishPendingGesture(f.surface, at: 0.03); settleFrames(f.surface)
        await nextMainTurn()
        XCTAssertNil(f.owner.pendingAppearancePreferences)
        XCTAssertEqual(f.owner.appearancePreferences.preferredIconSide, 32)
        XCTAssertEqual(f.view.statusLabel.textColor, .systemGreen)
    }
    func testDirectNavigationAndManualPinDoNotApplyOldGeometryBeforeBoundary() async {
        let f = Fixture(); defer { f.teardown() }
        XCTAssertTrue(f.surface.requestPage(2, timestamp: 0))
        let target = f.surface.core.activeTransition?.targetPage
        f.apply(side: 64, font: 16)
        XCTAssertEqual(f.surface.core.activeTransition?.targetPage, target)
        XCTAssertEqual(f.owner.appearancePreferences, .default)
        settleFrames(f.surface)
        await nextMainTurn()
        XCTAssertEqual(f.owner.appearancePreferences.preferredIconSide, 64)
        f.surface.beginInteraction(); f.apply(side: 32, font: 9)
        XCTAssertEqual(f.owner.appearancePreferences.preferredIconSide, 64)
        f.surface.endInteraction(); f.owner.flushPendingAppearanceIfReady()
        XCTAssertEqual(f.owner.appearancePreferences.preferredIconSide, 32)
    }
    func testAcceptedReturnToCurrentStyleCancelsSupersededQueuedDraft() {
        let f = Fixture(); defer { f.teardown() }
        f.owner.appearancePresentationReadinessCheck = { false }
        f.apply(side: 64, font: 16)
        XCTAssertNotNil(f.owner.pendingAppearancePreferences)
        f.apply(side: 80, font: 11, mainSide: 80)
        XCTAssertNil(f.owner.pendingAppearancePreferences); XCTAssertEqual(f.owner.appearancePreferences, .default)
        f.owner.appearancePresentationReadinessCheck = nil; f.owner.flushPendingAppearanceIfReady()
        XCTAssertEqual(f.assembly.renderer.itemAppearance, AppearancePreferences.default.mainItemAppearance)
    }
    func testActualHeldPointerKeepsStyleUntilSessionEnds() async throws {
        let f = Fixture(); defer { f.teardown() }
        let cell = try XCTUnwrap(f.assembly.renderer.pageView(forPage: 0)?.cell(at: 0))
        cell.layoutSubtreeIfNeeded()
        let point = cell.convert(NSPoint(x: cell.bounds.midX, y: cell.bounds.midY), to: nil)
        f.owner.dragCoordinator?.pointerDown(locationInWindow: point, sourceCell: cell, memberFolderID: nil)
        XCTAssertTrue(f.owner.dragCoordinator?.isSessionActive == true)
        f.apply(side: 64, font: 16)
        XCTAssertEqual(cell.itemAppearance, AppearancePreferences.default.mainItemAppearance); XCTAssertNotNil(f.owner.pendingAppearancePreferences)
        f.owner.dragCoordinator?.cancel(reason: .escape)
        await nextMainTurn()
        XCTAssertEqual(cell.itemAppearance.preferredIconSide, 64)
        XCTAssertNil(f.owner.pendingAppearancePreferences)
    }
    func testTitleEditorQueuesStyleAndCancelAppliesWithoutClosingFolder() async throws {
        let f = Fixture(); defer { f.teardown() }; f.installFolder()
        let overlay = try XCTUnwrap(f.owner.folderOverlay)
        overlay.layoutSubtreeIfNeeded(); overlay.titleEditButton.performClick(nil)
        XCTAssertNotNil(f.owner.folderTitleEditor)
        f.apply(side: 64, font: 16)
        XCTAssertEqual(overlay.itemAppearance, AppearancePreferences.default.itemAppearance)
        XCTAssertNotNil(f.owner.pendingAppearancePreferences)
        f.keyboard.onTitleCancel?()
        await nextMainTurn()
        XCTAssertNil(f.owner.folderTitleEditor)
        XCTAssertEqual(overlay.itemAppearance.preferredIconSide, 64)
        XCTAssertEqual(f.owner.folderOpenState?.openFolderID, f.folder)
    }
    func testFolderEntranceQueueFlushesAfterResizeAndRejectsOldMotionCompletion() async {
        let f = Fixture(); defer { f.teardown() }; f.installFolder()
        f.owner.closeFolder()
        f.owner.openFolder(folderID: f.folder, animatedFromPointer: true)
        f.apply(side: 64, font: 16)
        XCTAssertNotNil(f.owner.pendingAppearancePreferences)
        XCTAssertEqual(f.owner.appearancePreferences, .default)
        f.owner.windowDidResize(.init(name: NSWindow.didResizeNotification, object: f.window))
        await nextMainTurn()
        XCTAssertNil(f.owner.pendingAppearancePreferences)
        XCTAssertEqual(f.owner.folderOverlay?.itemAppearance.preferredIconSide, 64)
        f.apply(side: 32, font: 9)
        try? await Task.sleep(nanoseconds: 250_000_000)
        XCTAssertEqual(f.owner.appearancePreferences.preferredIconSide, 32)
        XCTAssertEqual(f.owner.folderOverlay?.itemAppearance.appLabelFontSize, 9)
    }

    func testFolderEntranceCompletesDeferredStyleAndScreenChangeAlsoFlushesQueue() async {
        let f = Fixture(); defer { f.teardown() }; f.installFolder()
        f.owner.closeFolder(); f.owner.openFolder(folderID: f.folder, animatedFromPointer: true)
        f.apply(side: 64, font: 16)
        XCTAssertNotNil(f.owner.pendingAppearancePreferences)
        // Observe the promised asynchronous drain, not a narrow fixed margin over240ms.
        _ = await waitUntil({ f.owner.pendingAppearancePreferences == nil }, timeout: 1)
        XCTAssertNil(f.owner.pendingAppearancePreferences)
        XCTAssertEqual(f.owner.folderOverlay?.itemAppearance.preferredIconSide, 64)
        f.owner.closeFolder(); f.owner.openFolder(folderID: f.folder, animatedFromPointer: true)
        f.apply(side: 32, font: 9)
        XCTAssertNotNil(f.owner.pendingAppearancePreferences)
        f.owner.windowDidChangeScreen(.init(name: NSWindow.didChangeScreenNotification, object: f.window))
        await nextMainTurn()
        XCTAssertNil(f.owner.pendingAppearancePreferences)
        XCTAssertEqual(f.owner.folderOverlay?.itemAppearance.preferredIconSide, 32)
    }

    func testTerminalFrameDefersAppearanceAndRechecksNewInputBeforeQueuedDrain() async {
        let f = Fixture(); defer { f.teardown() }
        gestureBegan(f.surface, at: 0); gestureChanged(f.surface, deltaX: 600, at: 0.02)
        gestureEnded(f.surface, at: 0.03); finishPendingGesture(f.surface, at: 0.04)
        f.apply(side: 64, font: 16)
        var insideFrame = true
        var observedTerminalFrame = false
        let previous = f.surface.appEvents.onStateChange
        f.surface.appEvents.onStateChange = { state in
            previous?(state)
            if state == .idle && insideFrame {
                observedTerminalFrame = true
                XCTAssertEqual(f.owner.appearancePreferences, .default)
            }
        }
        settleFrames(f.surface); insideFrame = false
        XCTAssertTrue(observedTerminalFrame)
        XCTAssertEqual(f.owner.appearancePreferences, .default)
        gestureBegan(f.surface, at: 20)
        await nextMainTurn()
        XCTAssertEqual(f.owner.appearancePreferences, .default)
        XCTAssertNotNil(f.owner.pendingAppearancePreferences)
        gestureEnded(f.surface, at: 20.01); finishPendingGesture(f.surface, at: 20.02); settleFrames(f.surface)
        await nextMainTurn()
        XCTAssertEqual(f.owner.appearancePreferences.preferredIconSide, 64)
    }

    func testBlankPointerOwnershipSurvivesThresholdAndReleasesQueuedAppearanceOnce() async {
        let f = Fixture(); defer { f.teardown() }
        let coordinator = f.owner.dragCoordinator
        coordinator?.pointerDown(locationInWindow: .init(x: 10, y: 10), sourceCell: nil, memberFolderID: f.folder)
        XCTAssertTrue(coordinator?.isSessionActive == true)
        f.apply(side: 64, font: 16)
        coordinator?.pointerDragged(locationInWindow: .init(x: 50, y: 50))
        XCTAssertTrue(coordinator?.isSessionActive == true, "An ineligible blank click is still held input")
        f.owner.schedulePendingAppearancePresentation(); await nextMainTurn()
        XCTAssertEqual(f.owner.appearancePreferences, .default)
        coordinator?.pointerUp(locationInWindow: .init(x: 50, y: 50))
        XCTAssertFalse(coordinator?.isSessionActive == true)
        await nextMainTurn()
        XCTAssertEqual(f.owner.appearancePreferences.preferredIconSide, 64)
        coordinator?.pointerDown(locationInWindow: .init(x: 10, y: 10), sourceCell: nil, memberFolderID: f.folder)
        f.apply(side: 32, font: 9); coordinator?.cancel(reason: .escape)
        await nextMainTurn()
        XCTAssertEqual(f.owner.appearancePreferences.preferredIconSide, 32)
    }

    func testClickOnlyFallbackThresholdRestoresSuppressionButWaitsForPhysicalRelease() async throws {
        let f = Fixture(); defer { f.teardown() }
        let cell = try XCTUnwrap(f.assembly.renderer.pageView(forPage: 0)?.cell(at: 0))
        let coordinator = try XCTUnwrap(f.owner.dragCoordinator)
        coordinator.dragStartGate = { false }
        let point = cell.convert(.init(x: cell.bounds.midX, y: cell.bounds.midY), to: nil)
        coordinator.pointerDown(locationInWindow: point, sourceCell: cell, memberFolderID: nil)
        f.apply(side: 64, font: 16)
        let moved = NSPoint(x: point.x + 40, y: point.y + 40)
        coordinator.pointerDragged(locationInWindow: moved)
        XCTAssertTrue(coordinator.isSessionActive)
        XCTAssertEqual(coordinator.controller.state, .idle)
        f.owner.schedulePendingAppearancePresentation(); await nextMainTurn()
        XCTAssertEqual(f.owner.appearancePreferences, .default)
        coordinator.pointerUp(locationInWindow: moved); await nextMainTurn()
        XCTAssertFalse(coordinator.isSessionActive)
        XCTAssertEqual(f.owner.appearancePreferences.preferredIconSide, 64)
        coordinator.pointerDown(locationInWindow: point, sourceCell: cell, memberFolderID: nil)
        f.apply(side: 32, font: 9); coordinator.setVisualHost(nil)
        coordinator.pointerUp(locationInWindow: moved); await nextMainTurn()
        XCTAssertFalse(coordinator.isSessionActive)
        XCTAssertEqual(f.owner.appearancePreferences.preferredIconSide, 32)
    }

    func testLostHostCancelsRealPressedAndDraggingControllersBeforeAppearanceDrain() async throws {
        for startDragging in [false, true] {
            let f = Fixture(); defer { f.teardown() }
            let coordinator = try XCTUnwrap(f.owner.dragCoordinator)
            let cell = try XCTUnwrap(f.assembly.renderer.pageView(forPage: 0)?.cell(at: 0))
            let point = cell.convert(.init(x: cell.bounds.midX, y: cell.bounds.midY), to: nil)
            var clicks = 0, commits = 0
            coordinator.onCellClick = { _ in clicks += 1 }
            coordinator.onCommit = { _ in commits += 1 }
            coordinator.pointerDown(locationInWindow: point, sourceCell: cell, memberFolderID: nil)
            XCTAssertEqual(coordinator.controller.state, .pressed)
            let moved = NSPoint(x: point.x + 40, y: point.y + 40)
            if startDragging {
                coordinator.pointerDragged(locationInWindow: moved)
                XCTAssertTrue(coordinator.controller.state == .dragging || coordinator.controller.state == .edgeTurnPending)
            }
            f.apply(side: 64, font: 16)
            XCTAssertNotNil(f.owner.pendingAppearancePreferences)
            coordinator.setVisualHost(nil)
            coordinator.pointerUp(locationInWindow: moved)
            XCTAssertEqual(coordinator.controller.state, .idle)
            XCTAssertFalse(coordinator.isSessionActive)
            await nextMainTurn()
            XCTAssertNil(f.owner.pendingAppearancePreferences)
            XCTAssertEqual(f.owner.appearancePreferences.preferredIconSide, 64)
            XCTAssertEqual(clicks, 0); XCTAssertEqual(commits, 0)
        }
    }

    func testAccessibilityCancellationFlushesQueueWithoutOldMotionOverwritingLatestStyle() async {
        let f = Fixture(); defer { f.teardown() }; f.installFolder()
        f.owner.closeFolder(); f.owner.openFolder(folderID: f.folder, animatedFromPointer: true)
        f.apply(side: 64, font: 16)
        f.owner.handleAccessibilityDisplayChange(wallpaperPolicy:
            .init(reduceTransparency: true, increaseContrast: true, reduceMotion: true))
        await nextMainTurn()
        XCTAssertNil(f.owner.pendingAppearancePreferences)
        XCTAssertEqual(f.owner.appearancePreferences.preferredIconSide, 64)
        f.apply(side: 32, font: 9)
        try? await Task.sleep(nanoseconds: 250_000_000)
        XCTAssertEqual(f.owner.folderOverlay?.itemAppearance.preferredIconSide, 32)
        XCTAssertEqual(f.view.statusLabel.textColor, .systemGreen)
    }

    func testExitVisualStaysFrozenUntilCompletionBeforeAcceptedAppearanceFanOut() async throws {
        let f = Fixture(); defer { f.teardown() }; f.installFolder()
        let overlay = try XCTUnwrap(f.owner.folderOverlay)
        let member = try XCTUnwrap(overlay.memberCell(at: 0)); member.layoutSubtreeIfNeeded()
        let frame = member.iconView.frame, font = member.nameLabel.font
        f.owner.closeFolder(animatedFromPointer: true)
        XCTAssertTrue(overlay.isVisualOnly)
        f.apply(side: 64, font: 16)
        XCTAssertNotNil(f.owner.pendingAppearancePreferences)
        XCTAssertEqual(member.itemAppearance, AppearancePreferences.default.itemAppearance)
        XCTAssertEqual(member.iconView.frame, frame); XCTAssertTrue(member.nameLabel.font === font)
        try? await Task.sleep(nanoseconds: 250_000_000)
        await nextMainTurn()
        XCTAssertNil(f.owner.pendingAppearancePreferences)
        XCTAssertEqual(f.owner.appearancePreferences.preferredIconSide, 64)
    }

    func testHideCancellationAppliesAcceptedQueueAndTornDownSurfaceDoesNotWritePresentation() async {
        let f = Fixture(); defer { f.teardown() }
        gestureBegan(f.surface, at: 0); f.apply(side: 64, font: 16)
        f.surface.cancel(); f.owner.prepareTransientCancellationForHide()
        await nextMainTurn()
        XCTAssertEqual(f.owner.appearancePreferences.preferredIconSide, 64)
        f.surface.teardown(); f.apply(side: 32, font: 9)
        XCTAssertEqual(f.owner.appearancePreferences.preferredIconSide, 64)
        XCTAssertEqual(f.owner.appearancePresentationState, .unavailable)
    }
}
