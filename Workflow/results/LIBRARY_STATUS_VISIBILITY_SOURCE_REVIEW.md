# Library catalog-status visibility — independent source review

Date: 2026-10-15

## Verdict

**BOUNDED SOURCE PASS.** No blocking, major, or other must-fix production defect found in the reviewed stage delta. One non-blocking test-discrimination limitation is recorded below. This verdict covers source correctness and bounded test design; it is not GUI, VoiceOver, physical-device, performance, or complete product acceptance.

## Authority and execution boundary

Reviewed the explicit assignment, `/Users/mac/.codex/RTK.md`, project `AGENTS.md`, package structure, relevant plan context, and `Workflow/stage-summaries/2026-10-15-library-status-visibility.md`. This is an existing macOS AppKit/Swift Package application with a composition-root status owner and a separately queued status renderer. The assignment authorizes independent review under the Chief waiver, with Main plus this reviewer (2 total, maximum 3).

All shell invocations were RTK-prefixed. The only file written by this reviewer is this report. No source/test edits, test execution, build, Swift invocation, GUI interaction, process control, agent dispatch, reference-product inspection, raw-asset reading, installation, or commit was performed. Main retains serial runtime verification ownership and the existing dirty worktree is preserved. Reviewer-executed tests/builds/UI checks: **0 / 0 / 0**.

## Frozen input and exact-delta evidence

Compared `.build/verification/20261015/library-category-count/source-inputs-final.json` (450 entries) with `library-status-visibility/source-inputs-final.json` (451 entries):

- Changed: `Sources/PagingPrototypeApp/AppDelegate.swift` only.
- Added: `Tests/PagingUITests/LibraryCatalogStatusVisibilityTests.swift` only.
- Removed: none.
- All 449 non-asset files match the final manifest at review and immediately before report creation. No additional files were found under Sources, Tests, Scripts, or Resources outside the manifest, excluding `.DS_Store`.
- The two raw assets, `Resources/AppIcon-1024.png` and `Resources/AppIcon.icns`, were not opened or rehashed, respecting the assignment. Their recorded hashes are identical between manifests. This is not an independent 451-file byte verification claim.
- All 18 Sources/PagingCore and Sources/PagingUI inputs remain unchanged. AppGridStatusView, package definition, public APIs, hierarchy, and physics are outside the actual stage delta.

Hashes:

| Input | SHA-256 |
| --- | --- |
| Baseline manifest | `9f3ef3247cd5974fc8345cf289f7fd28c3c555dc65995fc59783d01b422cddcb` |
| Final manifest | `ce83e4688592f81de69c0926405d481f9a4043eb21116cbf094618cfc8e93e52` |
| Prior AppDelegate | `e26c89ef77b6cc7fc1ff914281bc4d3d37a633dc46b0abc2fb6c5c8b12e00136` |
| Final AppDelegate | `de331b06d0e955ef77d9860bdbdd97c838422902268cf57dbeda78589ae49ec0` |
| New integration tests | `208bb2ccde690a1083c0dd64d89be7051361d0285e8d0d271b1f7abb031a1cd5` |
| Unchanged AppGridStatusView | `c05af008285a8559bf89ffa70358045d13de53d61b0b1a20e2ff10d39b0cb7c8` |

Independently reversed the identified AppDelegate edits **in memory only** and recovered the exact prior SHA-256 above, matching the baseline manifest. This independently corroborates Main's `app-delegate-delta-proof.json`; the reconstruction was not accepted merely because that JSON says it succeeded. The exact production delta comprises the private committed-visibility latch, its install/teardown reset, the identity-checked render callback, a private visibility projection, and replacement of the prior refresh-time Library hide and unconditional mode-time status hide/show with that projection. The existing teardown callback clearing was already present.

## Source analysis

1. **Committed visibility and pending-state boundary:** AppDelegate.swift:215–235 installs a weak-self/weak-status callback with `catalogStatusView === status`. AppGridStatusView.swift:117–134 writes rendered text, `renderedState`, spinner state, its own `.ready` hidden policy and AX exposure before invoking that callback synchronously. The latch therefore captures the renderer's semantic visibility before the Library mask, rather than inferring visibility from a pending `state` or reading an already masked value in a later queue turn. Equal-state `update` returns without rendering (AppGridStatusView.swift:68–71), which explains why Back must project the retained committed visibility rather than rely on another render.

2. **Queue order and reentrancy:** AppDelegate.swift:253–263 retains coalescing, final-teardown and generation guards. It stages state, reapplies the current committed visibility, then lays out. When a later render completes, its synchronous callback reapplies the Library mask within that same queued render. No new await, nested run loop, client callback, timer, or forced render was introduced between latch capture and projection. Under the existing main-thread/AppKit ownership, both renderer-before-mode and mode-before-render orderings converge on the same mask. The added helper performs only constant-size Boolean/properties work and never scans the catalog or formats strings.

