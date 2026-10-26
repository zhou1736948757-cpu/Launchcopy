# Sources path titles: bounded Settings layout repair

Date: 2026-10-19. **SOURCE/TEST ACCEPT; bounded native width check passed. Full goal incomplete.**

## Reproduction and repair

One unshown controller test reproduced Sources tab-content growth from 500 to 2798pt for an unselected long synthetic menu title in English, Japanese and Chinese (RED: one test, three failures). That initial test did not measure NSWindow.frame; returning Appearance did not fail. It therefore establishes content growth, not the exact cause of the older visible cross-tab window width.

The five-line production change in `Sources/PagingPrototypeApp/AppSourcesSettingsView.swift` lowers horizontal compression resistance and enables middle truncation for the closed popup. Full menu titles, accessibility labels and represented path identities are retained. No global width cap, window reset, path-storage, main-grid, folder, cache or paging change.

The final new `SettingsSourcePathWidthTests.swift` asserts frame, content rectangle and tab widths against the initial 500pt baseline in all three languages, with short/long paths selected and unselected, plus complete titles/path identities/menu AX labels and unchanged customRootPaths. It never orders a window. The return-to-Appearance check resets placeholder selection first; selected-long-path cross-tab coverage is separately supplied by Main's native check, not this test.

## Verification and delivery

- Frozen **517 inputs** match; exact delta from the prior 516 is five production lines plus the new test. `source-delta-r1.json` verifies removal of exactly those lines restores the prior file hash.
- Focused **56/0**, full **3139/0**; Debug, actual Release, package and packaged resource probe **365 keys × 3 languages** passed serially. `git diff --check` passed; existing dirty history retained.
- Independent read-only Turing review: bounded SOURCE/TEST ACCEPT, no blocker; not a native replay or independent freeze verification. See `../reviews/SETTINGS_SOURCE_PATH_WIDTH-r1.md`.
- New unsigned, uninstalled candidate: `.build/candidates/settings-source-width-rc-20261019-r1/LaunchcopyUITest.app`; executable SHA **de3b27a6ff83bbdc93ecfd16fe630c4820636f2f5ec98f8969eb91ee296b0964**. Strict v2 sources-v1 profile; only two new independently authored metadata-only fixture apps, no old profile/data imports.

## Native check and restoration

Main normally quit visual PID17189 and verified absence. Finder opened new candidate PID26988. Through the real Sources chooser, Main added ONLY the new candidate's Extras directory to a draft, opened the popup and selected its full long path. Inline screenshot showed a compact Sources window and abbreviated closed control; the menu and AX value retained the full path. Switching to Appearance retained the compact window (inline 1000px-wide image), and switching back retained the selected full source path. No manual resize/reset or Appearance edit. Sources Apply was never clicked; this was a presentation check, not another saved-root gate. The two metadata fixtures remain byte-identical.

Main normally quit26988, verified exact absence, then restored the unchanged human visual demo through Finder as PID29854: ordinary main window, empty search, folder closed, wallpaper READY. This dc4ed visual binary does NOT contain the new Sources width repair; it preserves the existing large-icon demo configuration rather than importing user data into the fresh Sources test profile.

## Limits and next action

This repair's visible native check is Chinese; its EN/JA coverage is unshown AppKit. Earlier native EN/JA Appearance checks belong to the prior b88e candidate and must not be silently reassigned. No private wallpaper screenshot was saved. No formal user data, reference source/assets, OS/security, signing/install, Git history or process signals changed.

Human large-icon aesthetics, matched physical performance, 120Hz/multidisplay, real IME/spoken VoiceOver, intermittent wallpaper causality and reserved feature semantics remain separate. Next concrete work: continue the current requirements matrix's unmatched interaction/accessibility gates; do not rerun already-closed Sources saved/draft checks without a relevant code change.

Evidence directory: `.build/verification/20261019/settings-width-investigation/`, especially final-verification-r1.json, source-inputs-r2.json, source-delta-r1.json, focused-r1/r2/r3.log, full-r1.log and serial-jobs-r1.json.
