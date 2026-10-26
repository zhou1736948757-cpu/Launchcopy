# App Library native settings — implementation handoff

Status: SOURCE FROZEN for Main's serial verification. Worker implementation only;
no Swift invocation, build, test execution, GUI acceptance or Reviewer PASS claim.

## Scope and authority

Implemented the approved native Settings view contract independently in the shared
dirty tree. Read AGENTS.md, /Users/mac/.codex/RTK.md,
Docs/APP_LIBRARY_SPEC.md, Docs/APP_LIBRARY_SLICE_PROPOSAL.md and the native stage
summary. The approved specification incorporates the proposal's historical
PROPOSED markers. Human waived the formal workflow for this wave, authorized the
bounded agents and limited concurrency to three including Main.

No agent was dispatched. No reference-product code, evidence or assets were read.
No edits to Main-owned foundations, settings window, AppDelegate, launch controller
or Package.swift. No store, dialog, window, process, install, sign, commit, reset or
cleanup operation. All shell invocations used RTK.

## Exact changed files

- Sources/PagingPrototypeApp/AppLibrarySettingsView.swift (new)
- Tests/PagingUITests/AppLibrarySettingsViewTests.swift (new)
- Workflow/results/APP_LIBRARY_NATIVE_SETTINGS.md (new)

## Contract and presentation decisions

- Internal `@MainActor AppLibrarySettingsView(frame:strings:)`, with
  `onSetEnabled: ((Bool) -> Bool)?`, `onRecover: (() -> Void)?`,
  `applyState(preferences:loadResult:pendingCount:saveResult:isLoaded:)` and
  `relabel(strings:)`. No I/O and no independent coordinator.
- Checkbox starts off and disabled with the localized loading status. After a
  healthy loaded/missing snapshot it follows the supplied committed preferences.
- Toggle captures the native requested Boolean before invoking Main. A `true`
  return acknowledges acceptance only: the checkbox retains the committed value,
  controls are disabled and status shows pending until the owner applies a
  snapshot. A `false` return immediately restores committed display and shows
  failure. Missing callback reports unavailable without accepting an edit.
- Pending is established before invoking the callback, allowing a reentrant
  pending/terminal `applyState` without replacing a terminal receipt with local
  pending. Owner pending count blocks all actions, including stale direct sends.
- Terminal owner preferences always drive the checkbox, including an older actual
  successful baseline followed by a failed later write. A saved receipt is not
  displayed during loading or pending. The view does not derive state from a
  draft or the load result's potentially obsolete associated preferences.
- Future version uses `loadFuture`. Ambiguous, oversized and unavailable payloads
  use `unavailable`, without inventing a newer version. Protected enablement is a
  disabled native mixed checkbox with localized `unknown` accessibility help.
  Protected/unavailable save receipts are also disabled and shown unavailable.
- Corrupt or recovery-required state shows disabled off and an explicit recovery
  button. Only its permitted action calls Main, which owns confirmation and
  recovery. Clicking it does not imply confirmation or clear the protection.
  Pending recovery disables the button; a failed recovery retains protection and
  shows both save failure and recovery guidance. Successful recovery follows the
  owner's healthy snapshot.
- Native vertical constraints keep recovery below a wrapping, unlimited-line
  status. Text and controls are bounded to the pane width. There is no horizontal
  button row competing with the status or fixed-height message clipping.
- Stable UI/accessibility identifiers are `library.settings.enabled`,
  `library.settings.recover`, `library.settings.status`. Labels/status and unknown
  help are relocalized without replacing controls, callbacks or pending state.
  Existing LibraryTextKey resources are reused without localization edits.

## Verification evidence and remaining gates

Source inspection and static whitespace/contract checks only. The test file
defines 16 XCTest cases covering English, Simplified Chinese and Japanese,
default-off/loading, protected states, corrupt recovery, unavailable/missing
callbacks, accepted/rejected toggle requests, reentrant owner snapshots,
pending/success/failure reconciliation and small-pane control bounds.

Executed Swift tests: ZERO (intentionally prohibited for this worker).
Compilation and native layout assertions are unverified until Main runs them.
No source result is a claim of persistence durability, runtime UI availability,
VoiceOver acceptance, restart behavior or whole-product parity.

Main's next action: wire the view into the owned settings tab/coordinator, freeze
the complete source wave, then serially compile and run
`AppLibrarySettingsViewTests` with the existing isolated native test setup.
Verify all controls remain fully visible in the actual settings tab for each
language and confirm the owner receives the captured Boolean and explicit
recovery request. Reviewers/Main own the final verdict and stage summary update.

Static-check result: all three owned files have no trailing whitespace; all 16
test method names are unique; all three stable identifiers are present; the view
contains no store construction, NSWindow, NSAlert, NSWorkspace or Task creation.
An initial static-check assertion expected 17 tests; the actual count is 16 and
the handoff and assertion were corrected. This was not a Swift test run.
