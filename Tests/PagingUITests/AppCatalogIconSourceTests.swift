import AppCatalogCore
import AppGridUI
import AppIconPipeline
import AppKit
import Foundation
@testable import MacAppCatalog
import XCTest
@testable import PagingPrototypeApp

/// Commit integration only: synthetic URLs are identifiers, never filesystem inputs.
/// Pipeline concurrency, delivery revocation and cancellation belong to its own tests.
@MainActor
final class AppCatalogIconSourceTests: XCTestCase {
    func testResolverReportsAddedChangedRemovedAndIgnoresRevisionOrName() {
        let resolver = IconURLResolver()
        let alpha = record("alpha", source: "A")
        let beta = record("beta", source: "B")
        XCTAssertEqual(resolver.update(from: snapshot(1, [alpha, beta])),
                       Set([alpha.iconIdentity, beta.iconIdentity]))
        XCTAssertTrue(resolver.update(from: snapshot(2, [alpha, beta])).isEmpty)
        let renamed = record("alpha", source: "A", name: "Renamed")
        XCTAssertTrue(resolver.update(from: snapshot(3, [renamed, beta])).isEmpty)
        let moved = record("alpha", source: "C")
        let added = record("gamma", source: "D")
        XCTAssertEqual(resolver.update(from: snapshot(4, [moved, added])),
                       Set([alpha.iconIdentity, beta.iconIdentity, added.iconIdentity]))
        XCTAssertEqual(resolver.url(for: alpha.iconIdentity), moved.canonicalURL)
        XCTAssertEqual(resolver.url(for: alpha.id), moved.canonicalURL)
        XCTAssertNil(resolver.url(for: beta.iconIdentity))
        XCTAssertNil(resolver.url(for: beta.id))
        XCTAssertEqual(resolver.update(from: snapshot(5, [])),
                       Set([alpha.iconIdentity, added.iconIdentity]))
        XCTAssertTrue(resolver.update(from: snapshot(6, [])).isEmpty)
        XCTAssertEqual(resolver.update(from: snapshot(7, [alpha])), Set([alpha.iconIdentity]))
    }

    func testRefreshCommitInvalidatesBeforeRenderAndPreservesUnaffectedHit() async throws {
        let scanner = IconSourceScanner()
        let loader = IconSourceLoader()
        let assembly = makeAssembly(scanner: scanner, loader: loader)
        defer { assembly.teardown() }
        let alpha = record("alpha", source: "A")
        let moved = record("alpha", source: "B")
        let stable = record("stable", source: "Stable")
        let old = try image(red: 255)
        let fresh = try image(green: 255)
        let unaffected = try image(blue: 255)
        loader.install(old, at: alpha.canonicalURL)
        loader.install(fresh, at: moved.canonicalURL)
        loader.install(unaffected, at: stable.canonicalURL)
        try await stage([alpha, stable], scanner: scanner, assembly: assembly)
        XCTAssertNotNil(assembly.refreshController.applyPendingAtIdleBoundary(currentPage: 0))
        try await expectIcon(alpha, in: assembly, image: old)
        try await expectIcon(stable, in: assembly, image: unaffected)

        try await stage([moved, stable], scanner: scanner, assembly: assembly)
        let rendered = expectation(description: "fresh icon requested inside presentation callback")
        var renderCount = 0
        assembly.onPresentationUpdate = { _ in
            renderCount += 1
            XCTAssertEqual(assembly.urlResolver.url(for: alpha.iconIdentity), moved.canonicalURL)
            assembly.iconPipeline.request(key: self.key(alpha), generation: 2) { _, _, result in
                if case .success(let actual) = result { XCTAssertTrue(actual === fresh) }
                else { XCTFail("Expected the new source image") }
                rendered.fulfill()
            }
        }
        XCTAssertNotNil(assembly.refreshController.applyPendingAtIdleBoundary(currentPage: 0))
        await fulfillment(of: [rendered], timeout: 3)
        XCTAssertEqual(renderCount, 1)
        let hits = assembly.iconPipeline.stats.cacheHits
        try await expectIcon(stable, in: assembly, image: unaffected)
        XCTAssertEqual(assembly.iconPipeline.stats.cacheHits, hits + 1)
        XCTAssertEqual(loader.sources, [alpha.canonicalURL, stable.canonicalURL, moved.canonicalURL])
    }

