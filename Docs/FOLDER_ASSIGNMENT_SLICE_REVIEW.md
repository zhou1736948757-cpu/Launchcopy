# Folder Assignment Slice — Independent Source Review

Date: 2026-10-13
Project: `/Users/mac/Projects/Launch_Copy/PagingPrototype`
Contract: `Docs/LAUNCHBETTER_FOLDER_ASSIGNMENT_SLICE.md`
Stage: `2026-10-13-folder-assignment-parity`

## Verdict and authority

**SOURCE REVIEW: FAIL — actionable transaction and identity findings remain.**
This is a source verdict for the inspected slice and shared integration, not a
test-suite failure or a GUI, performance, packaging, or full-parity verdict.
Main owns repair decisions, implementation, test execution, builds and packaging.
The reviewer created only this report, dispatched no agents, and ran no builds,
tests, GUI, installs, commits, process stops or implementation edits. No original
LaunchBetter/Buho implementation, assets or historical evidence was accessed.

## Evidence boundary

- Independently read the approved slice contract, current stage summary, current
  menu/policy, context-menu embedding, owner commit/protection/restore code,
  search presentation, projection/mutation/persistence dependencies and tests.
- Independently read the final lines of the current log
  `.build/verification/20261013/folder-assignment/full-r1.log`: XCTest reports
  **1795 executed, 0 failures**, completed at `18:12:13.168`, with `22.433` seconds
  test duration. The subsequent Swift Testing zero-test trailer does not negate
  the executed XCTest suite. This reviewer did not execute the suite.
- Main reports focused **53/0** and 53 additional tests (36 submenu, 8 search,
  9 owner). Those counts are supplied evidence, not independently executed checks.
- Relevant source/test hashes were unchanged on the final read. Source inspection
  establishes the paths below; the listed missing regressions were not executed.
- Real context-menu display, keyboard interactions, restart, physical paging,
  actual persistence on device, timing, Debug/Release and candidate acceptance
  remain outside this review. Green synthetic tests do not satisfy those gates.

## Findings

### F1 — [P1] Shared drag commit bypasses bootstrap and layout protection

**Actionable location:** `Sources/PagingPrototypeApp/AppDelegate.swift:793-794`.
Supporting paths: `AppDelegate.swift:727-741`, `769-775`, `1704-1719`,
`1814-1822`; `Sources/AppGridUI/DragUI/DragUISessionCoordinator.swift:514-517`;
`Sources/AppGridUI/LayoutStore/LayoutStoreActor.swift:75-78`.

**Trigger and evidence:** Folder menus correctly reject `isRestoringLayout` and
layout-store read-only protection, but drag has only title/search gates and calls
the same `commitWorkspaceLayout` directly. That function checks teardown and
assembly availability only. Once a catalog is visible while `store.load()` is
still suspended, a real drag can commit a generated session layout. The eventual
restore returns early because `sessionLayout != nil` at line 1713, losing the
saved canonical order and hidden/missing references from the session. With a
loaded protected store, drag still changes session/provider/UI, while the actor
silently refuses its enqueue. This protection issue is on the shared drag path;
it is not a claim that the menu's initial read-only guard is missing.

**Likely root cause:** Protection is enforced by the menu consumer, rather than
by the application transaction used by both organization entry points.

**Recommended solution:** Use a common layout-write readiness guard for drag
startup and the final shared commit, covering bootstrap, teardown and independent
layout protection. Preserve the existing click fallback when drag is unavailable.
Recheck at commit so a protection change during a drag cannot apply stale work.
Do not reuse the menu's active-drag prohibition inside a successful drag commit.

**Required regression:** Hold a controlled load continuation with a saved layout
containing latent members; attempt a real drag before release and assert no
session/provider change or enqueue, then assert saved layout restoration. Repeat
with a protected store and with protection raised between press and drop.

**Affected scope / regression risk:** Shared organization transaction and drag
gating; preserve ordinary clicks, allowed healthy drag and search/title arbitration.
**Confidence:** High from the complete call chain; no device reproduction claimed.

