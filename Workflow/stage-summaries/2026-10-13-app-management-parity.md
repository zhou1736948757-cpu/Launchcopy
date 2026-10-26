# App Management Parity — Execution

Objective: move the full LaunchBetter-on-Launchcopy goal forward with independent
hidden-app/alias/search/action functionality. The preceding turn was progress:
implemented appearance controls, added32 tests, reviewed and preserved a candidate.

Baseline: current dirty `319b8cc` tree;1622 tests/0 failures at16:34:13 JST and
appearance candidate SHA146246c7a7c2e985225b6f35ff536700ba9a871f4f8414d60e12fe8f72a4214e.
Full parity and latest-candidate GUI/performance gates remain incomplete.

Discovery: canonical catalog/presentation are already separated; persistent app
references and latent-layout projection exist. AppDelegate enqueues layout writes
but has no observed startup load hook. Hiding introduces gaps between visible and
logical drag indices, requiring stable-identity mapping rather than filtered layouts.

Contract: `Docs/LAUNCHBETTER_APP_MANAGEMENT_SLICE.md`, refining the approved scope.
Main implements canonical/presentation/layout integration and persistence/UI;
two disjoint Workers implement pure metadata and context consumer plumbing.
Maximum3 agents including Main; serialized SwiftPM; no original reference code copied.

Next: implement disjoint pieces, integrate without resetting canonical/layout data,
verify actual production callbacks, independently review, build and package uniquely.
Known GUI lock is not a reason to stop available code work or shrink the full goal.

## Integration checkpoint (17:27 JST)

- Canonical catalog/layout are distinct from managed visible presentation. Added
  metadata projection, same-revision reload, original-and-alias search and hidden
  launch rejection. Hiding keeps one-visible-member folders and latent references.
- Canonical drag indices are mapped by identity and cached once per layout/catalog/
  composition generation; no full-layout scan on each pointer event. Async layout
  bootstrap preserves first-scan pending data and rejects canceled/late results.
- Private schema1 metadata store/coordinator, settings controls and safe context
  actions implemented. Future schemas disable mutation and remain preserved.
- First focused integration:77 tests/2 failures, both synthetic owner-retention
  fixture assumptions. Fixed test with autoreleasepool and no icon task; r2 focused
  model/consumer test run:31/0. Provider/search projection run:8/0.
- Later assembly compile found optional chaining misuse in Main's new test (fixed),
  then an incomplete worker fixture constructor. Workers are still writing tests;
  no final integrated test/build/reviewer/GUI PASS is claimed yet.
- Current workers own disjoint regression files only; production edits belong to
  Main. Independent source reviewer follows the completed integration run.

## Review-driven repairs (17:46 JST)

Initial Reviewer FAIL identified3 P2s: indicator used logical indices as displayed
indices; startup journal always chose validA instead of newestA/B; visually
dissolved latent group member lacked canonical drag ownership. All3 have source
repairs and new regressions; independent follow-up remains pending.

- Indicator reverse-maps mapped logical indices and retains pointer-aware cross-row
  geometry. Tests assert real bar rectangles for top/member/move-out and hidden gaps.
- Journal chooses greater writeGeneration; tieA; protects future/over-limit either
  slot before selection.12 new tests passed, including fresh-store two-save restore.
- Displayed latent singleton proxies its persisted group for top-level drag/target,
  preserving missing references. Actual coordinator down/drag/up and center-drop
  tests passed. App clicks still launch the displayed app; metadata-only singleton
  remains a normal visible folder per the contract.
- Restored old current-page clamp. Aligned empty-unavailable folder test to existing
  ADR-009 projection (hidden, expected references preserved); added valid two-member
  catalog-return test. Updated move-out fixture's actual right margin and included
  its previously omitted installed app, avoiding an invalid visible/logical tail.
- Indexed canonical projection removes repeated linear catalog/folder resolutions,
  preserving first-match bundle/path semantics; direct regression added. Same-revision
  application no longer redundantly calls unconditional setPageCount after reload.
- Focused integrated101/0 then regression124/0; latest reviewer-repair subset99/0.
  Full rerun is in progress; initial full1723/5 failure log is retained.
- Desktop recheck through CUA still reports locked Mac. No unlock bypass/security
  changes, app launch, GUI acceptance or physical performance PASS is claimed.

## Candidate checkpoint (17:49 JST)

- Full rerun: **1742 tests/0 failures**,26.946s,17:46:39 JST.
  Log: `.build/verification/20261013/app-management/full-r2.log`.
  Baseline1622 plus120 new tests. Failed intermediate runs remain archived.
- Debug build and Release package: exit0. Existing `diagBackend` non-Sendable
  capture warning remains; do not claim zero compiler warnings.
- `git diff --check`: pass.289 source/test/package files individually hashed in
  `.build/verification/20261013/app-management/source-files.sha256`.
- Candidate: `.build/candidates/app-management-rc-20261013-r1/Launchcopy.app`.
  Release executable SHA-256:
  `afdcd48982d81a30c395923b601bb4916be7a5f56ee83d5e6d0def3da2594ae6`.
  Manifest beside app; Info.plist lint passed. Linker-ad-hoc signature, no team,
  unsealed resources; not distribution-signed/notarized. No install/launch/commit.
- Reviewer follow-up requested against final frozen source and attributed logs;
  current report's historical initial FAIL must not be presented as final PASS.

Final independent review: **scoped source PASS**, R1–R3 repairs observed, no new
blocking findings. Reviewer inspected Main's1742/0 log but did not execute tests or
builds. `Docs/APP_MANAGEMENT_SLICE_REVIEW.md` preserves initial FAIL and follow-up.
Main's completed build/package evidence above remains separate from review and
GUI/physical acceptance. All delegated agents are closed; full goal stays active.

## Next live acceptance (only after unlocked CUA session)

Prefer Desktop2 or `--ui-test-windowed` ordinary test window. Do not terminate the
existing app, overwrite an installed version, auto-enable login/gestures, alter
security settings, or use another capture backend to circumvent CUA lock.

1. Check no top page-number text and safe-area search placement; appearance labels
   and blur0/18/60 Apply/reopen. The preceding slice's physical gates remain pending.
2. Real settings Applications controls: hide selected app; restore individually/all;
   alias display and search original+alias; clearing search restores saved order.
3. Folder with two members: hide one, keep same folder; hide both, temporarily absent;
   restore members and recover original group/order. Confirm no layout reset.
4. Right-click on top app and folder member: open, alias/reset, hide, Finder reveal;
   cancel alias sheet; no accidental app launch or blank-hide while using controls.
5. Drag with leading/interior hidden gaps: indicator matches drop and resulting order.
   Latent singleton reorder moves its persisted group, preserving missing member;
   drop onto singleton joins that group; click still launches its displayed app.
6. Restart the same candidate when explicitly authorized to stop/relaunch it; verify
   metadata/order recovery and newer journal slot. Tests do not substitute for this.
7. Matched real trackpad performance AB for paging/input/startup after management and
   appearance migration. Existing long-tail causality unresolved; no120Hz claim.

Record only neutral outcomes/counts and candidate hash. Do not copy real app names,
bundle IDs, paths or alias text into diagnostics/reports/screenshots. Entire migration
is not complete: see the full parity ledger for navigation, appearance, sources,
watching, localization and optional Library work.
