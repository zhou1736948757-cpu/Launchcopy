# T-1E-folder-open-repair-wiring — Review r1

Verdict: **PASS**

## Scope
Independent read-only review of the folder-cell click wiring (keyboard focus + openFolder) and its 3 integration tests. Task spec: `Workflow/tasks/T-1E-folder-open-repair-wiring.md`. Worker result: `Workflow/results/T-1E-folder-open-repair-wiring.md`.

## Findings (file:line)

1. **Focus set BEFORE open** — `Sources/PagingPrototypeApp/AppDelegate.swift:555-560` `handleFolderCellClick` calls `keyboardController?.setFocus(to: identity)` (line 557) before `openFolder(folderID:)` (line 559). `KeyboardFocusController.setFocus` (KeyboardFocusController.swift:203-208) sets `focusModel.current` and exits deferred state, so a subsequent Return/Enter is no longer a no-op. Confirmed: with folder open, `keyDown` Return → `activateInnerMember` → `onActivateMember` (KeyboardFocusController.swift:150-154, 326-332). Click-then-Return path is correct.

2. **openFolder reuses existing snapshot/open/refresh path** — `AppDelegate.swift:544-549` `openFolder(folderID:)` looks up the entry from `assembly.provider.servedFolderSnapshot?.entry(for:)`, calls `folderOpenState.open(entry)`, then `refreshFolderOverlay()`. The existing `openFolder(_ identity:)` (537-540) delegates to it. No new open/refresh machinery introduced.

3. **No parallel app-launch path; AppLaunchController untouched** — `handleFolderCellClick` only sets focus + opens folder; it never routes to `AppLaunchController`. Folder identity is rejected by `as? AppID` (verified by `testFolderIdentityNeverEntersLaunch`). `AppLaunchController.swift` mtime 2026-08-28 21:46, predates task. Member launch still reuses `AppLaunchController.handleCell` via `makeMemberLaunchCell` (AppDelegate.swift:588-593).

4. **Seam use is faithful and minimal** — `onFolderClick` propagation mirrors the existing `folderSnapshotProvider` seam exactly: `AppGridRenderer.onFolderClick` with `didSet` fan-out to pages (AppCatalogAssembly.swift:172-178), set on page in `render()` (241), and `AppGridPageView.prepareCells` sets it on every cell (new + reused) (AppGridPageView.swift:188-203). This is the "renderer/page factory path already used for folderSnapshotProvider" the spec explicitly allowed. `AppGridUI` and `AppCatalogAssembly.swift` are not in the frozen list (only `AppLaunchController.swift` is frozen in PagingPrototypeApp), so these edits are in scope.

5. **Frozen trees untouched (mtime check)** — newest mtime per frozen tree, all predate task work (task created 2026-08-30 ~17:45; changed files 17:44-17:45):
   - Sources/PagingCore: 2026-08-30 11:46
   - Sources/AppCatalogCore: 2026-08-28 20:50
   - Sources/MacAppCatalog: 2026-08-28 21:01
   - Sources/AppIconPipeline: 2026-08-29 00:22
   - Sources/PagingTelemetry: 2026-08-28 21:09
   - Sources/PagingUI: 2026-08-30 15:15
   - Package.swift: 2026-08-28 20:42
   - Sources/PagingPrototypeApp/AppLaunchController.swift: 2026-08-28 21:46

## Verification evidence

- `swift build -c debug` → exit 0.
- `swift test` (3 full runs, serial): run 1 = 767 tests, 0 failures, exit 0; run 2 = 767 tests, 0 failures, exit 0; run 3 = 767 tests, 0 failures, exit 0. All runs executed > 0 tests (no INVALID_TEST_EXECUTION).
- New tests confirmed individually: `testFolderCellClickOpensFolderViaRendererSeam` (pass), `testFolderCellClickThenReturnActivatesMember` (pass), `testAppCellClickStillLaunchesViaAppLaunchController` (pass). FolderIntegrationTests suite = 17 tests, 0 failures.
- `swift build -c release` → exit 0.

## Flakiness assessment

The Worker claimed "First run showed 5 failures; 3 subsequent full runs all 0 failures — pre-existing intermittent flakiness, not from these changes." I ran the full suite 3 times plus a filtered FolderIntegrationTests run plus a single-test run: **zero failures in every run**. I could not reproduce the reported 5 failures. The 3 new tests passed consistently in both isolated and full-suite runs. No failure was observed that touches the changed code paths, and no failure is attributable to this change. The flakiness claim is consistent with my observations (the change is stable across all my runs); I can neither confirm nor reproduce the specific 5-failure first run, but it does not affect the verdict since the new tests pass consistently and the change is deterministic.

## MINOR notes

- Baseline count discrepancy: task spec says baseline 762, reviewer brief says 764; Worker reports 762 + 5 = 767. Total observed = 767, consistent with 3 new tests (764+3) or 5 new (762+5). The 3 new tests are confirmed present and passing; the exact baseline figure is not resolvable without git history (no git ops allowed). Non-blocking.
- The task's "Write scope" listed only AppDelegate.swift and the test file; the Worker also edited AppCatalogAssembly.swift and AppGridPageView.swift. This is required to propagate the callback through the allowed seam and is not a frozen-tree violation. Non-blocking.

## Privacy
No app names, bundle IDs, folder titles, or raw paths recorded. Only neutral counters and project source file paths.
