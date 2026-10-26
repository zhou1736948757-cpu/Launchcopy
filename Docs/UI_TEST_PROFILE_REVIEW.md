# Isolated UI Test Profile — Independent Combined Source Review

Date: 2026-10-13
Authority: user-approved combined review scope, `Docs/ISOLATED_UI_TEST_PROFILE_PROPOSAL.md`,
`Docs/LAUNCHBETTER_FOLDER_RENAME_REPAIR_PLAN.md`, and the approved cancellable Quit policy.
Reviewer writable scope for this review: this NEW document only.

Current decision: **r2 Rename SOURCE PASS / UI Test Isolation SOURCE PASS**. See the dated final r2 rereview below; earlier FAIL sections are preserved history.

## Separate verdicts

- **Rename / durability: SOURCE PASS** for the current combined-source snapshot,
  including the final R5 late-timeout and R7 resident hide/suspend repairs.
- **UI test isolation: SOURCE FAIL — I1 / P1.** The synthetic-only catalog boundary
  is not enforced for ordinary directory symlinks beneath an admitted root.
- **Writable candidate GUI prerequisite remains FAIL.** No GUI, restart, physical
  input/performance, production global activation/login, or full parity acceptance
  is issued. Main owns execution and the decision to route the concrete repair.

These verdicts apply to combined ui-profile r1, not the earlier rename-r1 binary.
`Docs/FOLDER_RENAME_SLICE_REVIEW.md` is preserved unchanged as historical evidence;
its earlier failures are not silently relabeled or attributed to this candidate.
Profile implementation is now explicitly authorized and included in this review.

## Frozen inputs and existing execution evidence

Freeze: `.build/verification/20261013/ui-profile/source-files-r1.sha256`.
Actual count: **309 entries**. Reviewer independently read and hashed all recorded
files: **309 matches, zero missing/changed**, and repeated the check before writing.
Manifest SHA-256: `ffc29322b0f5cf11a5e797e216ca9544e073596321b14493c120b8e7c3956abb`.
No test/build commands were executed by this reviewer.

Read Main's existing `focused-r1.log`: **94 tests / 0 failures**,
2026-10-13 19:38:50.755 JST, 0.978 seconds wall duration. Read `full-r1.log`:
**1913 tests / 0 failures**, 19:40:57.597 JST, 30.629 seconds wall duration.
The actual nonzero XCTest runs are the evidence, not the subsequent zero-test
Swift Testing footer. These results do not test I1's missing traversal case.

Read `debug-r1.log` and `release-package-r1.log`: product builds complete;
the latter records complete assembly of
`.build/candidates/folder-rename-ui-profile-rc-20261013-r1/LaunchcopyUITest.app`.
Executable SHA-256 from log/Main:
`a9f9059551f476faf7feb61e7d0d57443e4dd5cea68bd44a28b678466a455eee`.
Main reports the distinct test bundle ID `com.launchcopy.test.folderrename`.
No candidate was launched or stopped by this reviewer.

`Docs/ISOLATED_UI_PROFILE_CAPTURE_PROTOCOL.md` explicitly requires an independent
isolation PASS before writable GUI, uses Info.plist-only synthetic packages and
normal test-instance Quit, and excludes original icons/executable launch smoke.
Its prescribed 37 fixtures and distinct bundle identity are useful operational
controls; they do not repair the scanner's source containment gap.

## I1 — P1: nested directory symlink escapes the synthetic-only catalog

**Exact locations:**

- `Sources/PagingPrototypeApp/AppDelegate.swift:139–146,521–525`: startup validates
  only each requested root's canonical containment, then supplies profile-local
  roots to the ordinary assembly.
- `Sources/PagingPrototypeApp/AppCatalogAssembly.swift:410–418`: ordinary
  `CatalogScanner` / `ScanConfiguration` and real SystemIconLoader are used.
- `Sources/MacAppCatalog/CatalogScanner.swift:144–152,156–160,174–177,191–207,216–232`:
  `.app` symlinks obey the follow flag, but ordinary directory symlinks do not.
- `Sources/MacAppCatalog/ScanConfiguration.swift:23–26`: the default explicitly
  promises not to follow directory symlinks.

