# Native isolated test entry: independent bounded source review

Date: 2026-10-14. Verdict: **FAIL — three actionable source findings**.

This verdict covers the approved native entry/startup-safety slice at the source hashes below. It is not a runtime, native UI, physical-input, packaged-candidate, or full-project acceptance verdict. The ordinary zero-CLI marked entry has the intended isolated resolver path; the findings concern a remaining explicit-test startup bypass, the new headless check, and packaging write ordering.

## Authority, scope, and evidence boundary

- Reviewed the approved `Docs/ISOLATED_NATIVE_TEST_ENTRY_SPEC.md`, its dated four-error correction, and `Workflow/stage-summaries/2026-10-14-startup-isolation-safety.md`.
- Domain: native macOS SwiftPM/AppKit application. Existing `AppArguments`, `UITestProfile`, application assembly, and service factories remain the relevant owners; no alternative launcher or storage design is proposed.
- This review follows the explicit human packet: Main plus this reviewer, maximum two; the two implementation writers were reported frozen/closed. Only this report was written. No additional agents, goal operations, implementation edits, commits, resets, or history changes were made.
- Read-only RTK-prefixed source inspection, Git status/diff/HEAD inspection, and SHA-256 calculation only. No Swift, tests, packaging, app launches, process control, reference material, evidence logs, assets, or global memory were executed/read. Candidate manifest filenames were enumerated, not opened.
- Main reports focused verification of 69 tests / 0 failures and a full run in progress. Neither claim was independently verified here. `Workflow/manifest.json` contains workflow configuration, not an executed-test count. No full count, including the suggested 401, is inferred. Full-run completion remains Main's evidence gate.
- Baseline is a substantially dirty shared worktree, including untracked review inputs. HEAD is `319b8cc149a8553adfc3414abaacbe28b59d97ef`; HEAD alone does not identify this source snapshot. The diff from HEAD also contains earlier localization work and is not treated as the exclusive native-entry change set.

## Findings

### F1 — [P1] The performance shortcut still bypasses explicit test-intent rejection in unmarked artifacts

**Evidence and trigger:** `Sources/PagingPrototypeApp/AppMain.swift:25-36` runs the early resolver only when metadata exists or the bundle ID is reserved, then enters `PerfBenchmark.run()` before the ordinary parse/safety decision at lines 45-63. In an ordinary bundle or raw developer binary with no marker, `PAGING_PROTOTYPE_PERF=1` plus an invalid explicit test intent such as arguments `--ui-test-profile ../invalid` therefore follows the benchmark branch without consulting `AppStartupSafety` or validating the profile location. This is a source-derived control-flow trace, not an executed reproduction. `PerfBenchmark.swift:125-134` constructs `PagingSurface` and begins telemetry; its default-enabled telemetry uses fixed `perf-cli-p<N>` run IDs at the ordinary temporary output location.

**Impact:** An invalid test configuration can reach AppKit-backed view construction and diagnostic file writes instead of the required headless rejection. A valid CLI profile outside the candidate tree is also not validated on this path. This does not demonstrate production preference access, and it does not affect the already-guarded marked/reserved zero-CLI native path.

**Likely root cause:** Early preflight recognizes bundle test intent but omits raw CLI test intent. The pure safety tests exercise the policy helper, not this environment-branch ordering.

**Recommended solution:** Apply a shared pure preflight before the performance shortcut whenever the bundle is marked/reserved **or** the raw arguments express test intent, including the unsupported case/equals variants already covered by safety tests. Reject parse/profile-location failures there. Preserve the existing performance behavior for ordinary non-test startup. Cover this ordering through a suitable startup-decision seam; do not use production startup as a negative fixture.

**Affected scope / regression risks:** `AppMain.swift`, shared test-intent policy, entry-focused tests. Keep ordinary non-test performance/smoke behavior and the four legacy tuning families unchanged. Do not relocate benchmark storage as an unrelated feature expansion.

**Confidence:** High for the bypass and subsequent benchmark operations, based on direct source control flow; runtime behavior was not exercised.

### F2 — [P2] The new startup check does not consistently produce neutral, resolver-only output

