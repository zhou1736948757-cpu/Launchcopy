import AppKit
import XCTest
@testable import PagingPrototypeApp

@MainActor
final class WallpaperLoadStateTests: XCTestCase {
    private let enabled = LaunchcopyMaterialPolicy(reduceTransparency: false, increaseContrast: false, reduceMotion: false)
    private let disabled = LaunchcopyMaterialPolicy(reduceTransparency: true, increaseContrast: false, reduceMotion: false)

    private func image() throws -> CGImage {
        let context = try XCTUnwrap(CGContext(data: nil, width: 1, height: 1, bitsPerComponent: 8,
            bytesPerRow: 4, space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
        return try XCTUnwrap(context.makeImage())
    }

    func testReportsReadyAndFailureOnlyAfterCurrentRenderCompletion() throws {
        var completions: [@MainActor (CGImage?) -> Void] = []
        let controller = WallpaperBackdropController(imageLoader: { _, _, done in completions.append(done) },
            sourceResolver: { _ in URL(fileURLWithPath: "/SyntheticPrivateSource") })
        let host = NSView(frame: NSRect(x: 0, y: 0, width: 120, height: 80))
        controller.attach(to: host)
        var states: [WallpaperBackdropController.LoadState] = []
        controller.onLoadStateChange = { states.append($0) }
        controller.refresh(for: nil, policy: enabled)
        XCTAssertEqual(controller.loadState, .loading)
        completions[0](try image())
        XCTAssertEqual(controller.loadState, .ready)
        controller.refresh(for: nil, policy: enabled)
        completions[1](nil)
        XCTAssertEqual(controller.loadState, .renderFailed)
        XCTAssertEqual(states, [.loading, .ready, .loading, .renderFailed])
        XCTAssertFalse(states.map(\.rawValue).joined().contains("SyntheticPrivateSource"))
    }

    func testMissingSourceAndPolicyDisabledAreDistinctAndNeitherStartsLoader() {
        var resolutions = 0
        let controller = WallpaperBackdropController(imageLoader: { _, _, _ in XCTFail("No source must not render") },
            sourceResolver: { _ in resolutions += 1; return nil })
        let host = NSView(frame: NSRect(x: 0, y: 0, width: 120, height: 80))
        controller.attach(to: host)
        controller.refresh(for: nil, policy: disabled)
        XCTAssertEqual(controller.loadState, .policyDisabled)
        XCTAssertEqual(resolutions, 0)
        controller.refresh(for: nil, policy: enabled)
        XCTAssertEqual(controller.loadState, .sourceUnavailable)
        XCTAssertEqual(resolutions, 1)
    }

    func testObsoleteReadyOrFailedResultCannotReplaceCurrentState() throws {
        var completions: [@MainActor (CGImage?) -> Void] = []
        let controller = WallpaperBackdropController(imageLoader: { _, _, done in completions.append(done) },
            sourceResolver: { _ in URL(fileURLWithPath: "/SyntheticSource") })
        let host = NSView(frame: NSRect(x: 0, y: 0, width: 120, height: 80))
        controller.attach(to: host)
        controller.refresh(for: nil, policy: enabled)
        controller.refresh(for: nil, policy: disabled)
        completions[0](try image())
        XCTAssertEqual(controller.loadState, .policyDisabled)
        controller.refresh(for: nil, policy: enabled)
        controller.refresh(for: nil, policy: enabled)
        completions[2](try image())
        completions[1](nil)
        XCTAssertEqual(controller.loadState, .ready)
    }

    func testHostReplacementResetsStateAndRejectsOldCompletion() throws {
        var done: (@MainActor (CGImage?) -> Void)?
        let controller = WallpaperBackdropController(imageLoader: { _, _, callback in done = callback },
            sourceResolver: { _ in URL(fileURLWithPath: "/SyntheticSource") })
        let original = NSView(frame: NSRect(x: 0, y: 0, width: 120, height: 80))
        let replacement = NSView(frame: original.frame)
        controller.attach(to: original)
        controller.refresh(for: nil, policy: enabled)
        controller.attach(to: replacement)
        XCTAssertEqual(controller.loadState, .idle)
        try XCTUnwrap(done)(image())
        XCTAssertEqual(controller.loadState, .idle)
    }

    func testWindowHelpIsUntouchedForProductionAndUnresolvedProfile() throws {
        _ = NSApplication.shared
        let window = NSWindow(contentRect: .zero, styleMask: [.titled], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        window.setAccessibilityHelp("Existing help")
        let controller = WallpaperBackdropController(imageLoader: { _, _, _ in }, sourceResolver: { _ in nil })
        for options in [AppArguments.Options.default,
                        try AppArguments.parse(["--ui-test-windowed", "--ui-test-profile", "gui"]).get()] {
            let owner = AppDelegate(options: options)
            owner.installIsolatedWallpaperDiagnostics(backdrop: controller, window: window)
            XCTAssertNil(controller.onLoadStateChange)
            XCTAssertEqual(window.accessibilityHelp(), "Existing help")
            XCTAssertFalse(window.isVisible)
        }
    }

    func testResolvedProfileReceivesOnlyNeutralCurrentStateInWindowHelp() throws {
        _ = NSApplication.shared
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("wallpaper-state-" + UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let app = root.appendingPathComponent(".build/candidates/test/Test.app")
        try FileManager.default.createDirectory(at: app, withIntermediateDirectories: true)
        let owner = AppDelegate(options: try AppArguments.parse(["--ui-test-windowed", "--ui-test-profile", "gui"]).get())
        try owner.configureUITestProfile(bundleURL: app)
        let window = NSWindow(contentRect: .zero, styleMask: [.titled], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        let controller = WallpaperBackdropController(imageLoader: { _, _, _ in XCTFail("Missing source") }, sourceResolver: { _ in nil })
        let host = NSView(frame: NSRect(x: 0, y: 0, width: 120, height: 80))
        controller.attach(to: host)
        owner.installIsolatedWallpaperDiagnostics(backdrop: controller, window: window)
        XCTAssertEqual(window.accessibilityHelp(), "Wallpaper diagnostic: idle")
        controller.refresh(for: nil, policy: disabled)
        XCTAssertEqual(window.accessibilityHelp(), "Wallpaper diagnostic: policy-disabled")
        controller.refresh(for: nil, policy: enabled)
        XCTAssertEqual(window.accessibilityHelp(), "Wallpaper diagnostic: source-unavailable")
        XCTAssertFalse(window.isVisible)
    }
}
