# Live Appearance and Integrated Main-Grid Controls

Date: 2026-10-17
Status: APPROVED_FOR_IMPLEMENTATION — human confirmed the recommended real-time effect and automatic-save contract on 2026-10-17.

## Problem and intended outcome
The human supplied the current Appearance settings screenshot and requested changes to be real-time and main-grid row/column controls to be included in this same section. The current explicit Apply/dismiss-to-discard behavior conflicts with that requested direct feedback. Provide one understandable native Appearance page with continuous feedback, no redundant Grid tab, preserved data safety and paging performance.

This is an incremental change to the established SwiftPM/AppKit application, not a new project or license/source migration. No reference project source/resources are needed. Existing independent implementations and ownership boundaries remain.

## Source discovery and approved baseline
- AppearanceSettingsView sliders currently have isContinuous=false, edit only a retained draft, and require Apply. Defaults changes only that draft. AppearanceSettingsCoordinator synchronously saves a dedicated UserDefaults payload before notifying presentation.
- AppDelegate separately queues appearance presentation until existing gesture/drag/editor/lifecycle ownership is safe.
- MainGridCapacitySettingsView is a separate seventh Grid tab with explicit Apply/Defaults, independent asynchronous receipt-bearing store/coordinator, stable-anchor relocation and Quit protection.
- The accepted ranges are blur0–60, icon32–64pt, font9–16pt; main grid3–8 columns and3–8 rows, default5columns×7rows. Small-window readability protection and independent adaptive folders were accepted.
- Current diagnostic candidate folder-scroll-diagnostic-rc-20261017-r2 has one human-confirmed physical folder-swipe success, not a proven fix for the original intermittent failure. Do not disturb or relabel that evidence.

## Proposed user-facing contract to confirm
1. Changes on Appearance take effect without an Apply button. Show-app-names and supported sliders react while being changed, not only after release. Numeric captions update immediately. Valid row/column selections automatically request the same safe main-grid transaction.
2. Place rows/columns and per-page count in the existing Appearance page under a clear Main Grid subsection. Remove the independent Grid tab, keeping Activation, Appearance, App Management, Sources, Language and Library: six tabs total. Keep all controls readable in a vertically scrolling native layout and accessible in small windows.
3. Automatically save valid edits. No Apply/Save gesture is required. Closing does not roll back changes. A short bounded write-coalescing window (initial target200ms of inactivity) may combine slider edits; it must not delay ordinary visual feedback. Flush the newest accepted edit on interaction end, settings dismissal and normal Quit. A timer is for write coalescing only, not a periodic polling loop.
4. During outer/folder paging, drag, rename, IME or modal/lifecycle ownership, do not interrupt the owner or rebuild a moving grid. Retain the latest requested values, indicate pending presentation, and apply at the first existing safe boundary. Main-grid row/column reflow continues to wait until folder/Library closes; folder dimensions and physics remain independent. Ordinary idle main-grid updates do not wait for settings to close.
5. A single scoped Restore Appearance Defaults requests the appearance defaults and5×7 main-grid default immediately through their respective owners, with automatic save and honest per-domain outcomes. It does not reset activation, language, sources, hidden apps, aliases, Library preferences or arrangement. Independent stores are not promised to form an atomic disk transaction.
6. Saving and visual presentation are separate facts. Show saving/queued/saved/failed states from the actual relevant owner/receipt. Failed saves must not claim Saved or silently discard the latest user intention. Keep a visible retry/recovery path; normal Quit uses the existing default-Cancel save protection for admitted unsaved work. A successfully acknowledged edit is not undone by an older completion.
7. Future/ambiguous/unavailable payload protections remain fail-closed. Programmatic load/relabel/reopen/resize must never auto-save defaults or repair corrupt data. Supported corrupt payload recovery still requires a clearly labeled explicit user recovery action; a live change must not silently replace protected or corrupt data.

## Architecture and data decisions
- Preserve the current separate appearance and capacity schemas/paths; no disk-schema migration, preference namespace merge or workspace reserialization solely to combine UI. Existing saved values must load unchanged and without writes.
- Compose existing domain controls and clear section ownership under one Appearance content view; avoid duplicating shape validation/store logic or creating a second pager. Existing retained controller references may remain internally if useful, but there is no independent Grid tab.
- Model current requested/previewed, durable last-success and pending presentation states distinctly. Use monotonic request/owner generations so stale work cannot change current controls, UI or save feedback. A shared lightweight scheduling adapter may coalesce edits; avoid an unbounded task/write queue.
- Separate continuous visual requests from debounced persistence. A synchronous UserDefaults return is an API-level save acknowledgment, not proof of fsync or crash-durability; capacity file success remains its real atomic-write receipt. Do not weaken these evidence meanings.
- Apply preview/reflow only through the appropriate current owner and readiness guards. Reuse the existing idle capacity transaction and stable current-page identity anchor; preserve query/catalog revision/canonical order and deferred keyboard focus. Never forge a catalog revision or weaken stale-menu/icon/drag validation.
- Settings dismissal must flush accepted work without synchronously waiting on asynchronous disk IO on the main thread. Quit drainage must include pending debounce/admitted writes and preserve existing Cancel/Exit Anyway protections. Teardown and owner replacement suppress stale presentation but do not abandon already-accepted writes.
- Programmatic control synchronization and language relabeling are silent. Reopening loads the latest requested/current valid snapshot and accurate receipt feedback, not stale defaults. Invalid/transient values never enter production state.

