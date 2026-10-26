# Wallpaper loading: independent bounded source review

Date: 2026-10-15

## Verdict and authority

**ACCEPT_WITH_NON_BLOCKING_NOTES — bounded source/test-control review only.** No blocking defect found in the new controls against the inspected provider/controller. This is not full-product PASS, an independent test execution, a performance certification, or real-wallpaper acceptance. Wallpaper remains **NOT_FIXED / PARTIAL_STAGE_LOCALIZED**; the source-open cause remains unproven. No production repair is proposed or authorized by this review.

The inspected implementation is an AppKit main-actor controller using a background CGImage loader and an ImageIO/Core Image provider with condition-based same-key coordination, bounded memory caching, and asynchronous disk writes. Source inspection was confined to `Tests/PagingUITests/WallpaperBackdropPipelineTests.swift`, `Sources/PagingPrototypeApp/WallpaperBackdropProvider.swift`, and the controller in `Sources/PagingPrototypeApp/WallpaperBackdropView.swift`. Also read the assigned stage summary, diagnosis, project instructions, and the eight named evidence artifacts. Existing test sources and unrelated implementation were not reviewed. The human's report-only/no-other-agents assignment governs this slice.

No tests, Swift commands, builds, packaging, UI operations, reference-source access, raw-image access, raw-sample access, process actions, or agent dispatch were performed. Main's concurrent full suite is outside this verdict.

## Findings

### F1 — P3: qualify the diagnostic opening as an observation of sampled intervals

**Location:** `Workflow/results/WALLPAPER_LOADING_DIAGNOSIS.md:4`, interpreted with lines 9–13.

The opening says the observed long loading state “is blocked before image decode/render/compositing.” The retained evidence supports the narrower statement that, in both grouped sampling windows, one wallpaper worker was observed in the source-open call within `decodeThumbnail`, and another was waiting in provider coordination. It does not establish uninterrupted residence throughout the entire loading interval, a specific kernel reason, or the absence of every other decode/render operation. The later paragraph already states the appropriate limitations, so this is a non-blocking wording issue, not rejection of stage localization.

Recommended wording for Main's consideration: “During both grouped sampling windows, the observed wallpaper worker remained in ImageIO source-open, before the provider's thumbnail-return/render path completed; the reason for the open wait remains unresolved.” No diagnosis edits were made here. Confidence: high for the wording limitation; underlying trace collection/parser fidelity was not independently re-executed.

### F2 — P3: equal-image reuse does not discriminate obsolete-generation installation

**Location:** `Tests/PagingUITests/WallpaperBackdropPipelineTests.swift:115–147`; `WallpaperBackdropView.swift:201–205`.

The repeated-request control correctly captures submission order independently of completion order, waits for two initial deliveries, and checks identical provider CGImage objects and a warm refresh. Because both generations return the same image, removing the controller's generation guard could still satisfy these new assertions: an early obsolete delivery could install the same image and emit the sole initial ready transition. This limits the control's coverage; it does not invalidate its stated same-key reuse purpose. The inspected controller does contain the generation/host guard. Do not treat this new test alone as proof of stale-generation rejection. A distinct-result, controlled-order test would be the appropriate discriminator if that claim were needed; no additional test is requested for this bounded slice. Confidence: high from the assertions and controller branch.

No P0, P1, or P2 finding is raised for this review scope.

## Test correctness and evidence

- **Corrected image assertions are appropriate.** Lines 168–175 derive expected reduced pixel dimensions from the actual submitted request and compare the returned CGImage itself. This matches provider render sizing (`WallpaperBackdropProvider.swift:124–125,142–144`). Lines 177–185 require an installed valid image with representations, logical size equal to the request, visibility, and full alpha; this matches `NSImage(cgImage:size:)` in the controller. No NSBitmapImageRep subtype requirement or wrapper-pixel equality remains. These assertions establish shape and installation state, not pixel-content fidelity, blur aesthetics, compositor output, or a screen-visible result.
- **Cold-path control is meaningful.** A unique authored PNG and absent per-test cache directory precede refresh. The real background-loader adapter runs the provider. The semaphore holds the scheduling boundary, allowing a main-queue heartbeat to verify loading/no installed image before releasing real work. Main-actor request/result/state capture and main-queue completion are consistent with the controller contract. The heartbeat proves responsiveness at this held boundary, not continuous responsiveness during every ImageIO/Core Image operation.
- **Reuse control is meaningful within its stated limit.** The two refresh submissions occur before main-queue delivery; provider work may overlap or run sequentially. Identity and cache-count assertions support shared memory-image reuse, including a subsequent warm refresh. There is no forced in-flight overlap, count of actual decodes/renders, fresh-provider disk reload, or disk-persistence assertion. The diagnosis correctly avoids those claims.
- **Execution is supplied evidence only.** `focused-r3.log` records 9 controller + 2 pipeline + 5 provider XCTest cases, 16 total / 0 failures, with the two new tests rendering 1029×669 for request geometry 1470×956 at scale 2. The trailing separate Swift Testing message reports zero tests and does not replace the real 16-case XCTest result. No independent execution or full-suite result is claimed. Earlier failed harness runs were described by Main but were not among the logs inspected here.

## Liveness and resource bounds

The cold test's semaphore wait has a 15-second deadline and a deferred release. Each expectation wait is also bounded to 15 seconds. This avoids an unbounded test-authored semaphore wait, including the synchronous-loader regression described in the comment. These are separate waits, not one global 15-second test deadline or a speed target.

