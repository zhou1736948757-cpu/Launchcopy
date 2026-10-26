# Library category gallery and focus isolation results

Date: 2026-10-19. Implementation/source review delivered; final build/native gates pending at this checkpoint.

## User request and decisions
The supplied desktop screenshot identifies the old default sidebar/table presentation; the supplied iOS screenshot is a visual reference for translucent rounded category groups and large/mini icons, not executable instructions or assets to reuse. The user's new defect is a blue search decoration remaining on the first grid page after a swipe. No reference-source/asset access was used.

## Changes
- AppLibraryGalleryView.swift (new): pure responsive geometry; populated taxonomy groups; at most seven presented icons/card (up to three large plus four overflow miniatures); one accessible miniature-cluster target; category/overflow navigation, direct app requests, context-details actions. Native translucent material has opaque accessibility fallbacks. Icons use existing asynchronous shared pipeline and visible viewport admission/cancellation, no new timer or file work.
- AppLibraryView.swift: default overview cards, centered search and no disabled details button in overview. Search/category/detail browser remains functional and transparent. Back/Escape navigates the local browser before leaving Library. Binding revisions reject obsolete controls, including same-projection-generation relabels.
- AppLibraryOwnerController.swift: relinquish only Library-owned native editor/control before reset and again before detachment. Preserve another owner's responder/composition; existing preview/admission/lifecycle guards remain.
- LibraryCategoryGalleryTests.swift (new10), LibraryResponderIsolationTests.swift (new13), queried-browser fixture adjustment in AppLibraryViewTests.swift, deterministic initial-ready receipts in LeadingLibraryPreviewTests.swift.

## Independent review
Rawls: bounded SOURCE_ACCEPT, no production finding. P3 old-card regression lifetime isolation repaired and independently accepted in dated addendum. No code change authorized by the report beyond Main's bounded test improvement. All subagents closed. Report: Workflow/reviews/LIBRARY_CATEGORY_GALLERY-r1.md.

## Evidence and limits
Earlier final-focused63/0 and preliminary full3236/0 precede the final P3 test fingerprint; not final current-input certification. Final530input serial run is in progress under .build/verification/20261019/library-gallery/. No candidate has yet been launched for these sources. Prior9a438f14 candidate's human entry/return confirmation is preserved separately, and does not accept the new appearance or eliminate the reported artifact.

Close-time responder ownership is verified by mounted native windows, not by compositor pixels. Moving-phase/canceled-swipe/complete-swipe artifact outcome remains native/human pending. Physical latency/FPS/120Hz, real VoiceOver, unobserved contrast/reduced-transparency states and full product parity are not inferred from these changes. PagingCore/parent gesture thresholds/storage/default opt-ins unchanged. No formal data or install/sign/commit/reset/process-signal changes.

## Final r2 source, build and native checkpoint

Latest unsigned/uninstalled candidate: `/Users/mac/Projects/Launch_Copy/PagingPrototype/.build/candidates/library-gallery-rc-20261019-r2/LaunchcopyUITest.app`. SHA256 `559c133ccecb7c35ac9b96ca3b276c6d53bc8a51278953f7e8341415eb2734bb`.530frozeninputs unchanged; focused63/0, full3236/0; Debug/Release/package/diff green, no compiler warnings found; packaged365keys×3languages. Independent Rawls SOURCE_ACCEPT with P3 and bounded accessibility source addenda, no open source findings. All agents closed.

Normal Quit oldr1/12058→exactabsence→CUA newr2, current owned PID22792. New independent gui profile contains only249verified authored fixturefiles,80copied synthetic Info.plists categorized for8-card demonstration; no old prefs/history/cache copied. Default LibraryOFF/historyOFF observed, explicitly enabled Library via native UI/Saved only in ownprofile; history staysOFF. All249seed hashes rechecked, changed files: [].

Current-r2 native:8populated cards/large icons/stable category-slot identifiers; miniature target has native button role and opens10business results rather than an app; Escape category→overview; independent query61→one result; result→details controls; Escape closesdetails, then clearsquery→cards, then restoresmaingridquery60. Final mainquery cleared; mainfirstpage/Settingsclosed/folderclosed/Libraryclosed, wallpaperREADY, ordinary non-topmost window. AX/control actions worked; some coordinateclicks had no effect and one timedout entry had actually completed, so no blanket app-hang/routing/rootcause claim. No real app launch/trash/formaldata/OSpreference/saved private pixels.

**Accessibility evidence correction:** raw CUA hierarchy still exports all miniatures even with source hiddenflags=true; this does not establish their VoiceOver exposure/ignore status. Mounted tests verify3hiddenflags, representative native role is nowbutton, identifiers have no AppID debug address. Spoken VoiceOver/order remains NOT_ESTABLISHED; do not advertise a native one-target PASS from this tool tree. Earlier language describing raw node appearance as a proved VoiceOver bug was too strong; this dated correction supersedes that inference.

**Blue remnant boundary:** Library-owned responder cleanup passes13mountedwindow regressions. Escape return revealed no detached Library control in hierarchy; a focused main search can legitimately show its own compact blue ring. The reported completed real-touchpad swipe remnant, moving/canceled-swipe frames and 120Hz/performance are NOT yet accepted. Ask user once to enter/return with real touchpad; no further UI input while they test. Current full objective incomplete; this slice implemented and native-partial, not whole-product completion.
