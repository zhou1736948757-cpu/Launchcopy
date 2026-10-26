# Folder Assignment — Execution Checkpoint

Previous goal turn: progress, not a wait/no-progress turn. App-management features,
three independent source-review repairs,1742/0 full tests and uniquely hashed
candidate were completed. GUI remains locked; full parity is not complete.

Baseline: dirty319b8cc; full1742/0 at17:46:39 JST. App-management candidate SHA
afdcd48982d81a30c395923b601bb4916be7a5f56ee83d5e6d0def3da2594ae6.
Source/test manifest289 files in prior verification directory. Preserve all changes.

Current approved requirement: safe context-menu folder assignment. Contract in
Docs/LAUNCHBETTER_FOLDER_ASSIGNMENT_SLICE.md; no new capacity/gesture model.
Main: shared application commit/search/protection integration, tests and docs.
Worker: standalone folder-assignment submenu/policy/tests, no overlapping writes.
Reviewer after stable integration. Main owns all SwiftPM resources; max3 including
Main, no formal historical chef workflow. No reference implementation inputs.

Direct-page navigation proposal is separately recorded and awaits confirmation;
do not alter PagingCore for it yet. Continue approved work while user is away.

## Integration checkpoint (18:11 JST)

- Standalone assignment submenu/policy adds existing destinations and member move-out;
  canonical IDs/full snapshot bindings, duplicate-title handling, hidden/latent groups,
  readonly and stale protection.36 test definitions delivered by Worker, not Worker-run.
- Shared app commit extracted from drag callback; search commit replays active query
  before one surface/focus update and one async persistence enqueue. Main aligns
  search capacity with surface. Metadata future schema does not gate layout-only menus.
- Startup protection is cached with an explicit pending/readonly state and generation;
  canceled or superseded loads cannot unlock a newer store. No menu/frame disk queries.
- Member removal closes an open overlay by comparing identities, not logical count
  to filtered visible count. This repairs hidden-member count masking a removal.
- Initial focused78/0; integration fixture accidentally stayed in tracking due to
  the existing momentum grace phase, and an overly strict currentSession gate also
  rejected settling (the core retains that record after input ownership ends).
  Corrected explicit finishGesture fixture and state-based gate; latest focused53/0.
- Pending catalog delivered during cancel now demonstrably rejects old transaction,
  with zero enqueue. Active physical drag is rejected without canceling that drag.
  Full-suite run in progress; source Reviewer evaluating final integrated changes.
- Newly observed full-goal gap: title editor currently never mounts in the overlay
  and commitFolderTitle does not invoke persisted rename. Explicitly added to parity
  ledger; do not count historical model tests as successful application rename.

## Full-test checkpoint

Full suite: **1795/0**,22.433s,18:12:13 JST; log
`.build/verification/20261013/folder-assignment/full-r1.log`.
Baseline1742 plus53 new tests (36 submenu/policy,8 search commit,9 owner assembly).
No PagingCore/physics changes. Both Workers closed after direct file review;
independent Reviewer follows frozen source. Debug/Release package is in progress;
do not claim reviewed candidate/live acceptance yet.

Next implementation: real folder-title editor entry/mount/cancel lifecycle and
persisted rename via shared commit, keeping member order/identity/query and title
privacy. Specific page-dot proposal remains pending response. Full migration and
physical gates remain incomplete; this is progress, not a genuine locked-GUI impasse.

## Independent review and repair checkpoint (18:28 JST)

Initial source review FAIL: F1 bootstrap/protection bypass by shared drag commit;
F2 path-to-bundle duplicate representation; F3 weak source binding lost after
cancel and premature folder close; F4 enqueue could target replacement store.
1795/0 did not establish those missing cases. Initial r1 candidate is preserved,
not source-approved: SHA b950c64bcd0fdfa6a9c7af64a778cc6684a9a5b9f5d20d3cb6d69f2607b8db1e.

Repairs: common readiness at drag-start/final transaction; click fallback retained.
Stored-reference resolver and matching-based tail, used by menu policy and cached
drag source/targets without migrating latent refs. Weak validation closure crosses
the owner boundary, is rechecked after cancellation before folder UI cleanup.
Persistence captures intended store/generation and checks before AND after enqueue.
Superseded queued writes are discarded, never sent to another store.

New actual-member test also found overlay bindings hardcoded catalogRevision0,
which had disabled real member context menus despite synthetic menu tests. Added
explicit configure revision default0 (legacy fixture compatibility), passed actual
served revision by owner, and included revision in idempotence/token construction.
Normal member success and rejected-member preservation now use real overlay cells.

New tests cover bootstrap click/drag, protection-after-press, store replacement,
same-revision rendered cell clear during cancellation, rejected member UI, path
member real menu moves and actual canonical-path drag. Replaced historical preload
drag-wins fixture with rejection/restore expectation: unsafe organization is now
prevented before bootstrap, rather than discarding saved hidden/missing references.

Latest repair subset99/0; further path-drag tests/final full rerun in progress.
Reviewer follow-up requested; no repair candidate PASS until source review and
final integrated evidence. No live GUI or physical performance evidence added.

## Final r2 source/build checkpoint

- Independent **scoped SOURCE PASS**: F1–F4 closed, real member catalog revision
  wiring observed; original FAIL retained. Reviewer read logs, did not run tests.
- Full1817/0 at18:30:34 JST,28.711s (`full-r2.log`); focused101/0 (`reviewer-repairs-r3.log`).
  Baseline1742 plus75 tests. Failed intermediate captures are retained as history.
- Debug build and Release r2 package exited0. Existing diagBackend non-Sendable
  capture warning remains; not a zero-warning build.
- Candidate: `.build/candidates/folder-assignment-rc-20261013-r2/Launchcopy.app`.
  Executable SHA-256:
  `7e6af7200c574a8b536b5f4aad183b5701b97de80120636ce1a76b07560d0706`.
  Package manifest beside app, Info.plist lint OK.295 source/test/package file
  hashes in `source-files-r2.sha256`, all rechecked OK (`source-check-r2.log`).
  Verification paths relative to `.build/verification/20261013/folder-assignment/`.
- No install/sign/notarize/commit/process stop/app launch. Candidate remains
  linker-ad-hoc, not distribution signed. Latest code GUI and physical gates pending
  prior verified CUA lock; no repeated lock probing during code progress.
- All delegated agents closed. Full goal remains active; no full parity claim.

Next: `Docs/LAUNCHBETTER_FOLDER_RENAME_REPAIR_PLAN.md` for real edit/persist wiring,
immediate-Quit accepted-write durability and separate hidden/alias identity-change
follow-up. Direct-navigation specific proposal awaiting user decision; other
appearance/settings/source watching/optional Library remain on the full ledger.
