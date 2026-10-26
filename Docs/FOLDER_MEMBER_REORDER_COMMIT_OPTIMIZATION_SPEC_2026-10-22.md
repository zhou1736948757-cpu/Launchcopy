# Retain unchanged main-grid presentation for a folder member permutation

## Problem and evidence
Three real accepted folder reorders on the isolated a3703652 diagnostic candidate spent 21–26ms inside the overlay release handler. Within that transaction, provider work took approximately 8–10ms, top-level presentation approximately 8–11ms, and folder refresh approximately 5–6ms. All visible member icons were ready. No display completion marker was obtained. This proves an application contribution, not the entire perceived300ms cause. Wallpaper was render-failed at inspection; normal-wallpaper performance is not certified.

## Bounded change
Keep the normal provider/search layout transaction and persistence path. For a certified strict member-order-only permutation of the currently open folder, retain unchanged main-grid hosts, bindings, surface generation and top-level focus layout instead of reloading them. Continue all existing telemetry, settings/page-dot/status and Library notification fanout. Continue synchronous open-folder reconciliation and the established icon-continuity binding path. The drag owner finishes its normal pointer-up transaction rather than being cancelled as a catalog refresh for this special case.

All other commits retain the general refresh path. This is not a provider incremental-update project, a layout/appearance change, a new animation, a timer tweak or a persistence optimization.

## Eligibility and safety
- There is an open live folder, and its current provider expected layout is available.
- The incoming persistent layout changes only that folder's member order and the ordinary layout generation. Top-level order, folder collection order, identities, titles, other folder records and the target member multiset remain unchanged. Reject duplicate or unchanged permutations.
- No pending provider catalog, folder, management, expected-layout or search update exists before the transaction. A reusable read-only aggregate pending-work property may expose this existing state; no new mutable state or fake catalog revision.
- Search controller and provider have no active nonempty query. Keep pending/latest-wins search semantics intact.
- The normal provider commit still returns the same catalog revision. Validate the visible top-level projection remains equal apart from this folder's member order before retaining hosts. Any uncertainty falls back to the full existing update.
- Do not skip telemetry/settings/status/Library fanout, folder generation changes, member selection reconciliation, persistence admission, write failure/quit protection or normal drag cleanup.
- No source/reference assets, formal user data, OS/backend/preferences schema or source scanning changes.

## Implementation and test ownership
Main owns production files, integration, all test/build/package/native execution and durable records. A worker may edit only the existing FolderAssignmentAssemblyTests.swift and a new FolderReorderPresentationPolicyTests.swift to cover the agreed pure helper and real owner behavior. No overlapping writes, worker test/build/UI/process actions or children; at most three agents including Main. Reviewer is read-only after source freeze.

Pure internal helper: `FolderReorderPresentationPolicy.isPureMemberPermutation(from:to:folderID:) -> Bool`, using existing persistent layout values. It must not touch services or UI. The private owner presentation method may accept a default-false option to retain the main grid; no caller other than the verified member permutation selects it.

## Acceptance and verification
1. A real owner within-folder drag commits the new order before returning, retains known member images, advances provider folder generation, preserves main surface generation/bindings, finishes the drag session and submits the complete new persistent layout.
2. Top-level reorder, folder membership/title/collection changes, duplicate/no-op permutations, other-folder edits, active search and any pending provider work follow the existing full-refresh path and preserve search/pending semantics.
3. Existing diagnostic stages remain comparable and truthful; retaining the main grid does not bypass provider commit or falsely report a display completion.
4. Capture a discriminating RED owner test on the old implementation, focused/full nonzero suites, Debug/actual Release/unique isolated package, frozen source hashes/diff check and bounded independent source review.
5. Real before/after timing and human release acceptance remain separate pending gates after source verification. Do not claim the whole latency is fixed or infer OS/CPU causality.

## Delivery and maintenance
Preserve the current isolated human arrangement and the already captured neutral numeric samples. Only normal Quit of the owned old instance is allowed for later handover; no signals/sign/install/Git/cleanup. If the native service remains unavailable, retain the candidate and report the exact UI limitation rather than force a restart. The separate visual-scale feedback remains documented but is not bundled into this optimization.
