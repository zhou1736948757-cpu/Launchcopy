# Language status consumers — Worker B

Status: worker source implementation complete, ready for Main's source freeze and
serial verification. No builds/tests executed; no apps launched or controlled.
Approved contract: `Docs/INTERFACE_LANGUAGE_SPEC.md`.
Stage: `Workflow/stage-summaries/2026-10-14-language-status-menus.md`.
The old Chief workflow is waived; this worker creates no further agents.

## Exact resource handoff to Main

`CatalogTextKey` is a public String / CaseIterable / Sendable enum with public
`englishFallback: String`. Each entry is static with no placeholders. Main owns
schema, the three tables and `LocalizedStrings.catalogText(_:)`; the consumer
does not branch on language or create a default resource-backed snapshot.

| Case | Exact resource key | en | zh-Hans | ja |
| --- | --- | --- | --- | --- |
| loading | catalog.loading | Loading application catalog… | 正在加载应用列表… | アプリ一覧を読み込み中… |
| ready | catalog.ready | Application catalog ready | 应用列表已就绪 | アプリ一覧の準備ができました |
| empty | catalog.empty | No applications found | 未找到应用 | アプリが見つかりません |
| partialFailure | catalog.partialFailure | Some applications could not be loaded | 部分应用未能加载 | 一部のアプリを読み込めませんでした |
| refreshing | catalog.refreshing | Refreshing application catalog… | 正在刷新应用列表… | アプリ一覧を更新中… |
| noResults | catalog.noResults | No applications match the search | 没有符合搜索条件的应用 | 検索条件に一致するアプリがありません |

All three ellipses are the single Unicode character U+2026. Resources must use
these exact strings; the English column equals the enum fallback.

## Ownership

Only these assigned paths may be changed:

- `Sources/AppGridUI/AppGridStatusView.swift`
- `Sources/LauncherLocalization/CatalogTextKey.swift` (new)
- `Tests/AppGridUITests/StatusLanguageConsumersTests.swift` (new)
- `Workflow/results/LANGUAGE_STATUS_CONSUMERS.md` (new)

Main owns root mounting, precedence, runtime callbacks, schema and resources.
No change is authorized here to AppGridUIState or refresh/search protocols.

## Integration warning already identified

The existing `AppGridStatusViewTests` and
`AppGridSearchPresentationControllerTests.testNoResultsStatusViewRendersNeutralText`
assert immediately rendered text/spinner after construction or update. The approved
next-main-turn contract changes that timing. Main must update those out-of-scope
tests to await `drainDeferredPresentationTurns()` before presentation assertions;
semantic state assertions remain synchronous. No such tests have been run here.

## Integration hooks

- Construct `AppGridStatusView(frame: ..., strings: displayedStrings)` with the
  already-resolved immutable snapshot before mounting. The optional snapshot is
  explicit on this initializer; nil uses each typed key's English fallback. The
  existing `init(frame:)` is preserved and delegates with nil, with no resource IO.
- `update(state:)` stores the six existing states synchronously and only schedules
  presentation if the state changed. Do not infer rendering from the immediate
  state value: `statusText` is the last committed text until the next main turn.
- `relabel(strings:)` retains the new displayed snapshot and schedules a render
  even for equal semantic state. Call from Main's safe language-release callback;
  do not resolve language or construct snapshots inside a frame callback.
- `teardown()` is terminal and idempotent. Call outside frame callbacks before
  discarding the mounted view. It invalidates the pending generation, releases
  the snapshot, stops/hides the spinner and disables/hides accessibility. Later
  update/relabel calls cannot revive an externally retained view.
- Main mounts this view in the existing root container and chooses its bounds:
  center loading/empty/no-results; unobtrusive refreshing/partial failure; ready
  is hidden by this view at presentation commit. Provide enough height for the
  desired wrapped content. The view clamps geometry to its own current bounds;
  it cannot make arbitrarily small bounds display arbitrarily long text in full.
- Main routes served catalog/search presentation state through production
  callbacks and resolves state precedence. Pending query/candidate revisions must
  not be passed off as served results. No routing, mounting, precedence or
  callback ownership is implemented by Worker B.
