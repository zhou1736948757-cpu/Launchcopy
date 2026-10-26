# Main Grid Rows and Columns — Bounded Specification

Date: 2026-10-17
Status: APPROVED_FOR_IMPLEMENTATION — human confirmed main-grid range/default/deferral and separate small-window protection on2026-10-17; implementation underway. Historical proposal language below is superseded by the dated approvals.
Authority: explicit human question replies on2026-10-17 approve3–8 columns/rows, default5×7, independent folders, preserved physics/order and safe deferral, plus small-window readability protection. General continuation was not used as substitute approval.

## Problem and intended outcome

Allow the local macOS launcher user to choose how many rows and columns appear on the main grid without changing its accepted paging feel, saved organization or the independent adaptive folder layout. Existing icon size/type controls are already implemented. This slice addresses the missing logical capacity controls rather than another cosmetic redesign.

## Proposed scope and non-goals

- Add independently authored, localized main-grid row and column controls to existing settings, preserving explicit Apply, draft/failure protection and safe Quit behavior.
- Proposed integer ranges: **3–8 columns and 3–8 rows**, bounded at **9–64 items per page**. These ranges are a new recommendation, NOT existing approval or a value copied from a reference product.
- Default remains **5 columns × 7 rows = 35 items/page**. Restore-default behavior must clearly specify its scope and must not reset unrelated activation/source/Library/alias settings.
- Keep the accepted folder-only adaptive maximum5×3 and its size-dependent reductions independent. Main-grid controls must not alter folder capacity, material, member order, navigation, opening/closing or saved title.
- Do not modify paging physics, frame source, Timer tolerance, gesture thresholds, search matching, hidden/alias semantics, canonical workspace order, app identity, launch validation or source watching.
- No leftmost Library page, usage recording, uninstall, new system gesture, wallpaper preference experiment, installation/signing/distribution or reference code/assets.

## Functional contract

### Editing and application

- Existing controls use bounded integer values and show the resulting items/page; no free-form unvalidated count or product overflow.
- Apply explicitly accepts a valid draft. Persistence failure stays visible, retains a retryable draft and does not claim Saved or silently substitute an in-memory success.
- Proposed application boundary: no active gesture/settle animation, held pointer/drag, folder overlay (including its entrance/retained exit), title/alias editor, marked-text composition or modal transaction. Queue the latest accepted update until the owner is idle. Existing scalar appearance behavior need not be broadened or made more restrictive inadvertently.
- When capacity cannot yet apply, communicate Saved/Queued versus Applied accurately. Do not tear down a live input session, force folder closure or clear a draft to make application happen sooner.
- Multiple accepted updates are latest-wins. Old owner/session/store callbacks cannot apply or acknowledge a newer configuration.
- The new receipt-bearing capacity owner must be explicitly added to termination admission/drain/epoch checks; the existing drain does NOT already cover capacity or scalar appearance. An accepted pending capacity must then be protected during Quit and restore on a normal restart. Canceling unaccepted settings edits changes neither effective capacity nor persisted capacity.
- Ordinary window resize does not silently change the user's logical rows/columns or canonical ordering. Existing cell-fit rules may reduce rendered size/truncate labels. A supported minimum viewport/readability policy must be verified before implementation; do not silently invent a different effective capacity to hide layout failures.

### Anchor, focus and query

- Preserve current query and its input/selection state. Do not relaunch a search, clear it or treat layout change as a catalog revision.
- If an existing selection is visible and valid, anchor that stable app/folder identity. Otherwise anchor the first still-valid item of the current visible page; use deterministic nearest-valid fallback if that item disappeared. Empty presentation maps safely to page0 with no stale focus.
- Recompute anchor page from its index in the current visible sequence and the new logical capacity; do not persist old page indices or reorder entries to preserve screen slots.
- Preserve an existing valid selected identity with its new location. Do not create a blue selection merely because a settings change happened; deferred-keyboard-focus semantics must remain deferred.
- Keyboard/typewriter arrows use the newly committed row/column dimensions only after the same layout boundary. Page dots, page count, drag slots and accessibility names must reflect that same committed configuration.
- Library stays a separate optional view with its own category/query state. Capacity controls must not close it, change categories or contaminate Library search. Precise hidden-grid update ownership will follow the source audit, preserving the approved Library model.

