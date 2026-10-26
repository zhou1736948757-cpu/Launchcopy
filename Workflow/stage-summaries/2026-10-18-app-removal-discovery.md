# App removal — discovery and bounded proposal

Date: 2026-10-18
Status: PROPOSED; NO IMPLEMENTATION OR REMOVAL

## Objective and confirmed current facts
Preserve full parity scope rather than silently omit the explicit destructive-action backlog. Current approved parity spec reserves uninstall/delete for a specific decision. Actual AppContextMenuController actions are launch, alias, clearAlias, hide and reveal plus organization. AppLibraryActionRequest already carries appID/canonicalURL/catalogRevision/generation. No app-removal implementation/spec was found in current project sources/docs. Independent implementation and routine autonomy do not remove this explicit major-feature decision gate.

## Proposal and rationale
Docs/APP_REMOVAL_PROPOSAL.md defines one-item Move to Trash with default-Cancel confirmation, conservative local/current-user-owned/non-system/not-running/profile-bounded eligibility, current binding checks, no privilege/permanent-delete/forcequit/support-file cleanup, receipt-based async execution, existing refresh/dormant organization and bounded Quit. It does not mislabel simple bundle trash as complete uninstall or race-proof deletion. No extra gesture/page-model changes bundled.

## Evidence and unchanged baseline
Current bcf43c54 candidate/501sourceinputs/3038green retained; prior goal turn actualnativeUndoRedoPROGRESS. This turn creates a substantive English next-feature contract after inspecting current source/approved roadmap; no code/UI/build/test/data changes, no worker needed for small serial discovery. Formal data/reference projects/assets/OS preferences/install/sign/commit/process signals untouched. Full objective incomplete.

## Next action
Request one material product confirmation. While pending, continue only existing safe acceptance/diagnostic work when there is a concrete unclosed gate; do not implement destructive behavior or repeat closed tests to simulate progress.