The real provider remains synchronous on worker threads: its condition wait (`WallpaperBackdropProvider.swift:63–79`) has no deadline, and ImageIO source-open/thumbnail/render calls have no cancellation mechanism in this source. XCTest expectation timeout does not terminate those operations or drain asynchronous disk writes. Controller generations reject obsolete deliveries but do not cancel their workers. Thus no hard bound on underlying blocked-worker lifetime or global production concurrency is established. This is existing behavior, not a production change from the new tests; the diagnosis's warning against a blind UI timeout is justified.

Per invocation, the new controls submit one cold load and three reuse-test loads, with one provider/cache namespace per test and authored 8×8 PNG inputs. Provider memory retention is capped at six images / 48 MiB (`105–116`), not total transient rendering memory or disk usage. Rendering follows the actual main screen (`WallpaperBackdropView.swift:176–182`), so the 160×100 host is not a fixed render-resource cap. Very large requests can evict even a newly rendered image under the byte policy; cache-count/identity assertions therefore assume an image that fits that policy. Current focused evidence satisfies that assumption; universal display-configuration portability is not established.

Fixtures use UUID directories and deliberately remain under `.build/verification/20261015/wallpaper-pipeline-fixtures`. Work is finite per run, but repeated runs accumulate authored fixtures/cache files; there is no suite-wide disk-retention bound. Async writes can outlive test completion. The review neither deleted artifacts nor inspected their image contents.

## Diagnostic evidence assessment

`sample-02-sanitized.json` and `sample-03-active-sanitized.json` both identify PID 96238 and report 177 observations for each retained relevant frame: `backgroundLoader` / `blurredWallpaper` / condition wait on one thread, and `decodeThumbnail` / `CGImageSourceCreateWithURL` / `CGImageReadCreateWithURL` / `open` / `__open` on another. Provider source places source creation at line 131, thumbnail decoding at line 137, and rendering later at lines 90–95. The condition waiter is consistent with an in-flight same-key request, but sanitized frames contain no key identity tying it uniquely to the other sampled worker. Counts on nested frames must not be added as independent events, converted into a continuous long-duration measurement, or interpreted as 177 requests. The discarded broad first sample is not used for the conclusion.

The main/event-thread `mach_msg2_trap` token is compatible with an idle event loop; by itself it does not prove responsiveness. `native-results.json` separately records loading before/after Settings activation, observed black backdrop, no ready state, normal Quit and exact-process absence. Those are Main's recorded observations, not independently repeated UI/process verification. The supplied records support continuing NOT_FIXED and argue against patching the compositor based on this observation alone. They do not exclude every possible later rendering problem. No native query was issued by this reviewer.

`metadata-probe.json` reports a separately resolved main-screen source with regular/nonempty/local/read-access properties; `source-class-probe.json` reports PNG/Downloads/not-symlink. Neither establishes URL identity with the sampled app request, effective access for the app, successful content open, or known cloud/download state. The diagnosis explicitly preserves those distinctions.

`tcc-request-summary.json` correlates an AllFiles context, own-PID attribution, own-bundle subject and result authValue 0 / authReason 5 under one request ID. Individual records do not all contain every attribution/service flag. This supports reporting the correlated request/result only. It does not establish Downloads-folder denial, the necessity of Full Disk Access, or that TCC caused the sampled open wait. No symbolic interpretation of authReason 5 was independently verified. Missing entries in this bounded query are not negative proof. The diagnosis's explicit TCC caveats are appropriate; no permission change follows from this review.

Sanitized artifacts record that raw samples were not retained; their contents inspected here contain no raw personal wallpaper URL/image. Collection duration, interval, sanitization implementation, raw disposal and historical interactions are provenance supplied by Main, not independently audited by this source-only review.

## Input integrity and exact edits

Read-only SHA-256 verification matched **455/455** current files against `source-inputs-final.json`, with zero missing files and zero mismatches, repeated immediately before report creation. This includes all 454 other manifest entries and the one new pipeline test. Historical “prior 454 unchanged” is Main's baseline statement: the supplied final manifest proves current agreement with that freeze, not an independently compared earlier 454-entry manifest or completeness of all possible build inputs.

- Final manifest SHA-256: `2ab1e65f615b365fa5d9869cfa2ee73c47d21f2cab3d5a9fa798a85d3eb34d7b`.
- Reviewed new test SHA-256: `dd3332da203047942d1760d52a2e88ae70ae6915f778faf6df59fea436b1e5e9`.
- The candidate executable SHA-256 is recorded in `native-results.json`; its binary was not independently opened or rehashed in this review.

Evidence artifact SHA-256 values at inspection:

| Artifact | SHA-256 |
| --- | --- |
| sample-02-sanitized.json | 34d1f39b69d68dd50cfe9a3c6ae7e76c86c3b82d9f26cbc00a18dc325372c26e |
| sample-03-active-sanitized.json | 4544ddb7bba06a6bd80416e3795265cd12acc07153d358e3152552cc3cab3c36 |
| metadata-probe.json | 5ad3b33a904b7931122c08810ab9015ac441888163c07035f2defb40c134f2e7 |
| source-class-probe.json | e800dff73b798ff46e4d4e70b9ade58fc31aea13f01c82851744be2bda53930d |
| tcc-request-summary.json | ccc48e4296db0ebc6fba86bb9d0a3013cf955fa5bce455b0c5ef0b6987dd0f43 |
| native-results.json | 6dcf11979a4eccc4477c02ff6fa48dec1975788ffa07177f3eb242b0b08bc635 |
| focused-r3.log | 3c7e94140dec829e94f616f3f9c1282e33fd42cd77aecfea4997e437f597a632 |

**Exact edit:** created only `Workflow/results/WALLPAPER_LOADING_SOURCE_REVIEW.md` (this report). No implementation, test, diagnosis, stage summary, other documentation, or workflow-state file was edited. Remaining full-suite verification and real-source/product gates belong to Main.
