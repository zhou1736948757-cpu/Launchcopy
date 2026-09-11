# T-1F-B-tests-actor — LayoutStoreActor 测试编写

Status: PASS (closed by Main after independent review; original Worker context-exhausted before verification)

## Plan
- Read the 5 allowed files (actor, store types, IO protocol, domain layout, mutation-tests pattern).
- Write `Tests/AppGridUITests/LayoutStoreActorTests.swift` covering the 13-point matrix (first launch, save-load-restart round trip, atomic replace, interrupted write, primary corrupt + backup valid, both corrupt, write failure → persistenceDegraded, coalescing latest-wins, flush barrier, reset, unknown future version never overwrites, multi-instance last-writer-wins, all temp roots).
- Use injected custom IO for failure simulation; each test gets its own temp dir (FileManager.temporaryDirectory + UUID), cleaned up at end.
- Run verification serially: `swift build -c debug`, `swift test`, `swift build -c release`.
- Update this file with test path, test count, verification outputs, Status: PASS.
