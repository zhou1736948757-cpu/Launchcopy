import AppCatalogCore
import AppGridUI
import AppIconPipeline
import AppKit
import LauncherLocalization
import XCTest
@testable import PagingPrototypeApp

/// Synthetic detached controls only. Main serializes execution with the owner
/// integration suite; these assertions do not establish physical entry latency.
@MainActor
final class LibraryGalleryPreparationTests: XCTestCase {
    private let strings = LocalizedStrings(language: .english)

    private func entry(_ index: Int, category: AppLibraryCategory = .utilities,
                       name: String? = nil, manual: AppLibraryCategory? = nil) -> AppLibraryEntry {
        let id = AppID.bundleIdentifier("fixture.gallery.preparation.\(index)")
        let record = AppRecord(id: id, displayName: "Preparation \(index)",
            bundleIdentifier: "fixture.gallery.preparation.\(index)",
            canonicalURL: URL(fileURLWithPath: "/SyntheticPreparation/App\(index).app"),
            iconIdentity: .from(appID: id), sourceRootPriority: 0)
        return .init(record: record, displayName: name ?? record.displayName,
            category: category, manualCategory: manual)
    }

    private func gallery() -> AppLibraryGalleryView {
        AppLibraryGalleryView(frame: .init(x: 0, y: 0, width: 1000, height: 700))
    }

    // Keep the pool private in production. Reflection is confined to the identity
    // assertions, which must observe prepared objects before normal consumption.
    private func pool(_ gallery: AppLibraryGalleryView) throws -> [LibraryCategoryCard] {
        let optional = try XCTUnwrap(Mirror(reflecting: gallery).descendant("preparedCards"))
        let value = try XCTUnwrap(Mirror(reflecting: optional).children.first?.value)
        return try XCTUnwrap(Mirror(reflecting: value).descendant("cards") as? [LibraryCategoryCard])
    }

    private func assertPrepared(_ gallery: AppLibraryGalleryView, entries: [AppLibraryEntry]) async {
        let completed = await gallery.prepareCards(entries: entries, strings: strings, shouldContinue: { true })
        XCTAssertTrue(completed)
        XCTAssertTrue(gallery.hasPreparedCards)
        XCTAssertTrue(gallery.cards.isEmpty)
    }

    func testIdlePoolAlreadyHasUsableNativeControlGeometryBeforeEntry() async throws {
        let gallery = gallery()
        let entries = (0..<8).map { entry($0) } + [entry(20, category: .games)]
        await assertPrepared(gallery, entries: entries)
        let prepared = try pool(gallery)
        XCTAssertEqual(prepared.count, 2)
        for card in prepared {
            XCTAssertGreaterThan(card.frame.width, 0, "First live entry must not be the first layout")
            XCTAssertGreaterThan(card.frame.height, 0)
            for button in card.iconButtons {
                XCTAssertGreaterThan(button.frame.width, 0)
                XCTAssertGreaterThan(button.frame.height, 0)
            }
            XCTAssertNil(card.window)
            XCTAssertNil(card.superview)
            XCTAssertTrue(card.isAccessibilityHidden())
        }
        XCTAssertTrue(gallery.cards.isEmpty)
    }

    func testMatchingPoolConsumesExactObjectsOnlyOnceAndKeepsTaxonomyOrder() async throws {
        let gallery = gallery()
        let entries = [entry(1), entry(2, category: .games), entry(3)]
        await assertPrepared(gallery, entries: entries)
        let prepared = try pool(gallery)
        XCTAssertEqual(prepared.map(\.category), [.games, .utilities])
        let buttons = prepared.map { $0.iconButtons[0] }

        gallery.apply(entries: entries, strings: strings, generation: 41, pipeline: nil)
        XCTAssertFalse(gallery.hasPreparedCards)
        XCTAssertEqual(gallery.cards.count, prepared.count)
        for (current, previous) in zip(gallery.cards, prepared) { XCTAssertTrue(current === previous) }
        for (card, button) in zip(gallery.cards, buttons) { XCTAssertTrue(card.iconButtons[0] === button) }

        gallery.apply(entries: entries, strings: strings, generation: 42, pipeline: nil)
        for (current, previous) in zip(gallery.cards, prepared) { XCTAssertFalse(current === previous) }
        XCTAssertFalse(gallery.hasPreparedCards)
    }

