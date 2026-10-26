import AppKit
import LauncherLocalization
import XCTest
@testable import PagingPrototypeApp

/// Unshown native menus only; no clipboard access, application launch or key injection.
@MainActor
final class LauncherEditMenuTests: XCTestCase {
    func testInstalledMenuIncludesStandardResponderChainEditingCommands() throws {
        _ = NSApplication.shared
        let prior = NSApp.mainMenu
        defer { NSApp.mainMenu = prior }
        let host = AppDelegate(options: .default)
        host.installLauncherMenu()
        let menu = try XCTUnwrap(NSApp.mainMenu)
        let expected = [("undo:", "z", NSEvent.ModifierFlags.command),
                        ("redo:", "z", [.command, .shift]),
                        ("cut:", "x", .command), ("copy:", "c", .command),
                        ("paste:", "v", .command), ("selectAll:", "a", .command)]
        let edit = try XCTUnwrap(menu.items.compactMap(\.submenu).first {
            $0.items.contains { $0.action == NSSelectorFromString("paste:") }
        }, "Native text editors need the application Edit menu for standard shortcuts")
        for (selector, key, modifiers) in expected {
            let item = try XCTUnwrap(edit.items.first { $0.action == NSSelectorFromString(selector) })
            XCTAssertNil(item.target, "Editing must route to the current native responder, not the grid")
            XCTAssertEqual(item.keyEquivalent, key)
            XCTAssertEqual(item.keyEquivalentModifierMask, modifiers)
        }
        XCTAssertTrue(edit.autoenablesItems)
        XCTAssertEqual(menu.items.count, 3)
        XCTAssertEqual(menu.items[0].submenu?.items.first?.action, #selector(NSApplication.terminate(_:)))
        XCTAssertEqual(menu.items[2].submenu?.items.first?.keyEquivalentModifierMask, [.command, .control])
    }

    func testEditingTitlesUseSelectedLanguageAndStableNativeCommands() {
        let controller = LauncherEditMenuController(strings: nil)
        XCTAssertEqual(controller.menu.title, "Edit")
        let commands = controller.menu.items.filter { !$0.isSeparatorItem }
        XCTAssertEqual(commands.map(\.title), ["Undo", "Redo", "Cut", "Copy", "Paste", "Select All"])
        let expected: [(InterfaceLanguage, String, [String])] = [
            (.english, "Edit", ["Undo", "Redo", "Cut", "Copy", "Paste", "Select All"]),
            (.simplifiedChinese, "编辑", ["撤销", "重做", "剪切", "复制", "粘贴", "全选"]),
            (.japanese, "編集", ["取り消す", "やり直す", "カット", "コピー", "ペースト", "すべてを選択"])
        ]
        for (language, title, labels) in expected {
            controller.relabel(strings: LocalizedStrings(language: language))
            XCTAssertEqual(controller.menu.title, title)
            XCTAssertEqual(controller.menuItem.title, title)
            XCTAssertEqual(commands.map(\.title), labels)
            XCTAssertTrue(zip(commands, controller.menu.items.filter { !$0.isSeparatorItem }).allSatisfy { $0 === $1 })
            XCTAssertTrue(commands.allSatisfy { $0.target == nil })
        }
    }

    func testInstalledEditMenuFollowsDeferredLanguagePresentation() async throws {
        _ = NSApplication.shared
        let prior = NSApp.mainMenu
        let host = AppDelegate(options: .default)
        let surface = makeSurface(pageCount: 1, itemsPerPage: 35)
        host.surface = surface
        let store = EditingLanguageStore()
        defer {
            host.teardownLanguagePresentation()
            surface.teardown()
            host.surface = nil
            NSApp.mainMenu = prior
        }
        host.installLanguagePreferences(store: store, preferredLanguages: { ["en"] }, center: NotificationCenter())
        host.installLauncherMenu()
        let edit = try XCTUnwrap(NSApp.mainMenu?.items[1].submenu)
        let paste = try XCTUnwrap(edit.items.first { $0.action == NSSelectorFromString("paste:") })
        let owner = try XCTUnwrap(host.languagePresentationController)
        let lease = owner.acquire(.markedText)
        owner.request(.japanese)
        for _ in 0..<3 { await nextMainTurn() }
        XCTAssertEqual(edit.title, "Edit")
        XCTAssertEqual(paste.title, "Paste")
        owner.release(lease)
        for _ in 0..<5 { await nextMainTurn() }
        XCTAssertEqual(host.languageStrings?.language, .japanese)
        XCTAssertEqual(edit.title, "編集")
        XCTAssertEqual(paste.title, "ペースト")
        XCTAssertTrue(NSApp.mainMenu?.items[1].submenu === edit)
        XCTAssertNil(paste.target)
    }

    func testCommandVUsesNativeMenuKeyMatchingWithoutReadingClipboard() throws {
        _ = NSApplication.shared
        let controller = LauncherEditMenuController(strings: nil)
        let paste = try XCTUnwrap(controller.menu.items.first { $0.action == NSSelectorFromString("paste:") })
        XCTAssertNil(paste.target, "Production routing belongs to the native responder chain")
        // Scope this key-matching check to an explicit local spy. Never send
        // paste to an arbitrary key editor left by another test in the suite.
        // Native candidate validation separately exercises real field routing.
        let receiver = EditingActionReceiver()
        paste.target = receiver
        defer { paste.target = nil }
        let key = try XCTUnwrap(NSEvent.keyEvent(with: .keyDown, location: .zero,
            modifierFlags: .command, timestamp: 0, windowNumber: 0, context: nil,
            characters: "v", charactersIgnoringModifiers: "v", isARepeat: false, keyCode: 9))
        XCTAssertTrue(controller.menu.performKeyEquivalent(with: key))
        XCTAssertEqual(receiver.pasteCount, 1)
    }

    private func nextMainTurn() async {
        await withCheckedContinuation { continuation in
            DispatchQueue.main.async { continuation.resume() }
        }
    }

}


@MainActor
private final class EditingLanguageStore: LanguagePreferencesPersisting {
    func load() -> LanguagePreferencesLoadResult { .loaded(.init(language: .english)) }
    func save(_ preferences: LanguagePreferences) -> LanguagePreferencesSaveResult { .saved }
}


@MainActor
private final class EditingActionReceiver: NSResponder {
    var pasteCount = 0
    @objc func paste(_ sender: Any?) { pasteCount += 1 }
}
