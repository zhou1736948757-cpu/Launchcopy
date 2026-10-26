# Library folder destination choices — delivery checkpoint

Date: 2026-10-15. Full objective remains ACTIVE / incomplete.
Status: CODE_VALIDATED; independent bounded SOURCE PASS; Main bounded native popup/save/restart PASS. No independent live native Reviewer or physical performance acceptance is claimed.

## Defect and actual counterexamples
Library iterated the storage folder array, included the current owner and always offered move-out; it did not use canonical top-level order or the grid's collision-safe labels. Title-based popup insertion also collapsed duplicate titles: an actual AppKit sheet could lose a destination or the move-out operation, not merely display ambiguous text.

Before the production patch, successful compilation followed by actual AppDelegate/injected-presenter sheet execution produced:
- Three cases / seven assertion failures: canonical order/owner/title mismatch, bogus top-level move-out, useless no-choice modal.
- One operation-title collision case / four assertion failures: a folder named exactly like the translated move-out operation did not retain both correct actions.
These are unshown AppKit integration tests, not native pointer or physical-user evidence. Original bodies and RED logs remain retained.

## Three-input repair
- `AppFolderAssignmentMenuController.swift`: extracted the existing pure reference/owner/top-level/ordinal algorithm into internal `FolderAssignmentChoices`; grid retains its exact title algorithm and all immutable cell/revision/hidden/read-only protections.
- `AppDelegate.swift`: Library consumes the same choices. Independent NSMenuItem objects preserve each typed action even when a literal folder title matches move-out. Folder destinations precede a separator and member-only move-out; no action means no sheet. Initial selection is a real action, never a separator. Writer epoch/directory, request/generation, exact layout, revalidation and shared mutation/commit are unchanged.
- `MenuMutationLifecycleTests.swift`: five actual-sheet regressions added; all eight prior methods retained. The identical-writer replacement test now selects the typed FolderID rather than assuming popup index1; old rejection/fresh enqueue assertions remain.

No public protocol, layout schema/mutation, new navigation/gesture, frame work, scan, icon request or persistence path was added. Only three of455 frozen inputs changed; other452 unchanged, including prior cold-gesture fix, Core/PagingUI, domain mutations, resources/scripts.

## Executed verification
| Gate | Main result |
| --- | --- |
| Primary RED | 3 XCTest /7 assertion failures, compilation successful |
| Collision RED | 1 XCTest /4 assertion failures, compilation successful |
| Focused | 189 XCTest /0 failures,5.200s; actual lifecycle suite13/0 |
| Full | 2693 XCTest /0 failures,52.863s; trailing SwiftTesting zero footer excluded |
| Debug | explicit build exit0 |
| Release/package | unique packaged test entry exit0; actual Release build and packaged resource probe |
| Packaged resources | positive288 keys/signatures ×3 languages; no new negative resource probe claim |
| Integrity | all455 final hashes and executable reverified after native actions; git diff check pass |
| Independent Ramanujan | bounded SOURCE PASS, noP0–P3; all455 hashes/three diffs verified; Main RED/focused/full logs inspected. Reviewer tests/build/native/process executions0; closed. |

## New candidate
`/Users/mac/Projects/Launch_Copy/PagingPrototype/.build/candidates/library-folder-choices-rc-20261015-r1/LaunchcopyUITest.app`

Executable SHA256: `252ec673581b1c3d0c54c1fee9ce1080a89691a0fd114e93ebe7c2096b57cba3`.
Source freeze: `.build/verification/20261015/library-folder-choices/source-inputs-final.json`,455 entries, SHA256 `0c06c767c6f0ef418811454ff01c9bfb90f36c21678ba158083ba55a69b7d083`.
Previous candidates retained. No install, explicit signing, notarization, publish, commit, reset/clean or process kill.

## Main actual native transaction
1. Before first launch only, authored a new candidate-local test profile: ten Info-only apps, five valid two-member folders, three titled Same, one literal Same(1), one titled exactly the Chinese move-out operation. Stored folder array A/B/C/D/E differs from canonical top-level C/D/E/B/A. Own schema1 seed/checksum/write10/layout4 retained; no existing profile/layout overwritten.
2. PID90621 actually loaded all five expected folders. Temporarily enabled Library via native settings from defaultOff; All10, selected Choice Beta, whose canonical owner is A.
3. Real Organize popup AX exposed exact sequence: `Same (2)`, `Same (1)`, operation-named folder, `Same (3)`, move-out operation. OwnerA excluded, all four destinations plus the operation retained. The sheet-target screenshot cropped the extended menu, so it is **not** separate visual proof of the separator; unshown integration tests/source prove separator construction.
4. Selected actual `Same (3)` and clicked native Save. Actual journal write11/layout5 placed Beta at the end of folderB (Gamma, Delta, Beta), dissolved A into remaining Alpha at its canonical position, and preserved all other groups/order. All ten refs occur exactly once. Library selection stayed on Beta.
5. Back showed targetSame3 and top-level Alpha. Restored LibraryOff via native settings, query empty; normal menu Quit/exact process absence.
6. Same candidate genuinely restarted as PID92276. Grid restored four folders plus Alpha with Library entry absent. Opened the target icon: actual members Gamma, Delta, Beta; Escape closed it. A preceding plain AX-caption click did not open it; no product defect inferred from that routing attempt.
7. Journal payload/write11 unchanged across restart. Final normal menu Quit/exact executable absence; no post-Quit app query. Own ten-app fixture and accepted test layout remain as controlled artifacts, not reset/deleted. No fault, job, agent or own test instance remains.

Native receipt: `.build/verification/20261015/library-folder-choices/native-choices.json`; authored initial layout: `native-seed-layout.json`. This proves only the stated native pointer/save/restart transaction. It is not arbitrary layout import, broad folder UX, spoken VoiceOver, physical paging/gesture or all-locale acceptance.

Wallpaper stayed loading in both process observations. Prior warm-ready recovery is still historical and not a causal repair. No OS wallpaper/privacy/security setting was changed.

## Next authorized work / remaining objective
Next concrete approved defect: appearance persistent-store factory failure silently falls back to an in-memory Saved result. Reproduce that actual construction branch and reject false persistence success through existing failure presentation, without changing schema or adding a session-only feature.

Full reference-experience parity, human IME/VoiceOver/physical performance/120Hz, unresolved long-tail causality and unconfirmed capacity/destructive/usage/extra-gesture decisions remain open. Do not mark the goal complete from this bounded fix.