### F2 — [P1] Path-to-bundle identity transition duplicates a live app

**Actionable location:** `Sources/PagingPrototypeApp/AppDelegate.swift:1683-1686`.
Supporting paths: `Sources/AppGridUI/LayoutDomain/VisibleWorkspaceProjection.swift:74-85`,
`100-115`, `133-141`; `Sources/AppGridUI/LayoutDomain/PersistentAppReference.swift:25-29`,
`41-47`; `Sources/PagingPrototypeApp/AppFolderAssignmentMenuController.swift:19`,
`113-120`; `Sources/AppGridUI/LayoutDomain/LayoutMutation.swift:158-170`.

**Trigger and evidence:** An existing saved app reference uses canonical path,
and the current record at that path now also has a bundle identifier. Projection
explicitly resolves the saved path to that record, but its unorchestrated-tail
test compares only the newly preferred bundle reference against stored keys.
The owner appends that bundle reference to the canonical layout even though the
same live record is already represented by its saved path. If that path is a
member of folder A, menu ownership lookup using `.from(record:)` misses A and
offers it as a destination. Moving into A or another folder moves the appended
bundle reference and leaves the path member in place. One live app can appear
twice in a folder or in two folders. Distinct path/bundle keys evade logical
reference-equality duplicate checks.

**Likely root cause:** Tail membership and menu/policy source identity use the
preferred new reference instead of the reference already representing the record
in the current canonical layout.

**Recommended solution:** Determine whether a record is already represented by
any canonical reference using existing matching semantics, and use its existing
stored reference for source membership and mutation. Append only genuinely
unrepresented records. Preserve dormant references and avoid introducing a new
identity migration or destructive normalization policy without approval.

**Required regression:** A valid layout contains a path member plus a latent
survivor; the current catalog record at that path has a bundle ID. Assert one
presentation occurrence, exclusion of its current owner from menu destinations,
and a real menu cross-folder move/move-out that preserves the original reference,
the latent survivor and exactly one live occurrence. Also cover an existing
top-level path reference and moving another app into the affected folder.

**Affected scope / regression risk:** Canonical resolved-layout tail, menu owner
lookup and policy source reference. Existing pure path-only and bundle-only cases
must remain valid; unrelated identity migration is not authorized by this report.
**Confidence:** High, deterministic source-derived case; not runtime reproduced.

### F3 — [P2] Cancellation transaction loses the weak cell/token validation

**Actionable locations:**
`Sources/PagingPrototypeApp/AppFolderAssignmentMenuController.swift:174-195` and
`Sources/PagingPrototypeApp/AppDelegate.swift:1838-1846`.
Supporting paths: `AppFolderAssignmentMenuController.swift:68`, `72-89`;
`AppDelegate.swift:493-497`, `575-576`, `1057-1075`, `1321-1328`;
`Sources/PagingCore/PagingCore.swift:365-379`;
`Sources/AppGridUI/AppGridSearchPresentationController.swift:90-101`.

**Trigger and evidence:** The menu validates weak ownership and the full item
token before calling `onApply`, but that callback passes only record/action/layout.
While a settling transition is cancelled, callbacks can commit a staged search
result at the same catalog revision and refresh/reuse cells. The owner's final
guard rechecks revision, layout, URL and hidden state, but has no cell/token to
revalidate. Therefore same-revision rebinding or loss of the originating cell can
still commit the retained action. The new revision-8 cancellation test covers the
revision mismatch branch, not this token-only invalidation branch.

There is also an observable rejection side effect in this same transaction:
`closeFolder()` runs before cancellation and the final guard. For a member action
that is then rejected by a staged catalog change, the open overlay has already
been cleared/removed. This violates the contract's rejection/no-refresh boundary
and makes late cell validation impossible for real overlay cells, because the
owner itself has already invalidated them.

**Likely root cause:** The immutable menu binding stops at the consumer boundary;
the owner invalidates UI before the transaction's final validity decision.

