import Foundation
import XCTest
@testable import PagingPrototypeApp

final class AppSourceRootAdmissionTests: XCTestCase {
    private let home = URL(fileURLWithPath: "/synthetic/Home", isDirectory: true)
    private let candidate = URL(fileURLWithPath: "/synthetic/Extra Apps", isDirectory: true)

    private var context: AppSourceRootAdmissionContext {
        .init(homeURL: home, fixedRoots: [])
    }

    func testAcceptsCanonicalLocalUnicodeFolderAndPersistsOnlyResolvedPath() async throws {
        let original = URL(fileURLWithPath: "/synthetic/Old/../应用程序/Cafe\u{301}", isDirectory: true)
        let canonical = URL(fileURLWithPath: "/synthetic/应用程序/Cafe\u{301}", isDirectory: true)
        let probe = AdmissionProbe(canonicalPaths: [original.path: canonical])
        let service = LocalAppSourceRootAdmitter(probe: probe)
        let result = await service.admit(original, context: context)
        XCTAssertEqual(result, .accepted(canonical))
        let accepted = try acceptedURL(result)
        XCTAssertEqual(Array(accepted.path.utf8), Array(canonical.path.utf8))
        XCTAssertTrue(AppSourcesPreferences(customRootPaths: [accepted.path]).isValid)
        XCTAssertEqual(probe.calls.map(\.operation), [.canonicalize, .metadata])
        XCTAssertEqual(probe.calls.last?.url.path, canonical.path)
    }

    func testBundleOrEmbeddedHelperSourceRejectsBeforeMetadataRead() async {
        for path in ["/synthetic/Product.app", "/synthetic/Product.APP/Contents/Helpers"] {
            let probe = AdmissionProbe()
            let result = await LocalAppSourceRootAdmitter(probe: probe).admit(URL(fileURLWithPath: path), context: context)
            XCTAssertEqual(result, .rejected(.applicationBundle)); XCTAssertTrue(probe.calls.isEmpty)
        }
        let alias = URL(fileURLWithPath: "/synthetic/Alias")
        let probe = AdmissionProbe(canonicalPaths: [alias.path: URL(fileURLWithPath: "/synthetic/Product.app")])
        let result = await LocalAppSourceRootAdmitter(probe: probe).admit(alias, context: context)
        XCTAssertEqual(result, .rejected(.applicationBundle)); XCTAssertEqual(probe.calls.map(\.operation), [.canonicalize])
    }

    func testLocalhostFileURLIsAcceptedAsLocalPath() async throws {
        let input = try XCTUnwrap(URL(string: "file://localhost/synthetic/Extra%20Apps"))
        let probe = AdmissionProbe()
        let result = await LocalAppSourceRootAdmitter(probe: probe).admit(input, context: context)
        XCTAssertEqual(result, .accepted(candidate))
    }

    func testNonFileRemoteHostRelativeAndDecoratedReferencesNeverProbe() async throws {
        let base = URL(fileURLWithPath: "/synthetic/", isDirectory: true)
        let inputs = [
            try XCTUnwrap(URL(string: "https://example.invalid/apps")),
            try XCTUnwrap(URL(string: "file://server.invalid/synthetic/apps")),
            try XCTUnwrap(URL(string: "file:relative/apps")),
            try XCTUnwrap(URL(string: "apps", relativeTo: base)),
            try XCTUnwrap(URL(string: "file:///synthetic/apps?query=value")),
            try XCTUnwrap(URL(string: "file:///synthetic/apps#fragment")),
            try XCTUnwrap(URL(string: "file://user@localhost/synthetic/apps"))
        ]
        for input in inputs {
            let probe = AdmissionProbe()
            let result = await LocalAppSourceRootAdmitter(probe: probe).admit(input, context: context)
            XCTAssertEqual(result, .rejected(.invalidURL))
            XCTAssertTrue(probe.calls.isEmpty)
        }
    }

