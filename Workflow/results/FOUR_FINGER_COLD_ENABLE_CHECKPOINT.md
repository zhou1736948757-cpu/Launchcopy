# Four-finger cold-disabled enable — delivery checkpoint

Date: 2026-10-15. Full goal ACTIVE/incomplete. CODE_VALIDATED + independent bounded SOURCE PASS. Main isolated-native settings/restart PASS only; production physical gesture acceptance NOT_RUN.

## Defect and causal evidence
Production boot attached MultitouchSupportBackend only when the saved four-finger preference was On. Existing Settings Apply called composition.applyPreferences alone; startFourFinger could not create a missing provider. SavedOff cold startup -> acceptedOn could therefore stay backendmissing.

Main first extracted the actual preference-application body into an internal shared helper without changing behavior and retained the old startup conditional. The actual SettingsCoordinator.Apply/transaction regression compiled, accepted and committed On, but failed factorycount/provideridentity/started/readystate: **1 XCTest / 4 assertion failures**. Original three input bodies, exact final diffs, logs and manifests retained. No separate complete intermediate RED source snapshot was captured; extraction equivalence is attributable to the stage/tool record and original source, not an invented prior hash.

## Bounded repair
Only2existingappsourcefiles +1existingtestfile changed:
- LauncherRuntimeServices.swift: internal synchronous lazy helper; live/nonisolated/acceptedOn/nilprovider creates the existing backend, then applies the existing plan. Already attached providers are reused; teardown cannot resurrect services.
- AppDelegate.swift: startup and accepted settings share this helper. Settings capture immutable profile isolation and weak composition; old boot-only attachment removed.
- LauncherRuntimeServicesTests.swift: eight added tests, two prior retained. Actual settings acceptance, initialOff/devicefree, initialOn/repeat, Off/Onreuse, isolatedfactorynevercalled, unavailablehonesty, explicitprovideridentity, teardown and future-save-refusal rollback.

Other452frozen inputs unchanged, including allCore/PagingUI, recognizer, backend, publictouchprotocols, preferences/schema/defaults, frameparameters, localization/resources/scripts. No new gesture/API/permission, private symbol, real-device test or runtime diagnostic added.

## Verification / review
| Gate | Actual result |
| --- | --- |
| RED | 1XCTest /4assertfail; compilation successful |
| Focused | 78XCTest /0fail,0.462s; runtime suite10/0 (8new) |
| Full | 2688XCTest /0fail,53.305s; trailingSwiftTesting0notcounted |
| Debug | explicitswiftbuildexit0,0.33s |
| Release/package | productbuild15.49s + resourceprobe0.13s, unique test-entry packageexit0 |
| Packaged localization | actualpositive288keys/signatures ×3languages; no new negative probe claimed |
| Input identity | all455finalhashes reverified after native work; exactly3changed vs baseline |
| gitdiffcheck | pass |
| Independent Goodall | boundedSOURCEPASS/noP0–P3; independently455hashes andexact3diffs verified, MainRED/focused/full logs inspected. Reviewer0test/build/Swift/native/process actions; closed. |

## Current candidate
`/Users/mac/Projects/Launch_Copy/PagingPrototype/.build/candidates/four-finger-cold-enable-rc-20261015-r1/LaunchcopyUITest.app`

ExecutableSHA256: `92936519e050824d660663ab9e4fed0e9dbc572f4c56083571c221f4da70a026`.
Sourcefreeze455: `.build/verification/20261015/four-finger-cold-enable/source-inputs-final.json`; SHA256 `ca059a305b4f7dc9584c94cc24bc502a78782e1a3c25bf0ddbf491d65deaa294`.
Prior66cdcandidate retained; no installation/signing/notarization/publish/commit/cleanup.

## Exact-candidate isolated native gate
- New own emptyprofile; ordinarynon-topmostwindow. PID83753 SettingsdefaultOn andnotready/backendmissing (intentionalisolation).
- NativeOff+Apply acknowledged; normalmenuQuit/exactabsence.
- Exactsamecandidate newPID84424 startswithcheckboxOff/readinessnotready. Confirms realprocessrestart, notwindowreopen.
- NativeOn+Apply acknowledged; remainsnotready/backendmissing, preservingfake-serviceisolation. RestoreddefaultOn, shortcut/hotcorner/login remainOff; no registration/OSsetting/formaldata changes.
- FinalnormalmenuQuit/exactabsence, no subsequentappquery. Sourceempty, no fault/livejob/agent/owninstanceleft. FinalOn savedack observed; no thirdrestart durability claim.

This does not exercise the production provider in a real gesture. Mockreadiness and isolatednotready are distinct deliberate outcomes. ProductionM01–M12/energy/physicalacceptance remainsopen. Wallpaper stayedloading inbothfreshcandidateprocesses; previous66cdwarmreadyscreenshots remain historicaltransientrecovery, not a repair or guaranteedcoldreliability.

## Remaining full-goal work
The independent requirement audits foundtwoadditionalexistingapproveddefects, notmerelyexternalgates: Libraryfolderdestinationchoices (canonicalorder/currentowner/duplicatelabels) andconditionalappearancefactorynil->InMemoryfalseSaved. Queue boundedactualcounterexamples/repairs, do notmarkfullgoalcomplete. Library standard-flow choice correction is a useful next step; conditional persistence protection remains queued. PhysicalIME/VoiceOver/performance/120Hz and unconfirmedcapacity/destructive/usage/extragesture branches stay separate.

Artifacts: `.build/verification/20261015/four-finger-cold-enable/`; source review `Workflow/results/FOUR_FINGER_COLD_ENABLE_SOURCE_REVIEW.md`; native receipt `native-isolation.json`.
