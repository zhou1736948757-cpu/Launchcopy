# Language status/menu/notice integration

Status: implementation in progress. Previous turn is concrete progress:2324/0,
178-key strict packaged candidate-r4 and repaired/source-reviewed frame/draft paths.
Full goal active; complete parity and native/restart/performance gates unproven.
Approved language contract: Docs/INTERFACE_LANGUAGE_SPEC.md.

## Ownership and plan

Main handles immediate shared localization schema/resources and production runtime/status
mounting plus app-owned alias/assignment/management/workspace-save/Quit alert builders.
Worker A owns binding-safe Context/FolderAssignment menus, MenuTextKey and new menu tests/report.
Worker B owns AppGridStatusView, CatalogTextKey and new status tests/report.
Main+two workers max3. Agents never build or control apps; Main serial gates after source freeze.
Old Chief workflow waived. Preserve existing dirty tree/history; no reference code/resources.

Interfaces: enums String/CaseIterable/Sendable with public englishFallback:String.
Main supplies LocalizedStrings.menuText(_:) and catalogText(_:). Workers publish exact
resource cases/translations, never edit shared .strings/schema/AppDelegate/Package.
Menus capture one immutable displayed snapshot at build, never rebuild while tracked;
keep IDs/actions/represented objects/token/revision/layout protection/user titles unchanged.
Status update(state:) and relabel(strings:) coalesce text/spinner/AX on next-main turn,
with lifecycle generation/teardown and no new frame formatting/IO. status hitTest=nil;
text rewraps in bounds, no stolen blank clicks/focus. Main mounts on existing container:
center empty/loading/no-results, unobtrusive refreshing/partial state, ready hidden.
Status uses served search/presentation state, not pending query/candidate revisions.

App-owned modal copy is built from current immutable snapshot. Register ownership before
presenting; release/retry after ALL outcomes, no stale post-teardown mutation. Alias editor
and Quit safe default/order/button semantics remain unchanged. Persistent save notice stores
semantic result and relabels without resetting visibility/expiry/persistence generations.

## Gates and boundaries

All3 table signatures/coverage/fallback, native unshown menus/actions/status/alerts, real
production status routing and transitive frame tests; full XCTest, Debug/Release, actual
resource-inclusive candidate positive/negative tests/current hashes, independent bounded review.
No install/app launch/process control/sign/publish/commit/clean. RTK mandatory. Library/capacity
still independently unconfirmed. Whole language/parity GUI/IME/VoiceOver/restart/physical
performance remain open; Timer0ms and >25ms CAUSALITY_UNRESOLVED remain unchanged.

## Final code checkpoint

65focused/2366full0fail, DebugRelease/current384hashes,213keys in actual three-language
package plus2negative fixtures. Scoped menu clear and status/noticeF1-F4repairPASS;
all4helpers closed. Exactcandidate manualkit prepared with37Info-only syntheticapps,
ordinary isolated runner(binary+resources checked), NOT launched. See
Workflow/results/LANGUAGE_STATUS_MENUS_CODE_CHECKPOINT.md for hashes/full history/pending gates.
