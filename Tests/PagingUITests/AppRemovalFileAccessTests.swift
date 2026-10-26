import Darwin
import Foundation
import XCTest
@testable import PagingPrototypeApp

final class AppRemovalFileAccessTests: XCTestCase {
    private let syntheticRoot = URL(fileURLWithPath: "/SyntheticAppRemoval/Profile/Applications", isDirectory: true)
    private let syntheticSelf = URL(fileURLWithPath: "/SyntheticAppRemoval/Launchcopy.app", isDirectory: true)

    func testMinimalIdentityInitializationIsDeterministic() {
        XCTAssertEqual(AppRemovalFileIdentity(device: 7, inode: 11),
                       AppRemovalFileIdentity(device: 7, inode: 11))
        XCTAssertNotEqual(AppRemovalFileIdentity(device: 7, inode: 11),
                          AppRemovalFileIdentity(device: 7, inode: 12))
    }

    func testDecodedControlCharactersRejectBeforeAnyFilesystemProbe() async {
        let probe = AppRemovalFileProbeStub(), trash = AppRemovalFileTrashCounter()
        let service = LocalAppRemovalFileAccess(probe: probe, trash: { try trash.call($0) })
        for value in [0, 1, 9, 10, 13, 31, 127] {
            let control = String(UnicodeScalar(UInt8(value)))
            let url = URL(fileURLWithPath: "/SyntheticAppRemoval/Bad" + control + "Name.app")
            let result = await service.moveToTrash(candidate(at: url), allowedTestRoot: nil, selfBundleURL: syntheticSelf)
            XCTAssertEqual(result, .rejected(.unsafePath), "Control scalar: \(value)")
        }
        XCTAssertTrue(probe.calls.isEmpty)
        XCTAssertTrue(trash.calls.isEmpty)
    }

    func testLiteralPercentEncodedLookingNamesRemainTheActualSelectedPath() async throws {
        let fixture = try makeFixture(), trash = AppRemovalFileTrashCounter()
        let service = LocalAppRemovalFileAccess(trash: { try trash.call($0) })
        for name in ["Literal%00.app", "Literal%0A.app", "Literal%7F.app"] {
            let app = try fixture.makeApp(name)
            let inspection = await service.inspect(url: app, allowedTestRoot: fixture.applications, selfBundleURL: fixture.selfBundle)
            XCTAssertEqual(try eligibleCandidate(inspection).url, app)
        }
        XCTAssertTrue(trash.calls.isEmpty)
    }

    @MainActor
    func testConstructionDoesNoIOAndInspectionAndTrashLeaveMainThread() async throws {
        let probe = AppRemovalFileProbeStub()
        let trash = AppRemovalFileTrashCounter()
        let service: any AppRemovalFileAccess = LocalAppRemovalFileAccess(probe: probe, trash: { try trash.call($0) })
        XCTAssertTrue(probe.calls.isEmpty)
        XCTAssertTrue(trash.calls.isEmpty)
        let url = syntheticRoot.appendingPathComponent("Example.app", isDirectory: true)
        let inspection = await service.inspect(url: url, allowedTestRoot: syntheticRoot, selfBundleURL: syntheticSelf)
        let candidate = try eligibleCandidate(inspection)
        XCTAssertTrue(trash.calls.isEmpty, "Inspection alone cannot authorize Trash")
        let result = await service.moveToTrash(candidate, allowedTestRoot: syntheticRoot, selfBundleURL: syntheticSelf)
        XCTAssertEqual(result, .moved)
        XCTAssertFalse(probe.calls.isEmpty)
        XCTAssertTrue(probe.calls.allSatisfy { !$0.wasMainThread })
        XCTAssertEqual(trash.calls.map(\.url), [url])
        XCTAssertTrue(trash.calls.allSatisfy { !$0.wasMainThread })
    }

    func testRealAuthoredLocalAppIsEligibleWithAndWithoutProfile() async throws {
        let fixture = try makeFixture()
        let app = try fixture.makeApp("Example.app")
        let trash = AppRemovalFileTrashCounter()
        let service = LocalAppRemovalFileAccess(trash: { try trash.call($0) })
        for root in [Optional(fixture.applications), nil] {
            let inspection = await service.inspect(url: app, allowedTestRoot: root, selfBundleURL: fixture.selfBundle)
            let candidate = try eligibleCandidate(inspection)
            let disk = try FileManagerAppRemovalProbe().metadata(at: app)
            let parent = try FileManagerAppRemovalProbe().metadata(at: fixture.applications)
            XCTAssertEqual(candidate.url, app)
            XCTAssertEqual(candidate.identity.device, disk.device)
            XCTAssertEqual(candidate.identity.inode, disk.inode)
            XCTAssertEqual(candidate.identity.owner, getuid())
            XCTAssertEqual(candidate.identity.parentInode, parent.inode)
        }
        XCTAssertTrue(trash.calls.isEmpty)
    }

