# Icon Load Replacement Source Review

Date: 2026-10-17
Verdict: **PASS — bounded source review; no actionable regression found in the reviewed change.**

## Scope and baseline

Reviewed `Sources/AppIconPipeline/IconPipeline.swift` against `.build/verification/20261017/icon-load-replacement/IconPipeline.before.txt`, and the new `Tests/AppIconPipelineTests/IconPipelineReplacementTests.swift`. Supporting reads were limited to Consumer/handle/cancel/shutdown/delivery, the semaphore, cache and loader contracts, and relevant existing cancellation/shutdown/merge test helpers. This is existing Swift/AppKit correctness maintenance. The user waived the Chief workflow; no agents were dispatched.

Read `RTK.md`, applicable `AGENTS.md`, and `Workflow/stage-summaries/2026-10-17-icon-load-replacement.md`. The shared dirty checkout is not a clean Git baseline. Comparing the supplied manifests gives 465 prior inputs, 466 frozen inputs, 464 unchanged, exactly one changed production file and one added test file, with no removals. Both reviewed current files match the freeze; this does not independently rehash or audit every other input.

## Findings and reasoning

No blocking findings.

- **Current-load ownership:** Each newly admitted load captures its own private UUID while the pipeline lock also publishes its entry (lines 246–251). Even an immediately completing task must acquire that lock before finishing. A removed or replaced load cannot pass `finish`'s key/UUID/shutdown guard (lines 364–387), regardless of whether its loader honors cancellation.
- **Cache atomicity:** Entry validation, removal, successful cache insertion/eviction accounting, and consumer delivery selection now share one pipeline lock. Request, cancellation, purge and shutdown cannot observe a gap between those operations. Both old-before-new and old-after-new success results are discarded when their entry is no longer current. Failed results use the same identity guard and never insert cache entries; the cancellation-error early return remains intact.
- **Cancellation and delivery:** Last-consumer cancellation and cancelAll still remove/cancel their entry under the pipeline lock. Consumer state arbitration remains unchanged; cancelling one merged consumer retains the others, and delivery already selected remains the winner over later cancellation. Consumer cancellation releases its state lock before acquiring the pipeline lock, so this patch introduces no inverse lock nesting. Callbacks remain outside the pipeline lock, on MainActor, with each consumer's own generation and the existing final shutdown check.
- **Shutdown and scope:** Shutdown serializes cache clearing and entry removal with finish; a later old success cannot restore cache state. The semaphore still encloses the loader and releases permits on success/error. Public APIs, cache limits/LRU/cost calculation, concurrency limits, image capping, UI requests, frame/physics and storage are unchanged. There is no new page-owned cancellation policy.

## Tests and inspected Main evidence

All paths below are under `.build/verification/20261017/icon-load-replacement/`. No tests, builds, packaging, UI or process actions were run by this reviewer.

| Main log | Observed evidence |
| --- | --- |
| `red.log:13–28` | Two executed regression methods, six assertion failures: old success consumed the pending replacement and populated its cache; late cancelAll success overwrote fresh cache. No loader-admission timeout appeared. |
| `focused-r1.log:185–211` | Both regressions pass; 45 tests, zero failures, 4.911 seconds. Predates fixture cleanup hardening. |
| `focused-r2.log:105–131` | Both regressions pass after the closed-flag change; 45 tests, zero failures, 4.792 seconds. |
| `full-r1.log` terminal summary | 2,814 tests, zero failures, 53.047 seconds. Both regression methods also passed in this run. |
| `debug-r1.log` | Product build reports completion, 0.33 seconds. |
| `package-r1.log` (initial inspection) | Release compilation was still in progress. Superseded by the final update below. |

The appended Swift Testing zero-test footer is not the XCTest execution count.

The fixture registers ordinal continuations before announcing admission, deliberately ignores task cancellation, and distinguishes old/fresh in-memory image identity. Its lock-protected closed flag prevents cleanup from stranding later registrations; continuation removal/resumption avoids double resume. Existing focused tests cover surviving merged consumers, generations, limits, cache and shutdown.

**Evidence limits:** Resuming an old loader is not an acknowledgement that pipeline finish has run. The 0.2-second inverted waits and later assertions depend on scheduling; especially the cache-overwrite test can miss an old completion delayed until after its cache assertion/teardown. These tests reproduce the bug empirically and support the repair, but do not exhaust interleavings or independently prove non-cooperative shutdown completion behavior. Source lock/identity reasoning supplies the ownership argument. The unchanged MainActor shutdown check is not a proof of every concurrent shutdown/callback interleaving. No performance, hitch-causality, native UI, physical-input or new candidate acceptance claim follows.

## SHA-256 receipt

| Input | SHA-256 |
| --- | --- |
| `IconPipeline.before.txt` | `dac4ff8151434e32eba5348a618aa704e39a7f0ef38b32f2f3ea3fc17798575e` |
| `source-inputs-r1.json` | `c9f3746f9c8c941cafcafd08c5e93079f5033a9233ec65cde319dc23975919db` |
| Current `Sources/AppIconPipeline/IconPipeline.swift` | `00b2ac0f7f49791ed260c6fc49e3e6fed010433feeb8bbf6c8d38ff0707b0546` |
| Current `Tests/AppIconPipelineTests/IconPipelineReplacementTests.swift` | `0a8827b4ce754a2bbf8eea9c638f0b57b0e8a4f644f3520eee875089df5274ab` |
| `focused-r2.log` | `9958212cf3082165cdaa1859cb89e8d052513a46b34572f35d61e3949617cf93` |
| Completed `full-r1.log` | `47dab5f406c131fb8263826c3f1f895135368bc0a63650cf985ee5f1499e692d` |

The saved production baseline also matches its source-before manifest hash. This verdict is bound to the two current source hashes above. Main retains stage-summary updates and stage closeout. Accepted folder experience is not reopened; main-grid capacity remains explicitly pending. The previously reported running candidate `39484896` was not inspected or altered and is not evidence of native acceptance for this patch.

Reviewer write scope: this report only; no implementation, tests, shared stage summary, evidence or repository state was modified.

## Final evidence update — 2026-10-17

The completed `package-r1.log` supersedes the initial pending package observation: actual Release product build completed in 22.46 seconds; the candidate was assembled, the native-test-entry static check was accepted, and the packaged localization probe verified 290 required keys/signatures across three languages. Main additionally reports a passing diff check; the reviewer did not rerun it. Focused r2 remains 45/0 (4.792 seconds), full remains 2,814/0 (53.047 seconds), and Debug remains 0.33 seconds.

The package log records candidate `.build/candidates/icon-load-replacement-rc-20261017-r1/LaunchcopyUITest.app` and executable SHA-256 `929e7616311a5f7af3dbcecad44cc7b2f341049cbf282ab7414e0159d613b3d1`. This is a logged executable hash, not an independently recomputed app-bundle hash. Main explicitly reports the candidate has **not been launched** and the current `39484896` instance is unchanged. Static package acceptance does not establish a new native runtime PASS.

The reviewer rehashed both reviewed source/test files after the final handoff: both still match `source-inputs-r1.json` and the receipt above. No source drift was observed in this bounded scope. Final verdict remains **PASS for the reviewed private ownership repair**, with the timing and runtime evidence limits unchanged. No additional files were written.
