# Native text editing investigation — 2026-10-15

## Objective and classification
Previous goal turn PROGRESS: identifier feature delivered and renderer handoff fixed, reviewed, packaged and natively inspected; full parity ACTIVE/incomplete. Next aligned existing-contract issue: supported native paste did not insert while typeText did. Do not presume that observation proves an app bug. Inspect/reproduce ordinary command editing of main/Library search and rename/settings fields, including responder routing and existing language presentation.

## Architecture / scope / baseline
SwiftPM tools5.9/AppKit/macOS14, existing language snapshot and app-owned MenuTextKey resources. Current main menu installs only App/Quit and View/Toggle; no standard Edit commands. Latest renderer candidate exe1d9d1c...,2633/0,446input manifest. Preserve dirty tree and all PagingCore/UI sources in this slice. No new custom key handler/global monitor/clipboard polling/text logging/translation of user content or physics/input changes.

## Plan and proportional decision
Main immediately establishes a targeted red reproduction before any implementation. A missing native text-editing command can be a bounded compatibility bug within approved search/rename/keyboard scope, not a new product feature. If proven, add standard nil-target responder-chain menu items and existing three-language presentation, without bypassing marked text/field validation or launching apps. No full specification needed for a small correction; substantial contract changes require confirmation.

Main owns serial tests/build/package and native app control. At most one sidecar reviewer after stable patch; no worker needed on tightly coupled menu/localization integration. Maximum2includingMain, user waived formal Chief routing. Reviewer writes only its own report, no tests/app control; Main performs immediate reproduction, not delegated critical-path work.

## Verification / safety / next action
Red regression must show missing commands, then verify localized menu titles/standard shortcuts/nil targets; existing application presentation/relabel, composition/focus and keyboard tests remain regression scope. Full nonzero XCTest, Debug/Release, strict packaged resources and unique isolated candidate/hash/source freeze. Native before/after only own test instance and candidate-local data; normal Quit, exact-process absence, no query after finalQuit. Keep real IME/VoiceOver/physical acceptance separate; no claim from synthetic keyboard actions. No formal app/profile, install/sign/commit/publish/reference-source/resource reads, unrelated process stop or OS setting changes. Native wallpaper delay is a separate unresolved observation.

## Concrete before observations / red test
Old exactrenderer candidate: coordinate-focused search accepted typeText Handoff; Command-A then07 appended Handoff07 instead of replacing; native paste Demo left value unchanged. AX mainmenu only App/View. Wallpaper now ready/visible on this reopening (previous loading observation not rewritten). Own normalQuit verified exactprocessabsent. Added installed realmenu regression and changed installer private->internal only for @testable use, no behaviorchange. Next execute RED.

## RED and concurrency decision
Main actual installedmenu RED1XCTest/1failure: no submenu contains paste:. Nativebefore Command-A/paste observed failures support repairing missing standardmenu registration; causal nativeafter still required. Main owns AppDelegate + new LauncherEditMenuController + PagingUITests. One authorized worker owns only MenuTextKey + three Localizable.strings + localizationtests needed for 7 exact statickeys (edit,undo,redo,cut,copy,paste,selectAll). Disjoint source writes, no tests/build/UI fromworker; max2includingMain. This narrow foundation parallelism is safe afterMainredterminal; no overlapping review during activewrites.

## Stable implementation and review wave
Worker completed exactly6localization files:7static keys +fallback +three tables +independent15menu-key contract and perkey missing/invalid/signature regressions. Worker0tests andclosed. Main adds native LauncherEditMenuController and wires AppDelegate installer + existing deferredlanguage presentation, internal installer test seam,4unshownmenu tests including actual NSMenu keyequivalent->current NSApp responder with no clipboard use. No new key event interceptor or clipboard observer. Frozen448inputs (see manifest); all18PagingCore/UI match priorcandidate. Mainfocusedserialrun live. Independentread-only reviewer writes only NATIVE_TEXT_EDITING_SOURCE_REVIEW.md, no tests/build/UI, max2includingMain.

Performance budget: no added frame/gesture callback work, timers, catalog refresh or clipboard I/O; six native commands created only at menu installation and seven static labels refreshed only when existing safe language owner presents. No measured physical no-regression claim; matcheddeviceAB remains pending.

## Compile-boundary correction
Focused-r1 terminated beforetests: Main added @MainActor controller but installer was not annotated; compiler rejected initializer call and warned property isolation. Corrected only installer @MainActor, consistent with existing AppKit lifecycle caller/other installers. Retained failedlog; freezeAppDelegatehash updated explicitly. Next r2focused, then source freeze reviewerfinalconfirmation.

Focused-r2 also terminated beforetests on Main test-only identity comparison of AppKit Any? target; corrected explicit conditional cast to the receiver class (not a weakened assertion). Earlier repeated preexisting fcntl/weak-mutability warnings retained, no zero-warningclaim. Installer production fix compiled. Freeze testhash updated; next r3.

## Focused verification
Main r3 focused67XCTest/0failure,7.573s, including4new native-menu tests, real NSMenu command-V resolving currentresponder withoutclipboard access, existing search/folder/keyboard and deferredlanguage + strict3language resources. r1/r2 compile failures retained. Source448hashes match. Main now serial fullsuite/debug/releasepackage job confirmedlive; native app remainsclosed until terminalverification. No independentReviewer conclusion yet.