**Evidence and trigger:** `AppMain.swift:47-51` prints the raw `ParseError` and help before reaching `LAUNCHCOPY_STARTUP_CHECK` at lines 72-74. In an unmarked artifact with the check enabled, arguments `--ui-test-windowed --private-fixture-name` yield an unknown-argument error that includes the caller's literal token before exit 2. Ordinary malformed arguments can similarly print raw values and then report fallback booleans. On success, help handling at lines 64-66 and the composited notice at lines 68-70 also precede the check. Existing performance/smoke environment branches at lines 35-42 take precedence over the check and can run diagnostic work instead of the intended resolver-only probe.

**Impact:** The approved check cannot be relied upon as a path/ID/name-free, headless startup-decision probe across these supported/error cases. The valid plain marked check does print only three booleans; the defect is branch/output ordering, not those boolean values.

**Likely root cause:** The check was added downstream of existing presentation and diagnostic branches rather than given a bounded early path through the same resolver.

**Recommended solution:** When the new check is explicitly enabled, resolve startup before existing diagnostic/help/error output branches. Emit only mode booleans on success and the existing neutral rejection message plus a nonzero exit on failure. Preserve normal help and ordinary legacy diagnostics when the check is absent. Document deterministic precedence when check and existing diagnostic environment flags are both present.

**Affected scope / regression risks:** `AppMain.swift` and entry/output-focused tests. Preserve normal production CLI fallback and avoid constructing AppKit or diagnostic sessions in the check path.

**Confidence:** High; output and precedence follow directly from the source ordering. No output was captured by running the app.

### F3 — [P2] Native packaging creates an out-of-project directory before rejecting the destination

**Evidence and trigger:** `Scripts/package-app.sh:48-56` calls `validate_native_destination`. `Scripts/verify-native-ui-test-entry.py:36-53,75-86` accepts a new `.app` under any canonical `.build/candidates/<candidate>` tree; it has no project-root constraint. With a valid opt-in/profile/reserved ID and a new `OUT_APP` such as `/tmp/native-entry-review/.build/candidates/new/Test.app`, this preflight accepts the ancestry. `package-app.sh:67-73` then creates the parent directory at line 68 **before** checking whether it is under the project's `.build`. Packaging finally rejects it, but has already written outside its declared destination boundary. No such directory was created in this review.

**Impact:** A rejected native packaging invocation has an unauthorized filesystem side effect. The generic profile resolver's acceptance of canonical candidate aliases does not replace the packaging script's narrower project-root write boundary.

**Likely root cause:** Native preflight reuses generic candidate ancestry rules, while project containment is checked only after `mkdir`. Shell `pwd` also does not explicitly request physical-path resolution, so canonical containment should be checked using the same resolved destination that will be written.

**Recommended solution:** Canonicalize the proposed destination and check containment under the canonical project `.build` before any directory creation. Preserve the generic `UITestProfile` identity rules, including approved aliases; make the project-root restriction a packaging preflight responsibility. Add a bounded negative packaging/preflight check verifying rejection leaves an external candidate parent absent. This reviewer did not execute that check.

**Affected scope / regression risks:** `package-app.sh` and its Python preflight integration. Keep explicit opt-in, existing-destination rejection, reserved ID, and non-destructive native mode. No production packaging redesign is required.

**Confidence:** High for the direct external-path write ordering. No adversarial race or runtime exploit is assumed.

## Contract checks supported by this source snapshot

