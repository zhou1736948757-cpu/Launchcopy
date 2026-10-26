# Folder First Escape After Search — Native Counterexample

Date:2026-10-17
Status: **REPRODUCED NATIVELY / SOURCE PATH IDENTIFIED / AUTOMATED RED AND REPAIR PENDING**

## Exact context and observations

Isolated unsigned candidate `.build/candidates/icon-load-replacement-rc-20261017-r1/LaunchcopyUITest.app`, executable929e7616311a5f7af3dbcecad44cc7b2f341049cbf282ab7414e0159d613b3d1. Ordinary non-topmost2000×1400px test window, synthetic40Info-only apps with35-member folder. No real app launch or formal data.

1. Click actual search field; type synthetic query `36`. AX shows only Dense App36 and search field editor focused.
2. Command-A / Backspace clears query and restores original grid; search editor remains first responder.
3. Click real folder glyph. Folder opens15members/page1of3, but AX focus remains search field. Next button reaches page2/members16–30, focus still search field.
4. First Escape changes focus to window/root but folder remains visibly open. A fresh full AX+screenshot confirms page2 and15members still present; this is not inferred from a transient diff or animation timeout.
5. Second Escape closes folder and leaves launcher.
6. Negative/control path: immediately reopen folder from root with no search-editor ownership; first Escape closes folder.

Current final state is main grid, empty query, folder closed, latest929e candidate running. Structured evidence `.build/verification/20261017/icon-load-replacement/native-handover-r1.json`. No personal screenshot file saved. Current wallpaper loading/black remains unrelated unresolved issue.

## Preliminary source explanation (not an automated RED yet)

- `Sources/PagingPrototypeApp/AppSearchController.swift:control(_:textView:doCommandBy:)` routes cancelOperation to `handleEscape`. Empty-query handler calls `exitSearchAndRestoreFocus`, consumes the command and restores the keyboard responder, without checking an open folder.
- `AppDelegate.swift:openFolder(folderID:animatedFromPointer:)` finishes folder title state, configures modal state/visuals and starts optional motion but does not explicitly hand off the search field editor's first-responder ownership.
- `KeyboardFocusController.swift:handleEscape` already has title-edit > folder-close > grid/hide priority, but it cannot apply that priority when the search editor consumes the first key.

No input-related production code changed in the icon ownership repair. This is a newly observed path, NOT proof that IconPipeline caused an input regression, or that the earlier user's accepted opening/gesture experience was invalid.

## Required bounded follow-up

Reproduce against real AppDelegate/search/keyboard/window wiring in an isolated in-process AppKit regression (no OS event posting), then implement the narrowest responder/command-ownership correction. Preserve empty/nonempty search Escape semantics when no folder is open; preserve query and selection/draft, marked-text composition, title editing priority, deferred keyboard selection (pointer opening must not invent a blue highlight), drag/ESC, retained-exit/reversal and Cmd-F behavior. Do not simply clear search or synthesize a second Escape. Check all open paths, current owner and mounted-window lifecycle rather than stale captured closures. No broader capacity/physics/store change.

Run focused/full tests plus builds/package/source review after any repair; verify exact new candidate with this native sequence and no-search control. This is an existing modal keyboard ownership defect and can be repaired within maintenance scope independently of the still-pending row/column feature. No need to repeat the already sent capacity question, change OS settings, copy reference code or request a new product design merely for this bug. Current native verdict remains PARTIAL, not all-gates PASS.

## 2026-10-17 — Superseding repair evidence

The recorded old-build failure remains historical. New6886de43 candidate completed the identical search-clear/open/next/single-Escape native sequence successfully, plus Cmd-F and no-folder search controls. Specific defect CLOSED for that tested path; full evidence `Workflow/results/FOLDER_SEARCH_RESPONDER_RESULTS.md`. Real IME/physical/performance and unrelated wallpaper remain unverified/unresolved.
