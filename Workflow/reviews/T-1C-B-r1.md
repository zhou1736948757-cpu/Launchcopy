# Review: T-1C-B — AppKit responder / 页面表面接线

- **Reviewer**: independent (read-only)
- **Date**: 2026-08-29
- **Verdict**: **PASS**
- **Review revision**: r1

## Scope reviewed

New files (the actual diff):
- `Sources/PagingUI/KeyboardPageTurner.swift`
- `Sources/PagingPrototypeApp/KeyboardFocusController.swift`
- `Sources/AppGridUI/AppGridCellFocus.swift`
- `Tests/PagingUITests/KeyboardPageTurnerTests.swift`
- `Tests/PagingUITests/KeyboardFocusControllerTests.swift`

Read-only types wired against: `PagingSurface`, `PagingCore`, `ScrollInputMapper`, `AppGridCellView`, `AppGridPageView`, `AppGridRenderer`, `AppGridUIPageContentProvider`, and T-1C-A focus types (`AppGridFocusModel`, `AppGridFocusNavigator`, `AppGridFocusIdentity`, `AppGridFocusLayout`).

## Verification executed (independent, not trusting Worker summary)

| Command | Exit | Result |
|---|---|---|
| `swift test --filter "KeyboardPageTurnerTests\|KeyboardFocusControllerTests"` | 0 | 14/14 passed (6 turner + 8 controller) |
| `swift test` (full) | 0 | 501/501 passed, 0 failures |
| `swift build` (debug) | 0 | Build complete, no warnings |
| `swift build -c release` | 0 | Build complete |

`exit_code == 0` with `executed_tests == 501 > 0` → **valid test execution** (not INVALID_TEST_EXECUTION). Worker's claimed counts (14 targeted, 501 full) are confirmed.

## Acceptance criteria — per-criterion result

| Criterion | Result | Evidence |
|---|---|---|
| surface 或键盘代理可成为 first responder | ✅ | `KeyboardFocusController.acceptsFirstResponder`/`becomeFirstResponder` return true (lines 72–75); `testAcceptsFirstResponder` passes |
| 未聚焦窗口不响应不该响应的键 | ✅ | Local responder chain only; controller only receives `keyDown` when it is first responder; no global monitor |
| 支持的按键被处理，未支持按键不被错误吞掉 | ✅ | Arrow keys routed (lines 80–82, 120–135); unsupported keys fall through to `super.keyDown` (line 90); `performKeyEquivalent` returns false for unsupported (line 96); `testUnsupportedKeyFallsThrough`/`testPerformKeyEquivalentFallsThrough` pass |
| 触控板 scrollWheel 路径未回归 | ✅ | No change to `PagingSurface.scrollWheel`/`handleScrollInput`; full 501-test suite (incl. PagingSurface trackpad tests) green |
| keyboard navigation 与 settle/interruption 不产生双重 commit | ✅ | `KeyboardPageTurner.turn` guards `core.state == .idle` (line 51); non-idle → `.deferred`; `testDeferredDuringSettleNoDoubleCommit` asserts `commitCount == 1` |
| 页面切换期间焦点视觉状态没有落到旧 page host | ✅ | `handleArrow` unhighlights old cell before recycle (lines 126–135, 138–151); `testCrossPageFocusVisualLandsOnNewPage` asserts old `isFocused == false`, new `isFocused == true` |
| teardown 后按键/异步回调零 UI 写回 | ✅ | `applyFocusVisual`/`applyLayout` guard `!surface.isTearingDown` (lines 110, 139); `testTeardownZeroUIWriteback` passes |
| resize 后焦点仍映射到正确 cell 或按文档化规则迁移 | ✅ | `applyLayout(_:)` delegates to `AppGridFocusModel.apply`; `testResizeFocusStillMapsToCorrectCell` passes |
| 跨页仅在 `core.state == .idle` 时进行；非 idle 不破坏手势/settle | ✅ | `turn` guard line 51; `testDeferredWhenTracking`/`testDeferredDuringSettleNoDoubleCommit` pass |

## Constraints verified

- **Local responder chain**: `KeyboardFocusController` is an `NSView` subclass added as a subview of `PagingSurface`; `hitTest` returns nil (line 78) so it never intercepts mouse/trackpad. No global `NSEvent` monitor (grep clean).
- **No Accessibility permission**: grep for `AXIsProcessTrusted`/`AXUIElement` clean.
- **No sync disk I/O / icon reads**: grep for `FileManager`/`Data(contentsOf`/`NSWorkspace.open` clean.
- **No per-key view-tree rebuild**: `setFocused` only mutates layer properties; controller only unhighlights/highlights two cells.
- **Keyboard cross-page via legal seam**: `KeyboardPageTurner.synthesizeFling` (lines 66–80) drives `handleScrollInput` → `ScrollInputMapper` → `PagingCore`; never touches `visualOffset`/`committedPage`/private state. `PagingCore` frozen (mtimes predate Worker B session).
- **Unsupported keys not swallowed**: fall through to `super.keyDown` / `performKeyEquivalent` returns false.
- **Focus visual incremental**: layer-only mutation; no view-tree rebuild.
- **Accessibility/visual/launch-object consistency**: `setFocused` sets both layer visual and `setAccessibilityFocused`; cell resolved via renderer to the bound app.
- **Neutral naming / privacy**: no app name/bundleID/path/URL/icon data/user-input literals (grep clean); `AppID` opaque.

## Forbidden trees untouched

No git baseline exists (all top-level entries untracked), so verification used file mtimes. Only the 5 new files were modified during Worker B's window (2026-08-29 22:40–22:50). All forbidden trees predate it:

