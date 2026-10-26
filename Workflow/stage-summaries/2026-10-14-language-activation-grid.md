# Language activation and grid integration wave

Status: implementation in progress. Approved contract: Docs/INTERFACE_LANGUAGE_SPEC.md.

## Plan and concurrency

Main plus two bounded workers, three agents maximum. Old Chief workflow waived by user.
Main owns shared resource schema/tables, runtime wiring, serial verification and documentation.
Worker A owns activation settings controller, shortcut presentation, ActivationTextKey.swift and new focused tests/report.
Worker B owns grid/folder/provider/pager/page-dots/title editor presentation, GridTextKey.swift and focused tests/report.
Workers do not build or control applications. Resource/code assembly tests are run serially by Main after source freeze.

Shared contract: typed enum raw values have activation/grid prefixes; CaseIterable and Sendable;
public var englishFallback: String. Shared LocalizedStrings activationText(_:) and gridText(_:)
are provided by Main. Count/page helpers use existing memberCount(_:)/page(_:total:) plus
folderHelp(_:) (typed integer, authored resources by Main). Workers publish exact key lists,
English fallback and requested translations in own reports; never edit shared .strings tables.
Keep data-only names, drafts, callbacks and bindings unchanged. Localization must not do IO,
formatting, or relabeling on advanceFrame or its transitive callbacks. AX changes coalesce
outside that stack with lifecycle generation checks; frozen inert exit visuals keep old text.

## Constraints and evidence

Preserve existing dirty worktree and candidates; no commits, installs, signing, app launches,
process control or reference-tree reads. RTK shell prefix mandatory. No new capacity/Library.
Previous verified baseline: 2282 tests/0, resource schema97; not full translation acceptance.
New code/resource counts and exact hashes must be measured, not reused. Native real GUI,
VoiceOver, restart, physical performance and120Hz gates remain unexecuted here.

## Final code checkpoint

81focused/77repair/2324full zero failures; Debug/Release and strict178-key actual-app
resources plus2negativefixtures verified;375inputs unchanged. See
Workflow/results/LANGUAGE_ACTIVATION_GRID_CODE_CHECKPOINT.md for currentcandidate hash,
all repair history and pending gates. Independent bounded reviews clear repaired scopes;
all4 helpers closed. No GUI/install/launch/restart/physical/whole-goal PASS.
