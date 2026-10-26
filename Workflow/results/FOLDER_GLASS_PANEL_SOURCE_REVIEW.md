# Folder Glass Panel — Independent Bounded Source Review

Date: 2026-10-16
Verdict: **SOURCE FAIL — one P2 lifecycle contract gap.**
Physical appearance/performance verdict: **NOT ASSESSED**.

## Authority, scope and method

Reviewed the current on-disk sources against `AGENTS.md`, `Docs/FOLDER_FROSTED_MATERIAL_SPEC.md` and `Workflow/stage-summaries/2026-10-16-folder-glass-panel.md`. This is the approved native panel-glass slice. Exterior blur remains unimplemented and pending a separate performance-first feasibility gate; it has not been established to be too expensive.

The project is a macOS 14+ SwiftPM/AppKit application. The folder view owns its retained visual subtree; AppDelegate owns mounting, title sessions, policy propagation and generation-gated entrance/exit transitions. Review concentrated on `FolderOverlayView.swift`, `FolderMaterialPolicyTests.swift`, and the material-related owner regression in `FolderRenameAssemblyTests.swift`. Targeted reads of AppDelegate and existing visual-only tests established actual lifecycle callers. A limited diff of the three named files was only supplementary: HEAD includes earlier accumulated work and is not an isolated pre-glass baseline. No findings below attribute all dirty changes to this slice.

All shell commands used `rtk proxy`. No builds, tests, UI, reference projects, system settings, installs, process termination or other agents were invoked. Parent owns serialized tests; this reviewer used no test/build resources and dispatched no additional concurrency. Only this report was written.

## Finding F1 — P2: Park the material when the reusable overlay is detached

**Affected source:** `Sources/AppGridUI/FolderOverlayView.swift:588-605` and `:941-943`; related native-material initialization at `:382-390` and terminal shutdown at `:622-624`.

**Evidence:** The normal effect starts visible with `state = .active`. `clearContent()` restores the panel and clears content, but neither hides nor deactivates the effect. `viewWillMove(toWindow: nil)` only cancels paging. The effect's sole `.inactive` assignment is in terminal `teardown()`, which ordinary folder close does not call. AppDelegate retains the reusable overlay at `:979`; synchronous close clears/removes it at `:1774-1776`, animated exit removes/clears it at `:1628-1633`, and interrupted/cancelled exit removes/clears it at `:1652-1658`. Thus, after closing a normally transparent folder through any of these paths, the detached retained overlay still contains an individually unhidden `.active` effect, until final application teardown or another policy change.

**Contract:** `Docs/FOLDER_FROSTED_MATERIAL_SPEC.md:49` explicitly requires lifecycle handling that does not “leave an active detached effect.” Terminal teardown satisfies this, reusable detachment does not. This is a source-state/contract failure. `.active` describes native effect state; this review does **not** equate it with a running timer, an active render pass, a leak or measured background GPU cost. No user-visible failure or performance regression has been demonstrated.

**Likely root cause:** New material shutdown is attached only to terminal disposal; reusable close/detach still uses the pre-material lifecycle.

**Recommended solution:** Add bounded view-lifecycle reconciliation so a detached/parked effect is hidden and inactive, then restore the current material policy before the next mounted opening can draw. Keep the same effect, panel and editor identities. Keep glass enabled throughout a still-mounted retained exit; do not deactivate merely because `isVisualOnly` is true. Ensure reattachment does not reactivate a torn-down view or bypass the opaque accessibility fallback. No snapshot, new timer, owner/physics redesign or measured-performance assertion is needed for this fix.

**Test gap:** `FolderMaterialPolicyTests.swift:85-86` expects active state for every non-torn-down overlay, including cleared host-only views; `:337-367` checks clear/resume without a real detach/reattach. It does not exercise the owner close paths above with an actual host. Add coverage for ordinary close, retained-exit completion/cancellation and reopening the same material instance, including fallback policies and terminal teardown. Parent must execute any added tests; none were executed here.

**Affected scope:** Material lifecycle in the folder view and focused lifecycle/owner tests.

**Regression risks:** Deactivating at visual-only entry would change the exit appearance. Restoring too late could create a first-frame material switch; restoring unconditionally could defeat Reduce Transparency/Increase Contrast or terminal shutdown.

