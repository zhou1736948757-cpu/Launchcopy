# Folder Exterior Blur Feasibility Results — 2026-10-16

## Decision
Do not integrate/enable the proposed synchronous AppKit own-view snapshot path in the current candidate. Directly reducing the requested output resolution reduced cost but did not make main-thread capture negligible in the measured synthetic app assembly. The user prioritizes performance and permits omitting exterior blur. Keep the already-built panel glass candidate and leave exterior blur deferred rather than knowingly add an unvalidated opening stall. This is NOT proof that every exterior blur implementation is too expensive; a retained native material or immutable-model background renderer has not been benchmarked and may behave differently.

## Experiment isolation and actual scope
Canonical463 inputs copied into .build/experiments/folder-blur-feasibility-20261016-r1/Package. Only the copy's AdaptiveFolderOwnerTests.swift modified. Actual app assembly/provider/renderer and native grid cells with generated blue-square icons; unshown NSWindow, synthetic generated checker background as root sibling and NSSearchField chrome sibling. No real app scanning, wallpaper, OS screenshot APIs, window ordering/activation, user input injection or persisted pixel data. All captured pixels stayed in memory. Existing production/test/package/profile bytes unchanged.

The probe requests NSBitmapImageRep at a capped256/512/1024 longest edge with logical view size, then calls own-root cacheDisplay. This bounds the allocated output, NOT every internal AppKit allocation/cache/texture. It verifies removal of chrome/grid changes captured bytes, so a cheap wallpaper-only or blank result cannot pass. This checks content presence, not complete screen-compositor/presentation fidelity.

## Actual executed evidence
First experimental run:1 test/3failed assertions because raw visible-not-hidden count included5 offscreen cells in the retained next-page host;40 retained,35 actually in the root viewport. Timings from that failed test are preliminary only. Also corrected misleading cold label: repeated timed captures followed3 inclusion-check captures and are not cold captures.

Finalr2:1 test/0fail,8.549s.35 visible native cells asserted using root intersection;40 retained recorded. Three viewport sizes1000x700,1470x956,2560x1440 points crossed with three capped image edges.9cases x31 timed samples =279 timing samples, plus27 initial/inclusion captures. Reused one CIContext; context creation separately50.51ms. Thermal state nominal at end. Sources, raw r1/r2 logs, scalar JSON and receipts retained under .build/verification/20261016/folder-blur-feasibility/.

| Requested longest image edge | Main allocation+capture remaining median across viewports | First validation capture across viewports |
| --- | --- | --- |
|256px|6.38–7.15ms|8.25–13.00ms|
|512px|8.71–10.46ms|10.04–11.90ms|
|1024px (small viewport stays1000px)|17.73–20.46ms|20.05–28.86ms|

At1470x956pt specifically:256px capture median6.64ms/first8.80ms;512px9.56ms/first11.61ms;1024px19.33ms/first20.78ms. Warm synchronous CI-render medians across all cases were approximately0.83–3.64ms; these DO NOT include asynchronous handoff/texture upload/final composition. Moving the filter off-thread does not move AppKit capture off the main thread. Timing comparisons across fixed-order cases are descriptive, not a matched production A/B or causal regression test. No arbitrary time threshold was asserted as a test pass.

## What this changes
The earlier idea that a one-shot low-resolution background would necessarily be cheap is not supported enough to ship. Measured capture alone occupies a material portion of a16.67ms60Hz frame budget; first-capture behavior is less favorable, and the user specifically values launchcopy's fluidity. The current candidate gets NO exterior snapshot code, new timer or capture workload. Do not hide this cost by waiting before opening, repeatedly regenerating while idle/paging or popping in a late blurred background.

## Boundaries / next action
No new physical or native material-performance PASS. Desktop still locked on fresh CUA check; old clear-backdrop87504 has not been Quit and new panel-glass05c415a0 has not launched. One earlier unlock request remains pending, not repeated. Native panel appearance, first-frame compositing, actual touchpad following/settling and matched cold/warm perf still need an unlocked desktop. Future exterior work should compare a retained native within-window material and its system tint/brightness behavior before undertaking another custom renderer. Preserve no new dimming, stable editor host and all accepted paging/layout semantics.

Production baseline remains2794/0 with prior Debug/Release/package and SOURCEPASS; no canonical full suite rerun was needed/claimed for this isolated experiment. Full LaunchBetter-to-Launchcopy goal remains incomplete.

## Independent source review and interpretation correction
Cicero completed a source-only probe review, zero build/test/UI executions, report Workflow/results/FOLDER_BLUR_PROBE_SOURCE_REVIEW.md. It reviewed finalr2 sourcehash84849a21766c2fcb9c65bcc16ea56676cd41edaa5c51183f6cc10c9f282c58b8 but did not certify r2 execution or the whole canonical copy; those verifications are Main's evidence above. Reviewer report retained; agent closed.

The byte-difference checks are inclusion SMOKE only, not per-cell or region/color accuracy. Filtered output size does not independently prove correct blur appearance. All cases used radius12 in image pixels, so they are NOT matched point-space blur-quality comparisons. Capture-cost interpretation is separate from that visual mismatch; no equal-quality filter-speedup claim follows. CI timings include assertion/API overhead and omit object release/autorelease draining, scheduler handoff, complete GPU/upload/display and animation costs. Three validation images remain live while sampling; single-buffer bytes are NOT peak-memory or process-RSS evidence. Captures are already-warmed/repeated and context-shared, not system-cold. Do not sum summarized medians/percentiles into an end-to-end percentile. The limited result is enough to avoid shipping an unvalidated synchronous capture cost, not to accept any final effect or reject all alternatives.