| Area | Source assessment |
| --- | --- |
| Marked/reserved startup | Resolver rejection occurs before `NSApplication.shared`, `AppDelegate` construction, and the existing headless shortcuts. Missing reserved marker and wrong-ID marker reject. F1 concerns unmarked CLI intent. |
| Strict marker | `NativeUITestEntry.swift:37-44` requires exactly `version`/`profile`, rejects CFBoolean and floating-point NSNumber encodings, requires integer value 1 and the existing ASCII profile grammar. Python likewise requires exact keys and `type(version) is int`, excluding bool. |
| Default marked options | Starts from the existing parser/default options, then forces windowed=true, fullscreen=false, marker profile, folderLab=true. No separate `defaultWindowedProfile` symbol exists in inspected source; the approved default marked behavior is assembled in the resolver. |
| CLI precedence | Valid same-profile windowed runner remains compatible; another profile rejects; windowed-only inherits marker profile. Fullscreen is overridden by windowed as explicitly approved. Profile-only without windowed remains a parse error, matching the supplied tests. Catalog-root overrides and neutral content reject for marked entries. |
| Path identity | Uses the existing side-effect-free `UITestProfile.resolve` before AppKit. Canonical candidate ancestry, existing `.app`, local file URL, and all five output-directory guards remain owners of identity/safety. Canonical bundle/candidate aliases within the accepted tree are intentionally allowed; profile output symlinks and escaping canonical paths reject. |
| Stores/services/content | Existing `AppDelegate.configureUITestProfile` precedes preference installation, creates profile-local directories, and rechecks resolution. Marked options flow into candidate-derived suites, layout/cache roots, synthetic catalog roots, and `LauncherRuntimeServices` fake activation/login adapters. Source inspection does not prove live absence of production I/O. |
| Legacy CLI | Diff confirms exactly FOUR pre-existing fatal tuning families: decay, glide frames, overshoot, timer tolerance. Invalid frame driver without test intent retains ordinary fallback. Typed isolation errors and case/equals raw test intent reject through the new safety policy. The spec/stage append dated corrections superseding earlier five-error wording. |
| Packaging metadata | Native mode requires explicit nonempty `NATIVE_UI_TEST_PROFILE`, a valid ID, reserved bundle ID, and non-destructive packaging. Reserved ID without opt-in rejects. Marker contains data only; manifest records explicit mode/isolation and Info.plist SHA-256 alongside executable/localization identities. F3 remains a pre-write containment defect. |
| Metadata checker | Bounded fixed regular Info.plist read; rejects symlink plist/non-directory Contents, duplicate keys, oversized input, malformed/future markers, wrong identity, and unsafe output directories. Source inspection only; checker was not executed. |
| Tests | Supplied Swift tests cover pure safety ordering across argument failures, four tuning families and frame-driver compatibility; marker shape/version/profile, no profile-directory writes during resolution, same/conflicting CLI, content conflict, outside candidate and profile symlink. They do not cover F1/F2 entry environment/output ordering or F3 project containment before mkdir. No XCTest result is certified here. |

No marker commands, executable-path arrays, LSEnvironment injection, Terminal launch, or alternate execution wrapper were added by the reviewed native entry. Later native inspection must use direct Cua opening of **only the allowed test app** after Main's repaired code/candidate gates. Denial of that app is a stop boundary; this report does not authorize another surface or tool.

## Snapshot identity

Core input hashes were calculated twice after inspection and were unchanged across those two reads. These identify reviewed source bytes, not compiled binaries, Info.plist bytes in a built app, or runtime observations. Supporting-input hashes below were calculated once. A repair requires refreshed hashes and bounded re-review.

```text
547a2e3165c0bd3135d2f96186da6259b630d7c9ce76488b10e981d46a2d9835  Docs/ISOLATED_NATIVE_TEST_ENTRY_SPEC.md
0cbf45db95e4766badc6c7fdce75e42a30dc384d5422513eab003ef6c5584345  Workflow/stage-summaries/2026-10-14-startup-isolation-safety.md
b465e0038a5cf90c83265de62aa5abe819c41a028d9d13219300f14fa7d059e5  Sources/PagingPrototypeApp/AppStartupSafety.swift
020b92f9dfb37cfb84553c9b762417261bf0a1a64bf90c4f3c8cd4b8035f9396  Sources/PagingPrototypeApp/NativeUITestEntry.swift
f8d690aadcab6ddb4471d4bc80b15910260d44df52fa364e4c7faef57b56fed2  Sources/PagingPrototypeApp/AppMain.swift
26a5a3e67444ac4b3584ee9e04fceef68280016a76a29454c22c383997a9623a  Scripts/package-app.sh
7b2b5699082b26ce73ae3e351b92b3cba2404370a22a9f2f51cb764f50718c3d  Scripts/verify-native-ui-test-entry.py
4fce04249e5ea798968a4a53b94d0e6c7b6e1f9c147df42160d6a38070338b6d  Tests/PagingUITests/StartupIsolationSafetyTests.swift
12d463e7b842b90006d32699f7adb2a14b61ed2cd7d8e05228baa6f0ed87c9bd  Tests/PagingUITests/NativeUITestEntryTests.swift
7130894ed4fecfb19d5435489fedc7ac82f699869bc2669c8f846463db55fa7c  Sources/PagingPrototypeApp/UITestProfile.swift
472de3fa0dd82736e34cdf6c605847f2023a44c9a205988b9e63b57d4d01c84a  Sources/PagingPrototypeApp/AppArguments.swift
8d78ea4f207b3d7a6bf23bff8ad7b9795e01bbbf40fb11b3d6567bcabdbf24d3  Sources/PagingPrototypeApp/AppDelegate.swift
967db367f5219f8bdf56116eaecddab632ddb9dc986b57a29e69c49bba656927  Sources/PagingPrototypeApp/LauncherRuntimeServices.swift
a0171640878ec3ddd5205a3f05a312e2da1cd43127802833f1df9da8d291e966  Workflow/manifest.json
```