    func testInjectedSuccessfulReceiptCallsExactlyOneSelectedPath() async throws {
        let fixture = try makeFixture()
        let app = try fixture.makeApp("Selected.app")
        let neighbor = try fixture.makeApp("Neighbor.app")
        let trash = AppRemovalFileTrashCounter()
        let service = LocalAppRemovalFileAccess(trash: { try trash.call($0) })
        let inspection = await service.inspect(url: app, allowedTestRoot: fixture.applications,
                                               selfBundleURL: fixture.selfBundle)
        let result = await service.moveToTrash(try eligibleCandidate(inspection), allowedTestRoot: fixture.applications,
                                              selfBundleURL: fixture.selfBundle)
        XCTAssertEqual(result, .moved)
        XCTAssertEqual(trash.calls.map(\.url), [app])
        XCTAssertTrue(FileManager.default.fileExists(atPath: app.path), "The injected receipt does not move files")
        XCTAssertTrue(FileManager.default.fileExists(atPath: neighbor.path))
    }

    func testFailedReceiptDoesNotRetryDeleteOrModifyTheApp() async throws {
        let fixture = try makeFixture()
        let app = try fixture.makeApp("Failure.app")
        let trash = AppRemovalFileTrashCounter(shouldFail: true)
        let service = LocalAppRemovalFileAccess(trash: { try trash.call($0) })
        let inspection = await service.inspect(url: app, allowedTestRoot: fixture.applications,
                                               selfBundleURL: fixture.selfBundle)
        let candidate = try eligibleCandidate(inspection)
        let original = try FileManagerAppRemovalProbe().metadata(at: app)
        let result = await service.moveToTrash(candidate, allowedTestRoot: fixture.applications,
                                              selfBundleURL: fixture.selfBundle)
        XCTAssertEqual(result, .failed)
        XCTAssertEqual(trash.calls.map(\.url), [app])
        XCTAssertEqual(try FileManagerAppRemovalProbe().metadata(at: app), original)
        XCTAssertEqual(try Data(contentsOf: app.appendingPathComponent("authored-fixture.txt")), Data("fixture".utf8))
    }

    func testProfileRejectsExternalSelectionsAndComponentLookalikesBeforeAnyProbe() async {
        let probe = AppRemovalFileProbeStub()
        let trash = AppRemovalFileTrashCounter()
        let service = LocalAppRemovalFileAccess(probe: probe, trash: { try trash.call($0) })
        let outside = [
            "/SyntheticAppRemoval/Outside.app",
            "/SyntheticAppRemoval/Profile/ApplicationsOther/Example.app",
            "/SyntheticAppRemoval/Profile/Other/Example.app"
        ]
        for path in outside {
            let result = await service.inspect(url: URL(fileURLWithPath: path), allowedTestRoot: syntheticRoot,
                                               selfBundleURL: syntheticSelf)
            XCTAssertEqual(result, .rejected(.wrongProfile))
        }
        XCTAssertTrue(probe.calls.isEmpty)
        XCTAssertTrue(trash.calls.isEmpty)
    }

    func testProtectedRootsAndTrashNeverReachFilesystemOrTrashEvenWithProfile() async {
        let probe = AppRemovalFileProbeStub()
        let trash = AppRemovalFileTrashCounter()
        let service = LocalAppRemovalFileAccess(probe: probe, trash: { try trash.call($0) })
        for path in ["/System", "/system", "/Library", "/usr", "/bin", "/sbin", "/private", "/etc",
                     "/var", "/tmp", "/dev", "/cores", "/Network", "/net", "/automount", "/.vol",
                     "/SyntheticAppRemoval/.Trash", "/Volumes/Fixture/.Trashes"] {
            let root = URL(fileURLWithPath: path, isDirectory: true)
            let url = root.appendingPathComponent("Protected.app", isDirectory: true)
            for profile in [Optional(root), nil] {
                let inspection = await service.inspect(url: url, allowedTestRoot: profile, selfBundleURL: syntheticSelf)
                XCTAssertEqual(inspection, .rejected(.protectedLocation), path)
                let result = await service.moveToTrash(candidate(at: url), allowedTestRoot: profile,
                                                      selfBundleURL: syntheticSelf)
                XCTAssertEqual(result, .rejected(.protectedLocation), path)
            }
        }
        XCTAssertTrue(probe.calls.isEmpty)
        XCTAssertTrue(trash.calls.isEmpty)
    }

    func testMalformedRemoteAndNestedPathsFailBeforeProbe() async throws {
        let probe = AppRemovalFileProbeStub()
        let trash = AppRemovalFileTrashCounter()
        let service = LocalAppRemovalFileAccess(probe: probe, trash: { try trash.call($0) })
        let invalid: [(URL, AppRemovalRejection)] = [
            (try XCTUnwrap(URL(string: "https://example.invalid/Example.app")), .unsafePath),
            (try XCTUnwrap(URL(string: "file://server.invalid/Example.app")), .notLocal),
            (try XCTUnwrap(URL(string: "file:///SyntheticAppRemoval/Example.app?query")), .unsafePath),
            (try XCTUnwrap(URL(string: "file:///SyntheticAppRemoval/Example.app#fragment")), .unsafePath),
            (URL(fileURLWithPath: "/SyntheticAppRemoval/Example.txt"), .unsafePath),
            (URL(fileURLWithPath: "/SyntheticAppRemoval/Bad\u{0}Name.app"), .unsafePath),
            (URL(fileURLWithPath: "/SyntheticAppRemoval/Apps/../Example.app"), .unsafePath),
            (URL(fileURLWithPath: "/SyntheticAppRemoval/Outer.APP/Contents/Helper.app"), .unsafePath)
        ]
        for (url, rejection) in invalid {
            let result = await service.moveToTrash(candidate(at: url), allowedTestRoot: nil, selfBundleURL: syntheticSelf)
            XCTAssertEqual(result, .rejected(rejection))
        }
        XCTAssertTrue(probe.calls.isEmpty)
        XCTAssertTrue(trash.calls.isEmpty)
    }

