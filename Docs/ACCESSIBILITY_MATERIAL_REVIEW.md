# Accessibility Material Repair — Independent Source Review

Date: 2026-10-13, 20:14 JST
Verdict: **PASS — bounded source and lifecycle review only**
Open actionable findings: **none (P0/P1/P2/P3)**.

## Authority and scope

Reviewed the existing-contract repair in `Docs/ACCESSIBILITY_MATERIAL_REPAIR.md`,
the approved `Docs/LAUNCHBETTER_PARITY_SPEC.md` (especially sections 4–6), and the
latest reconstructed `Docs/LAUNCHBETTER_PARITY_STATUS.md`. This review covers
material tokens, the application-owned accessibility notification/cache/chrome
and folder consumers, early title cancellation, folder material lifecycle, and
the assigned regression test sources. It does not approve new product scope.

The reviewer wrote only this new document. No source/test edits, builds, test
execution, GUI operations, reference/old rebuild access, installation, commits,
process termination, additional agents, or workflow runtime routing were used.
Main alone owns execution and delivery verification.

## Stable input identity

Main identified the integrated frozen manifest:
`.build/verification/20261013/material-repair/source-files-r1.sha256`.
Independent read-only fingerprint verification found **311/311 matches**, zero
mismatches. Manifest SHA256:
`d1e95cc91196a94282f738b75e7d78d5f6b38ca9b19d129750f16d2ee2ddd16e`.
Fingerprint coverage is not source-review coverage of all 311 files.

| Assigned source/test | SHA256 |
| --- | --- |
| `Sources/PagingPrototypeApp/LaunchcopyVisualTokens.swift` | `b0e33cdf67e3a53385026f39e67508abaeecce3e185ff601f5a54e85ab4f2220` |
| `Sources/PagingPrototypeApp/AppDelegate.swift` | `a12a010dd10b6d4d5022894c6cfa489f257ae39ead963b3cfc0e6e5710a0d335` |
| `Sources/AppGridUI/FolderOverlayView.swift` | `c15663ae78b97b256685095aea74a2a08c57df19b22c96d4663a0fde58368c51` |
| `Tests/AppGridUITests/FolderMaterialPolicyTests.swift` | `b04b92ddb453ea195b17598620b28f3764d3ddbacea86f3daca746ee57925746` |
| `Tests/PagingUITests/LauncherChromeMaterialTests.swift` | `5e355dae15eee44bda526022d06c6091d12f10157191e607b242362aeec5de4a` |
| `Tests/PagingUITests/FolderRenameAssemblyTests.swift` | `32c91abd322dc50c28eb4a29b7260ae3dc252f1179c55bac1afeb7283294aeb5` |

Supporting reads were restricted to relevant own-project source/tests, including
`FolderTitleEditor.swift`, `PagingSurface.swift`, and the notification tests in
`AppearancePreferencesTests.swift`. Any change to reviewed source hashes requires
a scoped review update before treating this verdict as applicable.

## Findings and concrete source evidence

No current defect warranting a severity was found within the assigned scope.
The following are accepted observations, not newly discovered defects.

| Requirement | Exact locations | Review result |
| --- | --- | --- |
| Preserve ordinary styling | `LaunchcopyVisualTokens.swift:49–56`; `AppDelegate.swift:2097–2137`; `FolderOverlayView.swift:243–270,297–309` | Normal settings fill remains black at alpha 0.32, with zero border width and a clear border. Existing gear symbol, tint, size, corner radius, target/action, autoresizing and labels remain. Normal folder backdrop stays black at alpha 0.35; panel stays window-background color, separator border width 1, footer secondary-label color. Material methods do not change fonts, frames or hit regions. |
| Real opacity under Reduce Transparency | `LaunchcopyVisualTokens.swift:49–53`; `AppDelegate.swift:2131–2137`; `FolderOverlayView.swift:301–313` | Chrome fill alpha is 1, and its actual layer receives both that fill and `isOpaque = true`. Folder backdrop alpha becomes 1 and panel fill explicitly receives alpha 1. The intentional collapsed backdrop exception remains clear. |
| Contrast independent of motion/transparency | `LaunchcopyVisualTokens.swift:13–30`; `AppDelegate.swift:2135–2137`; `FolderOverlayView.swift:297–309` | Contrast separately selects a 2-point white chrome boundary, a 2-point label-color panel boundary, and label-color footer text. No material branch depends on Reduce Motion. Folder material application never changes its motion flag. |
| Actual notification and cached consumers | `AppDelegate.swift:62–65,503–505,1780–1807,1445–1456,2125–2143,2499–2502` | Production subscribes through the workspace notification center and calls the real handler on the main queue. Handler caches policy, refreshes the existing settings layer, refreshes the open folder, and refreshes wallpaper. Subsequently created chrome/folders consume the cached policy; startup falls back to current system flags. Final teardown removes the observer from its owning center and guards late handler/layer updates. |
| No added frame I/O, scans, persistence, page/cell rebind or icon requests in material consumers | `AppDelegate.swift:2131–2137`; `FolderOverlayView.swift:297–314,656–667`; `AppDelegate.swift:1447–1456,1791–1807` | New material consumers are constant-size layer/text updates. They do not invoke catalog, persistence, page reload or icon APIs, install timers, or add a frame callback. Application notification handling retains folder refresh and existing motion/drag/transition cancellation. `configure` remains idempotent for unchanged entry/page/motion/catalog (`FolderOverlayView.swift:381–413`); motion/catalog changes and actual visual resume can still rebind through existing lifecycle paths. This is not a claim that every pre-existing notification/lifecycle path is constant-time. |
| Retained exit views remain material-immutable | `FolderOverlayView.swift:297–300,322–372`; `AppDelegate.swift:1433–1444` | Torn-down and visual-only overlays reject policy updates before even storing flags. Closed retained exit overlays are not given an interactive material refresh. Existing cleanup may reset a removed view; frozen presentation is not mutated by the material API. |
| Collapsed clear and current-policy restore | `FolderOverlayView.swift:301–302,640–667,419–451` | Updates while collapsed keep the outer backdrop clear and panel hidden. Restore uses stored `materialBackdropColor`, rather than hardcoded normal alpha. Direct restore, configure, clear-content and teardown converge on the existing restore path. Ignored visual-only updates cannot replace the stored restore policy. |
| Cancel unaccepted title before focus transfer | `AppDelegate.swift:1791–1801,1542–1555`; `FolderTitleEditor.swift:70–81,94–98` | Handler first calls `finishFolderTitleEditing(returnFocus: false)`, before motion refresh, drag cancellation or transition cancellation. Finish clears rename context and owner editor, marks the editor finished and removes its callbacks before unmounting. Later native focus-loss or stale explicit commit cannot save the draft; this finish does not request a new first responder. |
| Preserve module boundary and privacy | `FolderOverlayView.swift:19–22,297–309`; `AppDelegate.swift:1791–1807,2131–2137` | AppGridUI consumes two semantic booleans without importing the app target. Reviewed material/cancellation additions add no title/name/path/identity logging, telemetry, storage schema or settings diagnostics. Existing diagnostics elsewhere are outside this repair verdict. |

