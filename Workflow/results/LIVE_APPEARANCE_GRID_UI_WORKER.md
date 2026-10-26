# Live Appearance / Integrated Grid UI Worker

Date: 2026-10-17
Checkpoint: IMPLEMENTED_SOURCE_ONLY — stable for Main's serialized compile/review wave. No worker execution or PASS claim.

## Authority and scope

Implemented the approved `Docs/LIVE_APPEARANCE_AND_GRID_SPEC.md` within the assigned UI slice. Read project `AGENTS.md`, `/Users/mac/.codex/RTK.md`, `write-swift` and `apple-design`. All shell-based source inspection used the `rtk` prefix. No builds, tests, app/UI interactions, process operations, Git actions, reference source/assets, OS changes or formal-data actions were performed. Existing tests and Main/localization-owned files were not modified.

## Exact changed paths

- `Sources/PagingPrototypeApp/AppearanceSettingsView.swift`
- `Sources/PagingPrototypeApp/MainGridCapacitySettingsView.swift`
- `Sources/PagingPrototypeApp/ActivationSettingsWindowController.swift`
- `Tests/PagingUITests/LiveAppearanceSettingsViewTests.swift` (new, authored only)
- `Workflow/results/LIVE_APPEARANCE_GRID_UI_WORKER.md` (this report)

## Integration APIs

`AppearanceSettingsView.swift` adds the public top-level `LiveSettingsSaveState: Equatable` enum with exactly `idle`, `pending`, `saved`, `failed`, `protected`, `recoveryRequired`, `unavailable`.

Public Appearance callbacks and status method:

```swift
var onChange: ((AppearancePreferences) -> Bool)?
var onFlush: (() -> Void)?
var onRestoreGridDefaults: (() -> Void)?
func updateLiveStatus(_ state: LiveSettingsSaveState,
                      presentation: AppearancePresentationState)
```

`onApply: ((AppearancePreferences) -> AppearancePreferencesSaveResult)?`, `applyClicked(_:)`, `applyButton`, `presentationStateProvider`, `refreshPresentationStatus()`, `reload(preferences:loadResult:)`, `relabel(strings:)` and the internal `onDiscardDraft` seam remain. Appearance `applyClicked` is limited to failure/recovery states. Failed retry can fall back to `onChange` plus `onFlush` if `onApply` is absent; corrupt recovery requires the explicit `onApply` path.

`MainGridCapacitySettingsView` retains `onApply: ((MainGridCapacity) -> Bool)?`, `updateStatus(pendingCount:saveResult:presentation:)`, load/relabel/actions and `onDiscardDraft`. New internal APIs:

```swift
private(set) var isExplicitRecoveryRequest = false
private(set) var isEmbedded = false
init(frame: NSRect, strings: LocalizedStrings, embedded: Bool = false)
func setEmbedded(_ embedded: Bool)
```

`isExplicitRecoveryRequest` is a read-only internal Boolean. Only an explicit `applyClicked` action while `requiresExplicitRecovery` is set passes authorization into the synchronous `onApply` callback. The Boolean is set immediately around that callback and reset with `defer`. Normal control changes, Defaults and healthy failure retries see `false`. The owner must combine it with its own corrupt/recovery-required state when deciding `recoveringCorruptPayload`; the view never infers storage authority from a Boolean admission.

Appearance composition adds internal `attachMainGridSection(_:)` and a read-only `mainGridSection` reference. The controller keeps the original `mainGridCapacityView` instance, embeds it into Appearance, wires `onRestoreGridDefaults` to that same instance's `defaultsClicked(nil)`, and removes the independent Grid tab. The six tab identifiers remain `activation`, `appearance`, `management`, `sources`, `language`, `library`.

## Behavior implemented

