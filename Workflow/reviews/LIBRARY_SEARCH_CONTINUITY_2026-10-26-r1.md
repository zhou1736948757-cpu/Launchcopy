# Library search continuity and passive cards — independent source review R1

Verdict: **SOURCE PASS — bounded to the frozen R4 header/card slice.**

No actionable source finding was identified in the reviewed changes. This verdict is independent source review, supported by inspection of completed Main-owned logs. It does not certify native appearance, physical flash elimination, full application parity, or release readiness. The separately admitted MacAppCatalog metadata-reader repair is outside this review.

## Authority and evidence binding

- Repository: `/Users/mac/Projects/Launch_Copy/PagingPrototype`.
- Read `AGENTS.md`, `/Users/mac/.codex/RTK.md`, `Docs/LIBRARY_SEARCH_CONTINUITY_AND_PASSIVE_CARDS_2026-10-26.md`, and the actual stage-summary path `Workflow/stage-summaries/2026-10-26-library-search-continuity.md`. The supplied `stage2026-...` shorthand was resolved to that existing file.
- Honored the direct assignment: source review only; old Chief/watchdog workflow waived; no additional agents dispatched; no implementation, test, shared-document, or Git mutations. All shell commands started with `rtk`.
- Ran no tests, builds, UI, process inspection/control, profile checks, catalog probes, reference inspection, or asset inspection. This report is the only authored file.
- Baseline: `source-baseline-r1.json`, **610 inputs**. Current review freeze: `source-inputs-r4.json`, **611 inputs**. Initial and final full-manifest hash reads both matched **611/611**, with zero missing files or mismatches. These full reads preceded the separately admitted reader repair. Immediately before writing this report, all **16/16 reviewed delta files** were rehashed and still matched R4.
- Recomputed the baseline-to-R4 manifest difference: **16 files, exactly matching `source-delta-r4.json`**: eight product files and eight test files; 15 modified existing inputs, one added input (`LauncherSearchHeader.swift`), no removals. Unchanged manifest entries were hash-checked, not all text-reviewed.
- Independently verified **57/57 saved baseline texts** against the 610-input baseline hashes. Used real before/after text comparisons for the **14 changed files with saved old text**. The new helper has no old text. `GestureValidationRuntimeTests.swift` has a hash-only baseline: inspected the current affected method, but cannot independently reconstruct or certify the claimed one-assertion historical diff.

Manifest SHA-256 bindings:

| Evidence | SHA-256 |
| --- | --- |
| `source-inputs-r4.json` | `17364e730175faf5908019143e8a577911ba41c2e73620f1493a1f337fda6098` |
| `source-delta-r4.json` | `735b25d2250d89b45e60b2d8e8257408467a94c181c5eec412815e10cab87490` |
| `focused-r4.log` | `26c2c42dd50bdf04c008e359bcf7b4fb36a43d8bd765a42e9467ba9dd7f3b24a` |

Verification artifacts above are under `.build/verification/20261026/library-search-continuity/`.

## Source review coverage and conclusions

Reviewed complete changed product functions and their lifecycle callers, with new/changed test methods and relevant fixtures. The very large `AppDelegate.swift` and unrelated dirty tree were deliberately not reviewed wholesale.

| Product source | Inspected behavior and conclusion |
| --- | --- |
| `LauncherSearchHeader.swift:4-22`; `AppSearchFieldView.swift:17-24`; `LibrarySearchField.swift:5-9` | Both native controls share regular size, system font, no outline and no recents. Geometry preserves the previous main-header calculation, including bounds origin, finite safe-area handling and small-size clamping. The flipped variant provides local standalone geometry. |
| `AppLibraryView.swift:185-221`, `365-431`, `883-888` | Mount hides the field before reparenting it beside the moving body. Header visibility controls both visual and AX exposure. Mounted layout leaves the host-supplied header frame intact and converts the actual header into body coordinates for adjacent controls. Standalone layout uses the shared flipped policy. The visible placeholder matches main search while the AX label remains Library-specific. Editor/control ownership explicitly includes the sibling field. |
| `AppLibraryOwnerController.swift:174-225`, `340-366`, `398-463`, `650-663` | Preview body is hidden before attachment; sibling search starts hidden. Ordinary entry and preview commit hide the grid before revealing/focusing Library search, with session/identity rechecks after grid callbacks. Close relinquishes only Library-owned responders, resets, rechecks ownership, and **unmounts the outgoing native field before restoring the grid editor**. Closing admission and active-owner checks protect the inspected restoration/teardown callback paths. Current host search geometry is copied to the mounted sibling during layout. |
| `LeadingLibraryNavigator.swift:166-181` and related commit/cancel paths | Admission, initial parent render and only then preview-body reveal occur inside the disabled-actions transaction. Commit, cancellation, reversal and Reduce Motion retain the last semantic search owner until ownership transfer. |
| `AppDelegate.swift:2177-2190`, `2784-2794`, `2848-2932`, related return/resize/screen handlers | Main and Library receive the same root-coordinate header frame. Main search is excluded from moving grid views. Return preview exposes retained grid content while keeping its search hidden; the committed Library sibling remains stationary. Resize/screen changes cancel navigation before recomputing geometry. Grid restoration retains the existing independent-query and selection policy. |
| `AppLibraryGalleryView.swift:139-184`, `248-311`, `401-430`, related preparation/icon lifecycle | Removed category expansion callbacks and the full-card button. Background/caption are passive; the card is an AX group. All seven icons, including four miniatures, bind their own app identity, activation, details menu and AX label. Live binding, hidden/loading/action blocking, request validation and retirement guards remain. Retirement disables old controls, hides AX, clears card callbacks and cancels icons. Prepared cards stay detached, blocked and callback-free until fresh live binding. |

