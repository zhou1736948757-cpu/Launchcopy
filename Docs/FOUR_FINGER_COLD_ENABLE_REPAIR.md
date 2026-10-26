# Cold-disabled four-finger enable — maintenance repair plan

Date: 2026-10-15. Existing approved four-finger/settings contract; bounded bug repair, not a new gesture/API/permission/feature policy.

## Concrete source counterexample
AppDelegate currently attaches MultitouchSupportBackend at startup only when saved fourFingerActivationEnabled is true. The existing Settings applyPreferences closure invokes composition.applyPreferences alone. ActivationComposition.startFourFinger only restarts an already attached provider/coordinator; with nil provider it explicitly relies on the host to attach. Therefore a production cold startup with the saved preferenceOff can accept a later settingsOn yet have no device provider. InitialdefaultOn tests/isolatednativeUI do not cover this counterexample.

## Proposed bounded implementation
Consolidate the host startup and accepted-settings preference application through one internal LauncherRuntimeServices helper, preserving module/public protocols. On nonisolated, still-live composition + enabled prefs + no provider, lazily create/attach the existing production backend, then apply the existing plan. Existing providers are reused; disabled cold startup does not construct/read devices. Isolated profiles must never invoke the real provider factory, even after repeated settings changes. Teardown must not resurrect services. Defaultfactory is productionbackend; tests inject MockTouchProvider and countcalls. No changes to recognizer/process/flush/geometry/timing/defaults/private symbols/global registration/login/window/paging/stores.

## Evidence plan
After current auditagents finish their stable455snapshot, Main adds a focused regression in existing LauncherRuntimeServicesTests, executes actualRED before helper/hostrepair, then checks enabledcold/disabledcold->enable/off->onreuse/isolated/teardown. Test the actual shared preference helper frombothhostsites, not merely mock attachment in isolation. Actualsettings transaction rollback and unavailableprovider status should remain regressioncoverage. Independent bounded source review, focused/fullnonzeroXCTest, Debug/Release/package/newhash ifproductionchanges. No physicalrecognition claim from synthetic tests; isolatedGUI readiness remainsnotconnected bydesign.

## Ownership / risks
Mainserialcode/tests/build/package; currenttwoauditors writeonlydisjoint reports againstold455freeze beforecodechanges. Later oneboundedindependentreviewer, total<=3. Preserveexistingdirtytree/candidates. No productiondata, nativeglobaldevice/permissiontest, OSsettings/sign/install/commit/kill/delete/referencecode. This fixes hostlifecycle of an existing approved feature; no substantial new crossmodulecontract.

Status: counterexample established by source trace; RED/implementation notyetperformed.

## Current checkpoint — 2026-10-15 cold-disabled gesture enable repaired

FullgoalACTIVE/incomplete; thisturnPROGRESS. MainactualSettingsApplyRED1/4 -> sharedhostlazybackendattachmentfix, 78focused/2688full0fail, Debug/actualReleasepackage/288keys3languages/gitdiffcheckpass. Exactly3of455inputs(2appsource+existingtests)changed,452othersunchanged; all455rehashafterGUI. IndependentGoodallSOURCEPASS/noP0–P3/0executions,closed. Newcandidatefour-finger-cold-enable-rc-20261015-r1 exe92936519e050824d660663ab9e4fed0e9dbc572f4c56083571c221f4da70a026; old66cdretained. Native83753On->OffApply/normalQuit/exactabsence ->84424coldOff->OnApply/notconnectedhonesty (isolatedfakebackendbydesign); finalnormalQuit/exactabsence/sourceempty/defaultOnacknowledged. ProductionphysicalcoldOff->On NOT_RUN, no broadnativePASS. Freshcandidatewallpaperloadingbothprocesses; prior66cdwarmready notfix. No currentjobs/agents/ownapp/faultleft.

Nextconcreteapproveddefect: Libraryfolderdestinationchoices toporder/currentowner/duplicatelabels; conditionalappearancepersistentfactorynil falseSavedalsoneedsboundedrepair. Bothauditsclosedagainstold455/66cd, source/currentcheckpointseparated. Fullresults Workflow/results/FOUR_FINGER_COLD_ENABLE_CHECKPOINT.md; auditqueue CURRENT_REQUIREMENTS_AUDIT_SUMMARY.md. No formaldata/OSpermissions/install/sign/publish/commit/kill/delete/referencecopy. Physicalandpendingproductbranchesremain, notremovedfromfullobjective.
