import Foundation
import XCTest
@testable import PagingPrototypeApp

final class AppRemovalRunningPolicyTests: XCTestCase {
    func testCaseAliasesConservativelyRefuseTheRunningApp() {
        let candidate = URL(fileURLWithPath: "/Applications/Disposable.app")
        XCTAssertTrue(AppRemovalRunningPolicy.matches(candidate: candidate,
            runningURL: URL(fileURLWithPath: "/applications/disposable.APP"), isTerminated: false))
    }

    func testOnlyTheCompletePathMatchesAndTerminatedOrUnknownURLsDoNot() {
        let candidate = URL(fileURLWithPath: "/Applications/Disposable.app")
        XCTAssertTrue(AppRemovalRunningPolicy.matches(candidate: candidate, runningURL: candidate, isTerminated: false))
        for other in ["/Other/Disposable.app", "/Applications/Disposable2.app", "/Applications/Disposable.app/Contents/Helper.app"] {
            XCTAssertFalse(AppRemovalRunningPolicy.matches(candidate: candidate,
                runningURL: URL(fileURLWithPath: other), isTerminated: false))
        }
        XCTAssertFalse(AppRemovalRunningPolicy.matches(candidate: candidate, runningURL: nil, isTerminated: false))
        XCTAssertFalse(AppRemovalRunningPolicy.matches(candidate: candidate, runningURL: candidate, isTerminated: true))
        XCTAssertFalse(AppRemovalRunningPolicy.matches(candidate: candidate,
            runningURL: URL(string: "https://example.invalid/Disposable.app"), isTerminated: false))
    }
}