    func testMissingRegularFileAndWrongExtensionAreRejectedWithoutTrash() async throws {
        let fixture = try makeFixture()
        let file = fixture.applications.appendingPathComponent("Regular.app")
        try Data("not a directory".utf8).write(to: file)
        let wrongExtension = fixture.applications.appendingPathComponent("Folder.txt", isDirectory: true)
        try FileManager.default.createDirectory(at: wrongExtension, withIntermediateDirectories: false)
        let trash = AppRemovalFileTrashCounter()
        let service = LocalAppRemovalFileAccess(trash: { try trash.call($0) })
        for (url, rejection) in [(fixture.applications.appendingPathComponent("Missing.app"), AppRemovalRejection.unavailable),
                                 (file, .unsafePath), (wrongExtension, .unsafePath)] {
            let result = await service.moveToTrash(candidate(at: url), allowedTestRoot: fixture.applications,
                                                   selfBundleURL: fixture.selfBundle)
            XCTAssertEqual(result, .rejected(rejection))
        }
        XCTAssertTrue(trash.calls.isEmpty)
    }

    func testRealBundleSymlinkAndSymlinkedAncestorDoNotReachTrash() async throws {
        let fixture = try makeFixture()
        let app = try fixture.makeApp("Original.app")
        let alias = fixture.applications.appendingPathComponent("Alias.app", isDirectory: true)
        try FileManager.default.createSymbolicLink(at: alias, withDestinationURL: app)
        let folder = fixture.applications.appendingPathComponent("Folder", isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: false)
        let child = folder.appendingPathComponent("Child.app", isDirectory: true)
        try FileManager.default.createDirectory(at: child, withIntermediateDirectories: false)
        let linkedFolder = fixture.applications.appendingPathComponent("LinkedFolder", isDirectory: true)
        try FileManager.default.createSymbolicLink(at: linkedFolder, withDestinationURL: folder)
        let trash = AppRemovalFileTrashCounter()
        let service = LocalAppRemovalFileAccess(trash: { try trash.call($0) })
        for url in [alias, linkedFolder.appendingPathComponent("Child.app", isDirectory: true)] {
            let result = await service.moveToTrash(candidate(at: url), allowedTestRoot: fixture.applications,
                                                   selfBundleURL: fixture.selfBundle)
            XCTAssertEqual(result, .rejected(.unsafePath))
        }
        XCTAssertTrue(trash.calls.isEmpty)
        XCTAssertTrue(FileManager.default.fileExists(atPath: app.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: child.path))
    }

    func testSymlinkedProfileRootAndItsAncestorsAreWrongProfile() async throws {
        let fixture = try makeFixture()
        _ = try fixture.makeApp("Original.app")
        let alias = fixture.root.appendingPathComponent("ApplicationsAlias", isDirectory: true)
        try FileManager.default.createSymbolicLink(at: alias, withDestinationURL: fixture.applications)
        let ancestorAlias = fixture.root.appendingPathComponent("ProfileAlias", isDirectory: true)
        let profile = fixture.root.appendingPathComponent("Profile", isDirectory: true)
        try FileManager.default.createDirectory(at: profile.appendingPathComponent("Applications/Example.app"),
                                                withIntermediateDirectories: true)
        try FileManager.default.createSymbolicLink(at: ancestorAlias, withDestinationURL: profile)
        let trash = AppRemovalFileTrashCounter()
        let service = LocalAppRemovalFileAccess(trash: { try trash.call($0) })
        for root in [alias, ancestorAlias.appendingPathComponent("Applications", isDirectory: true)] {
            let name = root == alias ? "Original.app" : "Example.app"
            let result = await service.moveToTrash(candidate(at: root.appendingPathComponent(name)),
                                                   allowedTestRoot: root, selfBundleURL: fixture.selfBundle)
            XCTAssertEqual(result, .rejected(.wrongProfile))
        }
        XCTAssertTrue(trash.calls.isEmpty)
    }

    func testSelfBundleItsAppAncestorAndCanonicalAliasAreProtected() async throws {
        let fixture = try makeFixture()
        let app = try fixture.makeApp("Self.app")
        let alias = fixture.root.appendingPathComponent("SelfAlias.app")
        try FileManager.default.createSymbolicLink(at: alias, withDestinationURL: app)
        let trash = AppRemovalFileTrashCounter()
        let service = LocalAppRemovalFileAccess(trash: { try trash.call($0) })
        for ownBundle in [app, app.appendingPathComponent("Contents/Helper.app"), alias] {
            let result = await service.moveToTrash(candidate(at: app), allowedTestRoot: fixture.applications,
                                                   selfBundleURL: ownBundle)
            XCTAssertEqual(result, .rejected(.protectedLocation))
        }
        XCTAssertTrue(trash.calls.isEmpty)
    }

