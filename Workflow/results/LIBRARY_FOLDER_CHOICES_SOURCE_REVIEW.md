# Library folder choices — independent bounded SOURCE review

Date: 2026-10-15

**Verdict: PASS (SOURCE only).** No actionable P0, P1, P2, or P3 finding in the frozen three-input delta. No implementation repair recommended. This verdict does not close native acceptance, packaging, physical interaction, or the whole project goal.

## Authority and review boundary

Read `/Users/mac/.codex/RTK.md`, project `AGENTS.md`, `Docs/LIBRARY_FOLDER_CHOICES_REPAIR.md`, and `Workflow/stage-summaries/2026-10-15-library-folder-choices.md`. Applied the explicit report-only reviewer assignment and existing approved organization semantics. No additional agents were dispatched; no implementation, tests, workflow state, resources, reference implementation, or other contributors' work was edited. The sole reviewer output is this report.

The project is a macOS 14+ Swift Package application using AppKit, with app-target assembly around existing layout-domain and grid/UI modules. The internal shared value helper belongs to the app target's existing folder-assignment controller file. The change introduces no public protocol, persistence schema, domain mutation, navigation model, gesture, or product scope.

**Reviewer execution counts:** 0 tests, 0 Swift/compiler/build/package invocations, 0 native/UI sessions, 0 application launches or process-control actions, 0 subagents. Read-only source/log inspection and hash/diff comparison were performed. Test outcomes below are Main's retained execution evidence, not reviewer executions.

## Input integrity

Both saved manifests contain exactly **455 inputs**, with identical path sets. Exactly **3 changed; 452 unchanged**. All 455 current files matched `source-inputs-final.json`; no missing files or hash mismatches. Each saved original body matched its baseline hash, and all three saved unified-diff bodies matched independently computed original-to-current differences. This establishes the delta against the supplied stage baseline, not a clean Git checkout or a historical repository baseline.

Verification directory: `.build/verification/20261015/library-folder-choices/`.

| Input | Baseline SHA-256 | Final/current SHA-256 |
| --- | --- | --- |
| `Sources/PagingPrototypeApp/AppDelegate.swift` | `59e990a26c5b186936322453e3f492c38d0bd4df3e1dd59a85e671c2ff26563d` | `6ea9ca3f6b6c39ec881b266fc1ba5b57d89186c5db3f8f380b319e874f36e759` |
| `Sources/PagingPrototypeApp/AppFolderAssignmentMenuController.swift` | `29f3f477e6ee0d7e1826de7ef156f0a88d84e9ab573d7a6416dd03efa00f555f` | `d51e93da472b3412dd24749c85b9436e98a375f33061077a4498baa46b9c5942` |
| `Tests/PagingUITests/MenuMutationLifecycleTests.swift` | `6670f9f83a0e53c5a61071e02e63d9b0c5853196f4645f0107d548ef6df97b90` | `e70d16ab010e37d225d466f32f9c88dd3d89336df2ef55a662169ad33554e0d2` |

Manifest SHA-256:

- `baseline-inputs.json`: `ca059a305b4f7dc9584c94cc24bc502a78782e1a3c25bf0ddbf491d65deaa294`
- `source-inputs-final.json`: `0c06c767c6f0ef418811454ff01c9bfb90f36c21678ba158083ba55a69b7d083`

Saved diff SHA-256:

- `AppDelegate.swift.diff`: `bccf91f655f9cc248afe334e832dcc36d300773857c86be5f5d748038db4a394`
- `AppFolderAssignmentMenuController.swift.diff`: `bf4cbcefbf09ac26976dec4cb67e53c4c3beabef4b33ad99d75f6e74ad1e5609`
- `MenuMutationLifecycleTests.swift.diff`: `6c9286181a112ec467438bb9644f916f32d066753e4c74e43526d7fa87a7b26d`

The other 452 manifested inputs, including layout-domain mutations, Core, paging/gesture code, localization, resources, and scripts, are unchanged from this stage's baseline. The earlier cold-gesture repair remains part of that baseline. The separate conditional appearance fallback issue is outside this delta.

## Source assessment

