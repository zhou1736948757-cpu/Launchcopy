# Library drawer focus repair

Date: 2026-10-19
Status: VERIFIED_BOUNDED_REPAIR; full LaunchBetter-on-Launchcopy objective remains incomplete.

## Defect and minimal implementation
Independent read-only audit by Kepler found that responsive Library layout hides the results scroll before checking whether its table owned first responder. AppKit can synchronously resign the hidden table to the window, erasing the evidence needed to move keyboard focus into the visible details drawer. This affects narrowing a side-by-side presentation and restoring details for a surviving selection after loading.

`Sources/PagingPrototypeApp/AppLibraryView.swift` now captures results-table focus before layout/visibility changes, alongside the existing category focus captures, and uses that captured ownership at the existing close-details-button handoff. No new UI state, timer, event route, persistence format, page geometry or paging parameter. This is a routine correction of the approved Library keyboard contract, not a new feature.

## Regression evidence
`Tests/PagingUITests/AppLibraryViewTests.swift` adds three mounted, unshown AppKit-window methods:
- Wide details plus focused results ->700/360-wide drawer: focus moves to the visible details close button, with selection retained.
- Nil/loading ->same surviving identity: automatic drawer restoration transfers the displaced results focus into details.
- Marked search and an independently settled visible details control retain their own focus through resize.

Historical red-r1 executed3 methods/8 failures. Its negative-control fixture initially reused details after legitimately committing marked text and revoking that selection. Rebuilding a settled selection for the independent visible-control case corrected the fixture; no product behavior was weakened. Corrected red-r2 executed3 methods/2 failures in8.443s: both intended positive paths failed, negative controls passed. The resize method throws at its first700 failure, so old-source360 was not independently reached in that RED run.

After the patch, focused45/0 in2.746s; full3098/0 in68.864s (runner wall71.521s). Debug build0.44s; actual Release executable build18.50s; packaged resource probe0.13s; package wall21.840s. Strict native-test entry and361 localization keys/signatures across three languages passed. Actual nonzero XCTest counts are used, not the separate zero-test Swift Testing footer.

Kepler independently accepted the two-file source/test repair without actionable findings. Report: `Workflow/reviews/LIBRARY_DRAWER_FOCUS-r1.md`. Reviewer performed no test/build/UI execution and is closed. Main alone ran serial verification and native testing. A verification-runner root guard initially refused before any Swift/package job; corrected the parent index and then started the successful serial job. That startup issue did not alter production source or acceptance.

## Exact candidate and native evidence
Unsigned/uninstalled candidate: `.build/candidates/library-drawer-focus-rc-20261019-r1/LaunchcopyUITest.app`.
Executable SHA-256: `658bd6b98992fabba2bcb9e5ad35e7bd25b324a6f14e1afe422b6b2f24382038`.

Main normally quit the previous own test and verified exact executable absence before opening this exact new path. Only the82 independently authored fixtures, layout and capacity were seeded. No formal data, previous preferences, activity, cache, locks or Finder metadata were imported.

Actual shown-window results:
1. At2000×1400px, a unique own-fixture query, Down selection and explicit Details established side-by-side results/details. Resizing to1400×1000px exposed the drawer, AX reported `library.details.close` focused and its blue focus ring was visible. Space closed only details and returned to selected results.
2. Reestablished the wide presentation, then resized to800×1000px. The same details-close focus was reported, compact category picker appeared and query/selection survived. Native details scrolling reached value1 and visibly exposed the bottom organization/removal controls without clipping; no destructive action was invoked. Space again closed only details.
3. With details open, explicitly focused Library search at800×1000px, then restored2000×1400px. AX retained `library.search` and the exact query: resize did not steal ordinary search focus.
4. Library Back restored the main-grid query. Cleanup disabled Library, left trackingOFF throughout, cleared only the test query and restored the original ordinary non-topmost2000×1400px window.

Final own process PID15521; main page, folder/settings closed. NamesON, blur28, icon54, font12,6columns×5rows, FollowSystem. All511 frozen inputs and all87 seeded files match after native testing; no probe is running and no activity file was created. Wallpaper still reported loading in this new run; intermittent wallpaper cause is NOT fixed by this work.

## Boundaries and next work
Native focus handoff is verified for the two shown viewport transitions above, not a universal screen/OS/accessibility claim. Loading/restoration was tested through real unshown AppKit controls, not forced as a native filesystem experiment. Real Chinese/Japanese IME, spoken VoiceOver, matched physical60/120Hz/multidisplay/energy/RSS, original folder-scroll and wallpaper causality remain separate. No human feature acceptance or full parity completion inferred. No reference source/assets, OS/security changes, signals, installation/signing/publishing or Git-history operation.

Authoritative receipts: `.build/verification/20261019/library-drawer-focus/{source-inputs-r1.json,source-delta-r1.json,red-r1.log,red-r2.log,focused-r1.log,full-r1.log,serial-jobs-r1.json,native-fixture-r1.json,native-results-r1.json,final-receipt-r1.json}`. Prior app-removal actual Trash/recovery receipts remain valid for their older exact candidate; this stage does not relabel those operations as repeated on the new binary.

Continue only an unclosed approved acceptance item or a concretely demonstrated defect. Remaining reserved page-model/gesture decisions are not automatically authorized. Full objective remains intact and incomplete; this goal turn made concrete implementation, automated and native progress.