**Confidence:** High for the reachable retained native state and explicit specification mismatch; no claim about physical performance impact.

## Other source checks

| Requirement | Current-source evidence | Assessment |
| --- | --- | --- |
| One retained native effect at the bottom of the stable panel | `FolderOverlayView.swift:29-32,342-343,373-390`; `.popover`, `.withinWindow`, `.active`, one bottom child | Satisfied structurally; no replacement/remount path found |
| Rounded clipping and layout-boundary sizing | `:386-388,1253-1277`; same radius as panel, masksToBounds, frame follows panel bounds in both layout paths | Satisfied structurally; actual blur bleed needs native visual inspection |
| Normal clear host and clear exterior | `:371,375,451-467,837-855` | Normal host clear; exterior remains clear through policy/collapse/restore; no exterior blur added |
| Accessibility opaque fallback | `:447-461`; either Reduce Transparency or Increase Contrast hides the effect and selects fully opaque semantic fill; contrast also strengthens border/footer | Satisfied in source; Reduce Motion remains independently configured |
| Decoration owns no input/AX content | `:29-32,389`; effect hitTest returns nil, is not an AX element and exports no children | Satisfied structurally; actual VoiceOver remains untested |
| Stable editor and sharp foreground | `:396-435,660-681`; editor and member cells are siblings above the effect; policy changes do not reparent them | Satisfied structurally; view-level identity tests at `FolderMaterialPolicyTests.swift:129-149,251-294` are relevant |
| Owner title cancellation remains intentional | `AppDelegate.swift:2310-2324` cancels an unaccepted draft before policy-driven refresh; owner regression `FolderRenameAssemblyTests.swift:563-589` checks fallback-to-glass, no save and reopening | Appropriate source coverage; does not claim owner notification preserves a draft it deliberately cancels |
| Retained exit is inert and uses the same view | `FolderOverlayView.swift:476-539,1194-1197`; owner `:1570-1601,1623-1662` samples presentation, suppresses callbacks/input/AX/late icon writes and generation-gates removal | Satisfied while mounted; F1 concerns the subsequent detached state |
| Move-out collapse/restore and terminal teardown | `FolderOverlayView.swift:827-855` hides/restores the parent panel without replacing material; `:608-643` hides/deactivates material and gates subsequent policy writes | Satisfied structurally; no collapse-driven new material allocation |
| No material-driven idle/per-frame work or icon rebinding | All `panelMaterial` references are initialization, policy, terminal teardown and layout. `applyMaterialPolicy` does not configure cells, request icons, capture pixels, filter images, persist preferences or start clocks. `renderTrackpadOffset` at `:1061-1074` has no material work | No added application-side material loop found; native compositor cost is unmeasured |
| Geometry/physics boundary | Material receives existing `panel.bounds`; policy mutates only material/fill/contour/footer colors. No material path changes capacity, ordering, motion parameters, paging configuration or persistence | No material-driven geometry/physics change found; lack of an isolated stage baseline prevents a whole-worktree unchanged claim |

Existing paging can create/bind page proxies when its bounded page window advances (`FolderOverlayView.swift:1018-1057`), and interactive visual resume can rebind members (`:1226-1239`). These are existing current-source lifecycle behaviors, not new material work or evidence of zero total per-frame activity. The material policy tests at `:194-247` appropriately check unchanged cells, tokens, images, geometry and icon-request counts under repeated policy toggles; they are source-reviewed assertions only.

## Evidence limits and remaining gates

No executed-test, compile, Debug/Release, packaging, localization or startup-order input PASS is issued by this reviewer. Parent's in-progress serial runs remain separate evidence. No native visual/physical gate is closed: light/dark/busy-background legibility, rounded blur edges, opening/reversal first frames, absence of brightness flashes, actual trackpad finger-following/settling, Chinese/Japanese IME, VoiceOver and matched cold/warm compositor measurements remain pending. Prior unexplained frame tails remain unresolved. Neither native API choice nor this report establishes low runtime cost.

Next executable action: Main addresses or explicitly resolves F1 against the approved specification, executes focused lifecycle/material/owner tests in its serialized lane, then requests a source re-review of the updated hashes. Exterior feasibility and physical acceptance remain separate.

