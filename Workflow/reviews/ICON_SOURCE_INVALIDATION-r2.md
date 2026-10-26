# ICON_SOURCE_INVALIDATION — r2 follow-up

2026-10-20. **Bounded source/test-source PASS; r1 P2 ordering finding CLOSED.** Reviewed only the r2-to-r3 counter/test/specification changes and verified the six current files byte-for-byte against immutable `review-inputs-r3` and its manifest. No new actionable finding.

`IconPipeline.swift` increments a scalar `processedLoadResults` inside the existing finish lock, before the ownership guard; the internal read-only getter takes that same lock. Observing the increment therefore establishes that the prior ownership decision has completed and released the lock, including stale-result rejection. It does not assert callback enqueueing or execution. Wrapping increment adds no policy, callbacks, identity history or mapping/retirement changes.

`IconSourceInvalidationTests.swift:97` now waits for one processed result while the replacement decoder remains gated. Only then does it attach another replacement listener and release the replacement. At line 132, the completed-replacement case waits for two processed results before probing cache. Each test owns an isolated pipeline with exactly those controlled completions; the count cannot be supplied by unrelated work. The helper holds MainActor, observes positive lock-protected state, and fails explicitly on its bounded timeout. Polling delay and inverted callback waits are no longer the evidence for finish ordering. These gates close the exact scheduler-dependent gap identified in r1.

Main reports the new 12-test GREEN and a selected mutation removing only the finish loadID comparison: 1 test / 4 assertion failures, 0 unexpected failures, with old finish positively acknowledged. This is discriminating evidence for an old result consuming pending replacement listeners/cache, rather than merely disabling invalidation. These execution results and mutation logs are Main-owned, not executed or independently log-verified by this reviewer. After Main's restoration notice, current pipeline SHA-256 was independently confirmed against r3 below. Main's final focused/full/Debug/Release-package verification is running; this report does not preempt its result.

All other r1 boundaries remain: root-search wiring is source-only, its mirrored test is honestly limited to assembly behavior; ordinary pre-existing cancellation APIs are not certified. No same-path refresh, native/UI/performance, warning-clean or full parity claim. Only this follow-up report was written; no tests/build/UI/Git mutations/signals/reference/formal data operations or additional agents.

## Final SHA-256

Frozen root: `.build/verification/20261020/icon-source-invalidation/review-inputs-r3/`. Each of the six input hashes matches both frozen and restored current files.

```text
b119be2397fb120d1472414d1ab0062c85813884f6994232d471b033d66d2c85  Sources/AppIconPipeline/IconPipeline.swift
7070bdacc45f5d9f7067e2ae6f5a4afd797327b8dad03a3012d6e43e2879f6b7  Sources/PagingPrototypeApp/AppCatalogAssembly.swift
89664d880eb7861aedb8e739d49883db4fedc8cf59acf3c1db764934820bc802  Sources/PagingPrototypeApp/AppDelegate.swift
e2bbfee5b3d212cb2e698a4d977687d5f3d71f9a970e31dc8f9d664f5e3f380a  Tests/AppIconPipelineTests/IconSourceInvalidationTests.swift
721b59ad0682c19711e5719be0fcc858dbb632ee1016d4ac9d34342a6b986e56  Tests/PagingUITests/AppCatalogIconSourceTests.swift
02e1d353104107d4b3337bed351181ca2c0315cc7dde2360e8873e785cb7756b  Docs/ICON_SOURCE_INVALIDATION_SPEC.md
521d5e924713c74d096dc1fef1973fd495f0531bc4e879815df6b1c11d1670e4  .build/verification/20261020/icon-source-invalidation/review-inputs-r3.json
```