Supporting source inputs:

```text
6357a11a049f69a081a0f2260faef12d16f25d03a89449154cfe85890f1f3f57  Sources/PagingPrototypeApp/PerfBenchmark.swift
c069b2046173df177b098ccbc98e13d61d454e232187cbf4aa9038b82db5d0dc  Sources/PagingTelemetry/PagingTelemetry.swift
7ab77f258272a595054fcecbe1cd5b15ac73a685b58bfbb9c661c02b789452f2  Sources/PagingTelemetry/TelemetrySession.swift
750e8a23895ad62a933a0204df3c710ee27aaa7ff32edd01d800f3266f65804f  Tests/PagingUITests/UITestProfileTests.swift
6928c4ebd8edcabc637e028d24790450a052b739117f0b0ef9f6ad6b45b7bcfc  AGENTS.md
```

## Handoff

Main should repair F1-F3 within the accepted entry/startup-safety scope, refresh source hashes, and obtain bounded re-review before relying on this slice's code gate. Focused/full XCTest, Debug/Release packaging, unique candidate/executable/plist/resource identity, direct allowed-app native behavior, and physical/manual acceptance remain separate Main-owned gates. No full-goal completion is claimed. The automatic goal remains untouched; the fresh human request is the authority for this review.

## 2026-10-14 — R2 append-only source re-review after F1-F3 repair

**Current bounded verdict: FAIL — F1 and F2 closed in source; F3's original external-mkdir defect closed in source; one related packaging repair defect, F4 [P2], remains.** This section supersedes the earlier snapshot's current disposition without deleting or rewriting its findings, hashes, or execution boundary.

Main reported repaired source frozen. This same reviewer inspected the refreshed specification/stage, `AppStartupPlan`, `AppStartupSafety`, `AppMain`, package script/checker, and the three relevant test files. Only this report is modified. No source edits, test/build/package execution, apps, controls, process operations, additional agents, or goal operations were performed. Frozen source hashes below matched across two read-only calculations before this append. The prior report bytes had SHA-256 `a40474fc3b7d515db1365beab07d7903d3f6eae8e26dee200915956e11b9095b` before appending.

### Finding dispositions and retained behavior

| Finding | R2 source disposition | Evidence |
| --- | --- | --- |
| F1: explicit CLI test intent bypassed by performance | CLOSED IN SOURCE | `AppStartupPlan.swift:19-28` includes marker presence, reserved ID, or shared `AppStartupSafety.hasUITestIntent` in preflight. Only ordinary non-test/non-check startup can return performance/smoke without parsing. All test-intent paths parse and pass the existing native/profile resolver before lines 38-39 may choose diagnostics. Invalid arguments/location yield a neutral reject action. |
| F2: check neutrality/precedence | CLOSED IN SOURCE | Check prevents the early diagnostic return at plan lines 22-25; failure under check cannot select `legacyReject` at lines 29-35; success returns `.check` at line 37 before performance/smoke/application. `AppMain.swift:27-37` executes neutral rejection with exit 2 or the three mode booleans with exit 0; help, raw errors, composited notices, diagnostic sessions and `NSApplication.shared` are confined to other actions. |
| F3: external mkdir before project containment | ORIGINAL DEFECT CLOSED IN SOURCE | `package-app.sh:68-83` resolves physical project root and proposed parent, checks strict descendant containment under canonical project `.build`, and rejects before line 84's mkdir. The app path then uses the physical parent at line 86. Generic profile/candidate alias rules remain unchanged. F4 below concerns the remaining noncanonical sidecar paths, not continued acceptance of the original external-parent trigger. |