**Concrete trigger and source evidence:** configure a valid candidate/profile
with its normal `Applications` root. Under that root, an ordinary directory
symlink named `External` points outside the profile to a directory containing an
`.app`. Root validation succeeds: it checks `Applications`, not its descendants.
The scanner sees a symlink, resolves its target to determine that it is a directory,
then routes the non-`.app` directory to `descend` without checking
`followDirectorySymlinks`. `descend` resolves and walks the external directory.
`processBundle` subsequently reads that outside package's Info.plist. Its lexical
root-containment check returns nil, but the `?? bundleURL.standardizedFileURL`
fallback still inserts the outside app into the catalog. Its actual URL is then
available to the standard icon/launch consumers.

This is a source control-flow finding, not a claim that any real app was scanned
or launched in this review. A regression fixture can prove it entirely with two
temporary synthetic directories, without touching real application roots.
Storage/preference namespaces may remain isolated while this catalog read/consumer
boundary fails. The new specification requires synthetic-only catalog content;
the existing scanner dependency therefore blocks the profile source PASS.

**Likely root cause:** the old scanner's no-follow gate is applied only to linked
`.app` entries, while generic directory descent and its containment-failure fallback
remain permissive. New profile validation assumes the supplied root confines all
subsequent scanner reads.

**Recommended solution:** make the profile's actual scan honor the no-follow/
containment contract before descending or reading external metadata; reject or
skip escaping entries without producing real app records. Main can use a bounded
scanner contract repair or an equivalent profile-specific enforcement seam;
this reviewer does not authorize an architecture change. Do not rely solely on
manually clean fixtures or a post-scan UI filter (metadata has already been read).
Preserve ordinary production defaults and explicitly configured symlink semantics.

**Required regression:** through the real scanner/assembly used by a configured
profile, place a non-`.app` directory symlink under synthetic Applications targeting
an outside temporary directory with a valid synthetic Outside.app. Prove default
profile scanning neither reads/adopts the outside app nor supplies its URL to icon/
launch resolution; keep valid local fixtures discoverable. Also retain the existing
helper/root escape and `.app`-symlink coverage. No reviewer-created fixture was run.

**Affected scope:** candidate synthetic catalog admission and its icon/launch
consumers; not a demonstrated write to production preference/layout stores.
**Regression risks:** accidentally changing explicit production follow behavior,
losing valid local fixture records, filtering only after private/external reads.
**Confidence:** high from explicit branches. **Severity:** P1 because the missing
constraint is a prerequisite for the newly authorized writable GUI workflow.

## Rename and durability repairs observed

| Area | Current source acceptance |
| --- | --- |
| R5 direct drain | Receipt submission ID is compared to latest after completion; mismatch repeats flush under the same absolute deadline (`WorkspacePersistenceQueue.swift:101–108`). Failed receipts are not reused as cached durability. |
| R5 late automatic timeout | Late callback now captures operation weakly, compares its submissionID to captured batch, and explicitly reschedules latest observation on mismatch instead of publishing old success (`WorkspacePersistenceQueue.swift:126–138`). Default observation wait remains 2 seconds (`30–31`); only tests inject a shorter interval. |
| R5 meaningful regression | `WorkspacePersistenceQueueTests.swift:227–243` actually waits for both automatic observer timeouts, then releases scripted A success / B failure. Expected outcomes are timeout, timeout, failure with no old success. This closes the prior unexercised callback branch in source/test evidence. |
| R7 shared resident hide | `AppDelegate.swift:2151–2165` cancels pending Quit before normal hide cleanup. Installed launcher uses `launcherDidHideHandler` (`443,2169–2175`), covering sleep/session suspension that can bypass prepareHide. |
| R7 retained prompt cleanup | `AppDelegate.swift:2180–2189` retains the alert locally, clears owner reference and invalidates the quit choice before endSheet/abortModal. Store replacement and teardown share the same cleanup; stale choices cannot approve a new attempt. |
| R7 regression and presentation | Owner test at `FolderRenameAssemblyTests.swift:398–424` exercises actual composition background hide/willSleep, negative reply, stale-choice rejection and a successful retry. Visible parent uses retained sheet; hidden parent uses standalone modal (`AppDelegate.swift:2314–2328`); Cancel remains Return/default (`2337–2340`). These are source/unshown owner checks, not a rendered-sheet GUI pass. |
| Other previous findings | Ordered store-epoch submissions, latest-batch state rechecks, retained terminal rejections, bounded single-writer final flush, neutral persistent failure notice and accepted-data dirty gate remain observed. F1–F3/R4/R6 have no new scoped source finding. Actual shouldTerminate still defers irreversible teardown until accepted termination. |
| Title and metadata | Fresh control per edit, token/revision/layout/store-epoch checks, own field editor's live text, cancel/dismiss before unmount, no-op handling, canonical hidden/missing member preservation and preferred/path alias fallback remain present. No new identity, lifecycle or title-data loss finding was observed in this combined change. |

