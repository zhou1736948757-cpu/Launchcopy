# App Library interaction audit — 2026-10-15

## Scope / baseline
Previous turn: PROGRESS, two reproduced Library state defects repaired; 2589/0, exact unsigned isolated candidate 27bcafb6...,440 inputs. Current supported native getApp returned locked. No UI bypass, app launch, duplicate unlock question or full acceptance. Goal remains full independent reference-experience parity, ACTIVE.

## Immediate plan and concurrency
Main audits approved Library interactions, category draft receipt/recovery and grid-return lifecycle against existing spec and implementation. One read-only sidecar independently checks IME, keyboard/focus and accessibility semantics in the mounted Library view/owner; report only, no new feature or scanner/physics/schema. Two agents including Main, disjoint report-only reviewer and serial Main test/build/UI control. Preserve all dirty work; no reference-source/asset reads, install/sign/commit or production data.

If evidence reveals a real in-scope defect, Main reproduces it with nonzero XCTest before a proportionate patch, then runs exact focused/full/build/package and obtains bounded review. Do not invent or force a defect, use synthetic tests as native certification, implement unapproved branches, or mutate frozen Core/UI physics. If no safe progress remains, document actual native and pending-contract blockers and audit repeated impasse honestly.

## Acceptance / next action
Check source/test coverage for stated requirements, then execute only meaningful new regression evidence or an established repair. Native/restart/VoiceOver/physical gates remain distinct; saved drafts and query context must be retained where the approved spec requires. Source findings alone are not GUI PASS.

## Main interaction findings and new execution
Existing AppLibraryView retains per-AppID dirty category choice through loading/relabel and only reconciles on successful receipt; obsolete/missing identities revoke actions. Existing tests exercise dirty receipt/failure states. No new production defect is asserted from Main's bounded category review.

Added AppLibraryGridReturnIntegrationTests.swift: actual AppDelegate final catalog callback composition, capture, preparation and restore callbacks (not replacement stubs), real mounted unshown fields/tables and latest catalog commit. A visibility-reporting window admits the production transition without ordering/activation; this is explicitly synthetic, not GUI. Tests establish main query and field editor restoration with no independent Library query leakage, and saved app anchor relocation with updated revision/page after catalog collapse. Reduce Motion makes synthetic page selection synchronous; ordinary animation/physical input is not certified.

Initial test harness compilation failed because the nested Fixture lacked explicit MainActor isolation; fixed that test-only declaration. This is retained in return-integration-r1.log, not credited as test execution. Corrected focused run: 2 XCTest/0 failures,0.561seconds in return-integration-r2.log. No production/Core/UI source changed. Full run live handle25918; reviewer continues independent input/focus/accessibility audit.441 hashes captured, all440 prior inputs unchanged. No need to invent another production candidate from test-only edits; exact bootstrap binary remains the code candidate pending native access.

## Confirmed category-focus defect / bounded repair
Reviewer completed input audit: no defect initially established, E1 actual IME chain/E2 category+Tab focus/E3 accessibility actions remain distinct evidence gaps. Report APP_LIBRARY_INPUT_ACCESSIBILITY_AUDIT.md remains historical unchanged.

Main reproduced the concrete E2 resize risk through the actual mounted unshown window: focus wide table then shrink; focus compact picker then widen. Both first responder and preferredFirstResponder remained the newly hidden category control (1 XCTest/4 failed assertions, category-focus-red.log). AppKit did not repair either direction automatically in this fixture.

Only AppLibraryView.layout now remaps a current category responder to its newly visible counterpart. Existing search/marked editor/result focus is not touched. Added a separate test guarding search composition and results focus across both directions. No query/category/action/store/physics changes, no extra IO/task/frame work. Review agent resumed for distinct report-only narrow repair review, twoagentsincludingMain; Main serialfocused live34256. Initial all-green2591/fullr1 precedes this repair and cannot certify the new source.441 inputs refrozen; finalfull/build/package required next.

## Correction to the focus-mechanism interpretation
The red counterpart assertions did NOT establish a retained hidden responder. Main's additional pre/post observation (category-focus-observation.log) confirmed the category control owned focus before resize, but AFTER hiding the actual responder was NSWindow in both directions. Thus AppKit resigned the hidden control but lost category navigation focus instead of selecting the visible counterpart. The earlier hidden-responder interpretation above is superseded, not silently erased.

Initial after-hide conditional repair also failed35/4 because the old control had already resigned before the check. Final repair captures category ownership before visibility changes and transfers only that displaced category focus to its visible equivalent. Search marked-text and results focus are explicitly not touched. Narrow source review ongoing. Final441 input manifest refrozen; Core/UI unchanged. Original red, failed intermediate and mechanism observation logs retained.

## Final evidence / review / next action


Full independent LaunchBetter-experience goal remains ACTIVE/incomplete. Previous turn PROGRESS; this turn added actual AppDelegate grid-return callback coverage and reproduced/repaired category focus loss across wide/compact layouts. AppKit resigns the hidden category control to NSWindow before a post-hide check can see it; final layout snapshots prior category ownership and moves only that displaced focus to its visible counterpart. Search marked-text/result focus retained. No query/category/store/physics change.

Main final35focused/2593full0fail, Debug/Release/package, strict274-key3-language positive/two negative probes;441 frozen inputs match,18 PagingCore/PagingUI sources unchanged. Independent final bounded ACCEPT: APP_LIBRARY_CATEGORY_FOCUS_REVIEW_R2.md (reviewer0tests, read Main logs). Earlier 1test/4fail, ineffective35/4repair, mechanism observations and test-harness compile failure preserved. Interim2591/0 predates finalrepair and is not its acceptance.

Current unsigned/uninstalled candidate: .build/candidates/library-category-focus-rc-20261015-r1/LaunchcopyUITest.app; executable afa1df6cf2cf58deab1520422a14087a14ac315639cbac057093cbc07a884e9a. Forty owned Info-only fixtures prepared, not launch-success evidence. Supported desktop check still Maclocked; no app started, no GUI/restart/realIME/VoiceOver/physical gate. Existing unlock request remains, no bypass/duplicate request. All agents/build jobs closed/completed; no formal-data mutation/install/sign/commit.

Next executable action after unlock: direct supported opening of exact isolated candidate, following Workflow/results/APP_LIBRARY_NATIVE_VALIDATION_PROTOCOL.md. Full handoff: Workflow/results/APP_LIBRARY_INTERACTION_CHECKPOINT.md. Broad capacity/usage/gesture/destructive approvals and actual wallpaper source/long-tail/60Hz AB/120Hz/accessibility/distribution gates remain intact. This is concrete aligned progress, not full completion or repeated no-progress blockage.