    func testSynchronizationUsesServedSnapshotEvenWithNewerUncommittedScanHead() async throws {
        let scanner = IconSourceScanner()
        let loader = IconSourceLoader()
        let assembly = makeAssembly(scanner: scanner, loader: loader)
        defer { assembly.teardown() }
        let alpha = record("alpha", source: "A")
        let pending = record("alpha", source: "B")
        let head = record("alpha", source: "C")
        let old = try image(red: 255)
        let fresh = try image(green: 255)
        loader.install(old, at: alpha.canonicalURL)
        loader.install(fresh, at: pending.canonicalURL)
        loader.install(try image(blue: 255), at: head.canonicalURL)
        try await stage([alpha], scanner: scanner, assembly: assembly)
        XCTAssertNotNil(assembly.commitPendingAtIdleBoundary(currentPage: 0))
        try await expectIcon(alpha, in: assembly, image: old)
        try await stage([pending], scanner: scanner, assembly: assembly)
        let pendingSnapshot = try XCTUnwrap(assembly.provider.pendingSnapshot)

        // Advance the data-source head without handing that result to the provider.
        let admitted = expectation(description: "newer head scan admitted")
        scanner.enqueue([head], admitted: admitted)
        let completed = expectation(description: "newer head stored")
        let refresh = Task { @MainActor in
            let outcome = await assembly.dataSource.refresh()
            XCTAssertTrue(outcome.succeeded)
            completed.fulfill()
        }
        defer { refresh.cancel() }
        await fulfillment(of: [admitted, completed], timeout: 3)
        XCTAssertEqual(assembly.dataSource.currentSnapshot?.records.map(\.canonicalURL), [head.canonicalURL])
        XCTAssertEqual(assembly.provider.pendingSnapshot, pendingSnapshot)
        assembly.synchronizeIconSourcesWithCommittedCatalog()
        XCTAssertEqual(assembly.urlResolver.url(for: alpha.iconIdentity), alpha.canonicalURL)
        let hits = assembly.iconPipeline.stats.cacheHits
        try await expectIcon(alpha, in: assembly, image: old)
        XCTAssertEqual(assembly.iconPipeline.stats.cacheHits, hits + 1)

        XCTAssertNotNil(assembly.refreshController.applyPendingAtIdleBoundary(currentPage: 0))
        XCTAssertEqual(assembly.provider.servedSnapshot, pendingSnapshot)
        XCTAssertEqual(assembly.urlResolver.url(for: alpha.iconIdentity), pending.canonicalURL)
        try await expectIcon(alpha, in: assembly, image: fresh)
        XCTAssertEqual(loader.sources, [alpha.canonicalURL, pending.canonicalURL])
    }

    func testSearchCatalogCommitSynchronizesBeforeItsPresentationConsumer() async throws {
        let scanner = IconSourceScanner()
        let loader = IconSourceLoader()
        let assembly = makeAssembly(scanner: scanner, loader: loader)
        defer { assembly.teardown() }
        let alpha = record("alpha", source: "A")
        let moved = record("alpha", source: "B")
        let old = try image(red: 255)
        let fresh = try image(green: 255)
        loader.install(old, at: alpha.canonicalURL)
        loader.install(fresh, at: moved.canonicalURL)
        try await stage([alpha], scanner: scanner, assembly: assembly)
        XCTAssertNotNil(assembly.commitPendingAtIdleBoundary(currentPage: 0))
        try await expectIcon(alpha, in: assembly, image: old)
        assembly.searchPresentation.updateQuery(.init(raw: "alpha"))
        _ = assembly.commitPendingAtIdleBoundary(currentPage: 0)
        try await stage([moved], scanner: scanner, assembly: assembly)

        // Mirrors the root search callback's explicit assembly-owned synchronization.
        // This does not instantiate AppDelegate or independently verify its wiring.
        let rendered = expectation(description: "search consumer receives fresh source")
        var renderCount = 0
        assembly.searchPresentation.onPresentationUpdate = { _ in
            assembly.synchronizeIconSourcesWithCommittedCatalog()
            renderCount += 1
            XCTAssertEqual(assembly.urlResolver.url(for: alpha.id), moved.canonicalURL)
            assembly.iconPipeline.request(key: self.key(alpha), generation: 2) { _, _, result in
                if case .success(let actual) = result { XCTAssertTrue(actual === fresh) }
                else { XCTFail("Expected the new search source image") }
                rendered.fulfill()
            }
        }
        XCTAssertNotNil(assembly.searchPresentation.applyPendingAtIdleBoundary(currentPage: 0))
        await fulfillment(of: [rendered], timeout: 3)
        XCTAssertEqual(renderCount, 1)
        XCTAssertEqual(assembly.provider.activeQuery?.raw, "alpha")
        XCTAssertEqual(assembly.provider.presentationRecords.map(\.id), [alpha.id])
        XCTAssertEqual(loader.sources, [alpha.canonicalURL, moved.canonicalURL])
    }

