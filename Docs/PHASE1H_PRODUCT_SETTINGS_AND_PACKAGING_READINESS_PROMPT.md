# Phase 1H — Product Settings and Packaging Readiness

> Status: **APPROVED — 2026-09-11**
> Approval: user 「批准」; decisions in `Workflow/decisions/2026-09-11-phase1h-gate0-approved.md`
> Display name **Launchcopy**; Bundle ID **`com.launchcopy.app`**; Chinese UI; native AppKit settings;
> Launch at Login implement (default off); four-finger private backend retained with Ready/error UI;
> GitHub publish by user (no auto push this phase).
> This phase prepares a product-quality application shell. It does **not** authorize release,
> distribution, signing, notarization submission, login-item installation on the user's machine
> without a separate announcement, deletion of evidence, or automatic Git publication.

---

## 0. Role and mission

You are the Main/Orchestrator for Phase 1H of `PagingPrototype`, a clean-room macOS AppKit
application implemented as a Swift Package.

Your mission is to turn the completed automated Phase 1G activation composition into a coherent,
testable product shell by delivering:

1. a real, single-instance Activation Settings window;
2. safe live application of activation preferences;
3. a public-API Launch at Login capability, disabled by default;
4. an independent application identity and UI foundation;
5. a reproducible `.app` packaging path suitable for local Release validation;
6. an explicit signing, sandbox, privacy, and notarization feasibility decision packet;
7. separation of product behavior from opt-in diagnostics and laboratory tools;
8. current documentation and an auditable Phase 1H handoff.

This is a readiness phase, not a release phase. Preserve the existing paging, catalog, search,
keyboard, drag/folder, persistence, and activation behavior unless this specification explicitly
requires a narrow integration change.

Communicate with the user in Chinese. Write reasoning artifacts, specifications, ADRs, code,
comments, filenames, and technical documentation in English unless an existing public UI string or
repository convention requires localized product copy.

---

## 1. Mandatory preflight and approval gate

### 1.1 Read before proposing work

Before modifying any source file, read at least:

- `AGENTS.md` files that apply to the repository;
- `README.md`;
- `Package.swift`;
- `Workflow/config.json`;
- `Workflow/STATE.json`;
- `Workflow/PLAN.md`;
- `Docs/PHASE1G_CHECKPOINT.md`;
- `Docs/PHASE1G_ACTIVATION_ENTRY_HOT_CORNER_PROMPT.md`;
- `Docs/ADR-011-LAUNCHER-PRESENTATION-LIFECYCLE.md`;
- `Docs/ADR-012-SYSTEM-WIDE-ACTIVATION-PRIVACY.md`;
- `Docs/ADR-013-FOUR-FINGER-ACTIVATION-BACKEND.md`;
- `Sources/PagingPrototypeApp/ActivationSettings.swift`;
- `Sources/PagingPrototypeApp/ActivationPreferences.swift`;
- `Sources/PagingPrototypeApp/ActivationComposition.swift`;
- `Sources/PagingPrototypeApp/StatusItemController.swift`;
- `Sources/PagingPrototypeApp/AppDelegate.swift`;
- `Sources/PagingPrototypeApp/AppMain.swift`;
- the current tests for activation preferences, status item, shortcut, Hot Corner, four-finger
  activation, and launcher integration.

Use live repository contents as evidence. Do not infer current status from this prompt alone.

### 1.2 Reconcile Phase 1G honestly

The user has reported that the previous part is complete. The last recorded repository state may
still describe Phase 1G as `PHASE1G_AUTOMATED_COMPLETE_PHYSICAL_PENDING`, with automated tasks
passing but physical gates such as M01–M12, energy A/B, multi-display, sleep/lock, rapid-race, and
older B10/B11 checks pending.

At Gate 0:

1. inspect the live state and latest evidence;
2. record the user's completion statement as acceptance input;
3. distinguish these three states explicitly:
   - automated implementation/review complete;
   - user-reported practical acceptance;
   - evidence-backed physical gate results;