    func testOwnerWriteFlagsPermissionsAndMountPointRejectionMatrix() async {
        let url = syntheticRoot.appendingPathComponent("Example.app", isDirectory: true)
        let variants: [(AppRemovalFileMetadata, URL?, AppRemovalRejection)] = [
            (AppRemovalFileProbeStub.metadata(for: url, owner: 502), nil, .notOwned),
            (AppRemovalFileProbeStub.metadata(for: url, prohibitsWrites: true), nil, .notWritable),
            (AppRemovalFileProbeStub.metadata(for: url), url, .notWritable),
            (AppRemovalFileProbeStub.metadata(for: url), syntheticRoot, .notWritable),
            (AppRemovalFileProbeStub.metadata(for: url, device: 2), nil, .unsafePath)
        ]
        for (metadata, unwritable, rejection) in variants {
            let probe = AppRemovalFileProbeStub()
            probe.setMetadata(metadata, at: url)
            if let unwritable { probe.setUnwritable(at: unwritable) }
            let trash = AppRemovalFileTrashCounter()
            let service = LocalAppRemovalFileAccess(probe: probe, trash: { try trash.call($0) })
            let result = await service.moveToTrash(candidate(at: url), allowedTestRoot: syntheticRoot,
                                                   selfBundleURL: syntheticSelf)
            XCTAssertEqual(result, .rejected(rejection))
            XCTAssertTrue(trash.calls.isEmpty)
        }
        let probe = AppRemovalFileProbeStub()
        probe.setMetadata(AppRemovalFileProbeStub.metadata(for: syntheticRoot, prohibitsWrites: true), at: syntheticRoot)
        let trash = AppRemovalFileTrashCounter()
        let service = LocalAppRemovalFileAccess(probe: probe, trash: { try trash.call($0) })
        let result = await service.moveToTrash(candidate(at: url), allowedTestRoot: syntheticRoot,
                                               selfBundleURL: syntheticSelf)
        XCTAssertEqual(result, .rejected(.notWritable))
        XCTAssertTrue(trash.calls.isEmpty)
    }

    func testLocalReadOnlyAndUnknownVolumesFailClosedForTargetAndParent() async {
        let url = syntheticRoot.appendingPathComponent("Example.app", isDirectory: true)
        let variants: [(AppRemovalVolumeMetadata, AppRemovalRejection)] = [
            (AppRemovalVolumeMetadata(isLocal: false, isReadOnly: false), .notLocal),
            (AppRemovalVolumeMetadata(isLocal: true, isReadOnly: true), .notWritable),
            (AppRemovalVolumeMetadata(isLocal: nil, isReadOnly: false), .unavailable),
            (AppRemovalVolumeMetadata(isLocal: true, isReadOnly: nil), .unavailable)
        ]
        for inspectedURL in [url, syntheticRoot] {
            for (volume, rejection) in variants {
                let probe = AppRemovalFileProbeStub()
                probe.setVolume(volume, at: inspectedURL)
                let trash = AppRemovalFileTrashCounter()
                let service = LocalAppRemovalFileAccess(probe: probe, trash: { try trash.call($0) })
                let result = await service.moveToTrash(candidate(at: url), allowedTestRoot: syntheticRoot,
                                                       selfBundleURL: syntheticSelf)
                XCTAssertEqual(result, .rejected(rejection))
                XCTAssertTrue(trash.calls.isEmpty)
            }
        }
    }

    func testRootProfileForeignOwnerAndMalformedContextAreRejected() async throws {
        let url = syntheticRoot.appendingPathComponent("Example.app", isDirectory: true)
        let probe = AppRemovalFileProbeStub()
        probe.setMetadata(AppRemovalFileProbeStub.metadata(for: syntheticRoot, owner: 502), at: syntheticRoot)
        let trash = AppRemovalFileTrashCounter()
        let service = LocalAppRemovalFileAccess(probe: probe, trash: { try trash.call($0) })
        for root in [syntheticRoot, URL(fileURLWithPath: "/"),
                     try XCTUnwrap(URL(string: "https://example.invalid/Applications"))] {
            let result = await service.moveToTrash(candidate(at: url), allowedTestRoot: root, selfBundleURL: syntheticSelf)
            XCTAssertEqual(result, .rejected(.wrongProfile))
        }
        let invalidSelf = try XCTUnwrap(URL(string: "https://example.invalid/Self.app"))
        let result = await service.moveToTrash(candidate(at: url), allowedTestRoot: nil, selfBundleURL: invalidSelf)
        XCTAssertEqual(result, .rejected(.unsafePath))
        XCTAssertTrue(trash.calls.isEmpty)
    }

