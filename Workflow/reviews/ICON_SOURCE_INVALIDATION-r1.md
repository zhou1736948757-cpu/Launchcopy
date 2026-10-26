# ICON_SOURCE_INVALIDATION — independent bounded review r1

2026-10-20. Reviewed final immutable **review-inputs-r2** against the named baselines; all six frozen/current input hashes match the manifest.

**Verdict: bounded production-source PASS; test-source FINDING [P2].** No remaining production correctness blocker found in this scope. Deterministic old-completion ordering is not fully gated by the tests.

## Finding

**[P2] A resumed old loader is not proof that its pipeline completion was processed.** `Tests/AppIconPipelineTests/IconSourceInvalidationTests.swift:96–105` calls `loader.finish(0)`, immediately adds another replacement consumer, then finishes load 1. The helper (`241–245` in r2) only resumes a continuation. Allowed trace: old continuation stays unscheduled → replacement finishes/delivers → old pipeline finish sees no replacement entry. Thus the test can pass without exercising the old loadID against a still-pending replacement. In the completed-replacement case (`130–138`), the 0.1-second inverted callback wait likewise does not acknowledge old finish processing before the cache probe; old completion could run only after shutdown. This is an evidence gap, not a demonstrated production failure.

Recommended solution: add an explicit acknowledgment after the pipeline finish ownership decision, outside locks. In the first case require old finish processing while replacement remains pending, then finish the replacement. In the second require old finish processing before probing the replacement cache. A loader-return expectation alone does not establish this boundary. Affected scope: the two non-cooperative-load regression gates. Regression risk: false PASS under scheduling that avoids the ownership conflict. Confidence: high from the continuation/control-flow trace; no mutation executed by this reviewer.

## Source assessment

- `IconPipeline.swift:312–335` removes every cached variant of affected identities and only their in-flight ownership/queued receipts. `finish` checks current loadID before cache insertion or listener removal, protecting replacement consumers/cache from old non-cooperative success. Unaffected identities remain intact.
- Cache-hit and finish receipt registration occur under the same lock as invalidation/admission. Invalidation therefore revokes accepted-but-not-admitted delivery, including the gap before its MainActor task is scheduled. UI callbacks run after unlocking. Receipt lifetime follows outstanding callbacks: admission, invalidation and shutdown remove them; there is no identity-history/tombstone accumulation. This is not a fixed queue-size claim.
- Consumer identity/state checks preserve pending cancellation and existing cancel-after-acceptance semantics; retired handles cannot cancel replacements. Shutdown clears queued receipts/cache/in-flight ownership and rejects new work. Already-admitted callbacks retain their linearization point; integrated MainActor commits/callbacks serialize.
- **Main-identified cancellation-handler liveness issue is resolved in r2:** invalidation first retires ownership/receipts under lock, then cancels collected tasks outside it. A synchronous loader cancellation handler can reenter stats/request without reacquiring an owned invalidation lock; any old completion after unlock still fails ownership. The new positive test (`169–192`) registers a real cancellation handler before its loader-start expectation, reenters `stats`, and checks retirement accounting. The helper's closed state prevents a continuation arriving after cleanup from leaking. Existing cancellation APIs were not widened or certified by this refinement.
- Resolver replacement/delta calculation is atomic and compares in-memory canonical URLs. Assembly uses `provider.servedSnapshot`, not a newer data-source head. Refresh synchronizes before forwarding (`AppCatalogAssembly.swift:589–593`); actual root-search wiring synchronizes before render (`AppDelegate.swift:1461–1465`); direct idle commit synchronizes before returning (`629–633`). Same-URL/name/revision updates preserve cache identity.

## Test boundaries and execution evidence

Refresh integration invokes production assembly forwarding and requests the icon inside its callback. Served/pending/head authority and committed remove/re-add are meaningfully separated. Queued-hit/finished-delivery cases explicitly observe a receipt while MainActor cannot execute the callback, then revoke it. Variant tests exercise two point sizes; scale/appearance coverage follows from the identity-based source loop, not dedicated cases. These two new files do not independently cover every consumer cancellation/shutdown case.

**Root-search integration is source-only by the final requested boundary.** The search test (`AppCatalogIconSourceTests.swift:140–154`) honestly supplies a mirrored synchronization call; deleting/reordering the actual AppDelegate call would not fail that test. It verifies assembly behavior, not production callback installation. This is an explicit accepted limitation, not independent root-wiring test evidence.

Main reports historical pipeline 5/0 and integration 6/0, plus an invalidation-disabled mutation yielding 2 tests / 10 assertion failures and exact restoration before r2 refinement. These are supplied results, not independently run/log-verified here. The mutation establishes selected tests depend on invalidation; it does not resolve the ordering finding. Final r2 contains six pipeline and six integration tests; Main's serial verification is next. No r2 execution PASS or warning-clean claim is made; the existing unrelated WeakMutability warning remains.

Only this report was written. No tests/build/UI/Git mutations/signals/native actions/reference/formal data operations; no additional agents, legacy Chef bypassed. No same-path refresh, NSWorkspace freshness, performance, native acceptance or full parity claim.

## SHA-256

Six reviewed inputs below identify both current files and their identical copies under `.build/verification/20261020/icon-source-invalidation/review-inputs-r2/`. Full-file AppDelegate hashing does not expand semantic review beyond its specified wiring.

```text
5ac90dbd4e6868f86fdc7537e24ebd1fb29a3df84d22594d0b666a409b8bafc5  Sources/AppIconPipeline/IconPipeline.swift
7070bdacc45f5d9f7067e2ae6f5a4afd797327b8dad03a3012d6e43e2879f6b7  Sources/PagingPrototypeApp/AppCatalogAssembly.swift
89664d880eb7861aedb8e739d49883db4fedc8cf59acf3c1db764934820bc802  Sources/PagingPrototypeApp/AppDelegate.swift
f0e5b3cfb60735e76315de307fdbae403d2ac4ba2d7073d13e06cbcbc09c6d95  Tests/AppIconPipelineTests/IconSourceInvalidationTests.swift
721b59ad0682c19711e5719be0fcc858dbb632ee1016d4ac9d34342a6b986e56  Tests/PagingUITests/AppCatalogIconSourceTests.swift
00056c8274bb4df3217d3428e5d1b5fedd0d3eff6385062882f0567b3e0613e1  Docs/ICON_SOURCE_INVALIDATION_SPEC.md
00b2ac0f7f49791ed260c6fc49e3e6fed010433feeb8bbf6c8d38ff0707b0546  .build/verification/20261020/icon-source-invalidation/IconPipeline.baseline.swift
3647b449bc573f607ab369f3864c0f00a0f9ebf4afaee7c0d3c7f081ca7ea862  .build/verification/20261020/icon-source-invalidation/AppCatalogAssembly.baseline.swift
895e9af3ab43d945ae6106884f54b83eb22d2b96faa9a9bfe7fff0158c2a393e  .build/verification/20261020/icon-source-invalidation/AppDelegate.baseline.swift
c1b2f760e9946bdf62739c7963d10ed7fec00133aef2ad89e108d139800c902a  .build/verification/20261020/icon-source-invalidation/review-inputs-r2.json
```
