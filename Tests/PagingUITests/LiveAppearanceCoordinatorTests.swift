import AppKit
import XCTest
@testable import PagingPrototypeApp

@MainActor
final class LiveAppearanceCoordinatorTests: XCTestCase {
    private final class Store: AppearancePreferencesPersisting {
        var value = AppearancePreferences.default
        var loadOverride: AppearancePreferencesLoadResult?
        var result = AppearancePreferencesSaveResult.saved
        var writes: [AppearancePreferences] = []
        var onSave: (() -> Void)?
        func load() -> AppearancePreferencesLoadResult { loadOverride ?? .loaded(value) }
        func save(_ value: AppearancePreferences) -> AppearancePreferencesSaveResult {
            writes.append(value)
            let callback = onSave; onSave = nil; callback?()
            if result == .saved { self.value = value; loadOverride = nil }
            return result
        }
    }
    private final class Clock {
        var callbacks: [@MainActor () -> Void] = []
        var cancellations = 0
        var canceled = Set<Int>()
        func schedule(_ body: @escaping @MainActor () -> Void) -> (() -> Void) {
            let index = callbacks.count
            callbacks.append(body)
            return { [weak self] in self?.cancellations += 1; self?.canceled.insert(index) }
        }
    }
    private func value(_ n: Int) -> AppearancePreferences {
        .init(showsAppLabels: n % 2 == 0, wallpaperBlurRadius: n % 61,
              preferredIconSide: 32 + n % 33, appLabelFontSize: 9 + n % 8)
    }

    func testTwoHundredLiveIntentsPreviewImmediatelyAndPersistOnlyLatest() {
        let store = Store(), clock = Clock()
        let base = AppearanceSettingsCoordinator(store: store) { _ in }
        let live = LiveAppearanceSettingsCoordinator(persistence: base, schedule: clock.schedule)
        var previews: [AppearancePreferences] = []
        live.onPreview = { previews.append($0) }
        for n in 1...200 { XCTAssertTrue(live.submit(value(n))) }
        XCTAssertEqual(previews.count, 200)
        XCTAssertTrue(store.writes.isEmpty)
        XCTAssertTrue(live.requiresQuitProtection)
        for callback in clock.callbacks { callback() }
        XCTAssertEqual(store.writes, [value(200)])
        XCTAssertEqual(live.state, .saved)
        XCTAssertFalse(live.requiresQuitProtection)
    }

    func testFlushOnDismissDoesNotRollbackAndOldScheduledCallbackCannotSaveAgain() {
        let store = Store(), clock = Clock()
        let live = LiveAppearanceSettingsCoordinator(
            persistence: AppearanceSettingsCoordinator(store: store) { _ in }, schedule: clock.schedule)
        XCTAssertTrue(live.submit(value(2)))
        XCTAssertEqual(live.flush(), .saved)
        for callback in clock.callbacks { callback() }
        XCTAssertEqual(store.writes, [value(2)])
        XCTAssertEqual(live.requested, value(2))
    }

    func testFailureKeepsIntentPreviewAndQuitProtectionUntilExplicitRetrySucceeds() {
        let store = Store(), clock = Clock()
        store.result = .encodingFailed
        let live = LiveAppearanceSettingsCoordinator(
            persistence: AppearanceSettingsCoordinator(store: store) { _ in }, schedule: clock.schedule)
        XCTAssertTrue(live.submit(value(3)))
        XCTAssertEqual(live.flush(), .encodingFailed)
        XCTAssertEqual(live.requested, value(3))
        XCTAssertEqual(live.state, .failed)
        XCTAssertTrue(live.requiresQuitProtection)
        XCTAssertEqual(store.value, .default)
        store.result = .saved
        XCTAssertEqual(live.retry(value(3)), .saved)
        XCTAssertFalse(live.requiresQuitProtection)
        XCTAssertEqual(store.value, value(3))
    }

    func testCorruptRequiresExplicitRecoveryAndFutureBlocksLiveWrites() {
        let store = Store(), clock = Clock()
        store.loadOverride = .corrupt
        let live = LiveAppearanceSettingsCoordinator(
            persistence: AppearanceSettingsCoordinator(store: store) { _ in }, schedule: clock.schedule)
        XCTAssertFalse(live.submit(value(4)))
        XCTAssertTrue(store.writes.isEmpty)
        XCTAssertFalse(live.requiresQuitProtection)
        XCTAssertEqual(live.state, .recoveryRequired)
        XCTAssertEqual(live.retry(value(4)), .saved)
        store.loadOverride = .futureVersion(900)
        XCTAssertFalse(live.submit(value(5)))
        XCTAssertEqual(live.state, .protected)
        XCTAssertEqual(store.writes.count, 1)
    }