## Isolation mechanisms that do pass source inspection

- `AppArguments.swift:265–277,337–339` accepts one exact bounded lowercase ASCII
  profile ID and requires the explicit `--ui-test-windowed` switch. No profile
  means no new resolution; profile errors do not normalize into a production ID.
- `UITestProfile.swift:53–85,102–119` requires a real existing canonical `.app`
  beneath adjacent `.build/candidates` components, resolves candidate aliases,
  rejects external/lookalike roots and output-directory symlinks/file collisions.
  The root's descendants are not inspected here, which matters for I1.
- `UITestProfile.swift:87–95` uses length-framed candidate identity/profile with
  SHA-256 suite names; same candidate/profile survives restart, other candidates/
  profiles differ. Raw candidate/profile strings are not used as suite names.
- `AppDelegate.swift:136–167` resolves before preference stores/services, validates
  explicit roots, creates only profile-owned directories and resolves again before
  assigning the profile. Invalid configuration exits startup without ordinary
  storage fallback. A partially created candidate-local directory is not a
  production data write. Existing fixture directories are not chmod/reset.
- Layout directory (`AppDelegate.swift:674–677`), appearance/management/activation
  suite selection (`1755,1804,1662`) and wallpaper cache (`346–351`) use the profile.
  Namespaced UserDefaults live in the OS preference mechanism; this is namespace
  isolation, not a claim that their physical files all reside under the candidate.
  Constructor failures retain existing in-memory fallbacks, never production suites.
- `LauncherRuntimeServices.swift:7–24` chooses fake global shortcut/session/hot-corner
  adapters and fake login when isolated; production factories use the same real
  adapters as before. `AppDelegate.swift:1689` prevents attaching the real touch
  backend. Settings apply operates on already selected fake adapters and cannot
  switch to real registration. No production global unregister/login mutation was
  introduced for the test profile.
- Absent profile retains production suite names, store-directory fallback, ordinary
  runtime adapters, window behavior and default wallpaper provider. Same-process
  settings reuse does not contact a different resident process.
- Helper tests use actual temporary `.app` directories and canonical symlink cases;
  five assembly tests cover fail-before-store root rejection, local directory/restart
  marker, and distinct actual preference stores. Two runtime-factory tests verify
  fake globals/login. These tests do not exercise the nested ordinary-directory
  symlink through CatalogScanner that causes I1.

## Delivery boundary

Do not treat the current packaged candidate as isolation-approved for writable GUI.
Main should repair I1, provide matching source/test/candidate evidence, and request
an isolation rereview. Rename SOURCE PASS does not confer the separate profile
safety PASS. Current and old candidates keep their own identities; tests run against
an injected/unshown setup do not certify real candidate behavior. Reviewer performed
no builds, tests, GUI operations, installations, process stops or source edits.
Only this new report is written; the prior rename report is retained.

## Combined reviewed-file fingerprints

The following rows match ui-profile source freeze r1 (309 total recorded entries).