## Reviewed input hashes

Hashes below were checked again immediately before report creation. This verdict applies to these bytes, not subsequent concurrent edits.

- `Docs/FOLDER_FROSTED_MATERIAL_SPEC.md` — SHA-256 `701eab655eade50eef6420b5eafa0575ffb280d7a26e28420eaf3c154a5c2e02`
- `Workflow/stage-summaries/2026-10-16-folder-glass-panel.md` — SHA-256 `79b9a8ec84c7c74dc38511c1d1996573929149ed545b91a4cf5c9db047071fb4`
- `Sources/AppGridUI/FolderOverlayView.swift` — SHA-256 `b0f3fdb435b9b7cf0ce96849ed13b2662f45c3a43c589685350f8411a8425a81`
- `Tests/AppGridUITests/FolderMaterialPolicyTests.swift` — SHA-256 `45d4be2372d58eb6d4e51aaa6697241a24ebecce6c417f3e558eb1d0151e12cf`
- `Tests/PagingUITests/FolderRenameAssemblyTests.swift` — SHA-256 `6b93910a0b7c74748ffc7628e844499afcc9a95cc0c829b1fa501bf9c10a81b8`
- `Sources/PagingPrototypeApp/AppDelegate.swift` — SHA-256 `55dac97ca278a569ad5ed70a66553648020edcd439dfa9a96e09460a1eb3890c`

Report created (UTC): 2026-10-16T06:55:05+00:00


## Supplemental review — fourth file and repair handoff (2026-10-16)

Status: **Fourth-file test adjustment accepted at source level; original SOURCE FAIL retained. F1 repair/re-review pending stable updated sources.**

### Adaptive chrome regression adjustment

Read the complete current `Tests/PagingUITests/AdaptiveFolderOwnerTests.swift` at SHA-256 `aa296e6625db38e768ba365ff3d46a4c6d3f03110dd464da005162be31560135`. This file is untracked in the current checkout, so `git diff` does not supply a pre-adjustment baseline. The source assessment below verifies retained assertions directly; exact before/after identity relies on Main's description rather than an independently available historical copy.

At lines 241-264, `testInsufficientSpaceVisibleChromeNeverOverlapsOrEscapesPanel` still checks all three insufficient-space sizes (180x150, 180x70, 400x270), asserts that member presentation is unavailable, checks every included foreground view against panel bounds, checks every pair for intersections, and requires a visible Close folder button. The existing title-edit target exclusion remains specific to the intentional label/hit-target overlap.

New checks unwrap a material view, require it to be the panel's bottom child, require its frame to equal `panel.bounds`, and require its hit test to return nil. The foreground filter excludes this exact material instance by identity (`$0 !== material`); it does not exclude all material classes, all backgrounds, or any additional title/footer/message/button view. A full-panel backdrop is expected to overlap foreground chrome, so separating that decoration from the foreground-only intersection invariant is appropriate. No foreground geometry tolerance was added, and no retained foreground bound/intersection/button assertion was removed from the current test logic. The adjustment does not weaken the intended foreground chrome acceptance contract.

Precision note: this test selects the first NSVisualEffectView and does not itself assert `effects.count == 1`. The existing `FolderMaterialPolicyTests.materialView` helper at lines 95-98 explicitly enforces the singleton invariant. Consequently, the combined source coverage checks uniqueness; do not describe the fourth test alone as containing an explicit singleton-count assertion. Another visible, nonempty material instance would also remain in this fourth test's foreground list rather than being blanket-exempted.

### Execution evidence boundary

Main reports that the initial full run executed 2793 tests with six failures, all from the generic overlap checks in this test case. That explanation is consistent with the current source: the decoration deliberately spans the panel. This reviewer did not read execution logs or run tests and therefore records these numbers as Main-reported, not independently verified. At handoff, focused r2 was running, full r2 was planned, and packaging had not started. No rerun, packaging or physical-performance PASS is issued here.

The original production file and original three reviewed-source hashes were unchanged at the fourth-file inspection checkpoint. That observation predates the newly announced F1 repair and is not a claim about subsequent concurrent edits.

### Accepted F1 repair handoff; no premature re-review

