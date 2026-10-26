import AppKit
import LauncherLocalization

/// Registers native text editing through AppKit's current responder chain.
/// It never reads the clipboard, chooses an editor, or intercepts key events.
@MainActor
final class LauncherEditMenuController {
    let menuItem: NSMenuItem
    let menu: NSMenu
    private var localizedItems: [(NSMenuItem, MenuTextKey)] = []

    init(strings: LocalizedStrings?) {
        menuItem = NSMenuItem()
        menu = NSMenu()
        menu.autoenablesItems = true
        menuItem.submenu = menu
        add(.undo, selector: "undo:", key: "z")
        add(.redo, selector: "redo:", key: "z", modifiers: [.command, .shift])
        menu.addItem(.separator())
        add(.cut, selector: "cut:", key: "x")
        add(.copy, selector: "copy:", key: "c")
        add(.paste, selector: "paste:", key: "v")
        menu.addItem(.separator())
        add(.selectAll, selector: "selectAll:", key: "a")
        relabel(strings: strings)
    }

    func relabel(strings: LocalizedStrings?) {
        let title = strings?.menuText(.edit) ?? MenuTextKey.edit.englishFallback
        menuItem.title = title
        menu.title = title
        for (item, key) in localizedItems {
            item.title = strings?.menuText(key) ?? key.englishFallback
        }
    }

    private func add(_ key: MenuTextKey, selector: String, key equivalent: String,
                     modifiers: NSEvent.ModifierFlags = .command) {
        let item = NSMenuItem(title: key.englishFallback,
                              action: NSSelectorFromString(selector), keyEquivalent: equivalent)
        item.target = nil
        item.keyEquivalentModifierMask = modifiers
        menu.addItem(item)
        localizedItems.append((item, key))
    }
}