    func testExactCanonicalIdentityRequiredForFixedProfileRoot() async {
        let boundary = URL(fileURLWithPath: "/synthetic/Profile/Applications")
        let selected = boundary.appendingPathComponent("Baseline")
        let moved = boundary.appendingPathComponent("Different")
        let probe = AdmissionProbe(canonicalPaths: [selected.path: moved])
        let exact = AppSourceRootAdmissionContext(homeURL: home, fixedRoots: [boundary],
            allowedSyntheticRoot: boundary, requiresExactCanonicalPath: true)
        let result = await LocalAppSourceRootAdmitter(probe: probe).admit(selected, context: exact)
        XCTAssertEqual(result, .rejected(.changedCanonicalPath))
        XCTAssertEqual(probe.calls.map(\.operation), [.canonicalize])
    }

    func testAbsoluteFileURLIgnoresConstructorBaseAndIsAnAbsoluteSelection() async throws {
        // Verified Foundation behavior: an absolute string discards relativeTo.
        // Reject real base-backed relative references, not this valid absolute URL.
        let base = URL(fileURLWithPath: "/synthetic/", isDirectory: true)
        let input = try XCTUnwrap(URL(string: "file:///synthetic/apps", relativeTo: base))
        XCTAssertNil(input.baseURL)
        let result = await LocalAppSourceRootAdmitter(probe: AdmissionProbe()).admit(input, context: context)
        XCTAssertEqual(result, .accepted(URL(fileURLWithPath: "/synthetic/apps", isDirectory: true)))
    }

    func testAllASCIIControlsAndDELNeverProbe() async {
        for code in Array(0...31) + [127] {
            let input = URL(fileURLWithPath: "/synthetic/" + String(UnicodeScalar(code)!) + "Apps")
            let probe = AdmissionProbe()
            let result = await LocalAppSourceRootAdmitter(probe: probe).admit(input, context: context)
            XCTAssertEqual(result, .rejected(.invalidURL))
            XCTAssertTrue(probe.calls.isEmpty)
        }
    }

    func testHomeAncestorsFilesystemAndVolumeAggregatesRejectBeforeIO() async {
        for path in ["/", "/synthetic", home.path, "/Volumes", "/System/Volumes", "/synthetic/Home/.."] {
            let probe = AdmissionProbe()
            let result = await LocalAppSourceRootAdmitter(probe: probe).admit(
                URL(fileURLWithPath: path), context: context)
            XCTAssertEqual(result, .rejected(.tooBroad))
            XCTAssertTrue(probe.calls.isEmpty)
        }
    }

    func testCaseAliasesOfHomeAncestorsAndVolumeAggregatesRejectBeforeIO() async {
        for path in ["/SYNTHETIC/HOME", "/Synthetic", "/volumes", "/SYSTEM/volumes"] {
            let probe = AdmissionProbe()
            let result = await LocalAppSourceRootAdmitter(probe: probe).admit(URL(fileURLWithPath: path), context: context)
            XCTAssertEqual(result, .rejected(.tooBroad)); XCTAssertTrue(probe.calls.isEmpty)
        }
    }

    func testVolumeFlagOrExactVolumeURLRejectsActualDiskRoots() async {
        let disk = URL(fileURLWithPath: "/Volumes/SyntheticDisk", isDirectory: true)
        for metadata in [AdmissionProbe.localMetadata(isVolume: true),
                         AdmissionProbe.localMetadata(volumeURL: disk)] {
            let probe = AdmissionProbe(metadata: metadata)
            let result = await LocalAppSourceRootAdmitter(probe: probe).admit(disk, context: context)
            XCTAssertEqual(result, .rejected(.tooBroad))
        }
        let apps = disk.appendingPathComponent("Applications", isDirectory: true)
        let probe = AdmissionProbe(metadata: AdmissionProbe.localMetadata(volumeURL: disk))
        let result = await LocalAppSourceRootAdmitter(probe: probe).admit(apps, context: context)
        XCTAssertEqual(result, .accepted(apps))
    }