4. close stale workflow task labels only when the existing evidence supports closure;
5. carry genuinely unrun physical checks forward as named debt rather than inventing `PASS`;
6. do not rerun the entire Phase 1G unless a Phase 1H regression or missing prerequisite requires a
   targeted check.

### 1.3 First-response stop condition

Your first response in the new task must contain a concise Chinese decision packet with:

- the reconciled current state;
- the proposed Phase 1H boundary;
- unresolved product decisions from section 4;
- files expected to change;
- validation gates;
- risks and rollback strategy.

Then ask the user to confirm this specification and the unresolved decisions. **Stop before source
implementation.** The copied prompt is a draft, not implicit approval.

After explicit approval, write the approved decisions to `Workflow/decisions/`, update the prompt's
status to `APPROVED`, and use the approved specification as the source of truth.

---

## 2. Existing contracts that must remain true

The following are compatibility constraints, not redesign invitations:

1. One launcher window controller remains the authority for presentation.
2. Show/Hide state derives from committed launcher visibility; do not add a second toggle state.
3. Blank click, Escape, successful app launch, and close hide the launcher.
4. Quit terminates and tears down resident services.
5. `applicationShouldTerminateAfterLastWindowClosed` remains false.
6. Status item, Dock reopen, shortcut, Hot Corner, and four-finger activation route into the same
   presentation coordinator.
7. Target screen policy remains mouse screen, then key screen, then main screen, then index zero,
   unless a separately approved ADR changes it.
8. Four-finger inward pinch may show the launcher; outward spread must not automatically hide it.
9. Four-finger enabled does not imply backend ready. Preserve `Enabled != Ready` semantics.
10. Shortcut and Hot Corner remain off by default. Four-finger default behavior follows the latest
    approved Phase 1G decision and persisted migration policy.
11. Activation persistence remains isolated from workspace layout persistence.
12. Unknown future preference schemas must not be overwritten by older code.
13. Reset Activation and Reset Layout remain separate actions.
14. Do not change the frozen paging engine or its performance conclusions in this phase.
15. Preserve the performance evidence tokens:
    - `PRODUCT_TIMER_TOLERANCE_0MS`;
    - `SHORT_TAIL_MITIGATED_BY_TOLERANCE` for the recorded 20–25 ms short tail only;
    - `CAUSALITY_UNRESOLVED_FOR_GT25MS`.
16. Do not claim that Phase 1H fixes any unresolved >25 ms tail.

---

## 3. Source and provenance discipline

### 3.1 Clean-room rule

Implement from this specification, public Apple documentation, and existing `Launch_Copy` source.
Do not mechanically translate decompiled code or reproduce third-party visual expression.

### 3.2 Denied sources

Do not open, copy, quote, summarize, or use implementation details from:

- `/Users/mac/Projects/LaunchBetter/Docs/aegis/work/2026-08-25-buho-launchpad-reverse/evidence/`;
- `/Users/mac/Projects/BuhoReverseNotes/`;
- any Buho binary, resource, decompiler output, private string table, screenshot set, or report.

Phase 1H does not require those sources.

### 3.3 LaunchBetter boundary

The user owns LaunchBetter and previously authorized narrowly scoped reference reads. For Phase 1H,
default to **no LaunchBetter source access**. If a missing integration fact genuinely requires it:

1. explain the exact question;
2. request a narrow user-approved path;
3. log the access in `PROVENANCE/`;
4. extract a behavior requirement, not code or visual expression;
5. implement independently in `Launch_Copy`.

Do not use LaunchBetter branding, icons, assets, copy, spacing, component composition, or source code
unless the user explicitly provides an ownership/transfer decision for this product.

### 3.4 Public documentation

Use current official Apple documentation for `SMAppService`, application bundle structure, code
signing, App Sandbox, Hardened Runtime, privacy manifests where applicable, and notarization tooling.
Record documentation URLs and access dates in the relevant ADR. Distinguish documented behavior
from locally observed behavior.

