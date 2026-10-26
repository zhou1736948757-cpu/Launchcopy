# Title edit focus — independent bounded source review

- **Verdict: SOURCE PASS (bounded).** No actionable correctness or regression finding in the frozen three-file delta. This approves only the inspected source change and its source-level regression evidence; it is not a native-input or full-parity PASS.
- Review date: 2026-10-15. Final independent freeze check: 2026-10-15T19:02:53+09:00.
- Project: PagingPrototype, SwiftPM / AppKit, existing composition-root folder rename and search/window responder restoration.
- Role: independent Reviewer. Human waiver of legacy Chief applies. Explorer is closed; Main + Reviewer = 2, ceiling 3. No agents dispatched by this Reviewer.
- Only authorized output: `Workflow/results/TITLE_EDIT_FOCUS_SOURCE_REVIEW.md`.

## Authority and review boundary

Read project `AGENTS.md`, `/Users/mac/.codex/RTK.md`, the designated stage summary, relevant current/historical contract sections of `Workflow/PLAN.md`, `Workflow/MAIN_BRIEF.md`, configuration/state, Explorer's source-route report, the exact bounded diff, the three owned before copies, affected source and adjacent lifecycle/control/test code. The stage summary and explicit task describe the current maintenance scope; older plan checkpoints and legacy Chief/model instructions are historical where superseded by this dispatch.

The existing contract already prioritizes title editing over folder/search/grid restoration. Repairing pending field-editor admission and avoiding reacquisition of an already-owned native editor preserves that contract. The change introduces no new activation policy, public seam, window ownership model or persistence policy. No discovery interview/new specification is required for this bounded maintenance review.

## Independent input freeze and precise delta

Recomputed SHA-256 for **454/454** current inputs, independently enumerated the same 454-file inventory under Sources/Tests/Scripts/Resources plus Package.swift, and compared both manifests. No missing, extra, added or removed inputs. All live hashes match the current manifest. The three before copies individually match the prior manifest, and reconstructing the unified diff from those copies and the live files reproduces `bounded-existing-inputs.diff` byte for byte. Repeated the verification immediately before report creation and again after writing it; no source edits or manifest rewrites were made.

| Evidence | SHA-256 |
| --- | --- |
| Current `title-edit-focus/source-inputs-final.json` | `dc7f88ad185d2544babdf5e3830f9e0e42f4e9ab8753a61b2c474695a668e023` |
| Prior `folder-title-cancellation/source-inputs-final.json` | `764d98d3ba3e4e77c38be046a1ad276ff8e977f767e6d05a0be97439c0442cf9` |
| Exact `title-edit-focus/bounded-existing-inputs.diff` | `cf5309530840a648440bad3ddf5d76790a80a7b2438d96259c43f9d2ab463078` |

| Changed input | Prior / matching before copy | Current |
| --- | --- | --- |
| `Sources/PagingPrototypeApp/AppDelegate.swift` | `a89a1ac50d887c1f9ff93f9eb3c6e80f74d5691a68b11dba54c8f1754e868cb8` | `fd937580eddc8443b3bd34687ef75ae35cd41cad3b3160fea2b7a51581c0dcd8` |
| `Sources/PagingPrototypeApp/AppSearchController.swift` | `a1fe5d4cea1eef493b45e258e4d57b5bb68ccff3ccbba23833052d13ad029649` | `e40587e613b839af056b12a8fa45ff035fcbbe15046f7c693a7ee2164986b57f` |
| `Tests/PagingUITests/FolderRenameAssemblyTests.swift` | `16c3042bcd9d53e297a9870d447e7e145a5fd992db58f11ce24a0395ce8463cb` | `3821ffdc91997b5528dce684b9ba8a1fb25307f031d25847bc5f17233c9f86a3` |