    func testMetadataRejectsNonDirectoryUnreadableRemoteAndUnknownLocality() async {
        let cases: [(AppSourceRootMetadata, AppSourceRootRejection)] = [
            (AdmissionProbe.localMetadata(isDirectory: false), .notDirectory),
            (AdmissionProbe.localMetadata(isDirectory: nil), .metadataUnavailable),
            (AdmissionProbe.localMetadata(isReadable: false), .unreadable),
            (AdmissionProbe.localMetadata(volumeIsLocal: false), .nonLocalVolume),
            (AdmissionProbe.localMetadata(volumeIsLocal: nil), .unknownLocality),
            (AdmissionProbe.localMetadata(isVolume: nil), .metadataUnavailable),
            (AdmissionProbe.localMetadata(volumeURL: nil), .metadataUnavailable)
        ]
        for (metadata, rejection) in cases {
            let probe = AdmissionProbe(metadata: metadata)
            let result = await LocalAppSourceRootAdmitter(probe: probe).admit(candidate, context: context)
            XCTAssertEqual(result, .rejected(rejection))
            XCTAssertEqual(probe.calls.map(\.operation), [.canonicalize, .metadata])
        }
    }

    func testMissingUnreadableAndUnexpectedProbeFailuresAreNeutral() async {
        for (failure, rejection) in [(AppSourceRootProbeFailure.missing, AppSourceRootRejection.missing),
                                     (.unreadable, .unreadable), (.unavailable, .metadataUnavailable)] {
            for operation in [AdmissionProbe.Operation.canonicalize, .metadata] {
                let probe = AdmissionProbe(failure: failure, failingOperation: operation)
                let result = await LocalAppSourceRootAdmitter(probe: probe).admit(candidate, context: context)
                XCTAssertEqual(result, .rejected(rejection))
            }
        }
    }

    func testFixedBaselineAndSubfoldersAreAlreadyCoveredWithoutMetadataReads() async {
        let fixed = ["/Applications", "/System/Applications", "/System/Applications/Utilities",
                     "/synthetic/Home/Applications"].map { URL(fileURLWithPath: $0, isDirectory: true) }
        let baseline = AppSourceRootAdmissionContext(homeURL: home, fixedRoots: fixed)
        let originalPaths = baseline.fixedRoots.map(\.path)
        for root in fixed {
            for selection in [root, root.appendingPathComponent("Tools/Nested", isDirectory: true)] {
                // Even a temporarily missing fixed folder remains part of the baseline.
                let probe = AdmissionProbe(failure: .missing, failingOperation: .metadata)
                let result = await LocalAppSourceRootAdmitter(probe: probe).admit(selection, context: baseline)
                XCTAssertEqual(result, .alreadyCovered)
                XCTAssertEqual(probe.calls.map(\.operation), [.canonicalize])
            }
        }
        XCTAssertEqual(baseline.fixedRoots.map(\.path), originalPaths)
    }

    func testPathComponentLookalikesAreNotCoveredOrHomeAncestors() async {
        let baseline = AppSourceRootAdmissionContext(homeURL: home,
                                                   fixedRoots: [URL(fileURLWithPath: "/Applications")])
        for path in ["/ApplicationsOther", "/ApplicationsOther/Nested", "/synthetic/HomeOther"] {
            let input = URL(fileURLWithPath: path, isDirectory: true)
            let probe = AdmissionProbe()
            let result = await LocalAppSourceRootAdmitter(probe: probe).admit(input, context: baseline)
            XCTAssertEqual(result, .accepted(input))
        }
    }

    func testCanonicalAliasIntoFixedRootIsAlreadyCovered() async {
        let fixed = URL(fileURLWithPath: "/Applications", isDirectory: true)
        let target = fixed.appendingPathComponent("Nested", isDirectory: true)
        let probe = AdmissionProbe(canonicalPaths: [candidate.path: target])
        let baseline = AppSourceRootAdmissionContext(homeURL: home, fixedRoots: [fixed])
        let result = await LocalAppSourceRootAdmitter(probe: probe).admit(candidate, context: baseline)
        XCTAssertEqual(result, .alreadyCovered)
        XCTAssertEqual(probe.calls.map(\.operation), [.canonicalize])
    }

