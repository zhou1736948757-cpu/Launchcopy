# App Library native view — source freeze

Date: 2026-10-15. Status: IMPLEMENTED_SOURCE_FROZEN; ready for Main's serial verification. This is not a Reviewer PASS, successful Swift compilation, executed-test result, or physical UI acceptance.

## Authorization and exact changed files

The human authorized this bounded implementation and waived the formal workflow. No additional agents were dispatched. The shared dirty tree was preserved. Only these four new owned files were written:

1. `Sources/PagingPrototypeApp/AppLibraryView.swift`
2. `Sources/PagingPrototypeApp/AppLibraryCategoryLabels.swift`
3. `Tests/PagingUITests/AppLibraryViewTests.swift`
4. `Workflow/results/APP_LIBRARY_NATIVE_VIEW.md`

Read inputs: project `AGENTS.md`, `/Users/mac/.codex/RTK.md`, approved `Docs/APP_LIBRARY_SPEC.md`, incorporated `Docs/APP_LIBRARY_SLICE_PROPOSAL.md`, and `Workflow/stage-summaries/2026-10-15-app-library-native.md`; existing domain, localization, pipeline and native-control/test interfaces; local AppKit SDK declarations for native lifecycle/editing APIs. No LaunchBetter/Buho/reference implementation, evidence, or assets were read or copied. No Main-owned source, foundation, localization, existing settings, Package.swift or workflow state was changed.

## Frozen owner interface

`AppLibraryView.init(frame:strings:iconPipeline:)` accepts the optional shared `IconPipeline`, default nil. `apply(snapshot:isLoading:catalogIsEmpty:actionGeneration:)`, `reset()`, `focusSearch()`, `handleEscape() -> Bool`, and `relabel(strings:)` implement the requested contract. `query`, `selectedCategory`, and `detailsOpen` are externally read-only.

Callbacks: `onBack`, `onQueryChange`, `onCategoryChange`, `onOpen`, `onReveal`, `onEditAlias`, `onSetHidden`, and `onSetCategory`, with exactly the requested immutable `AppLibraryActionRequest` argument types. The subsequent human-authorized extension adds optional `onFolderAssignment: ((AppLibraryActionRequest) -> Void)?`. The native button uses `menuText(.organizeApps)` and stays hidden until the owner supplies its existing layout-safe assignment picker. There is no fake grid cell, folder mutation, classifier task, scanner, persistence, NSWorkspace call or app action implementation in the view.

Responder extensions: `preferredFirstResponder: NSResponder` retains the current Library view/control/table/window field editor, otherwise returns the query field. `hasPresentationOwnership: Bool` reports an owned active text responder, including IME composition and native detail text selection/editing. `onPresentationOwnershipChange: (() -> Void)?` fires on native text begin/end and reset. Main remains responsible for mode transitions, lifecycle/action validity, menu/sheet cancellation and safe projection/relabel publication.

## Behavior and resource boundaries

- Native reusable category/results NSTableViews and independent NSSearchField; no query history. Details controls are allocated only on selection/details request. Category counts consume the supplied snapshot.
- Search Return/Down selects and focuses the first result without launching. Selected result Return or keypad Enter emits Open. Native Tab/Shift-Tab are not intercepted. Escape first consumes owned marked text through the native input context, then closes details, clears query, or requests Back. Main's window-level IME/menu/sheet guard still owns the outer cancellation priority.
- Selection continuity is by AppID. Loading nil snapshots retain only ephemeral `(AppID, detailsWasOpen)` while removing actual selected rows, detail values and executable actions. Repeated loading nil applies preserve this pending identity. The next nonnil snapshot restores it only if still present, using fresh canonical URL, revision, metadata and owner generation; removal/filter/hide clears it permanently. Unavailable nil clears it too. Query/category edits immediately revoke actions before callbacks. Reset clears pending continuity.
- Category picker contains Automatic followed by all 22 approved categories. Changing its selection does not save. Explicit Save emits the selected category or nil; Restore Automatic emits nil. Pure relabel preserves an unsubmitted picker draft; fresh snapshot metadata displays the owner's acknowledged classification.
- Details contain only original name, alias when distinguishable from the original display name, effective/automatic/manual category, bundle ID, canonical location, version and build. Unknown metadata uses the selected-language Unknown text. A same-as-original alias cannot be distinguished by the current entry contract and is shown as Unknown rather than invented.
- Each visible result cell owns its individual shared-pipeline request handle. Request eligibility requires a visible mounted window, visible Library/results, a current non-loading snapshot, and a visible table row. Delivery rechecks presentation generation, cell reuse generation/key, current AppID/row and visibility. Apply, reset, hiding (including hidden ancestors), row removal/recycling and detach cancel handles/release cell images. The shared pipeline is never shut down or flushed by the view. No details-icon request or whole-catalog prefetch exists.
- Blank hits inside Library return its root. Scroll bubbling terminates at the root rather than reaching the pager. Wide windows show details beside results; narrower windows replace results with a scrollable details drawer, and compact widths replace the sidebar with the native category popup. Header and pane frames remain within root bounds; owner-provided screen-safe insets remain outside this view.
- Accessibility labels use selected-language `.libraryText`/`.menuText`; native identifiers include `library.search`, `library.categories`, `library.results`, `library.back`, and lazy `library.details` plus action/field identifiers. Relabel does not replace the search editor or change query/selection.

## Verification performed and deferred

All shell commands used `rtk`. Read-only source inspection, SDK declaration checks and a bounded Python text check found all required extended contract names and no prohibited owner/I/O constructs in the view. The test file contains **17 test methods**, using synthetic records and ordinary mounted, unshown temporary windows. Tests cover search/results Return, native Tab, Escape priority, refresh/removal and immediate action revocation, explicit category save/reset, factual details, management/folder callbacks, loading/unavailable/empty states, responder ownership, IME navigation protection, relabel draft preservation, compact layout, blank hits/reset, no unshown-window icon prefetch, resident image release, and repeated nil-loading continuity with fresh metadata and removed-identity rejection.

**Executed Swift tests: 0 (explicitly prohibited for this worker).** No Swift/build/formatter command, app startup, app/process control, installation, signing, commit/reset/cleanup or production-data action was performed. Text inspection is not compilation or runtime validation. Main must run its serial focused/full checks after this freeze. Physical accessibility, real IME cancellation, viewport icon request/cancellation under visible scrolling, narrow-window visual layout, persistence/restart and performance remain separate gates.

Frozen SHA-256 inputs:

| File | SHA-256 |
| --- | --- |
| `Sources/PagingPrototypeApp/AppLibraryView.swift` | `eb11bae04649eec2c08dd835b1081e680e3971a7052ae23442f1debd96789168` |
| `Sources/PagingPrototypeApp/AppLibraryCategoryLabels.swift` | `7cf0ef70fb1d51face074efca1c9141c6a23955b9089c4a9d39d15c949c1595a` |
| `Tests/PagingUITests/AppLibraryViewTests.swift` | `ccd2a9e0444cbfe9afc280b2669a14e9cfff9152f62614b5b97e8beb20379dc7` |

Next action: Main assembles these APIs without changing the frozen inputs, then runs serial compilation/tests and records actual outcomes in the stage summary. Any necessary source repair should be explicitly routed back to this owner or coordinated after freeze.