1. **Shared canonical policy preserves grid behavior.** `AppFolderAssignmentMenuController.swift:60–101` extracts the original reference resolution, current-owner lookup, top-level traversal, owner exclusion, and move-out eligibility. The ordinal title algorithm's function body is byte-for-byte identical to the former implementation. Reserved literal titles and previously generated titles still prevent ordinal collisions. Destinations remain canonical FolderIDs ordered by `topLevelOrder`; neither visible projections nor catalog availability removes latent destinations. The grid consumer at lines 157–183 keeps its binding, revision, canonical-record, hidden/read-only, and lifecycle checks. Library consumes the helper directly without constructing a grid cell.

2. **Library popup construction retains every action.** `AppDelegate.swift:2425–2472` returns before presentation when reference resolution fails or no action exists. It builds separate `NSMenuItem` objects and attaches typed actions through `representedObject`; it does not use title-deduplicating popup insertion. `autoenablesItems = false` prevents actionless selection items from being disabled through menu validation. Folder destinations precede a separator and member-only move-out. When only move-out exists, no leading separator is inserted. With the nonempty-action guard, index zero is always an actionable initial selection. The popup and individual choices receive accessibility labels. A folder whose title matches the localized operation retains a separate identity and menu group. Save reads the selected item's typed action, so label text and popup index are not mutation identities.

3. **Existing mutation/lifecycle guards remain intact.** The saved AppDelegate diff changes choice construction only. Writer epoch and directory capture, current owner identity, Library request/catalog generation resolution, and fresh record resolution remain at lines 2431–2437 and 2465–2470. Unchanged `applyFolderAssignment` at lines 3003–3025 retains readiness/hidden/canonical checks, exact-layout policy validation, revalidation after cancellation, and the shared commit path. `FolderAssignmentPolicy` and domain mutations are unchanged. Unchanged `presentApplicationSheet` at lines 3064–3083 retains its one-shot completion gate, language epoch/window/root checks, and modal lease release. Choice extraction adds no alternate write path.

4. **Regression tests exercise the actual application seam.** The test file retains all 8 existing test methods and adds 5, for 13 total. The old identical-directory writer replacement case changes selection from index 1 to the typed destination action while retaining old-callback rejection, zero old/replacement writes, fresh-sheet success, and one fresh enqueue assertions. New cases route through actual AppDelegate/Library ownership with an injected presenter and unshown AppKit sheet objects. Assertions cover canonical order differing from storage order, duplicate titles plus a literal ordinal title, excluded current owner, entirely latent destination, popup accessibility label, stable destination despite an edited presentation label, source dissolution position, preservation of unrelated references, exactly one enqueue despite duplicate completion, top-level exclusion of move-out, no-choice/no-modal behavior, and operation-title collision with separate stable actions and separator. Existing grid ordinal/latent/owner safety tests are unchanged.

## Retained execution evidence inspected

| Evidence | Observed terminal outcome | Attribution |
| --- | --- | --- |
| `red.log` | Successful compilation, then 3 XCTest cases / 7 assertion failures, 0.700 s | Main, before production patch |
| `collision-red.log` | Successful compilation, then 1 XCTest case / 4 assertion failures, 0.479 s | Main, before production patch |
| `focused.log` | 189 XCTest cases / 0 failures, 5.200 s; includes 13 MenuMutationLifecycle cases / 0 failures and 36 grid assignment cases / 0 failures | Main |
| `full.log` terminal section | 2693 XCTest cases / 0 failures, 52.863 s | Main; terminal section inspected after completion |

The logs' trailing Swift Testing footer reporting 0 tests is not counted as successful execution; the nonzero XCTest suite totals above supply execution evidence. Retained RED logs show the missing/incorrect actual popup actions and unnecessary modal ownership, rather than compilation failure.

Main additionally reported Debug build exit 0 and a passing Git diff check. Those two results were not independently executed or their logs inspected by this reviewer. Release/unique packaging and the planned owned synthetic native popup check remain Main-owned; no native outcome is claimed here.

## Remaining gates and handoff

No P0–P3 issue or minimal source fix is required for this frozen delta. Confidence is high for source parity and guard preservation. Actual pointer/keyboard selection, displayed popup rendering, and VoiceOver behavior are not established by injected-presenter tests or source review. Main should finish its existing release/package/native gates independently; this report does not wait on them or certify them. Any subsequent source changes require refreshing the freeze and reviewing the resulting delta.
