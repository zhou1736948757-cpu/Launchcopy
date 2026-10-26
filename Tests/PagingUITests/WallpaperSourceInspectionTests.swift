import AppKit
import Darwin
import Foundation
import XCTest
@testable import PagingPrototypeApp

final class WallpaperSourceInspectionTests: XCTestCase {
    private func fixtureDirectory() throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: url) }
        return url
    }

    func testRegularFileAndSymlinkMetadataRemainPathFree() throws {
        let directory = try fixtureDirectory()
        let file = directory.appendingPathComponent("PrivateFixtureName")
        try Data([1, 2]).write(to: file)
        let alias = directory.appendingPathComponent("Alias")
        try FileManager.default.createSymbolicLink(at: alias, withDestinationURL: file)
        for url in [file, alias] {
            let result = WallpaperSourceInspection.inspect(url)
            XCTAssertEqual(result.kind, .regular)
            XCTAssertEqual(result.localVolume, true)
            XCTAssertFalse(result.summary.contains("PrivateFixtureName"))
            XCTAssertFalse(result.summary.contains(directory.path))
        }
    }

    func testDirectoryAndFIFORequireNoStreamOpen() throws {
        let directory = try fixtureDirectory()
        let fifo = directory.appendingPathComponent("pipe")
        let status = fifo.withUnsafeFileSystemRepresentation { path -> Int32 in
            guard let path else { return -1 }
            return mkfifo(path, 0o600)
        }
        XCTAssertEqual(status, 0)
        XCTAssertEqual(WallpaperSourceInspection.inspect(directory).kind, .directory)
        let result = WallpaperSourceInspection.inspect(fifo)
        XCTAssertEqual(result.kind, .fifo)
        XCTAssertNil(result.localVolume)
        XCTAssertNil(result.downloaded)
    }

    func testMissingAndNonFileSourcesHaveNeutralOutcomes() throws {
        let missing = try fixtureDirectory().appendingPathComponent("missing")
        XCTAssertEqual(WallpaperSourceInspection.inspect(missing).kind, .unavailable)
        let url = try XCTUnwrap(URL(string: "https://example.invalid/private"))
        XCTAssertEqual(WallpaperSourceInspection.inspect(url).kind, .nonFile)
    }

    @MainActor
    func testStaleInspectionDoesNotCrossPolicyOrHostGeneration() {
        var completions: [@MainActor (WallpaperSourceInspection) -> Void] = []
        let controller = WallpaperBackdropController(imageLoader: { _, _, _ in },
            sourceResolver: { _ in URL(fileURLWithPath: "/SyntheticSource") },
            sourceInspector: { _, done in completions.append(done) })
        let enabled = LaunchcopyMaterialPolicy(reduceTransparency: false, increaseContrast: false, reduceMotion: false)
        let disabled = LaunchcopyMaterialPolicy(reduceTransparency: true, increaseContrast: false, reduceMotion: false)
        let first = NSView(frame: NSRect(x: 0, y: 0, width: 80, height: 60))
        let second = NSView(frame: first.frame)
        let result = WallpaperSourceInspection(kind: .regular, localVolume: true, ubiquitous: false, downloaded: nil)
        controller.attach(to: first)
        controller.refresh(for: nil, policy: enabled)
        controller.refresh(for: nil, policy: disabled)
        completions[0](result)
        XCTAssertNil(controller.sourceInspection)
        controller.refresh(for: nil, policy: enabled)
        controller.attach(to: second)
        completions[1](result)
        XCTAssertNil(controller.sourceInspection)
        controller.refresh(for: nil, policy: enabled)
        completions[2](result)
        XCTAssertEqual(controller.sourceInspection, result)
        XCTAssertEqual(controller.loadState, .loading)
    }

    @MainActor
    func testDefaultControllerStartsNoMetadataInspection() {
        var calls = 0
        let controller = WallpaperBackdropController(imageLoader: { _, _, done in calls += 1; done(nil) },
            sourceResolver: { _ in URL(fileURLWithPath: "/SyntheticSource") })
        let host = NSView(frame: NSRect(x: 0, y: 0, width: 80, height: 60))
        controller.attach(to: host)
        controller.refresh(for: nil, policy: .init(reduceTransparency: false, increaseContrast: false, reduceMotion: false))
        XCTAssertEqual(calls, 1)
        XCTAssertNil(controller.sourceInspection)
        XCTAssertEqual(controller.loadState, .renderFailed)
    }
}
