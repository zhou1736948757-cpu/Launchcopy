# T-1J-LM-VERIFY — Verification Result

Status: IMPLEMENTED_PENDING_GUI_AND_FORMAL_REVIEW
Date: 2026-09-13
Owner: Main verification record

## Scope

This record covers the current Phase 1J layout, top-level click routing, Folder
motion/lifecycle integration, serialized automated verification, and a fresh
unsigned release candidate. It does not promote `LOCAL_RC_VALIDATED` and does
not replace the required independent Reviewer or user GUI/physical gates.

## Source identity

- Checkout: `/Users/mac/Projects/Launch_Copy/PagingPrototype`
- `git_head`: `6382bd911741831d13360e402c270bb6509b3679`
- Worktree: dirty; the package-time manifest recorded `git_dirty=65`.
  A later read-only status snapshot listed 64 short-status entries; this is a
  snapshot difference, not a claim that unrelated work was removed.
- Existing user and Phase 1J changes were preserved. No commit, reset, clean,
  or destructive operation was performed.

## Automated verification

All SwiftPM commands were run serially because the checkout shares `.build`.

| Check | Result | Evidence / notes |
|---|---|---|
| `rtk swift test --filter FolderOverlayTests` | PASS, 14/14 | Includes visual-only cleanup and callback/lifecycle coverage. |
| `swift build --target PagingPrototypeApp --configuration debug` | PASS | Debug target compilation completed. |
| `rtk swift test` | PASS, 1549/1549, 0 failures | Completed 2026-09-13 05:56:16.471; test time 23.929s. |
| `rtk swift build -c release --product PagingPrototypeApp` | PASS | `Build of product 'PagingPrototypeApp' complete! (21.34s)`. |
| `rtk git diff --check` | PASS | No whitespace errors. |

The historical baseline was 1530/0. The current count is higher because the
Phase 1J geometry, click, Folder motion, and lifecycle tests were added; the
increase is not a silent test skip. The only reported compiler warning is the
pre-existing Sendable warning at
`Sources/PagingPrototypeApp/AppDelegate.swift:1463`:
`capture of 'diagBackend' with non-Sendable type 'MultitouchSupportBackend' in a '@Sendable' closure`.

## Candidate package

The package command reread `Scripts/package-app.sh` and used a unique ID with
`LEGACY_DESTRUCTIVE=0`. The script assembled a new directory, refused existing
destinations, and did not sign, install, publish, or stop processes.

- Candidate: `/Users/mac/Projects/Launch_Copy/PagingPrototype/.build/candidates/phase1j-rc-20260913-055944-42580/Launchcopy.app`
- Manifest: `/Users/mac/Projects/Launch_Copy/PagingPrototype/.build/candidates/phase1j-rc-20260913-055944-42580/CANDIDATE_MANIFEST.txt`
- Configuration: `release`
- Bundle ID: `com.launchcopy.app`
- Version/build: `0.1.0` / `1`
- Minimum system: `14.0`
- Package-time build: `2026-09-12T21:59:47Z`
- Executable SHA-256: `23733d4cf96cbbeaffac5fa51d9d45da8db6018fd71a94de8a8f58d80a6fdf1c`
- Plist lint: PASS
- Signing/notarization: unsigned and not notarized; no distribution claim

Prior candidates were left untouched, including
`.build/candidates/phase1j-rc-20260911/`.

## Implementation evidence reviewed

- Top-level click path remains the B1/manual delivery path in
  `Sources/PagingPrototypeApp/AppDelegate.swift`, through
  `AppGridCellView` and `DragUISessionCoordinator` to
  `AppLaunchController`. Existing focused click tests and the full suite pass.
- `Sources/AppGridUI/FolderOverlayView.swift` now restores move-out state
  directly during clear/teardown even while a retained exit visual is
  visual-only. The focused regression test is
  `testClearContentRestoresMoveOutStateWhileVisualOnly`.
- Retained Folder exit visuals are the real overlay in inert visual-only mode;
  input, hit-testing, accessibility, callbacks, and late icon writes are
  suppressed while frozen. Normal motion is 180ms with bounded scale and
  displacement; Reduce Motion is opacity-only with identity transform.
- Presentation-render fidelity remains bounded by the retained-view approach;
  the earlier cache-vs-presentation experiment showed that bitmap cache capture
  does not preserve a live presentation transform.