The pure action router is a proportionate repair: `AppMain` performs only the selected action, while the existing parser/profile resolver remain the policy owners. The resolver/check branches do not construct diagnostic sessions or AppKit objects. Shared CLI intent retains the prior case/equals detection and typed isolation-error rejection.

Ordinary non-test headless precedence remains performance before smoke, including legacy diagnostics' own parsing/reporting behavior. Outside diagnostic/check modes, ordinary nonfatal parse errors still select default application options with the original error available for legacy logging. The four tuning families still select `legacyReject`; invalid frame driver without test intent still falls back. Marked profile matching, forced windowed/folder-lab options, strict metadata types/keys and reserved identity handling are unchanged by hash. This closes the identified routing defects without claiming that every runtime storage/service behavior was independently exercised.

### F4 — [P2] Sidecar writes retain the original parent after packaging canonicalization

**Evidence and concrete trigger:** `package-app.sh:84-86` creates `APP_PARENT_ABS` and rebuilds `APP_DIR` using that physical parent, but does not assign it back to `APP_PARENT`. Resource and candidate manifests still use the original lexical parent at lines 191 and 199. For a new absolute destination under the project such as `<project>/.build/candidates/new/unused/../Test.app`, with `unused` absent, the Python native preflight's `Path.resolve(strict=False)` and containment step normalize the parent to `<project>/.build/candidates/new`. The script creates that canonical directory and assembles the app there. It does not create `unused`. The later redirection to `new/unused/../LOCALIZATION_RESOURCES.sha256` cannot traverse the missing `unused` directory and fails, leaving an assembled app without the required emitted identity sidecars. This is a source-derived filesystem/control-flow trace, not an executed packaging test; it requires no symlink race or malicious concurrent writer.

**Impact:** A destination accepted and normalized by preflight can fail after substantial artifact writes solely because packaging mixes canonical and original paths. The comment at line 85 promises physical-parent use for every subsequent artifact write, but the sidecars violate it. F3's original external-path rejection is repaired; a successful candidate/identity-manifest handoff is still unreliable for this accepted path form.

**Likely root cause:** Canonicalization updated `APP_DIR` but omitted the shared `APP_PARENT` used by both sidecars. These sidecars are necessary to the existing candidate identity contract, not an additional feature.

**Recommended solution:** After successful containment, use the validated physical parent consistently, e.g. set `APP_PARENT` to `APP_PARENT_ABS` before subsequent writes, or derive both sidecar paths explicitly from `APP_PARENT_ABS`. Keep the generic `UITestProfile` alias semantics unchanged. Main's packaging validation should cover the existing external-parent negative case and a positive canonicalized destination/sidecar consistency case.

**Affected scope / regression risks:** `Scripts/package-app.sh` parent reuse and candidate/resource sidecar destinations. No change to profile identity, production settings, startup policy, or packaging opt-in is needed. Preserve already-created candidates rather than deleting them for verification.

**Confidence:** High for the inconsistent variable use and missing lexical component failure; packaging execution and artifact contents were not inspected.

### Tests inspected and execution attribution

`AppStartupPlanTests.swift` contains exactly five test methods. They cover invalid explicit test intent before performance/smoke (including malformed case/equals and outside-candidate profile), check precedence over diagnostic/help/composited/legacy-error routes, ordinary legacy routing/fallback/fatal tuning behavior, bad marked/reserved metadata across modes, and valid explicit-profile preflight without profile-directory creation. Existing safety tests still cover all four tuning families and ordinary frame-driver fallback. These are meaningful pure-routing checks for F1/F2. Output neutrality additionally follows from inspecting the now-small `AppMain` action switch; no output was independently executed or captured by this reviewer. F3/F4 packaging behavior still needs Main's serial validation.

