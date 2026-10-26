import XCTest
import LauncherLocalization
@testable import PagingPrototypeApp

@MainActor
final class LanguagePresentationControllerTests: XCTestCase {
    func testRequestCoalescesOutsideCallerAndLatestWins() {
        var callbacks: [@MainActor () -> Void] = []
        var presented: [InterfaceLanguage] = []
        let owner = LanguagePresentationController(preference: .english,
            preferredLanguages: { ["en"] }, isReady: { true }, schedule: { callbacks.append($0) })
        owner.onPresent = { presented.append($0) }
        owner.request(.simplifiedChinese)
        owner.request(.japanese)
        XCTAssertEqual(callbacks.count, 1)
        XCTAssertEqual(owner.state, .queued)
        XCTAssertEqual(owner.displayedLanguage, .english)
        XCTAssertTrue(presented.isEmpty)
        callbacks.removeFirst()()
        XCTAssertEqual(presented, [.japanese])
        XCTAssertEqual(owner.state, .applied)
    }

    func testOverlappingSameKindOwnersAndFinalReleaseDoNotNeedMoreInput() {
        var callbacks: [@MainActor () -> Void] = []
        let owner = LanguagePresentationController(preference: .english,
            preferredLanguages: { [] }, isReady: { true }, schedule: { callbacks.append($0) })
        let sheet1 = owner.acquire(.modal), sheet2 = owner.acquire(.modal)
        owner.request(.japanese)
        XCTAssertTrue(callbacks.isEmpty)
        owner.release(sheet1); owner.release(sheet1)
        XCTAssertTrue(callbacks.isEmpty)
        owner.release(sheet2)
        XCTAssertEqual(callbacks.count, 1)
        callbacks.removeFirst()()
        XCTAssertEqual(owner.displayedLanguage, .japanese)
    }

    func testReacquiredOwnerBeforeCallbackDefersUntilRealRelease() {
        var callbacks: [@MainActor () -> Void] = []
        let owner = LanguagePresentationController(preference: .english,
            preferredLanguages: { [] }, isReady: { true }, schedule: { callbacks.append($0) })
        owner.request(.japanese)
        let token = owner.acquire(.pointer)
        callbacks.removeFirst()()
        XCTAssertEqual(owner.displayedLanguage, .english)
        XCTAssertEqual(owner.state, .queued)
        owner.release(token)
        XCTAssertEqual(callbacks.count, 1)
        callbacks.removeFirst()()
        XCTAssertEqual(owner.state, .applied)
    }

    func testExternalReadinessRequiresNotificationAndIsRechecked() {
        var ready = false
        var callbacks: [@MainActor () -> Void] = []
        let owner = LanguagePresentationController(preference: .english,
            preferredLanguages: { [] }, isReady: { ready }, schedule: { callbacks.append($0) })
        owner.request(.japanese)
        XCTAssertTrue(callbacks.isEmpty)
        ready = true; owner.readinessDidChange()
        XCTAssertEqual(callbacks.count, 1)
        ready = false; callbacks.removeFirst()()
        XCTAssertEqual(owner.state, .queued)
        ready = true; owner.readinessDidChange(); callbacks.removeFirst()()
        XCTAssertEqual(owner.displayedLanguage, .japanese)
    }

    func testReturnToDisplayedCancelsPendingWithoutRelabeling() {
        var callbacks: [@MainActor () -> Void] = []
        var presentations = 0
        let owner = LanguagePresentationController(preference: .english,
            preferredLanguages: { [] }, isReady: { true }, schedule: { callbacks.append($0) })
        owner.onPresent = { _ in presentations += 1 }
        owner.request(.japanese); owner.request(.english)
        XCTAssertEqual(owner.state, .applied)
        callbacks.removeFirst()()
        XCTAssertEqual(presentations, 0)
        XCTAssertNil(owner.pendingLanguage)
    }

    func testEqualFollowSystemResolvesNewLanguageAndUnchangedIsNoRelabel() {
        var preferred = ["en"]
        var callbacks: [@MainActor () -> Void] = []
        let owner = LanguagePresentationController(preference: .system,
            preferredLanguages: { preferred }, isReady: { true }, schedule: { callbacks.append($0) })
        owner.refreshAcceptedResolution(); XCTAssertTrue(callbacks.isEmpty)
        preferred = ["ja"]
        owner.refreshAcceptedResolution()
        XCTAssertEqual(owner.acceptedPreference, .system)
        callbacks.removeFirst()()
        XCTAssertEqual(owner.displayedLanguage, .japanese)
    }

    func testReentrantRequestWaitsForAnotherTurn() {
        var callbacks: [@MainActor () -> Void] = []
        let owner = LanguagePresentationController(preference: .english,
            preferredLanguages: { [] }, isReady: { true }, schedule: { callbacks.append($0) })
        owner.onPresent = { language in
            if language == .japanese { owner.request(.simplifiedChinese) }
        }
        owner.request(.japanese); callbacks.removeFirst()()
        XCTAssertEqual(owner.displayedLanguage, .japanese)
        XCTAssertEqual(owner.state, .queued)
        XCTAssertEqual(callbacks.count, 1)
        callbacks.removeFirst()()
        XCTAssertEqual(owner.displayedLanguage, .simplifiedChinese)
    }

    func testTeardownRejectsLateCallbacksOwnersAndRequests() {
        var callbacks: [@MainActor () -> Void] = []
        var count = 0
        let owner = LanguagePresentationController(preference: .english,
            preferredLanguages: { [] }, isReady: { true }, schedule: { callbacks.append($0) })
        owner.onPresent = { _ in count += 1 }
        owner.request(.japanese)
        let token = owner.acquire(.titleEditor)
        owner.teardown(); owner.release(token); owner.request(.simplifiedChinese)
        callbacks.removeFirst()()
        XCTAssertEqual(owner.state, .unavailable)
        XCTAssertEqual(owner.displayedLanguage, .english)
        XCTAssertEqual(count, 0)
    }
}