    func testFullEntryEqualityAndLanguageAreRequiredRatherThanOnlyIDs() async throws {
        let original = [entry(1), entry(2)]
        let variants: [([AppLibraryEntry], LocalizedStrings)] = [
            ([entry(1, name: "Changed alias"), entry(2)], strings),
            ([entry(1, manual: .utilities), entry(2)], strings),
            ([entry(1, category: .games), entry(2)], strings),
            (Array(original.reversed()), strings),
            ([entry(1)], strings),
            (original, .init(language: .japanese))
        ]
        for (entries, language) in variants {
            let gallery = gallery()
            await assertPrepared(gallery, entries: original)
            let prepared = try pool(gallery)
            gallery.apply(entries: entries, strings: language, generation: 1, pipeline: nil)
            XCTAssertFalse(gallery.hasPreparedCards)
            XCTAssertTrue(gallery.cards.allSatisfy { current in !prepared.contains { $0 === current } })
            XCTAssertEqual(gallery.cards.flatMap(\.entries).count, entries.count)
        }
    }

    func testEmptyLoadingApplyRetainsPoolWithoutPublishingControlsOrActions() async throws {
        let gallery = gallery()
        let entries = (0..<8).map { entry($0) }
        var actions = 0
        gallery.onOpen = { _ in actions += 1 }
        gallery.onDetails = { _ in actions += 1 }
        await assertPrepared(gallery, entries: entries)
        let prepared = try XCTUnwrap(pool(gallery).first)
        gallery.apply(entries: [], strings: strings, generation: 1, pipeline: nil)
        XCTAssertTrue(gallery.hasPreparedCards)
        XCTAssertTrue(gallery.cards.isEmpty)
        XCTAssertNil(prepared.superview)
        XCTAssertFalse(prepared.accessibilityPerformPress())
        for button in prepared.iconButtons {
            XCTAssertFalse(button.isEnabled)
            button.performClick(nil)
            button.onActivate?()
            button.onDetails?()
        }
        XCTAssertEqual(actions, 0)
        gallery.apply(entries: entries, strings: strings, generation: 2, pipeline: nil)
        XCTAssertTrue(gallery.cards.first === prepared)
        XCTAssertFalse(gallery.hasPreparedCards)
    }

    func testPreparationHasNoIconsGalleryCallbacksHostOrAccessibilityAdmission() async throws {
        let gallery = gallery()
        let pipeline = IconPipeline(loader: RecordingIconLoader(), limits: .init())
        defer { gallery.discardPreparation(); pipeline.shutdown() }
        // A retained pipeline from a previous empty presentation must stay idle.
        gallery.apply(entries: [], strings: strings, generation: 1, pipeline: pipeline)
        let host = NSView(frame: gallery.frame)
        var actions = 0
        gallery.onOpen = { _ in actions += 1 }
        gallery.onDetails = { _ in actions += 1 }
        let entries = (0..<8).map { entry($0) } + [entry(20, category: .games)]
        var admissions = 0
        let completed = await gallery.prepareCards(entries: entries, strings: strings) {
            admissions += 1
            XCTAssertFalse(gallery.hasPreparedCards, "No partial pool is published")
            XCTAssertTrue(gallery.cards.isEmpty)
            XCTAssertNil(gallery.window)
            XCTAssertTrue(host.subviews.isEmpty)
            gallery.synchronizeIcons()
            XCTAssertEqual(pipeline.stats.requests, 0)
            return true
        }
        XCTAssertTrue(completed)
        XCTAssertEqual(admissions, 6, "Initial/final guards plus guards around one yield per category")
        for card in try pool(gallery) {
            XCTAssertNil(card.superview)
            XCTAssertNil(card.window)
            XCTAssertTrue(card.isAccessibilityHidden())
            XCTAssertNil(card.entryProfile)
            XCTAssertNil(card.onOpen)
            XCTAssertNil(card.onDetails)
            XCTAssertEqual(card.accessibilityRole(), .group)
            XCTAssertFalse(card.accessibilityPerformPress())
            for button in card.iconButtons {
                XCTAssertFalse(button.isEnabled)
                XCTAssertNil(button.entryProfile)
                XCTAssertNotNil(button.image, "Only the generic placeholder is constructed")
                XCTAssertEqual(button.accessibilityLabel(), button.entry.displayName)
                XCTAssertFalse(button.refusesFirstResponder)
                button.performClick(nil)
                button.onActivate?()
                button.onDetails?()
            }
        }
        XCTAssertEqual(actions, 0)
        XCTAssertEqual(pipeline.stats.requests, 0)
        XCTAssertTrue(host.subviews.isEmpty)
    }