**Recommended solution:** Carry a weak binding validation closure or equivalent
immutable expectation into the synchronous owner transaction. Cancel stale paging
input, then revalidate the original cell/token and all owner expectations before
any success UI work. Defer folder close/content clearing until the final guard
accepts the mutation; separate visual-animation cancellation from logical close
where needed. Do not retain the originating cell strongly as a workaround.

**Required regression:** Invoke the actual retained menu selector; on cancellation
rebind/clear its actual rendered cell without changing layout/revision/URL and
assert no commit/enqueue. Separately start from an open member overlay, deliver a
changed catalog through cancellation and assert rejection preserves folder UI
unless the independent catalog update itself requires its reconciliation. Include
a normal member-menu success so the owner's cleanup does not reject its own action.

**Affected scope / regression risk:** Menu-to-owner callback contract, cancellation
ordering and folder close; preserve allowed settling takeover and active physical
drag rejection without cancelling the physical interaction.
**Confidence:** High on missing validation/order; synthetic callback case proposed,
not executed here.

### F4 — [P2] Deferred enqueue can write into a replacement store generation

**Actionable location:** `Sources/PagingPrototypeApp/AppDelegate.swift:853-858`.
Supporting path: `AppDelegate.swift:1694-1708`.

**Trigger and evidence:** Commit captures `layoutRestoreGeneration`, then launches
a task which obtains `self.layoutStore` only when it eventually runs. If a store
is installed/replaced in the same MainActor turn before the task starts, that task
enqueues the earlier layout into the new store. The generation check occurs after
`enqueue`, so it only prevents a stale state assignment, not the write. This is a
conditional installation race exposed by the installation seam; current launch
source installs a store once, and this review does not claim normal production
startup replaces it repeatedly.

**Likely root cause:** Store identity is captured too late and generation
validation protects only feedback.

**Recommended solution:** Capture the intended store with the generation at the
transaction boundary, and check generation/teardown before requesting enqueue.
Keep the existing post-await check before changing owner protection state. Define
replacement behavior for already accepted writes without silently routing them
to another store.

**Required regression:** Commit a valid layout, synchronously install a second
controlled store before yielding, then allow tasks to run. Assert the old layout
is never enqueued into the replacement store and stale state cannot overwrite its
load protection. Use a controlled continuation for a superseded load as well.

**Affected scope / regression risk:** Owner persistence lifecycle; preserve normal
one-success/one-enqueue behavior and store actor coalescing.
**Confidence:** High for the stated scheduling order; production frequency unknown.

## Source observations that are correctly implemented

- Real view menu providers lead through `AppContextMenuController` to the independent
  submenu and its Objective-C selector, then to the owner's shared commit. Owner
  assembly tests call `performActionForItem`; submenu tests explicitly distinguish
  modeled counters from real owner/persistence evidence.
- Bindings are weak for cells, compare the full token, revision, URL and persistent
  reference before dispatch, and compare full layout values rather than generation
  alone. Renamed/removed targets change that snapshot; folder IDs determine targets.
- Canonical top-level folder order supplies destinations, including entirely latent
  groups; ordinary hidden/missing references survive existing atomic mutations.
  Duplicate menu titles receive collision-aware local ordinal suffixes.
- Menu layout protection is independent of metadata future-schema protection.
  No-op/rejection before owner cancellation avoids commit/enqueue.
- Final logical-state gating correctly permits idle/cancelled/settling and rejects
  tracking/interrupted; active physical drag is rejected without cancellation.
- Post-cancel revision/full-layout/hidden/URL guards reject the staged new-catalog
  transaction covered by the final owner cancellation test.
- Shared commit aligns search `itemsPerPage` to the surface, reapplies the current
  query through `commitLayout`, uses the served presentation count, and checks
  removed visible member identities rather than comparing canonical and filtered
  member counts. These are not outstanding findings.
- Submenu generation is request-driven. The resolved-layout cache prevents a full
  projection on every drag lookup when its inputs are unchanged. No new per-frame
  menu build, preferences I/O or layout I/O path was found; no timing claim is made.

## Separate full-goal residual — not an assignment-slice repair

