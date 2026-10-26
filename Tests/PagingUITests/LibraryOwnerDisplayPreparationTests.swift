import AppCatalogCore
import AppGridUI
import AppIconPipeline
import AppKit
import LauncherLocalization
import XCTest
@testable import PagingPrototypeApp

private actor DisplayPreparationStore: AppLibraryPersisting {
    func load() -> AppLibraryLoadResult { .loaded(.init(enabled: true)) }
    func save(_ preferences: AppLibraryPreferences, recoveringCorruptPayload: Bool) -> AppLibrarySaveResult { .saved }
}

/// Visibility is admission only; these windows are never ordered or activated.
private final class DisplayPreparationWindow: NSWindow {
    var reportsVisible = true
    override var isVisible: Bool { reportsVisible }
}

@MainActor
final class LibraryOwnerDisplayPreparationTests: XCTestCase {
    @MainActor
    private final class Fixture {
        let host = NSView(frame: .init(x: 0, y: 0, width: 1000, height: 700))
        let window: DisplayPreparationWindow
        let preferences = AppLibraryPreferencesCoordinator(store: DisplayPreparationStore())
        let pipeline = IconPipeline(loader: RecordingIconLoader(), limits: .init())
        let owner: AppLibraryOwnerController
        let profile = LibraryEntryProfile()
        var ready = true
        var layerPreparations = 0
        var catalog: CatalogSnapshot

        init(visible: Bool = true) {
            window = DisplayPreparationWindow(contentRect: host.bounds, styleMask: [.titled], backing: .buffered, defer: false)
            window.isReleasedWhenClosed = false
            window.reportsVisible = visible
            window.contentView = host
            catalog = .init(revision: .init(1), records: (0..<3).map { index in
                let id = AppID.bundleIdentifier("fixture.display.prepared.\(index)")
                return .init(id: id, displayName: "Display Fixture \(index)", bundleIdentifier: nil,
                    canonicalURL: URL(fileURLWithPath: "/SyntheticDisplay/\(index).app"),
                    iconIdentity: .from(appID: id), sourceRootPriority: 0)
            })
            owner = .init(preferences: preferences, strings: .init(language: .english), iconPipeline: pipeline)
            owner.entryProfile = profile
            owner.catalogProvider = { [weak self] in self?.catalog }
            owner.canTransition = { [weak self] in self?.ready == true }
            owner.captureGrid = { .init(query: "", page: 0, selection: nil, searchWasFocused: false) }
            owner.prepareGridLayerBackings = { [weak self] in self?.layerPreparations += 1; return 0 }
            owner.attach(to: host, showsEntryButton: false)
        }

        func teardown() {
            owner.teardown()
            pipeline.shutdown()
            window.contentView = nil
            window.close()
        }
    }

    private func eventually(_ condition: () -> Bool, file: StaticString = #filePath, line: UInt = #line) async throws {
        let deadline = ContinuousClock.now.advanced(by: .seconds(8))
        while !condition(), ContinuousClock.now < deadline { try await Task.sleep(for: .milliseconds(2)) }
        XCTAssertTrue(condition(), file: file, line: line)
    }

    private func assertIconsPrepared(_ f: Fixture, file: StaticString = #filePath, line: UInt = #line) throws {
        let optional = try XCTUnwrap(Mirror(reflecting: f.owner).descendant("preparedView"))
        let prepared = try XCTUnwrap(Mirror(reflecting: optional).children.first?.value as? AppLibraryView)
        let poolOptional = try XCTUnwrap(Mirror(reflecting: prepared.galleryView).descendant("preparedCards"))
        let pool = try XCTUnwrap(Mirror(reflecting: poolOptional).children.first?.value)
        let cards = try XCTUnwrap(Mirror(reflecting: pool).descendant("cards") as? [LibraryCategoryCard])
        let buttons = cards.flatMap(\.iconButtons)
        XCTAssertGreaterThan(prepared.galleryView.bounds.width, 0, file: file, line: line)
        XCTAssertGreaterThan(prepared.galleryView.bounds.height, 0, file: file, line: line)
        XCTAssertTrue(buttons.allSatisfy { $0.bounds.width > 0 && $0.bounds.height > 0 }, file: file, line: line)
        XCTAssertGreaterThan(f.pipeline.stats.requests, 0,
            "Native button subview counts: \(buttons.map { $0.subviews.count })", file: file, line: line)
    }

    func testVisibleIdlePreDisplayRemainsDetachedInertAndRunsOncePerEnvironment() async throws {
        let f = Fixture(); defer { f.teardown() }
        await f.preferences.loadIfNeeded()
        try await eventually { f.owner.hasPreparedDisplay }
        XCTAssertTrue(f.owner.hasPreparedCards)
        XCTAssertFalse(f.owner.isOpen)
        XCTAssertNil(f.owner.view)
        XCTAssertTrue(f.host.subviews.isEmpty)
        XCTAssertNil(f.window.firstResponder as? NSTextView)
        try assertIconsPrepared(f)
        let requests = f.pipeline.stats.requests
        let layers = f.layerPreparations
        for _ in 0..<20 { f.owner.refreshReadiness() }
        try await Task.sleep(for: .milliseconds(250))
        XCTAssertEqual(f.pipeline.stats.requests, requests)
        XCTAssertEqual(f.layerPreparations, layers)
        XCTAssertTrue(f.owner.hasPreparedDisplay)
    }

