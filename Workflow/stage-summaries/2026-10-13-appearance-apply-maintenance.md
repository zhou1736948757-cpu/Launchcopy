# Appearance Equal-Apply Persistence — Bounded Maintenance

Status: CODE_VALIDATED_GUI_PENDING, 2026-10-13.

## Objective / authority

Repair conditional P2 F1 from the read-only appearance survey: storage corruption,
removal or a different healthy payload after coordinator initialization currently
lets equal Apply return saved without repairing current persistence. This is
maintenance of the already-approved explicit save/no-op/future protection contract,
NOT implementation of proposed icon/type/schema2/capacity settings.

## Source baseline / confirmed facts

PageDots maintenance2094/0 and Debug/Release r3 assembled;334 fingerprints matched
before this task. Its source-only reviewer is separate and still pending. Existing
appearance schema1/default48pt/11pt/5x7 and all physical parameters remain intact.
Survey F1 is control-flow/source evidence only until new failing tests reproduce.

## Ownership and constraints

Main retains documentation/critical integration and sole Swift execution.
One worker owns ONLY Sources/PagingPrototypeApp/AppearancePreferences.swift and
Tests/PagingUITests/AppearancePreferencesTests.swift. PageDots reviewer writes only
its own report. Main+2 cap; disjoint writes, no builds/tests/apps by helpers.
Do not revert any dirty files or touch reference/excluded trees or production data.
No launch/install/sign/notarize/publish/commit/process stop.

## Required behavior and verification

Read current persisted state when deciding an equal-value no-op; refuse fresh
future data byte-for-byte; save only on explicit Apply; healthy persisted matching
payload no-op; explicit corruption/removal/different-data repair even if committed
value equal. No UI apply callback when effective preferences unchanged; failures
preserve in-memory values. No automatic repair on load/settings reopen and no
schema/field/range changes. Native view Apply should report saved only when the
real store reloads the expected draft. Tests use unique synthetic suites only.
Main records red/nonzero focused/full results, independent scoped review, builds,
new candidate/source/exe hashes. Real restart/GUI/physical remain unverified.

## Current risks / next step

Multi-process synchronization/atomic UserDefaults durability is not newly promised.
Use fresh observation but preserve store-level future recheck before write. Worker
adds bounded repro tests FIRST and reports ready; Main runs red before worker edits
production source. Proposed appearance/capacity questions remain unanswered.

## Reproduction gate

Hooke published6 native-view/real unique suite tests, production hash remained
198d9f3e604359ab6ccf6b0336485f061613481edb4877115eb32a9b5e1caeca.
Initial EqualApply filter omitted failure-named method:5methods12assert failures,
red.log; corrected complete native filter6methods15assert failures at22:45:27.388
JST, red-six.log. Main authorized minimal coordinator repair after this evidence.
Existing future/no-op behavior is part of the6 tests; no test weakening permitted.
No complete repair or PASS yet. All evidence in
.build/verification/20261013/appearance-apply-maintenance/.

## Minimal repair and focused gate

Hooke repaired only coordinator current-persisted-result/no-op/health refresh;
worker closed. Source489ab91038736a6202a510e9ed4502fe3613e72435530a0e89612e927641f61b.
Schema1/field/default/ranges/store save guard unchanged. Main focused45/0 at
22:47:47.119 JST1.712s, all6 native tests pass.334 input fingerprints captured;
exactly2 source/test paths changed since r3. Full suite now running. Bernoulli
independent bounded source review pending, writes only own report. No GUI or real
process restart claim; unique suite reload is structural persistence evidence.

## Full-suite gate

2100 XCTest cases/0 failures at22:49:46.052 JST78.036s.2094 r3 baseline+6new
regressions; all existing tests retained. The test elapsed time is NOT a frame/
physical performance measurement and not comparable to earlier device/cpu runs.
Debug/Release candidate build currently running in serialized Main-only shell
session; no success/hash/review/candidate acceptance inferred before completion.

## Final code-only delivery

Bernoulli independent bounded source PASS in
Docs/APPEARANCE_APPLY_MAINTENANCE_REVIEW.md, initial F1 closed; no implementation
changes by reviewer. Reviewer/helper closed; no current Swift sessions running.
Final focused45/0, full2100/0; Debug0.70s and Release/package38.23s exit0.
334 source/test/resource/script/package fingerprints matched postbuild. Exact
source delta since r3 is AppearancePreferences.swift +its tests only. Existing
Sendable diagnostic warning persists; no zero-warning/physical regression claim.

Unique candidate .build/candidates/appearance-apply-rc-20261013-r1/LaunchcopyUITest.app,
bundle com.launchcopy.test.appearanceapply; executable SHA256
544f8f2ce7086ed15d346e307c34a4f790a97c7444fd79a0f896790fbec1ca76.
Candidate-local appearanceapply profile/385 metadata-only bundles prepared;
manual .build/verification/20261013/appearance-apply-maintenance/launch-ui-test-r1.command
NOT executed. No app launch/install/sign/notarize/publish/commit/process stops.
Linker ad-hoc does not establish distribution signing or acceptance.

Actual GUI/VoiceOver/real process restart/failure dialog/matched physical real-icon
AB/120Hz unverified. Native last locked and prior policy denial remain; user
manual isolated runner/unlock required before native CUA. Public NSFont diagnostic
and native-view tests are not a substitute. Long-tail>25ms causality unresolved.

## Next executable action / full scope

ICON_AND_TYPOGRAPHY_SPEC remains PROPOSED and specific user question pending;
GRID_APPEARANCE_AND_CAPACITY_PROPOSAL also unconfirmed. No new size/type fields,
schema2, row/column or queue contract implemented. Read source surveys before
confirmed implementation: default compressed folders and separate drag preview
need explicit geometry/consistency treatment, not a constant-only enlargement.
Library/categories/localization and explicitly gated gesture/destructive parity
remain on full ledger. Whole goal ACTIVE/incomplete; no smaller success definition.
