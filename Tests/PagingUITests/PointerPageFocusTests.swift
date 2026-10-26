// Pointer page navigation uses the existing keyboard focus model and manual-frame fixture.
// Surface request acceptance and owner wiring belong to Main's integration tests.

import AppKit
import XCTest
@testable import AppCatalogCore
@testable import AppGridUI
@testable import AppIconPipeline
@testable import PagingPrototypeApp
@testable import PagingUI

@MainActor
final class PointerPageFocusTests: XCTestCase {
    private var factory: FakeAppFactory!
    private var surface: PagingSurface!
    private var assembly: AppCatalogAssembly!
    private var controller: KeyboardFocusController!

    override func setUpWithError() throws {
        factory = try FakeAppFactory(prefix: "pointer-page-focus-tests")
        surface = makeSurface(pageCount: 3, itemsPerPage: 35)
        assembly = AppCatalogAssembly(roots: [factory.root], loader: RecordingIconLoader())
        wireAssembly(assembly, to: surface)
    }

    override func tearDownWithError() throws {
        controller = nil
        assembly?.teardown()
        assembly = nil
        surface?.teardown()
        surface = nil
        factory?.removeRoot()
        factory = nil
    }

    private func readyController(appCount: Int = 3, selected: Bool = true) async throws {
        _ = try factory.makeApps(names: (0..<appCount).map { String(format: "App%03d", $0) })
        assembly.begin()
        let committed = await waitUntil { self.assembly.provider.servedSnapshot != nil }
        XCTAssertTrue(committed)
        _ = try XCTUnwrap(assembly.provider.servedSnapshot)

        controller = KeyboardFocusController(columns: 5)
        controller.install(on: surface, focusModel: AppGridFocusModel())
        let previousIdle = surface.onIdleBoundary
        surface.onIdleBoundary = { [weak controller, weak surface] in
            previousIdle?()
            guard let controller, let surface else { return }
            controller.reconcileSettledCrossPage(committedPage: surface.core.committedPage)
        }
        if selected {
            controller.keyDown(with: keyEvent(124))
        }
    }

    private func keyEvent(_ keyCode: UInt16, modifiers: NSEvent.ModifierFlags = []) -> NSEvent {
        // AppKit always supports creating these synthetic key-down events.
        NSEvent.keyEvent(with: .keyDown, location: .zero, modifierFlags: modifiers,
                         timestamp: 0, windowNumber: 0, context: nil,
                         characters: "", charactersIgnoringModifiers: "",
                         isARepeat: false, keyCode: keyCode)!
    }

    private func currentLayout() throws -> AppGridFocusLayout {
        let snapshot = try XCTUnwrap(assembly.provider.servedSnapshot)
        return AppGridFocusLayout.build(from: snapshot, itemsPerPage: surface.itemsPerPage)
    }

    private func focusOn(page: Int, slot: Int) throws {
        let layout = try currentLayout()
        let entry = try XCTUnwrap(layout.validEntry(page: page, slot: slot))
        controller.setFocus(to: AppGridFocusIdentity(catalogRevision: layout.revision,
                                                     pageIndex: page, slotIndex: slot,
                                                     entryIdentity: entry))
    }

    private func cell(page: Int, slot: Int) throws -> AppGridCellView {
        try XCTUnwrap(assembly.renderer.pageView(forPage: page)?.cell(at: slot))
    }

    private func beginKeyboardCrossPageSettle() throws -> AppGridCellView {
        try focusOn(page: 0, slot: 34)
        let oldCell = try cell(page: 0, slot: 34)
        XCTAssertTrue(oldCell.isFocused)
        controller.keyDown(with: keyEvent(124))
        XCTAssertEqual(surface.core.state, .settling)
        XCTAssertEqual(surface.core.committedPage, 0)
        XCTAssertEqual(controller.focusModel.current?.pageIndex, 1)
        XCTAssertEqual(controller.focusModel.current?.slotIndex, 0)
        XCTAssertFalse(oldCell.isFocused)
        let targetCell = try cell(page: 1, slot: 0)
        XCTAssertTrue(targetCell.isFocused)
        return targetCell
    }

