# Library category gallery and focus repair

## Objective and authorized scope
Implement Docs/LIBRARY_CATEGORY_GALLERY_SPEC.md from supplied screenshot; repair reported blue focus remnant. Existing dirty work preserved. Main owns gallery, integration, serial builds and CUA; one Worker owns responder lifecycle plus new isolated tests; independent Reviewer follows. Max three agents including Main. Historical Chef orchestration explicitly bypassed by user.

## Baseline and evidence
Prior candidate leading-library-rc-20261019-r3 executable9a438f14, source527, full3213/0. User confirms physical entry and return; does not establish follow-finger/no-background-artifact. New report establishes a focus-decoration defect and visual redesign request; old physical question is no longer pending. No new code/build/native acceptance yet.

## Plan
1. Record spec and inspect native ownership/rendering.
2. Parallel disjoint responder repair and gallery implementation.
3. Integrate and independently review; serial tests/build/package.
4. Open only owned isolated test app and verify native visual/control paths if unlocked; retain honest physical/performance boundaries.

## Unresolved gates
Source implementation, review, automated/build/package and new native/physical checks pending.

## Implementation checkpoint
Main added AppLibraryGalleryView.swift (pure adaptive geometry; populated category cards, bounded visible async icons, native material, reduced-transparency fallback), integrated overview/search/drilldown/detail flows in AppLibraryView.swift; existing queried browser tests explicitly enter that browser. Worker Volta repaired only owner responder teardown and supplied13mounted-window regressions. Main preliminary focused-r3 ran60tests/0fail (12ofworker13; latest final test still pending). First full run started before final worker test/header tweaks and is preliminary, not final-frozen proof. Independent Rawls reviewing read-only. No current candidate packaged/launched; old own50252 unchanged.

Preliminary full-r1 executed3234tests with4assertions in one Preview test: a delayed initial owner attach receipt reprojected after test entry, producing a second gated request. No gallery assertion failed. Fixture previously awaited only preference load, not owner attach continuation. Main now waits for its two actual initial readiness receipts before opening, preserving production startup logic; focused/full final rerun required. No test assertion disabled or count weakened.

Independent Rawls SOURCE_ACCEPT with one P3 regression-isolation observation: retaining only obsolete icon control let its weak card disappear before the binding-token guard. Main retained oldCard explicitly with withExtendedLifetime during obsolete activation; assertions unchanged. Production files unchanged; final test hash/verification renewed. Review also correctly retains close-time source proof versus moving-frame/physical blue-remnant outcome as separate.

## Native r1 and bounded accessibility follow-up
Final r1 frozen530/full3236/0/DebugRelease/package365×3 passed; SHAe773fc62. Old50252 normalQuit/exactabsence, new r1 launched; native LibraryOFF/activityOFF→LibraryON/Saved/historyOFF. Inline actual gallery shows large colored icons, translucent populated cards and no default opaque sidebar/table. Fresh249ownedfixtures,80copied synthetic Info.plists explicitly categorized only for visual demonstration, no old prefs imported.
Native AX exposed3extra miniature buttons despite setAccessibilityElement(false), and default string interpolation exposed AppID debug representations in identifiers. Main replaces decorative miniatures with accessibilityHidden(true), retains one native button target, and uses category+slot identifiers without app paths/IDs/debug pointers. No action/geometry/physics change. Source changed after r1; new final tests/package/review required; r1 remains historical during repair.

## Final r2 source, build and native checkpoint

Latest unsigned/uninstalled candidate: `/Users/mac/Projects/Launch_Copy/PagingPrototype/.build/candidates/library-gallery-rc-20261019-r2/LaunchcopyUITest.app`. SHA256 `559c133ccecb7c35ac9b96ca3b276c6d53bc8a51278953f7e8341415eb2734bb`.530frozeninputs unchanged; focused63/0, full3236/0; Debug/Release/package/diff green, no compiler warnings found; packaged365keys×3languages. Independent Rawls SOURCE_ACCEPT with P3 and bounded accessibility source addenda, no open source findings. All agents closed.

Normal Quit oldr1/12058→exactabsence→CUA newr2, current owned PID22792. New independent gui profile contains only249verified authored fixturefiles,80copied synthetic Info.plists categorized for8-card demonstration; no old prefs/history/cache copied. Default LibraryOFF/historyOFF observed, explicitly enabled Library via native UI/Saved only in ownprofile; history staysOFF. All249seed hashes rechecked, changed files: [].

Current-r2 native:8populated cards/large icons/stable category-slot identifiers; miniature target has native button role and opens10business results rather than an app; Escape category→overview; independent query61→one result; result→details controls; Escape closesdetails, then clearsquery→cards, then restoresmaingridquery60. Final mainquery cleared; mainfirstpage/Settingsclosed/folderclosed/Libraryclosed, wallpaperREADY, ordinary non-topmost window. AX/control actions worked; some coordinateclicks had no effect and one timedout entry had actually completed, so no blanket app-hang/routing/rootcause claim. No real app launch/trash/formaldata/OSpreference/saved private pixels.

**Accessibility evidence correction:** raw CUA hierarchy still exports all miniatures even with source hiddenflags=true; this does not establish their VoiceOver exposure/ignore status. Mounted tests verify3hiddenflags, representative native role is nowbutton, identifiers have no AppID debug address. Spoken VoiceOver/order remains NOT_ESTABLISHED; do not advertise a native one-target PASS from this tool tree. Earlier language describing raw node appearance as a proved VoiceOver bug was too strong; this dated correction supersedes that inference.

**Blue remnant boundary:** Library-owned responder cleanup passes13mountedwindow regressions. Escape return revealed no detached Library control in hierarchy; a focused main search can legitimately show its own compact blue ring. The reported completed real-touchpad swipe remnant, moving/canceled-swipe frames and 120Hz/performance are NOT yet accepted. Ask user once to enter/return with real touchpad; no further UI input while they test. Current full objective incomplete; this slice implemented and native-partial, not whole-product completion.