`Sources/PagingPrototypeApp/AppDelegate.swift:1370-1374` ends title editing but
does not call `LayoutMutation.renameFolder` or shared persistence. Main explicitly
tracks real title-editor rename persistence in the pending ledger. This report
does not treat that known residual as a newly introduced assignment finding, and
does not claim this slice fixes folder rename or completes full parity.

## Frozen inputs

SHA-256 on the final source read, unchanged from the preceding hash read:

| Path | SHA-256 |
| --- | --- |
| `Docs/LAUNCHBETTER_FOLDER_ASSIGNMENT_SLICE.md` | `f360b61e502199a1c4737ad62995d99c0766c8c121d11a17afb73b709456c35f` |
| `Sources/PagingPrototypeApp/AppFolderAssignmentMenuController.swift` | `f4328a9dd4ada686bd283d86a07dbff2fd1c4dbb310286f4cb090d8d938409d3` |
| `Sources/PagingPrototypeApp/AppContextMenuController.swift` | `bf02e696932204bc9ecf1fa97b61c841bb8f0c4243ea967d777968cdd23b5594` |
| `Sources/PagingPrototypeApp/AppDelegate.swift` | `2a0c183f9172a2b97cf40fcf7d13b1d6b53cd9a0960e3ad48cfa0bd76fcd2294` |
| `Sources/AppGridUI/AppGridSearchPresentationController.swift` | `361beac3483c812c227ca3bed4dc27c90ee5124550f2a6736217569082377e47` |
| `Sources/AppGridUI/LayoutDomain/VisibleWorkspaceProjection.swift` | `f5a8a7854f6a16100beb4f8c90d1d44ac6359924fd4a2eb2ad54665ee2634527` |
| `Tests/PagingUITests/AppFolderAssignmentMenuTests.swift` | `b9adb404fdb75f47bdf63c77d623d3a2bbb657523adf86a047618c8d3a72f230` |
| `Tests/PagingUITests/FolderAssignmentAssemblyTests.swift` | `346b4a39e21adb21c2349aa41fc064a636427e4c2ca480ae0a4ad29c46a2235a` |

Next action: Main assesses and repairs the actionable findings within approved
scope, supplies final source hashes and regression evidence, then requests a
source re-review. Builds/packages do not resolve these source findings themselves.

---

## 2026-10-13 repair re-review — superseding source verdict

**SCOPED SOURCE PASS. F1–F4 are closed for the repaired source identified below.
No additional actionable finding remains within the assignment slice and its
reviewed shared integration.** This section supersedes the initial verdict for
the repaired source only. The original FAIL findings, original input hashes and
initial r1 candidate remain historical; this does not validate that old candidate.

The updated slice contract explicitly records shared bootstrap/read-only guards,
stored-reference ownership without identity migration, real member catalog tokens,
and dropping accepted-but-not-yet-enqueued work when a store is replaced. These
semantics are consistent with the inspected repairs.

### Closure evidence

