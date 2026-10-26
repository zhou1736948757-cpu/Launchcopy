# Wrapped application metadata — independent bounded source review

Date: 2026-10-26  
Verdict: **SOURCE PASS**  
Actionable findings: **None within the two-path scope.**

## Authority and scope

Reviewed the established Swift/Foundation macOS catalog implementation against `AGENTS.md`, `/Users/mac/.codex/RTK.md`, the dated warning refinement in `Docs/LIBRARY_SEARCH_CONTINUITY_AND_PASSIVE_CARDS_2026-10-26.md`, and `Workflow/stage-summaries/2026-10-26-library-search-continuity.md`. The explicit maximum of three agents including Main and waiver of the old Chief/watchdog workflow apply. No agents were dispatched by this reviewer.

The verdict covers only:

- `Sources/MacAppCatalog/CatalogScanner.swift`, specifically the small `BundleMetadataReader` fallback.
- New `Tests/MacAppCatalogTests/BundleMetadataFallbackTests.swift`.

Selected existing failure/report, scan/cancellation, fixture, canonicalization, identity, repository and metadata-test sections were read only to resolve these contracts. The earlier Kepler R4 header/card verdict and sixteen UI deltas are separate; this review does not certify them.

## Frozen inputs and exact comparison

Parsed `.build/verification/20261026/library-search-continuity/source-inputs-r5.json`: **612 entries**. Its `source-delta-r5.json` lists **18 overall deltas**. Content hashes below matched both the R5 manifest and a second read immediately before writing this report. The other inputs were not independently hash-audited here.

| Reviewed path | SHA-256 |
| --- | --- |
| `Sources/MacAppCatalog/CatalogScanner.swift` | `10b66f741216e417457e1756680b10b71c671a0af7e2cd9905b7d944d1d759bc` |
| `Tests/MacAppCatalogTests/BundleMetadataFallbackTests.swift` | `494e13191346db5da768ac9455d9932d89016e8c5fbce6eae37f98b149c84c6f` |

Compared the scanner byte-for-byte with the authorized saved text at `.build/verification/20261026/library-search-continuity/baseline-files/Sources/MacAppCatalog/CatalogScanner.swift` (SHA-256 `141359764f015d248cbff56dc0fb88a93cc75a6ae7ba1ad2a29120fad4a4f80d`). There is one diff hunk, at the reader's former line 36 onward: the old early missing-file return and direct parse are replaced by a standard-first branch and the public Bundle fallback. Shared field extraction and the entire scanner below the reader are unchanged. No Git baseline or Git mutation was used.

The new test file is 125 lines and has no saved historical body at the corresponding baseline path. It was reviewed in full as new source; this report makes no historical test-body comparison claim.

## Source assessment

- **Standard metadata remains authoritative** (`CatalogScanner.swift:38-45`). If `Contents/Info.plist` exists, direct data/plist parsing still decides the result. Unreadable, malformed or nondictionary standard metadata returns `.corrupted`; no fallback bypasses that branch. Existing standard dictionaries retain their previous acceptance semantics.
- **Fallback admission is narrow** (`CatalogScanner.swift:46-52`). Only the missing-standard-file branch asks `Bundle(url: url)?.infoDictionary`, using the discovered outer URL. A nil, empty or non-`APPL` fallback dictionary returns `.missingInfoPlist`. The package-type requirement applies to this added branch, preserving the existing standard-path contract.
- **Field and identity semantics are preserved** (`CatalogScanner.swift:54-64`, `226-246`). Both branches use the same name, identifier, category, version and build extraction. Missing/empty identifiers still produce `.valid(identifier: nil, ...)`; the unchanged scanner counts `.missingBundleIdentifier` and creates canonical-URL fallback identity. Invalid and corrupt metadata still increment their genuine failure categories and remain excluded.
- **The outer app remains the record destination** (`CatalogScanner.swift:230-246`). Canonicalization uses the discovered outer bundle, independently of metadata lookup. No inner Bundle URL replaces it. Root traversal, symlink admission, cancellation, root priority, repository policy, sorting, schemas and saved organization have no changes in the scanner diff.
- **Security and threading remain bounded** (`CatalogScanner.swift:36-64`, `70-91`). The added operation requests public Foundation metadata; there is no executable-load call, principal-class lookup, custom Wrapper/WrappedBundle traversal, new error logging or counter suppression. The reader remains stateless and returns value metadata. The existing utility serial queue is unchanged; no Bundle/dictionary is retained or passed across the completion boundary. No concrete API-availability, actor-isolation or new shared-state defect was found in the inspected source.

