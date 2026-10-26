# Folder Viewport Fit — Candidate GUI Validation

Status: GUI_UNEXECUTED, 2026-10-14.

## Candidate and entry boundary

Candidate: `.build/candidates/folder-viewport-rc-20261014-r1/LaunchcopyUITest.app`
Executable SHA-256: `3cd72adc543a386ef1b9a2318226bae0067a9b0a50c9bf738bc97a040f533db8`.
Manual runner: `.build/verification/20261014/folder-viewport-fit/launch-ui-test-r1.command`.

The prepared runner opens an ordinary non-topmost window using the isolated
folderfit profile, 385 metadata-only synthetic bundles, and fake global/login
backends. It has NOT been executed. No installation or production-data reset is
required. Native access previously reported a locked Mac and a Terminal control
policy denial; do not bypass these boundaries through another tool. The next
interactive entry requires manual user launch/unlock. Only normally Quit the test
instance launched for this session; do not stop unrelated processes.

## Interactive checks

1. Repeat the approved icon/type gates from `ICON_TYPE_GUI_VALIDATION_PLAN.md`
   using this newer candidate; historical candidate results do not transfer.
2. Open a full 35-member folder and resize the ordinary window, including a
   compact approximately 1000x600 viewport. Confirm the last row remains above
   the footer, with no title/footer interception or negative row positions.
3. Check first/last rows with pointer launch, context menu, keyboard selection,
   folder pagination, drag within the folder, and move-out proxy. Retain the
   established typewriter navigation and cancellation behavior.
4. Check mixed appearance values (32/9, 48/11, 64/16), hidden names, reopening,
   entrance/exit interruption, and queued Apply during a held pointer/drag/title
   edit. Confirm fitted icons do not overlap captions/counts.
5. Very short cells may clip text or have a zero-size icon. Do not classify that
   as readable universal fit. Verify zero icons do not acquire phantom padded
   launch hits. The pre-existing 200pt minimum panel may exceed smaller owner
   bounds; record this limitation rather than claiming universal viewport support.
6. Normally Quit/relaunch the same isolated profile and check accepted appearance
   preferences. Test persistence is not production-profile migration acceptance.

## Evidence and exclusions

Record candidate hash, viewport, actions, actual result, and errors. Keep GUI,
VoiceOver, real-icon quality, restart, physical paging AB, and 120Hz evidence
separate. Metadata-only bundles do not validate real app launches or icon workload.
Current code gates: 49 focused and 2163 full tests, zero failures; Debug/Release;
bounded source review clear; 341 postbuild fingerprints. These do NOT mark the
interactive checks above PASS. Long-tail >25ms causality remains unresolved.