| File | SHA-256 |
| --- | --- |
| Sources/PagingPrototypeApp/AppDelegate.swift | b57d96cb4f66a2b0cee613f4326c6cc07aa094b1cecc8a6d21b3327fe3b79e3e |
| Sources/PagingPrototypeApp/AppArguments.swift | 472de3fa0dd82736e34cdf6c605847f2023a44c9a205988b9e63b57d4d01c84a |
| Sources/PagingPrototypeApp/UITestProfile.swift | 1b4e8602b3ed443ac237962b1a50f5e0e59a97521e6193878c5f302303d54ded |
| Sources/PagingPrototypeApp/LauncherRuntimeServices.swift | 967db367f5219f8bdf56116eaecddab632ddb9dc986b57a29e69c49bba656927 |
| Sources/PagingPrototypeApp/WorkspacePersistenceQueue.swift | 60655100da52832df6842a91cecb582939e83df25976dcf7408f0e85baea5e79 |
| Sources/PagingPrototypeApp/WorkspaceQuitCoordinator.swift | 2f70b22650cd05257fb9f2087bb213240c6dd043b55a2581cfe2c1b9cf4054f7 |
| Sources/AppGridUI/LayoutStore/LayoutStoreActor.swift | 1f6aee06be615ae6f2b06ee5633200e0931c5f2663b1270a258d1e45a4707d5a |
| Sources/MacAppCatalog/CatalogScanner.swift | 3ee08cc942c6b76695c9e91eb5b192c7a75eea0a3e184c9057fdfd59d07d0ad0 |
| Sources/MacAppCatalog/ScanConfiguration.swift | 8a367754945da8a97f607a743f6d2e3cd6a0900a26c127dc9391bea7cc68eb82 |
| Sources/MacAppCatalog/URLNormalizer.swift | 2895ef9044fa3755a423430000ea3992de64bee4c7007cb0c6e2b556c193d9b0 |
| Sources/PagingPrototypeApp/AppCatalogAssembly.swift | d4e21001a6a432af90abaae5d479873eb51325be0ef7c93a4b538035f636993c |
| Sources/PagingPrototypeApp/ActivationComposition.swift | 75e02c448a5648d2fdd8ab2ff6599ee92b1c8845562452a436adcae519289a98 |
| Sources/PagingPrototypeApp/WallpaperBackdropProvider.swift | 63f4958112f158f66fd888853f369adb80077971d90008272f77cc6b94fe1a3a |
| Tests/PagingUITests/UITestProfileTests.swift | bb96845ec83fb5edf66f80115c7f248a79231b0203b0a74dad1d91a8b4dc9c39 |
| Tests/PagingUITests/UITestProfileAssemblyTests.swift | d5843d20dd879bed96588cbe42074c6a244392673826cfe69dc3577909441cf2 |
| Tests/PagingUITests/LauncherRuntimeServicesTests.swift | 6184bc00fed7c6345c29fc917d4eceff736206c2ca9ef60f771edddb4c73c9f8 |
| Tests/PagingUITests/WorkspacePersistenceQueueTests.swift | 1549074ecd843e4e9b4e8f56f64fa49fc7ab41c792dedd86512c415c4b66f386 |
| Tests/PagingUITests/FolderRenameAssemblyTests.swift | 77a6cf49c378e2d9edcd66ff71e0ce887cec673a1a1a0ed1434fe30d4a940ae1 |

Report checkpoint (UTC): 2026-10-13T10:46:20.869997+00:00.


## I1 repair inspection checkpoint — pending replacement freeze

The bounded no-follow contract repair is observed in current source:
`CatalogScanner.swift:144–148` rejects every symlink entry before target resolution
(`153–155`) or app classification. Generic directory descent can therefore no
longer reach the reported external alias when the default follow flag is false.
`ScanConfiguration.swift:23–26,37–45` is unchanged; explicit follow=true continues
to use the existing target/descent path. No new scanner policy/API was introduced.

`AppDelegate.swift:511–518,531` now shares `makeContentAssembly` between runtime
installation and the configured-profile test. It retains the profile Applications
root substitution and ordinary AppRuntimeFactory/real scanner selection. The
scope of the source repair matches I1; no additional implementation finding was
observed in these changes.

Two scanner regressions at `CatalogScannerTests.swift:98–116` use actual symlinks,
real metadata reading with a read recorder, and explicit follow=true preservation.
The new actual profile/datasource test at `UITestProfileAssemblyTests.swift:95–129`
adds an outside temporary synthetic app and repeats refresh; it asserts catalog
exclusion plus outside resolver exclusion/local resolver inclusion.

Existing `isolation-repair-r1.log` currently records **83 tests / 2 failures** at
19:51:07.729 JST. These are retained as evidence, not declared green:

- Reader test expected a lexical /var URL while scanner used canonical /private/var.
  Its recorded read list contains only the local fixture. Canonicalize the expected
  fixture URL without weakening the no-outside-reader assertion.
- Profile assembly test's expected local resolver URL was nil: direct provider
  receive/search commit bypassed refresh-controller presentation callback, which
  normally updates URLResolver (`AppCatalogAssembly.swift:435–440`). This explains
  the fixture failure, not an observed external read. The corrected fixture must
  disclose/cover the actual resolver update it intends to assert.