Main reports a safe F2 reproduction using the old r1 raw developer binary: synthetic token disclosed, exit 2, with a JSON artifact. That reproduction and artifact were not read or repeated here and are **Main-owned execution evidence**, not independent validation. The unsafe old performance/F1 path was not executed. Main reports r1 candidate preserved and never launched. F3's external-parent negative verification was described as next/pending at this handoff.

The refreshed stage records historical initial gates of 69 focused / 2434 full tests, zero failures, and 400 inputs. Those are explicitly stage/Main-reported historical counts, not counts from a manifest independently read here, and not repaired-source execution results. No 401 count, new total, zero-warning claim, repaired build result, or native/physical PASS is inferred.

### R2 reviewed source hashes

```text
0dbacbe7a3cd515ef499923f600a3e0027cfeb0865653a2580f1864a085011f6  Docs/ISOLATED_NATIVE_TEST_ENTRY_SPEC.md
1884a69a4e3d17a48328d92154c9f003c19ed3a88d2d9a1d1540816529a48b01  Workflow/stage-summaries/2026-10-14-startup-isolation-safety.md
e97465d4fb81dc44c0ed1a551eb93b6e4843baa018ec5ff08120a07a8aeb92c5  Sources/PagingPrototypeApp/AppStartupPlan.swift
7708bffe7b97f22a6b06378b3258b2e619e0500983e692857123810a44828e90  Sources/PagingPrototypeApp/AppStartupSafety.swift
17fbe204c3fa2608ebca4f34a77084aab57f67247856a877e115ffedfcfe1c0c  Sources/PagingPrototypeApp/AppMain.swift
020b92f9dfb37cfb84553c9b762417261bf0a1a64bf90c4f3c8cd4b8035f9396  Sources/PagingPrototypeApp/NativeUITestEntry.swift
7130894ed4fecfb19d5435489fedc7ac82f699869bc2669c8f846463db55fa7c  Sources/PagingPrototypeApp/UITestProfile.swift
472de3fa0dd82736e34cdf6c605847f2023a44c9a205988b9e63b57d4d01c84a  Sources/PagingPrototypeApp/AppArguments.swift
5358cac93e40bac309adfff84b0507dd020a29891f14ef7b64c187befd356117  Scripts/package-app.sh
7b2b5699082b26ce73ae3e351b92b3cba2404370a22a9f2f51cb764f50718c3d  Scripts/verify-native-ui-test-entry.py
689fb1af34bd7b5d7a0bd15d23a25f1f3f8adeec6736ee67f088fa946610b527  Tests/PagingUITests/AppStartupPlanTests.swift
4fce04249e5ea798968a4a53b94d0e6c7b6e1f9c147df42160d6a38070338b6d  Tests/PagingUITests/StartupIsolationSafetyTests.swift
12d463e7b842b90006d32699f7adb2a14b61ed2cd7d8e05228baa6f0ed87c9bd  Tests/PagingUITests/NativeUITestEntryTests.swift
```

### R2 handoff boundary

Main owns the bounded F4 correction, refreshed frozen hashes, serial code/test/packaging/candidate identity gates, and subsequent direct Cua opening of only the allowed native test app after those gates. No app has been opened by this reviewer. A denied app remains a stop boundary, with no alternate tool/surface workaround. This append neither resumes/closes the automatic goal nor claims full-project completion, runtime isolation acceptance, native GUI acceptance, or physical-input PASS.

## 2026-10-14 — R3 append-only source re-review after F4 repair

**Current verdict: PASS — bounded source review only. F1-F4 are closed in the reviewed source; no remaining actionable finding in this repair scope.** This supersedes the current disposition of R1/R2 while preserving all earlier findings, hashes, and evidence qualifications. It does not certify packaging execution, a built candidate, native runtime/physical behavior, or completion of the full goal.

### F4 disposition