- Main supplies `LocalizedStrings.catalogText(_ key: CatalogTextKey) -> String`,
  registers all six static keys in the shared required-key schema, and adds the
  exact rows above to all three tables. The API and schema wiring were visible
  in Main's concurrently changed source during read-only review; strict resource
  coverage and compilation remain Main's gates.

## Presentation and lifecycle details

`update` and `relabel` never mutate label/spinner/accessibility presentation. One
weak-self main-queue closure per pending batch reads the latest state/snapshot
pair. Its captured lifecycle generation must match and teardown must be false.
The callback renders one static string, then applies that same value to text and
accessibility, commits spinner activity/visibility and ready visibility together.
There are no language switches in this consumer; the only switch maps semantic
states to typed keys.

`internal private(set) languageFormattingCount` increments at the actual static
render seam, once per committed batch, including nil-snapshot English fallback.
It does not count scheduling. Equal state updates without relabel and layout-only
calls do not render. Layout uses the committed busy state, so pending data cannot
prematurely change spinner/text geometry. It measures the wrapping native cell at
current width, permits unlimited text lines and bounds label/spinner geometry;
there is no fixed 20-point text height. Ready remains semantically ready even
though the overlay is hidden. Its rendered ready string remains observable.

The overlay always returns nil from native hitTest, refuses first responder via
both acceptsFirstResponder and becomeFirstResponder, and uses a noneditable,
nonselectable native label. Only the overlay exposes a static-text accessibility
element when visible; label/spinner children do not duplicate the announcement.

## Tests authored, not executed

`Tests/AppGridUITests/StatusLanguageConsumersTests.swift` adds 13 bounded native
XCTest cases. No windows are shown, no application control is used, no polling or
unbounded timing loops are added. Deferred presentation is drained via the
existing four-main-turn helper. Coverage includes:

- All six states in actual en/zh-Hans/ja resource-backed snapshots on the same
  retained native view; exact text/AX, busy/ready visibility and control identity.
- Explicit nil-snapshot and absent-resource English fallback through the view.
- Same-state language relabel, deferred text/spinner/AX commit, and coalesced
  latest-wins state/language pairs.
- Initial queued-render invalidation and already-rendered externally retained
  view teardown; terminal/idempotent lifecycle behavior.
- Actual PagingSurface.advanceFrame/onAnimationFrame invocation (120 bounded
  calls, frameDriver disabled) stages updates/relabels/layout with zero extra
  static renders or text/spinner/AX writes in that frame stack, then one render
  after the main-turn drain. This test callback is a regression seam, not evidence
  of Main's production status routing or all transitive Core callbacks.
- Static equal-state/layout regression count, injected long mixed-script text,
  real shipped failure/no-results text wrapping in all three languages, resize
  remeasurement without localization work, compact busy geometry.
- Actual NSView container hit-testing through label/spinner/blank points, hidden
  ready behavior, and explicit refusal of native first-responder acquisition.

## Changed paths and evidence boundary

Changed exactly the four owned paths listed above. Existing tracked status view
was clean at baseline; the other three assigned paths are new. All other dirty
work belongs to existing work/Main/other workers and was preserved.

Read-only source/diff inspection confirms the public hooks, semantic mapping,
single queued render seam and absence of default LocalizedStrings construction
or language branching in AppGridStatusView. After worker source freeze:

- `rtk proxy git diff --check -- Sources/AppGridUI/AppGridStatusView.swift`:
  exit 0, no whitespace diagnostics.
- `rtk proxy git diff --no-index --check /dev/null <new assigned path>` for each
  of CatalogTextKey.swift, StatusLanguageConsumersTests.swift and this report:
  exit 1, no whitespace diagnostics. No-index comparison reports additions
  against the empty file; this is not compile/test success or failure evidence.
- Owned-path status: one modified tracked view and three new untracked files,
  matching the exact ownership list. Worker implementation source is now frozen.

No compile, XCTest, Debug/Release, packaging, GUI, VoiceOver, restart or physical
performance acceptance is claimed. No build/test invocation, toolchain migration,
install/sign/clean, commit, process control, reference-tree access, global memory
write or edits to shared localization resources/protocols were performed. Main
must compile after freeze, adapt the two legacy synchronous tests within its
authorized ownership, execute the focused suite, and verify mounting/routing,
strict resources and full integration independently.