3. **Mode ownership:** AppLibraryOwnerController.swift:106/142 sets `isOpen = true` before `setGridHidden(true)`; close at :161/169 sets it false before `setGridHidden(false)`. AppDelegate.swift:2285–2293 now projects from that authoritative current owner state. The visibility formula at :267–272 is committed-hidden OR Library-open, and sets both `isHidden` and AX element exposure consistently. No pending state can unhide the old Ready label. Committed loading, refreshing, partial failure, empty and no-results remain eligible to reappear when the mode mask is removed.

4. **Replacement and teardown:** Status install increments generation and resets the latch before later queued work can execute; the replaced view is torn down and detached. Old refresh blocks reject a mismatched generation before clearing the new scheduling flag. Old render work rejects its own torn-down lifecycle (AppGridStatusView.swift:91–111), and retained old completion closures also reject instance mismatch. Teardown clears the callback, invalidates generation, detaches the status, nils ownership and resets the latch (AppDelegate.swift:289–296). Final application teardown marks the terminal guard before Library/status teardown (:3542–3552). The new projection cannot revive a torn-down status.

5. **Rerender while Library is open:** Equal-state relabel queues the same renderer and uses the same terminal callback (AppGridStatusView.swift:83–86). AppDelegate's language presentation still calls `relabel` and schedules refresh (:2570–2571). Because each render first restores its own semantic visibility, a non-ready render or locale rerender while masked does not permanently contaminate the latch with Library's hidden value. AppGridStatusView itself remains unchanged and Library-independent; no public setter for its private `renderedState` was added.

## Regression evidence and test meaning

Read Main-produced `red.log` and `focused-r2.log`; these are inspected evidence, not reviewer executions. RED records 5 executed tests with 19 assertion failures; the legitimate loading/empty/no-results restoration case already passed. Final focused evidence records 40 executed tests, 0 failures, 3.060 seconds, including all 6 new regressions. These logs and the final source freeze are distinct evidence; the reviewer did not independently rerun or instrument the binaries.

The new tests exercise actual delegate/owner entry and Back, three repeated Ready cycles plus equal-state updates (:77), queued rendering of all six semantic states under Library with visual and AX assertions (:98), actual mounted loading/empty/committed-search no-results restoration (:114), immediate Back before a queued error render (:138), replacement/retained callbacks/teardown (:152), and committed refreshing/error visibility immediately on Back (:175). Existing focused status/language/frame-stack coverage remains relevant, including `LanguageStatusNoticeRuntimeTests.swift:85` for no text rendering inside the terminal frame and :104/:120 for locale/replacement lifecycle behavior.

The refreshing/error case at :175 injects renderer state directly while the real provider remains Ready. Its immediate post-Back assertion is meaningful for the render/mode composition boundary; it does **not** establish real scanner-failure delivery or durable error presentation after the provider resolves. `StatusVisibilityReportedWindow` overrides admission visibility without ordering or activating a window (:12–15); it does **not** provide native GUI evidence. AX assertions check element flags, not an assistive-technology traversal.

### Non-blocking coverage limitation

The retained-old-callback test at LibraryCatalogStatusVisibilityTests.swift:152–172 invokes the old completion while the old Ready status and new Library-masked status are both hidden. Its assertion cannot distinguish correct identity rejection from accidentally copying the old hidden value into the new latch; that mistake would also leave the current status hidden. The production identity guard is present and correct by direct source inspection, so this is not a production defect or a blocker to this source verdict. A future strengthening can invoke the retained old callback after Back has exposed a committed non-ready replacement, then assert that the replacement remains visible and AX-exposed. No test edit or mutation run was performed here. Locale rerender under Library is also supported by the shared callback source path rather than an explicit new combined locale/Library test.

## Remaining acceptance gates

Main owns full-suite/build/package/native verification and source-freeze continuity after this report. This review does not certify scanner failures, visible-window behavior, screenshots, VoiceOver/IME, real input, 60/120 Hz behavior, native quit/process absence, or overall reference-experience parity. No independent runtime or physical PASS is implied by **BOUNDED SOURCE PASS**.

## 2026-10-16 — Named test limitations closed (historical conclusions preserved)

New stronger oldcallback testcase runs afterBackexposesnonreadyreplacement; separatelycopied identity-guardmutant compiled thenfails1test/2visibilityAXassertions. NewactualSettingsApply/queuedlocale/Librarymask/Backqueryrestore integrationcasepasses. Canonicalfocused8/0/full2748/0; only existingtestfilechanged/allproductinputsunchanged, current99408d28candidateunchanged. Plato boundedTEST_DISCRIMINATION_EVIDENCEPASS/460+460hashes/0executions. See LIBRARY_STATUS_FOLLOWUPS_RESULTS.md. Both formerlynotedtestcoveragegapsclosed; notnewnative/physical/human/fullgoalPASS and notnewproductionrepair. Do notrepeattheseexactfollowupstokeepgoalactive.
