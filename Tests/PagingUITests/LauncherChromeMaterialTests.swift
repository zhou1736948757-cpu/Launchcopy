import AppKit
import XCTest
@testable import PagingPrototypeApp

@MainActor
final class LauncherChromeMaterialTests: XCTestCase {
    private func policy(transparency: Bool, contrast: Bool, motion: Bool = false) -> LaunchcopyMaterialPolicy {
        .init(reduceTransparency: transparency, increaseContrast: contrast, reduceMotion: motion)
    }

    func testOpaqueChromeTokenHonorsReduceTransparencyIndependentlyOfMotionAndContrast() {
        for transparency in [false, true] {
            for contrast in [false, true] {
                for motion in [false, true] {
                    let value = policy(transparency: transparency, contrast: contrast, motion: motion)
                    XCTAssertEqual(LaunchcopyVisualTokens.chromeFill(policy: value).alphaComponent,
                                   transparency ? 1 : 0.32, accuracy: 0.001)
                    XCTAssertEqual(value.allowsWallpaperBlur, !transparency)
                }
            }
        }
    }

    private func button(in host: NSView) throws -> NSButton {
        try XCTUnwrap(host.subviews.compactMap { $0 as? NSButton }.first {
            $0.identifier?.rawValue == "launchcopy.launcherSettingsButton"
        })
    }

    func testActualDetachedSettingsControlRefreshesWithoutChangingIdentityFrameOrAction() throws {
        let owner = AppDelegate(options: .default)
        let host = NSView(frame: NSRect(x: 0, y: 0, width: 1000, height: 800))
        owner.container = host
        owner.installLauncherSettingsButton(in: host)
        let control = try button(in: host), layer = try XCTUnwrap(control.layer)
        let frame = control.frame, action = control.action
        for transparency in [false, true] {
            for contrast in [false, true] {
                let value = policy(transparency: transparency, contrast: contrast)
                owner.refreshLauncherChromeMaterial(policy: value)
                XCTAssertEqual(try XCTUnwrap(layer.backgroundColor).alpha,
                               transparency ? 1 : 0.32, accuracy: 0.001)
                XCTAssertEqual(layer.isOpaque, transparency)
                XCTAssertEqual(layer.borderWidth, contrast ? 2 : 0)
                XCTAssertEqual(try XCTUnwrap(layer.borderColor).alpha, contrast ? 1 : 0, accuracy: 0.001)
                XCTAssertTrue(try button(in: host) === control)
                XCTAssertEqual(control.frame, frame); XCTAssertEqual(control.action, action)
                XCTAssertTrue(control.target as? AppDelegate === owner)
                XCTAssertEqual(control.accessibilityLabel(), "设置")
                XCTAssertNil(owner.lastWorkspacePersistenceOutcome)
                XCTAssertEqual(owner.resolvedLayoutBuildCount, 0)
            }
        }
    }

    func testAccessibilityChangeConsumerUpdatesExistingAndSubsequentlyCreatedChrome() throws {
        let owner = AppDelegate(options: .default)
        let host = NSView(frame: NSRect(x: 0, y: 0, width: 1000, height: 800))
        owner.container = host
        let high = policy(transparency: true, contrast: true)
        owner.handleAccessibilityDisplayChange(wallpaperPolicy: high)
        owner.installLauncherSettingsButton(in: host)
        let control = try button(in: host)
        XCTAssertEqual(try XCTUnwrap(control.layer?.backgroundColor).alpha, 1)
        XCTAssertEqual(control.layer?.borderWidth, 2)
        owner.handleAccessibilityDisplayChange(wallpaperPolicy: policy(transparency: false, contrast: false))
        XCTAssertEqual(try XCTUnwrap(control.layer?.backgroundColor).alpha, 0.32, accuracy: 0.001)
        XCTAssertEqual(control.layer?.borderWidth, 0)
        XCTAssertFalse(control.layer?.isOpaque ?? true)
    }
}
