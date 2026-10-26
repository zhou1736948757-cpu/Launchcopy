# App Management Parity Slice — Independent Source Review

Date: 2026-10-13
Reviewer: independent source Reviewer, read-only except this report
Contract: `Docs/LAUNCHBETTER_APP_MANAGEMENT_SLICE.md`

Current result: **scoped source PASS** after observing R1-R3 repairs.
The final follow-up below supersedes the historical FAIL checkpoints.

## Initial result: FAIL

Three high-confidence P2 source findings remain at this checkpoint. Main owns
repairs and execution evidence; no full-suite or runtime PASS is asserted.

### R1 — P2: Logical insertion indices are rendered as visible indices

- Exact location: `Sources/AppGridUI/DragUI/DragUIVisuals.swift:246-251`;
  callers at `:167-171` and `:224-228`.
- Evidence: classification now emits canonical logical indices, but
  `localInsertionIndex` only subtracts `pageIndex * itemsPerPage`; it never
  reads `DragItemFrame.logicalIndex`. For visible frames at canonical indices
  `[1, 3, 5]`, left-half hit on the first item yields insertion `1`, which the
  visual renders between visible items 0 and 1 rather than before item 0.
  Canonical index `3` becomes a visible tail slot rather than the gap before
  visible item 1. Later pages can clamp to the wrong page edge. Member frames
  lack pagination annotations and pass the logical number through unchanged.
- Likely root cause: the new canonical-index contract reached classification
  and mutation but not the insertion-indicator consumer.
- Recommended solution: derive the visible insertion boundary from mapped
  logical frame indices, including indices immediately after a hit item and
  hidden gaps; retain the previous pagination fallback only for unmapped frames.
  Preserve pointer-based cross-row anchoring.
- Affected scope: top-level insertion, folder-member reorder, move-out indicator.
- Regression risks: leading/interior/trailing hidden references, later pages,
  both hit sides, gaps, cross-row anchoring, and unmapped legacy geometry.
- Required regression: assert indicator rectangles against displayed frames,
  not merely classifier intents or committed layouts.
- Confidence: high; deterministic source trace, no GUI claim.

### R2 — P2: Startup restore selects an older valid journal slot

- Exact location: `Sources/AppGridUI/LayoutStore/LayoutStoreActor.swift:201-204`;
  new production consumer: `Sources/PagingPrototypeApp/AppDelegate.swift:1682-1694`.
- Evidence: the load switch matches `(.valid(let decoded), _)` before any
  two-valid-slot comparison. Normal persistence writes generation 1 to A,
  generation 2 to B (`LayoutStoreActor.swift:379-385`); a fresh store restores
  generation 1 whenever both slots validate. The new startup hook installs
  that stale layout. This dependency defect predates the slice, but the new
  hook exposes it to startup acceptance.
- Likely root cause: A is treated as a permanent primary, although the writer
  rotates between A and B and `writeGeneration` defines journal recency.
- Recommended solution: select the higher `writeGeneration` when both slots
  validate, using a deterministic tie rule. Preserve future/over-limit protection
  and corrupt-slot backup behavior.
- Affected scope: restored order, folder membership and subsequent drag baseline.
- Regression risks: newer A, newer B, equal generations, one corrupt/absent slot,
  future-version protection in either slot.
- Required regression: two completed saves followed by a fresh store load,
  plus explicit two-valid-slot fixtures in both generation orders.
- Confidence: high; source and existing journal rotation establish the sequence.

### R3 — P2: A visually dissolved latent folder member has no valid drag mapping

- Exact locations: `Sources/AppGridUI/DragSession/DragLogicalIndexMapper.swift:23-32`;
  `Sources/AppGridUI/DragUI/DragUISessionCoordinator.swift:604-618`;
  projection: `Sources/AppGridUI/LayoutDomain/VisibleWorkspaceProjection.swift:126-132`;
  canonical source check: `Sources/AppGridUI/DragSession/DragSessionController.swift:263-268`.
- Evidence: a saved folder with two logical members and only one catalog-available
  member projects that member as a top-level app. The expected layout still has
  a `.folder` entry and that app only in the member list. `topLevel` mapping has
  no app key for it and omits its frame. Pointer-down resolves it as a
  `.topLevelApp`, whose source is absent from the canonical top-level order;
  the controller rejects the drag and falls back to click-only handling.
- Likely root cause: runtime visual dissolution changes the displayed scope,
  while source resolution and geometry mapping assume displayed and persistent
  scopes are identical except for filtered gaps.
- Recommended solution: preserve or explicitly translate the latent member's
  canonical folder ownership in both source and destination geometry. Do not
  drop a legitimately displayed frame or disable its drag as the remedy.
- Affected scope: restored folders with temporarily missing apps; drops onto or
  drags from their visible singleton. Hidden-only one-member folders are already
  retained correctly and must remain so.
- Regression risks: latent member return, hidden member restoration, mixed order,
  move-out, and preservation of every saved member reference.
- Required regression: saved two-member folder + one unavailable member, then
  verify actual source resolution, mapped frame participation and committed layout.
- Confidence: high; deterministic mismatch between projection and canonical scope.