    func testHiddenWindowDoesNoIconDisplayWorkAndResumesAfterReadiness() async throws {
        let f = Fixture(visible: false); defer { f.teardown() }
        await f.preferences.loadIfNeeded()
        try await eventually { f.owner.hasPreparedCards }
        try await Task.sleep(for: .milliseconds(250))
        XCTAssertFalse(f.owner.hasPreparedDisplay)
        XCTAssertEqual(f.pipeline.stats.requests, 0)
        f.window.reportsVisible = true
        f.owner.refreshReadiness()
        try await eventually { f.owner.hasPreparedDisplay }
        try assertIconsPrepared(f)
        XCTAssertTrue(f.host.subviews.isEmpty)
    }

    func testRealInputCanConsumePoolDuringQuietPeriodWithoutWaitingForDisplay() async throws {
        let f = Fixture(); defer { f.teardown() }
        await f.preferences.loadIfNeeded()
        try await eventually { f.owner.hasPreparedCards }
        f.ready = false
        f.owner.suspendPreparationForInput()
        f.ready = true
        XCTAssertTrue(f.owner.enter(preview: true))
        XCTAssertTrue(f.owner.isOpen)
        XCTAssertTrue(f.owner.isPreviewing)
        XCTAssertFalse(f.owner.hasPreparedDisplay)
        let requests = f.pipeline.stats.requests
        f.ready = false
        f.owner.cancelPreview()
        try await Task.sleep(for: .milliseconds(250))
        XCTAssertEqual(f.pipeline.stats.requests, requests)
        XCTAssertTrue(f.host.subviews.isEmpty)
    }

    func testResizeAndReplacementPoolInvalidateDisplayReadiness() async throws {
        let f = Fixture(); defer { f.teardown() }
        await f.preferences.loadIfNeeded()
        try await eventually { f.owner.hasPreparedDisplay }
        let layers = f.layerPreparations
        f.host.setFrameSize(.init(width: 800, height: 650))
        XCTAssertFalse(f.owner.hasPreparedDisplay)
        f.owner.layout(searchFrame: .init(x: 200, y: 600, width: 400, height: 28))
        try await eventually { f.owner.hasPreparedDisplay }
        XCTAssertGreaterThan(f.layerPreparations, layers)
        XCTAssertTrue(f.owner.enter(preview: true))
        f.owner.cancelPreview()
        XCTAssertFalse(f.owner.hasPreparedDisplay, "The old controls were consumed and revoked")
        try await eventually { f.owner.hasPreparedDisplay }
        XCTAssertTrue(f.host.subviews.isEmpty)
    }

    func testDetachedCardsUseDestinationAppearanceThenRestoreLiveInheritance() async throws {
        let f = Fixture(); defer { f.teardown() }
        f.host.appearance = try XCTUnwrap(NSAppearance(named: .aqua))
        await f.preferences.loadIfNeeded()
        try await eventually { f.owner.hasPreparedDisplay }
        let optional = try XCTUnwrap(Mirror(reflecting: f.owner).descendant("preparedView"))
        let prepared = try XCTUnwrap(Mirror(reflecting: optional).children.first?.value as? AppLibraryView)
        let poolOptional = try XCTUnwrap(Mirror(reflecting: prepared.galleryView).descendant("preparedCards"))
        let pool = try XCTUnwrap(Mirror(reflecting: poolOptional).children.first?.value)
        let cards = try XCTUnwrap(Mirror(reflecting: pool).descendant("cards") as? [LibraryCategoryCard])
        XCTAssertFalse(cards.isEmpty)
        for card in cards { XCTAssertEqual(card.appearance?.name, f.host.effectiveAppearance.name) }
        XCTAssertTrue(f.owner.enter(preview: true))
        try await eventually { f.owner.view?.galleryView.cards.isEmpty == false }
        for card in try XCTUnwrap(f.owner.view).galleryView.cards { XCTAssertNil(card.appearance) }
    }

    func testInvalidationAndTeardownCannotPublishLateDisplayReadiness() async throws {
        let f = Fixture()
        await f.preferences.loadIfNeeded()
        try await eventually { f.owner.hasPreparedCards }
        f.owner.invalidateSourceTargets()
        XCTAssertFalse(f.owner.hasPreparedDisplay)
        XCTAssertFalse(f.owner.hasPreparedCards)
        f.teardown()
        try await Task.sleep(for: .milliseconds(250))
        XCTAssertFalse(f.owner.hasPreparedDisplay)
        XCTAssertFalse(f.owner.hasPreparedPresentation)
        XCTAssertTrue(f.host.subviews.isEmpty)
    }
}
