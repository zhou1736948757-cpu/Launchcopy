# Wallpaper same-candidate launch-context control

Date:2026-10-15
Result: NOT_FIXED; ordinary foreground launch does not by itself resolve the observed loading/source-open wait. FullgoalACTIVE/incomplete.

## Baseline / exact observation
Previous goal turn PROGRESS from two native persistence-failure/Cancel/retry/restart transactions; no ownapp/agent/holder/fault remained. Verified exactcurrentcandidate absent before this control. Same unsigned title-edit-focus-rc-20261015-r1/LaunchcopyUITest.app, executable889d661392cc18f0e59958b1b51d499dfac13d82a116a7fa53e1b31852c12bed, existingisolatedgui data/unchanged455inputs. No source, mode, renderer, cache, wallpaper or privacy-setting change.

Supported CUA opened a NEWFinderwindow, navigated to exactcandidate directory, used observedapp's normalOpen secondaryaction. ExactownedPID13579 was confirmed BEFORE binding CUA app, so CUA getApp didnotcreateit. Native screenshot showed red/greenactive titlebar; Help stillloading/regular/localyes. At finalobservationstillloading. A1second/5ms sample onlyofthisexactprocess was captured in memory with explicit-file/dev/stdout; rawheaders/paths discarded. Whitelisted callgraph groups only retained in finder-active-sample.json. Relevant frames177observations: worker backgroundLoader->blurredWallpaper->decodeThumbnail->CGImageSourceCreateWithURL->CGImageReadCreateWithURL->open->__open; secondworkerprovidercoordinationwait. Exactwaiterkey notidentified. Counts arenot177requests/continuouselapsedmeasurement or kernelcauseproof.

Normal ownmenuQuit; exactexecutableabsence verified; no appqueryafterfinalQuit. Closed only newlycreatedFinderwindow; originalDownloadswindow remained. No otherappquit/forceactivation policy change/processkill. All455inputs reverified unchanged. No test/build/package rerun thisturn. Old2677/0 and build receipts remain oldexecutions, not freshones. Allagents/jobs/appinstances terminal.

## API hypothesis / static audit
Current resolver runs onMainActor and keeps originalNSURL throughworker/provider. LocalSDK NSWorkspace.h only promises desktop URL. [Apple desktopImageURL documentation](https://developer.apple.com/documentation/appkit/nsworkspace/desktopimageurl(for:)) requires mainthread; current source meets it. [Apple scoped-access documentation](https://developer.apple.com/documentation/foundation/url/startaccessingsecurityscopedresource()) describes explicitsecurity-scoped URLs/bookmarks; no evidence hereestablishes that a missing start/stop wrappercausedthiswait. No speculative wrapper/APIpatch made. This is not proofnoURLcouldeverbe scoped.

Independent Nash report-only bounded ownpackaging audit: botholderf370...andcurrent889d...sameInfo.plist/bundleID/isolatedentry; inherited linkeradhocsignatures and changingCDHash-only implicitdesignatedrequirements. Bothshare resource-envelope signatureverify failure. Unsignedbundle limitation is real, not a newwallpaper-regression diagnosis or permission-grant justification. No signingperformed. Agentdidnotreadwallpaper/refcode or run source/tests/build/UI/processactions; report writtenonly andagentclosed. No formalReviewer/nativePASS follows. See WALLPAPER_CANDIDATE_IDENTITY_AUDIT.md.

## Supported interpretation / next control
This rules out the simple proposed remedy of normally opening/visibly activating this samecandidate. It does NOT determine activationstate at the initialopen syscall, every OS admission policy, TCCcause, scopedURLpresence, or sourceidentity acrossindependent earlierresolverprobes. No FullDiskAccess, signing, AppNap, compositor or timeoutworkaround follows.

A direct source-variable A/B/A requires temporarilychanging the actualmacOSdesktopwallpaper to an authoredlocalPNG thenrestoringoriginal, while keepingcandidate/profile/launchroutefixed and doingfreshprocesses. This non-sensitive OSsetting action was NOT inferred from broadcomputeruse. Wrote Docs/WALLPAPER_SOURCE_CONTROL_PROTOCOL.md (PROPOSED) with preverifiedrollback, privacy/noalternatehelperreads, no cachedeletion, cautiousinterpretation. Sent ONEdistinctapprovalquestion throughasyncuserinput; awaitinganswer, noOSwallpaperchangeperformed. Do not repeatquestion or call it a verified livejobwait.

Artifacts:.build/verification/20261015/wallpaper-launch-context/finder-launch.json and finder-active-sample.json. Inline nativeobservations are Main's execution, not independentlyrepeatedreview. Newdurablefacts are actualnormalFindercontrol and staticidentityboundaries, not a fix. Fullmigrationstillunproven includingwallpaper, physical/realIME/VoiceOver and separatecapacity/destructive/usage/extra-gesture decisions.

## 2026-10-15 correction — transient recovery observed

Same66cd55c1 candidate/profile PID68800 loading->ready and actual blurredbackdrop; normalexit/exactabsence thennewPID70038 ready/visible withexistingwarmcache. No code/OSwallpaper/privacy/signaturechange. IntermittentfailureNOT_FIXED, causeunresolved; do notpresentpersistentblackasuniversalcurrentstate. Originalsource-openobservationspreserved. Main observations, no independentliveReviewer. See Workflow/results/SOURCE_NATIVE_ROOT_LOSS_RESULTS.md and coverage-repair/wallpaper-transient-recovery.json. BothnormalQuit/exactabsence;455inputsunmodified.
