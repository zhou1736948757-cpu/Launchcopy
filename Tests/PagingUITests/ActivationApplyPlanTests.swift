//
//  ActivationApplyPlanTests.swift
//  PagingUITests
//
//  Phase 1H T-1H-A：Settings 草稿校验、apply 顺序、rollback 顺序、相等 no-op、失败映射。
//  纯值逻辑，无 AppKit / SMAppService / 真实 defaults。
//

import XCTest
@testable import PagingPrototypeApp

final class ActivationApplyPlanTests: XCTestCase {

    private let cornerA = HotCorner.topLeft
    private let cornerB = HotCorner.bottomRight
    private let validShortcut = ShortcutSpec(keyCode: 3, modifiers: [.command, .shift])
    private let bareKeyShortcut = ShortcutSpec(keyCode: 3, modifiers: [])

    // MARK: - Validation

    func testHotCornerEnableRequiresSelectedCorner() {
        var draft = ActivationPreferencesDraft(committed: ActivationPreferences())
        draft.hotCornerEnabled = true
        draft.selectedCorner = nil

        XCTAssertEqual(
            ActivationDraftValidator.validate(draft),
            [.hotCornerMissingSelectedCorner]
        )
        guard case .invalid(let errors) = ActivationApplyPlanner.plan(
            from: ActivationPreferences(), to: draft
        ) else {
            return XCTFail("必须 invalid")
        }
        XCTAssertEqual(errors, [.hotCornerMissingSelectedCorner])
    }

    func testShortcutEnableRequiresSpec() {
        var draft = ActivationPreferencesDraft(committed: ActivationPreferences())
        draft.globalShortcutEnabled = true
        draft.shortcut = nil

        XCTAssertEqual(
            ActivationDraftValidator.validate(draft),
            [.shortcutMissingSpec]
        )
    }

    func testBareKeyShortcutRejected() {
        var draft = ActivationPreferencesDraft(committed: ActivationPreferences())
        draft.globalShortcutEnabled = true
        draft.shortcut = bareKeyShortcut

        XCTAssertFalse(ShortcutSpecValidator.isRegisterable(bareKeyShortcut))
        XCTAssertEqual(
            ActivationDraftValidator.validate(draft),
            [.shortcutMissingModifiers]
        )
        guard case .invalid(let errors) = ActivationApplyPlanner.plan(
            from: ActivationPreferences(), to: draft
        ) else {
            return XCTFail("裸键必须 invalid")
        }
        XCTAssertEqual(errors, [.shortcutMissingModifiers])
    }

    func testValidDraftPassesValidation() {
        var draft = ActivationPreferencesDraft(committed: ActivationPreferences())
        draft.hotCornerEnabled = true
        draft.selectedCorner = cornerA
        draft.globalShortcutEnabled = true
        draft.shortcut = validShortcut
        XCTAssertTrue(ActivationDraftValidator.validate(draft).isEmpty)
    }

    // MARK: - No-op

    func testNoOpWhenDraftEqualsCommitted() {
        let committed = ActivationPreferences()
        let draft = ActivationPreferencesDraft(committed: committed)
        guard case .planned(let plan) = ActivationApplyPlanner.plan(from: committed, to: draft) else {
            return XCTFail("合法草稿必须 planned")
        }
        XCTAssertTrue(plan.isNoOp)
        XCTAssertTrue(plan.steps.isEmpty)
        XCTAssertTrue(plan.rollbackSteps.isEmpty)
        XCTAssertEqual(plan.proposed.fourFingerActivationEnabled, committed.fourFingerActivationEnabled)
        XCTAssertEqual(plan.proposed.settings.showStatusItem, committed.settings.showStatusItem)
        XCTAssertFalse(plan.proposed.settings.launchAtLoginEnabled)
    }

    // MARK: - Plan order