---

## 4. Product decisions requiring explicit user confirmation

Do not invent these values. Present a recommended option and implications for each.

### D1 — Product identity

Obtain:

- public application name;
- bundle identifier;
- version and build-number policy;
- copyright owner string;
- whether `PagingPrototype` remains only an internal module/executable name.

Recommendation: choose an independent name and bundle identifier unrelated to Buho. Internal type
renaming is optional and should only occur when it improves product vocabulary without causing a
large no-value diff.

### D2 — Distribution target

Choose one primary target:

- direct local/internal use;
- Developer ID direct distribution and notarization readiness;
- Mac App Store feasibility;
- multiple variants.

Recommendation: treat Developer ID direct distribution as the initial readiness target if the
four-finger backend still depends on private MultitouchSupport APIs. Do not claim Mac App Store
eligibility while that dependency exists.

### D3 — Four-finger/private-API policy

Choose one:

- direct-distribution build keeps the private backend with explicit readiness/error UI;
- product build omits the private backend and keeps other activation methods;
- separate build variants with a compile-time capability boundary;
- postpone the decision and mark packaging readiness partial.

Recommendation: isolate the backend behind an existing/narrow capability protocol and document the
distribution consequence. Never silently replace the implementation, conceal private API use, or
represent it as public API.

### D4 — Launch at Login scope

Confirm whether Phase 1H may implement the setting or only prepare an ADR/prototype. If implemented:

- it is off by default;
- it changes only after a direct user action;
- it uses public `SMAppService` APIs;
- it exposes current status and actionable failure text;
- tests must not register a real login item;
- validation on the user's machine requires a separately announced reversible action.

### D5 — Settings UX style

Choose:

- native AppKit preferences window using standard controls and platform spacing;
- an approved independent custom visual system.

Recommendation: native AppKit preferences UI for this phase. It minimizes expressive similarity,
reduces design risk, improves accessibility, and keeps Phase 1H focused on product readiness.

### D6 — Localization

Choose initial product language and fallback behavior. Recommendation: establish localization-ready
string boundaries now, but ship only the user-approved initial locale in this phase.

---

## 5. Scope

### 5.1 In scope

- Settings window architecture and UI.
- Editing, validation, persistence, live apply, and rollback of activation preferences.
- Shortcut recording and conflict/invalid-state presentation.
- Hot Corner selection and enablement.
- Four-finger enabled/readiness/error presentation.
- Status item visibility with a safe recovery path.
- Launch at Login readiness or implementation according to D4.
- Independent app name, icon, bundle metadata, accessibility labels, and localization boundary.
- Reproducible local `.app` bundle generation.
- Entitlements and capability inventory.
- Signing, Hardened Runtime, sandbox, private-API, and notarization feasibility documentation.
- Product/diagnostic separation.
- Documentation refresh.
- Automated tests, local bundle inspection, and a focused manual acceptance matrix.

### 5.2 Out of scope without a new approval

- Publishing or uploading any artifact.
- Developer ID or App Store signing with the user's identity.
- Notarization submission.
- Installing or enabling Launch at Login on the user's machine.
- Shipping through the Mac App Store.
- Replacing the four-finger backend.
- New gesture semantics.
- Redesigning the paging engine, grid, search, drag, folders, or app-launch behavior.
- Importing LaunchBetter/Buho visual assets or source.
- Deleting reverse-engineering evidence, provenance records, test logs, or historical Workflow data.
- Git commit, push, tag, release, or pull request.

---

## 6. Required architecture

### 6.1 Settings domain

Keep the persisted value model independent of AppKit. Extend schema versions only when a new
persisted field requires it. Provide explicit migration tests for every supported prior schema.

Use three layers:

1. **Draft state** — mutable values displayed in the Settings UI.
2. **Validation and planning** — pure logic that compares current and proposed values and produces a
   deterministic apply plan.
