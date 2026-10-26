# Wallpaper State Diagnosis — 2026-10-15

## Objective and scope

Continue full independently implemented parity. Previous turn made real catalog commit/native progress. Latest candidate59ece69b... showed a flat backdrop with0isolated cache files. Before changing rendering, distinguish policy-disabled, missing source, pending render, render failure and applied image. The current native observation cannot tell these apart. No reference assets/code, alternate wallpaper access, system-preference mutation, polling, GUI launch wrapper or production data use.

## Proportionate diagnostic contract

Add internal finite-state observation to the existing MainActor wallpaper controller, with no paths, images, app identifiers or associated raw error data. Default callback nil; publication only at existing discrete attach/refresh/completion boundaries. Existing generation guards reject obsolete image AND obsolete state. Rendering/policy/source resolver remains unchanged.

Only an already-resolved isolated UI profile connects this observer to that test window's accessibility help, using a fixed English enum token. No production AX text, new preference/store/file/directory, timer or frame work. Unit tests verify all outcomes, stale completion and production-versus-profile owner wiring. This is bounded diagnostic maintenance of an approved appearance requirement, not a new cross-module product design or approval of Library/capacity.

Main owns implementation/tests and native app resource. Source review may run read-only in parallel with serial Main tests/build. Preserve existing dirty tree/candidates. Native app opens only through Cua after candidate checks. Classify the actual token before proposing any source/decode/compositing repair; do not turn unknown into PASS.

## Plan and acceptance

1. Add neutral state and profile-only AX help; unit-check no policy/render changes and stale-state gating.
2. Freeze inputs; serial focused/full tests, Debug/Release and packaged-resource checks.
3. Open unique dedicated candidate directly and read exact window help/token. Need real current observation, not source inference.
4. If policy-disabled, retain accessibility behavior and document no compositor fault proved. If source/render failed, scope a concrete follow-up from actual branch; no private fallback guess.
5. Normal Quit only our test instance, identity/closure checks, update stage/project plan/memory honestly. Full parity/physical/global activation remain incomplete; Library question still awaits confirmation.

## Risks and next action

Window help must not receive a stale request result. Diagnostic observation must not start work or leak source data. An applied-image token is not by itself proof of correct visible compositing. Next: implement bounded state/wiring and tests.

## Delivered bounded diagnostic and source review

Added internal finite LoadState and default-nil observer in WallpaperBackdropView.swift; AppDelegate connects only a successfully resolved isolated profile to weak test-window AXhelp. Existing rendering/source/policy callbacks unchanged; no file/timer/frame instrumentation or new stores. Added6tests for ready/failure, missing source versus policy skip, stale completions, host replacement and resolved-profile-versus-production/unresolved wiring. Removed a needless try! in the test before final freeze.

Main initialfocused54/0 (before that test cleanup); finalfull2455/0, Debug/Release successful,407source/test/script/resource/package frozen inputs and strict221-key3-language package positive/2negative fixtures verified. Independent bounded source PASS: `Workflow/results/WALLPAPER_STATE_SOURCE_REVIEW.md`, no reviewer execution. No whole-project zero-warning claim.

Unsigned candidate: `.build/candidates/wallpaper-state-rc-20261015-r1/LaunchcopyUITest.app`.

Executable SHA256: `b19af336ea50eac36259d87dad9aa193e38d09c8edfe69a5d855d594a1abafa1`.

## Actual current native cause boundary

Direct Cua opened exact candidate, fresh72Info-only synthetic apps. AX window help actually reported `Wallpaper diagnostic: loading`; subsequent AX/native screenshot and a later AX check retained that state with a flat fallback. This excludes the observed request being skipped by Reduce Transparency or rejected for a missing source URL. It does NOT prove a successfully decoded/assigned image or compositor fault. Source rendering remains unresolved rather than PASS.

Read-only exact-process inspection confirmed PID9187 / the candidate executable. Main took a1second,10ms-interval `sample` of ONLY that permitted test process; no fullPaths, stop/kill/debugger attach or application other than our own was involved. Raw output was held in memory and not saved; filtered callgraph omitted binary/path header and addresses were redacted. Artifact: `.build/verification/20261015/wallpaper-state/own-process-blocked-load-sample.json`.

All91samples of one user-initiated worker passed through WallpaperBackdropProvider.blurredWallpaper → decodeThumbnail → CGImageSourceCreateWithURL → ImageIO URL reader → __open. The other wallpaper worker waited in _pthread_cond_wait at existing in-flight deduplication. Main thread sampled in its ordinary mach_msg runloop wait. Thus source opening is the observed stalled stage before any blur/image completion; dedupe waiting is secondary, not evidence of a self-caused lock deadlock. Profiling is diagnostic evidence, not matched frame/performance or system-wide causality proof.

Specific underlying file condition remains UNKNOWN: no source path/raw data was exposed or recorded. FIFO, cloud hydration, network/offline source, filesystem/permission mediation and other open causes are not proven. Do not mechanically patch the compositor, override accessibility policy, read private wallpaper stores, or call the original rendering bug fixed from these observations. A regular/bounded source admission/read design requires reproduction and current type/locality evidence first.

Closure: own app-menu normal Quit completed; exact-name test process absent,407inputs matched final freeze. `closeout.json` records source-open stage and explicitly `wallpaper_fix_claimed:false`. All Main test/build/sample handles terminal; reviewer closed. No install/sign/commit/system settings/production app or layout modification.

## Remaining actions

Normal Quit only our instance and final hash/process closure checks below. Full goal remains active/incomplete. Library confirmation still pending; no capacity/extra/data/destructive branch approval inferred. Next safe diagnosis: characterize source kind/locality using path-free background observation and reproduce the applicable source-open mechanism with independently generated fixtures; avoid changing user's wallpaper or granting new permissions. The separate reviewer baseline onPagePrepared-teardown lifecycle reproduction remains available. Do not repeat old stage bugs or turn this diagnostic checkpoint into full-parity acceptance.
