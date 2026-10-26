# Activation diagnostic isolation: independent bounded source review

Date: 2026-10-14

## Verdict and authority

**PASS for the bounded source review; no blocking defect found.** No implementation repair is requested on the evidence inspected. This verdict does not close the task, approve additional features, or establish runtime, physical GUI, performance, packaging, or full-suite acceptance. Main retains those gates.

The project is a Swift Package/AppKit launcher with separate paging, catalog, rendering, and application-composition modules. Review followed the approved parity specification and the activation-isolation stage contract. The Chief workflow waiver and maximum-three concurrency arrangement were supplied by Main; this reviewer dispatched no agents and changed no model/workflow settings.

Only this report was written. No build, tests, application launch, process control, source edits, reference material, global/project memory, or raw runtime evidence were used. Existing dirty-tree changes were preserved. Read-only source inspection used RTK after reading its prefix instruction. The first instruction-file read necessarily preceded learning that prefix rule.

## Frozen input identity

SHA-256 values measured directly from the current working files after Main's test-only LifetimeProbe correction:

| Input | SHA-256 |
| --- | --- |
| `Sources/PagingPrototypeApp/FourFingerDiagnostics.swift` | `f1446d21bacf7a1c4f1e66976e5d3665b698235e3fe93e5d1476959d5643b6ad` |
| `Sources/PagingPrototypeApp/ActivationComposition.swift` | `7a6bbdfcd4e1aae36c5c62721fdc3961e9ec0ff7ff1d3b84255f7e2ac01e7d72` |
| `Sources/PagingPrototypeApp/AppDelegate.swift` | `b84973383b87f7992a85bcfcd57160c5b9005e79bb0caeb0d491047f33a7b44f` |
| `Tests/PagingUITests/FourFingerDiagnosticIsolationTests.swift` | `ac358f66fc90c5530618feabd33237422e9e8d2d6796b5fd1aa7e294c990944a` |
| `Docs/LAUNCHBETTER_PARITY_SPEC.md` | `811227da254051ac7539d2c7cf084a397d4fc89f148140a29ae9e6f0f76a918e` |
| `Workflow/stage-summaries/2026-10-14-activation-diagnostic-isolation.md` | `103a655db98abe15086d69a96f52123f300965f17a2991b3a7afc7c3c31ddf56` |

The final identity check confirmed all four implementation/test files and the approved specification unchanged. The stage summary advanced from `f86876e276cd2b3fca351c7a9ab76f00497ec02a04118b4bd82e01042633f7be` to the value above during review; it was reread, and its later execution checkpoint is attributed below. This was an evidence update, not a source/test freeze violation.

Supporting source inspected: AppCatalogAssembly, AppGridRefreshController, AppArguments, MultitouchSupportBackend, the relevant state enums, and the catalog assembly test's startup assertions. The AppDelegate working diff contains earlier unrelated work; this verdict covers the specified isolation slice and the necessary catalog wiring, not every dirty-tree hunk.

## Source findings

### Default path avoids activation diagnostic work

- `AppDelegate.swift:1951–1963` stops/removes any prior diagnostic owner and constructs a new one only under the existing `options.pagingLab`. Ordinary provider attachment, preferences, and session observation remain outside that diagnostic condition. `AppArguments.swift:129,189–190` retains the false default and existing `--paging-lab` option; no new flag is introduced.
- `ActivationComposition.swift:238–240` first binds the optional diagnostic callback. With it nil, the diagnostic condition, effect counting, interpolation, and sink invocation are skipped. The process/adopt/flush/apply sequence at lines 221–246 remains intact; the focused composition diff changes observation rather than recognizer or presentation semantics.
- `FourFingerDiagnostics.swift:29–39` guards disabled mode before callback or timer installation. The production default does not even construct this object. Its `print`/`fflush` sink is reachable only when observation is enabled.
- The old one-second backend disclosure, unowned repeating timer, unconditional four-finger preference/backend output, and teardown stack output are removed in the relevant AppDelegate diff. Current teardown at lines 3132–3158 contains no stack formatting/output.

These are activation-diagnostic conclusions. AppDelegate still has other pre-existing startup/telemetry/error output; neither this review nor the stdout-prefix test establishes whole-application zero I/O.

### Ownership, lifecycle, origin, and stale delivery

`FourFingerDiagnostics.swift:4–7,19–22` confines scheduling and tick execution to MainActor. The production timer is scheduled from the MainActor-owned start path; its closure calls `MainActor.assumeIsolated` rather than dispatching an additional asynchronous completion. No new unchecked-Sendable backend capture is introduced.

The timer retains only a weak diagnostic owner; the diagnostic object holds a weak composition. The installed event closure weakly captures both and checks composition identity plus its generation ticket (`:32–39`). Every start first stops the previous session. Stop advances generation, invalidates/releases the timer, clears the previous owner's callback, and removes the owner (`:42–48`). A retained old tick fails generation before reading or stopping a replacement (`:50–54`); an old event closure fails identity/generation. Timer deallocation cleanup at line 60 invalidates the timer, and retained callbacks cannot keep the diagnostic object or composition alive.

Host teardown explicitly stops/releases diagnostics before tearing down activation services (`AppDelegate.swift:3155–3158`). Composition teardown also clears its diagnostic slot (`ActivationComposition.swift:203–214`). Missing owners/backends cause sampling to stop without output. A stopped real backend yields one final neutral sample and stops (`FourFingerDiagnostics.swift:52–57`). Sampling accesses the current owner's backend only during the guarded tick and never starts/stops the touch provider or modifies recognizer, launcher, Core, preferences, or presentation state.