    func testExternalFutureBetweenPreviewAndFlushNeverAcknowledgesSave() {
        let store = Store(), clock = Clock()
        let live = LiveAppearanceSettingsCoordinator(
            persistence: AppearanceSettingsCoordinator(store: store) { _ in }, schedule: clock.schedule)
        XCTAssertTrue(live.submit(value(6)))
        store.loadOverride = .futureVersion(42)
        XCTAssertEqual(live.flush(), .futureVersion(42))
        XCTAssertEqual(live.state, .protected)
        XCTAssertTrue(live.requiresQuitProtection)
        XCTAssertTrue(store.writes.isEmpty)
    }

    func testNewCorruptionAfterPreviewRequiresExplicitRecoveryBeforeWrite() {
        let store = Store(), clock = Clock()
        let live = LiveAppearanceSettingsCoordinator(
            persistence: AppearanceSettingsCoordinator(store: store) { _ in }, schedule: clock.schedule)
        XCTAssertTrue(live.submit(value(12)))
        store.loadOverride = .corrupt
        XCTAssertEqual(live.flush(), .encodingFailed)
        XCTAssertTrue(store.writes.isEmpty)
        XCTAssertEqual(live.state, .recoveryRequired)
        XCTAssertTrue(live.requiresQuitProtection)
        XCTAssertEqual(live.retry(value(12)), .saved)
        XCTAssertEqual(store.value, value(12))
    }

    func testNewIntentDuringSaveCannotBeOverwrittenByOlderReceipt() {
        let store = Store(), clock = Clock()
        let live = LiveAppearanceSettingsCoordinator(
            persistence: AppearanceSettingsCoordinator(store: store) { _ in }, schedule: clock.schedule)
        XCTAssertTrue(live.submit(value(7)))
        store.onSave = { XCTAssertTrue(live.submit(self.value(8))) }
        XCTAssertEqual(live.flush(), .saved)
        XCTAssertEqual(live.requested, value(8))
        XCTAssertEqual(live.state, .pending)
        XCTAssertTrue(live.requiresQuitProtection)
        XCTAssertEqual(live.flush(), .saved)
        XCTAssertEqual(store.value, value(8))
    }

    func testNestedFlushCannotCancelNewestDebounceOrAcknowledgeItsUnsavedValue() {
        let store = Store(), clock = Clock()
        let live = LiveAppearanceSettingsCoordinator(
            persistence: AppearanceSettingsCoordinator(store: store) { _ in }, schedule: clock.schedule)
        XCTAssertTrue(live.submit(value(10)))
        store.onSave = {
            XCTAssertTrue(live.submit(self.value(11)))
            XCTAssertNotEqual(live.flush(), .saved)
        }
        _ = live.flush()
        for (index, callback) in clock.callbacks.enumerated() where !clock.canceled.contains(index) { callback() }
        XCTAssertEqual(store.value, value(11))
        XCTAssertFalse(live.requiresQuitProtection)
    }

    func testInvalidAndSilentInitialStateDoNotWriteOrArmWork() {
        let store = Store(), clock = Clock()
        let live = LiveAppearanceSettingsCoordinator(
            persistence: AppearanceSettingsCoordinator(store: store) { _ in }, schedule: clock.schedule)
        XCTAssertEqual(live.state, .idle)
        XCTAssertTrue(live.submit(.default))
        XCTAssertFalse(live.submit(.init(wallpaperBlurRadius: 999)))
        XCTAssertTrue(clock.callbacks.isEmpty)
        XCTAssertTrue(store.writes.isEmpty)
        XCTAssertFalse(live.requiresQuitProtection)
    }

    func testInvalidateFlushesAcceptedLatestAndRevokesPreviewCallbacks() {
        let store = Store(), clock = Clock()
        let live = LiveAppearanceSettingsCoordinator(
            persistence: AppearanceSettingsCoordinator(store: store) { _ in }, schedule: clock.schedule)
        XCTAssertTrue(live.submit(value(9)))
        live.invalidate()
        XCTAssertEqual(store.writes, [value(9)])
        XCTAssertFalse(live.submit(value(10)))
        for callback in clock.callbacks { callback() }
        XCTAssertEqual(store.writes.count, 1)
    }
}