Main explicitly accepted F1 as a source-state/specification gap, with no proven GPU-cost claim. Main plans an unshown real-NSWindow regression, RED first, covering detach/attach, mounted retained exit followed by detach/clear, reopen, opaque fallbacks, collapse and terminal reattachment. Proposed repair reconciles native effect state through the view's own window lifecycle and gates rendering by fallback/collapse/teardown while preserving an active still-mounted exit. No owner or physics changes are planned.

These are Main's intended changes, not inspected implementation or executed evidence. The original FAIL and its reviewed hashes above remain historical. Wait for Main's stable-source checkpoint before final F1 re-review; require updated input hashes and distinguish any test results from source and physical acceptance. This supplemental entry adds no new blocking finding and does not close F1.

Supplement appended (UTC): 2026-10-16T06:56:44+00:00


## Repair re-review — 2026-10-16 (supersedes the original verdict for the hashes below)

**Current verdict: SOURCE PASS for the bounded panel-glass slice. F1 is resolved in source; no additional blocking source finding.**

The original SOURCE FAIL, evidence and earlier hashes remain historical above. This is a repair verdict for the four named files at the final hashes below, not a retrospective change to the original result. Executed green tests, package delivery and native visual/physical performance acceptance are not certified by this verdict.

### F1 resolution

`FolderOverlayView.swift:29-46` now gives the retained material its own attachment reconciliation: `viewDidMoveToWindow()` calls the same bounded state update as the `isRenderingAllowed` setter. The state is active only when allowed and the material's own `window` is non-nil. Initialization explicitly starts inactive (`:398`), avoiding an active host-only default.

`updatePanelMaterialRendering()` at `:479-482` permits rendering only when the overlay is not torn down, not move-out collapsed, and neither accessibility opaque fallback is selected. The existing mutation boundaries call it: policy changes at `:461-476`, collapse at `:847-859`, restore/clear reuse at `:865-877`, and terminal teardown at `:642-647`. Final teardown sets its terminal flag before reconciliation and before restoring collapse state, so neither restore nor later reattachment can revive the effect.

| Source state | Result |
| --- | --- |
| Detached normal reusable material | Inactive, including after exit detachment and subsequent clear/resume |
| Attached normal transparent material | Active |
| Attached normal drawing-only retained exit | Remains active; visual-only is deliberately not a rendering disqualifier |
| Reduce Transparency or Increase Contrast | Hidden effect, inactive state, opaque semantic panel fallback |
| Move-out collapsed | Parent panel hidden and material inactive; restore reconciles the current policy |
| Terminal teardown, including later reattachment | Hidden and inactive |

The repair meets the explicit no-active-detached-effect contract. A detached normal effect need not additionally set its own hidden flag: its inactive state and absence of a window resolve F1, and the specification's updated execution sequence expressly requires inactive parking. The earlier recommendation to hide as well was not an additional approved requirement. No GPU/compositor saving, leak repair or measured performance improvement is inferred from native `.inactive` state.

The original material remains one retained bottom child, within-window/popover, rounded and clipped (`:357,387-404`); the stable clear panel/editor host is preserved. Foreground content remains above it. The decoration still rejects input and accessibility children and is not an accessibility element. The exterior remains clear (`:484-488`). Both existing layout paths size only the effect to existing panel bounds (`:1275-1299`). No new capture, filtering, timer, icon request/rebinding, persistence or physics work was introduced into the reconciliation function or the frame callback (`:1083-1095`). AppDelegate's hash is unchanged from the original review; no owner repair is required for the material to receive its own window lifecycle notification.

### All four files and test intent