    func testCanonicalHomeAndAggregateEscapesRejectBeforeTargetMetadata() async {
        for target in [home, home.deletingLastPathComponent(), URL(fileURLWithPath: "/"),
                       URL(fileURLWithPath: "/Volumes"), URL(fileURLWithPath: "/System/Volumes")] {
            let probe = AdmissionProbe(canonicalPaths: [candidate.path: target])
            let result = await LocalAppSourceRootAdmitter(probe: probe).admit(candidate, context: context)
            XCTAssertEqual(result, .rejected(.tooBroad))
            XCTAssertEqual(probe.calls.map(\.operation), [.canonicalize])
        }
    }

    func testInvalidCanonicalProbeResultIsRevalidatedBeforeMetadata() async throws {
        for target in [try XCTUnwrap(URL(string: "file://server.invalid/synthetic/Apps")),
                       URL(fileURLWithPath: "/synthetic/Bad\u{7F}Apps")] {
            let probe = AdmissionProbe(canonicalPaths: [candidate.path: target])
            let result = await LocalAppSourceRootAdmitter(probe: probe).admit(candidate, context: context)
            XCTAssertEqual(result, .rejected(.invalidURL))
            XCTAssertEqual(probe.calls.map(\.operation), [.canonicalize])
        }
    }

    func testCanonicalAliasWithinProfileReadsOnlyCanonicalTarget() async {
        let allowed = URL(fileURLWithPath: "/synthetic/Profile/Applications", isDirectory: true)
        let input = allowed.appendingPathComponent("Alias", isDirectory: true)
        let target = allowed.appendingPathComponent("Canonical Apps", isDirectory: true)
        let probe = AdmissionProbe(canonicalPaths: [input.path: target])
        let profile = AppSourceRootAdmissionContext(homeURL: home, fixedRoots: [], allowedSyntheticRoot: allowed)
        let result = await LocalAppSourceRootAdmitter(probe: probe).admit(input, context: profile)
        XCTAssertEqual(result, .accepted(target))
        XCTAssertEqual(probe.calls.map(\.url.path), [input.path, target.path])
    }

    func testProfileRejectsExternalSelectionsAndLookalikesBeforeAnyProbe() async {
        let allowed = URL(fileURLWithPath: "/synthetic/Profile/Applications", isDirectory: true)
        let profile = AppSourceRootAdmissionContext(homeURL: home,
                                                   fixedRoots: [URL(fileURLWithPath: "/Applications")],
                                                   allowedSyntheticRoot: allowed)
        for path in ["/Applications", "/synthetic/Outside", "/synthetic/Profile",
                     "/synthetic/Profile/ApplicationsOther", "/synthetic/Profile/Applications/../../Outside"] {
            let probe = AdmissionProbe()
            let result = await LocalAppSourceRootAdmitter(probe: probe).admit(
                URL(fileURLWithPath: path), context: profile)
            XCTAssertEqual(result, .rejected(.outsideSyntheticRoot))
            XCTAssertTrue(probe.calls.isEmpty, "External profile selections must not reach either probe")
        }
    }

    func testProfileCanonicalEscapeCannotReadExternalMetadataOrBeCoveredByProductionRoot() async {
        let allowed = URL(fileURLWithPath: "/synthetic/Profile/Applications", isDirectory: true)
        let input = allowed.appendingPathComponent("Alias", isDirectory: true)
        let external = URL(fileURLWithPath: "/Applications", isDirectory: true)
        let probe = AdmissionProbe(canonicalPaths: [input.path: external])
        let profile = AppSourceRootAdmissionContext(homeURL: home, fixedRoots: [external],
                                                   allowedSyntheticRoot: allowed)
        let result = await LocalAppSourceRootAdmitter(probe: probe).admit(input, context: profile)
        XCTAssertEqual(result, .rejected(.outsideSyntheticRoot))
        XCTAssertEqual(probe.calls.map(\.operation), [.canonicalize])
        XCTAssertFalse(probe.calls.contains { $0.operation == .metadata && $0.url == external })
    }

