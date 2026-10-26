import AppKit
import LauncherLocalization
import XCTest
@testable import PagingPrototypeApp

/// Unshown, in-memory layout checks. Intrinsic growth alone is not window growth.
@MainActor
final class SettingsSourcePathWidthTests: XCTestCase {
    func testUnselectedLongSourcePathDoesNotExpandRetainedWindowAcrossTabs() throws {
        _ = NSApplication.shared
        for language in [InterfaceLanguage.english, .japanese, .simplifiedChinese] {
            let controller = ActivationSettingsWindowController(
                draft: ActivationPreferencesDraft(committed: ActivationPreferences()),
                strings: LocalizedStrings(language: language)
            )
            let window = try XCTUnwrap(controller.window)
            let tabs = try XCTUnwrap(window.contentView as? NSTabView)
            tabs.selectTabViewItem(withIdentifier: "appearance")
            tabs.layoutSubtreeIfNeeded()
            let baseline = tabs.bounds.width
            let frameWidth = window.frame.width
            let contentWidth = window.contentRect(forFrameRect: window.frame).width
            XCTAssertEqual(baseline, 500, accuracy: 1)
            func assertStableWindow(file: StaticString = #filePath, line: UInt = #line) {
                XCTAssertEqual(tabs.bounds.width, baseline, accuracy: 1, file: file, line: line)
                XCTAssertEqual(window.frame.width, frameWidth, accuracy: 1, file: file, line: line)
                XCTAssertEqual(window.contentRect(forFrameRect: window.frame).width,
                    contentWidth, accuracy: 1, file: file, line: line)
                XCTAssertFalse(window.isVisible, file: file, line: line)
            }
            XCTAssertFalse(window.isVisible)

            let sources = controller.appSourcesView
            let longPath = "/SyntheticApplications/" + String(repeating: "LongComponent/", count: 24) + "Extras"
            for path in ["/SyntheticApplications/Extras", longPath] {
                sources.reload(preferences: AppSourcesPreferences(
                    customRootPaths: [path], automaticRefreshEnabled: true),
                    fixedRoots: [], watchStatus: .disabled)
                tabs.selectTabViewItem(withIdentifier: "sources")
                tabs.layoutSubtreeIfNeeded()
                XCTAssertEqual(sources.rootsPopup.indexOfSelectedItem, 0)
                XCTAssertEqual(sources.rootsPopup.item(at: 1)?.representedObject as? String, path)
                assertStableWindow()
                let item = try XCTUnwrap(sources.rootsPopup.item(at: 1))
                XCTAssertEqual(item.title, path)
                XCTAssertEqual(item.accessibilityLabel(), path)
                sources.rootsPopup.selectItem(at: 1)
                sources.selectionChanged(nil)
                tabs.layoutSubtreeIfNeeded()
                XCTAssertEqual(sources.rootsPopup.titleOfSelectedItem, path)
                XCTAssertEqual(sources.draft.customRootPaths, [path])
                assertStableWindow()
                print("SETTINGS_WIDTH language=\(language) long=\(path == longPath) frame=\(window.frame.width) contentRect=\(window.contentRect(forFrameRect: window.frame).width) content=\(tabs.bounds.width) page=\(sources.bounds.width) popup=\(sources.rootsPopup.bounds.width) intrinsic=\(sources.rootsPopup.intrinsicContentSize.width)")
                // Reload preserves represented selection when still present;
                // reset just the popup selection for the next unselected case.
                sources.rootsPopup.selectItem(at: 0)
            }
            tabs.selectTabViewItem(withIdentifier: "appearance")
            tabs.layoutSubtreeIfNeeded()
            assertStableWindow()
        }
    }
}