1. **FolderOverlayView.swift:** the repair closes the reachable detach-state gap while preserving the mounted retained exit, opaque fallbacks, collapsed presentation, terminal gating, editor ownership and existing presentation-aware owner sequence.
2. **FolderMaterialPolicyTests.swift:** the helper now expects active state only for an attached, normal, noncollapsed, nonterminal overlay (`:73-99`). Existing policy, identity, editor, icon-binding and clear-exterior assertions remain. New `testRetainedMaterialParksOnDetachAndRestoresOnlyForLiveTransparentHost` (`:153-193`) creates a real unshown NSWindow without ordering it front, checks initially detached state, attachment, mounted visual-only state, detachment, clear/resume/configure/reopen with the same effect, collapse/restore and terminal reattachment across the four policy combinations. This directly addresses the former host-only coverage gap rather than simply changing an expected constant.
3. **FolderRenameAssemblyTests.swift:** unchanged from the prior review by hash; `:563-589` still checks owner fallback-to-glass policy propagation, cancellation of an obsolete draft without saving and reopening. Its earlier source assessment remains applicable.
4. **AdaptiveFolderOwnerTests.swift:** unchanged from the fourth-file review by hash. At `:241-264`, all three size cases, unavailable-member assertion, foreground bounds checks, pairwise foreground nonoverlap and visible Close folder requirement remain. Only the exact, separately checked bottom full-panel/pass-through decoration is newly exempted. No weakening of the intended foreground chrome contract was found. Explicit singleton counting remains in the material-test helper, not in this owner test itself.

### Coverage and execution boundaries

Read `.build/folder-glass-panel-lifecycle-red.log`: lines 12-40 record the lifecycle regression actually executing one XCTest with 21 assertion failures before repair. The trailing Swift Testing line with zero tests does not supersede that XCTest execution. The RED log establishes that the regression exposed the old state; it does not prove the current implementation passes.

At dispatch Main reported focused r3 in progress and the post-repair full run not yet rerun. The stage checkpoint reports prior focused r2 at 47/0; this reviewer did not independently validate that run. No current GREEN, full-suite, build or package PASS is issued here. This review executed no tests or UI and wrote no implementation/test file.

**Remaining owner-level coverage boundary (not a new blocking source finding):** the new regression reproduces retained exit/detach/clear/reopen using view APIs; it does not trigger AppDelegate's scheduled exit completion or interrupted-reversal callback itself. The owner rename test checks close/reopen policy contour, not native effect state on every animation path. Thus, actual owner animation completion/cancellation, resize/source replacement and terminal application sequencing are not newly execution-verified by this test. Existing owner/transition regressions and Main's serialized full run remain necessary evidence; do not present this view-level regression as execution proof of every owner path.

Native first-frame coherence, rounded blur appearance, light/dark/busy-background legibility, no dark flash, physical trackpad behavior, actual IME/VoiceOver and native compositor measurements remain pending. Exterior blur is still pending separate feasibility work and has not been declared expensive. SOURCE PASS closes this bounded source review only, not the stage or those acceptance gates.

### Final reviewed hashes

These hashes were rechecked immediately before this append. They identify the exact source/context bytes for this repair verdict; later concurrent changes require appropriate new review.

- `Sources/AppGridUI/FolderOverlayView.swift` — SHA-256 `c637f19d85a2624feaff3c7fe2dc110d4663d2506f6efd50e99463eb4ababcd8`
- `Tests/AppGridUITests/FolderMaterialPolicyTests.swift` — SHA-256 `722036e2364a1dd3c1d00a9685fc7ec0a93ae36db483416302dcd1238c77c2b1`
- `Tests/PagingUITests/FolderRenameAssemblyTests.swift` — SHA-256 `6b93910a0b7c74748ffc7628e844499afcc9a95cc0c829b1fa501bf9c10a81b8`
- `Tests/PagingUITests/AdaptiveFolderOwnerTests.swift` — SHA-256 `aa296e6625db38e768ba365ff3d46a4c6d3f03110dd464da005162be31560135`
- `Sources/PagingPrototypeApp/AppDelegate.swift` — SHA-256 `55dac97ca278a569ad5ed70a66553648020edcd439dfa9a96e09460a1eb3890c`
- `Docs/FOLDER_FROSTED_MATERIAL_SPEC.md` — SHA-256 `3ff43196272bc4db62b8ad9c2a8d67c71573e30243e07f5123f0c4031436455e`
- `Workflow/stage-summaries/2026-10-16-folder-glass-panel.md` — SHA-256 `1d15bb14227e87257d02b43d3a1bdf985b38f2917e3b076968c5bd96e87bdf0b`
- `.build/folder-glass-panel-lifecycle-red.log` — SHA-256 `f63e4c1afff85c6e377b76cde8fcef73c139d21b646e4b4b38da19709adb4787` (read-only historical RED evidence)

Repair verdict appended (UTC): 2026-10-16T06:59:03+00:00