    func testPlanOrderStatusHotCornerShortcutFourFingerLaunchAtLogin() {
        var committed = ActivationPreferences()
        committed.fourFingerActivationEnabled = true
        committed.settings.showStatusItem = true
        committed.settings.launchAtLoginEnabled = false

        var draft = ActivationPreferencesDraft(committed: committed)
        draft.showStatusItem = false
        draft.hotCornerEnabled = true
        draft.selectedCorner = cornerA
        draft.globalShortcutEnabled = true
        draft.shortcut = validShortcut
        draft.fourFingerActivationEnabled = false
        draft.launchAtLoginEnabled = true

        guard case .planned(let plan) = ActivationApplyPlanner.plan(from: committed, to: draft) else {
            return XCTFail("必须 planned")
        }

        XCTAssertEqual(plan.steps, [
            .statusItem(show: false),
            .hotCorner(cornerA),
            .shortcut(validShortcut),
            .fourFinger(enabled: false),
            .launchAtLogin(enabled: true),
        ])
        XCTAssertEqual(
            plan.steps.map(\.target),
            [.statusItem, .hotCorner, .shortcut, .fourFinger, .launchAtLogin]
        )
    }

    func testPartialChangeKeepsDocumentedRelativeOrder() {
        var committed = ActivationPreferences()
        committed.settings.showStatusItem = true
        committed.fourFingerActivationEnabled = true

        var draft = ActivationPreferencesDraft(committed: committed)
        draft.fourFingerActivationEnabled = false
        draft.launchAtLoginEnabled = true
        // status item unchanged

        guard case .planned(let plan) = ActivationApplyPlanner.plan(from: committed, to: draft) else {
            return XCTFail("必须 planned")
        }
        XCTAssertEqual(plan.steps, [
            .fourFinger(enabled: false),
            .launchAtLogin(enabled: true),
        ])
    }

    func testHotCornerChangeEmitsNewCornerTarget() {
        var committed = ActivationPreferences()
        committed.settings.hotCornerEnabled = true
        committed.settings.selectedCorner = cornerA

        var draft = ActivationPreferencesDraft(committed: committed)
        draft.selectedCorner = cornerB

        guard case .planned(let plan) = ActivationApplyPlanner.plan(from: committed, to: draft) else {
            return XCTFail("必须 planned")
        }
        XCTAssertEqual(plan.steps, [.hotCorner(cornerB)])
        XCTAssertEqual(plan.rollbackSteps, [.hotCorner(cornerA)])
    }

    func testDisablingHotCornerEmitsNilTarget() {
        var committed = ActivationPreferences()
        committed.settings.hotCornerEnabled = true
        committed.settings.selectedCorner = cornerA

        var draft = ActivationPreferencesDraft(committed: committed)
        draft.hotCornerEnabled = false

        guard case .planned(let plan) = ActivationApplyPlanner.plan(from: committed, to: draft) else {
            return XCTFail("必须 planned")
        }
        XCTAssertEqual(plan.steps, [.hotCorner(nil)])
        XCTAssertEqual(plan.rollbackSteps, [.hotCorner(cornerA)])
    }

    // MARK: - Rollback order

    func testRollbackIsReverseOfForwardStepsWithOldValues() {
        var committed = ActivationPreferences()
        committed.settings.showStatusItem = true
        committed.fourFingerActivationEnabled = true
        committed.settings.launchAtLoginEnabled = false

        var draft = ActivationPreferencesDraft(committed: committed)
        draft.showStatusItem = false
        draft.hotCornerEnabled = true
        draft.selectedCorner = cornerA
        draft.launchAtLoginEnabled = true

        guard case .planned(let plan) = ActivationApplyPlanner.plan(from: committed, to: draft) else {
            return XCTFail("必须 planned")
        }

        XCTAssertEqual(plan.steps, [
            .statusItem(show: false),
            .hotCorner(cornerA),
            .launchAtLogin(enabled: true),
        ])
        XCTAssertEqual(plan.rollbackSteps, [
            .launchAtLogin(enabled: false),
            .hotCorner(nil),
            .statusItem(show: true),
        ], "rollback = 正向步骤逆序 + 旧目标值")
    }

