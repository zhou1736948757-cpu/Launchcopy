# Library cold-entry investigation and measured optimization — 2026-10-20

## Current outcome
**MEASURED_CARD_WORK_REDUCED / PHYSICAL_FIRST_ENTRY_PENDING.** Blue outline removal was accepted by the user on the preceding candidate. The user still reported first-swipe hitching, with warm swipes smooth. Do not mark that physical gate passed from these changes.

## Evidence and scope
The first diagnostic binary bf66882… captured3559 fixed-schema samples,0drops. That control unexpectedly contains parent input events as well as menu actions; operator provenance is unconfirmed, so it is not a pure menu A/B or a certified physical trial. Nonempty galleryApply wall durations were85.2801,81.4016,52.1685ms. A53.5742ms viewApply occurred inside a parent-navigation window. These establish a significant application-owned source contribution, not the entire visual root cause.

The final optimized binary's ordinary native menu/Back control captured374samples,0drops. Both normal fresh session deliveries consumed8never-presented prepared cards. Nonempty galleryApply measured3.5612ms and5.0262ms. This is a measured reduction of that source block, not total frame time, CPU time or input-to-display latency. Control entries still include other costs: owner entry20.3631/451.3675ms, search focus5.65/63.7815ms. The latter remain unlocalized; menu/activation/field-editor effects are not attributed without more evidence. No claim that all hitching or GPU/compositor cold work is fixed.

## Implementation
- Opt-in, fixed enum/numeric-only, bounded8192 in-memory samples; no per-frame file writes. Admission requires Boolean diagnostic marker AND resolved isolated profile. Export once at normal termination into revalidated own profile; no production fallback, app/query/path/wallpaper payloads.
- Retain one empty native root and prepare one detached set of NEVER-PRESENTED category cards while idle. Separate immutable background projection; no live projection/session/actions/scanner/store/history/icon work. Build one category per actor yield with cancellation/admission/key checks.
- Every real entry still starts a fresh normal projection. Consume only on complete entry equality and matching rendered language, once. Never recycle previously presented controls; old callback revocation remains intact.
- Preserve a single preparation worker slot until canceled work actually completes. Check catalog revision/management/preferences/language before publication; source, reset, feature disable and teardown revoke pending content.
- Separate preparation admission excludes parent hold/transition without changing navigation canTransition. Zero-delta hold release retries readiness. Unchanged presentation/search/arrangement commits do not discard valid prepared cards.
- PagingCore/PagingUI/AppGridUI, geometry, gestures, damping, timer defaults, persistence schemas and resources unchanged in this wave.

## Validation and review
546frozeninputs;12source/test changedpaths against architecture final-r2. Focused134/0; full3322/0; Debug/Release/package/diff passed. Packaged localization365keys×3languages. Independent bounded source-only follow-ups PASS; reviewers did not execute tests/native UI or accept physical performance. All agents closed. Earlier compile and shell-reuse regression failures are preserved in logs and repaired without weakening the existing shell-reuse test.

- Specification: Docs/LIBRARY_COLD_ENTRY_DIAGNOSTIC_SPEC.md
- Frozen final inputs, logs, verification, fixture receipt and native results: .build/verification/20261020/library-cold-entry/optimized-r2/
- Serial runner: .build/verification/20261020/library-cold-entry/run_optimized_r2.py
- Diagnostic history: final-r1/; optimized-r1/ is passed but NEVER_LAUNCHED and superseded.
- Independent reviews: Workflow/reviews/LIBRARY_COLD_ENTRY_DIAGNOSTIC_SOURCE-r1/r2.md and LIBRARY_IDLE_CARDS_SOURCE-r1..r4.md.

## Current artifact / handoff
- Candidate: `/Users/mac/Projects/Launch_Copy/PagingPrototype/.build/candidates/library-idle-cards-20261020-r2/LaunchcopyUITest.app`
- Executable SHA256: `5dd9f1a6b132fed21957b0207a370b634dd0a48c74f37bb7b717e1deeab2f0a1`
- Unsigned, not installed, no formal profile/preferences touched.249own authored seed hashes rechecked; no preferences/history/cache imported, no private screenshots persisted.
- Native current window: empty main first page, Settings/Folder/Library closed, wallpaper READY. Own Library ON/history OFF.
- Normal Quit exported control capture. Subsequent CUA observation showed fresh processPID21527(start11:09:23); no intermediate process-absence proof is claimed. Main has NOT entered Library in this fresh process. Activated only through normal View show/hide entry.
- Next: one real-touchpad FIRST entry then two round trips. After feedback, normal Quit exports this process's numeric capture for physical-path analysis. Do not disturb this process before the user's test, silently warm the Library by entering it, or declare a smoothness PASS.

## Remaining limits
Cold fallback remains when the user enters before idle preparation completes. Detached preparation does not pre-render GPU material composition. Control samples are small, not statistical ABBA and not120Hz certification. Wallpaper is now READY on this candidate; the earlier candidate's render-failed cause was not repaired or identified here. Legacy >25ms tail CAUSALITY_UNRESOLVED and unrelated architecture backlog remain separate. Full product parity/release certification is incomplete.

## Changed paths
- `Sources/PagingPrototypeApp/AppDelegate.swift`
- `Sources/PagingPrototypeApp/AppLibraryGalleryView.swift`
- `Sources/PagingPrototypeApp/AppLibraryOwnerController.swift`
- `Sources/PagingPrototypeApp/AppLibraryProjectionController.swift`
- `Sources/PagingPrototypeApp/AppLibraryView.swift`
- `Sources/PagingPrototypeApp/LeadingLibraryNavigator.swift`
- `Sources/PagingPrototypeApp/LibraryEntryProfile.swift`
- `Sources/PagingPrototypeApp/LibraryEntryProfileSession.swift`
- `Tests/PagingUITests/LibraryEntryProfileIntegrationTests.swift`
- `Tests/PagingUITests/LibraryEntryProfileTests.swift`
- `Tests/PagingUITests/LibraryGalleryPreparationTests.swift`
- `Tests/PagingUITests/LibraryOwnerCardPreparationTests.swift`

## 2026-10-20 user disposition superseding physical-pending handoff
User performed the first-entry test and still observed a hitch, then explicitly accepted ignoring it as non-blocking, suggesting high CPU load. Outcome USER_DEFERRED_NONBLOCKING, NOT a smoothness PASS, NOT proof of a CPU cause. No further hitch experiments/tuning requested. Existing numeric capture from the owned process was archived on normal Quit into .build/verification/20261020/library-header/; source/binary unchanged for that capture. Follow-up work is only the requested overview Back removal; new test candidate optional profiling is OFF.