| Finding | Repaired source and independent assessment | Relevant regression source |
| --- | --- | --- |
| F1 | `Sources/PagingPrototypeApp/AppDelegate.swift:773-775`, `794-795`, `1820-1824`: drag startup and final commit share readiness, blocking restore and layout-store protection. The gate does not treat the committing drag itself as forbidden. Existing thresholded click fallback remains reachable when drag startup is denied. The restore task still rejects cancelled/superseded results at `1712-1713`. | `Tests/PagingUITests/FolderAssignmentAssemblyTests.swift:277-314`: suspended bootstrap, click fallback, rejected commit, saved-layout restoration and protection raised after press. `Tests/PagingUITests/AppManagementAssemblyTests.swift:103-123` correctly changes the old late-load expectation: unsafe preload organization is rejected, allowing saved layout to restore. |
| F2 | `Sources/AppGridUI/LayoutDomain/WorkspaceAppReferenceResolver.swift:18-69` indexes stored references and uses existing bundle/path matching without migrating them. `VisibleWorkspaceProjection.swift:88-90`, `130-133` excludes already represented records from the tail. `AppFolderAssignmentMenuController.swift:19-20`, `115-116`, `182`, `207` uses stored ownership for policy and binding. `AppDelegate.swift:1688-1693`, `DragSession/DragLogicalIndexMapper.swift:26-33`, `66-70`, and `DragUI/DragUISessionCoordinator.swift:627-633` align cached geometry and drag source with the stored reference. | `Tests/AppGridUITests/WorkspaceAppReferenceResolverTests.swift` contains 13 resolver/projection regressions. `Tests/PagingUITests/FolderAssignmentAssemblyTests.swift:403-436` exercises menu selectors through the real owner, retaining the path reference and latent survivor with one visible occurrence. `Tests/AppGridUITests/AppManagementDragVisualTests.swift:107-147` checks coordinator drag source/commit and canonical member frame mapping. |
| F3 | `Sources/PagingPrototypeApp/AppFolderAssignmentMenuController.swift:70`, `197-209` supplies a synchronous validator retaining a binding whose cell is weak. `AppDelegate.swift:1806-1808`, `1841`, `1851-1859` invokes it before and after cancellation, alongside owner revision/layout/hidden/path checks. Folder close now follows final validation. A rejected operation does not close the member overlay on its own. Settling remains allowed; an active physical drag remains rejected without cancellation. | `Tests/PagingUITests/FolderAssignmentAssemblyTests.swift:340-382` dispatches actual selectors using a rendered top-level cell and an actual overlay member. A same-revision cancellation callback clears the rendered binding and produces zero enqueue; a staged revision change rejects while preserving the open overlay. The new-catalog cancellation and active-drag tests remain in the suite. |
| F4 | `Sources/PagingPrototypeApp/AppDelegate.swift:854-861` captures the intended store and generation at commit, rejects superseded/teardown work before enqueue, and retains the separate post-await state-feedback guard. An already in-flight request keeps its captured original store. No earlier layout is routed into the replacement store. | `Tests/PagingUITests/FolderAssignmentAssemblyTests.swift:316-329` accepts a healthy commit and replaces the store in the same actor turn without suspension; neither store receives the superseded queued write, and the replacement's protection state remains authoritative. |

Abbreviated `AppDelegate.swift` and `AppFolderAssignmentMenuController.swift`
refer to `Sources/PagingPrototypeApp/`. `VisibleWorkspaceProjection.swift` refers
to `Sources/AppGridUI/LayoutDomain/`; `DragSession/` and `DragUI/` are under
`Sources/AppGridUI/`.

### Additional real member revision repair

`Sources/AppGridUI/FolderOverlayView.swift:318-334` accepts and remembers the
catalog revision, and includes it in configuration idempotence.
`FolderOverlayView.swift:685-695` uses that revision for member binding and page
identity; visual resume rebinds through the same token function at `738-745`.
`Sources/PagingPrototypeApp/AppDelegate.swift:1341-1344` supplies the actual served
revision. Thus the real member submenu no longer fails its initial catalog-token
guard because of a hard-coded zero revision.

`Tests/PagingUITests/FolderAssignmentAssemblyTests.swift:134-144` now obtains
`folderOverlay.memberCell(at: 0)`, asserts revision 7, creates the organization
submenu and invokes its real menu action through the owner. The source and final
log support the successful member move-out and overlay close; this is stronger
than the initial synthetic standalone-cell success fixture. The rejection test
also uses an actual overlay member.

### Verified test evidence and remaining acceptance bounds

- Independently read current Main-produced
  `.build/verification/20261013/folder-assignment/full-r2.log`: **1817 XCTest tests,
  0 failures**, completed `2026-10-13 18:30:34.515 JST`, `28.711` seconds test duration.
- Independently read
  `.build/verification/20261013/folder-assignment/reviewer-repairs-r3.log`:
  **101 tests, 0 failures**, completed `18:29:16.569`, `0.668` seconds test duration.
- The full log explicitly reports the repaired bootstrap, same-revision rendered
  cell cancellation, member success, rejected-overlay preservation, queued-store
  replacement, path menu and added drag regressions as executed and passed.