## Full-suite harness correction, not product guard relaxation
Full-r1 executed2640/4: our menu-keymatching test incorrectly assumed global NSApp.keyWindow=nil (refusedsendingcommand safely), plus3assertions in existingLibraryfolder-sheet test initialreadiness. First fixed our test to assert productionnil target then explicitlytargetlocalspy ONLY for nativeNSMenu keymatching, with honesttestname/comments; no AppKitglobalchain/keywindow assumption/clipboard access. Targeted12/0 includingall8MenuMutation tests followed.

Inspected initialLibrarysetup: requestgeneration capturedbeforeasync preference/catalog projection fanout, then waiting repeatedly on permanentlystale request. Deterministic reproduction adds realowner.catalogDidCommit afterinitialrequestcapture, asserts oldrequestgeneration differs/resolve=nil; oldunchangedawaitloop nowRED1test/3sameassertfailures (readiness-red.log). Repaired onlyinitialtestreadiness by regeneratingrequest withcurrentactiongeneration eachawaititeration under original2sdeadline, assertinggenerationcurrent beforefirstsheet. Retain all original postwriterreplacement oldcallback/nooldornewwrites/freshcallbackonewrite assertions, plus deterministicinvalidation checks. No productionLibrary changes, no tolerance/timeoutincrease or weakenedstaleguard. Exact fullsuite's natural scheduling contributor remains notdirectlyinstrumented; deterministicmechanism +testharnessrepair is what isproven. Current freeze448inputs,10changed/new; all18Core/UI unchanged.

## Final test/source-review evidence and packaging retry
Finalfocused-r4:75/0,6.949s. Finalfull-r2:2640/0,58.140s. Debugbuild success. Final448input source manifest independent reviewer SOURCEPASS (report NATIVE_TEXT_EDITING_SOURCE_REVIEW.md), reviewer0tests/build, nowclosed. Main full-r1 2640/4 and all red/compile records retained; final source differs in testharness described above.

First packaging attempt misconfigured EXECUTABLE_NAME=LaunchcopyUITest (display bundle name, not SwiftPM product); package aborted at build with no suchproduct before app assembly. Retained release-package.log. Retry removes override, uses actual PagingPrototypeApp product and existing script's LaunchcopyUITest destination naming; no script/source changes, no destructivecleanup or extra app launch. Retryjob currentlylive; no package/nativeafter claim yet.

## Native and final checkpoint

## Current checkpoint — Native text editing, 2026-10-15

Previous turn was PROGRESS (identifier search and renderer cleanup). This continuation repaired missing standard native Edit commands in approved text-input scope. Before: Command-A appended text and paste did not insert. Current candidate: actual main/Library all-select replacement/paste works, Library Back retains independent main query. Existing App/View actions and deferred language owner remain; no new keyboard interceptor or clipboard access. Seven typed static labels follow the existing three-language resource pipeline.

Final Main focused75/0 and full2640/0 (58.140s), Debug/Release/package success. Strict packaged288-key/3-language positive/two negative probes;448 frozen inputs match. All18 PagingCore/UI sources unchanged this slice. Independent bounded SOURCEPASS, reviewer0tests/build; worker0tests/build. Both agents closed, jobs terminal. Initial compile errors, full2640/4, deterministic Library-test readiness red1/3 and first invalid product-name packaging attempt retained. Initial test setup alone now obtains current action generation; original stale writer callback/no-write/fresh-write invariants and deadline retained, no production Library guard changed.

Latest unsigned/uninstalled candidate: .build/candidates/native-text-editing-rc-20261015-r1/LaunchcopyUITest.app; exeSHA34ea5275b0d75cc52f75ca6524f2c59ef880ed4b9e95af6cbbc902fae2441d4a. Native Japanese Apply acknowledged; samecandidate59674 -> normalQuit/verifiedabsence ->61316 retained Japanese/Libraryenabled. Latest native dots2of2->1of2 verified after actual focus; initial background disabled guard unchanged. Wallpaper reached ready/visible, not a delay-cause fix. Final normal menuQuit verified exactprocessabsent, no native query after finalQuit. No formaldata/install/sign/commit/OSpreferences/Space change or reference-source/resource use.

Next concrete issue: long Japanese Library category title+count share a truncating label, hiding the numeric suffix (observed screenshot; AppLibraryView.swift353-376). Repair existing category-cell count reservation; preserve full AX label, focus and selection. RealIME/Tab/VoiceOver/physical comparison/120Hz/full parity remain unaccepted; capacity/usage/extra-gesture/destructive approval separate. Full goal ACTIVE/incomplete. Handoff: Workflow/results/NATIVE_TEXT_EDITING_CHECKPOINT.md; evidence: .build/verification/20261015/native-text-editing/. Earlier status sections are preserved history, not current authority.


Current native observations are inline tool evidence, not saved raw images. All448 source hashes and executable reverified after final normalQuit; process absent, bothagents closed and allbuildjobs terminal. Next action is the concrete long-category count layout repair, not arbitrary feature expansion. Documentation update initially stopped on an H1-header assumption (existing project memory/plan begin H2); retry preserved each complete body with correct per-file guards, rather than overwriting or normalizing history.