**CLOSED IN SOURCE.** `Scripts/package-app.sh:86` now assigns `APP_PARENT="$APP_PARENT_ABS"` immediately before canonical `APP_DIR` assignment at line 87. Both sidecars at lines 192 and 200 consequently derive from the validated physical parent, matching the assembled app's parent. For the previously identified accepted `/unused/../` form, downstream sidecar destinations no longer retain the nonexistent lexical component. The project containment check remains before mkdir at line 84; generic `UITestProfile` alias semantics remain unchanged. This is a direct source/control-flow assessment, not an executed positive or negative packaging check.

The refreshed hashes confirm `AppStartupPlan`, startup safety/entry/main, `UITestProfile`, `AppArguments`, all three reviewed Swift test files, the metadata checker, specification, and stage summary are unchanged from R2. The prior F1/F2 closures and F3 external-parent rejection therefore retain their R2 source basis. The package script is the sole changed input among that reviewed set. Its refreshed digest matched across two read-only calculations.

### Execution boundary and Main-owned gates

This same reviewer only inspected source/report text and calculated hashes, then appended this report. No source edits, tests, builds, packaging, app launches, process/control actions, other agents, evidence-artifact reads, or goal operations were performed. The pre-append report digest was `eff4212e2d28777dbccc0cce92483ff0eea5f4a5d90fc0c3a45b81f2f7a2ffab`.

Main reports actual r2 results of **74 focused tests / 2439 full tests**, with Debug and Release passing. These are Main-owned results, not independent reviewer proof; their logs/artifacts were not read or replayed here. Main also states the r2 build finished before the package script edit, so those results are not evidence that the repaired packaging script was exercised.

Main's planned r3 packaging must separately exercise (1) rejection of an external parent without creating it, and (2) a positive canonical `/unused/../` destination with both identity sidecars in the physical candidate parent. Those execution checks and fresh candidate/executable/Info.plist/resource identity remain pending at this handoff. After the serial gates, only direct Cua opening of the allowed native test app is within scope; tool denial remains a stop boundary. No runtime, native UI, or physical PASS is granted by this source verdict.

### R3 current reviewed input hashes

```text
0dbacbe7a3cd515ef499923f600a3e0027cfeb0865653a2580f1864a085011f6  Docs/ISOLATED_NATIVE_TEST_ENTRY_SPEC.md
1884a69a4e3d17a48328d92154c9f003c19ed3a88d2d9a1d1540816529a48b01  Workflow/stage-summaries/2026-10-14-startup-isolation-safety.md
e97465d4fb81dc44c0ed1a551eb93b6e4843baa018ec5ff08120a07a8aeb92c5  Sources/PagingPrototypeApp/AppStartupPlan.swift
7708bffe7b97f22a6b06378b3258b2e619e0500983e692857123810a44828e90  Sources/PagingPrototypeApp/AppStartupSafety.swift
17fbe204c3fa2608ebca4f34a77084aab57f67247856a877e115ffedfcfe1c0c  Sources/PagingPrototypeApp/AppMain.swift
020b92f9dfb37cfb84553c9b762417261bf0a1a64bf90c4f3c8cd4b8035f9396  Sources/PagingPrototypeApp/NativeUITestEntry.swift
7130894ed4fecfb19d5435489fedc7ac82f699869bc2669c8f846463db55fa7c  Sources/PagingPrototypeApp/UITestProfile.swift
472de3fa0dd82736e34cdf6c605847f2023a44c9a205988b9e63b57d4d01c84a  Sources/PagingPrototypeApp/AppArguments.swift
0a8ef1084618a1316a608dd4ee002efae5182d2d263d2b2eba2a60fb012b96c3  Scripts/package-app.sh
7b2b5699082b26ce73ae3e351b92b3cba2404370a22a9f2f51cb764f50718c3d  Scripts/verify-native-ui-test-entry.py
689fb1af34bd7b5d7a0bd15d23a25f1f3f8adeec6736ee67f088fa946610b527  Tests/PagingUITests/AppStartupPlanTests.swift
4fce04249e5ea798968a4a53b94d0e6c7b6e1f9c147df42160d6a38070338b6d  Tests/PagingUITests/StartupIsolationSafetyTests.swift
12d463e7b842b90006d32699f7adb2a14b61ed2cd7d8e05228baa6f0ed87c9bd  Tests/PagingUITests/NativeUITestEntryTests.swift
```
