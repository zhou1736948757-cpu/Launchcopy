import AppKit
import XCTest
@testable import PagingPrototypeApp

/// Direct production delegate contracts using synthetic drafts and unmounted controls.
/// These notifications do not establish the cause of any native AX/Escape behavior.
@MainActor
final class FolderTitleEditorCompletionTests: XCTestCase {
    private enum Completion: Equatable {
        case commit(String)
        case cancel
    }

    @MainActor
    private final class Fixture {
        let editor = FolderTitleEditor()
        // An inert command argument, never acquired as an AppKit field editor.
        let textView = NSTextView()
        var completions: [Completion] = []

        init() {
            editor.stringValue = "Fixture seed"
            editor.fallbackTitle = "Fixture fallback"
            recordCallbacks()
        }

        func recordCallbacks() {
            editor.onCommit = { [weak self] in self?.completions.append(.commit($0)) }
            editor.onCancel = { [weak self] in self?.completions.append(.cancel) }
        }

        func command(_ selector: Selector) -> Bool {
            editor.control(editor, textView: textView, doCommandBy: selector)
        }

        func endEditing(userInfo: [AnyHashable: Any]? = nil) {
            editor.controlTextDidEndEditing(Notification(
                name: NSControl.textDidEndEditingNotification,
                object: editor,
                userInfo: userInfo
            ))
        }

        func endEditing(movement: Int) {
            // SDK NSText.h exposes these integer movement constants; AppKit.apinotes
            // maps the notification key to NSText.movementUserInfoKey.
            endEditing(userInfo: [NSText.movementUserInfoKey: NSNumber(value: movement)])
        }
    }

