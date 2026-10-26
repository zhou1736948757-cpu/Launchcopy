# Identifier search implementation — 2026-10-15

Human approved Docs/BUNDLE_IDENTIFIER_SEARCH_SPEC.md; full goal freshly ACTIVE. Previous goal turn was genuine blocked audit, not completion; new approval permits meaningful code progress and starts a fresh blocker audit. Native unlock is independent, no GUI assumption.

## Plan / architecture / scope
SwiftPM/AppKit; one existing shared AppManagementPreferences matching policy, schema2 legacy-compatible management store, same idle/generation-safe grid and Library presentation. Default OFF; canonical bundleIdentifier only, hidden/original/alias/order preserved. Keep name-only matcher/Core/UI/Timer unchanged. Main owns store/coordinator/application scheduling/wiring and integration tests; no blind policy-only call through cancellation-heavy legacy management apply.

## Concurrency / interfaces
Max3includingMain. Worker1 domain prefs/shared matching and new focused domain tests only. Worker2 AppManagementSettingsView/localization and corresponding settings tests only. Both prohibited Swift/build/app control, reference source/assets, unrelated files, global memory or formal data; do not revert others. Main only serial tests/build and native resources. After freeze, independent bounded review (workers completed/closed before reviewer). English files/Chinese communication/RTK commands. No formal Chief workflow (human waived).

Agreed domain name: searchByBundleIdentifier Bool defaultfalse, copied by hide/alias transformations. Codable schema2 requires bool; Main explicitly decodes schema1 legacy payload with flagfalse. UI interface: onSetSearchByBundleIdentifier ((Bool)->AppManagementSaveResult)?, identifierSearchPendingProvider (()->Bool)?, refreshIdentifierSearchState(storedEnabled: Bool,isPending: Bool). Localized checkbox/help/pending/applied/failure separate from alias draft/status. No sixth/seventh tab.

## Acceptance / next actions
Before modifications freeze prior441 inputs/currentcandidate afa1df6c...2593/0 (actual physical baseline not available whilelocked). Structural budget: no addedframework/scan/IO, constant optional matching per record, at most one pending policy/projection. Capture controlled synthetic domain workload separately from real paging/physical gate; do not advertise physical no-regression.

Main: preserve source/store baseline, implement schema2, test oldpayload/noautowrite/wrongmissingflag/future/failure; safe latest policy deferral through existing readiness notifications without polling/cancelling editors/gestures/folders. Preserve current queries/anchors/actions/generation and hide/alias drafts. Focused/fullnonzero/Debug/Release/package+strictresources/executable/source hashes, independent review. Native/restart/VoiceOver/physical remain separate. No commit/install/sign/publish/processstop/cleanup.

## Safety
Existing tree dirty, preserve it. AppManagement existing UserDefaults acknowledgement is not fsync or restart durability; do not invent new accepted-write guarantees. Test profiles injected, unresolved profiles fail preflight. No new query logs/history/source resources. Update project plan/memory and this stage after material results.

## Worker integration / first execution / review
Domain worker changed shared preference policy and added12domain tests; settings worker changed native managementview/7typedkeys+3resources and added11settings tests. Both executed0Swift/tests, report paths IDENTIFIER_SEARCH_DOMAIN_WORKER.md and IDENTIFIER_SEARCH_SETTINGS_WORKER.md; both closed. Independent domain/store reviewer BOUNDED SOURCEPASS,0tests, thenclosed. Separate UI/owner reviewer found F1 missing Library-writer completion readiness event; originalFAIL retained. Max3includingMain observed throughout, disjoint scopes.

Main added schema2explicitlegacy decoder and bool-requiring payload, specialized fresh-valid-baseline toggle refusal for corrupt/future/different metadata, profilefail-closed store, safe queued policy-only owner path, generation/idle/readiness scheduling and currentquery/anchor restoration. No blind input-cancelling metadata path. Added5store regressions and actualdelegate heldgesture/latestowner/folder/same-revision anchor/selection-clear/Libraryquery tests.

Initialfocused34/5fail identified two test-harness assumptions, not an ownerfix: gesture began against zero results/no pages; pointerentrance was stillactive despite surfaceReduceMotion seam. Tests now begin on actual nonempty heldpresentation and use normal keyboardopen before checkingstablefolder. Correctedfocused35/0 then37/0 afterextraanchor tests. Existing baseline conditional-downcast warnings observed; no wholeprojectzero-warning claim.

## F1 actual reproduction / repair
Added gated acceptedLibrarysave regression: orderedmainqueue marker ensures first policyattempt alreadyrejected; writer released then observeautomaticapplication withoutmanualflush/retry/unrelatednotification, saved/failed xclosed/open. Initial awaitinXCTestautoclosure compile error retained separately, fixed localawaitvalue; actual red1XCTest/8assertfails,8.701seconds. This proves missingevent rather than relying on source hypothesis.

