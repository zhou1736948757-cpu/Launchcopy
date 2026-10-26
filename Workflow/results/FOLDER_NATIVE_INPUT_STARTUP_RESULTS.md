# Folder Native Input Startup Repair — Final Handoff

Date:2026-10-16
Status: CODE_AND_PACKAGE_VERIFIED; PHYSICAL_PENDING; DIMMING_CHOICE_PENDING

## Actual user evidence and correction
User reports folder-interaction r2 still fails real two-finger paging. Previous2788green, bounded source review, native page-button and resize observations did not establish this gate; preserve the user-reported failure. User perceives a black shadow because the whole background dims during opening; no extra-black-frame causal claim is established. A separate recommendation to remove dimming is pending explicit user choice (Docs/FOLDER_BACKDROP_FEEDBACK_PROPOSAL.md); no visual change was silently implemented.

## Established cause
Actual applicationDidFinishLaunching installs content assembly before constructing/assigning the window. Old installFolderWiring assigned onFolderScroll only if self.window existed. That assignment was skipped at production startup. The later native window installed folderOpenStateProvider, recognized an open folder and returned after calling a nil optional scroll callback. Thus the event was consumed without reaching the inner pager. Previous Fixture assigned owner.window first and hid this lifecycle defect. This is an established source/order cause supported by an actually failing corresponding regression, not a whole-device smoothness conclusion.

## Bounded repair
Window creation now calls installFolderWindowInput(on:) to install BOTH folder state provider and scroll callback, independent of content creation order. Both resolve the current owner state/overlay dynamically via weak self. Removed the conditional local-overlay callback installation in content wiring. One authoritative window route remains; no global event monitor, input remapping, physics or fallback animation change.

## Tests and independent review
- Actual startup-order regression RED:1test/2assertionfailures (nilcallback and zero inneroffset), log .build/folder-native-input-startup-red.log.
- Fixed focused66/0; strengthened actualowner31/0. Tests use the SAME production window-input helper for content-first and window-first construction. Events enter window.sendEvent; they advance the inner offset, release/settle to committedpage1 and update visible member while preserving outer page/offset. Blocked events remain consumed. Replacement test retains the retired overlay and proves original window route reaches only current overlay without reinstalling window wiring.
- Final full suite2790tests/0failures,86.491s: .build/folder-native-input-full-final.log. This final run includes strengthened completion assertions.
- Debug build/actualRelease packaging/probe passed; packaged290keys/signatures across3languages; git diff --check passed. Existing unrelated test warnings are not represented as zero warnings.
- Banach independently confirmed startup cause and final source repair, with no remaining blocking findings in bounded scope;463/463 hashes matched. Reviewer ran0tests/builds/UI, not a physical PASS. Report Workflow/results/FOLDER_NATIVE_INPUT_STARTUP_REVIEW.md.

## Frozen change scope and candidate
463manifest entries,461unchanged relative priorr2. Only Sources/PagingPrototypeApp/AppDelegate.swift and Tests/PagingUITests/AppDelegateBoundedRegressionTests.swift changed. OuterPagingCore/mapper/frame source/parameters, folder visual layout/material, resources, Package, schemas, canonical order and reference sources untouched. Broad dirty tree preserved.

New unsigned/uninstalled candidate: /Users/mac/Projects/Launch_Copy/PagingPrototype/.build/candidates/folder-native-input-rc-20261016-r1/LaunchcopyUITest.app
Executable SHA256:6b2e1ab8a6ade22249136855fcc5fdc9804083174df9b6d0aaa6e64354e8579e
Candidate-local40Info-only fake apps/35-memberfolder seeded from prior test profile; layout/library bytes identical and verified. No wallpaper cache, lock files or formal preferences/data copied. Fixture apps do not contain launchable executables; outeronepagefixture cannot prove outer paging performance.

## Native boundary and next action
CUA returned Mac locked while attempting to inspect old test instance. No normal Quit or UI action occurred; old test remains available, new candidate NOTLAUNCHED. Do not confuse current running oldr2 with this repair. All agents/build/test jobs closed. Next after manual unlock: normally Quit ONLY old isolated test instance, open exact new candidate in ordinary/non-topmost mode and verify native scroll delivery, then user actualtwofinger follow/settle/background isolation. No physical PASS or claim that all reported symptoms are fixed. Dimming remains unchanged pending separate choice. No install/sign/publish/commit/reset/clean/delete/processkill/formaldata/OSsecurity changes.

## Receipts
.build/verification/20261016/folder-native-input/final-receipt.json; source-inputs-final.json; archivedred/focused/full/build/package logs; two final source/test copies; independent review copy. Prior receipts and candidates retained. Whole-product goal remains incomplete; previous wallpaper/long-tail and reserved feature decisions unrelated.