Targeted unchanged collaborators: `SearchFieldFocusPolicy.swift`, `LeadingLibraryPresentation.swift`, `LibraryHorizontalLayout.swift`, `AppSearchController.swift` and `LauncherWindowInput.swift`; `Package.swift` supplied architecture context. The native Library event path still uses normal AppKit delivery, and query state/delegates remain separate.

Reviewed test changes in all eight delta test files: `LeadingLibraryAppIntegrationTests`, `LibrarySearchFocusDrawingTests`, `LibraryCategoryGalleryTests`, `LibraryGalleryPreparationTests`, `LibraryOwnerCardPreparationTests`, `LibraryPresentationPreparationTests`, `LibraryTransitionGalleryWorkTests`, and the affected `GestureValidationRuntimeTests` method. Related test inspection included `LibraryResponderIsolationTests`, `AppLibraryGridReturnIntegrationTests`, selected `LeadingLibraryPreviewTests` methods and `LeadingPaneSharedFrameTests`.

The new tests exercise hidden preview admission, stationary single-header state in both directions, commit/cancel and both render modes, common style, seven individual launch requests, passive backgrounds/captions, AX identity, retained context-menu rejection, loading/action policy, and stale/prepared controls. Existing actual-owner grid-return and responder tests retain query/editor, anchor/selection, composition, shared-editor reuse and callback teardown assertions. Geometry expectation changes reflect the approved 28-point shared header rather than dropping alignment checks. Source inspection found no actionable regression in these paths.

## Completed Main-owned verification only

No execution below was performed by this reviewer. Read the corresponding completed `.json` and `.log` files; failure counts are XCTest assertion failures, not counts of failing test methods.

| Main run | Completed evidence | Interpretation |
| --- | --- | --- |
| `search-before-r1` | Exit 1; compilation failed; zero tests executed | Worker's optional chaining on a nonoptional NSView AX identifier. `INVALID_TEST_EXECUTION`; not a product RED or PASS. |
| `search-before-r2` | 3 tests / 13 assertion failures | Actual RED for preview admission, style/placeholder/frame and moving/duplicate headers. Model/owner evidence, not physical scanout. |
| `focused-r1` | Exit 1; compilation failed; zero tests executed | Main isolated the pure geometry helper to MainActor. `INVALID_TEST_EXECUTION`; corrected by isolating only native-control configuration. |
| `focused-r2` | 349 tests / 15 assertion failures | Includes genuine grid-editor restoration failures and standalone-body geometry compatibility, plus old header expectations and seven AX-element assertions. |
| `focused-r3` | 349 tests / 9 assertion failures | Earlier grid-return/editor and standalone-body failures are gone. Seven remaining assertions concern `isAccessibilityElement()`, **not keyboard eligibility**; two retain old 16-point geometry. Preserve the stage's explicit correction of Main's initial misreading. |
| `focused-r4` | **349 tests / 0 failures**, exit 0 | Completed at `2026-10-26T01:43:50.462619+09:00` in Main's metadata. Explicit app-button AX exposure and the remaining exact shared-frame expectations are present. |

R4 log completion: `focused-r4.log:859-862`. No tests were rerun, skipped or rewritten by this reviewer. The unchanged actual-owner return tests passed in Main's completed R3/R4 focused runs; the review does not erase the earlier failures. Full-suite, Debug/Release/package and native outcomes are not admitted into this verdict. Main has deferred those jobs until the separate metadata repair completes.

## Warning scope and evidence correction

**Catalog warning classification/product behavior is unchanged by this R4 header/card slice.** No scanner, severity, source, permission or OS change belongs to this verdict.

The stage records Main's fresh Foundation-only original-reader/default-root probe: five candidates classified `invalidAppBundle`, all other failure kinds zero, with all four default roots available. This was a fresh equivalent-configuration probe, not a direct measurement of the historical UI warning.

Latest Main-provided evidence supersedes a corruption inference: all five are outer directories containing `Wrapper` and `WrappedBundle`, without outer `Contents/Info.plist` or root `Info.plist`, and with zero alias/regular-file candidates. Main subsequently confirmed contained wrapped APPL/iOS metadata for all five and successful public `Bundle(url: OUTER).infoDictionary` reads for 5/5, without launching apps. These are aggregate findings supplied by Main, not independently repeated here. They support a reader false-negative/support gap; they do not certify harmlessness or independently identify the historical UI's exact five items.

The contract/stage now separately admits a narrow MacAppCatalog fallback when standard `Contents/Info.plist` is absent: accept only public Bundle APPL metadata, reuse extraction and the canonical outer URL, retain standard corrupt/missing/non-APPL behavior, and add synthetic RED tests before repair. That reader implementation, its tests, any later input freeze, and its review are **explicitly outside this report**. No wrapper-path special case, executable loading or error suppression is approved by this source verdict.

## Limits and handoff

- Confidence is high for the bounded source conclusions and exact R4 delta binding, not for unobserved native behavior.
- The new production-header integration assertion uses a 1000×700 host with zero supplied safe-area top. Safe-area, resize and nonzero bounds-origin alignment were traced through source; this reviewer performed no independent runtime geometry matrix.
- Model transforms/hidden flags and mounted-but-unshown AppKit tests cannot prove compositor timing, absence of a physical flash, perceived motion, physical trackpad behavior, live IME acceptance, VoiceOver traversal or complete visual parity.
- This SOURCE PASS closes only this review. Main owns the separate metadata scope, subsequent full tests/build/package evidence and authorized native/human acceptance gates. Do not extend this report to a later changed header/card slice without revalidation.

Reviewed slice revalidated and report written at 2026-10-25T16:53:38.754708+00:00.
