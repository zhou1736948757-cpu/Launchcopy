# Adaptive Folder Layout — execution checkpoint

Date:2026-10-15/16. Full parity goal ACTIVE/incomplete. User explicitly approved desktop adaptive folder policy after proposal and read-only Ohm planning review. Source of truth: Docs/ADAPTIVE_FOLDER_LAYOUT_SPEC.md (approved, five integration clarifications).

## Confirmed implementation / baseline
Main integrates one pure FolderLayoutSnapshot/resolver with FolderOpenState, FolderOverlayView, AppDelegate and actual folder keyboard columns/focus. Legacy standalone FolderOpenState/default overlay35 retained for explicit external/test callers; production host resolves independent15 maximum and safe reduced capacity. LabelsOff reserves caption budget, so no visibility-only repage. Existing outer5x7/35, Timer0ms, all PagingCore/PagingUI source hashes unchanged. No canonical membership/order/store schema change. Insufficient presentation gates member actions and offers localized Close/resize message. Ordinary resize preserves same mounted title editor; drag resize cancels existing press before applying new snapshot. Old menu actions reject hidden cells.

Gauss delivered new pure policy+11tests; Hilbert delivered state/keyboard+23tests; Main delivered actual owner10tests and coupled wiring. Both workers closed; neither executed tests/build/UI. MaxMain+2 obeyed. Independent Raman source review in progress against460-input manifest; Main serial full tests.

## Actual execution so far
- owner-red.log:2tests/39 assertions failed before host repair (35/page and0pt compact glyphs), compiled actual RED.
- focused-1.log: compile failed on new nested fixture actor isolation; separate fromRED; fixed with explicitMainActor fixture.
- focused-2.log:147tests/0fail.
- focused-3.log:57tests/1fail, new drag fixture missing production revision/committed-page wiring; corrected fixture, not production/criteria relaxation.
- owner-final-2.log:10tests/0fail, includes actual assembly canonical inner indices/top35 annotations, held-pointer freeze/cancel, page2Return, unavailable recovery and mounted editor draft.
- full-1.log:RUNNING, not yet a result.
- gitdiffcheckexit0 on broad dirty tree; pre-existing histories/candidates retained.

Input freeze .build/verification/20261015/adaptive-folder/source-inputs-review.json:460inputs,9oldchanged+5new,446oldunchanged against prior455. Baseline prior2700/0 and79002dc4 executable remain historical, not current candidate evidence. Two new localization keys require290-key/three-language packaging validation. No new package/native acceptance yet.

## Native protocol after build/review
Create unique candidate/profile and copy only own40Info-only app fixtures plus canonical35-member layout before first startup. No formal preferences/layout, personal icons/resources or OS wallpaper/permission changes. Normal ordinary non-topmost window. Actual open -> three pages15/15/5 at regular size if viewport permits; collect all35unique identities in original order from nativeAX. Inspect useful icons/captions at defaults and64/16, narrow/short window resize, same folder anchor, labelsOff names/no duplicate captions, normal title draft resize/Escape if possible. Restore defaults/window/query, normal own-instanceQuit/exactabsence. Inline screenshots may contain personal wallpaper but are not saved/copied to diagnostics. UI assertions do not establish physical60/120Hz, energy, realIME/spokenVoiceOver or wallpaper rootcause.

## Next executable action / scope boundary
Collect actual full result and Raman's independent source findings, fix any concrete defect with fresh tests/review freeze; then Debug/Release/isolated package and native protocol. Do not close fullgoal or claim allparity, physical performance, signing/install/distribution. No commit/reset/clean/delete/processkill/referencecopy.

## Verification correction / final test execution — 2026-10-16

full-1 completed2744tests/7 assertion failures (not leftRUNNING): initial search-frame geometry and directly injected folder firstarrow counterexamples. Source fixes use authoritative searchFieldFrame resolver and initial deferred navigation seed0; title-readiness computed after geometry commit. Existing regressions unchanged. focused-4 executed70/0. Revised460freeze source-inputs-review-r2.json SHA4e8cd3882cdb2031a2092f0e033f4a5a45fdbc487cb75f4db647d6cb4c288fca, communicated toRaman; originalr1 historical. full-2 executed2744/0 in58.857s. Debug/Release packaging nowrunning; native notyet run. Full tests include44newcases, not0testSwiftTesting footer.

## Independent review findings repaired — 2026-10-16

Raman reported2P2/sourcefindings against460r2, notSOURCEPASS: pendingtitlelayout failed to clear on resize roundtrip; fallbackmessage/Close/title overlapped at132x102panel. Main reproduced BOTH in compiled ownerreview-red2tests/14assertfails. Repair explicitly clears temporary editor snapshot when original safe grid fits again; fallbackmessage andClose frames now come from shared FolderLayoutSnapshot, short panels hide title to prioritize message/Close, mountededitor uses message region without replacement/composition calls. Hidden unavailable pageindicator no longer collides. review-repair-1 executed23/0. Added complete fallback bounds/nonoverlap assertions to existingpurelayouttests. Refreshed460r3 freeze; fulltest/re-review/newpackage pending. r1candidate3b7c10aa retainedasPRE_REVIEW, not shipped/native-tested and neverinstalled.