    func testReplacementOfRealAppAfterConfirmationRejectsChangedIdentity() async throws {
        let fixture = try makeFixture()
        let app = try fixture.makeApp("Selected.app")
        let trash = AppRemovalFileTrashCounter()
        let service = LocalAppRemovalFileAccess(trash: { try trash.call($0) })
        let inspection = await service.inspect(url: app, allowedTestRoot: fixture.applications,
                                               selfBundleURL: fixture.selfBundle)
        let original = try eligibleCandidate(inspection)
        // Preserve the original inode alive, then author a replacement at its path.
        let saved = fixture.applications.appendingPathComponent("SavedOriginal.app")
        try FileManager.default.moveItem(at: app, to: saved)
        _ = try fixture.makeApp("Selected.app")
        let result = await service.moveToTrash(original, allowedTestRoot: fixture.applications,
                                               selfBundleURL: fixture.selfBundle)
        XCTAssertEqual(result, .rejected(.changed))
        XCTAssertTrue(trash.calls.isEmpty)
        XCTAssertTrue(FileManager.default.fileExists(atPath: saved.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: app.path))
    }

    func testReplacementOfRealParentRejectsEvenWhenAppInodeIsPreserved() async throws {
        let fixture = try makeFixture()
        let app = try fixture.makeApp("Selected.app")
        let trash = AppRemovalFileTrashCounter()
        let service = LocalAppRemovalFileAccess(trash: { try trash.call($0) })
        let inspection = await service.inspect(url: app, allowedTestRoot: fixture.applications,
                                               selfBundleURL: fixture.selfBundle)
        let original = try eligibleCandidate(inspection)
        let savedParent = fixture.root.appendingPathComponent("SavedApplications", isDirectory: true)
        try FileManager.default.moveItem(at: fixture.applications, to: savedParent)
        try FileManager.default.createDirectory(at: fixture.applications, withIntermediateDirectories: false)
        try FileManager.default.moveItem(at: savedParent.appendingPathComponent("Selected.app"), to: app)
        XCTAssertEqual(try FileManagerAppRemovalProbe().metadata(at: app).inode, original.identity.inode)
        let result = await service.moveToTrash(original, allowedTestRoot: fixture.applications,
                                               selfBundleURL: fixture.selfBundle)
        XCTAssertEqual(result, .rejected(.changed))
        XCTAssertTrue(trash.calls.isEmpty)
    }

    func testFinalInspectionRechecksOwnershipPermissionsVolumeAndProfile() async throws {
        let url = syntheticRoot.appendingPathComponent("Example.app", isDirectory: true)
        for rejection in [AppRemovalRejection.notOwned, .notWritable, .notLocal, .unavailable, .wrongProfile] {
            let probe = AppRemovalFileProbeStub()
            let trash = AppRemovalFileTrashCounter()
            let service = LocalAppRemovalFileAccess(probe: probe, trash: { try trash.call($0) })
            let inspection = await service.inspect(url: url, allowedTestRoot: syntheticRoot, selfBundleURL: syntheticSelf)
            let original = try eligibleCandidate(inspection)
            var root = syntheticRoot
            switch rejection {
            case .notOwned: probe.setMetadata(AppRemovalFileProbeStub.metadata(for: url, owner: 502), at: url)
            case .notWritable: probe.setUnwritable(at: syntheticRoot)
            case .notLocal: probe.setVolume(AppRemovalVolumeMetadata(isLocal: false, isReadOnly: false), at: url)
            case .unavailable: probe.setUnavailable(at: url)
            case .wrongProfile: root = syntheticRoot.appendingPathComponent("AnotherProfile", isDirectory: true)
            default: XCTFail("Unexpected test variant")
            }
            let result = await service.moveToTrash(original, allowedTestRoot: root, selfBundleURL: syntheticSelf)
            XCTAssertEqual(result, .rejected(rejection))
            XCTAssertTrue(trash.calls.isEmpty)
        }
    }

    func testFinalInspectionRejectsReplacedAncestorBeforeReadingItsTarget() async throws {
        let url = syntheticRoot.appendingPathComponent("Folder/Example.app", isDirectory: true)
        let folder = url.deletingLastPathComponent()
        let probe = AppRemovalFileProbeStub()
        let trash = AppRemovalFileTrashCounter()
        let service = LocalAppRemovalFileAccess(probe: probe, trash: { try trash.call($0) })
        let inspection = await service.inspect(url: url, allowedTestRoot: syntheticRoot, selfBundleURL: syntheticSelf)
        let original = try eligibleCandidate(inspection)
        let previousTargetReads = probe.calls.filter { $0.url == url }.count
        probe.setMetadata(AppRemovalFileProbeStub.metadata(for: folder, isDirectory: false, isSymbolicLink: true), at: folder)
        let result = await service.moveToTrash(original, allowedTestRoot: syntheticRoot, selfBundleURL: syntheticSelf)
        XCTAssertEqual(result, .rejected(.unsafePath))
        XCTAssertEqual(probe.calls.filter { $0.url == url }.count, previousTargetReads)
        XCTAssertTrue(trash.calls.isEmpty)
    }

