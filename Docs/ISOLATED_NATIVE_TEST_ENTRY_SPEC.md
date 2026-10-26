# Direct Native Isolated Test Entry — Proposed Contract

Status: APPROVED_IMPLEMENTATION_CONTRACT,2026-10-14. User explicitly selected the recommended direct-entry scheme. This is a development/test artifact entry,
not a new production feature or permission to bypass tool restrictions. Existing
independent test data/window contract is approved; new metadata entry is now specifically confirmed for implementation. Main may separately repair already-required
fail-closed CLI parsing without this confirmation.

## Problem and outcome

Native app control can open an allowed app, but cannot pass CLI profile arguments.
The current test .app therefore cannot safely be opened directly: it defaults to
production data/window mode unless launched through the CLI runner. Terminal
control is disallowed. Do not open Terminal/Finder/scripts through another tool.
Provide an explicitly packaged test app whose OWN normal supported startup is
isolated, allowing direct native app control without arbitrary command execution.

## Scope and non-goals

- Add opt-in versioned bundle metadata to a unique test candidate only. The ordinary
  production bundle/default startup must remain unchanged.
- Support the existing windowed/profile/folder-lab test behavior; do not invent a
  second launcher stack, change paging parameters, source scanning policy or data.
- No install/sign/notarization, process kill, original preference/layout/copy,
  reference code/resources, Library/capacity/new gestures or general shell runner.
- Never use this entry to interact with a tool-denied app. If native control of the
  test app itself is denied, stop at that boundary, not alternate tools/surfaces.

## Required startup/data behavior

1. Package only with explicit test-entry opt-in, reserved test bundle ID, valid
   profile ID and canonical candidate location. Metadata consists of a strict
   version/profile marker, not an array of arbitrary commands or executable paths.
2. Normal native open of THAT marked app resolves the same candidate-derived test
   namespaces, fake global/login services, ordinary non-topmost window and synthetic
   apps. It must not read/write production settings even before showing a window.
3. Missing marker in a production app preserves legacy production behavior. A
   reserved test-entry bundle with absent/corrupt/future marker must reject before
   initializing AppKit/preferences/catalog; never silently enter production mode.
4. Any malformed metadata, wrong bundle ID/location, profile-resolution error or
   CLI parsing error in the test entry is fatal/headless. Valid explicit CLI runner
   flags with the SAME profile remain compatible; a conflicting profile/window
   mode must reject rather than select another namespace or fullscreen behavior.
5. Existing UserDefaults/profile path safeguards remain the sole identity/storage
   authority. Never import layout/cache/preferences from old/production candidates.
6. Hash Info.plist/test-entry marker alongside executable/resources in the candidate
   identity. Native startup observations must identify the exact marked candidate;
   app display name is not sufficient.

## Architecture, testing and delivery

Use a pure typed startup decision before NSApplication.shared. Reuse AppArguments
and UITestProfile for validation; application assembly and approved profile remain
owners of storage/services/UI. Packaging validates metadata and emits an explicit
manifest; normal builds and raw developer binaries are unaffected.

Test absent/valid/malformed/future metadata, reserved/wrong bundle identity,
location/symlink rejection, zero-CLI defaults, same/conflicting CLI profiles,
malformed CLI and existing headless error exits. Nonzero focused/full XCTest,
independent source review, Debug/Release, unique candidate/source/executable/plist/
resource hashes; no production fallback even on error. Source/code gates are not
native GUI/physical acceptance.

After confirmation and code gates, open ONLY the allowed test app through native
app control; inspect real UI/session/language/geometry/input behavior. Quit only
our test instance normally if necessary, never the user's other applications.
User currently says the computer is not in use and asks Main to act directly;
respect that scope and latest native availability. Full parity remains incomplete.

## Approved implementation design

Marker key LaunchcopyUITestEntry is an exact dictionary: version1(integer, not
Boolean), profile(valid existing ID). Reserved bundle ID com.launchcopy.ui-test
requires that marker for direct/native startup. Wrong/missing/future markers reject;
ordinary production/no-marker defaults unchanged. Explicit CLI testprofile must
match marker; windowed-only still implies the marked profile. Marker always selects
windowed+folder-lab, independent of fullscreen (windowed takes precedence). Source
root overrides and neutral-content flags cannot substitute a real catalog in a
marked entry. Explicit diagnostic flags do not modify its storage identity.

Pure resolver returns configured options or a typed neutral rejection before
NSApplication.shared. Valid isolated profiles resolve the canonical candidate path
before AppKit; actual assembly repeats its existing safe resolution. Existing legacy
non-test parse fallback and five fatal tuning errors remain. New headless startup
check executes THIS resolver and prints only mode booleans, no paths/IDs/names.
Packaging opts in through NATIVE_UI_TEST_PROFILE, validates reserved bundle and ID,
records Info.plist digest and explicit mode. Existing explicit runner remains
compatible for the same profile, but older unmarked reserved artifacts are no
longer the safe native entry; do not launch them directly.

Implementation handoff correction: actual AppMain has FOUR fatal tuning families
(decay/glide/overshoot/timer-tolerance), not five. The initial worker packet/count
was mistaken. Invalid frame-driver preserves ordinary legacy fallback absent test
intent; explicit test intent still rejects. Main corrected the disjoint worker
tests to match the actual pre-existing source contract, not a new product policy.
Both workers froze/closed before Main's final integration and serial verification.

Review repair clarification: neutral startup check has highest precedence over
help/composited/error/performance/smoke output; rawCLItest intent always preflights
before any diagnostic mode. Ordinary non-test headless diagnostic behavior remains
unchanged. Canonical packaging containment is validated before ANY mkdir/artifact
write, not merely native candidate ancestry.

## 2026-10-19 bounded Sources fixture extension
Version1 strictprofile-only metadata and defaultbehavior remain unchanged. A selected explicitversion2fixed sources-v1preset extends native verification only, retainingreservedID/candidateprofile/fakes/ordinarywindow/failclosed safeguards. See SOURCES_NATIVE_FIXTURE_ENTRY_SPEC.md for newexactmarker/path/CLIrejection/packagingcontracts; noarbitrarycatalogrootmetadata. This adaptation falls within alreadyapprovedisolatedtestconfigurationand humanroutine-decisionautonomy, not a newproductionfeature or filesystemgrant. Native Sources acceptance stillpending.
