# Folder title cancellation — independent bounded source review

**Verdict: PASS — BOUNDED SOURCE ONLY.** No actionable findings in the assigned production delta and eight added test methods. This does not close the overall goal, certify a candidate, establish native causality, or pass physical acceptance.

## Authority, scope, and execution boundary

- Reviewed the repository `AGENTS.md`, `/Users/mac/.codex/RTK.md`, `Workflow/stage-summaries/2026-10-15-folder-title-cancellation.md`, current checkpoint and relevant rename sections of `Workflow/PLAN.md`, and relevant handoff/configuration metadata. The current human waiver supersedes legacy Chief/watchdog routing. Authorized wave: Main plus this reviewer, two total, ceiling three; worker already closed. No additional agents dispatched.
- Domain: existing SwiftPM macOS 14+ AppKit application. `FolderTitleEditor` owns field completion/normalization; `AppDelegate` owns guarded rename sessions, mounted-editor lifetime and accepted workspace writes; `FolderOverlayView` hosts the editor. This review evaluates the existing architecture and conventions without redesign.
- Production review scope is exclusively `FolderTitleEditor.controlTextDidEndEditing`. Read adjacent completion methods, existing owner/host wiring, and relevant existing tests as context. The added coverage is seven direct production-delegate tests and one method added to the existing rename assembly tests.
- Reviewer executed **zero Swift commands, tests, builds, package jobs, UI operations, process-control operations, installs, signing operations, or commits**. Source/hash/diff inspection used read-only Python and RTK-prefixed shell tools. No restricted reference source, reference application, or reference assets were accessed. Manifest resources were hashed as opaque bytes, not visually inspected.
- Only authorized project write: this report. No implementation, tests, plans, state, events, manifests or evidence files were edited. Main owns parallel execution and subsequent acceptance gates.

## Independently verified freeze and exact delta

Two complete reviewer hash passes, including the pass immediately before writing this report, matched **454/454 current files**, with zero missing paths or hash mismatches. Every current Swift file under `Sources/` and `Tests/` is listed in the freeze. Scope is this manifest, not an assertion that the entire repository is clean.

| Evidence | SHA-256 |
| --- | --- |
| Current `folder-title-cancellation/source-inputs-final.json` | `764d98d3ba3e4e77c38be046a1ad276ff8e977f767e6d05a0be97439c0442cf9` |
| Prior `hidden-label-accessibility/source-inputs-final.json` | `0bdbf42fa75721e73075669e75bba081a9a3b8f45684d1558ef135d545962096` |
| Independently reconstructed and saved `bounded-existing-inputs.diff` | `614b5de9126f456694618b9f9cb4c88e1aedc9442978148668cd49c0736c740e` |

Both manifests are under `.build/verification/20261015/`. Comparison: prior **453**, current **454**; **451 unchanged**, **two modified**, **one added**, **zero removed**.

| Input | Prior SHA-256 | Current SHA-256 |
| --- | --- | --- |
| `Sources/PagingPrototypeApp/FolderTitleEditor.swift` | `4470a7f27afcb6f3466b00fbf10898a01bbe40480570c43d7e3e232009511f03` | `9573c14b201c80bd1824f3fda398334aaf39ccc0ab0b4f584e45a359a058c0c9` |
| `Tests/PagingUITests/FolderRenameAssemblyTests.swift` | `385d8c83551260c29c24553b51f574aa341557f26b710159256a40c424bc4bed` | `16c3042bcd9d53e297a9870d447e7e145a5fd992db58f11ce24a0395ce8463cb` |
| `Tests/PagingUITests/FolderTitleEditorCompletionTests.swift` | Absent | `a58f3a776c5913ce5d4216a83a4dad136989980bc79b8df9212a0d4c3f32ebcc` |

Both supplied `before-*.swift` copies independently hash to their respective prior-manifest values. Rebuilding the two-file unified diff from those copies and current files reproduces the saved diff byte for byte. Additional in-memory reversal proves:

1. Replacing only the current `controlTextDidEndEditing` method with its before-copy method restores the entire original production file exactly.
2. Removing only `testCancelEndEditingDoesNotWriteAndFreshSessionCanCommit` restores the entire original assembly test file exactly. All prior tests are preserved.

All six PagingCore and twelve PagingUI inputs (18 total), all 53 AppGridUI inputs, localization/resources, package/scripts and every other prior input remain unchanged. Earlier fixes remain byte-identical to the prior freeze. This is a relative-delta proof, not a renewed certification of those earlier fixes.

## Source audit

