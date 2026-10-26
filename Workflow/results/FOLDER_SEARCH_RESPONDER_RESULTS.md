# Search-to-Folder Responder Handoff — Results

Date:2026-10-17
Status: **BOUNDED DEFECT REPAIRED: SOURCE / EXECUTED TESTS / EXACT-CANDIDATE NATIVE SEQUENCE VERIFIED**

## Actual defect

On the previous929e candidate, searching then clearing and clicking a folder left the background search field editor as first responder. The first Escape only exited search focus; the folder stayed visibly open, and a second Escape was required. The root/no-search control needed one. Original native evidence and source explanation remain in `Workflow/results/FOLDER_ESCAPE_AFTER_SEARCH_REPRO.md`; this was not attributed to the icon pipeline's unrelated change.

## Narrow repair

In `Sources/PagingPrototypeApp/AppDelegate.swift:openFolder(folderID:animatedFromPointer:)`, preflight an existing folder, then negotiate the native responder handoff only when this owner's current search field/editor owns this owner's actual window. Transfer to the existing keyboard controller before modal state/visual opening. Refusal returns without opening the overlay. After callbacks, window/search/keyboard/assembly/folder-state identities must still match, and folder data is resolved fresh.

No query clearing, query-generation update, forced marked-text cancellation, synthetic second key, selection invention or global Escape interception. Existing missing/mismatched window and unrelated-responder paths retain their prior behavior; this is not a universal opening prohibition. Existing pointer keyboard bookkeeping happens before the owner callback and is not rolled back as a new transaction. No folder layout/motion/material, paging physics, source frame, icon/cache, persistence, capacity or public protocol change.

Exactly two existing inputs changed relative466 baseline: the owner source and `Tests/PagingUITests/AppDelegateBoundedRegressionTests.swift`;464 other inputs unchanged, no new manifest entries. Four new tests use real in-process AppKit windows/editors and installed callbacks: actual-responder first Escape, nonempty query/generation/deferred selection preservation, native refusal, and owner-window loss during resignation. The last method is named replacement but actually sets the owner window to nil; nonnil replacement is guarded by source identity comparison, not separately executed. Helpers are private. No OS event posting or system preference changes.

## Actual execution and independent review

- First test compile failed because a new assertion referenced a private member; changed only that assertion to the existing public `focusedFolderMember` getter. This compile failure is not a test RED.
- Actual RED r2: **1 executed method /3failed assertions** (wrong responder, folder still open and mounted after first Escape).
- Focused r1:91/0. Added callback owner checks/fresh entry resolution and the fourth test; final focused r2: **92/0,3.683s**.
- Full r1: **2818/0,53.538s**; actual XCTest, not the trailing zero-test Swift Testing footer.
- Explicit Debug passed0.33s; actual Release passed15.56s; safe package/native-entry static check and packaged localization290keys/signatures ×3languages passed; `git diff --check` passed.

Hegel independent bounded SOURCEPASS/no blocking finding,466 hashes verified, before-diffs checked and existing RED/focused logs inspected. Reviewer executed no tests/build/UI; full/build/package/native remained Main-owned. Review report explicitly preserves real IME and scope limitations: `Workflow/results/FOLDER_SEARCH_RESPONDER_SOURCE_REVIEW.md`. It also discloses initial instruction/memory lookup commands missing RTK before subsequent compliance; no implementation edits by reviewer. All agents closed and jobs terminal; Main+reviewer at most2.

Immutable raw logs, before-copies, manifest and receipts are in `.build/verification/20261017/folder-search-responder/`: `red.log` (compile), `red-r2.log`, `focused-r1.log`, `focused-r2.log`, `full-r1.log`, `debug-r1.log`, `package-r1.log`, `source-before.json`, `source-inputs-r1.json`, `candidate-r1.json`, `native-handover-r1.json`. The original test before-copy was recovered from our own controlled package and hash-matched to the baseline before use.

## Exact candidate and native verification

`/Users/mac/Projects/Launch_Copy/PagingPrototype/.build/candidates/folder-search-responder-rc-20261017-r1/LaunchcopyUITest.app`

Executable SHA-256: `6886de430463ecedd17371d8751843698c36336781d2075eacecca10fb7d947f`.

Unsigned/uninstalled. Old own929e/PID56086 normally quit via observed app menu, exact executable absence verified before new launch; no query of closed binding. New profile seeded after Quit only from own40Info-only synthetic apps plus layout/Library JSON, no wallpaper cache/lock/formal data. New exact candidate running, process in receipt.

Main actual CUA, ordinary non-topmost2000×1400px window:
1. Search `36` ->one synthetic match; clear ->original grid with search still focused.
2. Click actual folder glyph ->15members/page1of3; AX focus now window/root instead of search. Next ->page2/members16–30.
3. **One Escape closes folder and leaves launcher.** This is the original failing sequence, now successful; no replayed second key.
4. Reopen from root; Command-F closes folder and focuses search.
5. Type `36`; Escape clears query and keeps search focus. Next Escape releases empty search focus, leaving launcher.
6. Root/no-search control: open folder then one Escape closes it.

Final state main grid, empty query, folder closed; new candidate intentionally running. All466 source hashes, candidate executable and isolated layout/Library payloads reverified unchanged after native actions. No captured personal screenshot file saved, OS setting/permission, signing/install/distribution/commit/reset/clean/delete/kill or reference-source/assets operation.

## Remaining boundaries

This closes the specific native modal first-Escape counterexample, not all responder/IME/accessibility scenarios or a new physical gesture/performance benchmark. Native refusal/reentrancy are covered by controlled in-process AppKit tests, not real IME composition. A live native AX root focus does not expose the exact responder class; its class ownership is asserted separately in the owner test. No whole objective completion or universal reentrant-state lock inferred.

Wallpaper stayed loading/black in this run; the older intermittent source-open problem remains unresolved. Main-grid3..8 rows/columns remains proposed pending the existing specific confirmation and engineering readability/anchor/resource gates. Other reserved product/hardware/privacy/OS decisions remain unchanged. Full migration objective ACTIVE and incomplete; this stage made concrete source/test/native progress.