    func testAdmissionRejectsBeforeAndAfterYieldAndAfterLocalCardConstruction() async {
        let entries = [entry(1), entry(2, category: .games)]
        // 1: entry; 2/3: first yield; 4/5: second yield; 6: publish.
        for rejectedAdmission in 1...6 {
            let gallery = gallery()
            var admissions = 0
            let completed = await gallery.prepareCards(entries: entries, strings: strings) {
                admissions += 1
                return admissions != rejectedAdmission
            }
            XCTAssertFalse(completed)
            XCTAssertEqual(admissions, rejectedAdmission)
            XCTAssertFalse(gallery.hasPreparedCards)
            XCTAssertTrue(gallery.cards.isEmpty)
        }
    }

    func testTaskCancellationAfterYieldCannotPublishLocalPool() async {
        let gallery = gallery()
        var admissions = 0
        let task = Task { @MainActor in
            await gallery.prepareCards(entries: [self.entry(1)], strings: self.strings) {
                admissions += 1
                if admissions == 3 { withUnsafeCurrentTask { $0?.cancel() } }
                return true
            }
        }
        let completed = await task.value
        XCTAssertFalse(completed)
        XCTAssertEqual(admissions, 3)
        XCTAssertFalse(gallery.hasPreparedCards)
        XCTAssertTrue(gallery.cards.isEmpty)
    }

    func testDiscardAfterYieldRevokesLocalWorkAndAllowsFreshPreparation() async throws {
        let gallery = gallery()
        var admissions = 0
        let completed = await gallery.prepareCards(entries: [entry(1), entry(2, category: .games)], strings: strings) {
            admissions += 1
            // The second post-yield guard runs with one local card already built.
            if admissions == 5 { gallery.discardPreparation() }
            return true
        }
        XCTAssertFalse(completed)
        XCTAssertEqual(admissions, 5)
        XCTAssertFalse(gallery.hasPreparedCards)
        await assertPrepared(gallery, entries: [entry(3)])
        let prepared = try XCTUnwrap(pool(gallery).first)
        gallery.discardPreparation()
        XCTAssertFalse(gallery.hasPreparedCards)
        gallery.apply(entries: [entry(3)], strings: strings, generation: 2, pipeline: nil)
        XCTAssertFalse(gallery.cards.first === prepared)
    }

    func testEntryDuringYieldWinsOverSuspendedPreparation() async {
        let gallery = gallery()
        let entries = [entry(1), entry(2, category: .games)]
        var admissions = 0
        var presented: [LibraryCategoryCard] = []
        let completed = await gallery.prepareCards(entries: entries, strings: strings) {
            admissions += 1
            if admissions == 5 {
                gallery.apply(entries: entries, strings: self.strings, generation: 99, pipeline: nil)
                presented = gallery.cards
            }
            return true
        }
        XCTAssertFalse(completed)
        XCTAssertFalse(gallery.hasPreparedCards)
        XCTAssertEqual(presented.count, 2)
        for (current, prior) in zip(gallery.cards, presented) { XCTAssertTrue(current === prior) }
    }

    func testEmptyApplyDuringYieldInvalidatesUnfinishedPreparation() async {
        let gallery = gallery()
        var admissions = 0
        let completed = await gallery.prepareCards(entries: [entry(1)], strings: strings) {
            admissions += 1
            if admissions == 3 {
                gallery.apply(entries: [], strings: self.strings, generation: 1, pipeline: nil)
            }
            return true
        }
        XCTAssertFalse(completed)
        XCTAssertFalse(gallery.hasPreparedCards)
        XCTAssertTrue(gallery.cards.isEmpty)
    }