- `Sources/PagingCore/` — mtimes 08-28 → 08-29 21:16 (before 22:44) ✅
- `Package.swift` — 08-28 20:42 ✅
- `Docs/`, `PROVENANCE/` — no files modified in window ✅
- `Tests/AppGridUITests/`, `Tests/PagingCoreTests/` — no files modified in window ✅
- T-1C-A focus files — 22:34–22:35 (Worker A, before Worker B) ✅
- `AppDelegate.swift` (14:04), `AppLaunchController.swift` (08-28) ✅; `KeyboardLaunchAdapter.swift` does not exist (T-1C-C deliverable, out of scope) ✅

No conflict markers or trailing whitespace in the 5 new files.

## Findings

### F1 — QUESTION: Focus model moves to target page before the page commit
- **Location**: `Sources/PagingPrototypeApp/KeyboardFocusController.swift:126–135`; `Sources/PagingUI/KeyboardPageTurner.swift:48–60`.
- **Observation**: On a cross-page arrow, `handleArrow` calls `pageTurner.turn(...)`; `turn` synthesizes the fling and returns `.turned(target)` **immediately**, before the settle animation commits. The controller then sets `focusModel = AppGridFocusModel(current: target)` and applies focus visual. The actual `committedPage` changes only when the settle completes (asynchronously via the frame driver).
- **Impact**: If the settle is interrupted by a trackpad gesture (D4 takeover) before commit, the focus model points to a page that may not be displayed. The integration layer (T-1C-C) must reconcile focus after settle/interruption. Within the keyboard flow the fling is velocity-forced (12000 px/s ≫ threshold 800) and deterministic, so the commit normally lands on `target`; this is an edge-case robustness concern, not a defect in the tested path.
- **Recommendation**: Confirm T-1C-C reconciles focus on settle completion/interruption (e.g., re-apply layout / re-validate focus identity against the committed page), or gate the focus-model update on the actual commit.

### F2 — MINOR: Cell reuse does not reset the focus visual
- **Location**: `Sources/AppGridUI/AppGridCellFocus.swift:21–33`; `Sources/AppGridUI/AppGridCellView.swift:67–75` (`clearContent`); `Sources/AppGridUI/AppGridPageView.swift:134–147` (`clearForReuse`).
- **Observation**: `setFocused` mutates `layer.borderWidth/borderColor/backgroundColor`. `clearContent`/`clearForReuse` clear token/name/icon/accessibility but do **not** reset the layer border/background. The keyboard flow is safe because `handleArrow` explicitly unhighlights the old cell before the page host is recycled. However, a focused cell recycled by a **non-keyboard** page change (trackpad fling, catalog refresh) would retain the focus border on a cell now bound to a different app.
- **Impact**: Violates prompt §4.3 "焦点视觉状态不能因为 cell 复用而残留在错误的 app 上" for the trackpad/refresh path. Not triggered by the keyboard flow under test; not an explicit T-1C-B acceptance criterion.
- **Recommendation**: Reset the focus visual in `clearContent` (or have the controller clean up on page/state changes), so reuse never leaves a stale focus border.

### F3 — MINOR: `testUnsupportedKeyFallsThrough` does not verify real responder-chain fall-through
- **Location**: `Tests/PagingUITests/KeyboardFocusControllerTests.swift` (`testUnsupportedKeyFallsThrough`).
- **Observation**: The test sends `keyCode 0` and asserts focus is unchanged and `onActivate` not called. It does not verify the key actually reaches the next responder (no window/responder chain in the test harness), so it only proves the controller does not handle the key, not that AppKit fall-through occurs.
- **Impact**: Test-quality gap; the code path (`super.keyDown`) is correct by inspection.
- **Recommendation**: Optional — add a harness that installs a next responder and asserts the event is forwarded.

### F4 — QUESTION: No focus highlight during cross-page settle
- **Location**: `Sources/PagingPrototypeApp/KeyboardFocusController.swift:138–151`.
- **Observation**: On cross-page, the old cell is unhighlighted and the new page host is not yet live, so `cell(for: identity)` returns nil and no highlight is applied until `refreshFocusVisual()` is called after settle. There is a brief window with no focus highlight.
- **Impact**: UX gap, matches the Worker's documented timing; does not violate the "no focus on old page host" criterion.
- **Recommendation**: Accept as documented, or highlight a placeholder/adjacent live cell during settle if desired.

## Likely root cause (for the findings above)

None of the findings are defects in the tested keyboard path. F1/F4 are consequences of the documented design decision to move the focus model to the target page immediately and apply the new cell's highlight only after settle. F2 is a lifecycle gap in the focus-visual reset on cell reuse. F3 is a test-harness limitation.

## Recommended solution

- F1: Confirm T-1C-C reconciles focus on settle completion/interruption.
- F2: Reset the focus visual in `AppGridCellView.clearContent` (or equivalent) so reuse never leaves a stale border.
- F3: Optional — strengthen the fall-through test with a next-responder harness.
- F4: Accept as documented, or add a settle-time placeholder highlight.

## Affected scope

- `Sources/PagingUI/KeyboardPageTurner.swift`, `Sources/PagingPrototypeApp/KeyboardFocusController.swift`, `Sources/AppGridUI/AppGridCellFocus.swift` and their tests. No changes to `PagingCore`, `Package.swift`, `Docs/`, `PROVENANCE/`, or other test dirs.

## Regression risks

- Low. Full 501-test suite green; debug and release builds pass; forbidden trees untouched; no global monitor/permission/sync-I/O introduced.
- F2 is the only latent risk (stale focus border on reused cells via non-keyboard page changes); it does not affect the keyboard flow under test.

## Confidence

High. All acceptance criteria verified by independent test execution and code inspection; forbidden-tree integrity confirmed via mtimes; constraint/privacy scans clean.

## Verdict

**PASS**
