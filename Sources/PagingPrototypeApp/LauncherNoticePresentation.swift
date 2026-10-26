import AppKit
import AppGridUI
import LauncherLocalization

/// Native alert builders only. Presentation/ownership and persistence stay in AppDelegate.
@MainActor
enum LauncherNoticePresentation {
    static func workspaceMessage(_ result: LayoutStoreFlushResult?, strings: LocalizedStrings) -> String {
        let key: NoticeTextKey
        switch result {
        case .readOnly?: key = .workspaceProtectedMessage
        case .staleRejected?: key = .workspaceStaleMessage
        case .rejectedOverLimit?: key = .workspaceLimitMessage
        case .timedOut?: key = .workspaceTimedOutMessage
        default: key = .workspaceUnsavedMessage
        }
        return strings.noticeText(key)
    }

    static func aliasEditor(strings: LocalizedStrings, alias: String) -> (NSAlert, NSTextField) {
        let alert = NSAlert()
        alert.messageText = strings.noticeText(.aliasEditorTitle)
        alert.informativeText = strings.noticeText(.aliasEditorHelp)
        alert.addButton(withTitle: strings.noticeText(.save))
        alert.addButton(withTitle: strings.text(.cancel))
        let field = NSTextField(frame: NSRect(x: 0, y: 0, width: 300, height: 28))
        field.stringValue = alias
        field.setAccessibilityLabel(strings.noticeText(.aliasEditorAccessibility))
        alert.accessoryView = field
        return (alert, field)
    }

    static func assignmentError(_ result: LayoutMutationResult, strings: LocalizedStrings) -> NSAlert? {
        switch result { case .success, .noOp: return nil; case .cancelled, .rejected: break }
        let alert = NSAlert()
        alert.messageText = strings.noticeText(.organizationErrorTitle)
        alert.informativeText = strings.noticeText(.organizationErrorHelp)
        alert.addButton(withTitle: strings.noticeText(.okay))
        return alert
    }

    static func managementError(_ result: AppManagementSaveResult, strings: LocalizedStrings) -> NSAlert? {
        let reason: NoticeTextKey
        switch result {
        case .saved: return nil
        case .invalidPreferences: reason = .aliasInvalidMessage
        case .futureVersion: reason = .managementFutureMessage
        case .failed: reason = .managementFailedMessage
        }
        let alert = NSAlert()
        alert.messageText = strings.noticeText(.managementErrorTitle)
        alert.informativeText = strings.noticeText(reason)
        alert.addButton(withTitle: strings.noticeText(.okay))
        return alert
    }
}

@MainActor
final class ApplicationSheetCompletionGate {
    private var didComplete = false
    func claim() -> Bool {
        guard !didComplete else { return false }
        didComplete = true
        return true
    }
}
