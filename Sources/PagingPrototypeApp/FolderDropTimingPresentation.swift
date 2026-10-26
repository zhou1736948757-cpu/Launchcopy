import AppGridUI
import AppKit

/// Developer-only opt-in commands. No marker schema, production preference or disk output.
@MainActor
extension AppDelegate {
    func installFolderDropTimingMenu(in menu: NSMenu) {
        guard uiTestProfile != nil else { return }
        menu.addItem(.separator())
        let toggle = NSMenuItem(title: "Enable Folder Drop Timing",
            action: #selector(toggleFolderDropTiming(_:)), keyEquivalent: "")
        toggle.identifier = .init("diagnostics.folderDrop.toggle")
        toggle.state = folderDropLatencyProbe == nil ? .off : .on
        toggle.target = self
        menu.addItem(toggle)
        let report = NSMenuItem(title: "Folder Drop Timing Results…",
            action: #selector(showFolderDropTiming(_:)), keyEquivalent: "")
        report.identifier = .init("diagnostics.folderDrop.report")
        report.target = self
        menu.addItem(report)
    }

    @objc func toggleFolderDropTiming(_ sender: NSMenuItem?) {
        guard uiTestProfile != nil else { return }
        if folderDropLatencyProbe == nil {
            folderDropLatencyProbe = FolderDropLatencyProbe()
            configureFolderDropTimingObservers()
        } else {
            stopFolderDropTiming()
        }
        sender?.state = folderDropLatencyProbe == nil ? .off : .on
    }

    @objc func showFolderDropTiming(_ sender: Any?) {
        guard uiTestProfile != nil else { return }
        makeFolderDropTimingAlert().runModal()
    }

    /// Keep a full three-sample report readable without making a screen-height alert.
    func makeFolderDropTimingAlert() -> NSAlert {
        let alert = NSAlert()
        alert.messageText = "Folder Drop Timing"
        alert.informativeText = "In-memory timings only. Pre-draw is not displayed-pixel completion."
        let report = folderDropLatencyProbe?.summary ?? "Diagnostics are off."
        let scroll = NSScrollView(frame: NSRect(x: 0, y: 0, width: 520, height: 300))
        scroll.hasVerticalScroller = true
        scroll.drawsBackground = false
        let text = NSTextView(frame: NSRect(x: 0, y: 0, width: 500,
            height: max(300, CGFloat(report.split(separator: "\n").count) * 16 + 16)))
        text.isEditable = false
        text.isSelectable = true
        text.drawsBackground = false
        text.font = .monospacedSystemFont(ofSize: 11, weight: .regular)
        text.textColor = .labelColor
        text.textContainerInset = NSSize(width: 8, height: 8)
        text.textContainer?.widthTracksTextView = true
        text.autoresizingMask = [.width]
        text.string = report
        text.setAccessibilityLabel("Folder drop timing report")
        scroll.documentView = text
        alert.accessoryView = scroll
        alert.addButton(withTitle: "Close")
        return alert
    }

    func stopFolderDropTiming() {
        folderDropLatencyProbe = nil
        folderOverlay?.onDropDiagnosticEvent = nil
        (window as? QuitOnBlankClickWindow)?.onFolderMouseUpTiming = nil
    }

    func configureFolderDropTimingObservers() {
        guard uiTestProfile != nil, let probe = folderDropLatencyProbe else {
            folderOverlay?.onDropDiagnosticEvent = nil
            (window as? QuitOnBlankClickWindow)?.onFolderMouseUpTiming = nil
            return
        }
        let observedWindow = window as? QuitOnBlankClickWindow
        observedWindow?.onFolderMouseUpTiming = { [weak self, weak probe, weak observedWindow] eventTime, now in
            guard let self, let probe, self.folderDropLatencyProbe === probe,
                  let observedWindow, self.window === observedWindow,
                  self.folderOpenState?.isOpen == true else { return }
            probe.noteWindowRelease(eventTimestamp: eventTime, now: now)
        }
        let observedOverlay = folderOverlay
        observedOverlay?.onDropDiagnosticEvent = { [weak self, weak probe, weak observedOverlay] event in
            guard let self, let probe, self.folderDropLatencyProbe === probe,
                  let observedOverlay, self.folderOverlay === observedOverlay else { return }
            switch event {
            case .willRelease(let eventTime, let now):
                probe.beginRelease(eventTimestamp: eventTime, now: now)
            case .didRelease(let now, let readyIcons, let members):
                guard let id = probe.endRelease(now: now, readyIcons: readyIcons, visibleMembers: members) else { return }
                DispatchQueue.main.async { [weak self, weak probe] in
                    guard let self, let probe, self.folderDropLatencyProbe === probe else { return }
                    probe.noteNextTurn(for: id, now: ProcessInfo.processInfo.systemUptime)
                }
            case .willDraw(let now):
                probe.noteWillDraw(now: now)
            }
        }
    }

    func recordFolderDropStage(_ stage: FolderDropLatencyProbe.Stage) {
        guard let probe = folderDropLatencyProbe else { return }
        probe.mark(stage, now: ProcessInfo.processInfo.systemUptime)
    }
}