full-3 completed2746/68 assertions, ALL in newly extended pure tiny-bounds test: CoreGraphics intersects includes degenerate zero-area rectangles; assertions wrongly treated hidden/empty chrome as occluding. Main corrected geometric assertion to test only positive-area rendered regions, as the actual visible-control owner test already did. Bounded-frame checks retained for every empty/nonempty rectangle, and positive-area overlap prohibitions retained. No production change fromr3; r4manifest differs onlyFolderLayoutPolicyTests.swift. This is test-model correction, not waived overlap failure ornativePASS. Full-4 pending.


Final full-4 executed2746tests/0fail in60.571s, including46newcases. r4manifest SHA53cbfb0bbea9a1bdd55092d6a76ce6a07a42fd2f32f257cb075a0a72da13530e,460/460Mainverified. Raman boundedSOURCEPASS/460hashes/0executions returned; explicit closure references for original2P2 requested for durable report. FinalDebug/Release290key3language package running with unique r2profile. No currentnative claim or installation.

## Final bounded delivery — 2026-10-16

- Current source: r4manifest460/460matches, SHA53cbfb0bbea9a1bdd55092d6a76ce6a07a42fd2f32f257cb075a0a72da13530e. Compared with prior455:9existingchanged+5new,446existingunchanged. All PagingCore/PagingUI/outercapacity/Timer inputs unchanged.
- Full-4:2746tests/0fail,60.571s, including46new tests. Explicit finalDebug build passes; actual finalRelease build25.01s and isolated package pass. Packaged localization probe290requiredkeys/3languages/signatures verified. Broadgitdiffcheckexit0. Earlier compilation/failure logs retained as history, not silently replaced with PASS.
- Candidate: .build/candidates/adaptive-folder-rc-20261016-r2/LaunchcopyUITest.app. ExecutableSHA99408d28283198a6c9f47506652a4f94e2d55293dc8e3b1ff08dfa987b21bd04. r1candidate3b7c10aa retained pre-review, do not use as latest.
- Independent Raman SOURCEPASS explicitly closes bothoriginalP2/460hashmatches/0executions; allworkers/reviewerclosed. Full review record ADAPTIVE_FOLDER_LAYOUT_SOURCE_REVIEW.md.

### Main native transactions (current r2 candidate only)

Owned40Info-only fixtures and one canonical35-member folder, fresh private profile, no original-data/caches copied. Native2000x1400px ordinary window: real folder open/pagebuttons show01–15,16–30,31–35; all35 unique in originalorder, same leading slots on partial lastpage, useful visible default glyphs,3pages. Native resizing to1400x1000px keeps currentanchor visible and glyphs present, but actual usable height includes title/search/safe chrome:4x1/9pages, NOT the pure700x500-boundary test's12/8 capacity. This conservative short-window result is recorded honestly; its page count may warrant later human spacing calibration, not a false12-member native claim.

Actual mounted title draft roundtrip: regular page2 at2000x1400px -> compact1400x1000px -> restored2000x1400px. Draft retained, unsafe member AX suppressed, all15 members16–30 restored; Escape cancelled the draft and retained the canonical title. This establishes Latin input/native editor retention, not measured selection/composition/IME proof. Native point sizes are inferred at2x; the separate540x500pt case belongs to automated unshown testing, not this native transaction.

Native maximum64/16Apply acknowledged, regular15 members then compact4 visible useful glyphs with captions truncated insidecells. LabelsOff retains4unique namedimages/0membercaptions and unchanged9pagecount. Native1080x1400px narrow-tall ->3x3/9namedimages/4pages;1400x1400px medium-tall ->4x3/12images/3pages; restored2000x1400px ->15images/3pages. Native defaults labelsOn/blur18/icon48/font11Apply acknowledged; restored15texts and0duplicate namedmemberimages. Original window size restored, folderclosed, observednormalmenuQuit, exactprocessNONE, no postQuitappquery. Canonical layout envelope hash unchanged. Receipts .build/verification/20261015/adaptive-folder/native-results.json.

Inline screenshots visually inspected only, no personal wallpaper image saved/copied. Wallpaper loading->ready observed again, not causalfix. No realapp launched for Info-only fixtures, no physicaldrag/performance/RMchange/nativefallbacktiny gate claimed in this run. Unshown tests cover those named source contracts; actualfull-screen proportions/user visual acceptance, spokenVoiceOver, realIME, physicalgesture/energy/60/120Hz remain separate.

### Changes and scope

New Sources/AppGridUI/FolderLayoutPolicy.swift; modified FolderOpenState/FolderOverlayView, AppDelegate/KeyboardFocusController/AppContextMenuController, GridTextKey and three locale tables. Four new test files (policy/state/keyboard/actualowner) add46cases. Existing default appearance and canonical persistence schema unchanged. Approved folder-only exception appended to ICON_AND_TYPOGRAPHY_SPEC.md. Independent implementation only, no forbiddenreferencecode/assets accessed. No commit/install/sign/publish/delete/kill/reset/clean or formal-data/OSpermission changes. All own test instances/agents/jobs terminal, retained own fixtures/artifacts for recovery.

This folder slice is implemented and bounded-test/native verified; human visual acceptance remainspending. Full LaunchBetter-experience-on-Launchcopy goal ACTIVE/incomplete, with previous remaining approved/native/device/permission/product branches still tracked. Do not mark wholegoal complete from this delivery. Next when user returns: review actual folder proportion/spacing; use r2testentry if they want, without opening/overwriting formal installation. Other useful approved gate remains open-Library source invalidation/status/action recovery; wallpaper rootcause remains unresolved separately.
