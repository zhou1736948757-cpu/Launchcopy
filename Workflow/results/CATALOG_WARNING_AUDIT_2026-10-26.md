# Bounded catalog warning audit — 2026-10-26

## Scope and conclusion

Source-only investigation for the current Library/search stage. Read project instructions, the warning contract, and `Workflow/stage-summaries/2026-10-26-library-search-continuity.md:3-10`. The old orchestration workflow is waived; no additional agents were started.

**The current preview's failure categories remain unknown.** The warning is consistent with discovery failures or an unsuccessful refresh; its text does not identify a cause. No classification correction is objectively established. Only this report was written. No catalog scan, build, test, GUI operation, process control, preference/profile read/write, Git mutation, reference material, or media/evidence access was performed. The only live filesystem checks were boolean probes of the four fixed default application roots. Source pointers below refer to the inspected checkout, not a verified match to the running preview binary.

## Warning composition

- `Sources/MacAppCatalog/ScanFailure.swift:14-24,36-56`: five categories; `failureCount` includes all, but only `missingBundleIdentifier` contributes to `nonBlockingFailureCount`. `discoveryFailureCount = failureCount - nonBlockingFailureCount`; negative supplied counts are clamped and totals saturate.
- `Sources/PagingPrototypeApp/AppCatalogAssembly.swift:138-167`: the adapter forwards success/cancellation and total/nonblocking counts. The per-kind dictionary is **not** exposed in `AppGridRefreshOutcome` (`Sources/AppGridUI/AppGridDataSource.swift:31-54`).
- `Sources/AppGridUI/AppGridRefreshController.swift:138-153`: a noncancelled outcome becomes `.partialFailure` when `!succeeded || discoveryFailureCount > 0`. Cancellation restores the previous state, potentially retaining an earlier warning. A completed successful refresh with zero discovery failures becomes ready/empty.
- `Sources/PagingPrototypeApp/CatalogStatusPresentation.swift:5-15` preserves partial failure ahead of empty/search results. `AppDelegate.swift:267-274,301-318` supplies this status and compact footer placement. `Sources/AppGridUI/AppGridStatusView.swift:135-158` renders its warning glyph/text; the Chinese text maps to `catalog.partialFailure` in `Sources/LauncherLocalization/Resources/zh-Hans.lproj/Localizable.strings:244`.
- Whole-refresh failure can occur even with zero category counts: repository construction failure retains the old snapshot and returns a nil result snapshot (`Sources/MacAppCatalog/CatalogRepository.swift:92-111`). Thus anonymous category counts alone do not prove that every warning came from the scanner.

## Exact scanner classifications

| Category | Actual trigger and warning relevance | Source |
| --- | --- | --- |
| `unreadableDirectory` | Any thrown `contentsOfDirectory` error, for a retained root or descendant. Missing directories, access denial and other enumeration errors are merged; no error-code or root/descendant distinction survives. Discovery failure. | `Sources/MacAppCatalog/CatalogScanner.swift:134-145` |
| `invalidAppBundle` | A discovered entry with extension exactly `app` has no observable `Contents/Info.plist` according to `fileExists`. Candidate selection does not require `isDirectory == true`, so a non-directory ending in `.app` can qualify. This classification is not proof of why the plist is unobservable. No record is added; discovery failure. | `CatalogScanner.swift:38-42,162-176,221-226` in the same directory |
| `corruptedBundle` | Plist is observable but data cannot be read, cannot be parsed, or is not a dictionary. No record is added; discovery failure. | `CatalogScanner.swift:38-43,225-226` |
| `missingBundleIdentifier` | Parsed dictionary has an absent, non-string or empty identifier. The app is still recorded using canonical-URL fallback identity. **Cannot alone trigger this warning.** Missing name uses a filename fallback; missing category/version/build produces no failure category. | `CatalogScanner.swift:44-53,227-237` |
| `symlinkCycleDetected` | Descent resolves to an ancestor already on the current traversal chain. Discovery failure. Normally zero with the default no-follow policy; a previously visited non-ancestor is merely skipped. | `CatalogScanner.swift:149-160,196-205` |

Default configuration is overlapping-root deduplication **on**, directory-symlink following **off**, and stopping at every `.app` candidate **on** (`Sources/MacAppCatalog/ScanConfiguration.swift:17-41`). Consequently:

- Invalid `.app` entries reached through ordinary subdirectories can produce persistent warnings. Embedded helper apps inside an encountered `.app` are not visited by default, even if the outer bundle is invalid (`CatalogScanner.swift:164-182`).
- Recognized symlink entries are skipped before bundle processing. Explicit roots are nevertheless resolved before traversal (`CatalogScanner.swift:103-113,149-160`). A cycle is a supported category, not an established current cause.
- Missing a **retained** default root would count as `unreadableDirectory`; there is no optional-root flag or default-versus-explicit origin in `ScanConfiguration`. The overlapping system-utilities root is removed by default deduplication, so its absence alone under an available parent need not cause a failure (`CatalogRoots.swift:23-28`; `CatalogScanner.swift:95-98,245-254`).
- Ordinary fixed roots are retained by root admission even when unavailable; custom-root admission has separate rejection categories that are not scanner categories (`Sources/PagingPrototypeApp/AppSourceRootAdmission.swift:21-32,249-270`; adapter consumes only accepted roots at `AppCatalogAssembly.swift:144-150`). Do not reinterpret a rejected custom source as a specific footer category.
- Entry resource-value failures are swallowed by `try?` rather than separately counted (`CatalogScanner.swift:149-160`); this report is not an exhaustive filesystem-health diagnosis.

## Permitted live root preflight

Only existence, directory type, read access and search access were checked; no directory contents or app inventory were enumerated.

| Anonymous root kind | Exists | Directory | Readable | Searchable |
| --- | --- | --- | --- | --- |
| sharedApplications | true | true | true | true |
| systemApplications | true | true | true | true |
| systemUtilities | true | true | true | true |
| userApplications | true | true | true | true |

These are current worker-process boolean observations. They do not prove enumeration success, descendant readability, plist validity, the preview's effective configuration, or the status of its last accepted refresh. No missing default root was observed by this preflight.

## Minimal standalone diagnostic for Main — proposed, not executed

Use the existing Foundation-only `AppCatalogCore` + `MacAppCatalog` modules. Do not instantiate the app assembly, settings stores, watcher, icon pipeline, or any AppKit application. This single-refresh helper preserves repository success semantics and emits only fixed category labels, integers and booleans:

```swift
import AppCatalogCore
import MacAppCatalog

@main
enum AnonymousCatalogProbe {
    static func main() async {
        let repository = CatalogRepository(policy: .init(), scanning: CatalogScanner())
        let result = await repository.refresh(configuration: ScanConfiguration())
        let report = result.report
        print("cancelled=\(result.cancelled)")
        print("coalesced=\(result.coalesced)")
        print("snapshotAvailable=\(result.snapshot != nil)")
        for kind in ScanFailureKind.allCases {
            print("\(kind.rawValue)=\(report.failureCounts[kind] ?? 0)")
        }
        print("failureCount=\(report.failureCount)")
        print("nonBlockingFailureCount=\(report.nonBlockingFailureCount)")
        print("discoveryFailureCount=\(report.discoveryFailureCount)")
    }
}
```

Public APIs: `CatalogScanner.init()/scan(configuration:revision:completion:)` (`CatalogScanner.swift:64-83`), `CatalogScanning.scan` / `CatalogScanResult` (`CatalogScanning.swift:13-37`), `ScanConfiguration.init()` (`ScanConfiguration.swift:37-47`), `CatalogRevision.init(_:)` (`Sources/AppCatalogCore/AppCatalogCore.swift:98-103`), `CatalogRepository.init(policy:scanning:)/refresh(configuration:)` and actor-isolated `lastReport` (`CatalogRepository.swift:46-61`), and the public report/category fields (`ScanFailure.swift:14-63`). A direct callback scan with `CatalogRevision(1)` is also possible; it omits repository-build failure detection.

Compilation/linking is **source-feasible, unverified here**: `Package.swift:1,10-13,36-43` specifies Swift tools 5.9, macOS 14+, and the two targets; neither imports AppKit. There is no explicit library product or probe executable. Do not assume a reusable `-lMacAppCatalog` exists in build output. Main can create the helper only in an owned scratch directory and compile two temporary libraries, then the executable, serially. For an arm64 host, the following illustrates complete module/link inputs; `probeDir` must be an existing scratch directory containing the helper source:

```sh
rtk proxy xcrun swiftc -swift-version 5 -target arm64-apple-macosx14.0 -parse-as-library -emit-library -emit-module -module-name AppCatalogCore -module-cache-path "${probeDir:?}/ModuleCache" -emit-module-path "$probeDir/AppCatalogCore.swiftmodule" Sources/AppCatalogCore/*.swift -o "$probeDir/libAppCatalogCore.dylib"
rtk proxy xcrun swiftc -swift-version 5 -target arm64-apple-macosx14.0 -parse-as-library -emit-library -emit-module -module-name MacAppCatalog -module-cache-path "${probeDir:?}/ModuleCache" -emit-module-path "$probeDir/MacAppCatalog.swiftmodule" -I "$probeDir" -L "$probeDir" -lAppCatalogCore Sources/MacAppCatalog/*.swift -o "$probeDir/libMacAppCatalog.dylib"
rtk proxy xcrun swiftc -swift-version 5 -target arm64-apple-macosx14.0 -parse-as-library -module-cache-path "${probeDir:?}/ModuleCache" -I "$probeDir" -L "$probeDir" -lMacAppCatalog -lAppCatalogCore -Xlinker -rpath -Xlinker "$probeDir" "$probeDir/AnonymousCatalogProbe.swift" -o "$probeDir/AnonymousCatalogProbe"
```

Adapt the host target if needed. No compiler/toolchain or existing build artifacts were inspected. The scanner necessarily reads public app metadata and creates records in memory; never print/encode the result, snapshot, records, URLs, raw errors or configuration, and do not add preference reads, permission prompts, source filtering or filesystem changes. Main alone may execute the helper; it has not been run here.

The default helper measures a fresh default-root scan. Source confirms integrated-preview mode selects defaults and skips source-store installation (`Sources/PagingPrototypeApp/AppDelegate.swift:810-822,2481-2484`), but whether the current process is that mode is unverified. It cannot retroactively identify that process's last report or reproduce a synthetic/custom-root run without Main confirming the authorized effective configuration in memory.

## Candidate correction and remaining gate

**No product correction proposed.** In particular, do not suppress `invalidAppBundle`, `unreadableDirectory` or cycles, drop roots, or assume missing optional defaults explain the warning. An optional-default absence policy would require explicit origin/optionality semantics plus a targeted regression that still reports inaccessible/explicit sources; the present source does not establish that policy.

Main's next gate is an authorized anonymous helper result, including success/cancellation flags, against the confirmed configuration and source baseline. If `unreadableDirectory > 0`, existing counters still cannot distinguish retained-root failure from descendant failure or missing from denied/IO. If all discovery counts are zero, examine whole-refresh success and retained/cancelled state rather than deleting diagnostics. Physical cause, current category attribution, warning resolution and preview-binary equivalence remain unresolved.

## 2026-10-26 — Library header/cards and measured wrapper warning correction
The earlier live-warning-category unknown boundary now has a fresh equivalent-config explanation, not a retroactive report capture: fiveOSrecognizediOSwrappedAPPL candidates were false negatives of Contents-only metadata lookup. A standardfirst publicBundleAPPL fallback preserves realerrors and outercanonicalURL; old/newdefaultrootprobes137apps/5errors→142/0. NewLibraryHeader8de25194…/ownedPID58258 has no native mainwarning atinspection; same5currentprofilehashes/modespreserved after old26223normalQuit/start. No app launched/renamed/organized byagent.

Main/Library search sharedstyle/geometry/visibleplaceholder andstationaryrootheaders, hiddenbeforemount preview, passivecategorygroups with individualminiappactions. Full3793/0/focused479/0,612inputs/18deltas, two bounded SOURCEPASS andserialartifact/resource/entrygates; native staticheader/menu/background-noexpand/ESCbackverified. Physicalfirstslide/returnflash/currentIME/AXdevice/performance/fullparity/originalintermittentdragcause remainseparate. Newauthority `Workflow/results/LIBRARY_SEARCH_CONTINUITY_2026-10-26.md` and deliveryindex; no oldacceptance repeated or savedname migrated.