- The added path drag test calls the actual coordinator's
  `pointerDown`/`pointerDragged`/`pointerUp` and inspects its commit callback. The
  added member test checks canonical frame identity/index mapping; it does not
  execute a physical member drag. Neither test is real-device GUI acceptance.
- This reviewer ran no tests/builds/GUI and wrote only this report. Main states
  no implementation changes followed the final full run; the current hashes below
  bind this source verdict. Core owner/menu/overlay hashes were stable across the
  final review reads. The log itself does not embed a complete source manifest.
- Candidate r2 packaging, executable/source-manifest correspondence, Debug/Release,
  real context menus, keyboard/restart, physical paging and performance remain
  separate gates. No install, signing, notarization or full-parity PASS is implied.
- The known real title-editor rename-persistence gap remains a separate full-goal
  residual. Its original report entry is retained; assignment repairs do not close it.

### Re-reviewed source hashes

| Path | SHA-256 |
| --- | --- |
| `Docs/LAUNCHBETTER_FOLDER_ASSIGNMENT_SLICE.md` | `b3edf8a86b6f9b9464b8284d7e468462911484a68adb5360adb495463b4e7f88` |
| `Sources/PagingPrototypeApp/AppFolderAssignmentMenuController.swift` | `d08b587e2dc2cec31c394fce9d3049b90c6961cb3c510620830bbda20ff69461` |
| `Sources/PagingPrototypeApp/AppContextMenuController.swift` | `bf02e696932204bc9ecf1fa97b61c841bb8f0c4243ea967d777968cdd23b5594` |
| `Sources/PagingPrototypeApp/AppDelegate.swift` | `ed72bccae73dd8cf8d2df8b305b20bb830ab1e8525248cc0c80af9322eb2b03b` |
| `Sources/AppGridUI/AppGridSearchPresentationController.swift` | `361beac3483c812c227ca3bed4dc27c90ee5124550f2a6736217569082377e47` |
| `Sources/AppGridUI/LayoutDomain/WorkspaceAppReferenceResolver.swift` | `51642c0ae03fa61713a7685c5e177ed5cc85960404c4b6ba3c892df86566ea8e` |
| `Sources/AppGridUI/LayoutDomain/VisibleWorkspaceProjection.swift` | `caf0ca1cc15ab4a257da9a3957b1eb1615bb63c78101f3906276eca21faee9a6` |
| `Sources/AppGridUI/DragSession/DragLogicalIndexMapper.swift` | `4bd0d35a768e31ac4913af268cf483ea48272b0cb9b56c150735ceedbbd1a4c6` |
| `Sources/AppGridUI/DragUI/DragUISessionCoordinator.swift` | `57a141f2cca1289410e6caf9d438725d66944e980ddd12901a6fca23d8ef2667` |
| `Sources/AppGridUI/FolderOverlayView.swift` | `eff256fda52fc729e819d24a99830ba00d336c3bb5725c4e99469e8e288c0d26` |
| `Tests/PagingUITests/AppFolderAssignmentMenuTests.swift` | `81c4673d0f2d479a2852ad6e145a56327bd1bb401180fc3e0bae437289c09e94` |
| `Tests/PagingUITests/FolderAssignmentAssemblyTests.swift` | `83d14cdfcde5fb5388aff2ced84ff8527c1f2295df099f667666f01556261791` |
| `Tests/AppGridUITests/WorkspaceAppReferenceResolverTests.swift` | `ea50c217f53fffd1fde6d41bc02f58c8d0dec18a14ebe9c6c751f4237dbc2963` |
| `Tests/AppGridUITests/AppManagementDragVisualTests.swift` | `f63804ae1b818930ac0323e027161dba858b9f7fafecf7498968a1adad5c844a` |
| `Tests/PagingUITests/AppManagementAssemblyTests.swift` | `94864ecf6821c9a23fe3b80389088c74a9776f5c97951c6ab4cc5abfb2ba4995` |

Next action: Main may proceed with separately controlled r2 build/package and
manifest verification. Any material source change requires renewed source/test
evidence; this scoped PASS does not transfer to an unidentified executable.