    func testChangesDuringInspectionAndForgedIdentitiesCannotReachTrash() async throws {
        let url = syntheticRoot.appendingPathComponent("Example.app", isDirectory: true)
        let trash = AppRemovalFileTrashCounter()
        let unstableProbe = AppRemovalFileProbeStub()
        unstableProbe.changeInodeOnSecondRead(at: url)
        let unstable = LocalAppRemovalFileAccess(probe: unstableProbe, trash: { try trash.call($0) })
        let result = await unstable.moveToTrash(candidate(at: url), allowedTestRoot: syntheticRoot, selfBundleURL: syntheticSelf)
        XCTAssertEqual(result, .rejected(.changed))
        let stable = LocalAppRemovalFileAccess(probe: AppRemovalFileProbeStub(), trash: { try trash.call($0) })
        let forgedResult = await stable.moveToTrash(candidate(at: url), allowedTestRoot: syntheticRoot, selfBundleURL: syntheticSelf)
        XCTAssertEqual(forgedResult, .rejected(.changed))
        XCTAssertTrue(trash.calls.isEmpty)
    }

    func testAbsentContentsOrInfoPlistCannotReachTrash() async throws {
        let fixture = try makeFixture()
        let trash = AppRemovalFileTrashCounter()
        let service = LocalAppRemovalFileAccess(trash: { try trash.call($0) })
        for (index, relativePath) in ["Contents", "Contents/Info.plist"].enumerated() {
            let app = try fixture.makeApp("Absent-\(index).app")
            try FileManager.default.removeItem(at: app.appendingPathComponent(relativePath))
            let result = await service.moveToTrash(candidate(at: app), allowedTestRoot: fixture.applications,
                                                   selfBundleURL: fixture.selfBundle)
            XCTAssertEqual(result, .rejected(.unavailable))
        }
        XCTAssertTrue(trash.calls.isEmpty)
    }

    func testMalformedPlistWrongMarkersAndOversizeCannotReachTrash() async throws {
        let fixture = try makeFixture()
        let trash = AppRemovalFileTrashCounter()
        let service = LocalAppRemovalFileAccess(trash: { try trash.call($0) })
        var missingExecutable = AppRemovalFileFixture.validInfo
        missingExecutable.removeValue(forKey: "CFBundleExecutable")
        var wrongPackage = AppRemovalFileFixture.validInfo
        wrongPackage["CFBundlePackageType"] = "FMWK"
        var emptyIdentifier = AppRemovalFileFixture.validInfo
        emptyIdentifier["CFBundleIdentifier"] = ""
        var escapingExecutable = AppRemovalFileFixture.validInfo
        escapingExecutable["CFBundleExecutable"] = "../Outside"
        var malformedIdentifier = AppRemovalFileFixture.validInfo
        malformedIdentifier["CFBundleIdentifier"] = "invalid/identifier"
        let values: [Any] = [[String](), [String: String](), missingExecutable, wrongPackage, emptyIdentifier,
                             escapingExecutable, malformedIdentifier]
        var invalidData = try values.map {
            try PropertyListSerialization.data(fromPropertyList: $0, format: .xml, options: 0)
        }
        invalidData.append(Data("not a property list".utf8))
        invalidData.append(Data(repeating: 0x61, count: 1_048_577))
        for (index, data) in invalidData.enumerated() {
            let app = try fixture.makeApp("Malformed-\(index).app")
            try data.write(to: app.appendingPathComponent("Contents/Info.plist"))
            let result = await service.moveToTrash(candidate(at: app), allowedTestRoot: fixture.applications,
                                                   selfBundleURL: fixture.selfBundle)
            XCTAssertEqual(result, .rejected(.unsafePath))
        }
        XCTAssertTrue(trash.calls.isEmpty)
    }

    func testSymlinkedContentsAndInfoAndNonregularPlistCannotReachTrash() async throws {
        let fixture = try makeFixture()
        let trash = AppRemovalFileTrashCounter()
        let service = LocalAppRemovalFileAccess(trash: { try trash.call($0) })
        for (index, relativePath) in ["Contents", "Contents/Info.plist"].enumerated() {
            let app = try fixture.makeApp("LinkedMetadata-\(index).app")
            let original = app.appendingPathComponent(relativePath)
            let saved = fixture.root.appendingPathComponent("SavedMetadata-\(index)")
            try FileManager.default.moveItem(at: original, to: saved)
            try FileManager.default.createSymbolicLink(at: original, withDestinationURL: saved)
            let result = await service.moveToTrash(candidate(at: app), allowedTestRoot: fixture.applications,
                                                   selfBundleURL: fixture.selfBundle)
            XCTAssertEqual(result, .rejected(.unsafePath))
        }
        for useFIFO in [false, true] {
            let app = try fixture.makeApp(useFIFO ? "FIFO.app" : "DirectoryPlist.app")
            let info = app.appendingPathComponent("Contents/Info.plist")
            try FileManager.default.removeItem(at: info)
            if useFIFO {
                let status = info.withUnsafeFileSystemRepresentation { path -> Int32 in
                    guard let path else { return -1 }
                    return mkfifo(path, 0o600)
                }
                XCTAssertEqual(status, 0)
            } else {
                try FileManager.default.createDirectory(at: info, withIntermediateDirectories: false)
            }
            let result = await service.moveToTrash(candidate(at: app), allowedTestRoot: fixture.applications,
                                                   selfBundleURL: fixture.selfBundle)
            XCTAssertEqual(result, .rejected(.unsafePath))
        }
        XCTAssertTrue(trash.calls.isEmpty)
    }

