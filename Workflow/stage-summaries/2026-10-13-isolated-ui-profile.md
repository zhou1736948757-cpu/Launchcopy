# Isolated UI Profile and Rename Repairs — Checkpoint

Date: 2026-10-13. User approved isolated test configuration and normal Quit of
only the explicitly launched test instance. Normal installed/resident apps remain
untouched. No commit/install/distribution signing or original reference assets.

## Specification and ownership

Docs/ISOLATED_UI_TEST_PROFILE_PROPOSAL.md is the approved specification (historical
filename retained). Main assembly, Socrates parser/profile pure helper (closed),
Galileo independent scoped Reviewer. At most3 active including Main; now Main and
Reviewer only. Existing dirty HEAD319b8cc preserved. No historical chef runtime.

## Implementation

Explicit --ui-test-profile <id> requires --ui-test-windowed. Candidate .app and all
output paths canonicalized; candidates-only, ASCII bounded IDs, symlink escapes
and non-directory collisions rejected. Stable hashed candidate/profile namespace
separates activation/appearance/management suites, layout and wallpaper cache.
Configure before opening production stores. Synthetic catalog roots only; omitted
roots use candidate-local Applications. No fallback to ordinary layout/suites on
invalid profile. Existing production namespace/catalog/adapters unchanged without
profile. Fake global/session/login services, no Multitouch backend. Settings Apply
cannot swap fake services into real system registration. Test window title distinct.

R5 rename late timeout callback now verifies receipt submission coverage and
reschedules latest observer on mismatch. R7 shared hide/suspend cleanup invalidates
Quit first, ends retained sheet/aborts standalone modal; never approves by Hide.
Store replacement and teardown share prompt cleanup. Snapshot rename-r1 remains
SOURCE FAIL and is not promoted despite1883/0; original report history retained.

## Execution evidence

Focused94/0 (including parser36, profile15, profileassembly5, runtimefactory2,
owner19, queue13, quit4) at19:38:50.755 JST. Full1913/0 at19:40:57.597 JST,30.629s.
`.build/verification/20261013/ui-profile/` contains logs and309-file source/test/
script/package manifest, all checked unchanged. Debug/Release isolated candidate
packaging underway; existing diagBackend compiler warning remains.

Source rereview pending, no writable GUI/candidate launch/true restart PASS yet.
Desktop Finder CUA accessible. Planned packaged test-only product LaunchcopyUITest,
bundle com.launchcopy.test.folderrename, distinct from resident selection. Binary
source follows frozen manifest; different bundle identity and fake activation are
disclosed and cannot certify production activation/login/fullscreen performance.
Use ordinary window or Desktop2, not screen cover. Mutating CUA tests wait source
isolation verdict, target only synthetic profile. Preserve artifacts and exit only
that instance normally. Full goal remains active; remaining parity ledger applies.

## Packaged checkpoint

Debug and Release package exit0 (Release10.26s). Exact isolated candidate:
`.build/candidates/folder-rename-ui-profile-rc-20261013-r1/LaunchcopyUITest.app`,
SHA256 `a9f9059551f476faf7feb61e7d0d57443e4dd5cea68bd44a28b678466a455eee`.
Manifest beside app;309-file source manifest checked after build.37 synthetic
Info.plist-only fixtures and a CUA-terminal launch runner prepared, not executed.
Scoped independent source review remains in progress, not PASS. Candidate not
installed/launched. Protocol: Docs/ISOLATED_UI_PROFILE_CAPTURE_PROTOCOL.md.

## Independent review and I1 repair

Combined source review in Docs/UI_TEST_PROFILE_REVIEW.md: rename/durability PASS,
isolation FAIL I1/P1 (nested ordinary directory symlink followed outside the
synthetic root). No candidate has been launched; r1 preserved as this FAIL snapshot.
Main enforced the existing followDirectorySymlinks=false contract for all entries
before target resolution, preserving explicit true semantics. Real reader-spy test
proves no outside metadata read, while explicit-follow regression remains.
Configured profile uses shared makeContentAssembly seam (fails closed before
profile configuration); repeated actual dataSource refresh excludes outside
record/URLResolver while retaining valid local record/URL.
Focused50/0 at19:53:06.447 JST0.196s after normalizing macOS /var path alias and
using actual cached-snapshot begin callback in the fixture (not fake resolver
updates).309-file r2 source manifest frozen; full-r2/rereview pending. Must rebuild
a new candidate for repaired source; do not launch earlier failing r1.

## I1 repair execution/build identity

Full-r2:1917/0 at19:54:07.779 JST,30.485s. Debug success; Release10.71s and
new candidate assembled:
`.build/candidates/folder-rename-ui-profile-rc-20261013-r2/LaunchcopyUITest.app`.
SHA256 `fb20fab5fc993e4a8d5ea9f7ed8578f5aa6d1e63941e71444ca6425233ece4ed`.
309 r2 manifest entries checked unchanged after build. Existing diagBackend
warning remains. Previous initial repair run had2 fixture-only mismatches
(/var canonical spelling, resolver callback not exercised); retained logs,
corrected focused50/0 and full1917/0 replace that execution result. Independent
final isolation rereview pending (Galileo01a134ab-0094-7b21-b2f0-13363ed4ef7b).
Do not launch old r1; normal GUI/restart of repaired r2 still not executed.

## Final scoped review and honest GUI launch boundary

Reviewer final r2: rename/durability SOURCE PASS and isolated test profile SOURCE
PASS. All309 source fingerprints and full executable SHA independently verified.
Previous FAIL snapshots retained. Reviewer closed; no subagents remain active.

CUA attempt to select com.apple.Terminal for the approved launch runner returned:
"Computer Use is not allowed to use the app 'com.apple.Terminal' for safety reasons."
No terminal was controlled and no app candidate launched. Do not route around the
blocked application via Finder/another shell UI or an undocumented CUA API.
Hand off launch of the already prepared runner to the user; after a confirmed
manual launch, CUA may bind the distinct test bundle and perform the approved
ordinary-window interaction matrix. This is a native-tool policy boundary, not
a locked Mac, source failure, GUI FAIL, or inability to continue source development.

Manual runner:
`/Users/mac/Projects/Launch_Copy/PagingPrototype/.build/verification/20261013/ui-profile/launch-ui-test-r2.command`.
It starts ONLY the known r2 executable with --ui-test-windowed --ui-test-profile
gui --folder-lab --disable-telemetry-bridge; root has37 metadata-only synthetic
fixtures. No ordinary layout/alias/preference/root write or process stop occurred.
No install/sign/notarize/commit. Normal test-instance Quit/restart still untested,
not PASS. The full parity goal stays active; continue pending appearance/settings/
sources/Library work under approved scope while waiting for safe runtime entry.
