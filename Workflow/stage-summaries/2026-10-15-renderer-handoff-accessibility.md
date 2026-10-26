# Renderer handoff accessibility repair — 2026-10-15

## Goal / baseline / classification
Full independent reference-experience parity remains ACTIVE/incomplete. Previous turn PROGRESS: default-off identifier feature/source reviews/2630green/native samecandidate restart. Current source inspection confirms native AX's obsolete Page1of5 originates plausibly from an initial NeutralPageRenderer child left in PageHostView when a custom renderer adopts the host; current grid/page dots correctly use two pages. Hypothesis, not yet reproduced regression.

## Bounded decision
Fix abandoned neutral-renderer ownership, not page-number arithmetic or visible chrome. This is a small existing-contract lifecycle bug, not new feature/public API or physics change. Main owns immediate reproduction and minimal fix in PageHostView.customRenderer nil->nonnull adoption. Retire only the neutral renderer's own content; don't remove arbitrary host children, call host.clearForReuse during rendering, bump binding generation, dispose shared custom renderers, or add recurring/frame formatting.

The prior18-source Core/UI-unchanged fingerprint was a previous slice's evidence, not a prohibition on this bounded rendering repair in approved UI scope. If proven, exactly one presentational PagingUI source may change; all PagingCore/parameters/driver/input/time/animation code and remaining17sourcehashes remain fixed. Report that precisely rather than claiming18unchanged. No capacity, gesture, destructive, usage, extra schema or reference-code branch.

## Plan / concurrency
Main first adds real unshown host handoff and actual assembly regression, verifies nonzero RED, then minimal source change. Tests cover neutral cleanup, unrelated child preservation, same custom reassignment/no repeatedclear, current accessibility count and binding-generation stability. Retain neutral lab behavior/reuse/backdrop/real renderer. After stable source, one independent read-only reviewer in parallel with Main serialtests/build/package; max2includingMain. No dispatching immediate critical implementation away. Source/report scopes disjoint.

## Acceptance / safety
Focused/fullnonzero, Debug/Release, packaged281-key3language positive/negative, uniqueunsignedcandidate/hash/currentfrozeninputs. Supported native direct open/profilefixtures only; verify initial AX obsolete label gone/currentdotscorrect and no topnumber visible; no formal profile/app changes. Normal Quit only own instance. Broader actualIME/Tab/VoiceOver/physical60HzAB/120Hz/lifecycle and pendingcapacity remain separate.
English files/Chinese communication/RTK/preserve dirtywork/artifacts; no commit/install/sign/publish/processstop/cleanup/referencecode/assets or authworkaround. No universal custom-renderer-replacement guarantee beyond this actual startup neutral->custom case. Next executable action: regression.

## Reproduced mechanism / minimal repair
Main RED2XCTest/6assertfails foractualneutralchildren/placeholderhandoff; separateactualcatalogassemblyRED1/2 asserts while properhostandAppGridpage labels alreadycorrectlyreportedtwo pages and bindinggenerationunchanged. The stale label is an abandoned child from NeutralPageRenderer, NOT wrong current page arithmetic. One unrelated sentinel child is explicitly protected.

Added exactlynil->nonnull branch in PageHostView.customRenderer.didSet calling the existing neutralRenderer.clearForReuse; leaveshostgeneration/customrenderer/wiring/content/typography/localization/scheduling/Core untouched. No repeatedcleanup onsamecustomassignment, no arbitrarysubviewremoval or hostreuse. Neutral-lab initialpresentation stays asbefore. Next: independentread-onlyscope review inparallelMainfocused/full/build/package, max2Main+reviewer. Main testcommandonly, no UIuntiljobsdone.

## Focused execution and freeze
Main63focusedXCTest/0fail,1.838s, covers3newhandofftests plusrealbackdrop/language/cataloghostrange/directdots/pointerfocus regressions. Originalred2/6 andactualassemblyred1/2 retained.446inputs frozen: only Sources/PagingUI/PageHostView.swift andnewtest differ fromlastidentifiercandidate; allCore plusother17paginginputs unchanged. Onepresentationalsource change explicitlyreported, not18unchanged. Full/debug/release/package nowseriallive; independent reviewerreadstable2files, max2agentsincludingMain. No nativeapplication running/start duringtests.

## Final checkpoint

## Current checkpoint — Renderer handoff repair, 2026-10-15

Identifier search is approved/implemented; see its preceding checkpoint for native ON/OFF/shared-search/restart evidence. Subsequently reproduced stale neutral-renderer five-page AX children at real custom-grid startup and retired only that renderer's owned content on nil-to-custom adoption. Three new regressions; RED2/6 and real assembly RED1/2 retained. Main63focused/2633full0fail, Debug/Release/package,281keys/3languages positive/two negative probes;446inputs match. Bounded independent SOURCEPASS, reviewer0tests. One presentational PagingUI source intentionally changed (PageHostView); other17PagingCore/UI sources and allCore/physics/timing/input unchanged.

Latest unsigned/uninstalled candidate: .build/candidates/renderer-handoff-rc-20261015-r1/LaunchcopyUITest.app; exeSHA1d9d1caada6a77ab14aad364a09f59a2a92a7071ce7d2ea534885897d95dd51f. Supported native isolated ordinary window: obsolete neutral Page1of5/Page2of5 labels absent, correct two dots/current1of2, no top-number decoration in inspected screenshot. Native dotforward/back not accepted (disabled controls; no guard relaxation or inferred cause); wallpaper still loading in this run. RealIME/Tab/VoiceOver/physical gates not replaced. Initial47505, post-first-Quit native query48937; final normal menuQuit followed only by exact-process check returned absent. No own testprocess left running.

Fullgoal ACTIVE/incomplete; this bounded repair is progress, not fullparity. No formaldata/install/sign/commit/processkill or referencecode/assets. Capacity branch still awaits prior confirmation. Fullhandoff: Workflow/results/RENDERER_HANDOFF_CHECKPOINT.md; rawrunlogs/manifests and native observation summary: .build/verification/20261015/renderer-handoff/. Earlier BLOCKED/proposed-identifier status sections are historical and superseded.


All Main build jobs terminal and reviewer closed. Native first-label/visual repair confirmed; direct dotnavigation/physical gates not accepted. Final own normalQuit verified by exact-process absence; no further native query after finalQuit. Source manifest446 reverified unchanged.