    func testDirectCommitSynchronizesBeforeReturnAndSameURLRenameKeepsCachedImage() async throws {
        let scanner = IconSourceScanner()
        let loader = IconSourceLoader()
        let assembly = makeAssembly(scanner: scanner, loader: loader)
        defer { assembly.teardown() }
        let alpha = record("alpha", source: "A")
        let renamed = record("alpha", source: "A", name: "Renamed")
        let icon = try image(red: 255, green: 128)
        loader.install(icon, at: alpha.canonicalURL)
        try await stage([alpha], scanner: scanner, assembly: assembly)
        XCTAssertNotNil(assembly.commitPendingAtIdleBoundary(currentPage: 0))
        XCTAssertEqual(assembly.urlResolver.url(for: alpha.id), alpha.canonicalURL)
        let revision = try XCTUnwrap(assembly.provider.servedSnapshot?.revision)
        try await expectIcon(alpha, in: assembly, image: icon)
        try await stage([renamed], scanner: scanner, assembly: assembly)
        XCTAssertNotNil(assembly.commitPendingAtIdleBoundary(currentPage: 0))
        XCTAssertGreaterThan(try XCTUnwrap(assembly.provider.servedSnapshot?.revision), revision)
        XCTAssertEqual(assembly.provider.servedSnapshot?.records.first?.displayName, "Renamed")
        let hits = assembly.iconPipeline.stats.cacheHits
        try await expectIcon(renamed, in: assembly, image: icon)
        assembly.searchPresentation.updateQuery(.init(raw: "Renamed"))
        XCTAssertNil(assembly.commitPendingAtIdleBoundary(currentPage: 0))
        assembly.synchronizeIconSourcesWithCommittedCatalog()
        try await expectIcon(renamed, in: assembly, image: icon)
        XCTAssertEqual(assembly.iconPipeline.stats.cacheHits, hits + 2)
        XCTAssertEqual(loader.sources, [alpha.canonicalURL])
    }

    func testCommittedRemovalAndReadditionAtSameURLCannotReuseRemovedImage() async throws {
        let scanner = IconSourceScanner()
        let loader = IconSourceLoader()
        let assembly = makeAssembly(scanner: scanner, loader: loader)
        defer { assembly.teardown() }
        let alpha = record("alpha", source: "A")
        let old = try image(red: 255)
        let fresh = try image(blue: 255)
        loader.install(old, at: alpha.canonicalURL)
        try await stage([alpha], scanner: scanner, assembly: assembly)
        XCTAssertNotNil(assembly.commitPendingAtIdleBoundary(currentPage: 0))
        try await expectIcon(alpha, in: assembly, image: old)
        try await stage([], scanner: scanner, assembly: assembly)
        XCTAssertNotNil(assembly.commitPendingAtIdleBoundary(currentPage: 0))
        XCTAssertNil(assembly.urlResolver.url(for: alpha.id))
        XCTAssertNil(assembly.urlResolver.url(for: alpha.iconIdentity))
        loader.install(fresh, at: alpha.canonicalURL)
        try await stage([alpha], scanner: scanner, assembly: assembly)
        XCTAssertNotNil(assembly.commitPendingAtIdleBoundary(currentPage: 0))
        try await expectIcon(alpha, in: assembly, image: fresh)
        XCTAssertEqual(loader.sources, [alpha.canonicalURL, alpha.canonicalURL])
    }

    private func makeAssembly(scanner: IconSourceScanner, loader: IconSourceLoader) -> AppCatalogAssembly {
        let assembly = AppCatalogAssembly(roots: [URL(fileURLWithPath: "/__synthetic_icon_sources__")],
                                          scanning: scanner, loader: loader)
        loader.connect(assembly.urlResolver)
        return assembly
    }

    private func stage(_ records: [AppRecord], scanner: IconSourceScanner,
                       assembly: AppCatalogAssembly) async throws {
        let admitted = expectation(description: "synthetic scanner admitted")
        let staged = expectation(description: "scan reached pending presentation")
        scanner.enqueue(records, admitted: admitted)
        assembly.refreshController.onStateChange = { state in
            if !state.isBusy, assembly.provider.hasPendingSnapshot { staged.fulfill() }
        }
        defer { assembly.refreshController.onStateChange = nil }
        assembly.refreshNow()
        await fulfillment(of: [admitted, staged], timeout: 3)
        let pending = try XCTUnwrap(assembly.provider.pendingSnapshot)
        XCTAssertEqual(Set(pending.records.map(\.id)), Set(records.map(\.id)))
    }