## Independent review

Formal read-only Terra Reviewer task
`01a0977e-d3b1-7b70-bf10-1130d673d7f3` completed at the task-status layer, but
both the original and same-session re-send returned no readable assistant
message (`latestAssistantMessageId=null`, empty turn items). The earlier Terra
audit found no reproducible click defect and identified two coverage gaps: the
exact mounted production hierarchy plus recognizer action, and AppDelegate
hide/resize while Folder transitions are active. Those gaps remain explicitly
unclaimed because the formal verdict text is unavailable.

Reviewer verdict for this record: **PENDING**.

## GUI and physical gates

No fresh current-candidate GUI or physical-input run is claimed. The desktop
automation gate remains blocked by the exact message:
`The Mac is locked and automatic unlock could not unlock it. Ask the user to unlock the Mac manually before continuing.`

Therefore the following remain unverified in this record: real icon launch
from the current candidate, page/search visual placement, Folder origin-aware
open/close/reversal timing, Escape during motion, drag regression in the real
window, Reduce Motion behavior, and hide/resize/teardown under live animation.
Static tests, build success, package assembly, and HTTP/accessibility-style
reachability must not be read as substitutes for these gates.

## Verdict and next action

Current label: **RC_IMPLEMENTED_MANUAL_PENDING**.

Recover or otherwise obtain the formal Terra response and append its
findings/verdict. After the Mac is manually unlocked, run the current
candidate GUI matrix and record exact candidate identity. Do not claim
`LOCAL_RC_VALIDATED` until the required A-D manual gates are either completed
or explicitly waived by the user.

## Superseding Verification Update - 2026-09-13 07:13 local

This section supersedes the stale automated counts and candidate identity above;
the earlier entries remain historical records and are not rewritten.

### Current source and Terra audit reconciliation

- The current checkout remains `/Users/mac/Projects/Launch_Copy/PagingPrototype`.
- `HEAD` remains `6382bd911741831d13360e402c270bb6509b3679`.
- A fresh status snapshot counted 68 porcelain entries. Existing user and
  Phase 1J changes were preserved; no commit, reset, clean, deletion, process
  termination, installation, signing, or publication was performed.
- Read-only Terra audit task
  `01a097cd-ddbe-73c2-8fc8-09f7af9ed202` completed without edits. It identified
  three concrete risks: missing opacity-only entrance fallback for unavailable
  source geometry, an exit visual being retained when no reliable source could
  be formed, and missing screen-change cancellation wiring.
- The current tree addresses those findings at
  `Sources/PagingPrototypeApp/AppDelegate.swift:1052-1076` (optional source
  geometry plus identity-transform/opacity fallback),
  `Sources/PagingPrototypeApp/AppDelegate.swift:1093-1103` (reliable-source
  guard and immediate close), and
  `Sources/PagingPrototypeApp/AppDelegate.swift:1456-1457`, together with
  `Sources/PagingPrototypeApp/ActivationComposition.swift:333-338` (screen
  change callback before target refresh). This is implementation evidence, not
  a formal independent Reviewer PASS.

### Fresh automated evidence

- `rtk swift test`: exit `0`; XCTest executed `1553` tests with `0` failures in
  `24.021s` on 2026-09-13 07:11:33-07:11:57. The trailing Swift Testing
  footer reported zero tests because this package's executed suites are XCTest;
  it does not replace the XCTest count.
- Focused Phase 1J/click/folder command run immediately before the full suite:
  `rtk swift test --filter
  'FolderMotionTests|FolderOverlayTests|FolderIntegrationTests|LauncherIntegrationTests|AppLaunchControllerTests|B1ManualDeliveryTests|Bug9CellHitRoutingTests|AppCatalogAssemblyTests'`
  exited `0` with `94` XCTest cases and `0` failures.
- `swift build --target PagingPrototypeApp --configuration debug`: exit `0`,
  target build complete in `0.52s`.
- `swift build -c release --product PagingPrototypeApp`: exit `0`, product
  linked in `21.14s`. The only warning remains the existing
  `Sources/PagingPrototypeApp/AppDelegate.swift:1475` Sendable capture warning
  for `diagBackend` in a Timer `@Sendable` closure.
- `git diff --check`: exit `0`.