    func testPlistInPlaceSubstitutionPreservingBundleAndFileInodesIsRejected() async throws {
        let fixture = try makeFixture()
        let app = try fixture.makeApp("InPlace.app")
        let info = app.appendingPathComponent("Contents/Info.plist")
        let trash = AppRemovalFileTrashCounter()
        let service = LocalAppRemovalFileAccess(trash: { try trash.call($0) })
        let inspection = await service.inspect(url: app, allowedTestRoot: fixture.applications,
                                               selfBundleURL: fixture.selfBundle)
        let original = try eligibleCandidate(inspection)
        let originalBundle = try XCTUnwrap(original.identity.bundle)
        let attributes = try FileManager.default.attributesOfItem(atPath: info.path)
        var dictionary = AppRemovalFileFixture.validInfo
        dictionary["CFBundleIdentifier"] = "invalid.appremoval.changed"
        let data = try PropertyListSerialization.data(fromPropertyList: dictionary, format: .xml, options: 0)
        let handle = try FileHandle(forWritingTo: info)
        defer { try? handle.close() }
        try handle.truncate(atOffset: 0)
        try handle.write(contentsOf: data)
        if let modification = attributes[.modificationDate] {
            try FileManager.default.setAttributes([.modificationDate: modification], ofItemAtPath: info.path)
        }
        XCTAssertEqual(try FileManagerAppRemovalProbe().metadata(at: app).inode, original.identity.inode)
        XCTAssertEqual(try FileManagerAppRemovalProbe().metadata(at: info).inode, originalBundle.file.inode)
        let changedInspection = await service.inspect(url: app, allowedTestRoot: fixture.applications,
                                                      selfBundleURL: fixture.selfBundle)
        let changed = try eligibleCandidate(changedInspection)
        XCTAssertNotEqual(changed.identity.bundle?.digest, originalBundle.digest)
        let result = await service.moveToTrash(original, allowedTestRoot: fixture.applications,
                                               selfBundleURL: fixture.selfBundle)
        XCTAssertEqual(result, .rejected(.changed))
        XCTAssertTrue(trash.calls.isEmpty)
    }

    func testReplacedOrInvalidatedPlistRevokesAnEarlierCandidate() async throws {
        let fixture = try makeFixture()
        let trash = AppRemovalFileTrashCounter()
        let service = LocalAppRemovalFileAccess(trash: { try trash.call($0) })
        for makeMalformed in [false, true] {
            let app = try fixture.makeApp(makeMalformed ? "Invalidated.app" : "ReplacedPlist.app")
            let info = app.appendingPathComponent("Contents/Info.plist")
            let inspection = await service.inspect(url: app, allowedTestRoot: fixture.applications,
                                                   selfBundleURL: fixture.selfBundle)
            let original = try eligibleCandidate(inspection)
            if makeMalformed {
                try Data("invalidated".utf8).write(to: info)
            } else {
                let saved = fixture.root.appendingPathComponent("SavedInfo.plist")
                try FileManager.default.moveItem(at: info, to: saved)
                try PropertyListSerialization.data(fromPropertyList: AppRemovalFileFixture.validInfo, format: .xml,
                                                    options: 0).write(to: info)
            }
            let result = await service.moveToTrash(original, allowedTestRoot: fixture.applications,
                                                   selfBundleURL: fixture.selfBundle)
            XCTAssertEqual(result, .rejected(makeMalformed ? .unsafePath : .changed))
        }
        XCTAssertTrue(trash.calls.isEmpty)
    }

    private func candidate(at url: URL) -> AppRemovalCandidate {
        AppRemovalCandidate(url: url, identity: AppRemovalFileIdentity(device: 1, inode: 1))
    }

    private func eligibleCandidate(_ inspection: AppRemovalInspection) throws -> AppRemovalCandidate {
        guard case .eligible(let candidate) = inspection else {
            XCTFail("Expected an eligible authored or synthetic fixture, received \(inspection)")
            throw AppRemovalFileTestError.unexpectedInspection
        }
        return candidate
    }

    private func makeFixture() throws -> AppRemovalFileFixture {
        // Use unique project-local temporary fixtures. /tmp and /private remain
        // protected even when allowedTestRoot is supplied; tests never weaken it.
        let project = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
            .deletingLastPathComponent().deletingLastPathComponent().resolvingSymlinksInPath()
        let root = project.appendingPathComponent(".build/candidates/AppRemovalFileAccess-" + UUID().uuidString,
                                                 isDirectory: true)
        let fixture = AppRemovalFileFixture(root: root)
        try FileManager.default.createDirectory(at: fixture.applications, withIntermediateDirectories: true)
        addTeardownBlock { try FileManager.default.removeItem(at: root) }
        return fixture
    }
}

private enum AppRemovalFileTestError: Error { case unexpectedInspection, injectedFailure }

private struct AppRemovalFileFixture {
    let root: URL
    var applications: URL { root.appendingPathComponent("Applications", isDirectory: true) }
    var selfBundle: URL { root.appendingPathComponent("Launchcopy.app", isDirectory: true) }

    static let validInfo = ["CFBundlePackageType": "APPL", "CFBundleIdentifier": "invalid.appremoval.fixture",
                            "CFBundleExecutable": "Fixture"]

