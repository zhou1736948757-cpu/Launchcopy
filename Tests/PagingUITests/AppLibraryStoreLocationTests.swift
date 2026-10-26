import Foundation
import XCTest
@testable import PagingPrototypeApp

final class AppLibraryStoreLocationTests: XCTestCase {
    func testUnresolvedRequestedProfileNeverFallsBackToProduction() {
        let productionRoot = URL(fileURLWithPath: "/SyntheticSupport")
        XCTAssertNil(AppLibraryStoreLocation.resolve(testProfileRequested: true, profile: nil,
                                                      applicationSupportURL: productionRoot))
        XCTAssertEqual(AppLibraryStoreLocation.resolve(testProfileRequested: false, profile: nil,
            applicationSupportURL: productionRoot)?.path, "/SyntheticSupport/Launchcopy/Library/preferences.json")
        XCTAssertNil(AppLibraryStoreLocation.resolve(testProfileRequested: false, profile: nil,
                                                      applicationSupportURL: nil))
    }

    func testResolvedProfileWinsAndResolutionCreatesNothing() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let app = root.appendingPathComponent(".build/candidates/library/LaunchcopyUITest.app")
        try FileManager.default.createDirectory(at: app, withIntermediateDirectories: true)
        let profile = try UITestProfile.resolve(bundleURL: app, profileID: "gui")
        let resolved = AppLibraryStoreLocation.resolve(testProfileRequested: true, profile: profile,
            applicationSupportURL: URL(fileURLWithPath: "/SyntheticSupport"))
        XCTAssertEqual(resolved, profile.libraryDirectoryURL.appendingPathComponent("preferences.json"))
        XCTAssertFalse(FileManager.default.fileExists(atPath: profile.rootURL.path))
    }
}