    func testProfileAllowsOnlyItsSyntheticApplicationsTreeWithoutProbingContextRoots() async {
        let allowed = URL(fileURLWithPath: "/synthetic/Profile/Applications", isDirectory: true)
        let input = allowed.appendingPathComponent("More Apps", isDirectory: true)
        let probe = AdmissionProbe()
        let profile = AppSourceRootAdmissionContext(homeURL: home,
                                                   fixedRoots: [URL(fileURLWithPath: "/Applications")],
                                                   allowedSyntheticRoot: allowed)
        let result = await LocalAppSourceRootAdmitter(probe: probe).admit(input, context: profile)
        XCTAssertEqual(result, .accepted(input))
        XCTAssertEqual(probe.calls.map(\.url.path), [input.path, input.path])
    }

    func testInvalidContextBoundariesFailClosedWithoutIO() async throws {
        let invalidHome = try XCTUnwrap(URL(string: "https://example.invalid/home"))
        let contexts = [
            AppSourceRootAdmissionContext(homeURL: invalidHome, fixedRoots: []),
            AppSourceRootAdmissionContext(homeURL: home, fixedRoots: [],
                                          allowedSyntheticRoot: URL(fileURLWithPath: "/"))
        ]
        for (value, rejection) in zip(contexts, [AppSourceRootRejection.invalidURL, .outsideSyntheticRoot]) {
            let probe = AdmissionProbe()
            let result = await LocalAppSourceRootAdmitter(probe: probe).admit(candidate, context: value)
            XCTAssertEqual(result, .rejected(rejection))
            XCTAssertTrue(probe.calls.isEmpty)
        }
    }

    @MainActor
    func testContextAndActorConstructionPerformNoIOAndCallsLeaveMainThread() async {
        let probe = AdmissionProbe()
        let value = AppSourceRootAdmissionContext(homeURL: home, fixedRoots: [])
        let service: any AppSourceRootAdmitting = LocalAppSourceRootAdmitter(probe: probe)
        XCTAssertTrue(probe.calls.isEmpty)
        let result = await service.admit(candidate, context: value)
        XCTAssertEqual(result, .accepted(candidate))
        XCTAssertEqual(probe.calls.count, 2)
        XCTAssertTrue(probe.calls.allSatisfy { !$0.wasMainThread },
                      "Actor-owned canonicalization and metadata must leave the MainActor caller")
    }

    func testNoArbitraryRootCountLimit() async {
        let probe = AdmissionProbe()
        let service = LocalAppSourceRootAdmitter(probe: probe)
        for index in 0..<32 {
            let input = URL(fileURLWithPath: "/synthetic/Extra-\(index)", isDirectory: true)
            let result = await service.admit(input, context: context)
            XCTAssertEqual(result, .accepted(input))
        }
    }

    func testProductionProbeAcceptsTemporaryDirectoryAndClassifiesMissingAndFile() async throws {
        let fixture = try temporaryFixture()
        let apps = fixture.appendingPathComponent("Applications", isDirectory: true)
        try FileManager.default.createDirectory(at: apps, withIntermediateDirectories: false)
        let file = fixture.appendingPathComponent("ordinary-file")
        try Data("fixture".utf8).write(to: file)
        let service = LocalAppSourceRootAdmitter()
        let value = AppSourceRootAdmissionContext(homeURL: fixture.appendingPathComponent("Home"), fixedRoots: [])
        let accepted = await service.admit(apps, context: value)
        let notDirectory = await service.admit(file, context: value)
        let missing = await service.admit(fixture.appendingPathComponent("Missing"), context: value)
        XCTAssertEqual(accepted, .accepted(apps))
        XCTAssertEqual(notDirectory, .rejected(.notDirectory))
        XCTAssertEqual(missing, .rejected(.missing))
    }