The deinit path invalidates rather than explicitly clearing the composition's closure slot. Its weak captures make that remaining closure inert; explicit host stop clears the slot. This is not a retain-cycle or demonstrated production lifecycle defect.

### Diagnostic payload and behavior isolation

The recognition payload contains counts and typed recognizer/presentation states (`ActivationComposition.swift:240`). Sampling contains counters, provider state, a started boolean, and the backend's bounded startup detail (`FourFingerDiagnostics.swift:56`). Inspection of the backend's startup assignments found `notStarted`, `dlopenFailed`, `noDevices`, `registrationFailed`, and `ok(devices=count)`, not arbitrary error text, application identities, paths, or contact coordinates. The state enums contain neutral state/reason/screen/request fields.

The production sink prints and flushes synchronously in explicit lab mode. Therefore lab-mode output has an observation cost and does not prove a performance budget. The isolation repair removes that cost from the default activation path; it does not prove matched physical performance.

### Removing the delayed catalog repair retains authoritative delivery

The removed two-second closure directly changed `surface.core.pageCount`, then called the surface page-count/reload/layout seams regardless of input phase. Current startup has no replacement diagnostic mutation (`AppDelegate.swift:682–683`). Necessary delivery remains:

1. `self.surface` is assigned before assembly installation (`AppDelegate.swift:443,471–472`).
2. Presentation/idle callbacks are installed before `self.assembly = assembly` and `assembly.begin()` (`:752,782–784`).
3. Scan completion receives the pending snapshot before its non-busy state notification (`AppGridRefreshController.swift:138–143`). The AppDelegate state callback commits immediately when Core is idle; otherwise the surface idle callback performs the commit (`AppDelegate.swift:765–775,1316–1320`).
4. The idle seam commits catalog, folder composition, and query through `AppCatalogAssembly.commitPendingAtIdleBoundary` (`AppDelegate.swift:1334–1341`; `AppCatalogAssembly.swift:561–567`). Existing presentation callbacks refresh/reload the surface and reconcile served page count (`AppDelegate.swift:1267–1298,1322–1328`).
5. The startup window-geometry reload for an already-served revision remains (`AppDelegate.swift:672–680`). Existing-snapshot bootstrap also still has an immediate presentation callback (`AppGridRefreshController.swift:59–67`).

No diagnostic timer calls any catalog or UI mutation seam. Source inspection supplies a concrete reason that late first-scan completion does not require a fixed two-second repair. It does not independently prove startup GUI acceptance.

## Test assessment and evidence boundaries

The frozen test file contains seven meaningful cases: actual synthetic recognition/default stdout-prefix silence; disabled observer/no timer or sink; opt-in neutral recognition; replacement and repeated stop with retained ticks/callbacks; fake-real-backend sampling and stop; missing-backend stop without state changes; and deallocation with retained callbacks. Recognition actually reaches `.fired`. The initial-visible coordinator and nil native window prevent this fixture from ordering a real launcher window. The private LifetimeProbe at lines 52–55 and assertions at lines 169–186 preserve the weak-lifetime checks after the warning correction.

The scheduler deliberately uses unscheduled timers and manually invokes ticks. Those tests exercise ownership and cancellation logic, not actual RunLoop scheduling, device delivery, actor runtime behavior under native events, or physical gestures. The recognition cases use an already-visible coordinator, so they do not cover a hidden-to-visible native-window transition. The output test rejects the `paging-fourfinger-` prefix rather than asserting all stdout empty. The replacement/stop case does not exercise a retained callback after composition-only teardown while the diagnostic owner stays alive; production host stop-before-teardown is established by source ordering, not that test.

Textual source guards can establish absence of the old output/direct-mutation patterns and presence of an opt-in guard. They cannot alone prove short-circuit execution, lifecycle behavior, catalog readiness, or lack of UI effects. The supplied Swift test file is behavioral, not a comprehensive lexical guard suite. No separately executed guard script or raw guard output was inspected, so this review does not certify such a run.

Main supplied the following execution facts; this reviewer did not rerun or inspect raw logs:

| Run | Evidence status |
| --- | --- |
| baseline-r3 | Reported actual synthetic default-recognizer stdout red: 1 test / 1 failure. |
| baseline-r1 / baseline-r2 | Compile failure / NSApp fixture crash respectively; neither is valid behavioral red evidence. |
| postrepair focused-r1 | Reported 1 test / 0 failures. |
| focused-r2 | Latest supplied result: 60 tests / 0 failures, including all seven diagnostic cases. |
| focused-r3 | Initially pending in Main's message. The later stage-summary checkpoint records final 93 tests / 0 failures, including actual catalog/status/source, gesture/backend, prior menu/action routes and the seven diagnostic cases. The corrected targets supplied by Main are LanguageStatusNoticeRuntimeTests, AppCatalogAssemblyTests, and AppSourcesCatalogIntegrationTests; those suites are not credited to r2. |
| full-r1 | Later stage-summary checkpoint records 2417 tests / 0 failures, with a 394-input source freeze. Raw test/freeze evidence was not inspected by this reviewer. |

The LifetimeProbe-only warning correction was inspected and hashed. The final focused/full results above are reported evidence, not independently executed or log-verified evidence. Debug/Release and exact-candidate identity/resource completion remain pending in the latest stage summary. GUI acceptance, real hardware gestures, restart persistence, and matched physical A/B remain Main's separate gates.

## Handoff

No bounded source repair required. Confidence is high for the inspected default gating, weak ownership/generation checks, host teardown order, neutral payload, and retained catalog source path. Runtime confidence remains limited by this source-only assignment. Main should reconcile these frozen hashes with its reported focused/full results and subsequent required evidence before any stage closeout; this report itself makes no closeout or feature-authorization decision.