    func testResetDuringYieldAndAfterCompletionDiscardsPreparation() async {
        let view = AppLibraryView(frame: .init(x: 0, y: 0, width: 1000, height: 700), strings: strings)
        defer { view.reset() }
        var admissions = 0
        let completed = await view.galleryView.prepareCards(entries: [entry(1)], strings: strings) {
            admissions += 1
            if admissions == 3 { view.reset() }
            return true
        }
        XCTAssertFalse(completed)
        XCTAssertFalse(view.galleryView.hasPreparedCards)
        await assertPrepared(view.galleryView, entries: [entry(1)])
        view.reset()
        XCTAssertFalse(view.galleryView.hasPreparedCards)
        XCTAssertTrue(view.galleryView.cards.isEmpty)
    }

    func testAttachedOrAlreadyPresentedGalleryRejectsPreparation() async {
        let gallery = gallery()
        let window = NSWindow(contentRect: gallery.frame, styleMask: [.titled], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        window.contentView = gallery
        defer { window.contentView = nil; window.close() }
        var admissions = 0
        let attached = await gallery.prepareCards(entries: [entry(1)], strings: strings) {
            admissions += 1
            return true
        }
        XCTAssertFalse(attached)
        XCTAssertEqual(admissions, 0)
        window.contentView = nil
        gallery.apply(entries: [entry(1)], strings: strings, generation: 1, pipeline: nil)
        let presented = await gallery.prepareCards(entries: [entry(1)], strings: strings) { true }
        XCTAssertFalse(presented)
        XCTAssertFalse(gallery.hasPreparedCards)
    }

    func testPreparedControlsUseFreshSessionRequestAndOldControlsStayRevoked() async throws {
        let view = AppLibraryView(frame: .init(x: 0, y: 0, width: 1000, height: 700), strings: strings)
        defer { view.reset() }
        let entries = (0..<8).map { entry($0) }
        var requests: [AppLibraryActionRequest] = []
        view.onOpen = { requests.append($0) }
        await assertPrepared(view.galleryView, entries: entries)
        let prepared = try XCTUnwrap(pool(view.galleryView).first)
        for button in prepared.iconButtons {
            XCTAssertFalse(button.isEnabled)
            button.performClick(nil)
            button.onActivate?()
            button.onDetails?()
        }
        XCTAssertTrue(requests.isEmpty)
        func apply(_ generation: UInt64) {
            view.apply(snapshot: .init(revision: .init(generation), entries: entries, counts: [.utilities: entries.count]),
                isLoading: false, catalogIsEmpty: false, actionGeneration: generation)
            view.layoutSubtreeIfNeeded()
        }
        apply(51)
        XCTAssertTrue(view.galleryView.cards.first === prepared)
        XCTAssertTrue(prepared.iconButtons.allSatisfy(\.isEnabled))
        prepared.iconButtons[3].performClick(nil)
        XCTAssertEqual(requests, [.init(record: entries[3].record, catalogRevision: .init(51), generation: 51)])
        view.reset()
        await assertPrepared(view.galleryView, entries: entries)
        apply(52)
        XCTAssertFalse(view.galleryView.cards.first === prepared)
        XCTAssertTrue(prepared.isAccessibilityHidden())
        XCTAssertNil(prepared.onOpen)
        XCTAssertNil(prepared.onDetails)
        for button in prepared.iconButtons {
            XCTAssertFalse(button.isEnabled)
            button.performClick(nil)
            button.onActivate?()
            button.onDetails?()
        }
        XCTAssertEqual(requests.count, 1)
        XCTAssertNil(view.selectedCategory)
        XCTAssertFalse(view.detailsOpen)
        let current = try XCTUnwrap(view.galleryView.cards.first)
        current.iconButtons[6].performClick(nil)
        XCTAssertEqual(requests.last, .init(record: entries[6].record, catalogRevision: .init(52), generation: 52))
        // Same-generation rebinds must also revoke retained prepared controls.
        apply(52)
        XCTAssertNil(current.onOpen)
        XCTAssertNil(current.onDetails)
        for button in current.iconButtons {
            XCTAssertFalse(button.isEnabled)
            button.onActivate?()
            button.onDetails?()
        }
        XCTAssertEqual(requests.count, 2)
        XCTAssertNil(view.selectedCategory)
        XCTAssertFalse(view.detailsOpen)
    }
}