    private func expectIcon(_ record: AppRecord, in assembly: AppCatalogAssembly, image: NSImage) async throws {
        let delivered = expectation(description: "generated image delivered")
        assembly.iconPipeline.request(key: key(record), generation: 1) { _, _, result in
            if case .success(let actual) = result { XCTAssertTrue(actual === image) }
            else { XCTFail("Expected a generated image") }
            delivered.fulfill()
        }
        await fulfillment(of: [delivered], timeout: 3)
    }

    private func key(_ record: AppRecord) -> IconKey {
        .init(identity: record.iconIdentity, pointSize: 32, displayScale: 1)
    }

    private func record(_ token: String, source: String, name: String? = nil) -> AppRecord {
        let bundleID = "test.icon-source.\(token)"
        let id = AppID.bundleIdentifier(bundleID)
        return AppRecord(id: id, displayName: name ?? token, bundleIdentifier: bundleID,
                         canonicalURL: URL(fileURLWithPath: "/__synthetic_icon_sources__/\(source).app"),
                         iconIdentity: .from(appID: id), sourceRootPriority: 0)
    }

    private func snapshot(_ revision: UInt64, _ records: [AppRecord]) -> CatalogSnapshot {
        .init(revision: .init(revision), records: records)
    }

    private func image(red: UInt8 = 0, green: UInt8 = 0, blue: UInt8 = 0) throws -> NSImage {
        let bitmap = try XCTUnwrap(NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: 8, pixelsHigh: 8,
            bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
            colorSpaceName: .deviceRGB, bytesPerRow: 32, bitsPerPixel: 32))
        let pixels = try XCTUnwrap(bitmap.bitmapData)
        for offset in stride(from: 0, to: 8 * 8 * 4, by: 4) {
            pixels[offset] = red; pixels[offset + 1] = green
            pixels[offset + 2] = blue; pixels[offset + 3] = 255
        }
        let image = NSImage(size: NSSize(width: 8, height: 8))
        image.addRepresentation(bitmap)
        return image
    }
}

/// Immediate synthetic completion; expectation fulfillment proves actual scan admission.
private final class IconSourceScanner: CatalogScanning, @unchecked Sendable {
    private let lock = NSLock()
    private var queued: [(records: [AppRecord], admitted: XCTestExpectation)] = []

    func enqueue(_ records: [AppRecord], admitted: XCTestExpectation) {
        lock.lock(); defer { lock.unlock() }
        queued.append((records, admitted))
    }

    func scan(configuration: ScanConfiguration, revision: CatalogRevision,
              completion: @escaping @Sendable (CatalogScanResult) -> Void) -> ScanTask {
        lock.lock()
        let next = queued.isEmpty ? nil : queued.removeFirst()
        lock.unlock()
        guard let next else {
            XCTFail("Unexpected scan without a synthetic response")
            completion(.init(snapshot: nil, report: .init(appCount: 0, failureCounts: [:], scanDuration: 0),
                             cancelled: true))
            return ScanTask()
        }
        next.admitted.fulfill()
        completion(.init(snapshot: .init(revision: revision, records: next.records),
                         report: .init(appCount: next.records.count, failureCounts: [:], scanDuration: 0),
                         cancelled: false))
        return ScanTask()
    }
}

/// Resolves only the assembly's committed in-memory mapping; never calls NSWorkspace.
private final class IconSourceLoader: IconLoading, @unchecked Sendable {
    private let lock = NSLock()
    private var resolver: IconURLResolver?
    private var images: [URL: NSImage] = [:]
    private var recorded: [URL] = []
    var sources: [URL] { lock.lock(); defer { lock.unlock() }; return recorded }

    func connect(_ resolver: IconURLResolver) {
        lock.lock(); defer { lock.unlock() }; self.resolver = resolver
    }

    func install(_ image: NSImage, at url: URL) {
        lock.lock(); defer { lock.unlock() }; images[url] = image
    }

    func load(key: IconKey) async throws -> NSImage { try resolve(key) }

    private func resolve(_ key: IconKey) throws -> NSImage {
        lock.lock(); defer { lock.unlock() }
        guard let url = resolver?.url(for: key.identity), let image = images[url] else {
            throw IconFailure.loadFailed
        }
        recorded.append(url)
        return image
    }
}
