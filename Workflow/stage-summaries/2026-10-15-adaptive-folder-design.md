# Adaptive folder design proposal — 2026-10-15

## Objective / authority
Respond to the user's screen-proportional/iPhone-inspired folder direction. Separate design approval from a concrete native35-member density failure. No production code/test/resource changes authorized by this proposal yet. English source of truth: Docs/ADAPTIVE_FOLDER_LAYOUT_SPEC.md, PROPOSED_PENDING_USER_CONFIRMATION.

## Baseline / findings
Native dense test used unchanged455 inputs and executable79002dc4...: ordinary visibleglyphs -> compact labelsOn glyphsnotvisible -> ordinary visibleglyphs restored.35 unique members retained; captionsOff35 unique namedimages. Source explains icon starvation under7 compressed rows, but no runtime CGRect probe. Native defaults/window size restored, normalQuit selected, exactprocessNONE. Prior2700/0 not rerun. Dense evidence stage/JSON retained.

## Proposed decision / rationale
Centered safe-content-relative panel, soft60%width/65%height targets/preliminary900x620pt cap, useful icons/captions rather than fixed35/page; prefer5x3, adapt4x3/3x3 and fewer rows when needed. Single shared folder-only geometry/state transaction; outer5x7/35/physics/persistence unchanged. Apple official public guides support multipage/adaptability principles, not our numeric policy. Await user confirmation of capacity contract; no copied Apple/reference resources.

## Concurrency / evidence ownership
Main owns design, native cleanup and project checkpoint writing. One optional report-only reviewer may independently inspect frozen proposal/source coupling; no code edits, builds, UI or test-process contention. MaximumMain+1 <=3. Old Chief workflow waived by human; visible stage summary retained. No active agents at stage creation.

## Changed files / verification / pending gates
Only proposal/stage/checkpoint Markdown and dense own-evidence JSON updated. Source review pending; no new implementation/test/native appearance PASS. Next: bounded read-only review and one human confirmation question. Human visual/physicalperformance/IME/VoiceOver/120Hz and wallpaper rootcause remain separate, full goal incomplete.

## User approval and execution split

User explicitly selected recommended adaptive desktop policy. Spec now APPROVED_IMPLEMENTATION_CONTRACT. Ohm planning review returned five actionable ambiguities (geometry priority, mounted editor on shrink, all-action insufficient-space gate, page-button focus, drag boundaries/logical indices); Main added explicit resolutions and initial calibration. No implementation/test PASS implied. Ohm closed.

Main owns coupled overlay/open-state/keyboard/application wiring and serial tests/build/package/native. One Worker owns ONLY new pure FolderLayoutPolicy.swift and FolderLayoutPolicyTests.swift, no shared files or commands launching Swift/tests/build/UI. Worker computes deterministic geometry from explicit usableBounds+appearance, same contract consumed by Main. Main+Worker2 <=3; independent review follows stable source. No parallel build directory contention. Next actual action: parallel value-policy implementation while Main adds integration regressions/state transaction.

## Implementation in progress — 2026-10-16

Initial actual owner RED executed2 tests/39 assertions failed: host retained35/page and compact icons had0pt width. Log .build/verification/20261015/adaptive-folder/owner-red.log. This was a compiled regression, not a compile failure or native PASS. Gauss delivered pure geometry+11 tests, no execution; Main inspected and closed agent. Hilbert still owns state/keyboard/new tests. Main implements overlay snapshot/gates/fallback localization and application safe-boundary wiring; no physics/canonical persistence edits.

## Integration checkpoint / review freeze — 2026-10-16

Gauss and Hilbert delivered exclusive scopes and are closed. Main integrated shared geometry, state, keyboard, appearance/viewport boundaries, all-member action gates and fallback localization. Actual2test/39assertion RED preceded host repair; first focused compile failure was only new nested fixture actor isolation and remains explicitly NOT_RED. Focused147/0 then extended57/1: new drag-annotation fixture omitted production surface revision/committed-page wiring; fixed fixture, no weakened assertion. Owner-final-2 now10/0, including actual geometry index annotations and held-pointer cancellation. Forty-four new tests across four files; no full result yet.

