# Caption Visibility Maintenance and App Library Discovery

Status: DISCOVERY_AND_TESTS_FIRST_MAINTENANCE, 2026-10-13.

## Objective and original scope

Ensure the approved label visibility setting applies coherently to drag visuals,
including durable move-out content, without changing geometry/input/performance.
Prepare the next substantial separate optional App Library/category/details/
override implementation contract; do not substitute maintenance for full parity.
Library product scope is approved in PARITY_SPEC, specific contract needs approval.
Icon/type and capacity proposals remain unanswered; no inferred consent.

## Baseline and limitations

Latest Appearance Apply maintenance2100/0, bounded source PASS, Debug/Release and
334 fingerprints matched. Exact candidate appearance-apply-rc-20261013-r1, SHA
544f8f2ce7086ed15d346e307c34a4f790a97c7444fd79a0f896790fbec1ca76.
No installed/launched candidate; native last locked/prior policy denial remains.
No GUI/VoiceOver/real restart/physical/120Hz PASS from structural evidence.
Existing tree is dirty and preserved; no commit/reset/cleanup/process stop.

## Ownership / plan

Main locally reproduces approved drag-label inconsistency and owns bounded
DragUIVisuals/test repair plus docs/serialized Swift execution. Existing survey
already identifies the independent preview drawing path; do not redo that survey.
One read-only helper owns Library catalog/management/identity/lifecycle seam
survey, only one separate Workflow/results Markdown. At most Main+2; disjoint
writes; no source/test/build/apps or reference sources/assets by helper.

## Maintenance contract and gates

First reproduce using a real bound source AppGridCellView with showsAppLabels=false
and inspect the actual native preview caption, not just a boolean seam. Caption
should remain hidden when source clears/detaches/host changes and move-out preview
continues from cached content. Next visible source restores captions; nil/source
absence cannot leak stale previous name/state. Accessible source names remain.
No new scans/icon loads/snapshots on pointer move, no per-frame preference IO and
no changed drag regions/thresholds/identity/capacity/physics. Failed repro means
no speculative fix. Record red/green focused/full, review/build/hash, preserve GUI
boundaries. Proposed Library remains discovery only until confirmed specification.

## Next action

Main inspect existing preview capture/content/reuse tests and run failing minimal
native-view test. Helper reports concrete Library seams/metadata availability and
requirements gaps. Preserve all parity ledger rows and unapproved optional usage/
extra gesture/destructive branches; full goal remains active/incomplete.

User approved icon/type during discovery. Drag-caption consistency is now part of
the approved style propagation work, not a separate duplicated patch. See new
icon-type implementation stage. Library helper continues read-only; its proposed
contract is not implementation authority. No standalone visibility fix/testPASS
claimed in this discovery stage.
