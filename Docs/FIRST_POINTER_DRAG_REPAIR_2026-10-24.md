# First pointer drag continuity repair

## Problem and outcome
User reports first system three-finger pointer drag ignored, second effective. A concrete production path cancels any ordinary pointer transaction on a no-change pager-idle/catalog non-busy callback. Fix unnecessary cancellation without claiming this is the sole physical cause.

## Contract
A valid pressed/dragging/edge-pending transaction survives an idle boundary when the provider has no pending catalog, folder, management, expected-layout or query changes. Actual presentation changes, stale generations, Escape, focus loss, teardown and title/search gates retain existing invalidation. Click-only search fallback and blank presses do not acquire a durable transaction and keep existing cancellation. No synthetic mouse-down, threshold or paging engine changes.

## Implementation and maintenance
The composition root owns invalidation. Generalize the existing collapsed-member exception to real controller transaction ownership rather than a visual folder flag. Keep the ordinary pending commit and focus/status reconciliation; real update paths still cancel. Do not modify four-finger services or macOS drag settings.

## Acceptance
Reproduce old failure with production-installed idle callback inserted after the first pointer-down and after threshold on main and open-folder paths; verify first release commits once without needing a second attempt. Exercise real main-page settling. Real pending snapshot must cancel with zero late commit; retain search-click, Escape and focus-loss negatives. Run focused and complete XCTest, Debug and strict Release packaging, independent bounded review. Exact isolated sibling candidate/profile handover only after gates. Physical user recheck remains separate.

## Risks and unresolved causes
AppKit inactive-window first-mouse policy and opening-transition rejection remain separate hypotheses. Apple NSView documentation confirms default inactive first-down activation-only, but B1 manually routes main cells and this alone does not establish the reported cause. No speculative first-mouse policy change in this repair. Apple source: https://developer.apple.com/documentation/appkit/nsview/acceptsfirstmouse(for:) .

## Verification refinement
Exact full canonical order is asserted for same-page main insertion and real cross-page insertion, and folder member order is asserted together with unchanged top-level order. This strengthens the original commit/token checks without changing production behavior, thresholds or accepted interaction semantics.

## Manual unlock resolved / native handover complete
User clarified first drag also fails on main grid and explicitly confirmed manual unlock. Old owned39718normallyQuit via own menu; exactabsence verified. New ownedPID89871, `/Users/mac/Projects/Launch_Copy/PagingPrototype/.build/candidates/integrated-preview-rc-20261023-r1/LaunchcopyPreviewFirstDragFix.app`, SHA03b28185ed97685f114d41451f5d1ffdb8c41febba89ede22b05a298e2a9b817 verified. All5non-wallpaper profile file hashes/modes remain identical before oldQuit and after newstart; same candidate/integrated namespace retains arrangements/preferences without import/reset. Original canonicalmanifest exact; unique sidecar retained.

Native ordinary main window/wallpaperREADY/Librarymenuenabled observed; menu canceled, settingsclosed. No real-app launch/drag/grouping mutation by agent. FullR2 3662/0,focusedR3 92/0,595inputs stable; production/build/reviewR1 bytes unchanged by test-only exact-order refinements. Historical source-only reviewerPASS is not a new native/physical PASS. Prior desktop-lock blocker is resolved, but overall parity and actual first-three-finger acceptance remain unproved. User asked once to try first main drag without click prewarm, then first folder drag. Next action is handle actual result, not redundant build/static audit.

Authoritative currentreceipt `.build/verification/20261024/first-pointer-drag/final-native-ready-r1.json` supersedes wait/blocked receipts, which remain history.