    func testCancelMovementBeforeCancelCommandCancelsWithoutCommitting() {
        let fixture = Fixture()
        fixture.editor.stringValue = "  Fixture abandoned draft  "

        fixture.endEditing(movement: NSCancelTextMovement)

        XCTAssertEqual(fixture.completions, [.cancel],
                       "The legitimate cancel notification must finish before any command arrives")
        XCTAssertTrue(fixture.command(#selector(NSResponder.cancelOperation(_:))))
        XCTAssertEqual(fixture.completions, [.cancel])
    }

    func testReturnCommandAndOrdinaryMovementsCommitNormalizedActualDraftOnce() {
        // nil selects the actual Return delegate command; other cases use the
        // control's end-editing delegate with legitimate non-cancel movements.
        let movements: [Int?] = [nil, NSReturnTextMovement, NSOtherTextMovement,
                                 NSTabTextMovement, NSBacktabTextMovement]
        let drafts: [(raw: String, expected: String)] = [
            (" \n Fixture revised draft \t", "Fixture revised draft"),
            (" \t\n ", "Fixture fallback"),
            ("  " + String(repeating: "👨‍👩‍👧‍👦", count: 70) + "  ",
             String(repeating: "👨‍👩‍👧‍👦", count: 64))
        ]

        for movement in movements {
            for draft in drafts {
                let fixture = Fixture()
                fixture.editor.stringValue = draft.raw

                if let movement {
                    fixture.endEditing(movement: movement)
                } else {
                    XCTAssertTrue(fixture.command(#selector(NSResponder.insertNewline(_:))))
                }

                XCTAssertEqual(fixture.completions, [.commit(draft.expected)])
                fixture.editor.stringValue = "Fixture late draft"
                fixture.endEditing()
                fixture.editor.commit()
                XCTAssertTrue(fixture.command(#selector(NSResponder.cancelOperation(_:))))
                XCTAssertEqual(fixture.completions, [.commit(draft.expected)])
            }
        }
    }

    func testFocusLossWithoutUsableMovementMetadataStillCommitsActualDraft() {
        // Only metadata varies. Every notification is the real control's end-editing
        // notification with that editor as its object; source validation is out of scope.
        let metadata: [[AnyHashable: Any]?] = [
            nil,
            [:],
            [NSText.movementUserInfoKey: "Fixture invalid movement"],
            [NSText.movementUserInfoKey: NSNull()],
            [NSText.movementUserInfoKey: NSNumber(value: Double(NSCancelTextMovement) + 0.5)],
            [NSText.movementUserInfoKey: ["Fixture": "invalid movement"]],
            ["FixtureUnrelatedKey": NSNumber(value: NSCancelTextMovement)]
        ]

        for userInfo in metadata {
            let fixture = Fixture()
            fixture.editor.stringValue = " \t Fixture focus-loss draft \n "

            fixture.endEditing(userInfo: userInfo)

            XCTAssertEqual(fixture.completions, [.commit("Fixture focus-loss draft")])
            fixture.endEditing()
            XCTAssertEqual(fixture.completions, [.commit("Fixture focus-loss draft")])
        }
    }

    func testCancelCommandBlocksLateEndEditingAndCompletionAttempts() {
        let fixture = Fixture()
        fixture.editor.stringValue = "Fixture canceled by command"

        XCTAssertTrue(fixture.command(#selector(NSResponder.cancelOperation(_:))))
        XCTAssertEqual(fixture.completions, [.cancel])

        fixture.editor.stringValue = "Fixture late draft"
        fixture.endEditing()
        fixture.endEditing(movement: NSReturnTextMovement)
        fixture.endEditing(movement: NSCancelTextMovement)
        fixture.editor.commit()
        fixture.editor.cancel()
        XCTAssertTrue(fixture.command(#selector(NSResponder.insertNewline(_:))))
        XCTAssertEqual(fixture.completions, [.cancel])
    }

    func testCancelEndEditingBlocksLateCommitAndCommands() {
        let fixture = Fixture()
        fixture.editor.stringValue = "Fixture canceled by notification"

        fixture.endEditing(movement: NSCancelTextMovement)
        XCTAssertEqual(fixture.completions, [.cancel])

        fixture.editor.stringValue = "Fixture late draft"
        fixture.editor.commit()
        XCTAssertTrue(fixture.command(#selector(NSResponder.insertNewline(_:))))
        XCTAssertTrue(fixture.command(#selector(NSResponder.cancelOperation(_:))))
        fixture.endEditing(movement: NSCancelTextMovement)
        fixture.endEditing()
        XCTAssertEqual(fixture.completions, [.cancel])
    }

    func testDismissWithoutCallbackBlocksLateDelegateAndDirectCompletions() {
        let fixture = Fixture()
        fixture.editor.stringValue = "Fixture dismissed draft"

        fixture.editor.dismissWithoutCallback()

        XCTAssertNil(fixture.editor.onCommit)
        XCTAssertNil(fixture.editor.onCancel)
        XCTAssertTrue(fixture.completions.isEmpty)
        // Reattach recorders to verify the terminal guard, independently of clearing
        // the original callbacks. This does not start a new editing session.
        fixture.recordCallbacks()
        fixture.endEditing()
        fixture.endEditing(movement: NSCancelTextMovement)
        fixture.endEditing(movement: NSReturnTextMovement)
        XCTAssertTrue(fixture.command(#selector(NSResponder.cancelOperation(_:))))
        XCTAssertTrue(fixture.command(#selector(NSResponder.insertNewline(_:))))
        fixture.editor.commit()
        fixture.editor.cancel()
        fixture.editor.dismissWithoutCallback()
        XCTAssertTrue(fixture.completions.isEmpty)
    }

    func testOnCancelReentrancyCannotCommitOrCompleteAgain() {
        for cancelViaNotification in [false, true] {
            let fixture = Fixture()
            fixture.editor.stringValue = "Fixture reentrant draft"
            fixture.editor.onCancel = { [weak fixture] in
                guard let fixture else { return }
                fixture.completions.append(.cancel)
                // Bound recursion even if a future regression moves the terminal
                // guard after the callback; extra completions must fail assertions.
                guard fixture.completions.count == 1 else { return }
                fixture.editor.commit()
                fixture.editor.cancel()
                fixture.endEditing()
                fixture.endEditing(movement: NSCancelTextMovement)
                XCTAssertTrue(fixture.command(#selector(NSResponder.insertNewline(_:))))
                XCTAssertTrue(fixture.command(#selector(NSResponder.cancelOperation(_:))))
            }

            if cancelViaNotification {
                fixture.endEditing(movement: NSCancelTextMovement)
            } else {
                XCTAssertTrue(fixture.command(#selector(NSResponder.cancelOperation(_:))))
            }

            XCTAssertEqual(fixture.completions, [.cancel])
        }
    }
}
