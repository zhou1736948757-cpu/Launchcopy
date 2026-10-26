# Folder interaction feedback — 2026-10-16

## Objective and approved feedback
Human accepts adaptive folder layout proportions. User reports missing two-finger inner paging, window closing when three-finger dragging the window in the ordinary windowed test build, and a possible transient dark flash before folder entrance. These are reports, not yet causal findings.

## Scope and constraints
Main investigates native window chrome/blank click handling and regression coverage. One read-only sidecar investigates folder entrance composition. Folder gesture parity is a cross-module input contract: document proposal and obtain confirmation before implementation. Preserve outer paging physics, canonical order, dirty tree, existing candidates, isolated profile and formal data. Do not install/sign/commit/kill processes or copy reference code. Max three active agents including Main.

## Baseline
Previous evidence: 2748 tests/0 failures, isolated unsigned adaptive-folder r2 executable 99408d28...; prior evidence is not a current build or GUI acceptance. Human layout acceptance does not accept gesture or entrance behavior.

## Evidence / review / unresolved gates
Investigation pending. No repair or native three-finger reproduction claimed. Next: inspect window event classification and entrance animation; add minimal regression tests for established defects.

## Approved contract update
User explicitly confirmed continuous finger-following folder paging. Subsequent report confirms scroll leaking to outer grid. User clarified ordinary windowed test mode; no independent folder window resizing is expected. Folder layout proportions are human accepted.

## Established defects and repair approach
Actual RED execution: 2 tests / 2 failures in .build/folder-feedback-red.log: titlebar dispatch enters launcher search-exit path; mount observer sees opacity1 instead of0. No real three-finger event or flash frame captured. Prepare transparent entrance + final geometry before host mounting and disable implicit model actions. Window owns folder scroll routing (including rejected events) and native chrome bypass.

## Parallel ownership
Planck completed read-only entrance audit (closed, no tests/UI/writes). Hooke owns only new PagingUI/FolderPagingController.swift, its driver tests and own result note; Main owns overlay presentation, AppDelegate/window/keyboard integration and regression tests. Shared SPM runs serialized by Main. New controller reuses unchanged PagingCore/ScrollInputMapper; on-demand 60Hz/0ms clock only while settling/release-wait, no permanent idle timer. Folder presentation bounded current/neighbor visual-only pages, no per-frame rebinding or layout; title/panel/footer fixed. Candidate build and native/human acceptance pending.

## Review repair checkpoint
Linnaeus bounded source review found2P2 (noP1): long continuous drag could outpace fixed current-page visual hosts; Return/Enter performKeyEquivalent omitted cancellation. Main added actual RED regressions (2tests/5assertfailures), changed to moving bounded host window and added shortcut-path cancellation; focused88/0. Initial2786fullgreen does not certify post-review source. Finalfull/package/re-review in progress. Updated463inputfreeze source-inputs-r2.json. CUA blocked by Mac locked; no own GUI action/normalQuit/newlaunch succeeded. Human physical/flash acceptance remains pending; layouts accepted only.

## Final code/package handoff
Main actual final2788/0,52.073s; Debug/Release/package/probe290keys3languages/gitdiffcheck pass. Source reviewer closes original2P2/no newP1/P2/source-only.463r2freeze rehashed,455previous unchanged. Final candidate /Users/mac/Projects/Launch_Copy/PagingPrototype/.build/candidates/folder-interaction-rc-20261016-r2/LaunchcopyUITest.app, SHAb9446444a9b3e807db9e66f36150ff3d855e0ef2e733d96af1b0b123fc731c9b.40fixtureapps/35-memberfolder seeded candidate-locally, original profile bytes unchanged. No newcandidate launch/oldcandidate normalQuit because Mac locked; real physical/native/flash gates remain pending, not source/test PASS. All agents closed. Full details/results/changedfilelist and receipts recorded in FOLDER_INTERACTION_FEEDBACK_RESULTS.md and .build/verification/20261016/folder-interaction/. No full-goal completion or distribution claim.

## Native handover after unlock — 2026-10-16
The user manually unlocked the Mac. Main normally Quit the old isolated adaptive-folder test app through its observed application menu, verified exact old process absent, then launched exact folder-interaction r2 (PID23375/SHA b9446444...). No post-Quit old-app query. New ordinary non-topmost window loaded40fakeapps/35-memberfolder; wallpaper ready was transient observed status, not causal wallpaper-fix evidence.

Actual CUA native titlebar drag did not dismiss the window/folder. Actual border resize changed2000x1400pixels ->1400x1000pixels,15members/3pages ->4members/9pages; restoring original size returned15members/3pages. Next-page button showed16-30; previous restored01-15. Folder remains open onpage1 atoriginalsize for human testing. Three-finger gesture itself and flicker/smoothness were NOT verified. CUA horizontal scroll attempts showed no committed page transition; this is not physical gesture evidence and does not establish either PASS or a new product defect. Source463/candidatehash and fixture layout/library bytes reverified unchanged. No source/test/build changes or suite rerun in this handover. Native structured receipt .build/verification/20261016/folder-interaction/native-handover.json supersedes earlier not-launched/locked handover status; original receipts retained as history. No personal-wallpaper screenshot files saved.