    func testPointerClearUnhighlightsActualCellAndKeepsSelectionDeferred() async throws {
        try await readyController()
        controller.keyDown(with: keyEvent(124))
        let selectedCell = try cell(page: 0, slot: 1)
        XCTAssertTrue(selectedCell.isFocused)
        var searchRequests = 0
        controller.onSearchShortcut = { searchRequests += 1 }
        let commitsBefore = surface.core.commitCount

        controller.clearFocusForPointerNavigation()
        XCTAssertNil(controller.focusModel.current)
        XCTAssertFalse(selectedCell.isFocused)
        controller.clearFocusForPointerNavigation()
        controller.refreshFocusVisual()
        try controller.applyLayout(currentLayout())
        XCTAssertNil(controller.focusModel.current, "Layout refresh must retain deferred selection")
        XCTAssertFalse(selectedCell.isFocused)
        XCTAssertFalse(try cell(page: 0, slot: 0).isFocused)
        XCTAssertEqual(searchRequests, 0)
        XCTAssertEqual(surface.core.commitCount, commitsBefore)
    }

    func testPointerClearPreventsMatchingKeyboardSettleFromRestoringFocus() async throws {
        try await readyController(appCount: 40)
        let targetCell = try beginKeyboardCrossPageSettle()
        controller.clearFocusForPointerNavigation()
        XCTAssertNil(controller.focusModel.current)
        XCTAssertFalse(targetCell.isFocused)

        XCTAssertGreaterThan(settleFrames(surface), 0)
        XCTAssertEqual(surface.core.state, .idle)
        XCTAssertEqual(surface.core.committedPage, 1)
        XCTAssertNil(controller.focusModel.current, "Idle reconciliation must not restore the pending target")
        XCTAssertFalse(targetCell.isFocused)
        controller.reconcileSettledCrossPage(committedPage: 1)
        controller.refreshFocusVisual()
        try controller.applyLayout(currentLayout())
        XCTAssertNil(controller.focusModel.current)
        XCTAssertFalse(try cell(page: 1, slot: 0).isFocused)
    }

    func testPointerClearPreventsMismatchedReconciliationFromSeedingCommittedPage() async throws {
        try await readyController(appCount: 40)
        let targetCell = try beginKeyboardCrossPageSettle()
        controller.clearFocusForPointerNavigation()

        // Exercise the fallback branch while the actual committed page still differs from the target.
        controller.reconcileSettledCrossPage(committedPage: surface.core.committedPage)
        XCTAssertNil(controller.focusModel.current)
        XCTAssertFalse(targetCell.isFocused)
        XCTAssertFalse(try cell(page: 0, slot: 0).isFocused)
        settleFrames(surface)
        XCTAssertEqual(surface.core.state, .idle)
        XCTAssertNil(controller.focusModel.current)
        XCTAssertFalse(try cell(page: 1, slot: 0).isFocused)
    }

    func testActivePointerNavigationConsumesKeyDownWithoutMovingOrActivatingSelection() async throws {
        try await readyController(appCount: 40)
        try focusOn(page: 0, slot: 34)
        let selected = try XCTUnwrap(controller.focusModel.current)
        let selectedCell = try cell(page: 0, slot: 34)
        controller.isPointerPageNavigationActive = { true }
        var activations = 0
        controller.onActivate = { _ in activations += 1 }

        for keyCode in [UInt16(123), 124, 125, 126, 36, 76] {
            controller.keyDown(with: keyEvent(keyCode))
            XCTAssertEqual(controller.focusModel.current, selected)
            XCTAssertTrue(selectedCell.isFocused)
            XCTAssertEqual(surface.core.state, .idle)
            XCTAssertEqual(surface.core.committedPage, 0)
        }
        XCTAssertEqual(activations, 0)
    }

    func testActivePointerNavigationConsumesKeyEquivalentsWithoutActivation() async throws {
        try await readyController()
        let selected = try XCTUnwrap(controller.focusModel.current)
        controller.isPointerPageNavigationActive = { true }
        var activations = 0
        controller.onActivate = { _ in activations += 1 }

        for keyCode in [UInt16(123), 124, 125, 126, 36, 76] {
            XCTAssertTrue(controller.performKeyEquivalent(with: keyEvent(keyCode)))
            XCTAssertEqual(controller.focusModel.current, selected)
        }
        XCTAssertEqual(activations, 0)
        XCTAssertFalse(controller.performKeyEquivalent(with: keyEvent(0)))
        XCTAssertFalse(controller.performKeyEquivalent(with: keyEvent(48)), "Tab keeps its existing route")
    }

