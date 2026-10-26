import AppGridUI
import AppKit

/// Optional neutral aggregate counters, never a change to native event delivery.
@MainActor
extension AppDelegate {
    func installPointerInputDiagnosticMenu(in menu: NSMenu) {
        guard uiTestProfile != nil else { return }
        let actions: [(String, String, Selector)] = [
            ("开始／重置拖拽诊断", "diagnostics.pointer.start", #selector(startPointerInputDiagnostics(_:))),
            ("拖拽诊断结果…", "diagnostics.pointer.report", #selector(showPointerInputDiagnostics(_:))),
            ("停止拖拽诊断", "diagnostics.pointer.stop", #selector(stopPointerInputDiagnostics(_:)))
        ]
        for (title, id, action) in actions {
            let item = menu.addItem(withTitle: title, action: action, keyEquivalent: "")
            item.identifier = .init(id)
            item.target = self
        }
    }

    @objc func startPointerInputDiagnostics(_ sender: Any?) {
        guard uiTestProfile != nil else { return }
        PointerInputDiagnostics.setEnabled(true)
        PointerInputDiagnostics.reset()
    }

    @objc func stopPointerInputDiagnostics(_ sender: Any?) {
        guard uiTestProfile != nil else { return }
        PointerInputDiagnostics.setEnabled(false)
    }

    @objc func showPointerInputDiagnostics(_ sender: Any?) {
        guard uiTestProfile != nil else { return }
        let alert = NSAlert()
        alert.messageText = "拖拽输入诊断"
        alert.informativeText = "仅内存计数；不含应用名称、坐标或原始触摸。不同层的次数不一定一一对应。"
        let currentState = [
            "sampled_at_report_not_at_failure",
            "search_active=\(search?.isSearchActive == true)",
            "layout_can_commit=\(canCommitWorkspaceLayout)",
            "title_editor_mounted=\(folderTitleEditor != nil)",
            "folder_open=\(folderOpenState?.isOpen == true)",
            "folder_transition=\(folderOverlay?.isPanelTransitionActive == true)",
            "window_key=\(window?.isKeyWindow == true)",
            "app_active=\(NSApp.isActive)"
        ].joined(separator: "\n")
        let report = currentState + "\n\n" + PointerInputDiagnostics.report()
        let scroll = NSScrollView(frame: NSRect(x: 0, y: 0, width: 500, height: 320))
        scroll.hasVerticalScroller = true
        scroll.drawsBackground = false
        let text = NSTextView(frame: NSRect(x: 0, y: 0, width: 480,
            height: max(320, CGFloat(report.split(separator: "\n").count) * 16 + 16)))
        text.isEditable = false
        text.isSelectable = true
        text.drawsBackground = false
        text.font = .monospacedSystemFont(ofSize: 11, weight: .regular)
        text.textColor = .labelColor
        text.textContainerInset = NSSize(width: 8, height: 8)
        text.textContainer?.widthTracksTextView = true
        text.autoresizingMask = [.width]
        text.string = report
        text.setAccessibilityLabel("Pointer input diagnostic report")
        scroll.documentView = text
        alert.accessoryView = scroll
        alert.addButton(withTitle: "关闭")
        alert.runModal()
    }
}
