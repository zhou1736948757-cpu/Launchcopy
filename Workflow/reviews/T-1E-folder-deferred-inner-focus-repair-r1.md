# Review: T-1E-folder-deferred-inner-focus-repair (r1)

- Reviewer: independent (read-only; no implementation files edited)
- Reviewed against: `Workflow/tasks/T-1E-folder-deferred-inner-focus-repair.md` (spec) and `Workflow/results/T-1E-folder-deferred-inner-focus-repair.md` (worker claim)
- Verdict: **PASS**

## 1. Spec conformance — `Sources/PagingPrototypeApp/KeyboardFocusController.swift`

| Spec item | Observed | Result |
|---|---|---|
| `openFolder(_:)` :269-276 — `applyInnerFocusVisual()` call removed | Function body (:270-274) is exactly `openedFolderIdentity = identity.entryIdentity`; `innerFocusIndex = 0`; `focusModel = AppGridFocusModel(current: nil)`; `applyFocusVisual()`; `onOpenFolder?(identity)`. No `applyInnerFocusVisual()` call anywhere in the function. | PASS |
| `openFolderFromClick(_:)` :285-294 — `applyInnerFocusVisual()` call removed | Body (:286-292) is exactly `openedFolderIdentity = .folder(folderID)`; `innerFocusIndex = 0`; `focusModel = AppGridFocusModel(current: nil)`; `applyFocusVisual()`; synthetic identity; `onOpenFolder?(identity)`. No `applyInnerFocusVisual()` call. | PASS |
| Doc comments updated | `openFolder` :267-268: "T-1E-folder-deferred-inner-focus-repair：打开时不显示内环，首次方向键后延迟显示（与 isDeferredSelection 一致）。" `openFolderFromClick` :282-284: same deferred-ring wording + `onOpenFolder`/`openFolder(folderID:)` note. Old wording "打开后立即应用内部成员焦点视觉" absent (grep: 0 matches). | PASS |
| `handleInnerArrow` :330-344 unchanged | Present at :329-343; still calls `applyInnerFocusVisual()` at :342 after `navigator.move` — the deferred-on-first-arrow behavior. | PASS |
| `applyInnerFocusVisual` :356-363 unchanged | Present at :355-362; slot = `(innerFocusIndex ?? 0) % membersPerPage`; loop sets `setFocused(i == slot)`. | PASS |
| `closeFolder` / `restoreFocusAfterClose` / `activateInnerMember` / `isFolderOpen` unchanged | Present at :301-307, :310-326, :346-352, :262-264 respectively; behavior matches spec description. | PASS |
| Bug 2 preserved (outer ring cleared + `innerFocusIndex = 0` on both open paths) | Both paths set `focusModel = AppGridFocusModel(current: nil)` and `innerFocusIndex = 0`. | PASS |

Global grep: `applyInnerFocusVisual` appears only at :342 (call, inside `handleInnerArrow`) and :355 (definition). No other call sites.

## 2. Test conformance — `Tests/PagingUITests/FolderIntegrationTests.swift`

| Spec item | Observed | Result |
|---|---|---|
| `testMouseOpenClearsOuterRingAndShowsInnerRing` → `testMouseOpenClearsOuterRingAndDefersInnerRing` (:543) | Renamed; `XCTAssertNil(keyboard.focusModel.current, ...)` retained (:570); :571-572 `XCTAssertEqual(overlay.memberCell(at: 0)?.isFocused, false, "打开后无内环（延迟选中）")`; :574-576 `rightArrow()` keyDown then `memberCell(at: 1)?.isFocused == true`. | PASS |
| `testKeyboardOpenShowsInnerRingOnMemberOne` → `testKeyboardOpenDefersInnerRingUntilFirstArrow` (:579) | Renamed; :601-602 `isFocused == false` ("键盘打开后无内环（延迟选中）"); :604-606 `rightArrow()` then `memberCell(at: 1)?.isFocused == true`. | PASS |
| `testMouseOpenThenRightArrowMovesInnerRing` (:609) | :626 `memberCell(at: 0)?.isFocused == false` ("打开后无环（延迟选中）"); :628-632 post-arrow assertions retained (member 2 focused, member 1 unfocused). | PASS |
| Helpers reused | `rightArrow()` :500, `returnKey()` :501, `makeFolderSeamFixture()` :516 all present in the same file. | PASS |
| Old test names gone | Grep for both old names: 0 matches anywhere in the package. | PASS |

## 3. Frozen-tree check (mtime)

Edited files: `KeyboardFocusController.swift` = 1788091607, `FolderIntegrationTests.swift` = 1788091614.

| Frozen path | Newest mtime | Older than edits? |
|---|---|---|
| Sources/PagingCore/ | 1788057962 | yes |
| Sources/AppCatalogCore/ | 1787917822 | yes |
| Sources/MacAppCatalog/ | 1787918515 | yes |
| Sources/AppIconPipeline/ | 1787930560 | yes |
| Sources/PagingTelemetry/ | 1787918942 | yes |
| Sources/PagingUI/ | 1788070530 | yes |
| Sources/AppGridUI/ | 1788090925 | yes |
| Sources/PagingPrototypeApp/AppLaunchController.swift | 1787921214 | yes |
| Sources/PagingPrototypeApp/AppDelegate.swift | 1788090949 | yes (newest frozen file overall) |
| Sources/PagingPrototypeApp/AppCatalogAssembly.swift | 1788079459 | yes |
| Package.swift | 1787917375 | yes |

All frozen trees/files predate both edits. No frozen tree touched. (Repo has no git commits per spec; mtime is the agreed evidence.)

## 4. Independent test run (serial, this reviewer)

Commands run in `/Users/mac/Projects/Launch_Copy/PagingPrototype`:

1. `swift build -c debug` → exit 0 ("Build complete!").
2. `swift test` → `Test Suite 'All tests' passed ... Executed 772 tests, with 0 failures (0 unexpected) in 12.682 (12.723) seconds`; TEST_EXIT=0. Matches baseline 772; N=772 > 0, so this is a real execution, not INVALID_TEST_EXECUTION.
3. `swift build -c release` → exit 0 ("Build complete!").

## 5. Findings

- No BLOCKER / MAJOR findings.
- MINOR (informational): spec line numbers (:275/:293/:543/:575/:596-597/:617) are off by −1 to −2 from the current file because the doc-comment lines grew; the semantic targets all match exactly. No action needed.
- No deviations from the worker's result claim were found; the claim's mtime figures (1788090949 / 1788091607 / 1788091614) and test count (772, 0 failures) were independently reproduced.

## 6. Conclusion

All acceptance criteria verified: no inner ring on open (mouse or keyboard), ring appears on the moved-to member after the first arrow key, outer ring still cleared on mouse open, ←/→ member navigation intact, frozen trees untouched, full suite green. Verdict: **PASS**.