3. **Runtime application** — main-actor adapters that execute the plan, persist only successful
   results, and expose actionable failures.

Do not let controls write directly to `UserDefaults` or system services.

### 6.2 Transactional apply semantics

Define and test a transaction contract:

1. validate the complete draft;
2. compute old and new service plans;
3. apply reversible runtime changes in a documented order;
4. if any mandatory step fails, restore the prior runtime plan;
5. persist only after the runtime reaches the accepted state;
6. if persistence fails, restore runtime state when safe and surface an error;
7. never leave the UI claiming a state that the runtime did not accept.

For system-owned asynchronous states such as Launch at Login, represent requesting, enabled,
disabled, requires-approval, not-found, and failed states explicitly rather than reducing all results
to a Boolean.

### 6.3 Settings window ownership

Create one `SettingsWindowController` (or an equivalently clear independent name) owned strongly by
the application composition root.

Required behavior:

- status menu `Activation Settings…` opens or focuses the same window;
- repeated commands never create duplicate windows;
- the window is independent of launcher visibility;
- closing Settings does not quit the resident app;
- Settings restores a sensible position but does not persist private screen identifiers;
- controls have keyboard navigation, VoiceOver labels, help text, and sufficient contrast;
- Reduce Motion does not impair state feedback;
- error messages are user-actionable and do not expose internal traces.

### 6.4 Settings sections

Provide platform-appropriate sections:

#### General

- Launch at Login, if approved by D4.
- Show menu bar item.
- Product version/build display.

#### Activation

- Four-finger inward pinch toggle.
- Backend readiness and a concise explanation if unavailable.
- Global shortcut enable toggle and recorder.
- Hot Corner enable toggle and corner selector.

#### Data and Diagnostics

- Reset Activation Settings.
- Reset Workspace Layout as a separate, clearly distinguished action if the existing layout layer
  exposes a safe API; otherwise link to/document it without inventing a destructive shortcut.
- Diagnostic status explaining that telemetry is off by default.
- No raw touch traces, app identities, window titles, search queries, or screen identifiers.

Destructive reset controls require confirmation and must state exactly what is preserved.

### 6.5 Status item recovery rule

If the user disables the menu bar item, at least one tested, discoverable route must still open
Settings or restore it, such as an application menu command or Dock reopen flow. Do not allow a
configuration that makes the resident app impossible to configure or quit.

### 6.6 Shortcut recording

The recorder must:

- accept only supported key/modifier combinations;
- reject or explain reserved/invalid combinations;
- show the normalized shortcut before apply;
- support clearing the shortcut;
- not install a real global shortcut during unit tests;
- roll back to the previous registration if replacement fails;
- avoid logging key history.

### 6.7 Launch at Login adapter

Put `SMAppService` behind a protocol so tests use fakes. The production adapter must be main-actor
safe and map framework errors/statuses into a small product-owned result model.

Do not introduce a helper executable unless official API requirements and the selected deployment
model require one. Document why the chosen service type matches the final `.app` bundle.

### 6.8 App bundle and identity

Produce a deterministic packaging path that creates a valid local Release `.app` from the SwiftPM
build. Prefer a small reviewed build script or generated Xcode project only after evaluating the
maintenance trade-off. Do not add an opaque third-party packaging dependency for a task that can be
implemented with standard Apple tooling.

The bundle must include, as applicable:

- executable;
- `Info.plist` with approved identity/version/minimum system values;
- application icon and required icon representations;
- localized string resources if D6 approves them;
- entitlements selected by ADR, not copied from another product;
- privacy manifest only when the final API/dependency inventory requires it;
- no Workflow, reverse evidence, test fixtures, raw diagnostics, or development-only scripts.

The independent app icon must be original or user-owned. If no approved icon exists, use an
explicitly temporary neutral development icon and mark visual identity as a release blocker; do not
generate a look-alike.

### 6.9 Diagnostics boundary

