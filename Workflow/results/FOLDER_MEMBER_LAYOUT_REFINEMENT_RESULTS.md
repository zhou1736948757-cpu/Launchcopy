# Folder member layout refinement — delivery

Date: 2026-10-19. **Bounded SOURCE ACCEPT, automated verification and scoped native layout checks complete. Full parity remains incomplete.**

## User request and implementation
The user explicitly asked to refine folder layout alongside the main grid. Folder members now center their icon/name stack within each actual cell, with6pt gap and6pt minimum outer padding instead of separating the name from a top-aligned glyph as rows grow. Regular, reused and transient swipe cells use the same explicit context. Shared finite geometry accepts an optional actual fractional icon limit for durable previews; a32.5pt captured glyph stays32.5pt without widening its caption gap or changing a saved preference.

Main and standard default geometry, panel ratios, maximum5×3 capacity, ordering, title/footer, source-origin glass/motion, inner/outer paging parameters, icon pipeline and preference schemas/defaults remain unchanged. The existing base/folder size preference is still32–64/default48; no forced migration or extra slider.

The related move-out repair retains pre-collapse capture but uses capture-free elevation after host switching. A static review found the old duplicate post-collapse source read; this is not a measured hitch cause. No new per-pointer/frame capture, icon request or rebind is added.

## Ownership and exact change scope
Main: `Sources/AppGridUI/GridItemAppearance.swift`, `FolderOverlayView.swift`, `DragUI/DragUIVisuals.swift`, and new `Tests/AppGridUITests/FolderMemberContentLayoutTests.swift`.
Worker Euclid: `Sources/AppGridUI/DragUI/DragUISessionCoordinator.swift`, `Sources/PagingPrototypeApp/AppDelegate.swift` move-out callback, and new `Tests/AppGridUITests/MoveOutCachedElevationTests.swift`. Main explicitly initialized NSApplication for its unshown window test. No legacy tests were weakened.
Independent Goodall read-only review: bounded SOURCE ACCEPT, no actionable issue. Review is not a test run/native replay/physical performance certification. All subagents are closed.

## Verification and artifact
- **519 frozen inputs**: five intentionally changed production inputs and two new test files relative to the517input baseline; all other512 baseline inputs retained.
- Focused **61/0** (initial60/0 before the extra nonfinite case); full **3147/0**, eight new test methods. Debug, actual Release, package and packaged resource verification **365 keys × 3 languages** passed serially. `git diff --check` passed.
- Tests cover centered normal/tall rows, hidden labels, every supported font/tiny geometry, malformed bounds/limits,48/64/fractional preview fit after source clear, regular/reused/swipe context agreement, layout-only request budget, and cached elevation through host changes/source reuse/teardown.
- New unsigned, uninstalled candidate: `.build/candidates/folder-member-layout-rc-20261019-r1/LaunchcopyUITest.app`.
- Executable SHA-256: **3f01be1d69d4055f2ca1229fad088d0bbf4a8d85f580e82b472c59528413de3e**.

## Native observations and current runtime
Main normally quit own old visual29854 and verified absence. The fresh candidate uses reserved v1 gui entry/fake services/ordinary window. Its fresh profile copies ONLY249 hash-verified, independently authored fixture files:82synthetic apps with authored icons/inert probes, own canonical layout and capacity. No reference assets, real apps, old Appearance/Library/activity/cache/lock data were imported or existing profile reset.

Finder opened PID44539. Main observed the35-member folder's5×3 grid and all three pages at the original48pt preference, with icons loaded and names grouped. Main then used the actual live Appearance control to set ONLY this new isolated profile's folder/base preference to64; main stayed80, font11, blur18, outer6×5. The control reported saved; larger folder icons and consistent three-page layout were observed. This is an explicit test preference, not a changed product default.

Main normally quit44539, verified exact absence, and Finder reopened the same binary as **PID52219**. The larger folder rendering returned. Current handoff: ordinary window, empty search, Settings closed, **folder open on page1/3**, wallpaper READY. The old dc4ed demo remains closed/preserved. Both old and new249whitelisted seed files remain byte-identical; folder membership and top-level ordering are unchanged.

Two CUA-generated move-out attempts on last member/page3 produced no observed commit (one before, one after restart). Pointer admission/threshold/preview were not established. This is **INCONCLUSIVE_NO_COMMIT**, not a native drag PASS and not a proven application root cause. No layout restoration was needed; no speculative routing repair followed. Future work should discriminate a native-control drag against this custom route and capture neutral admission state before changing behavior. One temporary CUA noWindowsAvailable observation recovered on the same live44539 process; no crash or restart was inferred from it.

## Remaining gates
Native page buttons/stills and saved restart are not physical two-finger performance, moving preview, create-folder/reorder/move-out acceptance, real IME, spoken VoiceOver,120Hz/multidisplay or human aesthetic acceptance. Existing intermittent paging/wallpaper causality remains unresolved. No private wallpaper screenshot was saved. No formal user arrangement, reference material, OS/security, process signals, install/sign/publication or Git history changed.

Next concrete action: current-build input-admission discriminator for generated drag, with owned native slider control and exact preference restoration; continue the requirement matrix without inventing reserved gesture/page semantics. Full objective remains ACTIVE/incomplete.

Evidence: `.build/verification/20261019/folder-member-layout/` (source-inputs-r1.json, source-delta-r1.json, focused-r1/r2.log, full-r1.log, serial-jobs-r1.json, native-fixture-r1.json, before-drag-logical-r1.json, native-drag-attempt-r1.json, final-verification-r1.json). Independent review: `Workflow/reviews/FOLDER_MEMBER_LAYOUT_REFINEMENT-r1.md`.