    func makeApp(_ name: String) throws -> URL {
        let url = applications.appendingPathComponent(name, isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: false)
        let contents = url.appendingPathComponent("Contents", isDirectory: true)
        try FileManager.default.createDirectory(at: contents, withIntermediateDirectories: false)
        try PropertyListSerialization.data(fromPropertyList: Self.validInfo, format: .xml, options: 0)
            .write(to: contents.appendingPathComponent("Info.plist"))
        try Data("fixture".utf8).write(to: url.appendingPathComponent("authored-fixture.txt"))
        return url
    }
}

/// Only records a receipt or throws. No platform Trash, process, or UI calls.
private final class AppRemovalFileTrashCounter: @unchecked Sendable {
    struct Call { let url: URL; let wasMainThread: Bool }
    private let lock = NSLock()
    private var recorded: [Call] = []
    private let shouldFail: Bool

    init(shouldFail: Bool = false) { self.shouldFail = shouldFail }

    var calls: [Call] {
        lock.lock()
        defer { lock.unlock() }
        return recorded
    }

    func call(_ url: URL) throws {
        lock.lock()
        recorded.append(Call(url: url, wasMainThread: Thread.isMainThread))
        lock.unlock()
        if shouldFail { throw AppRemovalFileTestError.injectedFailure }
    }
}

/// All mutable scripting and observations are protected by the same lock.
private final class AppRemovalFileProbeStub: AppRemovalFileProbing, @unchecked Sendable {
    struct Call { let url: URL; let wasMainThread: Bool }
    let currentUserID: UInt32 = 501
    private let lock = NSLock()
    private var recorded: [Call] = []
    private var metadataByPath: [String: AppRemovalFileMetadata] = [:]
    private var volumeByPath: [String: AppRemovalVolumeMetadata] = [:]
    private var unwritable: Set<String> = []
    private var unavailable: Set<String> = []
    private var changing: Set<String> = []
    private var reads: [String: Int] = [:]

    var calls: [Call] {
        lock.lock()
        defer { lock.unlock() }
        return recorded
    }

    static func metadata(for url: URL, owner: UInt32 = 501, isDirectory: Bool = true,
                         isSymbolicLink: Bool = false, prohibitsWrites: Bool = false,
                         device: UInt64 = 1, inode: UInt64? = nil) -> AppRemovalFileMetadata {
        // Stable across executions; Hashable's randomized hash is inappropriate
        // for a disk identity fixture.
        let stableInode = url.path.utf8.reduce(UInt64(5381)) { ($0 &* 33) &+ UInt64($1) }
        return AppRemovalFileMetadata(device: device, inode: inode ?? stableInode, owner: owner,
                                      birthSeconds: 1, birthNanoseconds: 0, mode: 0o755, isDirectory: isDirectory,
                                      isSymbolicLink: isSymbolicLink, prohibitsWrites: prohibitsWrites)
    }

    func metadata(at url: URL) throws -> AppRemovalFileMetadata {
        lock.lock()
        defer { lock.unlock() }
        record(url)
        if unavailable.contains(url.path) { throw AppRemovalFileTestError.injectedFailure }
        reads[url.path, default: 0] += 1
        if changing.contains(url.path), reads[url.path, default: 0] >= 2 {
            return Self.metadata(for: url, inode: 123)
        }
        return metadataByPath[url.path] ?? Self.metadata(for: url)
    }

    func isWritableDirectory(at url: URL) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        record(url)
        return !unwritable.contains(url.path)
    }

    func volume(at url: URL) throws -> AppRemovalVolumeMetadata {
        lock.lock()
        defer { lock.unlock() }
        record(url)
        return volumeByPath[url.path] ?? AppRemovalVolumeMetadata(isLocal: true, isReadOnly: false)
    }

    func bundleMetadata(at url: URL, expectedDirectory: AppRemovalFileMetadata) throws -> AppRemovalBundleFileIdentity {
        lock.lock()
        defer { lock.unlock() }
        record(url)
        return AppRemovalBundleFileIdentity(
            contents: Self.metadata(for: url.appendingPathComponent("Contents")),
            file: Self.metadata(for: url.appendingPathComponent("Contents/Info.plist"), isDirectory: false),
            byteCount: 100, modifiedSeconds: 1, modifiedNanoseconds: 0, changedSeconds: 1, changedNanoseconds: 0,
            digest: "synthetic-valid-app-plist"
        )
    }

    func setMetadata(_ metadata: AppRemovalFileMetadata, at url: URL) {
        lock.lock()
        defer { lock.unlock() }
        metadataByPath[url.path] = metadata
    }

    func setVolume(_ volume: AppRemovalVolumeMetadata, at url: URL) {
        lock.lock()
        defer { lock.unlock() }
        volumeByPath[url.path] = volume
    }

    func setUnwritable(at url: URL) {
        lock.lock()
        defer { lock.unlock() }
        unwritable.insert(url.path)
    }

    func setUnavailable(at url: URL) {
        lock.lock()
        defer { lock.unlock() }
        unavailable.insert(url.path)
    }

    func changeInodeOnSecondRead(at url: URL) {
        lock.lock()
        defer { lock.unlock() }
        changing.insert(url.path)
    }

    private func record(_ url: URL) {
        recorded.append(Call(url: url, wasMainThread: Thread.isMainThread))
    }
}