Inventory every runtime `print`, diagnostic recorder, telemetry path, lab CLI switch, and temporary
probe.

Classify each as:

- required product error/reporting;
- opt-in development diagnostic;
- test-only seam;
- obsolete probe.

Then:

- keep telemetry and frame/run-loop profiling off by default;
- compile or runtime-gate development probes explicitly;
- prevent raw diagnostic output in ordinary packaged execution;
- retain useful tools and historical evidence outside the product bundle;
- do not delete evidence merely to make the bundle cleaner;
- add a bundle-content test that catches accidental inclusion.

---

## 7. Distribution and platform decision packet

Create `Docs/ADR-014-product-packaging-and-distribution.md` (or the next free ADR number) covering:

1. chosen bundle construction approach;
2. selected product identity and version source;
3. Launch at Login API and service choice;
4. entitlement inventory and justification;
5. Hardened Runtime readiness;
6. App Sandbox feasibility;
7. private MultitouchSupport dependency and consequences;
8. direct distribution vs Mac App Store implications;
9. signing and notarization commands proposed but not executed;
10. privacy/data inventory;
11. rollback and uninstall behavior;
12. known blockers before release.

The ADR must use precise status labels:

- `IMPLEMENTED_AND_LOCALLY_VERIFIED`;
- `READY_FOR_USER_AUTHORIZED_SIGNING_TEST`;
- `FEASIBILITY_ONLY`;
- `BLOCKED_BY_PRIVATE_API`;
- `BLOCKED_BY_MISSING_IDENTITY_OR_CREDENTIAL`;
- `NOT_IN_SCOPE`.

Do not use `READY` without naming what it is ready for.

---

## 8. Workflow and delegation

Use the existing `chef-worker-reviewer-workflow` v1.4 artifacts and live configuration. Do not
invent model names or silently change concurrency.

### 8.1 Main responsibilities

- own `Package.swift`, application composition, shared workflow state, final integration, and user
  decisions;
- reconcile Phase 1G state before creating Phase 1H tasks;
- allocate non-overlapping write scopes;
- serialize shared builds and tests;
- keep `Workflow/STATE.json` and the Phase 1H checkpoint current;
- stop for decisions that materially change distribution or private-API policy.

### 8.2 Suggested task graph

After approval, create concrete task IDs and dependency edges equivalent to:

- **T-1H-A — Settings domain and apply-plan contracts**
  - pure models, validation, migration, transaction tests;
  - no AppKit UI.
- **T-1H-B — Settings AppKit UI**
  - depends on A;
  - single-instance controller, sections, accessibility, status-menu wiring.
- **T-1H-C — Launch at Login adapter**
  - depends on D4 approval and A;
  - public API seam, fake tests, status/error mapping.
- **T-1H-D — Product identity and bundle pipeline**
  - depends on D1/D2/D6;
  - metadata, resources, icon, deterministic local bundle assembly.
- **T-1H-E — Diagnostics/product boundary**
  - can audit in parallel after approval;
  - changes only explicitly assigned files.
- **T-1H-F — Composition and recovery paths**
  - depends on B/C and existing Phase 1G composition;
  - live apply, Settings entry points, status-item recovery.
- **T-1H-G — Packaging/distribution ADR and verification**
  - depends on C/D/E/F;
  - unsigned local artifact inspection and readiness verdict.
- **T-1H-H — Independent review and manual acceptance packet**
  - depends on all implementation tasks;
  - no self-approval by implementing Worker.

### 8.3 Concurrency rules

- Re-check actual available concurrency before each dispatch wave.
- Maximum configured Worker concurrency is a ceiling, not a target.
- Never run two writers on the same file.
- Do not run shared `swift build`, `swift test`, bundle assembly, or mutation-heavy formatters in
  parallel.
- A Worker may perform targeted compilation in its own non-conflicting environment only if the
  workflow supports it.
- Main integrates; Reviewer reviews the integrated tree.