    func testActivePointerNavigationNeverSeedsDeferredSelectionThroughEitherEntryPoint() async throws {
        try await readyController(selected: false)
        controller.isPointerPageNavigationActive = { true }
        var activations = 0
        controller.onActivate = { _ in activations += 1 }

        for keyCode in [UInt16(123), 124, 125, 126, 36, 76] {
            XCTAssertTrue(controller.performKeyEquivalent(with: keyEvent(keyCode)))
            controller.keyDown(with: keyEvent(keyCode))
            XCTAssertNil(controller.focusModel.current)
            XCTAssertFalse(try cell(page: 0, slot: 0).isFocused)
        }
        XCTAssertEqual(activations, 0)
        XCTAssertEqual(surface.core.state, .idle)
    }

    func testFirstDirectionAfterPointerNavigationSeedsFinalCommittedPage() async throws {
        try await readyController(appCount: 75)
        var pointerNavigationActive = true
        controller.isPointerPageNavigationActive = { pointerNavigationActive }
        controller.clearFocusForPointerNavigation()

        // Use the published manual-frame fixture to change the committed page.
        // Actual pointer request/Surface ownership is tested by Main's integration suite.
        XCTAssertTrue(flingForwardOnce(surface, at: 10))
        XCTAssertEqual(surface.core.committedPage, 1)
        controller.keyDown(with: keyEvent(124))
        XCTAssertNil(controller.focusModel.current)
        XCTAssertTrue(flingForwardOnce(surface, at: 20))
        XCTAssertEqual(surface.core.committedPage, 2)
        XCTAssertNil(controller.focusModel.current)
        let finalFirstCell = try cell(page: 2, slot: 0)
        XCTAssertFalse(finalFirstCell.isFocused)

        pointerNavigationActive = false
        controller.keyDown(with: keyEvent(123))
        XCTAssertEqual(controller.focusModel.current?.pageIndex, 2)
        XCTAssertEqual(controller.focusModel.current?.slotIndex, 0, "First direction seeds without moving")
        XCTAssertTrue(finalFirstCell.isFocused)
        controller.keyDown(with: keyEvent(124))
        XCTAssertEqual(controller.focusModel.current?.pageIndex, 2)
        XCTAssertEqual(controller.focusModel.current?.slotIndex, 1)
        XCTAssertFalse(finalFirstCell.isFocused)
        XCTAssertTrue(try cell(page: 2, slot: 1).isFocused)
    }

    private func assertExistingKeyboardBehavior() throws {
        XCTAssertFalse(controller.performKeyEquivalent(with: keyEvent(124)))
        XCTAssertNil(controller.focusModel.current)
        controller.keyDown(with: keyEvent(124))
        XCTAssertEqual(controller.focusModel.current?.slotIndex, 0)
        controller.keyDown(with: keyEvent(124))
        let selected = try XCTUnwrap(controller.focusModel.current)
        XCTAssertEqual(selected.slotIndex, 1)
        XCTAssertTrue(try cell(page: 0, slot: 1).isFocused)

        var activated: [AppGridFocusIdentity] = []
        controller.onActivate = { activated.append($0) }
        for keyCode in [UInt16(36), 76] {
            controller.keyDown(with: keyEvent(keyCode))
            XCTAssertTrue(controller.performKeyEquivalent(with: keyEvent(keyCode)))
        }
        XCTAssertEqual(activated, Array(repeating: selected, count: 4))
        XCTAssertEqual(controller.focusModel.current, selected)
    }

    func testNilPointerNavigationProviderPreservesExistingKeyboardBehavior() async throws {
        try await readyController(selected: false)
        XCTAssertNil(controller.isPointerPageNavigationActive)
        try assertExistingKeyboardBehavior()
    }