The title-order repair addresses the specific failure Main reported in
`owner-focused-r1` (23 tests, 1 failure): accessibility-driven focus transfer could
auto-save an unaccepted draft. This historical failure is superseded for the
reviewed source by callback invalidation before unmount/drag cancellation. The
earlier run was reported by Main, not independently re-executed by this reviewer.

## Test-source assessment and execution boundary

Reviewed all **7** `FolderMaterialPolicyTests`:

- `:91–117`: light/dark normal appearance and all four policies under both motion
  flags. The native drawing closure stays nonthrowing; caught errors are retained
  outside it and rethrown after drawing, rather than silently swallowed.
- `:119–131`: applying policy before content configuration survives opening.
- `:133–188`: repeated toggles preserve cell identity, bindings, injected icons,
  generation, geometry, labels/fonts, pipeline request count and loader keys.
- `:190–234`: mounted editor and title request/invalidation callbacks survive
  material-only updates without removal or lifecycle cancellation.
- `:236–274`: collapsed clear presentation and all four restore callers use the
  latest stored policy without extra requests.
- `:276–308`: visual-only updates are ignored, including stored policy, followed
  by cleanup/resume checks.
- `:310–332`: retained torn-down views reject material updates.

Reviewed all **3** `LauncherChromeMaterialTests` (`:11–22,30–54,56–70`): independent
token matrix, actual detached settings target/action/layer and identity/frame
preservation, and production-handler refresh before/after control creation.

Reviewed the new `FolderRenameAssemblyTests.swift:427–449` regression. It uses
the real application owner, folder title button and mounted editor in an unshown
AppKit window; injects production accessibility-handler events; verifies opaque/
contrast folder mapping; attempts stale commit after cancellation; checks saved
layout equality and zero accepted writes; and verifies normal policy on reopen.
It does not change live system accessibility settings. Its handler injection is
not an OS notification or physical drag reproduction. Supporting observer tests
in `AppearancePreferencesTests.swift:148–183` exercise notification delivery and
removal plus the handler/wallpaper pending-result seam through a test center.

Main's `.build/verification/20261013/material-repair/focused-r3.log` was read,
not generated by this reviewer. It records **73 XCTest tests / 0 failures** at
**20:12:14.107 JST**, **1.166 seconds** elapsed (`:233–236`), including the assigned
7 + 3 + 1 regressions. The subsequent Swift Testing trailer has zero tests and is
not substituted for this nonzero XCTest result. This is observed Main-owned
execution evidence, not independent test execution or certification of a binary.

The prior **1917/0** full-suite result, Debug/Release success, R2 source PASS and
R2 executable hash in `LAUNCHBETTER_PARITY_STATUS.md:29–33` are baseline records.
They do not certify this repaired candidate. Main reported the current full suite
running; its result and current Debug/Release/candidate hash gates remain outside
this source verdict.

## Ledger integrity and remaining acceptance gates

`LAUNCHBETTER_PARITY_STATUS.md:43–52` explicitly records the accidental PLAN-text
overwrite, preserved archive location and reconstruction authority. The current
ledger has the parity header, requirement rows and separate pending GUI/physical/
delivery gates, rather than treating PLAN text as a new acceptance decision.
The reconstruction is used only for scope/integrity context. This reviewer does
not certify exact recovery of every historical byte, re-audit historical runs,
or treat reconstruction as test evidence.

This bounded PASS establishes no GUI/pixel acceptance, physical accessibility
toggle behavior, matched performance non-regression, restart durability, complete
product parity, distribution readiness, or new-candidate build/package identity.
Those gates remain Main/user-owned. No repair recommendation or architecture
expansion is required by this source review.
