# T-1H-A — Settings domain and apply-plan contracts

- **Date**: 2026-09-11
- **Worker**: Grok Build subagent
- **Status**: implemented (awaiting Reviewer verdict; Worker does not self-certify PASS)
- **Gate 0**: `Workflow/decisions/2026-09-11-phase1h-gate0-approved.md`

## Objective

Pure Foundation Settings draft / validation / transactional apply-plan contracts; schema v2 for `launchAtLoginEnabled` (D4 default off); no AppKit UI, no SMAppService, no AppDelegate / Package.swift edits.

## Files changed

### Created
| Path | Role |
|---|---|
| `Sources/PagingPrototypeApp/ActivationApplyPlan.swift` | Draft, validation errors, apply/rollback steps, failure mapping |
| `Tests/PagingUITests/ActivationApplyPlanTests.swift` | Validation, plan order, rollback, no-op, failure mapping |
| `Workflow/results/T-1H-A.md` | This evidence |

### Modified
| Path | Change |
|---|---|
| `Sources/PagingPrototypeApp/ActivationSettings.swift` | `launchAtLoginEnabled: Bool = false`; `currentSchemaVersion = 2`; decode/migration default |
| `Sources/PagingPrototypeApp/ActivationPreferences.swift` | `currentSchemaVersion = 2`; v1→v2 migrate on load; save normalizes settings schema; suite name kept `com.pagingprototype.activation` (documented) |
| `Tests/PagingUITests/ActivationSettingsTests.swift` | Default-off login item; v1 payload decode; whitelist + reset preserve login item |
| `Tests/PagingUITests/ActivationPreferencesTests.swift` | Defaults/round-trip/whitelist; `testSchemaV1LoadMigratesLaunchAtLoginDefaultOff`; `testSchemaV2PersistsLaunchAtLoginEnabled` |

### Explicitly not touched
- `AppDelegate.swift`, `Package.swift`, AppKit Settings UI, real `SMAppService`

## Design summary

1. **Draft** — `ActivationPreferencesDraft` mirrors committed prefs for Settings UI.
2. **Validation** — Hot Corner enable ⇒ `selectedCorner`; shortcut enable ⇒ `ShortcutSpec` with modifiers via `ShortcutSpecValidator.isRegisterable` (bare keys rejected).
3. **Apply plan** — deterministic order: statusItem → hotCorner → shortcut → fourFinger → launchAtLogin; only changed fields emitted as absolute targets.
4. **Rollback** — reverse of forward steps with previous target values; mid-failure rolls back successful prefix only; `restorePreviousAcceptedConfig = true`.
5. **Schema v2** — field on `ActivationSettings`; store schema 2; v1 load migrates in-memory (`launchAtLoginEnabled=false`, bump schema); future store schema still refused; suite name unchanged for now.

## Test evidence

### Filtered (required)

```text
swift test --filter 'ActivationApplyPlanTests|ActivationPreferencesTests|ActivationSettingsTests'
```

| Suite | Executed | Failures |
|---|---:|---:|
| ActivationApplyPlanTests | 14 | 0 |
| ActivationPreferencesTests | 17 | 0 |
| ActivationSettingsTests | 11 | 0 |
| **Total** | **42** | **0** |
| Exit | **0** | |

(`executed_tests == 42 > 0` — valid PASS evidence for this task scope.)

### Full suite (feasibility)

```text
swift test
```

- Executed: **1500**, Failures: **5**, Exit: **1**
- Failures are **out of T-1H-A write scope** (pre-existing Phase 1F debt):
  - `Bug10PreviewHostTests.testMoveOutBarAndPreviewShareOverlayCoordinateSystem`
  - `Bug11RowBoundaryIndicatorTests.testTopLevelTargetUsesAnnotatedPageAndCrossRowAnchor`
  - `DragCommitIntegrationTests.testTwoMemberFolderMoveOutShowsRemainingAppProxyThenDissolves`
  - `T1FD1FixUITests.testPreviewShowsSourceCellIconAndName`
- No failures in ActivationApplyPlan / ActivationPreferences / ActivationSettings suites.

## Constraints compliance

| Constraint | Result |
|---|---|
| No AppKit in apply-plan file | Yes (`import Foundation` only) |
| No real SMAppService | Yes (boolean target only) |
| No git commit | Yes |
| No AppDelegate / Package.swift | Yes |

## Memory candidates

- Activation preferences store schema is now **2**; suite remains `com.pagingprototype.activation` until a later packaging/identity task renames it.
- Settings apply order contract: statusItem → hotCorner → shortcut → fourFinger → launchAtLogin.
- `launchAtLoginEnabled` lives on `ActivationSettings` (not top-level prefs); default off; resetActivation preserves it.

## Next executable action

Independent Reviewer on T-1H-A (diff + filtered evidence). Downstream: T-1H-B Settings AppKit UI / T-1H-C SMAppService adapter can consume these contracts.
