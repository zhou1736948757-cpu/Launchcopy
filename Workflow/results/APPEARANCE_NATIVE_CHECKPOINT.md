# Appearance close/discard and native acceptance checkpoint — 2026-10-15

## Status
Full independent LaunchBetter-experience parity remains ACTIVE/incomplete. This slice repaired a reproduced violation of the approved appearance close/discard contract. Native Apply, defaults-as-draft, representative scalar extremes and real-process persistence were checked. **The whole appearance slice is not accepted:** hiding visual labels also removes application/folder names from the actual accessibility tree; that newly observed defect remains open.

## Baseline and root cause
The previous unsigned library-status-visibility candidate (executable42bc2e9d...) opened with true/18/48/11. Setting an unapplied false/0/64/16 draft and closing left the grid unchanged, but reopening the retained settings controller incorrectly retained that draft. Language-era preservesInterfaceDraftsOnReopen intentionally avoids reconfiguring retained controllers; hideSettings discarded only the language draft. The appearance contract still requires dismissal to discard unapplied appearance edits. Visible reentry/language relabel must continue preserving unrelated drafts.

## Bounded implementation
Only three production files and one new integration-test file changed against the451-input previous slice:
- Sources/PagingPrototypeApp/AppearanceSettingsView.swift: internal draft-discard callback.
- Sources/PagingPrototypeApp/ActivationSettingsWindowController.swift: existing hide/close path invokes the callback after orderOut.
- Sources/PagingPrototypeApp/AppDelegate.swift: existing appearance composition supplies the current coordinator's accepted snapshot/load protection, guarded by weak lifetimes, exact view/coordinator identity and final teardown.
- Tests/PagingUITests/AppearanceDraftCloseIntegrationTests.swift: six actual-composition regressions.

Discard only reloads appearance controls. It does not read/write storage, apply runtime configuration, clear an accepted pending update, reset another section, change the retain/reentry flag, or hardcode defaults. Accepted-but-queued preferences take precedence over older displayed values. Failed saves return to the prior accepted snapshot. The public API and all18 PagingCore/PagingUI files, resources, physics, timers and fixed5x7 capacity are unchanged. Exact bounded reversal recovers all three prior source hashes.

## Execution and independent review
- Before patch:4 XCTest /6 assertion failures, retained in close-red.log.
- Final focused:63/0,4.140s, including6 new tests and existing appearance/language/settings tests.
- Final full:2657/0,71.573s. Debug and Release/package succeeded; diff check passed.
- Packaged-only localization:288 keys,3 languages; positive exit0 and two deliberate negative probes exit1.
- Final452 inputs match after native acceptance; no missing/removed baseline input.
- Independent reviewer Sagan: BOUNDED SOURCE PASS, no actionable finding in the bounded delta. Reviewer independently verified all452 hashes and exact three-source reversal;0 tests/builds/UI. Report: Workflow/results/APPEARANCE_CLOSE_SOURCE_REVIEW.md. Reviewer closed, jobs terminal.

These are distinct evidence layers. Source review/XCTest are not native acceptance, VoiceOver or physical performance results.

## Exact current candidate
Unsigned, uninstalled:
/Users/mac/Projects/Launch_Copy/PagingPrototype/.build/candidates/appearance-close-rc-20261015-r1/LaunchcopyUITest.app

Executable SHA-256:4e1af930a30b64eec66da7e8d21fb17a8af5fa89f79c18a4318b788b6a4e7fa9.

Candidate-local isolated ordinary non-topmost window/profile, forty owned Info-only fixture bundles. No formal application/profile changes or executable fixture-launch claim.

## Supported native observations
1. Initial repaired-candidate defaults: labelsOn/blur18/icon48/font11. Unapplied Off/0/64/16 -> actual close button -> reopen returns On/18/48/11. The before/after close-discard regression passes.
2. Apply Off/0/64/16 acknowledged; close/reopen retains accepted values. Visual labels disappear, sharp wallpaper remains visibly composited. No black fill inferred as the intended zero-blur behavior.
3. Restore Defaults produces only On/18/48/11 draft and explicit draft feedback. Closing without Apply then reopening restores accepted Off/0/64/16, not defaults.
4. Apply On/60/32/9: strong blur, smaller icons/font, visible labels and no observed overlap in the inspected1000x700pt ordinary window.
5. Apply On/0/64/16: sharp wallpaper, larger labels/icons with auto-fit, no observed overlap. Screenshots do not measure actual rendered64pt icon dimensions.
6. True restart: own PID44491 -> normal menuQuit -> exact executable absent -> same candidate reopened as PID47697. Actual controls restored On/0/64/16 and screenshot was inspected. This is process persistence, not only reopening a singleton settings window.
7. Final profile: Restore Defaults -> Apply acknowledged, On/18/48/11 saved. No second restart of those default values claimed. Normal menuQuit PID47697 -> exact executable absent. No native query after finalQuit; no owned test instance left running.
8. A settings click timeout recovered by observing the same running object; repeated background AX click did not open settings, then an observed coordinate click did. No app restart/guard bypass used to make that interaction succeed.

Native screenshots/AX trees are inline tool observations, not saved raw image artifacts. JSON files summarize observations and exact process checks, not a fabricated raw trace.

## Open actual-native defect: hidden label accessibility
With accepted showLabels=false, the full actual native tree lost all Handoff Demo application names and Group1 folder name; unnamed images remained. Names returned with showLabels=true. Existing property-level accessibility-label tests therefore do not establish native exposure when the only label child is hidden. Source root cause has not yet been inspected; no fix or VoiceOver PASS is claimed. This blocks full appearance acceptance, not the close/discard source fix.

Next executable action: inspect current AppGridCellView/folder title accessibility exposure, add actual exposed-element regressions, and repair only the reproduced name-visibility contract. Preserve current launch/drag/folder editing/reuse behavior; do not introduce an unreviewed activation route or Unknown wrapper. Rebuild/review/package/native-verify a new exact candidate if source changes. Keep all18 Core/UI/physics frozen unless a separately justified existing-contract issue demands otherwise.

## Evidence and remaining boundaries
Evidence directory:.build/verification/20261015/appearance-native/. Includes red/focused/full/debug/release logs,452-input manifest/delta proof, package probes, native-before.json, native-fixed-results.json and before/restart/final process records.

Retain prior status-slice follow-ups: old callback test needs a non-ready visible replacement to discriminate latch corruption; explicit combined locale+Library test is not yet added. Real IME/Tab/VoiceOver, matched physical60Hz AB,120Hz, multiple displays, power loss, native scanner failures and broader lifecycle gates remain separate. >25ms long-tail causality remains unresolved. Capacity/rows/columns/anchor, usage/history, destructive/extra gestures remain independently unapproved; no inference from this slice.

No installation/signing/notarization/publication/commit/push/reset/cleanup/deletion/processkill, OS setting/Space change, reference implementation/resource read, formal-data mutation or unrelated-app control. Existing dirty work preserved. Progress only; full goal remains active.
