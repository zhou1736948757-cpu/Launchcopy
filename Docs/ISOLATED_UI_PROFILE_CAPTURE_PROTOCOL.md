# Isolated Candidate GUI Capture Protocol

Date: 2026-10-13. Preconditions: approved test profile, frozen source manifest,
nonzero full suite, Debug/Release build, independent storage/service isolation
review PASS. No writable GUI while that review is FAIL/pending.

## Identity and safety

Use exact candidate LaunchcopyUITest.app / com.launchcopy.test.folderrename,
ordinary --ui-test-windowed, --ui-test-profile gui. This is a test-only packaged
identity, not an installed update. No process-wide pkill, no resident app Quit.
Record exact executable SHA and config before launch. A newly created terminal
window may launch the command through native CUA; every actual UI interaction
uses CUA, no AppleScript/event tap/AX shell injection. Never launch through
cua.getApp before profile arguments have been set (it would start default mode).
Once started, bind the distinct test bundle identifier and inspect fresh state.

Create synthetic Info.plist-only .app fixtures under candidate-local
UITestProfiles/gui/Applications. No executable launch smoke on these packages:
they intentionally cannot certify NSWorkspace real app launch. Use37 fixtures
with --folder-lab for a two-member folder plus35 top-level entries. No original
reference images/icons/code. Profile is local and must not scan real app roots.
Only synthetic titles/aliases may be used; do not save raw real catalogs or
window titles into evidence. CUA snapshots with unrelated personal windows are
not persisted as evidence.

## Interaction matrix

1. Verify ordinary non-covering window, search control reachable and no top page
   number, synthetic content present, no full-screen/cross-Space behavior.
2. Open folder through actual cell, click title button, live text entry/Enter,
   close/reopen label retained; Escape draft does not save. Test field focus-loss.
3. Use settings/app context actions: alias+original search, hide/restore, folder
   assignment, labels/blur Apply. Mark each observed vs untested, not blanket PASS.
4. Normal Quit ONLY test instance; confirm its process gone without stopping any
   other process. Reopen exact same candidate/profile; verify saved title/member
   structure and settings. This is a true process restart test under disclosed
   isolation config, not full production activation/performance acceptance.
5. For write failure, first establish LKG in the isolated journal; intentionally
   make only that synthetic Layout directory unwritable (never production). Rename
   through UI, verify notice, Quit failure -> default Cancel -> input usable. Restore
   test-directory permission before a retry/restart. Capture counts/outcomes, not
   private content. Always leave synthetic test fixture recoverable and permissions
   restored, even on a failed assertion. Do not exit without Save unless explicitly
   testing approved Quit Anyway on disposable synthetic data.
6. Hide/suspend failure lifecycle, Reduce Motion override and drag remain separate
   checks; automation does not simulate a physical trackpad fluidity rating.

## Evidence boundaries

Save raw code/build/test logs, manifest and neutral GUI step/outcome notes.
Representative pixels only when they show the test window without unrelated
content. Do not claim120Hz, physical input, production global activation, login
registration or distribution readiness. A failed/native-tool-blocked step stays
FAIL/BLOCKED/UNTESTED. Return focus safely and normally Quit only this test instance.
Remaining complete-product parity stays on LAUNCHBETTER_PARITY_STATUS.md.
