# Main-grid screen-relative proportions

Date: 2026-10-19
Status: IMPLEMENTATION_IN_PROGRESS / NATIVE_ACCEPTANCE_PENDING

## Objective and scope
Human requests a modest revision to icon size, arrangement and position relative to screen size, informed by iOS. Review public Apple guidance and current independent AppKit geometry; preserve paging, logical capacity, saved order and independent folder layout. No reference product/source/assets access. Existing workflow waived; Main owns local investigation, one bounded read-only layout reviewer audits numeric geometry. At most two agents including Main. No shared writes/build jobs.

## Baseline and confirmed facts
Current AppGridGeometry stretches all columns across bounds minus48pt; cellHeight88pt, preferred inter-cell spacing16pt, top96pt/bottom24pt. GridItemContentGeometry caps glyphs to the explicit32–64pt preference and available caption space. Consequently horizontal separation increases on wide windows without any corresponding glyph growth; folder count captions can further reduce folder glyph fit. Existing7-row ordinary envelope/centered partial rows and occupied-row search centering are deliberate contracts, not incidental bugs. All511 frozen code/package inputs match at discovery.

## Decisions and limitations
This is visual design discovery, not a new automatic-capacity feature. Apple guidance is a reference for safe areas/adaptation and icon-size options, not evidence of a published universal SpringBoard spacing formula. Candidate numeric values are independent desktop tuning. No row/column/order/persistence/physics/folder/OS/data change or real-device/performance acceptance is inferred. A bounded proposal and independently authored schematic comparisons will precede any code change.

## Changed files and evidence
This summary, a proportion proposal and authored design-only comparison artifacts. No implementation/test/build/candidate change. Prior3098/0 remains historical, not rerun. Independent audit pending.

## Next executable action
Finish the computed same-preference layout comparison, review visual tradeoffs, then implement only the selected bounded main-grid policy with shared geometry for rendering/readability/hit-testing/source motion, tests and isolated native verification. Do not silently override saved icon preferences or reduce logical capacity.

## Selected bounded change

Boyle read-only audit independently confirmed all three baseline calculations and recommends128pt maximum main-grid cell width. Main selects that small pure geometry change under the human request/routine autonomy. Main owns the two-file implementation and serial tests; no concurrency build conflict. Do not change vertical placement, icon preference, folder policy, capacity, storage or physics. Prior discovery-only statements are historical; no new PASS yet.

## Focused verification and source review

Changed exactly three production/test inputs: AppGridGeometry.swift, AppGridGeometryTests.swift (+3 test methods), AppGridPageViewTests.swift (two old24pt full-row-origin expectations updated to actual180pt/128pt/center assertions; partial/single centering checks retained). Focused r1 executed30tests/2failures, both legacy coordinate assumptions; r2 executed30/0 after adapting those intentional layout expectations. No broad assertion deletion. Existing compile warnings retained, not zero-warning claim. James independently accepted final stable three-file source delta; no runtime/performance verdict. Reviewer closed; Main owns ongoing serial full suite/Debug/Release/package.

## Full-suite first run and compatibility adaptation

Full r1 executed3101tests with3assertionfailures: two additional old full-width assertions in CompactGridGeometryTests (minX24/width177.6 instead of new148/128 at1000 x1000), and an AppLibraryOwnerIntegrationTests2-second readiness wait. Main preserves all vertical checks and adds explicit centered-row verification when updating those intentional full-width expectations. No Library source/test change or timeout relaxation; the isolated Library failure is not yet established transient or geometry-related. Four source/test inputs now differ from baseline; latest freeze source-inputs-r2.json. Focusedr3 includes both updated geometry suites and that exact Library method; fullr2 will follow before delivery. Ptolemy reviews only the additional one-file compatibility delta, disjoint from Main serial tests. No green claim before actual outputs.

## Final automated suite

Focusedr3 passed38/0, including the exact Library method that missed its2-second wait in fullr1. Fullr2 passed3101/0 (199.120s XCTest /205.150s process). The earlier Library wait failure did not recur in either control; no claim of diagnosed scheduling causality and no Library source/test/timeout edit. Ptolemy independently accepted the fourth test-file arithmetic; source and compatibility reviewers both closed. Debug build passed; Release/package still in progress at this checkpoint. No native/physical/aesthetic PASS yet.

## Delivery / final native boundary

Full3101/0, focused38/0, Debug/actualRelease/package361keysx3 passed;511inputfreeze matches, exactly one production+three testfiles changed. New75ba5344 candidate packaged and bounded native observed on PIDs40324/42772 at1000 x700pt. Main6x5, folderglyphopen/ESCclose, single-resultcenter, nativeAppearance/restart5x7/28-54-12 persistence verified. Restored6x5/queryempty and normalQuit/exactabsence; no final6x5reopen. Old86profilepayloads/layout unchanged, no history/Library import. Menustate recovered with documentedCancel, not a confirmedproductbug. Wallpaperlaterready, intermittentcauseunresolved. All reviewers/jobs terminal. Human aesthetic/physical/wide/drag acceptance remains pending. Full report Workflow/results/MAIN_GRID_PROPORTIONS_RESULTS.md; final-receipt-r1.json/native-results-r1.json.