The prior **r1 frozen isolation FAIL** and packaged candidate remain historical.
I1's implementation fix is observed, but replacement frozen fingerprints and
corrected execution/build/candidate identity are still pending. This checkpoint
is not an authorization to launch the old candidate for writable GUI, nor a GUI
or runtime acceptance claim. Reviewer ran no tests/builds and edited only this
report. A final superseding source verdict will identify the new freeze explicitly.

Checkpoint time (UTC): 2026-10-13T10:53:19.025635+00:00.


## Final isolation repair rereview — source freeze r2

Date: 2026-10-13. This dated decision supersedes the **combined r1 isolation FAIL**
for the newly identified r2 source only. Earlier FAIL, failed fixture execution,
candidate identities and findings are retained above as historical evidence.

**Rename / durability: SOURCE PASS retained.**
**UI test profile isolation: SOURCE PASS — I1 closed in observed source.**
**Remaining actionable findings within this approved source scope: none.**

These are bounded source verdicts. They clear the independent source/isolation
review prerequisite for Main's approved synthetic-profile capture protocol; they
do not certify a GUI run, actual process restart, physical input/performance,
production global activation/login, full parity or distribution readiness.
The old r1 executable is not retrospectively approved by the new source verdict.

### r2 identity and verification evidence

- Freeze: `.build/verification/20261013/ui-profile/source-files-r2.sha256`.
- Actual count: **309 entries**. Reviewer independently hashed every recorded file
  and rechecked before writing: **309 matches, zero changed/missing**.
- Manifest SHA-256:
  `26bcf5f6e59128232b2bc6c83952d701379d9acfdb581aa9fd30214fe2244e6c`.
- Compared r1 and r2 manifests: exactly **four** recorded files changed, listed in
  the fingerprint table below. No other implementation/profile/runtime/queue/store
  input changed; all prior positive source checks remain applicable.
- Read Main's `isolation-repair-r2.log`: **50 tests / 0 failures**,
  2026-10-13 19:53:06.447 JST, 0.196 seconds wall duration.
- Read Main's `full-r2.log`: **1917 tests / 0 failures**,
  2026-10-13 19:54:07.779 JST, 30.485 seconds wall duration.
- Main is rebuilding Debug/Release and a unique R2 candidate. Its final candidate
  identity/hash and build evidence are separate pending delivery artifacts; the
  previous `a9f905...` combined-r1 executable is not the reviewed r2 repair binary.
- Reviewer did not execute tests/builds/GUI or launch/stop any application. Only
  this review document was updated. All review shell commands used `rtk`.

### Why I1 is closed

`Sources/MacAppCatalog/CatalogScanner.swift:144–148` now applies the documented
no-follow flag to **all** entries before target resolution (`153–155`) or `.app`
classification. Under default false, an ordinary directory symlink below synthetic
Applications therefore cannot reach descend, external metadata reading, the
containment-failure record fallback, or outside icon/launch resolver admission.
The gate is at the actual read/traversal boundary, not a post-read presentation
filter. Ordinary non-symlink nested fixture directories still use the existing
recursive path.

`ScanConfiguration.swift` is unchanged. No new configuration API/policy was added.
Explicit follow=true does not take the new skip branch and retains the original
symlink target/descent semantics; the bounded repair restores the existing false
contract rather than silently redefining the true setting.

`AppDelegate.swift:513–519` shares the real makeContentAssembly seam used by runtime
installation (`532`). It now explicitly returns nil if a profile was requested but
not configured (`514`); empty roots cannot fall back to ordinary catalog defaults
in that case. After successful configuration, omitted roots become profile-owned
Applications; explicit roots remain subject to the earlier canonical containment
validation. Preference/store/service bootstrap remains downstream of successful
profile configuration.

### Regression evidence and fixture corrections

`Tests/MacAppCatalogTests/CatalogScannerTests.swift:98–107` uses actual temporary
symlinks and a read recorder delegating to the real metadata reader. The record
list contains the local fixture only, and the complete observed reader-call list
contains only its canonical URL. Correcting /var versus /private/var in the expected
URL does not relax the assertion against any outside metadata read.

`CatalogScannerTests.swift:110–116` explicitly enables follow=true and retains the
expected external synthetic alias record, checking compatibility independently.
No real application directory or reference icon is needed for either fixture.

