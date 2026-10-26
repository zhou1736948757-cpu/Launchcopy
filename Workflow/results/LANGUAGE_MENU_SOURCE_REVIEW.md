# Independent language menu source review

Date: 2026-10-14.
Verdict: **No actionable defect found in the frozen menu-consumer scope by source inspection.**
This is a bounded source-review conclusion, not a compiled/test/runtime or whole-language PASS.
Executed builds: 0. Executed XCTest methods: 0. Executed GUI/menu tracking: 0.

## Assignment and evidence boundary

Only this report is writable. Reviewed the approved `Docs/INTERFACE_LANGUAGE_SPEC.md`,
`Workflow/stage-summaries/2026-10-14-language-status-menus.md`, project `AGENTS.md`,
and `/Users/mac/.codex/RTK.md`. Primary inputs:

- `Sources/PagingPrototypeApp/AppContextMenuController.swift`
- `Sources/PagingPrototypeApp/AppFolderAssignmentMenuController.swift`
- `Sources/LauncherLocalization/MenuTextKey.swift`
- `Tests/PagingUITests/MenuLanguageConsumersTests.swift`
- `Workflow/results/LANGUAGE_MENU_CONSUMERS.md` (resource requests and handoff)

Supporting reads were limited to the localization snapshot/schema/render seam,
the eight menu entries in the three resource tables, existing context/assignment
action tests, and the local SDK's NSMenuItem declarations. An Apple documentation
lookup was read-only and contributed no additional finding or runtime evidence.
Main's current immutable displayed-snapshot injection is an assignment premise.
Shared resources and production owner/runtime hooks remain Main work in progress;
provisional Main integration is not scored as a frozen-consumer defect.

No implementation, shared resource, existing report, workflow state or memory file
was edited. No build, test, app control, launch, tracking, install, signing, commit,
LaunchBetter/Buho access or global-memory read occurred.

## Findings

**None in the assigned frozen implementation/test/request scope.** No speculative
style finding or hypothetical provider misuse is promoted to a bug. The concrete
resource integration observation below is outside the frozen implementation verdict.

## Inspected contracts and source evidence

| Contract | Source evidence and assessment |
| --- | --- |
| One immutable snapshot per context menu | `AppContextMenuController.swift:41-64`: invalid binding/revision/record/hidden states exit first; line 45 invokes the provider once. All five action titles and the organization parent title use that local value, including the parent title rendered after the organization provider returns. No per-item snapshot reacquisition. |
| One immutable snapshot per assignment submenu | `AppFolderAssignmentMenuController.swift:110-145`: record/reference/layout/availability guards precede the single provider read at line 129. Submenu title and move-out title use that same local value regardless of destination count. Parent and submenu each capture their own snapshot; coherence between these synchronous groups relies on Main's supplied displayed snapshot, as declared in the handoff. |
| Retained menus and bindings stay frozen | Both controllers create new menus only when their menu factory is explicitly called. There is no retained-menu relabel/rebuild path, observer, deferred language callback or item mutation on provider replacement. Action handlers at context lines 74-89 and assignment lines 181-223 do not consult language. This supports retained-object stability; actual native tracking/release remains a runtime-owner gate. |
| Actions, identifiers, targets and represented bindings | Context lines 48-60 retain ordered `launch`, `alias`, `clearAlias`, `hide`, `reveal`, selector `handleMenuAction:`, `management.*`, explicit controller target and a distinct Binding containing weak cell/full token/revision/record/action. Organization remains `management.organization`, nil action, and an attached submenu (lines 63-69). Assignment lines 135-143 and 168-177 retain `folderAssignment.moveToFolder`/`folderAssignment.moveToTopLevel`, selector `handleAssignment:`, explicit target, and typed FolderID/action plus immutable expected layout/reference in Binding (lines 77-95). No localized title participates in routing. Neither controller sets or rewrites tags; dispatch does not use a tag. |
| Context stale/canonical/hidden/read-only rejection | Context lines 42-44 check construction revision and visibility; lines 75-80 require the same live cell token, catalog revision, current canonical URL and visibility at action time. Read-only permits only launch/reveal, both in enablement (line 59) and action delivery (line 80). Current record metadata is delivered, rather than a presentation alias or cached record. |
| Assignment stale/canonical/reference/layout/protection rejection | Assignment construction lines 111-127 check token identity/revision, canonical ID/URL/reference, hidden state and layout membership. Lines 183-198 repeat cell/revision/identity/URL/reference/hidden/full-layout and read-only/canApply/callback guards. Full layout equality rejects same-generation changes as well as stale generation. The final validate closure at lines 202-203 rechecks through `isCurrent` at lines 207-215 before owner commit. Localization does not alter policy at lines 13-55 or ownership of commits. |
| User folder titles and ordinal suffixes | Assignment lines 122-125 use canonical top-level order and exclude the source owner. Lines 148-165 derive titles solely from verbatim user titles, duplicate counts, reserved literal titles and used ordinal labels. The suffix remains ` (N)` with the existing collision skip; no locale formatting or localization key is applied to user content. Move-out separator availability remains lines 139-143. |
| Snapshot-only rendering; no resource IO in consumer build/render | The two consumers invoke `menuText` on captured snapshots, not `LocalizedStrings.init`, Bundle, FileHandle, preferences, locale or resource providers. Supporting seam `LocalizedStrings.swift:5-8,26-35,58-60,119-121` stores validated templates during snapshot construction and renders from retained dictionaries. `ValidatedTemplate.render` in `LocalizationResources.swift:248-261` consumes in-memory segments. With Main injecting an already-built snapshot, no resource IO is introduced by these menu rendering calls. This is source evidence, not an executed IO counter or runtime measurement. |
| Nil compatibility and typed vocabulary | Context lines 48-54,64 and assignment lines 130,141 retain Chinese legacy literals if no snapshot is supplied, without constructing a fallback snapshot. `MenuTextKey.swift:2-23` defines eight distinct String-backed CaseIterable/Sendable keys and matching English fallbacks. No dynamic arguments or placeholders are needed. |
| Accessibility and menu behavior | Context lines 47,55-60,66 and assignment lines 131-143,171-177 keep manual enablement, empty key equivalents and title-derived AX labels, including verbatim/disambiguated user titles. This does not establish VoiceOver behavior, native menu sizing or long-label reachability. |

