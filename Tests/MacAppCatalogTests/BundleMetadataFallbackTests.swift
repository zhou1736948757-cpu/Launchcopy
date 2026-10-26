import Foundation
import XCTest
import AppCatalogCore
@testable import MacAppCatalog

/// Synthetic metadata only. No real applications, executable loading or user profiles.
final class BundleMetadataFallbackTests: XCTestCase {
    private let reader = BundleMetadataReader()

    private func properties(identifier: String? = "fixture.metadata.wrapped", package: String = "APPL") -> [String: Any] {
        var values: [String: Any] = [
            "CFBundleName": "Synthetic Wrapped App", "CFBundlePackageType": package,
            "CFBundleSupportedPlatforms": ["iPhoneOS"], "LSRequiresIPhoneOS": true,
            "CFBundleShortVersionString": "1.2", "CFBundleVersion": "3",
            "LSApplicationCategoryType": "public.app-category.education"
        ]
        values["CFBundleIdentifier"] = identifier
        return values
    }

    private func write(_ values: [String: Any], to url: URL) throws {
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try PropertyListSerialization.data(fromPropertyList: values, format: .xml, options: 0).write(to: url)
    }

    private func wrapped(in factory: FakeAppFactory, identifier: String? = "fixture.metadata.wrapped") throws -> URL {
        let outer = try factory.makeDirectory("Wrapped.app")
        let inner = outer.appendingPathComponent("Wrapper/Synthetic.app", isDirectory: true)
        try write(properties(identifier: identifier), to: inner.appendingPathComponent("Info.plist"))
        try FileManager.default.createSymbolicLink(atPath: outer.appendingPathComponent("WrappedBundle").path,
                                                  withDestinationPath: "Wrapper/Synthetic.app")
        return outer
    }

    func testSystemRecognizedWrappedAppUsesPublicBundleMetadata() throws {
        let factory = try FakeAppFactory(); defer { withExtendedLifetime(factory) {} }
        let outer = try wrapped(in: factory)
        XCTAssertNotNil(Bundle(url: outer)?.infoDictionary, "The synthetic control must be recognized by Foundation")
        guard case .valid(let identifier, let name, let metadata) = reader.readBundleMetadata(at: outer, fileManager: .default) else {
            return XCTFail("A system-recognized application wrapper must not be classified missingInfoPlist")
        }
        XCTAssertEqual(identifier, "fixture.metadata.wrapped")
        XCTAssertEqual(name, "Synthetic Wrapped App")
        XCTAssertEqual(metadata.declaredCategoryIdentifier, "public.app-category.education")
        XCTAssertEqual(metadata.version, "1.2")
        XCTAssertEqual(metadata.build, "3")
    }

    func testFallbackPreservesMissingIdentifierAsANonblockingMetadataResult() throws {
        let factory = try FakeAppFactory(); defer { withExtendedLifetime(factory) {} }
        let outer = try wrapped(in: factory, identifier: nil)
        guard case .valid(let identifier, _, _) = reader.readBundleMetadata(at: outer, fileManager: .default) else {
            return XCTFail("Missing identity retains the established canonical-URL fallback, not a hard bundle failure")
        }
        XCTAssertNil(identifier)
    }

    func testStandardContentsMetadataStillWinsOverAValidWrappedFallback() throws {
        let factory = try FakeAppFactory(); defer { withExtendedLifetime(factory) {} }
        let outer = try wrapped(in: factory)
        var ordinary = properties(identifier: "fixture.metadata.standard")
        ordinary["CFBundleName"] = "Standard Wins"
        try write(ordinary, to: outer.appendingPathComponent("Contents/Info.plist"))
        guard case .valid(let identifier, let name, _) = reader.readBundleMetadata(at: outer, fileManager: .default) else {
            return XCTFail("Existing standard bundle behavior must remain unchanged")
        }
        XCTAssertEqual(identifier, "fixture.metadata.standard")
        XCTAssertEqual(name, "Standard Wins")
    }

    func testCorruptStandardPlistIsNotHiddenByAValidWrappedFallback() throws {
        let factory = try FakeAppFactory(); defer { withExtendedLifetime(factory) {} }
        let outer = try wrapped(in: factory)
        let contents = outer.appendingPathComponent("Contents", isDirectory: true)
        try FileManager.default.createDirectory(at: contents, withIntermediateDirectories: true)
        try Data("not a plist".utf8).write(to: contents.appendingPathComponent("Info.plist"))
        guard case .corrupted = reader.readBundleMetadata(at: outer, fileManager: .default) else {
            return XCTFail("Do not turn genuine standard-plist corruption into a successful fallback")
        }
    }

    func testMissingMetadataRemainsAnInvalidBundle() throws {
        let factory = try FakeAppFactory(); defer { withExtendedLifetime(factory) {} }
        let empty = try factory.makeDirectory("Empty.app")
        guard case .missingInfoPlist = reader.readBundleMetadata(at: empty, fileManager: .default) else {
            return XCTFail("Empty .app directories must remain failures")
        }
    }

    func testNonapplicationFlatMetadataIsNotAdmittedAsAnApp() throws {
        let factory = try FakeAppFactory(); defer { withExtendedLifetime(factory) {} }
        let flat = try factory.makeDirectory("NotAnApplication.app")
        try write(properties(package: "BNDL"), to: flat.appendingPathComponent("Info.plist"))
        guard case .missingInfoPlist = reader.readBundleMetadata(at: flat, fileManager: .default) else {
            return XCTFail("A metadata fallback must require an application package")
        }
    }

    func testFlatApplicationMetadataCanUseTheSamePublicBundleFallback() throws {
        let factory = try FakeAppFactory(); defer { withExtendedLifetime(factory) {} }
        let flat = try factory.makeDirectory("Flat.app")
        try write(properties(identifier: "fixture.metadata.flat"), to: flat.appendingPathComponent("Info.plist"))
        guard case .valid(let identifier, _, _) = reader.readBundleMetadata(at: flat, fileManager: .default) else {
            return XCTFail("Public Bundle application metadata is independent of the Contents directory spelling")
        }
        XCTAssertEqual(identifier, "fixture.metadata.flat")
    }

    func testScannerRetainsOuterLaunchURLAndDoesNotReportTheRecognizedWrapperAsInvalid() async throws {
        let factory = try FakeAppFactory(); defer { withExtendedLifetime(factory) {} }
        let outer = try wrapped(in: factory)
        let scanner = CatalogScanner()
        let result: CatalogScanResult = await withCheckedContinuation { continuation in
            _ = scanner.scan(configuration: .init(roots: [factory.root]), revision: .init(1)) { result in
                continuation.resume(returning: result)
            }
        }
        XCTAssertFalse(result.cancelled)
        XCTAssertEqual(result.report.discoveryFailureCount, 0)
        XCTAssertEqual(result.snapshot?.records.count, 1)
        let record = try XCTUnwrap(result.snapshot?.records.first)
        XCTAssertEqual(record.canonicalURL, outer.standardizedFileURL)
        XCTAssertEqual(record.id, .bundleIdentifier("fixture.metadata.wrapped"))
    }
}