## Architecture and storage decisions (pending source audit)

Retain the existing SwiftPM/AppKit layering and one owner-controlled layout transaction. The domain value validates columns/rows/capacity; the app owner coordinates provider capacity, surface requests, renderer metrics, keyboard focus, page dots and drag admission in one generation boundary. Do not introduce a second pager/state machine or mutable competing sources of truth.

Configuration uses a separate versioned capacity file/receipt-bearing asynchronous owner, with its own scoped Apply/Defaults controls; preserve existing appearance schema2 and workspace bytes. A shared all-or-nothing cross-store Apply is out of scope. Missing capacity defaults5/7 without a write; supported malformed/out-of-range pairs are corrupt rather than silently clamped; future/ambiguous envelopes are protected before typed body decoding and freshly checked before save. Explicit recovery Apply may repair corrupt capacity with a real write receipt; load/resize/language/close never repair it. Factory failure rejects persistence instead of silently selecting an in-memory success. The new owner participates in Quit admission, actual accepted-write drain, failure/cancel/retry and current-owner epochs, independently of presentation readiness. Missing/corrupt/future/denied storage must have explicit honest behavior, never delete workspace organization, and remain isolated in tests. Never import a reference product's state or use formal data for testing.

Stale page/cell/icon/coordinator generations are revoked at one discrete boundary. Outstanding asynchronous icons cannot write into new slots; logical ownership checks do not rely on fabricated catalog revisions. Folder source geometry must be resolved live after a main-grid change, not cached by pre-change frame.

## Performance and resources

The product priority is retained paging performance. Source discovery establishes a default radius3 / at most7 attached hosts: a single fully populated pass serves up to245 slots at35/page versus448 at64/page. Default icon cache256entries/64MiB and loader concurrency4 do NOT bound retained view images, queued unique keys, transaction-wide rebinding or whole-process memory. Record actual render/request deltas and lifecycle results before certifying an envelope; do not promise three hosts or448 lifetime requests. No per-frame scans, persistence, classification, image generation, configuration rebinding or grid rebuilds. Reconfiguration is a bounded idle transaction, not work added to every gesture/frame callback.

Record synthetic timing/resource checks separately from matched physical catalog/build/viewport/hardware evidence. Existing60Hz acceptance and unresolved >25ms tails stay historical; neither this contract nor green tests establish120Hz, energy or end-to-end hitch improvement. If the range cannot meet safe resource/readability constraints, revise the proposal explicitly before implementation rather than silently weakening it.

## Acceptance and test requirements

1. Default and legacy restart remain5×7/35; proposed endpoints3×3/9 and8×8/64; malformed/out-of-range/overflow data safely handled without touching workspace data.
2. Partial/empty/first/last pages; stable app/folder anchor across larger/smaller capacities; hidden/latent entries and same/count-changing searches preserve canonical order/query.
3. Existing deferred/selected keyboard semantics and typewriter navigation at row/column/page boundaries, including partial final rows.
4. Page dot count/target and new direct-page interruption behavior remain coherent with committed capacity.
5. Held pointer, active gesture, settle, drag, folder open/transition, text/IME or modal operation defers application; latest accepted update applies exactly once after safety boundary.
6. Before-boundary event/icon/menu/drag callbacks cannot act on changed bindings; normal settled input resumes after the layout transaction.
7. Folder-independent size/capacity/motion/membership/title/inner-page state is unchanged; later opening/closing uses the new live outer glyph location.
8. Settings draft cancel/reopen, language change, saved-versus-queued/error feedback, denied/corrupt/future store, actual normal restart and Quit-cancel/retry protection are covered.
9. Native isolated candidate verifies supported window sizes and maximum icon/font settings across proposed capacities; Library remains intact; no formal data or OS setting changes.
10. Independent source review, nonzero focused/full test execution, explicit Debug/Release builds, new candidate hashes, localization schema verification, source freeze and native/physical evidence boundaries are recorded. Tests/builds from the old candidate are not relabeled as new executions.

## Delivery and maintenance

Follow existing project Docs and Workflow/stage-summaries conventions, preserve all dirty changes and old artifacts. Main owns integration and serial builds; delegated write scopes must be disjoint and at most3agents including Main. Keep pure capacity/anchor tests separate from AppKit owner integration; share established policy/store primitives without broad framework refactors. No commit/reset/clean/sign/install/publish or process kill. Native testing only own isolated ordinary non-topmost instances; preserve the user-controlled launcher.

