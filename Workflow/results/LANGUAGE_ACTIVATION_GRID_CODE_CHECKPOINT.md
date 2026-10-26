# Language activation/grid/pager code checkpoint

Date: 2026-10-14. Status: CODE_CHECKPOINT_VALIDATED; full parity and complete language acceptance remain open.
Approved source of truth: Docs/INTERFACE_LANGUAGE_SPEC.md. No re-confirmation of languages required.

## Delivered scope

- Retained activation controls, shortcut presets/recording/validation, typed virtual-key fallback,
  login/service/readiness state render in en, zh-Hans and ja. Preserve drafts and recording state.
- Folder counts/help, title editor, inner navigation/footer, live/pooled grid pages/cells,
  renderer-created/reused pages, surface/host accessibility and page-dot meaning receive the
  displayed snapshot. User names/aliases/titles/queries stay data. Inert exits retain old text.
- Page/cell/host/surface/dot formatting is coalesced outside the frame stack, including diagnostics.
  Constructors on lazy render paths do not load localization resources.
- Real production pending-catalog callbacks are shared by runtime and tests. Catalog/pager commit
  stays synchronous; Management template/reload work moves to an epoch/owner-checked main turn.
  Actual field-editor, menu/modal, Core and teardown ownership defer/retry presentation.
- Passive refresh preserves genuinely unfinished alias drafts. Accepted Save/Clear updates the
  view's accepted mirror; rejected actions preserve drafts. Accepted hide/unhide advances the
  rollback baseline even while catalog presentation is held. No second persistence writer.

## Final executed code gates

| Gate | Evidence |
| --- | --- |
| Final focused | focused-r4.log: 81 tests/0, 2026-10-14 13:30:33.834 JST, 6.682s |
| Management/frame repair | management-frame-repair-r5.log: 77/0, 13:29:15.077 JST, 5.071s |
| Final full | full-r5.log: 2324/0, 13:31:15.031 JST, 40.459s |
| Debug | debug-r4.log: product build succeeded |
| Release/candidate | release-package-r4.log: product build 11.95s; probe build 0.12s; packaged strict validation succeeded |
| Actual app resources | 3 languages, 178 exact required keys/signatures; development fallback forbidden |
| Negative resource fixtures | Missing activation.shortcutRecord in all3 and wrong folderHelpOther signature in all3 each rejected exit1 |
| Source freeze | source-files-r5.sha256 + source-check-r5.json: all375 input fingerprints match after packaging |
| Whitespace | git diff --check exited0 |
| Independent review | Activation bounded source clear; grid review initial P2/P2-R1/P2-R2 followed by append-only final SOURCE CLEAR for repaired paths |

Current unsigned candidate: `/Users/mac/Projects/Launch_Copy/PagingPrototype/.build/candidates/language-activation-grid-rc-20261014-r4/LaunchcopyUITest.app`
Executable SHA-256: `63194604981a552d4fd5cafba908b28aabd1a559bf4ccc6d857a8b4157ab086b`
Resource-inclusive identity: adjacent CANDIDATE_MANIFEST.txt and LOCALIZATION_RESOURCES.sha256.
Main did not install/launch/sign/publish this app, control other apps, commit or clean the tree.
Recorded end-of-wave HEAD:319b8cc149a8553adfc3414abaacbe28b59d97ef (do not infer it was unchanged over older sessions).

## Failures and repairs retained as evidence

- focused-r1:58/19 assertions. Twelve new-template signature fixture omissions;
  six renderer newly-created/reused pages missed Main snapshot injection; one old-language
  recording checkbox locator. Hooks/fixtures repaired; focused-r2:58/0.
- full-r1:2318/249 assertions, mostly immediate-text expectations (207 repeated view-budget
  assertions) after approved deferred AX contract. Added bounded queue drains OUTSIDE frame
  loops; original assertions/budgets/names remain. Chinese dot fixtures now inject Chinese;
  recording locator uses its stable action. legacy-focused-r1:174/1 then caption expectation
  corrected to selected resource; full-r2:2318/0. No assertions removed to force green.
- Reviewer original P2: Management reload/templates remained on terminal-frame pending catalog
  commit; moved text-only refresh to safe next turn, with actual shipping callback tests.
- repair-r1:74/4 fixture failures; configured controller was not the static singleton.
  Actual configured owner is now preferred. repair-r2:74/3 because alias field was in hidden
  tab; fixture selects actual Management tab before native editor ownership. repair-r3:74/0;
  full-r3:2321/0. Strong assertions retained; no live GUI claim.
- Reviewer P2-R1: generic restoration revived successfully cleared alias. Dirty/accepted
  semantics and Save/Clear/Save/failure regressions added. repair-r4:76/0; full-r4:2323/0.
- Reviewer P2-R2: success then rejected inverse used stale hidden baseline while editor held
  refresh. Added local accepted mirrors and real controlled-store/coordinator/provider/native
  editor tests in BOTH directions, failed/protected inverse and release. repair-r5:77/0.
- Candidate-r1/r2/r3 are preserved but superseded. ONLY candidate-r4 matches final source.
- Existing Sendable/fixture warnings persist. No zero-warning or toolchain-causality claim.

## Honest remaining scope and next work

Complete catalog/search status mounting/semantic same-state rerender, context/assignment menus,
rename/alias/launch/Finder/save/Quit notices and app-owned alerts. Do not treat missing features
as translated. Library and adjustable capacity contracts remain independently unconfirmed.

Exact-candidate displayed UI/wrapping, VoiceOver, actual IME/menu/picker interactions, isolated
fresh-process preference restart and physical/frame-cost AB remain unexecuted. No app has been
launched by this wave; no installation or human acceptance. Keep non-topmost/isolated runner
and user Desktop2 boundary. Existing >25ms CAUSALITY_UNRESOLVED and120Hz hardware gate remain;
no physical paging parameters, Timer0ms production setting or PagingCore algorithms changed.
This is not a diagnosis or fix of the historical hitch.