## Repairs already observed in source

- `Sources/AppGridUI/DragSession/DropIntent.swift:250-263`: mapped hit insertion uses the hit frame's own
  logical index, with +1 for its right half. Hidden successors are not skipped.
  `DragLogicalIndexMapperTests.testRightHalfInsertionDoesNotJumpOverHiddenSuccessorReferences`
  covers top-level and member mutation through the classifier.
- `AppDelegate.swift:955-965`: same-revision reload and revision refresh are
  mutually exclusive, and `setPageCount` is conditional. The prior unconditional
  second presentation rebind is removed.
- `AppContextMenuController.swift:39-40, 50, 58-64`: creation checks the captured
  catalog revision; actions revalidate the complete binding token, live revision,
  canonical URL, hidden policy and read-only state. Read-only mutations are also
  disabled in the menu. Test source covers retained stale menus and direct action
  delivery after read-only transition.

## Additional source observations

- Metadata keys use the existing `PersistentAppReference.comparisonKey`.
  Alias normalization, 128-grapheme limit, control rejection and original-name
  matching are implemented without altering canonical identities, URLs or icons.
- Provider retains canonical catalog/organization and expected layout. Management
  projection filters visible membership after canonical projection; hiding to one
  member retains the folder, and hiding all does not delete saved references.
  Latest staged preferences compose with a pending first scan and expected layout.
- `beginLayoutRestore` rejects cancelled loads, final teardown and a newer committed
  user layout. Synthetic load-gate tests cover restore-before-scan, superseded load
  and late load after drag; these tests do not address R2's real journal selection.
- The preference coordinator saves before applying and avoids equal healthy writes.
  Store load has no write side effect; recognized future schemas reject overwrites;
  corrupt payload replacement occurs only through an explicit save operation.
- Settings controls target canonical records, include hidden entries and do not
  request icons. Production callbacks re-resolve current app identities.
- Menu Binding holds the cell weakly; page/overlay factories and production menu
  callbacks capture owners weakly. The reported retained-cell autoreleasepool test
  correction is consistent with this ownership structure; no cell retain cycle was
  identified in the reviewed source.
- Launch rejects hidden/stale/missing apps and checks the current file; Finder reveal
  checks the file and uses the public Workspace API. Alias-sheet confirmation checks
  the captured revision and hidden policy before current-identity resolution.
- No metadata keys or alias text enter the reviewed diagnostics/telemetry paths.
  Presentation telemetry contains revision and anonymous timing only. No real saved
  metadata was opened or reproduced in this report.
- Content and drag-geometry paths use memory only; canonical mapping is cached by
  catalog/layout/presentation generations. Metadata apply does not invoke scanning
  or layout persistence. This is structural evidence, not measured performance.

## Compatibility and execution gates

Main reported a 1,723-test full-suite run with five assertion failures, including
out-of-range current-page clamping, an empty latent-folder expectation, and a
move-out integration intent failure. Repairs/investigation are in progress; none
of these is silently declared resolved here.

For zero catalog-available folder members, existing `VisibleWorkspaceProjection`
and ADR-009 latent-reference semantics hide the folder while retaining expected
layout. The old direct-commit test instead expects a visible empty placeholder.
Recommend explicitly document this alignment and replace that expectation with
invisible + saved-reference-preservation + member-return assertions. Do not remove
or weaken the test without recording the semantic reason. One-member latent
projection remains independently subject to R3.

Reviewer inspected source and test definitions only. No builds, tests, GUI,
reference implementation sources, installs, commits or process stops were run.
Only this report was written. Main-reported test counts are attributed evidence,
not Reviewer execution. Final integrated evidence and observed source repairs are
required before a scoped source PASS. GUI, physical smoothness and full parity
acceptance remain separate.

## Follow-up source review — Main integration repairs

- Observed current-page clamping at
  `Sources/AppGridUI/AppGridUIPageContentProvider.swift:320-326`: validates positive
  capacity and clamps against the old visible page count before staging layout
  and capturing the old anchor. This restores the prior direct-commit behavior.
- Reviewed `AppGridUIPageContentProviderApplyCommittedLayoutTests.swift:112-135`: the
  zero-available-member expectation is explicitly changed to invisible and asserts
  unchanged expected layout. Its fixture remains invalid (single-member folder
  and duplicate missing reference); it cannot establish valid saved-folder recovery.
  Add a valid two-member, both-unavailable fixture and catalog-return assertions.
  The reason for the expectation change is consistent with existing ADR-009
  projection semantics; this is not evidence that R3 has been repaired.
- Reviewed `Tests/PagingUITests/DragCommitIntegrationTests.swift:781`: actual surface
  right margin replaces the old panel-relative point. Appending previously
  unorchestrated catalog apps makes the old point overlap a real target. The
  integration test retains its move-out intent, transient-proxy and logical
  dissolution assertions; choosing the actual outer margin is a justified fixture
  correction rather than weakening those behaviors.