## Unresolved decision before implementation

Confirm the proposed **main-grid-only3–8 rows/3–8 columns**, preserved5×7 default, existing paging feel and independent folder capacity, with accepted changes queued until interactions and folders are closed. Implementation-file ownership, storage selection, minimum viewport and maximum live-slot envelope are being established from current source, not from reference code. No capacity implementation has started.

## Source-discovery decisions and unresolved engineering gates

Source reports: `Workflow/results/MAIN_GRID_CAPACITY_GEOMETRY_DISCOVERY.md` and `MAIN_GRID_CAPACITY_PREFERENCES_DISCOVERY.md` (read-only, zero tests/builds). Provider, refresh/search, Surface and renderer hold separate capacity/shape values; keyboard columns are fixed at construction and same-revision focus migration currently skips relocation. A coherent owner transaction and explicit same-revision reload/reconfiguration are required; no catalog revision forgery.

Use existing direct-page navigation for changed anchor pages and defer selected focus until settlement; do NOT promise an immediate arbitrary rebase, toggle Reduce Motion or change Core physics to emulate one. Same-product different-shape changes still invalidate bindings/keyboard metrics. Capacity waits while optional Library is open; leave Library query/category/details untouched and apply at its return-to-grid safe boundary, then restore stable identity through the existing return policy.

Readability remains an implementation-entry gate, not proven by3..8 arithmetic: there is no current enforced minimum main-grid viewport. Extending current formulas to8 rows at700×500pt would fit a default folder glyph to about7.5pt (formula-only, unacceptable to claim readable);1000×700pt yields about32.5pt. Do not ship range endpoints with invisible/tiny cells, silently reduce logical capacity or seize the user's window size. Define and verify a supported viewport/readability policy before capacity implementation; if it needs a materially different user-visible policy, revise this proposal and confirm it rather than treating the range question as blanket approval.

A distinct existing renderer retirement weakness was found during discovery: missing weak hosts are skipped by the current sweep. Main will first reproduce and, if confirmed, narrowly repair that lifecycle defect under existing maintenance scope. This does not authorize any capacity controls or establish whole-process memory/performance PASS.

## Human decisions accepted — 2026-10-17 (supersedes pending status above)

The human explicitly selected the main-grid-only3…8 row/column proposal, default5×7, preserved organization/paging feel, independent folder and queued safe application. The human separately accepted small-window readability protection: preserve the chosen logical dimensions, do not resize the window or silently reduce capacity, show a localized request to enlarge the window/reduce rows/columns instead of an unreadably dense main grid; settings remains accessible. This is APPROVED_FOR_IMPLEMENTATION. Existing source-discovery conclusions above remain engineering evidence, not feature completion.

Implementation decisions: one validated MainGridCapacity value in AppGridUI, separate version1 receipt-bearing capacity file/coordinator in the app layer; independent scoped Apply/Defaults. Domain/store foundations can proceed before native presentation verification. Main owns composition/termination integration; tests/builds serialize. Readability is evaluated using actual main-grid geometry and GridItemContentGeometry for the current appearance and visible captions, conservatively including a folder caption/count stack: require a fitted icon side of at least24pt and nonempty full-size caption lines. Insufficient content area suppresses only the main grid/input/AX, shows the localized protection message, preserves logical layout/query/selection and keeps settings reachable. It does not affect independent folder layout/Library. No new per-frame render/rebinding/persistence work; evaluate at layout/configuration boundaries. Native endpoint/default viewport verification remains required.

## Superseding settings interaction contract — 2026-10-17
Human approved Docs/LIVE_APPEARANCE_AND_GRID_SPEC.md: main-grid rows/columns move into Appearance, healthy edits auto-submit and preview at the safe boundary, no independent Grid tab/normal Apply. Healthy equal loaded/acknowledged values do not write again. Failed/indeterminate retries and missing/corrupt explicit recovery still require real receipts. Separate schemas, bounds, stable anchor, folder/Library deferral, readability and Quit protections remain; old explicit-Apply/discard settings paragraphs above are historical, not the current UI contract.
