# Concurrency decision — frame hitch wave

- Planned Workers: 2
- Worker A owns only PagingUI recorder implementation/tests.
- Worker B owns only Python analyzer/docs/tests.
- Write sets do not overlap; SwiftPM verification is serialized by Main after both return.
- Quality rationale: repair removes observer self-contamination while analyzer makes the evidence pipeline repeatable; neither depends on the other's implementation to begin.
- Reviewer wave will be independent and read-only before Main accepts either task.