### Fresh unsigned candidate

The existing `Scripts/package-app.sh` was reread and invoked with
`LEGACY_DESTRUCTIVE=0` and a new candidate ID. It refused overwrite targets and
performed no signing, notarization, installation, publication, process stop, or
old-candidate removal.

- Candidate:
  `/Users/mac/Projects/Launch_Copy/PagingPrototype/.build/candidates/phase1j-rc-20260913-071309-final/Launchcopy.app`
- Manifest:
  `/Users/mac/Projects/Launch_Copy/PagingPrototype/.build/candidates/phase1j-rc-20260913-071309-final/CANDIDATE_MANIFEST.txt`
- Package-time `git_head`:
  `6382bd911741831d13360e402c270bb6509b3679`
- Package-time `git_dirty`: `68`
- Package-time `built_at`: `2026-09-12T23:13:14Z`
- Executable SHA-256:
  `c2a0f3750e3536e7a8c0d6005ac0a30524081efd6e6bb1f578ceed34c2a10069`
- `Info.plist` lint: PASS. Candidate is unsigned and not notarized.

### Runtime boundary and verdict

No fresh current-candidate GUI, physical mouse/trackpad, or real
`NSWorkspace.shared.open` launch result is claimed. Native desktop automation
is still blocked by the exact message:
`The Mac is locked and automatic unlock could not unlock it. Ask the user to unlock the Mac manually before continuing.`

Consequently, current-candidate icon launch, page/search placement, Folder
origin-aware open/close/reversal timing, Escape during motion, drag behavior,
Reduce Motion feel, and hide/resize/screen-change/teardown under live animation
remain manual/runtime gates. The retained-view exit approach is explicitly not
claimed to be a bitmap presentation-fidelity proof. The current label remains
`RC_IMPLEMENTED_MANUAL_PENDING`; no independent Reviewer PASS or
`LOCAL_RC_VALIDATED` claim is made.

## Superseding Runtime Update - 2026-09-13 12:26 local

The user reported that the Mac had been unlocked. A fresh native automation
probe was nevertheless attempted and returned the exact error
`The Mac is locked and automatic unlock could not unlock it. Ask the user to unlock the Mac manually before continuing.`
The same probe reported `unsupported Codex auth method: apikey` for browser
automation. A read-only `/usr/bin/pmset -g assertions` snapshot at
`2026-09-13 12:24:41 +0800` still showed `UserIsActive 0`. No GUI action was
performed and no existing process was stopped.

### Exact-candidate synthetic live run

The newest safe candidate was run directly, without installation or overwrite:

```text
PAGING_PROTOTYPE_GUI_SELFDRIVE=1 .build/candidates/phase1j-rc-20260913-1212-final/Launchcopy.app/Contents/MacOS/Launchcopy --neutral-content --page-count 5 --items-per-page 35 --reduce-motion-override off
```

The process exited `0` after approximately 20 seconds. It reported the
60 Hz runloop Timer source with `tolerance=0.000ms`, prepared the launcher
surface and wallpaper, initialized the four-finger backend with
`devices=1`, then emitted:

```text
SELFDRIVE stats: flings=40 committed=30 stales=10 live=5 pool=0 layouts=19 telemetryEvents=0
```

The run then called `teardownAll` and exited cleanly. This proves current
candidate startup, synthetic paging, stale rejection, host accounting, and
teardown only. It does not prove pointer delivery, Folder visual behavior,
real `NSWorkspace.shared.open`, WindowServer input, or physical trackpad
behavior.

Candidate identity was rechecked after the run:

- Candidate: `/Users/mac/Projects/Launch_Copy/PagingPrototype/.build/candidates/phase1j-rc-20260913-1212-final/Launchcopy.app`
- Manifest: `/Users/mac/Projects/Launch_Copy/PagingPrototype/.build/candidates/phase1j-rc-20260913-1212-final/CANDIDATE_MANIFEST.txt`
- Executable SHA-256: `0e1bba9a00a4eee5bc6602d681e8b59950dba45a4a1dbb9cbe7d56351bd9f8d1`
- Existing worktree status count: `69`; no source or test file was edited in
  this runtime pass.

The current label remains `RC_IMPLEMENTED_MANUAL_PENDING`. GUI, physical
input, real app launch, and formal independent Reviewer gates remain open.