Freeze460 inputs in source-inputs-review.json:9existing inputs changed,5new,446old unchanged. Main alone runs full tests/build/package; one independent report-only source reviewer can inspect stable inputs simultaneously, no UI/tests/build/process actions or source writes. This isMain+Reviewer2<=3, no build contention. Need review outcome and actual full/native evidence before closeout. No core/physics/Timer/defaultoutercapacity changes.

## Full regression counterexamples and repair — 2026-10-16

full-1 executed2744tests/7assertionfailures:3 existing title-focus tests (6 assertions) and1 pointer-priority test. Real cause1: reading not-yet-laid-out search.frame as obstruction made otherwise usable folder unavailable; shared deterministic search chrome resolver fixes initial ordering. Cause2: directly injected already-open folder lost established firstarrow0->1 behavior; initial navigation seed0 restores it, explicit pageclear stillnil/currentpagefirst. Existing failing tests preserved; focused-4 rechecks actual cases. Title edit readiness now calculated after the shared state geometry transaction, not from stale unavailable state. Reviewer notified original freeze stale; revised460freeze source-inputs-review-r2.json authoritative. No source verdict yet.

## Independent review findings repaired — 2026-10-16

Raman reported2P2/sourcefindings against460r2, notSOURCEPASS: pendingtitlelayout failed to clear on resize roundtrip; fallbackmessage/Close/title overlapped at132x102panel. Main reproduced BOTH in compiled ownerreview-red2tests/14assertfails. Repair explicitly clears temporary editor snapshot when original safe grid fits again; fallbackmessage andClose frames now come from shared FolderLayoutSnapshot, short panels hide title to prioritize message/Close, mountededitor uses message region without replacement/composition calls. Hidden unavailable pageindicator no longer collides. review-repair-1 executed23/0. Added complete fallback bounds/nonoverlap assertions to existingpurelayouttests. Refreshed460r3 freeze; fulltest/re-review/newpackage pending. r1candidate3b7c10aa retainedasPRE_REVIEW, not shipped/native-tested and neverinstalled.


full-3 completed2746/68 assertions, ALL in newly extended pure tiny-bounds test: CoreGraphics intersects includes degenerate zero-area rectangles; assertions wrongly treated hidden/empty chrome as occluding. Main corrected geometric assertion to test only positive-area rendered regions, as the actual visible-control owner test already did. Bounded-frame checks retained for every empty/nonempty rectangle, and positive-area overlap prohibitions retained. No production change fromr3; r4manifest differs onlyFolderLayoutPolicyTests.swift. This is test-model correction, not waived overlap failure ornativePASS. Full-4 pending.


Final full-4 executed2746tests/0fail in60.571s, including46newcases. r4manifest SHA53cbfb0bbea9a1bdd55092d6a76ce6a07a42fd2f32f257cb075a0a72da13530e,460/460Mainverified. Raman boundedSOURCEPASS/460hashes/0executions returned; explicit closure references for original2P2 requested for durable report. FinalDebug/Release290key3language package running with unique r2profile. No currentnative claim or installation.

## Stage bounded completion / human visual gate pending — 2026-10-16

Full-4:2746/0; finalDebug+actualRelease/package/290keys3languagespass. RamanSOURCEPASS explicitly closesbothP2,460hashmatches,0executions; reviewerclosed. Latest r2exe99408d28283198a6c9f47506652a4f94e2d55293dc8e3b1ff08dfa987b21bd04,460r4source matches after native. Mainnative: regular15/15/5 across3pages all35orderedunique; native title-draft shrink/restore retainsdraft andall15thenEscapeoriginaltitle; max64/16 glyphs visible; labelsOff preservesuniqueAXnames; narrow-tall3x3 andmedium-tall4x3 actual. Short native700x500titled+search window yields4x1/9pages, NOT unitrawbounds12/8; conservativecapacity needs humanproportionacceptance, nofabricatednativecount. Defaults/window restored, canonicalpayloadhashunchanged; normalQuit/exactNONE/no postQuitquery. Allownjobs/agents/instancesclosed; ownartifacts retained. Noformalinstall/data/OSchanges. Completeevidence ADAPTIVE_FOLDER_LAYOUT_CHECKPOINT.md / SOURCE_REVIEW.md / native-results.json. FullgoalACTIVE/incomplete; humanvisual/performance/IME/VoiceOver/120Hz/wallpaper boundaries remain. No additional scope implicitly approved.