    func testRealFixtureSymlinksToHomeAndOutsideProfileStopBeforeMetadata() async throws {
        let fixture = try temporaryFixture()
        let apps = fixture.appendingPathComponent("Applications", isDirectory: true)
        let fixtureHome = fixture.appendingPathComponent("Home", isDirectory: true)
        let outside = fixture.appendingPathComponent("Outside", isDirectory: true)
        for directory in [apps, fixtureHome, outside] {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: false)
        }
        let homeAlias = apps.appendingPathComponent("HomeAlias")
        let outsideAlias = apps.appendingPathComponent("OutsideAlias")
        try FileManager.default.createSymbolicLink(at: homeAlias, withDestinationURL: fixtureHome)
        try FileManager.default.createSymbolicLink(at: outsideAlias, withDestinationURL: outside)
        for (input, profile, rejection) in [(homeAlias, Optional<URL>.none, AppSourceRootRejection.tooBroad),
                                             (outsideAlias, Optional(apps), .outsideSyntheticRoot)] {
            let probe = AdmissionProbe(resolveFixtureSymlinks: true)
            let value = AppSourceRootAdmissionContext(homeURL: fixtureHome, fixedRoots: [],
                                                      allowedSyntheticRoot: profile)
            let result = await LocalAppSourceRootAdmitter(probe: probe).admit(input, context: value)
            XCTAssertEqual(result, .rejected(rejection))
            XCTAssertEqual(probe.calls.map(\.operation), [.canonicalize])
        }
    }

    private func acceptedURL(_ result: AppSourceRootAdmissionResult) throws -> URL {
        guard case let .accepted(url) = result else {
            XCTFail("Expected canonical admission")
            throw AppSourceRootProbeFailure.unavailable
        }
        return url
    }

    private func temporaryFixture() throws -> URL {
        let fixture = FileManager.default.temporaryDirectory
            .appendingPathComponent("AppSourceRootAdmission-" + UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: fixture, withIntermediateDirectories: false)
        addTeardownBlock { try FileManager.default.removeItem(at: fixture) }
        return fixture.resolvingSymlinksInPath()
    }
}

/// Mutable observation is lock-protected; all responses are immutable synthetic metadata.
private final class AdmissionProbe: AppSourceRootFileSystemProbing, @unchecked Sendable {
    enum Operation: Equatable { case canonicalize, metadata }
    struct Call {
        let operation: Operation
        let url: URL
        let wasMainThread: Bool
    }

    private let lock = NSLock()
    private var recordedCalls: [Call] = []
    private let canonicalPaths: [String: URL]
    private let resultMetadata: AppSourceRootMetadata
    private let failure: AppSourceRootProbeFailure?
    private let failingOperation: Operation
    private let resolveFixtureSymlinks: Bool

    init(canonicalPaths: [String: URL] = [:], metadata: AppSourceRootMetadata = AdmissionProbe.localMetadata(),
         failure: AppSourceRootProbeFailure? = nil, failingOperation: Operation = .metadata,
         resolveFixtureSymlinks: Bool = false) {
        self.canonicalPaths = canonicalPaths
        resultMetadata = metadata
        self.failure = failure
        self.failingOperation = failingOperation
        self.resolveFixtureSymlinks = resolveFixtureSymlinks
    }

    var calls: [Call] {
        lock.lock()
        defer { lock.unlock() }
        return recordedCalls
    }

    func canonicalURL(for url: URL) throws -> URL {
        try record(.canonicalize, url: url)
        if resolveFixtureSymlinks {
            // Used only for paths created by temporaryFixture, never arbitrary real paths.
            return try FileManagerAppSourceRootProbe().canonicalURL(for: url)
        }
        return canonicalPaths[url.path] ?? url
    }

    func metadata(at url: URL) throws -> AppSourceRootMetadata {
        try record(.metadata, url: url)
        return resultMetadata
    }

    static func localMetadata(isDirectory: Bool? = true, isReadable: Bool = true,
                              volumeIsLocal: Bool? = true, isVolume: Bool? = false,
                              volumeURL: URL? = URL(fileURLWithPath: "/")) -> AppSourceRootMetadata {
        AppSourceRootMetadata(isDirectory: isDirectory, isReadable: isReadable,
                              volumeIsLocal: volumeIsLocal, isVolume: isVolume, volumeURL: volumeURL)
    }

    private func record(_ operation: Operation, url: URL) throws {
        lock.lock()
        recordedCalls.append(Call(operation: operation, url: url, wasMainThread: Thread.isMainThread))
        lock.unlock()
        if operation == failingOperation, let failure { throw failure }
    }
}