- Reviewed `Sources/AppGridUI/LayoutDomain/VisibleWorkspaceProjection.swift:74-87,
  104-116`: first-match dictionaries preserve bundle-ID equality and normalized
  canonical-path matching, even for a path reference to an app that also has a
  bundle ID. First folder-ID match is retained. This removes repeated catalog
  and folder scans from the cold projection path without introducing I/O or
  metadata output. No semantic regression identified in this optimization.

Result at this follow-up checkpoint: FAIL; R1, R2 and R3 remain unmodified in the
observed source. Execution evidence is still pending from Main.

## Repairs and final result — scoped source PASS

Final follow-up: 2026-10-13, after Main's 17:46:39 JST integrated test run.
All three findings are resolved in the inspected source. No additional actionable
blocking finding was identified in the reviewed app-management slice. Earlier
FAIL sections are historical evidence, not the current verdict.

### R1 — resolved

`Sources/AppGridUI/DragUI/DragUIVisuals.swift:246-252` now maps canonical insertion
indices to the first displayed frame whose logical index is at or beyond the
boundary, or to the displayed tail. All mapped frames take this route before the
legacy pagination fallback. Thus before-hit, after-hit and several hidden gaps
can correctly share the same displayed boundary. Existing pointer-selected
cross-row anchoring remains downstream and unchanged.

`Tests/AppGridUITests/AppManagementDragVisualTests.swift:9-50` checks actual bar
rectangles for hidden gaps, misleading outer-page annotations, member frames,
move-out and both cross-row pointer anchors. Existing unmapped geometry retains
its prior path. This closes the logical/visible index consumer mismatch.

### R2 — resolved

`Sources/AppGridUI/LayoutStore/LayoutStoreActor.swift:201-206` handles two valid
slots before the single-valid cases, selecting higher `writeGeneration`, with A
winning an equal-generation tie. It initializes `lastPersistedGeneration` from
the selected slot. Future-version and over-limit checks still precede selection;
corrupt/absent-slot behavior remains intact.

`Tests/AppGridUITests/LayoutStoreJournalRecencyTests.swift:17-112` provides 12
regressions: a fresh store after two completed saves, newer A/B even when layout
generation orders disagree, tie A, future and over-limit protection in either
slot through attempted enqueue/flush, corrupt counterpart preservation and
absent counterpart handling. These tests address the journal defect directly,
rather than only feeding a synthetic layout result to AppDelegate.

### R3 — resolved under the explicit proxy ownership contract

The updated contract explicitly defines the visually dissolved singleton as a
proxy for its persisted group during top-level drag, while clicking launches the
displayed app. This decision preserves latent membership and uses the existing
folder reorder/add operations; it does not silently dissolve a saved group.

- `Sources/AppGridUI/DragSession/DragLogicalIndexMapper.swift:25-44` translates a
  displayed member to the owning persisted folder identity and canonical index.
  Translation is suppressed when an actual frame already represents that folder,
  preserving the wrong-scope rejection regression and avoiding a duplicate proxy.
- `Sources/AppGridUI/DragUI/DragUISessionCoordinator.swift:617-624` resolves the
  displayed app's source to `.topLevelFolder` when its persistent owner occupies
  the top level. The transaction therefore uses top-level scope and a valid
  canonical source. The click event still dispatches the original app cell.
- Classifier geometry now sees that proxy as the persisted folder; a drop onto it
  uses the existing folder-add mutation, retaining its missing members. Group
  reorder retains folder identity, title and complete member list.
- `Tests/AppGridUITests/AppManagementDragVisualTests.swift:52-108` exercises real
  coordinator pointer-down/drag/up source resolution and group reorder, and
  classifier-to-mutation center drop onto the proxy with missing-member preservation.

### Other follow-up checks

`Tests/AppGridUITests/AppManagementPresentationTests.swift:185-201` adds the
requested valid two-member folder with both members unavailable, then catalog
return: no visible folder while absent, unchanged expected layout, and restored
folder identity/membership after return. This supplements the historical invalid
empty-folder fixture rather than relying on it for recovery acceptance.

`AppManagementPresentationTests.swift:164-183` checks indexed projection's first
bundle match and a canonical-path reference to a bundled app. Source retains
first-match behavior and existing path normalization. The prior clamp repair,
actual-right-margin move-out fixture correction, hit-owned right-half insertion,
single presentation reload and stale/read-only menu checks remain observed.

### Evidence and limits

Reviewer read Main's log
`.build/verification/20261013/app-management/full-r2.log`; its XCTest footer records
1,742 executed tests, 0 failures, 26.946 seconds, completed at 17:46:39 JST. Main
reports no source changes since that run and a focused 99-test run with 0 failures,
including the 12 journal tests and proxy/indicator cases. The focused result is
Main-provided evidence; Reviewer did not independently execute either run.

Reviewer performed source/test-definition review and log reading only, and wrote
only `Docs/APP_MANAGEMENT_SLICE_REVIEW.md`. No build, test command, GUI, reference
implementation access, install, commit or process stop was performed. No extra
agent was dispatched by Reviewer. Production build/package verification remains
Main's next gate. Main reports the GUI session is locked; there is no current GUI
or real-device evidence. This scoped source PASS does not certify full parity,
physical smoothness, GUI acceptance or measured performance. Structural no-I/O
observations remain separate from those gates.