## Performance and nonfunctional requirements
- Continuous value feedback must be responsive; coalesce redundant presentation requests to the newest bounded main-turn update where necessary without waiting for the save debounce.
- Do not perform a full-resolution wallpaper blur synchronously for every slider event. Inspect the current backdrop worker/cache path, retain latest-wins cancellation/generation checks and bound active+queued work. Reuse stable input/cache where valid; do not weaken material/accessibility policy or promise a performance result without measuring it.
- Metric-only changes must not restart enumeration/scanning or rebind unchanged app icons unnecessarily. No configuration persistence or catalog work in paging frame callbacks. No unbounded retained previews/write tasks/callbacks.
- Preserve Reduce Motion, Reduce Transparency, Increase Contrast, keyboard control labels and English/Simplified Chinese/Japanese localization; update help text so it no longer instructs Apply or discard-on-close.
- Preserve titlebar dragging, window resizing and small-window protection. Do not force fullscreen, set topmost, switch Spaces, alter OS settings or touch formal test-unrelated data.

## Acceptance and testing
1. Continuous slider events update numeric feedback and idle main-grid appearance before release without Apply; checkbox and row/column changes work equivalently. A valid final value survives normal restart.
2. Exactly six localized settings tabs, no independent Grid tab; Appearance includes all existing appearance controls plus row/column/count and scoped Defaults. Long help/status text fits or scrolls in all three languages and supported test window sizes.
3. Load, relabel, reopen and geometry changes produce no unsolicited writes. Continuous200-event bursts keep queue/work bounded, latest value wins; equal values do not trigger redundant work. Verify final-event/dismiss/Quit flush and failure/retry with injected clocks/stores, not wall-time guesses.
4. Real writes and previews distinguish pending/failed/saved states; old receipts and owner replacements cannot publish stale success. Future/corrupt/unavailable payload handling preserves explicit recovery and original data. Partial Defaults failure is visible, not described as all-or-nothing success.
5. Gesture/drag/folder/Library/editor/IME/modal gates retain latest values and later apply once safely. Nonzero-page capacity shrink and same-product different-shape changes retain actual aligned page origins, order/query/selection. Main-grid row/column changes never alter folder capacity.
6. No regressions in folder physical-input/modal ownership, live menu origins, icon callback generations, Quit protection, search or title editing. Keep unresolved physical cases distinct from deterministic tests.
7. Execute nonzero focused/full XCTest, Debug/actual Release/package/localization gates on frozen current sources; bounded independent source review; record new candidate hash. Preserve raw RED/FAIL evidence and the broad existing dirty tree.
8. Native ordinary non-topmost isolated test: while dragging sliders observe background changes; adjust rows/columns without Apply; close/reopen settings and normal Quit/restart; small-window recovery; folder open and two-finger paging. Human physical experience is its own gate, not inferred from tests or AX.

## Non-goals and remaining risks
No new ranges, grid capacities, physics/timing/frame-driver changes, folder animation/material redesign, scanning/resources changes, usage history, uninstall, installation/signing/publication or reference code/assets. Existing wallpaper readiness/occasional failure, >25ms latency causality,120Hz/multidisplay/realIME/spokenVoiceOver remain distinct and not certified by this feature.

Preview/save separation changes the previous explicit-Apply lifecycle and requires integration tests, not merely isContinuous=true plus save-on-every-event. The200ms write target is engineering tuning, not a guaranteed physical-latency claim. If the backdrop path cannot sustain continuous rendering, report measured constraints and revise the approach rather than silently shipping release-only feedback.

## Delivery and maintenance
Document this stage in Workflow/stage-summaries and update project PLAN/MEMORY after material decisions. Main owns integration/native and serialized build execution; optional delegates have disjoint files and at most3 active agents including Main. Existing Chief ceremony is waived by the human. Preserve all dirty changes and prior evidence; no commit/reset/clean/delete/kill/OS/formal-data/reference-source/sign/install/publish actions. UI is CUA only and own old test instances exit normally when a verified replacement is ready.

## Confirmation required
Confirm automatic live effect plus automatic save, merged Appearance controls/removal of Grid tab, bounded write coalescing with dismissal/Quit flush, and retained safe-boundary deferral for concurrent gestures/drag/rename/folder/Library. No implementation changes have been made for this request yet.

## Human approval — 2026-10-17
Human selected “按这个实时生效并自动保存方案实现（推荐）”. This approves the contract above and supersedes pending-confirmation language in earlier snapshots. Existing domains retain separate error/receipt ownership.