- Three native `NSSlider` subclasses use continuous actions. Controls validate and update numeric captions before calling `onChange`. Equal already-admitted values do not resubmit. The slider's `mouseDown(with:)` defers a local completion hook until `super.mouseDown` returns; the hook invokes `onFlush`. No event monitor was added.
- Owner status is installed before invoking callbacks, and revision checks retain authoritative synchronous status on rejected admission, including protected/recovery-required outcomes. Admission alone stays Saving. Presentation refresh never promotes persistence to Saved; legacy presentation-unavailable copy that asserts a save is restricted to acknowledged Saved state.
- Healthy Apply buttons are hidden; failures expose Retry Saving and supported corruption exposes Recover Settings. Initial corrupt Appearance/Grid controls and Defaults can update the reviewed candidate but cannot autosave or clear the recovery warning. An unrequested success cannot clear initial corruption. Protected/unavailable domains reject direct actions. Protected Appearance state remains latched until owner reload.
- Grid recovery disables its draft controls while the explicit recovery write awaits a receipt, retaining the reviewed candidate. Failed recovery re-enables the explicit retry path. This prevents editing a different unsubmitted corrupt candidate while an older recovery receipt is in flight.
- Combined Defaults independently submits healthy Appearance defaults, invokes Grid Defaults even when Appearance is protected/unavailable, and flushes Appearance accepted work. The combined button remains enabled if the Grid callback/section is attached. There is one visible Defaults button across the integrated page. There is no aggregate-success claim or cross-store atomicity claim.
- Appearance has one full-page vertical scroll view containing controls, status, the Grid subsection and Defaults. Embedded Grid has its natural content height, no nested scroll view, no fixed-height footer and no second Defaults button. Its retry row collapses while unused. Standalone Grid can still use its own scroll container.
- Relabeling mutates retained titles/help/status/accessibility in place using `liveAppearanceText` and the existing `mainGridCapacityText(.title)`. No relabel/load/embedding path submits or flushes. Legacy Apply instructions on live Grid failure/corruption feedback are replaced with the new typed live copy.
- Existing dismissal hooks remain invoked from both hide and close. Main binds them to accepted-work flushing; no UI rollback was added.

## Authored coverage; not executed

`LiveAppearanceSettingsViewTests.swift` covers native continuous/action wiring and caption order, completion-hook flush wiring, automatic checkbox/sliders/grid/default actions, equal-value deduplication, silent reload/relabel/embedding, receipt versus admission/presentation, synchronous authoritative rejection status, failure retry, explicit corruption recovery and scoped authorization/reset, protection/unavailable refusal, partial Defaults outcomes, invalid Grid menus, embedded control/menu identity, six integrated tabs, one scroll/Defaults button, unrelated draft preservation, and retained dismissal hooks.

Tests use in-memory callbacks and unshown controller fixtures, with no production stores/catalog. The tracking-completion test invokes the configured local seam; it does not simulate or certify native tracking. Existing tests that assert seven tabs, manual Apply, draft-only Defaults or discard-on-close remain Main's adaptation responsibility.

## Remaining gates and risks owned by Main

- Compile and execute the new and adapted tests serially against frozen sources. This worker performed source inspection only; Swift/AppKit API/type correctness and constraint behavior are not execution-verified.
- Verify small-window/three-language wrapping and scrolling, actual native mouse tracking, keyboard/accessibility controls and settings dismissal. The existing settings-window style/geometry was preserved. No visual or physical acceptance is claimed.
- Preserve monotonic owner generations and current-request receipt filtering. UI status APIs intentionally accept owner-rendered status without a generation parameter; the views cannot independently identify an old healthy receipt.
- Main owns debounce bounds, actual previews, real persistence receipts, recovery storage authority, safe-boundary reflow, dismissal/Quit drainage and old contract-test migration. UI-only changes cannot certify any of those integration/runtime properties.
- Localization is supplied by the separate localization worker through `LiveAppearanceTextKey` / `LocalizedStrings.liveAppearanceText(_:)`; that implementation was read for interface alignment and not edited.

No remaining UI-scope blocker is known from source inspection. This checkpoint is an implementation handoff, not a Reviewer verdict.