The warning explanation is appropriately limited: the old reader's Contents-only lookup can reject an outer application whose metadata Foundation recognizes. The reported anonymous default-root observations support that explanation for the five measured candidates. This reviewer did not read those applications, independently reproduce the probe, capture the historical UI report, or establish whether any app can launch. Wrapper packaging recognition and live cache behavior remain Foundation/platform behavior, not a launchability guarantee.

## Tests and cache/fixture assessment

All eight new methods exercise actual reader/scanner behavior; no skips, mocked success results or genuine-failure assertion removals were found.

- Wrapped and flat positive cases, including optional fields, exercise the new branch (`BundleMetadataFallbackTests.swift:35-55`, `99-106`). The wrapper control explicitly requires Foundation recognition before reader assertions.
- Standard-priority and corrupt-standard controls coexist with a synthetically valid inner wrapped app (`58-79`). Empty and nonapplication cases must remain `.missingInfoPlist` (`82-96`).
- The scanner regression uses the real default scanner, requires a noncancelled result, zero discovery failures and exactly one record, then asserts the outer canonical URL and expected identity (`109-123`). It would fail if the wrapper were rejected or the record were redirected to the inner app.
- Existing scanner controls still assert missing-ID counting/canonical identity, corrupt exclusion and invalid exclusion (`CatalogScannerTests.swift:142-180`). These corroborate the unchanged result-to-report mapping rather than replacing real failures with a clean footer.

`FakeAppFactory.swift:20-27` creates a fresh UUID temporary root per instance. Every fixture is fully constructed before its first Bundle/reader lookup, and each test explicitly retains its factory through completion. The sole explicit Foundation pre-read is a positive recognition control, not a fixture mutation. Thus repeated synthetic identifiers do not reuse a fixture URL, no fixture depends on an earlier test's warmed URL, and no concrete cache-driven false positive was found. The corrupt/standard controls do not prewarm Bundle before writing their standard plist. Relative wrapper links are confined to the synthetic outer fixture; they add no production traversal implementation. Cache invalidation after a live app changes at the same URL was not independently exercised or certified by this source review.

## Main-owned completed logs, read only

The following are evidence reported by Main's completed runs, not execution by this reviewer:

| Evidence | Observed result |
| --- | --- |
| `metadata-before-r1.json` / `.log` | Exit 1; eight XCTest tests, six assertion failures. Wrapped, flat, missing-ID and scanner cases fail under the old reader; standard-priority, corrupt-standard, empty and nonapplication controls pass. |
| `focused-r5.json` / `.log` | Exit 0; **479 XCTest tests, zero failures**. The eight new fallback tests pass. Existing corrupt, invalid and missing-ID scanner controls also pass. |

Exact useful log locations: RED suite/result at `metadata-before-r1.log:12-40`; new green suite at `focused-r5.log:441-459`; existing genuine-failure controls at `603-626`; selected-run aggregate at `1160-1163`. The trailing separate Swift Testing runner reports zero tests; it is not used as evidence of a pass. The nonzero XCTest suite supplies the counts above. Source-to-built-binary provenance was not independently reproduced.

## Execution boundary and next gate

Reviewer activity consisted of source/text reads, scoped hash/diff inspection and writing this report. No implementation/test/other-document edits, builds, test runs, UI/native interaction, process/profile operations, app launches, Git mutation, or reference-project/evidence/assets reads were performed. Only this review file was intentionally written in the repository.

**SOURCE PASS is complete for the exact two R5 paths above.** It is not independent executable validation, a full-suite/package/native verdict, performance acceptance, historical-warning capture, application launch validation or full product parity. Main remains the sole execution owner for remaining full/build/package/native and anonymous aggregate-probe gates. This review does not wait for or presume those outcomes.