Minimal AppLibraryOwnerController.preferencesChanged repair: afteractiveguard deferonReadinessChange, preserving existing preference/receipt/projection/ownership logic. Added fixturedelegate teardown regression forlatewritercompletion: acceptedwritefinishes but queuedpolicycannotpublish afterteardown. Mainfocusedr4live85828; UI/ownerR2 independentreview requested, originalFAIL not erased.

## Performance evidence limits / work budget
Retained baseline441fingerprints and previously built afa1df6c... candidate, not a new matchedphysical measurement. IdentifierSearchWorkloadTests uses1000owned syntheticrecords, OFF/ON xname/IDquery x3samples, correctcounts and separategrid/Librarywalltime, no rawquery/ID/path output. Controlledsynthetic workload.json exists fromr2; it is NOTpre-migrationAB, allocationmeasurement, asynchronousowner latency, paging/realIME/physical acceptance or absoluteperformancebudgetPASS. Structural no-scan/no-frameIO and unchangedCore/Timer remain required. Existingphysicaland120Hz gates stayopen.

One unintended empty /tmp/launchcopy-noop-never-used file was created during a diagnostic shell invocation. It is unused by application/build/tests, contains no user data, and is retained rather than deleting unrelated state. No referencecode/assets/formaldata/install/sign/commit/processstop.

## Wider verification and static localization contract
AfterF1fix focusedr4 executed44/0,1.616s. Fullr1 then executed2630/5fail,59.482s, exclusively five assertions in the preexisting exact-key localization contract; not a green run. Its independent explicit settings-key list still described old274-key schema. Main added ONLY the7approved identifiers inenumorder and adjusted staticbase101to108, retaining exactenum/required-resource/set/3table checks and uniqueness. No productiontext/matching/store repair fromthisfailure. Focusedr5validationplusfeature currentlylive70072;445inputsrefrozen with18changed/new and18PagingCore/UIunchanged. Debug/Release/package were not attempted afterfailedfull due serial&&gate. Full/build/package rerunrequired.

## Final verification / native results / next action


Human approved the written default-off shared identifier-search spec; actual goal ACTIVE. Added canonical-ID-only OR matching to shared management policy, schema2/explicit read-only legacy load, corruption/future/different-baseline refusal for the new toggle, typed three-language checkbox/help/queued/applied/failure, and latest-wins idle policy application without cancelling gesture/editor or closing a stable folder. Existing name-only matcher/5×7/Core/Timer unchanged. A reproduced missing Library-writer completion wakeup was repaired through existing readiness notification.

Main final50focused/2630full0fail; Debug/Release/package; strict281-key3language positive and new identifier-key/placeholder negatives;445 frozen inputs match,18 changed/new,18 PagingCore/PagingUI unchanged. Domain/store and UI/ownerR2 bounded SOURCEPASS (reviewers0tests). All earlier34/5harness, F1red1/8, await-autoclosurecompile, full2630/5stale-key-contract failures retained; static independent contract updated7keys/base101to108, not weakened. Report-time stale manifest note resolved: final currenthash matches a616059f... test and all445 inputs.

Latest unsigned/uninstalled candidate: .build/candidates/identifier-search-rc-20261015-r1/LaunchcopyUITest.app; executable f3709254c9e332d831f6ae3ad40d5d1aa3bdc6d90934122d023e082a0def4086. Actual supported desktop now accessible. Native defaultOFF/noresults ->ON/samequerymatches ->OFF/noresults verified; Library exactID match/details/Return-select/manualGames/alias/hide-exclusion/Back tested. Normal ownmenuQuit process37414 absent, exactsamecandidate reopened as40676; flag/Libraryenable/English/hidden/alias/manualcategory retained acrossprocess. Hidden restored without resetting flag, Automatic restored without losing ID hit. Final ownmenuQuit verified processabsent. Only synthetic40Info-onlyfixtures/isolateddata; no real-app-launch success inferred. Chinese/English settings screenshots inspected, notsaved asfiles.

Native wallpaper actually progressed loading(regular/local) ->ready and visible image; this is not a cause fix or general no-delay guarantee. Actual AX-only initial Page1of5 vs two-page dots remains a concrete accessibility mismatch for next diagnosis; no visible top-page decoration. Automated paste did notinsert but native typeText did; source/app cause unestablished. RealIME/Tab/VoiceOver/Japanesevisual/physicalAB/120Hz/powerloss/fullparity remain unaccepted. Space2 notverified/no Spacechange; ordinary non-topmost test mode used. Allagents/jobsclosed, no install/sign/commit/formaldata or unrelatedprocess changes. Full goal ACTIVE/incomplete, not BLOCKED.

Handoff: Workflow/results/IDENTIFIER_SEARCH_IMPLEMENTATION_CHECKPOINT.md and native-results.json under .build/verification/20261015/identifier-search/. Next aligned work: investigate observed stale AX page-count label, then remaining actual Library/input/lifecycle/physical gates; capacity branch still awaits existing confirmation. Old BLOCKED/proposed-identifier sections below are historical and superseded.

