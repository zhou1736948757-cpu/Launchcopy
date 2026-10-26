# Library cold-entry diagnosis

## Objective and baseline
SwiftPM/AppKit launcher; preserve independently implemented PagingCore and current UI contracts. User confirms first Library swipe hitches, warm swipes smooth; blue outline removed. Prior physical first-entry gate FAIL remains. Baseline candidate5e2d3b0b…, not accepted for smoothness; source audit/test passes remain scoped.

## Decisions
Instrument actual application-owned cold work first; do not tune physics or assert speculative prewarming fixed it. Opt-in bounded in-memory recorder; export only normal test-app termination. No private data in output. Spec: Docs/LIBRARY_COLD_ENTRY_DIAGNOSTIC_SPEC.md.

## Concurrency
Main owns integration/serial validation/native. Disjoint worker recorder/tests. Read-only wallpaper sidecar; max3 including Main. Completed sidecar reports no timeout in wallpaper worker, no source-level direct Library dependency; runtime cause unproved.

## Current status
Implementation pending. No new build/native/physical PASS. Next: recorder + hooks, regression tests, inspect phase timing.

## Native baseline update
CUA rechecked existing owned5e2d… test process; main first page, empty query. Window diagnostic now reports `render-failed`, not the prior indefinitely observed LOADING. No private source paths/pixels captured. This corrects current state only, does not identify the wallpaper failure cause or connect it to first Library hitch.

## Implementation in progress
In-memory recorder now authored with fixed event tags, injectable DispatchTime clock,8192cap/drop count. Nil-by-default hooks cover shell construction/owner entry/projection delivery, root/gallery layout/card creation/material policy/icon delivery and parent begin/input/render/frame/commit. Explicit Bool test-bundle marker plus resolved UITestProfile admission; common-mode RunLoop observer sampled only while parent transition owns input; export once on normal termination, revalidate candidate root, unique nonoverwriting own JSON. No physics/persistence/default changes. Focused build running serially; independent bounded source review pending.

## Independent review r1
Reviewer found missing separate card layout duration (P2). Added fixed `cardLayout` tag and native-unshown subtree integration coverage; no forced synchronous layout added to production. Prior focused101/0 validates pre-repair recorder/hooks, not final packet. Reviewer follow-up requested on revised packet.

## Validation progress / review r2
Frozen544 inputs;9source/test delta paths from architecture final-r2. Focused102/0 and full3300/0; Debug passed. Release/package still running at this checkpoint. Independent reviewer SOURCE ONLY PASS r2 after missing card span repair; all subagents closed. No native or physical performance result for new code yet. Existing ownedPID6229 normally Quit via native menu; exact executable absence verified. No formal data or user applications touched.

## Native measured source contribution / optimization decision
Candidatebf66882… native own Library ON/Saved/history OFF and wallpaper READY observed. Normal old/new Quit only. First capture exported3559samples/0drops; schema/privacy validated. Native control session unexpectedly also contains109parentInputs/3parentBegins (CUA user-changed notification observed); NOT a pure menu control or a verified user-physical trial. Nonempty galleryApply spans85.2801/81.4016/52.1685ms; latter inside a parent-navigation window, viewApply53.5742ms. Parent commit up to50.0312ms also observed; not all costs attributed. No claim of complete compositor/rootcause.

Evidence supports moving NEVER-PRESENTED card creation out of scroll-time snapshot delivery. Added spec measured addendum: one inert detached pool, one category per yield, strict entries/language match on fresh live projection, one-time consume, no previously exposed control reuse. Main owner/projection/view; worker gallery+gallerytests; worker disjoint ownertests, max3 includingMain, serial builds. Current bf66882 artifact remains diagnostic history during newsourcechanges; full3300/0 belongs ONLY to that diagnostic packet.