    func testFalsePointerNavigationProviderPreservesExistingKeyboardBehavior() async throws {
        try await readyController(selected: false)
        controller.isPointerPageNavigationActive = { false }
        try assertExistingKeyboardBehavior()
    }

    func testEscapeAndSearchShortcutKeepTheirExistingRoutesDuringPointerNavigation() async throws {
        try await readyController()
        controller.isPointerPageNavigationActive = { true }
        let selected = controller.focusModel.current
        let selectedCell = try cell(page: 0, slot: 0)
        var searchRequests = 0
        var escapeExhaustions = 0
        controller.onSearchShortcut = { searchRequests += 1 }
        controller.onEscapeExhausted = { escapeExhaustions += 1 }

        XCTAssertTrue(controller.performKeyEquivalent(with: keyEvent(3, modifiers: .command)))
        XCTAssertEqual(searchRequests, 1)
        XCTAssertEqual(controller.focusModel.current, selected)
        XCTAssertTrue(selectedCell.isFocused)
        controller.keyDown(with: keyEvent(53))
        XCTAssertNil(controller.focusModel.current)
        XCTAssertFalse(selectedCell.isFocused)
        XCTAssertEqual(escapeExhaustions, 0)
        controller.keyDown(with: keyEvent(53))
        XCTAssertEqual(escapeExhaustions, 1)
    }

    func testFolderNavigationAndActivationRetainPriorityDuringPointerNavigation() async throws {
        try await readyController()
        let members = [CatalogFixture.appID("fixture.member0"), CatalogFixture.appID("fixture.member1")]
        let folderState = FolderOpenState()
        let folder = FolderEntry(id: FolderID(), title: "Fixture folder", members: members)
        folderState.open(folder)
        controller.folderOpenStateProvider = { folderState }
        controller.isPointerPageNavigationActive = { true }
        var activatedMembers: [AppID] = []
        var topLevelActivations = 0
        var searchRequests = 0
        controller.onActivateMember = { activatedMembers.append($0) }
        controller.onActivate = { _ in topLevelActivations += 1 }
        controller.onCloseFolder = { folderState.close() }
        controller.onSearchShortcut = { searchRequests += 1 }

        XCTAssertFalse(controller.performKeyEquivalent(with: keyEvent(124)))
        controller.keyDown(with: keyEvent(124))
        controller.keyDown(with: keyEvent(36))
        XCTAssertTrue(controller.performKeyEquivalent(with: keyEvent(76)))
        XCTAssertEqual(activatedMembers, [members[1], members[1]])
        XCTAssertEqual(topLevelActivations, 0)
        controller.keyDown(with: keyEvent(53))
        XCTAssertFalse(folderState.isOpen)

        folderState.open(folder)
        XCTAssertTrue(controller.performKeyEquivalent(with: keyEvent(3, modifiers: .command)))
        XCTAssertFalse(folderState.isOpen)
        XCTAssertEqual(searchRequests, 1)
    }

    func testTitleEditingRetainsPriorityDuringPointerNavigation() async throws {
        try await readyController()
        controller.isPointerPageNavigationActive = { true }
        controller.beginTitleEditing()
        let selected = controller.focusModel.current
        var activations = 0
        var titleCancellations = 0
        var searchRequests = 0
        controller.onActivate = { _ in activations += 1 }
        controller.onTitleCancel = { titleCancellations += 1 }
        controller.onSearchShortcut = { searchRequests += 1 }

        for keyCode in [UInt16(123), 124, 125, 126, 36, 76] {
            XCTAssertFalse(controller.performKeyEquivalent(with: keyEvent(keyCode)))
            controller.keyDown(with: keyEvent(keyCode))
            XCTAssertEqual(controller.focusModel.current, selected)
        }
        XCTAssertEqual(activations, 0)
        XCTAssertTrue(controller.performKeyEquivalent(with: keyEvent(3, modifiers: .command)))
        XCTAssertEqual(searchRequests, 1)
        controller.keyDown(with: keyEvent(53))
        XCTAssertEqual(titleCancellations, 1)
        XCTAssertEqual(controller.focusModel.current, selected)
        XCTAssertTrue(controller.performKeyEquivalent(with: keyEvent(36)))
        XCTAssertEqual(activations, 0)
    }
}
