# App Library foundation checkpoint — 2026-10-15

Status: implemented and test/build/package verified; independent Main-foundation/domain/localization source reviews PASS within their bounded scopes. Not native Library feature completion or full parity acceptance.

## Approved source of truth
Human explicitly confirmed the written Library proposal: default-off optional resident-window view, categories/details/manual category, hide/alias reuse, grid restoration, no usage history. Docs/APP_LIBRARY_SPEC.md incorporates Docs/APP_LIBRARY_SLICE_PROPOSAL.md. Formal Chief workflow waived; disjoint agents, no more than three including Main.

## Changes
Foundation worker implemented optional bounded AppBundleMetadata + compatible AppRecord, existing single-plist scanner extraction, alias forwarding, pure22-category taxonomy/19game whitelist/preferences/projection and37tests. Localization worker implemented53typedLibrarykeys, strictschema/fallback andthree independently authored language tables plus9tests. Main implemented serialboundedversionedJSONactor, no-followdescriptor localIO/cooperatinglock/expected-byteCAS, explicitcorruptrecovery/future/duplicateprotection, accepted-write/durable-receipt owner/boundeddrain, coalescedgeneration-gatedoff-mainprojection, candidate-localLibraryprofile/file routing, andtests. Prior wallpaper metadata-only source observer has its five tests verified; no wallpaper render fix claimed.

## Independent review and repairs
Domain/localization bounded SOURCEPASS: Workflow/results/APP_LIBRARY_DOMAIN_LOCALIZATION_REVIEW.md. Main-foundation r1 SOURCEFAIL: Workflow/results/APP_LIBRARY_MAIN_FOUNDATION_REVIEW.md; retained four findings and source fingerprints. Main repaired all four and added six regression methods; fresh independent r2 SOURCEPASS: Workflow/results/APP_LIBRARY_MAIN_FOUNDATION_REVIEW_R2.md. Previous projection observer issue had an actual1test/1failure red regression then repaired113focusedgreen.

Local persistence guarantees cooperating writers in the private local directory, not arbitrary non-participating malicious filesystem mutation. Detected substitutions fail and no-follow anchored operations avoid redirection. Equal-content retries repeat flush work after indeterminate failure. All successful receipts are retained; latest failure preserves/reconciles last acknowledged successful preferences, never claims failed draft saved. Current-file bytes after an indeterminate post-rename failure are not a successful flush or physical-durability receipt.

## Exact current Main evidence
- Focused r5:119 XCTest/0 failures, .build/verification/20261015/app-library/focused-r5.log.
- Full r3:2533 XCTest/0 failures, full-r3.log. Earlier2527/4fail hardcodedlocaleexpectation and119/8fail canonicaltempfixture runs retained, not credited.
- Debug r2:exit0, debug-r2.log.
- Release/package r2:exit0, release-package-r2.log.
- Packaged resource probe:3languages/274requiredkeys positive; missingLibrarykey andinvalidLibraryplaceholder negativefixtures both exit1, packaged-resource-results-r2.json.
-429frozenpackage/source/test/script/resourceinputs match source-inputs-final.json.
-18PagingCore/PagingUI source inputs match the prior wallpaper-state baseline; paging-frozen-check.json. Physics/Timer0ms unchanged.
- Unsigned candidate: .build/candidates/app-library-foundation-rc-20261015-r2/LaunchcopyUITest.app.
- Executable SHA256:8b36c02418f45976c6528b13aba7226d8b18730ad750269c9b9bf43424587b4f.
- No source-only review is represented as independent test execution. No zero-warning historical-test claim. No candidate was opened for GUI acceptance, installed, signed, published or committed. Production data was not used.

## Next executable action
Source-r2 disposition is PASS with the documented cooperating-writer boundary. Main next owns native AppLibraryView and settings enablement integration, preserving the existing sole window. Wire lazy coordinator construction and fail-closed storage routing (never unresolvedtestprofile fallback), startup inspect withoutdirectorycreation, defaultdisabledentry, protected/corrupt explicitrecovery controls. Wire projection only after sharedcatalog commits; invalidate onsource/lifecycle/hide before newcallback/action. Compose existing ownercallbacks, do not replace them.

Implement mode/return-context transaction: save gridquery/page/AppID focus; reject title/drag/modalSaveQuit/restore transitions; immediatelyclosefolder onvalidentry; suspend hiddenpager/search/dots; separatequery/responder/ESCpriority/blankclick/scroll; Back remaps latestvisiblegrid anddoesnotreopenfolder; hide resetsLibraryquery/details and nextshowgrid. Details read current canonicalAppRecord, not aliases or fake cell tokens. Launch/reveal/category/hide/alias/folder actions must re-resolve immutableAppID+expectedrevision+canonicalURL+source/lifecycle epochs; use existingpublicroutes andneutralfailures.

Integrate acceptedLibrarywrite drain into existing bounded WorkspaceQuitCoordinator with defaultCancel; broaden save-failure text truthfully if needed. Guard draft/category generation and publish onlyacknowledgedsuccess. Mount lazy native results with existingboundediconcache, no classifier/icons/views whileclosed, noframe-timeIO/sorting. Add navigation/latest-action/lifecycle/failure/Quit tests, independent source review, new Debug/Release/profilecandidate/packagechecks, then native mounted/VoiceOver/processrestart acceptance. Baselinematchedphysical performance/120Hz and >25ms causality remain separate; no globalusagehistory or rows/columns/extra-gesture scope inferred. Preserve old dirty files/candidates and all r1 fail evidence.
