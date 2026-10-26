import AppCatalogCore
import Foundation
import XCTest
@testable import MacAppCatalog

final class AppBundleMetadataScannerTests: XCTestCase {
    private final class ResultBox: @unchecked Sendable {
        private let lock = NSLock()
        private var stored: CatalogScanResult?
        var value: CatalogScanResult? {
            get { lock.lock(); defer { lock.unlock() }; return stored }
            set { lock.lock(); defer { lock.unlock() }; stored = newValue }
        }
    }

    private func makeBundle(_ fields: [String: Any], factory: FakeAppFactory,
                            format: PropertyListSerialization.PropertyListFormat = .xml) throws -> URL {
        let app = try factory.makeApp(named: factory.uniqueName("LibraryMetadata"))
        let data = try PropertyListSerialization.data(fromPropertyList: fields, format: format, options: 0)
        try data.write(to: app.appendingPathComponent("Contents/Info.plist"))
        return app
    }

    private func read(_ app: URL) throws -> AppBundleMetadata {
        guard case .valid(_, _, let metadata) = BundleMetadataReader().readBundleMetadata(
            at: app, fileManager: .default) else {
            XCTFail("Optional metadata must not invalidate a readable dictionary plist")
            throw NSError(domain: "AppBundleMetadataScannerTests", code: 1)
        }
        return metadata
    }

    private func scan(_ root: URL) throws -> CatalogScanResult {
        let completion = expectation(description: "metadata scan")
        let box = ResultBox()
        let task = CatalogScanner().scan(configuration: .init(roots: [root]), revision: .init(19)) { result in
            box.value = result
            completion.fulfill()
        }
        wait(for: [completion], timeout: 10)
        XCTAssertFalse(task.isCancelled)
        return try XCTUnwrap(box.value)
    }

    func testXMLAndBinaryPlistsExtractAllOptionalFields() throws {
        let factory = try FakeAppFactory()
        for format: PropertyListSerialization.PropertyListFormat in [.xml, .binary] {
            let app = try makeBundle([
                "CFBundleIdentifier": "fixture.library.scanner", "CFBundleName": "Fixture",
                "LSApplicationCategoryType": "public.app-category.developer-tools",
                "CFBundleShortVersionString": " 1.2.3 ", "CFBundleVersion": "007"
            ], factory: factory, format: format)
            XCTAssertEqual(try read(app), .init(declaredCategoryIdentifier: "public.app-category.developer-tools",
                                              version: "1.2.3", build: "007"))
        }
    }

    func testAbsentOptionalFieldsAreEmpty() throws {
        let factory = try FakeAppFactory()
        let app = try makeBundle(["CFBundleIdentifier": "fixture.library.scanner"], factory: factory)
        XCTAssertEqual(try read(app), .init())
    }

    func testWrongPlistTypesAreNotCoercedToStrings() throws {
        let factory = try FakeAppFactory()
        let invalid: [Any] = [42, true, ["not", "a", "string"], ["value": "1"], Data([1, 2]), Date()]
        for value in invalid {
            let app = try makeBundle([
                "CFBundleIdentifier": "fixture.library.scanner",
                "LSApplicationCategoryType": value, "CFBundleShortVersionString": value,
                "CFBundleVersion": value
            ], factory: factory)
            XCTAssertEqual(try read(app), .init())
        }
    }

    func testMalformedOptionalFieldsDoNotDiscardOtherDeclarations() throws {
        let factory = try FakeAppFactory()
        let app = try makeBundle([
            "LSApplicationCategoryType": " \t ", "CFBundleShortVersionString": ["1"],
            "CFBundleVersion": "99"
        ], factory: factory)
        XCTAssertEqual(try read(app), .init(build: "99"))
        let control = try makeBundle(["CFBundleShortVersionString": "1\u{0000}2"],
                                     factory: factory, format: .binary)
        XCTAssertEqual(try read(control), .init())
    }

    func testScanForwardsMetadataWithoutChangingIdentityRevisionOrFailureCounts() throws {
        let factory = try FakeAppFactory()
        try makeBundle([
            "CFBundleIdentifier": "fixture.library.scan", "CFBundleName": "Original",
            "LSApplicationCategoryType": "public.app-category.video", "CFBundleShortVersionString": "3",
            "CFBundleVersion": "300"
        ], factory: factory)
        let result = try scan(factory.root)
        let record = try XCTUnwrap(result.snapshot?.records.first)
        XCTAssertEqual(record.bundleMetadata, .init(declaredCategoryIdentifier: "public.app-category.video",
                                                    version: "3", build: "300"))
        XCTAssertEqual(record.displayName, "Original")
        XCTAssertEqual(record.id, .bundleIdentifier("fixture.library.scan"))
        XCTAssertEqual(result.snapshot?.revision, .init(19))
        XCTAssertEqual(result.report.appCount, 1)
        XCTAssertTrue(result.report.failureCounts.isEmpty)
    }

    func testOptionalMetadataSurvivesMissingIdentifierFallback() throws {
        let factory = try FakeAppFactory()
        let app = try makeBundle(["CFBundleVersion": "5", "LSApplicationCategoryType": false], factory: factory)
        let result = try scan(factory.root)
        let record = try XCTUnwrap(result.snapshot?.records.first)
        XCTAssertEqual(record.bundleMetadata, .init(build: "5"))
        XCTAssertNil(record.bundleIdentifier)
        XCTAssertEqual(record.id, .canonicalURLFallback(app.resolvingSymlinksInPath().standardizedFileURL))
        XCTAssertEqual(result.report.failureCounts[.missingBundleIdentifier], 1)
        XCTAssertNil(result.report.failureCounts[.corruptedBundle])
    }

    func testCorruptAndMissingPlistsRemainScannerFailures() throws {
        let factory = try FakeAppFactory()
        try factory.makeCorruptedApp(named: "Corrupt")
        try factory.makeInvalidApp(named: "Missing")
        let result = try scan(factory.root)
        XCTAssertEqual(result.snapshot?.records, [])
        XCTAssertEqual(result.report.failureCounts[.corruptedBundle], 1)
        XCTAssertEqual(result.report.failureCounts[.invalidAppBundle], 1)
    }

    func testOversizedOptionalStringsDegradeWithoutScanFailureOrOtherFieldLoss() throws {
        let factory = try FakeAppFactory()
        let boundary = String(repeating: "é", count: 512)
        try makeBundle([
            "CFBundleIdentifier": "fixture.library.bounded",
            "LSApplicationCategoryType": String(repeating: "x", count: 1025),
            "CFBundleShortVersionString": boundary, "CFBundleVersion": boundary + "a"
        ], factory: factory)
        let result = try scan(factory.root)
        let record = try XCTUnwrap(result.snapshot?.records.first)
        XCTAssertEqual(record.bundleMetadata, .init(version: boundary))
        XCTAssertEqual(result.report.appCount, 1)
        XCTAssertTrue(result.report.failureCounts.isEmpty)
    }
}