    // MARK: - Failure mapping

    func testFailureMappingRollsBackOnlySuccessfulPrefix() {
        var committed = ActivationPreferences()
        committed.settings.showStatusItem = true
        committed.fourFingerActivationEnabled = true

        var draft = ActivationPreferencesDraft(committed: committed)
        draft.showStatusItem = false
        draft.hotCornerEnabled = true
        draft.selectedCorner = cornerA
        draft.fourFingerActivationEnabled = false

        guard case .planned(let plan) = ActivationApplyPlanner.plan(from: committed, to: draft) else {
            return XCTFail("必须 planned")
        }
        // steps: statusItem(false), hotCorner(A), fourFinger(false)
        XCTAssertEqual(plan.steps.count, 3)

        let failure = ActivationApplyPlanner.failureMapping(plan: plan, failedAtIndex: 1)
        XCTAssertEqual(failure.failedStep, .hotCorner(cornerA))
        XCTAssertEqual(failure.failedIndex, 1)
        XCTAssertTrue(failure.restorePreviousAcceptedConfig)
        XCTAssertEqual(failure.rollbackSteps, [.statusItem(show: true)],
                       "仅回滚已成功的 statusItem 变更")
    }

    func testFailureAtFirstStepNeedsNoRollback() {
        let committed = ActivationPreferences()
        var draft = ActivationPreferencesDraft(committed: committed)
        draft.launchAtLoginEnabled = true

        guard case .planned(let plan) = ActivationApplyPlanner.plan(from: committed, to: draft) else {
            return XCTFail("必须 planned")
        }
        let failure = ActivationApplyPlanner.failureMapping(plan: plan, failedAtIndex: 0)
        XCTAssertEqual(failure.failedStep, .launchAtLogin(enabled: true))
        XCTAssertTrue(failure.rollbackSteps.isEmpty)
        XCTAssertTrue(failure.restorePreviousAcceptedConfig)
    }

    // MARK: - Proposed materialization

    func testProposedPreferencesCarryDraftValuesAndCurrentSchema() {
        var draft = ActivationPreferencesDraft(committed: ActivationPreferences())
        draft.fourFingerActivationEnabled = false
        draft.launchAtLoginEnabled = true
        draft.showStatusItem = false

        guard case .planned(let plan) = ActivationApplyPlanner.plan(
            from: ActivationPreferences(), to: draft
        ) else {
            return XCTFail("必须 planned")
        }
        XCTAssertEqual(plan.proposed.schemaVersion, ActivationPreferences.currentSchemaVersion)
        XCTAssertEqual(plan.proposed.settings.schemaVersion, ActivationSettings.currentSchemaVersion)
        XCTAssertFalse(plan.proposed.fourFingerActivationEnabled)
        XCTAssertTrue(plan.proposed.settings.launchAtLoginEnabled)
        XCTAssertFalse(plan.proposed.settings.showStatusItem)
    }

    func testDraftFromCommittedRoundTripFields() {
        var committed = ActivationPreferences()
        committed.settings.hotCornerEnabled = true
        committed.settings.selectedCorner = cornerB
        committed.settings.globalShortcutEnabled = true
        committed.settings.shortcut = validShortcut
        committed.settings.launchAtLoginEnabled = true
        committed.fourFingerActivationEnabled = false

        let draft = ActivationPreferencesDraft(committed: committed)
        XCTAssertEqual(draft.hotCornerEnabled, true)
        XCTAssertEqual(draft.selectedCorner, cornerB)
        XCTAssertEqual(draft.shortcut, validShortcut)
        XCTAssertTrue(draft.launchAtLoginEnabled)
        XCTAssertFalse(draft.fourFingerActivationEnabled)

        let rematerialized = draft.makePreferences()
        XCTAssertEqual(rematerialized.settings.selectedCorner, cornerB)
        XCTAssertEqual(rematerialized.settings.shortcut, validShortcut)
        XCTAssertTrue(rematerialized.settings.launchAtLoginEnabled)
    }
}