Baseline limitation: the four reviewed Swift inputs are untracked in the current
tree, consistent with the worker's declared preexisting untracked-controller
baseline (`LANGUAGE_MENU_CONSUMERS.md:13-14`). Consequently this review verifies
current guards/identities and consistency with existing tests; it does not claim
a historical tracked-diff proof of every unchanged line.

## Test-source assessment

The new class contains 12 test methods, as reported. Independent literal expectations
cover en/zh-Hans/ja, menu/AX titles and exact identifiers (`MenuLanguageConsumersTests.swift:21-30,185-220`).
Provider counts and retained Binding/target/selector object identities are asserted
at lines 235-304. Selector routing to current metadata and stable FolderIDs is
asserted at lines 306-335. Stale revision/reuse/URL/hidden, full-layout changes,
read-only and interaction protection, missing callbacks, user-title collisions,
top-level availability and unused-provider cases are represented at lines 338-467.
Synthetic callbacks use `.noOp` and never commit a layout (lines 129-135).

The tests call explicit NSObject targets and do not present native menus
(lines 170-177). Their source provides no actual tracked-menu/owner-release or GUI
acceptance. Tags are not explicitly asserted. Provider-call counts are not physical
IO counters: the deliberately changing test providers create snapshots inside
their closures (lines 287-294), whereas the production premise is a preconstructed
displayed snapshot. The final validate protection is visible in implementation;
existing `AppFolderAssignmentMenuTests` additionally contains owner revalidation
cases. None of these test sources was executed during this review.

## Resource requests and provisional integration observation

`LANGUAGE_MENU_CONSUMERS.md:62-71` requests exactly the eight enum raw keys;
English values match `MenuTextKey.englishFallback`, Chinese values match nil
compatibility, and requested Japanese values match the new tests' independent
expectations. Every requested label has zero dynamic placeholders. User folder
names are not resource keys or format arguments. The handoff correctly states
that Main owns schema/table registration, packaged-resource validation and runtime
injection, and explicitly avoids claiming compilation/test/GUI acceptance.

At the supporting shared-table read, all eight keys were present in each table,
and the schema included `MenuTextKey.allCases` with empty placeholders. Two
**provisional Japanese values** differed from the frozen request/test literals:

| Key | Frozen request/test expectation | Shared ja table observed |
| --- | --- | --- |
| `menu.hideApp` | `アプリを非表示` | `アプリを非表示にする` (`Resources/ja.lproj/Localizable.strings:218`) |
| `menu.revealInFinder` | `Finderで表示` | `Finder に表示` (`Resources/ja.lproj/Localizable.strings:219`) |

Evidence: request report lines 67-68 and test line 29 versus the shared table
lines above. With these particular valid table values, exact title assertions at
test line 187 would not match. This is a concrete **integration alignment note**,
not a failure attributed to unfinished Main resources and not an executed test
failure. Main should reconcile final table copy with the frozen request/expectations
before serial focused verification. No shared-table required-key, signature,
packaging or runtime verdict is issued here.

## Frozen input fingerprints

SHA-256 readings matched across two bounded reads during the review:

| Input | SHA-256 |
| --- | --- |
| `Sources/PagingPrototypeApp/AppContextMenuController.swift` | `e773b9a19769878ef7dcb27058a9363139084df52b4892aa291e02480a315abd` |
| `Sources/PagingPrototypeApp/AppFolderAssignmentMenuController.swift` | `29f3f477e6ee0d7e1826de7ef156f0a88d84e9ab573d7a6416dd03efa00f555f` |
| `Sources/LauncherLocalization/MenuTextKey.swift` | `85bd52938ebeb465d3e92739e0664ab7c854a7f76765e3b976ccbc49ecef4a63` |
| `Tests/PagingUITests/MenuLanguageConsumersTests.swift` | `2256e013ebfef93fd43afee91d011932ce61fdb6a648166d652ac54b3149ee38` |
| `Workflow/results/LANGUAGE_MENU_CONSUMERS.md` | `4a286080a8b6c32e9336ccc50637026a1b93d069efe427cee0687949ea3e509d` |

These fingerprints identify only the reviewed frozen inputs, not the in-progress
shared resources/runtime or an application candidate.

## Remaining gates and process disclosure

Main still owns final resource alignment, focused nonzero native XCTest execution,
production native-menu owner/release integration and the approved wider verification.
Tracked-menu language deferral, GUI, long English/Japanese labels, VoiceOver,
packaged-resource isolation and whole-language acceptance remain unproven here.
No source repair is recommended in the frozen consumer scope on this evidence.

Process deviation: the initial RTK instruction-file read and one `pwd` were issued
without the prefix while discovering the RTK rule. Every subsequent shell command,
including project reads, fingerprints and this sole report write, used `rtk`.
