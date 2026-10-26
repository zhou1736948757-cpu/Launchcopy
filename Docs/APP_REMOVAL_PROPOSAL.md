# Explicit app removal through the macOS Trash

Date: 2026-10-18
Status: APPROVED_IMPLEMENTATION_CONTRACT — human explicitly selected the recommended safe proposal on 2026-10-18.

## Problem, outcome and authority
The approved full parity roadmap still identifies uninstall/delete as an intentionally reserved feature. Current Launchcopy provides Hide, aliases, organization, launch and Finder reveal, but no removal action. Hide is not uninstall. The human now prefers autonomous routine decisions; that does not by itself approve adding destructive capabilities. This specification proposes one concrete bounded next branch rather than silently dropping it from parity.

For a user explicitly choosing to remove a local application, provide a clearly labelled Move to Trash action through standard macOS facilities. Do not call this complete uninstall: support files, preferences, receipts, shared data and login/background services are not cleaned. Any reference-specific cleanup remains unmapped until separately established/approved.

## Scope and non-goals
- One selected application bundle per transaction; main/folder context menus and Library details reuse a single owner/service.
- Explicit contextual confirmation with app name and local path, Move to Trash / Cancel, default Cancel. Confirmation only authorizes this selected candidate, never a whole source folder.
- Only present, ordinary local, current-user-owned, user-removable top-level `.app` directories with safe current bindings. Reject system-protected locations, read-only/network/nonlocal volumes, symlinked bundles/ancestors, nested helper apps, the running Launchcopy bundle, stale or substituted candidates and running applications. No silent privilege escalation.
- In isolated profiles, further restrict removal to that exact profile's authored Applications directory. A test profile must never act on a formal application.
- Do not force quit apps, request admin credentials, empty Trash, permanently delete files, invoke shell removal, automate Finder scripts, remove supporting files, run uninstall helpers or silently change permissions.
- Recovery uses normal macOS Trash/Finder facilities, not a private duplicate or an advertised app Undo action. If Trash operation is unavailable, report failure; do not fall back to permanent deletion.

## Functional contracts
1. At menu/details construction, offer or explain availability using the existing current catalog/hidden/cell or Library-generation guards. No file inspection on frame callbacks.
2. At action start, resolve current identity, canonical URL, revision, owner/lifecycle and profile. Inspect eligibility off the frame path. Show confirmation only for this immutable candidate. A changed result cannot inherit an earlier confirmation.
3. At confirmation, revalidate the same app/canonical path/catalog revision/lifecycle and fresh eligibility. Close/teardown, hidden app, catalog replacement or conflicting transaction revokes the request. Only one accepted removal runs at a time.
4. Refuse a running app rather than quitting it. On-demand public running-app inspection is used solely to validate this explicit destructive action, never as history tracking or a system-wide observer. Store/log no running-app list.
5. Use the platform Trash API once, off the frame callback. Report success only on its actual receipt. Ordinary cancellation/failure leaves the app and saved organization untouched as far as the operation reports; do not fabricate success based on prior eligibility.
6. After success, request refresh through the existing catalog owner, preserving auto-refresh preference and latest-wins generations. Removal from visible results follows that refreshed catalog; it is not a hide/alias/layout transaction. Saved layout membership, aliases, category overrides and retained activity remain dormant under existing absence policies. Returning the same identity can reuse existing dormant organization; do not promise an unconditional position under unrelated catalog/layout changes.
7. Render nonfatal, accessible localized pending/success/unavailable/failure states in English, Simplified Chinese and Japanese. Keep the settings/launcher responsive; block conflicting app actions only for the relevant transaction/lifecycle.
8. Pending accepted removal participates in bounded orderly Quit: wait for the real result within the existing deadline; default Cancel Quit on timeout/failure/unknown. Never claim an operation can be undone/cancelled after the platform has accepted it. Late callbacks may update the service outcome, not revive stale views.

## Architecture and data decisions
Reuse AppContextMenuController's immutable binding/revision validation and AppLibraryActionRequest's identity/URL/revision/generation. Add a small removal owner with explicit confirming/executing/result states and injected eligibility/Trash adapters. The application composition root wires both surfaces to the same owner and current catalog refresh. Keep pure eligibility decisions and UI/control state testable. No new SwiftPM target/dependency or layout/Library/activity schema migration.

The Trash adapter must use a supported macOS API and no privileged helper. File identity observations and final revalidation reduce stale-path mistakes but do not create atomic protection against arbitrary non-cooperating malicious filesystem replacement while macOS performs the Trash operation. Document that boundary; do not advertise race-proof deletion. Do not introduce broad access/permissions to mask an ordinary failure.

## Performance and privacy
No directory scan, eligibility/running-app query, Trash call, persistence or full icon regeneration in frame/touch/animation callbacks. Defer inspections to explicit actions and keep one accepted operation. Record a matched current candidate workload/baseline before implementation; source/unit timing does not prove physical smoothness. No upload or telemetry containing app identities, paths, process lists or removal history. Existing recent-launch recording observes launches only, not removals.

## Acceptance and testing
- Rejection matrix: protected locations, wrong profile, self/running/nested apps, links, unavailable/read-only/network volumes, missing/malformed bundles and stale view/catalog/path identity.
- Cancel never calls Trash; repeated confirmation cannot duplicate an operation; changed binding/generation revokes old requests.
- Injected successful, failed, delayed and indeterminate Trash outcomes; actual receipt and Quit behavior; teardown/late callback safety.
- Refresh and dormant layout/management/Library/activity invariants, existing launch/hide/Finder actions unchanged; no false permanent-delete fallback.
- Three-language text/key/signature/keyboard/accessibility tests; focused and full nonzero XCTest, Debug/Release, independent source review and unique unsigned isolated candidate.
- Native tests only with independently authored explicitly disposable fixture bundles in the candidate-local directory. Verify Cancel, move receipt, disappearance after refresh and normal Finder recovery where available; never remove a real user/system app for acceptance. Observe exact paths/hashes/state without publishing personal data.
- Human feature and matched physical performance acceptance remain separate. No installation/signing/distribution/commit authorization is implied.

## Maintenance, risks and unresolved decision
Keep removal eligibility conservative and separate from launch eligibility. Preserve recoverability and explicit scope; new support-file cleanup, batch actions, running-app termination or admin authorization are separate substantial decisions.

Human decision: implement this Move to Trash contract now, or explicitly defer app removal while retaining it as incomplete parity. This proposal does not authorize implementation or actual removal of formal apps. Existing four-finger inward activation remains unchanged; spread-to-hide was declined, and leftmost paged Library/other extra gestures are not bundled into this proposal.

## Approval — 2026-10-18
The human explicitly approved this bounded safe Move to Trash implementation via the proposal question. This authorizes independent code, controlled tests using authored disposable candidate-local applications, and ordinary execution of the resulting feature only following its per-app confirmation. It does not authorize automatic removal of formal applications, extra gestures, privileged cleanup or permanent deletion. Historical proposal-only statements above are superseded by this explicit approval. The locked desktop does not block source implementation; native acceptance will require actual access later.