## Idle card preparation implementation checkpoint
Gallery worker implemented private never-presented pool and12tests; closed. Main integrates owner version/key/cancellation gates, preserves one actual background projector slot through cancellation completion, starts new live projection for every entry, and revalidates full entries/language before one-time pool consumption. Previously presented controls are never recycled. Source/opt-out/reset/teardown discard; current callback guards and icon viewport admission retained. Added optional viewFocus span to disambiguate separately observed entry/commit native focus cost. Preliminary Debug source build passes (not final tests); owner test worker and independent source review still active.

## Independent preparation review r3 / repair
Source reviewer found P2: zero-delta parent .hold left grid idle, allowing preparation through shared canTransition. Added separate owner canPrepare gate wired only to !navigator.isTransitioning; navigation canTransition unchanged. Parent zero-delta hold release now notifies readiness even without pager commit. Added actual navigator/surface/owner regression for blocked hold then retry. Preliminary test compile failed because Main regression used nonexistent PagingSurface(frame:); corrected to existing pageCount/pageWidth initializer and disabled test frameDriver. Failure log preserved; no runtime PASS inferred. Added fixed optional preparedCardsReady/Consumed numeric marks for native cache-use proof, plus viewFocus timing; strict diagnostic envelope unchanged.

## Preparation focused regression r2 / repair
133tests/1failure: original testCatalogChangesNeverMakePreparedShellAnActionableSnapshotCache caught unnecessary root shell destruction on source invalidation (construction count2vs1). Preserved original test assertion and repaired production to revoke source-bearing pool/work while retaining only empty native shell. New owner source-invalid test now explicitly permits that empty shell, still forbids cards/live snapshot/actions/icons and requires newer source revision. No prior acceptance threshold weakened. Final frozen validation follows.

## Frozen optimization validation in progress
546input hashes,12source/test paths differ from architecture final-r2, all changes in application layer/tests; PagingCore/PagingUI/AppGridUI/Package/scripts untouched in this wave. Focused133/0 passed. Source-only follow-up PASS covers hold gate, numerical marks and root-shell regression repair; all subagents closed. Full suite/Debug/Release/package in serial runner run_optimized_r1.py; native/physical optimized gates NOT_RUN at this checkpoint.

## Main holistic hot-path correction after optimized-r1
Optimized-r1 completed133focused/3321full/DebugRelease/package/diff and remains NEVER_LAUNCHED. Main then found catalogDidCommit also fans out on same-revision search/arrangement commits; unconditional pool invalidation would turn typing into repeated idle native construction. Removed that unconditional invalidation; version/management/preference/language key and real source-invalid revocation already handle relevant changes. Added regression verifying eight unchanged presentation commits retain ready pool and produce no new ready event. This is a scoped performance correction, not a relaxation of stale target checks. New frozen optimized-r2 validation required; r1 results remain historical.

## Final source review / optimized-r2 progress
Independent final SOURCE-ONLY PASS r4 for unchanged-key correction, actual key/source revocation retained; all agents closed. Optimized-r2 focused134/0/full3322/0 and Debug passed on frozen546inputs; Release/package pending at this checkpoint. Original blue-outline user acceptance remains scoped; physical cold-entry acceptance NOT_RUN for optimized code.

## Current delivery / native control
Optimized-r2:134focused/3322full/DebugRelease/package/diff passed,546frozeninputs. Actual native two menu entries/Back, wallpaperREADY, both8-card prepared pools consumed; galleryApply3.5612/5.0262ms versus prior52–85ms source block.374samples/0drops. Other noncard entry/focus costs remain explicitly unresolved; no total-latency/GPU/physicalPASS. Full report Workflow/results/LIBRARY_COLD_ENTRY_RESULTS.md.

Candidate5dd9f1a6… ownPID21527 freshly started after normal Quit/control export and subsequent CUA observation, mainfirstpage emptyquery. Activated via normal View show/hide, NO Library entry by Main in this fresh process.249seed/source/binary/plist hashes rechecked; no formaldata/install/sign/Git/signals/private screenshots. All agents closed. Physical firstentry USER_RETEST_PENDING; do not manipulate UI during requested test.