**451 inputs are identical to the prior freeze.** This includes all 6 PagingCore + 12 PagingUI files, all 53 AppGridUI files, both project Resources files, and the preceding `FolderTitleEditor.swift` completion fix (`9573c14b201c80bd1824f3fda398334aaf39ccc0ab0b4f584e45a359a058c0c9`). Project resource binaries were hashed opaquely solely to satisfy the 454-input check; no asset was opened visually, copied or used as reference material. No excluded project/reference source or assets were inspected.

The production delta consists of one provider hunk and one private restoration hunk. The test delta adds one opt-in probe, opt-in actual search-controller composition, teardown, and three tests to the existing file. No `makeKey`, ordering/fronting, `NSApp.activate`, window level/Space/geometry, global key guards, event dispatch, completion, resource, layout or paging-physics implementation changed.

## Source analysis

### Title admission and stale ownership

`Sources/PagingPrototypeApp/AppDelegate.swift:972-985` keeps Library priority and folder/grid fallbacks unchanged. Title admission now requires a non-nil current rename context, the current owned editor, exact equality with the overlay's mounted-editor slot, and a non-nil editor window identical to the owner's current window. A native field editor is no longer a prerequisite for requesting the mounted title control.

The provider captures the owner weakly and resolves current properties each time; it caches neither editor nor context. A completed/cancelled old editor cannot regain ownership through this closure. `beginTitleEditing` creates a fresh editor/context and token per session; commit/cancel callbacks retain the existing token checks (`:1767-1801`). `finishFolderTitleEditing` clears context/editor ownership and callbacks before unmount/focus consequences (`:1833-1846`). Folder close/switch, store replacement/restore, resize/screen change, overlay invalidation, session suspension and teardown retain their existing cancellation paths. `FolderOverlayView.swift:529-558` controls mounting/invalidation; normal unmount clears the mounted slot before removing the view.

Thus a detached editor, a stale editor moved elsewhere into the same window after unmount, an editor in another window, or an editor whose owner window has been replaced cannot be admitted as the current title. The new same-window detached test covers the particularly useful distinction between mere window membership and the exact mounted slot. Arbitrary out-of-contract manual reparenting that leaves the overlay's slot inconsistent is not simulated; production mounting/removal paths inspected here maintain that slot.

The context presence check is session ownership, not a new validation of captured layout/catalog/store epochs. The existing commit path still validates token, folder, revision, layout and store epoch before mutation (`:1806-1823`); this patch does not relax it. The unchanged stale-target, old-callback, cancellation and lifecycle tests provide adjacent coverage.

### Native field editor, generic controls, selection and IME

`Sources/PagingPrototypeApp/AppSearchController.swift:265-288` retains the same target window (`field.window`) and mode-provider precedence. Direct responder identity still returns immediately. The added branch asks an `NSControl` for its current editor and returns only if that exact object is already the target window's first responder. It neither creates a field editor nor treats a merely non-nil editor as ownership. An unrelated window's editor does not meet that identity test. A control without its current editor, another target, or a non-control responder follows the existing `makeFirstResponder` path; nil provider keeps the existing search/grid logic. This remains a synchronous MainActor check with no deferred retained editor or new observer.

The generic `NSControl` check is appropriate to this restoration seam: it avoids reassigning an already satisfied control/editor relationship, while direct responders such as the keyboard controller remain unchanged. Library already returns its owned responder/editor when available (`AppLibraryView.swift:158-173`), so that path normally takes the earlier identity return. Observer registration, weak capture, teardown and deinit removal are unchanged; the opt-in fixture explicitly tears its observer down.

The no-op branch performs no text, selection, marked-text, delegate or input-context mutation. The native-editor regression checks actual editor identity, first responder, draft, selection, canonical layout and immediate store state after observer delivery. This supports selection/draft preservation in this in-process case. It does **not** establish real IME behavior: the new test does not create marked text, and the existing Library composition and title relabel tests exercise different triggers. Actual IME/native activation/first-key delivery remain separate gates.

## Regression evidence and quality