`Tests/PagingUITests/UITestProfileAssemblyTests.swift:95–128` configures a real
profile, constructs the same assembly seam as the runtime, performs a real datasource
refresh, and proves only the local synthetic record is present. Calling
`assembly.begin()` at 122 uses the actual cached-snapshot refresh-controller
presentation callback (`AppCatalogAssembly.swift:435–440`) to populate URLResolver.
The test asserts **local resolver present** and **outside resolver absent**, then
repeats real refresh and retains the single-record boundary. It neither manually
populates the resolver nor swaps in a fake scanner. The earlier nil-resolver fixture
failure is superseded by a genuine consumer-wiring assertion, not a weakened test.

`UITestProfileAssemblyTests.swift:131–133` also asserts that an unconfigured requested
profile cannot construct the ordinary catalog. The old failed 83/2 checkpoint remains
above; the new 50/0 and full 1917/0 evidence are tied to r2.

### Delivery handoff

Main may proceed with its already authorized normal test-instance GUI protocol
once the unique R2 candidate's build/hash/config match this repaired source and
the remaining protocol prerequisites are checked. Use explicit profile/windowed
arguments before starting the distinct test bundle; synthetic fixtures and their
fault directories remain the only writable test data. This source PASS does not
report any UI step as observed or authorize interaction with the resident instance.
No remaining source repair is requested within this reviewed bounded scope.

### r2 changed-file fingerprints

| File | SHA-256 |
| --- | --- |
| Sources/MacAppCatalog/CatalogScanner.swift | 52e3e40b1c38b976f3bb04362c3d44e137fcba0ef7f28bef48e76ea6dde77c69 |
| Sources/PagingPrototypeApp/AppDelegate.swift | 93474c3844a932838abf6b7fb7d91782fa09596932feb68cec081d63d214bd32 |
| Tests/MacAppCatalogTests/CatalogScannerTests.swift | 3d6ae13b8f8af18aef4ae4dddb683a24dfe464f053efab483db21edf069cb69c |
| Tests/PagingUITests/UITestProfileAssemblyTests.swift | e311e5694d6657aaba0964346b703997709e8bddbc375fe0c3f1a13580f8771d |

Unchanged ScanConfiguration fingerprint: `8a367754945da8a97f607a743f6d2e3cd6a0900a26c127dc9391bea7cc68eb82`.

Final r2 source-review check/write time (UTC): 2026-10-13T10:55:59.325915+00:00.


## Final superseding r2 source verdict and candidate identity

**Rename / durability: SOURCE PASS. UI test isolation: SOURCE PASS.**
No remaining actionable source finding in the approved combined scope. This
confirms the dated r2 repair review above and supersedes its pending-build/identity
status. It does not alter any historical r1 FAIL, fixture failure or candidate hash.

Reviewer read `ui-profile/debug-r2.log` and `release-package-r2.log`: Debug and
Release product builds complete, and unique R2 candidate assembly complete.
Reviewer independently rehashed every entry in `source-files-r2.sha256` after
these build artifacts were present: **309/309 matches; zero mismatches/missing**.
The r2 manifest SHA-256 remains
`26bcf5f6e59128232b2bc6c83952d701379d9acfdb581aa9fd30214fe2244e6c`.

Exact reviewed delivery candidate:

- App: `.build/candidates/folder-rename-ui-profile-rc-20261013-r2/LaunchcopyUITest.app`.
- Bundle identifier read from its Info.plist: `com.launchcopy.test.folderrename`.
- Executable: `Contents/MacOS/LaunchcopyUITest`.
- Executable SHA-256, independently read and hashed by reviewer, matching package
  log/Main:
  `fb20fab5fc993e4a8d5ea9f7ed8578f5aa6d1e63941e71444ca6425233ece4ed`.
- Repair focused evidence: **50/0** in `isolation-repair-r2.log`.
- Full evidence: **1917/0**, 19:54:07.779 JST, 30.485 seconds, in `full-r2.log`.

**GUI is still UNTESTED.** The above is source, existing execution/build evidence
and exact artifact identity verification. Reviewer did not build, run tests,
launch/stop any app or use GUI. Main may use only this R2 candidate for the already
approved explicit synthetic-profile protocol after checking its launch arguments
and remaining operational prerequisites; no old R1 candidate is covered. Actual
Quit/restart, visual/AX behavior, fault-dialog interaction, physical performance,
production activation/login and full parity remain separate acceptance gates.
Only this report was appended; earlier rename/isolation history is preserved.

Identity verification/report time (UTC): 2026-10-13T10:57:24.150670+00:00.