### 8.4 Agent context discipline

Create and maintain:

- `Docs/PHASE1H_CHECKPOINT.md` — concise current task/build/test/decision/debt state;
- `Workflow/results/T-1H-*.md` — task evidence and changed-file inventory;
- `Workflow/decisions/YYYY-MM-DD-phase1h-*.md` — user decisions;
- `PROVENANCE/PHASE1H_SOURCE_ACCESS.md` — sources consulted and denied boundaries;
- `Docs/PHASE1H_VALIDATION_RESULTS.md` — gate table and exact evidence.

Agents must write durable findings before ending a context. Do not paste huge build logs into
checkpoints; record command, exit status, test counts, artifact path/hash, and the exact failure.

---

## 9. Automated acceptance criteria

All tests must use isolated temporary storage and fake system adapters where state mutation would
affect the real machine.

### 9.1 Settings model and persistence

- Existing schema loads with no data loss.
- Fresh install defaults match approved product decisions.
- Invalid corner/shortcut values fail safe.
- Unknown future schema is preserved and write-refused.
- Reset Activation does not alter layout data.
- Reset Layout does not alter activation data.
- Save failure does not leave runtime/UI in a false-success state.
- Runtime apply failure restores the previous accepted configuration.
- Reopening Settings reflects committed values, not abandoned drafts.

### 9.2 Window and navigation

- Repeated `Activation Settings…` commands reuse one window.
- Close and reopen works without creating duplicates.
- Settings may remain open while launcher shows/hides.
- Closing launcher or Settings does not terminate the resident app.
- Quit tears down Settings and activation services.
- Full keyboard traversal reaches every interactive control.
- Every control has a stable accessibility label/value/help contract.

### 9.3 Activation controls

- Four-finger toggle distinguishes enabled from backend ready.
- Unavailable backend has truthful UI and no crash.
- Shortcut validation rejects unsupported combinations.
- Failed shortcut replacement restores the prior registration.
- Hot Corner requires a valid selected corner before enabling.
- Live changes update only the affected service.
- Disabling status item preserves a tested recovery path.

### 9.4 Launch at Login

- Unit tests never call the real registration service.
- Status mapping covers enabled, disabled, requires approval, unavailable, and failure.
- Register/unregister errors preserve truthful displayed state.
- Default is off unless an explicit approved migration says otherwise.
- No startup loop or duplicate launcher window is possible.

### 9.5 Packaging

- Debug and Release Swift builds pass.
- Full `swift test` passes with nonzero execution for every test target.
- Packaging command is reproducible from a clean build directory.
- Produced `.app` has a valid bundle structure.
- `plutil -lint` passes for all bundled plists.
- Bundle identifier, executable, version, build, minimum OS, icon, and display name match approved
  values.
- `codesign --display --verbose=4` is used only to inspect current signature state unless signing is
  separately authorized.
- `spctl` and notarization results are not claimed when no authorized signed/notarized artifact
  exists.
- Product bundle contains no tests, Workflow files, provenance evidence, source dumps, or raw
  diagnostic logs.
- Ordinary packaged launch does not emit laboratory diagnostics.
- Headless smoke and development tools remain available through explicit development paths.

### 9.6 Regression

Targeted regression tests must cover:

- launcher show/hide/quit composition;
- status menu and Dock reopen;
- shortcut/Hot Corner/four-finger routing;
- app scanning and launch;
- search and keyboard focus;
- drag/folder/layout persistence;
- existing paging input and interruption semantics.

Do not update snapshots or expected values merely to silence a regression. Explain every intentional
contract change and tie it to an approved requirement.

---

## 10. Manual acceptance matrix

Automated tests do not replace GUI or system-integration checks. Prepare a short, copyable manual
packet and mark every unrun item `PENDING`.

### M1 — Settings lifecycle

- Open from menu bar.
- Invoke again and confirm the same window focuses.
- Close and reopen.
- Show/hide launcher while Settings remains open.
- Quit and confirm process exit.

