import Foundation
import XCTest
@testable import PagingPrototypeApp

final class AppSourcesPreferencesTests: XCTestCase {
    func testDefaultsContainOnlyCustomInputsAndEnableRefresh() {
        XCTAssertEqual(AppSourcesPreferences.default.customRootPaths, [])
        XCTAssertTrue(AppSourcesPreferences.default.automaticRefreshEnabled)
        XCTAssertEqual(AppSourcesPreferences.default, AppSourcesPreferences())
        XCTAssertTrue(AppSourcesPreferences.default.isValid)
        XCTAssertTrue(AppSourcesPreferences(automaticRefreshEnabled: false).isValid)
    }

    func testCodableRoundTripsDefaultsPathsAndToggle() throws {
        for value in [AppSourcesPreferences.default,
                      .init(customRootPaths: ["/synthetic/apps", "/synthetic/Other Apps"],
                            automaticRefreshEnabled: false)] {
            let data = try JSONEncoder().encode(value)
            XCTAssertEqual(try JSONDecoder().decode(AppSourcesPreferences.self, from: data), value)
        }
    }

    func testLexicalNormalizationAndStrictValidationAgree() {
        let cases: [(String, String)] = [
            ("/synthetic/apps", "/synthetic/apps"),
            ("//synthetic///apps/", "/synthetic/apps"),
            ("/synthetic/./apps", "/synthetic/apps"),
            ("/synthetic/old/../apps", "/synthetic/apps"),
            ("/../../synthetic/apps", "/synthetic/apps")
        ]
        for (input, canonical) in cases {
            XCTAssertEqual(AppSourcesPreferences.standardizedRootPath(input), canonical)
            XCTAssertEqual(AppSourcesPreferences(customRootPaths: [input]).isValid, input == canonical)
            XCTAssertTrue(AppSourcesPreferences(customRootPaths: [canonical]).isValid)
        }
    }

    func testEmptyRelativeAndWholeFilesystemPathsAreRejected() {
        for path in ["", " ", "relative/apps", "~/Applications", "file:///synthetic/apps",
                     "/", "//", "/./", "/synthetic/..", "/../"] {
            XCTAssertNil(AppSourcesPreferences.standardizedRootPath(path))
            XCTAssertFalse(AppSourcesPreferences(customRootPaths: [path]).isValid)
        }
    }

    func testEveryASCIIControlIncludingDELIsRejected() {
        for code in Array(0...31) + [127] {
            let path = "/synthetic/" + String(UnicodeScalar(code)!) + "apps"
            XCTAssertNil(AppSourcesPreferences.standardizedRootPath(path))
            XCTAssertFalse(AppSourcesPreferences(customRootPaths: [path]).isValid)
        }
    }

    func testUnicodeSpacesAndLiteralPathCharactersArePreserved() throws {
        let paths = ["/synthetic/应用程序", "/synthetic/Café", "/synthetic/Cafe\u{301}",
                     "/synthetic/🧪 Apps", "/synthetic/ Apps ", "/synthetic/~apps",
                     "/synthetic/percent%20apps", "/synthetic/line\u{2028}separator"]
        for path in paths {
            XCTAssertEqual(AppSourcesPreferences.standardizedRootPath(path), path)
            let value = AppSourcesPreferences(customRootPaths: [path])
            XCTAssertTrue(value.isValid)
            let decoded = try JSONDecoder().decode(AppSourcesPreferences.self,
                                                   from: JSONEncoder().encode(value))
            XCTAssertEqual(Array(decoded.customRootPaths[0].utf8), Array(path.utf8))
        }
    }

    func testDuplicatesIncludingUnicodeCanonicalEquivalentsAreRejected() {
        XCTAssertFalse(AppSourcesPreferences(customRootPaths: ["/synthetic/apps", "/synthetic/apps"]).isValid)
        XCTAssertFalse(AppSourcesPreferences(customRootPaths: ["/synthetic/Café", "/synthetic/Cafe\u{301}"]).isValid)
        XCTAssertFalse(AppSourcesPreferences(customRootPaths: ["/synthetic/apps", "/synthetic/./apps"]).isValid)
        XCTAssertTrue(AppSourcesPreferences(customRootPaths: ["/synthetic/Apps", "/synthetic/apps"]).isValid,
                      "Volume-specific case equivalence belongs to runtime admission")
    }

    func testModelDoesNotImposeRootCountOrFilesystemAdmissionPolicy() {
        XCTAssertTrue(AppSourcesPreferences(customRootPaths: (0..<2_000).map { "/synthetic/apps/\($0)" }).isValid)
        XCTAssertTrue(AppSourcesPreferences(customRootPaths: ["/synthetic/nonexistent/apps",
                                                              "/Volumes/synthetic",
                                                              "/Users/synthetic"]).isValid)
    }

    func testRemovalChangesOnlyCustomValue() {
        let original = AppSourcesPreferences(customRootPaths: ["/synthetic/first", "/synthetic/second"],
                                             automaticRefreshEnabled: false)
        var draft = original
        draft.customRootPaths.removeFirst()
        XCTAssertEqual(original.customRootPaths, ["/synthetic/first", "/synthetic/second"])
        XCTAssertEqual(draft.customRootPaths, ["/synthetic/second"])
        XCTAssertFalse(draft.automaticRefreshEnabled)
        XCTAssertTrue(draft.isValid)
    }
}