| Concern | Assessment and source evidence |
| --- | --- |
| Legitimate cancel notification | `FolderTitleEditor.swift:77–86` now dispatches the exact cancel movement to existing `cancel()`. The before-copy always committed this notification. This is a concrete completion-contract defect independent of any native reproduction. |
| Parsing strictness | The conditional `as? Int` bridge accepts integral `NSNumber` values and compares the resulting value with `NSCancelTextMovement`. It does not use a truncating `intValue`, string parsing or a truthiness heuristic. Fractional `23.5` cannot become cancel `23`. Missing key, nil/empty metadata, strings, null, collections, unrelated keys and other movements retain the original commit fallback. Exact integral values are intended, rather than a restriction to one NSNumber storage encoding. |
| SDK contract | Read-only local macOS 15.4 SDK `NSText.h:157–190` identifies integer movement codes and cancel `0x17`; `AppKit.apinotes:10369–10370` maps the key to `NSText.movementUserInfoKey`. No invented event or new notification channel was introduced. |
| Focus loss, Return and Tab | Every non-cancel case still calls the unchanged `commit()`. Return command handling and Tab/backtab responder-chain fallthrough are unchanged (`FolderTitleEditor.swift:61–72`). Normalization still reads the current field editor before the field value and uses the existing fallback/Unicode limit (`:91–95`). |
| IME/input handling | The patch touches an end-edit completion callback only. It introduces no key monitor, activation handler, responder override, marked-text mutation or text interpretation. Existing command routing is unchanged. The new tests do not simulate a real IME candidate session; physical IME/candidate Escape acceptance remains unproven. A delivered end-edit cancel contract must not be described as proof about which notification a physical IME emits. |
| Ordering/idempotence | `commit()` and `cancel()` set `didFinish` before invoking callbacks (`:91–102`), so cancel-first blocks subsequent commit, Return, focus-loss, duplicate cancel and reentrant completions. A prior completed commit remains terminal; this patch does not undo accepted writes retroactively. `dismissWithoutCallback()` marks terminal and clears callbacks (`:107–110`). |
| Owner writes | `AppDelegate.swift:1781–1792` keeps weak owner captures and per-session token guards. Cancel calls `finishFolderTitleEditing()` (`:1824–1825`), with no rename mutation or persistence enqueue. Only the unchanged accepted commit path performs `commitWorkspaceLayout` (`:1802–1819`). |
| Lifetimes and teardown | `AppDelegate.swift:1829–1842` invalidates context and editor ownership and dismisses callbacks before unmount/responder changes. A fresh editor is constructed per session (`:1773–1788`). `FolderOverlayView.swift:543–557` clears host ownership and retains cancellation-before-removal ordering. The delta adds no retained closure, async job or shared mutable lifetime. |
| Scope/privacy | No owner, store, public API, layout, paging, resources, diagnostics or telemetry changes. Synthetic test strings stay in tests; the production change does not log user content. |

## Test quality and evidence interpretation

The seven new direct tests (`FolderTitleEditorCompletionTests.swift:51–203`) invoke the production delegate and production completion methods, not a copied completion algorithm. Each fixture has isolated state and weak callback captures. Coverage includes notification-before-command cancellation; Return/ordinary movement normalization, fallback and Unicode length; malformed/fractional metadata; command-first and notification-first late completions; dismissal with recorders reattached to test the terminal guard independently; and bounded reentrancy. These are unmounted synthetic delegate-contract tests, not native keyboard tests.

The single added assembly method (`FolderRenameAssemblyTests.swift:191–217`) uses the existing actual title-button/owner/overlay mount fixture (`:81–103`), a synthetic cancel notification and an actor-backed recording store. It asserts unchanged accepted layout, editor/overlay removal, recovered edit readiness, no canceled write, a working new session on another folder, ignored stale old-editor completions, preserved original membership, and exactly one final accepted layout in the write history. Its real owner/mount wiring is meaningful integration coverage; its notification is manually delivered, text is assigned, window is unshown and store is a test double. It proves neither physical keystrokes nor disk durability. Final layout and write-history assertions also strengthen the immediate empty-write snapshot against scheduling ambiguity.

Read existing Main-owned logs; **no reviewer execution results are claimed**:

- `red-r2.log`: 8 executed tests, 8 assertion failures, 0 unexpected, reported XCTest duration 0.554s. Four test cases fail (one assembly and three direct); four pass. Eight assertion failures must not be mislabeled as eight failing test cases. The earlier compile failure is not executed RED.
- `focused-r1.log`: 63 executed tests, 0 failures, reported XCTest duration 1.853s; includes all seven direct tests and all 22 assembly tests. This is existing Main evidence, not an independent rerun.
- Full suite, Debug/Release, packaging and subsequent candidate verification were pending with Main at review handoff and are outside this verdict. No conclusion is drawn about their later completion.

Reviewed log identities: `red-r2.log` SHA-256 `965aa855bc943b60bb1f67d5aaee3cef63693bced4b08d6a6c163f8e01ea49fc`; `focused-r1.log` SHA-256 `1f3580b61429cff9b86be164bd082ce8d18b2e98d7779387310cd9739ae110f2`.

## Native boundary, findings and remaining gates

The stage summary and `native-before-results.json` describe observations on the BEFORE candidate whose supplied executable identity is `4f15b1333d6e030c48e1c6ab7dc8d4ffd687517e5491f0f6bcc82e289a4c2ca8`. This reviewer did not launch or hash that executable. Inactive gray-window AX-set-only remained a draft; first Escape activated the window and committed. Actual notification order and activation causality were not observed. Active-window blue-caret/selection with actual plain text entry plus Escape already canceled BEFORE this patch; active AX-set plus Escape canceled too. Tab committed and Return restored the synthetic original title.

Consequently, ordinary focused Escape was not established as broken, and this patch is not certified as fixing the inactive AX anomaly. The supported source conclusion is narrower: honoring an explicitly delivered legitimate cancel end-edit notification prevents that notification from committing the draft.

**Actionable findings: none in the bounded source/test delta.** No repair or scope expansion is requested. Source confidence is high for the reviewed frozen completion contract. Runtime confidence is limited to accurately reading Main's supplied logs, without independent execution. Main retains full/build/package verification, any exact-candidate native comparison, unresolved inactive AX causality and existing real IME, VoiceOver, physical-input/durability and broader goal gates. Bounded SOURCE PASS does not waive those gates.

Reviewer final pre-write freeze verification (UTC): 2026-10-15T09:27:08+00:00