### M2 — Accessibility and keyboard

- Traverse all controls without a pointer.
- Verify labels, state announcements, and error association with VoiceOver.
- Verify default button, Cancel/Revert behavior, and Escape behavior.
- Verify Increase Contrast and Reduce Motion modes.

### M3 — Activation live apply

- Toggle each activation method independently.
- Configure and replace the shortcut.
- Confirm invalid shortcuts do not destroy the previous valid shortcut.
- Select each Hot Corner and verify only the selected corner activates.
- Verify four-finger readiness and show behavior where supported.
- Confirm spread does not hide.

### M4 — Recovery and persistence

- Disable menu bar item and recover Settings through the approved alternate route.
- Relaunch and verify committed settings.
- Reset Activation and confirm layout is preserved.
- Reset Layout, if exposed, and confirm activation settings are preserved.
- Inject/observe a controlled persistence failure using a test build, not the real user domain.

### M5 — Launch at Login

Run only after the user separately authorizes changing the real login-item state:

- enable;
- inspect system status;
- log out/in or restart as appropriate;
- verify one resident process and no surprise launcher window;
- disable;
- verify removal and document recovery if macOS requires Settings approval.

### M6 — Packaged app

- Launch the locally built `.app` from Finder.
- Confirm name, icon, menus, Settings, Dock behavior, and status item.
- Confirm ordinary launch is quiet and no terminal is required.
- Confirm app scan, app launch, paging, search, drag/folder, and quit.
- Confirm no source/evidence/dev-only resource is bundled.

Carry Phase 1G physical debt into this matrix or its linked document; do not silently erase it.

---

## 11. Risk register and required mitigations

### R1 — False product readiness

Risk: a locally assembled unsigned `.app` is described as releasable.
Mitigation: report local bundle, signed artifact, Gatekeeper acceptance, notarization, and distribution
as separate gates.

### R2 — Private API/distribution incompatibility

Risk: four-finger MultitouchSupport use conflicts with sandbox, review, or future OS behavior.
Mitigation: explicit ADR, capability boundary, truthful UI, selected distribution target, and no App
Store claim without compliant evidence.

### R3 — Login-item side effects

Risk: tests or development runs modify the user's login items.
Mitigation: fake adapter by default, direct user action, separate manual authorization, reversible
validation, and status inspection.

### R4 — Settings/runtime divergence

Risk: UI says enabled while service registration failed.
Mitigation: transaction plan, typed result states, rollback, persist-after-apply, and failure tests.

### R5 — User lockout

Risk: hiding the status item removes all Settings/Quit access.
Mitigation: tested alternate route and recovery documentation.

### R6 — Preference corruption

Risk: schema change overwrites newer or unrelated data.
Mitigation: isolated suite, version check before decode/write, migrations, atomic/ordered commits, and
separate reset domains.

### R7 — Diagnostic privacy leakage

Risk: product logs touch traces, key history, app identity, window title, search text, or screen
identity.
Mitigation: inventory, default-off diagnostics, minimal typed events, bundle-content checks, and
privacy review.

### R8 — Visual/provenance contamination

Risk: product identity or Settings UI reproduces a third-party product.
Mitigation: native controls or approved independent design, original assets, source-access log, and
independent visual review.

### R9 — Broad refactor regression

Risk: product-shell work destabilizes mature paging/grid behavior.
Mitigation: narrow adapters, no PagingCore changes, disjoint task scopes, full regression suite, and
review of integrated diffs.

### R10 — Stale documentation

Risk: README and state files continue to report old test counts or phases.
Mitigation: derive counts from executed commands, timestamp evidence, and update docs only after
verification.

---

## 12. Stop and escalation conditions

Stop implementation and ask the user when any of these occurs:

- product name, bundle ID, distribution target, or private-API policy remains unresolved and blocks
  the next change;