All execution figures below are from Main's retained logs, independently read here, **not rerun by this Reviewer**. Evidence directory: `.build/verification/20261015/title-edit-focus/`.

| Evidence | Independently checked meaning |
| --- | --- |
| `red.log:7-14` | Initial compile failure: NSText lacked the attempted selection setter method. It executed no regression tests and is not the RED result. Current test uses the selection property. |
| `red-r2.log:12-32` | Executed **3 tests / 9 assertion failures across 2 cases**. Pending-owner case failed twice; owned-native-editor case failed seven times. Detached same-window negative already passed. |
| Native-editor RED | Observer delivery caused 3 responder requests, ended/unmounted the owned editor, lost editor text/selection and changed canonical layout to the unaccepted draft. This is an actual production-callback counterexample in an unshown window, not merely a failed getter comparison. The empty-writes assertion did not fail in this log; no completed disk write is inferred. |
| `focused-r1.log` | **75 tests / 0 failures, 4.556 seconds** XCTest execution (4.565 seconds selected-suite wall report). Suites: Library view 21, search integration 8, search responder 5, rename assembly 25, title completion 7, language consumers 9. The separate Swift Testing footer saying 0 tests does not erase the executed XCTest count. |

The probe's deferred path intentionally returns true for a title request without acquiring NSText. That is an explicit pending-admission model and verifies target choice, not successful AppKit focus/activation. In the native-editor case deferral remains false and the subclass delegates responder changes to actual NSWindow behavior; recording detects reacquisition and reentrant consequences. Tests post the real controller's observed notification against the same unshown window and use actual owner/overlay rename wiring. They do not simulate an OS key transition or key event.

Existing fixtures still default to original NSWindow and `search == nil`; only the three new tests enable search/probe composition. The negative was already green before the repair, as expected; with pending-title admission now allowed it guards against dropping the new mounted-slot restriction. Immediate no-write checks alone are not a drain proof, but synchronous canonical-layout and ownership checks independently detect the observed unwanted commit. Existing native focus-transfer/completion tests continue to cover legitimate completion rather than globally suppressing focus loss.

No blocking test-quality issue found. Optional follow-up coverage can isolate the foreign-window provider guard, a second generic mode control with an unrelated first responder, and marked text across this exact observer callback. These are coverage limits, not demonstrated source defects or authorization for additional edits in this review.

## Native and delivery limits

The supplied supported-before observation—opening/closing the owned Settings UI without Apply, then active window/field styling and correct first Return/Escape/Tab—is pre-patch context reported by Main. This Reviewer performed no UI observation. The inactive AX first-key commit/leak route remains untraced. Explorer established a conditional source route after title completion, not the actual event cause, replay, ordering or activation state. This patch's source evidence cannot turn either observation into a native after-fix PASS.

At dispatch Main owned full-suite/build/package work in parallel; this Reviewer neither executed nor certified those jobs or their later outputs. Main must attach its final frozen-candidate verification and any supported native results separately. Full parity, physical input, VoiceOver, real IME, performance/120Hz, multi-display and restart/durability acceptance are outside this verdict. Original goal remains incomplete.

## Findings, confidence and execution disclosure

- **Actionable source defects: none found in the bounded delta.** No repair requested; no product/test changes made.
- Confidence: high for exact input/diff identity and local ownership/idempotence reasoning; limited to the inspected source and retained in-process evidence for behavior. Native causality is undetermined.
- Reviewer executions: **0 Swift commands, 0 test runs, 0 builds/packages, 0 UI actions, 0 process-control actions, 0 installs, 0 signing operations, 0 commits**. Only read/search/hash/diff verification and this report write occurred. No full/native PASS is self-certified.
- Procedure deviation: the first instruction read, working-directory read and empty memory-registry search used unprefixed shell calls before RTK's rule was applied. Every subsequent shell call used `rtk proxy`. The memory search had no match and supplied no review conclusions. No other persistent file was written by this Reviewer; manifests/evidence and all product/test/other documentation remain unedited.