- official API requirements conflict with the proposed packaging structure;
- Launch at Login would require changing the real machine before separate authorization;
- a requested signing/notarization step needs credentials or account actions;
- sandbox/notarization feasibility would require removing an approved feature;
- preference migration could destroy or reinterpret existing user data;
- a Worker needs access to a denied source;
- existing dirty changes overlap the intended files and ownership is unclear;
- full tests regress outside the approved Phase 1H scope;
- a destructive reset or evidence deletion appears necessary;
- release, upload, commit, push, tag, or publication would be the next action.

Use exact terminal labels such as:

- `PHASE1H_DECISION_REQUIRED`;
- `PHASE1H_BLOCKED_BY_PRIVATE_API_POLICY`;
- `PHASE1H_BLOCKED_BY_PRODUCT_IDENTITY`;
- `PHASE1H_LOGIN_ITEM_USER_AUTHORIZATION_REQUIRED`;
- `PHASE1H_SIGNING_CREDENTIAL_REQUIRED`;
- `PHASE1H_PHYSICAL_ACCEPTANCE_PENDING`.

---

## 13. Delivery artifacts

At completion, provide:

1. approved Phase 1H specification with decision references;
2. updated `Workflow/PLAN.md` and `Workflow/STATE.json`;
3. `Docs/PHASE1H_CHECKPOINT.md`;
4. `Docs/PHASE1H_VALIDATION_RESULTS.md`;
5. packaging/distribution ADR;
6. provenance access record;
7. per-task Worker/Reviewer result files;
8. current README build/run/package instructions;
9. deterministic package command or script;
10. local `.app` path, size, SHA-256, and bundle inspection summary;
11. exact build/test commands, exit statuses, and test counts;
12. manual acceptance packet with PASS/FAIL/PENDING and evidence owner;
13. a release-blocker list;
14. rollback/uninstall instructions, including Launch at Login removal if it was ever enabled.

Do not include secrets, signing credentials, raw touch traces, or sensitive host-specific identifiers
in durable artifacts.

---

## 14. Definition of done

Phase 1H may be declared `IMPLEMENTATION_COMPLETE_PHYSICAL_PENDING` only when:

- approved decisions are recorded;
- Settings UI and live apply are implemented and independently reviewed;
- the status-menu stub is replaced by the real single-instance Settings route;
- Launch at Login is either implemented under the approved policy or explicitly marked
  `FEASIBILITY_ONLY` with no false claim;
- a reproducible local Release `.app` is assembled and inspected;
- product identity/resources are independent and provenance-reviewed;
- diagnostics are default-off and excluded from ordinary product behavior;
- Debug build, Release build, full tests, targeted tests, and bundle checks pass;
- documentation reflects the executed results rather than stale counts;
- every unrun real-machine, signing, notarization, login-item, and Phase 1G physical gate remains
  visibly `PENDING` or `BLOCKED`.

Phase 1H may be declared `PHASE1H_COMPLETE` only after the user completes and accepts the required
manual GUI/system checks for the approved scope. This still does not mean the app is signed,
notarized, distributed, or released.

The only permitted next-stage recommendation is a narrowly scoped candidate such as:

```text
RECOMMEND_PROCEED_TO_PHASE_1I_RELEASE_CANDIDATE_VALIDATION
```

That recommendation must list remaining blockers and must not perform release actions.

---

## 15. Required final response format

Return a concise Chinese handoff with:

1. **Outcome** — exact completion label.
2. **What changed** — user-visible product behavior and architecture.
3. **Verification** — commands, test counts, artifact hash, and manual gates.
4. **Distribution truth** — local bundle vs signed/notarized/released status.
5. **Open debt** — physical gates, private API, identity, signing, or login-item items.
6. **Files** — clickable links to the main spec, ADR, validation report, and packaged artifact.
7. **Next authorization** — one precise action requiring user approval, if any.

Never collapse `build passed`, `tests passed`, `local .app assembled`, `physical acceptance passed`,
`signed`, `notarized`, and `released` into one status.
